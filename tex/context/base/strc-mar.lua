if not modules then modules = { } end modules ['strc-mar'] = {
    version   = 1.001,
    comment   = "companion to strc-mar.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: cleanup stack (structures.marks.reset(v_all) also does the job)

local insert, concat = table.insert, table.concat
local tostring, next, setmetatable, rawget = tostring, next, setmetatable, rawget
local lpegmatch = lpeg.match

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local hasattribute       = nodes.hasattribute
local traversenodes      = node.traverse
local texsetattribute    = tex.setattribute
local texbox             = tex.box

local a_marks            = attributes.private("structure","marks")

local trace_marks_set    = false  trackers.register("marks.set",    function(v) trace_marks_set = v end)
local trace_marks_get    = false  trackers.register("marks.get",    function(v) trace_marks_get = v end)
local trace_marks_all    = false  trackers.register("marks.detail", function(v) trace_marks_all = v end)

local report_marks       = logs.new("structure","marks")

local variables          = interfaces.variables

local v_first            = variables.first
local v_last             = variables.last
local v_previous         = variables.previous
local v_next             = variables.next
local v_top              = variables.top
local v_bottom           = variables.bottom
local v_current          = variables.current
local v_default          = variables.default
local v_page             = variables.page
local v_all              = variables.all

local v_nocheck_suffix   = ":" .. variables.nocheck

local v_first_nocheck    = variables.first    .. v_nocheck_suffix
local v_last_nocheck     = variables.last     .. v_nocheck_suffix
local v_previous_nocheck = variables.previous .. v_nocheck_suffix
local v_next_nocheck     = variables.next     .. v_nocheck_suffix
local v_top_nocheck      = variables.top      .. v_nocheck_suffix
local v_bottom_nocheck   = variables.bottom   .. v_nocheck_suffix

local structures         = structures
local marks              = structures.marks
local lists              = structures.lists

local settings_to_array  = utilities.parsers.settings_to_array

marks.data               = marks.data or { }

storage.register("structures/marks/data", marks.data, "structures.marks.data")

local data = marks.data
local stack, topofstack = { }, 0

local ranges = {
    [v_page] = {
        first = 0,
        last  = 0,
    },
}

local function resolve(t,k)
    if k then
        if trace_marks_set or trace_marks_get then
            report_marks("undefined: name=%s",k)
        end
        local crap = { autodefined = true }
        t[k] = crap
        return crap
    else
        -- weird: k is nil
    end
end

setmetatable(data, { __index = resolve} )

function marks.exists(name)
    return rawget(data,name) ~= nil
end

-- identify range

local function sweep(head,first,last)
    for n in traversenodes(head) do
        local id = n.id
        if id == glyph_code then
            local a = hasattribute(n,a_marks)
            if not a then
                -- next
            elseif first == 0 then
                first, last = a, a
            elseif a > last then
                last = a
            end
        elseif id == hlist_code or id == vlist_code then
            local a = hasattribute(n,a_marks)
            if not a then
                -- next
            elseif first == 0 then
                first, last = a, a
            elseif a > last then
                last = a
            end
            local list = n.list
            if list then
                first, last = sweep(list, first, last)
            end
        end
    end
    return first, last
end

local classes = { }

setmetatable(classes, { __index = function(t,k) local s = settings_to_array(k) t[k] = s return s end } )

function marks.synchronize(class,n)
    local box = texbox[n]
    if box then
        local first, last = sweep(box.list,0,0)
        local classlist = classes[class]
        for i=1,#classlist do
            local class = classlist[i]
            local range = ranges[class]
            if not range then
                range = { }
                ranges[class] = range
            end
            range.first, range.last = first, last
            if trace_marks_get or trace_marks_set then
                report_marks("synchronize: class=%s, first=%s, last=%s",class,range.first,range.last)
            end
        end
    elseif trace_marks_get or trace_marks_set then
        report_marks("synchronize: class=%s, box=%s, no content",class,n)
    end
end

-- define etc

local function resolve(t,k)
    if k == "fullchain" then
        local fullchain = { }
        local chain = t.chain
        while chain and chain ~= "" do
            insert(fullchain,1,chain)
            chain = data[chain].chain
        end
        t[k] = fullchain
        return fullchain
    elseif k == "chain" then
        t[k] = ""
        return ""
    elseif k == "reset" or k == "set" then
        t[k] = 0
        return 0
    elseif k == "parent" then
        t[k] = false
        return false
    end
end

function marks.define(name,settings)
    settings = settings or { }
    data[name] = settings
    local parent = settings.parent
    if parent == nil or parent == "" then
        settings.parent = false
    else
        local dp = data[parent]
        if not dp then
            settings.parent = false
        elseif dp.parent then
            settings.parent = dp.parent
        end
    end
    setmetatable(settings, { __index = resolve } )
end

for k, v in next, data do
    setmetatable(v, { __index = resolve } ) -- runtime loaded table
end

local function parentname(name)
    local dn = data[name]
    return dn and dn.parent or name
end

function marks.relate(name,chain)
    local dn = data[name]
    if dn and not dn.parent then
        if chain and chain ~= "" then
            dn.chain = chain
            local dc = data[chain]
            if dc then
                local children = dc.children
                if not children then
                    children = { }
                    dc.children = children
                end
                children[#children+1] = name
            end
        elseif trace_marks_set then
            report_marks("invalid relation: name=%s, chain=%s",name,chain or "-")
        end
    end
end

local function resetchildren(new,name)
    local dn = data[name]
    if dn and not dn.parent then
        local children = dn.children
        if children then
            for i=1,#children do
                local ci = children[i]
                new[ci] = false
                if trace_marks_set then
                    report_marks("reset: parent=%s, child=%s",name,ci)
                end
                resetchildren(new,ci)
            end
        end
    end
end

function marks.set(name,value)
    local dn = data[name]
    if dn then
        local child = name
        local parent = dn.parent
        if parent then
            name = parent
            dn = data[name]
        end
        dn.set = topofstack
        local top = stack[topofstack]
        local new = { }
        if top then
            for k, v in next, top do
                local d = data[k]
                local r = d.reset
                local s = d.set
                if r <= topofstack and s < r then
                    new[k] = false
                else
                    new[k] = v
                end
            end
        end
        resetchildren(new,name)
        new[name] = value
        topofstack = topofstack + 1
        stack[topofstack] = new
        if trace_marks_set then
            if name == child then
                report_marks("set: name=%s, index=%s, value=%s",name,topofstack,value)
            else
                report_marks("set: parent=%s, child=%s, index=%s, value=%s",parent,child,topofstack,value)
            end
        end
        tex.setattribute("global",a_marks,topofstack)
    end
end

local function reset(name)
    if v_all then
        if trace_marks_set then
            report_marks("reset: all")
        end
        stack = { }
        for name, dn in next, data do
            local parent = dn.parent
            if parent then
                dn.reset = 0
                dn.set = 0
            end
        end
    else
        local dn = data[name]
        if dn then
            local parent = dn.parent
            if parent then
                name = parent
                dn = data[name]
            end
            if trace_marks_set then
                report_marks("reset: name=%s, index=%s",name,topofstack)
            end
            dn.reset = topofstack
            local children = dn.children
            if children then
                for i=1,#children do
                    local ci = children[i]
                    reset(ci)
                end
            end
        end
    end
end

marks.reset = reset

function marks.get(n,name,value)
    local dn = data[name]
    if dn then
        name = dn.parent or name
        local top = stack[n]
        if top then
            context(top[name])
        end
    end
end

function marks.show(first,last)
    if first and last then
        for k=first,last do
            local v = stack[k]
            if v then
                report_marks("% 4i: %s",k,table.sequenced(v))
            end
        end
    else
        for k, v in table.sortedpairs(stack) do
            report_marks("% 4i: %s",k,table.sequenced(v))
        end
    end
end

local function resolve(name,first,last,strict,quitonfalse,notrace)
    local dn = data[name]
    if dn then
        local child = name
        local parent = dn.parent
        name = parent or child
        dn = data[name]
        local step, method
        if first > last then
            step, method = -1, "bottom-up"
        else
            step, method = 1, "top-down"
        end
        if trace_marks_get and not notrace then
            report_marks("request: strategy=%s, name=%s, parent=%s, strict=%s",method,child,parent or "",tostring(strict or false))
        end
        if trace_marks_all and not notrace then
            marks.show(first,last)
        end
        local r = dn.reset
        local s = dn.set
        if first <= last and first <= r then
            if trace_marks_get and not notrace then
                report_marks("reset (first case): name=%s, first=%s, last=%s, reset=%s, index=%s",name,first,last,r,first)
            end
        elseif first >= last and last <= r then
            if trace_marks_get and not notrace then
                report_marks("reset (last case): name=%s, first=%s, last=%s, reset=%s, index=%s",name,first,last,r,last)
            end
        elseif not stack[first] or not stack[last] then
            if trace_marks_get and not notrace then
                -- a previous or next method can give an out of range, which is valid
                report_marks("out of range: name=%s, reset=%s, index=%s",name,r,first)
            end
        elseif strict then
            local top = stack[first]
            local fullchain = dn.fullchain
            if not fullchain or #fullchain == 0 then
                if trace_marks_get and not notrace then
                    report_marks("no full chain, trying: name=%s, first=%s, last=%s",name,first,last)
                end
                return resolve(name,first,last)
            else
                if trace_marks_get and not notrace then
                    report_marks("found chain: %s",concat(fullchain," => "))
                end
                local chaindata, chainlength = { }, #fullchain
                for i=1,chainlength do
                    local cname = fullchain[i]
                    if data[cname].set > 0 then
                        local value = resolve(cname,first,last,false,false,true)
                        if value == "" then
                            if trace_marks_get and not notrace then
                                report_marks("quit chain: name=%s, reset=%s, start=%s",name,r,first)
                            end
                            return ""
                        else
                            chaindata[i] = value
                        end
                    end
                end
                if trace_marks_get and not notrace then
                    report_marks("chain list: %s",concat(chaindata," => "))
                end
                local value, index, found = resolve(name,first,last,false,false,true)
                if value ~= ""  then
                    if trace_marks_get and not notrace then
                        report_marks("following chain: %s",concat(fullchain," => "))
                    end
                    for i=1,chainlength do
                        local cname = fullchain[i]
                        if data[cname].set > 0 and chaindata[i] ~= found[cname] then
                            if trace_marks_get and not notrace then
                                report_marks("empty in chain: name=%s, reset=%s, index=%s",name,r,first)
                            end
                            return ""
                        end
                    end
                    if trace_marks_get and not notrace then
                        report_marks("found: name=%s, reset=%s, start=%s, index=%s, value=%s",name,r,first,index,value)
                    end
                    return value, index, found
                elseif trace_marks_get and not notrace then
                    report_marks("not found: name=%s, reset=%s",name,r)
                end
            end
        else
            for i=first,last,step do
                local current = stack[i]
                local value = current and current[name]
                if value == nil then
                    -- search on
                elseif value == false then
                    if quitonfalse then
                        return ""
                    end
                elseif value == true then
                    if trace_marks_get and not notrace then
                        report_marks("quit: name=%s, reset=%s, start=%s, index=%s",name,r,first,i)
                    end
                    return ""
                elseif value ~= "" then
                    if trace_marks_get and not notrace then
                        report_marks("found: name=%s, reset=%s, start=%s, index=%s, value=%s",name,r,first,i,value)
                    end
                    return value, i, current
                end
            end
            if trace_marks_get and not notrace then
                report_marks("not found: name=%s, reset=%s",name,r)
            end
        end
    end
    return ""
end

-- todo: column:first column:last

local methods  = { }

local function doresolve(name,rangename,swap,df,dl,strict)
    local range = ranges[rangename] or ranges[v_page]
    local first, last = range.first, range.last
    if trace_marks_get then
        report_marks("resolve: name=%s, range=%s, swap=%s, first=%s, last=%s, df=%s, dl=%s, strict=%s",
            name,rangename,tostring(swap or false),first,last,df,dl,tostring(strict or false))
    end
    if swap then
        first, last = last + df, first + dl
    else
        first, last = first + df, last + dl
    end
    local value, index, found = resolve(name,first,last,strict)
    -- maybe something more
    return value, index, found
end

methods[v_previous]         = function(name,range) return doresolve(name,range,false,-1,0,true ) end -- strict
methods[v_top]              = function(name,range) return doresolve(name,range,false, 0,0,true ) end -- strict
methods[v_bottom]           = function(name,range) return doresolve(name,range,true , 0,0,true ) end -- strict
methods[v_next]             = function(name,range) return doresolve(name,range,true , 0,1,true ) end -- strict

methods[v_previous_nocheck] = function(name,range) return doresolve(name,range,false,-1,0,false) end
methods[v_top_nocheck]      = function(name,range) return doresolve(name,range,false, 0,0,false) end
methods[v_bottom_nocheck]   = function(name,range) return doresolve(name,range,true , 0,0,false) end
methods[v_next_nocheck]     = function(name,range) return doresolve(name,range,true , 0,1,false) end

local function resolve(name,range,f_swap,l_swap,step,strict) -- we can have an offset
    local f_value, f_index, f_found = doresolve(name,range,f_swap,0,0,strict)
    local l_value, l_index, l_found = doresolve(name,range,l_swap,0,0,strict)
    if f_found and l_found and l_index > f_index then
        local name = parentname(name)
        for i=f_index,l_index,step do
            local si = stack[i]
            local sn = si[name]
            if sn and sn ~= false and sn ~= true and sn ~= "" and sn ~= f_value then
                return sn, i, si
            end
        end
    end
    return f_value, f_index, f_found
end

methods[v_first        ] = function(name,range) return resolve(name,range,false,true, 1,true ) end -- strict
methods[v_last         ] = function(name,range) return resolve(name,range,true,false,-1,true ) end -- strict

methods[v_first_nocheck] = function(name,range) return resolve(name,range,false,true, 1,false) end
methods[v_last_nocheck ] = function(name,range) return resolve(name,range,true,false,-1,false) end

methods[v_current] = function(name,range) -- range is ignored here
    local top = stack[topofstack]
    return top and top[parentname(name)] or ""
end

local function fetched(name,range,method)
    local value = (methods[method] or methods[v_first])(name,range) or ""
    if not trace_marks_get then
        -- no report
    elseif value == "" then
        report_marks("nothing fetched: name=%s, range=%s, method=%s",name,range,method)
    else
        report_marks("marking fetched: name=%s, range=%s, method=%s, value=%s",name,range,method,value)
    end
    return value or ""
end

-- can be used at the lua end:

marks.fetched = fetched

-- this will move to a separate runtime modules

marks.tracers = marks.tracers or { }

function marks.tracers.showtable()
    context.starttabulate { "|l|l|l|lp|lp|" }
    context.tabulaterowbold("name","parent","chain","children","fullchain")
    context.ML()
    for k, v in table.sortedpairs(data) do
        local parent, chain, children, fullchain = v.parent or "", v.chain or "", v.children or { }, v.fullchain or { }
        table.sort(children) -- in-place but harmless
        context.tabulaterowtyp(k,parent,chain,concat(children," "),concat(fullchain," "))
    end
    context.stoptabulate()
end

-- pushing to context:

local separator = context.nested.markingseparator
local command   = context.nested.markingcommand
local ctxconcat = context.concat

local function fetchonemark(name,range,method)
    context(command(name,fetched(name,range,method)))
end

local function fetchtwomarks(name,range)
    ctxconcat( {
        command(name,fetched(name,range,v_first)),
        command(name,fetched(name,range,v_last)),
    }, separator(name))
end

local function fetchallmarks(name,range)
    ctxconcat( {
        command(name,fetched(name,range,v_previous)),
        command(name,fetched(name,range,v_first)),
        command(name,fetched(name,range,v_last)),
    }, separator(name))
end

function marks.fetch(name,range,method) -- chapter page first | chapter column:1 first
    if trace_marks_get then
        report_marks("marking asked: name=%s, range=%s, method=%s",name,range,method)
    end
    if method == "" or method == v_default then
        fetchonemark(name,range,v_first)
    elseif method == v_both then
        fetchtwomarks(name,range)
    elseif method == v_all then
        fetchallmarks(name,range)
    else
        fetchonemark(name,range,method)
    end
end

function marks.fetchonemark (name,range,method) fetchonemark (name,range,method) end
function marks.fetchtwomarks(name,range)        fetchtwomarks(name,range       ) end
function marks.fetchallmarks(name,range)        fetchallmarks(name,range       ) end

-- here we have a few helpers

function marks.title(tag,n)
    lists.savedtitle(tag,n,"marking")
end

function marks.number(tag,n) -- no spec
    -- no prefix (as it is the prefix)
    lists.savednumber(tag,n)
end

-- interface

commands.definemarking      = marks.define
commands.relatemarking      = marks.relate
commands.setmarking         = marks.set
commands.resetmarking       = marks.reset
commands.synchronizemarking = marks.synchronize
commands.getmarking         = marks.fetch
commands.fetchonemark       = marks.fetchonemark
commands.fetchtwomarks      = marks.fetchtwomarks
commands.fetchallmarks      = marks.fetchallmarks

function commands.doifelsemarking(str) -- can be shortcut
    commands.testcase(marks.exists(str))
end

