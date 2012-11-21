if not modules then modules = { } end modules ['trac-ctx'] = {
    version   = 1.001,
    comment   = "companion to trac-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local commands = commands
local context  = context
local register = trackers.register

local textrackers   = tex.trackers   or { }
local texdirectives = tex.directives or { }

tex.trackers   = textrackers
tex.directives = texdirectives

storage.register("tex/trackers",  textrackers,  "tex.trackers")
storage.register("tex/directives",texdirectives,"tex.directives")

local function doit(category,tag,v)
    local tt = category[tag]
    if tt then
        context.unprotect()
        context(v and tt[1] or tt[2]) -- could be one call
        context.protect()
    end
end

local function initialize(category,register)
    for tag, commands in next, category do
        register(tag, function(v) doit(category,tag,v) end) -- todo: v,tag in caller
    end
end

local function install(category,register,tag,enable,disable)
    category[tag] = { enable, disable }
    register(tag, function(v) doit(category,tag,v) end) -- todo: v,tag in caller
end

function commands.initializetextrackers  () initialize(textrackers  ,trackers  .register  ) end
function commands.initializetexdirectives() initialize(texdirectives,directives.register) end

-- commands.install(tag,enable,disable):

function commands.installtextracker  (...) install(textrackers  ,trackers  .register,...) end
function commands.installtexdirective(...) install(texdirectives,directives.register,...) end
