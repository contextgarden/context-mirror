if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We overload the regular loader. We do so because we operate mostly in
-- tds and use our own loader code. Alternatively we could use a more
-- extensive definition of package.path and package.cpath but even then
-- we're not done. Also, we now have better tracing.
--
-- -- local mylib = require("libtest")
-- -- local mysql = require("luasql.mysql")

local concat = table.concat

local trace_libraries = false

trackers.register("resolvers.libraries", function(v) trace_libraries = v end)
trackers.register("resolvers.locating",  function(v) trace_libraries = v end)

local report_libraries = logs.reporter("resolvers","libraries")

local gsub, insert = string.gsub, table.insert
local P, Cs, lpegmatch = lpeg.P, lpeg.Cs, lpeg.match
local unpack = unpack or table.unpack
local is_readable = file.is_readable

local resolvers, package = resolvers, package

local  libsuffixes = { 'tex', 'lua' }
local clibsuffixes = { 'lib' }
local  libformats  = { 'TEXINPUTS', 'LUAINPUTS' }
local clibformats  = { 'CLUAINPUTS' }

local libpaths   = nil
local clibpaths  = nil
local libhash    = { }
local clibhash   = { }
local libextras  = { }
local clibextras = { }

local pattern = Cs(P("!")^0 / "" * (P("/") * P(-1) / "/" + P("/")^1 / "/" + 1)^0)

local function cleanpath(path) --hm, don't we have a helper for this?
    return resolvers.resolve(lpegmatch(pattern,path))
end

local function getlibpaths()
    if not libpaths then
        libpaths = { }
        for i=1,#libformats do
            local paths = resolvers.expandedpathlistfromvariable(libformats[i])
            for i=1,#paths do
                local path = cleanpath(paths[i])
                if not libhash[path] then
                    libpaths[#libpaths+1] = path
                    libhash[path] = true
                end
            end
        end
    end
    return libpaths
end

local function getclibpaths()
    if not clibpaths then
        clibpaths = { }
        for i=1,#clibformats do
            local paths = resolvers.expandedpathlistfromvariable(clibformats[i])
            for i=1,#paths do
                local path = cleanpath(paths[i])
                if not clibhash[path] then
                    clibpaths[#clibpaths+1] = path
                    clibhash[path] = true
                end
            end
        end
    end
    return clibpaths
end

package.libpaths  = getlibpaths
package.clibpaths = getclibpaths

function package.extralibpath(...)
    local paths = { ... }
    for i=1,#paths do
        local path = cleanpath(paths[i])
        if not libhash[path] then
            if trace_libraries then
                report_libraries("! extra lua path '%s'",path)
            end
            libextras[#libextras+1] = path
            libpaths[#libpaths  +1] = path
        end
    end
end

function package.extraclibpath(...)
    local paths = { ... }
    for i=1,#paths do
        local path = cleanpath(paths[i])
        if not clibhash[path] then
            if trace_libraries then
                report_libraries("! extra lib path '%s'",path)
            end
            clibextras[#clibextras+1] = path
            clibpaths[#clibpaths  +1] = path
        end
    end
end

if not package.loaders[-2] then
    -- use package-path and package-cpath
    package.loaders[-2] = package.loaders[2]
end

local function loadedaslib(resolved,rawname)
    return package.loadlib(resolved,"luaopen_" .. gsub(rawname,"%.","_"))
end

local function loadedbylua(name)
    if trace_libraries then
        report_libraries("! locating %q using normal loader",name)
    end
    local resolved = package.loaders[-2](name)
end

local function loadedbyformat(name,rawname,suffixes,islib)
    if trace_libraries then
        report_libraries("! locating %q as %q using formats %q",rawname,name,concat(suffixes))
    end
    for i=1,#suffixes do -- so we use findfile and not a lookup loop
        local format = suffixes[i]
        local resolved = resolvers.findfile(name,format) or ""
        if trace_libraries then
            report_libraries("! checking for %q' using format %q",name,format)
        end
        if resolved ~= "" then
            if trace_libraries then
                report_libraries("! lib %q located on %q",name,resolved)
            end
            if islib then
                return loadedaslib(resolved,rawname)
            else
                return loadfile(resolved)
            end
        end
    end
end

local function loadedbypath(name,rawname,paths,islib,what)
    if trace_libraries then
        report_libraries("! locating %q as %q on %q paths",rawname,name,what)
    end
    for p=1,#paths do
        local path = paths[p]
        local resolved = file.join(path,name)
        if trace_libraries then -- mode detail
            report_libraries("! checking for %q using %q path %q",name,what,path)
        end
        if is_readable(resolved) then
            if trace_libraries then
                report_libraries("! lib %q located on %q",name,resolved)
            end
            if islib then
                return loadedaslib(resolved,rawname)
            else
                return loadfile(resolved)
            end
        end
    end
end

local function notloaded(name)
    if trace_libraries then
        report_libraries("? unable to locate library %q",name)
    end
end

package.loaders[2] = function(name)
    local thename = gsub(name,"%.","/")
    local luaname = file.addsuffix(thename,"lua")
    local libname = file.addsuffix(thename,os.libsuffix)
    return
        loadedbyformat(luaname,name,libsuffixes,   false)
     or loadedbyformat(libname,name,clibsuffixes,  true)
     or loadedbypath  (luaname,name,getlibpaths (),false,"lua")
     or loadedbypath  (luaname,name,getclibpaths(),false,"lua")
     or loadedbypath  (libname,name,getclibpaths(),true, "lib")
     or loadedbylua   (name)
     or notloaded     (name)
end

-- package.loaders[3] = nil
-- package.loaders[4] = nil

resolvers.loadlualib = require
