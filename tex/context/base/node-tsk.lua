if not modules then modules = { } end modules ['node-tsk'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_tasks = false  trackers.register("tasks", function(v) trace_tasks = v end)

tasks      = tasks      or { }
tasks.data = tasks.data or { }

function tasks.new(name,list)
    local tasklist = sequencer.reset()
    tasks.data[name] = { list = tasklist, runner = false }
    for l=1,#list do
        sequencer.appendgroup(tasklist,list[l])
    end
end

function tasks.restart(name,group)
    local data = tasks.data[name]
    if data then
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
        return string.format("%s unique tasks, %s created, %s calls",table.count(tasks.data),created,total)
    else
        return nil
    end
end)

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
                    runner = sequencer.compile(data.list,sequencer.nodeprocessor,0)
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
                        logs.report("nodes","creating task runner '%s'",name)
                    end
                    runner = sequencer.compile(data.list,sequencer.nodeprocessor,1)
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
                        logs.report("nodes","creating task runner '%s'",name)
                    end
                    runner = sequencer.compile(data.list,sequencer.nodeprocessor,2)
                    data.runner = runner
                end
                return runner(head,one,two)
            end
        else
            return function(head,...)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        logs.report("nodes","creating task runner '%s'",name)
                    end
                    runner = sequencer.compile(data.list,sequencer.nodeprocessor,3)
                    data.runner = runner
                end
                return runner(head,...)
            end
        end
    else
        return nil
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
