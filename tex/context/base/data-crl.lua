if not modules then modules = { } end modules ['data-crl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one is replaced by data-sch.lua --

local gsub = string.gsub

local resolvers = resolvers

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

curl = curl or { }
local curl = curl

local cached = { }

function curl.fetch(protocol, name) -- todo: use socket library
    local cleanname = gsub(name,"[^%a%d%.]+","-")
    local cachename = caches.setfirstwritablefile(cleanname,"curl")
    if not cached[name] then
        if not io.exists(cachename) then
            cached[name] = cachename
            local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name -- no protocol .. "://"
            os.spawn(command)
        end
        if io.exists(cachename) then
            cached[name] = cachename
        else
            cached[name] = ""
        end
    end
    return cached[name]
end

function finders.curl(protocol,filename)
    local foundname = curl.fetch(protocol, filename)
    return finders.generic(protocol,foundname,filetype)
end

function openers.curl(protocol,filename)
    return openers.generic(protocol,filename)
end

function loaders.curl(protocol,filename)
    return loaders.generic(protocol,filename)
end

-- todo: metamethod

function curl.install(protocol)
    finders[protocol] = function (filename,filetype) return finders.curl(protocol,filename) end
    openers[protocol] = function (filename)          return openers.curl(protocol,filename) end
    loaders[protocol] = function (filename)          return loaders.curl(protocol,filename) end
end

curl.install('http')
curl.install('https')
curl.install('ftp')
