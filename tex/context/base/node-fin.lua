if not modules then modules = { } end modules ['node-fin'] = {
    version   = 1.001,
    comment   = "companion to node-fin.tex",
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

--

states.collected = states.collected or { }

storage.register("states/collected", states.collected, "states.collected")

local collected = states.collected

function states.collect(str)
    collected[#collected+1] = str
end

function states.flush()
    if #collected > 0 then
        for i=1,#collected do
            texsprint(ctxcatcodes,collected[i]) -- we're in context mode anyway
        end
        collected = { }
        states.collected = collected
    end
end

function states.check()
    texio.write_nl(concat(collected,"\n"))
end

-- we used to do the main processor loop here and call processor for each node
-- but eventually this was too much a slow down (1 sec on 23 for 120 pages mk)
-- so that we moved looping to the processor itself; this may lead to a bit of
-- duplicate code once that we have more state handlers

local function process_attribute(head,plugin) -- head,attribute,enabled,initializer,resolver,processor,finalizer
    starttiming(attributes)
    local done, used, ok = false, nil, false
    local attribute = numbers[plugin.name] -- todo: plugin.attribute
    local namespace = plugin.namespace
    if namespace.enabled then
        local processor = plugin.processor
        if processor then
            local initializer = plugin.initializer
            local resolver    = plugin.resolver
            local inheritance = (resolver and resolver()) or -0x7FFFFFFF -- we can best use nil and skip !
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
                            local h, d = flusher(namespace,attribute,head,used)
                            head = h
                        end
                    end
                end
                done = true
            end
        end
    end
    stoptiming(attributes)
    return head, done
end

nodes.process_attribute = process_attribute

function nodes.install_attribute_handler(plugin)
    return function(head)
        return process_attribute(head,plugin)
    end
end

-- a few handlers

local current, current_selector, used, done = 0, 0, { }, false

local function insert(n,stack,previous,head) -- there is a helper, we need previous because we are not slided
    if n then
        if type(n) == "function" then
            n = n()
        end
        if n then
            n = copy_node(n)
            n.next = stack
            if previous then
                previous.next = n
            else
                head = n
            end
            previous = n -- ?
        else
            -- weird
        end
    end
    return stack, head
end

function states.initialize(what, attribute, stack)
    current, current_selector, used, done = 0, 0, { }, false
end

function states.finalize(namespace,attribute,head) -- is this one ok?
    if current > 0 then
        local nn = namespace.none
        if nn then
            local id = head.id
            if id == hlist or id == vlist then
                local list = head.list
                if list then
                    local _, h = insert(nn,list,nil,list)
                    head.list = h
                end
            else
                stack, head = insert(nn,head,nil,head)
            end
            return head, true, true
        end
    end
    return head, false, false
end

local function process(namespace,attribute,head,inheritance,default) -- one attribute
    local trigger = triggering and namespace.triggering and trigger
    local stack, previous, done = head, nil, false
    local nsdata, nsreviver, nsnone = namespace.data, namespace.reviver, namespace.none
    while stack do
        local id = stack.id
        -- we need to deal with literals too (reset as well as oval)
--~             if id == glyph or (id == whatsit and stack.subtype == 8) or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
        if id == glyph or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
            local c = has_attribute(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        local data = nsdata[default] or nsreviver(default)
                        stack, head = insert(data,stack,previous,head)
                        current, done, used[default] = default, true, true
                    end
                elseif current ~= c then
                    local data = nsdata[c] or nsreviver(c)
                    stack, head = insert(data,stack,previous,head)
                    current, done, used[c] = c, true, true
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
                        if trigger and has_attribute(stack,trigger) then
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
                    local data = nsdata[default] or nsreviver(default)
                    stack, head = insert(data,stack,previous,head)
                    current, done, used[default] = default, true, true
                end
            elseif current > 0 then
                stack, head = insert(nsnone,stack,previous,head)
                current, done, used[0] = 0, true, true
            end
        elseif id == hlist or id == vlist then
            local content = stack.list
            if content then
                local ok = false
                if trigger and has_attribute(stack,trigger) then
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
        previous = stack
        stack = stack.next
    end
    -- we need to play safe
-- i need a proper test set for this, maybe controlled per feature
--~         if current > 0 then
--~             stack, head = insert(nsnone,stack,previous,head)
--~             current, current_selector, done, used[0] = 0, 0, true, true
--~         end
    return head, done
end

states.process = process

-- we can force a selector, e.g. document wide color spaces, saves a little
-- watch out, we need to check both the selector state (like colorspace) and
-- the main state (like color), otherwise we get into troubles when a selector
-- state changes while the main state stays the same (like two glyphs following
-- each other with the same color but different color spaces e.g. \showcolor)

local function selective(namespace,attribute,head,inheritance,default) -- two attributes
    local trigger = triggering and namespace.triggering and trigger
    local stack, previous, done = head, nil, false
    local nsforced, nsselector = namespace.forced, namespace.selector
    local nsdata, nsreviver, nsnone = namespace.data, namespace.reviver, namespace.none
    while stack do
        local id = stack.id
        -- we need to deal with literals too (reset as well as oval)
--~             if id == glyph or (id == whatsit and stack.subtype == 8) or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
        if id == glyph or (id == rule and stack.width ~= 0) or (id == glue and stack.leader) then -- or disc
            local c = has_attribute(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        local data = nsdata[default] or nsreviver(default)
                        stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
                        current, done, used[default] = default, true, true
                    end
                else
                    local s = has_attribute(stack,nsselector)
                    if current ~= c or current_selector ~= s then
                        local data = nsdata[c] or nsreviver(c)
                        stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
                        current, current_selector, done, used[c] = c, s, true, true
                    end
                end
            elseif default and inheritance then
                if current ~= default then
                    local data = nsdata[default] or nsreviver(default)
                    stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
                    current, done, used[default] = default, true, true
                end
            elseif current > 0 then
                stack, head = insert(nsnone,stack,previous,head)
                current, current_selector, done, used[0] = 0, 0, true, true
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
                    if trigger and has_attribute(stack,trigger) then
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
                if trigger and has_attribute(stack,trigger) then
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
        previous = stack
        stack = stack.next
    end
    -- we need to play safe, this is subptimal since now we end each box
    -- even if it's not needed
-- i need a proper test set for this, maybe controlled per feature
--~         if current > 0 then
--~             stack, head = insert(nsnone,stack,previous,head)
--~             current, current_selector, done, used[0] = 0, 0, true, true
--~         end
    return head, done
end

states.selective = selective

statistics.register("attribute processing time", function()
    if statistics.elapsedindeed(attributes) then
        return format("%s seconds",statistics.elapsedtime(attributes))
    end
end)
