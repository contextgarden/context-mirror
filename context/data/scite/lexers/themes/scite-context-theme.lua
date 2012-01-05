local info = {
    version   = 1.002,
    comment   = "theme for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- context_path = string.split(os.resultof("mtxrun --find-file context.mkiv"))[1] or ""
-- global.trace("OEPS") -- how do we get access to the regular lua extensions

local context_path = "t:/sources" -- c:/data/tex-context/tex/texmf-context/tex/base
local font_name    = 'Dejavu Sans Mono'
local font_size    = 14

if not WIN32 then
    font_name = '!' .. font_name
end

local global = _G

-- dofile(_LEXERHOME .. '/themes/scite.lua') -- starting point so we miss nothing

module('lexer', package.seeall)

lexer.context      = lexer.context or { }
lexer.context.path = context_path

colors = {
    red       = color('7F', '00', '00'),
    green     = color('00', '7F', '00'),
    blue      = color('00', '00', '7F'),
    cyan      = color('00', '7F', '7F'),
    magenta   = color('7F', '00', '7F'),
    yellow    = color('7F', '7F', '00'),
    orange    = color('B0', '7F', '00'),
    --
    white     = color('FF', 'FF', 'FF'),
    light     = color('CF', 'CF', 'CF'),
    grey      = color('80', '80', '80'),
    dark      = color('4F', '4F', '4F'),
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

colors.teal   = colors.cyan
colors.purple = colors.magenta

style_default = style {
    font = font_name,
    size = font_size,
    fore = colors.black,
    back = colors.textpanel,
}

style_nothing = style {
    -- empty
}

style_number             = style { fore = colors.cyan }
style_comment            = style { fore = colors.yellow }
style_string             = style { fore = colors.magenta }
style_keyword            = style { fore = colors.blue, bold = true }

style_char               = style { fore = colors.magenta }
style_class              = style { fore = colors.black, bold = true }
style_constant           = style { fore = colors.cyan, bold = true }
style_definition         = style { fore = colors.black, bold = true }
style_okay               = style { fore = colors.dark }
style_error              = style { fore = colors.red }
style_warning            = style { fore = colors.orange }
style_invisible          = style { back = colors.orange }
style_function           = style { fore = colors.black, bold = true }
style_operator           = style { fore = colors.blue }
style_preproc            = style { fore = colors.yellow, bold = true }
style_tag                = style { fore = colors.cyan }
style_type               = style { fore = colors.blue }
style_variable           = style { fore = colors.black }
style_identifier         = style_nothing

style_line_number        = style { back = colors.linepanel }
style_bracelight         = style { fore = colors.orange, bold = true }
style_bracebad           = style { fore = colors.orange, bold = true }
style_indentguide        = style { fore = colors.linepanel, back = colors.white }
style_calltip            = style { fore = colors.white, back = colors.tippanel }
style_controlchar        = style_nothing

-- only bold seems to work

lexer.context.styles = {

 -- ["whitespace"] = style_whitespace,

    ["default"]    = style_nothing,
    ["number"]     = style_number,
    ["comment"]    = style_comment,
    ["keyword"]    = style_keyword,
    ["string"]     = style_string,

    ["command"]    = style { fore = colors.green, bold = true },
    ["preamble"]   = style_comment,
    ["embedded"]   = style { fore = colors.black, bold = true },
    ["grouping"]   = style { fore = colors.red  },
    ["primitive"]  = style_keyword,
    ["plain"]      = style { fore = colors.dark, bold = true },
    ["user"]       = style { fore = colors.green },
    ["data"]       = style_constant,
    ["special"]    = style { fore = colors.blue },
    ["extra"]      = style { fore = colors.yellow },
    ["quote"]      = style { fore = colors.blue, bold = true },

    ["okay"]       = style_okay,
    ["warning"]    = style_warning,
    ["invisible"]  = style_invisible,
    ["error"]      = style_error,

}

local styleset = { }

for k, v in next, lexer.context.styles do
    styleset[#styleset+1] = { k, v }
end

lexer.context.styleset = styleset
