if not modules then modules = { } end modules ['data-exp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, find, gmatch, lower = string.format, string.find, string.gmatch, string.lower
local concat, sort = table.concat, table.sort
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local Ct, Cs, Cc, P, C, S = lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.P, lpeg.C, lpeg.S
local type, next = type, next

local ostype = os.type
local collapsepath = file.collapsepath

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

-- As this bit of code is somewhat special it gets its own module. After
-- all, when working on the main resolver code, I don't want to scroll
-- past this every time. See data-obs.lua for the gsub variant.

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

local function f_first(a,b)
    local t, n = { }, 0
    for s in gmatch(b,"[^,]+") do
        n = n + 1 ; t[n] = a .. s
    end
    return concat(t,",")
end

local function f_second(a,b)
    local t, n = { }, 0
    for s in gmatch(a,"[^,]+") do
        n = n + 1 ; t[n] = s .. b
    end
    return concat(t,",")
end

local function f_both(a,b)
    local t, n = { }, 0
    for sa in gmatch(a,"[^,]+") do
        for sb in gmatch(b,"[^,]+") do
            n = n + 1 ; t[n] = sa .. sb
        end
    end
    return concat(t,",")
end

local left  = P("{")
local right = P("}")
local var   = P((1 - S("{}" ))^0)
local set   = P((1 - S("{},"))^0)
local other = P(1)

local l_first  = Cs( ( Cc("{") * (C(set) * left * C(var) * right / f_first) * Cc("}")               + other )^0 )
local l_second = Cs( ( Cc("{") * (left * C(var) * right * C(set) / f_second) * Cc("}")              + other )^0 )
local l_both   = Cs( ( Cc("{") * (left * C(var) * right * left * C(var) * right / f_both) * Cc("}") + other )^0 )
local l_rest   = Cs( ( left * var * (left/"") * var * (right/"") * var * right                      + other )^0 )

local stripper_1 = lpeg.stripper ("{}@")
local replacer_1 = lpeg.replacer { { ",}", ",@}" }, { "{,", "{@," }, }

local function splitpathexpr(str, newlist, validate) -- I couldn't resist lpegging it (nice exercise).
    if trace_expansions then
        report_resolvers("expanding variable '%s'",str)
    end
    local t, ok, done = newlist or { }, false, false
    local n = #t
    str = lpegmatch(replacer_1,str)
    repeat local old = str
        repeat local old = str ; str = lpegmatch(l_first, str) until old == str
        repeat local old = str ; str = lpegmatch(l_second,str) until old == str
        repeat local old = str ; str = lpegmatch(l_both,  str) until old == str
        repeat local old = str ; str = lpegmatch(l_rest,  str) until old == str
    until old == str -- or not find(str,"{")
    str = lpegmatch(stripper_1,str)
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then
                n = n + 1 ; t[n] = s
            end
        end
    else
        for s in gmatch(str,"[^,]+") do
            n = n + 1 ; t[n] = s
        end
    end
    if trace_expansions then
        for k=1,#t do
            report_resolvers("% 4i: %s",k,t[k])
        end
    end
    return t
end

-- We could make the previous one public.

local function validate(s)
    s = collapsepath(s) -- already keeps the //
    return s ~= "" and not find(s,"^!*unset/*$") and s
end

resolvers.validatedpath = validate -- keeps the trailing //

function resolvers.expandedpathfromlist(pathlist)
    local newlist = { }
    for k=1,#pathlist do
        splitpathexpr(pathlist[k],newlist,validate)
    end
    return newlist
end

local cleanup = lpeg.replacer {
    { "!"  , ""  },
    { "\\" , "/" },
}

local homedir

function resolvers.cleanpath(str)
    if not homedir then
        homedir = lpegmatch(cleanup,environment.homedir or "")
        if homedir == string.char(127) or homedir == "" or not lfs.isdir(homedir) then
            if trace_expansions then
                report_resolvers("no home dir set, ignoring dependent paths")
            end
            function resolvers.cleanpath(str)
                if find(str,"~") then
                    return "" -- special case
                else
                    return str and lpegmatch(cleanup,str)
                end
            end
        else
            cleanup = lpeg.replacer {
                { "!"  , ""      },
                { "\\" , "/"     },
                { "~"  , homedir },
            }
            function resolvers.cleanpath(str)
                return str and lpegmatch(cleanup,str)
            end
        end
    end
    return resolvers.cleanpath(str)
end

-- This one strips quotes and funny tokens.

local expandhome = P("~") / "$HOME" -- environment.homedir

local dodouble = P('"')/"" * (expandhome + (1 - P('"')))^0 * P('"')/""
local dosingle = P("'")/"" * (expandhome + (1 - P("'")))^0 * P("'")/""
local dostring =             (expandhome +  1              )^0

local stripper = Cs(
    lpegpatterns.unspacer * (dosingle + dodouble + dostring) * lpegpatterns.unspacer
)

function resolvers.checkedvariable(str) -- assumes str is a string
    return lpegmatch(stripper,str) or str
end

-- The path splitter:

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

local cache = { }

local splitter = Ct(lpeg.splitat(S(ostype == "windows" and ";" or ":;"))) -- maybe add ,

local backslashswapper = lpeg.replacer("\\","/")

local function splitconfigurationpath(str) -- beware, this can be either a path or a { specification }
    if str then
        local found = cache[str]
        if not found then
            if str == "" then
                found = { }
            else
                local split = lpegmatch(splitter,lpegmatch(backslashswapper,str)) -- can be combined
                found = { }
                local noffound = 0
                for i=1,#split do
                    local s = split[i]
                    if not find(s,"^{*unset}*") then
                        noffound = noffound + 1
                        found[noffound] = s
                    end
                end
                if trace_expansions then
                    report_resolvers("splitting path specification '%s'",str)
                    for k=1,noffound do
                        report_resolvers("% 4i: %s",k,found[k])
                    end
                end
                cache[str] = found
            end
        end
        return found
    end
end

resolvers.splitconfigurationpath = splitconfigurationpath

function resolvers.splitpath(str)
    if type(str) == 'table' then
        return str
    else
        return splitconfigurationpath(str)
    end
end

function resolvers.joinpath(str)
    if type(str) == 'table' then
        return file.joinpath(str)
    else
        return str
    end
end

-- The next function scans directories and returns a hash where the
-- entries are either strings or tables.

-- starting with . or .. etc or funny char

--~ local l_forbidden = S("~`!#$%^&*()={}[]:;\"\'||\\/<>,?\n\r\t")
--~ local l_confusing = P(" ")
--~ local l_character = lpegpatterns.utf8
--~ local l_dangerous = P(".")

--~ local l_normal = (l_character - l_forbidden - l_confusing - l_dangerous) * (l_character - l_forbidden - l_confusing^2)^0 * P(-1)
--~ ----- l_normal = l_normal * Cc(true) + Cc(false)

--~ local function test(str)
--~     print(str,lpegmatch(l_normal,str))
--~ end
--~ test("ヒラギノ明朝 Pro W3")
--~ test("..ヒラギノ明朝 Pro W3")
--~ test(":ヒラギノ明朝 Pro W3;")
--~ test("ヒラギノ明朝 /Pro W3;")
--~ test("ヒラギノ明朝 Pro  W3")

local weird = P(".")^1 + lpeg.anywhere(S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

local attributes, directory = lfs.attributes, lfs.dir

local function scan(files,spec,path,n,m,r)
    local full = (path == "" and spec) or (spec .. path .. '/')
    local dirs, nofdirs = { }, 0
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
                nofdirs = nofdirs + 1
                if path ~= "" then
                    dirs[nofdirs] = path..'/'..name
                else
                    dirs[nofdirs] = name
                end
            end
        end
    end
    if nofdirs > 0 then
        sort(dirs)
        for i=1,nofdirs do
            files, n, m, r = scan(files,spec,dirs[i],n,m,r)
        end
    end
    return files, n, m, r
end

function resolvers.scanfiles(path)
    if trace_locating then
        report_resolvers("scanning path '%s'",path)
    end
    local files, n, m, r = scan({ },path .. '/',"",0,0,0)
    files.__path__        = path
    files.__files__       = n
    files.__directories__ = m
    files.__remappings__  = r
    if trace_locating then
        report_resolvers("%s files found on %s directories with %s uppercase remappings",n,m,r)
    end
    return files
end

--~ print(table.serialize(resolvers.scanfiles("t:/sources")))
