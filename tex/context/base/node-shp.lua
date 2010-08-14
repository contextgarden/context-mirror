if not modules then modules = { } end modules ['node-shp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local free_node, remove_node = node.free, node.remove

local nodecodes = nodes.nodecodes

local hlist = nodecodes.hlist
local vlist = nodecodes.vlist
local disc  = nodecodes.disc
local mark  = nodecodes.mark
local kern  = nodecodes.kern
local glue  = nodecodes.glue

local function cleanup_page(head) -- rough
    local start = head
    while start do
        local id = start.id
        if id == disc or (id == glue and not start.writable) or (id == kern and start.kern == 0) or id == mark then
            head, start, tmp = remove_node(head,start)
            free_node(tmp)
        elseif id == hlist or id == vlist then
            local sl = start.list
            if sl then
                start.list = cleanup_page(sl)
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

nodes.cleanup_page_first = false

function nodes.cleanup_page(head)
    -- about 10% of the nodes make no sense for the backend
    if nodes.cleanup_page_first then
        head = cleanup_page(head)
    end
    return head, false
end

local actions = tasks.actions("shipouts",0)  -- no extra arguments

function nodes.process_page(head) -- problem, attr loaded before node, todo ...
    return actions(head)
end

--~ nodes.process_page = actions
