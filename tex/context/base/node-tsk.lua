if not modules then modules = { } end modules ['node-tsk'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_tasks = false  trackers.register("tasks.creation", function(v) trace_tasks = v end)

tasks      = tasks       or { }
tasks.data = tasks.data  or { }

function tasks.new(name,list)
    local tasklist = sequencer.reset()
    tasks.data[name] = { list = tasklist, runner = false }
    for l=1,#list do
        sequencer.appendgroup(tasklist,list[l])
    end
end

function tasks.restart(name)
    local data = tasks.data[name]
    if data then
        data.runner = false
    end
end

function tasks.enableaction(name,action)
    local data = tasks.data[name]
    if data then
        sequencer.enableaction(data.list,action)
        data.runner = false
    end
end
function tasks.disableaction(name,action)
    local data = tasks.data[name]
    if data then
        sequencer.disableaction(data.list,action)
        data.runner = false
    end
end
function tasks.enablegroup(name,group)
    local data = tasks.data[name]
    if data then
        sequencer.enablegroup(data.list,group)
        data.runner = false
    end
end
function tasks.disablegroup(name,group)
    local data = tasks.data[name]
    if data then
        sequencer.disablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.appendaction(name,group,action,where,kind)
    local data = tasks.data[name]
    if data then
        sequencer.appendaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.prependaction(name,group,action,where,kind)
    local data = tasks.data[name]
    if data then
        sequencer.prependaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.removeaction(name,group,action)
    local data = tasks.data[name]
    if data then
        sequencer.removeaction(data.list,group,action)
        data.runner = false
    end
end

function tasks.showactions(name,group,action,where,kind)
    local data = tasks.data[name]
    if data then
        logs.report("nodes","task %s, list:\n%s",name,sequencer.nodeprocessor(data.list))
    end
end

-- Optimizing for the number of arguments makes sense, but getting rid of
-- the nested call (no problem but then we also need to register the
-- callback with this mechanism so that it gets updated) does not save
-- much time (24K calls on mk.tex).

local created, total = 0, 0

statistics.register("node list callback tasks", function()
    if total > 0 then
        return string.format("%s unique task lists, %s instances (re)created, %s calls",table.count(tasks.data),created,total)
    else
        return nil
    end
end)

local compile, nodeprocessor = sequencer.compile, sequencer.nodeprocessor

function tasks.actions(name,n) -- we optimize for the number or arguments (no ...)
    local data = tasks.data[name]
    if data then
        if n == 0 then
            return function(head)
                local runner = data.runner
                total = total + 1 -- will go away
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s'",name)
                    end
                    runner = compile(data.list,nodeprocessor,0)
                    data.runner = runner
                end
                return runner(head)
            end
        elseif n == 1 then
            return function(head,one)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with 1 extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,1)
                    data.runner = runner
                end
                return runner(head,one)
            end
        elseif n == 2 then
            return function(head,one,two)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with 2 extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,2)
                    data.runner = runner
                end
                return runner(head,one,two)
            end
        elseif n == 3 then
            return function(head,one,two,three)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with 3 extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,3)
                    data.runner = runner
                end
                return runner(head,one,two,three)
            end
        elseif n == 4 then
            return function(head,one,two,three,four)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with 4 extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,4)
                    data.runner = runner
                end
                return runner(head,one,two,three,four)
            end
        elseif n == 5 then
            return function(head,one,two,three,four,five)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with 5 extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,5)
                    data.runner = runner
                end
                return runner(head,one,two,three,four,five)
            end
        else
            return function(head,...)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s' with n extra arguments",name)
                    end
                    runner = compile(data.list,nodeprocessor,"n")
                    data.runner = runner
                end
                return runner(head,...)
            end
        end
    else
        return nil
    end
end

function tasks.table(name) --maybe move this to task-deb.lua
    local tsk = tasks.data[name]
    local lst = tsk and tsk.list
    local HL, NC, NR, bold, type = context.HL, context.NC, context.NR, context.bold, context.type
    if lst then
        local list, order = lst.list, lst.order
        if list and order then
            context.starttabulate { "|l|l|" }
            NC() bold("category") NC() bold("function") NC() NR()
            for i=1,#order do
                HL()
                local o = order[i]
                local l = list[o]
                if #l == 0 then
                    NC() type(o) NC() NC() NR()
                else
                    for k, v in table.sortedpairs(l) do
                        NC() type(o) NC() type(v) NC() NR()
                    end
                end
            end
            context.stoptabulate()
        end
    end
end
tasks.new (
    "processors",
    {
        "before",      -- for users
        "normalizers",
        "characters",
        "words",
        "fonts",
        "lists",
        "after",       -- for users
    }
)

tasks.new (
    "finalizers",
    {
        "before",      -- for users
        "normalizers",
--      "characters",
--      "finishers",
        "fonts",
        "lists",
        "after",       -- for users
    }
)

tasks.new (
    "shipouts",
    {
        "before",      -- for users
        "normalizers",
        "finishers",
        "after",       -- for users
    }
)

tasks.new (
    "mvlbuilders",
    {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    }
)

tasks.new (
    "vboxbuilders",
    {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    }
)

--~ tasks.new (
--~     "parbuilders",
--~     {
--~         "before",      -- for users
--~         "lists",
--~         "after",       -- for users
--~     }
--~ )

--~ tasks.new (
--~     "pagebuilders",
--~     {
--~         "before",      -- for users
--~         "lists",
--~         "after",       -- for users
--~     }
--~ )
