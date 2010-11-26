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
local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

local trace_schemes = false  trackers.register("resolvers.schemes",function(v) trace_schemes = v end)

local report_schemes = logs.new("schemes")

local resolvers = resolvers

resolvers.schemes = resolvers.schemes or { }
local schemes     = resolvers.schemes
schemes.threshold = 24 * 60 * 60

directives.register("schemes.threshold", function(v) schemes.threshold = tonumber(v) or schemes.threshold end)

local cached, loaded, reused, thresholds = { }, { }, { }, { }

function schemes.curl(name,cachename) -- will use sockets instead or the curl library
    local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name -- no protocol .. "://"
    os.spawn(command)
end

function schemes.fetch(protocol,name,handler)
    local cleanname = gsub(name,"[^%a%d%.]+","-")
    local cachename = caches.setfirstwritablefile(cleanname,"schemes")
    if not cached[name] then
        statistics.starttiming(schemes)
        if not io.exists(cachename) or (os.difftime(os.time(),lfs.attributes(cachename).modification) >
                                                            (thresholds[protocol] or schemes.threshold)) then
            cached[name] = cachename
            if handler then
                if trace_schemes then
                    report_schemes("fetching '%s', protocol '%s', method 'built-in'",name,protocol)
                end
                io.flush()
                handler(protocol,name,cachename)
            else
                if trace_schemes then
                    report_schemes("fetching '%s', protocol '%s', method 'curl'",name,protocol)
                end
                io.flush()
                schemes.curl(name,cachename)
            end
        end
        if io.exists(cachename) then
            cached[name] = cachename
            if trace_schemes then
                report_schemes("using cached '%s', protocol '%s', cachename '%s'",name,protocol,cachename)
            end
        else
            cached[name] = ""
            if trace_schemes then
                report_schemes("using missing '%s', protocol '%s'",name,protocol)
            end
        end
        loaded[protocol] = loaded[protocol] + 1
        statistics.stoptiming(schemes)
    else
        if trace_schemes then
            report_schemes("reusing '%s', protocol '%s'",name,protocol)
        end
        reused[protocol] = reused[protocol] + 1
    end
    return cached[name]
end

function finders.schemes(protocol,filename,handler)
    local foundname = schemes.fetch(protocol,filename,handler)
    return finders.generic(protocol,foundname)
end

function openers.schemes(protocol,filename)
    return openers.generic(protocol,filename)
end

function loaders.schemes(protocol,filename)
    return loaders.generic(protocol,filename)
end

-- could be metatable and proper subtables

function schemes.install(protocol,handler,threshold)
    loaded    [protocol] = 0
    reused    [protocol] = 0
    finders   [protocol] = function (filename,filetype) return finders.schemes(protocol,filename,handler) end
    openers   [protocol] = function (filename)          return openers.schemes(protocol,filename)         end
    loaders   [protocol] = function (filename)          return loaders.schemes(protocol,filename)         end
    thresholds[protocol] = threshold or schemes.threshold
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
    return cachename
end

schemes.install('http',http_handler)
schemes.install('https')
schemes.install('ftp')

statistics.register("scheme handling time", function()
    local l, r, nl, nr = { }, { }, 0, 0
    for k, v in table.sortedhash(loaded) do
        if v > 0 then
            nl = nl + 1
            l[nl] = k .. ":" .. v
        end
    end
    for k, v in table.sortedhash(reused) do
        if v > 0 then
            nr = nr + 1
            r[nr] = k .. ":" .. v
        end
    end
    local n = nl + nr
    if n > 0 then
        l = (nl > 0 and concat(l)) or "none"
        r = (nr > 0 and concat(r)) or "none"
        return format("%s seconds, %s processed, threshold %s seconds, loaded: %s, reused: %s",
            statistics.elapsedtime(schemes), n, schemes.threshold, l, r)
    else
        return nil
    end
end)

--~ trace_schemes = true
--~ print(schemes.fetch("http","http://www.pragma-ade.com/show-man.pdf",http_handler))
