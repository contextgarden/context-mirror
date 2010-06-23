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

local report_languages = logs.new("languages")

languages.words = languages.words or { }

local words = languages.words

words.data      = words.data or { }
words.enables   = false
words.threshold = 4

local set_attribute   = node.set_attribute
local unset_attribute = node.unset_attribute
local traverse_nodes  = node.traverse
local node_id         = node.id
local wordsdata       = words.data
local chardata        = characters.data

local glyph_node = node_id('glyph')
local disc_node  = node_id('disc')
local kern_node  = node_id('kern')

words.colors    = {
    ["known"]   = "green",
    ["unknown"] = "red",
}

local spacing = lpeg.S(" \n\r\t")
local markup  = lpeg.S("-=")
local lbrace  = lpeg.P("{")
local rbrace  = lpeg.P("}")
local disc    = (lbrace * (1-rbrace)^0 * rbrace)^1 -- or just 3 times, time this
local word    = lpeg.Cs((markup/"" + disc/"" + (1-spacing))^1)

local loaded = { } -- we share lists

function words.load(tag,filename)
    local fullname = resolvers.find_file(filename,'other text file') or ""
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
    local current, start, str, language, n = head, nil, "", nil, 0
    local function action()
        if #str > 0 then
            local f = whenfound(language,str)
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
        if id == glyph_node then
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
                if chardata[code].uccode or chardata[code].lccode then
                    start = start or current
                    n = n + 1
                    str = str .. utfchar(code)
                elseif start then
                    action()
                end
            end
        elseif id == disc_node then
            if n > 0 then
                n = n + 1
            end
        elseif id == kern_node and current.subtype == 0 and start then
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

words.methods = { }
words.method  = 1

local methods = words.methods

methods[1] = function(head, attribute, yes, nop)
    local right, wrong = false, false
    if yes then right = function(n) set_attribute(n,attribute,yes) end end
    if nop then wrong = function(n) set_attribute(n,attribute,nop) end end
    for n in traverse_nodes(head) do
        unset_attribute(n,attribute) -- hm, not that selective (reset color)
    end
    local found, done = words.found, false
    mark_words(head, function(language,str)
        if #str < words.threshold then
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

local list, dump = { }, false -- todo: per language

local lower = characters.lower

methods[2] = function(head, attribute)
    dump = true
    mark_words(head, function(language,str)
        if #str >= words.threshold then
            str = lower(str)
            list[str] = (list[str] or 0) + 1
        end
    end)
    return head, true
end

words.used = list

function words.dump_used_words(name)
    if dump then
        report_languages("saving list of used words in '%s'",name)
        io.savedata(name,table.serialize(list))
    end
end

local color = attributes.private('color')

function words.check(head)
    if words.enabled and head.next then
        local colors = words.colors
        local alc    = attributes.list[color]
        return methods[words.method](head, color, alc[colors.known], alc[colors.unknown])
    else
        return head, false
    end
end

function words.enable(method)
    tasks.enableaction("processors","languages.words.check")
    words.method = method or words.method or 1
    words.enabled = true
end

function words.disable()
    words.enabled = false
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
