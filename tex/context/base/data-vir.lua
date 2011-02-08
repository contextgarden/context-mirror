if not modules then modules = { } end modules ['data-vir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local trace_virtual  = false
local report_virtual = logs.new("resolvers","virtual")

trackers.register("resolvers.locating", function(v) trace_virtual = v end)
trackers.register("resolvers.virtual",  function(v) trace_virtual = v end)

local resolvers = resolvers

local finders, openers, loaders, savers = resolvers.finders, resolvers.openers, resolvers.loaders, resolvers.savers

local data, n, template = { }, 0, "virtual://%s.%s" -- hm, number can be query

function savers.virtual(specification,content)
    n = n + 1 -- one number for all namespaces
    local path = specification.path
    local filename = format(template,path ~= "" and path or "virtualfile",n)
    if trace_virtual then
        report_virtual("saver: file '%s' saved",filename)
    end
    data[filename] = content
    return filename
end

function finders.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("finder: file '%s' found",original)
        end
        return original
    else
        if trace_virtual then
            report_virtual("finder: unknown file '%s'",original)
        end
        return finders.notfound()
    end
end

function openers.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("opener, file '%s' opened",original)
        end
        data[original] = nil
        return openers.helpers.textopener("virtual",original,d)
    else
        if trace_virtual then
            report_virtual("opener, file '%s' not found",original)
        end
        return openers.notfound()
    end
end

function loaders.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("loader, file '%s' loaded",original)
        end
        data[original] = nil
        return true, d, #d
    end
    if trace_virtual then
        report_virtual("loader, file '%s' not loaded",original)
    end
    return loaders.notfound()
end
