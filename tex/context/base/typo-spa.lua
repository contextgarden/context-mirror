if not modules then modules = { } end modules ['typo-spa'] = {
    version   = 1.001,
    comment   = "companion to typo-spa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local utfchar = utf.char

local trace_spacing = false  trackers.register("typesetters.spacing", function(v) trace_spacing = v end)

local report_spacing = logs.reporter("typesetting","spacing")

local nodes, fonts, node = nodes, fonts, node

local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local quaddata           = fonthashes.quads

local texattribute       = tex.attribute
local unsetvalue         = attributes.unsetvalue

local v_reset            = interfaces.variables.reset

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local somespace          = nodes.somespace
local somepenalty        = nodes.somepenalty

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.spacings     = typesetters.spacings or { }
local spacings           = typesetters.spacings

spacings.mapping         = spacings.mapping or { }
spacings.numbers         = spacings.numbers or { }

local a_spacings         = attributes.private("spacing")
spacings.attribute       = a_spacings

storage.register("typesetters/spacings/mapping", spacings.mapping, "typesetters.spacings.mapping")

local mapping = spacings.mapping
local numbers = spacings.numbers

for i=1,#mapping do
    local m = mapping[i]
    numbers[m.name] = m
end

-- todo cache lastattr

local function process(namespace,attribute,head)
    local done = false
    local start = head
    -- head is always begin of par (whatsit), so we have at least two prev nodes
    -- penalty followed by glue
    while start do
        if start.id == glyph_code then
            local attr = start[attribute]
            if attr and attr > 0 then
                local data = mapping[attr]
                if data then
                    local map = data.characters[start.char]
                    start[attribute] = unsetvalue -- needed?
                    if map then
                        local left = map.left
                        local right = map.right
                        local alternative = map.alternative
                        local quad = quaddata[start.font]
                        local prev = start.prev
                        if left and left ~= 0 and prev then
                            local ok = false
                            if alternative == 1 then
                                local somespace = somespace(prev,true)
                                if somespace then
                                    local prevprev = prev.prev
                                    local somepenalty = somepenalty(prevprev,10000)
                                    if somepenalty then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space before %s (left)", utfchar(start.char))
                                        end
                                        head = remove_node(head,prev,true)
                                        head = remove_node(head,prevprev,true)
                                    else
                                        if trace_spacing then
                                            report_spacing("removing space before %s (left)", utfchar(start.char))
                                        end
                                        head = remove_node(head,prev,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (somespace(prev,true) and somepenalty(prev.prev,true)) or somespace(prev,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space before %s (left)", utfchar(start.char))
                                end
                                insert_node_before(head,start,new_penalty(10000))
                                insert_node_before(head,start,new_glue(left*quad))
                                done = true
                            end
                        end
                        local next = start.next
                        if right and right ~= 0 and next then
                            local ok = false
                            if alternative == 1 then
                                local somepenalty = somepenalty(next,10000)
                                if somepenalty then
                                    local nextnext = next.next
                                    local somespace = somespace(nextnext,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space after %s (right)", utfchar(start.char))
                                        end
                                        head = remove_node(head,next,true)
                                        head = remove_node(head,nextnext,true)
                                    end
                                else
                                    local somespace = somespace(next,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing space after %s (right)", utfchar(start.char))
                                        end
                                        head = remove_node(head,next,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (somepenalty(next,10000) and somespace(next.next,true)) or somespace(next,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space after %s (right)", utfchar(start.char))
                                end
                                insert_node_after(head,start,new_glue(right*quad))
                                insert_node_after(head,start,new_penalty(10000))
                                done = true
                            end
                        end
                    end
                end
            end
        end
        start = start.next
    end
    return head, done
end

local enabled = false

function spacings.define(name)
    local data = numbers[name]
    if data then
        -- error
    else
        local number = #mapping + 1
        local data = {
            name       = name,
            number     = number,
            characters = { },
        }
        mapping[number] = data
        numbers[name]   = data
    end
end

function spacings.setup(name,char,settings)
    local data = numbers[name]
    if not data then
        -- error
    else
        data.characters[char] = settings
    end
end

function spacings.set(name)
    local n = unsetvalue
    if name ~= v_reset then
        local data = numbers[name]
        if data then
            if not enabled then
                tasks.enableaction("processors","typesetters.spacings.handler")
                enabled = true
            end
            n = data.number or unsetvalue
        end
    end
    texattribute[a_spacings] = n
end

function spacings.reset()
    texattribute[a_spacings] = unsetvalue
end

spacings.handler = nodes.installattributehandler {
    name      = "spacing",
    namespace = spacings,
    processor = process,
}

-- interface

commands.definecharacterspacing = spacings.define
commands.setupcharacterspacing  = spacings.setup
commands.setcharacterspacing    = spacings.set
