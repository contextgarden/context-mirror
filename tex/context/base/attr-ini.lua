if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed
-- we can also do the nsnone via a metatable and then also se index 0

local type = type
local format, gmatch = string.format, string.gmatch
local concat = table.concat
local texsprint = tex.sprint

local ctxcatcodes = tex.ctxcatcodes

-- todo: document this

-- nb: attributes: color etc is much slower than normal (marks + literals) but ...
-- nb. too many "0 g"s

nodes    = nodes or { }
states   = states or { }
shipouts = shipouts or { }

-- We can distinguish between rules and glyphs but it's not worth the trouble. A
-- first implementation did that and while it saves a bit for glyphs and rules, it
-- costs more resourses for transparencies. So why bother.

--
-- colors
--

-- we can also collapse the two attributes: n, n+1, n+2 and then
-- at the tex end add 0, 1, 2, but this is not faster and less
-- flexible (since sometimes we freeze color attribute values at
-- the lua end of the game
--
-- we also need to store the colorvalues because we need then in mp
--
-- This is a compromis between speed and simplicity. We used to store the
-- values and data in one array, which made in neccessary to store the
-- converters that need node constructor into strings and evaluate them
-- at runtime (after reading from storage). Think of:
--
-- colors.strings = colors.strings or { }
--
-- if environment.initex then
--     colors.strings[color] = "return colors." .. colorspace .. "(" .. concat({...},",") .. ")"
-- end
--
-- storage.register("colors/data", colors.strings, "colors.data") -- evaluated
--
-- We assume that only processcolors are defined in the format.

colors            = colors            or { }
colors.data       = colors.data       or { }
colors.values     = colors.values     or { }
colors.registered = colors.registered or { }

colors.enabled    = true
colors.weightgray = true
colors.attribute  = attributes.private('color')
colors.selector   = attributes.private('colormodel')
colors.default    = 1
colors.main       = nil
colors.triggering = true

storage.register("colors/values",     colors.values,     "colors.values")
storage.register("colors/registered", colors.registered, "colors.registered")

local templates = {
    rgb  = "r:%s:%s:%s",
    cmyk = "c:%s:%s:%s:%s",
    gray = "s:%s",
    spot = "p:%s:%s:%s:%s"
}

local models = {
    all  = 1,
    gray = 2,
    rgb  = 3,
    cmyk = 4,
}

colors.model = "all"

local data       = colors.data
local values     = colors.values
local registered = colors.registered

local numbers    = attributes.numbers
local list       = attributes.list

local min = math.min
local max = math.max

local nodeinjections = backends.nodeinjections
local codeinjections = backends.codeinjections
local registrations  = backends.registrations

local function rgbtocmyk(r,g,b) -- we could reduce
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

colors.rgbtocmyk  = rgbtocmyk
colors.rgbtogray  = rgbtogray
colors.cmyktorgb  = cmyktorgb
colors.cmyktogray = cmyktogray

-- we can share some *data by using s, rgb and cmyk hashes, but
-- normally the amount of colors is not that large; storing the
-- components costs a bit of extra runtime, but we expect to gain
-- some back because we have them at hand; the number indicates the
-- default color space

function colors.gray(s)
    return { 2, s, s, s, s, 0, 0, 0, 1-s }
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

--~ function colors.spot(parent,f,d,p)
--~     return { 5, .5, .5, .5, .5, 0, 0, 0, .5, parent, f, d, p }
--~ end

function colors.spot(parent,f,d,p)
    if type(p) == "number" then
        local n = list[numbers.color][parent] -- hard coded ref to color number
        if n then
            local v = values[n]
            if v then
                -- the via cmyk hack is dirty, but it scales better
                local c, m, y, k = p*v[6], p*v[7], p*v[8], p*v[8]
                local r, g, b = cmyktorgb(c,m,y,k)
                local s = cmyktogray(c,m,y,k)
                return { 5, s, r, g, b, c, m, y, k, parent, f, d, p }
            end
        end
    else
        -- todo, multitone (maybe p should be a table)
    end
    return { 5, .5, .5, .5, .5, 0, 0, 0, .5, parent, f, d, p }
end

local function graycolor(...) graycolor = nodeinjections.graycolor return graycolor(...) end
local function rgbcolor (...) rgbcolor  = nodeinjections.rgbcolor  return rgbcolor (...) end
local function cmykcolor(...) cmykcolor = nodeinjections.cmykcolor return cmykcolor(...) end
local function spotcolor(...) spotcolor = nodeinjections.spotcolor return spotcolor(...) end

local function extender(colors,key)
    if key == "none" then
        local d = graycolor(0)
        colors.none = d
        return d
    end
end

local function reviver(data,n)
    local v = values[n]
    local d
    if not v then
        local gray = graycolor(0)
        d = { gray, gray, gray, gray }
        logs.report("attributes","unable to revive color %s",n or "?")
    else
        local kind, gray, rgb, cmyk = v[1], graycolor(v[2]), rgbcolor(v[3],v[4],v[5]), cmykcolor(v[6],v[7],v[8],v[9])
        if kind == 2 then
            d = { gray, gray, gray, gray }
        elseif kind == 3 then
            d = { rgb, gray, rgb, cmyk }
        elseif kind == 4 then
            d = { cmyk, gray, rgb, cmyk }
        elseif kind == 5 then
            local spot = spotcolor(v[10],v[11],v[12],v[13])
            d = { spot, gray, rgb, cmyk }
        end
    end
    data[n] = d
    return d
end

setmetatable(colors,      { __index = extender })
setmetatable(colors.data, { __index = reviver  })

function colors.filter(n)
    return concat(data[n],":",5)
end

function colors.setmodel(name,weightgray)
    colors.model = name
    colors.default = models[name] or 1
    colors.weightgray = weightgray ~= false
    return colors.default
end

function colors.register(name, colorspace, ...) -- passing 9 vars is faster (but not called that often)
    local stamp = format(templates[colorspace],...)
    local color = registered[stamp]
    if not color then
        color = #values+1
        values[color] = colors[colorspace](...)
        registered[stamp] = color
    -- colors.reviver(color)
    end
    if name then
        list[colors.attribute][name] = color -- not grouped, so only global colors
    end
    return registered[stamp]
end

function colors.value(id)
    return values[id]
end

shipouts.handle_color = nodes.install_attribute_handler {
    name        = "color",
    namespace   = colors,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.selective,
    resolver    = function() return colors.main end,
}

-- transparencies

transparencies            = transparencies            or { }
transparencies.registered = transparencies.registered or { }
transparencies.data       = transparencies.data       or { }
transparencies.values     = transparencies.values     or { }
transparencies.enabled    = false
transparencies.triggering = true
transparencies.attribute  = attributes.private('transparency')

storage.register("transparencies/registered", transparencies.registered, "transparencies.registered")
storage.register("transparencies/values",     transparencies.values,     "transparencies.values")

local registered = transparencies.registered
local data       = transparencies.data
local values     = transparencies.values
local template   = "%s:%s"

local function inject_transparency  (...) inject_transparency   = nodeinjections.transparency return inject_transparency  (...) end
local function register_transparency(...) register_transparency = registrations.transparency  return register_transparency(...) end

function transparencies.register(name,a,t)
    local stamp = format(template,a,t)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = { a, t }
        registered[stamp] = n
        register_transparency(n,a,t)
    end
    return registered[stamp]
end

local function extender(transparencies,key)
    if key == "none" then
        local d = inject_transparency(0)
        transparencies.none = d
        return d
    end
end

local function reviver(data,n)
    local v = values[n]
    local d
    if not v then
        d = inject_transparency(0)
    else
        d = inject_transparency(n)
        register_transparency(n,v[1],v[2])
    end
    data[n] = d
    return d
end

setmetatable(transparencies,      { __index = extender })
setmetatable(transparencies.data, { __index = reviver  })

-- check if there is an identity

function transparencies.value(id)
    return values[id]
end

shipouts.handle_transparency = nodes.install_attribute_handler {
    name        = "transparency",
    namespace   = transparencies,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

--- overprint / knockout

overprints           = overprints      or { }
overprints.data      = overprints.data or { }
overprints.enabled   = false
overprints.attribute = attributes.private('overprint')

overprints.registered = {
    overprint = 1,
    knockout  = 2,
}

local data, registered = overprints.data, overprints.registered

local function extender(overprints,key)
    if key == "none" then
        local d = data[2]
        overprints.none = d
        return d
    end
end

local function reviver(data,n)
    if n == 1 then
        local d = nodeinjections.overprint() -- called once
        data[1] = d
        return d
    elseif n == 2 then
        local d = nodeinjections.knockout() -- called once
        data[2] = d
        return d
    end
end

setmetatable(overprints,      { __index = extender })
setmetatable(overprints.data, { __index = reviver  })

function overprints.register(stamp)
    return registered[stamp] or registered.overprint
end

shipouts.handle_overprint = nodes.install_attribute_handler {
    name        = "overprint",
    namespace   = overprints,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

--- negative / positive

negatives           = negatives      or { }
negatives.data      = negatives.data or { }
negatives.enabled   = false
negatives.attribute = attributes.private("negative")

negatives.registered = {
    positive = 1,
    negative = 2,
}

local data, registered = negatives.data, negatives.registered

local function extender(negatives,key)
    if key == "none" then
        local d = data[1]
        negatives.none = d
        return d
    end
end

local function reviver(data,n)
    if n == 1 then
        local d = nodeinjections.positive() -- called once
        data[1] = d
        return d
    elseif n == 2 then
        local d = nodeinjections.negative() -- called once
        data[2] = d
        return d
    end
end

setmetatable(negatives,      { __index = extender })
setmetatable(negatives.data, { __index = reviver  })

function negatives.register(stamp)
    return registered[stamp] or registered.positive
end

shipouts.handle_negative = nodes.install_attribute_handler {
    name        = "negative",
    namespace   = negatives,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

-- effects -- can be optimized (todo: metatables)

effects            = effects            or { }
effects.data       = effects.data       or { }
effects.values     = effects.values     or { }
effects.registered = effects.registered or { }
effects.enabled    = false
effects.stamp      = "%s:%s:%s"
effects.attribute  = attributes.private("effect")

storage.register("effects/registered", effects.registered, "effects.registered")
storage.register("effects/values",     effects.values,     "effects.values")

local data, registered, values = effects.data, effects.registered, effects.values

-- valid effects: normal inner outer both hidden (stretch,rulethickness,effect)

local function effect(...) effect = nodeinjections.effect return effect(...) end

local function extender(effects,key)
    if key == "none" then
        local d = effect(0,0,0)
        effects.none = d
        return d
    end
end

local function reviver(data,n)
    local e = values[n] -- we could nil values[n] now but hardly needed
    local d = effect(v[1],v[2],v[3])
    data[n] = d
    return d
end

setmetatable(effects,      { __index = extender })
setmetatable(effects.data, { __index = reviver  })

function effects.register(effect,stretch,rulethickness)
    local stamp = format(effects.stamp,effect,stretch,rulethickness)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = { effect, stretch, rulethickness }
        registered[stamp] = n
    end
    return n
end

shipouts.handle_effect = nodes.install_attribute_handler {
    name        = "effect",
    namespace   = effects,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

-- layers (ugly code, due to no grouping and such); currently we use exclusive layers
-- but when we need it stacked layers might show up too; the next function based
-- approach can be replaced by static (metatable driven) resolvers

viewerlayers            = viewerlayers            or { }
viewerlayers.data       = viewerlayers.data       or { }
viewerlayers.registered = viewerlayers.registered or { }
viewerlayers.values     = viewerlayers.values     or { }
viewerlayers.listwise   = viewerlayers.listwise   or { }
viewerlayers.enabled    = false
viewerlayers.attribute  = attributes.private("viewerlayer")

storage.register("viewerlayers/registered", viewerlayers.registered, "viewerlayers.registered")
storage.register("viewerlayers/values",     viewerlayers.values,     "viewerlayers.values")

local data       = viewerlayers.data
local values     = viewerlayers.values
local listwise   = viewerlayers.listwise
local registered = viewerlayers.registered
local template   = "%s"

-- stacked

local function extender(viewerlayers,key)
    if key == "none" then
        local d = nodeinjections.stoplayer()
        viewerlayers.none = d
        return d
    end
end

local function reviver(data,n)
    local d = nodeinjections.startlayer(values[n])
    data[n] = d
    return d
end

setmetatable(viewerlayers,      { __index = extender })
setmetatable(viewerlayers.data, { __index = reviver  })

local function initializer(...)
    return states.initialize(...)
end

viewerlayers.register = function(name,lw) -- if not inimode redefine data[n] in first call
    local stamp = format(template,name)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = name
        registered[stamp] = n
        listwise[n] = lw or false
    end
    return registered[stamp] -- == n
end

shipouts.handle_viewerlayer = nodes.install_attribute_handler {
    name        = "viewerlayer",
    namespace   = viewerlayers,
    initializer = initializer,
    finalizer   = states.finalize,
    processor   = states.stacked,
}
