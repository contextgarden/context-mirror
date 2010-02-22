if not modules then modules = { } end modules ['node-mig'] = {
    version   = 1.001,
    comment   = "companion to node-mig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local hlist  = node.id('hlist')
local vlist  = node.id('vlist')
local insert = node.id('ins')
local mark   = node.id('mark')

local has_attribute = node.has_attribute
local set_attribute = node.set_attribute
local remove_nodes  = nodes.remove

local migrated = attributes.private("migrated")

local trace_migrations = false

trackers.register("nodes.migrations", function(v) trace_migrations = v end)

local migrate_inserts, migrate_marks

local t_inserts, t_marks, t_sweeps = 0, 0, 0

local function locate(head,first,last,ni,nm)
    local current = head
    while current do
        local id = current.id
        if id == vlist or id == hlist then
            current.list, first, last, ni, nm = locate(current.list,first,last,ni,nm)
            current= current.next
        elseif migrate_inserts and id == insert then
            local insert
            head, current, insert = remove_nodes(head,current)
            insert.next = nil
            if first then
                insert.prev, last.next = last, insert
            else
                insert.prev, first = nil, insert
            end
            last, ni = insert, ni + 1
        elseif migrate_marks and id == mark then
            local mark
            head, current, mark = remove_nodes(head,current)
            mark.next = nil
            if first then
                mark.prev, last.next = last, mark
            else
                mark.prev, first = nil, mark
            end
            last, nm = mark, nm + 1
        else
            current= current.next
        end
    end
    return head, first, last, ni, nm
end

function nodes.migrate_outwards(head,where)
    local done = false
    if head then
        local current = head
        while current do
            local id = current.id
            if id == vlist or id == hlist and not has_attribute(current,migrated) then
                set_attribute(current,migrated,1)
                t_sweeps = t_sweeps + 1
                local h = current.list
                local first, last, ni, nm
                while h do
                    local id = h.id
                    if id == vlist or id == hlist then
                        h, first, last, ni, nm = locate(h,first,last,0,0)
                    end
                    h = h.next
                end
                if first then
                    t_inserts, t_marks = t_inserts + ni, t_marks + nm
                    if trace_migrations and (ni > 0 or nm > 0) then
                        logs.report("nodes","sweep %s, %s inserts and %s marks migrated outwards",t_sweeps,ni,nm)
                    end
                    -- inserts after head
                    local n = current.next
                    if n then
                        last.next, n.prev = n, last
                    end
                    current.next, first.prev = first, current
                    done, current = true, last
                end
            end
            current = current.next
        end
        return head, done
    end
end

experiments.register("marks.migrate", function(v)
    if v then
        tasks.enableaction("mvlbuilders", "nodes.migrate_outwards")
    end
    migrate_marks = v
end)

experiments.register("inserts.migrate", function(v)
    if v then
        tasks.enableaction("mvlbuilders", "nodes.migrate_outwards")
    end
    migrate_inserts = v
end)

statistics.register("node migrations", function()
    if trace_migrations and t_sweeps > 0 then
        return format("%s sweeps, %s inserts moved, %s marks moved",t_sweeps,t_inserts,t_marks)
    end
end)
