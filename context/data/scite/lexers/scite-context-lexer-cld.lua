local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cld",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token

module(...)

local cldlexer = _M
local lualexer = lexer.load('scite-context-lexer-lua')

_rules       = lualexer._rules_cld
_tokenstyles = lualexer._tokenstyles
_foldsymbols = lualexer._foldsymbols
_directives  = lualexer._directives

-- _rules[1] = { "whitespace", token(cldlexer.WHITESPACE, lexer.space^1) }
