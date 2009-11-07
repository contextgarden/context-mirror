if not modules then modules = { } end modules ['page-lin'] = {
    version   = 1.001,
    comment   = "companion to page-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental

local format = string.format
local texsprint, texwrite, texbox = tex.sprint, tex.write, tex.box

local ctxcatcodes = tex.ctxcatcodes

nodes            = nodes            or { }
nodes.lines      = nodes.lines      or { }
nodes.lines.data = nodes.lines.data or { } -- start step tag

-- if there is demand for it, we can support multiple numbering streams
-- and use more than one attibute

local hlist, vlist, whatsit = node.id('hlist'), node.id('vlist'), node.id('whatsit')

local display_math     = attributes.private('display-math')
local line_number      = attributes.private('line-number')
local line_reference   = attributes.private('line-reference')

local current_list     = { }
local cross_references = { }
local chunksize        = 250 -- not used in boxed

local has_attribute    = node.has_attribute
local traverse_id      = node.traverse_id
local traverse         = node.traverse
local copy_node        = node.copy

local data = nodes.lines.data

nodes.lines.scratchbox = nodes.lines.scratchbox or 0

-- cross referencing

function nodes.lines.number(n)
    n = tonumber(n)
    local cr = cross_references[n] or 0
    cross_references[n] = nil
    return cr
end

local function resolve(n,m) -- we can now check the 'line' flag (todo)
    while n do
        local id = n.id
        if id == whatsit then -- why whatsit
            local a = has_attribute(n,line_reference)
            if a then
                cross_references[a] = m
            end
        elseif id == hlist or id == vlist then
            resolve(n.list,m)
        end
        n = n.next
    end
end

function nodes.lines.finalize(t)
    local getnumber = nodes.lines.number
    for _,p in next, t do
        for _,r in next, p do
            if r.metadata.kind == "line" then
                local e = r.entries
                local u = r.userdata
                e.linenumber = getnumber(e.text or 0) -- we can nil e.text
                e.conversion = u and u.conversion
                r.userdata = nil -- hack
            end
        end
    end
end

local filters = jobreferences.filters
local helpers = structure.helpers

jobreferences.registerfinalizer(nodes.lines.finalize)

filters.line = filters.line or { }

function filters.line.default(data)
--  helpers.title(data.entries.linenumber or "?",data.metadata)
    texsprint(ctxcatcodes,format("\\convertnumber{%s}{%s}",data.entries.conversion or "numbers",data.entries.linenumber or "0"))
end

function filters.line.page(data,prefixspec,pagespec) -- redundant
    helpers.prefixpage(data,prefixspec,pagespec)
end

function filters.line.linenumber(data) -- raw
    texwrite(data.entries.linenumber or "0")
end


-- boxed variant

nodes.lines.boxed = { }

function nodes.lines.boxed.register(configuration)
    data[#data+1] = configuration
    return #data
end
function nodes.lines.boxed.setup(n,configuration)
    local d = data[n]
    if d then
        for k,v in pairs(configuration) do d[k] = v end
    else
        data[n] = configuration
    end
    return n
end

local leftskip = nodes.leftskip

local function check_number(n,a) -- move inline
    local d = data[a]
    if d then
        local s = d.start
        current_list[#current_list+1] = { n, s }
        if d.start % d.step == 0 then
            texsprint(ctxcatcodes, format("\\makenumber{%s}{%s}{%s}{%s}{%s}\\endgraf", d.tag or "", s, n.shift, n.width, leftskip(n.list)))
        else
            texsprint(ctxcatcodes, "\\skipnumber\\endgraf")
        end
        d.start = s + 1 -- (d.step or 1)
    end
end

function nodes.lines.boxed.stage_one(n)
    current_list = { }
    local head = texbox[n]
    if head then
        local list = head.list
    --~ while list.id == vlist and not list.next do
    --~     list = list.list
    --~ end
        for n in traverse_id(hlist,list) do -- attr test here and quit as soon as zero found
            if n.height == 0 and n.depth == 0 then
                -- skip funny hlists
            else
                local a = has_attribute(n.list,line_number)
                if a and a > 0 then
                    if has_attribute(n,display_math) then
                        if nodes.is_display_math(n) then
                            check_number(n,a)
                        end
                    else
                        if node.first_character(n.list) then
                            check_number(n,a)
                        end
                    end
                end
            end
        end
    end
end

function nodes.lines.boxed.stage_two(n,m)
    if #current_list > 0 then
        m = m or nodes.lines.scratchbox
        local t, i = { }, 0
        for l in traverse_id(hlist,texbox[m].list) do
            t[#t+1] = copy_node(l)
        end
        for j=1,#current_list do
            local l = current_list[j]
            local n, m = l[1], l[2]
            i = i + 1
            t[i].next = n.list
            n.list = t[i]
            resolve(n,m)
       end
    end
end

-- flow variant
--
-- it's too hard to make this one robust, so for the moment it's not
-- available; todo: line refs

if false then

    nodes.lines.flowed = { }

    function nodes.lines.flowed.prepare(tag)
        for i=1,#data do -- ??
            texsprint(ctxcatcodes,format("\\ctxlua{nodes.lines.flowed.prepare_a(%s)}\\ctxlua{nodes.lines.flowed.prepare_b(%s)}",i,i))
        end
    end

    function nodes.lines.flowed.prepare_a(i)
        local d = data[i]
        local p = d.present
        if p and p < chunksize then
            local b = nodes.lines.scratchbox
            texsprint(ctxcatcodes, format("{\\forgetall\\global\\setbox%s=\\vbox{\\unvbox%s\\relax\\offinterlineskip", b, b))
            while p < chunksize do
                texsprint(ctxcatcodes, format("\\mkmaketextlinenumber{%s}{%s}\\endgraf",d.start,1))
                p = p + 1
                d.start = d.start + d.step
            end
            d.present = p
            texsprint(ctxcatcodes, "}}")
        end
    end

    function nodes.lines.flowed.prepare_b(i)
        local d = data[i]
        local b = nodes.lines.scratchbox
        local l = texbox[b]
        if l then
            l = l.list
            local n = d.numbers
            while l do
                if l.id == hlist then
                    local m = copy_node(l)
                    m.next = nil
                    if n then
                        n.next = m
                    else
                        d.numbers = m
                    end
                    n = m
                end
                l = l.next
            end
        end
        tex.box[b] = nil
    end

    function nodes.lines.flowed.cleanup(i)
        if i then
            node.flush_list(data[i].numbers)
        else
            for i=1,#data do
                node.flush_list(data[i].numbers)
            end
        end
    end

    local function check_number(n,a)
        local d = data[a]
        if d then
            local m = d.numbers
            if m then
                d.numbers = m.next
                m.next = n.list
                n.list = m
                d.present = d.present - 1
            end
        end
    end

    function nodes.lines.flowed.apply(head)
        for n in node.traverse(head) do
            local id = n.id
            if id == hlist then
                if n.height == 0 and n.depth == 0 then
                    -- skip funny hlists
                else
                    local a = has_attribute(n,line_number)
                    if a and a > 0 then
                        if has_attribute(n,display_math) then
                            if nodes.is_display_math(n) then
                                check_number(n,a)
                            end
                        else
                            check_number(n,a)
                        end
                    end
                end
            end
        end
        return head, true
    end

end
