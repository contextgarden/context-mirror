if not modules then modules = { } end modules ['util-seq'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Here we implement a mechanism for chaining the special functions
that we use in <l n="context"> to deal with mode list processing. We
assume that namespaces for the functions are used, but for speed we
use locals to refer to them when compiling the chain.</p>
--ldx]]--

-- todo: delayed: i.e. we register them in the right order already but delay usage

local format, gsub, concat, gmatch = string.format, string.gsub, table.concat, string.gmatch
local type, loadstring = type, loadstring

utilities            = utilities or { }
local tables         = utilities.tables

local sequencers     = { }
utilities.sequencers = sequencers

local removevalue, insertaftervalue, insertbeforevalue = tables.removevalue, tables.insertaftervalue, tables.insertbeforevalue

local function validaction(action)
    local g = _G
    for str in gmatch(action,"[^%.]+") do
        g = g[str]
        if not g then
            return false
        end
    end
    return true
end

function sequencers.reset(t)
    local s = {
        list  = { },
        order = { },
        kind  = { },
        askip = { },
        gskip = { },
    }
    if t then
        s.arguments    = t.arguments
        s.returnvalues = t.returnvalues
        s.results      = t.results
    end
    s.dirty = true
    return s
end

function sequencers.prependgroup(t,group,where)
    if t then
        local list, order = t.list, t.order
        removevalue(order,group)
        insertbeforevalue(order,where,group)
        list[group] = { }
        t.dirty = true
    end
end

function sequencers.appendgroup(t,group,where)
    if t then
        local list, order = t.list, t.order
        removevalue(order,group)
        insertaftervalue(order,where,group)
        list[group] = { }
        t.dirty = true
    end
end

function sequencers.prependaction(t,group,action,where,kind,force)
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertbeforevalue(g,where,action)
            t.kind[action] = kind
            t.dirty = true
        end
    end
end

function sequencers.appendaction(t,group,action,where,kind,force)
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertaftervalue(g,where,action)
            t.kind[action] = kind
            t.dirty = true
        end
    end
end

function sequencers.enableaction (t,action) if t then t.dirty = true t.askip[action] = false end end
function sequencers.disableaction(t,action) if t then t.dirty = true t.askip[action] = true  end end
function sequencers.enablegroup  (t,group)  if t then t.dirty = true t.gskip[group]  = false end end
function sequencers.disablegroup (t,group)  if t then t.dirty = true t.gskip[group]  = true  end end

function sequencers.setkind(t,action,kind)
    if t then
        t.kind[action] = kind
        t.dirty = true
    end
end

function sequencers.removeaction(t,group,action,force)
    local g = t and t.list[group]
    if g and (force or validaction(action)) then
        removevalue(g,action)
        t.dirty = true
    end
end

local function localize(str)
    return (gsub(str,"%.","_"))
end

local function construct(t,nodummy)
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local arguments, returnvalues, results = t.arguments or "...", t.returnvalues, t.results
    local variables, calls, n = { }, { }, 0
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized = localize(action)
                    n = n + 1
                    variables[n] = format("local %s = %s",localized,action)
                    if not returnvalues then
                        calls[n] = format("%s(%s)",localized,arguments)
                    elseif n == 1 then
                        calls[n] = format("local %s = %s(%s)",returnvalues,localized,arguments)
                    else
                        calls[n] = format("%s = %s(%s)",returnvalues,localized,arguments)
                    end
                end
            end
        end
    end
    t.dirty = false
    if nodummy and #calls == 0 then
        return nil
    else
        variables = concat(variables,"\n")
        calls = concat(calls,"\n")
        if results then
            return format("%s\nreturn function(%s)\n%s\nreturn %s\nend",variables,arguments,calls,results)
        else
            return format("%s\nreturn function(%s)\n%s\nend",variables,arguments,calls)
        end
    end
end

sequencers.tostring = construct
sequencers.localize = localize

function sequencers.compile(t,compiler,n)
    if not t or type(t) == "string" then
        -- already compiled
    elseif compiler then
        t = compiler(t,n)
    else
        t = construct(t)
    end
    return loadstring(t)()
end

-- we used to deal with tail as well but now that the lists are always
-- double linked and the kernel function no longer expect tail as
-- argument we stick to head and done (done can probably also go
-- as luatex deals with return values efficiently now .. in the
-- past there was some copying involved, but no longer)

local template = [[
%s
return function(head%s)
  local ok, done = false, false
%s
  return head, done
end]]

function sequencers.nodeprocessor(t,nofarguments) -- todo: handle 'kind' in plug into tostring
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local vars, calls, args, n = { }, { }, nil, 0
    if nofarguments == 0 then
        args = ""
    elseif nofarguments == 1 then
        args = ",one"
    elseif nofarguments == 2 then
        args = ",one,two"
    elseif nofarguments == 3 then
        args = ",one,two,three"
    elseif nofarguments == 4 then
        args = ",one,two,three,four"
    elseif nofarguments == 5 then
        args = ",one,two,three,four,five"
    else
        args = ",..."
    end
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized = localize(action)
                    n = n + 1
                    vars[n] = format("local %s = %s",localized,action)
                    -- only difference with tostring is kind and rets (why no return)
                    if kind[action] == "nohead" then
                        calls[n] = format("        ok = %s(head%s) done = done or ok -- %s %i",localized,args,group,i)
                    else
                        calls[n] = format("  head, ok = %s(head%s) done = done or ok -- %s %i",localized,args,group,i)
                    end
                end
            end
        end
    end
    local processor = format(template,concat(vars,"\n"),args,concat(calls,"\n"))
 -- print(processor)
    return processor
end
