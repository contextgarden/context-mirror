if not modules then modules = { } end modules ['char-tex'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

characters     = characters or { }
characters.tex = characters.tex or { }

local find = string.find

local accent_map = {
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

local command_map = {
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

local P, C, R, S, Cs, Cc = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cs, lpeg.Cc
local U, lpegmatch = lpeg.utf8, lpeg.match

local accents  = (P('\\') * C(S(accents)) * (P("{") * C(U) * P("}" * Cc(true)) + C(U) * Cc(false))) / remap_accents
local commands = (P('\\') * C(R("az","AZ")^1)) / remap_commands

local convert_accents  = Cs((accents  + P(1))^0)
local convert_commands = Cs((commands + P(1))^0)

function characters.tex.toutf(str)
    if find(str,"\\") then
        str = lpegmatch(convert_commands,str)
        str = lpegmatch(convert_accents,str)
    end
    return str
end
