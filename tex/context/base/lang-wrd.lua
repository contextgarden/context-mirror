if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local lower, utfchar = string.lower, utf.char
local concat = table.concat
local lpegmatch = lpeg.match
local P, S, Cs = lpeg.P, lpeg.S, lpeg.Cs

local report_words = logs.reporter("languages","words")

local nodes, node, languages = nodes, node, languages

languages.words       = languages.words or { }
local words           = languages.words

words.data            = words.data or { }
words.enables         = false
words.threshold       = 4

local numbers         = languages.numbers
local registered      = languages.registered

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
local colist          = attributes.list[a_color]

local is_letter       = characters.is_letter -- maybe is_character as variant

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
        report_words("loading word file '%s'",fullname)
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
        report_words("missing word file '%s'",filename)
    end
end

function words.found(id, str)
    local tag = languages.numbers[id]
    if tag then
        local data = wordsdata[tag]
        if data then
            if data[str] then
                return 1
            elseif data[lower(str)] then
                return 2
            end
        end
    end
end

-- The following code is an adaption of experimental code for
-- hyphenating and spell checking.

-- there is an n=1 problem somewhere in nested boxes

--~ local function mark_words(head,whenfound) -- can be optimized and shared
--~     local current, start, str, language, n, done = head, nil, "", nil, 0, false
--~     local function action()
--~         if #str > 0 then
--~             local f = whenfound(language,str)
--~             if f then
--~                 done = true
--~                 for i=1,n do
--~                     f(start)
--~                     start = start.next
--~                 end
--~             end
--~         end
--~         str, start, n = "", nil, 0
--~     end
--~     while current do
--~         local id = current.id
--~         if id == glyph_code then
--~             local a = current.lang
--~             if a then
--~                 if a ~= language then
--~                     if start then
--~                         action()
--~                     end
--~                     language = a
--~                 end
--~             elseif start then
--~                 action()
--~                 language = a
--~             end
--~             local components = current.components
--~             if components then
--~                 start = start or current
--~                 n = n + 1
--~                 for g in traverse_nodes(components) do
--~                     str = str .. utfchar(g.char)
--~                 end
--~             else
--~                 local code = current.char
--~                 local data = chardata[code]
--~                 if is_letter[data.category] then
--~                     start = start or current
--~                     n = n + 1
--~                     str = str .. utfchar(code) -- slow, maybe str should be a table (and given max)
--~                 elseif start then
--~                     action()
--~                 end
--~             end
--~         elseif id == disc_code then
--~             if n > 0 then
--~                 n = n + 1
--~             end
--~         elseif id == kern_code and current.subtype == kerning_code and start then
--~             -- ok
--~         elseif start then
--~             action()
--~         end
--~         current = current.next
--~     end
--~     if start then
--~         action()
--~     end
--~     return head, done
--~ end

local function mark_words(head,whenfound) -- can be optimized and shared
    local current, language, done = head, nil, nil, 0, false
    local str, s, nds, n = { }, 0, { }, 0 -- n could also be a table, saves calls
    local function action()
        if s > 0 then
            local word = concat(str,"",1,s)
            local mark = whenfound(language,word)
            if mark then
                done = true
                for i=1,n do
                    mark(nds[i])
                end
            end
        end
        n, s = 0, 0
    end
    while current do
        local id = current.id
        if id == glyph_code then
            local a = current.lang
            if a then
                if a ~= language then
                    if s > 0 then
                        action()
                    end
                    language = a
                end
            elseif s > 0 then
                action()
                language = a
            end
            local components = current.components
            if components then
                n = n + 1
                nds[n] = current
                for g in traverse_nodes(components) do
                    s = s + 1
                    str[s] = utfchar(g.char)
                end
            else
                local code = current.char
                local data = chardata[code]
                if is_letter[data.category] then
                    n = n + 1
                    nds[n] = current
                    s = s + 1
                    str[s] = utfchar(code)
                elseif s > 0 then
                    action()
                end
            end
        elseif id == disc_code then -- take the replace
            if n > 0 then
                n = n + 1
                nds[n] = current
            end
        elseif id == kern_code and current.subtype == kerning_code and s > 0 then
            -- ok
        elseif s > 0 then
            action()
        end
        current = current.next
    end
    if s > 0 then
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
    if enabled then
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

-- colors

local cache = { } -- can also be done with method 1 -- frozen colors once used

setmetatable(cache, {
    __index = function(t,k) -- k == language, numbers[k] == tag
        local c
        if type(k) == "string" then
            c = colist[k]
        elseif k < 0 then
            c = colist["word:unset"]
        else
            c = colist["word:" .. (numbers[k] or "unset")] or colist["word:unknown"]
        end
        local v = c and function(n) set_attribute(n,a_color,c) end or false
        t[k] = v
        return v
    end
} )

-- method 1

local function sweep(language,str)
    if #str < words.threshold then
        return false
    elseif words.found(language,str) then -- can become a local wordsfound
        return cache["word:yes"] -- maybe variables.yes
    else
        return cache["word:no"]
    end
end

methods[1] = function(head)
    for n in traverse_nodes(head) do
        unset_attribute(n,a_color) -- hm, not that selective (reset color)
    end
    return mark_words(head,sweep)
end

-- method 2

local dumpname   = nil
local dumpthem   = false
local listname   = "document"

local category   = { }
local categories = { }

setmetatable(categories, {
    __index = function(t,k)
        local languages = { }
        setmetatable(languages, {
            __index = function(t,k)
                local r = registered[k]
                local v = {
                    number   = language,
                    parent   = r and r.parent   or nil,
                    patterns = r and r.patterns or nil,
                    tag      = r and r.tag      or nil,
                    list     = { },
                    total    = 0,
                    unique   = 0,
                }
                t[k] = v
                return v
            end
        } )
        local v = {
            languages = languages,
            total     = 0,
        }
        t[k] = v
        return v
    end
} )

local collected  = {
    total      = 0,
    version    = 1.000,
    categories = categories,
}

enablers[2] = function(settings)
    local name = settings.list
    listname = name and name ~= "" and name or "document"
    category = collected.categories[listname]
end

local function sweep(language,str)
    if #str >= words.threshold then
        str = lowerchar(str)
        local words = category.languages[numbers[language] or "unset"]
        local list = words.list
        local ls = list[str]
        if ls then
            list[str] = ls + 1
        else
            list[str] = 1
            words.unique = words.unique + 1
        end
        collected.total = collected.total + 1
        category.total = category.total + 1
        words.total = words.total + 1
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
        report_words("saving list of used words in '%s'",dumpname)
        io.savedata(dumpname,table.serialize(collected,true))
     -- table.tofile(dumpname,list,true)
    end
end

directives.register("languages.words.dump", function(v)
    dumpname = type(v) == "string" and v ~= "" and v
end)

luatex.registerstopactions(dumpusedwords)

-- method 3

local function sweep(language,str)
    return cache[language]
end

methods[3] = function(head)
    for n in traverse_nodes(head) do
        unset_attribute(n,a_color)
    end
    return mark_words(head,sweep)
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
