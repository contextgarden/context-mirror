if not modules then modules = { } end modules ['v-tex'] = {
    version   = 1.001,
    comment   = "companion to v-tex.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local context            = context
local verbatim           = context.verbatim
local makepattern        = visualizers.makepattern

local TexSnippet         = context.TexSnippet
local startTexSnippet    = context.startTexSnippet
local stopTexSnippet     = context.stopTexSnippet

local TexSnippetName     = verbatim.TexSnippetName
local TexSnippetGroup    = verbatim.TexSnippetGroup
local TexSnippetBoundary = verbatim.TexSnippetBoundary
local TexSnippetSpecial  = verbatim.TexSnippetSpecial
local TexSnippetComment  = verbatim.TexSnippetComment

local handler = visualizers.newhandler {
    startinline  = function() TexSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startTexSnippet() end,
    stopdisplay  = function() stopTexSnippet() end ,
    name         = function(s) TexSnippetName(s) end,
    group        = function(s) TexSnippetGroup(s) end,
    boundary     = function(s) TexSnippetBoundary(s) end,
    special      = function(s) TexSnippetSpecial(s) end,
    comment      = function(s) TexSnippetComment(s) end,
}

-- todo: unicode letters in control sequences (slow as we need to test the nature)

local comment     = S("%")
local name        = P("\\") * (patterns.letter + S("@!?"))^1
local escape      = P("\\") * (patterns.anything - patterns.newline)^-1 -- else we get \n
local group       = S("${}")
local boundary    = S('[]()<>#="')
local special     = S("/^_-&+'`|")

local pattern = visualizers.pattern

local grammar = visualizers.newgrammar("default", { "visualizer",

    comment     = makepattern(handler,"comment",comment)
                * (V("space") + V("content"))^0,
    name        = makepattern(handler,"name",name),
    escape      = makepattern(handler,"name",escape),
    group       = makepattern(handler,"group",group),
    boundary    = makepattern(handler,"boundary",boundary),
    special     = makepattern(handler,"special",special),

    pattern     =
        V("comment") + V("name") + V("escape") + V("group") + V("boundary") + V("special")
      + V("newline") * V("emptyline")^0 * V("beginline")
      + V("space")
      + V("default"),

    visualizer  =
        V("pattern")^1

} )

local parser = P(grammar)

visualizers.register("tex", { parser = parser, handler = handler, grammar = grammar } )
