if not modules then modules = { } end modules ['regi-ini'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Regimes take care of converting the input characters into
<l n='utf'/> sequences. The conversion tables are loaded at
runtime.</p>
--ldx]]--

local utfchar = utf.char
local char, gsub, format = string.char, string.gsub, string.format
local next = next
local insert, remove = table.insert, table.remove

local sequencers        = utilities.sequencers
local textlineactions   = resolvers.openers.helpers.textlineactions
local setmetatableindex = table.setmetatableindex

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

local trace_translating = false  trackers.register("regimes.translating", function(v) trace_translating = v end)

local report_loading     = logs.reporter("regimes","loading")
local report_translating = logs.reporter("regimes","translating")

regimes        = regimes or { }
local regimes  = regimes

local mapping  = {
    utf = false
}

local synonyms = { -- backward compatibility list

    ["windows-1250"] = "cp1250",
    ["windows-1251"] = "cp1251",
    ["windows-1252"] = "cp1252",
    ["windows-1253"] = "cp1253",
    ["windows-1254"] = "cp1254",
    ["windows-1255"] = "cp1255",
    ["windows-1256"] = "cp1256",
    ["windows-1257"] = "cp1257",
    ["windows-1258"] = "cp1258",

    ["il1"]          = "8859-1",
    ["il2"]          = "8859-2",
    ["il3"]          = "8859-3",
    ["il4"]          = "8859-4",
    ["il5"]          = "8859-9",
    ["il6"]          = "8859-10",
    ["il7"]          = "8859-13",
    ["il8"]          = "8859-14",
    ["il9"]          = "8859-15",
    ["il10"]         = "8859-16",

    ["iso-8859-1"]   = "8859-1",
    ["iso-8859-2"]   = "8859-2",
    ["iso-8859-3"]   = "8859-3",
    ["iso-8859-4"]   = "8859-4",
    ["iso-8859-9"]   = "8859-9",
    ["iso-8859-10"]  = "8859-10",
    ["iso-8859-13"]  = "8859-13",
    ["iso-8859-14"]  = "8859-14",
    ["iso-8859-15"]  = "8859-15",
    ["iso-8859-16"]  = "8859-16",

    ["latin1"]       = "8859-1",
    ["latin2"]       = "8859-2",
    ["latin3"]       = "8859-3",
    ["latin4"]       = "8859-4",
    ["latin5"]       = "8859-9",
    ["latin6"]       = "8859-10",
    ["latin7"]       = "8859-13",
    ["latin8"]       = "8859-14",
    ["latin9"]       = "8859-15",
    ["latin10"]      = "8859-16",

    ["utf-8"]        = "utf",
    ["utf8"]         = "utf",
    [""]             = "utf",

    ["windows"]      = "cp1252",

}

local currentregime = "utf"

local function loadregime(mapping,regime)
    local name = resolvers.findfile(format("regi-%s.lua",regime)) or ""
    local data = name ~= "" and dofile(name)
    if data then
        vector = { }
        for eightbit, unicode in next, data do
            vector[char(eightbit)] = utfchar(unicode)
        end
        report_loading("vector '%s' is loaded",regime)
    else
        vector = false
        report_loading("vector '%s' is unknown",regime)
    end
    mapping[regime] = vector
    return vector
end

setmetatableindex(mapping, loadregime)

local function translate(line,regime)
    if line and #line > 0 then
        local map = mapping[regime and synonyms[regime] or regime or currentregime]
        if map then
            line = gsub(line,".",map)
        end
    end
    return line
end

local function disable()
    currentregime = "utf"
    sequencers.disableaction(textlineactions,"regimes.process")
end

local function enable(regime)
    regime = synonyms[regime] or regime
    if mapping[regime] == false then
        disable()
    else
        currentregime = regime
        sequencers.enableaction(textlineactions,"regimes.process")
    end
end

regimes.translate = translate
regimes.enable    = enable
regimes.disable   = disable

-- The following function can be used when we want to make sure that
-- utf gets passed unharmed. This is needed for modules.

local level = 0

function regimes.process(str,filename,currentline,noflines,coding)
    if level == 0 and coding ~= "utf-8" then
        str = translate(str,currentregime)
        if trace_translating then
            report_translating("utf: %s",str)
        end
    end
    return str
end

function regimes.push()
    level = level + 1
    if trace_translating then
        report_translating("pushing level: %s",level)
    end
end

function regimes.pop()
    if level > 0 then
        if trace_translating then
            report_translating("popping level: %s",level)
        end
        level = level - 1
    end
end

sequencers.prependaction(textlineactions,"system","regimes.process")
sequencers.disableaction(textlineactions,"regimes.process")

-- interface:

commands.enableregime  = enable
commands.disableregime = disable

function commands.currentregime()
    context(currentregime)
end

local stack = { }

function commands.startregime(regime)
    insert(stack,currentregime)
    if trace_translating then
        report_translating("start: '%s'",regime)
    end
    enable(regime)
end

function commands.stopregime()
    if #stack > 0 then
        local regime = remove(stack)
        if trace_translating then
            report_translating("stop: '%s'",regime)
        end
        enable(regime)
    end
end

-- obsolete:
--
-- function regimes.setsynonym(synonym,target)
--     synonyms[synonym] = target
-- end
--
-- function regimes.truename(regime)
--     return regime and synonyms[regime] or regime or currentregime
-- end
--
-- commands.setregimesynonym = regimes.setsynonym
--
-- function commands.trueregimename(regime)
--     context(regimes.truename(regime))
-- end
--
-- function regimes.load(regime)
--     return mapping[synonyms[regime] or regime]
-- end
