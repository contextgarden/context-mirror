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

local resolvers = resolvers

resolvers.locators     = { notfound = { nil } }  -- locate databases
resolvers.hashers      = { notfound = { nil } }  -- load databases
resolvers.generators   = { notfound = { nil } }  -- generate databases

function resolvers.splitmethod(filename)
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
    filename = file.collapse_path(filename)
    local specification = (type(filename) == "string" and resolvers.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    local resolver = resolvers[what]
    if resolver[scheme] then
        if trace_locating then
            report_resolvers("handler '%s' -> '%s' -> '%s'",specification.original,what,table.sequenced(specification))
        end
        return resolver[scheme](filename,filetype)
    else
        return resolver.tex(filename,filetype) -- todo: specification
    end
end

