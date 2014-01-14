if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber

local match, format, find, concat, gsub, lower = string.match, string.format, string.find, table.concat, string.gsub, string.lower
local P, R, S, C, Ct, Cc, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.match
local utfbyte = utf.byte
local floor = math.floor

local trace_loading = false  trackers.register("fonts.loading", function(v) trace_loading    = v end)
local trace_mapping = false  trackers.register("fonts.mapping", function(v) trace_unimapping = v end)

local report_fonts  = logs.reporter("fonts","loading") -- not otf only

local fonts         = fonts or { }
local mappings      = fonts.mappings or { }
fonts.mappings      = mappings

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
<p>The name to unciode related code will stay of course.</p>
--ldx]]--

local function loadlumtable(filename) -- will move to font goodies
    local lumname = file.replacesuffix(file.basename(filename),"lum")
    local lumfile = resolvers.findfile(lumname,"map") or ""
    if lumfile ~= "" and lfs.isfile(lumfile) then
        if trace_loading or trace_mapping then
            report_fonts("loading map table %a",lumfile)
        end
        lumunic = dofile(lumfile)
        return lumunic, lumfile
    end
end

local hex     = R("AF","09")
local hexfour = (hex*hex*hex*hex)         / function(s) return tonumber(s,16) end
local hexsix  = (hex*hex*hex*hex*hex*hex) / function(s) return tonumber(s,16) end
local dec     = (R("09")^1) / tonumber
local period  = P(".")
local unicode = P("uni")   * (hexfour * (period + P(-1)) * Cc(false) + Ct(hexfour^1) * Cc(true))
local ucode   = P("u")     * (hexsix  * (period + P(-1)) * Cc(false) + Ct(hexsix ^1) * Cc(true))
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

local function tounicode16(unicode,name)
    if unicode < 0x10000 then
        return format("%04X",unicode)
    elseif unicode < 0x1FFFFFFFFF then
        return format("%04X%04X",floor(unicode/1024),unicode%1024+0xDC00)
    else
        report_fonts("can't convert %a in %a into tounicode",unicode,name)
    end
end

local function tounicode16sequence(unicodes,name)
    local t = { }
    for l=1,#unicodes do
        local unicode = unicodes[l]
        if unicode < 0x10000 then
            t[l] = format("%04X",unicode)
        elseif unicode < 0x1FFFFFFFFF then
            t[l] = format("%04X%04X",floor(unicode/1024),unicode%1024+0xDC00)
        else
            report_fonts ("can't convert %a in %a into tounicode",unicode,name)
        end
    end
    return concat(t)
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

mappings.loadlumtable        = loadlumtable
mappings.makenameparser      = makenameparser
mappings.tounicode16         = tounicode16
mappings.tounicode16sequence = tounicode16sequence
mappings.fromunicode16       = fromunicode16

local ligseparator = P("_")
local varseparator = P(".")
local namesplitter = Ct(C((1 - ligseparator - varseparator)^1) * (ligseparator * C((1 - ligseparator - varseparator)^1))^0)

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

function mappings.addtounicode(data,filename)
    local resources    = data.resources
    local properties   = data.properties
    local descriptions = data.descriptions
    local unicodes     = resources.unicodes
    if not unicodes then
        return
    end
    -- we need to move this code
    unicodes['space']  = unicodes['space']  or 32
    unicodes['hyphen'] = unicodes['hyphen'] or 45
    unicodes['zwj']    = unicodes['zwj']    or 0x200D
    unicodes['zwnj']   = unicodes['zwnj']   or 0x200C
    -- the tounicode mapping is sparse and only needed for alternatives
    local private       = fonts.constructors.privateoffset
    local unknown       = format("%04X",utfbyte("?"))
    local unicodevector = fonts.encodings.agl.unicodes -- loaded runtime in context
    local tounicode     = { }
    local originals     = { }
    resources.tounicode = tounicode
    resources.originals = originals
    local lumunic, uparser, oparser
    local cidinfo, cidnames, cidcodes, usedmap
    if false then -- will become an option
        lumunic = loadlumtable(filename)
        lumunic = lumunic and lumunic.tounicode
    end
    --
    cidinfo = properties.cidinfo
    usedmap = cidinfo and fonts.cid.getmap(cidinfo)
    --
    if usedmap then
        oparser  = usedmap and makenameparser(cidinfo.ordering)
        cidnames = usedmap.names
        cidcodes = usedmap.unicodes
    end
    uparser = makenameparser()
    local ns, nl = 0, 0
    for unic, glyph in next, descriptions do
        local index = glyph.index
        local name  = glyph.name
        if unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
            local unicode = lumunic and lumunic[name] or unicodevector[name]
            if unicode then
                originals[index] = unicode
                tounicode[index] = tounicode16(unicode,name)
                ns               = ns + 1
            end
            -- cidmap heuristics, beware, there is no guarantee for a match unless
            -- the chain resolves
            if (not unicode) and usedmap then
                local foundindex = lpegmatch(oparser,name)
                if foundindex then
                    unicode = cidcodes[foundindex] -- name to number
                    if unicode then
                        originals[index] = unicode
                        tounicode[index] = tounicode16(unicode,name)
                        ns               = ns + 1
                    else
                        local reference = cidnames[foundindex] -- number to name
                        if reference then
                            local foundindex = lpegmatch(oparser,reference)
                            if foundindex then
                                unicode = cidcodes[foundindex]
                                if unicode then
                                    originals[index] = unicode
                                    tounicode[index] = tounicode16(unicode,name)
                                    ns               = ns + 1
                                end
                            end
                            if not unicode or unicode == "" then
                                local foundcodes, multiple = lpegmatch(uparser,reference)
                                if foundcodes then
                                    originals[index] = foundcodes
                                    if multiple then
                                        tounicode[index] = tounicode16sequence(foundcodes)
                                        nl               = nl + 1
                                        unicode          = true
                                    else
                                        tounicode[index] = tounicode16(foundcodes,name)
                                        ns               = ns + 1
                                        unicode          = foundcodes
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
            -- The next time I look into this, I'll add an extra analysis step to the otf loader (we can
            -- resolve some tounicodes by looking into the gsub data tables that are bound to glyphs.
            --
            if not unicode or unicode == "" then
                local split = lpegmatch(namesplitter,name)
                local nsplit = split and #split or 0
                local t, n = { }, 0
                unicode = true
                for l=1,nsplit do
                    local base = split[l]
                    local u = unicodes[base] or unicodevector[base]
                    if not u then
                        break
                    elseif type(u) == "table" then
                        if u[1] >= private then
                            unicode = false
                            break
                        end
                        n = n + 1
                        t[n] = u[1]
                    else
                        if u >= private then
                            unicode = false
                            break
                        end
                        n = n + 1
                        t[n] = u
                    end
                end
                if n == 0 then -- done then
                    -- nothing
                elseif n == 1 then
                    originals[index] = t[1]
                    tounicode[index] = tounicode16(t[1],name)
                else
                    originals[index] = t
                    tounicode[index] = tounicode16sequence(t)
                end
                nl = nl + 1
            end
            -- last resort (we might need to catch private here as well)
            if not unicode or unicode == "" then
                local foundcodes, multiple = lpegmatch(uparser,name)
                if foundcodes then
                    if multiple then
                        originals[index] = foundcodes
                        tounicode[index] = tounicode16sequence(foundcodes,name)
                        nl               = nl + 1
                        unicode          = true
                    else
                        originals[index] = foundcodes
                        tounicode[index] = tounicode16(foundcodes,name)
                        ns               = ns + 1
                        unicode          = foundcodes
                    end
                end
            end
         -- if not unicode then
         --     originals[index] = 0xFFFD
         --     tounicode[index] = "FFFD"
         -- end
        end
    end
    if trace_mapping then
        for unic, glyph in table.sortedhash(descriptions) do
            local name  = glyph.name
            local index = glyph.index
            local toun  = tounicode[index]
            if toun then
                report_fonts("internal slot %U, name %a, unicode %U, tounicode %a",index,name,unic,toun)
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
