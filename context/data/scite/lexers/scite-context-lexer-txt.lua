local lexer = lexer
local token = lexer.token
local P, S, Cmt = lpeg.P, lpeg.S, lpeg.Cmt
local find, match = string.find, string.match

module(...)

local textlexer   = _M

local context     = lexer.context

local whitespace  = textlexer.WHITESPACE -- triggers states

local space       = lexer.space
local any         = lexer.any

local wordtoken   = context.patterns.wordtoken
local wordpattern = context.patterns.wordpattern
local checkedword = context.checkedword
local setwordlist = context.setwordlist
local validwords  = false

-- [#!-%] language=uk

local p_preamble = Cmt(#(S("#!-%") * P(" ")), function(input,i,_) -- todo: utf bomb
    if i == 1 then -- < 10 then
        validwords = false
        local s, e, line = find(input,'^[#!%-%%](.+)[\n\r]',i)
        if line then
            local language = match(line,"language=([a-z]+)")
            if language then
                validwords = setwordlist(language)
            end
        end
    end
    return false
end)

local t_preamble =
    token('preamble', p_preamble)

local t_word =
    Cmt(wordpattern, function(_,i,s)
        if validwords then
            return checkedword(validwords,s,i)
        else
            return true, { "text", i }
        end
    end)

local t_text =
    token("default", wordtoken^1)

local t_rest =
    token("default", (1-wordtoken-space)^1)

local t_spacing =
    token(whitespace, space^1)

_rules = {
    { "whitespace", t_spacing  },
    { "preamble",   t_preamble },
    { "word",       t_word     }, -- words >= 3
    { "text",       t_text     }, -- non words
    { "rest",       t_rest     },
}

_tokenstyles = lexer.context.styleset

