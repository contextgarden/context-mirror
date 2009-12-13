if not modules then modules = { } end modules ['l-dir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local find, gmatch = string.find, string.gmatch

dir = dir or { }

-- optimizing for no string.find (*) does not save time

local attributes = lfs.attributes
local walkdir    = lfs.dir

local function glob_pattern(path,patt,recurse,action)
    local ok, scanner
    if path == "/" then
        ok, scanner = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
    else
        ok, scanner = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
    end
    if ok and type(scanner) == "function" then
        if not find(path,"/$") then path = path .. '/' end
        for name in scanner do
            local full = path .. name
            local mode = attributes(full,'mode')
            if mode == 'file' then
                if find(full,patt) then
                    action(full)
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                glob_pattern(full,patt,recurse,action)
            end
        end
    end
end

dir.glob_pattern = glob_pattern

local function collect_pattern(path,patt,recurse,result)
    local ok, scanner
    result = result or { }
    if path == "/" then
        ok, scanner = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
    else
        ok, scanner = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
    end
    if ok and type(scanner) == "function" then
        if not find(path,"/$") then path = path .. '/' end
        for name in scanner do
            local full = path .. name
            local attr = attributes(full)
            local mode = attr.mode
            if mode == 'file' then
                if find(full,patt) then
                    result[name] = attr
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                attr.list = collect_pattern(full,patt,recurse)
                result[name] = attr
            end
        end
    end
    return result
end

dir.collect_pattern = collect_pattern

local P, S, R, C, Cc, Cs, Ct, Cv, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cv, lpeg.V

local pattern = Ct {
    [1] = (C(P(".") + P("/")^1) + C(R("az","AZ") * P(":") * P("/")^0) + Cc("./")) * V(2) * V(3),
    [2] = C(((1-S("*?/"))^0 * P("/"))^0),
    [3] = C(P(1)^0)
}

local filter = Cs ( (
    P("**") / ".*" +
    P("*")  / "[^/]*" +
    P("?")  / "[^/]" +
    P(".")  / "%%." +
    P("+")  / "%%+" +
    P("-")  / "%%-" +
    P(1)
)^0 )

local function glob(str,t)
    if type(str) == "table" then
        local t = t or { }
        for s=1,#str do
            glob(str[s],t)
        end
        return t
    elseif lfs.isfile(str) then
        local t = t or { }
        t[#t+1] = str
        return t
    else
        local split = pattern:match(str)
        if split then
            local t = t or { }
            local action = action or function(name) t[#t+1] = name end
            local root, path, base = split[1], split[2], split[3]
            local recurse = find(base,"%*%*")
            local start = root .. path
            local result = filter:match(start .. base)
            glob_pattern(start,result,recurse,action)
            return t
        else
            return { }
        end
    end
end

dir.glob = glob

--~ list = dir.glob("**/*.tif")
--~ list = dir.glob("/**/*.tif")
--~ list = dir.glob("./**/*.tif")
--~ list = dir.glob("oeps/**/*.tif")
--~ list = dir.glob("/oeps/**/*.tif")

local function globfiles(path,recurse,func,files) -- func == pattern or function
    if type(func) == "string" then
        local s = func -- alas, we need this indirect way
        func = function(name) return find(name,s) end
    end
    files = files or { }
    for name in walkdir(path) do
        if find(name,"^%.") then
            --- skip
        else
            local mode = attributes(name,'mode')
            if mode == "directory" then
                if recurse then
                    globfiles(path .. "/" .. name,recurse,func,files)
                end
            elseif mode == "file" then
                if func then
                    if func(name) then
                        files[#files+1] = path .. "/" .. name
                    end
                else
                    files[#files+1] = path .. "/" .. name
                end
            end
        end
    end
    return files
end

dir.globfiles = globfiles

-- t = dir.glob("c:/data/develop/context/sources/**/????-*.tex")
-- t = dir.glob("c:/data/develop/tex/texmf/**/*.tex")
-- t = dir.glob("c:/data/develop/context/texmf/**/*.tex")
-- t = dir.glob("f:/minimal/tex/**/*")
-- print(dir.ls("f:/minimal/tex/**/*"))
-- print(dir.ls("*.tex"))

function dir.ls(pattern)
    return table.concat(glob(pattern),"\n")
end

--~ mkdirs("temp")
--~ mkdirs("a/b/c")
--~ mkdirs(".","/a/b/c")
--~ mkdirs("a","b","c")

local make_indeed = true -- false

if string.find(os.getenv("PATH"),";") then

    function dir.mkdirs(...)
        local str, pth = "", ""
        for _, s in ipairs({...}) do
            if s ~= "" then
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        local first, middle, last
        local drive = false
        first, middle, last = str:match("^(//)(//*)(.*)$")
        if first then
            -- empty network path == local path
        else
            first, last = str:match("^(//)/*(.-)$")
            if first then
                middle, last = str:match("([^/]+)/+(.-)$")
                if middle then
                    pth = "//" .. middle
                else
                    pth = "//" .. last
                    last = ""
                end
            else
                first, middle, last = str:match("^([a-zA-Z]:)(/*)(.-)$")
                if first then
                    pth, drive = first .. middle, true
                else
                    middle, last = str:match("^(/*)(.-)$")
                    if not middle then
                        last = str
                    end
                end
            end
        end
        for s in gmatch(last,"[^/]+") do
            if pth == "" then
                pth = s
            elseif drive then
                pth, drive = pth .. s, false
            else
                pth = pth .. "/" .. s
            end
            if make_indeed and not lfs.isdir(pth) then
                lfs.mkdir(pth)
            end
        end
        return pth, (lfs.isdir(pth) == true)
    end

--~         print(dir.mkdirs("","","a","c"))
--~         print(dir.mkdirs("a"))
--~         print(dir.mkdirs("a:"))
--~         print(dir.mkdirs("a:/b/c"))
--~         print(dir.mkdirs("a:b/c"))
--~         print(dir.mkdirs("a:/bbb/c"))
--~         print(dir.mkdirs("/a/b/c"))
--~         print(dir.mkdirs("/aaa/b/c"))
--~         print(dir.mkdirs("//a/b/c"))
--~         print(dir.mkdirs("///a/b/c"))
--~         print(dir.mkdirs("a/bbb//ccc/"))

    function dir.expand_name(str)
        local first, nothing, last = str:match("^(//)(//*)(.*)$")
        if first then
            first = lfs.currentdir() .. "/"
            first = first:gsub("\\","/")
        end
        if not first then
            first, last = str:match("^(//)/*(.*)$")
        end
        if not first then
            first, last = str:match("^([a-zA-Z]:)(.*)$")
            if first and not find(last,"^/") then
                local d = lfs.currentdir()
                if lfs.chdir(first) then
                    first = lfs.currentdir()
                    first = first:gsub("\\","/")
                end
                lfs.chdir(d)
            end
        end
        if not first then
            first, last = lfs.currentdir(), str
            first = first:gsub("\\","/")
        end
        last = last:gsub("//","/")
        last = last:gsub("/%./","/")
        last = last:gsub("^/*","")
        first = first:gsub("/*$","")
        if last == "" then
            return first
        else
            return first .. "/" .. last
        end
    end

else

    function dir.mkdirs(...)
        local str, pth = "", ""
        for _, s in ipairs({...}) do
            if s ~= "" then
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        str = str:gsub("/+","/")
        if find(str,"^/") then
            pth = "/"
            for s in gmatch(str,"[^/]+") do
                local first = (pth == "/")
                if first then
                    pth = pth .. s
                else
                    pth = pth .. "/" .. s
                end
                if make_indeed and not first and not lfs.isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        else
            pth = "."
            for s in gmatch(str,"[^/]+") do
                pth = pth .. "/" .. s
                if make_indeed and not lfs.isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        end
        return pth, (lfs.isdir(pth) == true)
    end

--~         print(dir.mkdirs("","","a","c"))
--~         print(dir.mkdirs("a"))
--~         print(dir.mkdirs("/a/b/c"))
--~         print(dir.mkdirs("/aaa/b/c"))
--~         print(dir.mkdirs("//a/b/c"))
--~         print(dir.mkdirs("///a/b/c"))
--~         print(dir.mkdirs("a/bbb//ccc/"))

    function dir.expand_name(str)
        if not find(str,"^/") then
            str = lfs.currentdir() .. "/" .. str
        end
        str = str:gsub("//","/")
        str = str:gsub("/%./","/")
        return str
    end

end

dir.makedirs = dir.mkdirs
