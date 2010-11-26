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

regimes.synonyms = regimes.synonyms or { }
local synonyms   = regimes.synonyms

if storage then
    storage.register("regimes/synonyms", synonyms, "regimes.synonyms")
else
    regimes.synonyms = { }
end

-- setmetatable(regimes.data,_empty_table_)

regimes.currentregime = "utf"

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

function regimes.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

function regimes.setsynonym(synonym,target)
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

-- function regimes.enable(regime)
--     regime = synonyms[regime] or regime
--     if data[regime] then
--         regimes.currentregime = regime
--         local translate = regimes.translate
--         resolvers.filters.install('input',function(s)
--             return translate(s,regime)
--         end)
--     else
--         regimes.disable()
--     end
-- end
--
-- function regimes.disable()
--     regimes.currentregime = "utf"
--     resolvers.filters.install('input',nil)
-- end

local sequencers = utilities.sequencers

function regimes.process(s)
    return translate(s,regimes.currentregime)
end

function regimes.enable(regime)
    regime = synonyms[regime] or regime
    if data[regime] then
        regimes.currentregime = regime
        sequencers.enableaction(resolvers.openers.textfileactions,"regimes.process")
    else
        sequencers.disableaction(resolvers.openers.textfileactions,"regimes.process")
    end
end

function regimes.disable()
    regimes.currentregime = "utf"
    sequencers.disableaction(resolvers.openers.textfileactions,"regimes.process")
end

utilities.sequencers.prependaction(resolvers.openers.textfileactions,"system","regimes.process")
utilities.sequencers.disableaction(resolvers.openers.textfileactions,"regimes.process")
