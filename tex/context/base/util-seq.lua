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

-- todo: protect groups (as in tasks)

local format, gsub, concat, gmatch = string.format, string.gsub, table.concat, string.gmatch
local type, loadstring = type, loadstring

utilities            = utilities or { }
local tables         = utilities.tables

local sequencers     = { }
utilities.sequencers = sequencers
local functions      = { }
sequencers.functions = functions

local removevalue, insertaftervalue, insertbeforevalue = tables.removevalue, tables.insertaftervalue, tables.insertbeforevalue

local function validaction(action)
    if type(action) == "string" then
        local g = _G
        for str in gmatch(action,"[^%.]+") do
            g = g[str]
            if not g then
                return false
            end
        end
    end
    return true
end

function sequencers.reset(t)
    local s = {
        list   = { },
        order  = { },
        kind   = { },
        askip  = { },
        gskip  = { },
        dirty  = true,
        runner = nil,
    }
    if t then
        s.arguments    = t.arguments
        s.returnvalues = t.returnvalues
        s.results      = t.results
    end
    return s
end

function sequencers.prependgroup(t,group,where)
    if t then
        local order = t.order
        removevalue(order,group)
        insertbeforevalue(order,where,group)
        t.list[group], t.dirty, t.runner = { }, true, nil
    end
end

function sequencers.appendgroup(t,group,where)
    if t then
        local order = t.order
        removevalue(order,group)
        insertaftervalue(order,where,group)
        t.list[group], t.dirty, t.runner = { }, true, nil
    end
end

function sequencers.prependaction(t,group,action,where,kind,force)
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertbeforevalue(g,where,action)
            t.kind[action], t.dirty, t.runner = kind, true, nil
        end
    end
end

function sequencers.appendaction(t,group,action,where,kind,force)
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertaftervalue(g,where,action)
            t.kind[action], t.dirty, t.runner = kind, true, nil
        end
    end
end

function sequencers.enableaction (t,action)
    if t then
        t.askip[action], t.dirty, t.runner = false, true, nil
    end
end

function sequencers.disableaction(t,action)
    if t then
        t.askip[action], t.dirty, t.runner = true, true, nil
    end
end

function sequencers.enablegroup(t,group)
    if t then
        t.gskip[group], t.dirty, t.runner = false, true, nil
    end
end

function sequencers.disablegroup(t,group)
    if t then
        t.gskip[group], t.dirty, t.runner = true, true, nil
    end
end

function sequencers.setkind(t,action,kind)
    if t then
        t.kind[action], t.dirty, t.runner = kind, true, nil
    end
end

function sequencers.removeaction(t,group,action,force)
    local g = t and t.list[group]
    if g and (force or validaction(action)) then
        removevalue(g,action)
        t.dirty, t.runner = true, nil
    end
end

local function localize(str)
    return (gsub(str,"[%.: ]+","_"))
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
                    if type(action) == "function" then
                        local name = localize(tostring(action))
                        functions[name] = action
                        action = format("utilities.sequencers.functions.%s",name)
                    end
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
            t.compiled = format("%s\nreturn function(%s)\n%s\nreturn %s\nend",variables,arguments,calls,results)
        else
            t.compiled = format("%s\nreturn function(%s)\n%s\nend",variables,arguments,calls)
        end
        return t.compiled -- also stored so that we can trace
    end
end

sequencers.tostring = construct
sequencers.localize = localize

local function compile(t,compiler,n)
    if not t or type(t) == "string" then
        -- weird ... t.compiled = t .. so
        return false
    elseif compiler then
        t.compiled = compiler(t,n)
    else
        t.compiled = construct(t)
    end
    local runner = loadstring(t.compiled)()
    t.runner = runner
    return runner -- faster
end

sequencers.compile = compile

function sequencers.autocompile(t,compiler,n) -- to be used in tasks
    t.runner = compile(t,compiler,n)
    local autorunner = function(...)
        return (t.runner or compile(t,compiler,n))(...) -- ugly but less bytecode
    end
    t.autorunner = autorunner
    return autorunner -- one more encapsulation
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
                        calls[n] = format("        ok = %s(head%s) done = done or ok",localized,args)
                    else
                        calls[n] = format("  head, ok = %s(head%s) done = done or ok",localized,args)
                    end
                end
            end
        end
    end
    local processor = format(template,concat(vars,"\n"),args,concat(calls,"\n"))
 -- print(processor)
    return processor
end
