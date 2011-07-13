if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup (share locals)
-- discard language when redefined

-- 002D : hyphen-minus (ascii)
-- 2010 : hyphen
-- 2011 : nonbreakable hyphen
-- 2013 : endash (compound hyphen)

--~ lang:hyphenation(string) string = lang:hyphenation() lang:clear_hyphenation()

local type, tonumber = type, tonumber
local utf = unicode.utf8
local utfbyte = utf.byte
local format, gsub = string.format, string.gsub
local concat, sortedkeys, sortedpairs = table.concat, table.sortedkeys, table.sortedpairs
local lpegmatch = lpeg.match

local settings_to_array = utilities.parsers.settings_to_array

local trace_patterns = false  trackers.register("languages.patterns", function(v) trace_patterns = v end)

local report_initialization = logs.reporter("languages","initialization")

local prehyphenchar  = lang.prehyphenchar -- global per language
local posthyphenchar = lang.posthyphenchar -- global per language
local lefthyphenmin  = lang.lefthyphenmin
local righthyphenmin = lang.righthyphenmin

lang.exceptions      = lang.hyphenation

languages            = languages or {}
local languages      = languages

languages.version    = 1.010

languages.registered = languages.registered or { }
local registered     = languages.registered

languages.associated = languages.associated or { }
local associated     = languages.associated

languages.numbers    = languages.numbers    or { }
local numbers        = languages.numbers

languages.data       = languages.data       or { }
local data           = languages.data

storage.register("languages/numbers",   numbers,   "languages.numbers")
storage.register("languages/registered",registered,"languages.registered")
storage.register("languages/associated",associated,"languages.associated")
storage.register("languages/data",      data,      "languages.data")

local nofloaded  = 0

local function resolve(tag)
    local data, instance = registered[tag], nil
    if data then
        instance = data.instance
        if not instance then
            instance = lang.new(data.number)
            data.instance = instance
        end
    end
    return data, instance
end

local function tolang(what) -- returns lang object
    local tag = numbers[what]
    local data = tag and registered[tag] or registered[what]
    if data then
        local instance = data.lang
        if not instance then
            instance = lang.new(data.number)
            data.instance = instance
        end
        return instance
    end
end

-- languages.tolang = tolang

-- todo: en+de => merge

local function loaddefinitions(tag,specification)
    statistics.starttiming(languages)
    local data, instance = resolve(tag)
    local definitions = settings_to_array(specification.patterns or "")
    if #definitions > 0 then
        if trace_patterns then
            report_initialization("pattern specification for language '%s': %s",tag,specification.patterns)
        end
        local dataused, ok = data.used, false
        for i=1,#definitions do
            local definition = definitions[i]
            if definition ~= "" then
                if definition == "reset" then -- interfaces.variables.reset
                    if trace_patterns then
                        report_initialization("clearing patterns for language '%s'",tag)
                    end
                    instance:clear_patterns()
                elseif not dataused[definition] then
                    dataused[definition] = definition
                    local filename = "lang-" .. definition .. ".lua"
                    local fullname = resolvers.findfile(filename) or ""
                    if fullname ~= "" then
                        if trace_patterns then
                            report_initialization("loading definition '%s' for language '%s' from '%s'",definition,tag,fullname)
                        end
                        local defs = dofile(fullname) -- use regular loader instead
                        if defs then -- todo: version test
                            ok, nofloaded = true, nofloaded + 1
                            instance:patterns   (defs.patterns   and defs.patterns.data   or "")
                            instance:hyphenation(defs.exceptions and defs.exceptions.data or "")
                        else
                            report_initialization("invalid definition '%s' for language '%s' in '%s'",definition,tag,filename)
                        end
                    elseif trace_patterns then
                        report_initialization("invalid definition '%s' for language '%s' in '%s'",definition,tag,filename)
                    end
                elseif trace_patterns then
                    report_initialization("definition '%s' for language '%s' already loaded",definition,tag)
                end
            end
        end
        return ok
    elseif trace_patterns then
        report_initialization("no definitions for language '%s'",tag)
    end
    statistics.stoptiming(languages)
end

storage.shared.noflanguages = storage.shared.noflanguages or 0

local noflanguages = storage.shared.noflanguages

function languages.define(tag,parent)
    noflanguages = noflanguages + 1
    if trace_patterns then
        report_initialization("assigning number %s to %s",noflanguages,tag)
    end
    numbers[noflanguages] = tag
    registered[tag] = {
        tag      = tag,
        parent   = parent or "",
        patterns = "",
        loaded   = false,
        used     = { },
        dirty    = true,
        number   = noflanguages,
        instance = nil, -- luatex data structure
        synonyms = { },
    }
    storage.shared.noflanguages = noflanguages
end

function languages.synonym(synonym,tag) -- convenience function
    local l = registered[tag]
    if l then
        l.synonyms[synonym] = true -- maybe some day more info
    end
end

function languages.installed(separator)
    context(concat(sortedkeys(registered),separator or ","))
end

function languages.current(n)
    return numbers[n and tonumber(n) or tex.language]
end

function languages.associate(tag,script,language) -- not yet used
    associated[tag] = { script, language }
end

function languages.association(tag) -- not yet used
    if type(tag) == "number" then
        tag = numbers[tag]
    end
    local lat = tag and associated[tag]
    if lat then
        return lat[1], lat[2]
    else
        return nil, nil
    end
end

function languages.loadable(tag,defaultlanguage) -- hack
    local l = registered[tag] -- no synonyms
    if l and resolvers.findfile("lang-"..l.patterns..".lua") then
        return true
    else
        return false
    end
end

-- a bit messy, we will do all language setting in lua as we can now assign
-- and 'patterns' will go away here.

function languages.setdirty(tag)
    local l = registered[tag]
    if l then
        l.dirty = true
    end
end

if environment.initex then

    function languages.getnumber()
        return 0
    end

    function commands.languagenumber()
        context(0)
    end

else

    local function getnumber(tag,default,patterns)
        local l = registered[tag]
        if l then
            if l.dirty then
                if trace_patterns then
                    report_initialization("checking patterns for %s (%s)",tag,default)
                end
                -- patterns is already resolved to parent patterns if applicable
                if patterns and patterns ~= "" then
                    if l.patterns ~= patterns then
                        l.patterns = patterns
                        if trace_patterns then
                            report_initialization("loading patterns for '%s' using specification '%s'",tag,patterns)
                        end
                        loaddefinitions(tag,l)
                    else
                        -- unchanged
                    end
                elseif l.patterns == "" then
                    l.patterns = tag
                    if trace_patterns then
                        report_initialization("loading patterns for '%s' using tag",tag)
                    end
                    local ok = loaddefinitions(tag,l)
                    if not ok and tag ~= default then
                        l.patterns = default
                        if trace_patterns then
                            report_initialization("loading patterns for '%s' using default",tag)
                        end
                        loaddefinitions(tag,l)
                    end
                end
                l.loaded = true
                l.dirty = false
            end
            return l.number
        else
            return 0
        end
    end

    languages.getnumber = getnumber

    function commands.languagenumber(tag,default,patterns)
        context(getnumber(tag,default,patterns))
    end

end

-- not that usefull, global values

function languages.prehyphenchar (what) return prehyphenchar (tolang(what)) end
function languages.posthyphenchar(what) return posthyphenchar(tolang(what)) end
function languages.lefthyphenmin (what) return lefthyphenmin (tolang(what)) end
function languages.righthyphenmin(what) return righthyphenmin(tolang(what)) end

-- e['implementer']= 'imple{m}{-}{-}menter'
-- e['manual'] = 'man{}{}{}'
-- e['as'] = 'a-s'
-- e['user-friendly'] = 'user=friend-ly'
-- e['exceptionally-friendly'] = 'excep-tionally=friend-ly'

function languages.loadwords(tag,filename)
    local data, instance = resolve(tag)
    if data then
        statistics.starttiming(languages)
        instance:hyphenation(io.loaddata(filename) or "")
        statistics.stoptiming(languages)
    end
end

function languages.exceptions(tag,str)
    local data, instance = resolve(tag)
    if data then
        instance:hyphenation(string.strip(str)) -- we need to strip leading spaces
    end
end

function languages.hyphenate(tag,str)
    -- todo: does this still work?
    local data, instance = resolve(tag)
    if data then
        return instance:hyphenate(str)
    else
        return str
    end
end

--~ hyphenation.define        ("zerolanguage")
--~ hyphenation.loadpatterns  ("zerolanguage") -- else bug
--~ hyphenation.loadexceptions("zerolanguage") -- else bug

languages.logger = languages.logger or { }

function languages.logger.report()
    local result, r = { }, 0
    for tag, l in sortedpairs(registered) do
        if l.loaded then
            r = r + 1
            result[r] = format("%s:%s:%s", tag, l.parent, l.number)
        end
    end
    return (r > 0 and concat(result," ")) or "none"
end

-- must happen at the tex end

languages.associate('en','latn','eng')
languages.associate('uk','latn','eng')
languages.associate('nl','latn','nld')
languages.associate('de','latn','deu')
languages.associate('fr','latn','fra')

statistics.register("loaded patterns", function()
    local result = languages.logger.report()
    if result ~= "none" then
        return result
    end
end)

statistics.register("language load time", function()
    return statistics.elapsedseconds(languages, format(", nofpatterns: %s",nofloaded))
end)

--~ -- obsolete
--~ --
--~ -- loading the 26 languages that we normally load in mkiv, the string based variant
--~ -- takes .84 seconds (probably due to the sub's) while the lpeg variant takes .78
--~ -- seconds
--~ --
--~ -- the following lpeg can probably be improved (it was one of the first I made)

--~ local leftbrace  = lpeg.P("{")
--~ local rightbrace = lpeg.P("}")
--~ local spaces     = lpeg.S(" \r\n\t\f")
--~ local spacing    = spaces^0
--~ local validchar  = 1-(spaces+rightbrace+leftbrace)
--~ local validword  = validchar^1
--~ local content    = spacing * leftbrace * spacing * lpeg.C((spacing * validword)^0) * spacing * rightbrace * lpeg.P(true)
--~
--~ local command    = lpeg.P("\\patterns")
--~ local parser     = (1-command)^0 * command * content
--~
--~ local function filterpatterns(filename)
--~     return lpegmatch(parser,io.loaddata(resolvers.findfile(filename)) or "")
--~ end
--~
--~ local command = lpeg.P("\\hyphenation")
--~ local parser  = (1-command)^0 * command * content
--~
--~ local function filterexceptions(filename)
--~     return lpegmatch(parser,io.loaddata(resolvers.findfile(filename)) or "") -- "" ?
--~ end
--~
--~ local function loadthem(tag, filename, filter, target)
--~     statistics.starttiming(languages)
--~     local data, instance = resolve(tag)
--~     local fullname = (filename and filename ~= "" and resolvers.findfile(filename)) or ""
--~     local ok = fullname ~= ""
--~     if ok then
--~         if trace_patterns then
--~             report_initialization("filtering %s for language '%s' from '%s'",target,tag,fullname)
--~         end
--~         lang[target](data,filter(fullname) or "")
--~     else
--~         if trace_patterns then
--~             report_initialization("no %s for language '%s' in '%s'",target,tag,filename or "?")
--~         end
--~         lang[target](instance,"")
--~     end
--~     statistics.stoptiming(languages)
--~     return ok
--~ end
--~
--~ function hyphenation.loadpatterns(tag, patterns)
--~     return loadthem(tag, patterns, filterpatterns, "patterns")
--~ end
--~
--~ function hyphenation.loadexceptions(tag, exceptions)
--~     return loadthem(tag, exceptions, filterexceptions, "exceptions")
--~ end
