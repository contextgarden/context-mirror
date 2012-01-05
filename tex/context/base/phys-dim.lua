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

local V, P, S, R, C, Cc, Cs, matchlpeg, Carg = lpeg.V, lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.match, lpeg.Carg
local format, lower = string.format, string.lower
local appendlpeg = lpeg.append

local mergetable, mergedtable, keys, loweredkeys = table.merge, table.merged, table.keys, table.loweredkeys

local allocate = utilities.storage.allocate

physics          = physics or { }
physics.patterns = physics.patterns or { }

local variables  = interfaces.variables
local v_reverse  = variables.reverse

-- digits parser (todo : use patterns)

local digit        = R("09")
local sign         = S("+-")
local power        = S("^e")
local digitspace   = S("~@_")
local comma        = P(",")
local period       = P(".")
local semicolon    = P(";")
local colon        = P(":")
local signspace    = P("/")
local positive     = P("++") -- was p
local negative     = P("--") -- was n
local highspace    = P("//") -- was s
local padding      = P("=")
local plus         = P("+")
local minus        = P("-")
local space        = P(" ")

local digits       = digit^1

local ddigitspace  = digitspace  / "" / context.digitsspace
local dcommayes    = semicolon   / "" / context.digitsfinalcomma
local dcommanop    = semicolon   / "" / context.digitsseparatorspace
local dperiodyes   = colon       / "" / context.digitsfinalperiod
local dperiodnop   = colon       / "" / context.digitsseparatorspace
local ddigit       = digits           / context.digitsdigit
local dfinalcomma  = comma       / "" / context.digitsfinalcomma
local dfinalperiod = period      / "" / context.digitsfinalperiod
local dintercomma  = comma  * #(digitspace) / "" / context.digitsseparatorspace
                   + comma                  / "" / context.digitsintermediatecomma
local dinterperiod = period * #(digitspace) / "" / context.digitsseparatorspace
                   + period                 / "" / context.digitsintermediateperiod
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

local dleader      = (dpositive + dnegative + dhighspace + dsomesign + dsignspace)^0
local dtrailer     = dpower^0
local dfinal       = P(-1) + #P(1 - comma - period - semicolon - colon)
local dnumber      = (ddigitspace + ddigit)^1
local dtemplate    = ddigitspace^1

-- probably too complex, due to lookahead (lookback with state is probably easier)

local dpcfinalnumber = dtemplate * (dfinalcomma  + dcommanop ) + dnumber * (dfinalcomma  + dcommayes )
local dcpfinalnumber = dtemplate * (dfinalperiod + dperiodnop) + dnumber * (dfinalperiod + dperiodyes)

local dpcinternumber = dtemplate * (dintercomma  + dcommanop ) + dnumber * (dintercomma  + dcommayes )
local dcpinternumber = dtemplate * (dinterperiod + dperiodnop) + dnumber * (dinterperiod + dperiodyes)

local dfallback      = (dtemplate * (dcommanop + dperiodnop)^0)^0 * (dcommayes + dperiodyes + ddigit)^0

local p_c_number     = (dcpinternumber)^0 * (dpcfinalnumber)^0 * ddigit + dfallback -- 000.000.000,00
local c_p_number     = (dpcinternumber)^0 * (dcpfinalnumber)^0 * ddigit + dfallback -- 000,000,000.00

-- ony signs before numbers (otherwise we get s / seconds issues)
--
local p_c_dparser    = dleader * p_c_number * dtrailer * dfinal
local c_p_dparser    = dleader * c_p_number * dtrailer * dfinal

-- local p_c_dparser    = p_c_number * dtrailer * dfinal
-- local c_p_dparser    = c_p_number * dtrailer * dfinal

function commands.digits(str,p_c)
    if p_c == v_reverse then
        matchlpeg(p_c_dparser,str)
    else
        matchlpeg(c_p_dparser,str)
    end
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
--  Litre      = [[l]],
    Gram       = [[g]],
    Newton     = [[N]],
    Pascal     = [[Pa]],
    Atom       = [[u]],
    Joule      = [[J]],
    Watt       = [[W]],
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

mergetable(long_suffixes,loweredkeys(long_suffixes))

local long_prefixes_to_long  = { } for k, v in next, long_prefixes  do long_prefixes_to_long [lower(k)] = k end
local long_units_to_long     = { } for k, v in next, long_units     do long_units_to_long    [lower(k)] = k end
local long_operators_to_long = { } for k, v in next, long_operators do long_operators_to_long[lower(k)] = k end

local short_prefixes_to_long = {
    y  = "Yocto",
    z  = "Zetto",
    a  = "Atto",
    f  = "Femto",
    p  = "Pico",
    n  = "Nano",
    u  = "Micro",
    m  = "Milli",
    c  = "Centi",
    d  = "Deci",
    da = "Deca",
    h  = "Hecto",
    k  = "Kilo",
    M  = "Mega",
    G  = "Giga",
    T  = "Tera",
    P  = "Peta",
    E  = "Exa",
    Z  = "Zetta",
    Y  = "Yotta",
}

local short_units_to_long = { -- I'm not sure about casing
    m  = "Meter",
    Hz = "Hertz",
    hz = "Hertz",
    u  = "Hour",
    h  = "Hour",
    s  = "Second",
    g  = "Gram",
    n  = "Newton",
    v  = "Volt",

    l  = "Liter",
 -- w  = "Watt",
    W  = "Watt",
 -- a  = "Ampere",
    A  = "Ampere",

    Litre = "Liter",
    Metre = "Meter",
}

local short_operators_to_long = {
    ["."] = "Times",
    ["*"] = "Times",
    ["/"] = "Solidus",
    [":"] = "OutOf",
}

short_prefixes  = { } for k, v in next, short_prefixes_to_long  do short_prefixes [k] = long_prefixes [v] end
short_units     = { } for k, v in next, short_units_to_long     do short_units    [k] = long_units    [v] end
short_operators = { } for k, v in next, short_operators_to_long do short_operators[k] = long_operators[v] end

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

local prefixes   = long_prefixes
local units      = long_units
local operators  = long_operators
local suffixes   = long_suffixes

local somespace  = P(" ")^0/""

local l_prefix   = appendlpeg(keys(long_prefixes))
local l_unit     = appendlpeg(keys(long_units))
local l_operator = appendlpeg(keys(long_operators))
local l_suffix   = appendlpeg(keys(long_suffixes))

local l_prefix   = appendlpeg(long_prefixes_to_long,l_prefix)
local l_unit     = appendlpeg(long_units_to_long,l_unit)
local l_operator = appendlpeg(long_operators_to_long,l_operator)

local s_prefix   = appendlpeg(short_prefixes_to_long)
local s_unit     = appendlpeg(short_units_to_long)
local s_operator = appendlpeg(short_operators_to_long)

local s_suffix   = appendlpeg(keys(short_suffixes))

-- space inside Cs else funny captures and args to function

-- square centi meter per square kilo seconds

local l_suffix   = Cs(somespace * l_suffix)
local s_suffix   = Cs(somespace * s_suffix) + Cc("")
local l_operator = Cs(somespace * l_operator)

local combination = P { "start",
    l_prefix = Cs(somespace * l_prefix) + Cc(""),
    s_prefix = Cs(somespace * s_prefix) + Cc(""),
    l_unit   = Cs(somespace * l_unit),
    s_unit   = Cs(somespace * s_unit),
    start    = V("l_prefix") * V("l_unit")
             + V("s_prefix") * V("s_unit")
             + V("l_prefix") * V("s_unit")
             + V("s_prefix") * V("l_unit"),
}

-- inspect(s_prefix)
-- inspect(s_unit)
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

local l_prefixes  = allocate()
local l_units     = allocate()
local l_operators = allocate()

local labels = languages.data.labels or { }

labels.prefixes  = l_prefixes
labels.units     = l_units
labels.operators = l_operators

l_prefixes .test = { Kilo = "kilo" }
l_units    .test = { Meter = "meter", Second = "second" }
l_operators.test = { Solidus = " per " }

local function dimpus(p,u,s,wherefrom)
--~ print(p,u,s,wherefrom)
    if wherefrom == "" then
        p = prefixes[p] or p
        u = units   [u] or u
    else
        local lp = l_prefixes[wherefrom]
        local lu = l_units   [wherefrom]
        p = lp and lp[p] or p
        u = lu and lu[u] or u
    end
    s = suffixes[s] or s
    --
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

local function dimspu(s,p,u,wherefrom)
    return dimpus(p,u,s,wherefrom)
end

local function dimop(o,wherefrom)
--~ print(o,wherefrom)
    if wherefrom == "" then
        o = operators[o] or o
    else
        local lo = l_operators[wherefrom]
        o = lo and lo[o] or o
    end
    if o then
        unitsO(o)
    end
end

-- todo 0x -> rm
-- pretty large lpeg (maybe do dimension lookup otherwise)
-- not ok yet ... we have this p n s problem

local dimension = ((l_suffix * combination)   * Carg(1)) / dimspu
                + ((combination * s_suffix)   * Carg(1)) / dimpus
local number    = lpeg.patterns.number                   / unitsN
local operator  = C((l_operator + s_operator) * Carg(1)) / dimop  -- weird, why is the extra C needed here
local whatever  = (P(1)^0)                               / unitsU

local number    = (1-R("az","AZ")-P(" "))^1 / unitsN -- todo: catch { }

dimension = somespace * dimension * somespace
number    = somespace * number    * somespace
operator  = somespace * operator  * somespace

local unitparser = dimension^1 * (operator * dimension^1)^-1 + whatever + P(-1)

local p_c_unitdigitparser = (Cc(nil)/unitsNstart) * p_c_dparser * (Cc(nil)/unitsNstop) --
local c_p_unitdigitparser = (Cc(nil)/unitsNstart) * c_p_dparser * (Cc(nil)/unitsNstop) --

local p_c_combinedparser  = dleader * (p_c_unitdigitparser + number)^-1 * unitparser
local c_p_combinedparser  = dleader * (c_p_unitdigitparser + number)^-1 * unitparser

function commands.unit(str,wherefrom,p_c)
    if p_c == v_reverse then
        matchlpeg(p_c_combinedparser,str,1,wherefrom or "")
    else
        matchlpeg(c_p_combinedparser,str,1,wherefrom or "")
    end
end
