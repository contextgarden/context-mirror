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

local trace_features = false  trackers.register("afm.features", function(v) trace_features = v end)
local trace_indexing = false  trackers.register("afm.indexing", function(v) trace_indexing = v end)
local trace_loading  = false  trackers.register("afm.loading",  function(v) trace_loading  = v end)

local format, match, gmatch, lower, gsub = string.format, string.match, string.gmatch, string.lower, string.gsub
local lpegmatch = lpeg.match

fonts      = fonts     or { }
fonts.afm  = fonts.afm or { }

local afm = fonts.afm
local tfm = fonts.tfm

afm.version          = 1.402 -- incrementing this number one up will force a re-cache
afm.syncspace        = true  -- when true, nicer stretch values
afm.enhance_data     = true  -- best leave this set to true
afm.features         = { }
afm.features.aux     = { }
afm.features.data    = { }
afm.features.list    = { }
afm.features.default = { }
afm.cache            = containers.define("fonts", "afm", afm.version, true)

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

local c = lpeg.P("Comment")
local s = lpeg.S(" \t")
local l = lpeg.S("\n\r")
local w = lpeg.C((1 - l)^1)
local n = lpeg.C((lpeg.R("09") + lpeg.S("."))^1) / tonumber * s^0

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

-- On a rainy day I will rewrite this in lpeg ...

local keys = { }

function keys.FontName    (data,line) data.metadata.fullname     = line:strip() end
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

local function get_indexes(data,filename)
    local pfbfile = file.replacesuffix(filename,"pfb")
    local pfbname = resolvers.find_file(pfbfile,"pfb") or ""
    if pfbname == "" then
        pfbname = resolvers.find_file(file.basename(pfbfile),"pfb") or ""
    end
    if pfbname ~= "" then
        data.luatex.filename = pfbname
        local pfbblob = fontloader.open(pfbname)
        if pfbblob then
            local characters = data.characters
            local pfbdata = fontloader.to_table(pfbblob)
        --~ print(table.serialize(pfbdata))
            if pfbdata then
                local glyphs = pfbdata.glyphs
                if glyphs then
                    if trace_loading then
                        logs.report("load afm","getting index data from %s",pfbname)
                    end
                    -- local offset = (glyphs[0] and glyphs[0] != .notdef) or 0
                    for index, glyph in next, glyphs do
                        local name = glyph.name
                        if name then
                            local char = characters[name]
                            if char then
                                if trace_indexing then
                                    logs.report("load afm","glyph %s has index %s",name,index)
                                end
                                char.index = index
                            end
                        end
                    end
                elseif trace_loading then
                    logs.report("load afm","no glyph data in pfb file %s",pfbname)
                end
            elseif trace_loading then
                logs.report("load afm","no data in pfb file %s",pfbname)
            end
            fontloader.close(pfbblob)
        elseif trace_loading then
            logs.report("load afm","invalid pfb file %s",pfbname)
        end
    elseif trace_loading then
        logs.report("load afm","no pfb file for %s",filename)
    end
end

function afm.read_afm(filename)
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
                logs.report("load afm","loading char metrics")
            end
            get_charmetrics(data,charmetrics,vector)
            return ""
        end)
        afmblob = gsub(afmblob,"StartKernPairs(.-)EndKernPairs", function(kernpairs)
            if trace_loading then
                logs.report("load afm","loading kern pairs")
            end
            get_kernpairs(data,kernpairs)
            return ""
        end)
        afmblob = gsub(afmblob,"StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics", function(version,fontmetrics)
            if trace_loading then
                logs.report("load afm","loading variables")
            end
            data.afmversion = version
            get_variables(data,fontmetrics)
            data.fontdimens = scan_comment(fontmetrics) -- todo: all lpeg, no time now
            return ""
        end)
        data.luatex = { }
        get_indexes(data,filename)
        return data
    else
        if trace_loading then
            logs.report("load afm","no valid afm file %s",filename)
        end
        return nil
    end
end

--[[ldx--
<p>We cache files. Caching is taken care of in the loader. We cheat a bit
by adding ligatures and kern information to the afm derived data. That
way we can set them faster when defining a font.</p>
--ldx]]--

function afm.load(filename)
    -- hm, for some reasons not resolved yet
    filename = resolvers.find_file(filename,'afm') or ""
    if filename ~= "" then
        local name = file.removesuffix(file.basename(filename))
        local data = containers.read(afm.cache(),name)
        local size = lfs.attributes(filename,"size") or 0
        if not data or data.verbose ~= fonts.verbose or data.size ~= size then
            logs.report("load afm", "reading %s",filename)
            data = afm.read_afm(filename)
            if data then
            --  data.luatex = data.luatex or { }
                logs.report("load afm", "unifying %s",filename)
                afm.unify(data,filename)
                if afm.enhance_data then
                    logs.report("load afm", "add ligatures")
                    afm.add_ligatures(data,'ligatures') -- easier this way
                    logs.report("load afm", "add tex-ligatures")
                    afm.add_ligatures(data,'texligatures') -- easier this way
                    logs.report("load afm", "add extra kerns")
                    afm.add_kerns(data) -- faster this way
                end
                logs.report("load afm", "add tounicode data")
                fonts.map.add_to_unicode(data,filename)
                data.size = size
                data.verbose = fonts.verbose
                logs.report("load afm","saving: %s in cache",name)
                data = containers.write(afm.cache(), name, data)
                data = containers.read(afm.cache(),name)
            end
        end
        return data
    else
        return nil
    end
end

function afm.unify(data, filename)
    local unicodevector = fonts.enc.load('unicode').hash
    local glyphs, indices, unicodes, names = { }, { }, { }, { }
    local verbose, private = fonts.verbose, fonts.private
    for name, blob in next, data.characters do
        local code = unicodevector[name] -- or characters.name_to_unicode[name]
        if not code then
            local u = match(name,"^uni(%x+)$")
            code = u and tonumber(u,16)
            if not code then
                code = private
                private = private + 1
                logs.report("afm glyph", "assigning private slot U+%04X for unknown glyph name %s", code, name)
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
    luatex.filename = luatex.filename or file.removesuffix(file.basename(filename))
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

function afm.add_ligatures(afmdata,ligatures)
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

function afm.add_kerns(afmdata)
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

function afm.add_dimensions(data) -- we need to normalize afm to otf i.e. indexed table instead of name
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

function afm.copy_to_tfm(data)
    if data then
        local glyphs = data.glyphs
        if glyphs then
            local metadata, luatex = data.metadata, data.luatex
            local unicodes, indices = luatex.unicodes, luatex.indices
            local characters, parameters, descriptions = { }, { }, { }
            local tfm = {
                characters = characters,
                parameters = parameters,
                descriptions = descriptions,
                indices = indices,
                unicodes = unicodes,
                luatex = luatex,
            }
            for u, i in next, indices do
                local d = glyphs[i]
                characters[u] = { }
                descriptions[u] = d
            end
            tfm.encodingbytes      = metadata.encodingbytes or 2
            tfm.fullname           = metadata.fullname
            tfm.filename           = metadata.filename -- = tfm.checked_filename(metadata) -- to be tested first
            tfm.name               = tfm.fullname
            tfm.psname             = tfm.fullname
            tfm.type               = "real"
            tfm.units              = 1000
            tfm.direction          = 0
            tfm.boundarychar_label = 0
            tfm.boundarychar       = 65536
        --~ tfm.false_boundarychar = 65536 -- produces invalid tfm in luatex
            tfm.designsize         = (metadata.designsize or 10)*65536
            local spaceunits = 500
            tfm.spacer = "500 units"
            -- same as otf
            local endash, emdash = unicodes['space'], unicodes['emdash']
            if metadata.isfixedpitch then
                if descriptions[endash] then
                    spaceunits, tfm.spacer = descriptions[endash].width, "space"
                end
                if not spaceunits and descriptions[emdash] then
                    spaceunits, tfm.spacer = descriptions[emdash].width, "emdash"
                end
                if not spaceunits and metadata.charwidth then
                    spaceunits, tfm.spacer = metadata.charwidth, "charwidth"
                end
            else
                if descriptions[endash] then
                    spaceunits, tfm.spacer = descriptions[endash].width, "space"
                end
            --    if not spaceunits and descriptions[emdash] then
            --        spaceunits, tfm.spacer = descriptions[emdash].width/2, "emdash/2"
            --    end
                if not spaceunits and metadata.charwidth then
                    spaceunits, tfm.spacer = metadata.charwidth, "charwidth"
                end
            end
            --
            spaceunits = tonumber(spaceunits)
            parameters.slant         = 0
            parameters.space         = spaceunits
            parameters.space_stretch = 500
            parameters.space_shrink  = 333
            parameters.x_height      = 400
            parameters.quad          = 1000
            if spaceunits < 200 then
                -- todo: warning
            end
            tfm.ascender    = math.abs(metadata.ascender  or 0)
            tfm.descender   = math.abs(metadata.descender or 0)
            local italicangle = data.metadata.italicangle
            if italicangle then
                tfm.italicangle = italicangle
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
            if next(characters) then
                return tfm
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

function afm.features.register(name,default)
    afm.features.list[#afm.features.list+1] = name
    afm.features.default[name] = default
end

function afm.set_features(tfmdata)
    local shared = tfmdata.shared
    local afmdata = shared.afmdata
    local features = shared.features
    if features and next(features) then
        local mode = tfmdata.mode or fonts.mode
        local initializers = fonts.initializers
        local fi = initializers[mode]
        local fiafm = fi and fi.afm
        if fiafm then
            local lists = {
                fonts.triggers,
                afm.features.list,
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
                                logs.report("define afm","initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                            end
                            fiafm[f](tfmdata,value)
                            mode = tfmdata.mode or fonts.mode
                            fiafm = initializers[mode].afm
                        end
                    end
                end
            end
        end
        local fm = fonts.methods[mode]
        local fmafm = fm and fm.afm
        if fmfm then
            local lists = {
                afm.features.list,
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

function afm.check_features(specification)
    local features, done = fonts.define.check(specification.features.normal,afm.features.default)
    if done then
        specification.features.normal = features
        tfm.hash_instance(specification,true)
    end
end

function afm.afm_to_tfm(specification)
    local afmname = specification.filename or specification.name
    if specification.forced == "afm" or specification.format == "afm" then -- move this one up
        if trace_loading then
            logs.report("load afm","forcing afm format for %s",afmname)
        end
    else
        local tfmname = resolvers.findbinfile(afmname,"ofm") or ""
        if tfmname ~= "" then
            if trace_loading then
                logs.report("load afm","fallback from afm to tfm for %s",afmname)
            end
            afmname = ""
        end
    end
    if afmname == "" then
        return nil
    else
        afm.check_features(specification)
        specification = fonts.define.resolve(specification) -- new, was forgotten
        local features = specification.features.normal
        local cache_id = specification.hash
        local tfmdata  = containers.read(tfm.cache(), cache_id) -- cache with features applied
        if not tfmdata then
            local afmdata = afm.load(afmname)
            if afmdata and next(afmdata) then
                afm.add_dimensions(afmdata)
                tfmdata = afm.copy_to_tfm(afmdata)
                if tfmdata and next(tfmdata) then
                    tfmdata.shared = tfmdata.shared or { }
                    tfmdata.unique = tfmdata.unique or { }
                    tfmdata.shared.afmdata  = afmdata
                    tfmdata.shared.features = features
                    afm.set_features(tfmdata)
                end
            elseif trace_loading then
                logs.report("load afm","no (valid) afm file found with name %s",afmname)
            end
            tfmdata = containers.write(tfm.cache(),cache_id,tfmdata)
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

tfm.default_encoding = 'unicode'

function tfm.set_normal_feature(specification,name,value)
    if specification and name then
        specification.features = specification.features or { }
        specification.features.normal = specification.features.normal or { }
        specification.features.normal[name] = value
    end
end

function tfm.read_from_afm(specification)
    local tfmtable = afm.afm_to_tfm(specification)
    if tfmtable then
        tfmtable.name = specification.name
        tfmtable = tfm.scale(tfmtable, specification.size, specification.relativeid)
        local afmdata = tfmtable.shared.afmdata
        local filename = afmdata and afmdata.luatex and afmdata.luatex.filename
        if not filename then
            -- try to locate anyway and set afmdata.luatex.filename
        end
        if filename then
            tfmtable.encodingbytes = 2
            tfmtable.filename = resolvers.findbinfile(filename,"") or filename
            tfmtable.fontname = afmdata.metadata.fontname or afmdata.metadata.fullname
            tfmtable.fullname = afmdata.metadata.fullname or afmdata.metadata.fontname
            tfmtable.format   = 'type1'
            tfmtable.name     = afmdata.luatex.filename or tfmtable.fullname
        end
        if fonts.dontembed[filename] then
            tfmtable.file = nil
        end
        fonts.logger.save(tfmtable,'afm',specification)
    end
    return tfmtable
end

--[[ldx--
<p>Here comes the implementation of a few features. We only implement
those that make sense for this format.</p>
--ldx]]--

function afm.features.prepare_ligatures(tfmdata,ligatures,value)
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

function afm.features.prepare_kerns(tfmdata,kerns,value)
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

function fonts.initializers.base.afm.ligatures   (tfmdata,value) afm.features.prepare_ligatures(tfmdata,'ligatures',   value) end
function fonts.initializers.base.afm.texligatures(tfmdata,value) afm.features.prepare_ligatures(tfmdata,'texligatures',value) end
function fonts.initializers.base.afm.kerns       (tfmdata,value) afm.features.prepare_kerns    (tfmdata,'kerns',       value) end
function fonts.initializers.base.afm.extrakerns  (tfmdata,value) afm.features.prepare_kerns    (tfmdata,'extrakerns',  value) end

afm.features.register('liga',true)
afm.features.register('kerns',true)
afm.features.register('extrakerns') -- needed?

fonts.initializers.node.afm.ligatures    = fonts.initializers.base.afm.ligatures
fonts.initializers.node.afm.texligatures = fonts.initializers.base.afm.texligatures
fonts.initializers.node.afm.kerns        = fonts.initializers.base.afm.kerns
fonts.initializers.node.afm.extrakerns   = fonts.initializers.base.afm.extrakerns

fonts.initializers.base.afm.liga         = fonts.initializers.base.afm.ligatures
fonts.initializers.node.afm.liga         = fonts.initializers.base.afm.ligatures
fonts.initializers.base.afm.tlig         = fonts.initializers.base.afm.texligatures
fonts.initializers.node.afm.tlig         = fonts.initializers.base.afm.texligatures

fonts.initializers.base.afm.trep         = tfm.replacements
fonts.initializers.node.afm.trep         = tfm.replacements

afm.features.register('tlig',true) -- todo: also proper features for afm
afm.features.register('trep',true) -- todo: also proper features for afm

-- tfm features

fonts.initializers.base.afm.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.node.afm.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.base.afm.lineheight  = fonts.initializers.common.lineheight
fonts.initializers.node.afm.lineheight  = fonts.initializers.common.lineheight

-- vf features

fonts.initializers.base.afm.compose = fonts.initializers.common.compose
fonts.initializers.node.afm.compose = fonts.initializers.common.compose

-- afm specific, encodings ...kind of obsolete

afm.features.register('encoding')

fonts.initializers.base.afm.encoding = fonts.initializers.common.encoding
fonts.initializers.node.afm.encoding = fonts.initializers.common.encoding

-- todo: oldstyle smallcaps as features for afm files (use with care)

fonts.initializers.base.afm.onum  = fonts.initializers.common.oldstyle
fonts.initializers.base.afm.smcp  = fonts.initializers.common.smallcaps
fonts.initializers.base.afm.fkcp  = fonts.initializers.common.fakecaps

afm.features.register('onum',false)
afm.features.register('smcp',false)
afm.features.register('fkcp',false)

