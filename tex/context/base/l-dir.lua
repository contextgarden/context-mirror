-- filename : l-dir.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-dir'] = 1.001

dir = { }

-- optimizing for no string.find (*) does not save time

if lfs then

    function dir.glob_pattern(path,patt,recurse,action)
        for name in lfs.dir(path) do
            local full = path .. '/' .. name
            local mode = lfs.attributes(full,'mode')
            if mode == 'file' then
                if name:find(patt) then
                    action(full)
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                dir.glob_pattern(full,patt,recurse,action)
            end
        end
    end

    function dir.glob(pattern, action)
        local t = { }
        local action = action or function(name) table.insert(t,name) end
        local path, patt = pattern:match("^(.*)/*%*%*/*(.-)$")
        local recurse = path and patt
        if not recurse then
            path, patt = pattern:match("^(.*)/(.-)$")
            if not (path and patt) then
                path, patt = '.', pattern
            end
        end
        patt = patt:gsub("([%.%-%+])", "%%%1")
        patt = patt:gsub("%*", ".*")
        patt = patt:gsub("%?", ".")
        patt = "^" .. patt .. "$"
     -- print('path: ' .. path .. ' | pattern: ' .. patt .. ' | recurse: ' .. tostring(recurse))
        dir.glob_pattern(path,patt,recurse,action)
        return t
    end

    -- t = dir.glob("c:/data/develop/context/sources/**/????-*.tex")
    -- t = dir.glob("c:/data/develop/tex/texmf/**/*.tex")
    -- t = dir.glob("c:/data/develop/context/texmf/**/*.tex")
    -- t = dir.glob("f:/minimal/tex/**/*")
    -- print(dir.ls("f:/minimal/tex/**/*"))
    -- print(dir.ls("*.tex"))

    function dir.ls(pattern)
        return table.concat(dir.glob(pattern),"\n")
    end

    --~ mkdirs("temp")
    --~ mkdirs("a/b/c")
    --~ mkdirs(".","/a/b/c")
    --~ mkdirs("a","b","c")

    function dir.mkdirs(...) -- root,... or ... ; root is not split
        local pth, err = "", false
        for k,v in pairs({...}) do
            if k == 1 then
                if not lfs.isdir(v) then
                 -- print("no root path " .. v)
                    err = true
                else
                    pth = v
                end
            elseif lfs.isdir(pth .. "/" .. v) then
                pth = pth .. "/" .. v
            else
                for _,s in pairs(v:split("/")) do
                    pth = pth .. "/" .. s
                    if not lfs.isdir(pth) then
                        ok = lfs.mkdir(pth)
                        if not lfs.isdir(pth) then
                            err = true
                        end
                    end
                    if err then break end
                end
            end
            if err then break end
        end
        return pth, not err
    end

end
