if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-par.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local builders, nodes, node = builders, nodes, node

builders.paragraphs      = builders.paragraphs or { }
local parbuilders        = builders.paragraphs

parbuilders.constructors = parbuilders.constructors or { }
local       constructors = parbuilders.constructors

parbuilders.names        = parbuilders.names or { }
local names              = parbuilders.names

parbuilders.numbers      = parbuilders.numbers or { }
local numbers            = parbuilders.numbers

local p_attribute        = attributes.numbers['parbuilder'] or 999
parbuilders.attribute    = p_attribute

local has_attribute      = node.has_attribute
local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

storage.register("builders/paragraphs/names",   names,   "builders.paragraphs.names")
storage.register("builders/paragraphs/numbers", numbers, "builders.paragraphs.numbers")

local report_parbuilders = logs.new("parbuilders")

local mainconstructor = nil -- not stored in format

function parbuilders.register(name,number)
    names[number] = name
    numbers[name] = number
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
                    report_parbuilders("handler '%s' is not defined",tostring(constructor))
                    return true -- let tex break
                end
            end
        end
        return true -- let tex break
    end
end

-- just for testing

function constructors.default(head,followed_by_display)
    return true -- let tex break
end

-- also for testing (no surrounding spacing done)

function constructors.oneline(head,followed_by_display)
    return node.hpack(head)
end

-- It makes no sense to have a sequence here as we already have
-- pre and post hooks and only one parbuilder makes sense, so no:
--
-- local actions = nodes.tasks.actions("parbuilders",1)

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
        return true -- let tex do the work
    end
end

callbacks.register('linebreak_filter', processor, "breaking paragraps into lines")

statistics.register("linebreak processing time", function()
    return statistics.elapsedseconds(parbuilders)
end)
