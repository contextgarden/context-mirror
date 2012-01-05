local lexer = lexer
local token = lexer.token
local P = lpeg.P

module(...)

local stringlexer = _M

local whitespace = stringlexer.WHITESPACE -- triggers states

local space      = lexer.space
local nospace    = 1 - space

local p_spaces   = token(whitespace, space  ^1)
local p_string   = token("string",   nospace^1)

_rules = {
    { "whitespace", p_spaces },
    { "string",     p_string },
}

_tokenstyles = lexer.context.styleset
