if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- some loading stuff ... we might move this one to slot 1 depending
-- on the developments (the loaders must not trigger kpse); we could
-- of course use a more extensive lib path spec

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local gsub = string.gsub

local libformats = { 'luatexlibs', 'tex', 'texmfscripts', 'othertextfiles' }
local libpaths   = file.split_path(package.path)

package.loaders[#package.loaders+1] = function(name)
    for i=1,#libformats do
        local format = libformats[i]
        local resolved = resolvers.find_file(name,format) or ""
        if resolved ~= "" then
            if trace_locating then
                logs.report("fileio","! lib '%s' located via environment: '%s'",name,resolved)
            end
            return function() return dofile(resolved) end
        end
    end
    local simple = file.removesuffix(name)
    for i=1,#libpaths do
        local resolved = gsub(libpaths[i],"?",simple)
        if resolvers.isreadable.file(resolved) then
            if trace_locating then
                logs.report("fileio","! lib '%s' located via 'package.path': '%s'",name,resolved)
            end
            return function() return dofile(resolved) end
        end
    end
    -- just in case the distribution is messed up
    local resolved = resolvers.find_file(file.basename(name),'luatexlibs') or ""
    if resolved ~= "" then
        if trace_locating then
            logs.report("fileio","! lib '%s' located by basename via environment: '%s'",name,resolved)
        end
        return function() return dofile(resolved) end
    end
    if trace_locating then
        logs.report("fileio",'? unable to locate lib: %s',name)
    end
    return "unable to locate " .. name
end

resolvers.loadlualib = require
