if not modules then modules = { } end modules ['data-zip'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- partly redone .. needs testing

local format, find, match = string.format, string.find, string.match

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

-- zip:///oeps.zip?name=bla/bla.tex
-- zip:///oeps.zip?tree=tex/texmf-local
-- zip:///texmf.zip?tree=/tex/texmf
-- zip:///texmf.zip?tree=/tex/texmf-local
-- zip:///texmf-mine.zip?tree=/tex/texmf-projects

local resolvers = resolvers

zip                   = zip or { }
local zip             = zip

zip.archives          = zip.archives or { }
local archives        = zip.archives

zip.registeredfiles   = zip.registeredfiles or { }
local registeredfiles = zip.registeredfiles

local function validzip(str) -- todo: use url splitter
    if not find(str,"^zip://") then
        return "zip:///" .. str
    else
        return str
    end
end

function zip.openarchive(name)
    if not name or name == "" then
        return nil
    else
        local arch = archives[name]
        if not arch then
           local full = resolvers.findfile(name) or ""
           arch = (full ~= "" and zip.open(full)) or false
           archives[name] = arch
        end
       return arch
    end
end

function zip.closearchive(name)
    if not name or (name == "" and archives[name]) then
        zip.close(archives[name])
        archives[name] = nil
    end
end

function resolvers.locators.zip(specification)
    local archive = specification.filename
    local zipfile = archive and archive ~= "" and zip.openarchive(archive) -- tricky, could be in to be initialized tree
    if trace_locating then
        if zipfile then
            report_resolvers("zip locator, archive '%s' found",archive)
        else
            report_resolvers("zip locator, archive '%s' not found",archive)
        end
    end
end

function resolvers.hashers.zip(specification)
    local archive = specification.filename
    if trace_locating then
        report_resolvers("loading zip file '%s'",archive)
    end
    resolvers.usezipfile(specification.original)
end

function resolvers.concatinators.zip(zipfile,path,name) -- ok ?
    if not path or path == "" then
        return format('%s?name=%s',zipfile,name)
    else
        return format('%s?name=%s/%s',zipfile,path,name)
    end
end

function resolvers.finders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_resolvers("zip finder, archive '%s' found",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    dfile = zfile:close()
                    if trace_locating then
                        report_resolvers("zip finder, file '%s' found",queryname)
                    end
                    return specification.original
                elseif trace_locating then
                    report_resolvers("zip finder, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_resolvers("zip finder, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip finder, '%s' not found",original)
    end
    return resolvers.finders.notfound()
end

function resolvers.openers.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_resolvers("zip opener, archive '%s' opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    if trace_locating then
                        report_resolvers("zip opener, file '%s' found",queryname)
                    end
                    return resolvers.openers.helpers.textopener('zip',original,dfile)
                elseif trace_locating then
                    report_resolvers("zip opener, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_resolvers("zip opener, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip opener, '%s' not found",original)
    end
    return resolvers.openers.notfound()
end

function resolvers.loaders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_resolvers("zip loader, archive '%s' opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    logs.show_load(original)
                    if trace_locating then
                        report_resolvers("zip loader, file '%s' loaded",original)
                    end
                    local s = dfile:read("*all")
                    dfile:close()
                    return true, s, #s
                elseif trace_locating then
                    report_resolvers("zip loader, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_resolvers("zip loader, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip loader, '%s' not found",original)
    end
    return resolvers.openers.notfound()
end

-- zip:///somefile.zip
-- zip:///somefile.zip?tree=texmf-local -> mount

function resolvers.usezipfile(archive)
    local specification = resolvers.splitmethod(archive) -- to be sure
    local archive = specification.filename
    if archive and not registeredfiles[archive] then
        local z = zip.openarchive(archive)
        if z then
            local tree = url.query(specification.query).tree or ""
            if trace_locating then
                report_resolvers("zip registering, registering archive '%s'",archive)
            end
            statistics.starttiming(resolvers.instance)
            resolvers.prependhash('zip',archive)
            resolvers.extendtexmfvariable(archive) -- resets hashes too
            registeredfiles[archive] = z
            instance.files[archive] = resolvers.registerzipfile(z,tree)
            statistics.stoptiming(resolvers.instance)
        elseif trace_locating then
            report_resolvers("zip registering, unknown archive '%s'",archive)
        end
    elseif trace_locating then
        report_resolvers("zip registering, '%s' not found",archive)
    end
end

function resolvers.registerzipfile(z,tree)
    local files, filter = { }, ""
    if tree == "" then
        filter = "^(.+)/(.-)$"
    else
        filter = format("^%s/(.+)/(.-)$",tree)
    end
    if trace_locating then
        report_resolvers("zip registering, using filter '%s'",filter)
    end
    local register, n = resolvers.registerfile, 0
    for i in z:files() do
        local path, name = match(i.filename,filter)
        if path then
            if name and name ~= '' then
                register(files, name, path)
                n = n + 1
            else
                -- directory
            end
        else
            register(files, i.filename, '')
            n = n + 1
        end
    end
    report_resolvers("zip registering, %s files registered",n)
    return files
end
