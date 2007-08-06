-- filename : luat-crl.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions    then versions    = { } end versions['luat-crl'] = 1.001
if not curl        then curl        = { } end

curl.cachepath = cache.setpath(texmf.instance,"curl")

curl.cached = { }

function curl.fetch(protocol, name)
    local cachename = curl.cachepath .. "/" .. file.robustname(name)
    cachename = cachename:gsub("[\\/]", io.fileseparator)
    if not curl.cached[name] then
        if not io.exists(cachename) then
            curl.cached[name] = cachename
            local command = "curl --silent --create-dirs --output " .. cachename .. " " .. protocol .. "://" .. name
            os.execute(command)
        end
        if io.exists(cachename) then
            curl.cached[name] = cachename
        else
            curl.cached[name] = ""
        end
    end
    return curl.cached[name]
end

function input.finders.curl(instance,protocol,filename)
    local foundname = curl.fetch(protocol, filename)
    return input.finders.generic(instance,protocol,foundname,filetype)
end
function input.openers.curl(instance,protocol,filename)
    return input.openers.generic(instance,protocol,filename)
end
function input.loaders.curl(instance,protocol,filename)
    return input.loaders.generic(instance,protocol,filename)
end

-- todo: metamethod

function curl.install(protocol)
    input.finders[protocol] = function (instance,filename,filetype) return input.finders.curl(instance,protocol,filename) end
    input.openers[protocol] = function (instance,filename)          return input.openers.curl(instance,protocol,filename) end
    input.loaders[protocol] = function (instance,filename)          return input.loaders.curl(instance,protocol,filename) end
end

curl.install('http')
curl.install('https')
curl.install('ftp')
