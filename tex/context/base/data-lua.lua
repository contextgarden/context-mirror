if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is now a plug in into l-lua (as we also use the extra paths elsewhere).

local resolvers, package = resolvers, package

local gsub = string.gsub
local concat = table.concat
local addsuffix = file.addsuffix

local P, Cs, lpegmatch = lpeg.P, lpeg.Cs, lpeg.match

local  libsuffixes = { 'tex', 'lua' }
local clibsuffixes = { 'lib' }
local  libformats  = { 'TEXINPUTS', 'LUAINPUTS' }
local clibformats  = { 'CLUAINPUTS' }
local helpers      = package.helpers

trackers.register("resolvers.libraries", function(v) helpers.trace = v end)
trackers.register("resolvers.locating",  function(v) helpers.trace = v end)

helpers.report = logs.reporter("resolvers","libraries")

local pattern = Cs(P("!")^0 / "" * (P("/") * P(-1) / "/" + P("/")^1 / "/" + 1)^0)

local function cleanpath(path) -- hm, don't we have a helper for this?
    return resolvers.resolve(lpegmatch(pattern,path))
end

helpers.cleanpath = cleanpath

function helpers.libpaths(libhash)
    local libpaths  = { }
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
    return libpaths
end

function helpers.clibpaths(clibhash)
    local clibpaths = { }
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
    return clibpaths
end

function helpers.loadedbyformat(name,rawname,suffixes,islib)
    local trace  = helpers.trace
    local report = helpers.report
    if trace then
        report("! locating %q as %q using formats %q",rawname,name,concat(suffixes))
    end
    for i=1,#suffixes do -- so we use findfile and not a lookup loop
        local format = suffixes[i]
        local resolved = resolvers.findfile(name,format) or ""
        if trace then
            report("! checking for %q' using format %q",name,format)
        end
        if resolved ~= "" then
            if trace then
                report("! lib %q located on %q",name,resolved)
            end
            if islib then
                return loadedaslib(resolved,rawname)
            else
                return loadfile(resolved)
            end
        end
    end
end

local loadedaslib    = helpers.loadedaslib
local loadedbylua    = helpers.loadedbylua
local loadedbyformat = helpers.loadedbyformat
local loadedbypath   = helpers.loadedbypath
local notloaded      = helpers.notloaded

local getlibpaths    = package.libpaths
local getclibpaths   = package.clibpaths

function helpers.loaded(name)
    local thename   = gsub(name,"%.","/")
    local luaname   = addsuffix(thename,"lua")
    local libname   = addsuffix(thename,os.libsuffix)
    local libpaths  = getlibpaths()
    local clibpaths = getclibpaths()
    return loadedbyformat(luaname,name,libsuffixes,false)
        or loadedbyformat(libname,name,clibsuffixes,true)
        or loadedbypath(luaname,name,libpaths,false,"lua")
        or loadedbypath(luaname,name,clibpaths,false,"lua")
        or loadedbypath(libname,name,clibpaths,true,"lib")
        or loadedbylua(name)
        or notloaded(name)
end

resolvers.loadlualib = require
