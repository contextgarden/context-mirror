if not modules then modules = { } end modules ['regi-ini'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Regimes take care of converting the input characters into
<l n='utf'/> sequences. The conversion tables are loaded at
runtime.</p>
--ldx]]--

regimes         = regimes         or { }
regimes.data    = regimes.data    or { }
regimes.utf     = regimes.utf     or { }
regimes.context = regimes.context or { }

-- setmetatable(regimes.data,_empty_table_)

regimes.currentregime = ""

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

input         = input         or { }
input.filters = input.filters or { }

function regimes.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

function regimes.define(c) -- is this used at all?
    local r, u, s = c.regime, c.unicodeslot, c.slot
    regimes.data[r] = regimes.data[r] or { }
    if s then
        if u then
            regimes.data[r][regimes.number(s)] = regimes.number(u)
        else
            regimes.data[r][regimes.number(s)] = 0
        end
    else
        logs.report("regime","unknown vector %s/%s",r,s) -- ctx.statusmessage
    end
end

function regimes.load(regime)
    environment.loadluafile("regi-"..regime, 1.001)
    if regimes.data[regime] then
        regimes.utf[regime] = { }
        for k,v in pairs(regimes.data[regime]) do
            regimes.utf[regime][string.char(k)] = unicode.utf8.char(v)
        end
    end
end

function regimes.translate(line,regime)
    if regime and line then
        local rur = regimes.utf[regime]
        if rur then
            return line:gsub("(.)", rur) -- () redundant
        end
    end
    return line
end

function regimes.enable(regime)
    if regimes.data[regime] then
        regimes.currentregime = regime
        local translate = regimes.translate
        input.filters.dynamic_translator = function(s)
            return translate(s,regime)
        end
    else
        regimes.disable()
    end
end

function regimes.disable()
    regimes.currentregime            = ""
    input.filters.dynamic_translator = nil
end

function input.filters.frozen_translator(regime)
    return function(s)
        return regimes.translate(s,regime)
    end
end

--[[ldx--
<p>The following code is rather <l n='context'/> specific.</p>
--ldx]]--

function regimes.context.show(regime)
    local flush, tc = tex.sprint, tex.ctxcatcodes
    local r = regimes.data[regime]
    if r then
        flush(tc, "\\starttabulate[|rT|T|rT|lT|lT|lT|]")
        for k, v in ipairs(r) do
            flush(tc, string.format("\\NC %s\\NC\\getvalue{%s}\\NC %s\\NC %s\\NC %s\\NC %s\\NC\\NR", k,
                characters.contextname(v), characters.hexindex(v), characters.contextname(v),
                characters.category(v), characters.description(v)))
        end
        flush(tc, "\\stoptabulate")
    else
        flush(tc, "unknown regime " .. regime)
    end
end
