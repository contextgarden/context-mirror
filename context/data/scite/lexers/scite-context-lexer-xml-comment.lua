local lexer = lexer
local token = lexer.token
local P = lpeg.P

module(...)

local commentlexer = _M

local whitespace = commentlexer.WHITESPACE -- triggers states

local space      = lexer.space
local nospace    = 1 - space - P("-->")

local p_spaces   = token(whitespace, space  ^1)
local p_comment  = token("comment",  nospace^1)

_rules = {
    { "whitespace", p_spaces  },
    { "comment",    p_comment },
}

_tokenstyles = lexer.context.styleset

_foldsymbols = {
    _patterns = {
        "<%!%-%-", "%-%->", -- comments
    },
    ["comment"] = {
        ["<!--"] = 1, ["-->" ] = -1,
    }
}
