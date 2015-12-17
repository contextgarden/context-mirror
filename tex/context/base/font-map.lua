if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, next, type = tonumber, next, type

local match, format, find, concat, gsub, lower = string.match, string.format, string.find, table.concat, string.gsub, string.lower
local P, R, S, C, Ct, Cc, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.match
local utfbyte = utf.byte
local floor = math.floor
local formatters = string.formatters

local trace_loading = false  trackers.register("fonts.loading", function(v) trace_loading    = v end)
local trace_mapping = false  trackers.register("fonts.mapping", function(v) trace_unimapping = v end)

local report_fonts  = logs.reporter("fonts","loading") -- not otf only

local fonts         = fonts or { }
local mappings      = fonts.mappings or { }
fonts.mappings      = mappings

local allocate      = utilities.storage.allocate

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
<p>The name to unciode related code will stay of course.</p>
--ldx]]--

-- local function loadlumtable(filename) -- will move to font goodies
--     local lumname = file.replacesuffix(file.basename(filename),"lum")
--     local lumfile = resolvers.findfile(lumname,"map") or ""
--     if lumfile ~= "" and lfs.isfile(lumfile) then
--         if trace_loading or trace_mapping then
--             report_fonts("loading map table %a",lumfile)
--         end
--         lumunic = dofile(lumfile)
--         return lumunic, lumfile
--     end
-- end

local hex     = R("AF","09")
----- hexfour = (hex*hex*hex*hex)         / function(s) return tonumber(s,16) end
----- hexsix  = (hex*hex*hex*hex*hex*hex) / function(s) return tonumber(s,16) end
local hexfour = (hex*hex*hex^-2) / function(s) return tonumber(s,16) end
local hexsix  = (hex*hex*hex^-4) / function(s) return tonumber(s,16) end
local dec     = (R("09")^1) / tonumber
local period  = P(".")
local unicode = (P("uni") + P("UNI")) * (hexfour * (period + P(-1)) * Cc(false) + Ct(hexfour^1) * Cc(true)) -- base planes
local ucode   = (P("u")   + P("U")  ) * (hexsix  * (period + P(-1)) * Cc(false) + Ct(hexsix ^1) * Cc(true)) -- extended
local index   = P("index") * dec * Cc(false)

local parser  = unicode + ucode + index

local parsers = { }

local function makenameparser(str)
    if not str or str == "" then
        return parser
    else
        local p = parsers[str]
        if not p then
            p = P(str) * period * dec * Cc(false)
            parsers[str] = p
        end
        return p
    end
end

local f_single = formatters["%04X"]
local f_double = formatters["%04X%04X"]

-- 0.684 0.661 0,672 0.650 : cache at lua end (more mem)
-- 0.682 0,672 0.698 0.657 : no cache (moderate mem i.e. lua strings)
-- 0.644 0.647 0.655 0.645 : convert in c (less mem in theory)

-- local tounicodes = table.setmetatableindex(function(t,unicode)
--     local s
--     if unicode < 0x10000 then
--         s = f_single(unicode)
--     elseif unicode < 0x1FFFFFFFFF then
--         s = f_double(floor(unicode/1024),unicode%1024+0xDC00)
--     else
--         s = false
--     end
--     t[unicode] = s
--     return s
-- end)
--
-- local function tounicode16(unicode,name)
--     local s = tounicodes[unicode]
--     if s then
--         return s
--     else
--         report_fonts("can't convert %a in %a into tounicode",unicode,name)
--     end
-- end
--
-- local function tounicode16sequence(unicodes,name)
--     local t = { }
--     for l=1,#unicodes do
--         local u = unicodes[l]
--         local s = tounicodes[u]
--         if s then
--             t[l] = s
--         else
--             report_fonts ("can't convert %a in %a into tounicode",u,name)
--             return
--         end
--     end
--     return concat(t)
-- end
--
-- local function tounicode(unicode,name)
--     if type(unicode) == "table" then
--         local t = { }
--         for l=1,#unicode do
--             local u = unicode[l]
--             local s = tounicodes[u]
--             if s then
--                 t[l] = s
--             else
--                 report_fonts ("can't convert %a in %a into tounicode",u,name)
--                 return
--             end
--         end
--         return concat(t)
--     else
--         local s = tounicodes[unicode]
--         if s then
--             return s
--         else
--             report_fonts("can't convert %a in %a into tounicode",unicode,name)
--         end
--     end
-- end

local function tounicode16(unicode,name)
    if unicode < 0x10000 then
        return f_single(unicode)
    elseif unicode < 0x1FFFFFFFFF then
        return f_double(floor(unicode/1024),unicode%1024+0xDC00)
    else
        report_fonts("can't convert %a in %a into tounicode",unicode,name)
    end
end

local function tounicode16sequence(unicodes,name)
    local t = { }
    for l=1,#unicodes do
        local u = unicodes[l]
        if u < 0x10000 then
            t[l] = f_single(u)
        elseif unicode < 0x1FFFFFFFFF then
            t[l] = f_double(floor(u/1024),u%1024+0xDC00)
        else
            report_fonts ("can't convert %a in %a into tounicode",u,name)
            return
        end
    end
    return concat(t)
end

local function tounicode(unicode,name)
    if type(unicode) == "table" then
        local t = { }
        for l=1,#unicode do
            local u = unicode[l]
            if u < 0x10000 then
                t[l] = f_single(u)
            elseif u < 0x1FFFFFFFFF then
                t[l] = f_double(floor(u/1024),u%1024+0xDC00)
            else
                report_fonts ("can't convert %a in %a into tounicode",u,name)
                return
            end
        end
        return concat(t)
    else
        if unicode < 0x10000 then
            return f_single(unicode)
        elseif unicode < 0x1FFFFFFFFF then
            return f_double(floor(unicode/1024),unicode%1024+0xDC00)
        else
            report_fonts("can't convert %a in %a into tounicode",unicode,name)
        end
    end
end

local function fromunicode16(str)
    if #str == 4 then
        return tonumber(str,16)
    else
        local l, r = match(str,"(....)(....)")
        return (tonumber(l,16))*0x400  + tonumber(r,16) - 0xDC00
    end
end

-- Slightly slower:
--
-- local p = C(4) * (C(4)^-1) / function(l,r)
--     if r then
--         return (tonumber(l,16))*0x400  + tonumber(r,16) - 0xDC00
--     else
--         return tonumber(l,16)
--     end
-- end
--
-- local function fromunicode16(str)
--     return lpegmatch(p,str)
-- end

-- This is quite a bit faster but at the cost of some memory but if we
-- do this we will also use it elsewhere so let's not follow this route
-- now. I might use this method in the plain variant (no caching there)
-- but then I need a flag that distinguishes between code branches.
--
-- local cache = { }
--
-- function mappings.tounicode16(unicode)
--     local s = cache[unicode]
--     if not s then
--         if unicode < 0x10000 then
--             s = format("%04X",unicode)
--         else
--             s = format("%04X%04X",unicode/0x400+0xD800,unicode%0x400+0xDC00)
--         end
--         cache[unicode] = s
--     end
--     return s
-- end

mappings.makenameparser      = makenameparser
mappings.tounicode           = tounicode
mappings.tounicode16         = tounicode16
mappings.tounicode16sequence = tounicode16sequence
mappings.fromunicode16       = fromunicode16

local ligseparator = P("_")
local varseparator = P(".")
local namesplitter = Ct(C((1 - ligseparator - varseparator)^1) * (ligseparator * C((1 - ligseparator - varseparator)^1))^0)

-- maybe: ff fi fl ffi ffl => f_f f_i f_l f_f_i f_f_l

-- local function test(name)
--     local split = lpegmatch(namesplitter,name)
--     print(string.formatters["%s: [% t]"](name,split))
-- end

-- test("i.f_")
-- test("this")
-- test("this.that")
-- test("japan1.123")
-- test("such_so_more")
-- test("such_so_more.that")

-- to be completed .. for fonts that use unicodes for ligatures which
-- is a actually a bad thing and should be avoided in the first place

local overloads = allocate {
    IJ  = { name = "I_J",   unicode = { 0x49, 0x4A },       mess = 0x0132 },
    ij  = { name = "i_j",   unicode = { 0x69, 0x6A },       mess = 0x0133 },
    ff  = { name = "f_f",   unicode = { 0x66, 0x66 },       mess = 0xFB00 },
    fi  = { name = "f_i",   unicode = { 0x66, 0x69 },       mess = 0xFB01 },
    fl  = { name = "f_l",   unicode = { 0x66, 0x6C },       mess = 0xFB02 },
    ffi = { name = "f_f_i", unicode = { 0x66, 0x66, 0x69 }, mess = 0xFB03 },
    ffl = { name = "f_f_l", unicode = { 0x66, 0x66, 0x6C }, mess = 0xFB04 },
    fj  = { name = "f_j",   unicode = { 0x66, 0x6A } },
    fk  = { name = "f_k",   unicode = { 0x66, 0x6B } },
}

for k, v in next, overloads do
    local name = v.name
    local mess = v.mess
    if name then
        overloads[name] = v
    end
    if mess then
        overloads[mess] = v
    end
end

mappings.overloads = overloads

function mappings.addtounicode(data,filename,checklookups)
    local resources = data.resources
    local unicodes  = resources.unicodes
    if not unicodes then
        return
    end
    local properties    = data.properties
    local descriptions  = data.descriptions
    -- we need to move this code
    unicodes['space']   = unicodes['space']  or 32
    unicodes['hyphen']  = unicodes['hyphen'] or 45
    unicodes['zwj']     = unicodes['zwj']    or 0x200D
    unicodes['zwnj']    = unicodes['zwnj']   or 0x200C
    --
    local private       = fonts.constructors and fonts.constructors.privateoffset or 0xF0000 -- 0x10FFFF
    local unicodevector = fonts.encodings.agl.unicodes or { } -- loaded runtime in context
    local contextvector = fonts.encodings.agl.ctxcodes or { } -- loaded runtime in context
    local missing       = { }
    local nofmissing    = 0
    local oparser       = nil
    local cidnames      = nil
    local cidcodes      = nil
    local cidinfo       = properties.cidinfo
    local usedmap       = cidinfo and fonts.cid.getmap(cidinfo)
    local uparser       = makenameparser() -- hm, every time?
    if usedmap then
          oparser       = usedmap and makenameparser(cidinfo.ordering)
          cidnames      = usedmap.names
          cidcodes      = usedmap.unicodes
    end
    local ns            = 0
    local nl            = 0
    --
    for unic, glyph in next, descriptions do
        local name = glyph.name
        if name then
            local index = glyph.index
            local r = overloads[name]
            if r then
                -- get rid of weird ligatures
             -- glyph.name    = r.name
                glyph.unicode = r.unicode
            elseif not unic or unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
                local unicode = unicodevector[name] or contextvector[name]
                if unicode then
                    glyph.unicode = unicode
                    ns            = ns + 1
                end
                -- cidmap heuristics, beware, there is no guarantee for a match unless
                -- the chain resolves
                if (not unicode) and usedmap then
                    local foundindex = lpegmatch(oparser,name)
                    if foundindex then
                        unicode = cidcodes[foundindex] -- name to number
                        if unicode then
                            glyph.unicode = unicode
                            ns            = ns + 1
                        else
                            local reference = cidnames[foundindex] -- number to name
                            if reference then
                                local foundindex = lpegmatch(oparser,reference)
                                if foundindex then
                                    unicode = cidcodes[foundindex]
                                    if unicode then
                                        glyph.unicode = unicode
                                        ns            = ns + 1
                                    end
                                end
                                if not unicode or unicode == "" then
                                    local foundcodes, multiple = lpegmatch(uparser,reference)
                                    if foundcodes then
                                        glyph.unicode = foundcodes
                                        if multiple then
                                            nl      = nl + 1
                                            unicode = true
                                        else
                                            ns      = ns + 1
                                            unicode = foundcodes
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- a.whatever or a_b_c.whatever or a_b_c (no numbers) a.b_
                --
                -- It is not trivial to find a solution that suits all fonts. We tried several alternatives
                -- and this one seems to work reasonable also with fonts that use less standardized naming
                -- schemes. The extra private test is tested by KE and seems to work okay with non-typical
                -- fonts as well.
                --
                if not unicode or unicode == "" then
                    local split  = lpegmatch(namesplitter,name)
                    local nsplit = split and #split or 0 -- add if
                    if nsplit == 0 then
                        -- skip
                    elseif nsplit == 1 then
                        local base = split[1]
                        local u = unicodes[base] or unicodevector[base] or contextvector[name]
                        if not u then
                            -- skip
                        elseif type(u) == "table" then
                            -- unlikely
                            if u[1] < private then
                                unicode = u
                                glyph.unicode = unicode
                            end
                        elseif u < private then
                            unicode = u
                            glyph.unicode = unicode
                        end
                    else
                        local t, n = { }, 0
                        for l=1,nsplit do
                            local base = split[l]
                            local u = unicodes[base] or unicodevector[base] or contextvector[name]
                            if not u then
                                break
                            elseif type(u) == "table" then
                                if u[1] >= private then
                                    break
                                end
                                n = n + 1
                                t[n] = u[1]
                            else
                                if u >= private then
                                    break
                                end
                                n = n + 1
                                t[n] = u
                            end
                        end
                        if n > 0 then
                            if n == 1 then
                                unicode = t[1]
                            else
                                unicode = t
                            end
                            glyph.unicode = unicode
                        end
                    end
                    nl = nl + 1
                end
                -- last resort (we might need to catch private here as well)
                if not unicode or unicode == "" then
                    local foundcodes, multiple = lpegmatch(uparser,name)
                    if foundcodes then
                        glyph.unicode = foundcodes
                        if multiple then
                            nl      = nl + 1
                            unicode = true
                        else
                            ns      = ns + 1
                            unicode = foundcodes
                        end
                    end
                end
                -- check using substitutes and alternates
                local r = overloads[unicode]
                if r then
                    unicode = r.unicode
                    glyph.unicode = unicode
                end
                --
                if not unicode then
                    missing[unic] = true
                    nofmissing    = nofmissing + 1
                end
            end
        else
            -- no name
        end
    end
    if type(checklookups) == "function" then
        checklookups(data,missing,nofmissing)
    end
    -- todo: go lowercase
    if trace_mapping then
        for unic, glyph in table.sortedhash(descriptions) do
            local name    = glyph.name
            local index   = glyph.index
            local unicode = glyph.unicode
            if unicode then
                if type(unicode) == "table" then
                    local unicodes = { }
                    for i=1,#unicode do
                        unicodes[i] = formatters("%U",unicode[i])
                    end
                    report_fonts("internal slot %U, name %a, unicode %U, tounicode % t",index,name,unic,unicodes)
                else
                    report_fonts("internal slot %U, name %a, unicode %U, tounicode %U",index,name,unic,unicode)
                end
            else
                report_fonts("internal slot %U, name %a, unicode %U",index,name,unic)
            end
        end
    end
    if trace_loading and (ns > 0 or nl > 0) then
        report_fonts("%s tounicode entries added, ligatures %s",nl+ns,ns)
    end
end

-- local parser = makenameparser("Japan1")
-- local parser = makenameparser()
-- local function test(str)
--     local b, a = lpegmatch(parser,str)
--     print((a and table.serialize(b)) or b)
-- end
-- test("a.sc")
-- test("a")
-- test("uni1234")
-- test("uni1234.xx")
-- test("uni12349876")
-- test("u123400987600")
-- test("index1234")
-- test("Japan1.123")
