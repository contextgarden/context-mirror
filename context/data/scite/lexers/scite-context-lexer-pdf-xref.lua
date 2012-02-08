local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf xref",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token
local P = lpeg.P

local pdfxreflexer   = { _NAME = "pdfxref" }
local pdfobjectlexer = lexer.load("scite-context-lexer-pdf-object")

local context        = lexer.context
local patterns       = context.patterns

local whitespace     = lexer.WHITESPACE -- triggers states

local spacing        = patterns.spacing

local t_spacing      = token(whitespace, spacing)

local p_trailer      = P("trailer")

local t_xref         = token("default", (1-p_trailer)^1)
                     * token("keyword", p_trailer)
                     * t_spacing
                     * pdfobjectlexer._shared.dictionary

pdfxreflexer._rules = {
    { 'whitespace', t_spacing },
    { 'xref',       t_xref    },
}

pdfxreflexer._tokenstyles = context.styleset

return pdfxreflexer
