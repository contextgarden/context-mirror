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

-- temp hack, will be proper driver stuff

backends     = backends     or { }
backends.pdf = backends.pdf or { }
backend      = backend      or backends.pdf

function backends.pdf.literal(str)
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

    local contains = node.has_attribute

    nodes.trigger    = false
    nodes.triggering = false

    -- we used to do the main processor loop here and call processor for each node
    -- but eventually this was too much a slow down (1 sec on 23 for 120 pages mk)
    -- so that we moved looping to teh processor itself; this may lead to a bit of
    -- duplicate code once that we have more state handlers

    function nodes.process_page(head)
        local trigger = nodes.trigger
        if head then
            input.start_timing(attributes)
            local done, used = false, { }
            for name, plugin in pairs(shipouts.plugins) do
                local attribute = attributes.numbers[name]
                if attribute then
                    local namespace   = plugin.namespace
                    if namespace.enabled then
                        local initializer = plugin.initializer
                        local processor   = plugin.processor
                        local finalizer   = plugin.finalizer
                        local resolver    = plugin.resolver
                        if initializer then
                            initializer(namespace,attribute,head)
                        end
                        if processor then
                            local inheritance = (resolver and resolver()) or -1
                            local ok
                            ok, head = processor(namespace,attribute,head,inheritance)
                            done = done or ok
                        end
                        if finalizer then -- no need when not ok
                            local ok
                            ok, head, used[attribute] = finalizer(namespace,attribute,head)
                            done = done or ok
                        end
                    end
                else
                    texio.write_nl(string.format("undefined attribute %s",name))
                end
            end
            if done then
                for name, plugin in pairs(shipouts.plugins) do
                    local attribute = attributes.numbers[name]
                    if used[attribute] then
                        local namespace = plugin.namespace
                        if namespace.enabled then
                            local flusher  = plugin.flusher
                            if flusher then
                                head = flusher(namespace,attribute,head,used[attribute])
                            end
                        end
                    end
                end
            end
            input.stop_timing(attributes)
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

    local glyph, rule, whatsit, hlist, vlist = node.id('glyph'), node.id('rule'), node.id('whatsit'), node.id('hlist'), node.id('vlist')

    local current, used, done = 0, { }, false

    function states.initialize(what, attribute, stack)
        current, used, done = 0, { }, false
    end

    local contains, copy = node.has_attribute, node.copy

    local function insert(n,stack,previous,head)
        if n then
            n = copy(n)
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

    function states.finalize(namespace,attribute,head)
        if current > 0 and namespace.none then
            if head.id == hlist or head.id == vlist then
                local stack, previous, head = insert(namespace.none,head.list,nil,head.list)
            else
                local stack, previous, head = insert(namespace.none,head,nil,head)
            end
            return true, head, true
        else
            return false, head, false
        end
    end

    function states.process(namespace,attribute,head,inheritance,default) -- one attribute
        local trigger = nodes.triggering and nodes.trigger
        local stack, previous, done, process = head, nil, false, states.process
        while stack do
            local id = stack.id
            if id == hlist or id == vlist then
                local content = stack.list
                if content then
                    local ok = false
                    if trigger and contains(stack,trigger) then
                        local outer = contains(stack,attribute)
                        if outer ~= inheritance then
                            ok, stack.list = process(namespace,attribute,content,inheritance,outer)
                        else
                            ok, stack.list = process(namespace,attribute,content,inheritance,default)
                        end
                    else
                        ok, stack.list = process(namespace,attribute,content,inheritance,default)
                    end
                    done = done or ok
                end
            elseif id == glyph or id == rule or id == whatsit then -- special
                local c = contains(stack,attribute)
                if c then
                    if default and c == inheritance then
                        if current ~= default then
                            local data = namespace.data[default] or namespace.reviver(default)
                            stack, previous, head = insert(data,stack,previous,head)
                            current, done, used[default] = default, true, true
                        end
                    elseif current ~= c then
                        local data = namespace.data[c] or namespace.reviver(c)
                        stack, previous, head = insert(data,stack,previous,head)
                        current, done, used[c] = c, true, true
                    end
                elseif default and inheritance then
                    if current ~= default then
                        local data = namespace.data[default] or namespace.reviver(default)
                        stack, previous, head = insert(data,stack,previous,head)
                        current, done, used[default] = default, true, true
                    end
                elseif current > 0 then
                    stack, previous, head = insert(namespace.none,stack,previous,head)
                    current, done, used[0] = 0, true, true
                end
            end
            previous = stack
            stack = stack.next
        end
        return done, head
    end

    -- we can force a selector, e.g. document wide color spaces, saves a little

    function states.selective(namespace,attribute,head,inheritance,default) -- two attributes
        local trigger = nodes.triggering and nodes.trigger
        local stack, previous, done, selective = head, nil, false, states.selective
        local defaultselector, forcedselector, selector, reviver = namespace.default, namespace.forced, namespace.selector, namespace.reviver
        local none = namespace.none
        while stack do
            local id = stack.id
            if id == hlist or id == vlist then
                local content = stack.list
                if content then
                    local ok = false
                    if trigger and contains(stack,trigger) then
                        local outer = contains(stack,attribute)
                        if outer ~= inheritance then
                            ok, stack.list = selective(namespace,attribute,content,inheritance,outer)
                        else
                            ok, stack.list = selective(namespace,attribute,content,inheritance,default)
                        end
                    else
                        ok, stack.list = selective(namespace,attribute,content,inheritance,default)
                    end
                    done = done or ok
                end
            elseif id == glyph or id == rule or id == whatsit then -- special
                local c = contains(stack,attribute)
                if c then
                    if default and c == inheritance then
                        if current ~= default then
                            local data = namespace.data[default] or reviver(default)
                            stack, previous, head = insert(data[forcedselector or contains(stack,selector) or defaultselector],stack,previous,head)
                            current, done, used[default] = default, true, true
                        end
                    elseif current ~= c then
                        local data = namespace.data[c] or reviver(c)
                        stack, previous, head = insert(data[forcedselector or contains(stack,selector) or defaultselector],stack,previous,head)
                        current, done, used[c] = c, true, true
                    end
                elseif default and inheritance then
                    if current ~= default then
                        local data = namespace.data[default] or reviver(default)
                        stack, previous, head = insert(data[forcedselector or contains(stack,selector) or defaultselector],stack,previous,head)
                        current, done, used[default] = default, true, true
                    end
                elseif current > 0 then
                    stack, previous, head = insert(none,stack,previous,head)
                    current, done, used[0] = 0, true, true
                end
            end
            previous = stack
            stack = stack.next
        end
        return done, head
    end

    local collected = { }

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

colors            = colors            or { }
colors.data       = colors.data       or { }
colors.values     = colors.values     or { }
colors.registered = colors.registered or { }
colors.enabled    = true
colors.weightgray = true
colors.attribute  = 0
colors.selector   = 0
colors.default    = 1
colors.main     = nil

-- This is a compromis between speed and simplicity. We used to store the
-- values and data in one array, which made in neccessary to store the
-- converters that need node constructor into strings and evaluate them
-- at runtime (after reading from storage). Think of:
--
-- colors.strings    = colors.strings    or { }
--
-- if environment.initex then
--     colors.strings[color] = "return colors." .. colorspace .. "(" .. table.concat({...},",") .. ")"
-- end
--
-- input.storage.register(true,"colors/data", colors.strings, "colors.data") -- evaluated
--
-- We assume that only processcolors are defined in the format.

input.storage.register(false,"colors/values",     colors.values,     "colors.values")
input.storage.register(false,"colors/registered", colors.registered, "colors.registered")

colors.stamps = {
    rgb  = "r:%s:%s:%s",
    cmyk = "c:%s:%s:%s:%s",
    gray = "s:%s",
    spot = "p:%s:%s:%s:%s"
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

    local function rgbdata(r,g,b) -- dodo: backends.pdf.rgbdata
        return backends.pdf.literal(format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b))
    end

    local function cmykdata(c,m,y,k)
        return backends.pdf.literal(format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k))
    end

    local function graydata(s)
        return backends.pdf.literal(format("%s g %s G",s,s))
    end

    local function spotdata(n,f,d,p)
        if type(p) == "string" then
            p = p:gsub(","," ") -- brr misuse of spot
        end
        return backends.pdf.literal(format("/%s cs /%s CS %s SCN %s scn",n,n,p,p))
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
        return { 2, s, 0, 0, 0, 0, 0, 0, 1 }
    end

    function colors.rgb(r,g,b)
        local s = rgbtogray(r,g,b)
        local c, m, y, k = rgbtocmyk(r,g,b)
        return { 3, s, r, g, b, c, m, y, k }
    end

    function colors.cmyk(c,m,y,k)
        local s = cmyktogray(c,m,y,k)
        local r, g, b = cmyktorgb(c,m,y,k)
        return { 4, s, r, g, b, c, m, y, k }
    end

    function colors.spot(parent,f,d,p)
--~         if type(p) == "string" and p:find(",") then
--~             -- use converted replacement (combination color)
--~         else
--~             -- todo: map gray, rgb, cmyk onto fraction*parent
--~         end
        return { 5, .5, .5, .5, .5, 0, 0, 0, .5, parent, f, d, p }
    end

    function colors.reviver(n)
        local d = colors.data[n]
        if not d then
            local v = colors.values[n]
            if not v then
                local gray = graydata(0)
                d = { gray, gray, gray, gray }
                logs.report("attributes",string.format("unable to revive color %s",n or "?"))
            else
                local kind, gray, rgb, cmyk = v[1], graydata(v[2]), rgbdata(v[3],v[4],v[5]), cmykdata(v[6],v[7],v[8],v[9])
                if kind == 2 then
                    d = { gray, gray, gray, gray }
                elseif kind == 3 then
                    d = { rgb, gray, rgb, cmyk }
                elseif kind == 4 then
                    d = { cmyk, gray, rgb, cmyk }
                elseif kind == 5 then
                    local spot = spotdata(v[10],v[11],v[12],v[13])
                    d = { spot, gray, rgb, cmyk }
                end
            end
            colors.data[n] = d
        end
        return d
    end

    function colors.filter(n)
        return concat(colors.data[n],":",5)
    end

    colors.none = graydata(0)

end

function colors.setmodel(attribute,name)
    colors.selector = attributes.numbers[attribute]
    colors.default = colors.models[name] or 1
    return colors.default
end

function colors.register(attribute, name, colorspace, ...) -- passing 9 vars is faster
    local stamp = string.format(colors.stamps[colorspace], ...)
    local color = colors.registered[stamp]
    if not color then
        color = #colors.values+1
        colors.values[color] = colors[colorspace](...)
        colors.registered[stamp] = color
        colors.reviver(color)
    end
    if name then
        attributes.list[attributes.numbers[attribute]][name] = color -- not grouped, so only global colors
    end
    return colors.registered[stamp]
end

function colors.value(id)
    return colors.values[id]
end

shipouts.plugins.color = {
    namespace   = colors,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.selective ,
    resolver    = function(...) return colors.main end,
}

-- transparencies

-- for the moment we manage transparencies in the pdf driver because
-- first we need a nice interface to some pdf things

transparencies            = transparencies            or { }
transparencies.registered = transparencies.registered or { }
transparencies.data       = transparencies.data       or { }
transparencies.values     = transparencies.values     or { }
transparencies.enabled    = true
transparencies.template   = "%s:%s"

input.storage.register(false, "transparencies/registered", transparencies.registered, "transparencies.registered")
input.storage.register(false, "transparencies/data",       transparencies.data,       "transparencies.data")
input.storage.register(false, "transparencies/values",     transparencies.values,     "transparencies.values")

function transparencies.reference(n)
    return backends.pdf.literal(string.format("/Tr%s gs",n))
end

transparencies.none = transparencies.reference(0)

function transparencies.register(name,...)
    local stamp = string.format(transparencies.template, ...)
    local n = transparencies.registered[stamp]
    if not n then
        n = #transparencies.data+1
        transparencies.data[n] = transparencies.reference(n)
        transparencies.values[n] = { ... }
        transparencies.registered[stamp] = n
        states.collect(string.format("\\presetPDFtransparency{%s}{%s}",...)) -- too many, but experimental anyway
    end
    return transparencies.registered[stamp]
end

function transparencies.value(id)
    return transparencies.values[id]
end

shipouts.plugins.transparency = {
    namespace   = transparencies,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

--- overprint / knockout

overprints         = overprints      or { }
overprints.data    = overprints.data or { }
overprints.enabled = true

overprints.data[1] = backends.pdf.literal(string.format("/GSoverprint gs"))
overprints.data[2] = backends.pdf.literal(string.format("/GSknockout  gs"))

overprints.none    = overprints.data[1]

overprints.registered = {
    overprint = 1,
    knockout  = 2,
}

function overprints.register(stamp)
--  states.collect(tex.sprint(tex.ctxcatcodes,"\\initializePDFoverprint")) -- to be testd
    return overprints.registered[stamp] or overprints.registered.overprint
end

shipouts.plugins.overprint = {
    namespace   = overprints,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

--- negative / positive

negatives         = netatives      or { }
negatives.data    = negatives.data or { }
negatives.enabled = true

negatives.data[1] = backends.pdf.literal(string.format("/GSpositive gs"))
negatives.data[2] = backends.pdf.literal(string.format("/GSnegative gs"))

negatives.none    = negatives.data[1]

negatives.registered = {
    positive = 1,
    negative = 2,
}

function negatives.register(stamp)
--  states.collect(tex.sprint(tex.ctxcatcodes,"\\initializePDFnegative")) -- to be testd
    return negatives.registered[stamp] or negatives.registered.positive
end

shipouts.plugins.negative = {
    namespace   = negatives,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

-- effects

effects            = effects            or { }
effects.data       = effects.data       or { }
effects.registered = effects.registered or { }
effects.enabled    = true
effects.stamp      = "%s:%s:%s"

input.storage.register(false, "effects/registered", effects.registered, "effects.registered")
input.storage.register(false, "effects/data",       effects.data,       "effects.data")

function effects.register(effect,stretch,rulethickness)
    local stamp = string.format(effects.stamp,effect,stretch,rulethickness)
    local n = effects.registered[stamp]
    if not n then
        n = #effects.data+1
        effects.data[n] = effects.reference(effect,stretch,rulethickness)
        effects.registered[stamp] = n
    --  states.collect("") -- nothing
    end
    return effects.registered[stamp]
end

backends.pdf.effects = {
    normal = 1,
    inner  = 1,
    outer  = 2,
    both   = 3,
    hidden = 4,
}

function effects.reference(effect,stretch,rulethickness) -- will move, test code, we will develop a proper model for that
    effect = backends.pdf.effects[effects] or backends.pdf.effects['normal']
    if stretch > 0 then
        stretch = stretch .. " w "
    else
        stretch = ""
    end
    if rulethickness > 0 then
        rulethickness = number.dimenfactors["bp"]*rulethickness.. " Tc "
    else
        rulethickness = ""
    end
    return backends.pdf.literal(string.format("%s%s%s Tr",stretch,rulethickness,effect)) -- watch order
end

effects.none = effects.reference(effect,0,0)

shipouts.plugins.effect = {
    namespace   = effects,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

-- layers

--~ /OC /somename BDC
--~ EMC
