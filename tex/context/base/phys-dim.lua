if not modules then modules = { } end modules ['phys-dim'] = {
    version   = 1.001,
    comment   = "companion to phys-dim.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is pretty old code that I found back, but let's give it a try
-- in practice. It started out as m-units.lua but as we want to keep that
-- module around we moved the code to the dimensions module.
--
-- todo: maybe also an sciunit command that converts to si units (1 inch -> 0.0254 m)
-- etc .. typical something to do when listening to a news whow or b-movie

local P, S, R, C, Cc, Cs, matchlpeg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.match
local format = string.format
local appendlpeg = lpeg.append

local mergetable, mergedtable, keys, loweredkeys = table.merge, table.merged, table.keys, table.loweredkeys

physics          = physics or { }
physics.patterns = physics.patterns or { }

-- digits parser (todo : use patterns)

--~ local done        = false
--~ local mode        = 0

local digit        = R("09")
local sign         = S("+-")
local power        = S("^e")
local digitspace   = S("~@_")
local digitspacex  = digitspace + P(" ")
local comma        = P(",")
local period       = P(".")
local signspace    = P("/")
local positive     = S("p")
local negative     = S("n")
local highspace    = P("s")
local padding      = P("=")
local plus         = P("+")
local minus        = P("-")

local digits       = (digit^1)

local ddigitspacex = digitspacex / "" / context.digitsspace
local ddigitspace  = digitspace  / "" / context.digitsspace
local ddigit       = digits           / context.digitsdigit
local dseparator   = comma       / "" / context.digitscomma
                   + period      / "" / context.digitsperiod
local dsignspace   = signspace   / "" / context.digitssignspace
local dpositive    = positive    / "" / context.digitspositive
local dnegative    = negative    / "" / context.digitsnegative
local dhighspace   = highspace   / "" / context.digitshighspace
local dsomesign    = plus        / "" / context.digitsplus
                   + minus       / "" / context.digitsminus
local dpower       = power       / "" * (
                         plus  * C(digits) / context.digitspowerplus
                       + minus * C(digits) / context.digitspowerminus
                       +         C(digits) / context.digitspower
                   )
local dpadding     = padding     / "" / context.digitszeropadding -- todo

local digitparserspace =
    (dsomesign + dsignspace + dpositive + dnegative + dhighspace)^0
  * (dseparator^0 * (ddigitspacex + ddigit)^1)^1
  * dpower^0

local digitparser =
    (dsomesign + dsignspace + dpositive + dnegative + dhighspace)^0
  * (dseparator^0 * (ddigitspace + ddigit)^1)^1
  * dpower^0

physics.patterns.digitparserspace = digitparserspace
physics.patterns.digitparser      = digitparser

function commands.digits(str)
--~     done = false
    matchlpeg(digitparserspace,str)
end

-- units parser

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
    VoltAC     = [[V\unitsbackspace\unitslower{ac}]],
    VoltDC     = [[V\unitsbackspace\unitslower{dc}]],
    AC         = [[V\unitsbackspace\unitslower{ac}]],
    DC         = [[V\unitsbackspace\unitslower{dc}]],
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
    Times   = [[\unitsTIMES]], -- cdot
    Solidus = [[\unitsSOLIDUS]],
    Per     = [[\unitsSOLIDUS]],
    OutOf   = [[\unitsOUTOF]],
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

long_prefixes.Micro = [[\textmu]]
long_units   .Ohm   = [[\textohm]]

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

local somespace  = P(" ")^0/""

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

local l_suffix      = Cs(somespace * l_suffix)
local s_suffix      = Cs(somespace * s_suffix) + Cc("")
local l_operator    = Cs(somespace * l_operator)
local l_combination = (Cs(somespace * l_prefix) + Cc("")) * Cs(somespace * l_unit)
local s_combination = Cs(somespace * s_prefix) * Cs(somespace * s_unit) + Cc("") * Cs(somespace * s_unit)

local combination   = l_combination + s_combination

-- square kilo meter
-- square km

local unitsPUS    = context.unitsPUS
local unitsPU     = context.unitsPU
local unitsPS     = context.unitsPS
local unitsP      = context.unitsP
local unitsUS     = context.unitsUS
local unitsU      = context.unitsU
local unitsS      = context.unitsS
local unitsO      = context.unitsO
local unitsN      = context.unitsN
local unitsNstart = context.unitsNstart
local unitsNstop  = context.unitsNstop

local function dimpus(p,u,s)
    p = prefixes[p] or p
    u = units[u]    or u
    s = suffixes[s] or s
    if p ~= "" then
        if u ~= ""  then
            if s ~= ""  then
                unitsPUS(p,u,s)
            else
                unitsPU(p,u)
            end
        elseif s ~= ""  then
            unitsPS(p,s)
        else
            unitsP(p)
        end
    else
        if u ~= ""  then
            if s ~= ""  then
                unitsUS(u,s)
            else
                unitsU(u)
            end
        elseif s ~= ""  then
            unitsS(s)
        else
            unitsP(p)
        end
    end
end

local function dimspu(s,p,u)
    return dimpus(p,u,s)
end

local function dimop(o)
    o = operators[o] or o
    if o then
        unitsO(o)
    end
end

local dimension = (l_suffix * combination) / dimspu + (combination * s_suffix) / dimpus
local number    = lpeg.patterns.number / unitsN
local operator  = (l_operator + s_operator) / dimop
local whatever  = (P(1)^0) / unitsU

dimension = somespace * dimension * somespace
number    = somespace * number    * somespace
operator  = somespace * operator  * somespace

----- unitparser = dimension * dimension^0 * (operator * dimension^1)^-1 + whatever
local unitparser = dimension^1 * (operator * dimension^1)^-1 + whatever

local unitdigitparser = (P(true)/unitsNstart) * digitparser * (P(true)/unitsNstop)
local combinedparser  = (unitdigitparser + number)^-1 * unitparser

physics.patterns.unitparser     = unitparser
physics.patterns.combinedparser = combinedparser

function commands.unit(str)
    matchlpeg(combinedparser,str)
end
