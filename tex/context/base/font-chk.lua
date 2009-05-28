if not modules then modules = { } end modules ['font-chk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors

fonts              = fonts or { }
fonts.checkers     = fonts.checkers or { }

local checkers     = fonts.checkers
local fontdata     = fonts.ids
local is_character = characters.is_character
local chardata     = characters.data

local glyph        = node.id('glyph')
local traverse_id  = node.traverse_id

-- maybe in fonts namespace
-- deletion can be option

checkers.enabled = false
checkers.delete  = false

function fonts.register_message(font,char,message)
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
        logs.report("fonts","char U+%04X in font '%s' with id %s: %s",char,tfmdata.fullname,font,message)
        category[char] = true
    end
end

function checkers.missing(head,tail)
    if checkers.enabled then
        local lastfont, characters, found = nil, nil, nil
        for n in traverse_id(glyph,head) do
            local font, char = n.font, n.char
            if font ~= lastfont then
                characters = fontdata[font].characters
            end
            if not characters[char] and is_character[chardata[char].category] then
                if checkers.delete then
                    fonts.register_message(font,char,"missing (will be deleted)")
                else
                    fonts.register_message(font,char,"missing")
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
                local n = found[i]
                if n == tail then
                    head, tail = nodes.remove(head,n,true)
                else
                    head, _ = nodes.remove(head,n,true)
                end
            end
        end
    end
    return head, tail, false
end
