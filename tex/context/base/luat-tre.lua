-- filename : luat-tre.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-tre'] = 1.001

-- \input tree://oeps1/**/oeps.tex

do

    local done, found = { }, { }

    function input.finders.tree(specification,filetype)
        local fnd = found[specification]
        if not fnd then
            local spec = input.splitmethod(specification).path or ""
            if spec ~= "" then
                local path, name = file.dirname(spec), file.basename(spec)
                if path == "" then path = "." end
                local hash = done[path]
                if not hash then
                    local pattern = path .. "/*" -- we will use the proper splitter
                    hash = dir.glob(pattern)
                    done[path] = hash
                end
                local pattern = "/" .. name:gsub("([%.%-%+])", "%%%1") .. "$"
                for k, v in pairs(hash) do
                    if v:find(pattern) then
                        found[specification] = v
                        return v
                    end
                end
            end
            fnd = unpack(input.finders.notfound)
            found[specification] = fnd
        end
        return fnd
    end

    input.openers.tree = input.openers.generic
    input.loaders.tree = input.loaders.generic

end
