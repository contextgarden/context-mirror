if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \input tree://oeps1/**/oeps.tex

local find, gsub = string.find, string.gsub
local unpack = unpack or table.unpack

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

local done, found = { }, { }

function finders.tree(specification,filetype)
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
        fnd = unpack(finders.notfound)
        found[specification] = fnd
    end
    return fnd
end

openers.tree = openers.generic
loaders.tree = loaders.generic
