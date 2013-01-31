local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml cdata",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token
local P = lpeg.P

local xmlscriptlexer = { _NAME = "xml-script", _FILENAME = "scite-context-lexer-xml-script" }
local whitespace    = lexer.WHITESPACE -- triggers states
local context       = lexer.context

local space         = lexer.space
local nospace       = 1 - space - (P("</") * P("script") + P("SCRIPT")) * P(">")

local p_spaces      = token(whitespace, space  ^1)
local p_cdata       = token("default",  nospace^1)

xmlscriptlexer._rules = {
    { "whitespace", p_spaces },
    { "script",     p_cdata  },
}

xmlscriptlexer._tokenstyles = context.styleset

return xmlscriptlexer
