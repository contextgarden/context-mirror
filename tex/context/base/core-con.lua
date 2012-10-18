if not modules then modules = { } end modules ['core-con'] = {
    version   = 1.001,
    comment   = "companion to core-con.mkiv",
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

local utf = unicode.utf8

local floor, date, time, concat = math.floor, os.date, os.time, table.concat
local lower, format, rep, match = string.lower, string.format, string.rep, string.match
local utfchar, utfbyte = utf.char, utf.byte
local tonumber, tostring = tonumber, tostring

local settings_to_array = utilities.parsers.settings_to_array
local allocate = utilities.storage.allocate

local context    = context

local variables  = interfaces.variables

converters       = converters or { }
local converters = converters

languages        = languages  or { }
local languages  = languages

local function number(n)
    return tonumber(n)
end

converters.number = number

function commands.number(n) context(n) end

-- to be reconsidered ... languages namespace here, might become local plus a register command

local counters = allocate {
    ['**'] = {
        0x0061, 0x0062, 0x0063, 0x0064, 0x0065,
        0x0066, 0x0067, 0x0068, 0x0069, 0x006A,
        0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
        0x0070, 0x0071, 0x0072, 0x0073, 0x0074,
        0x0075, 0x0076, 0x0077, 0x0078, 0x0079,
        0x007A
    },
    ['slovenian'] = {
        0x0061, 0x0062, 0x0063, 0x010D, 0x0064,
        0x0065, 0x0066, 0x0067, 0x0068, 0x0069,
        0x006A, 0x006B, 0x006C, 0x006D, 0x006E,
        0x006F, 0x0070, 0x0072, 0x0073, 0x0161,
        0x0074, 0x0075, 0x0076, 0x007A, 0x017E
    },
    ['greek'] = { -- this should be the lowercase table
     -- 0x0391, 0x0392, 0x0393, 0x0394, 0x0395,
     -- 0x0396, 0x0397, 0x0398, 0x0399, 0x039A,
     -- 0x039B, 0x039C, 0x039D, 0x039E, 0x039F,
     -- 0x03A0, 0x03A1, 0x03A3, 0x03A4, 0x03A5,
     -- 0x03A6, 0x03A7, 0x03A8, 0x03A9
        0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5,
        0x03B6, 0x03B7, 0x03B8, 0x03B9, 0x03BA,
        0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF,
        0x03C0, 0x03C1, 0x03C3, 0x03C4, 0x03C5,
        0x03C6, 0x03C7, 0x03C8, 0x03C9,
    },
    ['arabic'] = {
        0x0627, 0x0628, 0x062C, 0x062F, 0x0647,
        0x0648, 0x0632, 0x062D, 0x0637, 0x0649,
        0x0643, 0x0644, 0x0645, 0x0646, 0x0633,
        0x0639, 0x0641, 0x0635, 0x0642, 0x0631,
        0x0634, 0x062A, 0x062B, 0x062E, 0x0630,
        0x0636, 0x0638, 0x063A,
    },
    ['persian'] = {
        0x0627, 0x0628, 0x062C, 0x062F, 0x0647,
        0x0648, 0x0632, 0x062D, 0x0637, 0x0649,
        0x06A9, 0x0644, 0x0645, 0x0646, 0x0633,
        0x0639, 0x0641, 0x0635, 0x0642, 0x0631,
        0x0634, 0x062A, 0x062B, 0x062E, 0x0630,
        0x0636, 0x0638, 0x063A,
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
    },
    ['korean'] = {
        0x3131, 0x3134, 0x3137, 0x3139, 0x3141,
        0x3142, 0x3145, 0x3147, 0x3148, 0x314A,
        0x314B, 0x314C, 0x314D, 0x314E
    },
    ['korean-parent'] = { -- parenthesed
        0x3200, 0x3201, 0x3202, 0x3203, 0x3204,
        0x3205, 0x3206, 0x3207, 0x3208, 0x3209,
        0x320A, 0x320B, 0x320C, 0x320D
    },
    ['korean-circle'] = { -- circled
        0x3260, 0x3261, 0x3262, 0x3263, 0x3264,
        0x3265, 0x3266, 0x3267, 0x3268, 0x3269,
        0x326A, 0x326B, 0x326C, 0x326D
    },
}

languages.counters = counters

counters['ar']   = counters['arabic']
counters['gr']   = counters['greek']
counters['g']    = counters['greek']
counters['sl']   = counters['slovenian']
counters['kr']   = counters['korean']
counters['kr-p'] = counters['korean-parent']
counters['kr-c'] = counters['korean-circle']

local fallback = utf.byte('0')

local function chr(n,m)
    return (n > 0 and n < 27 and utfchar(n+m)) or ""
end

local function chrs(n,m,t)
    if not t then
        t = { }
    end
    if n > 26 then
        chrs(floor((n-1)/26),m,t)
        n = (n-1)%26 + 1
    end
    if n ~= 0 then
        t[#t+1] = utfchar(n+m)
    end
    if n <= 26 then
        return concat(t)
    end
end

local function maxchrs(n,m,cmd,t)
    if not t then
        t = { }
    end
    if n > m then
        maxchrs(floor((n-1)/m),m,cmd)
        n = (n-1)%m + 1
    end
    t[#t+1] = format("%s{%s}",cmd,n)
    if n <= m then
        return concat(t)
    end
end

converters.chr     = chr
converters.chrs    = chrs
converters.maxchrs = maxchrs

local lowercharacter = characters.lcchars
local uppercharacter = characters.ucchars

local function do_alphabetic(n,mapping,mapper,t)
    if not t then
        t = { }
    end
    local chr = mapping[n] or fallback
    if mapper then
        chr = mapper[chr]
    end
    local max = #mapping
    if n > max then
        do_alphabetic(floor((n-1)/max),mapping,mapper,t)
        n = (n-1) % max + 1
    end
    t[#t+1] = chr
    if n <= max then
        return concat(t)
    end
end

local function alphabetic(n,code)
    return do_alphabetic(n,counters[code] or counters['**'],lowercharacter)
end

local function Alphabetic(n,code)
    return do_alphabetic(n,counters[code] or counters['**'],uppercharacter)
end

local function character (n) return chr (n,96) end
local function Character (n) return chr (n,64) end
local function characters(n) return chrs(n,96) end
local function Characters(n) return chrs(n,64) end

converters.alphabetic = alphabetic
converters.Alphabetic = Alphabetic
converters.character  = character
converters.Character  = Character
converters.characters = characters
converters.Characters = Characters

function commands.alphabetic(n,c) context(alphabetic(n,c)) end
function commands.Alphabetic(n,c) context(Alphabetic(n,c)) end
function commands.character (n)   context(character (n))   end
function commands.Character (n)   context(Character (n))   end
function commands.characters(n)   context(characters(n))   end
function commands.Characters(n)   context(Characters(n))   end

local days = {
    [false] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
    [true]  = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
}

local function weekday(day,month,year)
    return date("%w",time{year=year,month=month,day=day}) + 1
end

local function isleapyear(year)
    return (year % 400 == 0) or ((year % 100 ~= 0) and (year % 4 == 0))
end

local function leapyear(year)
    return isleapyear(year) and 1 or 0
end

local function nofdays(year,month)
    return days[isleapyear(year)][month]
end

local function year  () return date("%Y") end
local function month () return date("%m") end
local function hour  () return date("%H") end
local function minute() return date("%M") end
local function second() return date("%S") end

local function textime()
    return tonumber(date("%H")) * 60 + tonumber(date("%M"))
end

converters.weekday    = weekday
converters.isleapyear = isleapyear
converters.leapyear   = leapyear
converters.nofdays    = nofdays
converters.year       = year
converters.month      = month
converters.hour       = hour
converters.minute     = minute
converters.second     = second
converters.textime    = textime

function commands.weekday(day,month,year)
    context(weekday(day,month,year))
end

function commands.isleapyear(year)
    context(isleapyear(year))
end

function commands.leapyear(year)
    context(leapyear(year))
end

function commands.nofdays(year,month)
    context(nofdays(year,month))
end

function commands.year   () context(year   ()) end
function commands.month  () context(month  ()) end
function commands.hour   () context(hour   ()) end
function commands.minute () context(minute ()) end
function commands.second () context(second ()) end
function commands.textime() context(textime()) end

function commands.doifleapyearelse(year)
    commands.testcase(leapyear(year))
end

local roman = {
    { [0] = '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX' },
    { [0] = '', 'X', 'XX', 'XXX', 'XL', 'L', 'LX', 'LXX', 'LXXX', 'XC' },
    { [0] = '', 'C', 'CC', 'CCC', 'CD', 'D', 'DC', 'DCC', 'DCCC', 'CM' },
}

local function toroman(n)
    if n >= 4000 then
        return toroman(floor(n/1000)) .. " " .. toroman(n%1000)
    else
        return rep("M",floor(n/1000)) .. roman[3][floor((n%1000)/100)] .. roman[2][floor((n%100)/10)] .. roman[1][floor((n%10)/1)]
    end
end

local Romannumerals = toroman

local function romannumerals(n) return lower(toroman(n)) end

converters.toroman       = toroman
converters.Romannumerals = toroman
converters.romannumerals = romannumerals

function commands.romannumerals(n) context(lower(toroman(n))) end
function commands.Romannumerals(n) context(      toroman(n))  end

--~ local small = {
--~     0x0627, 0x066E, 0x062D, 0x062F, 0x0647, 0x0648, 0x0631
--~ }

--~ local large = {
--~     { 0x0627, 0x0628, 0x062C, 0x062F, 0x0647, 0x0648, 0x0632, 0x062D, 0x0637, },
--~     { 0x064A, 0x0643, 0x0644, 0x0645, 0x0646, 0x0633, 0x0639, 0x0641, 0x0635, },
--~     { 0x0642, 0x0631, 0x0634, 0x062A, 0x062B, 0x062E, 0x0630, 0x0636, 0x0638, },
--~     { 0x063A                                                                  },
--~ }

local small = {
    "ا", "ٮ", "ح", "د", "ه", "و", "ر",
}

local medium = {
     "ا", "ب", "ج", "د", "ه", "و","ز", "ح", "ط" ,
     "ي", "ك", "ل", "م", "ن", "س", "ع", "ف", "ص" ,
     "ق", "ر", "ش", "ت", "ث", "خ", "ذ", "ض", "ظ" ,
     "غ" ,
}

local large = {
    { "ا", "ب", "ج", "د", "ه", "و","ز", "ح", "ط" },
    { "ي", "ك", "ل", "م", "ن", "س", "ع", "ف", "ص" },
    { "ق", "ر", "ش", "ت", "ث", "خ", "ذ", "ض", "ظ" },
    { "غ" },
}

local function toabjad(n,what)
    if n <= 0 or n >= 2000 then
        return tostring(n)
    elseif what == 2 and n <= 7 then
        return small[n]
    elseif what == 3 and n <= 28 then
        return medium[n]
    else
        local a, b, c, d
        a, n = floor(n/1000), n % 1000 -- mod(n,1000)
        b, n = floor(n/ 100), n %  100 -- mod(n, 100)
        c, n = floor(n/  10), n %   10 -- mod(n,  10)
        d, n = floor(n/   1), n %    1 -- mod(n,   1)
        return (large[4][a] or "") .. (large[3][b] or "") .. (large[2][c] or "") .. (large[1][d] or "")
    end
end

converters.toabjad = toabjad

local function abjadnumerals     (n) return toabjad(n,false) end
local function abjadnodotnumerals(n) return toabjad(n,true ) end

converters.abjadnumerals      = abjadnumerals
converters.abjadnodotnumerals = abjadnodotnumerals

function commands.abjadnumerals     (n) context(toabjad(n,false)) end
function commands.abjadnodotnumerals(n) context(toabjad(n,true )) end

local vector = {
    normal = {
                [0] = "〇",
                [1] = "一",
                [2] = "二",
                [3] = "三",
                [4] = "四",
                [5] = "五",
                [6] = "六",
                [7] = "七",
                [8] = "八",
                [9] = "九",
               [10] = "十",
              [100] = "百",
             [1000] = "千",
            [10000] = "万",
        [100000000] = "亿",
    },
    cap = {
                [0] = "零",
                [1] = "壹",
                [2] = "贰",
                [3] = "叁",
                [4] = "肆",
                [5] = "伍",
                [6] = "陆",
                [7] = "柒",
                [8] = "捌",
                [9] = "玖",
               [10] = "拾",
              [100] = "佰",
             [1000] = "仟",
            [10000] = "萬",
        [100000000] = "亿",
    },
    all = {
                [0] = "〇",
                [1] = "一",
                [2] = "二",
                [3] = "三",
                [4] = "四",
                [5] = "五",
                [6] = "六",
                [7] = "七",
                [8] = "八",
                [9] = "九",
               [10] = "十",
               [20] = "廿",
               [30] = "卅",
              [100] = "百",
             [1000] = "千",
            [10000] = "万",
        [100000000] = "亿",
    }
}

local function tochinese(n,name) -- normal, caps, all
 -- improved version by Li Yanrui
    local result, r = { }, 0
    local vector = vector[name] or vector.normal
    while true do
        if n == 0 then
            break
        elseif n >= 100000000 then
            local m = floor(n/100000000)
            r = r + 1 ; result[r] = tochinese(m,name)
            r = r + 1 ; result[r] = vector[100000000]
            local z = n - m * 100000000
            if z > 0 and z < 10000000 then r = r + 1 ; result[r] = vector[0] end
            n = n % 100000000
        elseif n >= 10000000 then
            local m = floor(n/10000)
            r = r + 1 ; result[r] = tochinese(m,name)
            r = r + 1 ; result[r] = vector[10000]
            local z = n - m * 10000
            if z > 0 and z < 1000 then r = r + 1 ; result[r] = vector[0] end
            n = n % 10000
        elseif n >= 1000000 then
            local m = floor(n/10000)
            r = r + 1 ; result[r] = tochinese(m,name)
            r = r + 1 ; result[r] = vector[10000]
            local z = n - m * 10000
            if z > 0 and z < 1000 then r = r + 1 ; result[r] = vector[0] end
            n = n % 10000
        elseif n >= 100000 then
            local m = floor(n/10000)
            r = r + 1 ; result[r] = tochinese(m,name)
            r = r + 1 ; result[r] = vector[10000]
            local z = n - m * 10000
            if z > 0 and z < 1000 then r = r + 1 ; result[r] = vector[0] end
            n = n % 10000
         elseif n >= 10000 then
            local m = floor(n/10000)
            r = r + 1 ; result[r] = vector[m]
            r = r + 1 ; result[r] = vector[10000]
            local z = n - m * 10000
            if z > 0 and z < 1000 then r = r + 1 ; result[r] = vector[0] end
            n = n % 10000
         elseif n >= 1000 then
            local m = floor(n/1000)
            r = r + 1 ; result[r] = vector[m]
            r = r + 1 ; result[r] = vector[1000]
            local z =  n - m * 1000
            if z > 0 and z < 100 then r = r + 1 ; result[r] = vector[0] end
            n = n % 1000
         elseif n >= 100 then
            local m = floor(n/100)
            r = r + 1 ; result[r] = vector[m]
            r = r + 1 ; result[r] = vector[100]
            local z = n - m * 100
            if z > 0 and z < 10 then r = r + 1 ; result[r] = vector[0] end
            n = n % 100
         elseif n >= 10 then
            local m = floor(n/10)
            if m > 1 and vector[m*10] then
                r = r + 1 ; result[r] = vector[m*10]
            else
                r = r + 1 ; result[r] = vector[m]
                r = r + 1 ; result[r] = vector[10]
            end
            n = n % 10
        else
            r = r + 1 ; result[r] = vector[n]
            break
        end
    end
    if (result[1] == vector[1] and result[2] == vector[10]) then
        result[1] = ""
    end
    return concat(result)
end

-- local t = { 1,10,15,25,35,45,11,100,111,1111,10000,11111,100000,111111,1111111,11111111,111111111,100000000,1111111111,11111111111,111111111111,1111111111111 }
-- for k=1,#t do
-- local v = t[k]
--     print(v,tochinese(v),tochinese(v,"all"),tochinese(v,"cap"))
-- end

converters.tochinese = tochinese

local function chinesenumerals   (n) return tochinese(n,"normal") end
local function chinesecapnumerals(n) return tochinese(n,"cap"   ) end
local function chineseallnumerals(n) return tochinese(n,"all"   ) end

converters.chinesenumerals    = chinesenumerals
converters.chinesecapnumerals = chinesecapnumerals
converters.chineseallnumerals = chineseallnumerals

function commands.chinesenumerals   (n) context(tochinese(n,"normal")) end
function commands.chinesecapnumerals(n) context(tochinese(n,"cap"   )) end
function commands.chineseallnumerals(n) context(tochinese(n,"all"   )) end

converters.sequences = converters.sequences or { }

storage.register("converters/sequences", converters.sequences, "converters.sequences")

local sequences = converters.sequences

function converters.define(name,set)
    sequences[name] = settings_to_array(set)
end

commands.defineconversion = converters.define

local function convert(method,n) -- todo: language
    local converter = converters[method]
    if converter then
        return converter(n)
    else
        local lowermethod = lower(method)
        local linguistic = counters[lowermethod]
        if linguistic then
            return do_alphabetic(n,linguistic,lowermethod == method and lowercharacter or uppercharacter)
        end
        local sequence = sequences[method]
        if sequence then
            local max = #sequence
            if n > max then
                return sequence[(n-1) % max + 1]
            else
                return sequence[n]
            end
        else
            return n
        end
    end
end

converters.convert = convert

function commands.checkedconversion(method,n)
    context(convert(method,n))
end

-- Well, since the one asking for this didn't test it the following code is not
-- enabled.
--
-- -- This Lua version is based on a Javascript by Behdad Esfahbod which in turn
-- -- is based on GPL'd code by Roozbeh Pournader of the The FarsiWeb Project
-- -- Group: http://www.farsiweb.info/jalali/jalali.js.
-- --
-- -- We start tables at one, I kept it zero based in order to stay close to
-- -- the original.
-- --
-- -- Conversion by Hans Hagen
--
-- local g_days_in_month = { [0]=31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
-- local j_days_in_month = { [0]=31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29 }
--
-- local function div(a,b)
--   return math.floor(a/b)
-- end
--
-- local function remainder(a,b)
--   return a - div(a,b)*b
-- end
--
-- function gregorian_to_jalali(gy,gm,gd)
--     local jy, jm, jd, g_day_no, j_day_no, j_np, i
--     gy, gm, gd = gy - 1600, gm - 1, gd - 1
--     g_day_no = 365*gy + div((gy+3),4) - div((gy+99),100) + div((gy+399),400)
--     i = 0
--     while i < gm do
--         g_day_no = g_day_no + g_days_in_month[i]
--         i = i + 1
--     end
--     if (gm>1 and ((gy%4==0 and gy%100~=0) or (gy%400==0))) then
--         g_day_no = g_day_no + 1
--     end
--     g_day_no = g_day_no + gd
--     j_day_no = g_day_no - 79
--     j_np = div(j_day_no,12053)
--     j_day_no = remainder(j_day_no,12053)
--     jy = 979 + 33*j_np + 4*div(j_day_no,1461)
--     j_day_no = remainder(j_day_no,1461)
--     if j_day_no >= 366 then
--         jy = jy + div((j_day_no-1),365)
--         j_day_no = remainder((j_day_no-1),365)
--     end
--     i = 0
--     while i < 11 and j_day_no >= j_days_in_month[i] do
--         j_day_no = j_day_no - j_days_in_month[i]
--         i = i + 1
--     end
--     jm = i + 1
--     jd = j_day_no + 1
--     return jy, jm, jd
-- end
--
-- function jalali_to_gregorian(jy,jm,jd)
--     local gy, gm, gd, g_day_no, j_day_no, leap, i
--     jy, jm, jd = jy - 979, jm - 1, jd - 1
--     j_day_no = 365*jy + div(jy,33)*8 + div((remainder(jy,33)+3),4)
--     i = 0
--     while i < jm do
--         j_day_no = j_day_no + j_days_in_month[i]
--         i = i + 1
--     end
--     j_day_no = j_day_no + jd
--     g_day_no = j_day_no + 79
--     gy = 1600 + 400*div(g_day_no,146097)
--     g_day_no = remainder (g_day_no, 146097)
--     leap = 1
--     if g_day_no >= 36525 then
--         g_day_no = g_day_no - 1
--         gy = gy + 100*div(g_day_no,36524)
--         g_day_no = remainder (g_day_no, 36524)
--         if g_day_no >= 365 then
--             g_day_no = g_day_no + 1
--         else
--             leap = 0
--         end
--     end
--     gy = gy  + 4*div(g_day_no,1461)
--     g_day_no = remainder (g_day_no, 1461)
--     if g_day_no >= 366 then
--         leap = 0
--         g_day_no = g_day_no - 1
--         gy = gy + div(g_day_no, 365)
--         g_day_no = remainder(g_day_no, 365)
--     end
--     i = 0
--     while g_day_no >= g_days_in_month[i] + ((i == 1 and leap) or 0) do
--         g_day_no = g_day_no - g_days_in_month[i] + ((i == 1 and leap) or 0)
--         i = i + 1
--     end
--     gm = i + 1
--     gd = g_day_no + 1
--     return gy, gm, gd
-- end
--
-- print(gregorian_to_jalali(2009,02,24))
-- print(jalali_to_gregorian(1387,12,06))

-- more efficient but needs testing
--
-- local escapes = utffilters.private.escapes
--
-- local function do_alphabetic(n,mapping,chr)
--     local max = #mapping
--     if n > max then
--         do_alphabetic(floor((n-1)/max),max,chr)
--         n = (n-1)%max+1
--     end
--     n = chr(n,mapping)
--     context(escapes[n] or utfchar(n))
-- end
--
-- local lccodes, uccodes = characters.lccode, characters.uccode
--
-- local function do_alphabetic(n,mapping,chr)
--     local max = #mapping
--     if n > max then
--         do_alphabetic(floor((n-1)/max),mapping,chr)
--         n = (n-1)%max+1
--     end
--     characters.flush(chr(n,mapping))
-- end
--
-- local function lowercased(n,mapping) return characters.lccode(mapping[n] or fallback) end
-- local function uppercased(n,mapping) return characters.uccode(mapping[n] or fallback) end
--
-- function converters.alphabetic(n,code)
--     do_alphabetic(n,counters[code] or counters['**'],lowercased) -- lccode catches wrong tables
-- end
--
-- function converters.Alphabetic(n,code)
--     do_alphabetic(n,counters[code] or counters['**'],uppercased)
-- end

-- --

local ordinals = {
    english = function(n)
        local two = n % 100
        if two == 11 or two == 12 or two == 13 then
            return "th"
        else
            local one = n % 10
            if one == 1 then
                return "st"
            elseif one == 2 then
                return "nd"
            elseif one == 3 then
                return "rd"
            else
                return "th"
            end
        end
    end,
    dutch = function(n)
        return "e"
    end,
    french = function(n)
        if n == 1 then
            return "er"
        end
    end,
}

ordinals.en = ordinals.english
ordinals.nl = ordinals.dutch
ordinals.fr = ordinals.french

function converters.ordinal(n,language)
    local t = language and ordinals[language]
    return t and t(n)
end

function commands.ordinal(n,language)
    local t = language and ordinals[language]
    local o = t and t(n)
    context(n)
    if o then
        context.highordinalstr(o)
    end
end

-- --

local v_day      = variables.day
local v_year     = variables.year
local v_month    = variables.month
local v_weekday  = variables.weekday
local v_referral = variables.referral
local v_space    = variables.space

local convert = converters.convert

local days = { -- not variables.sunday
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
}

local months = { -- not variables.januari
     "january",
     "february",
     "march",
     "april",
     "may",
     "june",
     "july",
     "august",
     "september",
     "october",
     "november",
     "december",
}

function commands.dayname(n)
    context.labeltext(days[n] or "unknown")
end

function commands.weekdayname(day,month,year)
    context.labeltext(days[weekday(day,month,year)] or "unknown")
end

function commands.monthname(n)
    context.labeltext(months[n] or "unknown")
end

function commands.monthmnem(n)
    local m = months[n]
    context.labeltext(m and (m ..":mnem") or "unknown")
end

-- a prelude to a function that we can use at the lua end

-- day:ord month:mmem
-- j and jj obsolete

function commands.currentdate(str,currentlanguage) -- second argument false : no label
    local list = utilities.parsers.settings_to_array(str)
    local year, month, day = tex.year, tex.month, tex.day
    local auto = true
    for i=1,#list do
        local entry = list[i]
        local tag, plus = languages.labels.split(entry)
        local ordinal, mnemonic, whatordinal = false, false, nil
        if not tag then
            tag = entry
        elseif plus == "+" or plus == "ord" then
            ordinal = true
        elseif plus == "mnem" then
            mnemonic = true
        end
        if not auto and (tag == v_year or tag == v_month or tag == v_day or tag == v_weekday) then
            context.space()
        end
        auto = false
        if tag == v_year or tag == "y" then
            context(year)
        elseif tag == "yy" then
            context("%02i",year % 100)
        elseif tag == "Y" then
            context(year)
        elseif tag == v_month or tag == "m" then
            if currentlanguage == false then
                context(months[month] or "unknown")
            elseif mnemonic then
                commands.monthmnem(month)
            else
                commands.monthname(month)
            end
        elseif tag == "mm" then
            context("%02i",month)
        elseif tag == "M" then
            context(month)
        elseif tag == v_day or tag == "d" then
            if currentlanguage == false then
                context(days[day] or "unknown")
            else
                context.convertnumber(v_day,day)
            end
            whatordinal = day
        elseif tag == "dd" then
            context("%02i",day)
            whatordinal = day
        elseif tag == "D" then
            context(day)
            whatordinal = day
        elseif tag == v_weekday or tag == "w" then
            local wd = weekday(day,month,year)
            if currentlanguage == false then
                context(days[wd] or "unknown")
            else
                commands.dayname(wd)
            end
        elseif tag == "W" then
            context(weekday(day,month,year))
        elseif tag == v_referral then
            context("%04i%02i%02i",year,month,day)
        elseif tag == v_space or tag == "\\ " then
            context.space()
            auto = true
        elseif tag ~= "" then
            context(tag)
            auto = true
        end
        if ordinal and whatordinal then
            if currentlanguage == false then
                -- ignore
            else
                context("%s",converters.ordinal(whatordinal,currentlanguage))
            end
        end
    end
end

function commands.rawdate(str)
    commands.currentdate(str,false)
end
