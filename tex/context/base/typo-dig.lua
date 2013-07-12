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

local trace_digits = false  trackers.register("typesetters.digits", function(v) trace_digits = v end)

local report_digits = logs.reporter("typesetting","digits")

local nodes, node = nodes, node

local hpack_node         = node.hpack
local traverse_id        = node.traverse_id
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_glue           = nodepool.glue

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads

local v_reset            = interfaces.variables.reset

local charbase           = characters.data
local getdigitwidth      = fonts.helpers.getdigitwidth

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.digits       = typesetters.digits or { }
local digits             = typesetters.digits

digits.actions           = { }
local actions            = digits.actions

local a_digits           = attributes.private("digits")
digits.attribute         = a_digits

-- at some point we can manipulate the glyph node so then i need
-- to rewrite this then

function nodes.aligned(head,start,stop,width,how)
    if how == "flushright" or how == "middle" then
        head, start = insert_node_before(head,start,new_glue(0,65536,65536))
    end
    if how == "flushleft" or how == "middle" then
        head, stop = insert_node_after(head,stop,new_glue(0,65536,65536))
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
        local oldwidth, newwidth = start.width, getdigitwidth(font)
        if newwidth ~= oldwidth then
            if trace_digits then
                report_digits("digit trigger %a, instance %a, char %C, unicode %U, delta %s",
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
        if current.id == glyph_code then
            local attr = current[attribute]
            if attr and attr > 0 then
                current[attribute] = unsetvalue
                local action = actions[attr%100] -- map back to low number
                if action then
                    head, current, ok = action(head,current,attribute,attr)
                    done = done and ok
                elseif trace_digits then
                    report_digits("unknown digit trigger %a",attr)
                end
            end
        end
        current = current and current.next
    end
    return head, done
end

local m, enabled = 0, false -- a trick to make neighbouring ranges work

function digits.set(n) -- number or 'reset'
    if n == v_reset then
        n = unsetvalue
    else
        n = tonumber(n)
        if n then
            if not enabled then
                tasks.enableaction("processors","typesetters.digits.handler")
                if trace_digits then
                    report_digits("enabling digit handler")
                end
                enabled = true
            end
            if m == 100 then
                m = 1
            else
                m = m + 1
            end
            n = m * 100 + n
        else
            n = unsetvalue
        end
    end
    texsetattribute(a_digits,n)
end

digits.handler = nodes.installattributehandler { -- we could avoid this wrapper
    name      = "digits",
    namespace = digits,
    processor = process,
}

-- interface

commands.setdigitsmanipulation = digits.set
