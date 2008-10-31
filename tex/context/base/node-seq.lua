if not modules then modules = { } end modules ['node-seq'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we assume namespace usage, i.e. unique names for functions

local format, concat = string.format, table.concat

sequencer = sequencer or { }

function sequencer.reset()
    return {
        list = { },
        order = { },
        kind = { },
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

function sequencer.prependaction(t,group,action,where,kind)
    local g = t.list[group]
    if g then
        table.remove_value(g,action)
        table.insert_before_value(g,where,action)
        t.kind[action] = kind
    end
end

function sequencer.appendaction(t,group,action,where,kind)
    local g = t.list[group]
    if g then
        table.remove_value(g,action)
        table.insert_after_value(g,where,action)
        t.kind[action] = kind
    end
end

function sequencer.setkind(t,action,kind)
    t.kind[action] = kind
end

function sequencer.removeaction(t,group,action)
    local g = t.list[group]
    if g then
        table.remove_value(g,action)
    end
end

function sequencer.compile(t,compiler)
    if type(t) == "string" then
        -- already compiled
    elseif compiler then
        t = compiler(t)
    else
        t = sequencer.tostring(t)
    end
    return loadstring(t)()
end

local function localize(str)
    return str:gsub("%.","_")
end

local template = [[
%s
return function(...)
%s
end]]

function sequencer.tostring(t)
    local list, order, kind, vars, calls = t.list, t.order, t.kind, { }, { }
    for i=1,#order do
        local group = order[i]
        local actions = list[group]
        for i=1,#actions do
            local action = actions[i]
            local localized = localize(action)
            vars [#vars +1] = format("local %s = %s", localized, action)
            calls[#calls+1] = format("  %s(...) -- %s %i", localized, group, i)
        end
    end
    return template:format(concat(vars,"\n"),concat(calls,"\n"))
end

local template = [[
%s
return function(head,tail)
  local ok, done = false, false
%s
  return head, tail, done
end]]

function sequencer.nodeprocessor(t)
    local list, order, kind, vars, calls = t.list, t.order, t.kind, { }, { }
    for i=1,#order do
        local group = order[i]
        local actions = list[group]
        for i=1,#actions do
            local action = actions[i]
            local localized = localize(action)
            vars[#vars+1] = format("local %s = %s",localized,action)
            if kind[action] == "nohead" then
                calls[#calls+1] = format("              ok = %s(head,tail) done = done or ok -- %s %i",localized,group,i)
            elseif kind[action] == "notail" then
                calls[#calls+1] = format("  head,       ok = %s(head,tail) done = done or ok -- %s %i",localized,group,i)
            else
                calls[#calls+1] = format("  head, tail, ok = %s(head,tail) done = done or ok -- %s %i",localized,group,i)
            end
        end
    end
    return template:format(concat(vars,"\n"),concat(calls,"\n"))
end

--~ hans = {}
--~ taco = {}

--~ function hans.a(head,tail) print("a",head,tail) return head,tail,true end
--~ function hans.b(head,tail) print("b",head,tail) return head,tail,true end
--~ function hans.c(head,tail) print("c",head,tail) return head,tail,true end
--~ function hans.x(head,tail) print("x",head,tail) return head,tail,true end
--~ function taco.i(head,tail) print("i",head,tail) return head,tail,true end
--~ function taco.j(head,tail) print("j",head,tail) return head,tail,true end

--~ t = sequencer.reset()

--~ sequencer.appendgroup(t,"hans")
--~ sequencer.appendgroup(t,"taco")
--~ sequencer.prependaction(t,"hans","hans.a")
--~ sequencer.appendaction (t,"hans","hans.b")
--~ sequencer.appendaction (t,"hans","hans.x")
--~ sequencer.prependaction(t,"hans","hans.c","hans.b")
--~ sequencer.prependaction(t,"taco","taco.i")
--~ sequencer.prependaction(t,"taco","taco.j")
--~ sequencer.removeaction(t,"hans","hans.x")

--~ sequencer.setkind(t,"hans.b","notail")
--~ sequencer.setkind(t,"taco.j","nohead")

--~ print(sequencer.tostring(t))

--~ s = sequencer.compile(t,sequencer.nodeprocessor)

--~ print(sequencer.nodeprocessor(t))
--~ print(s("head","tail"))
