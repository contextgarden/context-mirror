if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup (share locals)

local utf = unicode.utf8
local utfbyte = utf.byte
local format = string.format
local concat = table.concat
local lpegmatch = lpeg.match

local trace_patterns = false  trackers.register("languages.patterns",  function(v) trace_patterns = v end)

languages                  = languages or {}
languages.version          = 1.009
languages.hyphenation      = languages.hyphenation        or { }
languages.hyphenation.data = languages.hyphenation.data   or { }

local langdata = languages.hyphenation.data

-- 002D : hyphen-minus (ascii)
-- 2010 : hyphen
-- 2011 : nonbreakable hyphen
-- 2013 : endash (compound hyphen)

--~ lang:hyphenation(string)
--~ string  =lang:hyphenation()
--~ lang:clear_hyphenation()

-- we can consider hiding data (faster access too)

-- loading the 26 languages that we normally load in mkiv, the string based variant
-- takes .84 seconds (probably due to the sub's) while the lpeg variant takes .78
-- seconds
--
-- the following lpeg can probably be improved (it was one of the first I made)

local leftbrace  = lpeg.P("{")
local rightbrace = lpeg.P("}")
local spaces     = lpeg.S(" \r\n\t\f")
local spacing    = spaces^0
local validchar  = 1-(spaces+rightbrace+leftbrace)
local validword  = validchar^1
local content    = spacing * leftbrace * spacing * lpeg.C((spacing * validword)^0) * spacing * rightbrace * lpeg.P(true)

local command    = lpeg.P("\\patterns")
local parser     = (1-command)^0 * command * content

local function filterpatterns(filename)
    if file.extname(filename) == "rpl" then
        return io.loaddata(resolvers.find_file(filename)) or ""
    else
        return lpegmatch(parser,io.loaddata(resolvers.find_file(filename)) or "")
    end
end

local command = lpeg.P("\\hyphenation")
local parser  = (1-command)^0 * command * content

local function filterexceptions(filename)
    if file.extname(filename) == "rhl" then
        return io.loaddata(resolvers.find_file(filename)) or ""
    else
        return lpegmatch(parser,io.loaddata(resolvers.find_file(filename)) or {}) -- "" ?
    end
end

local function record(tag)
    local data = langdata[tag]
    if not data then
         data = lang.new()
         langdata[tag] = data or 0
    end
    return data
end

languages.hyphenation.record = record

function languages.hyphenation.define(tag)
    local data = record(tag)
    return data:id()
end

function languages.hyphenation.number(tag)
    local d = langdata[tag]
    return (d and d:id()) or 0
end

lang.exceptions = lang.hyphenation

local function loadthem(tag, filename, filter, target)
    statistics.starttiming(languages)
    local data = record(tag)
    local fullname = (filename and filename ~= "" and resolvers.find_file(filename)) or ""
    local ok = fullname ~= ""
    if ok then
        if trace_patterns then
            logs.report("languages","filtering %s for language '%s' from '%s'",target,tag,fullname)
        end
        lang[target](data,filterpatterns(fullname))
    else
        if trace_patterns then
            logs.report("languages","no %s for language '%s' in '%s'",target,tag,filename or "?")
        end
        lang[target](data,"")
    end
    langdata[tag] = data
    statistics.stoptiming(languages)
    return ok
end

function languages.hyphenation.loadpatterns(tag, patterns)
    return loadthem(tag, patterns, filterpatterns, "patterns")
end

function languages.hyphenation.loadexceptions(tag, exceptions)
    return loadthem(tag, patterns, filterexceptions, "exceptions")
end

function languages.hyphenation.exceptions(tag, ...)
    local data = record(tag)
    data:hyphenation(...)
end

function languages.hyphenation.hyphenate(tag, str)
    return lang.hyphenate(record(tag), str)
end

function languages.hyphenation.lefthyphenmin(tag, value)
    local data = record(tag)
    if value then data:lefthyphenmin(value) end
    return data:lefthyphenmin()
end
function languages.hyphenation.righthyphenmin(tag, value)
    local data = record(tag)
    if value then data:righthyphenmin(value) end
    return data:righthyphenmin()
end

function languages.hyphenation.n()
    return table.count(langdata)
end

languages.registered = languages.registered or { }
languages.associated = languages.associated or { }
languages.numbers    = languages.numbers    or { }

storage.register("languages/registered",languages.registered,"languages.registered")
storage.register("languages/associated",languages.associated,"languages.associated")

local numbers    = languages.numbers
local registered = languages.registered
local associated = languages.associated

-- we can speed this one up with locals if needed

local function tolang(what)
    local kind = type(what)
    if kind == "number" then
        local w = what >= 0 and what <= 0x7FFF and numbers[what]
        return (w and langdata[w]) or 0
    elseif kind == "string" then
        return langdata[what]
    else
        return what
    end
end

function languages.setup(what,settings)
    what = languages.tolang(what or tex.language)
    local lefthyphen  = settings.lefthyphen
    local righthyphen = settings.righthyphen
    lefthyphen  = lefthyphen  ~= "" and lefthyphen  or nil
    righthyphen = righthyphen ~= "" and righthyphen or nil
    lefthyphen  = lefthyphen  and utfbyte(lefthyphen)  or 0
    righthyphen = righthyphen and utfbyte(righthyphen) or 0
    lang.posthyphenchar(what,lefthyphen)
    lang.prehyphenchar (what,righthyphen)
    lang.postexhyphenchar(what,lefthyphen)
    lang.preexhyphenchar (what,righthyphen)
end

function languages.prehyphenchar(what)
    return lang.prehyphenchar(tolang(what))
end
function languages.posthyphenchar(what)
    return lang.posthyphenchar(tolang(what))
end

languages.tolang = tolang

function languages.register(tag,parent,patterns,exceptions)
    parent = parent or tag
    registered[tag] = {
        parent     = parent,
        patterns   = patterns   or format("lang-%s.pat",parent),
        exceptions = exceptions or format("lang-%s.hyp",parent),
        loaded     = false,
        number     = 0,
    }
end

function languages.associate(tag,script,language)
    associated[tag] = { script, language }
end

function languages.association(tag)
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

function languages.loadable(tag)
    local l = registered[tag]
    if l and l.patterns and resolvers.find_file(patterns) then
        return true
    else
        return false
    end
end

languages.share = false -- we don't share language numbers

function languages.enable(tags)
    -- beware: we cannot set tex.language, but need tex.normallanguage
    for i=1,#tags do
        local tag = tags[i]
        local l = registered[tag]
        if l and l ~= "" then
            if not l.loaded then
                local tag = l.parent
                local number = languages.hyphenation.number(tag)
                if languages.share and number > 0 then
                    l.number = number
                else
                    -- we assume the same filenames
                    l.number = languages.hyphenation.define(tag)
                    languages.hyphenation.loadpatterns(tag,l.patterns)
                    languages.hyphenation.loadexceptions(tag,l.exceptions)
                    numbers[l.number] = tag
                end
                l.loaded = true
                if trace_patterns then
                    logs.report("languages","assigning number %s",l.number)
                end
            end
            if l.number > 0 then
                return l.number
            end
        end
    end
    return 0
end

-- e['implementer']= 'imple{m}{-}{-}menter'
-- e['manual'] = 'man{}{}{}'
-- e['as'] = 'a-s'
-- e['user-friendly'] = 'user=friend-ly'
-- e['exceptionally-friendly'] = 'excep-tionally=friend-ly'

function languages.hyphenation.loadwords(tag, filename)
    local id = languages.hyphenation.number(tag)
    if id > 0 then
        local l = lang.new(id) or 0
        statistics.starttiming(languages)
        local data = io.loaddata(filename) or ""
        l:hyphenation(data)
        statistics.stoptiming(languages)
    end
end

languages.hyphenation.define        ("zerolanguage")
languages.hyphenation.loadpatterns  ("zerolanguage") -- else bug
languages.hyphenation.loadexceptions("zerolanguage") -- else bug

languages.logger = languages.logger or { }

function languages.logger.report()
    local result = { }
    local sorted = table.sortedkeys(registered)
    for i=1,#sorted do
        local tag = sorted[i]
        local l = registered[tag]
        if l.loaded then
            local p = (l.patterns   and "pat") or '-'
            local e = (l.exceptions and "exc") or '-'
            result[#result+1] = format("%s:%s:%s:%s:%s", tag, l.parent, p, e, l.number)
        end
    end
    return (#result > 0 and concat(result," ")) or "none"
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
    return statistics.elapsedseconds(languages, format(", n=%s",languages.hyphenation.n()))
end)
