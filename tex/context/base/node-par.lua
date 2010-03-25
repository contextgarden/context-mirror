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
parbuilders.numbers      = parbuilders.numbers or { }
parbuilders.attribute    = attributes.numbers['parbuilder'] or 999

storage.register("parbuilders.names",   parbuilders.names,   "parbuilders.names")
storage.register("parbuilders.numbers", parbuilders.numbers, "parbuilders.numbers")

local constructors, names, numbers, p_attribute = parbuilders.constructors, parbuilders.names, parbuilders.numbers, parbuilders.attribute

local has_attribute = node.has_attribute
local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local mainconstructor = nil -- not stored in format

function parbuilders.register(name,number)
    parbuilders.names[number] = name
    parbuilders.numbers[name] = number
end

function parbuilders.setmain(name)
    mainconstructor = numbers[name]
end

-- return values:
--
-- true  : tex will break itself
-- false : idem but dangerous
-- head  : list of valid vmode nodes with last being hlist

function parbuilders.constructor(head,followed_by_display)
    if type(head) == "boolean" then
        return head
    else
        local attribute = has_attribute(head,p_attribute) or mainconstructor
        if attribute then
            local constructor = names[attribute]
            if constructor then
                local handler = constructor and constructors[constructor]
                if handler then
                    return handler(head,followed_by_display)
                else
                    logs.report("parbuilders","handler '%s' is not defined",tostring(constructor))
                    return true -- let tex break
                end
            end
        end
        return true -- let tex break
    end
end

-- just for testing

function parbuilders.constructors.default(head,followed_by_display)
    return true -- let tex break
end

-- also for testing (no surrounding spacing done)

function parbuilders.constructors.oneline(head,followed_by_display)
    return node.hpack(head)
end

-- It makes no sense to have a sequence here as we already have
-- pre and post hooks and only one parbuilder makes sense, so no:
--
-- local actions = tasks.actions("parbuilders",1)

-- todo: enable one as main

local actions = parbuilders.constructor
local enabled = false

function parbuilders.enable () enabled = true  end
function parbuilders.disable() enabled = false end

local function processor(head,followed_by_display)
    if enabled then
        starttiming(parbuilders)
        local head = actions(head,followed_by_display)
        stoptiming(parbuilders)
        return head
    else
        return true -- ler tex do the work
    end
end

callbacks.register('linebreak_filter', processor, "breaking paragraps into lines")

statistics.register("linebreak processing time", function()
    return statistics.elapsedseconds(parbuilders)
end)
