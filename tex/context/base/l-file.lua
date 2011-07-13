if not modules then modules = { } end modules ['l-file'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup

file       = file or { }
local file = file

local insert, concat = table.insert, table.concat
local find, gmatch, match, gsub, sub, char, lower = string.find, string.gmatch, string.match, string.gsub, string.sub, string.char, string.lower
local lpegmatch = lpeg.match
local getcurrentdir, attributes = lfs.currentdir, lfs.attributes

local P, R, S, C, Cs, Cp, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cp, lpeg.Cc

local function dirname(name,default)
    return match(name,"^(.+)[/\\].-$") or (default or "")
end

local function basename(name)
    return match(name,"^.+[/\\](.-)$") or name
end

local function nameonly(name)
    return (gsub(match(name,"^.+[/\\](.-)$") or name,"%..*$",""))
end

local function extname(name,default)
    return match(name,"^.+%.([^/\\]-)$") or default or ""
end

local function splitname(name)
    local n, s = match(name,"^(.+)%.([^/\\]-)$")
    return n or name, s or ""
end

file.basename = basename
file.dirname  = dirname
file.nameonly = nameonly
file.extname  = extname
file.suffix   = extname

function file.removesuffix(filename)
    return (gsub(filename,"%.[%a%d]+$",""))
end

function file.addsuffix(filename, suffix, criterium)
    if not suffix or suffix == "" then
        return filename
    elseif criterium == true then
        return filename .. "." .. suffix
    elseif not criterium then
        local n, s = splitname(filename)
        if not s or s == "" then
            return filename .. "." .. suffix
        else
            return filename
        end
    else
        local n, s = splitname(filename)
        if s and s ~= "" then
            local t = type(criterium)
            if t == "table" then
                -- keep if in criterium
                for i=1,#criterium do
                    if s == criterium[i] then
                        return filename
                    end
                end
            elseif t == "string" then
                -- keep if criterium
                if s == criterium then
                    return filename
                end
            end
        end
        return n .. "." .. suffix
    end
end

--~ print("1 " .. file.addsuffix("name","new")                   .. " -> name.new")
--~ print("2 " .. file.addsuffix("name.old","new")               .. " -> name.old")
--~ print("3 " .. file.addsuffix("name.old","new",true)          .. " -> name.old.new")
--~ print("4 " .. file.addsuffix("name.old","new","new")         .. " -> name.new")
--~ print("5 " .. file.addsuffix("name.old","new","old")         .. " -> name.old")
--~ print("6 " .. file.addsuffix("name.old","new","foo")         .. " -> name.new")
--~ print("7 " .. file.addsuffix("name.old","new",{"foo","bar"}) .. " -> name.new")
--~ print("8 " .. file.addsuffix("name.old","new",{"old","bar"}) .. " -> name.old")

function file.replacesuffix(filename, suffix)
    return (gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
end

--~ function file.join(...)
--~     local pth = concat({...},"/")
--~     pth = gsub(pth,"\\","/")
--~     local a, b = match(pth,"^(.*://)(.*)$")
--~     if a and b then
--~         return a .. gsub(b,"//+","/")
--~     end
--~     a, b = match(pth,"^(//)(.*)$")
--~     if a and b then
--~         return a .. gsub(b,"//+","/")
--~     end
--~     return (gsub(pth,"//+","/"))
--~ end

local trick_1 = char(1)
local trick_2 = "^" .. trick_1 .. "/+"

function file.join(...) -- rather dirty
    local lst = { ... }
    local a, b = lst[1], lst[2]
    if not a or a == "" then -- not a added
        lst[1] = trick_1
    elseif b and find(a,"^/+$") and find(b,"^/") then
        lst[1] = ""
        lst[2] = gsub(b,"^/+","")
    end
    local pth = concat(lst,"/")
    pth = gsub(pth,"\\","/")
    local a, b = match(pth,"^(.*://)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    a, b = match(pth,"^(//)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    pth = gsub(pth,trick_2,"")
    return (gsub(pth,"//+","/"))
end

--~ print(file.join("//","/y"))
--~ print(file.join("/","/y"))
--~ print(file.join("","/y"))
--~ print(file.join("/x/","/y"))
--~ print(file.join("x/","/y"))
--~ print(file.join("http://","/y"))
--~ print(file.join("http://a","/y"))
--~ print(file.join("http:///a","/y"))
--~ print(file.join("//nas-1","/y"))

-- We should be able to use:
--
-- function file.is_writable(name)
--     local a = attributes(name) or attributes(dirname(name,"."))
--     return a and sub(a.permissions,2,2) == "w"
-- end
--
-- But after some testing Taco and I came up with:

function file.is_writable(name)
    if lfs.isdir(name) then
        name = name .. "/m_t_x_t_e_s_t.tmp"
        local f = io.open(name,"wb")
        if f then
            f:close()
            os.remove(name)
            return true
        end
    elseif lfs.isfile(name) then
        local f = io.open(name,"ab")
        if f then
            f:close()
            return true
        end
    else
        local f = io.open(name,"ab")
        if f then
            f:close()
            os.remove(name)
            return true
        end
    end
    return false
end

function file.is_readable(name)
    local a = attributes(name)
    return a and sub(a.permissions,1,1) == "r"
end

file.isreadable = file.is_readable -- depricated
file.iswritable = file.is_writable -- depricated

-- todo: lpeg \\ / .. does not save much

local checkedsplit = string.checkedsplit

function file.splitpath(str,separator) -- string
    str = gsub(str,"\\","/")
    return checkedsplit(str,separator or io.pathseparator)
end

function file.joinpath(tab,separator) -- table
    return concat(tab,separator or io.pathseparator) -- can have trailing //
end

-- we can hash them weakly

--~ function file.collapsepath(str) -- fails on b.c/..
--~     str = gsub(str,"\\","/")
--~     if find(str,"/") then
--~         str = gsub(str,"^%./",(gsub(getcurrentdir(),"\\","/")) .. "/") -- ./xx in qualified
--~         str = gsub(str,"/%./","/")
--~         local n, m = 1, 1
--~         while n > 0 or m > 0 do
--~             str, n = gsub(str,"[^/%.]+/%.%.$","")
--~             str, m = gsub(str,"[^/%.]+/%.%./","")
--~         end
--~         str = gsub(str,"([^/])/$","%1")
--~     --  str = gsub(str,"^%./","") -- ./xx in qualified
--~         str = gsub(str,"/%.$","")
--~     end
--~     if str == "" then str = "." end
--~     return str
--~ end
--~
--~ The previous one fails on "a.b/c"  so Taco came up with a split based
--~ variant. After some skyping we got it sort of compatible with the old
--~ one. After that the anchoring to currentdir was added in a better way.
--~ Of course there are some optimizations too. Finally we had to deal with
--~ windows drive prefixes and thinsg like sys://.

function file.collapsepath(str,anchor)
    if anchor and not find(str,"^/") and not find(str,"^%a:") then
        str = getcurrentdir() .. "/" .. str
    end
    if str == "" or str =="." then
        return "."
    elseif find(str,"^%.%.") then
        str = gsub(str,"\\","/")
        return str
    elseif not find(str,"%.") then
        str = gsub(str,"\\","/")
        return str
    end
    str = gsub(str,"\\","/")
    local starter, rest = match(str,"^(%a+:/*)(.-)$")
    if starter then
        str = rest
    end
    local oldelements = checkedsplit(str,"/")
    local newelements = { }
    local i = #oldelements
    while i > 0 do
        local element = oldelements[i]
        if element == '.' then
            -- do nothing
        elseif element == '..' then
            local n = i -1
            while n > 0 do
                local element = oldelements[n]
                if element ~= '..' and element ~= '.' then
                    oldelements[n] = '.'
                    break
                else
                    n = n - 1
                end
             end
            if n < 1 then
               insert(newelements,1,'..')
            end
        elseif element ~= "" then
            insert(newelements,1,element)
        end
        i = i - 1
    end
    if #newelements == 0 then
        return starter or "."
    elseif starter then
        return starter .. concat(newelements, '/')
    elseif find(str,"^/") then
        return "/" .. concat(newelements,'/')
    else
        return concat(newelements, '/')
    end
end

--~ local function test(str)
--~    print(string.format("%-20s %-15s %-15s",str,file.collapsepath(str),file.collapsepath(str,true)))
--~ end
--~ test("a/b.c/d") test("b.c/d") test("b.c/..")
--~ test("/") test("c:/..") test("sys://..")
--~ test("") test("./") test(".") test("..") test("./..") test("../..")
--~ test("a") test("./a") test("/a") test("a/../..")
--~ test("a/./b/..") test("a/aa/../b/bb") test("a/.././././b/..") test("a/./././b/..")
--~ test("a/b/c/../..") test("./a/b/c/../..") test("a/b/c/../..")

function file.robustname(str,strict)
    str = gsub(str,"[^%a%d%/%-%.\\]+","-")
    if strict then
        return lower(gsub(str,"^%-*(.-)%-*$","%1"))
    else
        return str
    end
end

file.readdata = io.loaddata
file.savedata = io.savedata

function file.copy(oldname,newname)
    file.savedata(newname,io.loaddata(oldname))
end

-- lpeg variants, slightly faster, not always

--~ local period    = P(".")
--~ local slashes   = S("\\/")
--~ local noperiod  = 1-period
--~ local noslashes = 1-slashes
--~ local name      = noperiod^1

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * C(noperiod^1) * -1

--~ function file.extname(name)
--~     return lpegmatch(pattern,name) or ""
--~ end

--~ local pattern = Cs(((period * noperiod^1 * -1)/"" + 1)^1)

--~ function file.removesuffix(name)
--~     return lpegmatch(pattern,name)
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * C(noslashes^1) * -1

--~ function file.basename(name)
--~     return lpegmatch(pattern,name) or name
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * Cp() * noslashes^1 * -1

--~ function file.dirname(name)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return sub(name,1,p-2)
--~     else
--~         return ""
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * Cp() * noperiod^1 * -1

--~ function file.addsuffix(name, suffix)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return name
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * Cp() * noperiod^1 * -1

--~ function file.replacesuffix(name,suffix)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return sub(name,1,p-2) .. "." .. suffix
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * Cp() * ((noperiod^1 * period)^1 * Cp() + P(true)) * noperiod^1 * -1

--~ function file.nameonly(name)
--~     local a, b = lpegmatch(pattern,name)
--~     if b then
--~         return sub(name,a,b-2)
--~     elseif a then
--~         return sub(name,a)
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

local letter    = R("az","AZ") + S("_-+")
local separator = P("://")

local qualified = P(".")^0 * P("/") + letter*P(":") + letter^1*separator + letter^1 * P("/")
local rootbased = P("/") + letter*P(":")

lpeg.patterns.qualified = qualified
lpeg.patterns.rootbased = rootbased

-- ./name ../name  /name c: :// name/name

function file.is_qualified_path(filename)
    return lpegmatch(qualified,filename) ~= nil
end

function file.is_rootbased_path(filename)
    return lpegmatch(rootbased,filename) ~= nil
end

-- actually these are schemes

local slash  = S("\\/")
local period = P(".")
local drive  = C(R("az","AZ")) * P(":")
local path   = C(((1-slash)^0 * slash)^0)
local suffix = period * C(P(1-period)^0 * P(-1))
local base   = C((1-suffix)^0)

drive  = drive  + Cc("")
path   = path   + Cc("")
base   = base   + Cc("")
suffix = suffix + Cc("")

local pattern_a =   drive * path  *   base * suffix
local pattern_b =           path  *   base * suffix
local pattern_c = C(drive * path) * C(base * suffix)

function file.splitname(str,splitdrive)
    if splitdrive then
        return lpegmatch(pattern_a,str) -- returns drive, path, base, suffix
    else
        return lpegmatch(pattern_b,str) -- returns path, base, suffix
    end
end

function file.nametotable(str,splitdrive) -- returns table
    local path, drive, subpath, name, base, suffix = lpegmatch(pattern_c,str)
    if splitdrive then
        return {
            path    = path,
            drive   = drive,
            subpath = subpath,
            name    = name,
            base    = base,
            suffix  = suffix,
        }
    else
        return {
            path    = path,
            name    = name,
            base    = base,
            suffix  = suffix,
        }
    end
end

-- function test(t) for k, v in next, t do print(v, "=>", file.splitname(v)) end end
--
-- test { "c:", "c:/aa", "c:/aa/bb", "c:/aa/bb/cc", "c:/aa/bb/cc.dd", "c:/aa/bb/cc.dd.ee" }
-- test { "c:", "c:aa", "c:aa/bb", "c:aa/bb/cc", "c:aa/bb/cc.dd", "c:aa/bb/cc.dd.ee" }
-- test { "/aa", "/aa/bb", "/aa/bb/cc", "/aa/bb/cc.dd", "/aa/bb/cc.dd.ee" }
-- test { "aa", "aa/bb", "aa/bb/cc", "aa/bb/cc.dd", "aa/bb/cc.dd.ee" }

--~ -- todo:
--~
--~ if os.type == "windows" then
--~     local currentdir = getcurrentdir
--~     function getcurrentdir()
--~         return (gsub(currentdir(),"\\","/"))
--~     end
--~ end

-- for myself:

function file.strip(name,dir)
    local b, a = match(name,"^(.-)" .. dir .. "(.*)$")
    return a ~= "" and a or name
end
