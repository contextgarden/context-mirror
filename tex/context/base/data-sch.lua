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

local cleaners = { }

schemes.cleaners = cleaners

function cleaners.none(specification)
    return specification.original
end

function cleaners.strip(specification)
    return (gsub(specification.original,"[^%a%d%.]+","-"))
end

function cleaners.md5(specification)
    return file.addsuffix(md5.hex(specification.original),file.suffix(specification.path))
end

local cleaner = cleaners.strip

directives.register("schemes.cleanmethod", function(v) cleaner = cleaners[v] or cleaners.strip end)

function resolvers.schemes.cleanname(specification)
    local hash = cleaner(specification)
    if trace_schemes then
        report_schemes("hashing %s to %s",specification.original,hash)
    end
    return hash
end

local cached, loaded, reused, thresholds, handlers = { }, { }, { }, { }, { }

local function runcurl(name,cachename) -- will use sockets instead or the curl library
    local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name
    os.spawn(command)
end

local function fetch(specification)
    local original  = specification.original
    local scheme    = specification.scheme
    local cleanname = schemes.cleanname(specification)
    local cachename = caches.setfirstwritablefile(cleanname,"schemes")
    if not cached[original] then
        statistics.starttiming(schemes)
        if not io.exists(cachename) or (os.difftime(os.time(),lfs.attributes(cachename).modification) >
                                                            (thresholds[protocol] or schemes.threshold)) then
            cached[original] = cachename
            local handler = handlers[scheme]
            if handler then
                if trace_schemes then
                    report_schemes("fetching '%s', protocol '%s', method 'built-in'",original,scheme)
                end
                io.flush()
                handler(specification,cachename)
            else
                if trace_schemes then
                    report_schemes("fetching '%s', protocol '%s', method 'curl'",original,scheme)
                end
                io.flush()
                runcurl(original,cachename)
            end
        end
        if io.exists(cachename) then
            cached[original] = cachename
            if trace_schemes then
                report_schemes("using cached '%s', protocol '%s', cachename '%s'",original,scheme,cachename)
            end
        else
            cached[original] = ""
            if trace_schemes then
                report_schemes("using missing '%s', protocol '%s'",original,scheme)
            end
        end
        loaded[scheme] = loaded[scheme] + 1
        statistics.stoptiming(schemes)
    else
        if trace_schemes then
            report_schemes("reusing '%s', protocol '%s'",original,scheme)
        end
        reused[scheme] = reused[scheme] + 1
    end
    return cached[original]
end

local function finder(specification,filetype)
    return resolvers.methodhandler("finders",fetch(specification),filetype)
end

local opener = openers.file
local loader = loaders.file

local function install(scheme,handler,threshold)
    handlers  [scheme] = handler
    loaded    [scheme] = 0
    reused    [scheme] = 0
    finders   [scheme] = finder
    openers   [scheme] = opener
    loaders   [scheme] = loader
    thresholds[scheme] = threshold or schemes.threshold
end

schemes.install = install

local function http_handler(specification,cachename)
    local tempname = cachename .. ".tmp"
    local f = io.open(tempname,"wb")
    local status, message = http.request {
        url = specification.original,
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

install('http',http_handler)
install('https') -- see pod
install('ftp')

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
