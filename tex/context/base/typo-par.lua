if not modules then modules = { } end modules ['typo-par'] = {
    version   = 1.001,
    comment   = "companion to typo-par.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A playground for experiments.

local utfbyte = utf.byte
local utfchar = utf.char

local trace_paragraphs  = false  trackers.register("typesetters.paragraphs",        function(v) trace_paragraphs = v end)
local trace_dropper     = false  trackers.register("typesetters.paragraphs.dropper",function(v) trace_dropper    = v end)

local report_paragraphs = logs.reporter("nodes","paragraphs")
local report_dropper    = logs.reporter("nodes","dropped")

typesetters.paragraphs  = typesetters.paragraphs or { }
local paragraphs        = typesetters.paragraphs

local nodecodes         = nodes.nodecodes
local whatsitcodes      = nodes.whatsitcodes
local tasks             = nodes.tasks

local variables         = interfaces.variables

local texattribute      = tex.attribute
local unsetvalue        = attributes.unsetvalue

local glyph_code        = nodecodes.glyph
local hlist_code        = nodecodes.hlist
local kern_node         = nodecodes.kern
local whatsit_code      = nodecodes.whatsit
local localpar_code     = whatsitcodes.localpar

local a_paragraph       = attributes.private("paragraphspecial")
local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colorspace      = attributes.private('colormodel')

local dropper = {
    enabled  = false,
 -- font     = 0,
 -- n        = 0,
 -- distance = 0,
 -- hoffset  = 0,
 -- voffset  = 0,
}

local droppers = { }

typesetters.paragraphs.droppers = droppers

function droppers.set(specification)
    dropper = specification or { }
end

function droppers.freeze()
    if dropper.enabled then
        dropper.font = font.current()
    end
end

-- dropped caps experiment (will be done properly when luatex
-- stores the state in the local par node) .. btw, search still
-- works with dropped caps, as does an export

-- we need a 'par' attribute and in fact for dropped caps we don't need
-- need an attribute ... dropit will become s state counter (or end up
-- in the localpar user data

-- for the moment, each paragraph gets a number as id (attribute) ..problem
-- with nesting .. or anyhow, needed for tagging anyway

-- todo: prevent linebreak .. but normally a dropper ends up atthe top of
-- a page so this has a low priority

local function process(namespace,attribute,head)
    local done = false
    if head.id == whatsit_code and head.subtype == localpar_code then
        -- begin of par
        local a = head[attribute]
        if a and a > 0 then
            if dropper.enabled then
                dropper.enabled = false -- dangerous for e.g. nested || in tufte
                local first = head.next
                if first and first.id == hlist_code then
                    -- parbox .. needs to be set at 0
                    first = first.next
                end
                if first and first.id == glyph_code then
-- if texattribute[a_paragraph] >= 0 then
--     texattribute[a_paragraph] = unsetvalue
-- end
                    local char = first.char
                    local prev = first.prev
                    local next = first.next
                 -- if prev.id == hlist_code then
                 --     -- set the width to 0
                 -- end
                    if next and next.id == kern_node then
                        next.kern = 0
                    end
                    first.font = dropper.font or first.font
                    -- can be a helper
                    local ma = dropper.ma or 0
                    local ca = dropper.ca
                    local ta = dropper.ta
                    if ca and ca > 0 then
                        first[a_colorspace] = ma == 0 and 1 or ma
                        first[a_color] = ca
                    end
                    if ta and ta > 0 then
                        first[a_transparency] = ta
                    end
                    --
                    local width  = first.width
                    local height = first.height
                    local depth  = first.depth
                    local distance = dropper.distance or 0
                    local voffset = dropper.voffset or 0
                    local hoffset = dropper.hoffset or 0
                    first.xoffset = - width  - hoffset - distance
                    first.yoffset = - height - voffset
                    if true then
                        -- needed till we can store parindent with localpar
                        first.prev = nil
                        first.next = nil
                        local h = node.hpack(first)
                        h.width = 0
                        h.height = 0
                        h.depth = 0
                        prev.next = h
                        next.prev = h
                        h.next = next
                        h.prev = prev
                    end
                    if dropper.location == variables.margin then
                        -- okay
                    else
                        local lines = tonumber(dropper.n) or 0
                        if lines == 0 then -- safeguard, not too precise
                            lines = math.ceil((height+voffset) / tex.baselineskip.width)
                        end
                        tex.hangafter  = - lines
                        tex.hangindent = width + distance
                    end
                    done = true
                end
            end
        end
    end
    return head, done
end

local enabled = false

function paragraphs.set(n)
    if n == variables.reset or not tonumber(n) or n == 0 then
        texattribute[a_paragraph] = unsetvalue
    else
        if not enabled then
            tasks.enableaction("processors","typesetters.paragraphs.handler")
            if trace_paragraphs then
                report_paragraphs("enabling paragraphs")
            end
            enabled = true
        end
        texattribute[a_paragraph] = n
    end
end

paragraphs.attribute = a_paragraph

paragraphs.handler = nodes.installattributehandler {
    name      = "paragraphs",
    namespace = paragraphs,
    processor = process,
}
