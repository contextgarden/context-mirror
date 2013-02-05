local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token
local P = lpeg.P

local stringlexer = { _NAME = "lua-longstring", _FILENAME = "scite-context-lexer-lua-longstring" }
local whitespace  = lexer.WHITESPACE
local context     = lexer.context

local space       = lexer.space
local nospace     = 1 - space

local p_spaces    = token(whitespace, space  ^1)
local p_string    = token("string",   nospace^1)

stringlexer._rules = {
    { "whitespace", p_spaces },
    { "string",     p_string },
}

stringlexer._tokenstyles = lexer.context.styleset

return stringlexer
