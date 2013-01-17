if not modules then modules = { } end modules ['node-fin'] = {
    version   = 1.001,
    comment   = "companion to node-fin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- this module is being reconstructed
-- local functions, only slightly slower

local next, type, format = next, type, string.format

local attributes, nodes, node = attributes, nodes, node

local has_attribute   = node.has_attribute
local copy_node       = node.copy
local find_tail       = node.slide

local nodecodes       = nodes.nodecodes
local whatcodes       = nodes.whatcodes

local glyph_code      = nodecodes.glyph
local disc_code       = nodecodes.disc
local glue_code       = nodecodes.glue
local rule_code       = nodecodes.rule
local whatsit_code    = nodecodes.whatsit
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist

local pdfliteral_code = whatcodes.pdfliteral

local states     = attributes.states
local numbers    = attributes.numbers
local trigger    = attributes.private('trigger')
local triggering = false

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming

local unsetvalue  = attributes.unsetvalue

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
--             context(collected[i]) -- we're in context mode anyway
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
        starttiming(attributes) -- in principle we could delegate this to the main caller
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

-- nodes.process_attribute = process_attribute

function nodes.installattributehandler(plugin) -- we need to avoid this nested function
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
--~ function nodes.installattributehandler(plugin) -- we need to avoid this nested function
--~     plugindata[plugin.name] = plugin
--~     local str = format(template,plugin.name)
--~     return loadstring(str)()
--~ end

-- the injectors

local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local nsdata, nsnone, nslistwise, nsforced, nsselector, nstrigger
local current, current_selector, done = 0, 0, false -- nb, stack has a local current !
local nsbegin, nsend

function states.initialize(namespace,attribute,head)
    nsdata           = namespace.data
    nsnone           = namespace.none
    nsforced         = namespace.forced
    nsselector       = namespace.selector
    nslistwise       = namespace.listwise
    nstrigger        = triggering and namespace.triggering and trigger
    current          = 0
    current_selector = 0
    done             = false -- todo: done cleanup
    nsstep           = namespace.resolve_step
    if nsstep then
        nsbegin      = namespace.resolve_begin
        nsend        = namespace.resolve_end
        nspush       = namespace.push
        nspop        = namespace.pop
    end
end

function states.finalize(namespace,attribute,head) -- is this one ok?
    if current > 0 and nsnone then
        local id = head.id
        if id == hlist_code or id == vlist_code then
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

-- disc nodes can be ignored
-- we need to deal with literals too (reset as well as oval)
-- if id == glyph_code or (id == whatsit_code and stack.subtype == pdfliteral_code) or (id == rule_code and stack.width ~= 0) or (id == glue_code and stack.leader) then

-- local function process(namespace,attribute,head,inheritance,default) -- one attribute
--     local stack, done = head, false
--     while stack do
--         local id = stack.id
--         if id == glyph_code or (id == rule_code and stack.width ~= 0) or (id == glue_code and stack.leader) then -- or disc_code
--             local c = has_attribute(stack,attribute)
--             if c then
--                 if default and c == inheritance then
--                     if current ~= default then
--                         head = insert_node_before(head,stack,copy_node(nsdata[default]))
--                         current = default
--                         done = true
--                     end
--                 elseif current ~= c then
--                     head = insert_node_before(head,stack,copy_node(nsdata[c]))
--                     current = c
--                     done = true
--                 end
--                 -- here ? compare selective
--                 if id == glue_code then --leader
--                     -- same as *list
--                     local content = stack.leader
--                     if content then
--                         local savedcurrent = current
--                         local ci = content.id
--                         if ci == hlist_code or ci == vlist_code then
--                             -- else we reset inside a box unneeded, okay, the downside is
--                             -- that we trigger color in each repeated box, so there is room
--                             -- for improvement here
--                             current = 0
--                         end
--                         local ok = false
--                         if nstrigger and has_attribute(stack,nstrigger) then
--                             local outer = has_attribute(stack,attribute)
--                             if outer ~= inheritance then
--                                 stack.leader, ok = process(namespace,attribute,content,inheritance,outer)
--                             else
--                                 stack.leader, ok = process(namespace,attribute,content,inheritance,default)
--                             end
--                         else
--                             stack.leader, ok = process(namespace,attribute,content,inheritance,default)
--                         end
--                         current = savedcurrent
--                         done = done or ok
--                     end
--                 end
--             elseif default and inheritance then
--                 if current ~= default then
--                     head = insert_node_before(head,stack,copy_node(nsdata[default]))
--                     current = default
--                     done = true
--                 end
--             elseif current > 0 then
--                 head = insert_node_before(head,stack,copy_node(nsnone))
--                 current = 0
--                 done = true
--             end
--         elseif id == hlist_code or id == vlist_code then
--             local content = stack.list
--             if content then
--                 local ok = false
--                 if nstrigger and has_attribute(stack,nstrigger) then
--                     local outer = has_attribute(stack,attribute)
--                     if outer ~= inheritance then
--                         stack.list, ok = process(namespace,attribute,content,inheritance,outer)
--                     else
--                         stack.list, ok = process(namespace,attribute,content,inheritance,default)
--                     end
--                 else
--                     stack.list, ok = process(namespace,attribute,content,inheritance,default)
--                 end
--                 done = done or ok
--             end
--         end
--         stack = stack.next
--     end
--     return head, done
-- end

local function process(namespace,attribute,head,inheritance,default) -- one attribute
    local stack, done = head, false

    local function check()
        local c = has_attribute(stack,attribute)
        if c then
            if default and c == inheritance then
                if current ~= default then
                    head = insert_node_before(head,stack,copy_node(nsdata[default]))
                    current = default
                    done = true
                end
            elseif current ~= c then
                head = insert_node_before(head,stack,copy_node(nsdata[c]))
                current = c
                done = true
            end
        elseif default and inheritance then
            if current ~= default then
                head = insert_node_before(head,stack,copy_node(nsdata[default]))
                current = default
                done = true
            end
        elseif current > 0 then
            head = insert_node_before(head,stack,copy_node(nsnone))
            current = 0
            done = true
        end
        return c
    end

    local function nested(content)
        if nstrigger and has_attribute(stack,nstrigger) then
            local outer = has_attribute(stack,attribute)
            if outer ~= inheritance then
                return process(namespace,attribute,content,inheritance,outer)
            else
                return process(namespace,attribute,content,inheritance,default)
            end
        else
            return process(namespace,attribute,content,inheritance,default)
        end
    end

    while stack do
        local id = stack.id
        if id == glyph_code then
            check()
        elseif id == glue_code then
            local content = stack.leader
            if content and check() then
                local savedcurrent = current
                local ci = content.id
                if ci == hlist_code or ci == vlist_code then
                    -- else we reset inside a box unneeded, okay, the downside is
                    -- that we trigger color in each repeated box, so there is room
                    -- for improvement here
                    current = 0
                end

                local ok = false
                stack.leader, ok = nested(content)
                done = done or ok

                current = savedcurrent
            end
        elseif id == hlist_code or id == vlist_code then
            local content = stack.list
            if content then

                local ok = false
                stack.list, ok = nested(content)
                done = done or ok

            end
        elseif id == rule_code then
            if stack.width ~= 0 then
                check()
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

-- local function selective(namespace,attribute,head,inheritance,default) -- two attributes
--     local stack, done = head, false
--     while stack do
--         local id = stack.id
--         -- we need to deal with literals too (reset as well as oval)
--         -- if id == glyph_code or (id == whatsit_code and stack.subtype == pdfliteral_code) or (id == rule_code and stack.width ~= 0) or (id == glue_code and stack.leader) then -- or disc_code
--         if id == glyph_code -- or id == disc_code
--                 or (id == rule_code and stack.width ~= 0) or (id == glue_code and stack.leader) then -- or disc_code
--             local c = has_attribute(stack,attribute)
--             if c then
--                 if default and c == inheritance then
--                     if current ~= default then
--                         local data = nsdata[default]
--                         head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
--                         current = default
--                         done = true
--                     end
--                 else
--                     local s = has_attribute(stack,nsselector)
--                     if current ~= c or current_selector ~= s then
--                         local data = nsdata[c]
--                         head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
--                         current = c
--                         current_selector = s
--                         done = true
--                     end
--                 end
--             elseif default and inheritance then
--                 if current ~= default then
--                     local data = nsdata[default]
--                     head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
--                     current = default
--                     done = true
--                 end
--             elseif current > 0 then
--                 head = insert_node_before(head,stack,copy_node(nsnone))
--                 current, current_selector, done = 0, 0, true
--             end
--             if id == glue_code then -- leader
--                 -- same as *list
--                 local content = stack.leader
--                 if content then
--                     local savedcurrent = current
--                     local ci = content.id
--                     if ci == hlist_code or ci == vlist_code then
--                         -- else we reset inside a box unneeded, okay, the downside is
--                         -- that we trigger color in each repeated box, so there is room
--                         -- for improvement here
--                         current = 0
--                     end
--                     local ok = false
--                     if nstrigger and has_attribute(stack,nstrigger) then
--                         local outer = has_attribute(stack,attribute)
--                         if outer ~= inheritance then
--                             stack.leader, ok = selective(namespace,attribute,content,inheritance,outer)
--                         else
--                             stack.leader, ok = selective(namespace,attribute,content,inheritance,default)
--                         end
--                     else
--                         stack.leader, ok = selective(namespace,attribute,content,inheritance,default)
--                     end
--                     current = savedcurrent
--                     done = done or ok
--                 end
--             end
--         elseif id == hlist_code or id == vlist_code then
--             local content = stack.list
--             if content then
--                 local ok = false
--                 if nstrigger and has_attribute(stack,nstrigger) then
--                     local outer = has_attribute(stack,attribute)
--                     if outer ~= inheritance then
--                         stack.list, ok = selective(namespace,attribute,content,inheritance,outer)
--                     else
--                         stack.list, ok = selective(namespace,attribute,content,inheritance,default)
--                     end
--                 else
--                     stack.list, ok = selective(namespace,attribute,content,inheritance,default)
--                 end
--                 done = done or ok
--             end
--         end
--         stack = stack.next
--     end
--     return head, done
-- end

local function selective(namespace,attribute,head,inheritance,default) -- two attributes
    local stack, done = head, false

    local function check()
        local c = has_attribute(stack,attribute)
        if c then
            if default and c == inheritance then
                if current ~= default then
                    local data = nsdata[default]
                    head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                    current = default
                    done = true
                end
            else
                local s = has_attribute(stack,nsselector)
                if current ~= c or current_selector ~= s then
                    local data = nsdata[c]
                    head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                    current = c
                    current_selector = s
                    done = true
                end
            end
        elseif default and inheritance then
            if current ~= default then
                local data = nsdata[default]
                head = insert_node_before(head,stack,copy_node(data[nsforced or has_attribute(stack,nsselector) or nsselector]))
                current = default
                done = true
            end
        elseif current > 0 then
            head = insert_node_before(head,stack,copy_node(nsnone))
            current, current_selector, done = 0, 0, true
        end
        return c
    end

    local function nested(content)
        if nstrigger and has_attribute(stack,nstrigger) then
            local outer = has_attribute(stack,attribute)
            if outer ~= inheritance then
                return selective(namespace,attribute,content,inheritance,outer)
            else
                return selective(namespace,attribute,content,inheritance,default)
            end
        else
            return selective(namespace,attribute,content,inheritance,default)
        end
    end

    while stack do
        local id = stack.id
        if id == glyph_code then
            check()
        elseif id == glue_code then
            local content = stack.leader
            if content and check() then
                local savedcurrent = current
                local ci = content.id
                if ci == hlist_code or ci == vlist_code then
                    -- else we reset inside a box unneeded, okay, the downside is
                    -- that we trigger color in each repeated box, so there is room
                    -- for improvement here
                    current = 0
                end

                local ok = false
                stack.leader, ok = nested(content)
                done = done or ok

                current = savedcurrent
            end
        elseif id == hlist_code or id == vlist_code then
            local content = stack.list
            if content then

                local ok = false
                stack.list, ok = nested(content)
                done = done or ok

             -- nicer:
             --
             -- local content, ok = nested(content)
             -- if ok then
             --     stack.leader = content
             --     done = true
             -- end

            end
        elseif id == rule_code then
            if stack.width ~= 0 then
                check()
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
-- paragraph lines and then gets mixed up. A messy business (esp since we want to be
-- efficient).
--
-- Todo: make a better stacker. Keep track (in attribute) about nesting level. Not
-- entirely trivial and a generic solution is nicer (compares to the exporter).

local function stacked(namespace,attribute,head,default) -- no triggering, no inheritance, but list-wise
    local stack, done = head, false
    local current, depth = default or 0, 0

    local function check()
        local a = has_attribute(stack,attribute)
        if a then
            if current ~= a then
                head = insert_node_before(head,stack,copy_node(nsdata[a]))
                depth = depth + 1
                current, done = a, true
            end
        elseif default > 0 then
            --
        elseif current > 0 then
            head = insert_node_before(head,stack,copy_node(nsnone))
            depth = depth - 1
            current, done = 0, true
        end
        return a
    end

    while stack do
        local id = stack.id
        if id == glyph_code then
            check()
        elseif id == glue_code then
            local content = stack.leader
            if content and check() then
                local ok = false
                stack.leader, ok = stacked(namespace,attribute,content,current)
                done = done or ok
            end
        elseif id == hlist_code or id == vlist_code then
            local content = stack.list
            if content then
             -- the problem is that broken lines gets the attribute which can be a later one
                if nslistwise then
                    local a = has_attribute(stack,attribute)
                    if a and current ~= a and nslistwise[a] then -- viewerlayer / needs checking, see below
                        local p = current
                        current, done = a, true
                        head = insert_node_before(head,stack,copy_node(nsdata[a]))
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
        elseif id == rule_code then
            if stack.width ~= 0 then
                check()
            end
        end
        stack = stack.next
    end
    while depth > 0 do
        head = insert_node_after(head,stack,copy_node(nsnone))
        depth = depth - 1
    end
    return head, done
end

states.stacked = stacked

-- experimental

local function stacker(namespace,attribute,head,default) -- no triggering, no inheritance, but list-wise
    nsbegin()
    local current, previous, done, okay = head, head, false, false
    local attrib = default or unsetvalue

    local function check()
        local a = has_attribute(current,attribute) or unsetvalue
        if a ~= attrib then
            local n = nsstep(a)
            if n then
             -- !!!! TEST CODE !!!!
--                 head = insert_node_before(head,current,copy_node(nsdata[tonumber(n)])) -- a
                head = insert_node_before(head,current,n) -- a
            end
            attrib, done, okay = a, true, true
        end
        return a
    end

    while current do
        local id = current.id
        if id == glyph_code then
            check()
        elseif id == glue_code then
            local content = current.leader
            if content and check() then
                -- tricky as a leader has to be a list so we cannot inject before
                local _, ok = stacker(namespace,attribute,content,attrib)
                done = done or ok
            end
        elseif id == hlist_code or id == vlist_code then
            local content = current.list
            if not content then
                -- skip
            elseif nslistwise then
                local a = has_attribute(current,attribute)
                if a and attrib ~= a and nslistwise[a] then -- viewerlayer
                    done = true
                    head = insert_node_before(head,current,copy_node(nsdata[a]))
                    current.list = stacker(namespace,attribute,content,a)
                    head, current = insert_node_after(head,current,copy_node(nsnone))
                else
                    local ok = false
                    current.list, ok = stacker(namespace,attribute,content,attrib)
                    done = done or ok
                end
            else
                local ok = false
                current.list, ok = stacker(namespace,attribute,content,default)
                done = done or ok
            end
        elseif id == rule_code then
            if current.width ~= 0 then
                check()
            end
        end
        previous = current
        current = current.next
    end
    if okay then
        local n = nsend()
        if n then
             -- !!!! TEST CODE !!!!
--             head = insert_node_after(head,previous,copy_node(nsdata[tostring(n)]))
            head = insert_node_after(head,previous,n)
        end
    end
    return head, done
end

states.stacker = stacker

-- -- --

statistics.register("attribute processing time", function()
    return statistics.elapsedseconds(attributes,"front- and backend")
end)
