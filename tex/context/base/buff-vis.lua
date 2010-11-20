if not modules then modules = { } end modules ['buff-vis'] = {
    version   = 1.001,
    comment   = "companion to buff-vis.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local format = string.format
local C, P, V, patterns, lpegmatch = lpeg.C, lpeg.P, lpeg.V, lpeg.patterns, lpeg.match

visualizers = visualizers or { }

local patterns = { }  visualizers.patterns = patterns

local fallback = context.verbatim

function visualizers.pattern(visualizer,kind,pattern)
    if type(visualizer) == "table" and type(kind) == "string" then
        kind = visualizer[kind] or visualizer.default or fallback
    else
        kind = fallback
    end
    return C(pattern)/kind
end

setmetatable(patterns, {
    __index = function(t,k)
        local v = require(format("v-%s.lua",k)) or false
        context.input(format("v-%s.mkiv",k))
        t[k] = v
        return v
    end
} )

local function visualizestring(method,content)
    if content and content ~= "" then
        lpegmatch(patterns[method],content)
    end
end

visualizers.visualizestring = visualizestring

function visualizers.visualizefile(method,name)
    visualizestring(method,resolvers.loadtexfile(name))
end

function visualizers.visualizebuffer(method,name)
    lpegmatch(method,buffers.content(name))
end

local visualizer = {
    start   = function() context.startSnippet() end,
    stop    = function() context.stopSnippet() end ,
    default = context.verbatim,
}

local patterns = lpeg.patterns
local pattern = visualizers.pattern

local texvisualizer = P { "process",
    process =
        V("start") * V("content") * V("stop"),
    start =
        pattern(visualizer,"start",patterns.beginofstring),
    stop =
        pattern(visualizer,"stop",patterns.endofstring),
    content = (
        pattern(visualizer,"default",patterns.anything)
    )^1
}

return texvisualizer
