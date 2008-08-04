-- filename : l-file.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-file'] = 1.001

if not file then file = { } end

function file.removesuffix(filename)
    return (filename:gsub("%.[%a%d]+$",""))
end

file.stripsuffix = file.removesuffix

function file.addsuffix(filename, suffix)
    if not filename:find("%.[%a%d]+$") then
        return filename .. "." .. suffix
    else
        return filename
    end
end

function file.replacesuffix(filename, suffix)
    return (filename:gsub("%.[%a%d]+$","")) .. "." .. suffix
end

function file.dirname(name)
    return name:match("^(.+)[/\\].-$") or ""
end

function file.basename(name)
    return name:match("^.+[/\\](.-)$") or name
end

function file.nameonly(name)
    return ((name:match("^.+[/\\](.-)$") or name):gsub("%..*$",""))
end

function file.extname(name)
    return name:match("^.+%.([^/\\]-)$") or  ""
end

file.suffix = file.extname

--~ function file.join(...)
--~     local t = { ... }
--~     for i=1,#t do
--~         t[i] = (t[i]:gsub("\\","/")):gsub("/+$","")
--~     end
--~     return table.concat(t,"/")
--~ end

--~ print(file.join("x/","/y"))
--~ print(file.join("http://","/y"))
--~ print(file.join("http://a","/y"))
--~ print(file.join("http:///a","/y"))
--~ print(file.join("//nas-1","/y"))

function file.join(...)
    local pth = table.concat({...},"/")
    pth = pth:gsub("\\","/")
    local a, b = pth:match("^(.*://)(.*)$")
    if a and b then
        return a .. b:gsub("//+","/")
    end
    a, b = pth:match("^(//)(.*)$")
    if a and b then
        return a .. b:gsub("//+","/")
    end
    return (pth:gsub("//+","/"))
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

function file.iswritable(name)
    local a = lfs.attributes(name)
    return a and a.permissions:sub(2,2) == "w"
end

function file.isreadable(name)
    local a = lfs.attributes(name)
    return a and a.permissions:sub(1,1) == "r"
end

--~ function file.split_path(str)
--~     if str:find(';') then
--~         return str:splitchr(";")
--~     else
--~         return str:splitchr(io.pathseparator)
--~     end
--~ end

-- todo: lpeg

function file.split_path(str)
    local t = { }
    str = str:gsub("\\", "/")
    str = str:gsub("(%a):([;/])", "%1\001%2")
    for name in str:gmatch("([^;:]+)") do
        if name ~= "" then
            name = name:gsub("\001",":")
            t[#t+1] = name
        end
    end
    return t
end

function file.join_path(tab)
    return table.concat(tab,io.pathseparator) -- can have trailing //
end

function file.collapse_path(str)
    str = str:gsub("/%./","/")
    local n, m = 1, 1
    while n > 0 or m > 0 do
        str, n = str:gsub("[^/%.]+/%.%.$","")
        str, m = str:gsub("[^/%.]+/%.%./","")
    end
    str = str:gsub("([^/])/$","%1")
    str = str:gsub("^%./","")
    str = str:gsub("/%.$","")
    if str == "" then str = "." end
    return str
end

--~ print(file.collapse_path("a/./b/.."))
--~ print(file.collapse_path("a/aa/../b/bb"))
--~ print(file.collapse_path("a/../.."))
--~ print(file.collapse_path("a/.././././b/.."))
--~ print(file.collapse_path("a/./././b/.."))
--~ print(file.collapse_path("a/b/c/../.."))

function file.robustname(str)
    return (str:gsub("[^%a%d%/%-%.\\]+","-"))
end

file.readdata = io.loaddata
file.savedata = io.savedata

function file.copy(oldname,newname)
    file.savedata(newname,io.loaddata(oldname))
end

-- lpeg variants, slightly faster, not always

--~ local period    = lpeg.P(".")
--~ local slashes   = lpeg.S("\\/")
--~ local noperiod  = 1-period
--~ local noslashes = 1-slashes
--~ local name      = noperiod^1

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.C(noperiod^1) * -1

--~ function file.extname(name)
--~     return pattern:match(name) or ""
--~ end

--~ local pattern = lpeg.Cs(((period * noperiod^1 * -1)/"" + 1)^1)

--~ function file.removesuffix(name)
--~     return pattern:match(name)
--~ end

--~ file.stripsuffix = file.removesuffix

--~ local pattern = (noslashes^0 * slashes)^1 * lpeg.C(noslashes^1) * -1

--~ function file.basename(name)
--~     return pattern:match(name) or name
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * lpeg.Cp() * noslashes^1 * -1

--~ function file.dirname(name)
--~     local p = pattern:match(name)
--~     if p then
--~         return name:sub(1,p-2)
--~     else
--~         return ""
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.Cp() * noperiod^1 * -1

--~ function file.addsuffix(name, suffix)
--~     local p = pattern:match(name)
--~     if p then
--~         return name
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.Cp() * noperiod^1 * -1

--~ function file.replacesuffix(name,suffix)
--~     local p = pattern:match(name)
--~     if p then
--~         return name:sub(1,p-2) .. "." .. suffix
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * lpeg.Cp() * ((noperiod^1 * period)^1 * lpeg.Cp() + lpeg.P(true)) * noperiod^1 * -1

--~ function file.nameonly(name)
--~     local a, b = pattern:match(name)
--~     if b then
--~         return name:sub(a,b-2)
--~     elseif a then
--~         return name:sub(a)
--~     else
--~         return name
--~     end
--~ end

--~ local test = file.extname
--~ local test = file.stripsuffix
--~ local test = file.basename
--~ local test = file.dirname
--~ local test = file.addsuffix
--~ local test = file.replacesuffix
--~ local test = file.nameonly

--~ print(1,test("./a/b/c/abd.def.xxx","!!!"))
--~ print(2,test("./../b/c/abd.def.xxx","!!!"))
--~ print(3,test("a/b/c/abd.def.xxx","!!!"))
--~ print(4,test("a/b/c/def.xxx","!!!"))
--~ print(5,test("a/b/c/def","!!!"))
--~ print(6,test("def","!!!"))
--~ print(7,test("def.xxx","!!!"))

--~ local tim = os.clock() for i=1,250000 do local ext = test("abd.def.xxx","!!!") end print(os.clock()-tim)
