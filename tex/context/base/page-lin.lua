if not modules then modules = { } end modules ['page-lin'] = {
    version   = 1.001,
    comment   = "companion to page-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental -> will become builders

local trace_numbers = false  trackers.register("lines.numbers",  function(v) trace_numbers = v end)

local report_lines = logs.reporter("lines")

local attributes, nodes, node, context = attributes, nodes, node, context

nodes.lines       = nodes.lines or { }
local lines       = nodes.lines

lines.data        = lines.data or { } -- start step tag
local data        = lines.data
local last        = #data

local texgetbox   = tex.getbox

lines.scratchbox  = lines.scratchbox or 0

local leftmarginwidth = nodes.leftmarginwidth

storage.register("lines/data", lines.data, "nodes.lines.data")

-- if there is demand for it, we can support multiple numbering streams
-- and use more than one attibute

local variables          = interfaces.variables

local nodecodes          = nodes.nodecodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local whatsit_code       = nodecodes.whatsit

local a_displaymath      = attributes.private('displaymath')
local a_linenumber       = attributes.private('linenumber')
local a_linereference    = attributes.private('linereference')
local a_verbatimline     = attributes.private('verbatimline')

local current_list       = { }
local cross_references   = { }
local chunksize          = 250 -- not used in boxed

local traverse_id        = node.traverse_id
local traverse           = node.traverse
local copy_node          = node.copy
local hpack_node         = node.hpack
local insert_node_after  = node.insert_after
local insert_node_before = node.insert_before

-- cross referencing

function lines.number(n)
    n = tonumber(n)
    local cr = cross_references[n] or 0
    cross_references[n] = nil
    return cr
end

local function resolve(n,m) -- we can now check the 'line' flag (todo)
    while n do
        local id = n.id
        if id == whatsit_code then -- why whatsit
            local a = n[a_linereference]
            if a then
                cross_references[a] = m
            end
        elseif id == hlist_code or id == vlist_code then
            resolve(n.list,m)
        end
        n = n.next
    end
end

function lines.finalize(t)
    local getnumber = lines.number
    for _,p in next, t do
        for _,r in next, p do
            local m = r.metadata
            if m and m.kind == "line" then
                local e = r.entries
                local u = r.userdata
                e.linenumber = getnumber(e.text or 0) -- we can nil e.text
                e.conversion = u and u.conversion
                r.userdata = nil -- hack
            end
        end
    end
end

local filters = structures.references.filters
local helpers = structures.helpers

structures.references.registerfinalizer(lines.finalize)

filters.line = filters.line or { }

function filters.line.default(data)
--  helpers.title(data.entries.linenumber or "?",data.metadata)
    context.convertnumber(data.entries.conversion or "numbers",data.entries.linenumber or "0")
end

function filters.line.page(data,prefixspec,pagespec) -- redundant
    helpers.prefixpage(data,prefixspec,pagespec)
end

function filters.line.linenumber(data) -- raw
    context(data.entries.linenumber or "0")
end

-- boxed variant, todo: use number mechanism

lines.boxed = { }
local boxed = lines.boxed

-- todo: cache setups, and free id no longer used
-- use interfaces.cachesetup(t)

function boxed.register(configuration)
    last = last + 1
    data[last] = configuration
    if trace_numbers then
        report_lines("registering setup %a",last)
    end
    return last
end

function commands.registerlinenumbering(configuration)
    context(boxed.register(configuration))
end

function boxed.setup(n,configuration)
    local d = data[n]
    if d then
        if trace_numbers then
            report_lines("updating setup %a",n)
        end
        for k,v in next, configuration do
            d[k] = v
        end
    else
        if trace_numbers then
            report_lines("registering setup %a (br)",n)
        end
        data[n] = configuration
    end
    return n
end

commands.setuplinenumbering = boxed.setup

local function check_number(n,a,skip,sameline)
    local d = data[a]
    if d then
        local tag, skipflag, s = d.tag or "", 0, d.start or 1
        current_list[#current_list+1] = { n, s }
        if sameline then
            skipflag = 0
            if trace_numbers then
                report_lines("skipping broken line number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        elseif not skip and s % d.step == 0 then
            skipflag, d.start = 1, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("making number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        else
            skipflag, d.start = 0, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("skipping line number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or "no")
            end
        end
        context.makelinenumber(tag,skipflag,s,n.shift,n.width,leftmarginwidth(n.list),n.dir)
    end
end

-- xlist
--   xlist
--     hlist

local function identify(list)
    if list then
        for n in traverse_id(hlist_code,list) do
            if n[a_linenumber] then
                return list
            end
        end
        local n = list
        while n do
            local id = n.id
            if id == hlist_code or id == vlist_code then
                local ok = identify(n.list)
                if ok then
                    return ok
                end
            end
            n = n.next
        end
    end
end

function boxed.stage_zero(n)
    return identify(texgetbox(n).list)
end

-- reset ranges per page
-- store first and last per page
-- maybe just set marks directly

function boxed.stage_one(n,nested)
    current_list = { }
    local box = texgetbox(n)
    if box then
        local list = box.list
        if nested then
            list = identify(list)
        end
        local last_a, last_v, skip = nil, -1, false
        for n in traverse_id(hlist_code,list) do -- attr test here and quit as soon as zero found
            if n.height == 0 and n.depth == 0 then
                -- skip funny hlists -- todo: check line subtype
            else
                local list = n.list
                local a = list[a_linenumber]
                if a and a > 0 then
                    if last_a ~= a then
                        local da = data[a]
                        local ma = da.method
                        if ma == variables.next then
                            skip = true
                        elseif ma == variables.page then
                            da.start = 1 -- eventually we will have a normal counter
                        end
                        last_a = a
                        if trace_numbers then
                            report_lines("starting line number range %s: start %s, continue",a,da.start,da.continue or "no")
                        end
                    end
                    if n[a_displaymath] then
                        if nodes.is_display_math(n) then
                            check_number(n,a,skip)
                        end
                    else
                        local v = list[a_verbatimline]
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

function boxed.stage_two(n,m)
    if #current_list > 0 then
        m = m or lines.scratchbox
        local t, tn = { }, 0
        for l in traverse_id(hlist_code,texgetbox(m).list) do
            tn = tn + 1
            t[tn] = copy_node(l)
        end
        for i=1,#current_list do
            local li = current_list[i]
            local n, m, ti = li[1], li[2], t[i]
            if ti then
                ti.next, n.list = n.list, ti
                resolve(n,m)
            else
                report_lines("error in linenumbering (1)")
                return
            end
       end
    end
end

commands.linenumbersstageone = boxed.stage_one
commands.linenumbersstagetwo = boxed.stage_two
