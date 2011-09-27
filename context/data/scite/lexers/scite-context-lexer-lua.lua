local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer = lexer
local token, style, colors, exact_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.exact_match, lexer.style_nothing
local P, R, S, C, Cg, Cb, Cs, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cs, lpeg.Cmt
local match, find = string.match, string.find
local global = _G

-- beware: all multiline is messy, so even if it's no lexer, it should be an embedded lexer

module(...)

local cldlexer = _M

_directives = { } -- communication channel

-- this will be eextended

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
  '_G', '_VERSION', '_M',
}

local csnames = { -- todo: option
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

local whitespace    = cldlexer.WHITESPACE -- triggers states

local space         = lexer.space -- S(" \n\r\t\f\v")
local any           = lexer.any

local squote        = P("'")
local dquote        = P('"')
local escaped       = P("\\") * P(1)
local dashes        = P('--')

local spacing       = token(whitespace, space^1)
local rest          = token("default",  any)

local shortcomment  = token("comment", dashes * lexer.nonnewline^0)
local longcomment   = token("comment", dashes * longcomment)

local shortstring   = token("quote",  dquote)
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)

local longstring    = token("quote",  longonestart)
                    * token("string", longonestring)
                    * token("quote",  longonestop)
                    + token("quote",  longtwostart)
                    * token("string", longtwostring)
                    * token("quote",  longtwostop)

local string        = shortstring
                    + longstring

local integer       = P('-')^-1 * (lexer.hex_num + lexer.dec_num)
local number        = token("number", lexer.float + integer)

-- officially 127-255 are ok but not utf so useless

local validword     = R("AZ","az","__") * R("AZ","az","__","09")^0

local identifier    = token("default",validword)

local operator      = token("special", P('..') + P('~=') + S('+-*/%^#=<>;:,.{}[]()')) -- maybe split off {}[]()

local optionalspace = spacing^0
local hasargument   = #S("{(")

local keyword       = token("keyword", exact_match(keywords ))
local builtin       = token("plain",   exact_match(functions))
local constant      = token("data",    exact_match(constants))
local csname        = token("user",    exact_match(csnames  ))
                    * (
                        optionalspace * hasargument
                      + ( optionalspace * token("special", P(".")) * optionalspace * token("user", validword) )^1
                    )

_rules = {
    { 'whitespace',   spacing      },
    { 'keyword',      keyword      },
    { 'function',     builtin      },
    { 'csname',       csname       },
    { 'constant',     constant     },
    { 'identifier',   identifier   },
    { 'string',       string       },
    { 'longcomment',  longcomment  },
    { 'shortcomment', shortcomment },
    { 'number',       number       },
    { 'operator',     operator     },
    { 'rest',         rest         },
}

_tokenstyles = lexer.context.styleset

_foldsymbols = {
    _patterns = {
        '%l+',
        '[%({%)}%[%]]',
    },
    ['keyword'] = {
        ['if']       =  1,
        ['end']      = -1,
        ['do']       =  1,
        ['function'] =  1,
        ['repeat']   =  1,
        ['until']    = -1,
      },
    ['comment'] = {
        ['['] = 1, [']'] = -1,
    },
    ['quote'] = { -- to be tested
        ['['] = 1, [']'] = -1,
    },
    ['special'] = {
        ['('] = 1, [')'] = -1,
        ['{'] = 1, ['}'] = -1,
    },
}

-- embedded in tex:

local cstoken         = R("az","AZ","\127\255") + S("@!?_")
local csnametex       = P("\\") * cstoken^1
local commentline     = P('%') * (1-S("\n\r"))^0

local texcomment      = token('comment', Cmt(commentline, function() return _directives.cld_inline end))

local longthreestart  = P("\\!!bs")
local longthreestop   = P("\\!!es")
local longthreestring = (1-longthreestop)^0

local texstring       = token("quote",  longthreestart)
                      * token("string", longthreestring)
                      * token("quote",  longthreestop)

-- local texcommand   = token("user", csnametex)
--
-- local texstring    = token("quote", longthreestart)
--                    * (texcommand + token("string",P(1-texcommand-longthreestop)^1) - longthreestop)^0 -- we match long non-\cs sequences
--                    * token("quote", longthreestop)

_rules_cld = {
    { 'whitespace',   spacing      },
    { 'texstring',    texstring    },
    { 'texcomment',   texcomment   },
    { 'keyword',      keyword      },
    { 'function',     builtin      },
    { 'csname',       csname       },
    { 'constant',     constant     },
    { 'identifier',   identifier   },
    { 'string',       string       },
    { 'longcomment',  longcomment  },
    { 'shortcomment', shortcomment }, -- should not be used inline so best signal it as comment (otherwise complex state till end of inline)
    { 'number',       number       },
    { 'operator',     operator     },
    { 'rest',         rest         },
}
