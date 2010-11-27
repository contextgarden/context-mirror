if not modules then modules = { } end modules ['data-met'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)

local report_resolvers = logs.new("resolvers")

local allocate = utilities.storage.allocate

local resolvers = resolvers

resolvers.concatinators = allocate ()
resolvers.locators      = allocate { notfound = { nil } }  -- locate databases
resolvers.hashers       = allocate { notfound = { nil } }  -- load databases
resolvers.generators    = allocate { notfound = { nil } }  -- generate databases

function resolvers.splitmethod(filename) -- todo: trigger by suffix
    if not filename then
        return { } -- safeguard
    elseif type(filename) == "table" then
        return filename -- already split
    elseif not find(filename,"://") then
        return { scheme="file", path = filename, original = filename } -- quick hack
    else
        return url.hashed(filename)
    end
end

function resolvers.methodhandler(what, filename, filetype) -- ...
    filename = file.collapsepath(filename)
    local specification = (type(filename) == "string" and resolvers.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    local resolver = resolvers[what]
    if resolver[scheme] then
        if trace_locating then
            report_resolvers("using special handler for '%s' -> '%s' -> '%s'",specification.original,what,table.sequenced(specification))
        end
        return resolver[scheme](filename,filetype,specification) -- todo: query
    else
        if trace_locating then
            report_resolvers("no handler for '%s' -> '%s' -> '%s'",specification.original,what,table.sequenced(specification))
        end
        return resolver.tex(filename,filetype) -- todo: specification
    end
end

