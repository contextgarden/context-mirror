if not modules then modules = { } end modules ['typo-bld'] = { -- was node-par
    version   = 1.001,
    comment   = "companion to typo-bld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local insert, remove = table.insert, table.remove

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

local a_parbuilder       = attributes.numbers['parbuilder'] or 999 -- why 999
constructors.attribute   = a_parbuilder

local unsetvalue         = attributes.unsetvalue
local texsetattribute    = tex.setattribute
local has_attribute      = node.has_attribute
local texnest            = tex.nest

local nodepool           = nodes.pool
local new_baselineskip   = nodepool.baselineskip
local new_lineskip       = nodepool.lineskip
local insert_node_before = node.insert_before
local hpack_node         = node.hpack

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

storage.register("builders/paragraphs/constructors/names",   names,   "builders.paragraphs.constructors.names")
storage.register("builders/paragraphs/constructors/numbers", numbers, "builders.paragraphs.constructors.numbers")

local report_parbuilders = logs.reporter("parbuilders")

local mainconstructor = nil -- not stored in format
local nofconstructors = 0
local stack           = { }

function constructors.define(name)
    nofconstructors = nofconstructors + 1
    names[nofconstructors] = name
    numbers[name] = nofconstructors
end

function constructors.set(name) --- will go
    if name then
        mainconstructor = numbers[name] or unsetvalue
    else
        mainconstructor = stack[#stack] or unsetvalue
    end
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor ~= unsetvalue then
        constructors.enable()
    end
end

function constructors.start(name)
    local number = numbers[name]
    insert(stack,number)
    mainconstructor = number or unsetvalue
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor ~= unsetvalue then
        constructors.enable()
    end
--     report_parbuilders("start %s",name)
end

function constructors.stop()
    remove(stack)
    mainconstructor = stack[#stack] or unsetvalue
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor == unsetvalue then
        constructors.disable()
    end
--     report_parbuilders("stop")
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
        local attribute = has_attribute(head,a_parbuilder) -- or mainconstructor
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

-- also for testing (now also surrounding spacing done)

function builders.paragraphs.constructors.methods.oneline(head,followed_by_display)
    -- when needed we will turn this into a helper
    local t = texnest[texnest.ptr]
    local h = hpack_node(head)
    local d = tex.baselineskip.width - t.prevdepth - h.height
    t.prevdepth = h.depth
    t.prevgraf  = 1
    if d < tex.lineskiplimit then
        return insert_node_before(h,h,new_lineskip(tex.lineskip))
    else
        return insert_node_before(h,h,new_baselineskip(d))
    end
end

-- It makes no sense to have a sequence here as we already have
-- pre and post hooks and only one parbuilder makes sense, so no:
--
-- local actions = nodes.tasks.actions("parbuilders")
--
-- yet ... maybe some day.

local actions = constructors.handler
local enabled = false

local function processor(head,followed_by_display)
    -- todo: not again in otr so we need to flag
    if enabled then
        starttiming(parbuilders)
        local head = actions(head,followed_by_display)
        stoptiming(parbuilders)
        return head
    else
        return true -- let tex do the work
    end
end

function constructors.enable()
    enabled = true
end

function constructors.disable()
    enabled = false
end


callbacks.register('linebreak_filter', processor, "breaking paragraps into lines")

statistics.register("linebreak processing time", function()
    return statistics.elapsedseconds(parbuilders)
end)

-- interface

commands.defineparbuilder  = constructors.define
commands.startparbuilder   = constructors.start
commands.stopparbuilder    = constructors.stop
commands.setparbuilder     = constructors.set
commands.enableparbuilder  = constructors.enable
commands.disableparbuilder = constructors.disable
