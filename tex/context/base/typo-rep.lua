if not modules then modules = { } end modules ['typo-rep'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This was rather boring to program (more of the same) but I could
-- endure it by listening to a couple cd's by The Scene and The Lau
-- on the squeezebox on my desk.

local trace_stripping = false  trackers.register("nodes.stripping",  function(v) trace_stripping = v end)
                               trackers.register("fonts.stripping",  function(v) trace_stripping = v end)

local report_stripping = logs.reporter("fonts","stripping")

local nodes, node = nodes, node

local delete_node   = nodes.delete
local replace_node  = nodes.replace
local copy_node     = node.copy

local chardata      = characters.data
local collected     = false
local a_stripping   = attributes.private("stripping")
local fontdata      = fonts.hashes.identifiers
local tasks         = nodes.tasks

local texattribute  = tex.attribute
local unsetvalue    = attributes.unsetvalue

local v_reset       = interfaces.variables.reset

local nodecodes     = nodes.nodecodes
local glyph_code    = nodecodes.glyph

-- todo: other namespace -> typesetters

nodes.stripping  = nodes.stripping  or { } local stripping  = nodes.stripping
stripping.glyphs = stripping.glyphs or { } local glyphs     = stripping.glyphs

local function initialize()
    for k,v in next, chardata do
        if v.category == "cf" and v.visible ~= "yes" then
            if not glyphs[k]  then
                glyphs[k] = true
            end
        end
    end
    initialize = nil
end

local function process(what,head,current,char)
    if what == true then
        if trace_stripping then
            report_stripping("deleting 0x%05X from text",char)
        end
        head, current = delete_node(head,current)
    elseif type(what) == "function" then
        head, current = what(head,current)
        current = current.next
        if trace_stripping then
            report_stripping("processing 0x%05X in text",char)
        end
    elseif what then  -- assume node
        head, current = replace_node(head,current,copy_node(what))
        current = current.next
        if trace_stripping then
            report_stripping("replacing 0x%05X in text",char)
        end
    end
    return head, current
end

function nodes.handlers.stripping(head)
    local current, done = head, false
    while current do
        if current.id == glyph_code then
            -- it's more efficient to keep track of what needs to be kept
            local todo = current[a_stripping]
            if todo == 1 then
                local char = current.char
                local what = glyphs[char]
                if what then
                    head, current = process(what,head,current,char)
                    done = true
                else -- handling of spacing etc has to be done elsewhere
                    current = current.next
                end
            else
                current = current.next
            end
        else
            current = current.next
        end
    end
    return head, done
end

local enabled = false

function stripping.set(n) -- number or 'reset'
    if n == v_reset then
        n = unsetvalue
    else
        n = tonumber(n)
        if n then
            if not enabled then
                if initialize then initialize() end
                tasks.enableaction("processors","nodes.handlers.stripping")
                enabled = true
            end
        else
            n = unsetvalue
        end
    end
    texattribute[a_stripping] = n
end

-- why not in task-ini?

tasks.appendaction("processors","fonts","nodes.handlers.stripping",nil,"nodes.handlers.characters")
tasks.disableaction("processors","nodes.handlers.stripping")

-- interface

commands.setcharacterstripping = stripping.set
