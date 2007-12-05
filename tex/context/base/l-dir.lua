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
        local ok, scanner = xpcall(function() return lfs.dir(path) end, function() end) -- kepler safe
        if ok and type(scanner) == "function" then
            for name in scanner do
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

    function dir.globfiles(path,recurse,func,files)
        if type(func) == "string" then
            local s = func -- alas, we need this indirect way
            func = function(name) return name:find(s) end
        end
        files = files or { }
        for name in lfs.dir(path) do
            if name:find("^%.") then
                --- skip
            elseif lfs.attributes(name,'mode') == "directory" then
                if recurse then
                    dir.globfiles(path .. "/" .. name,recurse,func,files)
                end
            elseif func then
                if func(name) then
                    files[#files+1] = path .. "/" .. name
                end
            else
                files[#files+1] = path .. "/" .. name
            end
        end
        return files
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

    function dir.mkdirs(...)
        local pth, err, lst = "", false, table.concat({...},"/")
        for _, s in ipairs(lst:split("/")) do
            if pth == "" then
                pth = (s == "" and "/") or s
            else
                pth = pth .. "/" .. s
            end
            if s == "" then
                -- can be network path
            elseif not lfs.isdir(pth) then
                lfs.mkdir(pth)
            end
        end
        return pth, not err
    end

    dir.makedirs = dir.mkdirs

end
