if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \input tree://oeps1/**/oeps.tex

local find, gsub, format = string.find, string.gsub, string.format

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local done, found, notfound = { }, { }, resolvers.finders.notfound

function resolvers.finders.tree(specification)
    local spec = specification.filename
    local fnd = found[spec]
    if fnd == nil then
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
                    found[spec] = v
                    return v
                end
            end
        end
        fnd = notfound() -- false
        found[spec] = fnd
    end
    return fnd
end

function resolvers.locators.tree(specification)
    local name = specification.filename
    if name ~= '' and lfs.isdir(name) then
        if trace_locating then
            report_resolvers("tree locator '%s' found",name)
        end
        resolvers.appendhash('tree',name,false) -- don't cache
    elseif trace_locating then
        report_resolvers("tree locator '%s' not found",name)
    end
end

function resolvers.hashers.tree(specification)
    local name = specification.filename
    if trace_locating then
        report_resolvers("analysing tree '%s'",name)
    end
    resolvers.methodhandler("hashers",name)
end

resolvers.concatinators.tree = resolvers.concatinators.file
resolvers.generators.tree    = resolvers.generators.file
resolvers.openers.tree       = resolvers.openers.file
resolvers.loaders.tree       = resolvers.loaders.file
