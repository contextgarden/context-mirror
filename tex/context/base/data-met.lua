if not modules then modules = { } end modules ['data-met'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, format = string.find, string.format
local sequenced = table.sequenced
local addurlscheme, urlhashed = url.addscheme, url.hashed

local trace_locating = false

trackers.register("resolvers.locating", function(v) trace_methods = v end)
trackers.register("resolvers.methods",  function(v) trace_methods = v end)

--~ trace_methods = true

local report_resolvers = logs.new("resolvers")

local allocate = utilities.storage.allocate

local resolvers = resolvers

local registered = { }

local function splitmethod(filename) -- todo: filetype in specification
    if not filename then
        return { scheme = "unknown", original = filename }
    end
    if type(filename) == "table" then
        return filename -- already split
    end
    filename = file.collapsepath(filename)
    if not find(filename,"://") then
        return { scheme = "file", path = filename, original = filename, filename = filename }
    end
    local specification = url.hashed(filename)
    if not specification.scheme or specification.scheme == "" then
        return { scheme = "file", path = filename, original = filename, filename = filename }
    else
        return specification
    end
end

resolvers.splitmethod = splitmethod -- bad name but ok

-- the second argument is always analyzed (saves time later on) and the original
-- gets passed as original but also as argument

local function methodhandler(what,first,...) -- filename can be nil or false
    local method = registered[what]
    if method then
        local how, namespace = method.how, method.namespace
        if how == "uri" or how == "url" then
            local specification = splitmethod(first)
            local scheme = specification.scheme
            local resolver = namespace and namespace[scheme]
            if resolver then
                if trace_methods then
                    report_resolvers("resolver: method=%s, how=%s, scheme=%s, argument=%s",what,how,scheme,first)
                end
                return resolver(specification,...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_resolvers("resolver: method=%s, how=%s, default, argument=%s",what,how,first)
                    end
                    return resolver(specification,...)
                elseif trace_methods then
                    report_resolvers("resolver: method=%s, how=%s, no handler",what,how)
                end
            end
        elseif how == "tag" then
            local resolver = namespace and namespace[first]
            if resolver then
                if trace_methods then
                    report_resolvers("resolver: method=%s, how=%s, tag=%s",what,how,first)
                end
                return resolver(...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_resolvers("resolver: method=%s, how=%s, default",what,how)
                    end
                    return resolver(...)
                elseif trace_methods then
                    report_resolvers("resolver: method=%s, how=%s, unknown",what,how)
                end
            end
        end
    else
        report_resolvers("resolver: method=%s, unknown",what)
    end
end

resolvers.methodhandler = methodhandler

function resolvers.registermethod(name,namespace,how)
    registered[name] = { how = how or "tag", namespace = namespace }
    namespace["byscheme"] = function(scheme,filename,...)
        if scheme == "file" then
            return methodhandler(name,filename,...)
        else
            return methodhandler(name,addurlscheme(filename,scheme),...)
        end
    end
end

local concatinators = allocate { notfound = file.join       }  -- concatinate paths
local locators      = allocate { notfound = function() end  }  -- locate databases
local hashers       = allocate { notfound = function() end  }  -- load databases
local generators    = allocate { notfound = function() end  }  -- generate databases

resolvers.concatinators = concatinators
resolvers.locators      = locators
resolvers.hashers       = hashers
resolvers.generators    = generators

local registermethod = resolvers.registermethod

registermethod("concatinators",concatinators,"tag")
registermethod("locators",     locators,     "uri")
registermethod("hashers",      hashers,      "uri")
registermethod("generators",   generators,   "uri")
