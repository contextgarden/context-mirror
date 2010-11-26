if not modules then modules = { } end modules ['v-default'] = {
    version   = 1.001,
    comment   = "companion to v-default.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local patterns, P, V = lpeg.patterns, lpeg.P, lpeg.V
local makepattern = visualizers.makepattern

local handler = visualizers.newhandler()

local grammar = { "visualizer",

    -- basic

    emptyline  = makepattern(handler,"emptyline",patterns.emptyline),
    beginline  = makepattern(handler,"beginline",patterns.beginline),
    newline    = makepattern(handler,"newline",  patterns.newline),
    space      = makepattern(handler,"space",    patterns.space),
    default    = makepattern(handler,"default",  patterns.anything),
    content    = makepattern(handler,"default",  patterns.somecontent),

    -- handy

    line               = V("newline") * V("emptyline")^0 * V("beginline"),
    whitespace         = (V("space") + V("line"))^1,
    optionalwhitespace = (V("space") + V("line"))^0,

    -- used

    pattern            = V("line") + V("space") + V("content"),
    visualizer         = V("pattern")^1

}

local parser = P(grammar)

visualizers.register("default", { parser = parser, handler = handler, grammar = grammar })
