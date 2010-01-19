if not modules then modules = { } end modules ['node-ins'] = {
    version   = 1.001,
    comment   = "companion to node-ins.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local hlist  = node.id('hlist')
local vlist  = node.id('vlist')
local insert = node.id('ins')

local has_attribute = node.has_attribute
local set_attribute = node.set_attribute
local remove_nodes  = nodes.remove

local insert_moved = attributes.private("insert_moved")

local trace_inserts = false  trackers.register("inserts.moves", function(v) trace_inserts = v end)

local function locate(head,cache)
    local current = head
    while current do
        local id = current.id
        if id == vlist or id == hlist then
            current.list = locate(current.list,cache)
            current= current.next
        elseif id == insert then
            local insert
            head, current, insert = remove_nodes(head,current)
            cache[#cache+1] = insert
            insert.prev = nil
            insert.next = nil
        else
            current= current.next
        end
    end
    return head
end

function nodes.move_inserts_outwards(head,where)
    local done = false
    if head then
        local current = head
        while current do
            local id = current.id
            if id == vlist or id == hlist and not has_attribute(current,insert_moved) then
                set_attribute(current,insert_moved,1)
                local head = current
                local h, p = head.list, nil
                local cache = { }
                while h do
                    local id = h.id
                    if id == vlist or id == hlist then
                        h = locate(h,cache)
                    end
                    h = h.next
                end
                local n = #cache
                if n > 0 then
                    local first = cache[1]
                    local last = first
                    for i=2,n do
                        local c = cache[i]
                        last.next, c.prev = c, last
                        last = c
                    end
                    -- inserts after head
                    local n = head.next
                    if n then
                        head.next = first
                        first.prev = head
                        last.next = n
                        n.prev = last
                    else
                        head.next = first
                        first.prev = head
                    end
                    if trace_inserts then
                        logs.report("inserts","%s nested inserts moved",n)
                    end
                    done = true
                end
                current = head
            end
            current = current.next
        end
        return head, true
    end
end

tasks.prependaction("pagebuilders", "normalizers", "nodes.move_inserts_outwards")

tasks.disableaction("pagebuilders", "nodes.move_inserts_outwards")

experiments.register("inserts.moves", function(v)
    if v then
        tasks.enableaction("pagebuilders", "nodes.move_inserts_outwards")
    else
        tasks.disableaction("pagebuilders", "nodes.move_inserts_outwards")
    end
end)

