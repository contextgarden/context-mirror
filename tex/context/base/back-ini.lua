if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

backends = backends or { }

local trace_backend = false

local function nothing() return nil end

backends.nothing = nothing

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

    reference    = nothing,
    destination  = nothing,

}

backends.codeinjections = {

    prerollreference      = nothing,

    insertmovie           = nothing,
    insertsound           = nothing,

    presetsymbollist      = nothing,
    registersymbol        = nothing,
    registeredsymbol      = nothing,

    registercomment       = nothing,
    embedfile             = nothing,
    attachfile            = nothing,
    adddocumentinfo       = nothing,
    setupidentity         = nothing,
    setpagetransition     = nothing,
    defineviewerlayer     = nothing,
    addbookmarks          = nothing,
    addtransparencygroup  = nothing,

    typesetfield          = nothing,
    doiffieldelse         = nothing,
    doiffieldgroupelse    = nothing,
    definefield           = nothing,
    clonefield            = nothing,
    definefieldset        = nothing,
    getfieldgroup         = nothing,
    setformsmethod        = nothing,
    getdefaultfieldvalue  = nothing,

    setupcanvas           = nothing,

    initializepage        = nothing,
    initializedocument    = nothing,
    finalizepage          = nothing,
    finalizedocument      = nothing,

    flushpageactions      = nothing,
    flushdocumentactions  = nothing,

    insertrenderingwindow = nothing,
    processrendering      = nothing,
    kindofrendering       = nothing,
    flushrenderingwindow  = nothing,

    setfigurecolorspace   = nothing,
    setfigurealternative  = nothing,

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
        local backend = backends[what]
        if backend then
            if trace_backend then
                logs.report("backend", "initializing backend %s (%s)",what,backend.comment or "no comment")
            end
            backends.current = what
            for _, category in next, { "nodeinjections", "codeinjections", "registrations"} do
                local plugin = backend[category]
                if plugin then
                    local whereto = backends[category]
                    for name, meaning in next, whereto do
                        if plugin[name] then
                            whereto[name] = plugin[name]
                        --  logs.report("backend", "installing function %s in category %s of %s",name,category,what)
                        elseif trace_backend then
                            logs.report("backend", "no function %s in category %s of %s",name,category,what)
                        end
                    end
                elseif trace_backend then
                    logs.report("backend", "no category %s in %s",category,what)
                end
            end
            backends.helpers = backend.helpers
        elseif trace_backend then
            logs.report("backend", "no backend named %s",what)
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
