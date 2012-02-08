local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cld",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token

local cldlexer = { _NAME = "cld" }
local lualexer = lexer.load('scite-context-lexer-lua')

cldlexer._rules       = lualexer._rules_cld
cldlexer._tokenstyles = lualexer._tokenstyles
cldlexer._foldsymbols = lualexer._foldsymbols
cldlexer._directives  = lualexer._directives

return cldlexer
