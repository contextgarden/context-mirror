if not modules then modules = { } end modules ['data-crl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

curl = curl or { }

curl.cached    = { }
curl.cachepath = caches.definepath("curl")

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

function curl.fetch(protocol, name)
    local cachename = curl.cachepath() .. "/" .. name:gsub("[^%a%d%.]+","-")
--  cachename = cachename:gsub("[\\/]", io.fileseparator)
    cachename = cachename:gsub("[\\]", "/") -- cleanup
    if not curl.cached[name] then
        if not io.exists(cachename) then
            curl.cached[name] = cachename
            local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name -- no protocol .. "://"
            os.spawn(command)
        end
        if io.exists(cachename) then
            curl.cached[name] = cachename
        else
            curl.cached[name] = ""
        end
    end
    return curl.cached[name]
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
