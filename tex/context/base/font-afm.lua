if not modules then modules = { } end modules ['font-afm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
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

local format = string.format

fonts      = fonts     or { }
fonts.afm  = fonts.afm or { }

local afm = fonts.afm
local tfm = fonts.tfm

afm.version          = 1.26 -- incrementing this number one up will force a re-cache
afm.syncspace        = true -- when true, nicer stretch values
afm.enhance_data     = true -- best leave this set to true
afm.trace_features   = false
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

do

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

    function afm.scan_comment(str)
        fd = { }
        pattern:match(str)
        return fd
    end

end

do

    -- On a rainy day I will rewrite this in lpeg ...

    local keys = { }

    function keys.FontName    (data,line) data.fullname     = line:strip() end
    function keys.ItalicAngle (data,line) data.italicangle  = tonumber (line) end
    function keys.IsFixedPitch(data,line) data.isfixedpitch = toboolean(line,true) end
    function keys.CharWidth   (data,line) data.charwidth    = tonumber (line) end
    function keys.XHeight     (data,line) data.xheight      = tonumber (line) end
    function keys.Descender   (data,line) data.descender    = tonumber (line) end
    function keys.Ascender    (data,line) data.ascender     = tonumber (line) end
    function keys.Comment     (data,line)
     -- Comment DesignSize 12 (pts)
     -- Comment TFM designsize: 12 (in points)
        line = line:lower()
        local designsize = line:match("designsize[^%d]*(%d+)")
        if designsize then data.designsize = tonumber(designsize) end
    end

    local function get_charmetrics(data,charmetrics,vector)
        local characters = data.characters
        local chr, str, ind = { }, "", 0
        for k,v in charmetrics:gmatch("([%a]+) +(.-) *;") do
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
                local llx, lly, urx, ury = v:match("^ *(.-) +(.-) +(.-) +(.-)$")
                chr.boundingbox = { tonumber(llx), tonumber(lly), tonumber(urx), tonumber(ury) }
            elseif k == 'L'  then
                local plus, becomes = v:match("^(.-) +(.-)$")
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
        for one, two, value in kernpairs:gmatch("KPX +(.-) +(.-) +(.-)\n") do
            local chr = characters[one]
            if chr then
                if not chr.kerns then chr.kerns = { } end
                chr.kerns[two] = tonumber(value)
            end
        end
    end

    local function get_variables(data,fontmetrics)
        for key, rest in fontmetrics:gmatch("(%a+) *(.-)[\n\r]") do
            if keys[key] then keys[key](data,rest) end
        end
    end

    local function get_indexes(data,filename)
        local trace = fonts.trace
        local pfbname = input.find_file(file.removesuffix(file.basename(filename))..".pfb","pfb") or ""
        if pfbname ~= "" then
            data.luatex = data.luatex or { }
            data.luatex.filename = pfbname
            local pfbblob = fontforge.open(pfbname)
            if pfbblob then
                local characters = data.characters
                local pfbdata = fontforge.to_table(pfbblob)
            --~ print(table.serialize(pfbdata))
                if pfbdata then
                    local glyphs = pfbdata.glyphs
                    if glyphs then
                        if trace then
                            logs.report("load afm","getting index data from %s",pfbname)
                        end
                        -- local offset = (glyphs[0] and glyphs[0] != .notdef) or 0
                        for index, glyph in pairs(glyphs) do
                            local name = glyph.name
                            if name then
                                local char = characters[name]
                                if char then
                                    if trace then
                                        logs.report("load afm","glyph %s has index %s",name,index)
                                    end
                                    char.index = index
                                end
                            end
                        end
                    elseif trace then
                        logs.report("load afm","no glyph data in pfb file %s",pfbname)
                    end
                elseif trace then
                    logs.report("load afm","no data in pfb file %s",pfbname)
                end
            elseif trace then
                logs.report("load afm","invalid pfb file %s",pfbname)
            end
        elseif trace then
            logs.report("load afm","no pfb file for %s",filename)
        end
    end

    function afm.read_afm(filename)
        local ok, afmblob, size = input.loadbinfile(filename) -- has logging
    --  local ok, afmblob = true, file.readdata(filename)
        if ok and afmblob then
            local data = {
                version = version or '0',
                characters = { },
                filename = file.removesuffix(file.basename(filename))
            }
            afmblob = afmblob:gsub("StartCharMetrics(.-)EndCharMetrics", function(charmetrics)
                if fonts.trace then
                    logs.report("load afm","loading char metrics")
                end
                get_charmetrics(data,charmetrics,vector)
                return ""
            end)
            afmblob = afmblob:gsub("StartKernPairs(.-)EndKernPairs", function(kernpairs)
                if fonts.trace then
                    logs.report("load afm","loading kern pairs")
                end
                get_kernpairs(data,kernpairs)
                return ""
            end)
            afmblob = afmblob:gsub("StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics", function(version,fontmetrics)
                if fonts.trace then
                    logs.report("load afm","loading variables")
                end
                data.afmversion = version
                get_variables(data,fontmetrics)
                data.fontdimens = afm.scan_comment(fontmetrics) -- todo: all lpeg, no time now
                return ""
            end)
            get_indexes(data,filename)
            return data
        else
            if fonts.trace then
                logs.report("load afm","no valid afm file %s",filename)
            end
            return nil
        end
    end

end

--[[ldx--
<p>We cache files. Caching is taken care of in the loader. We cheat a bit
by adding ligatures and kern information to the afm derived data. That
way we can set them faster when defining a font.</p>
--ldx]]--

function afm.load(filename)
    local name = file.removesuffix(filename)
    local data = containers.read(afm.cache(),name)
    local size = lfs.attributes(name,"size") or 0
    if data and data.size ~= size then
        data = nil
    end
    if not data then
        local foundname = input.find_file(filename,'afm')
        if foundname and foundname ~= "" then
            data = afm.read_afm(foundname)
            if data then
                afm.unify(data,filename)
                if afm.enhance_data then
                    afm.add_ligatures(data,'ligatures') -- easier this way
                    afm.add_ligatures(data,'texligatures') -- easier this way
                    afm.add_kerns(data) -- faster this way
                end
                logs.report("load afm","file size: %s",size)
                data.size = size
                logs.report("load afm","saving: in cache")
                data = containers.write(afm.cache(), name, data)
            end
        end
    end
    return data
end

function afm.unify(data, filename)
--~     local unicode, unicodes, private  = fonts.enc.load('unicode').hash, { }, 0x0F0000
    local unicode, unicodes, private  = fonts.enc.load('unicode').hash, { }, fonts.private
    for name, blob in pairs(data.characters) do
        local code = unicode[name] -- or characters.name_to_unicode[name]
        if not code then
            local u = name:match("^uni(%x+)$")
            code = u and tonumber(u,16)
            if not code then
                code = private
                private = private + 1
                logs.report("afm glyph", "assigning private slot 0x%04X for unknown glyph name %s", code, name)
            end
        end
        blob.unicode = code
        unicodes[name] = code
    end
    data.luatex = {
        filename = file.basename(filename),
    --  version  = afm.version,
        unicodes = unicodes
    }
end

--[[ldx--
<p>These helpers extend the basic table with extra ligatures, texligatures
and extra kerns. This saves quite some lookups later.</p>
--ldx]]--

function afm.add_ligatures(afmdata,ligatures)
    local chars = afmdata.characters
    for k,v in pairs(characters[ligatures]) do
        local one = chars[k]
        if one then
            for _, b in pairs(v) do
                two, three = b[1], b[2]
                if two and three and chars[two] and chars[three] then
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
    local chars = afmdata.characters
    -- add complex with values of simplified when present
    local function do_it_left(what)
        for _,v in pairs(chars) do
            if v.kerns then
                local k = { }
                for complex,simple in pairs(characters.uncomposed[what]) do
                    local ks = k[simple]
                    if ks and not k[complex] then
                        k[complex] = ks
                    end
                end
                if not table.is_empty(k) then
                    v.extrakerns = k
                end
            end
        end
    end
    do_it_left("left")
    do_it_left("both")
    -- copy kerns from simple char to complex char unless set
    local function do_it_copy(what)
        for complex,simple in pairs(characters.uncomposed[what]) do
            local c = chars[complex]
            if c then -- optional
                local s = chars[simple]
                if s and s.kerns then
                    c.extrakerns = s.kerns -- ok ? no merge ?
                end
            end
        end
    end
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
        for n, d in pairs(data.characters) do
            local bb = d.boundingbox
            if bb then
                local ht, dp = bb[4], -bb[2]
                if ht ~= 0 then d.height = ht end
                if dp ~= 0 then d.depth  = dp end
            end
            d.name = n
        end
    end
end

function afm.copy_to_tfm(data)
    if data and data.characters then
        local tfm = { characters = { }, parameters = { } }
        local afmcharacters = data.characters
        local characters, parameters = tfm.characters, tfm.parameters
        if afmcharacters then
            for k, v in pairs(afmcharacters) do
                characters[v.unicode] = { description = v }
            end
        end
        tfm.encodingbytes      = data.encodingbytes or 2
        tfm.fullname           = data.fullname
        tfm.filename           = data.filename
        tfm.name               = tfm.fullname -- data.name or tfm.fullname
        tfm.type               = "real"
        tfm.units              = 1000
        tfm.stretch            = stretch
        tfm.slant              = slant
        tfm.direction          = 0
        tfm.boundarychar_label = 0
        tfm.boundarychar       = 65536
    --~ tfm.false_boundarychar = 65536 -- produces invalid tfm in luatex
        tfm.designsize         = (data.designsize or 10)*65536
        local spaceunits = 500
        tfm.spacer = "500 units"
        if data.isfixedpitch then
            if afmcharacters['space'] and afmcharacters['space'].width then
                spaceunits, tfm.spacer = afmcharacters['space'].width, "space"
            elseif afmcharacters['emdash'] and afmcharacters['emdash'].width then -- funny default
                spaceunits, tfm.spacer = afmcharacters['emdash'].width, "emdash"
            elseif data.charwidth then
                spaceunits, tfm.spacer = data.charwidth, "charwidth"
            end
        elseif afmcharacters['space'] and afmcharacters['space'].width then
            spaceunits, tfm.spacer = afmcharacters['space'].width, "space"
        elseif data.charwidth then
            spaceunits, tfm.spacer = data.charwidth, "charwidth variable"
        end
        spaceunits = tonumber(spaceunits)
        parameters.slant         = 0
        parameters.space         = spaceunits
        parameters.space_stretch = 500
        parameters.space_shrink  = 333
        parameters.x_height      = 400
        parameters.quad          = 1000
        parameters.extra_space   = 0
        if spaceunits < 200 then
            -- todo: warning
        end
        tfm.italicangle = data.italicangle
        tfm.ascender    = math.abs(data.ascender  or 0)
        tfm.descender   = math.abs(data.descender or 0)
        if data.italicangle then
            parameters.slant = parameters.slant - math.round(math.tan(data.italicangle*math.pi/180))
        end
        if data.isfixedpitch then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif afm.syncspace then
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        if data.xheight and data.xheight > 0 then
            parameters.x_height = data.xheight
        elseif afmcharacters['x'] and afmcharacters['x'].height then
            parameters.x_height = afmcharacters['x'].height or 0
        end
        local fd = data.fontdimens
        if fd and fd[8] and fd[9] and fd[10] then -- math
            for k,v in pairs(fd) do
                parameters[k] = v
            end
        end
        if table.is_empty(characters) then
            return nil
        else
            return tfm
        end
    else
        return nil
    end
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
    -- elsewhere: shared.features = fonts.define.check(shared.features,afm.features.default)
    local features = shared.features
    if not table.is_empty(features) then
        local mode = tfmdata.mode or fonts.mode
        local fi = fonts.initializers[mode]
        if fi and fi.afm then
            local function initialize(list) -- using tex lig and kerning
                if list then
                    for _, f in ipairs(list) do
                        local value = features[f]
                        if value and fi.afm[f] then -- brr
                            if afm.trace_features then
                                logs.report("define afm","initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                            end
                            fi.afm[f](tfmdata,value)
                            mode = tfmdata.mode or fonts.mode
                            fi = fonts.initializers[mode]
                        end
                    end
                end
            end
            initialize(fonts.triggers)
            initialize(afm.features.list)
            initialize(fonts.manipulators)
        end
        local fm = fonts.methods[mode]
        if fm and fm.afm then
            local function register(list) -- node manipulations
                if list then
                    for _, f in ipairs(list) do
                        if features[f] and fm.afm[f] then -- brr
                            if not shared.processors then -- maybe also predefine
                                shared.processors = { fm.afm[f] }
                            else
                                shared.processors[#shared.processors+1] = fm.afm[f]
                            end
                        end
                    end
                end
            end
            register(afm.features.list)
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
    local encoding, filename = afmname:match("^(.-)%-(.*)$") -- context: encoding-name.*
    if encoding and filename and fonts.enc.known[encoding] then
        tfm.set_normal_feature(specification,'encoding',encoding) -- will go away
        if fonts.trace then
            logs.report("load afm","stripping encoding prefix from filename %s",afmname)
        end
        afmname = filename
    elseif specification.forced == "afm" then
        if fonts.trace then
            logs.report("load afm","forcing afm format for %s",afmname)
        end
    else
        local tfmname = input.findbinfile(afmname,"ofm") or ""
        if tfmname ~= "" then
            if fonts.trace then
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
            if not table.is_empty(afmdata) then
                afm.add_dimensions(afmdata)
                tfmdata = afm.copy_to_tfm(afmdata)
                if not table.is_empty(tfmdata) then
                    tfmdata.shared = tfmdata.shared or { }
                    tfmdata.unique = tfmdata.unique or { }
                    tfmdata.shared.afmdata  = afmdata
                    tfmdata.shared.features = features
                    afm.set_features(tfmdata)
                end
            elseif fonts.trace then
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
--~ local fullname = input.findbinfile(specification.name,"afm") or ""
--~ if fullname ~= "" then
--~     specification.filename = fullname
--~ end
    local tfmtable = afm.afm_to_tfm(specification)
    if tfmtable then
        tfmtable.name = specification.name
        tfmtable = tfm.scale(tfmtable, specification.size)
        local afmdata = tfmtable.shared.afmdata
        local filename = afmdata and afmdata.luatex and afmdata.luatex.filename
        if not filename then
            -- try to locate anyway and set afmdata.luatex.filename
        end
        if filename then
            tfmtable.encodingbytes = 2
            tfmtable.filename = input.findbinfile(filename,"") or filename
            tfmtable.fullname = afmdata.fontname or afmdata.fullname
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
        local charlist = tfmdata.shared.afmdata.characters
        for _, chr in pairs(tfmdata.characters) do
            local ac = charlist[chr.description.name]
            if ac then
                local al = ac[ligatures]
                if al then
                    local ligatures = chr.ligatures
                    if not ligatures then
                        ligatures = { }
                        chr.ligatures =ligatures
                    end
                    for k,v in pairs(al) do
                        ligatures[charlist[k].unicode] = {
                            char = charlist[v].unicode,
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
        local charlist = tfmdata.shared.afmdata.characters
        for _, chr in pairs(tfmdata.characters) do
            local newkerns = charlist[chr.description.name][kerns]
            if newkerns then
                local kerns = chr.kerns
                if not kerns then
                    kerns = { }
                    chr.kerns = kerns
                end
                for k,v in pairs(newkerns) do
                    kerns[charlist[k].unicode] = v
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

