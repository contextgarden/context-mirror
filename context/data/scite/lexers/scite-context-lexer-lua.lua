local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not lexer._CONTEXTEXTENSIONS then dofile(_LEXERHOME .. "/scite-context-lexer.lua") end

local lexer = lexer
local token, style, colors, exact_match, no_style = lexer.token, lexer.style, lexer.colors, lexer.exact_match, lexer.style_nothing
local P, R, S, C, Cg, Cb, Cs, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cs, lpeg.Cmt
local match, find = string.match, string.find
local setmetatable = setmetatable

-- beware: all multiline is messy, so even if it's no lexer, it should be an embedded lexer

local lualexer    = { _NAME = "lua" }
local stringlexer = lexer.load("scite-context-lexer-lua-longstring")

local whitespace  = lexer.WHITESPACE

local directives = { } -- communication channel

-- this will be extended

local keywords = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', -- 'goto',
    'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true',
    'until', 'while',
}

local functions = {
    'assert', 'collectgarbage', 'dofile', 'error', 'getfenv', 'getmetatable',
    'ipairs', 'load', 'loadfile', 'loadstring', 'module', 'next', 'pairs',
    'pcall', 'print', 'rawequal', 'rawget', 'rawset', 'require', 'setfenv',
    'setmetatable', 'tonumber', 'tostring', 'type', 'unpack', 'xpcall', "select",
}

local constants = {
    '_G', '_VERSION', '_M', "...",
}

local depricated = {
    "arg", "arg.n",
}

local csnames = { -- todo: option
    "context",
    "metafun",
    "metapost",
}

local level         = nil
local setlevel      = function(_,i,s) level = s return i end

local equals        = P("=")^0

local longonestart  = P("[[")
local longonestop   = P("]]")
local longonestring = (1-longonestop)^0

local longtwostart  = P('[') * Cmt(equals,setlevel) * P('[')
local longtwostop   = P(']') *     equals           * P(']')

local sentinels = { } setmetatable(sentinels, { __index = function(t,k) local v = "]" .. k .. "]" t[k] = v return v end })

local longtwostring = P(function(input,index)
    if level then
     -- local sentinel = ']' .. level .. ']'
        local sentinel = sentinels[level]
        local _, stop = find(input,sentinel,index,true)
        return stop and stop + 1 - #sentinel or #input + 1
    end
end)

    local longtwostring_body = longtwostring

    local longtwostring_end = P(function(input,index)
        if level then
         -- local sentinel = ']' .. level .. ']'
            local sentinel = sentinels[level]
            local _, stop = find(input,sentinel,index,true)
            return stop and stop + 1 or #input + 1
        end
    end)

local longcomment = Cmt(#('[[' + ('[' * C(equals) * '[')), function(input,index,level)
 -- local sentinel = ']' .. level .. ']'
    local sentinel = sentinels[level]
    local _, stop = find(input,sentinel,index,true)
    return stop and stop + 1 or #input + 1
end)

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

-- fails on very long string with \ at end of lines (needs embedded lexer)
-- and also on newline before " but it makes no sense to waste time on it

local shortstring   = token("quote",  dquote)
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)

----- longstring    = token("quote",  longonestart)
-----               * token("string", longonestring)
-----               * token("quote",  longonestop)
-----               + token("quote",  longtwostart)
-----               * token("string", longtwostring)
-----               * token("quote",  longtwostop)

local string        = shortstring
-----               + longstring

lexer.embed_lexer(lualexer, stringlexer, token("quote",longtwostart), token("string",longtwostring_body) * token("quote",longtwostring_end))

local integer       = P('-')^-1 * (lexer.hex_num + lexer.dec_num)
local number        = token("number", lexer.float + integer)

-- officially 127-255 are ok but not utf so useless

local validword     = R("AZ","az","__") * R("AZ","az","__","09")^0

local identifier    = token("default",validword)

local operator      = token("special", P('..') + P('~=') + S('+-*/%^#=<>;:,.{}[]()')) -- maybe split off {}[]()

local optionalspace = spacing^0
local hasargument   = #S("{(")

local gotokeyword   = token("keyword", P("goto"))
                    * spacing
                    * token("grouping",validword)
local gotolabel     = token("keyword", P("::"))
                    * token("grouping",validword)
                    * token("keyword", P("::"))

local keyword       = token("keyword", exact_match(keywords ))
local builtin       = token("plain",   exact_match(functions))
local constant      = token("data",    exact_match(constants))
local csname        = token("user",    exact_match(csnames  ))
                    * (
                        optionalspace * hasargument
                      + ( optionalspace * token("special", P(".")) * optionalspace * token("user", validword) )^1
                    )

lualexer._rules = {
    { 'whitespace',   spacing      },
    { 'keyword',      keyword      },
    { 'function',     builtin      },
    { 'csname',       csname       },
    { 'constant',     constant     },
    { 'goto',         gotokeyword  },
    { 'identifier',   identifier   },
    { 'string',       string       },
    { 'number',       number       },
    { 'longcomment',  longcomment  },
    { 'shortcomment', shortcomment },
--  { 'number',       number       },
    { 'label',        gotolabel    },
    { 'operator',     operator     },
    { 'rest',         rest         },
}

lualexer._tokenstyles = lexer.context.styleset

lualexer._foldsymbols = {
    _patterns = {
        '%l+',
     -- '[%({%)}%[%]]',
        '[{}%[%]]',
    },
    ['keyword'] = { -- challenge:  if=0  then=1  else=-1  elseif=-1
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
     -- ['('] = 1, [')'] = -1,
        ['{'] = 1, ['}'] = -1,
    },
}

-- embedded in tex:

local cstoken         = R("az","AZ","\127\255") + S("@!?_")
local texcsname       = P("\\") * cstoken^1
local commentline     = P('%') * (1-S("\n\r"))^0

local texcomment      = token('comment', Cmt(commentline, function() return directives.cld_inline end))

local longthreestart  = P("\\!!bs")
local longthreestop   = P("\\!!es")
local longthreestring = (1-longthreestop)^0

local texstring       = token("quote",  longthreestart)
                      * token("string", longthreestring)
                      * token("quote",  longthreestop)

-- local texcommand      = token("user", texcsname)
local texcommand      = token("warning", texcsname)

-- local texstring    = token("quote", longthreestart)
--                    * (texcommand + token("string",P(1-texcommand-longthreestop)^1) - longthreestop)^0 -- we match long non-\cs sequences
--                    * token("quote", longthreestop)

-- local whitespace    = "whitespace"
-- local spacing       = token(whitespace, space^1)

lualexer._directives = directives

lualexer._rules_cld = {
    { 'whitespace',   spacing      },
    { 'texstring',    texstring    },
    { 'texcomment',   texcomment   },
    { 'texcommand',   texcommand   },
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

return lualexer
