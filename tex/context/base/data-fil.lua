if not modules then modules = { } end modules ['data-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local finders, openers, loaders, savers = resolvers.finders, resolvers.openers, resolvers.loaders, resolvers.savers
local locators, hashers, generators, concatinators = resolvers.locators, resolvers.hashers, resolvers.generators, resolvers.concatinators

local checkgarbage = utilities.garbagecollector and utilities.garbagecollector.check

function locators.file(specification)
    local name = specification.filename
    if name and name ~= '' and lfs.isdir(name) then
        if trace_locating then
            report_resolvers("file locator '%s' found",name)
        end
        resolvers.appendhash('file',name,true) -- cache
    elseif trace_locating then
        report_resolvers("file locator '%s' not found",name)
    end
end

function hashers.file(specification)
    local name = specification.filename
    local content = caches.loadcontent(name,'files')
    resolvers.registerfilehash(name,content,content==nil)
end

function generators.file(specification)
    local name = specification.filename
    local content = resolvers.scanfiles(name)
    resolvers.registerfilehash(name,content,true)
end

concatinators.file = file.join

function finders.file(specification,filetype)
    local filename = specification.filename
    local foundname = resolvers.findfile(filename,filetype)
    if foundname and foundname ~= "" then
        if trace_locating then
            report_resolvers("file finder: '%s' found",filename)
        end
        return foundname
    else
        if trace_locating then
            report_resolvers("file finder: %s' not found",filename)
        end
        return finders.notfound()
    end
end

-- The default textopener will be overloaded later on.

function openers.helpers.textopener(tag,filename,f)
    return {
        reader = function()                           return f:read () end,
        close  = function() logs.show_close(filename) return f:close() end,
    }
end

function openers.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = io.open(filename,"r")
        if f then
            if trace_locating then
                report_resolvers("file opener, '%s' opened",filename)
            end
            return openers.helpers.textopener("file",filename,f)
        end
    end
    if trace_locating then
        report_resolvers("file opener, '%s' not found",filename)
    end
    return openers.notfound()
end

function loaders.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = io.open(filename,"rb")
        if f then
            logs.show_load(filename)
            if trace_locating then
                report_resolvers("file loader, '%s' loaded",filename)
            end
            local s = f:read("*a")
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    if trace_locating then
        report_resolvers("file loader, '%s' not found",filename)
    end
    return loaders.notfound()
end
