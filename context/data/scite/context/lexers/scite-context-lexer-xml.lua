local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- adapted from the regular context pretty printer code (after all, lexing
-- boils down to much of the same and there are only so many ways to do
-- things). Simplified a bit as we have a different nesting model.

-- todo: parse entities in attributes

local global, string, table, lpeg = _G, string, table, lpeg
local P, R, S, C, Cmt, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cmt, lpeg.Cp
local type = type
local match, find = string.match, string.find

local lexers           = require("scite-context-lexer")

local patterns         = lexers.patterns
local token            = lexers.token

local xmllexer         = lexers.new("xml","scite-context-lexer-xml")
local xmlwhitespace    = xmllexer.whitespace

local xmlcommentlexer  = lexers.load("scite-context-lexer-xml-comment")
local xmlcdatalexer    = lexers.load("scite-context-lexer-xml-cdata")
local xmlscriptlexer   = lexers.load("scite-context-lexer-xml-script")
local lualexer         = lexers.load("scite-context-lexer-lua")


local space            = patterns.space
local any              = patterns.any

local dquote           = P('"')
local squote           = P("'")
local colon            = P(":")
local semicolon        = P(";")
local equal            = P("=")
local ampersand        = P("&")

-- NameStartChar ::= ":" | [A-Z] | "_" | [a-z]
--                 | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF]
--                 | [#x370-#x37D] | [#x37F-#x1FFF]
--                 | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF]
--                 | [#x3001-#xD7FF]
--                 | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
--
-- NameChar	  ::= NameStartChar
--                 | "-" | "." | [0-9] | #xB7
--                 | [#x203F-#x2040]
--                 | [#x0300-#x036F]

local name             = ( -- We are a bit more tolerant here.
                            R("az","AZ","09")
                          + S("_-.")
                          + patterns.utf8two + patterns.utf8three + patterns.utf8four
                         )^1
local openbegin        = P("<")
local openend          = P("</")
local closebegin       = P("/>") + P(">")
local closeend         = P(">")
local opencomment      = P("<!--")
local closecomment     = P("-->")
local openinstruction  = P("<?")
local closeinstruction = P("?>")
local opencdata        = P("<![CDATA[")
local closecdata       = P("]]>")
local opendoctype      = P("<!DOCTYPE") -- could grab the whole doctype
local closedoctype     = P("]>") + P(">")
local openscript       = openbegin * (P("script") + P("SCRIPT")) * (1-closeend)^0 * closeend -- begin
local closescript      = openend   * (P("script") + P("SCRIPT"))                  * closeend

local openlua          = "<?lua"
local closelua         = "?>"

-- <!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
-- <!DOCTYPE Something PUBLIC "... ..." "..." >
-- <!DOCTYPE Something SYSTEM "... ..." [ ... ] >
-- <!DOCTYPE Something SYSTEM "... ..." >
-- <!DOCTYPE Something [ ... ] >
-- <!DOCTYPE Something >

local entity           = ampersand * (1-semicolon)^1 * semicolon

local utfchar          = lexers.helpers.utfchar
local wordtoken        = patterns.wordtoken
local iwordtoken       = patterns.iwordtoken
local wordpattern      = patterns.wordpattern
local iwordpattern     = patterns.iwordpattern
local invisibles       = patterns.invisibles
local styleofword      = lexers.styleofword
local setwordlist      = lexers.setwordlist
local validwords       = false
local validminimum     = 3

-- <?xml version="1.0" encoding="UTF-8" language="uk" ?>
--
-- <?context-directive editor language us ?>

xmllexer.preamble = Cmt(P("<?xml " + P(true)), function(input,i) -- todo: utf bomb, no longer #
    validwords   = false
    validminimum = 3
    local language = match(input,"^<%?xml[^>]*%?>%s*<%?context%-directive%s+editor%s+language%s+(..)%s+%?>")
    if language then
        validwords, validminimum = setwordlist(language)
    end
    return false -- so we go back and now handle the line as processing instruction
end)

local t_word =
    C(iwordpattern) * Cp() / function(s,p) return styleofword(validwords,validminimum,s,p) end  -- a bit of a hack

local t_rest =
    token("default", any)

local t_text =
    token("default", (1-S("<>&")-space)^1)

local t_spacing =
    token(xmlwhitespace, space^1)

local t_optionalwhitespace =
    token("default", space^1)^0

local t_localspacing =
    token("default", space^1)

-- Because we want a differently colored open and close we need an embedded lexer (whitespace
-- trigger). What is actually needed is that scintilla applies the current whitespace style.
-- Even using different style keys is not robust as they can be shared. I'll fix the main
-- lexer code.

local t_sstring =
    token("quote",dquote)
  * token("string",(1-dquote)^0)        -- different from context
  * token("quote",dquote)

local t_dstring =
    token("quote",squote)
  * token("string",(1-squote)^0)        -- different from context
  * token("quote",squote)

-- local t_comment =
--     token("command",opencomment)
--   * token("comment",(1-closecomment)^0) -- different from context
--   * token("command",closecomment)

-- local t_cdata =
--     token("command",opencdata)
--   * token("comment",(1-closecdata)^0)   -- different from context
--   * token("command",closecdata)

-- maybe cdata just text (then we don't need the extra lexer as we only have one comment then)

-- <!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
-- <!DOCTYPE Something PUBLIC "... ..." "..." >
-- <!DOCTYPE Something SYSTEM "... ..." [ ... ] >
-- <!DOCTYPE Something SYSTEM "... ..." >
-- <!DOCTYPE Something [ ... ] >
-- <!DOCTYPE Something >

-- <!ENTITY xxxx SYSTEM "yyyy" NDATA zzzz>
-- <!ENTITY xxxx PUBLIC "yyyy" >
-- <!ENTITY xxxx "yyyy" >

local t_docstr  = t_dstring + t_sstring

local t_docent  = token("command",P("<!ENTITY"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * (
                    (
                        token("constant",P("SYSTEM"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      * token("constant",P("NDATA"))
                      * t_optionalwhitespace
                      * token("keyword",name)
                    ) + (
                        token("constant",P("PUBLIC"))
                      * t_optionalwhitespace
                      * t_docstr
                    ) + (
                        t_docstr
                    )
                  )
                * t_optionalwhitespace
                * token("command",P(">"))

local t_docele  = token("command",P("<!ELEMENT"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * token("command",P("("))
                * (
                    t_localspacing
                  + token("constant",P("#CDATA") + P("#PCDATA") + P("ANY"))
                  + token("text",P(","))
                  + token("comment",(1-S(",)"))^1)
                  )^1
                * token("command",P(")"))
                * t_optionalwhitespace
                * token("command",P(">"))

local t_docset  = token("command",P("["))
                * t_optionalwhitespace
                * ((t_optionalwhitespace * (t_docent + t_docele))^1 + token("comment",(1-P("]"))^0))
                * t_optionalwhitespace
                * token("command",P("]"))

local t_doctype = token("command",P("<!DOCTYPE"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * (
                    (
                        token("constant",P("PUBLIC"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      ) + (
                        token("constant",P("SYSTEM"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      )
                  )^-1
                * t_docset^-1
                * t_optionalwhitespace
                * token("command",P(">"))

lexers.embed(xmllexer, lualexer,        token("command", openlua),     token("command", closelua))
lexers.embed(xmllexer, xmlcommentlexer, token("command", opencomment), token("command", closecomment))
lexers.embed(xmllexer, xmlcdatalexer,   token("command", opencdata),   token("command", closecdata))
lexers.embed(xmllexer, xmlscriptlexer,  token("command", openscript),  token("command", closescript))

-- local t_name =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("keyword",name)
--     )
--   + token("keyword",name)

local t_name = -- more robust
    token("plain",name * colon)^-1
  * token("keyword",name)

-- local t_key =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("constant",name)
--     )
--   + token("constant",name)

local t_key =
    token("plain",name * colon)^-1
  * token("constant",name)

local t_attributes = (
    t_optionalwhitespace
  * t_key
  * t_optionalwhitespace
  * token("plain",equal)
  * t_optionalwhitespace
  * (t_dstring + t_sstring)
  * t_optionalwhitespace
)^0

local t_open =
    token("keyword",openbegin)
  * (
        t_name
      * t_optionalwhitespace
      * t_attributes
      * token("keyword",closebegin)
      +
      token("error",(1-closebegin)^1)
    )

local t_close =
    token("keyword",openend)
  * (
        t_name
      * t_optionalwhitespace
      * token("keyword",closeend)
      +
      token("error",(1-closeend)^1)
    )

local t_entity =
    token("constant",entity)

local t_instruction =
    token("command",openinstruction * P("xml"))
  * t_optionalwhitespace
  * t_attributes
  * t_optionalwhitespace
  * token("command",closeinstruction)
  + token("command",openinstruction * name)
  * token("default",(1-closeinstruction)^1)
  * token("command",closeinstruction)

local t_invisible =
    token("invisible",invisibles^1)

xmllexer.rules = {
    { "whitespace",  t_spacing     },
    { "word",        t_word        },
 -- { "text",        t_text        },
 -- { "comment",     t_comment     },
 -- { "cdata",       t_cdata       },
    { "doctype",     t_doctype     },
    { "instruction", t_instruction },
    { "close",       t_close       },
    { "open",        t_open        },
    { "entity",      t_entity      },
    { "invisible",   t_invisible   },
    { "rest",        t_rest        },
}

xmllexer.folding = {
    ["</"]   = { ["keyword"] = -1 },
    ["/>"]   = { ["keyword"] = -1 },
    ["<"]    = { ["keyword"] =  1 },
    ["<?"]   = { ["command"] =  1 },
    ["<!--"] = { ["command"] =  1 },
    ["?>"]   = { ["command"] = -1 },
    ["-->"]  = { ["command"] = -1 },
    [">"]    = { ["command"] = -1 },
}

return xmllexer
