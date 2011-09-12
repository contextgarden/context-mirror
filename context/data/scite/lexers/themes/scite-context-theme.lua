local info = {
    version   = 1.002,
    comment   = "theme for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- we need a proper pipe:
--
-- -- context_path = string.split(os.resultof("mtxrun --find-file context.mkiv"))[1] or ""

local context_path = "t:/sources" -- c:/data/tex-context/tex/texmf-context/tex/base
local font_name    = 'Dejavu Sans Mono'
local font_size    = 14

-- The following files are needed: mult-def.lua, mult-prm.lua and mult-def.lua. They can be
-- put in the _LEXERHOME/context path of needed. Currently we have:
--
--  _LEXERHOME/themes/scite-context-theme.lua
--  _LEXERHOME/scite-context-lexer.lua
--  _LEXERHOME/context/mult-def.lua
--  _LEXERHOME/context/mult-prm.lua
--  _LEXERHOME/context/mult-mps.lua
--  _LEXERHOME/context.lua
--  _LEXERHOME/metafun.lua
--
-- However, when you set the context_path variable and omit the files in the
-- _LEXERHOME/context path then the files will be picked up from the context
-- distribution which keeps them up to date automatically.
--
-- This (plus a bit more) is what goes in context.properties:
--
-- lexer.lpeg.home=$(SciteDefaultHome)/lexers
-- lexer.lpeg.script=$(lexer.lpeg.home)/scite-context-lexer.lua
-- lexer.lpeg.color.theme=$(lexer.lpeg.home)/themes/scite-context-theme.lua
--
-- fold.by.indentation=0
--
-- if PLAT_WIN
--     lexerpath.*.lpeg=$(lexer.lpeg.home)/LexLPeg.dll
--
-- if PLAT_GTK
--     lexerpath.*.lpeg=$(lexer.lpeg.home)/liblexlpeg.so
--
-- lexer.*.lpeg=lpeg
--
-- lexer.$(file.patterns.metapost)=lpeg_metafun
-- lexer.$(file.patterns.metafun)=lpeg_metafun
-- lexer.$(file.patterns.context)=lpeg_context
-- lexer.$(file.patterns.tex)=lpeg_context
-- lexer.$(file.patterns.lua)=lpeg_lua
-- lexer.$(file.patterns.xml)=lpeg_xml
--
-- comment.block.lpeg_context=%
-- comment.block.at.line.start.lpeg_context=1
--
-- comment.block.lpeg_metafun=%
-- comment.block.at.line.start.lpeg_metafun=1
--
-- comment.block.lpeg_lua=--
-- comment.block.at.line.start.lpeg_lua=1
--
-- comment.block.lpeg_props=#
-- comment.block.at.line.start.lpeg_props=1

dofile(_LEXERHOME .. '/themes/scite.lua') -- starting point so we miss nothing

module('lexer', package.seeall)

lexer.context      = lexer.context or { }
lexer.context.path = context_path

lexer.colors = {
    red       = color('7F', '00', '00'),
    green     = color('00', '7F', '00'),
    blue      = color('00', '00', '7F'),
    cyan      = color('00', '7F', '7F'),
    magenta   = color('7F', '00', '7F'),
    yellow    = color('7F', '7F', '00'),
    --
    teal      = color('00', '7F', '7F'), -- cyan
    purple    = color('7F', '00', '7F'), -- magenta
    orange    = color('B0', '7F', '00'),
    --
    white     = color('FF', 'FF', 'FF'),
    grey      = color('80', '80', '80'),
    black     = color('00', '00', '00'),
    --
    selection = color('F7', 'F7', 'F7'),
    logpanel  = color('E7', 'E7', 'E7'),
    textpanel = color('CF', 'CF', 'CF'),
    linepanel = color('A7', 'A7', 'A7'),
    tippanel  = color('44', '44', '44'),
    --
    right     = color('00', '00', 'FF'),
    wrong     = color('FF', '00', '00'),

}

style_default = style {
    font = font_name,
    size = font_size,
    fore = colors.black,
    back = colors.textpanel,
}

style_nothing = style {
    -- empty
}

style_char        = style { fore = colors.purple              }
style_class       = style { fore = colors.black,  bold = true }
style_comment     = style { fore = colors.green               }
style_constant    = style { fore = colors.cyan,   bold = true }
style_definition  = style { fore = colors.black,  bold = true }
style_error       = style { fore = colors.red                 }
style_function    = style { fore = colors.black,  bold = true }
style_keyword     = style { fore = colors.blue,   bold = true }
style_number      = style { fore = colors.cyan                }
style_operator    = style { fore = colors.black,  bold = true }
style_string      = style { fore = colors.magenta             }
style_preproc     = style { fore = colors.yellow              }
style_tag         = style { fore = colors.cyan                }
style_type        = style { fore = colors.blue                }
style_variable    = style { fore = colors.black               }
style_identifier  = style_nothing

style_line_number = style { back = colors.linepanel }
style_bracelight  = style { fore = colors.right, bold = true }
style_bracebad    = style { fore = colors.wrong, bold = true }
style_controlchar = style_nothing
style_indentguide = style { fore = colors.linepanel, back = colors.white }
style_calltip     = style { fore = colors.white,     back = colors.tippanel }
