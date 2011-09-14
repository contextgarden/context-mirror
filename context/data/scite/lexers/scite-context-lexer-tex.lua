local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for context",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}


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

  -- the embedded lexers don't backtrack (so they're not that usefull on large
  -- texts) which is probably a scintilla issue (trade off between speed and lexable
  -- area); also there is some weird bleeding back to the parent lexer with respect
  -- to colors (i.e. the \ in \relax can become black) so I might as well use private
  -- color specifications

  -- this lexer does not care about other macro packages (one can of course add a fake
  -- interface but it's not on the agenda)

]]--

local lexer = lexer
local global, string, table, lpeg = _G, string, table, lpeg
local token, style, colors, word_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.word_match, lexer.style_nothing
local exact_match = lexer.context.exact_match
local P, R, S, V, C, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt
local type, next, pcall, loadfile, setmetatable = type, next, pcall, loadfile, setmetatable

module(...)

local contextlexer = _M
local basepath     = lexer.context and lexer.context.path or _LEXERHOME

local commands   = { en = { } }
local primitives = { }
local helpers    = { }

do

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
        helpers = definitions.helpers or { }
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

local knowncommand = Cmt(R("az","AZ")^1, function(_,i,s)
    return currentcommands[s] and i
end)

local find, match = string.find, string.match

local knownpreamble = Cmt(P('% '), function(input,i,_)
    if i < 10 then
        local s, e, word = find(input,'^(.+)[\n\r]',i)
        if word then
            local interface = match(word,"interface=(..)")
            if interface then
                currentcommands = commands[interface] or commands.en or { }
            end
        end
    end
    return false
end)

local whitespace             = lexer.WHITESPACE -- triggers states
local any_char               = lexer.any_char

local space                  = lexer.space -- S(" \n\r\t\f\v")
local cstoken                = R("az","AZ") + S("@!?_") -- todo: utf8

local spacing                = token(whitespace,  space^1)
local preamble               = token('preamble',  knownpreamble)
local comment                = token('comment',   P('%') * (1-S("\n\r"))^0)
local command                = token('command',   P('\\') * knowncommand)
local helper                 = token('plain',     P('\\') * exact_match(helpers))
local primitive              = token('primitive', P('\\') * exact_match(primitives))
local ifprimitive            = token('primitive', P('\\if') * cstoken^1)
local csname                 = token('user',      P('\\') * (cstoken^1 + P(1)))
local grouping               = token('grouping',  S("{$}"))
local specials               = token('specials',  S("#()[]<>=\""))
local extras                 = token('extras',    S("`~%^&_-+/\'|"))
local default                = token('default',   P(1))

----- startluacode           = token("grouping", P("\\startluacode"))
----- stopluacode            = token("grouping", P("\\stopluacode"))

local luastatus              = nil
local luaenvironment         = P("luacode")

local inlinelua              = P("\\ctxlua")
                             + P("\\ctxcommand")
                             + P("\\cldcontext")

local startlua               = P("\\start") * Cmt(luaenvironment,function(_,i,s) luastatus = s return true end)
                             + inlinelua
                             * space^0
                             * Cmt(P("{"),function(_,i,s) luastatus = "}" return true end)
local stoplua                = P("\\stop") * Cmt(luaenvironment,function(_,i,s) return luastatus == s end)
                             + Cmt(P("}"),function(_,i,s) return luastatus == "}" end)

local startluacode           = token("embedded", startlua)
local stopluacode            = token("embedded", stoplua)

local metafunenvironment     = P("MPcode")
                             + P("useMPgraphic")
                             + P("reusableMPgraphic")
                             + P("uniqueMPgraphic")
                             + P("MPinclusions")
                             + P("MPextensions")
                             + P("MPgraphic")

-- local metafunstatus          = nil -- this does not work, as the status gets lost in an embedded lexer
-- local startmetafun           = P("\\start") * Cmt(metafunenvironment,function(_,i,s) metafunstatus = s return true end)
-- local stopmetafun            = P("\\stop")  * Cmt(metafunenvironment,function(_,i,s) return metafunstatus == s end)

local startmetafun           = P("\\start") * metafunenvironment
local stopmetafun            = P("\\stop")  * metafunenvironment

local openargument           = token("specials",P("{"))
local closeargument          = token("specials",P("}"))
local argumentcontent        = token("any_char",(1-P("}"))^0)

local metafunarguments       = (token("default",spacing^0) * openargument * argumentcontent * closeargument)^-2

local startmetafuncode       = token("embedded", startmetafun) * metafunarguments
local stopmetafuncode        = token("embedded", stopmetafun)

-- Function load(lexer_name) starts with _M.WHITESPACE = lexer_name..'_whitespace' which means that we need to
-- have frozen at the moment we load another lexer. Because spacing is used to revert to a parent lexer we need
-- to make sure that we load children as late as possible in order not to get the wrong whitespace trigger. This
-- took me quite a while to figure out (not being that familiar with the internals). BTW, if performance becomes
-- an issue we can rewrite the main lex function (memorize the grammars and speed up the byline variant).

local cldlexer = lexer.load('scite-context-lexer-cld')
local mpslexer = lexer.load('scite-context-lexer-mps')

lexer.embed_lexer(contextlexer, cldlexer, startluacode,     stopluacode)
lexer.embed_lexer(contextlexer, mpslexer, startmetafuncode, stopmetafuncode)

_rules = {
    { "whitespace",  spacing     },
    { "preamble",    preamble    },
    { "comment",     comment     },
    { "helper",      helper      },
    { "command",     command     },
    { "ifprimitive", ifprimitive },
    { "primitive",   primitive   },
    { "csname",      csname      },
    { "grouping",    grouping    },
    { "specials",    specials    },
    { "extras",      extras      },
    { 'any_char',    any_char    },
}

_tokenstyles = {
    { "preamble",  lexer.style_context_preamble  },
    { "comment",   lexer.style_context_comment   },
    { "default",   lexer.style_context_default   },
    { 'number',    lexer.style_context_number    },
    { "embedded",  lexer.style_context_embedded  },
    { "grouping",  lexer.style_context_grouping  },
    { "primitive", lexer.style_context_primitive },
    { "plain",     lexer.style_context_plain     },
    { "command",   lexer.style_context_command   },
    { "user",      lexer.style_context_user      },
    { "specials",  lexer.style_context_specials  },
    { "extras",    lexer.style_context_extras    },
    { "quote",    lexer.style_context_quote    },
    { "keyword",  lexer.style_context_keyword  },
}

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
    ["grouping"] = folds,
}
