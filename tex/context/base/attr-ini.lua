if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- nb: attributes: color etc is much slower than normal (marks + literals) but ...

--
-- nodes
--

nodes      = nodes      or { }

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

-- We can distinguish between rules and glyphs but it's not worth the trouble. A
-- first implementation did that and while it saves a bit for glyphs and rules, it
-- costs more resourses for transparencies. So why bother.

-- namespace for all those features / plural becomes singular

-- i will do the resource stuff later, when we have an interface to pdf (ok, i can
-- fake it with tokens but it will take some coding

function totokens(str)
    local t = { }
--~     for c in string.bytes(str) do
    for c in str:bytes() do
        t[#t+1] = { 12, c }
    end
    return t
end

-- temp hack, will be proper driver stuff

backends     = backends     or { }
backends.pdf = backends.pdf or { }
backend      = backend      or backends.pdf

do

    local pdfliteral, register = nodes.pdfliteral, nodes.register

    function backends.pdf.literal(str)
        local t = pdfliteral(str)
        register(t)
        return t
    end

end

-- shipouts

shipouts         = shipouts or { }
shipouts.plugins = shipouts.plugins or { }

do

    local pairs = pairs -- in theory faster

    local hlist, vlist = node.id('hlist'), node.id('vlist')

    local has_attribute = node.has_attribute

    nodes.trigger    = nodes.trigger    or false
    nodes.triggering = nodes.triggering or false

    -- we used to do the main processor loop here and call processor for each node
    -- but eventually this was too much a slow down (1 sec on 23 for 120 pages mk)
    -- so that we moved looping to the processor itself; this may lead to a bit of
    -- duplicate code once that we have more state handlers

    local starttiming, stoptiming = input.starttiming, input.stoptiming

    local function process_attributes(head,plugins)
        if head then -- is already tested
            starttiming(attributes)
            local done, used = false, { }
            local trigger, numbers = nodes.trigger, attributes.numbers
            for name, plugin in pairs(plugins) do
                local attribute = numbers[name]
                if attribute then
                    local namespace = plugin.namespace
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
                            local ok -- = false
                            head, ok = processor(namespace,attribute,head,inheritance)
                            done = done or ok
                        end
                        if finalizer then -- no need when not ok
                            local ok -- = false
                            head, ok, used[attribute] = finalizer(namespace,attribute,head)
                            done = done or ok
                        end
                    end
                else
                    texio.write_nl(string.format("undefined attribute %s",name))
                end
            end
            if done then
                for name, plugin in pairs(plugins) do
                    local attribute = numbers[name]
                    if used[attribute] then
                        local namespace = plugin.namespace
                        if namespace.enabled then
                            local flusher  = plugin.flusher
                            if flusher then
                                local h, d = flusher(namespace,attribute,head,used[attribute])
                                head = h
                            end
                        end
                    end
                end
            end
            stoptiming(attributes)
            return head, done
        else
            return head, false
        end
    end

    nodes.process_attributes = process_attributes

    --~ glyph   = 746876
    --~ glue    = 376096
    --~ hlist   = 152284
    --~ disc    =  47224
    --~ kern    =  41504
    --~ penalty =  31964
    --~ whatsit =  29048
    --~ vlist   =  20136
    --~ rule    =  13292
    --~ mark    =   4304
    --~ math    =   1072

    local disc, mark, free = node.id('disc'), node.id('mark'), node.free

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
                free(tmp)
            elseif id == hlist or id == vlist then
                local sl = start.list
                if sl then
                    start.list = cleanup_page(sl)
                end
                prev, start = start, nx
            else
                prev, start = start, nx
            end
        end
        return head
    end

    nodes.cleanup_page = cleanup_page

    nodes.cleanup_page_first = false

    function nodes.process_page(head)
        if nodes.cleanup_page_first then
            head = cleanup_page(head)
        end
        return process_attributes(head,shipouts.plugins)
    end

end

--
-- generic handlers
--

states = { }

do

    local glyph, rule, whatsit, hlist, vlist = node.id('glyph'), node.id('rule'), node.id('whatsit'), node.id('hlist'), node.id('vlist')

    local has_attribute, copy = node.has_attribute, node.copy

    local current, used, done = 0, { }, false

    function states.initialize(what, attribute, stack)
        current, used, done = 0, { }, false
    end

    local function insert(n,stack,previous,head) -- there is a helper, we need previous because we are not slided
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
        return stack, head
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
        local trigger = namespace.triggering and nodes.triggering and nodes.trigger
        local stack, previous, done = head, nil, false
        local nsdata, nsreviver, nsnone = namespace.data, namespace.reviver, namespace.none
        while stack do
            local id = stack.id
            if id == glyph or id == whatsit or id == rule then -- or disc
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
        return head, done
    end

    states.process = process

    -- we can force a selector, e.g. document wide color spaces, saves a little

    local function selective(namespace,attribute,head,inheritance,default) -- two attributes
        local trigger = namespace.triggering and nodes.triggering and nodes.trigger
        local stack, previous, done = head, nil, false
        local nsselector, nsforced, nsselector = namespace.default, namespace.forced, namespace.selector
        local nsdata, nsreviver, nsnone = namespace.data, namespace.reviver, namespace.none
        while stack do
            local id = stack.id
            if id == glyph or id == whatsit or id == rule then -- or disc
                -- todo: maybe track two states, also selector
                local c = has_attribute(stack,attribute)
                if c then
                    if default and c == inheritance then
                        if current ~= default then
                            local data = nsdata[default] or nsreviver(default)
                            stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
                            current, done, used[default] = default, true, true
                        end
                    elseif current ~= c then
                        local data = nsdata[c] or nsreviver(c)
                        stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
                        current, done, used[c] = c, true, true
                    end
                elseif default and inheritance then
                    if current ~= default then
                        local data = nsdata[default] or nsreviver(default)
                        stack, head = insert(data[nsforced or has_attribute(stack,nsselector) or nsselector],stack,previous,head)
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
        return head, done
    end

    states.selective = selective

end

states           = states           or { }
states.collected = states.collected or { }

input.storage.register(false,"states/collected", states.collected, "states.collected")

function states.collect(str)
    local collected = states.collected
    collected[#collected+1] = str
end

function states.flush()
--~     for _, c in ipairs(states.collected) do
--~         tex.sprint(tex.ctxcatcodes,c)
--~     end
    local collected = states.collected
    if #collected > 0 then
        for i=1,#collected do
            tex.sprint(tex.ctxcatcodes,collected[i]) -- we're in context mode anyway
        end
        states.collected = { }
    end
end

function states.check()
    texio.write_nl(table.concat(states.collected,"\n"))
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
colors.main       = nil

-- This is a compromis between speed and simplicity. We used to store the
-- values and data in one array, which made in neccessary to store the
-- converters that need node constructor into strings and evaluate them
-- at runtime (after reading from storage). Think of:
--
-- colors.strings = colors.strings or { }
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
    all  = 1,
    gray = 2,
    rgb  = 3,
    cmyk = 4,
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
        return { 2, s, s, s, s, 0, 0, 0, s }
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
    triggering  = true,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.selective,
    resolver    = function(...) return colors.main end,
}

-- transparencies

-- for the moment we manage transparencies in the pdf driver because
-- first we need a nice interface to some pdf things

transparencies            = transparencies            or { }
transparencies.registered = transparencies.registered or { }
transparencies.data       = transparencies.data       or { }
transparencies.values     = transparencies.values     or { }
transparencies.enabled    = false
transparencies.template   = "%s:%s"

input.storage.register(false, "transparencies/registered", transparencies.registered, "transparencies.registered")
input.storage.register(false, "transparencies/values",     transparencies.values,     "transparencies.values")

function transparencies.reference(n)
    return backends.pdf.literal(string.format("/Tr%s gs",n))
end

function transparencies.register(name,a,t)
    local stamp = string.format(transparencies.template,a,t)
    local n = transparencies.registered[stamp]
    if not n then
        n = #transparencies.data+1
        transparencies.data[n] = transparencies.reference(n)
        transparencies.values[n] = { a, t }
        transparencies.registered[stamp] = n
        states.collect(string.format("\\presetPDFtransparencybynumber{%s}{%s}{%s}",n,a,t)) -- too many, but experimental anyway
    end
    return transparencies.registered[stamp]
end

function transparencies.reviver(n)
    local d = transparencies.data[n]
    if not d then
        local v = transparencies.values[n]
        if not v then
            d = transparencies.reference(0)
            logs.report("attributes",string.format("unable to revive transparency %s",n or "?"))
        else
            d = transparencies.reference(n)
            states.collect(string.format("\\presetPDFtransparencybynumber{%s}{%s}{%s}",n,v[1],v[2]))
        end
        transparencies.data[n] = d
    end
    return d
end

-- check if there is an identity

--~ transparencies.none = transparencies.reference(transparencies.register(nil,1,1))

transparencies.none = transparencies.reference(0) -- for the moment the pdf backend does this

function transparencies.value(id)
    return transparencies.values[id]
end

shipouts.plugins.transparency = {
    namespace   = transparencies,
    triggering  = true,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

--- overprint / knockout

overprints         = overprints      or { }
overprints.data    = overprints.data or { }
overprints.enabled = false

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
negatives.enabled = false

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
effects.enabled    = false
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
