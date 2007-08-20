if not modules then modules = { } end modules ['char-con'] = {
    version   = 1.001,
    comment   = "companion to core-con.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module implements a bunch of conversions. Some are more
efficient than their <l n='tex'/> counterpart, some are even
slower but look nicer this way.</p>

<p>Some code may move to a module in the language namespace.</p>
--ldx]]--

converters = converters or { }
languages  = languages  or { }

languages.counters = {
    ['**'] = {
        0x0061, 0x0062, 0x0063, 0x0064, 0x0065,
        0x0066, 0x0067, 0x0068, 0x0069, 0x006A,
        0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
        0x0070, 0x0071, 0x0072, 0x0073, 0x0074,
        0x0075, 0x0076, 0x0077, 0x0078, 0x0079,
        0x007A
    },
    ['sl'] = {
        0x0061, 0x0062, 0x0063, 0x010D, 0x0064,
        0x0065, 0x0066, 0x0067, 0x0068, 0x0069,
        0x006A, 0x006B, 0x006C, 0x006D, 0x006E,
        0x006F, 0x0070, 0x0072, 0x0073, 0x0161,
        0x0074, 0x0075, 0x0076, 0x007A, 0x017E
    },
    ['gr'] = {
        0x0391, 0x0392, 0x0393, 0x0394, 0x0395,
        0x0396, 0x0397, 0x0398, 0x0399, 0x039A,
        0x039B, 0x039C, 0x039D, 0x039E, 0x039F,
        0x03A0, 0x03A1, 0x03A3, 0x03A4, 0x03A5,
        0x03A6, 0x03A7, 0x03A8, 0x03A9
    },
    ['arabic'] = {
        0x0660, 0x0661, 0x0662, 0x0663, 0x0664,
        0x0665, 0x0666, 0x0667, 0x0668, 0x0669
    },
    ['persian'] = {
        0x06F0, 0x06F1, 0x06F2, 0x06F3, 0x06F4,
        0x06F5, 0x06F6, 0x06F7, 0x06F8, 0x06F9
    },
    ['thai'] = {
        0xE050, 0xE051, 0xE052, 0xE053, 0xE054,
        0xE055, 0xE056, 0xE057, 0xE058, 0xE059
    },
    ['devangari'] = {
        0x0966, 0x0967, 0x0968, 0x0969, 0x096A,
        0x096B, 0x096C, 0x096D, 0x096E, 0x096F
    },
    ['gurmurkhi'] = {
        0x0A66, 0x0A67, 0x0A68, 0x0A69, 0x0A6A,
        0x0A6B, 0x0A6C, 0x0A6D, 0x0A6E, 0x0A6F
    },
    ['gujarati'] = {
        0x0AE6, 0x0AE7, 0x0AE8, 0x0AE9, 0x0AEA,
        0x0AEB, 0x0AEC, 0x0AED, 0x0AEE, 0x0AEF
    },
    ['tibetan'] = {
        0x0F20, 0x0F21, 0x0F22, 0x0F23, 0x0F24,
        0x0F25, 0x0F26, 0x0F27, 0x0F28, 0x0F29
    }
}

function converters.chr(n, m)
    if n > 0 and n < 27 then
        tex.sprint(string.char(n+m))
    end
end

function converters.maxchrs(n,m,cmd)
    if n <= m then
        tex.sprint(tex.texcatcodes, cmd .. "{" .. n .. "}")
    else
        converters.maxchrs(math.floor((n-1)/m),m,cmd)
        tex.sprint(tex.texcatcodes, cmd .. "{" .. ((n-1)%m + 1) .. "}")
    end
end
function converters.chrs(n,m)
    if n <= 26 then
        tex.sprint(string.char(n+m))
    else
        converters.chrs(math.floor((n-1)/26),m)
        tex.sprint(string.char(((n-1)%26 + 1)+m))
    end
end

do

    local function do_alphabetic(n,max,chr)
        if n <= max then
            characters.flush(chr(n))
        else
            do_alphabetic(math.floor((n-1)/max),max,chr)
            characters.flush(chr((n-1)%max+1))
        end
    end

    function converters.alphabetic(n,code)
        local code = languages.counters[code] or languages.counters['**']
        do_alphabetic(n,#code,function(n) return code[n] end)
    end

    function converters.Alphabetic(n,code)
        local code = languages.counters[code] or languages.counters['**']
        do_alphabetic(n,#code,function(n) return characters.uccode(code[n]) end)
    end

end

function converters.character(n)  converters.chr (n,96) end
function converters.Character(n)  converters.chr (n,64) end
function converters.characters(n) converters.chrs(n,96) end
function converters.Characters(n) converters.chrs(n,64) end

function converters.weekday(year,month,day)
    tex.sprint(os.date("%w",os.time{year=year,month=month,day=day})+1)
end

function converters.lpy(year)
    return (year % 400 == 0) or ((year % 100 ~= 0) and (year % 4 == 0))
end

function converters.leapyear(year)
    if converters.lpy(year) then tex.sprint(1) else tex.sprint(0) end
end

converters.mth = {
    [false] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
    [true]  = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
}

function converters.nofdays(year,month)
    tex.sprint(converters.mth[converters.lpy(year)][month])
end

function converters.year   () tex.sprint(os.date("%Y")) end
function converters.month  () tex.sprint(os.date("%m")) end
function converters.hour   () tex.sprint(os.date("%H")) end
function converters.minute () tex.sprint(os.date("%M")) end
function converters.second () tex.sprint(os.date("%S")) end
function converters.textime() tex.sprint(tonumber(os.date("%H"))*60+tonumber(os.date("%M"))) end

converters.rom = {
    { [0] = '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX' },
    { [0] = '', 'X', 'XX', 'XXX', 'XL', 'L', 'LX', 'LXX', 'LXXX', 'XC' },
    { [0] = '', 'C', 'CC', 'CCC', 'CD', 'D', 'DC', 'DCC', 'DCCC', 'CM' },
}

function converters.toroman(n)
    if n >= 4000 then
        return converters.toroman(math.floor(n/1000)) .. " " .. converters.toroman(n%1000)
    else
        return string.rep("M",math.floor(n/1000)) .. converters.rom[3][math.floor((n%1000)/100)] ..
            converters.rom[2][math.floor((n%100)/10)] .. converters.rom[1][math.floor((n% 10)/1)]
    end
end

function converters.romannumerals(n) return tex.sprint(string.lower(converters.toroman(n))) end
function converters.Romannumerals(n) return tex.sprint(             converters.toroman(n) ) end
