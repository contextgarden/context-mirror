if not modules then modules = { } end modules ['node-shp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local nodecodes   = nodes.nodecodes
local tasks       = nodes.tasks

local hlist_code  = nodecodes.hlist
local vlist_code  = nodecodes.vlist
local disc_code   = nodecodes.disc
local mark_code   = nodecodes.mark
local kern_code   = nodecodes.kern
local glue_code   = nodecodes.glue

local texbox      = tex.box

local free_node   = node.free
local remove_node = node.remove

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

function nodes.handlers.cleanuppage(head)
    -- about 10% of the nodes make no sense for the backend
    return cleanup(head), true
end

local actions = tasks.actions("shipouts")  -- no extra arguments

function nodes.handlers.finalize(head) -- problem, attr loaded before node, todo ...
    return actions(head)
end

--~ nodes.handlers.finalize = actions

-- interface

function commands.finalizebox(n)
    actions(texbox[n])
end
