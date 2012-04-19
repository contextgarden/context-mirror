local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not lexer._CONTEXTEXTENSIONS then require("scite-context-lexer") end

local lexer = lexer
local global, string, table, lpeg = _G, string, table, lpeg
local token, exact_match = lexer.token, lexer.exact_match
local P, R, S, V, C, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt
local type = type

local metafunlexer       = { _NAME = "mps", _FILENAME = "scite-context-lexer-mps" }
local whitespace         = lexer.WHITESPACE
local context            = lexer.context

local metapostprimitives = { }
local metapostinternals  = { }
local metapostshortcuts  = { }
local metapostcommands   = { }

local metafuninternals   = { }
local metafunshortcuts   = { }
local metafuncommands    = { }

local mergedshortcuts    = { }
local mergedinternals    = { }

do

    local definitions = context.loaddefinitions("scite-context-data-metapost")

    if definitions then
        metapostprimitives = definitions.primitives or { }
        metapostinternals  = definitions.internals  or { }
        metapostshortcuts  = definitions.shortcuts  or { }
        metapostcommands   = definitions.commands   or { }
    end

    local definitions = context.loaddefinitions("scite-context-data-metafun")

    if definitions then
        metafuninternals  = definitions.internals or { }
        metafunshortcuts  = definitions.shortcuts or { }
        metafuncommands   = definitions.commands  or { }
    end

    for i=1,#metapostshortcuts do
        mergedshortcuts[#mergedshortcuts+1] = metapostshortcuts[i]
    end
    for i=1,#metafunshortcuts do
        mergedshortcuts[#mergedshortcuts+1] = metafunshortcuts[i]
    end

    for i=1,#metapostinternals do
        mergedinternals[#mergedinternals+1] = metapostinternals[i]
    end
    for i=1,#metafuninternals do
        mergedinternals[#mergedinternals+1] = metafuninternals[i]
    end

end

local space      = lexer.space -- S(" \n\r\t\f\v")
local any        = lexer.any

local dquote     = P('"')
local cstoken    = R("az","AZ") + P("_")
local number     = context.patterns.real

local cstokentex = R("az","AZ","\127\255") + S("@!?_")

-- we could collapse as in tex

local spacing    = token(whitespace,  space^1)
local rest       = token('default',   any)
local comment    = token('comment',   P('%') * (1-S("\n\r"))^0)
local internal   = token('reserved',  exact_match(mergedshortcuts,false))
local shortcut   = token('data',      exact_match(mergedinternals))
local helper     = token('command',   exact_match(metafuncommands))
local plain      = token('plain',     exact_match(metapostcommands))
local quoted     = token('quote',     dquote)
                 * token('string',    P(1-dquote)^0)
                 * token('quote',     dquote)
local texstuff   = token('quote',     P("btex ") + P("verbatimtex "))
                 * token('string',    P(1-P(" etex"))^0)
                 * token('quote',     P(" etex"))
local primitive  = token('primitive', exact_match(metapostprimitives))
local identifier = token('default',   cstoken^1)
local number     = token('number',    number)
local grouping   = token('grouping',  S("()[]{}")) -- can be an option
local special    = token('special',   S("#()[]{}<>=:\"")) -- or else := <> etc split
local texlike    = token('string',    P("\\") * cstokentex^1)
local extra      = token('extra',     S("`~%^&_-+*/\'|\\"))

metafunlexer._rules = {
    { 'whitespace', spacing    },
    { 'comment',    comment    },
    { 'internal',   internal   },
    { 'shortcut',   shortcut   },
    { 'helper',     helper     },
    { 'plain',      plain      },
    { 'primitive',  primitive  },
    { 'texstuff',   texstuff   },
    { 'identifier', identifier },
    { 'number',     number     },
    { 'quoted',     quoted     },
 -- { 'grouping',   grouping   }, -- can be an option
    { 'special',    special    },
 -- { 'texlike',    texlike    },
    { 'extra',      extra      },
    { 'rest',       rest       },
}

metafunlexer._tokenstyles = context.styleset

metafunlexer._foldsymbols = {
    _patterns = {
        "%l+",
    },
    ["primitive"] = {
        ["beginfig"]      =  1,
        ["endfig"]        = -1,
        ["def"]           =  1,
        ["vardef"]        =  1,
        ["primarydef"]    =  1,
        ["secondarydef" ] =  1,
        ["tertiarydef"]   =  1,
        ["enddef"]        = -1,
        ["if"]            =  1,
        ["fi"]            = -1,
        ["for"]           =  1,
        ["forever"]       =  1,
        ["endfor"]        = -1,
    }
}

return metafunlexer
