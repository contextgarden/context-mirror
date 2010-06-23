if not modules then modules = { } end modules ['node-fin'] = {
    version   = 1.001,
    comment   = "companion to node-fin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed

local next, type, format = next, type, string.format
local texsprint = tex.sprint

local ctxcatcodes = tex.ctxcatcodes

local glyph   = node.id('glyph')
local glue    = node.id('glue')
local rule    = node.id('rule')
local whatsit = node.id('whatsit')
local hlist   = node.id('hlist')
local vlist   = node.id('vlist')

local has_attribute = node.has_attribute
local copy_node     = node.copy

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

states   = states or { }
shipouts = shipouts or { }

local numbers    = attributes.numbers
local trigger    = attributes.private('trigger')
local triggering = false

-- these two will be like trackers

function states.enabletriggering()
    triggering = true
end
function states.disabletriggering()
    triggering = false
end

-- the following code is no longer needed due to the new backend
-- but we keep it around for a while as an example
--
-- states.collected = states.collected or { }
--
-- storage.register("states/collected", states.collected, "states.collected")
--
-- local collected = states.collected
--
-- function states.collect(str)
--     collected[#collected+1] = str
-- end
--
-- function states.flush()
--     if #collected > 0 then
--         for i=1,#collected do
--             texsprint(ctxcatcodes,collected[i]) -- we're in context mode anyway
--         end
--         collected = { }
--         states.collected = collected
--     end
-- end
--
-- function states.check()
--     texio.write_nl(concat(collected,"\n"))
-- end

-- we used to do the main processor loop here and call processor for each node
-- but eventually this was too much a slow down (1 sec on 23 for 120 pages mk)
-- so that we moved looping to the processor itself; this may lead to a bit of
-- duplicate code once that we have more state handlers

local function process_attribute(head,plugin) -- head,attribute,enabled,initializer,resolver,processor,finalizer
    local namespace = plugin.namespace
    if namespace.enabled ~= false then -- this test will go away
        starttiming(attributes)
        local done, used, ok = false, nil, false
        local attribute = namespace.attribute or numbers[plugin.name] -- todo: plugin.attribute
        local processor = plugin.processor
        if processor then
            local initializer = plugin.initializer
            local resolver    = plugin.resolver
            local inheritance = (resolver and resolver()) or nil -- -0x7FFFFFFF -- we can best use nil and skip !
            if initializer then
                initializer(namespace,attribute,head)
            end
            head, ok = processor(namespace,attribute,head,inheritance)
            if ok then
                local finalizer = plugin.finalizer
                if finalizer then
                    head, ok, used = finalizer(namespace,attribute,head)
                    if used then
                        local flusher = plugin.flusher
                        if flusher then
                            head = flusher(namespace,attribute,head,used)
                        end
                    end
                end
                done = true
            end
        end
        stoptiming(attributes)
        return head, done
    else
        return head, false
    end
end

nodes.process_attribute = process_attribute

function nodes.install_attribute_handler(plugin) -- we need to avoid this nested function
    return function(head)
        return process_attribute(head,plugin)
    end
end

--~ experiment (maybe local to function makes more sense)
--~
--~ plugindata = { }
--~
--~ local template = [[
--~ local plugin = plugindata["%s"]
--~ local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming
--~ local namespace = plugin.namespace
--~ local attribute = namespace.attribute
--~ local processor = plugin.processor
--~ local initializer = plugin.initializer
--~ local resolver = plugin.resolver
--~ local finalizer = plugin.finalizer
--~ local flusher = plugin.flusher
--~ return function (head)
--~     if namespace.enabled then
--~         starttiming(attributes)
--~         local done, used, ok = false, nil, false
--~         if procesxsor then
--~             local inheritance = (resolver and resolver()) or nil -- -0x7FFFFFFF -- we can best use nil and skip !
--~             if initializer then
--~                 initializer(namespace,attribute,head)
--~             end
--~             head, ok = processor(namespace,attribute,head,inheritance)
--~             if ok then
--~                 if finalizer then
--~                     head, ok, used = finalizer(namespace,attribute,head)
--~                     if used and flusher then
--~                         head = flusher(namespace,attribute,head,used)
--~                     end
--~                 end
--~                 done = true
--~             end
--~         end
--~         stoptiming(attributes)
--~         return head, done
--~     else
--~         return head, false
--~     end
--~ end
--~ ]]
--~
--~ function nodes.install_attribute_handler(plugin) -- we need to avoid this nested function
--~     plugindata[plugin.name] = plugin
--~     local str = format(template,plugin.name)
--~     return loadstring(str)()
--~ end

-- the injectors

local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local nsdata, nsnone, nslistwise, nsforced, nsselector, nstrigger
local current, current_selector, done = 0, 0, false -- nb, stack has a local current !

function states.initialize(namespace,attribute,head)
    nsdata, nsnone = namespace.data, namespace.none
    nsforced, nsselector, nslistwise = namespace.forced, namespace.selector, namespace.listwise
    nstrigger = triggering and namespace.triggering and trigger
    current, current_selector, done = 0, 0, false -- todo: done cleanup
end

function states.finalize(namespace,attribute,head) -- is this one ok?
    if current > 0 and nsnone then
        local id = head.id
        if id == hlist or id == vlist then
            local list = head.list
            if list then
                head.list = insert_node_before(list,list,copy_node(nsnone))
            end
        else
            head = insert_node_before(head,head,copy_node(nsnone))
        end
        return head, true, true
    end
    return head, false, false
end

local function process(namespace,attribute,head,inheritance,default) -- one attribute
    local stack, done = head, false
    while stack do
        local id = stack.id
        -- we need to deal with literals too (reset as well as oval)
        -- if id == glyph or (id == whatsit and stack.subtype == 8) or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
        if id == glyph or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
            local c = has_attribute(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        head = insert_node_before(head,stack,copy_node(nsdata[default]))
                        current, done = default, true
                    end
                elseif current ~= c then
                    head = insert_node_before(head,stack,copy_node(nsdata[c]))
                    current, done = c, true
                end
                -- here ? compare selective
                if id == glue then --leader
                    -- same as *list
                    local content = stack.leader
                    if content then
                        local savedcurrent = current
                        local ci = content.id
                        if ci == hlist or ci == vlist then
                            -- else we reset inside a box unneeded, okay, the downside is
                            -- that we trigger color in each repeated box, so there is room
                            -- for improvement here
                            current = 0
                        end
                        local ok = false
                        if nstrigger and has_attribute(stack,nstrigger) then
                            local outer = has_attribute(stack,attribute)
                            if outer ~= inheritance then
                                stack.leader, ok = process(namespace,attribute,content,inheritance,outer)
                            else
                                stack.leader, ok = process(namespace,attribute,content,inheritance,default)
                            end
                        else
                            stack.leader, ok = process(namespace,attribute,content,inheritance,default)
                        end
                        current = savedcurrent
                        done = done or ok
                    end
                end
            elseif default and inheritance then
                if current ~= default then
                    head = insert_node_before(head,stack,copy_node(nsdata[default]))
                    current, done = default, true
                end
            elseif current > 0 then
                head = insert_node_before(head,stack,copy_node(nsnone))
                current, done = 0, true
            end
        elseif id == hlist or id == vlist then
            local content = stack.list
            if content then
                local ok = false
                if nstrigger and has_attribute(stack,nstrigger) then
                    local outer = has_attribute(stack,attribute)
                    if outer ~= inheritance then
                        stack.list, ok = process(namespace,attribute,content,inheritance,outer)
                    else
                        stack.list, ok = process(namespace,attribute,content,inheritance,default)
                    end
                else
                    stack.list, ok = process(namespace,attribute,content,inheritance,default)
                end
                done = done or ok
            end
        end
        stack = stack.next
    end
    return head, done
end

states.process = process

-- we can force a selector, e.g. document wide color spaces, saves a little
-- watch out, we need to check both the selector state (like colorspace) and
-- the main state (like color), otherwise we get into troubles when a selector
-- state changes while the main state stays the same (like two glyphs following
-- each other with the same color but different color spaces e.g. \showcolor)

local function selective(namespace,attribute,head,inheritance,default) -- two attributes
    local stack, done = head, false
    while stack do
        local id = stack.id
        -- we need to deal with literals too (reset as well as oval)
        -- if id == glyph or (id == whatsit and stack.subtype == 8) or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
        if id == glyph or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
            local c = has_attribute(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        local data = nsdata[default]
                        head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                        current, done = default, true
                    end
                else
                    local s = has_attribute(stack,nsselector)
                    if current ~= c or current_selector ~= s then
                        local data = nsdata[c]
                        head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                        current, current_selector, done = c, s, true
                    end
                end
            elseif default and inheritance then
                if current ~= default then
                    local data = nsdata[default]
                    head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                    current, done = default, true
                end
            elseif current > 0 then
                head = insert_node_before(head,stack,copy_node(nsnone))
                current, current_selector, done = 0, 0, true
            end
            if id == glue then -- leader
                -- same as *list
                local content = stack.leader
                if content then
                    local savedcurrent = current
                    local ci = content.id
                    if ci == hlist or ci == vlist then
                        -- else we reset inside a box unneeded, okay, the downside is
                        -- that we trigger color in each repeated box, so there is room
                        -- for improvement here
                        current = 0
                    end
                    local ok = false
                    if nstrigger and has_attribute(stack,nstrigger) then
                        local outer = has_attribute(stack,attribute)
                        if outer ~= inheritance then
                            stack.leader, ok = selective(namespace,attribute,content,inheritance,outer)
                        else
                            stack.leader, ok = selective(namespace,attribute,content,inheritance,default)
                        end
                    else
                        stack.leader, ok = selective(namespace,attribute,content,inheritance,default)
                    end
                    current = savedcurrent
                    done = done or ok
                end
            end
        elseif id == hlist or id == vlist then
            local content = stack.list
            if content then
                local ok = false
                if nstrigger and has_attribute(stack,nstrigger) then
                    local outer = has_attribute(stack,attribute)
                    if outer ~= inheritance then
                        stack.list, ok = selective(namespace,attribute,content,inheritance,outer)
                    else
                        stack.list, ok = selective(namespace,attribute,content,inheritance,default)
                    end
                else
                    stack.list, ok = selective(namespace,attribute,content,inheritance,default)
                end
                done = done or ok
            end
        end
        stack = stack.next
    end
    return head, done
end

states.selective = selective

-- Ideally the next one should be merged with the previous but keeping it separate is
-- safer. We deal with two situations: efficient boxwise (layoutareas) and mixed layers
-- (as used in the stepper). In the stepper we cannot use the box branch as it involves
-- paragraph lines and then getsmixed up. A messy business (esp since we want to be
-- efficient).

local function stacked(namespace,attribute,head,default) -- no triggering, no inheritance, but list-wise
    local stack, done = head, false
    local current, depth = default or 0, 0
    while stack do
        local id = stack.id
        if id == glyph or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
            local c = has_attribute(stack,attribute)
            if c then
                if current ~= c then
                    head = insert_node_before(head,stack,copy_node(nsdata[c]))
                    depth = depth + 1
                    current, done = c, true
                end
                if id == glue then
                    local content = stack.leader
                    if content then -- unchecked
                        local ok = false
                        stack.leader, ok = stacked(namespace,attribute,content,current)
                        done = done or ok
                    end
                end
            elseif default then
                --
            elseif current > 0 then
                head = insert_node_before(head,stack,copy_node(nsnone))
                depth = depth - 1
                current, done = 0, true
            end
        elseif id == hlist or id == vlist then
            local content = stack.list
            if content then
             -- the problem is that broken lines gets the attribute which can be a later one
                if nslistwise then
                    local c = has_attribute(stack,attribute)
                    if c and current ~= c and nslistwise[c] then -- viewerlayer
                        local p = current
                        current, done = c, true
                        head = insert_node_before(head,stack,copy_node(nsdata[c]))
                        stack.list = stacked(namespace,attribute,content,current)
                        head, stack = insert_node_after(head,stack,copy_node(nsnone))
                        current = p
                    else
                        local ok = false
                        stack.list, ok = stacked(namespace,attribute,content,current)
                        done = done or ok
                    end
                else
                    local ok = false
                    stack.list, ok = stacked(namespace,attribute,content,current)
                    done = done or ok
                end
            end
        end
        stack = stack.next
    end
    while depth > 0 do
        head = insert_node_after(head,stack,copy_node(nsnone))
        depth = depth -1
    end
    return head, done
end

states.stacked = stacked

-- -- --

statistics.register("attribute processing time", function()
    return statistics.elapsedseconds(attributes,"front- and backend")
end)
