if not modules then modules = { } end modules ['typo-spa'] = {
    version   = 1.001,
    comment   = "companion to typo-spa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- get rid of tex.scale here

local utf = unicode.utf8

local next, type = next, type
local utfchar = utf.char

local trace_spacing = false  trackers.register("typesetting.spacing", function(v) trace_spacing = v end)

local report_spacing = logs.new("spacing")

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove
local make_penalty_node  = nodes.penalty
local make_glue_node     = nodes.glue

local fontdata           = fonts.identifiers
local quaddata           = fonts.quads
local nodecodes          = nodes.nodecodes

local texattribute       = tex.attribute

local glyph              = nodecodes.glyph

typesetting          = typesetting          or { }
typesetting.spacings = typesetting.spacings or { }

local spacings = typesetting.spacings

spacings.mapping   = spacings.mapping or { }
spacings.attribute = attributes.private("spacing")

local a_spacings = spacings.attribute

storage.register("typesetting/spacings/mapping", spacings.mapping, "typesetting.spacings.mapping")

local function process(namespace,attribute,head)
    local done, mapping = false, spacings.mapping
    local start = head
    -- head is always begin of par (whatsit), so we have at least two prev nodes
    -- penalty followed by glue
    while start do
        if start.id == glyph then
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                local map = mapping[attr]
                if map then
                    map = map[start.char]
                    unset_attribute(start,attribute) -- needed?
                    if map then
                        local left, right, alternative = map.left, map.right, map.alternative
                        local quad = quaddata[start.font]
                        local prev = start.prev
                        if left and left ~= 0 and prev then
                            local ok = false
                            if alternative == 1 then
                                local somespace = nodes.somespace(prev,true)
                                if somespace then
                                    local prevprev = prev.prev
                                    local somepenalty = nodes.somepenalty(prevprev,10000)
                                    if somepenalty then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space before %s (left)", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,prev,true)
                                        head, _ = remove_node(head,prevprev,true)
                                    else
                                        if trace_spacing then
                                            report_spacing("removing space before %s (left)", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,prev,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (nodes.somespace(prev,true) and nodes.somepenalty(prev.prev,true)) or nodes.somespace(prev,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space before %s (left)", utfchar(start.char))
                                end
                                insert_node_before(head,start,make_penalty_node(10000))
                                insert_node_before(head,start,make_glue_node(tex.scale(quad,left)))
                                done = true
                            end
                        end
                        local next = start.next
                        if right and right ~= 0 and next then
                            local ok = false
                            if alternative == 1 then
                                local somepenalty = nodes.somepenalty(next,10000)
                                if somepenalty then
                                    local nextnext = next.next
                                    local somespace = nodes.somespace(nextnext,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space after %s (right)", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,next,true)
                                        head, _ = remove_node(head,nextnext,true)
                                    end
                                else
                                    local somespace = nodes.somespace(next,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing space after %s (right)", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,next,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (nodes.somepenalty(next,10000) and nodes.somespace(next.next,true)) or nodes.somespace(next,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space after %s (right)", utfchar(start.char))
                                end
                                insert_node_after(head,start,make_glue_node(tex.scale(quad,right)))
                                insert_node_after(head,start,make_penalty_node(10000))
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

function spacings.setup(id,char,left,right,alternative)
    local mapping = spacings.mapping[id]
    if not mapping then
        mapping = { }
        spacings.mapping[id] = mapping
    end
    local map = mapping[char]
    if not map then
        map = { }
        mapping[char] = map
    end
    map.left, map.right, map.alternative = left, right, alternative
end

function spacings.set(id)
    if not enabled then
        tasks.enableaction("processors","typesetting.spacings.handler")
        enabled = true
    end
    texattribute[a_spacings] = id
end

spacings.handler = nodes.install_attribute_handler {
    name      = "spacing",
    namespace = spacings,
    processor = process,
}
