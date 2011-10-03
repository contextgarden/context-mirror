local info = {
    version   = 1.002,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- The fold and lex functions are copied and patched from original code by Mitchell (see
-- lexer.lua). All errors are mine.
--
-- I'll probably make a whole copy and patch the other functions too as we need an extra
-- nesting model.
--
-- Also needed: preamble scan once. Can be handled in caller below and _M.preamble.
--
-- For huge files folding can be pretty slow and I do have some large ones that I keep
-- open all the time. Loading is normally no ussue, unless one has remembered the status
-- and the cursor is at the last line of a 200K line file. Optimizing the fold function
-- brought down loading of char-def.lua from 14 sec => 8 sec. Replacing the word_match
-- function and optimizing the lex function gained another 2+ seconds. A 6 second load
-- is quite ok for me.

-- Function load(lexer_name) starts with _M.WHITESPACE = lexer_name..'_whitespace' which
-- means that we need to have it frozen at the moment we load another lexer. Because spacing
-- is used to revert to a parent lexer we need to make sure that we load children as late
-- as possible in order not to get the wrong whitespace trigger. This took me quite a while
-- to figure out (not being that familiar with the internals). BTW, if performance becomes
-- an issue we can rewrite the main lex function (memorize the grammars and speed up the
-- byline variant).

-- Maybe it's safer to copy th eother methods here so that we have no dependencies, apart
-- from the the library.

local R, P, S, C, Cp, Cs, Ct, Cmt, Cc, Cf, Cg = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.Cp, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg
local lpegmatch = lpeg.match
local find, gmatch, match, lower, upper, gsub = string.find, string.gmatch, string.match, string.lower, string.upper, string.gsub
local concat = table.concat
local global = _G
local type, next, setmetatable, rawset = type, next, setmetatable, rawset

dofile(_LEXERHOME .. '/lexer.lua')

lexer.context    = lexer.context or { }
local context    = lexer.context

context.patterns = context.patterns or { }
local patterns   = context.patterns

local locations = {
 -- lexer.context.path,
    _LEXERHOME .. "/data", -- optional data directory
    _LEXERHOME .. "/..",   -- regular scite directory
}

local function collect(name)
    local definitions = loadfile(name .. ".luc") or loadfile(name .. ".lua")
    if type(definitions) == "function" then
        definitions = definitions()
    end
    if type(definitions) == "table" then
        return definitions
    else
        return nil
    end
end

-- local function exists(name)
--     local f = global.io.open(name)
--     return f and true or false
-- end
--
-- local function collect(name)
--     local f = global.io.open(name .. ".properties")
--     if f then
--         local result = { }
--         local data = gsub(f:read("*all") or "","\\ *[\n\r]+"," ")
--         for name, words in gmatch(data,".-([^%.]-)=(.-)\n") do
--             if name ~= "all" then
--                 local list = { }
--                 for word in gmatch(words,"([^ ]+)") do
--                     list[#list+1] = word
--                 end
--                 result[name] = list
--             end
--         end
--         f:close()
--         if next(result) then
--             return result
--         end
--     end
-- end

function context.loaddefinitions(name)
    for i=1,#locations do
        local data = collect(locations[i] .. "/" .. name)
        if data then
            return data
        end
    end
end

-- maybe more efficient:

function context.word_match(words,word_chars,case_insensitive)
    local chars = '%w_' -- maybe just "" when word_chars
    if word_chars then
        chars = '^([' .. chars .. gsub(word_chars,'([%^%]%-])', '%%%1') ..']+)'
    else
        chars = '^([' .. chars ..']+)'
    end
    if case_insensitive then
        local word_list = { }
        for i=1,#words do
            word_list[lower(words[i])] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[lower(word)] and e + 1 or nil
        end)
    else
        local word_list = { }
        for i=1,#words do
            word_list[words[i]] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[word] and e + 1 or nil
        end)
    end
end

-- nicer (todo: utf):

local idtoken = R("az","AZ","\127\255","__")
local digit   = R("09")
local sign    = S("+-")
local period  = P(".")
local space   = S(" \n\r\t\f\v")

patterns.idtoken  = idtoken

patterns.digit    = digit
patterns.sign     = sign
patterns.period   = period

patterns.cardinal = digit^1
patterns.integer  = sign^-1 * digit^1

patterns.real     =
    sign^-1 * (                    -- at most one
        digit^1 * period * digit^0 -- 10.0 10.
      + digit^0 * period * digit^1 -- 0.10 .10
      + digit^1                    -- 10
   )

patterns.restofline = (1-S("\n\r"))^1
patterns.space      = space
patterns.spacing    = space^1
patterns.nospacing  = (1-space)^1
patterns.anything   = P(1)

function context.exact_match(words,word_chars,case_insensitive)
    local characters = concat(words)
    local pattern -- the concat catches _ etc
    if word_chars == true or word_chars == false or word_chars == nil then
        word_chars = ""
    end
    if type(word_chars) == "string" then
        pattern = S(characters) + idtoken
        if case_insensitive then
            pattern = pattern + S(upper(characters)) + S(lower(characters))
        end
        if word_chars ~= "" then
            pattern = pattern + S(word_chars)
        end
    elseif word_chars then
        pattern = word_chars
    end
    if case_insensitive then
        local list = { }
        for i=1,#words do
            list[lower(words[i])] = true
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[lower(s)] -- and i
        end)
    else
        local list = { }
        for i=1,#words do
            list[words[i]] = true
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[s] -- and i
        end)
    end
end

-- spell checking (we can only load lua files)

-- return {
--     words = {
--         ["someword"]    = "someword",
--         ["anotherword"] = "Anotherword",
--     },
-- }

local lists = { }

local splitter = (Cf(Ct("") * (Cg(C((1-S(" \t\n\r"))^1 * Cc(true))) + P(1))^1,rawset) )^0
local splitter = (Cf(Ct("") * (Cg(C(R("az","AZ","\127\255")^1) * Cc(true)) + P(1))^1,rawset) )^0

local function splitwords(words)
    return lpegmatch(splitter,words)
end

function context.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
    if not tag or tag == "" then
        return false
    elseif lists[tag] ~= nil then
        return lists[tag]
    else
        local list = context.loaddefinitions("spell-" .. tag)
        if not list or type(list) ~= "table" then
            lists[tag] = false
            return nil
        elseif type(list.words) == "string" then
            list = splitwords(list.words)
            lists[tag] = list
            return list
        else
            list = list.words or false
            lists[tag] = list
            return list
        end
    end
end

patterns.wordtoken   = R("az","AZ","\127\255")
patterns.wordpattern = patterns.wordtoken^3 -- todo: if limit and #s < limit then

function context.checkedword(validwords,s,i) -- ,limit
    if not validwords then
        return true, { "text", i }
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return true, { "okay", i } -- exact match
        elseif word then
            return true, { "warning", i } -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return true, { "okay", i } -- exact match
            elseif word then
                return true, { "warning", i } -- case issue
            elseif upper(s) == s then
                return true, { "warning", i } -- probably a logo or acronym
            else
                return true, { "error", i }
            end
        end
    end
end

-- overloaded functions

local FOLD_BASE         = SC_FOLDLEVELBASE
local FOLD_HEADER       = SC_FOLDLEVELHEADERFLAG
local FOLD_BLANK        = SC_FOLDLEVELWHITEFLAG

local get_style_at      = GetStyleAt
local get_property      = GetProperty
local get_indent_amount = GetIndentAmount

local h_table, b_table, n_table = { }, { }, { }

setmetatable(h_table, { __index = function(t,level) local v = { level, FOLD_HEADER } t[level] = v return v end })
setmetatable(b_table, { __index = function(t,level) local v = { level, FOLD_BLANK  } t[level] = v return v end })
setmetatable(n_table, { __index = function(t,level) local v = { level              } t[level] = v return v end })

-- local newline    = P("\r\n") + S("\r\n")
-- local splitlines = Ct( ( Ct ( (Cp() * Cs((1-newline)^1) * newline^-1) + (Cp() * Cc("") * newline) ) )^0)
--
-- local lines = lpegmatch(splitlines,text) -- iterating over lines is faster
-- for i=1, #lines do
--     local li = lines[i]
--     local line = li[2]
--     if line ~= "" then
--         local pos = li[1]
--         for i=1,nofpatterns do
--             for s, m in gmatch(line,patterns[i]) do
--                 if hash[m] then
--                     local symbols = fold_symbols[get_style_at(start_pos + pos + s - 1)]
--                     if symbols then
--                         local l = symbols[m]
--                         if l then
--                             local t = type(l)
--                             if t == 'number' then
--                                 current_level = current_level + l
--                             elseif t == 'function' then
--                                 current_level = current_level + l(text, pos, line, s, match)
--                             end
--                             if current_level < FOLD_BASE then -- integrate in previous
--                                 current_level = FOLD_BASE
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--         if current_level > prev_level then
--             folds[line_num] = h_table[prev_level] -- { prev_level, FOLD_HEADER }
--         else
--             folds[line_num] = n_table[prev_level] -- { prev_level }
--         end
--         prev_level = current_level
--     else
--         folds[line_num] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
--     end
--     line_num = line_num + 1
-- end

local newline = P("\r\n") + S("\r\n")
local p_yes   = Cp() * Cs((1-newline)^1) * newline^-1
local p_nop   = newline

local function fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    local foldsymbols = lexer._foldsymbols
    if not foldsymbols then
        return { }
    end
    local patterns = foldsymbols._patterns
    if not patterns then
        return { }
    end
    local nofpatterns = #patterns
    if nofpatterns == 0 then
        return { }
    end
    local folds = { }
    local line_num = start_line
    local prev_level = start_level
    local current_level = prev_level
    local validmatches = foldsymbols._validmatches
    if not validmatches then
        validmatches = { }
        for symbol, matches in next, foldsymbols do -- whatever = { start = 1, stop = -1 }
            if not find(symbol,"^_") then -- brrr
                for s, _ in next, matches do
                    validmatches[s] = true
                end
            end
        end
        foldsymbols._validmatches = validmatches
    end
    local function action_y(pos,line) -- we can consider moving the local functions outside (drawback: folds is kept)
        for i=1,nofpatterns do
            for s, m in gmatch(line,patterns[i]) do
                if validmatches[m] then
                    local symbols = foldsymbols[get_style_at(start_pos + pos + s - 1)]
                    if symbols then
                        local action = symbols[m]
                        if action then
                            if type(action) == 'number' then -- we could store this in validmatches if there was only one symbol category
                                current_level = current_level + action
                            else
                                current_level = current_level + action(text,pos,line,s,m)
                            end
                            if current_level < FOLD_BASE then
                                current_level = FOLD_BASE
                            end
                        end
                    end
                end
            end
        end
        if current_level > prev_level then
            folds[line_num] = h_table[prev_level] -- { prev_level, FOLD_HEADER }
        else
            folds[line_num] = n_table[prev_level] -- { prev_level }
        end
        prev_level = current_level
        line_num = line_num + 1
    end
    local function action_n()
        folds[line_num] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
        line_num = line_num + 1
    end
    if lexer._reset_parser then
        lexer._reset_parser()
    end
    local lpegpattern = (p_yes/action_y + p_nop/action_n)^0 -- not too efficient but indirect function calls are neither but
    lpegmatch(lpegpattern,text)                             -- keys are not pressed that fast ... large files are slow anyway
    return folds
end

local function fold_by_indentation(text,start_pos,start_line,start_level)
    local folds = { }
    local current_line = start_line
    local prev_level = start_level
    for _, line in gmatch(text,'([\t ]*)(.-)\r?\n') do
        if line ~= "" then
            local current_level = FOLD_BASE + get_indent_amount(current_line)
            if current_level > prev_level then -- next level
                local i = current_line - 1
                while true do
                    local f = folds[i]
                    if f and f[2] == FOLD_BLANK then
                        i = i - 1
                    else
                        break
                    end
                end
                local f = folds[i]
                if f then
                    f[2] = FOLD_HEADER
                end -- low indent
                folds[current_line] = n_table[current_level] -- { current_level } -- high indent
            elseif current_level < prev_level then -- prev level
                local f = folds[current_line - 1]
                if f then
                    f[1] = prev_level -- high indent
                end
                folds[current_line] = n_table[current_level] -- { current_level } -- low indent
            else -- same level
                folds[current_line] = n_table[prev_level] -- { prev_level }
            end
            prev_level = current_level
        else
            folds[current_line] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
        end
        current_line = current_line + 1
    end
    return folds
end

local function fold_by_line(text,start_pos,start_line,start_level)
    local folds = { }
    for _ in gmatch(text,".-\r?\n") do
        folds[start_line] = n_table[start_level] -- { start_level }
        start_line = start_line + 1
    end
    return folds
end

function context.fold(text,start_pos,start_line,start_level)
    if text == '' then
        return { }
    end
    local lexer = global._LEXER
    local fold_by_lexer = lexer._fold
    if fold_by_lexer then
        return fold_by_lexer(text,start_pos,start_line,start_level,lexer)
    elseif get_property('fold.by.parsing',1) > 0 then
        return fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    elseif get_property('fold.by.indentation',1) > 0 then -- not that usefull
        return fold_by_indentation(text,start_pos,start_line,start_level,lexer)
    elseif get_property('fold.by.line',1) > 0 then -- rather useless
        return fold_by_line(text,start_pos,start_line,start_level,lexer)
    else
        return { }
    end
end

function context.lex(text,init_style)
    local lexer = global._LEXER
    local grammar = lexer._GRAMMAR
    if not grammar then
        return { }
    elseif lexer._LEXBYLINE then -- we could keep token
        local tokens = { }
        local offset = 0
        local noftokens = 0
        if true then
            for line in gmatch(text,'[^\r\n]*\r?\n?') do -- could be an lpeg
                local line_tokens = lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens do
                        local token = line_tokens[i]
                        token[2] = token[2] + offset
                        noftokens = noftokens + 1
                        tokens[noftokens] = token
                    end
                end
                offset = offset + #line
                if noftokens > 0 and tokens[noftokens][2] ~= offset then
                    noftokens = noftokens + 1
                    tokens[noftokens] = { 'default', offset + 1 }
                end
            end
        else -- alternative
            local lasttoken, lastoffset
            for line in gmatch(text,'[^\r\n]*\r?\n?') do -- could be an lpeg
                local line_tokens = lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens do
                        lasttoken = line_tokens[i]
                        lastoffset = lasttoken[2] + offset
                        lasttoken[2] = lastoffset
                        noftokens = noftokens + 1
                        tokens[noftokens] = lasttoken
                    end
                end
                offset = offset + #line
                if lastoffset ~= offset then
                    lastoffset = offset + 1
                    lasttoken = { 'default', lastoffset }
                    noftokens = noftokens + 1
                    tokens[noftokens] = lasttoken
                end
            end
        end
        return tokens
    elseif lexer._CHILDREN then
        -- as we cannot print, tracing is not possible ... this might change as we can as well
        -- generate them all in one go (sharing as much as possible)
        local _hash = lexer._HASH
        if not hash then
            hash = { }
            lexer._HASH = hash
        end
        grammar = hash[init_style]
        if grammar then
            lexer._GRAMMAR = grammar
        else
            for style, style_num in next, lexer._TOKENS do
                if style_num == init_style then
                    local lexer_name = match(style,'^(.+)_whitespace') or lexer._NAME
                    if lexer._INITIALRULE ~= lexer_name then
                        grammar = hash[lexer_name]
                        if not grammar then
                            build_grammar(lexer,lexer_name)
                            grammar = lexer._GRAMMAR
                            hash[lexer_name] = grammar
                        end
                    end
                    break
                end
            end
            grammar = grammar or lexer._GRAMMAR
            hash[init_style] = grammar
        end
        return lpegmatch(grammar,text)
    else
        return lpegmatch(grammar,text)
    end
end

-- todo: keywords: one lookup and multiple matches

function context.token(name, patt)
    return Ct(patt * Cc(name) * Cp())
end

lexer.fold        = context.fold
lexer.lex         = context.lex
lexer.token       = context.token
lexer.exact_match = context.exact_match
