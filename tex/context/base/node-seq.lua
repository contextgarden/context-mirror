if not modules then modules = { } end modules ['node-seq'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
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

sequencer = sequencer or { }

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

function sequencer.reset()
    return {
        list  = { },
        order = { },
        kind  = { },
        askip = { },
        gskip = { },
    }
end

function sequencer.prependgroup(t,group,where)
    local list, order = t.list, t.order
    table.remove_value(order,group)
    table.insert_before_value(order,where,group)
    list[group] = { }
end

function sequencer.appendgroup(t,group,where)
    local list, order = t.list, t.order
    table.remove_value(order,group)
    table.insert_after_value(order,where,group)
    list[group] = { }
end

function sequencer.prependaction(t,group,action,where,kind,force)
    local g = t.list[group]
    if g and (force or validaction(action)) then
        table.remove_value(g,action)
        table.insert_before_value(g,where,action)
        t.kind[action] = kind
    end
end

function sequencer.appendaction(t,group,action,where,kind,force)
    local g = t.list[group]
    if g and (force or validaction(action)) then
        table.remove_value(g,action)
        table.insert_after_value(g,where,action)
        t.kind[action] = kind
    end
end

function sequencer.enableaction (t,action) t.askip[action] = false end
function sequencer.disableaction(t,action) t.askip[action] = true  end
function sequencer.enablegroup  (t,group)  t.gskip[group]  = false end
function sequencer.disablegroup (t,group)  t.gskip[group]  = true  end

function sequencer.setkind(t,action,kind)
    t.kind[action] = kind
end

function sequencer.removeaction(t,group,action,force)
    local g = t.list[group]
    if g and (force or validaction(action)) then
        table.remove_value(g,action)
    end
end

function sequencer.compile(t,compiler,n)
    if type(t) == "string" then
        -- already compiled
    elseif compiler then
        t = compiler(t,n)
    else
        t = sequencer.tostring(t)
    end
    return loadstring(t)()
end

local function localize(str)
    return (gsub(str,"%.","_"))
end

local template = [[
%s
return function(...)
%s
end]]

function sequencer.tostring(t)
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local vars, calls, args = { }, { }, nil
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized = localize(action)
                    vars [#vars +1] = format("local %s = %s", localized, action)
                    calls[#calls+1] = format("  %s(...) -- %s %i", localized, group, i)
                end
            end
        end
    end
    return format(template,concat(vars,"\n"),concat(calls,"\n"))
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

function sequencer.nodeprocessor(t,n)
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local vars, calls, args = { }, { }, nil
    if n == 0 then
        args = ""
    elseif n == 1 then
        args = ",one"
    elseif n == 2 then
        args = ",one,two"
    elseif n == 3 then
        args = ",one,two,three"
    elseif n == 4 then
        args = ",one,two,three,four"
    elseif n == 5 then
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
                    vars[#vars+1] = format("local %s = %s",localized,action)
                    if kind[action] == "nohead" then
                        calls[#calls+1] = format("        ok = %s(head%s) done = done or ok -- %s %i",localized,args,group,i)
                    else
                        calls[#calls+1] = format("  head, ok = %s(head%s) done = done or ok -- %s %i",localized,args,group,i)
                    end
                end
            end
        end
    end
    local processor = format(template,concat(vars,"\n"),args,concat(calls,"\n"))
--~     print(processor)
    return processor
end
