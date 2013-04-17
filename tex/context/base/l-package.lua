if not modules then modules = { } end modules ['l-package'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Code moved from data-lua and changed into a plug-in.

-- We overload the regular loader. We do so because we operate mostly in
-- tds and use our own loader code. Alternatively we could use a more
-- extensive definition of package.path and package.cpath but even then
-- we're not done. Also, we now have better tracing.
--
-- -- local mylib = require("libtest")
-- -- local mysql = require("luasql.mysql")

local type = type
local gsub, format = string.gsub, string.format

local P, S, Cs, lpegmatch = lpeg.P, lpeg.S, lpeg.Cs, lpeg.match

local package    = package
local searchers  = package.searchers or package.loaders

-- dummies

local filejoin   = file and file.join        or function(path,name)   return path .. "/" .. name end
local isreadable = file and file.is_readable or function(name)        local f = io.open(name) if f then f:close() return true end end
local addsuffix  = file and file.addsuffix   or function(name,suffix) return name .. "." .. suffix end

--

-- local separator, concatinator, placeholder, pathofexecutable, ignorebefore = string.match(package.config,"(.-)\n(.-)\n(.-)\n(.-)\n(.-)\n")
--
-- local config = {
--     separator        = separator,           -- \ or /
--     concatinator     = concatinator,        -- ;
--     placeholder      = placeholder,         -- ? becomes name
--     pathofexecutable = pathofexecutable,    -- ! becomes executables dir (on windows)
--     ignorebefore     = ignorebefore,        -- - remove all before this when making lua_open
-- }

--

local function cleanpath(path) -- hm, don't we have a helper for this?
    return path
end

local pattern = Cs((((1-S("\\/"))^0 * (S("\\/")^1/"/"))^0 * (P(".")^1/"/"+P(1))^1) * -1)

local function lualibfile(name)
    return lpegmatch(pattern,name) or name
end

local helpers = package.helpers or {
    cleanpath  = cleanpath,
    lualibfile = lualibfile,
    trace      = false,
    report     = function(...) print(format(...)) end,
    builtin    = {
        ["preload table"]       = package.searchers[1], -- special case, built-in libs
        ["path specification"]  = package.searchers[2],
        ["cpath specification"] = package.searchers[3],
        ["all in one fallback"] = package.searchers[4], -- special case, combined libs
    },
    methods    = {
    },
    sequence   = {
        "already loaded",
        "preload table",
        "lua extra list",
        "lib extra list",
        "path specification",
        "cpath specification",
        "all in one fallback",
        "not loaded",
    }
}

package.helpers  = helpers

local methods = helpers.methods
local builtin = helpers.builtin

-- extra tds/ctx paths

local extraluapaths = { }
local extralibpaths = { }
local luapaths      = nil -- delayed
local libpaths      = nil -- delayed

local function getextraluapaths()
    return extraluapaths
end

local function getextralibpaths()
    return extralibpaths
end

local function getluapaths()
    luapaths = luapaths or file.splitpath(package.path, ";")
    return luapaths
end

local function getlibpaths()
    libpaths = libpaths or file.splitpath(package.cpath, ";")
    return libpaths
end

package.luapaths      = getluapaths
package.libpaths      = getlibpaths
package.extraluapaths = getextraluapaths
package.extralibpaths = getextralibpaths

local hashes = {
    lua = { },
    lib = { },
}

local function registerpath(tag,what,target,...)
    local pathlist  = { ... }
    local cleanpath = helpers.cleanpath
    local trace     = helpers.trace
    local report    = helpers.report
    local hash      = hashes[what]
    --
    local function add(path)
        local path = cleanpath(path)
        if not hash[path] then
            target[#target+1] = path
            hash[path]        = true
            if trace then
                report("registered %s path %s: %s",tag,#target,path)
            end
        else
            if trace then
                report("duplicate %s path: %s",tag,path)
            end
        end
    end
    --
    for p=1,#pathlist do
        local path = pathlist[p]
        if type(path) == "table" then
            for i=1,#path do
                add(path[i])
            end
        else
            add(path)
        end
    end
    return paths
end

helpers.registerpath = registerpath

function package.extraluapath(...)
    registerpath("extra lua","lua",extraluapaths,...)
end

function package.extralibpath(...)
    registerpath("extra lib","lib",extralibpaths,...)
end

-- lib loader (used elsewhere)

local function loadedaslib(resolved,rawname) -- todo: strip all before first -
 -- local init = "luaopen_" .. string.match(rawname,".-([^%.]+)$")
    local init = "luaopen_"..gsub(rawname,"%.","_")
    if helpers.trace then
        helpers.report("calling loadlib with '%s' with init '%s'",resolved,init)
    end
    return package.loadlib(resolved,init)
end

helpers.loadedaslib = loadedaslib

-- wrapped and new loaders

local function loadedbypath(name,rawname,paths,islib,what)
    local trace  = helpers.trace
    local report = helpers.report
    if trace then
        report("locating '%s' as '%s' on '%s' paths",rawname,name,what)
    end
    for p=1,#paths do
        local path = paths[p]
        local resolved = filejoin(path,name)
        if trace then -- mode detail
            report("checking '%s' using '%s' path '%s'",name,what,path)
        end
        if isreadable(resolved) then
            if trace then
                report("'%s' located on '%s'",name,resolved)
            end
            local result = nil
            if islib then
                result = loadedaslib(resolved,rawname)
            else
                result = loadfile(resolved)
            end
            if result then
                result()
            end
            return true, result
        end
    end
end

helpers.loadedbypath = loadedbypath

-- alternatively we could set the package.searchers

methods["already loaded"] = function(name)
    local result = package.loaded[name]
    if result then
        return true, result
    end
end

methods["preload table"] = function(name)
    local result = builtin["preload table"](name)
    if type(result) == "function" then
        return true, result
    end
end

methods["lua extra list"] = function(name)
    local thename  = lualibfile(name)
    local luaname  = addsuffix(thename,"lua")
    local luapaths = getextraluapaths()
    local done, result = loadedbypath(luaname,name,luapaths,false,"lua")
    if done then
        return true, result
    end
end

methods["lib extra list"] = function(name)
    local thename  = lualibfile(name)
    local libname  = addsuffix(thename,os.libsuffix)
    local libpaths = getextralibpaths()
    local done, result = loadedbypath(libname,name,libpaths,true,"lib")
    if done then
        return true, result
    end
end

local shown = false

methods["path specification"] = function(name)
    if not shown and helpers.trace then
        local luapaths = getluapaths() -- triggers list building
        if #luapaths > 0 then
            helpers.report("using %s built in lua paths",#luapaths)
        else
            helpers.report("no built in lua paths defined")
        end
        shown = true
    end
    local result = builtin["path specification"](name)
    if type(result) == "function" then
        return true, result()
    end
end

local shown = false

methods["cpath specification"] = function(name)
    if not shown and helpers.trace then
        local libpaths = getlibpaths() -- triggers list building
        if #libpaths > 0 then
            helpers.report("using %s built in lib paths",#libpaths)
        else
            helpers.report("no built in lib paths defined")
        end
        shown = true
    end
    local result = builtin["cpath specification"](name)
    if type(result) == "function" then
        return true, result()
    end
end

methods["all in one fallback"] = function(name)
    local result = builtin["all in one fallback"](name)
    if type(result) == "function" then
        return true, result()
    end
end

methods["not loaded"] = function(name)
    if helpers.trace then
        helpers.report("unable to locate '%s'",name)
    end
end

function helpers.loaded(name)
    local sequence = helpers.sequence
    for i=1,#sequence do
        local step = sequence[i]
        if helpers.trace then
            helpers.report("locating '%s' using method '%s'",name,step)
        end
        local done, result = methods[step](name)
        if done then
            if helpers.trace then
                helpers.report("'%s' located via method '%s' returns '%s'",name,step,type(result))
            end
            if result then
                package.loaded[name] = result
            end
            return result
        end
    end
    return nil -- we must return a value
end

function helpers.unload(name)
    if helpers.trace then
        if package.loaded[name] then
            helpers.report("unloading '%s', %s",name,"done")
        else
            helpers.report("unloading '%s', %s",name,"not loaded")
        end
    end
    package.loaded[name] = nil -- does that work? is readable only, maybe we need our own hash
end

searchers[1] = nil
searchers[2] = nil
searchers[3] = nil
searchers[4] = nil

helpers.savedrequire = helpers.savedrequire or require

require = helpers.loaded
