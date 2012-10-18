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

constructors.names       = constructors.names or { }
local names              = constructors.names

constructors.numbers     = constructors.numbers or { }
local numbers            = constructors.numbers

constructors.methods     = constructors.methods or { }
local methods            = constructors.methods

local p_attribute        = attributes.numbers['parbuilder'] or 999
constructors.attribute   = p_attribute

local has_attribute      = node.has_attribute
local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

storage.register("builders/paragraphs/constructors/names",   names,   "builders.paragraphs.constructors.names")
storage.register("builders/paragraphs/constructors/numbers", numbers, "builders.paragraphs.constructors.numbers")

local report_parbuilders = logs.reporter("parbuilders")

local mainconstructor = nil -- not stored in format

function constructors.register(name,number)
    names[number] = name
    numbers[name] = number
end

function constructors.set(name)
    mainconstructor = numbers[name]
end

-- return values:
--
-- true  : tex will break itself
-- false : idem but dangerous
-- head  : list of valid vmode nodes with last being hlist

function constructors.handler(head,followed_by_display)
    if type(head) == "boolean" then
        return head
    else
        local attribute = has_attribute(head,p_attribute) or mainconstructor
        if attribute then
            local method = names[attribute]
            if method then
                local handler = methods[method]
                if handler then
                    return handler(head,followed_by_display)
                else
                    report_parbuilders("contructor method '%s' is not defined",tostring(method))
                    return true -- let tex break
                end
            end
        end
        return true -- let tex break
    end
end

-- just for testing

function constructors.methods.default(head,followed_by_display)
    return true -- let tex break
end

-- also for testing (no surrounding spacing done)

function constructors.methods.oneline(head,followed_by_display)
    return node.hpack(head)
end

-- It makes no sense to have a sequence here as we already have
-- pre and post hooks and only one parbuilder makes sense, so no:
--
-- local actions = nodes.tasks.actions("parbuilders")
--
-- yet (maybe some day).
--
-- todo: enable one as main

local actions = constructors.handler
local enabled = false

function constructors.enable () enabled = true  end
function constructors.disable() enabled = false end

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
