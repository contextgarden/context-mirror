if not modules then modules = { } end modules ['l-file'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup

file = file or { }

local concat = table.concat
local find, gmatch, match, gsub = string.find, string.gmatch, string.match, string.gsub

function file.removesuffix(filename)
    return (gsub(filename,"%.[%a%d]+$",""))
end

function file.addsuffix(filename, suffix)
    if not find(filename,"%.[%a%d]+$") then
        return filename .. "." .. suffix
    else
        return filename
    end
end

function file.replacesuffix(filename, suffix)
    return (gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
end

function file.dirname(name,default)
    return match(name,"^(.+)[/\\].-$") or (default or "")
end

function file.basename(name)
    return match(name,"^.+[/\\](.-)$") or name
end

function file.nameonly(name)
    return (gsub(match(name,"^.+[/\\](.-)$") or name,"%..*$",""))
end

function file.extname(name)
    return match(name,"^.+%.([^/\\]-)$") or  ""
end

file.suffix = file.extname

--~ print(file.join("x/","/y"))
--~ print(file.join("http://","/y"))
--~ print(file.join("http://a","/y"))
--~ print(file.join("http:///a","/y"))
--~ print(file.join("//nas-1","/y"))

function file.join(...)
    local pth = concat({...},"/")
    pth = gsub(pth,"\\","/")
    local a, b = match(pth,"^(.*://)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    a, b = match(pth,"^(//)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    return (gsub(pth,"//+","/"))
end

function file.iswritable(name)
    local a = lfs.attributes(name) or lfs.attributes(file.dirname(name,"."))
    return a and a.permissions:sub(2,2) == "w"
end

function file.isreadable(name)
    local a = lfs.attributes(name)
    return a and a.permissions:sub(1,1) == "r"
end

file.is_readable = file.isreadable
file.is_writable = file.iswritable

-- todo: lpeg

--~ function file.split_path(str)
--~     local t = { }
--~     str = gsub(str,"\\", "/")
--~     str = gsub(str,"(%a):([;/])", "%1\001%2")
--~     for name in gmatch(str,"([^;:]+)") do
--~         if name ~= "" then
--~             t[#t+1] = gsub(name,"\001",":")
--~         end
--~     end
--~     return t
--~ end

local checkedsplit = string.checkedsplit

function file.split_path(str,separator)
    str = gsub(str,"\\","/")
    return checkedsplit(str,separator or io.pathseparator)
end

function file.join_path(tab)
    return concat(tab,io.pathseparator) -- can have trailing //
end

function file.collapse_path(str)
    str = gsub(str,"/%./","/")
    local n, m = 1, 1
    while n > 0 or m > 0 do
        str, n = gsub(str,"[^/%.]+/%.%.$","")
        str, m = gsub(str,"[^/%.]+/%.%./","")
    end
    str = gsub(str,"([^/])/$","%1")
    str = gsub(str,"^%./","")
    str = gsub(str,"/%.$","")
    if str == "" then str = "." end
    return str
end

--~ print(file.collapse_path("/a"))
--~ print(file.collapse_path("a/./b/.."))
--~ print(file.collapse_path("a/aa/../b/bb"))
--~ print(file.collapse_path("a/../.."))
--~ print(file.collapse_path("a/.././././b/.."))
--~ print(file.collapse_path("a/./././b/.."))
--~ print(file.collapse_path("a/b/c/../.."))

function file.robustname(str)
    return (gsub(str,"[^%a%d%/%-%.\\]+","-"))
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

-- also rewrite previous

local letter    = lpeg.R("az","AZ") + lpeg.S("_-+")
local separator = lpeg.P("://")

local qualified = lpeg.P(".")^0 * lpeg.P("/") + letter*lpeg.P(":") + letter^1*separator + letter^1 * lpeg.P("/")
local rootbased = lpeg.P("/") + letter*lpeg.P(":")

-- ./name ../name  /name c: :// name/name

function file.is_qualified_path(filename)
    return qualified:match(filename) ~= nil
end

function file.is_rootbased_path(filename)
    return rootbased:match(filename) ~= nil
end

local slash  = lpeg.S("\\/")
local period = lpeg.P(".")
local drive  = lpeg.C(lpeg.R("az","AZ")) * lpeg.P(":")
local path   = lpeg.C(((1-slash)^0 * slash)^0)
local suffix = period * lpeg.C(lpeg.P(1-period)^0 * lpeg.P(-1))
local base   = lpeg.C((1-suffix)^0)

local pattern = (drive + lpeg.Cc("")) * (path + lpeg.Cc("")) * (base + lpeg.Cc("")) * (suffix + lpeg.Cc(""))

function file.splitname(str) -- returns drive, path, base, suffix
    return pattern:match(str)
end

-- function test(t) for k, v in pairs(t) do print(v, "=>", file.splitname(v)) end end
--
-- test { "c:", "c:/aa", "c:/aa/bb", "c:/aa/bb/cc", "c:/aa/bb/cc.dd", "c:/aa/bb/cc.dd.ee" }
-- test { "c:", "c:aa", "c:aa/bb", "c:aa/bb/cc", "c:aa/bb/cc.dd", "c:aa/bb/cc.dd.ee" }
-- test { "/aa", "/aa/bb", "/aa/bb/cc", "/aa/bb/cc.dd", "/aa/bb/cc.dd.ee" }
-- test { "aa", "aa/bb", "aa/bb/cc", "aa/bb/cc.dd", "aa/bb/cc.dd.ee" }
