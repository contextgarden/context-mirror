if not modules then modules = { } end modules ['font-afm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Some code may look a bit obscure but this has to do with the
fact that we also use this code for testing and much code evolved
in the transition from <l n='tfm'/> to <l n='afm'/> to <l
n='otf'/>.</p>

<p>The following code still has traces of intermediate font support
where we handles font encodings. Eventually font encoding goes
away.</p>
--ldx]]--

local trace_features = false  trackers.register("afm.features",   function(v) trace_features = v end)
local trace_indexing = false  trackers.register("afm.indexing",   function(v) trace_indexing = v end)
local trace_loading  = false  trackers.register("afm.loading",    function(v) trace_loading  = v end)
local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_afm = logs.reporter("fonts","afm loading")

local next, type = next, type
local format, match, gmatch, lower, gsub, strip = string.format, string.match, string.gmatch, string.lower, string.gsub, string.strip
local lpegmatch = lpeg.match
local abs = math.abs

local findbinfile = resolvers.findbinfile

local fonts = fonts
fonts.afm   = fonts.afm or { }

local afm   = fonts.afm
local tfm   = fonts.tfm

afm.version         = 1.403 -- incrementing this number one up will force a re-cache
afm.syncspace       = true  -- when true, nicer stretch values
afm.addligatures    = true  -- best leave this set to true
afm.addtexligatures = true  -- best leave this set to true
afm.addkerns        = true  -- best leave this set to true
afm.cache           = containers.define("fonts", "afm", afm.version, true)

local definers = fonts.definers
local readers  = fonts.tfm.readers

local afmfeatures = {
    aux     = { },
    data    = { },
    list    = { },
    default = { },
}

afm.features = afmfeatures

--[[ldx--
<p>We start with the basic reader which we give a name similar to the
built in <l n='tfm'/> and <l n='otf'/> reader.</p>
--ldx]]--

--~ Comment FONTIDENTIFIER LMMATHSYMBOLS10
--~ Comment CODINGSCHEME TEX MATH SYMBOLS
--~ Comment DESIGNSIZE 10.0 pt
--~ Comment CHECKSUM O 4261307036
--~ Comment SPACE 0 plus 0 minus 0
--~ Comment QUAD 1000
--~ Comment EXTRASPACE 0
--~ Comment NUM 676.508 393.732 443.731
--~ Comment DENOM 685.951 344.841
--~ Comment SUP 412.892 362.892 288.889
--~ Comment SUB 150 247.217
--~ Comment SUPDROP 386.108
--~ Comment SUBDROP 50
--~ Comment DELIM 2390 1010
--~ Comment AXISHEIGHT 250

local P, S, C = lpeg.P, lpeg.S, lpeg.C

local c = P("Comment")
local s = S(" \t")
local l = S("\n\r")
local w = C((1 - l)^1)
local n = C((lpeg.R("09") + S("."))^1) / tonumber * s^0

local fd = { }

local pattern = ( c * s^1 * (
    ("CODINGSCHEME" * s^1 * w                            ) / function(a)                                      end +
    ("DESIGNSIZE"   * s^1 * n * w                        ) / function(a)     fd[ 1]                 = a       end +
    ("CHECKSUM"     * s^1 * n * w                        ) / function(a)     fd[ 2]                 = a       end +
    ("SPACE"        * s^1 * n * "plus"  * n * "minus" * n) / function(a,b,c) fd[ 3], fd[ 4], fd[ 5] = a, b, c end +
    ("QUAD"         * s^1 * n                            ) / function(a)     fd[ 6]                 = a       end +
    ("EXTRASPACE"   * s^1 * n                            ) / function(a)     fd[ 7]                 = a       end +
    ("NUM"          * s^1 * n * n * n                    ) / function(a,b,c) fd[ 8], fd[ 9], fd[10] = a, b, c end +
    ("DENOM"        * s^1 * n * n                        ) / function(a,b  ) fd[11], fd[12]         = a, b    end +
    ("SUP"          * s^1 * n * n * n                    ) / function(a,b,c) fd[13], fd[14], fd[15] = a, b, c end +
    ("SUB"          * s^1 * n * n                        ) / function(a,b)   fd[16], fd[17]         = a, b    end +
    ("SUPDROP"      * s^1 * n                            ) / function(a)     fd[18]                 = a       end +
    ("SUBDROP"      * s^1 * n                            ) / function(a)     fd[19]                 = a       end +
    ("DELIM"        * s^1 * n * n                        ) / function(a,b)   fd[20], fd[21]         = a, b    end +
    ("AXISHEIGHT"   * s^1 * n                            ) / function(a)     fd[22]                 = a       end +
    (1-l)^0
) + (1-c)^1)^0

local function scan_comment(str)
    fd = { }
    lpegmatch(pattern,str)
    return fd
end

-- On a rainy day I will rewrite this in lpeg ... or we can use the (slower) fontloader
-- as in now supports afm/pfb loading.

local keys = { }

function keys.FontName    (data,line) data.metadata.fontname     = strip    (line) -- get rid of spaces
                                      data.metadata.fullname     = strip    (line) end
function keys.ItalicAngle (data,line) data.metadata.italicangle  = tonumber (line) end
function keys.IsFixedPitch(data,line) data.metadata.isfixedpitch = toboolean(line,true) end
function keys.CharWidth   (data,line) data.metadata.charwidth    = tonumber (line) end
function keys.XHeight     (data,line) data.metadata.xheight      = tonumber (line) end
function keys.Descender   (data,line) data.metadata.descender    = tonumber (line) end
function keys.Ascender    (data,line) data.metadata.ascender     = tonumber (line) end
function keys.Comment     (data,line)
 -- Comment DesignSize 12 (pts)
 -- Comment TFM designsize: 12 (in points)
    line = lower(line)
    local designsize = match(line,"designsize[^%d]*(%d+)")
    if designsize then data.metadata.designsize = tonumber(designsize) end
end

local function get_charmetrics(data,charmetrics,vector)
    local characters = data.characters
    local chr, str, ind = { }, "", 0
    for k,v in gmatch(charmetrics,"([%a]+) +(.-) *;") do
        if k == 'C'  then
            if str ~= "" then characters[str] = chr end
            chr = { }
            str = ""
            v = tonumber(v)
            if v < 0 then
                ind = ind + 1
            else
                ind = v
            end
            chr.index = ind
        elseif k == 'WX' then
            chr.width = v
        elseif k == 'N'  then
            str = v
        elseif k == 'B'  then
            local llx, lly, urx, ury = match(v,"^ *(.-) +(.-) +(.-) +(.-)$")
            chr.boundingbox = { tonumber(llx), tonumber(lly), tonumber(urx), tonumber(ury) }
        elseif k == 'L'  then
            local plus, becomes = match(v,"^(.-) +(.-)$")
            if not chr.ligatures then chr.ligatures = { } end
            chr.ligatures[plus] = becomes
        end
    end
    if str ~= "" then
        characters[str] = chr
    end
end

local function get_kernpairs(data,kernpairs)
    local characters = data.characters
    for one, two, value in gmatch(kernpairs,"KPX +(.-) +(.-) +(.-)\n") do
        local chr = characters[one]
        if chr then
            if not chr.kerns then chr.kerns = { } end
            chr.kerns[two] = tonumber(value)
        end
    end
end

local function get_variables(data,fontmetrics)
    for key, rest in gmatch(fontmetrics,"(%a+) *(.-)[\n\r]") do
        if keys[key] then keys[key](data,rest) end
    end
end

local function get_indexes(data,pfbname)
    data.luatex.filename = resolvers.unresolve(pfbname) -- no shortcut
    local pfbblob = fontloader.open(pfbname)
    if pfbblob then
        local characters = data.characters
        local pfbdata = fontloader.to_table(pfbblob)
    --~ print(table.serialize(pfbdata))
        if pfbdata then
            local glyphs = pfbdata.glyphs
            if glyphs then
                if trace_loading then
                    report_afm("getting index data from %s",pfbname)
                end
                -- local offset = (glyphs[0] and glyphs[0] != .notdef) or 0
                for index, glyph in next, glyphs do
                    local name = glyph.name
                    if name then
                        local char = characters[name]
                        if char then
                            if trace_indexing then
                                report_afm("glyph %s has index %s",name,index)
                            end
                            char.index = index
                        end
                    end
                end
            elseif trace_loading then
                report_afm("no glyph data in pfb file %s",pfbname)
            end
        elseif trace_loading then
            report_afm("no data in pfb file %s",pfbname)
        end
        fontloader.close(pfbblob)
    elseif trace_loading then
        report_afm("invalid pfb file %s",pfbname)
    end
end

local function readafm(filename)
    local ok, afmblob, size = resolvers.loadbinfile(filename) -- has logging
--  local ok, afmblob = true, file.readdata(filename)
    if ok and afmblob then
        local data = {
            characters = { },
            metadata = {
                version = version or '0', -- hm
                filename = file.removesuffix(file.basename(filename))
            }
        }
        afmblob = gsub(afmblob,"StartCharMetrics(.-)EndCharMetrics", function(charmetrics)
            if trace_loading then
                report_afm("loading char metrics")
            end
            get_charmetrics(data,charmetrics,vector)
            return ""
        end)
        afmblob = gsub(afmblob,"StartKernPairs(.-)EndKernPairs", function(kernpairs)
            if trace_loading then
                report_afm("loading kern pairs")
            end
            get_kernpairs(data,kernpairs)
            return ""
        end)
        afmblob = gsub(afmblob,"StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics", function(version,fontmetrics)
            if trace_loading then
                report_afm("loading variables")
            end
            data.afmversion = version
            get_variables(data,fontmetrics)
            data.fontdimens = scan_comment(fontmetrics) -- todo: all lpeg, no time now
            return ""
        end)
        data.luatex = { }
        return data
    else
        if trace_loading then
            report_afm("no valid afm file %s",filename)
        end
        return nil
    end
end

--[[ldx--
<p>We cache files. Caching is taken care of in the loader. We cheat a bit
by adding ligatures and kern information to the afm derived data. That
way we can set them faster when defining a font.</p>
--ldx]]--

local addkerns, addligatures, unify -- we will implement these later

function afm.load(filename)
    -- hm, for some reasons not resolved yet
    filename = resolvers.findfile(filename,'afm') or ""
    if filename ~= "" then
        local name = file.removesuffix(file.basename(filename))
        local data = containers.read(afm.cache,name)
        local attr = lfs.attributes(filename)
        local size, time = attr.size or 0, attr.modification or 0
        --
        local pfbfile = file.replacesuffix(name,"pfb")
        local pfbname = resolvers.findfile(pfbfile,"pfb") or ""
        if pfbname == "" then
            pfbname = resolvers.findfile(file.basename(pfbfile),"pfb") or ""
        end
        local pfbsize, pfbtime = 0, 0
        if pfbname ~= "" then
            local attr = lfs.attributes(pfbname)
            pfbsize, pfbtime = attr.size or 0, attr.modification or 0
        end
        if not data or data.verbose ~= fonts.verbose
                or data.size ~= size or data.time ~= time or data.pfbsize ~= pfbsize or data.pfbtime ~= pfbtime then
            report_afm( "reading %s",filename)
            data = readafm(filename)
            if data then
            --  data.luatex = data.luatex or { }
                if pfbname ~= "" then
                    get_indexes(data,pfbname)
                elseif trace_loading then
                    report_afm("no pfb file for %s",filename)
                end
                report_afm( "unifying %s",filename)
                unify(data,filename)
                if afm.addligatures then
                    report_afm( "add ligatures")
                    addligatures(data,'ligatures') -- easier this way
                end
                if afm.addtexligatures then
                    report_afm( "add tex-ligatures")
                    addligatures(data,'texligatures') -- easier this way
                end
                if afm.addkerns then
                    report_afm( "add extra kerns")
                    addkerns(data) -- faster this way
                end
                report_afm( "add tounicode data")
                fonts.map.addtounicode(data,filename)
                data.size = size
                data.time = time
                data.pfbsize = pfbsize
                data.pfbtime = pfbtime
                data.verbose = fonts.verbose
                report_afm("saving: %s in cache",name)
                data = containers.write(afm.cache, name, data)
                data = containers.read(afm.cache,name)
            end
        end
        return data
    else
        return nil
    end
end

local uparser = fonts.map.makenameparser()

unify = function(data, filename)
    local unicodevector = fonts.enc.agl.unicodes -- loaded runtime in context
    local glyphs, indices, unicodes, names = { }, { }, { }, { }
    local verbose, private = fonts.verbose, fonts.privateoffset
    for name, blob in next, data.characters do
        local code = unicodevector[name] -- or characters.name_to_unicode[name]
        if not code then
         -- local u = match(name,"^uni(%x+)$")
         -- code = u and tonumber(u,16)
            code = lpegmatch(uparser,name)
            if not code then
                code = private
                private = private + 1
                report_afm("assigning private slot U+%04X for unknown glyph name %s", code, name)
            end
        end
        local index = blob.index
        unicodes[name] = code
        indices[code] = index
        glyphs[index] = blob
        names[name] = index
        blob.name = name
        if verbose then
            local bu = blob.unicode
            if not bu then
                blob.unicode = code
            elseif type(bu) == "table" then
                bu[#bu+1] = code
            else
                blob.unicode = { bu, code }
            end
        else
            blob.index = nil
        end
    end
    data.glyphs = glyphs
    data.characters = nil
    local luatex = data.luatex
    local filename = luatex.filename or file.removesuffix(file.basename(filename))
    luatex.filename = resolvers.unresolve(filename) -- no shortcut
    luatex.unicodes = unicodes -- name to unicode
    luatex.indices = indices -- unicode to index
    luatex.marks = { } -- todo
    luatex.names = names -- name to index
    luatex.private = private
end

--[[ldx--
<p>These helpers extend the basic table with extra ligatures, texligatures
and extra kerns. This saves quite some lookups later.</p>
--ldx]]--

addligatures = function(afmdata,ligatures)
    local glyphs, luatex = afmdata.glyphs, afmdata.luatex
    local indices, unicodes, names = luatex.indices, luatex.unicodes, luatex.names
    for k,v in next, characters[ligatures] do -- main characters table
        local one = glyphs[names[k]]
        if one then
            for _, b in next, v do
                two, three = b[1], b[2]
                if two and three and names[two] and names[three] then
                    local ol = one[ligatures]
                    if ol then
                        if not ol[two] then -- was one.ligatures ... bug
                            ol[two] = three
                        end
                    else
                        one[ligatures] = { [two] = three }
                    end
                end
            end
        end
    end
end

--[[ldx--
<p>We keep the extra kerns in separate kerning tables so that we can use
them selectively.</p>
--ldx]]--

addkerns = function(afmdata) -- using shcodes is not robust here
    local glyphs = afmdata.glyphs
    local names = afmdata.luatex.names
    local uncomposed = characters.uncomposed
    local function do_it_left(what)
        for index, glyph in next, glyphs do
            local kerns = glyph.kerns
            if kerns then
                local extrakerns = glyph.extrakerns or { }
                for complex, simple in next, uncomposed[what] do
                    if names[compex] then
                        local ks = kerns[simple]
                        if ks and not kerns[complex] then
                            extrakerns[complex] = ks
                        end
                    end
                end
                if next(extrakerns) then
                    glyph.extrakerns = extrakerns
                end
            end
        end
    end
    local function do_it_copy(what)
        for complex, simple in next, uncomposed[what] do
            local c = glyphs[names[complex]]
            if c then -- optional
                local s = glyphs[names[simple]]
                if s then
                    if not c.kerns then
                        c.extrakerns = s.kerns or { }
                    end
                    if s.extrakerns then
                        local extrakerns = c.extrakerns or { }
                        for k, v in next, s.extrakerns do
                            extrakerns[k] = v
                        end
                        if next(extrakerns) then
                            s.extrakerns = extrakerns
                        end
                    end
                end
            end
        end
    end
    -- add complex with values of simplified when present
    do_it_left("left")
    do_it_left("both")
    -- copy kerns from simple char to complex char unless set
    do_it_copy("both")
    do_it_copy("right")
end

--[[ldx--
<p>The copying routine looks messy (and is indeed a bit messy).</p>
--ldx]]--

-- once we have otf sorted out (new format) we can try to make the afm
-- cache similar to it (similar tables)

local function adddimensions(data) -- we need to normalize afm to otf i.e. indexed table instead of name
    if data then
        for index, glyph in next, data.glyphs do
            local bb = glyph.boundingbox
            if bb then
                local ht, dp = bb[4], -bb[2]
                if ht == 0 or ht < 0 then
                    -- no need to set it and no negative heights, nil == 0
                else
                    glyph.height = ht
                end
                if dp == 0 or dp < 0 then
                    -- no negative depths and no negative depths, nil == 0
                else
                    glyph.depth  = dp
                end
            end
        end
    end
end

local function copytotfm(data)
    if data then
        local glyphs = data.glyphs
        if glyphs then
            local metadata, luatex = data.metadata, data.luatex
            local unicodes, indices = luatex.unicodes, luatex.indices
            local characters, parameters, descriptions = { }, { }, { }
            local mode = data.mode or "base"
           -- todo : merge into tfm
            for u, i in next, indices do
                local d = glyphs[i]
                characters[u] = { }
                descriptions[u] = d
            end
            local filename = fonts.tfm.checkedfilename(luatex) -- was metadata.filename
            local fontname = metadata.fontname or metadata.fullname
            local fullname = metadata.fullname or metadata.fontname
            local endash, emdash, spacer, spaceunits = unicodes['space'], unicodes['emdash'], "space", 500
            -- same as otf
            if metadata.isfixedpitch then
                if descriptions[endash] then
                    spaceunits, spacer = descriptions[endash].width, "space"
                end
                if not spaceunits and descriptions[emdash] then
                    spaceunits, spacer = descriptions[emdash].width, "emdash"
                end
                if not spaceunits and metadata.charwidth then
                    spaceunits, spacer = metadata.charwidth, "charwidth"
                end
            else
                if descriptions[endash] then
                    spaceunits, spacer = descriptions[endash].width, "space"
                end
                if not spaceunits and metadata.charwidth then
                    spaceunits, spacer = metadata.charwidth, "charwidth"
                end
            end
            spaceunits = tonumber(spaceunits)
            if spaceunits < 200 then
                -- todo: warning
            end
            --
            parameters.slant         = 0
            parameters.space         = spaceunits
            parameters.space_stretch = 500
            parameters.space_shrink  = 333
            parameters.x_height      = 400
            parameters.quad          = 1000
            local italicangle = data.metadata.italicangle
            if italicangle then
                parameters.slant = parameters.slant - math.round(math.tan(italicangle*math.pi/180))
            end
            if metadata.isfixedpitch then
                parameters.space_stretch = 0
                parameters.space_shrink  = 0
            elseif afm.syncspace then
                parameters.space_stretch = spaceunits/2
                parameters.space_shrink  = spaceunits/3
            end
            parameters.extra_space = parameters.space_shrink
            if metadata.xheight and metadata.xheight > 0 then
                parameters.x_height = metadata.xheight
            else
                -- same as otf
                local x = unicodes['x']
                if x then
                    local x = descriptions[x]
                    if x then
                        parameters.x_height = x.height
                    end
                end
                --
            end
            local fd = data.fontdimens
            if fd and fd[8] and fd[9] and fd[10] then -- math
                for k,v in next, fd do
                    parameters[k] = v
                end
            end
            --
            if next(characters) then
                return {
                    characters         = characters,
                    parameters         = parameters,
                    descriptions       = descriptions,
                    indices            = indices,
                    unicodes           = unicodes,
                    luatex             = luatex,
                    encodingbytes      = 2,
                    mode               = mode,
                    filename           = filename,
                    fontname           = fontname,
                    fullname           = fullname,
                    psname             = fullname, -- in otf: tfm.fontname or tfm.fullname
                    name               = filename or fullname or fontname,
                    format             = fonts.fontformat(filename,"type1"),
                    type               = 'real',
                    units              = 1000,
                    direction          = 0,
                    boundarychar_label = 0,
                    boundarychar       = 65536,
                --~ false_boundarychar = 65536, -- produces invalid tfm in luatex
                    designsize         = (metadata.designsize or 10)*65536,
                    spacer             = spacer,
                    ascender           = abs(metadata.ascender  or 0),
                    descender          = abs(metadata.descender or 0),
                    italicangle        = italicangle,
                }
            end
        end
    end
    return nil
end

--[[ldx--
<p>Originally we had features kind of hard coded for <l n='afm'/>
files but since I expect to support more font formats, I decided
to treat this fontformat like any other and handle features in a
more configurable way.</p>
--ldx]]--

local function register_feature(name,default)
    afmfeatures.list[#afmfeatures.list+1] = name
    afmfeatures.default[name] = default
end

afmfeatures.register = register_feature

local function setfeatures(tfmdata)
    local shared = tfmdata.shared
    local afmdata = shared.afmdata
    local features = shared.features
    if features and next(features) then
        local mode = tfmdata.mode or features.mode or "base"
        local initializers = fonts.initializers
        local fi = initializers[mode]
        local fiafm = fi and fi.afm
        if fiafm then
            local lists = {
                fonts.triggers,
                afmfeatures.list,
                fonts.manipulators,
            }
            for l=1,3 do
                local list = lists[l]
                if list then
                    for i=1,#list do
                        local f = list[i]
                        local value = features[f]
                        if value and fiafm[f] then -- brr
                            if trace_features then
                                report_afm("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                            end
                            fiafm[f](tfmdata,value)
                            mode = tfmdata.mode or features.mode or "base"
                            fiafm = initializers[mode].afm
                        end
                    end
                end
            end
        end
        local fm = fonts.methods[mode]
        local fmafm = fm and fm.afm
        if fmafm then
            local lists = {
                afmfeatures.list,
            }
            local sp = shared.processors
            for l=1,1 do
                local list = lists[l]
                if list then
                    for i=1,#list do
                        local f = list[i]
                        if features[f] and fmafm[f] then -- brr
                            if not sp then
                                sp = { fmafm[f] }
                                shared.processors = sp
                            else
                                sp[#sp+1] = fmafm[f]
                            end
                        end
                    end
                end
            end
        end
    end
end

local function checkfeatures(specification)
    local features, done = definers.check(specification.features.normal,afmfeatures.default)
    if done then
        specification.features.normal = features
        tfm.hashinstance(specification,true)
    end
end

local function afmtotfm(specification)
    local afmname = specification.filename or specification.name
    if specification.forced == "afm" or specification.format == "afm" then -- move this one up
        if trace_loading then
            report_afm("forcing afm format for %s",afmname)
        end
    else
        local tfmname = findbinfile(afmname,"ofm") or ""
        if tfmname ~= "" then
            if trace_loading then
                report_afm("fallback from afm to tfm for %s",afmname)
            end
            afmname = ""
        end
    end
    if afmname == "" then
        return nil
    else
        checkfeatures(specification)
        specification = definers.resolve(specification) -- new, was forgotten
        local features = specification.features.normal
        local cache_id = specification.hash
        local tfmdata  = containers.read(tfm.cache, cache_id) -- cache with features applied
        if not tfmdata then
            local afmdata = afm.load(afmname)
            if afmdata and next(afmdata) then
                adddimensions(afmdata)
                tfmdata = copytotfm(afmdata)
                if tfmdata and next(tfmdata) then
                    local shared = tfmdata.shared
                    local unique = tfmdata.unique
                    if not shared then shared = { } tfmdata.shared = shared end
                    if not unique then unique = { } tfmdata.unique = unique end
                    shared.afmdata, shared.features = afmdata, features
                    setfeatures(tfmdata)
                end
            elseif trace_loading then
                report_afm("no (valid) afm file found with name %s",afmname)
            end
            tfmdata = containers.write(tfm.cache,cache_id,tfmdata)
        end
        return tfmdata
    end
end

--[[ldx--
<p>As soon as we could intercept the <l n='tfm'/> reader, I implemented an
<l n='afm'/> reader. Since traditional <l n='pdftex'/> could use <l n='opentype'/>
fonts with <l n='afm'/> companions, the following method also could handle
those cases, but now that we can handle <l n='opentype'/> directly we no longer
need this features.</p>
--ldx]]--

-- tfm.default_encoding = 'unicode'
--
-- function tfm.setnormalfeature(specification,name,value)
--     if specification and name then
--         local features = specification.features
--         if not features then
--             features = { }
--             specification.features = features
--         end
--         local normalfeatures = features.normal
--         if normalfeatures then
--             normalfeatures[name] = value
--         else
--             features.normal = { [name] = value }
--         end
--     end
-- end

local function read_from_afm(specification)
    local tfmtable = afmtotfm(specification)
    if tfmtable then
        tfmtable.name = specification.name
        tfmtable = tfm.scale(tfmtable, specification.size, specification.relativeid)
        local afmdata = tfmtable.shared.afmdata
        fonts.logger.save(tfmtable,'afm',specification)
    end
    return tfmtable
end

--[[ldx--
<p>Here comes the implementation of a few features. We only implement
those that make sense for this format.</p>
--ldx]]--

local function prepare_ligatures(tfmdata,ligatures,value)
    if value then
        local afmdata = tfmdata.shared.afmdata
        local luatex = afmdata.luatex
        local unicodes = luatex.unicodes
        local descriptions = tfmdata.descriptions
        for u, chr in next, tfmdata.characters do
            local d = descriptions[u]
            local l = d[ligatures]
            if l then
                local ligatures = chr.ligatures
                if not ligatures then
                    ligatures = { }
                    chr.ligatures = ligatures
                end
                for k, v in next, l do
                    local uk, uv = unicodes[k], unicodes[v]
                    if uk and uv then
                        ligatures[uk] = {
                            char = uv,
                            type = 0
                        }
                    end
                end
            end
        end
    end
end

local function prepare_kerns(tfmdata,kerns,value)
    if value then
        local afmdata = tfmdata.shared.afmdata
        local luatex = afmdata.luatex
        local unicodes = luatex.unicodes
        local descriptions = tfmdata.descriptions
        for u, chr in next, tfmdata.characters do
            local d = descriptions[u]
            local newkerns = d[kerns]
            if newkerns then
                local kerns = chr.kerns
                if not kerns then
                    kerns = { }
                    chr.kerns = kerns
                end
                for k,v in next, newkerns do
                    local uk = unicodes[k]
                    if uk then
                        kerns[uk] = v
                    end
                end
            end
        end
    end
end

-- hm, register?

local base_initializers   = fonts.initializers.base.afm
local node_initializers   = fonts.initializers.node.afm
local common_initializers = fonts.initializers.common

local function ligatures   (tfmdata,value) prepare_ligatures(tfmdata,'ligatures',   value) end
local function texligatures(tfmdata,value) prepare_ligatures(tfmdata,'texligatures',value) end
local function kerns       (tfmdata,value) prepare_kerns    (tfmdata,'kerns',       value) end
local function extrakerns  (tfmdata,value) prepare_kerns    (tfmdata,'extrakerns',  value) end

register_feature('liga')       -- was true
register_feature('kern')       -- was true
register_feature('extrakerns') -- needed?

base_initializers.ligatures    = ligatures
node_initializers.ligatures    = ligatures
base_initializers.texligatures = texligatures
node_initializers.texligatures = texligatures
base_initializers.kern         = kerns
node_initializers.kerns        = kerns
node_initializers.extrakerns   = extrakerns
base_initializers.extrakerns   = extrakerns

base_initializers.liga         = ligatures
node_initializers.liga         = ligatures
base_initializers.tlig         = texligatures
node_initializers.tlig         = texligatures
base_initializers.trep         = tfm.replacements
node_initializers.trep         = tfm.replacements

register_feature('tlig') -- was true -- todo: also proper features for afm
register_feature('trep') -- was true -- todo: also proper features for afm

-- tfm features

base_initializers.equaldigits = common_initializers.equaldigits
node_initializers.equaldigits = common_initializers.equaldigits
base_initializers.lineheight  = common_initializers.lineheight
node_initializers.lineheight  = common_initializers.lineheight

-- vf features

base_initializers.compose = common_initializers.compose
node_initializers.compose = common_initializers.compose

-- afm specific, encodings ...kind of obsolete

register_feature('encoding')

base_initializers.encoding = common_initializers.encoding
node_initializers.encoding = common_initializers.encoding

-- todo: oldstyle smallcaps as features for afm files (use with care)

base_initializers.onum  = common_initializers.oldstyle
base_initializers.smcp  = common_initializers.smallcaps
base_initializers.fkcp  = common_initializers.fakecaps

register_feature('onum',false)
register_feature('smcp',false)
register_feature('fkcp',false)

-- readers

local check_tfm   = readers.check_tfm

fonts.formats.afm = "type1"
fonts.formats.pfb = "type1"

local function check_afm(specification,fullname)
    local foundname = findbinfile(fullname, 'afm') or "" -- just to be sure
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"afm")
    end
    if foundname == "" and tfm.autoprefixedafm then
        local encoding, shortname = match(fullname,"^(.-)%-(.*)$") -- context: encoding-name.*
        if encoding and shortname and fonts.enc.known[encoding] then
            shortname = findbinfile(shortname,'afm') or "" -- just to be sure
            if shortname ~= "" then
                foundname = shortname
                if trace_defining then
                    report_afm("stripping encoding prefix from filename %s",afmname)
                end
            end
        end
    end
    if foundname ~= "" then
        specification.filename, specification.format = foundname, "afm"
        return read_from_afm(specification)
    end
end

function readers.afm(specification,method)
    local fullname, tfmtable = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmtable = check_afm(specification,specification.name .. "." .. forced)
        end
        if not tfmtable then
            method = method or definers.method or "afm or tfm"
            if method == "tfm" then
                tfmtable = check_tfm(specification,specification.name)
            elseif method == "afm" then
                tfmtable = check_afm(specification,specification.name)
            elseif method == "tfm or afm" then
                tfmtable = check_tfm(specification,specification.name) or check_afm(specification,specification.name)
            else -- method == "afm or tfm" or method == "" then
                tfmtable = check_afm(specification,specification.name) or check_tfm(specification,specification.name)
            end
        end
    else
        tfmtable = check_afm(specification,fullname)
    end
    return tfmtable
end

function readers.pfb(specification,method) -- only called when forced
    local original = specification.specification
    if trace_defining then
        report_afm("using afm reader for '%s'",original)
    end
    specification.specification = gsub(original,"%.pfb",".afm")
    specification.forced = "afm"
    return readers.afm(specification,method)
end
