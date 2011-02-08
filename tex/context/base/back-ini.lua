if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I need to check what is actually needed, maybe some can become
-- locals.

backends = backends or { }
local backends = backends

local trace_backend = false  trackers.register("backend.initializers", function(v) trace_finalizers = v end)

local report_backend = logs.reporter("backend","initializing")

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

    addtags      = nothing,

    insertu3d    = nothing,
    insertswf    = nothing,
    insertmovie  = nothing,
    insertsound  = nothing,

}

backends.codeinjections = {

    prerollreference       = nothing,

    presetsymbol           = nothing,
    presetsymbollist       = nothing,
    registersymbol         = nothing,
    registeredsymbol       = nothing,

    registercomment        = nothing,

    embedfile              = nothing,
    attachfile             = nothing,
    attachmentid           = nothing,

    adddocumentinfo        = nothing,
    setupidentity          = nothing,
    setupcanvas            = nothing,

    setpagetransition      = nothing,

    defineviewerlayer      = nothing,
    useviewerlayer         = nothing,

    addbookmarks           = nothing,

    addtransparencygroup   = nothing,

    typesetfield           = nothing,
    doiffieldelse          = nothing,
    doiffieldgroupelse     = nothing,
    doiffieldsetelse       = nothing,
    definefield            = nothing,
    clonefield             = nothing,
    definefieldset         = nothing,
    setfieldcalculationset = nothing,
    getfieldgroup          = nothing,
    getfieldset            = nothing,
    setformsmethod         = nothing,
    getdefaultfieldvalue   = nothing,

    flushpageactions       = nothing,
    flushdocumentactions   = nothing,

    insertrenderingwindow  = nothing,
    processrendering       = nothing,

    setfigurecolorspace    = nothing,
    setfigurealternative   = nothing,

    enabletags             = nothing,

    mergereferences        = nothing,
    mergeviewerlayers      = nothing,

    setformat              = nothing,
    getformatoption        = nothing,
    supportedformats       = nothing,

    -- called in tex

    finalizepage           = nothing, -- will go when we have a hook at the lua end

    finishreference        = nothing,

    getoutputfilename      = nothing,

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

local comment = { "comment", "" }

backends.tables = {
    vfspecials = {
        red        = comment,
        green      = comment,
        blue       = comment,
        black      = comment,
        startslant = comment,
        stopslant  = comment,
    }
}

backends.current = "unknown"

function backends.install(what)
    if type(what) == "string" then
        local backend = backends[what]
        if backend then
            if trace_backend then
                report_backend("initializing backend %s (%s)",what,backend.comment or "no comment")
            end
            backends.current = what
            for _, category in next, { "nodeinjections", "codeinjections", "registrations", "tables" } do
                local plugin = backend[category]
                local whereto = backends[category]
                if plugin then
                    for name, meaning in next, whereto do
                        if plugin[name] then
                            whereto[name] = plugin[name]
                        --  report_backend("installing function %s in category %s of %s",name,category,what)
                        elseif trace_backend then
                            report_backend("no function %s in category %s of %s",name,category,what)
                        end
                    end
                elseif trace_backend then
                    report_backend("no category %s in %s",category,what)
                end
                -- extra checks
                for k, v in next, whereto do
                    if not plugin[k] then
                        report_backend("entry %s in %s is not set",k,category)
                    end
                end
                for k, v in next, plugin do
                    if not whereto[k] then
                        report_backend("entry %s in %s is not used",k,category)
                    end
                end
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
