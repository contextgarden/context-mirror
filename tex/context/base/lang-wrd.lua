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

languages.words           = languages.words      or {}
languages.words.data      = languages.words.data or {}
languages.words.enables   = false
languages.words.threshold = 4

languages.words.colors    = {
    ["known"]   = "green",
    ["unknown"] = "red",
}

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
        lpegmatch(parser,data)
        languages.words.data[tag] = words
        statistics.stoptiming(languages)
    end
end

function languages.words.found(id, str)
    local tag = numbers[id]
    if tag then
        local data = languages.words.data[tag]
        return data and (data[str] or data[lower(str)])
    else
        return false
    end
end

-- The following code is an adaption of experimental code for
-- hyphenating and spell checking.

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
    if lw.enabled and head.next then
        local colors = lw.colors
        local alc    = attributes.list[color]
        return lw.methods[lw.method](head, color, alc[colors.known], alc[colors.unknown])
    else
        return head, false
    end
end

function languages.words.enable()
    tasks.enableaction("processors","languages.words.check")
    languages.words.enabled = true
end

function languages.words.disable()
    languages.words.enabled = false
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
