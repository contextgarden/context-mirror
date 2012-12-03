if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format = string.format
local sind, cosd = math.sind, math.cosd

backends       = backends or { }
local backends = backends

local trace_backend = false  trackers.register("backend.initializers", function(v) trace_finalizers = v end)

local report_backend = logs.reporter("backend","initializing")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local function nothing() return nil end

backends.nothing = nothing

local nodeinjections = { }
local codeinjections = { }
local registrations  = { }
local tables         = allocate()

local function donothing(t,k)
    t[k] = nothing
    return nothing
end

setmetatableindex(nodeinjections, donothing)
setmetatableindex(codeinjections, donothing)
setmetatableindex(registrations,  donothing)

local defaults = {
    nodeinjections = nodeinjections,
    codeinjections = codeinjections,
    registrations  = registrations,
    tables         = tables,
}

backends.defaults = defaults

backends.nodeinjections = { }  setmetatableindex(backends.nodeinjections, nodeinjections)
backends.codeinjections = { }  setmetatableindex(backends.codeinjections, codeinjections)
backends.registrations  = { }  setmetatableindex(backends.registrations,  registrations)
backends.tables         = { }  setmetatableindex(backends.tables,         tables)

backends.current = "unknown"

function backends.install(what)
    if type(what) == "string" then
        local backend = backends[what]
        if backend then
            if trace_backend then
                report_backend("initializing backend %s (%s)",what,backend.comment or "no comment")
            end
            backends.current = what
            for category, default in next, defaults do
                local target, plugin = backends[category], backend[category]
                setmetatableindex(plugin, default)
                setmetatableindex(target, plugin)
            end
        elseif trace_backend then
            report_backend("no backend named %s",what)
        end
    end
end

statistics.register("used backend", function()
    local bc = backends.current
    if bc ~= "unknown" then
        return format("%s (%s)",bc,backends[bc].comment or "no comment")
    else
        return nil
    end
end)

local comment = { "comment", "" }

tables.vfspecials = allocate {
    red        = comment,
    green      = comment,
    blue       = comment,
    black      = comment,
    startslant = comment,
    stopslant  = comment,
}

-- experimental code --

function commands.pdfrotation(a) -- somewhat weird here
    local s, c = sind(a), cosd(a)
    context("%0.6f %0.6f %0.6f %0.6f",c,s,-s,c)
end

