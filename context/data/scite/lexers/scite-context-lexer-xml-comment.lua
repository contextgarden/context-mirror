local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml comments",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token = lexer.token
local P = lpeg.P

local xmlcommentlexer = { _NAME = "xml-comment" }
local whitespace      = lexer.WHITESPACE
local context         = lexer.context

local space      = lexer.space
local nospace    = 1 - space - P("-->")

local p_spaces   = token(whitespace, space  ^1)
local p_comment  = token("comment",  nospace^1)

xmlcommentlexer._rules = {
    { "whitespace", p_spaces  },
    { "comment",    p_comment },
}

xmlcommentlexer._tokenstyles = context.styleset

xmlcommentlexer._foldsymbols = {
    _patterns = {
        "<%!%-%-", "%-%->", -- comments
    },
    ["comment"] = {
        ["<!--"] = 1, ["-->" ] = -1,
    }
}

return xmlcommentlexer
