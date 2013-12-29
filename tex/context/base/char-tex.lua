if not modules then modules = { } end modules ['char-tex'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg = lpeg

local find = string.find
local P, C, R, S, V, Cs, Cc = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.V, lpeg.Cs, lpeg.Cc
local U, lpegmatch = lpeg.patterns.utf8, lpeg.match

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

characters       = characters or { }
local characters = characters
characters.tex   = characters.tex or { }

local accentmapping = allocate {
    ['"'] = { [""] = "¨",
        A = "Ä", a = "ä",
        E = "Ë", e = "ë",
        I = "Ï", i = "ï", ["ı"] = "ï", ["\\i"] = "ï",
        O = "Ö", o = "ö",
        U = "Ü", u = "ü",
        Y = "Ÿ", y = "ÿ",
    },
    ["'"] = { [""] = "´",
        A = "Á", a = "á",
        C = "Ć", c = "ć",
        E = "É", e = "é",
        I = "Í", i = "í", ["ı"] = "í", ["\\i"] = "í",
        L = "Ĺ", l = "ĺ",
        N = "Ń", n = "ń",
        O = "Ó", o = "ó",
        R = "Ŕ", r = "ŕ",
        S = "Ś", s = "ś",
        U = "Ú", u = "ú",
        Y = "Ý", y = "ý",
        Z = "Ź", z = "ź",
    },
    ["."] = { [""] = "˙",
        C = "Ċ", c = "ċ",
        E = "Ė", e = "ė",
        G = "Ġ", g = "ġ",
        I = "İ", i = "i", ["ı"] = "i", ["\\i"] = "i",
        Z = "Ż", z = "ż",
    },
    ["="] = { [""] = "¯",
        A = "Ā", a = "ā",
        E = "Ē", e = "ē",
        I = "Ī", i = "ī", ["ı"] = "ī", ["\\i"] = "ī",
        O = "Ō", o = "ō",
        U = "Ū", u = "ū",
    },
    ["H"] = { [""] = "˝",
        O = "Ő", o = "ő",
        U = "Ű", u = "ű",
    },
    ["^"] = { [""] = "ˆ",
        A = "Â", a = "â",
        C = "Ĉ", c = "ĉ",
        E = "Ê", e = "ê",
        G = "Ĝ", g = "ĝ",
        H = "Ĥ", h = "ĥ",
        I = "Î", i = "î", ["ı"] = "î", ["\\i"] = "î",
        J = "Ĵ", j = "ĵ",
        O = "Ô", o = "ô",
        S = "Ŝ", s = "ŝ",
        U = "Û", u = "û",
        W = "Ŵ", w = "ŵ",
        Y = "Ŷ", y = "ŷ",
    },
    ["`"] = { [""] = "`",
        A = "À", a = "à",
        E = "È", e = "è",
        I = "Ì", i = "ì", ["ı"] = "ì", ["\\i"] = "ì",
        O = "Ò", o = "ò",
        U = "Ù", u = "ù",
        Y = "Ỳ", y = "ỳ",
    },
    ["c"] = { [""] = "¸",
        C = "Ç", c = "ç",
        K = "Ķ", k = "ķ",
        L = "Ļ", l = "ļ",
        N = "Ņ", n = "ņ",
        R = "Ŗ", r = "ŗ",
        S = "Ş", s = "ş",
        T = "Ţ", t = "ţ",
    },
    ["k"] = { [""] = "˛",
        A = "Ą", a = "ą",
        E = "Ę", e = "ę",
        I = "Į", i = "į",
        U = "Ų", u = "ų",
    },
    ["r"] = { [""] = "˚",
        A = "Å", a = "å",
        U = "Ů", u = "ů",
    },
    ["u"] = { [""] = "˘",
        A = "Ă", a = "ă",
        E = "Ĕ", e = "ĕ",
        G = "Ğ", g = "ğ",
        I = "Ĭ", i = "ĭ", ["ı"] = "ĭ", ["\\i"] = "ĭ",
        O = "Ŏ", o = "ŏ",
        U = "Ŭ", u = "ŭ",
        },
    ["v"] = { [""] = "ˇ",
        C = "Č", c = "č",
        D = "Ď", d = "ď",
        E = "Ě", e = "ě",
        L = "Ľ", l = "ľ",
        N = "Ň", n = "ň",
        R = "Ř", r = "ř",
        S = "Š", s = "š",
        T = "Ť", t = "ť",
        Z = "Ž", z = "ž",
        },
    ["~"] = { [""] = "˜",
        A = "Ã", a = "ã",
        I = "Ĩ", i = "ĩ", ["ı"] = "ĩ", ["\\i"] = "ĩ",
        N = "Ñ", n = "ñ",
        O = "Õ", o = "õ",
        U = "Ũ", u = "ũ",
    },
}

characters.tex.accentmapping = accentmapping

local accent_map = allocate { -- incomplete
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

-- local accents = table.concat(table.keys(accentmapping)) -- was _map

local function remap_accent(a,c,braced)
    local m = accentmapping[a]
    if m then
        local n = m[c]
        if n then
            return n
        end
    end
--     local m = accent_map[a]
--     if m then
--         return c .. m
--     elseif braced then -- or #c > 0
    if braced then -- or #c > 0
        return "\\" .. a .. "{" .. c .. "}"
    else
        return "\\" .. a .. " " .. c
    end
end

local command_map = allocate {
    ["i"]  = "ı",
    ["l"]  = "ł",
    ["ss"] = "ß",
    ["ae"] = "æ",
    ["AE"] = "Æ",
    ["oe"] = "œ",
    ["OE"] = "Œ",
    ["o"]  = "ø",
    ["O"]  = "Ø",
    ["aa"] = "å",
    ["AA"] = "Å",
}

-- no need for U here

local achar    = R("az","AZ") + P("ı") + P("\\i")

local spaces   = P(" ")^0
local no_l     = P("{") / ""
local no_r     = P("}") / ""
local no_b     = P('\\') / ""

local lUr      = P("{") * C(achar) * P("}")

local accents_1 = [["'.=^`~]]
local accents_2 = [[Hckruv]]

local accent   = P('\\') * (
    C(S(accents_1)) * (lUr * Cc(true) + C(achar) * Cc(false)) + -- we need achar for ı etc, could be sped up
    C(S(accents_2)) *  lUr * Cc(true)
) / remap_accent

local csname  = P('\\') * C(R("az","AZ")^1)

local command  = (
    csname +
    P("{") * csname * spaces * P("}")
) / command_map -- remap_commands

local both_1 = Cs { "run",
    accent  = accent,
    command = command,
    run     = (V("accent") + no_l * V("accent") * no_r + V("command") + P(1))^0,
}

local both_2 = Cs { "run",
    accent  = accent,
    command = command,
    run     = (V("accent") + V("command") + no_l * ( V("accent") + V("command") ) * no_r + P(1))^0,
}

function characters.tex.toutf(str,strip)
    if not find(str,"\\") then
        return str
    elseif strip then
        return lpegmatch(both_1,str)
    else
        return lpegmatch(both_2,str)
    end
end

-- print(characters.tex.toutf([[\~{Z}]],true))
-- print(characters.tex.toutf([[\'\i]],true))
-- print(characters.tex.toutf([[\'{\i}]],true))
-- print(characters.tex.toutf([[\"{e}]],true))
-- print(characters.tex.toutf([[\" {e}]],true))
-- print(characters.tex.toutf([[{\"{e}}]],true))
-- print(characters.tex.toutf([[{\" {e}}]],true))
-- print(characters.tex.toutf([[{\l}]],true))
-- print(characters.tex.toutf([[{\l }]],true))
-- print(characters.tex.toutf([[\v{r}]],true))
-- print(characters.tex.toutf([[fo{\"o}{\ss}ar]],true))
-- print(characters.tex.toutf([[H{\'a}n Th\^e\llap{\raise 0.5ex\hbox{\'{\relax}}} Th{\'a}nh]],true))

function characters.tex.defineaccents()
    for accent, group in next, accentmapping do
        context.dodefineaccentcommand(accent)
        for character, mapping in next, group do
            context.dodefineaccent(accent,character,mapping)
        end
    end
end
