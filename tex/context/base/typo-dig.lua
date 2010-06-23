if not modules then modules = { } end modules ['typo-dig'] = {
    version   = 1.001,
    comment   = "companion to typo-dig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we might consider doing this after the otf pass because now osf do not work
-- out well in node mode.

local next, type = next, type
local format, insert = string.format, table.insert
local round, div = math.round, math.div

local trace_digits = false  trackers.register("typesetting.digits", function(v) trace_digits = v end)

local report_digits = logs.new("digits")

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

local fontdata = fonts.identifiers
local chardata = fonts.characters
local quaddata = fonts.quads
local charbase = characters.data

typesetting        = typesetting        or { }
typesetting.digits = typesetting.digits or { }

local digits = typesetting.digits

digits.actions   = { }
digits.attribute = attributes.private("digits")

local a_digits = digits.attribute

local actions  = digits.actions

-- at some point we can manipulate the glyph node so then i need
-- to rewrite this then

function nodes.aligned(head,start,stop,width,how)
    if how == "flushright" or how == "middle" then
        head, start = insert_before(head,start,new_glue(0,65536,65536))
    end
    if how == "flushleft" or how == "middle" then
        head, stop = insert_after(head,stop,new_glue(0,65536,65536))
    end
    local prv, nxt = start.prev, stop.next
    start.prev, stop.next = nil, nil
    local packed = hpack_node(start,width,"exactly") -- no directional mess here, just lr
    if prv then
        prv.next, packed.prev = packed, prv
    end
    if nxt then
        nxt.prev, packed.next = packed, nxt
    end
    if packed.prev then
        return head, packed
    else
        return packed, packed
    end
end

actions[1] = function(head,start,attribute,attr)
    local font = start.font
    local char = start.char
    local unic = chardata[font][char].tounicode
    local what = unic and tonumber(unic,16) or char
    if charbase[what].category == "nd" then
        local oldwidth, newwidth = start.width, fonts.get_digit_width(font)
        if newwidth ~= oldwidth then
            if trace_digits then
                report_digits("digit trigger %s, instance %s, char 0x%05X, unicode 0x%05X, delta %s",
                    attr%100,div(attr,100),char,what,newwidth-oldwidth)
            end
            head, start = nodes.aligned(head,start,start,newwidth,"middle")
            return head, start, true
        end
    end
    return head, start, false
end

local function process(namespace,attribute,head)
    local done, current, ok = false, head, false
    while current do
        if current.id == glyph then
            local attr = has_attribute(current,attribute)
            if attr and attr > 0 then
                unset_attribute(current,attribute)
                local action = actions[attr%100] -- map back to low number
                if action then
                    head, current, ok = action(head,current,attribute,attr)
                    done = done and ok
                elseif trace_digits then
                    report_digits("unknown digit trigger %s",attr)
                end
            end
        end
        current = current and current.next
    end
    return head, done
end

local m = 0 -- a trick to make neighbouring ranges work

function digits.set(n)
    if trace_digits then
        report_digits("enabling digit handler")
    end
    tasks.enableaction("processors","typesetting.digits.handler")
    function digits.set(n)
        if m == 100 then
            m = 1
        else
            m = m + 1
        end
        tex.attribute[a_digits] = m * 100 + n
    end
    digits.set(n)
end

digits.handler = nodes.install_attribute_handler {
    name      = "digits",
    namespace = digits,
    processor = process,
}
