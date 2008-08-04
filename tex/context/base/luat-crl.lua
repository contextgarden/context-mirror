-- filename : luat-crl.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-crl'] = 1.001
if not curl     then curl     = { } end

curl.cached    = { }
curl.cachepath = caches.definepath("curl")

function curl.fetch(protocol, name)
    local cachename = curl.cachepath() .. "/" .. name:gsub("[^%a%d%.]+","-")
--  cachename = cachename:gsub("[\\/]", io.fileseparator)
    cachename = cachename:gsub("[\\]", "/")
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

function input.finders.curl(protocol,filename)
    local foundname = curl.fetch(protocol, filename)
    return input.finders.generic(protocol,foundname,filetype)
end
function input.openers.curl(protocol,filename)
    return input.openers.generic(protocol,filename)
end
function input.loaders.curl(protocol,filename)
    return input.loaders.generic(protocol,filename)
end

-- todo: metamethod

function curl.install(protocol)
    input.finders[protocol] = function (filename,filetype) return input.finders.curl(protocol,filename) end
    input.openers[protocol] = function (filename)          return input.openers.curl(protocol,filename) end
    input.loaders[protocol] = function (filename)          return input.loaders.curl(protocol,filename) end
end

curl.install('http')
curl.install('https')
curl.install('ftp')
