if not modules then modules = { } end modules ['data-sch'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local http  = require("socket.http")
local ltn12 = require("ltn12")

local gsub, concat, format = string.gsub, table.concat, string.format

local trace_schemes = false  trackers.register("resolvers.schemes",function(v) trace_schemes = v end)

schemes = schemes or { }

schemes.cached    = { }
schemes.cachepath = caches.definepath("schemes")
schemes.threshold = 24 * 60 * 60

directives.register("schemes.threshold", function(v) schemes.threshold = tonumber(v) or schemes.threshold end)

local cached, loaded, reused = schemes.cached, { }, { }

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

function schemes.curl(name,cachename)
    local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name -- no protocol .. "://"
    os.spawn(command)
end

function schemes.fetch(protocol,name,handler)
    local cachename = schemes.cachepath() .. "/" .. gsub(name,"[^%a%d%.]+","-")
    cachename = gsub(cachename,"[\\]", "/") -- cleanup
    if not cached[name] then
        statistics.starttiming(schemes)
        if not io.exists(cachename) or (os.difftime(os.time(),lfs.attributes(cachename).modification) > schemes.threshold) then
            cached[name] = cachename
            if handler then
                if trace_schemes then
                    logs.report("schemes","fetching '%s', protocol '%s', method 'built-in'",name,protocol)
                end
                io.flush()
                handler(protocol,name,cachename)
            else
                if trace_schemes then
                    logs.report("schemes","fetching '%s', protocol '%s', method 'curl'",name,protocol)
                end
                io.flush()
                schemes.curl(name,cachename)
            end
        end
        if io.exists(cachename) then
            cached[name] = cachename
            if trace_schemes then
                logs.report("schemes","using cached '%s', protocol '%s', cachename '%s'",name,protocol,cachename)
            end
        else
            cached[name] = ""
            if trace_schemes then
                logs.report("schemes","using missing '%s', protocol '%s'",name,protocol)
            end
        end
        loaded[protocol] = loaded[protocol] + 1
        statistics.stoptiming(schemes)
    else
        if trace_schemes then
            logs.report("schemes","reusing '%s', protocol '%s'",name,protocol)
        end
        reused[protocol] = reused[protocol] + 1
    end
    return cached[name]
end

function finders.schemes(protocol,filename,handler)
    local foundname = schemes.fetch(protocol,filename,handler)
    return finders.generic(protocol,foundname,filetype)
end

function openers.schemes(protocol,filename)
    return openers.generic(protocol,filename)
end

function loaders.schemes(protocol,filename)
    return loaders.generic(protocol,filename)
end

-- could be metatable

function schemes.install(protocol,handler)
    loaded [protocol] = 0
    reused [protocol] = 0
    finders[protocol] = function (filename,filetype) return finders.schemes(protocol,filename,handler) end
    openers[protocol] = function (filename)          return openers.schemes(protocol,filename)         end
    loaders[protocol] = function (filename)          return loaders.schemes(protocol,filename)         end
end

local function http_handler(protocol,name,cachename)
    local tempname = cachename .. ".tmp"
    local f = io.open(tempname,"wb")
    local status, message = http.request {
        url = name,
        sink = ltn12.sink.file(f)
    }
    if not status then
        os.remove(tempname)
    else
        os.remove(cachename)
        os.rename(tempname,cachename)
    end
end

schemes.install('http',http_handler)
schemes.install('https')
schemes.install('ftp')

statistics.register("scheme handling time", function()
    local l, r = { }, { }
    for k, v in table.sortedhash(loaded) do
        if v > 0 then
            l[#l+1] = k .. ":" .. v
        end
    end
    for k, v in table.sortedhash(reused) do
        if v > 0 then
            r[#r+1] = k .. ":" .. v
        end
    end
    local n = #l + #r
    if n > 0 then
        l = (#l > 0 and concat(l)) or "none"
        r = (#r > 0 and concat(r)) or "none"
        return format("%s seconds, %s processed, threshold %s seconds, loaded: %s, reused: %s",
            statistics.elapsedtime(schemes), n, schemes.threshold, l, r)
    else
        return nil
    end
end)

--~ trace_schemes = true
--~ print(schemes.fetch("http","http://www.pragma-ade.com/show-man.pdf",http_handler))
