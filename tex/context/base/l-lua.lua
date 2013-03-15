if not modules then modules = { } end modules ['l-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- compatibility hacks ... try to avoid usage

local major, minor = string.match(_VERSION,"^[^%d]+(%d+)%.(%d+).*$")

_MAJORVERSION = tonumber(major) or 5
_MINORVERSION = tonumber(minor) or 1
_LUAVERSION   = _MAJORVERSION + _MINORVERSION/10

-- lpeg

if not lpeg then
    lpeg = require("lpeg")
end

-- basics:

if loadstring then

    local loadnormal = load

    function load(first,...)
        if type(first) == "string" then
            return loadstring(first,...)
        else
            return loadnormal(first,...)
        end
    end

else

    loadstring = load

end

-- table:

-- At some point it was announced that i[pairs would be dropped, which makes
-- sense. As we already used the for loop and # in most places the impact on
-- ConTeXt was not that large; the remaining ipairs already have been replaced.
-- Hm, actually ipairs was retained, but we no longer use it anyway (nor
-- pairs).
--
-- Just in case, we provide the fallbacks as discussed in Programming
-- in Lua (http://www.lua.org/pil/7.3.html):

if not ipairs then

    -- for k, v in ipairs(t) do                ... end
    -- for k=1,#t            do local v = t[k] ... end

    local function iterate(a,i)
        i = i + 1
        local v = a[i]
        if v ~= nil then
            return i, v --, nil
        end
    end

    function ipairs(a)
        return iterate, a, 0
    end

end

if not pairs then

    -- for k, v in pairs(t) do ... end
    -- for k, v in next, t  do ... end

    function pairs(t)
        return next, t -- , nil
    end

end

-- The unpack function has been moved to the table table, and for compatiility
-- reasons we provide both now.

if not table.unpack then

    table.unpack = _G.unpack

elseif not unpack then

    _G.unpack = table.unpack

end

-- package:

-- if not package.seachers then
--
--     package.searchers = package.loaders -- 5.2
--
-- elseif not package.loaders then
--
--     package.loaders = package.searchers
--
-- end

if not package.loaders then -- brr, searchers is a special "loadlib function" userdata type

    package.loaders = package.searchers

end

-- moved from util-deb to here:

local print, select, tostring = print, select, tostring

local inspectors = { }

function setinspector(inspector) -- global function
    inspectors[#inspectors+1] = inspector
end

function inspect(...) -- global function
    for s=1,select("#",...) do
        local value = select(s,...)
        local done = false
        for i=1,#inspectors do
            done = inspectors[i](value)
            if done then
                break
            end
        end
        if not done then
            print(tostring(value))
        end
    end
end

--

local dummy = function() end

function optionalrequire(...)
    local ok, result = xpcall(require,dummy,...)
    if ok then
        return result
    end
end

-- Code moved from data-lua and changed into a plug-in.

-- We overload the regular loader. We do so because we operate mostly in
-- tds and use our own loader code. Alternatively we could use a more
-- extensive definition of package.path and package.cpath but even then
-- we're not done. Also, we now have better tracing.
--
-- -- local mylib = require("libtest")
-- -- local mysql = require("luasql.mysql")

local gsub, format = string.gsub, string.format

local package    =  package
local searchers  = package.searchers or package.loaders

local libpaths   = nil
local clibpaths  = nil
local libhash    = { }
local clibhash   = { }
local libextras  = { }
local clibextras = { }

-- dummies

local filejoin   = file and file.join        or function(path,name)   return path .. "/" .. name end
local isreadable = file and file.is_readable or function(name)        local f = io.open(name) if f then f:close() return true end end
local addsuffix  = file and file.addsuffix   or function(name,suffix) return name .. "." .. suffix end

--

local function cleanpath(path) -- hm, don't we have a helper for this?
    return path
end

local helpers    = package.helpers or {
    libpaths  = function() return { } end,
    clibpaths = function() return { } end,
    cleanpath = cleanpath,
    trace     = false,
    report    = function(...) print(format(...)) end,
}
package.helpers  = helpers

local function getlibpaths()
    return libpaths or helpers.libpaths(libhash)
end

local function getclibpaths()
    return clibpaths or helpers.clibpaths(clibhash)
end

package.libpaths  = getlibpaths
package.clibpaths = getclibpaths

function package.extralibpath(...)
    libpaths  = getlibpaths()
    local pathlist  = { ... }
    local cleanpath = helpers.cleanpath
    local trace     = helpers.trace
    local report    = helpers.report
    for p=1,#pathlist do
        local paths = pathlist[p]
        for i=1,#paths do
            local path = cleanpath(paths[i])
            if not libhash[path] then
                if trace then
                    report("! extra lua path: %s",path)
                end
                libextras[#libextras+1] = path
                libpaths [#libpaths +1] = path
            end
        end
    end
end

function package.extraclibpath(...)
    clibpaths = getclibpaths()
    local pathlist  = { ... }
    local cleanpath = helpers.cleanpath
    local trace     = helpers.trace
    local report    = helpers.report
    for p=1,#pathlist do
        local paths = pathlist[p]
        for i=1,#paths do
            local path = cleanpath(paths[i])
            if not clibhash[path] then
                if trace then
                    report("! extra lib path: %s",path)
                end
                clibextras[#clibextras+1] = path
                clibpaths [#clibpaths +1] = path
            end
        end
    end
end

if not searchers[-2] then
    -- use package-path and package-cpath
    searchers[-2] = searchers[2]
end

searchers[2] = function(name)
    return helpers.loaded(name)
end

local function loadedaslib(resolved,rawname)
    return package.loadlib(resolved,"luaopen_" .. gsub(rawname,"%.","_"))
end

local function loadedbylua(name)
    if helpers.trace then
        helpers.report("! locating '%s' using normal loader",name)
    end
    return searchers[-2](name)
end

local function loadedbypath(name,rawname,paths,islib,what)
    local trace  = helpers.trace
    local report = helpers.report
    if trace then
        report("! locating '%s' as '%s' on '%s' paths",rawname,name,what)
    end
    for p=1,#paths do
        local path = paths[p]
        local resolved = filejoin(path,name)
        if trace then -- mode detail
            report("! checking for '%s' using '%s' path '%s'",name,what,path)
        end
        if isreadable(resolved) then
            if trace then
                report("! lib '%s' located on '%s'",name,resolved)
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
    if helpers.trace then
        helpers.report("? unable to locate library '%s'",name)
    end
end

helpers.loadedaslib  = loadedaslib
helpers.loadedbylua  = loadedbylua
helpers.loadedbypath = loadedbypath
helpers.notloaded    = notloaded

function helpers.loaded(name)
    local thename   = gsub(name,"%.","/")
    local luaname   = addsuffix(thename,"lua")
    local libname   = addsuffix(thename,os.libsuffix or "so") -- brrr
    local libpaths  = getlibpaths()
    local clibpaths = getclibpaths()
    return loadedbypath(luaname,name,libpaths,false,"lua")
        or loadedbypath(luaname,name,clibpaths,false,"lua")
        or loadedbypath(libname,name,clibpaths,true,"lib")
        or loadedbylua(name)
        or notloaded(name)
end
