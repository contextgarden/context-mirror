if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable = setmetatable

backends       = backends or { }
local backends = backends

local trace_backend = false  trackers.register("backend.initializers", function(v) trace_finalizers = v end)

local report_backend = logs.reporter("backend","initializing")

local function nothing() return nil end

backends.nothing = nothing

local mt = {
    __index = function(t,k)
        t[k] = nothing
        return nothing
    end
}

local nodeinjections = { }  setmetatable(nodeinjections, mt)
local codeinjections = { }  setmetatable(codeinjections, mt)
local registrations  = { }  setmetatable(registrations,  mt)
local tables         = { }

local defaults = {
    nodeinjections = nodeinjections,
    codeinjections = codeinjections,
    registrations  = registrations,
    tables         = tables,
}

backends.defaults = defaults

backends.nodeinjections = { }  setmetatable(backends.nodeinjections, { __index = nodeinjections })
backends.codeinjections = { }  setmetatable(backends.codeinjections, { __index = codeinjections })
backends.registrations  = { }  setmetatable(backends.registrations,  { __index = registrations  })
backends.tables         = { }  setmetatable(backends.tables,         { __index = tables         })

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
                setmetatable(plugin, { __index = default })
                setmetatable(target, { __index = plugin  })
            end
        elseif trace_backend then
            report_backend("no backend named %s",what)
        end
    end
end

statistics.register("used backend", function()
    local bc = backends.current
    if bc ~= "unknown" then
        return string.format("%s (%s)",bc,backends[bc].comment or "no comment")
    else
        return nil
    end
end)

local comment = { "comment", "" }

tables.vfspecials = {
    red        = comment,
    green      = comment,
    blue       = comment,
    black      = comment,
    startslant = comment,
    stopslant  = comment,
}
