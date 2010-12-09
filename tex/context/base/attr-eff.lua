if not modules then modules = { } end modules ['attr-eff'] = {
    version   = 1.001,
    comment   = "companion to attr-eff.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local allocate = utilities.storage.allocate

local attributes, nodes = attributes, nodes

local states          = attributes.states
local tasks           = nodes.tasks
local nodeinjections  = backends.nodeinjections
local settexattribute = tex.setattribute

attributes.effects = attributes.effects or { }
local effects      = attributes.effects

local a_effect     = attributes.private('effect')

effects.data       = allocate()
effects.values     = effects.values     or { }
effects.registered = effects.registered or { }
effects.attribute  = a_effect

storage.register("attributes/effects/registered", effects.registered, "attributes.effects.registered")
storage.register("attributes/effects/values",     effects.values,     "attributes.effects.values")

local template = "%s:%s:%s"

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
    local d = effect(e[1],e[2],e[3])
    data[n] = d
    return d
end

setmetatable(effects,      { __index = extender })
setmetatable(effects.data, { __index = reviver  })

effects.handler = nodes.installattributehandler {
    name        = "effect",
    namespace   = effects,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

local function register(effect,stretch,rulethickness)
    local stamp = format(template,effect,stretch,rulethickness)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = { effect, stretch, rulethickness }
        registered[stamp] = n
    end
    return n
end

local function enable()
    tasks.enableaction("shipouts","attributes.effects.handler")
end

effects.register = register
effects.enable   = enable

-- interface

local enabled = false

function commands.triggereffect(effect,stretch,rulethickness)
    if not enabled then
        enable()
        enabled = true
    end
    settexattribute(a_effect,register(effect,stretch,rulethickness))
end
