if not modules then modules = { } end modules ['data-zip'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, match = string.format, string.find, string.match
local unpack = unpack or table.unpack

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

-- zip:///oeps.zip?name=bla/bla.tex
-- zip:///oeps.zip?tree=tex/texmf-local
-- zip:///texmf.zip?tree=/tex/texmf
-- zip:///texmf.zip?tree=/tex/texmf-local
-- zip:///texmf-mine.zip?tree=/tex/texmf-projects

zip                 = zip or { }
zip.archives        = zip.archives or { }
zip.registeredfiles = zip.registeredfiles or { }

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders
local locators, hashers, concatinators = resolvers.locators, resolvers.hashers, resolvers.concatinators

local archives = zip.archives

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
           local full = resolvers.find_file(name) or ""
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

function locators.zip(specification) -- where is this used? startup zips (untested)
    specification = resolvers.splitmethod(specification)
    local zipfile = specification.path
    local zfile = zip.openarchive(name) -- tricky, could be in to be initialized tree
    if trace_locating then
        if zfile then
            report_resolvers("zip locator, archive '%s' found",specification.original)
        else
            report_resolvers("zip locator, archive '%s' not found",specification.original)
        end
    end
end

function hashers.zip(tag,name)
    if trace_locating then
        report_resolvers("loading zip file '%s' as '%s'",name,tag)
    end
    resolvers.usezipfile(format("%s?tree=%s",tag,name))
end

function concatinators.zip(tag,path,name)
    if not path or path == "" then
        return format('%s?name=%s',tag,name)
    else
        return format('%s?name=%s/%s',tag,path,name)
    end
end

function resolvers.isreadable.zip(name)
    return true
end

function finders.zip(specification,filetype)
    specification = resolvers.splitmethod(specification)
    if specification.path then
        local q = url.query(specification.query)
        if q.name then
            local zfile = zip.openarchive(specification.path)
            if zfile then
                if trace_locating then
                    report_resolvers("zip finder, archive '%s' found",specification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    dfile = zfile:close()
                    if trace_locating then
                        report_resolvers("zip finder, file '%s' found",q.name)
                    end
                    return specification.original
                elseif trace_locating then
                    report_resolvers("zip finder, file '%s' not found",q.name)
                end
            elseif trace_locating then
                report_resolvers("zip finder, unknown archive '%s'",specification.path)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip finder, '%s' not found",filename)
    end
    return unpack(finders.notfound)
end

function openers.zip(specification)
    local zipspecification = resolvers.splitmethod(specification)
    if zipspecification.path then
        local q = url.query(zipspecification.query)
        if q.name then
            local zfile = zip.openarchive(zipspecification.path)
            if zfile then
                if trace_locating then
                    report_resolvers("zip opener, archive '%s' opened",zipspecification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    logs.show_open(specification)
                    if trace_locating then
                        report_resolvers("zip opener, file '%s' found",q.name)
                    end
                    return openers.text_opener(specification,dfile,'zip')
                elseif trace_locating then
                    report_resolvers("zip opener, file '%s' not found",q.name)
                end
            elseif trace_locating then
                report_resolvers("zip opener, unknown archive '%s'",zipspecification.path)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip opener, '%s' not found",filename)
    end
    return unpack(openers.notfound)
end

function loaders.zip(specification)
    specification = resolvers.splitmethod(specification)
    if specification.path then
        local q = url.query(specification.query)
        if q.name then
            local zfile = zip.openarchive(specification.path)
            if zfile then
                if trace_locating then
                    report_resolvers("zip loader, archive '%s' opened",specification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    logs.show_load(filename)
                    if trace_locating then
                        report_resolvers("zip loader, file '%s' loaded",filename)
                    end
                    local s = dfile:read("*all")
                    dfile:close()
                    return true, s, #s
                elseif trace_locating then
                    report_resolvers("zip loader, file '%s' not found",q.name)
                end
            elseif trace_locating then
                report_resolvers("zip loader, unknown archive '%s'",specification.path)
            end
        end
    end
    if trace_locating then
        report_resolvers("zip loader, '%s' not found",filename)
    end
    return unpack(openers.notfound)
end

-- zip:///somefile.zip
-- zip:///somefile.zip?tree=texmf-local -> mount

function resolvers.usezipfile(zipname)
    zipname = validzip(zipname)
    local specification = resolvers.splitmethod(zipname)
    local zipfile = specification.path
    if zipfile and not zip.registeredfiles[zipname] then
        local tree = url.query(specification.query).tree or ""
        local z = zip.openarchive(zipfile)
        if z then
            local instance = resolvers.instance
            if trace_locating then
                report_resolvers("zip registering, registering archive '%s'",zipname)
            end
            statistics.starttiming(instance)
            resolvers.prepend_hash('zip',zipname,zipfile)
            resolvers.extend_texmf_var(zipname) -- resets hashes too
            zip.registeredfiles[zipname] = z
            instance.files[zipname] = resolvers.register_zip_file(z,tree or "")
            statistics.stoptiming(instance)
        elseif trace_locating then
            report_resolvers("zip registering, unknown archive '%s'",zipname)
        end
    elseif trace_locating then
        report_resolvers("zip registering, '%s' not found",zipname)
    end
end

function resolvers.register_zip_file(z,tree)
    local files, filter = { }, ""
    if tree == "" then
        filter = "^(.+)/(.-)$"
    else
        filter = format("^%s/(.+)/(.-)$",tree)
    end
    if trace_locating then
        report_resolvers("zip registering, using filter '%s'",filter)
    end
    local register, n = resolvers.register_file, 0
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
