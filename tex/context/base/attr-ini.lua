if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--
-- attributes
--

nodes = nodes or { }

-- We can distinguish between rules and glyphs but it's not worth the trouble. A
-- first implementation did that and while it saves a bit for glyphs and rules, it
-- costs more resourses for transparencies. So why bother.

-- namespace for all those features / plural becomes singular

-- i will do the resource stuff later, when we have an interface to pdf (ok, i can
-- fake it with tokens but it will take some coding

function totokens(str)
    local t = { }
    for c in string.bytes(str) do
        t[#t+1] = { 12, c }
    end
    return t
end

function pdfliteral(str)
  local t = node.new('whatsit',8)
  t.mode = 1    -- direct
  t.data = str  -- totokens(str)
  return t
end

-- shipouts

shipouts         = shipouts or { }
shipouts.plugins = shipouts.plugins or { }

do

    local hlist, vlist = node.id('hlist'), node.id('vlist')

    local function do_process_page(attribute,processor,head) -- maybe work with ranges
        local previous, stack = nil, head
        while stack do
            local id = stack.id
            if id == hlist or id == vlist then
                local content = stack.list
                if content then
                    stack.list = do_process_page(attribute,processor,content)
                end
            else
                stack, previous, head = processor(attribute,stack,previous,head)
            end
            previous = stack
            stack = stack.next
        end
        return head
    end

    function nodes.process_page(head)
        if head then
            input.start_timing(nodes)
            local done, used = false, { }
            for name, plugin in pairs(shipouts.plugins) do
                local attribute = attributes.numbers[name]
                if attribute then
                    local initializer = plugin.initializer
                    local processor   = plugin.processor
                    local finalizer   = plugin.finalizer
                    if initializer then
                        initializer(attribute,head)
                    end
                    if processor then
                        head = do_process_page(attribute,processor,head)
                    end
                    if finalizer then
                        local ok
                        ok, head, used[attribute] = finalizer(attribute,head)
                        done = done or ok
                    end
                else
                    texio.write_nl(string.format("undefined attribute %s",name))
                end
            end
            if done then
                for name, plugin in pairs(shipouts.plugins) do
                    local attribute = attributes.numbers[name]
                    if used[attribute] then
                        local flusher = plugin.flusher
                        if flusher then
                            head = flusher(attribute,head,used[attribute])
                        end
                    end
                end
            end
            input.stop_timing(nodes)
        end
        return head
    end

end

--
-- attributes
--

attributes = attributes or { }

attributes.names   = attributes.names   or { }
attributes.numbers = attributes.numbers or { }
attributes.list    = attributes.list    or { }

input.storage.register(false,"attributes/names", attributes.names, "attributes.names")
input.storage.register(false,"attributes/numbers", attributes.numbers, "attributes.numbers")
input.storage.register(false,"attributes/list", attributes.list, "attributes.list")

function attributes.define(name,number)
    attributes.numbers[name], attributes.names[number], attributes.list[number] = number, name, { }
end

--
-- generic handlers
--

states = { }

do

    local glyph, rule, whatsit = node.id('glyph'), node.id('rule'), node.id('whatsit')

    local current, used, done = 0, { }, false

    function states.initialize(what, attribute, stack)
        current, used, done = 0, { }, false
    end

    local contains = node.has_attribute

    function insert(n,stack,previous,head)
        if n then
            n = node.copy(n)
            n.next = stack
            if previous then
                previous.next = n
            else
                head = n
            end
            previous = n
        end
        return stack, previous, head
    end

    function states.finalize(what,attribute,head)
        if what.enabled and what.none and current > 0 and head.list then
            local head = head.list
            stack, previous, head = insert(what.none,list,nil,list)
        end
        return done, head, used
    end

--~     function states.process(what,attribute,stack,previous,head) -- one attribute
--~         if what.enabled then
--~             local c = contains(stack,attribute)
--~             if c then
--~                 if current ~= c then
--~                     local id = stack.id
--~                     if id == glyph or id == rule or id == whatsit then
--~                         stack, previous, head = insert(what.data[c],stack,previous,head)
--~                         current, done, used[c] = c, true, true
--~                     end
--~                 end
--~             elseif current > 0 then
--~                 stack, previous, head = insert(what.none,stack,previous,head)
--~                 current, done, used[0] = 0, true, true
--~             end
--~         end
--~         return stack, previous, head
--~     end

    function states.process(what,attribute,stack,previous,head) -- one attribute
        if what.enabled then
            local id = stack.id
            if id == glyph or id == rule then -- or id == whatsit then
                local c = contains(stack,attribute)
                if c then
                    if current ~= c then
                        stack, previous, head = insert(what.data[c],stack,previous,head)
                        current, done, used[c] = c, true, true
                    end
                elseif current > 0 then
                    stack, previous, head = insert(what.none,stack,previous,head)
                    current, done, used[0] = 0, true, true
                end
            end
        end
        return stack, previous, head
    end

--~     function states.selective(what,attribute,stack,previous,head) -- two attributes
--~         if what.enabled then
--~             local c = contains(stack,attribute)
--~             if c then
--~                 if current ~= c then
--~                     local id = stack.id
--~                     if id == glyph or id == rule then -- or id == whatsit then
--~                         stack, previous, head = insert(what.data[c][contains(stack,what.selector) or what.default],stack,previous,head)
--~                         current, done, used[c] = c, true, true
--~                     end
--~                 end
--~             elseif current > 0 then
--~                 local id = stack.id
--~                 if id == glyph or id == rule then -- or id == whatsit then
--~                     stack, previous, head = insert(what.none,stack,previous,head)
--~                     current, done, used[0] = 0, true, true
--~                 end
--~             end
--~         end
--~         return stack, previous, head
--~     end

    function states.selective(what,attribute,stack,previous,head) -- two attributes
        if what.enabled then
            local id = stack.id
            if id == glyph or id == rule then -- or id == whatsit then
                local c = contains(stack,attribute)
                if c then
                    if current ~= c then
                        stack, previous, head = insert(what.data[c][contains(stack,what.selector) or what.default],stack,previous,head)
                        current, done, used[c] = c, true, true
                    end
                elseif current > 0 then
                    stack, previous, head = insert(what.none,stack,previous,head)
                    current, done, used[0] = 0, true, true
                end
            end
        end
        return stack, previous, head
    end

    collected = { }

    function states.collect(str)
        collected[#collected+1] = str
    end

    function states.flush()
        for _, c in ipairs(collected) do
            tex.sprint(tex.ctxcatcodes,c)
        end
        collected = { }
    end

end

--
-- colors
--

-- we can also collapse the two attributes: n, n+1, n+2 and then
-- at the tex end add 0, 1, 2, but this is not faster and less
-- flexible (since sometimes we freeze color attribute values at
-- the lua end of the game

-- we also need to store the colorvalues because we need then in mp

colors            = colors or { }
colors.enabled    = true
colors.data       = colors.data or { }
colors.strings    = colors.strings or { }
colors.registered = colors.registered or { }
colors.weightgray = true
colors.attribute  = 0
colors.selector   = 0
colors.default    = 1

input.storage.register(true,"colors/data", colors.strings, "colors.data")
input.storage.register(false,"colors/registered", colors.registered, "colors.registered")

colors.stamps = {
    rgb  = "r:%s:%s:%s",
    cmyk = "c:%s:%s:%s:%s",
    gray = "s:%s",
    spot = "p:%s:%s"
}

colors.models = {
    all = 1,
    gray = 2,
    rgb = 3,
    cmyk = 4
}

do

    local min    = math.min
    local max    = math.max
    local format = string.format
    local concat = table.concat

    local function rgbdata(r,g,b)
        return pdfliteral(format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b))
    end

    local function cmykdata(c,m,y,k)
        return pdfliteral(format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k))
    end

    local function graydata(s)
        return pdfliteral(format("%s g %s G",s,s))
    end

    local function spotdata(n,p) -- name, parent, ratio
        if type(p) == "string" then
            p = p:gsub(","," ") -- brr misuse of spot
        end
        return pdfliteral(format("/%s cs /%s CS %s SCN %s scn",n,n,p,p))
    end

    local function rgbtocmyk(r,g,b)
        return 1-r, 1-g, 1-b, 0
    end

    local function cmyktorgb(c,m,y,k)
        return 1.0 - min(1.0,c+k), 1.0 - min(1.0,m+k), 1.0 - min(1.0,y+k)
    end

    local function rgbtogray(r,g,b)
        if colors.weightgray then
            return .30*r+.59*g+.11*b
        else
            return r/3+g/3+b/3
        end
    end

    local function cmyktogray(c,m,y,k)
        return rgbtogray(cmyktorgb(c,m,y,k))
    end

    -- we can share some *data by using s, rgb and cmyk hashes, but
    -- normally the amount of colors is not that large; storing the
    -- components costs a bit of extra runtime, but we expect to gain
    -- some back because we have them at hand; the number indicates the
    -- default color space

    function colors.gray(s)
        local gray = graydata(s)
        return { gray, gray, gray, gray, 2, s, 0, 0, 0, 0, 0, 0, 1 }
    end

    function colors.rgb(r,g,b)
        local s = rgbtogray(r,g,b)
        local c, m, y, k = rgbtocmyk(r,g,b)
        local gray, rgb, cmyk = graydata(s), rgbdata(r,g,b), cmykdata(c,m,y,k)
        return { rgb, gray, rgb, cmyk, 3, s, r, g, b, c, m, y, k }
    end

    function colors.cmyk(c,m,y,k)
        local s = cmyktogray(c,m,y,k)
        local r, g, b = cmyktorgb(c,m,y,k)
        local gray, rgb, cmyk = graydata(s), rgbdata(r,g,b), cmykdata(c,m,y,k)
        return { cmyk, gray, rgb, cmyk, 4, s, r, g, b, c, m, y, k }
    end

    function colors.spot(parent,p) -- parent, ratio
        local spot = spotdata(parent,p)
        if type(p) == "string" and p:find(",") then
            -- use converted replacement (combination color)
        else
            -- todo: map gray, rgb, cmyk onto fraction*parent
        end
        local gray, rgb, cmyk = graydata(.5), rgbdata(.5,.5,.5), cmykdata(0,0,0,.5)
        return { spot, gray, rgb, cmyk, 5 }
    end

    function colors.filter(n)
        return concat(colors.data[n],":",5)
    end

    colors.none = graydata(0)

end

-- conversion models

function colors.setmodel(attribute,name)
    colors.selector = attributes.numbers[attribute]
    colors.default = colors.models[name] or 1
    return colors.default
end

function colors.register(attribute, name, colorspace, ...)
    local stamp = string.format(colors.stamps[colorspace], ...)
    local color = colors.registered[stamp]
    if not color then
        local cd = colors.data
        color = #cd+1
        cd[color] = colors[colorspace](...)
        if environment.initex then
            colors.strings[color] = "return colors." .. colorspace .. "(" .. table.concat({...},",") .. ")"
        end
        colors.registered[stamp] = color
    end
    attributes.list[attributes.numbers[attribute]][name] = color
    return colors.registered[stamp]
end

shipouts.plugins.color = {
    initializer = function(...) return states.initialize(colors,...) end,
    finalizer   = function(...) return states.finalize  (colors,...) end,
    processor   = function(...) return states.selective (colors,...) end,
}

--- overprint / knockout

overprints = { enabled = true , data = { } }

overprints.none    = pdfliteral(string.format("/GSoverprint gs"))
overprints.data[1] = pdfliteral(string.format("/GSknockout gs"))

overprints.registered = {
    overprint = 0,
    knockout  = 1,
}

function overprints.register(stamp)
    return overprints.registered[stamp] or overprints.registered.overprint
end

shipouts.plugins.overprint = {
    initializer = function(...) return states.initialize(overprints,...) end,
    finalizer   = function(...) return states.finalize  (overprints,...) end,
    processor   = function(...) return states.process   (overprints,...) end,
}

--- negative / positive

negatives = { enabled = true, data = { } }

negatives.none    = pdfliteral(string.format("/GSpositive gs"))
negatives.data[1] = pdfliteral(string.format("/GSnegative gs"))

negatives.registered = {
    positive = 0,
    negative = 1,
}

function negatives.register(stamp)
    return negatives.registered[stamp] or negatives.registered.positive
end

shipouts.plugins.negative = {
    initializer = function(...) return states.initialize(negatives,...) end,
    finalizer   = function(...) return states.finalize  (negatives,...) end,
    processor   = function(...) return states.process   (negatives,...) end,
}

-- effects

effects = { enabled = true, data = { } }

effects.none    = pdfliteral(string.format("0 Tr"))
effects.data[1] = pdfliteral(string.format("1 Tr"))
effects.data[2] = pdfliteral(string.format("2 Tr"))
effects.data[3] = pdfliteral(string.format("3 Tr"))

effects.registered = {
    normal = 0,
    inner  = 0,
    outer  = 1,
    both   = 2,
    hidden = 3,
}

function effects.register(stamp)
    return effects.registered[stamp] or effects.registered.normal
end

shipouts.plugins.effect = {
    initializer = function(...) return states.initialize(effects,...) end,
    finalizer   = function(...) return states.finalize  (effects,...) end,
    processor   = function(...) return states.process   (effects,...) end,
}

-- layers

--~ /OC /somename BDC
--~ EMC

-- transparencies

-- for the moment we manage transparencies in the pdf driver because
-- first we need a nice interface to some pdf things

transparencies = {
    enabled    = true,
    data       = { },
    registered = { },
    hack       = { }
}

input.storage.register(false, "transparencies/registed", transparencies.registered, "transparencies.registered")
input.storage.register(false, "transparencies/data",     transparencies.data,       "transparencies.data")
input.storage.register(false, "transparencies/hack",     transparencies.hack,       "transparencies.hack")

function transparencies.reference(n)
    return pdfliteral(string.format("/Tr%s gs",n))
end

transparencies.none = transparencies.reference(0)

transparencies.stamp = "%s:%s"

function transparencies.register(...)
    local stamp = string.format(transparencies.stamp, ...)
    if not transparencies.registered[stamp] then
        local n = #transparencies.data+1
        transparencies.data[n] = transparencies.reference(n)
        transparencies.registered[stamp] = n
        states.collect(string.format("\\presetPDFtransparency{%s}{%s}",...)) -- too many, but experimental anyway
    end
    return transparencies.registered[stamp]
end

shipouts.plugins.transparency = {
    initializer = function(...) return states.initialize(transparencies,...) end,
    finalizer   = function(...) return states.finalize  (transparencies,...) end,
    processor   = function(...) return states.process   (transparencies,...) end,
}

--~ shipouts.plugins.transparency.flusher = function(attribute,head,used)
--~     local max = 0
--~     for k,v in pairs(used) do
--~     end
--~     return head
--~ end

--~ from the time that node lists were tables and not userdata ...
--~
--~     local function do_collapse_page(stack,existing_t)
--~         if stack then
--~             local t = existing_t or { }
--~             for _, node in ipairs(stack) do
--~                 if node then
--~                     local kind = node[1]
--~                     node[3] = nil
--~                     if kind == 'hlist' or kind == 'vlist' then
--~                         node[8] = do_collapse_page(node[8]) -- maybe here check for nil
--~                         t[#t+1] = node
--~                     elseif kind == 'inline' then -- appending literals cost too much time
--~                         local nodes = node[4]
--~                         if #nodes == 1 then
--~                             t[#t+1] = nodes[1]
--~                         else
--~                             do_collapse_page(nodes,t)
--~                         end
--~                     else
--~                         t[#t+1] = node
--~                     end
--~                 end
--~             end
--~             return t
--~         else
--~             return nil
--~         end
--~     end
--~
--~     local function do_process_page(attribute,processor,stack)
--~         if stack then
--~             for i, node in ipairs(stack) do
--~                 if node then
--~                     local kind = node[1]
--~                     if kind == 'hlist' or kind == "vlist" then
--~                         local content = node[8]
--~                         if not content then
--~                             -- nil node
--~                         elseif type(content) == "table" then
--~                             node[8] = do_process_page(attribute,processor,content)
--~                         else
--~                             node[8] = do_process_page(attribute,processor,tex.get_node_list(content))
--~                         end
--~                     elseif kind == 'inline' then
--~                         node[4] = do_process_page(attribute,processor,node[4])
--~                     else
--~                         processor(attribute,stack,i,node,kind)
--~                     end
--~                 end
--~             end
--~         end
--~         return stack
--~     end
--~
--~     function nodes.process_page(stack,...)
--~         if stack then
--~             input.start_timing(nodes)
--~             local done, used = false, { }
--~             for name, plugin in pairs(shipouts.plugins) do
--~                 local attribute = attributes.numbers[name]
--~                 if attribute then
--~                     local initializer = plugin.initializer
--~                     local processor   = plugin.processor
--~                     local finalizer   = plugin.finalizer
--~                     if initializer then
--~                         initializer(attribute,stack)
--~                     end
--~                     if processor then
--~                         do_process_page(attribute,processor,stack)
--~                     end
--~                     if finalizer then
--~                         local ok
--~                         ok, used[attribute] = finalizer(attribute,stack)
--~                         done = done or ok
--~                     end
--~                 else
--~                     texio.write_nl(string.format("undefined attribute %s",name))
--~                 end
--~             end
--~             if done then
--~                 stack = do_collapse_page(stack)
--~                 for name, plugin in pairs(shipouts.plugins) do
--~                     local attribute = attributes.numbers[name]
--~                     if used[attribute] then
--~                         local flusher = plugin.flusher
--~                         if flusher then
--~                             flusher(attribute,stack,used[attribute])
--~                         end
--~                     end
--~                 end
--~             else
--~                 stack = true
--~             end
--~             input.stop_timing(nodes)
--~         end
--~         return stack
--~     end
--~
--~     function states.finalize(what,attribute,stack)
--~         if what.enabled then
--~             if current > 0 then
--~                 local list = stack
--~                 if #stack == 1 then
--~                     list = stack[#stack][8]
--~                 end
--~                 list[#list+1], current, done, used[0] = what.none, 0, true, true
--~             end
--~         end
--~         return done, used
--~     end
--~
--~     function states.process(what,attribute,stack,i,node,kind)
--~         if what.enabled then
--~             local a = node[3]
--~             if a then
--~                 local c = a[attribute]
--~                 if c then
--~                     if current ~= c and (kind == 'glyph' or kind == 'rule') then
--~                         stack[i], current, done, used[c] = nodes.inline(what.data[c], node), c, true, true
--~                     end
--~                 elseif current > 0 then
--~                     stack[i], current, done, used[0] = nodes.inline(what.none, node), 0, true, true
--~                 end
--~             end
--~         end
--~     end
