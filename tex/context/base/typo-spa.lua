if not modules then modules = { } end modules ['typo-spa'] = {
    version   = 1.001,
    comment   = "companion to typo-spa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local next, type = next, type
local utfchar = utf.char

local trace_hspacing     = false  trackers.register("nodes.hspacing",      function(v) trace_hspacing      = v end)

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove
local make_penalty_node  = nodes.penalty
local make_glue_node     = nodes.glue
local glyph              = node.id("glyph")
local fontdata           = fonts.ids

spacings           = spacings         or { }
spacings.mapping   = spacings.mapping or { }
spacings.attribute = attributes.private("spacing")

storage.register("spacings/mapping", spacings.mapping, "spacings.mapping")

function spacings.setspacing(id,char,left,right,alternative)
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

function spacings.process(namespace,attribute,head)
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
                        local quad = fontdata[start.font].parameters.quad
                        local prev = start.prev
                        if left and left ~= 0 and prev then
                            local ok = false
                            if alternative == 1 then
                                local somespace = nodes.somespace(prev,true)
                                if somespace then
                                    local prevprev = prev.prev
                                    local somepenalty = nodes.somepenalty(prevprev,10000)
                                    if somepenalty then
                                        if trace_hspacing then
                                            logs.report("spacing","removing penalty and space before %s", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,prev,true)
                                        head, _ = remove_node(head,prevprev,true)
                                    else
                                        local somespace = nodes.somespace(prev,true)
                                        if somespace then
                                            if trace_hspacing then
                                                logs.report("spacing","removing space before %s", utfchar(start.char))
                                            end
                                            head, _ = remove_node(head,prev,true)
                                        end
                                    end
                                end
                                ok = true
                            else
                                ok = not (nodes.somespace(prev,true) and nodes.somepenalty(prev.prev,true)) or nodes.somespace(prev,true)
                            end
                            if ok then
                                if trace_hspacing then
                                    logs.report("spacing","inserting penalty and space before %s", utfchar(start.char))
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
                                        if trace_hspacing then
                                            logs.report("spacing","removing penalty and space after %s", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,next,true)
                                        head, _ = remove_node(head,nextnext,true)
                                    end
                                else
                                    local somespace = nodes.somespace(next,true)
                                    if somespace then
                                        if trace_hspacing then
                                            logs.report("spacing","removing space after %s", utfchar(start.char))
                                        end
                                        head, _ = remove_node(head,next,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (nodes.somepenalty(next,10000) and nodes.somespace(next.next,true)) or nodes.somespace(next,true)
                            end
                            if ok then
                                if trace_hspacing then
                                    logs.report("spacing","inserting penalty and space after %s", utfchar(start.char))
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

lists.handle_spacing = nodes.install_attribute_handler {
    name      = "spacing",
    namespace = spacings,
    processor = spacings.process,
}

function spacings.enable()
    tasks.enableaction("processors","lists.handle_spacing")
end

--~ local data = {
--~     name      = "spacing",
--~     namespace = spacings,
--~     processor = spacings.process,
--~ }
--~ nodes.process_attribute = process_attribute
--~ function lists.handle_spacing(head)
--~     return process_attribute(head,data)
--~ end
