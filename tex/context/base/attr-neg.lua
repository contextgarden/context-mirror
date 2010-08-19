if not modules then modules = { } end modules ['attr-neg'] = {
    version   = 1.001,
    comment   = "companion to attr-neg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed and code will move to other places
-- we can also do the nsnone via a metatable and then also se index 0

local format = string.format

local attributes, nodes = attributes, nodes

local states         = attributes.states
local tasks          = nodes.tasks
local nodeinjections = backends.nodeinjections

--- negative / positive

attributes.negatives = attributes.negatives or { }
local negatives      = attributes.negatives
negatives.data       = negatives.data or { }
negatives.attribute  = attributes.private("negative")

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

attributes.negatives.handler = nodes.installattributehandler {
    name        = "negative",
    namespace   = negatives,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

function negatives.enable()
    tasks.enableaction("shipouts","attributes.negatives.handler")
end
