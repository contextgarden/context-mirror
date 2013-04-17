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

local luasuffixes = { 'tex', 'lua' }
local libsuffixes = { 'lib' }
local luaformats  = { 'TEXINPUTS', 'LUAINPUTS' }
local libformats  = { 'CLUAINPUTS' }
local helpers     = package.helpers or { }
local methods     = helpers.methods or { }

trackers.register("resolvers.libraries", function(v) helpers.trace = v end)
trackers.register("resolvers.locating",  function(v) helpers.trace = v end)

helpers.report = logs.reporter("resolvers","libraries")

helpers.sequence = {
    "already loaded",
    "preload table",
    "lua variable format",
    "lib variable format",
    "lua extra list",
    "lib extra list",
    "path specification",
    "cpath specification",
    "all in one fallback",
    "not loaded",
}

local pattern = Cs(P("!")^0 / "" * (P("/") * P(-1) / "/" + P("/")^1 / "/" + 1)^0)

function helpers.cleanpath(path) -- hm, don't we have a helper for this?
    return resolvers.resolve(lpegmatch(pattern,path))
end

local loadedaslib      = helpers.loadedaslib
local loadedbypath     = helpers.loadedbypath
local getextraluapaths = package.extraluapaths
local getextralibpaths = package.extralibpaths
local registerpath     = helpers.registerpath
local lualibfile       = helpers.lualibfile

local luaformatpaths
local libformatpaths

local function getluaformatpaths()
    if not luaformatpaths then
        luaformatpaths = { }
        for i=1,#luaformats do
            registerpath("lua format","lua",luaformatpaths,resolvers.expandedpathlistfromvariable(luaformats[i]))
        end
    end
    return luaformatpaths
end

local function getlibformatpaths()
    if not libformatpaths then
        libformatpaths = { }
        for i=1,#libformats do
            registerpath("lib format","lib",libformatpaths,resolvers.expandedpathlistfromvariable(libformats[i]))
        end
    end
    return libformatpaths
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
            local result = nil
            if islib then
                result = loadedaslib(resolved,rawname)
            else
                result = loadfile(resolved)
            end
            if result then
                return true, result()
            end
        end
    end
end

helpers.loadedbyformat = loadedbyformat

-- print(lualibfile("bar"))
-- print(lualibfile("foo.bar"))
-- print(lualibfile("crap/foo...bar"))
-- print(lualibfile("crap//foo.bar"))
-- print(lualibfile("crap/../foo.bar"))
-- print(lualibfile("crap/.././foo.bar"))

-- alternatively we could split in path and base and temporary set the libpath to path

-- we could build a list of relevant paths but for tracing it's better to have the
-- whole lot (ok, we could skip the duplicates)

local shown = false

methods["lua variable format"] = function(name)
    if not shown and helpers.trace then
        local luapaths = getluaformatpaths() -- triggers building
        if #luapaths > 0 then
            helpers.report("using %s lua format paths",#luapaths)
        else
            helpers.report("no lua format paths defined")
        end
        shown = true
    end
    local thename = lualibfile(name)
    local luaname = addsuffix(thename,"lua")
    local done, result = loadedbyformat(luaname,name,luasuffixes,false)
    if done then
        return true, result
    end
end

local shown = false

methods["lib variable format"] = function(name)
    if not shown and helpers.trace then
        local libpaths = getlibformatpaths() -- triggers building
        if #libpaths > 0 then
            helpers.report("using %s lib format paths",#libpaths)
        else
            helpers.report("no lib format paths defined")
        end
        shown = true
    end
    local thename = lualibfile(name)
    local libname = addsuffix(thename,os.libsuffix)
    local done, result = loadedbyformat(libname,name,libsuffixes,true)
    if done then
        return true, result
    end
end

-- package.extraclibpath(environment.ownpath)

resolvers.loadlualib = require
