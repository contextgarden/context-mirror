if not modules then modules = { } end modules ['char-cjk'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable = setmetatable
local insert = table.insert
local floor = math.floor
local format = string.format
local utfchar = utf.char

local ranges = characters.ranges

-- Hangul Syllable

-- The following conversion is taken from unicode.org/reports/tr15/tr15-23.html#Hangul
-- but adapted to our needs

local SBase = 0xAC00

local LBase, LCount = 0x1100, 19
local VBase, VCount = 0x1161, 21
local TBase, TCount = 0x11A7, 28

local NCount = VCount * TCount
local SCount = LCount * NCount

local L_TABLE = { [0] =
    "G", "GG", "N", "D", "DD", "R", "M", "B", "BB",
    "S", "SS", "", "J", "JJ", "C", "K", "T", "P", "H"
}

local V_TABLE = { [0] =
    "A", "AE", "YA", "YAE", "EO", "E", "YEO", "YE", "O",
    "WA", "WAE", "OE", "YO", "U", "WEO", "WE", "WI",
    "YU", "EU", "YI", "I"
}

local T_TABLE = { [0] =
    "", "G", "GG", "GS", "N", "NJ", "NH", "D", "L", "LG", "LM",
    "LB", "LS", "LT", "LP", "LH", "M", "B", "BS",
    "S", "SS", "NG", "J", "C", "K", "T", "P", "H"
}


local remapped = { -- this will be merged into char-def.lua
    [0x1100] = 0x3131, -- G
    [0x1101] = 0x3132, -- GG
    [0x1102] = 0x3134, -- N
    [0x1103] = 0x3137, -- D
    [0x1104] = 0x3138, -- DD
    [0x1105] = 0x3139, -- R
    [0X111A] = 0x3140, --
    [0x1106] = 0x3141, -- M
    [0x1107] = 0x3142, -- B
    [0x1108] = 0x3143, -- BB
    [0x1121] = 0x3144,
    [0x1109] = 0x3145, -- S
    [0x110A] = 0x3146, -- SS
    [0x110B] = 0x3147, -- (IEUNG)
    [0x110C] = 0x3148, -- J
    [0x110D] = 0x3149, -- JJ
    [0x110E] = 0x314A, -- C
    [0x110F] = 0x314B, -- K
    [0x1110] = 0x314C, -- T
    [0x1111] = 0x314D, -- P
    [0x1112] = 0x314E, -- H

    [0x1161] = 0x314F, -- A
    [0x1162] = 0x3150, -- AE
    [0x1163] = 0x3151, -- YA
    [0x1164] = 0x3152, -- YAE
    [0x1165] = 0x3153, -- EO
    [0x1166] = 0x3154, -- E
    [0x1167] = 0x3155, -- YEO
    [0x1168] = 0x3156, -- YE
    [0x1169] = 0x3157, -- O
    [0x116A] = 0x3158, -- WA
    [0x116B] = 0x3159, -- WAE
    [0x116C] = 0x315A, -- OE
    [0x116D] = 0x315B, -- YO
    [0x116E] = 0x315C, -- U
    [0x116F] = 0x315D, -- WEO
    [0x1170] = 0x315E, -- WE
    [0x1171] = 0x315F, -- WI
    [0x1172] = 0x3160, -- YU
    [0x1173] = 0x3161, -- EU
    [0x1174] = 0x3162, -- YI
    [0x1175] = 0x3163, -- I

    [0x11A7] = 0x3131, -- G
    [0x11A8] = 0x3132, -- GG
 -- [0x11A9] = 0x0000, -- GS
    [0x11AA] = 0x3134, -- N
 -- [0x11AB] = 0x0000, -- NJ
 -- [0x11AC] = 0x0000, -- NH
    [0x11AD] = 0x3137, -- D
 -- [0x11AE] = 0x0000, -- L
 -- [0x11AF] = 0x0000, -- LG
 -- [0x11B0] = 0x0000, -- LM
 -- [0x11B1] = 0x0000, -- LB
 -- [0x11B2] = 0x0000, -- LS
 -- [0x11B3] = 0x0000, -- LT
 -- [0x11B4] = 0x0000, -- LP
 -- [0x11B5] = 0x0000, -- LH
    [0x11B6] = 0x3141, -- M
    [0x11B7] = 0x3142, -- B
 -- [0x11B8] = 0x0000, -- BS
    [0x11B9] = 0x3145, -- S
 -- [0x11BA] = 0x0000, -- SS
 -- [0x11BB] = 0x0000, -- NG
    [0x11BC] = 0x3148, -- J
    [0x11BD] = 0x314A, -- C
    [0x11BE] = 0x314B, -- K
    [0x11BF] = 0x314C, -- T
    [0x11C0] = 0x314D, -- P
    [0x11C1] = 0x314E, -- H
}

local function decomposed(unicode)
    local SIndex = unicode - SBase
    if SIndex >= 0 and SIndex < SCount then
        local L = LBase + floor(SIndex / NCount)
        local V = VBase + floor((SIndex % NCount) / TCount)
        local T = TBase + SIndex % TCount
        if T ~= TBase then
            return L, V, T
        else
            return L, V
        end
    end
end

local function description(unicode)
    local SIndex = unicode - SBase
    if SIndex >= 0 and SIndex < SCount then
        local LIndex = floor(SIndex / NCount)
        local VIndex = floor((SIndex % NCount) / TCount)
        local TIndex = SIndex % TCount
        return format("HANGUL SYLLABLE %s%s%s",L_TABLE[LIndex],V_TABLE[VIndex],T_TABLE[TIndex])
    end
end

characters.hangul = {
    decomposed  = decomposed,
    description = description,
    remapped    = remapped,
}

-- so far

local hangul_syllable_basetable = {
    category    = "lo",
    cjkwd       = "w",
    description = "<Hangul Syllable>",
    direction   = "l",
    linebreak   = "h2",
}

local hangul_syllable_metatable = {
    __index = function(t,k)
        local u = t.unicodeslot
        if k == "fscode" then
            local fscode = -- firstsplitcode
               u  < 0xAC00 and nil    -- original
            or u  > 0xD7AF and nil    -- original
            or u >= 0xD558 and 0x314E -- 하 => ㅎ
            or u >= 0xD30C and 0x314D -- 파 => ㅍ
            or u >= 0xD0C0 and 0x314C -- 타 => ㅌ
            or u >= 0xCE74 and 0x314B -- 카 => ㅋ
            or u >= 0xCC28 and 0x314A -- 차 => ㅊ
            or u >= 0xC790 and 0x3148 -- 자 => ㅈ
            or u >= 0xC544 and 0x3147 -- 아 => ㅇ
            or u >= 0xC0AC and 0x3145 -- 사 => ㅅ
            or u >= 0xBC14 and 0x3142 -- 바 => ㅂ
            or u >= 0xB9C8 and 0x3141 -- 마 => ㅁ
            or u >= 0xB77C and 0x3139 -- 라 => ㄹ
            or u >= 0xB2E4 and 0x3137 -- 다 => ㄷ
            or u >= 0xB098 and 0x3134 -- 나 => ㄴ
            or u >= 0xAC00 and 0x3131 -- 가 => ㄱ -- was 0xAC20
            or                 nil    -- can't happen
            t[k] = fscode
            return fscode
        elseif k == "specials" then
            return { "char", decomposed(u) }
        elseif k == "description" then
            return description(u)
        else
            return hangul_syllable_basetable[k]-- no store
        end
    end
}

local hangul_syllable_extender = function(k,v)
    local t = {
        unicodeslot = k,
    }
    setmetatable(t,hangul_syllable_metatable)
    return t
end

local hangul_syllable_range = {
    first    = 0xAC00,
    last     = 0xD7A3,
    extender = hangul_syllable_extender,
}

setmetatable(hangul_syllable_range, hangul_syllable_metatable)

-- CJK Ideograph

local cjk_ideograph_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_metatable)
    return t
end

local cjk_ideograph_range = {
    first    = 0x4E00,
    last     = 0x9FBB,
    extender = cjk_ideograph_extender,
}

-- CJK Ideograph Extension A

local cjk_ideograph_extension_a_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph Extension A>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extension_a_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_extension_a_metatable)
    return t
end

local cjk_ideograph_extension_a_range = {
    first    = 0x3400,
    last     = 0x4DB5,
    extender = cjk_ideograph_extension_a_extender,
}

-- CJK Ideograph Extension B

local cjk_ideograph_extension_b_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph Extension B>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extension_b_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_extension_b_metatable)
    return t
end

local cjk_ideograph_extension_b_range = {
    first    = 0x20000,
    last     = 0x2A6D6,
    extender = cjk_ideograph_extension_b_extender,
}

-- Ranges

insert(ranges, hangul_syllable_range)
insert(ranges, cjk_ideograph_range)
insert(ranges, cjk_ideograph_extension_a_range)
insert(ranges, cjk_ideograph_extension_b_range)
