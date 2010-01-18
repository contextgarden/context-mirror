if not modules then modules = { } end modules ['typo-dig'] = {
    version   = 1.001,
    comment   = "companion to typo-dig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, insert = string.format, table.insert

local trace_digits = false  trackers.register("nodes.digits", function(v) trace_digits = v end)

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local hpack_node         = node.hpack
local traverse_id        = node.traverse_id
local insert_before      = node.insert_before
local insert_after       = node.insert_after

local glyph = node.id("glyph")
local kern  = node.id("kern")

local new_glue = nodes.glue

local fontdata = fonts.ids
local chardata = characters.data

digits           = digits or { }
digits.actions   = { }
digits.attribute = attributes.private("digits")

local actions  = digits.actions

-- at some point we can manipulate the glyph node so then i need
-- to rewrite this

function nodes.aligned(start,stop,width,how)
    local prv, nxt, head = start.prev, stop.next, nil
    start.prev, stop.next = nil, nil
    if how == "flushright" or how == "middle" then
        head, start = insert_before(start,start,new_glue(0,65536,65536))
    end
    if how == "flushleft" or how == "middle" then
        head, stop = insert_after(start,stop,new_glue(0,65536,65536))
    end
    local packed = hpack_node(start,width,"exactly") -- no directional mess here, just lr
    if prv then
        prv.next, packed.prev = packed, prv
    end
    if nxt then
        nxt.prev, packed.next = packed, nxt
    end
    return packed, prv, nxt
end

actions[1] = function(start,attribute)
    local char = start.char
    if chardata[char].category == "nd" then
        local fdf = fontdata[start.font]
        local oldwidth, newwidth = fdf.characters[char].width, fdf.parameters.quad/2
        if newwidth ~= oldwidth then
            local start = nodes.aligned(start,start,newwidth,"middle") -- return three node pointers
            return start, true
        end
    end
    return start, false
end

function digits.process(namespace,attribute,head)
    local done, current, ok = false, head, false
    while current do
        if current.id == glyph then
            local attr = has_attribute(current,attribute)
            if attr and attr > 0 then
                unset_attribute(current,attribute)
                local action = actions[attr]
                if action then
                    if current == head then
                        head, ok = action(current,attribute)
                        current = head
                    else
                        current, ok = action(current,attribute)
                    end
                    done = done and ok
                end
            end
        end
        current = current and current.next
    end
    return head, done
end

chars.handle_digits = nodes.install_attribute_handler {
    name = "digits",
    namespace = digits,
    processor = digits.process,
}

function digits.enable()
    tasks.enableaction("processors","chars.handle_digits")
end
