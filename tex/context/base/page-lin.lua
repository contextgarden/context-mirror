if not modules then modules = { } end modules ['page-lin'] = {
    version   = 1.001,
    comment   = "companion to page-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental

local trace_numbers = false  trackers.register("lines.numbers",  function(v) trace_numbers = v end)

local report_lines = logs.new("lines")

local format = string.format
local texsprint, texwrite, texbox = tex.sprint, tex.write, tex.box

local ctxcatcodes = tex.ctxcatcodes
local variables = interfaces.variables

nodes             = nodes             or { }
nodes.lines       = nodes.lines       or { }
nodes.lines.data  = nodes.lines.data  or { } -- start step tag

storage.register("lines/data", nodes.lines.data, "nodes.lines.data")

-- if there is demand for it, we can support multiple numbering streams
-- and use more than one attibute

local nodecodes = nodes.nodecodes

local hlist   = nodecodes.hlist
local vlist   = nodecodes.vlist
local whatsit = nodecodes.whatsit

local display_math     = attributes.private('display-math')
local line_number      = attributes.private('line-number')
local line_reference   = attributes.private('line-reference')
local verbatim_line    = attributes.private('verbatim-line')

local current_list     = { }
local cross_references = { }
local chunksize        = 250 -- not used in boxed

local has_attribute      = node.has_attribute
local traverse_id        = node.traverse_id
local traverse           = node.traverse
local copy_node          = node.copy
local hpack_node         = node.hpack
local insert_node_after  = node.insert_after
local insert_node_before = node.insert_before

local data = nodes.lines.data
local last = #data

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

-- boxed variant, todo: use number mechanism

nodes.lines.boxed = { }

-- todo: cache setups, and free id no longer used
-- use interfaces.cachesetup(t)

function nodes.lines.boxed.register(configuration)
    last = last + 1
    data[last] = configuration
    if trace_numbers then
        report_lines("registering setup %s",last)
    end
    return last
end

function nodes.lines.boxed.setup(n,configuration)
    local d = data[n]
    if d then
        if trace_numbers then
            report_lines("updating setup %s",n)
        end
        for k,v in next, configuration do
            d[k] = v
        end
    else
        if trace_numbers then
            report_lines("registering setup %s (br)",n)
        end
        data[n] = configuration
    end
    return n
end

local the_left_margin = nodes.the_left_margin

local function check_number(n,a,skip,sameline)
    local d = data[a]
    if d then
        local tag, skipflag, s = d.tag or "", 0, d.start or 1
        current_list[#current_list+1] = { n, s }
        if sameline then
            skipflag = 0
            if trace_numbers then
                report_lines("skipping broken line number %s for setup %s: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        elseif not skip and s % d.step == 0 then
            skipflag, d.start = 1, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("making number %s for setup %s: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        else
            skipflag, d.start = 0, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("skipping line number %s for setup %s: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        end
        context.makelinenumber(tag,skipflag,s,n.shift,n.width,the_left_margin(n.list),n.dir)
    end
end

function nodes.lines.boxed.stage_one(n)
    current_list = { }
    local head = texbox[n]
    if head then
        local list = head.list
        local last_a, last_v, skip = nil, -1, false
        for n in traverse_id(hlist,list) do -- attr test here and quit as soon as zero found
            if n.height == 0 and n.depth == 0 then
                -- skip funny hlists
            else
                local list = n.list
                local a = has_attribute(list,line_number)
                if a and a > 0 then
                    if last_a ~= a then
                        if data[a].method == variables.next then
                            skip = true
                        end
                        last_a = a
                    end
                    if has_attribute(n,display_math) then
                        if nodes.is_display_math(n) then
                            check_number(n,a,skip)
                        end
                    else
                        local v = has_attribute(list,verbatim_line)
                        if not v or v ~= last_v then
                            last_v = v
                            check_number(n,a,skip)
                        else
                            check_number(n,a,skip,true)
                        end
                    end
                    skip = false
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
        for i=1,#current_list do
            local li = current_list[i]
            local n, m, ti = li[1], li[2], t[i]
            ti.next, n.list = n.list, ti
            resolve(n,m)
       end
    end
end
