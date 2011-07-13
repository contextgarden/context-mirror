if not modules then modules = { } end modules ['font-chk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors
-- move to the nodes namespace

local report_fonts   = logs.reporter("fonts","checking")

local fonts          = fonts

fonts.checkers       = fonts.checkers or { }
local checkers       = fonts.checkers

local fonthashes     = fonts.hashes
local fontdata       = fonthashes.identifiers
local fontcharacters = fonthashes.characters

local is_character   = characters.is_character
local chardata       = characters.data

local tasks          = nodes.tasks
local enableaction   = tasks.enableaction
local disableaction  = tasks.disableaction

local glyph          = node.id('glyph')
local traverse_id    = node.traverse_id
local remove_node    = nodes.remove

-- maybe in fonts namespace
-- deletion can be option

local cleanup = false

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
        report_fonts("char U+%05X in font '%s' with id %s: %s",char,tfmdata.properties.fullname,font,message)
        category[char] = true
    end
end

fonts.loggers.onetimemessage = onetimemessage

function checkers.missing(head)
    local lastfont, characters, found = nil, nil, nil
    for n in traverse_id(glyph,head) do
        local font = n.font
        local char = n.char
        if font ~= lastfont then
            characters = fontcharacters[font]
        end
        if not characters[char] and is_character[chardata[char].category] then
            if cleanup then
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
    if found and cleanup then
        for i=1,#found do
            head = remove_node(head,found[i],true)
        end
    end
    return head, false
end

trackers.register("fonts.missing", function(v)
    if v then
        enableaction("processors","fonts.checkers.missing")
    else
        disableaction("processors","fonts.checkers.missing")
    end
    cleanup = v == "remove"
end)

function commands.checkcharactersinfont()
    enableaction("processors","fonts.checkers.missing")
end

function commands.removemissingcharacters()
    enableaction("processors","fonts.checkers.missing")
    cleanup = true
end
