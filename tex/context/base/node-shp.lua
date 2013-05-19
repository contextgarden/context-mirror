if not modules then modules = { } end modules ['node-shp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local next, type = next, type
local format = string.format
local concat, sortedpairs = table.concat, table.sortedpairs
local setmetatableindex = table.setmetatableindex

local nodecodes      = nodes.nodecodes
local tasks          = nodes.tasks
local handlers       = nodes.handlers

local hlist_code     = nodecodes.hlist
local vlist_code     = nodecodes.vlist
local disc_code      = nodecodes.disc
local mark_code      = nodecodes.mark
local kern_code      = nodecodes.kern
local glue_code      = nodecodes.glue

local texbox         = tex.box

local free_node      = node.free
local remove_node    = node.remove
local traverse_nodes = node.traverse

local function cleanup(head) -- rough
    local start = head
    while start do
        local id = start.id
        if id == disc_code or (id == glue_code and not start.writable) or (id == kern_code and start.kern == 0) or id == mark_code then
            head, start, tmp = remove_node(head,start)
            free_node(tmp)
        elseif id == hlist_code or id == vlist_code then
            local sl = start.list
            if sl then
                start.list = cleanup(sl)
                start = start.next
            else
                head, start, tmp = remove_node(head,start)
                free_node(tmp)
            end
        else
            start = start.next
        end
    end
    return head
end

directives.register("backend.cleanup", function()
    tasks.enableaction("shipouts","nodes.handlers.cleanuppage")
end)

function handlers.cleanuppage(head)
    -- about 10% of the nodes make no sense for the backend
    return cleanup(head), true
end

local actions = tasks.actions("shipouts")  -- no extra arguments

function handlers.finalize(head) -- problem, attr loaded before node, todo ...
    return actions(head)
end

-- handlers.finalize = actions

-- interface

function commands.finalizebox(n)
    actions(texbox[n])
end

-- just in case we want to optimize lookups:

local frequencies = { }

nodes.tracers.frequencies = frequencies

local data = { }
local done = false

setmetatableindex(data,function(t,k)
    local v = { }
    setmetatableindex(v,function(t,k)
        local v = { }
        t[k] = v
        setmetatableindex(v,function(t,k)
            t[k] = 0
            return 0
        end)
        return v
    end)
    t[k] = v
    return v
end)

local function count(head,data,subcategory)
    -- no components, pre, post, replace .. can maybe an option .. but
    -- we use this for optimization so it makes sense to look the the
    -- main node only
    for n in traverse_nodes(head) do
        local id = n.id
        local dn = data[nodecodes[n.id]]
        dn[subcategory] = dn[subcategory] + 1
        if id == hlist_code or id == vlist_code then
            count(n.list,data,subcategory)
        end
    end
end

local function register(category,subcategory)
    return function(head)
        done = true
        count(head,data[category],subcategory)
        return head, false
    end
end

frequencies.register = register
frequencies.filename = nil

trackers.register("nodes.frequencies",function(v)
    if type(v) == "string" then
        frequencies.filename = v
    end
    handlers.frequencies_shipouts_before   = register("shipouts", "begin")
    handlers.frequencies_shipouts_after    = register("shipouts", "end")
    handlers.frequencies_processors_before = register("processors", "begin")
    handlers.frequencies_processors_after  = register("processors", "end")
    tasks.prependaction("shipouts",   "before", "nodes.handlers.frequencies_shipouts_before")
    tasks.appendaction ("shipouts",   "after",  "nodes.handlers.frequencies_shipouts_after")
    tasks.prependaction("processors", "before", "nodes.handlers.frequencies_processors_before")
    tasks.appendaction ("processors", "after",  "nodes.handlers.frequencies_processors_after")
end)

statistics.register("node frequencies", function()
    if done then
        local filename = frequencies.filename or (tex.jobname .. "-frequencies.lua")
        io.savedata(filename,table.serialize(data,true))
        return format("saved in %q",filename)
    end
end)
