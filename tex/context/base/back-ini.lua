if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

backends = backends or { }

local function nothing() return nil end

backends.nodeinjections = {
    rgbcolor     = nothing,
    cmykcolor    = nothing,
    graycolor    = nothing,
    spotcolor    = nothing,
    transparency = nothing,
    overprint    = nothing,
    knockout     = nothing,
    positive     = nothing,
    negative     = nothing,
    effect       = nothing,
    startlayer   = nothing,
    stoplayer    = nothing,
    switchlayer  = nothing,
}

backends.codeinjections = {
    insertmovie        = nothing,
}

backends.registrations = {
    grayspotcolor  = nothing,
    rgbspotcolor   = nothing,
    cmykspotcolor  = nothing,
    grayindexcolor = nothing,
    rgbindexcolor  = nothing,
    cmykindexcolor = nothing,
    spotcolorname  = nothing,
    transparency   = nothing,
}

local nodeinjections = backends.nodeinjections
local codeinjections = backends.codeinjections
local registrations  = backends.registrations

backends.current = "unknown"

function backends.install(what)
    if type(what) == "string" then
        backends.current = what
        what = backends[what]
        if what then
            local wi = what.nodeinjections
            if wi then
                for k, v in next, wi do
                    nodeinjections[k] = v
                end
            end
            local wi = what.codeinjections
            if wi then
                for k, v in next, wi do
                    codeinjections[k] = v
                end
            end
            local wi = what.registrations
            if wi then
                for k, v in next, wi do
                    registrations[k] = v
                end
            end
        end
    end
end
