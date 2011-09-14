local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cld/lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Adapted from lua.lua by Mitchell who based it on a lexer by Peter Odding.

local lexer = lexer
local token, style, colors, word_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.word_match, lexer.style_nothing
local P, R, S, C, Cg, Cb, Cs, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cs, lpeg.Cmt
local match, find = string.match, string.find
local global = _G

module(...)

local keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
  'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true',
  'until', 'while',
}

local functions = {
  'assert', 'collectgarbage', 'dofile', 'error', 'getfenv', 'getmetatable',
  'ipairs', 'load', 'loadfile', 'loadstring', 'module', 'next', 'pairs',
  'pcall', 'print', 'rawequal', 'rawget', 'rawset', 'require', 'setfenv',
  'setmetatable', 'tonumber', 'tostring', 'type', 'unpack', 'xpcall',
}

local constants = {
  '_G', '_VERSION',
}

local csnames = {
    "context",
    "metafun",
}

local level         = nil
local setlevel      = function(_,i,s) level = s return i end

local equals        = P("=")^0

local longonestart  = P("[[")
local longonestop   = P("]]")
local longonestring = (1-longonestop)^0

local longtwostart  = P('[') * Cmt(equals,setlevel) * P('[')
local longtwostop   = P(']') *     equals           * P(']')

local longtwostring = P(function(input,index)
    if level then
        local sentinel = ']' .. level .. ']'
        local _, stop = find(input,sentinel,index,true)
        return stop and stop + 1 - #sentinel or #input + 1
    end
end)

-- local longtwostart  = P("[") * Cg(equals, "init") * P("[")
-- local longtwostop   = P("]") * C(equals) * P("]")
-- local longtwocheck  = Cmt(longtwostop * Cb("init"), function(s,i,a,b) return a == b end)
-- local longtwostring = (P(1) - longtwocheck)^0

local longcomment = Cmt(#('[[' + ('[' * P('=')^0 * '[')), function(input,index)
    local level = match(input,'^%[(=*)%[',index)
    level = "=="
    if level then
        local _, stop = find(input,']' .. level .. ']',index,true)
        return stop and stop + 1 or #input + 1
    end
end)

local longcomment =  Cmt(#('[[' + ('[' * C(P('=')^0) * '[')), function(input,index,level)
    local _, stop = find(input,']' .. level .. ']',index,true)
    return stop and stop + 1 or #input + 1
end)

local whitespace    = token(lexer.WHITESPACE, lexer.space^1)
local any_char      = lexer.any_char

local squote        = P("'")
local dquote        = P('"')
local escaped       = P("\\") * P(1)
local dashes        = P('--')

local shortcomment  = dashes * lexer.nonnewline^0
local longcomment   = dashes * longcomment
local comment       = token(lexer.COMMENT, longcomment + shortcomment)

local shortstring   = token("quote",      squote)
                    * token(lexer.STRING, (escaped + (1-squote))^0 )
                    * token("quote",      squote)
                    + token("quote",      dquote)
                    * token(lexer.STRING, (escaped + (1-dquote))^0 )
                    * token("quote",      dquote)

local longstring    = token("quote",      longonestart)
                    * token(lexer.STRING, longonestring)
                    * token("quote",      longonestop)
                    + token("quote",      longtwostart)
                    * token(lexer.STRING, longtwostring)
                    * token("quote",      longtwostop)

local string        = shortstring
                    + longstring

local integer       = P('-')^-1 * (lexer.hex_num + lexer.dec_num)
local number        = token(lexer.NUMBER, lexer.float + integer)

local word          = R('AZ','az','__','\127\255') * (lexer.alnum + '_')^0
local identifier    = token(lexer.IDENTIFIER, word)

local operator      = token(lexer.OPERATOR, P('~=') + S('+-*/%^#=<>;:,.{}[]()')) -- maybe split of {}[]()

local keyword       = token(lexer.KEYWORD,  word_match(keywords))
local builtin       = token(lexer.FUNCTION, word_match(functions))
local constant      = token(lexer.CONSTANT, word_match(constants))
local csname        = token("user",       word_match(csnames)) * (
                        whitespace^0 * #S("{(")
                        + ( whitespace^0 * token(lexer.OPERATOR, P(".")) * whitespace^0 * token("csname",word) )^1
                    )

_rules = {
    { 'whitespace', whitespace },
    { 'keyword',    keyword    },
    { 'function',   builtin    },
    { 'csname',     csname     },
    { 'constant',   constant   },
    { 'identifier', identifier },
    { 'string',     string     },
    { 'comment',    comment    },
    { 'number',     number     },
    { 'operator',   operator   },
    { 'any_char',   any_char   },
}

_tokenstyles = {
    { "comment",  lexer.style_context_comment  },
    { "quote",    lexer.style_context_quote    },
    { "keyword",  lexer.style_context_keyword  },
    { "user",     lexer.style_context_user     },
    { "specials", lexer.style_context_specials },
    { "extras",   lexer.style_context_extras   },
}

_foldsymbols = {
    _patterns = {
        '%l+',
        '[%({%)}%[%]]',
    },
    [lexer.KEYWORD] = {
        ['if']       =  1,
        ['end']      = -1,
        ['do']       =  1,
        ['function'] =  1,
        ['repeat']   =  1,
        ['until']    = -1,
      },
    [lexer.COMMENT] = {
        ['['] = 1, [']'] = -1,
    },
    ["quote"] = { -- to be tested
        ['['] = 1, [']'] = -1,
    },
    [lexer.OPERATOR] = {
        ['('] = 1, [')'] = -1,
        ['{'] = 1, ['}'] = -1,
    },
}
