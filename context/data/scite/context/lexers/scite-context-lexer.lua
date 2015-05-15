local info = {
    version   = 1.400,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "contains copyrighted code from mitchell.att.foicica.com",

}

-- todo: hook into context resolver etc
-- todo: only old api in lexers, rest in context subnamespace
-- todo: make sure we can run in one state .. copies or shared?
-- todo: auto-nesting

if lpeg.setmaxstack then lpeg.setmaxstack(1000) end

local log      = false
local trace    = false
local detail   = false
local show     = false -- nice for tracing (also for later)
local collapse = false -- can save some 15% (maybe easier on scintilla)
local inspect  = false -- can save some 15% (maybe easier on scintilla)

-- local log      = true
-- local trace    = true

-- GET GOING
--
-- You need to copy this file over lexer.lua. In principle other lexers could
-- work too but not now. Maybe some day. All patterns will move into the patterns
-- name space. I might do the same with styles. If you run an older version of
-- SciTE you can take one of the archives. Pre 3.41 versions can just be copied
-- to the right path, as there we still use part of the normal lexer.
--
-- REMARK
--
-- We started using lpeg lexing as soon as it came available. Because we had
-- rather demanding files an dalso wanted to use nested lexers, we ended up with
-- our own variant (more robust and faster). As a consequence successive versions
-- had to be adapted to changes in the (still unstable) api. In addition to
-- lexing we also have spell checking and such.
--
-- STATUS
--
-- todo: maybe use a special stripped version of the dll (stable api)
-- todo: play with hotspot and other properties
-- wish: access to all scite properties and in fact integrate in scite
-- todo: add proper tracing and so .. not too hard as we can run on mtxrun
-- todo: get rid of these lexers.STYLE_XX and lexers.XX (hide such details)
--
-- HISTORY
--
-- The fold and lex functions are copied and patched from original code by Mitchell
-- (see lexer.lua). All errors are mine. The ability to use lpeg is a real nice
-- adition and a brilliant move. The code is a byproduct of the (mainly Lua based)
-- textadept (still a rapidly moving target) that unfortunately misses a realtime
-- output pane. On the other hand, SciTE is somewhat crippled by the fact that we
-- cannot pop in our own (language dependent) lexer into the output pane (somehow
-- the errorlist lexer is hard coded into the editor). Hopefully that will change
-- some day.
--
-- Starting with SciTE version 3.20 there is an issue with coloring. As we still
-- lack a connection with SciTE itself (properties as well as printing to the log
-- pane) and we cannot trace this (on windows). As far as I can see, there are no
-- fundamental changes in lexer.lua or LexLPeg.cxx so it must be in Scintilla
-- itself. So for the moment I stick to 3.10. Indicators are: no lexing of 'next'
-- and 'goto <label>' in the Lua lexer and no brace highlighting either. Interesting
-- is that it does work ok in the cld lexer (so the Lua code is okay). Also the fact
-- that char-def.lua lexes fast is a signal that the lexer quits somewhere halfway.
-- Maybe there are some hard coded limitations on the amount of styles and/or length
-- if names.
--
-- After checking 3.24 and adapting to the new lexer tables things are okay again.
-- So, this version assumes 3.24 or higher. In 3.24 we have a different token
-- result, i.e. no longer a { tag, pattern } but just two return values. I didn't
-- check other changes but will do that when I run into issues. I had optimized
-- these small tables by hashing which was more efficient but this is no longer
-- needed. For the moment we keep some of that code around as I don't know what
-- happens in future versions.
--
-- In 3.31 another major change took place: some helper constants (maybe they're no
-- longer constants) and functions were moved into the lexer modules namespace but
-- the functions are assigned to the Lua module afterward so we cannot alias them
-- beforehand. We're probably getting close to a stable interface now. I've
-- considered making a whole copy and patch the other functions too as we need an
-- extra nesting model. However, I don't want to maintain too much. An unfortunate
-- change in 3.03 is that no longer a script can be specified. This means that
-- instead of loading the extensions via the properties file, we now need to load
-- them in our own lexers, unless of course we replace lexer.lua completely (which
-- adds another installation issue).
--
-- Another change has been that _LEXERHOME is no longer available. It looks like
-- more and more functionality gets dropped so maybe at some point we need to ship
-- our own dll/so files. For instance, I'd like to have access to the current
-- filename and other scite properties. For instance, we could cache some info with
-- each file, if only we had knowledge of what file we're dealing with.
--
-- For huge files folding can be pretty slow and I do have some large ones that I
-- keep open all the time. Loading is normally no ussue, unless one has remembered
-- the status and the cursor is at the last line of a 200K line file. Optimizing the
-- fold function brought down loading of char-def.lua from 14 sec => 8 sec.
-- Replacing the word_match function and optimizing the lex function gained another
-- 2+ seconds. A 6 second load is quite ok for me. The changed lexer table structure
-- (no subtables) brings loading down to a few seconds.
--
-- When the lexer path is copied to the textadept lexer path, and the theme
-- definition to theme path (as lexer.lua), the lexer works there as well. When I
-- have time and motive I will make a proper setup file to tune the look and feel a
-- bit and associate suffixes with the context lexer. The textadept editor has a
-- nice style tracing option but lacks the tabs for selecting files that scite has.
-- It also has no integrated run that pipes to the log pane. Interesting is that the
-- jit version of textadept crashes on lexing large files (and does not feel faster
-- either; maybe a side effect of known limitations).
--
-- Function load(lexer_name) starts with _lexers.WHITESPACE = lexer_name ..
-- '_whitespace' which means that we need to have it frozen at the moment we load
-- another lexer. Because spacing is used to revert to a parent lexer we need to
-- make sure that we load children as late as possible in order not to get the wrong
-- whitespace trigger. This took me quite a while to figure out (not being that
-- familiar with the internals). The lex and fold functions have been optimized. It
-- is a pitty that there is no proper print available. Another thing needed is a
-- default style in our own theme style definition, as otherwise we get wrong nested
-- lexers, especially if they are larger than a view. This is the hardest part of
-- getting things right.
--
-- It's a pitty that there is no scintillua library for the OSX version of scite.
-- Even better would be to have the scintillua library as integral part of scite as
-- that way I could use OSX alongside windows and linux (depending on needs). Also
-- nice would be to have a proper interface to scite then because currently the
-- lexer is rather isolated and the lua version does not provide all standard
-- libraries. It would also be good to have lpeg support in the regular scite lua
-- extension (currently you need to pick it up from someplace else).
--
-- With 3.41 the interface changed again so it gets time to look into the C++ code
-- and consider compiling and patching myself. Loading is more complicated not as
-- the lexer gets loaded automatically so we have little control over extending the
-- code now. After a few days trying all kind of solutions I decided to follow a
-- different approach: drop in a complete replacement. This of course means that I
-- need to keep track of even more changes (which for sure will happen) but at least
-- I get rid of interferences. The api (lexing and configuration) is simply too
-- unstable across versions. Maybe in a few years things have stabelized. (Or maybe
-- it's not really expected that one writes lexers at all.) A side effect is that I
-- now no longer will use shipped lexers but just the built-in ones. Not that it
-- matters much as the context lexers cover what I need (and I can always write
-- more).
--
-- In fact, the transition to 3.41 was triggered by an unfateful update of Ubuntu
-- which left me with an incompatible SciTE and lexer library and updating was not
-- possible due to the lack of 64 bit libraries. We'll see what the future brings.
--
-- Promissing is that the library now can use another Lua instance so maybe some day
-- it will get properly in SciTE and we can use more clever scripting.
--
-- In some lexers we use embedded ones even if we could do it directly, The reason is
-- that when the end token is edited (e.g. -->), backtracking to the space before the
-- begin token (e.g. <!--) results in applying the surrounding whitespace which in
-- turn means that when the end token is edited right, backtracking doesn't go back.
-- One solution (in the dll) would be to backtrack several space categories. After all,
-- lexing is quite fast (applying the result is much slower).
--
-- For some reason the first blob of text tends to go wrong (pdf and web). It would be
-- nice to have 'whole doc' initial lexing. Quite fishy as it makes it impossible to
-- lex the first part well (for already opened documents) because only a partial
-- text is passed.
--
-- So, maybe I should just write this from scratch (assuming more generic usage)
-- because after all, the dll expects just tables, based on a string. I can then also
-- do some more aggressive resource sharing (needed when used generic).
--
-- I think that nested lexers are still bugged (esp over longer ranges). It never was
-- robust or maybe it's simply not meant for too complex cases. The 3.24 version was
-- probably the best so far. The fact that styles bleed between lexers even if their
-- states are isolated is an issue. Another issus is that zero characters in the
-- text passed to the lexer can mess things up (pdf files have them in streams).
--
-- For more complex 'languages', like web or xml, we need to make sure that we use
-- e.g. 'default' for spacing that makes up some construct. Ok, we then still have a
-- backtracking issue but less.
--
-- TODO
--
-- I can make an export to context, but first I'll redo the code that makes the grammar,
-- as we only seem to need
--
--  lexer._TOKENSTYLES : table
--  lexer._CHILDREN    : flag
--  lexer._EXTRASTYLES : table
--  lexer._GRAMMAR     : flag
--
--  lexers.load        : function
--  lexers.lex         : function
--
-- So, if we drop compatibility with other lex definitions, we can make things simpler.

-- TRACING
--
-- The advantage is that we now can check more easily with regular Lua. We can also
-- use wine and print to the console (somehow stdout is intercepted there.) So, I've
-- added a bit of tracing. Interesting is to notice that each document gets its own
-- instance which has advantages but also means that when we are spellchecking we
-- reload the word lists each time. (In the past I assumed a shared instance and took
-- some precautions.)

-- todo: make sure we don't overload context definitions when used in context

local lpeg  = require("lpeg")

local global = _G
local find, gmatch, match, lower, upper, gsub, sub, format = string.find, string.gmatch, string.match, string.lower, string.upper, string.gsub, string.sub, string.format
local concat, sort = table.concat, table.sort
local type, next, setmetatable, rawset, tonumber, tostring = type, next, setmetatable, rawset, tonumber, tostring
local R, P, S, V, C, Cp, Cs, Ct, Cmt, Cc, Cf, Cg, Carg = lpeg.R, lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cp, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Carg
local lpegmatch = lpeg.match

local nesting = 0

local function report(fmt,str,...)
    if log then
        if str then
            fmt = format(fmt,str,...)
        end
        print(format("scite lpeg lexer > %s > %s",nesting == 0 and "-" or nesting,fmt))
    end
end

local function inform(...)
    if log and trace then
        report(...)
    end
end

inform("loading context lexer module (global table: %s)",tostring(global))

if not package.searchpath then

    -- Unfortunately the io library is only available when we end up
    -- in this branch of code.

    inform("using adapted function 'package.searchpath' (if used at all)")

    function package.searchpath(name,path)
        local tried = { }
        for part in gmatch(path,"[^;]+") do
            local filename = gsub(part,"%?",name)
            local f = io.open(filename,"r")
            if f then
                inform("file found on path: %s",filename)
                f:close()
                return filename
            end
            tried[#tried + 1] = format("no file '%s'",filename)
        end
        -- added: local path .. for testing
        local f = io.open(filename,"r")
        if f then
            inform("file found on current path: %s",filename)
            f:close()
            return filename
        end
        --
        tried[#tried + 1] = format("no file '%s'",filename)
        return nil, concat(tried,"\n")
    end

end

local lexers              = { }
local context             = { }
local helpers             = { }
lexers.context            = context
lexers.helpers            = helpers

local patterns            = { }
context.patterns          = patterns -- todo: lexers.patterns

context.report            = report
context.inform            = inform

lexers.LEXERPATH          = package.path -- can be multiple paths separated by ;
lexers.LEXERPATH          = "./?.lua"    -- good enough, will be set anyway (was

if resolvers then
    -- todo: set LEXERPATH
    -- todo: set report
end

local function sortedkeys(hash) -- simple version, good enough for here
    local t, n = { }, 0
    for k, v in next, hash do
        t[#t+1] = k
        local l = #tostring(k)
        if l > n then
            n = l
        end
    end
    sort(t)
    return t, n
end

helpers.sortedkeys = sortedkeys

local usedlexers          = { }
local parent_lexer        = nil

-- The problem with styles is that there is some nasty interaction with scintilla
-- and each version of lexer dll/so has a different issue. So, from now on we will
-- just add them here. There is also a limit on some 30 styles. Maybe I should
-- hash them in order to reuse.

-- todo: work with proper hashes and analyze what styles are really used by a
-- lexer

local default = {
    "nothing", "whitespace", "comment", "string", "number", "keyword",
    "identifier", "operator", "error", "preprocessor", "constant", "variable",
    "function", "type", "label",  "embedded",
    "quote", "special", "extra", "reserved", "okay", "warning",
    "command", "internal", "preamble", "grouping", "primitive", "plain",
    "user",
    -- not used (yet) .. we cross the 32 boundary so had to patch the initializer, see (1)
    "char", "class", "data", "definition", "invisible", "regex",
    "standout", "tag",
    "text",
}

local predefined = {
    "default", "linenumber", "bracelight", "bracebad", "controlchar",
    "indentguide", "calltip"
}

-- Bah ... ugly ... nicer would be a proper hash .. we now have properties
-- as well as STYLE_* and some connection between them ... why .. ok, we
-- could delay things but who cares. Anyway, at this moment the properties
-- are still unknown.

local function preparestyles(list)
    local reverse = { }
    for i=1,#list do
        local k = list[i]
        local K = upper(k)
        local s = "style." .. k
        lexers[K] = k -- is this used
        lexers["STYLE_"..K] = "$(" .. k .. ")"
        reverse[k] = true
    end
    return reverse
end

local defaultstyles    = preparestyles(default)
local predefinedstyles = preparestyles(predefined)

-- These helpers are set afterwards so we delay their initialization ... there
-- is no need to alias each time again and this way we can more easily adapt
-- to updates.

-- These keep changing (values, functions, tables ...) so we nee to check these
-- with each update. Some of them are set in the loader (the require 'lexer' is
-- in fact not a real one as the lexer code is loaded in the dll). It's also not
-- getting more efficient.

-- FOLD_BASE         = lexers.FOLD_BASE         or SC_FOLDLEVELBASE
-- FOLD_HEADER       = lexers.FOLD_HEADER       or SC_FOLDLEVELHEADERFLAG
-- FOLD_BLANK        = lexers.FOLD_BLANK        or SC_FOLDLEVELWHITEFLAG
-- get_style_at      = lexers.get_style_at      or GetStyleAt
-- get_indent_amount = lexers.get_indent_amount or GetIndentAmount
-- get_property      = lexers.get_property      or GetProperty
-- get_fold_level    = lexers.get_fold_level    or GetFoldLevel

-- It needs checking: do we have access to all properties now? I'll clean
-- this up anyway as I want a simple clean and stable model.

-- This is somewhat messy. The lexer dll provides some virtual fields:
--
-- + property
-- + property_int
-- + style_at
-- + fold_level
-- + indent_amount
--
-- but for some reasons not:
--
-- + property_expanded
--
-- As a consequence we need to define it here because otherwise the
-- lexer will crash. The fuzzy thing is that we don't have to define
-- the property and property_int tables but we do have to define the
-- expanded beforehand. The folding properties are no longer interfaced
-- so the interface to scite is now rather weak (only a few hard coded
-- properties).

local FOLD_BASE     = 0
local FOLD_HEADER   = 0
local FOLD_BLANK    = 0

local style_at      = { }
local indent_amount = { }
local fold_level    = { }

local function check_main_properties()
    if not lexers.property then
        lexers.property = { }
    end
    if not lexers.property_int then
        lexers.property_int = setmetatable({ }, {
            __index    = function(t,k)
                -- why the tostring .. it relies on lua casting to a number when
                -- doing a comparison
                return tonumber(lexers.property[k]) or 0 -- tostring removed
            end,
            __newindex = function(t,k,v)
                report("properties are read-only, '%s' is not changed",k)
            end,
        })
    end
end

lexers.property_expanded = setmetatable({ }, {
    __index   = function(t,k)
        -- better be safe for future changes .. what if at some point this is
        -- made consistent in the dll ... we need to keep an eye on that
        local property = lexers.property
        if not property then
            check_main_properties()
        end
        --
        return gsub(property[k],"[$%%]%b()", function(k)
            return t[sub(k,3,-2)]
        end)
    end,
    __newindex = function(t,k,v)
        report("properties are read-only, '%s' is not changed",k)
    end,
})

-- A downward compatible feature but obsolete:

-- local function get_property(tag,default)
--     return lexers.property_int[tag] or lexers.property[tag] or default
-- end

-- We still want our own properties (as it keeps changing so better play
-- safe from now on):

local function check_properties(lexer)
    if lexer.properties then
        return lexer
    end
    check_main_properties()
    -- we use a proxy
    local mainproperties = lexers.property
    local properties = { }
    local expanded = setmetatable({ }, {
        __index = function(t,k)
            return gsub(properties[k] or mainproperties[k],"[$%%]%b()", function(k)
                return t[sub(k,3,-2)]
            end)
        end,
    })
    lexer.properties = setmetatable(properties, {
        __index = mainproperties,
        __call = function(t,k,default) -- expands
            local v = expanded[k]
            local t = type(default)
            if t == "number" then
                return tonumber(v) or default
            elseif t == "boolean" then
                return v == nil and default or v
            else
                return v or default
            end
        end,
    })
    return lexer
end

-- do
--     lexers.property = { foo = 123, red = "R" }
--     local a = check_properties({})  print("a.foo",a.properties.foo)
--     a.properties.foo = "bar"        print("a.foo",a.properties.foo)
--     a.properties.foo = "bar:$(red)" print("a.foo",a.properties.foo) print("a.foo",a.properties("foo"))
-- end

local function set(value,default)
    if value == 0 or value == false or value == "0" then
        return false
    elseif value == 1 or value == true or value == "1" then
        return true
    else
        return default
    end
end

local function check_context_properties()
    local property = lexers.property -- let's hope that this stays
    log      = set(property["lexer.context.log"],     log)
    trace    = set(property["lexer.context.trace"],   trace)
    detail   = set(property["lexer.context.detail"],  detail)
    show     = set(property["lexer.context.show"],    show)
    collapse = set(property["lexer.context.collapse"],collapse)
    inspect  = set(property["lexer.context.inspect"], inspect)
end

function context.registerproperties(p) -- global
    check_main_properties()
    local property = lexers.property -- let's hope that this stays
    for k, v in next, p do
        property[k] = v
    end
    check_context_properties()
end

context.properties = setmetatable({ }, {
    __index    = lexers.property,
    __newindex = function(t,k,v)
        check_main_properties()
        lexers.property[k] = v
        check_context_properties()
    end,
})

-- We want locals to we set them delayed. Once.

local function initialize()
    FOLD_BASE     = lexers.FOLD_BASE
    FOLD_HEADER   = lexers.FOLD_HEADER
    FOLD_BLANK    = lexers.FOLD_BLANK
    --
    style_at      = lexers.style_at      -- table
    indent_amount = lexers.indent_amount -- table
    fold_level    = lexers.fold_level    -- table
    --
    check_main_properties()
    --
    initialize = nil
end

-- Style handler.
--
-- The property table will be set later (after loading) by the library. The
-- styleset is not needed any more as we predefine all styles as defaults
-- anyway (too bug sensitive otherwise).

local function toproperty(specification)
    local serialized = { }
    for key, value in next, specification do
        if value == true then
            serialized[#serialized+1] = key
        elseif type(value) == "table" then
            serialized[#serialized+1] = key .. ":" .. "#" .. value[1] .. value[2] .. value[3]
        else
            serialized[#serialized+1] = key .. ":" .. tostring(value)
        end
    end
    return concat(serialized,",")
end

local function tostyles(styles)
    local styleset = { }
    local property = lexers.property or { }
    for k, v in next, styles do
        v = toproperty(v)
        styleset[k] = v
        property["style."..k] = v
    end
    return styleset
end

context.toproperty = toproperty
context.tostyles   = tostyles

-- If we had one instance/state of Lua as well as all regular libraries
-- preloaded we could use the context base libraries. So, let's go poor-
-- mans solution now.

function context.registerstyles(styles)
    local styleset = tostyles(styles)
    context.styles   = styles
    context.styleset = styleset
    if trace then
        if detail then
            local t, n = sortedkeys(styleset)
            local template = "  %-" .. n .. "s : %s"
            report("initializing styleset:")
            for i=1,#t do
                local k = t[i]
                report(template,k,styleset[k])
            end
        else
            report("initializing styleset")
        end
    end
end

-- Some spell checking related stuff. Unfortunately we cannot use a path set
-- by property. This will get a hook for resolvers.

local locations = {
   "context/lexers",      -- context lexers
   "context/lexers/data", -- context lexers
   "../lexers",           -- original lexers
   "../lexers/data",      -- original lexers
   ".",                   -- whatever
   "./data",              -- whatever
}

local function collect(name)
    local root = gsub(lexers.LEXERPATH or ".","/.-lua$","") .. "/" -- this is a horrible hack
 -- report("module '%s' locating '%s'",tostring(lexers),name)
    for i=1,#locations do
        local fullname =  root .. locations[i] .. "/" .. name .. ".lua" -- so we can also check for .luc
        if trace then
            report("attempt to locate '%s'",fullname)
        end
        local okay, result = pcall(function () return dofile(fullname) end)
        if okay then
            return result, fullname
        end
    end
end

function context.loadluafile(name)
    local data, fullname = collect(name)
    if data then
        if trace then
            report("lua file '%s' has been loaded",fullname)
        end
        return data, fullname
    end
    report("unable to load lua file '%s'",name)
end

-- in fact we could share more as we probably process the data but then we need
-- to have a more advanced helper

local cache = { }

function context.loaddefinitions(name)
    local data = cache[name]
    if data then
        if trace then
            report("reusing definitions '%s'",name)
        end
        return data
    elseif trace and data == false then
        report("definitions '%s' were not found",name)
    end
    local data, fullname = collect(name)
    if not data then
        report("unable to load definition file '%s'",name)
        data = false
    elseif trace then
        report("definition file '%s' has been loaded",fullname)
        if detail then
            local t, n = sortedkeys(data)
            local template = "  %-" .. n .. "s : %s"
            for i=1,#t do
                local k = t[i]
                local v = data[k]
                if type(v) ~= "table" then
                    report(template,k,tostring(v))
                elseif #v > 0 then
                    report(template,k,#v)
                else
                    -- no need to show hash
                end
            end
        end
    end
    cache[name] = data
    return type(data) == "table" and data
end

function context.word_match(words,word_chars,case_insensitive)
    local chars = "%w_" -- maybe just "" when word_chars
    if word_chars then
        chars = "^([" .. chars .. gsub(word_chars,"([%^%]%-])", "%%%1") .."]+)"
    else
        chars = "^([" .. chars .."]+)"
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

-- Patterns are grouped in a separate namespace but the regular lexers expect
-- shortcuts to be present in the lexers library. Maybe I'll incorporate some
-- of l-lpeg later.

do

    local anything             = P(1)
    local idtoken              = R("az","AZ","\127\255","__")
    local digit                = R("09")
    local sign                 = S("+-")
    local period               = P(".")
    local octdigit             = R("07")
    local hexdigit             = R("09","AF","af")
    local lower                = R("az")
    local upper                = R("AZ")
    local alpha                = upper + lower
    local space                = S(" \n\r\t\f\v")
    local eol                  = S("\r\n")
    local backslash            = P("\\")
    local decimal              = digit^1
    local octal                = P("0")
                               * octdigit^1
    local hexadecimal          = P("0") * S("xX")
                               * (hexdigit^0 * period * hexdigit^1 + hexdigit^1 * period * hexdigit^0 + hexdigit^1)
                               * (S("pP") * sign^-1 * hexdigit^1)^-1 -- *

    patterns.idtoken           = idtoken
    patterns.digit             = digit
    patterns.sign              = sign
    patterns.period            = period
    patterns.octdigit          = octdigit
    patterns.hexdigit          = hexdigit
    patterns.ascii             = R("\000\127") -- useless
    patterns.extend            = R("\000\255") -- useless
    patterns.control           = R("\000\031")
    patterns.lower             = lower
    patterns.upper             = upper
    patterns.alpha             = alpha
    patterns.decimal           = decimal
    patterns.octal             = octal
    patterns.hexadecimal       = hexadecimal
    patterns.float             = sign^-1
                               * (digit^0 * period * digit^1 + digit^1 * period * digit^0 + digit^1)
                               * S("eE") * sign^-1 * digit^1 -- *
    patterns.cardinal          = decimal

    patterns.signeddecimal     = sign^-1 * decimal
    patterns.signedoctal       = sign^-1 * octal
    patterns.signedhexadecimal = sign^-1 * hexadecimal
    patterns.integer           = sign^-1 * (hexadecimal + octal + decimal)
    patterns.real              =
        sign^-1 * (                    -- at most one
            digit^1 * period * digit^0 -- 10.0 10.
          + digit^0 * period * digit^1 -- 0.10 .10
          + digit^1                    -- 10
       )

    patterns.anything          = anything
    patterns.any               = anything
    patterns.restofline        = (1-eol)^1
    patterns.space             = space
    patterns.spacing           = space^1
    patterns.nospacing         = (1-space)^1
    patterns.eol               = eol
    patterns.newline           = P("\r\n") + eol

    local endof                = S("\n\r\f")

    patterns.startofline       = P(function(input,index)
        return (index == 1 or lpegmatch(endof,input,index-1)) and index
    end)

    -- These are the expected ones for other lexers. Maybe all in own namespace
    -- and provide compatibility layer. or should I just remove them?

    lexers.any            = anything
    lexers.ascii          = ascii
    lexers.extend         = extend
    lexers.alpha          = alpha
    lexers.digit          = digit
    lexers.alnum          = alnum
    lexers.lower          = lower
    lexers.upper          = upper
    lexers.xdigit         = hexdigit
    lexers.cntrl          = control
    lexers.graph          = R("!~")
    lexers.print          = R(" ~")
    lexers.punct          = R("!/", ":@", "[\'", "{~")
    lexers.space          = space
    lexers.newline        = S("\r\n\f")^1
    lexers.nonnewline     = 1 - lexers.newline
    lexers.nonnewline_esc = 1 - (lexers.newline + '\\') + backslash * anything
    lexers.dec_num        = decimal
    lexers.oct_num        = octal
    lexers.hex_num        = hexadecimal
    lexers.integer        = integer
    lexers.float          = float
    lexers.word           = (alpha + "_") * (alpha + digit + "_")^0 -- weird, why digits

end

-- end of patterns

function context.exact_match(words,word_chars,case_insensitive)
    local characters = concat(words)
    local pattern -- the concat catches _ etc
    if word_chars == true or word_chars == false or word_chars == nil then
        word_chars = ""
    end
    if type(word_chars) == "string" then
        pattern = S(characters) + patterns.idtoken
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
        if #words == 0 then
            for k, v in next, words do
                list[lower(k)] = v
            end
        else
            for i=1,#words do
                list[lower(words[i])] = true
            end
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[lower(s)] -- and i or nil
        end)
    else
        local list = { }
        if #words == 0 then
            for k, v in next, words do
                list[k] = v
            end
        else
            for i=1,#words do
                list[words[i]] = true
            end
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[s] -- and i or nil
        end)
    end
end

function context.just_match(words)
    local p = P(words[1])
    for i=2,#words do
        p = p + P(words[i])
    end
    return p
end

-- spell checking (we can only load lua files)
--
-- return {
--     min = 3,
--     max = 40,
--     n = 12345,
--     words = {
--         ["someword"]    = "someword",
--         ["anotherword"] = "Anotherword",
--     },
-- }

local lists = { }

function context.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
    if not tag or tag == "" then
        return false, 3
    end
    local list = lists[tag]
    if not list then
        list = context.loaddefinitions("spell-" .. tag)
        if not list or type(list) ~= "table" then
            report("invalid spell checking list for '%s'",tag)
            list = { words = false, min = 3 }
        else
            list.words = list.words or false
            list.min   = list.min or 3
        end
        lists[tag] = list
    end
    if trace then
        report("enabling spell checking for '%s' with minimum '%s'",tag,list.min)
    end
    return list.words, list.min
end

patterns.wordtoken   = R("az","AZ","\127\255")
patterns.wordpattern = patterns.wordtoken^3 -- todo: if limit and #s < limit then

function context.checkedword(validwords,validminimum,s,i) -- ,limit
    if not validwords then -- or #s < validminimum then
        return true, "text", i -- true, "default", i
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return true, "okay", i -- exact match
        elseif word then
            return true, "warning", i -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return true, "okay", i -- exact match
            elseif word then
                return true, "warning", i -- case issue
            elseif upper(s) == s then
                return true, "warning", i -- probably a logo or acronym
            else
                return true, "error", i
            end
        end
    end
end

function context.styleofword(validwords,validminimum,s) -- ,limit
    if not validwords or #s < validminimum then
        return "text"
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return "okay" -- exact match
        elseif word then
            return "warning" -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return "okay" -- exact match
            elseif word then
                return "warning" -- case issue
            elseif upper(s) == s then
                return "warning" -- probably a logo or acronym
            else
                return "error"
            end
        end
    end
end

-- overloaded functions

local h_table, b_table, n_table = { }, { }, { } -- from the time small tables were used (optimization)

setmetatable(h_table, { __index = function(t,level) local v = { level, FOLD_HEADER } t[level] = v return v end })
setmetatable(b_table, { __index = function(t,level) local v = { level, FOLD_BLANK  } t[level] = v return v end })
setmetatable(n_table, { __index = function(t,level) local v = { level              } t[level] = v return v end })

local newline = patterns.newline
local p_yes   = Cp() * Cs((1-newline)^1) * newline^-1
local p_nop   = newline

local folders = { }

local function fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    local folder = folders[lexer]
    if not folder then
        --
        local pattern, folds, text, start_pos, line_num, prev_level, current_level
        --
        local fold_symbols = lexer._foldsymbols
        local fold_pattern = lexer._foldpattern -- use lpeg instead (context extension)
        --
        if fold_pattern then
            -- if no functions are found then we could have a faster one
            fold_pattern = Cp() * C(fold_pattern) / function(s,match)
                local symbols = fold_symbols[style_at[start_pos + s]]
                if symbols then
                    local l = symbols[match]
                    if l then
                        current_level = current_level + l
                    end
                end
            end
            local action_y = function()
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = ((fold_pattern + (1-newline))^1 * newline / action_y + newline/action_n)^0

         else
            -- the traditional one but a bit optimized
            local fold_symbols_patterns = fold_symbols._patterns
            local action_y = function(pos,line)
                for j = 1, #fold_symbols_patterns do
                    for s, match in gmatch(line,fold_symbols_patterns[j]) do -- "()(" .. patterns[i] .. ")"
                        local symbols = fold_symbols[style_at[start_pos + pos + s - 1]]
                        local l = symbols and symbols[match]
                        local t = type(l)
                        if t == "number" then
                            current_level = current_level + l
                        elseif t == "function" then
                            current_level = current_level + l(text, pos, line, s, match)
                        end
                    end
                end
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = (p_yes/action_y + p_nop/action_n)^0
        end
        --
        local reset_parser = lexer._reset_parser
        --
        folder = function(_text_,_start_pos_,_start_line_,_start_level_)
            if reset_parser then
                reset_parser()
            end
            folds         = { }
            text          = _text_
            start_pos     = _start_pos_
            line_num      = _start_line_
            prev_level    = _start_level_
            current_level = prev_level
            lpegmatch(pattern,text)
         -- make folds collectable
            local t = folds
            folds = nil
            return t
        end
        folders[lexer] = folder
    end
    return folder(text,start_pos,start_line,start_level,lexer)
end

local folds, current_line, prev_level

local function action_y()
    local current_level = FOLD_BASE + indent_amount[current_line]
    if current_level > prev_level then -- next level
        local i = current_line - 1
        local f
        while true do
            f = folds[i]
            if not f then
                break
            elseif f[2] == FOLD_BLANK then
                i = i - 1
            else
                f[2] = FOLD_HEADER -- low indent
                break
            end
        end
        folds[current_line] = { current_level } -- high indent
    elseif current_level < prev_level then -- prev level
        local f = folds[current_line - 1]
        if f then
            f[1] = prev_level -- high indent
        end
        folds[current_line] = { current_level } -- low indent
    else -- same level
        folds[current_line] = { prev_level }
    end
    prev_level = current_level
    current_line = current_line + 1
end

local function action_n()
    folds[current_line] = { prev_level, FOLD_BLANK }
    current_line = current_line + 1
end

local pattern = ( S("\t ")^0 * ( (1-patterns.eol)^1 / action_y + P(true) / action_n) * newline )^0

local function fold_by_indentation(text,start_pos,start_line,start_level)
    -- initialize
    folds        = { }
    current_line = start_line
    prev_level   = start_level
    -- define
    -- -- not here .. pattern binds and local functions are not frozen
    -- analyze
    lpegmatch(pattern,text)
    -- flatten
    for line, level in next, folds do
        folds[line] = level[1] + (level[2] or 0)
    end
    -- done, make folds collectable
    local t = folds
    folds = nil
    return t
end

local function fold_by_line(text,start_pos,start_line,start_level)
    local folds = { }
    -- can also be lpeg'd
    for _ in gmatch(text,".-\r?\n") do
        folds[start_line] = n_table[start_level] -- { start_level } -- stile tables ? needs checking
        start_line = start_line + 1
    end
    return folds
end

local threshold_by_lexer       =  512 * 1024 -- we don't know the filesize yet
local threshold_by_parsing     =  512 * 1024 -- we don't know the filesize yet
local threshold_by_indentation =  512 * 1024 -- we don't know the filesize yet
local threshold_by_line        =  512 * 1024 -- we don't know the filesize yet

function context.fold(lexer,text,start_pos,start_line,start_level) -- hm, we had size thresholds .. where did they go
    if text == "" then
        return { }
    end
    if initialize then
        initialize()
    end
    local fold_by_lexer   = lexer._fold
    local fold_by_symbols = lexer._foldsymbols
    local filesize        = 0 -- we don't know that
    if fold_by_lexer then
        if filesize <= threshold_by_lexer then
            return fold_by_lexer(text,start_pos,start_line,start_level,lexer)
        end
    elseif fold_by_symbols then -- and lexer.properties("fold.by.parsing",1) > 0 then
        if filesize <= threshold_by_parsing then
            return fold_by_parsing(text,start_pos,start_line,start_level,lexer)
        end
    elseif lexer.properties("fold.by.indentation",1) > 0 then
        if filesize <= threshold_by_indentation then
            return fold_by_indentation(text,start_pos,start_line,start_level,lexer)
        end
    elseif lexer.properties("fold.by.line",1) > 0 then
        if filesize <= threshold_by_line then
            return fold_by_line(text,start_pos,start_line,start_level,lexer)
        end
    end
    return { }
end

-- The following code is mostly unchanged:

local function add_rule(lexer,id,rule) -- unchanged
    if not lexer._RULES then
        lexer._RULES     = { }
        lexer._RULEORDER = { }
    end
    lexer._RULES[id] = rule
    lexer._RULEORDER[#lexer._RULEORDER + 1] = id
end

-- I finally figured out that adding more styles was an issue because of several
-- reasons:
--
-- + in old versions there was a limit in the amount, so we overran the built-in
--   hard coded scintilla range
-- + then, the add_style function didn't check for already known ones, so again
--   we had an overrun (with some magic that could be avoided)
-- + then, when I messed with a new default set I realized that there is no check
--   in initializing _TOKENSTYLES (here the inspect function helps)
-- + of course it was mostly a side effect of passing all the used styles to the
--   _tokenstyles instead of only the not-default ones but such a thing should not
--   matter (read: intercepted)
--
-- This finally removed a head-ache and was revealed by lots of tracing, which I
-- should have built in way earlier.

local function add_style(lexer,token_name,style) -- changed a bit around 3.41
    -- We don't add styles that are already defined as this can overflow the
    -- amount possible (in old versions of scintilla).
    if defaultstyles[token_name] then
        if trace and detail then
            report("default style '%s' is ignored as extra style",token_name)
        end
        return
    elseif predefinedstyles[token_name] then
        if trace and detail then
            report("predefined style '%s' is ignored as extra style",token_name)
        end
        return
    else
        if trace and detail then
            report("adding extra style '%s' as '%s'",token_name,style)
        end
    end
    -- This is unchanged. We skip the dangerous zone.
    local num_styles = lexer._numstyles
    if num_styles == 32 then
        num_styles = num_styles + 8
    end
    if num_styles >= 255 then
        report("there can't be more than %s styles",255)
    end
    lexer._TOKENSTYLES[token_name] = num_styles
    lexer._EXTRASTYLES[token_name] = style
    lexer._numstyles = num_styles + 1
end

local function check_styles(lexer)
    -- Here we also use a check for the dangerous zone. That way we can have a
    -- larger default set. The original code just assumes that #default is less
    -- than the dangerous zone's start.
    local numstyles   = 0
    local tokenstyles = { }
    for i=1, #default do
        if numstyles == 32 then
            numstyles = numstyles + 8
        end
        tokenstyles[default[i]] = numstyles
        numstyles = numstyles + 1
    end
    -- Unchanged.
    for i=1, #predefined do
        tokenstyles[predefined[i]] = i + 31
    end
    lexer._TOKENSTYLES  = tokenstyles
    lexer._numstyles    = numstyles
    lexer._EXTRASTYLES  = { }
    return lexer
end

-- At some point an 'any' append showed up in the original code ...
-- but I see no need to catch that case ... beter fix the specification.
--
-- hm, why are many joined twice

local function join_tokens(lexer) -- slightly different from the original (no 'any' append)
    local patterns = lexer._RULES
    local order    = lexer._RULEORDER
 -- report("lexer: %s, tokens: %s",lexer._NAME,table.concat(order," + "))
    if patterns and order then
        local token_rule = patterns[order[1]] -- normally whitespace
        for i=2,#order do
            token_rule = token_rule + patterns[order[i]]
        end
        if lexer._TYPE ~= "context" then
           token_rule = token_rule + lexers.token(lexers.DEFAULT, patterns.any)
        end
        lexer._TOKENRULE = token_rule
        return token_rule
    else
        return P(1)
    end
end

local function add_lexer(grammar, lexer) -- mostly the same as the original
    local token_rule = join_tokens(lexer)
    local lexer_name = lexer._NAME
    local children   = lexer._CHILDREN
    for i=1,#children do
        local child = children[i]
        if child._CHILDREN then
            add_lexer(grammar, child)
        end
        local child_name        = child._NAME
        local rules             = child._EMBEDDEDRULES[lexer_name]
        local rules_token_rule  = grammar["__" .. child_name] or rules.token_rule
        local pattern           = (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1
        grammar[child_name]     = pattern * V(lexer_name)
        local embedded_child    = "_" .. child_name
        grammar[embedded_child] = rules.start_rule * pattern
        token_rule              = V(embedded_child) + token_rule
    end
    if trace then
        report("adding lexer '%s' with %s children",lexer_name,#children)
    end
    grammar["__" .. lexer_name] = token_rule
    grammar[lexer_name]         = token_rule^0
end

local function build_grammar(lexer,initial_rule) -- same as the original
    local children = lexer._CHILDREN
    local lexer_name = lexer._NAME
    if children then
        if not initial_rule then
            initial_rule = lexer_name
        end
        local grammar = { initial_rule }
        add_lexer(grammar, lexer)
        lexer._INITIALRULE = initial_rule
        lexer._GRAMMAR = Ct(P(grammar))
        if trace then
            report("building grammar for '%s' with whitespace '%s'and %s children",lexer_name,lexer.whitespace or "?",#children)
        end
    else
        lexer._GRAMMAR = Ct(join_tokens(lexer)^0)
        if trace then
            report("building grammar for '%s' with whitespace '%s'",lexer_name,lexer.whitespace or "?")
        end
    end
end

-- So far. We need these local functions in the next one.

local lineparsers = { }

local maxmatched  = 100

local function collapsed(t)
    local lasttoken = nil
    local lastindex = nil
    for i=1,#t,2 do
        local token    = t[i]
        local position = t[i+1]
        if token == lasttoken then
            t[lastindex] = position
        elseif lastindex then
            lastindex = lastindex + 1
            t[lastindex] = token
            lastindex = lastindex + 1
            t[lastindex] = position
            lasttoken = token
        else
            lastindex = i+1
            lasttoken = token
        end
    end
    for i=#t,lastindex+1,-1 do
        t[i] = nil
    end
    return t
end

local function matched(lexer,grammar,text)
 -- text = string.gsub(text,"\z","!")
    local t = lpegmatch(grammar,text)
    if trace then
        if show then
            report("output of lexer: %s (max %s entries)",lexer._NAME,maxmatched)
            local s = lexer._TOKENSTYLES
            local p = 1
            for i=1,2*maxmatched,2 do
                local n = i + 1
                local ti = t[i]
                local tn = t[n]
                if ti then
                    local txt = sub(text,p,tn-1)
                    if txt then
                        txt = gsub(txt,"[%s]"," ")
                    else
                        txt = "!no text!"
                    end
                    report("%4i : %s > %s (%s) (%s)",n/2,ti,tn,s[ti] or "!unset!",txt)
                    p = tn
                else
                    break
                end
            end
        end
        report("lexer results: %s, length: %s, ranges: %s",lexer._NAME,#text,#t/2)
        if collapse then
            t = collapsed(t)
            report("lexer collapsed: %s, length: %s, ranges: %s",lexer._NAME,#text,#t/2)
        end
    elseif collapse then
        t = collapsed(t)
    end
    return t
end

-- Todo: make nice generic lexer (extra argument with start/stop commands) for
-- context itself.

function context.lex(lexer,text,init_style)
 -- local lexer = global._LEXER
    local grammar = lexer._GRAMMAR
    if initialize then
        initialize()
    end
    if not grammar then
        return { }
    elseif lexer._LEXBYLINE then -- we could keep token
        local tokens = { }
        local offset = 0
        local noftokens = 0
        local lineparser = lineparsers[lexer]
        if not lineparser then -- probably a cmt is more efficient
            lineparser = C((1-newline)^0 * newline) / function(line)
                local length = #line
                local line_tokens = length > 0 and lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens,2 do
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i]
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i + 1] + offset
                    end
                end
                offset = offset + length
                if noftokens > 0 and tokens[noftokens] ~= offset then
                    noftokens = noftokens + 1
                    tokens[noftokens] = "default"
                    noftokens = noftokens + 1
                    tokens[noftokens] = offset + 1
                end
            end
            lineparser = lineparser^0
            lineparsers[lexer] = lineparser
        end
        lpegmatch(lineparser,text)
        return tokens
    elseif lexer._CHILDREN then
        local hash = lexer._HASH -- hm, was _hash
        if not hash then
            hash = { }
            lexer._HASH = hash
        end
        grammar = hash[init_style]
        if grammar then
            lexer._GRAMMAR = grammar
         -- lexer._GRAMMAR = lexer._GRAMMAR or grammar
        else
            for style, style_num in next, lexer._TOKENSTYLES do
                if style_num == init_style then
                    -- the name of the lexers is filtered from the whitespace
                    -- specification .. weird code, should be a reverse hash
                    local lexer_name = match(style,"^(.+)_whitespace") or lexer._NAME
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
        if trace then
            report("lexing '%s' with initial style '%s' and %s children",lexer._NAME,#lexer._CHILDREN or 0,init_style)
        end
        return matched(lexer,grammar,text)
    else
        if trace then
            report("lexing '%s' with initial style '%s'",lexer._NAME,init_style)
        end
        return matched(lexer,grammar,text)
    end
end

-- hm, changed in 3.24 .. no longer small table but one table:

function context.token(name, patt)
    return patt * Cc(name) * Cp()
end

-- The next ones were mostly unchanged (till now), we moved it here when 3.41
-- became close to impossible to combine with cq. overload and a merge was
-- the only solution. It makes later updates more painful but the update to
-- 3.41 was already a bit of a nightmare anyway.

-- Loading lexers is rather interwoven with what the dll/so sets and
-- it changes over time. So, we need to keep an eye on changes. One
-- problem that we always faced were the limitations in length of
-- lexer names (as they get app/prepended occasionally to strings with
-- a hard coded limit). So, we always used alternative names and now need
-- to make sure this doesn't clash. As I no longer intend to use shipped
-- lexers I could strip away some of the code in the future, but keeping
-- it as reference makes sense.

-- I spend quite some time figuring out why 3.41 didn't work or crashed which
-- is hard when no stdout is available and when the io library is absent. In
-- the end of of the problems was in the _NAME setting. We set _NAME
-- to e.g. 'tex' but load from a file with a longer name, which we do
-- as we don't want to clash with existing files, we end up in
-- lexers not being found.

local whitespaces = { }

local function push_whitespace(name)
    table.insert(whitespaces,lexers.WHITESPACE or "whitespace")
    lexers.WHITESPACE = name .. "_whitespace"
end

local function pop_whitespace()
    lexers.WHITESPACE = table.remove(whitespaces) or "whitespace"
end

local function check_whitespace(lexer,name)
    if lexer then
        lexer.whitespace = (name or lexer.name or lexer._NAME) .. "_whitespace"
    end
end

function context.new(name,filename)
    local lexer = {
        _TYPE        = "context",
        --
        _NAME        = name,       -- used for token building
        _FILENAME    = filename,   -- for diagnostic purposed
        --
        name         = name,
        filename     = filename,
    }
    if trace then
        report("initializing lexer tagged '%s' from file '%s'",name,filename or name)
    end
    check_whitespace(lexer)
    check_styles(lexer)
    check_properties(lexer)
    return lexer
end

local function nolexer(name)
    local lexer = {
        _TYPE  = "unset",
        _NAME  = name,
     -- _rules = { },
    }
    check_styles(lexer)
    check_whitespace(lexer)
    check_properties(lexer)
    return lexer
end

local function load_lexer(name,namespace)
    if trace then
        report("loading lexer file '%s'",name)
    end
    push_whitespace(namespace or name) -- for traditional lexers .. no alt_name yet
    local lexer, fullname = context.loadluafile(name)
    pop_whitespace()
    if not lexer then
        report("invalid lexer file '%s'",name)
    elseif trace then
        report("lexer file '%s' has been loaded",fullname)
    end
    if type(lexer) ~= "table" then
        if trace then
            report("lexer file '%s' gets a dummy lexer",name)
        end
        return nolexer(name)
    end
    if lexer._TYPE ~= "context" then
        lexer._TYPE = "native"
        check_styles(lexer)
        check_whitespace(lexer,namespace or name)
        check_properties(lexer)
    end
    if not lexer._NAME then
        lexer._NAME = name -- so: filename
    end
    if name ~= namespace then
        lexer._NAME = namespace
    end
    return lexer
end

-- tracing ...

local function inspect_lexer(lexer,level)
    -- If we had the regular libs available I could use the usual
    -- helpers.
    local parent = lexer._lexer
    lexer._lexer = nil -- prevent endless recursion
    local name = lexer._NAME
    local function showstyles_1(tag,styles)
        local numbers = { }
        for k, v in next, styles do
            numbers[v] = k
        end
        -- sort by number and make number hash too
        local keys = sortedkeys(numbers)
        for i=1,#keys do
            local k = keys[i]
            local v = numbers[k]
            report("[%s %s] %s %s = %s",level,name,tag,k,v)
        end
    end
    local function showstyles_2(tag,styles)
        local keys = sortedkeys(styles)
        for i=1,#keys do
            local k = keys[i]
            local v = styles[k]
            report("[%s %s] %s %s = %s",level,name,tag,k,v)
        end
    end
    local keys = sortedkeys(lexer)
    for i=1,#keys do
        local k = keys[i]
        local v = lexer[k]
        report("[%s %s] root key : %s = %s",level,name,k,tostring(v))
    end
    showstyles_1("token style",lexer._TOKENSTYLES)
    showstyles_2("extra style",lexer._EXTRASTYLES)
    local children = lexer._CHILDREN
    if children then
        for i=1,#children do
            inspect_lexer(children[i],level+1)
        end
    end
    lexer._lexer = parent
end

function context.inspect(lexer)
    inspect_lexer(lexer,0)
end

-- An optional second argument has been introduced so that one can embed a lexer
-- more than once ... maybe something to look into (as not it's done by remembering
-- the start sequence ... quite okay but maybe suboptimal ... anyway, never change
-- a working solution).

-- namespace can be automatic: if parent then use name of parent (chain)

function context.loadlexer(filename,namespace)
    nesting = nesting + 1
    if not namespace then
        namespace = filename
    end
    local lexer = usedlexers[namespace] -- we load by filename but the internal name can be short
    if lexer then
        if trace then
            report("reusing lexer '%s'",namespace)
        end
        nesting = nesting - 1
        return lexer
    elseif trace then
        report("loading lexer '%s'",namespace)
    end
    --
    if initialize then
        initialize()
    end
    --
    parent_lexer = nil
    --
    lexer = load_lexer(filename,namespace) or nolexer(filename,namespace)
    usedlexers[filename] = lexer
    --
    if not lexer._rules and not lexer._lexer then
        lexer._lexer = parent_lexer
    end
    --
    if lexer._lexer then
        local _l = lexer._lexer
        local _r = lexer._rules
        local _s = lexer._tokenstyles
        if not _l._tokenstyles then
            _l._tokenstyles = { }
        end
        if _r then
            local rules = _l._rules
            local name  = lexer.name
            for i=1,#_r do
                local rule = _r[i]
                rules[#rules + 1] = {
                    name .. "_" .. rule[1],
                    rule[2],
                }
            end
        end
        if _s then
            local tokenstyles = _l._tokenstyles
            for token, style in next, _s do
                tokenstyles[token] = style
            end
        end
        lexer = _l
    end
    --
    local _r = lexer._rules
    if _r then
        local _s = lexer._tokenstyles
        if _s then
            for token, style in next, _s do
                add_style(lexer, token, style)
            end
        end
        for i=1,#_r do
            local rule = _r[i]
            add_rule(lexer, rule[1], rule[2])
        end
        build_grammar(lexer)
    end
    --
    add_style(lexer, lexer.whitespace, lexers.STYLE_WHITESPACE)
    --
    local foldsymbols = lexer._foldsymbols
    if foldsymbols then
        local patterns = foldsymbols._patterns
        if patterns then
            for i = 1, #patterns do
                patterns[i] = "()(" .. patterns[i] .. ")"
            end
        end
    end
    --
    lexer.lex  = lexers.lex
    lexer.fold = lexers.fold
    --
    nesting = nesting - 1
    --
    if inspect then
        context.inspect(lexer)
    end
    --
    return lexer
end

function context.embed_lexer(parent, child, start_rule, end_rule) -- mostly the same as the original
    local embeddedrules = child._EMBEDDEDRULES
    if not embeddedrules then
        embeddedrules = { }
        child._EMBEDDEDRULES = embeddedrules
    end
    if not child._RULES then
        local rules = child._rules
        if not rules then
            report("child lexer '%s' has no rules",child._NAME or "unknown")
            rules = { }
            child._rules = rules
        end
        for i=1,#rules do
            local rule = rules[i]
            add_rule(child, rule[1], rule[2])
        end
    end
    embeddedrules[parent._NAME] = {
        ["start_rule"] = start_rule,
        ["token_rule"] = join_tokens(child),
        ["end_rule"]   = end_rule
    }
    local children = parent._CHILDREN
    if not children then
        children = { }
        parent._CHILDREN = children
    end
    children[#children + 1] = child
    local tokenstyles = parent._tokenstyles
    if not tokenstyles then
        tokenstyles = { }
        parent._tokenstyles = tokenstyles
    end
    local childname = child._NAME
    local whitespace = childname .. "_whitespace"
    tokenstyles[whitespace] = lexers.STYLE_WHITESPACE -- all these STYLE_THINGS will go .. just a proper hash
    if trace then
        report("using whitespace '%s' as trigger for '%s' with property '%s'",whitespace,childname,lexers.STYLE_WHITESPACE)
    end
    local childstyles = child._tokenstyles
    if childstyles then
        for token, style in next, childstyles do
            tokenstyles[token] = style
        end
    end
    child._lexer = parent
    parent_lexer = parent
end

-- we now move the adapted code to the lexers namespace

lexers.new         = context.new
lexers.load        = context.loadlexer
------.loadlexer   = context.loadlexer
lexers.loadluafile = context.loadluafile
lexers.embed_lexer = context.embed_lexer
lexers.fold        = context.fold
lexers.lex         = context.lex
lexers.token       = context.token
lexers.word_match  = context.word_match
lexers.exact_match = context.exact_match
lexers.just_match  = context.just_match
lexers.inspect     = context.inspect
lexers.report      = context.report
lexers.inform      = context.inform

-- helper .. alas ... the lexer's lua instance is rather crippled .. not even
-- math is part of it

do

    local floor = math and math.floor
    local char  = string.char

    if not floor then

        floor = function(n)
            return tonumber(format("%d",n))
        end

        math = math or { }

        math.floor = floor

    end

    local function utfchar(n)
        if n < 0x80 then
            return char(n)
        elseif n < 0x800 then
            return char(
                0xC0 + floor(n/0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x10000 then
            return char(
                0xE0 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x40000 then
            return char(
                0xF0 + floor(n/0x40000),
                0x80 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        else
         -- return char(
         --     0xF1 + floor(n/0x1000000),
         --     0x80 + floor(n/0x40000),
         --     0x80 + floor(n/0x1000),
         --     0x80 + (floor(n/0x40) % 0x40),
         --     0x80 + (n % 0x40)
         -- )
            return "?"
        end
    end

    context.utfchar = utfchar

 -- -- the next one is good enough for use here but not perfect (see context for a
 -- -- better one)
 --
 -- local function make(t)
 --     local p
 --     for k, v in next, t do
 --         if not p then
 --             if next(v) then
 --                 p = P(k) * make(v)
 --             else
 --                 p = P(k)
 --             end
 --         else
 --             if next(v) then
 --                 p = p + P(k) * make(v)
 --             else
 --                 p = p + P(k)
 --             end
 --         end
 --     end
 --     return p
 -- end
 --
 -- function lpeg.utfchartabletopattern(list)
 --     local tree = { }
 --     for i=1,#list do
 --         local t = tree
 --         for c in gmatch(list[i],".") do
 --             if not t[c] then
 --                 t[c] = { }
 --             end
 --             t = t[c]
 --         end
 --     end
 --     return make(tree)
 -- end

    helpers.utfcharpattern = P(1) * R("\128\191")^0 -- unchecked but fast

    local p_false = P(false)
    local p_true  = P(true)

    local function make(t)
        local function making(t)
            local p    = p_false
            local keys = sortedkeys(t)
            for i=1,#keys do
                local k = keys[i]
                if k ~= "" then
                    local v = t[k]
                    if v == true then
                        p = p + P(k) * p_true
                    elseif v == false then
                        -- can't happen
                    else
                        p = p + P(k) * making(v)
                    end
                end
            end
            if t[""] then
                p = p + p_true
            end
            return p
        end
        local p    = p_false
        local keys = sortedkeys(t)
        for i=1,#keys do
            local k = keys[i]
            if k ~= "" then
                local v = t[k]
                if v == true then
                    p = p + P(k) * p_true
                elseif v == false then
                    -- can't happen
                else
                    p = p + P(k) * making(v)
                end
            end
        end
        return p
    end

    local function collapse(t,x)
        if type(t) ~= "table" then
            return t, x
        else
            local n = next(t)
            if n == nil then
                return t, x
            elseif next(t,n) == nil then
                -- one entry
                local k = n
                local v = t[k]
                if type(v) == "table" then
                    return collapse(v,x..k)
                else
                    return v, x .. k
                end
            else
                local tt = { }
                for k, v in next, t do
                    local vv, kk = collapse(v,k)
                    tt[kk] = vv
                end
                return tt, x
            end
        end
    end

    function helpers.utfchartabletopattern(list)
        local tree = { }
        local n = #list
        if n == 0 then
            for s in next, list do
                local t = tree
                local p, pk
                for c in gmatch(s,".") do
                    if t == true then
                        t = { [c] = true, [""] = true }
                        p[pk] = t
                        p = t
                        t = false
                    elseif t == false then
                        t = { [c] = false }
                        p[pk] = t
                        p = t
                        t = false
                    else
                        local tc = t[c]
                        if not tc then
                            tc = false
                            t[c] = false
                        end
                        p = t
                        t = tc
                    end
                    pk = c
                end
                if t == false then
                    p[pk] = true
                elseif t == true then
                    -- okay
                else
                    t[""] = true
                end
            end
        else
            for i=1,n do
                local s = list[i]
                local t = tree
                local p, pk
                for c in gmatch(s,".") do
                    if t == true then
                        t = { [c] = true, [""] = true }
                        p[pk] = t
                        p = t
                        t = false
                    elseif t == false then
                        t = { [c] = false }
                        p[pk] = t
                        p = t
                        t = false
                    else
                        local tc = t[c]
                        if not tc then
                            tc = false
                            t[c] = false
                        end
                        p = t
                        t = tc
                    end
                    pk = c
                end
                if t == false then
                    p[pk] = true
                elseif t == true then
                    -- okay
                else
                    t[""] = true
                end
            end
        end
        collapse(tree,"")
    --     inspect(tree)
        return make(tree)
    end

    patterns.invisibles = helpers.utfchartabletopattern {
        utfchar(0x00A0), -- nbsp
        utfchar(0x2000), -- enquad
        utfchar(0x2001), -- emquad
        utfchar(0x2002), -- enspace
        utfchar(0x2003), -- emspace
        utfchar(0x2004), -- threeperemspace
        utfchar(0x2005), -- fourperemspace
        utfchar(0x2006), -- sixperemspace
        utfchar(0x2007), -- figurespace
        utfchar(0x2008), -- punctuationspace
        utfchar(0x2009), -- breakablethinspace
        utfchar(0x200A), -- hairspace
        utfchar(0x200B), -- zerowidthspace
        utfchar(0x202F), -- narrownobreakspace
        utfchar(0x205F), -- math thinspace
    }

    -- now we can make:

    patterns.iwordtoken   = patterns.wordtoken - patterns.invisibles
    patterns.iwordpattern = patterns.iwordtoken^3

end

-- The following helpers are not used, partially replaced by other mechanisms and
-- when needed I'll first optimize them. I only made them somewhat more readable.

function lexers.delimited_range(chars, single_line, no_escape, balanced) -- unchanged
    local s = sub(chars,1,1)
    local e = #chars == 2 and sub(chars,2,2) or s
    local range
    local b = balanced and s or ""
    local n = single_line and "\n" or ""
    if no_escape then
        local invalid = S(e .. n .. b)
        range = patterns.any - invalid
    else
        local invalid = S(e .. n .. b) + patterns.backslash
        range = patterns.any - invalid + patterns.backslash * patterns.any
    end
    if balanced and s ~= e then
        return P {
            s * (range + V(1))^0 * e
        }
    else
        return s * range^0 * P(e)^-1
    end
end

function lexers.starts_line(patt) -- unchanged
    return P ( function(input, index)
        if index == 1 then
            return index
        end
        local char = sub(input,index - 1,index - 1)
        if char == "\n" or char == "\r" or char == "\f" then
            return index
        end
    end ) * patt
end

function lexers.last_char_includes(s) -- unchanged
    s = "[" .. gsub(s,"[-%%%[]", "%%%1") .. "]"
    return P ( function(input, index)
        if index == 1 then
            return index
        end
        local i = index
        while match(sub(input,i - 1,i - 1),"[ \t\r\n\f]") do
            i = i - 1
        end
        if match(sub(input,i - 1,i - 1),s) then
            return index
        end
    end)
end

function lexers.nested_pair(start_chars, end_chars) -- unchanged
    local s = start_chars
    local e = P(end_chars)^-1
    return P {
        s * (patterns.any - s - end_chars + V(1))^0 * e
    }
end

local function prev_line_is_comment(prefix, text, pos, line, s) -- unchanged
    local start = find(line,"%S")
    if start < s and not find(line,prefix,start,true) then
        return false
    end
    local p = pos - 1
    if sub(text,p,p) == "\n" then
        p = p - 1
        if sub(text,p,p) == "\r" then
            p = p - 1
        end
        if sub(text,p,p) ~= "\n" then
            while p > 1 and sub(text,p - 1,p - 1) ~= "\n"
                do p = p - 1
            end
            while find(sub(text,p,p),"^[\t ]$") do
                p = p + 1
            end
            return sub(text,p,p + #prefix - 1) == prefix
        end
    end
    return false
end

local function next_line_is_comment(prefix, text, pos, line, s)
    local p = find(text,"\n",pos + s)
    if p then
        p = p + 1
        while find(sub(text,p,p),"^[\t ]$") do
            p = p + 1
        end
        return sub(text,p,p + #prefix - 1) == prefix
    end
    return false
end

function lexers.fold_line_comments(prefix)
    local property_int = lexers.property_int
    return function(text, pos, line, s)
        if property_int["fold.line.comments"] == 0 then
            return 0
        end
        if s > 1 and match(line,"^%s*()") < s then
            return 0
        end
        local prev_line_comment = prev_line_is_comment(prefix, text, pos, line, s)
        local next_line_comment = next_line_is_comment(prefix, text, pos, line, s)
        if not prev_line_comment and next_line_comment then
            return 1
        end
        if prev_line_comment and not next_line_comment then
            return -1
        end
        return 0
    end
end

-- done

return lexers
