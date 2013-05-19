if not modules then modules = { } end modules ['node-mig'] = {
    version   = 1.001,
    comment   = "companion to node-mig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local attributes, nodes, node = attributes, nodes, node

local remove_nodes  = nodes.remove

local nodecodes     = nodes.nodecodes
local tasks         = nodes.tasks

local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local insert_code   = nodecodes.ins
local mark_code     = nodecodes.mark

local a_migrated    = attributes.private("migrated")

local trace_migrations = false trackers.register("nodes.migrations", function(v) trace_migrations = v end)

local report_nodes = logs.reporter("nodes","migrations")

local migrate_inserts, migrate_marks, inserts_too

local t_inserts, t_marks, t_sweeps = 0, 0, 0

local function locate(head,first,last,ni,nm)
    local current = head
    while current do
        local id = current.id
        if id == vlist_code or id == hlist_code then
            current.list, first, last, ni, nm = locate(current.list,first,last,ni,nm)
            current = current.next
        elseif migrate_inserts and id == insert_code then
            local insert
            head, current, insert = remove_nodes(head,current)
            insert.next = nil
            if first then
                insert.prev, last.next = last, insert
            else
                insert.prev, first = nil, insert
            end
            last, ni = insert, ni + 1
        elseif migrate_marks and id == mark_code then
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

function nodes.handlers.migrate(head,where)
    local done = false
    if head then
        if trace_migrations then
            report_nodes("migration sweep %a",where)
        end
        local current = head
        while current do
            local id = current.id
            -- inserts_too is a temp hack, we should only do them when it concerns
            -- newly placed (flushed) inserts
            if id == vlist_code or id == hlist_code or (inserts_too and id == insert_code) and not current[a_migrated] then
                current[a_migrated] = 1
                t_sweeps = t_sweeps + 1
                local h = current.list
                local first, last, ni, nm
                while h do
                    local id = h.id
                    if id == vlist_code or id == hlist_code then
                        h, first, last, ni, nm = locate(h,first,last,0,0)
                    end
                    h = h.next
                end
                if first then
                    t_inserts, t_marks = t_inserts + ni, t_marks + nm
                    if trace_migrations and (ni > 0 or nm > 0) then
                        report_nodes("sweep %a, container %a, %s inserts and %s marks migrated outwards during %a",
                            t_sweeps,nodecodes[id],ni,nm,where)
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

-- for the moment this way, this will disappear

experiments.register("marks.migrate", function(v)
    if v then
        tasks.enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    migrate_marks = v
end)

experiments.register("inserts.migrate", function(v)
    if v then
        tasks.enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    migrate_inserts = v
end)

experiments.register("inserts.migrate.nested", function(v)
    if v then
        tasks.enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    inserts_too = v
end)

statistics.register("node migrations", function()
    if trace_migrations and t_sweeps > 0 then
        return format("%s sweeps, %s inserts moved, %s marks moved",t_sweeps,t_inserts,t_marks)
    end
end)
