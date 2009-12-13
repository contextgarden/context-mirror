if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- some loading stuff ... we might move this one to slot 2 depending
-- on the developments (the loaders must not trigger kpse); we could
-- of course use a more extensive lib path spec

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local gsub = string.gsub

local  libformats = { 'luatexlibs', 'tex', 'texmfscripts', 'othertextfiles' } -- 'luainputs'
local clibformats = { 'lib' }
local  libpaths   = file.split_path(package.path)
local clibpaths   = file.split_path(package.cpath)

local function thepath(...)
    local t = { ... } t[#t+1] = "?.lua"
    local path = file.join(unpack(t))
    if trace_locating then
        logs.report("fileio","! appending '%s' to 'package.path'",path)
    end
    return path
end

function package.append_libpath(...)
    table.insert(libpaths,thepath(...))
end

function package.prepend_libpath(...)
    table.insert(libpaths,1,thepath(...))
end

-- beware, we need to return a loadfile result !

package.loaders[2] = function(name) -- was [#package.loaders+1]
    if trace_locating then -- mode detail
        logs.report("fileio","! locating '%s'",name)
    end
    for i=1,#libformats do
        local format = libformats[i]
        local resolved = resolvers.find_file(name,format) or ""
        if trace_locating then -- mode detail
            logs.report("fileio","! checking for '%s' using 'libformat path': '%s'",name,format)
        end
        if resolved ~= "" then
            if trace_locating then
                logs.report("fileio","! lib '%s' located via environment: '%s'",name,resolved)
            end
            return loadfile(resolved)
        end
    end
    local simple = gsub(name,"%.lua$","")
    local simple = gsub(simple,"%.","/")
    for i=1,#libpaths do -- package.path, might become option
        local libpath = libpaths[i]
        local resolved = gsub(libpath,"?",simple)
        if trace_locating then -- more detail
            logs.report("fileio","! checking for '%s' on 'package.path': '%s'",simple,libpath)
        end
        if resolvers.isreadable.file(resolved) then
            if trace_locating then
                logs.report("fileio","! lib '%s' located via 'package.path': '%s'",name,resolved)
            end
            return loadfile(resolved)
        end
    end
    local libname = file.addsuffix(simple,os.libsuffix)
    for i=1,#clibformats do
        -- better have a dedicated loop
        local format = clibformats[i]
        local paths = resolvers.expanded_path_list_from_var(format)
        for p=1,#paths do
            local path = paths[p]
            local resolved = file.join(path,libname)
            if trace_locating then -- mode detail
                logs.report("fileio","! checking for '%s' using 'clibformat path': '%s'",libname,path)
            end
            if resolvers.isreadable.file(resolved) then
                if trace_locating then
                    logs.report("fileio","! lib '%s' located via 'clibformat': '%s'",libname,resolved)
                end
                return package.loadlib(resolved,name)
            end
        end
    end
    for i=1,#clibpaths do -- package.path, might become option
        local libpath = clibpaths[i]
        local resolved = gsub(libpath,"?",simple)
        if trace_locating then -- more detail
            logs.report("fileio","! checking for '%s' on 'package.cpath': '%s'",simple,libpath)
        end
        if resolvers.isreadable.file(resolved) then
            if trace_locating then
                logs.report("fileio","! lib '%s' located via 'package.cpath': '%s'",name,resolved)
            end
            return package.loadlib(resolved,name)
        end
    end
    -- just in case the distribution is messed up
    if trace_loading then -- more detail
        logs.report("fileio","! checking for '%s' using 'luatexlibs': '%s'",name)
    end
    local resolved = resolvers.find_file(file.basename(name),'luatexlibs') or ""
    if resolved ~= "" then
        if trace_locating then
            logs.report("fileio","! lib '%s' located by basename via environment: '%s'",name,resolved)
        end
        return loadfile(resolved)
    end
    if trace_locating then
        logs.report("fileio",'? unable to locate lib: %s',name)
    end
--  return "unable to locate " .. name
end

resolvers.loadlualib = require
