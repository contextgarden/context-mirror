local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for context",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- maybe: _LINEBYLINE variant for large files (no nesting)
-- maybe: protected_macros

--[[

  experiment dd 2009/10/28 .. todo:

  -- figure out if tabs instead of splits are possible
  -- locate an option to enter name in file dialogue (like windows permits)
  -- figure out why loading a file fails
  -- we cannot print to the log pane
  -- we cannot access props["keywordclass.macros.context.en"]
  -- lexer.get_property only handles integers
  -- we cannot run a command to get the location of mult-def.lua

  -- local interface = props["keywordclass.macros.context.en"]
  -- local interface = lexer.get_property("keywordclass.macros.context.en","")

  -- it seems that whitespace triggers the lexer when embedding happens, but this
  -- is quite fragile due to duplicate styles

  -- this lexer does not care about other macro packages (one can of course add a fake
  -- interface but it's not on the agenda)

]]--

local lexer = lexer
local global, string, table, lpeg = _G, string, table, lpeg
local token, style, colors, exact_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.exact_match, lexer.style_nothing
local P, R, S, V, C, Cmt, Cp, Cc, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt, lpeg.Cp, lpeg.Cc, lpeg.Ct
local type, next, pcall, loadfile, setmetatable = type, next, pcall, loadfile, setmetatable
local find, match, lower = string.find, string.match, string.lower

module(...)

local contextlexer = _M
local cldlexer     = lexer.load('scite-context-lexer-cld')
local mpslexer     = lexer.load('scite-context-lexer-mps')

local commands   = { en = { } }
local primitives = { }
local helpers    = { }
local constants  = { }

do -- todo: only once, store in global

    local definitions = lexer.context.loaddefinitions("scite-context-data-interfaces")

    if definitions then
        for interface, list in next, definitions do
            local c = { }
            for i=1,#list do
                c[list[i]] = true
            end
            if interface ~= "en" then
                list = definitions.en
                if list then
                    for i=1,#list do
                        c[list[i]] = true
                    end
                end
            end
            commands[interface] = c
        end
    end

    local definitions = lexer.context.loaddefinitions("scite-context-data-context")

    if definitions then
        helpers   = definitions.helpers   or { }
        constants = definitions.constants or { }
    end

    local definitions = lexer.context.loaddefinitions("scite-context-data-tex")

    if definitions then
        local function add(data)
            for k, v in next, data do
                primitives[#primitives+1] = v
                if normal then
                    primitives[#primitives+1] = "normal" .. v
                end
            end
        end
        add(definitions.tex,true)
        add(definitions.etex)
        add(definitions.pdftex)
        add(definitions.aleph)
        add(definitions.omega)
        add(definitions.luatex)
        add(definitions.xetex)
    end

end

local currentcommands = commands.en or { }

local cstoken = R("az","AZ","\127\255") + S("@!?_")

local knowncommand = Cmt(cstoken^1, function(_,i,s)
    return currentcommands[s] and i
end)

local wordpattern = lexer.context.wordpattern
local checkedword = lexer.context.checkedword
local setwordlist = lexer.context.setwordlist
local validwords  = false

-- % language=uk

local knownpreamble = Cmt(#P("% "), function(input,i,_) -- todo : utfbomb
    if i < 10 then
        validwords = false
        local s, e, word = find(input,'^(.+)[\n\r]',i) -- combine with match
        if word then
            local interface = match(word,"interface=(..)")
            if interface then
                currentcommands  = commands[interface] or commands.en or { }
            end
            local language = match(word,"language=(..)")
            validwords = language and setwordlist(language)
        end
    end
    return false
end)

-- -- the token list contains { "style", endpos } entries
-- --
-- -- in principle this is faster but it is also crash sensitive for large files

-- local constants_hash  = { } for i=1,#constants  do constants_hash [constants [i]] = true end
-- local helpers_hash    = { } for i=1,#helpers    do helpers_hash   [helpers   [i]] = true end
-- local primitives_hash = { } for i=1,#primitives do primitives_hash[primitives[i]] = true end

-- local specialword = Ct( P('\\') * Cmt( C(cstoken^1), function(input,i,s)
--     if currentcommands[s] then
--         return true, "command", i
--     elseif constants_hash[s] then
--         return true, "data", i
--     elseif helpers_hash[s] then
--         return true, "plain", i
--     elseif primitives_hash[s] then
--         return true, "primitive", i
--     else -- if starts with if then primitive
--         return true, "user", i
--     end
-- end) )

-- local specialword = P('\\') * Cmt( C(cstoken^1), function(input,i,s)
--     if currentcommands[s] then
--         return true, { "command", i }
--     elseif constants_hash[s] then
--         return true, { "data", i }
--     elseif helpers_hash[s] then
--         return true, { "plain", i }
--     elseif primitives_hash[s] then
--         return true, { "primitive", i }
--     else -- if starts with if then primitive
--         return true, { "user", i }
--     end
-- end)

-- experiment: keep space with whatever ... less tables

local commentline            = P('%') * (1-S("\n\r"))^0
local endline                = S("\n\r")^1

local whitespace             = contextlexer.WHITESPACE -- triggers states

local space                  = lexer.space -- S(" \n\r\t\f\v")
local any                    = lexer.any
local backslash              = P("\\")
local hspace                 = S(" \t")

local p_spacing              = space^1
local p_rest                 = any

local p_preamble             = knownpreamble
local p_comment              = commentline
local p_command              = backslash * knowncommand
local p_constant             = backslash * exact_match(constants)
local p_helper               = backslash * exact_match(helpers)
local p_primitive            = backslash * exact_match(primitives)
local p_ifprimitive          = P('\\if') * cstoken^1
local p_csname               = backslash * (cstoken^1 + P(1))
local p_grouping             = S("{$}")
local p_special              = S("#()[]<>=\"")
local p_extra                = S("`~%^&_-+/\'|")
local p_text                 = cstoken^1 --maybe add punctuation and space

-- no looking back           = #(1-S("[=")) * cstoken^3 * #(1-S("=]"))

-- local p_word                 = Cmt(wordpattern, function(_,i,s)
--     if not validwords then
--         return true, { "text", i }
--     else
--         -- keys are lower
--         local word = validwords[s]
--         if word == s then
--             return true, { "okay", i } -- exact match
--         elseif word then
--             return true, { "warning", i } -- case issue
--         else
--             local word = validwords[lower(s)]
--             if word == s then
--                 return true, { "okay", i } -- exact match
--             elseif word then
--                 return true, { "warning", i } -- case issue
--             else
--                 return true, { "error", i }
--             end
--         end
--     end
-- end)

local p_word = Cmt(wordpattern, function(_,i,s)
    if validwords then
        return checkedword(validwords,s,i)
    else
        return true, { "text", i }
    end
end)

-- local p_text                 = (1 - p_grouping - p_special - p_extra - backslash - space + hspace)^1

-- keep key pressed at end-of syst-aux.mkiv:
--
-- 0 : 15 sec
-- 1 : 13 sec
-- 2 : 10 sec
--
-- the problem is that quite some style subtables get generated so collapsing ranges helps

local option = 1

if option == 1 then

    p_comment                = p_comment^1
    p_grouping               = p_grouping^1
    p_special                = p_special^1
    p_extra                  = p_extra^1

    p_command                = p_command^1
    p_constant               = p_constant^1
    p_helper                 = p_helper^1
    p_primitive              = p_primitive^1
    p_ifprimitive            = p_ifprimitive^1

elseif option == 2 then

    local included           = space^0

    p_comment                = (p_comment     * included)^1
    p_grouping               = (p_grouping    * included)^1
    p_special                = (p_special     * included)^1
    p_extra                  = (p_extra       * included)^1

    p_command                = (p_command     * included)^1
    p_constant               = (p_constant    * included)^1
    p_helper                 = (p_helper      * included)^1
    p_primitive              = (p_primitive   * included)^1
    p_ifprimitive            = (p_ifprimitive * included)^1

end

local spacing                = token(whitespace,  p_spacing    )

local rest                   = token('default',   p_rest       )
local preamble               = token('preamble',  p_preamble   )
local comment                = token('comment',   p_comment    )
local command                = token('command',   p_command    )
local constant               = token('data',      p_constant   )
local helper                 = token('plain',     p_helper     )
local primitive              = token('primitive', p_primitive  )
local ifprimitive            = token('primitive', p_ifprimitive)
local csname                 = token('user',      p_csname     )
local grouping               = token('grouping',  p_grouping   )
local special                = token('special',   p_special    )
local extra                  = token('extra',     p_extra      )
----- text                   = token('default',   p_text       )
----- word                   = token("okay",      p_word       )
local word                   = p_word

----- startluacode           = token("grouping", P("\\startluacode"))
----- stopluacode            = token("grouping", P("\\stopluacode"))

local luastatus = false
local luatag    = nil
local lualevel  = 0

local function startdisplaylua(_,i,s)
    luatag = s
    luastatus = "display"
    cldlexer._directives.cld_inline = false
    return true
end

local function stopdisplaylua(_,i,s)
    local ok = luatag == s
    if ok then
cldlexer._directives.cld_inline = false
        luastatus = false
    end
    return ok
end

local function startinlinelua(_,i,s)
    if luastatus == "display" then
        return false
    elseif not luastatus then
        luastatus = "inline"
        cldlexer._directives.cld_inline = true
        lualevel = 1
        return true
    else
        lualevel = lualevel + 1
        return true
    end
end

local function stopinlinelua_b(_,i,s) -- {
    if luastatus == "display" then
        return false
    elseif luastatus == "inline" then
        lualevel = lualevel + 1
        return false
    else
        return true
    end
end

local function stopinlinelua_e(_,i,s) -- }
    if luastatus == "display" then
        return false
    elseif luastatus == "inline" then
        lualevel = lualevel - 1
        local ok = lualevel <= 0
        if ok then
cldlexer._directives.cld_inline = false
            luastatus = false
        end
        return ok
    else
        return true
    end
end

local luaenvironment         = P("luacode")

local inlinelua              = P("\\") * (
                                    P("ctx") * ( P("lua") + P("command") )
                                  + P("cldcontext")
                               )

local startlua               = P("\\start") * Cmt(luaenvironment,startdisplaylua)
                             + inlinelua * space^0 * Cmt(P("{"),startinlinelua)

local stoplua                = P("\\stop") * Cmt(luaenvironment,stopdisplaylua)
                             + Cmt(P("{"),stopinlinelua_b)
                             + Cmt(P("}"),stopinlinelua_e)

local startluacode           = token("embedded", startlua)
local stopluacode            = token("embedded", stoplua)

local metafunenvironment     = ( P("use") + P("reusable") + P("unique") ) * ("MPgraphic")
                             + P("MP") * ( P("code")+ P("page") + P("inclusions") + P("extensions") + P("graphic") )

local startmetafun           = P("\\start") * metafunenvironment
local stopmetafun            = P("\\stop")  * metafunenvironment

local openargument           = token("special", P("{"))
local closeargument          = token("special", P("}"))
local argumentcontent        = token("default",(1-P("}"))^0)

local metafunarguments       = (spacing^0 * openargument * argumentcontent * closeargument)^-2

local startmetafuncode       = token("embedded", startmetafun) * metafunarguments
local stopmetafuncode        = token("embedded", stopmetafun)

lexer.embed_lexer(contextlexer, cldlexer, startluacode,     stopluacode)
lexer.embed_lexer(contextlexer, mpslexer, startmetafuncode, stopmetafuncode)

-- Watch the text grabber, after all, we're talking mostly of text (beware,
-- no punctuation here as it can be special. We might go for utf here.

_rules = {
    { "whitespace",  spacing     },
    { "preamble",    preamble    },
    { "word",        word        },
 -- { "text",        text        },
    { "comment",     comment     },
    { "constant",    constant    },
    { "helper",      helper      },
    { "command",     command     },
    { "primitive",   primitive   },
    { "ifprimitive", ifprimitive },
    { "csname",      csname      },
 -- { "whatever",    specialword }, -- not yet, crashes
    { "grouping",    grouping    },
    { "special",     special     },
    { "extra",       extra       },
    { "rest",        rest        },
}

_tokenstyles = lexer.context.styleset

local folds = {
    ["\\start"] = 1, ["\\stop" ] = -1,
    ["\\begin"] = 1, ["\\end"  ] = -1,
}

_foldsymbols = {
    _patterns    = {
        "\\start", "\\stop", -- regular environments
        "\\begin", "\\end",  -- (moveable) blocks
    },
    ["helper"]   = folds,
    ["command"]  = folds,
    ["user"]     = folds,
    ["grouping"] = folds,
}
