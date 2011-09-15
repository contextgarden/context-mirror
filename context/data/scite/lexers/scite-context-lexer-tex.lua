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
local find, match = string.find, string.match

module(...)

local contextlexer = _M

local basepath     = lexer.context and lexer.context.path or _LEXERHOME

local commands   = { en = { } }
local primitives = { }
local helpers    = { }
local constants  = { }

do -- todo: only once, store in global

    local definitions = lexer.context.loaddefinitions("mult-def.lua")

    if definitions then
        for command, languages in next, definitions.commands do
            commands.en[languages.en or command] = true
            for language, command in next, languages do
                local c = commands[language]
                if c then
                    c[command] = true
                else
                    commands[language] = { [command] = true }
                end
            end
        end
    end

    local definitions = lexer.context.loaddefinitions("mult-low.lua")

    if definitions then
        helpers   = definitions.helpers   or { }
        constants = definitions.constants or { }
    end

    local definitions = lexer.context.loaddefinitions("mult-prm.lua")

    if definitions then
        primitives = definitions.primitives or { }
        for i=1,#primitives do
            primitives[#primitives+1] = "normal" .. primitives[i]
        end
        table.sort(primitives)
    end

end

local currentcommands = commands.en or { }

local cstoken = R("az","AZ","\127\255") + S("@!?_")

local knowncommand = Cmt(cstoken^1, function(_,i,s)
    return currentcommands[s] and i
end)

local knownpreamble = Cmt(P("% "), function(input,i,_)
    if i < 10 then
        local s, e, word = find(input,'^(.+)[\n\r]',i) -- combine with match
        if word then
            local interface = match(word,"interface=(..)")
            if interface then
                currentcommands  = commands[interface] or commands.en or { }
            end
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

local whitespace             = contextlexer.WHITESPACE -- triggers states

local space                  = lexer.space -- S(" \n\r\t\f\v")
local any                    = lexer.any

local spacing                = token(whitespace,  space^1)
local rest                   = token('default',   any)
local preamble               = token('preamble',  knownpreamble)
local comment                = token('comment',   P('%') * (1-S("\n\r"))^0)
local command                = token('command',   P('\\') * knowncommand)
local constant               = token('data',      P('\\') * exact_match(constants))
local helper                 = token('plain',     P('\\') * exact_match(helpers))
local primitive              = token('primitive', P('\\') * exact_match(primitives))
local ifprimitive            = token('primitive', P('\\if') * cstoken^1)
local csname                 = token('user',      P('\\') * (cstoken^1 + P(1)))
local grouping               = token('grouping',  S("{$}")) -- maybe also \bgroup \egroup \begingroup \endgroup
local special                = token('special',   S("#()[]<>=\""))
local extra                  = token('extra',     S("`~%^&_-+/\'|"))

local text                   = token('default',   cstoken^1 )

----- startluacode           = token("grouping", P("\\startluacode"))
----- stopluacode            = token("grouping", P("\\stopluacode"))

local luastatus              = nil
local luaenvironment         = P("luacode")

local inlinelua              = P("\\ctx") * ( P("lua") + P("command") )
                             + P("\\cldcontext")

local startlua               = P("\\start") * Cmt(luaenvironment,function(_,i,s) luastatus = s return true end)
                             + inlinelua
                             * space^0
                             * Cmt(P("{"),function(_,i,s) luastatus = "}" return true end)
local stoplua                = P("\\stop") * Cmt(luaenvironment,function(_,i,s) return luastatus == s end)
                             + Cmt(P("}"),function(_,i,s) return luastatus == "}" end)

local startluacode           = token("embedded", startlua)
local stopluacode            = token("embedded", stoplua)

-- local metafunenvironment     = P("useMPgraphic")
--                              + P("reusableMPgraphic")
--                              + P("uniqueMPgraphic")
--                              + P("MPcode")
--                              + P("MPpage")
--                              + P("MPinclusions")
--                              + P("MPextensions")
--                              + P("MPgraphic")

local metafunenvironment     = ( P("use") + P("reusable") + P("unique") ) * ("MPgraphic")
                             + P("MP") * ( P("code")+ P("page") + P("inclusions") + P("extensions") + P("graphic") )

-- local metafunstatus          = nil -- this does not work, as the status gets lost in an embedded lexer
-- local startmetafun           = P("\\start") * Cmt(metafunenvironment,function(_,i,s) metafunstatus = s return true end)
-- local stopmetafun            = P("\\stop")  * Cmt(metafunenvironment,function(_,i,s) return metafunstatus == s end)

local startmetafun           = P("\\start") * metafunenvironment
local stopmetafun            = P("\\stop")  * metafunenvironment

local openargument           = token("special", P("{"))
local closeargument          = token("special", P("}"))
local argumentcontent        = token("default",(1-P("}"))^0)

local metafunarguments       = (spacing^0 * openargument * argumentcontent * closeargument)^-2

local startmetafuncode       = token("embedded", startmetafun) * metafunarguments
local stopmetafuncode        = token("embedded", stopmetafun)

local cldlexer = lexer.load('scite-context-lexer-cld')
local mpslexer = lexer.load('scite-context-lexer-mps')

lexer.embed_lexer(contextlexer, cldlexer, startluacode,     stopluacode)
lexer.embed_lexer(contextlexer, mpslexer, startmetafuncode, stopmetafuncode)

-- Watch the text grabber, after all, we're talking mostly of text (beware,
-- no punctuation here as it can be special. We might go for utf here.

_rules = {
    { "whitespace",  spacing     },
    { "preamble",    preamble    },

    { "text",        text        },

    { "comment",     comment     },

    { "constant",    constant    },
    { "helper",      helper      },
    { "command",     command     },
    { "ifprimitive", ifprimitive },
    { "primitive",   primitive   },
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
