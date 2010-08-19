if not modules then modules = { } end modules ['node-tsk'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this might move to task-*

local trace_tasks = false  trackers.register("tasks.creation", function(v) trace_tasks = v end)

local report_tasks = logs.new("tasks")

local nodes      = nodes

nodes.tasks      = nodes.tasks or { }
local tasks      = nodes.tasks
tasks.data       = tasks.data  or { }
local tasksdata  = tasks.data

local sequencers = utilities.sequencers

function tasks.new(name,list)
    local tasklist = sequencers.reset()
    tasksdata[name] = { list = tasklist, runner = false }
    for l=1,#list do
        sequencers.appendgroup(tasklist,list[l])
    end
end

function tasks.restart(name)
    local data = tasksdata[name]
    if data then
        data.runner = false
    end
end

function tasks.enableaction(name,action)
    local data = tasksdata[name]
    if data then
        sequencers.enableaction(data.list,action)
        data.runner = false
    end
end

function tasks.disableaction(name,action)
    local data = tasksdata[name]
    if data then
        sequencers.disableaction(data.list,action)
        data.runner = false
    end
end

function tasks.enablegroup(name,group)
    local data = tasksdata[name]
    if data then
        sequencers.enablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.disablegroup(name,group)
    local data = tasksdata[name]
    if data then
        sequencers.disablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.appendaction(name,group,action,where,kind)
    local data = tasksdata[name]
    if data then
        sequencers.appendaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.prependaction(name,group,action,where,kind)
    local data = tasksdata[name]
    if data then
        sequencers.prependaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.removeaction(name,group,action)
    local data = tasksdata[name]
    if data then
        sequencers.removeaction(data.list,group,action)
        data.runner = false
    end
end

function tasks.showactions(name,group,action,where,kind)
    local data = tasksdata[name]
    if data then
        report_tasks("task %s, list:\n%s",name,sequencers.nodeprocessor(data.list))
    end
end

-- Optimizing for the number of arguments makes sense, but getting rid of
-- the nested call (no problem but then we also need to register the
-- callback with this mechanism so that it gets updated) does not save
-- much time (24K calls on mk.tex).

local created, total = 0, 0

statistics.register("node list callback tasks", function()
    if total > 0 then
        return string.format("%s unique task lists, %s instances (re)created, %s calls",table.count(tasksdata),created,total)
    else
        return nil
    end
end)

local compile, nodeprocessor = sequencers.compile, sequencers.nodeprocessor

function tasks.actions(name,n) -- we optimize for the number or arguments (no ...)
    local data = tasksdata[name]
    if data then
        if n == 0 then
            return function(head)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner '%s'",name)
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
                        report_tasks("creating runner '%s' with 1 extra arguments",name)
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
                        report_tasks("creating runner '%s' with 2 extra arguments",name)
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
                        report_tasks("creating runner '%s' with 3 extra arguments",name)
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
                        report_tasks("creating runner '%s' with 4 extra arguments",name)
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
                        report_tasks("creating runner '%s' with 5 extra arguments",name)
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
                        report_tasks("creating runner '%s' with n extra arguments",name)
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
    local tsk = tasksdata[name]
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
                    NC() type(o) NC() context("unset") NC() NR()
                else
                    local done = false
                    for k, v in table.sortedhash(l) do
                        NC() if not done then type(o) done = true end NC() type(v) NC() NR()
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
