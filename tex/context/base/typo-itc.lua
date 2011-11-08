if not modules then modules = { } end modules ['typo-itc'] = {
    version   = 1.001,
    comment   = "companion to typo-itc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfchar = utf.char

local trace_italics       = false  trackers.register("typesetters.italics", function(v) trace_italics = v end)

local report_italics      = logs.reporter("nodes","italics")

typesetters.italics       = typesetters.italics or { }
local italics             = typesetters.italics

local nodecodes           = nodes.nodecodes
local glyph_code          = nodecodes.glyph
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local disc_code           = nodecodes.disc

local tasks               = nodes.tasks

local insert_node_after   = node.insert_after
local delete_node         = nodes.delete
local has_attribute       = node.has_attribute

local texattribute        = tex.attribute
local a_italics           = attributes.private("italics")
local unsetvalue          = attributes.unsetvalue

local new_correction_kern = nodes.pool.fontkern
local new_correction_glue = nodes.pool.glue

local points              = number.points

local fonthashes          = fonts.hashes
local fontdata            = fonthashes.identifiers
local italicsdata         = fonthashes.italics

local forcedvariant       = false

function typesetters.italics.forcevariant(variant)
    forcedvariant = variant
end

local function setitalicinfont(font,char)
    local tfmdata = fontdata[font]
    local character = tfmdata.characters[char]
    if character then
        local italic = character.italic_correction
        if not italic then
            local autoitalicamount = tfmdata.properties.autoitalicamount or 0
            if autoitalicamount ~= 0 then
                local description = tfmdata.descriptions[char]
                if description then
                    italic = description.italic
                    if not italic then
                        local boundingbox = description.boundingbox
                        italic = boundingbox[3] - description.width + autoitalicamount
                        if italic < 0 then -- < 0 indicates no overshoot or a very small auto italic
                            italic = 0
                        end
                    end
                    if italic ~= 0 then
                        italic = italic * tfmdata.parameters.hfactor
                    end
                end
            end
            if trace_italics then
                report_italics("setting italic correction of %s (U+%05X) of font %s to %s",utfchar(char),char,font,points(italic))
            end
            character.italic_correction = italic or 0
        end
        return italic
    else
        return 0
    end
end

-- todo: clear attribute

local function process(namespace,attribute,head)
    local done     = false
    local italic   = 0
    local lastfont = nil
    local lastattr = nil
    local previous = nil
    local prevchar = nil
    local current  = head
    local inserted = nil
    while current do
        local id = current.id
        if id == glyph_code then
            local font = current.font
            local char = current.char
            local data = italicsdata[font]
            if font ~= lastfont then
                if italic ~= 0 then
                    if data then
                        if trace_italics then
                            report_italics("ignoring %s between italic %s and italic %s",points(italic),utfchar(prevchar),utfchar(char))
                        end
                    else
                        if trace_italics then
                            report_italics("inserting %s between italic %s and regular %s",points(italic),utfchar(prevchar),utfchar(char))
                        end
                        insert_node_after(head,previous,new_correction_kern(italic))
                        done = true
                    end
                elseif inserted and data then
                    if trace_italics then
                        report_italics("deleting last correction before %s",utfchar(char))
                    end
                    delete_node(head,inserted)
                else
                    -- nothing
                end
                lastfont = font
            end
            if data then
                local attr = forcedvariant or has_attribute(current,attribute)
                if attr and attr > 0 then
                    local cd = data[char]
                    if not cd then
                        -- this really can happen
                        italic = 0
                    else
                        italic = cd.italic or cd.italic_correction
                        if not italic then
                            italic = setitalicinfont(font,char) -- calculated once
                         -- italic = 0
                        end
                        if italic ~= 0 then
                            lastfont = font
                            lastattr = attr
                            previous = current
                            prevchar = char
                        end
                    end
                else
                    italic = 0
                end
            else
                italic = 0
            end
            inserted = nil
        elseif id == disc_code then
            -- skip
        elseif id == kern_code then
            inserted = nil
            italic = 0
        elseif id == glue_code then
            if italic ~= 0 then
                if trace_italics then
                    report_italics("inserting %s between italic %s and glue",points(italic),utfchar(prevchar))
                end
                inserted = new_correction_glue(italic) -- maybe just add ? else problem with penalties
                insert_node_after(head,previous,inserted)
                italic = 0
                done = true
            end
        elseif italic ~= 0 then
            if trace_italics then
                report_italics("inserting %s between italic %s and whatever",points(italic),utfchar(prevchar))
            end
            inserted = nil
            insert_node_after(head,previous,new_correction_kern(italic))
            italic = 0
            done = true
        end
        current = current.next
    end
    if italic ~= 0 and lastattr > 1 then -- more control is needed here
        if trace_italics then
            report_italics("inserting %s between italic %s and end of list",points(italic),utfchar(prevchar))
        end
        insert_node_after(head,previous,new_correction_kern(italic))
        done = true
    end
    return head, done
end

local enable

enable = function()
    tasks.enableaction("processors","typesetters.italics.handler")
    if trace_italics then
        report_italics("enabling text italics")
    end
    enable = false
end

function italics.set(n)
    if enable then
        enable()
    end
    if n == variables.reset then
        texattribute[a_italics] = unsetvalue
    else
        texattribute[a_italics] = tonumber(n) or unsetvalue
    end
end

function italics.reset()
    texattribute[a_italics] = unsetvalue
end

italics.handler = nodes.installattributehandler {
    name      = "italics",
    namespace = italics,
    processor = process,
}

local variables        = interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash

function commands.setupitaliccorrection(option) -- no grouping !
    if enable then
        enable()
    end
    local options = settings_to_hash(option)
    local variant = unsetvalue
    if options[variables.text] then
        variant = 1
    elseif options[variables.always] then
        variant = 2
    end
    if options[variables.global] then
        forcedvariant = variant
        texattribute[a_italics] = unsetvalue
    else
        forcedvariant = false
        texattribute[a_italics] = variant
    end
    if trace_italics then
        report_italics("force: %s, variant: %s",tostring(forcedvariant),tostring(variant ~= unsetvalue and variant))
    end
end

-- for manuals:

local stack = { }

function commands.pushitaliccorrection()
    table.insert(stack,{forcedvariant, texattribute[a_italics] })
end

function commands.popitaliccorrection()
    local top = table.remove(stack)
    forcedvariant = top[1]
    texattribute[a_italics] = top[2]
end
