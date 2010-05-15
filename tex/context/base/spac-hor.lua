if not modules then modules = { } end modules ['spac-hor'] = {
    version   = 1.001,
    comment   = "companion to spac-hor.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match = string.match
local utfbyte = utf.byte
local chardata = characters.data

local can_have_space = table.tohash {
    "lu", "ll", "lt", "lm", "lo", -- letters
 -- "mn", "mc", "me",             -- marks
    "nd", "nl", "no",             -- numbers
    "ps", "pi",                   -- initial
 -- "pe", "pf",                   -- final
 -- "pc", "pd", "po",             -- punctuation
    "sm", "sc", "sk", "so",       -- symbols
 -- "zs", "zl", "zp",             -- separators
 -- "cc", "cf", "cs", "co", "cn", -- others
}

function commands.autonextspace(str) -- todo: use nexttoken
    local ch = match(str,"the letter (.)") or match(str,"the character (.)")
    ch = ch and chardata[utfbyte(ch)]
    if ch and can_have_space[ch.category] then
     -- texsprint(ctxcatcodes,"\\space") -- faster
        context.space()
    end
end
