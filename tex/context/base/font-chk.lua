if not modules then modules = { } end modules ['font-chk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors
-- move to the nodes namespace

local report_fonts = logs.reporter("fonts","checking")

local fonts        = fonts

fonts.checkers     = fonts.checkers or { }
local checkers     = fonts.checkers

local fontdata     = fonts.hashes.identifiers
local is_character = characters.is_character
local chardata     = characters.data
local tasks        = nodes.tasks

local glyph        = node.id('glyph')
local traverse_id  = node.traverse_id
local remove_node  = nodes.remove

-- maybe in fonts namespace
-- deletion can be option

checkers.enabled = false
checkers.delete  = false

-- to tfmdata.properties ?

local function onetimemessage(font,char,message)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared
    local messages = shared.messages
    if not messages then
        messages = { }
        shared.messages = messages
    end
    local category = messages[message]
    if not category then
        category = { }
        messages[message] = category
    end
    if not category[char] then
        report_fonts("char U+%04X in font '%s' with id %s: %s",char,tfmdata.properties.fullname,font,message)
        category[char] = true
    end
end

fonts.loggers.onetimemessage = onetimemessage

function checkers.missing(head)
    if checkers.enabled then
        local lastfont, characters, found = nil, nil, nil
        for n in traverse_id(glyph,head) do
            local font, char = n.font, n.char
            if font ~= lastfont then
                characters = fontdata[font].characters
            end
            if not characters[char] and is_character[chardata[char].category] then
                if checkers.delete then
                    onetimemessage(font,char,"missing (will be deleted)")
                else
                    onetimemessage(font,char,"missing")
                end
                if not found then
                    found = { n }
                else
                    found[#found+1] = n
                end
            end
        end
        if found and checkers.delete then
            for i=1,#found do
                head = remove_node(head,found[i],true)
            end
        end
    end
    return head, false
end

trackers.register("fonts.missing", function(v)
    tasks.enableaction("processors", "fonts.checkers.missing") -- always on then
    checkers.enabled = v
end)

function checkers.enable(delete)
    tasks.enableaction("processors", "fonts.checkers.missing") -- always on then
    if delete ~= nil then
        checkers.delete = delete
   end
   checkers.enabled = true
end

