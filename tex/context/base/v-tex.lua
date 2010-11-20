if not modules then modules = { } end modules ['v-tex'] = {
    version   = 1.001,
    comment   = "companion to buff-vis.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local verbatim = context.verbatim
local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local visualizer = {
    start    = function() context.startTexSnippet() end,
    stop     = function() context.stopTexSnippet() end ,
    name     = function(s) verbatim.TexSnippetName(s) end,
    group    = function(s) verbatim.TexSnippetGroup(s) end,
    boundary = function(s) verbatim.TexSnippetBoundary(s) end,
    special  = function(s) verbatim.TexSnippetSpecial(s) end,
    comment  = function(s) verbatim.TexSnippetComment(s) end,
    default  = function(s) verbatim(s) end,
}

-- todo: unicode letters

local comment    = S("%")
local restofline = (1-patterns.newline)^0
local anything   = patterns.anything
local name       = P("\\") * (patterns.letter + S("@!?"))^1
local escape     = P("\\") * (anything - patterns.newline)^-1 -- else we get \n
local group      = S("${}")
local boundary   = S('[]()<>#="')
local special    = S("/^_-&+'`|")

local pattern = visualizers.pattern

local texvisualizer = P { "process",
    process =
        V("start") * V("content") * V("stop"),
    start =
        pattern(visualizer,"start",patterns.beginofstring),
    stop =
        pattern(visualizer,"stop",patterns.endofstring),
    content = (
        pattern(visualizer,"comment",comment)
      * pattern(visualizer,"default",restofline)
      + pattern(visualizer,"name",name)
      + pattern(visualizer,"name",escape)
      + pattern(visualizer,"group",group)
      + pattern(visualizer,"boundary",boundary)
      + pattern(visualizer,"special",special)
      + pattern(visualizer,"default",anything)
    )^1
}

return texvisualizer
