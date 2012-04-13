local info = {
    version   = 1.002,
    comment   = "theme for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- context_path = string.split(os.resultof("mtxrun --find-file context.mkiv"))[1] or ""
-- global.trace("OEPS") -- how do we get access to the regular lua extensions

-- The regular styles set the main lexer styles table but we avoid that in order not
-- to end up with updating issues. We just use another table.

-- if not lexer._CONTEXTEXTENSIONS then require("scite-context-lexer") end

local context_path = "t:/sources" -- c:/data/tex-context/tex/texmf-context/tex/base
local font_name    = 'Dejavu Sans Mono'
local font_size    = 14

if not WIN32 then
    font_name = '!' .. font_name
end

local color   = lexer.color
local style   = lexer.style

lexer.context = lexer.context or { }
local context = lexer.context

context.path  = context_path

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

-- to be set:
--
-- style_nothing
-- style_class
-- style_comment
-- style_constant
-- style_definition
-- style_error
-- style_function
-- style_keyword
-- style_number
-- style_operator
-- style_string
-- style_preproc
-- style_tag
-- style_type
-- style_variable
-- style_embedded
-- style_label
-- style_regex
-- style_identifier
--
-- style_line_number
-- style_bracelight
-- style_bracebad
-- style_controlchar
-- style_indentguide
-- style_calltip

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

style_quote              = style { fore = colors.blue, bold = true }
style_special            = style { fore = colors.blue }
style_extra              = style { fore = colors.yellow }

style_embedded           = style { fore = colors.black, bold = true }

style_char               = style { fore = colors.magenta }
style_reserved           = style { fore = colors.magenta, bold = true }
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

style_standout           = style { fore = colors.orange, bold = true }

style_line_number        = style { back = colors.linepanel }
style_bracelight         = style_standout
style_bracebad           = style_standout
style_indentguide        = style { fore = colors.linepanel, back = colors.white }
style_calltip            = style { fore = colors.white, back = colors.tippanel }
style_controlchar        = style_nothing

style_label              = style { fore = colors.red, bold = true  } -- style { fore = colors.cyan, bold = true  }
style_regex              = style_string

style_command            = style { fore = colors.green, bold = true }

-- only bold seems to work

lexer.style_nothing     = style_nothing
lexer.style_class       = style_class
lexer.style_comment     = style_comment
lexer.style_constant    = style_constant
lexer.style_definition  = style_definition
lexer.style_error       = style_error
lexer.style_function    = style_function
lexer.style_keyword     = style_keyword
lexer.style_number      = style_number
lexer.style_operator    = style_operator
lexer.style_string      = style_string
lexer.style_preproc     = style_preproc
lexer.style_tag         = style_tag
lexer.style_type        = style_type
lexer.style_variable    = style_variable
lexer.style_embedded    = style_embedded
lexer.style_label       = style_label
lexer.style_regex       = style_regex
lexer.style_identifier  = style_nothing

local styles = { -- as we have globals we could do with less

 -- ["whitespace"] = style_whitespace, -- not to be set!

["default"]    = style_nothing,
["number"]     = style_number,
["comment"]    = style_comment,
["keyword"]    = style_keyword,
["string"]     = style_string,
["preproc"]    = style_preproc,

    ["reserved"]   = style_reserved,
    ["internal"]   = style_standout,

    ["command"]    = style_command,
    ["preamble"]   = style_comment,
    ["embedded"]   = style_embedded,
    ["grouping"]   = style { fore = colors.red  },
["label"]      = style_label,
    ["primitive"]  = style_keyword,
    ["plain"]      = style { fore = colors.dark, bold = true },
    ["user"]       = style { fore = colors.green },
    ["data"]       = style_constant,
    ["special"]    = style_special,
    ["extra"]      = style_extra,
    ["quote"]      = style_quote,

    ["okay"]       = style_okay,
    ["warning"]    = style_warning,
    ["invisible"]  = style_invisible,
["error"]      = style_error,

}

-- Old method (still available):

local styleset = { }

for k, v in next, styles do
    styleset[#styleset+1] = { k, v }
end

context.styles   = styles
context.styleset = styleset

-- We need to be sparse due to some limitation (and the number of built in styles
-- growing).

-- function context.newstyleset(list)
--     local t = { }
--     if list then
--         for i=1,#list do
--             t[list[i]] = true
--         end
--     end
--     return t
-- end

-- function context.usestyle(set,name)
--     set[name] = true
--     return name
-- end

-- function context.usestyleset(set)
--     local t = { }
--     for k, _ in next, set do
--         t[#t+1] = { k, styles[k] or styles.default }
--     end
-- end
