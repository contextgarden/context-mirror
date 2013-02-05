local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for plain text (with spell checking)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not lexer._CONTEXTEXTENSIONS then require("scite-context-lexer") end

local lexer = lexer
local token = lexer.token
local P, S, Cmt, Cp, Ct = lpeg.P, lpeg.S, lpeg.Cmt, lpeg.Cp, lpeg.Ct
local find, match = string.find, string.match

local textlexer    = { _NAME = "txt", _FILENAME = "scite-context-lexer-txt" }
local whitespace   = lexer.WHITESPACE
local context      = lexer.context

local space        = lexer.space
local any          = lexer.any

local wordtoken    = context.patterns.wordtoken
local wordpattern  = context.patterns.wordpattern
local checkedword  = context.checkedword
local styleofword  = context.styleofword
local setwordlist  = context.setwordlist
local validwords   = false
local validminimum = 3

-- local styleset    = context.newstyleset {
--     "default",
--     "text", "okay", "error", "warning",
--     "preamble",
-- }

-- [#!-%] language=uk

local p_preamble = Cmt(#(S("#!-%") * P(" ")), function(input,i,_) -- todo: utf bomb
    if i == 1 then -- < 10 then
        validwords, validminimum = false, 3
        local s, e, line = find(input,'^[#!%-%%](.+)[\n\r]',i)
        if line then
            local language = match(line,"language=([a-z]+)")
            if language then
                validwords, validminimum = setwordlist(language)
            end
        end
    end
    return false
end)

local t_preamble =
    token("preamble", p_preamble)

local t_word =
--  Ct( wordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() ) -- the function can be inlined
    wordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() -- the function can be inlined

local t_text =
    token("default", wordtoken^1)

local t_rest =
    token("default", (1-wordtoken-space)^1)

local t_spacing =
    token(whitespace, space^1)

textlexer._rules = {
    { "whitespace", t_spacing  },
    { "preamble",   t_preamble },
    { "word",       t_word     }, -- words >= 3
    { "text",       t_text     }, -- non words
    { "rest",       t_rest     },
}

textlexer._LEXBYLINE   = true -- new (needs testing, not yet as the system changed in 3.24)
textlexer._tokenstyles = context.styleset

return textlexer
