if not modules then modules = { } end modules ['char-tex'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg = lpeg

local find = string.find
local P, C, R, S, Cs, Cc = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cs, lpeg.Cc
local U, lpegmatch = lpeg.patterns.utf8, lpeg.match

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

characters       = characters or { }
local characters = characters
characters.tex   = characters.tex or { }

local accent_map = allocate {
   ['~'] = "̃" , --  ̃ Ẽ
   ['"'] = "̈" , --  ̈ Ë
   ["`"] = "̀" , --  ̀ È
   ["'"] = "́" , --  ́ É
   ["^"] = "̂" , --  ̂ Ê
    --  ̄ Ē
    --  ̆ Ĕ
    --  ̇ Ė
    --  ̉ Ẻ
    --  ̌ Ě
    --  ̏ Ȅ
    --  ̑ Ȇ
    --  ̣ Ẹ
    --  ̧ Ȩ
    --  ̨ Ę
    --  ̭ Ḙ
    --  ̰ Ḛ
}

local accents = table.concat(table.keys(accent_map))

local function remap_accents(a,c,braced)
    local m = accent_map[a]
    if m then
        return c .. m
    elseif braced then
        return "\\" .. a .. "{" .. c .. "}"
    else
        return "\\" .. a .. c
    end
end

local command_map = allocate {
    ["i"] = "ı"
}

local function remap_commands(c)
    local m = command_map[c]
    if m then
        return m
    else
        return "\\" .. c
    end
end

local accents  = (P('\\') * C(S(accents)) * (P("{") * C(U) * P("}" * Cc(true)) + C(U) * Cc(false))) / remap_accents
local commands = (P('\\') * C(R("az","AZ")^1)) / remap_commands

local convert_accents  = Cs((accents  + P(1))^0)
local convert_commands = Cs((commands + P(1))^0)

local no_l = P("{") / ""
local no_r = P("}") / ""

local convert_accents_strip  = Cs((no_l * accents  * no_r + accents  + P(1))^0)
local convert_commands_strip = Cs((no_l * commands * no_r + commands + P(1))^0)

function characters.tex.toutf(str,strip)
    if find(str,"\\") then -- we can start at the found position
        if strip then
            return lpegmatch(convert_accents_strip,lpegmatch(convert_commands_strip,str))
        else
            return lpegmatch(convert_accents,      lpegmatch(convert_commands,      str))
        end
    end
    return str
end

--~ print(characters.tex.toutf([[\"{e}]]),true)
--~ print(characters.tex.toutf([[{\"{e}}]],true))
