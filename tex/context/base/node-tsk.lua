if not modules then modules = { } end modules ['node-tsk'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
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

function tasks.actions(name)
    local data = tasks.data[name]
    if data then
        return function(head,tail,...)
            local runner = data.runner
            if not runner then
                if trace_tasks then
                    logs.report("nodes","creating task runner '%s'",name)
                end
                runner = sequencer.compile(data.list,sequencer.nodeprocessor)
                data.runner = runner
            end
            return runner(head,tail,...)
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
