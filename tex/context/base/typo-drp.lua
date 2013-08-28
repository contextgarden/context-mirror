if not modules then modules = { } end modules ['typo-drp'] = {
    version   = 1.001,
    comment   = "companion to typo-drp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This ons is sensitive for order (e.g. when combined with first line
-- processing.

local tonumber, type, next = tonumber, type, next
local ceil = math.ceil

local utfbyte = utf.byte
local utfchar = utf.char

local trace_initials    = false  trackers.register("typesetters.initials", function(v) trace_initials = v end)
local report_initials   = logs.reporter("nodes","initials")

local initials          = typesetters.paragraphs or { }
typesetters.initials    = initials or { }

local nodes             = nodes
local tasks             = nodes.tasks

local hpack_nodes       = nodes.hpack
local nodecodes         = nodes.nodecodes
local whatsitcodes      = nodes.whatsitcodes

local nodepool          = nodes.pool
local new_kern          = nodepool.kern

local insert_before     = nodes.insert_before
local insert_after      = nodes.insert_after

local variables         = interfaces.variables
local v_default         = variables.default
local v_margin          = variables.margin

local texget            = tex.get
local texsetattribute   = tex.setattribute
local unsetvalue        = attributes.unsetvalue

local glyph_code        = nodecodes.glyph
local hlist_code        = nodecodes.hlist
local kern_node         = nodecodes.kern
local whatsit_code      = nodecodes.whatsit
local localpar_code     = whatsitcodes.localpar

local actions           = { }
initials.actions        = actions

local a_initial         = attributes.private("initial")
local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colorspace      = attributes.private('colormodel')

local settings          = nil

function initials.set(specification)
    settings = specification or { }
    settings.enabled = true
    tasks.enableaction("processors","typesetters.initials.handler")
    if trace_initials then
        report_initials("enabling initials")
    end
    texsetattribute(a_initial,1)
end

commands.setinitial = initials.set

-- dropped caps experiment (will be done properly when luatex
-- stores the state in the local par node) .. btw, search still
-- works with dropped caps, as does an export

-- we need a 'par' attribute and in fact for dropped caps we don't need
-- need an attribute ... dropit will become s state counter (or end up
-- in the localpar user data

-- for the moment, each paragraph gets a number as id (attribute) ..problem
-- with nesting .. or anyhow, needed for tagging anyway

-- todo: prevent linebreak .. but normally a initial ends up at the top of
-- a page so this has a low priority

actions[v_default] = function(head,setting)
    local done = false
    if head.id == whatsit_code and head.subtype == localpar_code then
        -- begin of par
        local first = head.next
        -- parbox .. needs to be set at 0
        if first and first.id == hlist_code then
            first = first.next
        end
        -- we need to skip over kerns and glues (signals)
        while first and first.id ~= glyph_code do
            first = first.next
        end
        if first and first.id == glyph_code then
            local char = first.char
            local prev = first.prev
            local next = first.next
         -- if prev.id == hlist_code then
         --     -- set the width to 0
         -- end
            if next and next.id == kern_node then
                next.kern = 0
            end
            if setting.font then
                first.font = setting.font
            end
            if setting.dynamic > 0 then
                first[0] = setting.dynamic
            end
            -- can be a helper
            local ma = setting.ma or 0
            local ca = setting.ca
            local ta = setting.ta
            if ca and ca > 0 then
                first[a_colorspace] = ma == 0 and 1 or ma
                first[a_color] = ca
            end
            if ta and ta > 0 then
                first[a_transparency] = ta
            end
            --
            local width     = first.width
            local height    = first.height
            local depth     = first.depth
            local distance  = setting.distance or 0
            local voffset   = setting.voffset or 0
            local hoffset   = setting.hoffset or 0
            local parindent = tex.parindent
            local baseline  = texget("baselineskip").width
            local lines     = tonumber(setting.n) or 0
            --
            first.xoffset   = - width  - hoffset - distance - parindent
            first.yoffset   = - voffset -- no longer - height here 
            -- We pack so that successive handling cannot touch the dropped cap. Packaging
            -- in a hlist is also needed because we cannot locally adapt e.g. parindent (not
            -- yet stored in with localpar).
            first.prev = nil
            first.next = nil
            local h = hpack_nodes(first)
            h.width = 0
            h.height = 0
            h.depth = 0
            prev.next = h
            next.prev = h
            h.next = next
            h.prev = prev

            -- end of packaging
            if setting.location == v_margin then
                -- okay
            else
                if lines == 0 then -- safeguard, not too precise
                    lines = ceil((height+voffset) / baseline)
                end
                -- We cannot set parshape yet ... when we can I'll add a slope
                -- option (positive and negative, in emwidth).
                local hangafter  = - lines
                local hangindent = width + distance + parindent
                if trace_initials then
                    report_initials("setting hangafter to %i and hangindent to %p",hangafter,hangindent)
                end
                tex.hangafter  = hangafter
                tex.hangindent = hangindent
                if parindent ~= 0 then
                    insert_after(first,first,new_kern(-parindent))
                end
            end
            done = true
        end
    end
    return head, done
end

local function process(namespace,attribute,head)
    local start = head
    local attr  = nil
    while start do
        attr = start[attribute]
        if attr then
            break
        elseif start.id == glyph then
            break
        else
            start = start.next
        end
    end
    if attr then
        -- here as we can process nested boxes first so we need to keep state
        tasks.disableaction("processors","typesetters.initials.handler")
     -- texsetattribute(attribute,unsetvalue)
        local alternative = settings.alternative or v_default
        local action = actions[alternative] or actions[v_default]
        if action then
            if trace_initials then
                report_initials("processing initials, alternative %a",alternative)
            end
            local head, done = action(head,settings)
            return head, done
        end
    end
    return head, false
end

initials.attribute = a_initial

initials.handler = nodes.installattributehandler {
    name      = "initials",
    namespace = initials,
    processor = process,
}
