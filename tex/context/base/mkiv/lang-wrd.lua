if not modules then modules = { } end modules ['lang-wrd'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower = string.lower
local utfchar = utf.char
local concat, setmetatableindex = table.concat, table.setmetatableindex
local lpegmatch = lpeg.match
local P, S, Cs, Cf, Cg, Cc, C = lpeg.P, lpeg.S, lpeg.Cs, lpeg.Cf, lpeg.Cg, lpeg.Cc, lpeg.C

local report_words = logs.reporter("languages","words")

local nodes           = nodes
local languages       = languages

local implement       = interfaces.implement

languages.words       = languages.words or { }
local words           = languages.words

words.data            = words.data or { }
words.enables         = false
words.threshold       = 4

local numbers         = languages.numbers
local registered      = languages.registered

local nuts            = nodes.nuts
local tonut           = nuts.tonut

local getfield        = nuts.getfield
local getnext         = nuts.getnext
local getid           = nuts.getid
local getsubtype      = nuts.getsubtype
local getchar         = nuts.getchar
local setattr         = nuts.setattr
local isglyph         = nuts.isglyph

local traverse_nodes  = nuts.traverse
local traverse_ids    = nuts.traverse_id

local wordsdata       = words.data
local chardata        = characters.data
local tasks           = nodes.tasks

local unsetvalue      = attributes.unsetvalue

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
local markup  = S("-=") / ""
local lbrace  = P("{") / ""
local rbrace  = P("}") / ""
local snippet = lbrace * (1-rbrace)^0 * rbrace
local disc    = snippet/"" -- pre
              * snippet/"" -- post
              * snippet    -- replace
local word    = Cs((markup + disc + (1-spacing))^1)

-- lpegmatch((spacing + word/function(s) print(s) end)^0,"foo foo-bar bar{}{}{}foo  bar{}{}{foo}")

local loaded  = { } -- we share lists
local loaders = {
    txt = function(list,fullname)
        local data = io.loaddata(fullname)
        if data and data ~= "" then
            local parser = (spacing + word/function(s) list[s] = true end)^0
         -- local parser = Cf(Cc(list) * Cg(spacing^0 * word * Cc(true))^1,rawset) -- not better
            lpegmatch(parser,data)
        end
    end,
    lua = function(list,fullname)
        local data = dofile(fullname)
        if data and type(data) == "table" then
            local words = data.words
            if words then
                for k, v in next, words do
                    list[k] = true
                end
            end
        end
    end,
}

loaders.luc = loaders.lua

function words.load(tag,filename)
    local fullname = resolvers.findfile(filename,'other text file') or ""
    if fullname ~= "" then
        report_words("loading word file %a",fullname)
        statistics.starttiming(languages)
        local list = loaded[fullname]
        if not list then
            list = wordsdata[tag] or { }
            local suffix = file.suffix(fullname)
            local loader = loaders[suffix] or loaders.txt
            loader(list,fullname)
            loaded[fullname] = list
        end
        wordsdata[tag] = list
        statistics.stoptiming(languages)
    else
        report_words("missing word file %a",filename)
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

-- The following code is an adaption of experimental code for hyphenating and
-- spell checking.

-- there is an n=1 problem somewhere in nested boxes

local function mark_words(head,whenfound) -- can be optimized and shared
    local current, language, done = tonut(head), nil, nil, 0, false
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
    -- we haven't done the fonts yet so we have characters (otherwise
    -- we'd have to use the tounicodes)
    while current do
        local code, id = isglyph(current)
        if code then
            local a = getfield(current,"lang")
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
            local data = chardata[code]
            if is_letter[data.category] then
                n = n + 1
                nds[n] = current
                s = s + 1
                str[s] = utfchar(code)
            elseif s > 0 then
                action()
            end
        elseif id == disc_code then -- take the replace
            if n > 0 then
                local r = getfield(current,"replace")
                if r then
                    for current in traverse_ids(glyph_code,r) do
                        local code = getchar(current)
                        n = n + 1
                        nds[n] = current
                        s = s + 1
                        str[s] = utfchar(code)
                    end
                end
            end
        elseif id == kern_code and getsubtype(current) == kerning_code and s > 0 then
            -- ok
        elseif s > 0 then
            action()
        end
        current = getnext(current)
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
    elseif not head then
        return head, false
    else
        return head, false
    end
end

function words.enable(settings)
    local method = settings.method
    wordmethod = method and tonumber(method) or wordmethod or 1
    local e = enablers[wordmethod]
    if e then
        e(settings)
    end
    tasks.enableaction("processors","languages.words.check")
    enabled = true
end

function words.disable()
    enabled = false
end

-- colors

local cache = { } -- can also be done with method 1 -- frozen colors once used

table.setmetatableindex(cache, function(t,k) -- k == language, numbers[k] == tag
    local c
    if type(k) == "string" then
        c = colist[k]
    elseif k < 0 then
        c = colist["word:unset"]
    else
        c = colist["word:" .. (numbers[k] or "unset")] or colist["word:unknown"]
    end
    local v = c and function(n) setattr(n,a_color,c) end or false
    t[k] = v
    return v
end)

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
        setattr(n,a_color,unsetvalue) -- hm, not that selective (reset color)
    end
    return mark_words(head,sweep)
end

-- method 2

local dumpname   = nil
local dumpthem   = false
local listname   = "document"

local category   = { }

local categories = setmetatableindex(function(t,k)
    local languages = setmetatableindex(function(t,k)
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
    end)
    local v = {
        languages = languages,
        total     = 0,
    }
    t[k] = v
    return v
end)

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
        report_words("saving list of used words in %a",dumpname)
        io.savedata(dumpname,table.serialize(collected,true))
     -- table.tofile(dumpname,list,true)
    end
end

directives.register("languages.words.dump", function(v)
    dumpname = (type(v) == "string" and v ~= "" and v) or dumpname
end)

luatex.registerstopactions(dumpusedwords)

-- method 3

local function sweep(language,str)
    return cache[language]
end

methods[3] = function(head)
    for n in traverse_nodes(head) do
        setattr(n,a_color,unsetvalue)
    end
    return mark_words(head,sweep)
end

-- for the moment we hook it into the attribute handler

-- languagehacks = { }

-- function languagehacks.process(namespace,attribute,head)
--     return languages.check(head)
-- end

-- chars.plugins[chars.plugins+1] = {
--     name = "language",
--     namespace = languagehacks,
--     processor = languagehacks.process
-- }

-- interface

implement {
    name      = "enablespellchecking",
    actions   = words.enable,
    arguments = {
        {
            { "method" },
            { "list" }
        }
    }
}

implement {
    name      = "disablespellchecking",
    actions   = words.disable
}

implement {
    name      = "loadspellchecklist",
    arguments = { "string", "string" },
    actions   = words.load
}
