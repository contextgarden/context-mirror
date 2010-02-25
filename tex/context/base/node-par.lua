if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-par.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

parbuilders              = parbuilders or { }
parbuilders.constructors = parbuilders.constructors or { }
parbuilders.names        = parbuilders.names or { }
parbuilders.attribute    = attributes.numbers['parbuilder'] or 999

local constructors, names, p_attribute = parbuilders.constructors, parbuilders.names, parbuilders.attribute

storage.register("parbuilders.names", parbuilders.names, "parbuilders.names")

local has_attribute = node.has_attribute
local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

-- store parbuilders.names

function parbuilders.register(name,attribute)
    parbuilders.names[attribute] = name
end

function parbuilders.constructor(head,is_display)
    local attribute = has_attribute(head,p_attribute)
    if attribute then
        local constructor = names[attribute]
        if constructor then
            return constructors[constructor](head,is_display)
        end
    end
    return false
end

-- just for testing

function parbuilders.constructors.default(head,is_display)
    return false
end

-- also for testing (no surrounding spacing done)

function parbuilders.constructors.oneline(head,is_display)
    return node.hpack(head)
end

local actions = tasks.actions("parbuilders",1)

local function processor(head,is_display)
    starttiming(parbuilders)
    local _, done = actions(head,is_display)
    stoptiming(parbuilders)
    return done
end

--~ callbacks.register('linebreak_filter', actions, "breaking paragraps into lines")
callbacks.register('linebreak_filter', processor, "breaking paragraps into lines")

statistics.register("linebreak processing time", function()
    return statistics.elapsedseconds(parbuilders)
end)
