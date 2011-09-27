local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local global, string, table, lpeg = _G, string, table, lpeg
local token, exact_match = lexer.token, lexer.exact_match
local P, R, S, V, C, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt
local type = type

module(...)

local metafunlexer      = _M

local context           = lexer.context

local metafunhelpers    = { }
local metafunconstants  = { }
local plaincommands     = { }
local primitivecommands = { }

do

    local definitions = context.loaddefinitions("scite-context-data-metapost")

    if definitions then
        plaincommands     = definitions.plain      or { }
        primitivecommands = definitions.primitives or { }
    end

    local definitions = context.loaddefinitions("scite-context-data-metafun")

    if definitions then
        metafunhelpers   = definitions.helpers   or { }
        metafunconstants = definitions.constants or { }
    end

end

local whitespace = metafunlexer.WHITESPACE -- triggers states

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
local constant   = token('data',      exact_match(metafunconstants))
local helper     = token('command',   exact_match(metafunhelpers))
local plain      = token('plain',     exact_match(plaincommands))
local quoted     = token('quote',     dquote)
                 * token('string',    P(1-dquote)^0)
                 * token('quote',     dquote)
local primitive  = token('primitive', exact_match(primitivecommands))
local identifier = token('default',   cstoken^1)
local number     = token('number',    number)
local special    = token('special',   S("#()[]<>=:\"")) -- or else := <> etc split
local texlike    = token('string',    P("\\") * cstokentex^1)
local extra      = token('extra',     S("`~%^&_-+/\'|\\"))

_rules = {
    { 'whitespace', spacing    },
    { 'comment',    comment    },
    { 'constant',   constant   },
    { 'helper',     helper     },
    { 'plain',      plain      },
    { 'primitive',  primitive  },
    { 'identifier', identifier },
    { 'number',     number     },
    { 'quoted',     quoted     },
    { 'special',    special    },
 -- { 'texlike',    texlike    },
    { 'extra',      extra      },
    { 'rest',       rest       },
}

_tokenstyles = context.styleset

_foldsymbols = {
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
