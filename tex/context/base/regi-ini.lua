if not modules then modules = { } end modules ['regi-ini'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local char, utfchar, gsub = string.char, utf.char, string.gsub

--[[ldx--
<p>Regimes take care of converting the input characters into
<l n='utf'/> sequences. The conversion tables are loaded at
runtime.</p>
--ldx]]--

regimes          = regimes or { }
local regimes    = regimes

regimes.data     = regimes.data or { }
local data       = regimes.data

regimes.utf      = regimes.utf or { }

-- regimes.synonyms = regimes.synonyms or { }
-- local synonyms   = regimes.synonyms
--
-- if storage then
--     storage.register("regimes/synonyms", synonyms, "regimes.synonyms")
-- else
--     regimes.synonyms = { }
-- end

local synonyms = {

    ["windows-1250"]  = "cp1250",
    ["windows-1251"]  = "cp1251",
    ["windows-1252"]  = "cp1252",
    ["windows-1253"]  = "cp1253",
    ["windows-1254"]  = "cp1254",
    ["windows-1255"]  = "cp1255",
    ["windows-1256"]  = "cp1256",
    ["windows-1257"]  = "cp1257",
    ["windows-1258"]  = "cp1258",

    ["il1"]           = "8859-1",
    ["il2"]           = "8859-2",
    ["il3"]           = "8859-3",
    ["il4"]           = "8859-4",
    ["il5"]           = "8859-9",
    ["il6"]           = "8859-10",
    ["il7"]           = "8859-13",
    ["il8"]           = "8859-14",
    ["il9"]           = "8859-15",
    ["il10"]          = "8859-16",

    ["iso-8859-1"]    = "8859-1",
    ["iso-8859-2"]    = "8859-2",
    ["iso-8859-3"]    = "8859-3",
    ["iso-8859-4"]    = "8859-4",
    ["iso-8859-9"]    = "8859-9",
    ["iso-8859-10"]   = "8859-10",
    ["iso-8859-13"]   = "8859-13",
    ["iso-8859-14"]   = "8859-14",
    ["iso-8859-15"]   = "8859-15",
    ["iso-8859-16"]   = "8859-16",

    ["latin1"]        = "8859-1",
    ["latin2"]        = "8859-2",
    ["latin3"]        = "8859-3",
    ["latin4"]        = "8859-4",
    ["latin5"]        = "8859-9",
    ["latin6"]        = "8859-10",
    ["latin7"]        = "8859-13",
    ["latin8"]        = "8859-14",
    ["latin9"]        = "8859-15",
    ["latin10"]       = "8859-16",

    ["utf-8"]         = "utf",
    ["utf8"]          = "utf",

    ["windows"]       = "cp1252",

}

regimes.currentregime = "utf"

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

function regimes.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

function regimes.setsynonym(synonym,target) -- more or less obsolete
    synonyms[synonym] = target
end

function regimes.truename(regime)
    context((regime and synonyms[synonym] or regime) or regimes.currentregime)
end

function regimes.load(regime)
    regime = synonyms[regime] or regime
    if not data[regime] then
        environment.loadluafile("regi-"..regime, 1.001)
        if data[regime] then
            regimes.utf[regime] = { }
            for k,v in next, data[regime] do
                regimes.utf[regime][char(k)] = utfchar(v)
            end
        end
    end
end

function regimes.translate(line,regime)
    regime = synonyms[regime] or regime
    if regime and line then
        local rur = regimes.utf[regime]
        if rur then
            return (gsub(line,"(.)",rur)) -- () redundant
        end
    end
    return line
end

local sequencers      = utilities.sequencers
local textlineactions = resolvers.openers.helpers.textlineactions

function regimes.process(s)
    return regimes.translate(s,regimes.currentregime)
end

function regimes.enable(regime)
    regime = synonyms[regime] or regime
    if data[regime] then
        regimes.currentregime = regime
        sequencers.enableaction(textlineactions,"regimes.process")
    else
        sequencers.disableaction(textlineactions,"regimes.process")
    end
end

function regimes.disable()
    regimes.currentregime = "utf"
    sequencers.disableaction(textlineactions,"regimes.process")
end

utilities.sequencers.prependaction(textlineactions,"system","regimes.process")
utilities.sequencers.disableaction(textlineactions,"regimes.process")
