if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \input tree://oeps1/**/oeps.tex

local find, gsub, format = string.find, string.gsub, string.format
local unpack = unpack or table.unpack

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local done, found, notfound = { }, { }, resolvers.finders.notfound

function resolvers.finders.tree(specification,filetype)
    local fnd = found[specification]
    if not fnd then
        local spec = resolvers.splitmethod(specification).path or ""
        if spec ~= "" then
            local path, name = file.dirname(spec), file.basename(spec)
            if path == "" then path = "." end
            local hash = done[path]
            if not hash then
                local pattern = path .. "/*" -- we will use the proper splitter
                hash = dir.glob(pattern)
                done[path] = hash
            end
            local pattern = "/" .. gsub(name,"([%.%-%+])", "%%%1") .. "$"
            for k=1,#hash do
                local v = hash[k]
                if find(v,pattern) then
                    found[specification] = v
                    return v
                end
            end
        end
        fnd = unpack(notfound) -- unpack ? why not just notfound[1]
        found[specification] = fnd
    end
    return fnd
end

function resolvers.locators.tree(specification)
    local spec = resolvers.splitmethod(specification)
    local path = spec.path
    if path ~= '' and lfs.isdir(path) then
        if trace_locating then
            report_resolvers("tree locator '%s' found (%s)",path,specification)
        end
        resolvers.appendhash('tree',specification,path,false) -- don't cache
    elseif trace_locating then
        report_resolvers("tree locator '%s' not found",path)
    end
end

function resolvers.hashers.tree(tag,name)
    if trace_locating then
        report_resolvers("analysing tree '%s' as '%s'",name,tag)
    end
    -- todo: maybe share with done above
    local spec = resolvers.splitmethod(tag)
    local path = spec.path
    resolvers.generators.tex(path,tag) -- we share this with the normal tree analyzer
end

function resolvers.generators.tree(tag)
    local spec = resolvers.splitmethod(tag)
    local path = spec.path
    resolvers.generators.tex(path,tag) -- we share this with the normal tree analyzer
end

function resolvers.concatinators.tree(tag,path,name)
    return file.join(tag,path,name)
end

resolvers.isreadable.tree    = file.isreadable
resolvers.openers.tree       = resolvers.openers.generic
resolvers.loaders.tree       = resolvers.loaders.generic
