if not modules then modules = { } end modules ['data-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_files = logs.reporter("resolvers","files")

local resolvers = resolvers

local finders, openers, loaders, savers = resolvers.finders, resolvers.openers, resolvers.loaders, resolvers.savers
local locators, hashers, generators, concatinators = resolvers.locators, resolvers.hashers, resolvers.generators, resolvers.concatinators

local checkgarbage = utilities.garbagecollector and utilities.garbagecollector.check

function locators.file(specification)
    local name = specification.filename
    local realname = resolvers.resolve(name) -- no shortcut
    if realname and realname ~= '' and lfs.isdir(realname) then
        if trace_locating then
            report_files("file locator %a found as %a",name,realname)
        end
        resolvers.appendhash('file',name,true) -- cache
    elseif trace_locating then
        report_files("file locator %a not found",name)
    end
end

function hashers.file(specification)
    local name = specification.filename
    local content = caches.loadcontent(name,'files')
    resolvers.registerfilehash(name,content,content==nil)
end

function generators.file(specification)
    local path = specification.filename
    local content = resolvers.scanfiles(path,false,true) -- scan once
--~     inspect(content)
    resolvers.registerfilehash(path,content,true)
end

concatinators.file = file.join

function finders.file(specification,filetype)
    local filename = specification.filename
    local foundname = resolvers.findfile(filename,filetype)
    if foundname and foundname ~= "" then
        if trace_locating then
            report_files("file finder: %a found",filename)
        end
        return foundname
    else
        if trace_locating then
            report_files("file finder: %a not found",filename)
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
                report_files("file opener: %a opened",filename)
            end
            return openers.helpers.textopener("file",filename,f)
        end
    end
    if trace_locating then
        report_files("file opener: %a not found",filename)
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
                report_files("file loader: %a loaded",filename)
            end
            local s = f:read("*a") -- io.readall(f) is faster but we never have large files here
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
        report_files("file loader: %a not found",filename)
    end
    return loaders.notfound()
end
