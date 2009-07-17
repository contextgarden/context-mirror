if not modules then modules = { } end modules ['node-shp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local hlist = node.id('hlist')
local vlist = node.id('vlist')
local disc  = node.id('disc')
local mark  = node.id('mark')

local free_node = node.free

local function cleanup_page(head) -- rough
    local prev, start = nil, head
    while start do
        local id, nx = start.id, start.next
        if id == disc or id == mark then
            if prev then
                prev.next = nx
            end
            if start == head then
                head = nx
            end
            local tmp = start
            start = nx
            free_node(tmp)
        elseif id == hlist or id == vlist then
            local sl = start.list
            if sl then
                start.list = cleanup_page(sl)
                prev, start = start, nx
            else
                if prev then
                    prev.next = nx
                end
                if start == head then
                    head = nx
                end
                local tmp = start
                start = nx
                free_node(tmp)
            end
        else
            prev, start = start, nx
        end
    end
    return head
end

nodes.cleanup_page_first = false

function nodes.cleanup_page(head)
    if nodes.cleanup_page_first then
        head = cleanup_page(head)
    end
    return head, false
end

local actions = tasks.actions("shipouts",0)  -- no extra arguments

function nodes.process_page(head) -- problem, attr loaded before node, todo ...
    return actions(head)
end
