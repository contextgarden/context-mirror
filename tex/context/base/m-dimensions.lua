if not modules then modules = { } end modules ['m-dimensions'] = {
    version   = 1.001,
    comment   = "companion to m-dimensions.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is pretty old code that I found back, but let's give it a try
-- in practice. It started out as m-units.lua but as we want to keep that
-- module around we moved the code to the dimensions module.

local P, C, Cc, Cs, matchlpeg = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.match
local format = string.format
local appendlpeg = lpeg.append

local mergetable, mergedtable, keys, loweredkeys = table.merge, table.merged, table.keys, table.loweredkeys

local long_prefixes = {
    Yocto = [[y]],  -- 10^{-24}
    Zepto = [[z]],  -- 10^{-21}
    Atto  = [[a]],  -- 10^{-18}
    Femto = [[f]],  -- 10^{-15}
    Pico  = [[p]],  -- 10^{-12}
    Nano  = [[n]],  -- 10^{-9}
    Micro = [[\mu]],-- 10^{-6}
    Milli = [[m]],  -- 10^{-3}
    Centi = [[c]],  -- 10^{-2}
    Deci  = [[d]],  -- 10^{-1}

    Deca  = [[da]], -- 10^{1}
    Hecto = [[h]],  -- 10^{2}
    Kilo  = [[k]],  -- 10^{3}
    Mega  = [[M]],  -- 10^{6}
    Giga  = [[G]],  -- 10^{9}
    Tera  = [[T]],  -- 10^{12}
    Peta  = [[P]],  -- 10^{15}
    Exa   = [[E]],  -- 10^{18}
    Zetta = [[Z]],  -- 10^{21}
    Yotta = [[Y]],  -- 10^{24}

    Kibi  = [[ki]], -- 2^{10}
    Mebi  = [[Mi]], -- 2^{20}
    Gibi  = [[Gi]], -- 2^{30}
    Tebi  = [[Ti]], -- 2^{40}
    Pebi  = [[Pi]], -- 2^{50}

    Kibi  = [[Ki]], -- binary
    Mebi  = [[Mi]], -- binary
    Gibi  = [[Gi]], -- binary
    Tebi  = [[Ti]], -- binary
    Pebi  = [[Pi]], -- binary
    Exbi  = [[Ei]], -- binary
    Zebi  = [[Zi]], -- binary
    Yobi  = [[Yi]], -- binary
}

local long_units = {
    Meter      = [[m]],
    Hertz      = [[hz]],
    Second     = [[s]],
    Hour       = [[h]],
    Liter      = [[l]],
    Litre      = [[l]],
    Gram       = [[g]],
    Newton     = [[N]],
    Pascal     = [[Pa]],
    Atom       = [[u]],
    Joule      = [[W]],
    Watt       = [[J]],
    Celsius    = [[C]], -- no SI
    Kelvin     = [[K]],
    Fahrenheit = [[F]], -- no SI
    Mol        = [[mol]],
    Mole       = [[mol]],
    Equivalent = [[eql]],
    Farad      = [[F]],
    Ohm        = [[\Omega]],
    Siemens    = [[S]],
    Ampere     = [[A]],
    Coulomb    = [[C]],
    Volt       = [[V]],
    eVolt      = [[eV]],
    Tesla      = [[T]],
    VoltAC     = [[V\scientificunitbackspace\scientificunitlower{ac}]],
    VoltDC     = [[V\scientificunitbackspace\scientificunitlower{dc}]],
    AC         = [[V\scientificunitbackspace\scientificunitlower{ac}]],
    DC         = [[V\scientificunitbackspace\scientificunitlower{dc}]],
    Bit        = [[bit]],
    Baud       = [[Bd]],
    Byte       = [[B]],
    Erlang     = [[E]],
    Bequerel   = [[Bq]],
    Sievert    = [[Sv]],
    Candela    = [[cd]],
    Bell       = [[B]],
    At         = [[at]],
    Atm        = [[atm]],
    Bar        = [[bar]],
    Foot       = [[ft]],
    Inch       = [[inch]],
    Cal        = [[cal]],
    Force      = [[f]],
    Lux        = [[lux]],
    Gray       = [[Gr]],
    Weber      = [[Wb]],
    Henry      = [[H]],
    Sterant    = [[sr]],
    Angstrom   = [[Å]],
    Gauss      = [[G]],
    Rad        = [[rad]],
    Deg        = [[°]],
    RPS        = [[RPS]],
    RPM        = [[RPM]],
    RevPerSec  = [[RPS]],
    RevPerMin  = [[RPM]],
    Percent    = [[\percent]],
    Promille   = [[\promille]],
}

local long_operators = {
    Times   = [[\scientificunitTIMES]], -- cdot
    Solidus = [[\scientificunitSOLIDUS]],
    Per     = [[\scientificunitSOLIDUS]],
    OutOf   = [[\scientificunitOUTOF]],
}

local long_suffixes = {
    Linear  = [[1]],
    Square  = [[2]],
    Cubic   = [[3]],
    Inverse = [[-1]],
    ILinear = [[-1]],
    ISquare = [[-2]],
    ICubic  = [[-3]],
}

mergetable(long_prefixes, loweredkeys(long_prefixes))
mergetable(long_units, loweredkeys(long_units))
mergetable(long_operators, loweredkeys(long_operators))
mergetable(long_suffixes, loweredkeys(long_suffixes))

local short_prefixes = {
    y  = long_prefixes.Yocto,
    z  = long_prefixes.Zetto,
    a  = long_prefixes.Atto,
    f  = long_prefixes.Femto,
    p  = long_prefixes.Pico,
    n  = long_prefixes.Nano,
    u  = long_prefixes.Micro,
    m  = long_prefixes.Milli,
    c  = long_prefixes.Centi,
    d  = long_prefixes.Deci,
    da = long_prefixes.Deca,
    h  = long_prefixes.Hecto,
    k  = long_prefixes.Kilo,
    M  = long_prefixes.Mega,
    G  = long_prefixes.Giga,
    T  = long_prefixes.Tera,
    P  = long_prefixes.Peta,
    E  = long_prefixes.Exa,
    Z  = long_prefixes.Zetta,
    Y  = long_prefixes.Yotta,
}

local short_units = {
    m  = long_units.Meter,
    hz = long_units.Hertz,
    u  = long_units.Hour,
    h  = long_units.Hour,
    s  = long_units.Second,
}

local short_operators = {
    ["."] = long_operators.Times,
    ["*"] = long_operators.Times,
    ["/"] = long_operators.Solidus,
    [":"] = long_operators.OutOf,
}

local short_suffixes = { -- maybe just raw digit match
    ["1"]   = long_suffixes.Linear,
    ["2"]   = long_suffixes.Square,
    ["3"]   = long_suffixes.Cubic,
    ["+1"]  = long_suffixes.Linear,
    ["+2"]  = long_suffixes.Square,
    ["+3"]  = long_suffixes.Cubic,
    ["-1"]  = long_suffixes.Inverse,
    ["-1"]  = long_suffixes.ILinear,
    ["-2"]  = long_suffixes.ISquare,
    ["-3"]  = long_suffixes.ICubic,
    ["^1"]  = long_suffixes.Linear,
    ["^2"]  = long_suffixes.Square,
    ["^3"]  = long_suffixes.Cubic,
    ["^+1"] = long_suffixes.Linear,
    ["^+2"] = long_suffixes.Square,
    ["^+3"] = long_suffixes.Cubic,
    ["^-1"] = long_suffixes.Inverse,
    ["^-1"] = long_suffixes.ILinear,
    ["^-2"] = long_suffixes.ISquare,
    ["^-3"] = long_suffixes.ICubic,
}

local prefixes   = mergedtable(long_prefixes,short_prefixes)
local units      = mergedtable(long_units,short_units)
local operators  = mergedtable(long_operators,short_operators)
local suffixes   = mergedtable(long_suffixes,short_suffixes)

local space      = P(" ")^0/""

local l_prefix   = appendlpeg(keys(long_prefixes))
local l_unit     = appendlpeg(keys(long_units))
local l_operator = appendlpeg(keys(long_operators))
local l_suffix   = appendlpeg(keys(long_suffixes))

local s_prefix   = appendlpeg(keys(short_prefixes))
local s_unit     = appendlpeg(keys(short_units))
local s_operator = appendlpeg(keys(short_operators))
local s_suffix   = appendlpeg(keys(short_suffixes))

-- space inside Cs else funny captures and args to function

-- square centi meter per square kilo seconds

local l_suffix      = Cs(space * l_suffix)
local s_suffix      = Cs(space * s_suffix) + Cc("")
local l_operator    = Cs(space * l_operator)
local l_combination = (Cs(space * l_prefix) + Cc("")) * Cs(space * l_unit)
local s_combination = Cs(space * s_prefix) * Cs(space * s_unit) + Cc("") * Cs(space * s_unit)

local combination   = l_combination + s_combination

-- square kilo meter
-- square km

local function dimpus(p,u,s)
    p = prefixes[p] or p
    u = units[u]    or u
    s = suffixes[s] or s
    if p ~= "" then
        if u ~= ""  then
            if s ~= ""  then
                return format(" p=%s u=%s s=%s ",p,u,s)
            else
                return format(" p=%s u=%s ",p,u)
            end
        elseif s ~= ""  then
            return format(" p=%s s=%s ",p,s)
        else
            return format(" p=%s ",p)
        end
    else
        if u ~= ""  then
            if s ~= ""  then
                return format(" u=%s s=%s ",u,s)
            else
                return format(" u=%s ",u)
            end
        elseif s ~= ""  then
            return format(" s=%s ",s)
        else
            return format(" p=%s ",p)
        end
    end
end

local function dimop(o)
    o = operators[o] or o
    if o then
        return format(" o=%s ",o)
    end
end

local function dimnum(n)
    if n ~= "" then
        return format(" n=%s ",n)
    end
end

local function dimerror(s)
    return s ~= "" and s or "error"
end

local dimension =
    (l_suffix * combination) / function (s,p,u)
        return dimpus(p,u,s)
    end
  + (combination * s_suffix) / function (p,u,s)
        return dimpus(p,u,s)
    end

local operator = (l_operator + s_operator) / function(o)
    return dimop(o)
end

local number = (lpeg.patterns.number / function(n)
    return dimnum(n)
end)^-1

dimension = space * dimension * space
number    = space * number    * space
operator  = space * operator  * space

local expression = lpeg.Cs (
    number * dimension * dimension^0 * (operator * dimension^1)^-1 * P(-1)
    + (P(1)^0) / function(s) return dimerror(s) end
)

if commands and context then

    local scientificunitPUS = context.scientificunitPUS
    local scientificunitPU  = context.scientificunitPU
    local scientificunitPS  = context.scientificunitPS
    local scientificunitP   = context.scientificunitP
    local scientificunitUS  = context.scientificunitUS
    local scientificunitU   = context.scientificunitU
    local scientificunitS   = context.scientificunitS
    local scientificunitO   = context.scientificunitO
    local scientificunitN   = context.scientificunitN

    dimpus = function(p,u,s)
        p = prefixes[p] or p
        u = units[u]    or u
        s = suffixes[s] or s
        if p ~= "" then
            if u ~= ""  then
                if s ~= ""  then
                    scientificunitPUS(p,u,s)
                else
                    scientificunitPU(p,u)
                end
            elseif s ~= ""  then
                scientificunitPS(p,s)
            else
                scientificunitP(p)
            end
        else
            if u ~= ""  then
                if s ~= ""  then
                    scientificunitUS(u,s)
                else
                    scientificunitU(u)
                end
            elseif s ~= ""  then
                scientificunitS(s)
            else
                scientificunitP(p)
            end
        end
    end

    dimop = function(o)
        o = operators[o] or o
        if o then
            scientificunitO(o)
        end
    end

    dimnum = function(n)
        if n ~= "" then
            scientificunitN(n)
        end
    end

    dimerror = function(s)
        scientificunitU(s)
    end

    function commands.scientificunit(str)
        matchlpeg(expression,str)
    end

else

    local tests = {
--~         "m/u",
--~         "km/u",
--~         "km",
--~         "km/s2",
--~         "km/ms2",
--~         "km/ms-2",
--~         "km/h",
--~         "           meter                 ",
--~         "           meter per        meter",
--~         "cubic      meter per square meter",
--~         "cubic kilo meter per square meter",
--~         "KiloMeter/Hour",
--~         "10.5 kilo pascal",
--~         "kilo pascal meter liter per second",
--~         "100 crap",
    }

    for i=1,#tests do
        local test = tests[i]
        print(test,matchlpeg(expression,test) or test)
    end

end
