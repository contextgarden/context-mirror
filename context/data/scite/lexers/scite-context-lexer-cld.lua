local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cld/lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer

module(...)

local cldlexer = lexer.load('scite-context-lexer-lua')

_rules       = cldlexer._rules_cld
_tokenstyles = cldlexer._tokenstyles
_foldsymbols = cldlexer._foldsymbols

_directives  = cldlexer._directives
