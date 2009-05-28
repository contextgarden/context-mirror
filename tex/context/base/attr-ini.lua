if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed

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

-- namespace for all those features / plural becomes singular

-- i will do the resource stuff later, when we have an interface to pdf (ok, i can
-- fake it with tokens but it will take some coding

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
colors.attribute  = 0
colors.selector   = 0
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

function colors.reviver(n)
    local d = data[n]
    if not d then
        local v = values[n]
        if not v then
            local gray = nodeinjections.graycolor(0)
            d = { gray, gray, gray, gray }
            logs.report("attributes","unable to revive color %s",n or "?")
        else
            local kind, gray, rgb, cmyk = v[1], nodeinjections.graycolor(v[2]), nodeinjections.rgbcolor(v[3],v[4],v[5]), nodeinjections.cmykcolor(v[6],v[7],v[8],v[9])
            if kind == 2 then
                d = { gray, gray, gray, gray }
            elseif kind == 3 then
                d = { rgb, gray, rgb, cmyk }
            elseif kind == 4 then
                d = { cmyk, gray, rgb, cmyk }
            elseif kind == 5 then
                local spot = nodeinjections.spotcolor(v[10],v[11],v[12],v[13])
                d = { spot, gray, rgb, cmyk }
            end
        end
        data[n] = d
    end
    return d
end

function colors.filter(n)
    return concat(data[n],":",5)
end

colors.none = nodeinjections.graycolor(0)

function colors.setmodel(attribute,name)
    colors.model = name
    colors.selector = numbers[attribute]
    colors.default = models[name] or 1
    return colors.default
end

function colors.register(attribute, name, colorspace, ...) -- passing 9 vars is faster
    local stamp = format(templates[colorspace],...)
    local color = registered[stamp]
    if not color then
        color = #values+1
        values[color] = colors[colorspace](...)
        registered[stamp] = color
        colors.reviver(color)
    end
    if name then
        list[numbers[attribute]][name] = color -- not grouped, so only global colors
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

-- for the moment we manage transparencies in the pdf driver because
-- first we need a nice interface to some pdf things

transparencies            = transparencies            or { }
transparencies.registered = transparencies.registered or { }
transparencies.data       = transparencies.data       or { }
transparencies.values     = transparencies.values     or { }
transparencies.enabled    = false
transparencies.triggering = true

storage.register("transparencies/registered", transparencies.registered, "transparencies.registered")
storage.register("transparencies/values",     transparencies.values,     "transparencies.values")

local registered = transparencies.registered
local data       = transparencies.data
local values     = transparencies.values
local template   = "%s:%s"

local function reference(n)
    reference = nodeinjections.transparency
    return reference(n)
end

function transparencies.register(name,a,t)
    local stamp = format(template,a,t)
    local n = registered[stamp]
    if not n then
        n = #data+1
        data[n] = reference(n)
        values[n] = { a, t }
        registered[stamp] = n
        registrations.transparency(n,a,t)
    end
    return registered[stamp]
end

function transparencies.reviver(n)
    local d = data[n]
    if not d then
        local v = values[n]
        if not v then
            d = reference(0)
            logs.report("attributes","unable to revive transparency %s",n or "?")
        else
            d = reference(n)
            registrations.transparency(n,v[1],v[2])
        end
        data[n] = d
    end
    return d
end

-- check if there is an identity

transparencies.none = reference(0) -- for the moment the pdf backend does this

function transparencies.value(id)
    return values[id]
end

shipouts.handle_transparency = nodes.install_attribute_handler {
    name        = "transparency",
    namespace   = transparencies,
    initializer = states.initialize,
    finalizer   = states.finalize  ,
    processor   = states.process   ,
}

--- overprint / knockout

overprints         = overprints      or { }
overprints.data    = overprints.data or { }
overprints.enabled = false

overprints.data[1] = nodeinjections.overprint()
overprints.data[2] = nodeinjections.knockout()

overprints.none    = overprints.data[2]

overprints.registered = {
    overprint = 1,
    knockout  = 2,
}

--~ storage.register("overprints/registered", overprints.registered, "overprints.registered")
--~ storage.register("overprints/data",       overprints.data,       "overprints.data")

local data       = overprints.data
local registered = overprints.registered

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

negatives         = negatives      or { }
negatives.data    = negatives.data or { }
negatives.enabled = false

negatives.data[1] = nodeinjections.positive()
negatives.data[2] = nodeinjections.negative()

negatives.none    = negatives.data[1]

negatives.registered = {
    positive = 1,
    negative = 2,
}

function negatives.register(stamp)
    return negatives.registered[stamp] or negatives.registered.positive
end

shipouts.handle_negative = nodes.install_attribute_handler {
    name        = "negative",
    namespace   = negatives,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

-- effects -- can be optimized

effects            = effects            or { }
effects.data       = effects.data       or { }
effects.registered = effects.registered or { }
effects.enabled    = false
effects.stamp      = "%s:%s:%s"

storage.register("effects/registered", effects.registered, "effects.registered")
storage.register("effects/data",       effects.data,       "effects.data")

function effects.register(effect,stretch,rulethickness)
    local stamp = format(effects.stamp,effect,stretch,rulethickness)
    local n = effects.registered[stamp]
    if not n then
        n = #effects.data+1
        effects.data[n] = effects.reference(effect,stretch,rulethickness)
        effects.registered[stamp] = n
    end
    return effects.registered[stamp]
end

-- valid effects: normal inner outer both hidden

function effects.reference(effect,stretch,rulethickness)
    effects.reference = nodeinjections.effect
    return nodeinjections.effect(stretch,rulethickness,effect)
end

effects.none = effects.reference(0,0,0)

shipouts.handle_effect = nodes.install_attribute_handler {
    name        = "effect",
    namespace   = effects,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

-- layers (ugly code, due to no grouping and such)

viewerlayers            = viewerlayers            or { }
viewerlayers.data       = viewerlayers.data       or { }
viewerlayers.registered = viewerlayers.registered or { }
viewerlayers.enabled    = false

storage.register("viewerlayers/registered", viewerlayers.registered, "viewerlayers.registered")
--~ storage.register("viewerlayers/data",       viewerlayers.data,       "viewerlayers.data")

local data       = viewerlayers.data
local registered = viewerlayers.registered
local template   = "%s"

local somedone = false
local somedata = { }
local nonedata = nodeinjections.stoplayer()

function viewerlayers.none() -- no local
    if somedone then
        somedone = false
        return nonedata
    else
        return nil
    end
end

local function some(name)
    local sd = somedata[name]
    if not sd then
        sd = {
            nodeinjections.switchlayer(name),
            nodeinjections.startlayer(name),
        }
        somedata[name] = sd
    end
    if somedone then
        return sd[1]
    else
        somedone = true
        return sd[2]
    end
end

local function initializer(...)
    somedone = false
    return states.initialize(...)
end

viewerlayers.register = function(name)
    local stamp = format(template,name)
    local n = registered[stamp]
    if not n then
        n = #data + 1
        data[n] = function() return some(name) end -- slow but for the moment we don't store things in the format
        registered[stamp] = n
    end
    return registered[stamp] -- == n
end

shipouts.handle_viewerlayer = nodes.install_attribute_handler {
    name        = "viewerlayer",
    namespace   = viewerlayers,
    initializer = initializer,
    finalizer   = states.finalize,
    processor   = states.process,
}
