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

if not lexer._CONTEXTEXTENSIONS then require("scite-context-lexer") end

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

local colors = {
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

lexer.colors = colors

-- defaults:

local style_nothing     = style { }
----- style_whitespace  = style { }
local style_comment     = style { fore = colors.yellow }
local style_string      = style { fore = colors.magenta }
local style_number      = style { fore = colors.cyan }
local style_keyword     = style { fore = colors.blue, bold = true }
local style_identifier  = style_nothing
local style_operator    = style { fore = colors.blue }
local style_error       = style { fore = colors.red }
local style_preproc     = style { fore = colors.yellow, bold = true }
local style_constant    = style { fore = colors.cyan, bold = true }
local style_variable    = style { fore = colors.black }
local style_function    = style { fore = colors.black, bold = true }
local style_class       = style { fore = colors.black, bold = true }
local style_type        = style { fore = colors.blue }
local style_label       = style { fore = colors.red, bold = true  }
local style_regex       = style { fore = colors.magenta }

-- reserved:

local style_default     = style { font = font_name, size = font_size, fore = colors.black, back = colors.textpanel }
local style_text        = style { font = font_name, size = font_size, fore = colors.black, back = colors.textpanel }
local style_line_number = style { back = colors.linepanel }
local style_bracelight  = style { fore = colors.orange, bold = true }
local style_bracebad    = style { fore = colors.orange, bold = true }
local style_indentguide = style { fore = colors.linepanel, back = colors.white }
local style_calltip     = style { fore = colors.white, back = colors.tippanel }
local style_controlchar = style_nothing

-- extras:

local style_quote       = style { fore = colors.blue, bold = true }
local style_special     = style { fore = colors.blue }
local style_extra       = style { fore = colors.yellow }
local style_embedded    = style { fore = colors.black, bold = true }
----- style_char        = style { fore = colors.magenta }
local style_reserved    = style { fore = colors.magenta, bold = true }
local style_definition  = style { fore = colors.black, bold = true }
local style_okay        = style { fore = colors.dark }
local style_warning     = style { fore = colors.orange }
local style_invisible   = style { back = colors.orange }
local style_tag         = style { fore = colors.cyan }
----- style_standout    = style { fore = colors.orange, bold = true }
local style_command     = style { fore = colors.green, bold = true }
local style_internal    = style { fore = colors.orange, bold = true }

local style_preamble    = style { fore = colors.yellow }
local style_grouping    = style { fore = colors.red  }
local style_primitive   = style { fore = colors.blue, bold = true }
local style_plain       = style { fore = colors.dark, bold = true }
local style_user        = style { fore = colors.green }
local style_data        = style { fore = colors.cyan, bold = true }


-- used by the generic lexer:

lexer.style_nothing      = style_nothing       --  0
-----.whitespace         = style_whitespace    --  1
lexer.style_comment      = style_comment       --  2
lexer.style_string       = style_string        --  3
lexer.style_number       = style_number        --  4
lexer.style_keyword      = style_keyword       --  5
lexer.style_identifier   = style_nothing       --  6
lexer.style_operator     = style_operator      --  7
lexer.style_error        = style_error         --  8
lexer.style_preproc      = style_preproc       --  9
lexer.style_constant     = style_constant      -- 10
lexer.style_variable     = style_variable      -- 11
lexer.style_function     = style_function      -- 12
lexer.style_class        = style_class         -- 13
lexer.style_type         = style_type          -- 14
lexer.style_label        = style_label         -- 15
lexer.style_regex        = style_regexp        -- 16

lexer.style_default      = style_default       -- 32
lexer.style_line_number  = style_line_number   -- 33
lexer.style_bracelight   = style_bracelight    -- 34
lexer.style_bracebad     = style_bracebad      -- 35
lexer.style_indentguide  = style_indentguide   -- 36
lexer.style_calltip      = style_calltip       -- 37
lexer.style_controlchar  = style_controlchar   -- 38

local styles = { -- as we have globals we could do with less

 -- ["whitespace"] = style_whitespace, -- not to be set!
    ["default"]    = style_nothing,    -- else no good backtracking to start-of-child
 -- ["number"]     = style_number,
 -- ["comment"]    = style_comment,
 -- ["keyword"]    = style_keyword,
 -- ["string"]     = style_string,
 -- ["preproc"]    = style_preproc,
 -- ["error"]      = style_error,
 -- ["label"]      = style_label,

    ["invisible"]  = style_invisible,
    ["quote"]      = style_quote,
    ["special"]    = style_special,
    ["extra"]      = style_extra,
    ["embedded"]   = style_embedded,
 -- ["char"]       = style_char,
    ["reserved"]   = style_reserved,
 -- ["definition"] = style_definition,
    ["okay"]       = style_okay,
    ["warning"]    = style_warning,
 -- ["standout"]   = style_standout,
    ["command"]    = style_command,
    ["internal"]   = style_internal,
    ["preamble"]   = style_preamble,
    ["grouping"]   = style_grouping,
    ["primitive"]  = style_primitive,
    ["plain"]      = style_plain,
    ["user"]       = style_user,
    ["data"]       = style_data,

    ["text"]       = style_text, -- style_default

}

local styleset = { }

for k, v in next, styles do
    styleset[#styleset+1] = { k, v }
end

context.styles   = styles
context.styleset = styleset

function context.stylesetcopy()
    local t = { }
    for i=1,#styleset do
        local s = styleset[i]
        t[i] = s
t[s[1]] = t[s[2]] -- new style ?
    end
    t[#t+1] = { "whitespace", style_nothing }
t.whitespace = style_nothing -- new style ?
    return t
end

-- We can be sparse if needed:

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
