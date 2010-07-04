if not modules then modules = { } end modules ['regi-ini'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local char, utfchar, gsub = string.char, utf.char, string.gsub
local texsprint = tex.sprint

local ctxcatcodes = tex.ctxcatcodes

--[[ldx--
<p>Regimes take care of converting the input characters into
<l n='utf'/> sequences. The conversion tables are loaded at
runtime.</p>
--ldx]]--

regimes          = regimes          or { }
regimes.data     = regimes.data     or { }
regimes.utf      = regimes.utf      or { }
regimes.synonyms = regimes.synonyms or { }

storage.register("regimes/synonyms", regimes.synonyms, "regimes.synonyms")

-- setmetatable(regimes.data,_empty_table_)

regimes.currentregime = "utf"

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

function regimes.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

function regimes.setsynonym(synonym,target)
    regimes.synonyms[synonym] = target
end

function regimes.truename(regime)
    texsprint(ctxcatcodes,(regime and regimes.synonyms[synonym] or regime) or regimes.currentregime)
end

function regimes.load(regime)
    regime = regimes.synonyms[regime] or regime
    if not regimes.data[regime] then
        environment.loadluafile("regi-"..regime, 1.001)
        if regimes.data[regime] then
            regimes.utf[regime] = { }
            for k,v in next, regimes.data[regime] do
                regimes.utf[regime][char(k)] = utfchar(v)
            end
        end
    end
end

function regimes.translate(line,regime)
    regime = regimes.synonyms[regime] or regime
    if regime and line then
        local rur = regimes.utf[regime]
        if rur then
            return (gsub(line,"(.)",rur)) -- () redundant
        end
    end
    return line
end

function regimes.enable(regime)
    regime = regimes.synonyms[regime] or regime
    if regimes.data[regime] then
        regimes.currentregime = regime
        local translate = regimes.translate
        resolvers.install_text_filter('input',function(s)
            return translate(s,regime)
        end)
    else
        regimes.disable()
    end
end

function regimes.disable()
    regimes.currentregime = "utf"
    resolvers.install_text_filter('input',nil)
end
