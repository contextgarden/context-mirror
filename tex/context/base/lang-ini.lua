if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup (share locals)

local utf = unicode.utf8

local find, lower, format, utfchar = string.find, string.lower, string.format, utf.char
local concat = table.concat

if lang.use_new then lang.use_new(true) end

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

--~ local function filter(filename,what)
--~     local data = io.loaddata(resolvers.find_file(filename))
--~     local data = data:match(string.format("\\%s%%s*(%%b{})",what or "patterns"))
--~     return data:match("{%s*(.-)%s*}") or ""
--~ end

-- loading the 26 languages that we normally load in mkiv, the string based variant
-- takes .84 seconds (probably due to the sub's) while the lpeg variant takes .78
-- seconds

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
    if find(filename,"%.rpl") then
        return io.loaddata(resolvers.find_file(filename)) or ""
    else
        return parser:match(io.loaddata(resolvers.find_file(filename)) or "")
    end
end

local command = lpeg.P("\\hyphenation")
local parser  = (1-command)^0 * command * content

local function filterexceptions(filename)
    if find(filename,"%.rhl") then
        return io.loaddata(resolvers.find_file(filename)) or ""
    else
        return parser:match(io.loaddata(resolvers.find_file(filename)) or {}) -- "" ?
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

local function loadthem(tag, filename, filter, target)
    statistics.starttiming(languages)
    local data = record(tag)
    filename = (filename and filename ~= "" and resolvers.find_file(filename)) or ""
    local ok = filename ~= ""
    if ok then
        lang[target](data,filterpatterns(filename))
    else
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
    return loadthem(tag, patterns, filterexceptions, "hyphenation")
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

-- we can speed this one up with locals if needed

local function tolang(what)
    local kind = type(what)
    if kind == "number" then
        return langdata[languages.numbers[what]]
    elseif kind == "string" then
        return langdata[what]
    else
        return what
    end
end

function languages.prehyphenchar(what)
    return lang.prehyphenchar(tolang(what))
end
function languages.posthyphenchar(what)
    return lang.posthyphenchar(tolang(what))
end

languages.tolang = tolang

languages.registered = languages.registered or { }
languages.associated = languages.associated or { }
languages.numbers    = languages.numbers    or { }

storage.register("languages/registered",languages.registered,"languages.registered")
storage.register("languages/associated",languages.associated,"languages.associated")

function languages.register(tag,parent,patterns,exceptions)
    parent = parent or tag
    languages.registered[tag] = {
        parent     = parent,
        patterns   = patterns   or format("lang-%s.pat",parent),
        exceptions = exceptions or format("lang-%s.hyp",parent),
        loaded     = false,
        number     = 0,
    }
end

function languages.associate(tag,script,language)
    languages.associated[tag] = { script, language }
end

function languages.association(tag)
    if type(tag) == "number" then
        tag = languages.numbers[tag]
    end
    local lat = tag and languages.associated[tag]
    if lat then
        return lat[1], lat[2]
    else
        return nil, nil
    end
end

function languages.loadable(tag)
    local l = languages.registered[tag]
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
        local l = languages.registered[tag]
        if l then
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
                    languages.numbers[l.number] = tag
                end
                l.loaded = true
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
    local result = {}
    for _, tag in ipairs(table.sortedkeys(languages.registered)) do
        local l = languages.registered[tag]
        if l.loaded then
            local p = (l.patterns   and "pat") or '-'
            local e = (l.exceptions and "exc") or '-'
            result[#result+1] = format("%s:%s:%s:%s:%s", tag, l.parent, p, e, l.number)
        end
    end
    return (#result > 0 and concat(result," ")) or "none"
end

languages.words           = languages.words      or {}
languages.words.data      = languages.words.data or {}
languages.words.enable    = false
languages.words.threshold = 4

languages.words.colors    = {
    ["known"]   = "green",
    ["unknown"] = "red",
}

do

    local spacing = lpeg.S(" \n\r\t")
    local markup  = lpeg.S("-=")
    local lbrace  = lpeg.P("{")
    local rbrace  = lpeg.P("}")
    local disc    = (lbrace * (1-rbrace)^0 * rbrace)^1 -- or just 3 times, time this
    local word    = lpeg.Cs((markup/"" + disc/"" + (1-spacing))^1)

    function languages.words.load(tag, filename)
        local filename = resolvers.find_file(filename,'other text file') or ""
        if filename ~= "" then
            statistics.starttiming(languages)
            local data = io.loaddata(filename) or ""
            local words = languages.words.data[tag] or {}
            parser = (spacing + word/function(s) words[s] = true end)^0
            parser:match(data)
            languages.words.data[tag] = words
            statistics.stoptiming(languages)
        end
    end

end

function languages.words.found(id, str)
    local tag = languages.numbers[id]
    if tag then
        local data = languages.words.data[tag]
        return data and (data[str] or data[lower(str)])
    else
        return false
    end
end

-- The following code is an adaption of experimental code for
-- hyphenating and spell checking.

do

    local glyph, disc, kern = node.id('glyph'), node.id('disc'), node.id('kern')

    local bynode   = node.traverse
    local chardata = characters.data

    local function mark_words(head,found) -- can be optimized
        local current, start, str, language, n = head, nil, "", nil, 0
        local function action()
            if #str > 0 then
                local f = found(language,str)
                if f then
                    for i=1,n do
                        f(start)
                        start = start.next
                    end
                end
            end
            str, start, n = "", nil, 0
        end
        while current do
            local id = current.id
            if id == glyph then
                local a = current.lang
                if a then
                    if a ~= language then
                        if start then
                            action()
                        end
                        language = a
                    end
                elseif start then
                    action()
                    language = a
                end
                local components = current.components
                if components then
                    start = start or current
                    n = n + 1
                    for g in bynode(components) do
                        str = str .. utfchar(g.char)
                    end
                else
                    local code = current.char
                    if chardata[code].uccode or chardata[code].lccode then
                        start = start or current
                        n = n + 1
                        str = str .. utfchar(code)
                    elseif start then
                        action()
                    end
                end
            elseif id == disc then
                if n > 0 then n = n + 1 end
                -- ok
            elseif id == kern and current.subtype == 0 and start then
                -- ok
            elseif start then
                action()
            end
            current = current.next
        end
        if start then
            action()
        end
        return head
    end

    languages.words.methods = { }
    languages.words.method  = 1

    local lw = languages.words

    languages.words.methods[1] = function(head, attribute, yes, nop)
        local set   = node.set_attribute
        local unset = node.unset_attribute
        local right, wrong = false, false
        if yes then right = function(n) set(n,attribute,yes) end end
        if nop then wrong = function(n) set(n,attribute,nop) end end
        for n in node.traverse(head) do
            unset(n,attribute) -- hm
        end
        local found, done = languages.words.found, false
        mark_words(head, function(language,str)
            if #str < lw.threshold then
                return false
            elseif found(language,str) then
                done = true
                return right
            else
                done = true
                return wrong
            end
        end)
        return head, done
    end

    local color = attributes.private('color')

    function languages.words.check(head)
        if lw.enable and head.next then
            local colors = lw.colors
            local alc    = attributes.list[color]
            return lw.methods[lw.method](head, color, alc[colors.known], alc[colors.unknown])
        else
            return head, false
        end
    end

end

-- for the moment we hook it into the attribute handler

--~ languagehacks = { }

--~ function languagehacks.process(namespace,attribute,head)
--~     return languages.check(head)
--~ end

--~ chars.plugins[chars.plugins+1] = {
--~     name = "language",
--~     namespace = languagehacks,
--~     processor = languagehacks.process
--~ }

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
    if statistics.elapsedindeed(languages) then
        return format("%s seconds, n=%s", statistics.elapsedtime(languages), languages.hyphenation.n())
    end
end)
