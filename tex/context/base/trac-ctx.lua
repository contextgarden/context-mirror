if not modules then modules = { } end modules ['trac-ctx'] = {
    version   = 1.001,
    comment   = "companion to trac-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tex.trackers = tex.trackers or { }

local textrackers = tex.trackers
local register    = trackers.register

storage.register("tex/trackers",textrackers,"tex.trackers")

local function doit(tag,v)
    local tt = textrackers[tag]
    if tt then
        context.unprotect()
        context(v and tt[1] or tt[2])
        context.protect()
    end
end

function commands.initializetextrackers()
    for tag, commands in next, textrackers do
        register(tag, function(v) doit(tag,v) end) -- todo: v,tag in caller
    end
end

function commands.installtextracker(tag,enable,disable)
    textrackers[tag] = { enable, disable }
    register(tag, function(v) doit(tag,v) end) -- todo: v,tag in caller
end

-- lua.registerfinalizer(dump,"dump storage")
