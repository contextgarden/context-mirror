if not modules then modules = { } end modules ['page-str'] = {
    version   = 1.001,
    comment   = "companion to page-str.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- work in progresss .. unfinished

local concat = table.concat

local find_tail, write_node, free_node, copy_nodelist = node.slide, node.write, node.free, node.copy_list
local vpack_nodelist, hpack_nodelist = node.vpack, node.hpack
local texdimen, texbox = tex.dimen, tex.box

local new_kern  = nodes.kern
local new_glyph = nodes.glyph

local trace_collecting = false  trackers.register("streams.collecting", function(v) trace_collecting = v end)
local trace_flushing   = false  trackers.register("streams.flushing",   function(v) trace_flushing   = v end)

local report_streams = logs.new("streams")

streams = streams or { }

local data, name, stack = { }, nil, { }

function streams.enable(newname)
    if newname == "default" then
        name = nil
    else
        name = newname
    end
end

function streams.disable()
    name = stack[#stack]
end

function streams.start(newname)
    table.insert(stack,name)
    name = newname
end

function streams.stop(newname)
    name = table.remove(stack)
end

function streams.collect(head,where)
    if name and head and name ~= "default" then
        local tail = node.slide(head)
        local dana = data[name]
        if not dana then
            dana = { }
            data[name] = dana
        end
        local last = dana[#dana]
        if last then
            local tail = find_tail(last)
            tail.next, head.prev = head, tail
        elseif last == false then
            dana[#dana] = head
        else
            dana[1] = head
        end
        if trace_collecting then
            report_streams("appending snippet '%s' to slot %s",name,#dana)
        end
        return nil, true
    else
        return head, false
    end
end

function streams.push(thename)
    if not thename or thename == "" then
        thename = name
    end
    if thename and thename ~= "" then
        local dana = data[thename]
        if dana then
            dana[#dana+1] = false
            if trace_collecting then
                report_streams("pushing snippet '%s'",thename)
            end
        end
    end
end

function streams.flush(name,copy) -- problem: we need to migrate afterwards
    local dana = data[name]
    if dana then
        local dn = #dana
        if dn == 0 then
            -- nothing to flush
        elseif copy then
            if trace_flushing then
                report_streams("flushing copies of %s slots of '%s'",dn,name)
            end
            for i=1,dn do
                local di = dana[i]
                if di then
                    write_node(copy_nodelist(di.list)) -- list, will be option
                end
            end
            if copy then
                data[name] = nil
            end
        else
            if trace_flushing then
                report_streams("flushing %s slots of '%s'",dn,name)
            end
            for i=1,dn do
                local di = dana[i]
                if di then
                    write_node(di.list) -- list, will be option
                    di.list = nil
                    free_node(di)
                end
            end
        end
    end
end

function streams.synchronize(list) -- this is an experiment !
    -- we don't optimize this as we want to trace in detail
    list = aux.settings_to_array(list)
    local max = 0
    if trace_flushing then
        report_streams("synchronizing list: %s",concat(list," "))
    end
    for i=1,#list do
        local dana = data[list[i]]
        if dana then
            local n = #dana
            if n > max then
                max = n
            end
        end
    end
    if trace_flushing then
        report_streams("maximum number of slots: %s",max)
    end
    for m=1,max do
        local height, depth = 0, 0
        for i=1,#list do
            local name = list[i]
            local dana = data[name]
            local slot = dana[m]
            if slot then
                local vbox = vpack_nodelist(slot)
                local ht, dp = vbox.height, vbox.depth
                if ht > height then
                    height = ht
                end
                if dp > depth then
                    depth = dp
                end
                dana[m] = vbox
                if trace_flushing then
                    report_streams("slot %s of '%s' is packed to height %s and depth %s",m,name,ht,dp)
                end
            end
        end
        if trace_flushing then
            report_streams("slot %s has max height %s and max depth %s",m,height,depth)
        end
        local strutht, strutdp = texdimen.globalbodyfontstrutheight, texdimen.globalbodyfontstrutdepth
        local struthtdp = strutht + strutdp
        for i=1,#list do
            local name = list[i]
            local dana = data[name]
            local vbox = dana[m]
            if vbox then
                local delta_height = height - vbox.height
                local delta_depth  = depth  - vbox.depth
                if delta_height > 0 or delta_depth > 0 then
                    if false then
                        -- actually we need to add glue and repack
                        vbox.height, vbox.depth = height, depth
                        if trace_flushing then
                            report_streams("slot %s of '%s' with delta (%s,%s) is compensated",m,i,delta_height,delta_depth)
                        end
                    else
                        -- this is not yet ok as we also need to keep an eye on vertical spacing
                        -- so we might need to do some splitting or whatever
                        local tail = vbox.list and find_tail(vbox.list)
                        local n, delta = 0, delta_height -- for tracing
                        while delta > 0 do
                            -- we need to add some interline penalties
                            local line = copy_nodelist(tex.box.strutbox)
                            line.height, line.depth = strutht, strutdp
                            if tail then
                                tail.next, line.prev = line, tail
                            end
                            tail = line
                            n, delta = n +1, delta - struthtdp
                        end
                        dana[m] = vpack_nodelist(vbox.list)
                        vbox.list = nil
                        free_node(vbox)
                        if trace_flushing then
                            report_streams("slot %s:%s with delta (%s,%s) is compensated by %s lines",m,i,delta_height,delta_depth,n)
                        end
                    end
                end
            else
                -- make dummy
            end
        end
    end
end

tasks.appendaction("mvlbuilders", "normalizers", "streams.collect")

tasks.disableaction("mvlbuilders", "streams.collect")

function streams.initialize()
    tasks.enableaction ("mvlbuilders", "streams.collect")
end

-- todo: remove empty last { }'s
