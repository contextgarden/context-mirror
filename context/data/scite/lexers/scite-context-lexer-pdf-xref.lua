local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token
local P = lpeg.P
local global = _G

module(...)

local pdflexer          = _M
local objectlexer       = lexer.load("scite-context-lexer-pdf-object")

local context           = lexer.context
local patterns          = context.patterns

local whitespace        = pdflexer.WHITESPACE -- triggers states

local space             = patterns.space
local spacing           = patterns.spacing

local t_spacing         = token(whitespace, spacing)

local p_trailer         = P("trailer")

local t_xref            = token("default", (1-p_trailer)^1)
                        * token("keyword", p_trailer)
                        * t_spacing
                        * objectlexer._shared.dictionary

_rules = {
    { 'whitespace', t_spacing },
    { 'xref',       t_xref    },
}

_tokenstyles = context.styleset
