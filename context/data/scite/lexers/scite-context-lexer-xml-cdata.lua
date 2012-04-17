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

local xmlcdatalexer = { _NAME = "xml-cdata" }
local whitespace    = lexer.WHITESPACE -- triggers states
local context       = lexer.context

local space         = lexer.space
local nospace       = 1 - space - P("]]>")

local p_spaces      = token(whitespace, space  ^1)
local p_cdata       = token("comment",  nospace^1)

xmlcdatalexer._rules = {
    { "whitespace", p_spaces },
    { "cdata",      p_cdata  },
}

xmlcdatalexer._tokenstyles = context.styleset

return xmlcdatalexer
