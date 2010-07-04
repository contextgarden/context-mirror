if not modules then modules = { } end modules ['data-exp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, gsub, find, gmatch, lower = string.format, string.gsub, string.find, string.gmatch, string.lower
local concat, sort = table.concat, table.sort
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local lpegCt, lpegCs, lpegP, lpegC, lpegS = lpeg.Ct, lpeg.Cs, lpeg.P, lpeg.C, lpeg.S
local type, next = type, next

local ostype = os.type
local collapse_path = file.collapse_path

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_resolvers = logs.new("resolvers")

-- As this bit of code is somewhat special it gets its own module. After
-- all, when working on the main resolver code, I don't want to scroll
-- past this every time.

-- {a,b,c,d}
-- a,b,c/{p,q,r},d
-- a,b,c/{p,q,r}/d/{x,y,z}//
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a{b,c}{d,e}f
-- {a,b,c,d}
-- {a,b,c/{p,q,r},d}
-- {a,b,c/{p,q,r}/d/{x,y,z}//}
-- {a,b,c/{p,q/{x,y,z}},d/{p,q,r}}
-- {a,b,c/{p,q/{x,y,z},w}v,d/{p,q,r}}
-- {$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}

-- this one is better and faster, but it took me a while to realize
-- that this kind of replacement is cleaner than messy parsing and
-- fuzzy concatenating we can probably gain a bit with selectively
-- applying lpeg, but experiments with lpeg parsing this proved not to
-- work that well; the parsing is ok, but dealing with the resulting
-- table is a pain because we need to work inside-out recursively

local dummy_path_expr = "^!*unset/*$"

local function do_first(a,b)
    local t = { }
    for s in gmatch(b,"[^,]+") do t[#t+1] = a .. s end
    return "{" .. concat(t,",") .. "}"
end

local function do_second(a,b)
    local t = { }
    for s in gmatch(a,"[^,]+") do t[#t+1] = s .. b end
    return "{" .. concat(t,",") .. "}"
end

local function do_both(a,b)
    local t = { }
    for sa in gmatch(a,"[^,]+") do
        for sb in gmatch(b,"[^,]+") do
            t[#t+1] = sa .. sb
        end
    end
    return "{" .. concat(t,",") .. "}"
end

local function do_three(a,b,c)
    return a .. b.. c
end

local stripper_1 = lpeg.stripper("{}@")

local replacer_1 = lpeg.replacer {
    { ",}", ",@}" },
    { "{,", "{@," },
}

local function splitpathexpr(str, newlist, validate)
    -- no need for further optimization as it is only called a
    -- few times, we can use lpeg for the sub
    if trace_expansions then
        report_resolvers("expanding variable '%s'",str)
    end
    local t, ok, done = newlist or { }, false, false
    str = lpegmatch(replacer_1,str)
    while true do
        done = false
        while true do
            str, ok = gsub(str,"([^{},]+){([^{}]+)}",do_first)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}([^{},]+)",do_second)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}{([^{}]+)}",do_both)
            if ok > 0 then done = true else break end
        end
        str, ok = gsub(str,"({[^{}]*){([^{}]+)}([^{}]*})",do_three)
        if ok > 0 then done = true end
        if not done then break end
    end
    str = lpegmatch(stripper_1,str)
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then t[#t+1] = s end
        end
    else
        for s in gmatch(str,"[^,]+") do
            t[#t+1] = s
        end
    end
    if trace_expansions then
        for k=1,#t do
            report_resolvers("% 4i: %s",k,t[k])
        end
    end
    return t
end

local function validate(s)
    local isrecursive = find(s,"//$")
    s = collapse_path(s)
    if isrecursive then
        s = s .. "//"
    end
    return s ~= "" and not find(s,dummy_path_expr) and s
end

resolvers.validated_path = validate -- keeps the trailing //

function resolvers.expanded_path_from_list(pathlist) -- maybe not a list, just a path
    -- a previous version fed back into pathlist
    local newlist, ok = { }, false
    for k=1,#pathlist do
        if find(pathlist[k],"[{}]") then
            ok = true
            break
        end
    end
    if ok then
        for k=1,#pathlist do
            splitpathexpr(pathlist[k],newlist,validate)
        end
    else
        for k=1,#pathlist do
            for p in gmatch(pathlist[k],"([^,]+)") do
--~                 p = collapse_path(p)
                p = validate(p)
                if p ~= "" then newlist[#newlist+1] = p end
            end
        end
    end
    return newlist
end

-- We also put some cleanup code here.

local cleanup -- used recursively

cleanup = lpeg.replacer {
    { "!",  "" },
    { "\\", "/" },
    { "~" , function() return lpegmatch(cleanup,environment.homedir) end },
}

function resolvers.clean_path(str)
    return str and lpegmatch(cleanup,str)
end

-- This one strips quotes and funny tokens.

--~ local stripper = lpegCs(
--~     lpegpatterns.unspacer * lpegpatterns.unsingle
--~   + lpegpatterns.undouble * lpegpatterns.unspacer
--~ )

local expandhome = lpegP("~") / "$HOME" -- environment.homedir

local dodouble = lpegP('"')/"" * (expandhome + (1 - lpegP('"')))^0 * lpegP('"')/""
local dosingle = lpegP("'")/"" * (expandhome + (1 - lpegP("'")))^0 * lpegP("'")/""
local dostring =                 (expandhome +  1              )^0

local stripper = lpegCs(
    lpegpatterns.unspacer * (dosingle + dodouble + dostring) * lpegpatterns.unspacer
)

function resolvers.checked_variable(str) -- assumes str is a string
    return lpegmatch(stripper,str) or str
end

-- The path splitter:

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

--~ local checkedsplit = string.checkedsplit

local cache = { }

local splitter = lpegCt(lpeg.splitat(lpegS(ostype == "windows" and ";" or ":;"))) -- maybe add ,

local function split_configuration_path(str) -- beware, this can be either a path or a { specification }
    if str then
        local found = cache[str]
        if not found then
            if str == "" then
                found = { }
            else
                str = gsub(str,"\\","/")
                local split = lpegmatch(splitter,str)
                found = { }
                for i=1,#split do
                    local s = split[i]
                    if not find(s,"^{*unset}*") then
                        found[#found+1] = s
                    end
                end
                if trace_expansions then
                    report_resolvers("splitting path specification '%s'",str)
                    for k=1,#found do
                        report_resolvers("% 4i: %s",k,found[k])
                    end
                end
                cache[str] = found
            end
        end
        return found
    end
end

resolvers.split_configuration_path = split_configuration_path

function resolvers.split_path(str)
    if type(str) == 'table' then
        return str
    else
        return split_configuration_path(str)
    end
end

function resolvers.join_path(str)
    if type(str) == 'table' then
        return file.join_path(str)
    else
        return str
    end
end

-- The next function scans directories and returns a hash where the
-- entries are either strings or tables.

-- starting with . or .. etc or funny char

--~ local l_forbidden = lpegS("~`!#$%^&*()={}[]:;\"\'||\\/<>,?\n\r\t")
--~ local l_confusing = lpegP(" ")
--~ local l_character = lpegpatterns.utf8
--~ local l_dangerous = lpegP(".")

--~ local l_normal = (l_character - l_forbidden - l_confusing - l_dangerous) * (l_character - l_forbidden - l_confusing^2)^0 * lpegP(-1)
--~ ----- l_normal = l_normal * lpegCc(true) + lpegCc(false)

--~ local function test(str)
--~     print(str,lpegmatch(l_normal,str))
--~ end
--~ test("ヒラギノ明朝 Pro W3")
--~ test("..ヒラギノ明朝 Pro W3")
--~ test(":ヒラギノ明朝 Pro W3;")
--~ test("ヒラギノ明朝 /Pro W3;")
--~ test("ヒラギノ明朝 Pro  W3")

local weird = lpegP(".")^1 + lpeg.anywhere(lpegS("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

function resolvers.scan_files(specification)
    if trace_locating then
        report_resolvers("scanning path '%s'",specification)
    end
    local attributes, directory = lfs.attributes, lfs.dir
    local files = { __path__ = specification }
    local n, m, r = 0, 0, 0
    local function scan(spec,path)
        local full = (path == "" and spec) or (spec .. path .. '/')
        local dirs = { }
        for name in directory(full) do
            if not lpegmatch(weird,name) then
                local mode = attributes(full..name,'mode')
                if mode == 'file' then
                    n = n + 1
                    local f = files[name]
                    if f then
                        if type(f) == 'string' then
                            files[name] = { f, path }
                        else
                            f[#f+1] = path
                        end
                    else -- probably unique anyway
                        files[name] = path
                        local lower = lower(name)
                        if name ~= lower then
                            files["remap:"..lower] = name
                            r = r + 1
                        end
                    end
                elseif mode == 'directory' then
                    m = m + 1
                    if path ~= "" then
                        dirs[#dirs+1] = path..'/'..name
                    else
                        dirs[#dirs+1] = name
                    end
                end
            end
        end
        if #dirs > 0 then
            sort(dirs)
            for i=1,#dirs do
                scan(spec,dirs[i])
            end
        end
    end
    scan(specification .. '/',"")
    files.__files__, files.__directories__, files.__remappings__ = n, m, r
    if trace_locating then
        report_resolvers("%s files found on %s directories with %s uppercase remappings",n,m,r)
    end
    return files
end

--~ print(table.serialize(resolvers.scan_files("t:/sources")))
