if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local lower, utfchar = string.lower, utf.char
local lpegmatch = lpeg.match
local P, S, Cs = lpeg.P, lpeg.S, lpeg.Cs

local report_languages = logs.new("languages")

local nodes, node, languages = nodes, node, languages

languages.words       = languages.words or { }
local words           = languages.words

words.data            = words.data or { }
words.enables         = false
words.threshold       = 4

local set_attribute   = node.set_attribute
local unset_attribute = node.unset_attribute
local traverse_nodes  = node.traverse
local wordsdata       = words.data
local chardata        = characters.data
local tasks           = nodes.tasks

local nodecodes       = nodes.nodecodes
local kerncodes       = nodes.kerncodes

local glyph_code      = nodecodes.glyph
local disc_code       = nodecodes.disc
local kern_code       = nodecodes.kern

local kerning_code    = kerncodes.kerning
local lowerchar       = characters.lower

local a_color         = attributes.private('color')

words.colors    = {
    ["known"]   = "green",
    ["unknown"] = "red",
}

local spacing = S(" \n\r\t")
local markup  = S("-=")
local lbrace  = P("{")
local rbrace  = P("}")
local disc    = (lbrace * (1-rbrace)^0 * rbrace)^1 -- or just 3 times, time this
local word    = Cs((markup/"" + disc/"" + (1-spacing))^1)

local loaded = { } -- we share lists

function words.load(tag,filename)
    local fullname = resolvers.findfile(filename,'other text file') or ""
    if fullname ~= "" then
        statistics.starttiming(languages)
        local list = loaded[fullname]
        if not list then
            list = wordsdata[tag] or { }
            local parser = (spacing + word/function(s) list[s] = true end)^0
            lpegmatch(parser,io.loaddata(fullname) or "")
            loaded[fullname] = list
        end
        wordsdata[tag] = list
        statistics.stoptiming(languages)
    else
        report_languages("missing words file '%s'",filename)
    end
end

function words.found(id, str)
    local tag = languages.numbers[id]
    if tag then
        local data = wordsdata[tag]
        return data and (data[str] or data[lower(str)])
    else
        return false
    end
end

-- The following code is an adaption of experimental code for
-- hyphenating and spell checking.

local function mark_words(head,whenfound) -- can be optimized
    local current, start, str, language, n, done = head, nil, "", nil, 0, false
    local function action()
        if #str > 0 then
            local f = whenfound(language,str)
            if f then
                done = true
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
        if id == glyph_code then
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
                for g in traverse_nodes(components) do
                    str = str .. utfchar(g.char)
                end
            else
                local code = current.char
                local data = chardata[code]
                if data.uccode or data.lccode then
                    start = start or current
                    n = n + 1
                    str = str .. utfchar(code)
                elseif start then
                    action()
                end
            end
        elseif id == disc_code then
            if n > 0 then
                n = n + 1
            end
        elseif id == kern_code and current.subtype == kerning_code and start then
            -- ok
        elseif start then
            action()
        end
        current = current.next
    end
    if start then
        action()
    end
    return head, done
end

local methods  = { }
words.methods  = methods

local enablers = { }
words.enablers = enablers

local wordmethod = 1
local enabled    = false

function words.check(head)
    if enabled and head.next then
        return methods[wordmethod](head)
    else
        return head, false
    end
end

function words.enable(settings)
    local method = settings.method
    wordmethod = method and tonumber(method) or wordmethod or 1
    local e = enablers[wordmethod]
    if e then e(settings) end
    tasks.enableaction("processors","languages.words.check")
    enabled = true
end

function words.disable()
    enabled = false
end

-- method 1

local colors = words.colors
local colist = attributes.list[a_color]

local right  = function(n) set_attribute(n,a_color,colist[colors.known]) end
local wrong  = function(n) set_attribute(n,a_color,colist[colors.unknown]) end

local function sweep(language,str)
    if #str < words.threshold then
        return false
    elseif words.found(language,str) then
        return right
    else
        return wrong
    end
end

methods[1] = function(head)
    for n in traverse_nodes(head) do
        unset_attribute(n,attribute) -- hm, not that selective (reset color)
    end
    return mark_words(head,sweep)
end

-- method 2

local dumpname   = nil
local dumpthem   = false
local listname   = "document"

local category   = { }

local collected  = {
    total      = 0,
    categories = { document = { total = 0, list = { } } },
}

enablers[2] = function(settings)
    local name = settings.list
    listname = name and name ~= "" and name or "document"
    category = collected.categories[listname]
    if not category then
        category = { }
        collected.categories[listname] = category
    end
end

local numbers    = languages.numbers
local registered = languages.registered

local function sweep(language,str)
    if #str >= words.threshold then
        collected.total = collected.total + 1
        str = lowerchar(str)
        local number = numbers[language] or "unset"
        local words = category[number]
        if not words then
            local r = registered[number]
            category[number] = {
                number   = language,
                parent   = r and r.parent   or nil,
                patterns = r and r.patterns or nil,
                tag      = r and r.tag      or nil,
                list     = { [str] = 1 },
                total    = 1,
            }
        else
            local list = words.list
            list[str] = (list[str] or 0) + 1
            words.total = words.total + 1
        end
    end
end

methods[2] = function(head)
    dumpthem = true
    return mark_words(head,sweep)
end

local function dumpusedwords()
    if dumpthem then
        collected.threshold = words.threshold
        dumpname = dumpname or file.addsuffix(tex.jobname,"words")
        report_languages("saving list of used words in '%s'",dumpname)
        io.savedata(dumpname,table.serialize(collected,true))
     -- table.tofile(dumpname,list,true)
    end
end

directives.register("languages.words.dump", function(v)
    dumpname = type(v) == "string" and v ~= "" and v
end)

luatex.registerstopactions(dumpusedwords)

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
