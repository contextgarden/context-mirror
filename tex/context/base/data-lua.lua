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

local P, S, Cs, lpegmatch = lpeg.P, lpeg.S, lpeg.Cs, lpeg.match

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

local loadedaslib    = helpers.loadedaslib
local loadedbylua    = helpers.loadedbylua
local loadedbypath   = helpers.loadedbypath
local notloaded      = helpers.notloaded

local getlibpaths    = package.libpaths
local getclibpaths   = package.clibpaths

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

local function loadedbyformat(name,rawname,suffixes,islib)
    local trace  = helpers.trace
    local report = helpers.report
    if trace then
        report("locating %a as %a using formats %a",rawname,name,suffixes)
    end
    for i=1,#suffixes do -- so we use findfile and not a lookup loop
        local format = suffixes[i]
        local resolved = resolvers.findfile(name,format) or ""
        if trace then
            report("checking %a using format %a",name,format)
        end
        if resolved ~= "" then
            if trace then
                report("lib %a located on %a",name,resolved)
            end
            if islib then
                return true, loadedaslib(resolved,rawname)
            else
                return true, loadfile(resolved)
            end
        end
    end
end

helpers.loadedbyformat = loadedbyformat

-- alternatively we could set the package.searchers

local pattern = Cs((((1-S("\\/"))^0 * (S("\\/")^1/"/"))^0 * (P(".")^1/"/"+P(1))^1) * -1)

local function lualibfile(name)
    return lpegmatch(pattern,name) or name
end

helpers.lualibfile = lualibfile

-- print(lualibfile("bar"))
-- print(lualibfile("foo.bar"))
-- print(lualibfile("crap/foo...bar"))
-- print(lualibfile("crap//foo.bar"))
-- print(lualibfile("crap/../foo.bar"))
-- print(lualibfile("crap/.././foo.bar"))

-- alternatively we could split in path and base and temporary set the libpath to path

function helpers.loaded(name)
    local thename   = lualibfile(name)
    local luaname   = addsuffix(thename,"lua")
    local libname   = addsuffix(thename,os.libsuffix)
    local libpaths  = getlibpaths()
    local clibpaths = getclibpaths()
    local done, result = loadedbyformat(luaname,name,libsuffixes,false)
    if done then
        return result
    end
    local done, result = loadedbyformat(libname,name,clibsuffixes,true)
    if done then
        return result
    end
    local done, result = loadedbypath(luaname,name,libpaths,false,"lua")
    if done then
        return result
    end
    local done, result = loadedbypath(luaname,name,clibpaths,false,"lua")
    if done then
        return result
    end
    local done, result = loadedbypath(libname,name,clibpaths,true,"lib")
    if done then
        return result
    end
    local done, result = loadedbylua(name)
    if done then
        return result
    end
    return notloaded(name)
end

-- package.searchers[3] = nil -- get rid of the built in one (done in l-lua)

-- package.extraclibpath(environment.ownpath)

resolvers.loadlualib = require
