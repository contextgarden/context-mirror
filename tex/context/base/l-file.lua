-- filename : l-file.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-file'] = 1.001

if not file then file = { } end

function file.removesuffix(filename)
    return filename:gsub("%.%a+$", "")
end

function file.addsuffix(filename, suffix)
    if not filename:find("%.%a-$") then
        return filename .. "." .. suffix
    else
        return filename
    end
end

function file.replacesuffix(filename, suffix)
    return filename:gsub("%.%a+$", "." .. suffix)
end

function file.dirname(name)
    return name:match("^(.+)[/\\].-$") or ""
end

function file.basename(name)
    return name:match("^.+[/\\](.-)$") or name
end

function file.extname(name)
    return name:match("^.+%.(.-)$") or  ""
end

function file.join(...) -- args
    return (string.gsub(table.concat({...},"/"),"\\","/"))
end

function file.is_writable(name)
    local f = io.open(name, 'w')
    if f then
        f:close()
        return true
    else
        return false
    end
end

function file.is_readable(name)
    local f = io.open(name,'r')
    if f then
        f:close()
        return true
    else
        return false
    end
end

function file.split_path(str)
    if str:find(';') then
        return str:splitchr(";")
    else
        return str:splitchr(io.pathseparator)
    end
end

function file.join_path(tab)
    return table.concat(tab,io.pathseparator)
end

--~ print('test'           .. " == " .. file.collapse_path("test"))
--~ print("test/test"      .. " == " .. file.collapse_path("test/test"))
--~ print("test/test/test" .. " == " .. file.collapse_path("test/test/test"))
--~ print("test/test"      .. " == " .. file.collapse_path("test/../test/test"))
--~ print("test"           .. " == " .. file.collapse_path("test/../test"))
--~ print("../test"        .. " == " .. file.collapse_path("../test"))
--~ print("../test/"       .. " == " .. file.collapse_path("../test/"))
--~ print("a/a"            .. " == " .. file.collapse_path("a/b/c/../../a"))

function file.collapse_path(str)
    local ok = false
    while not ok do
        ok = true
        str, n = str:gsub("[^%./]+/%.%./", function(s)
            ok = false
            return ""
        end)
    end
    return (str:gsub("/%./","/"))
end

function file.robustname(str)
    return (str:gsub("[^%a%d%/%-%.\\]+","-"))
end

file.readdata = io.loaddata
file.savedata = io.savedata
