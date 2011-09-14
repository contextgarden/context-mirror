local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local global, string, table, lpeg = _G, string, table, lpeg
local token, style, colors, word_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.word_match, lexer.style_nothing
local exact_match = lexer.context.exact_match
local P, R, S, V, C, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt
local type, next, pcall, loadfile = type, next, pcall, loadfile

module(...)

local metafunlexer = _M
local basepath     = lexer.context and lexer.context.path or _LEXERHOME

local metafuncommands   = { }
local plaincommands     = { }
local primitivecommands = { }

do

    local definitions = lexer.context.loaddefinitions("mult-mps.lua")

    if definitions then
        metafuncommands   = definitions.metafun    or { }
        plaincommands     = definitions.plain      or { }
        primitivecommands = definitions.primitives or { }
    end

end

local whitespace = lexer.WHITESPACE -- triggers states
local any_char   = lexer.any_char

local space      = lexer.space -- S(" \n\r\t\f\v")
local digit      = R("09")
local sign       = S("+-")
local period     = P(".")
local cstoken    = R("az","AZ") + P("_")
local number     = sign^-1 * (                     -- at most one
                        digit^1 * period * digit^0 -- 10.0 10.
                      + digit^0 * period * digit^1 -- 0.10 .10
                      + digit^1                    -- 10
                   )

local spacing    = token(whitespace,   space^1)
local comment    = token('comment',    P('%') * (1-S("\n\r"))^0)
local metafun    = token('command',    exact_match(metafuncommands))
local plain      = token('plain',      exact_match(plaincommands))
local quoted     = token('specials',   P('"'))
                 * token('default',    P(1-P('"'))^1)
                 * token('specials',   P('"'))
local primitive  = token('primitive',  exact_match(primitivecommands))
local csname     = token('user',       cstoken^1)
local specials   = token('specials',   S("#()[]<>=:\""))
local number     = token('number',     number)
local extras     = token('extras',     S("`~%^&_-+/\'|\\"))
local default    = token('default',    P(1))

_rules = {
    { 'whitespace', spacing    },
    { 'comment',    comment    },
    { 'metafun',    metafun    },
    { 'plain',      plain      },
    { 'primitive',  primitive  },
    { 'csname',     csname     },
    { 'number',     number     },
    { 'quoted',     quoted     },
    { 'specials',   specials   },
    { 'extras',     extras     },
    { 'any_char',   any_char   },
}

_tokenstyles = {
    { "comment",   lexer.style_context_comment   },
    { "default",   lexer.style_context_default   },
    { "number" ,   lexer.style_context_number    },
    { "primitive", lexer.style_context_primitive },
    { "plain",     lexer.style_context_plain     },
    { "command",   lexer.style_context_command   },
    { "user",      lexer.style_context_user      },
    { "specials",  lexer.style_context_specials  },
    { "extras",    lexer.style_context_extras    },
}
