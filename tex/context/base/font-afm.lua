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

fonts                      = fonts     or { }
fonts.afm                  = fonts.afm or { }
fonts.afm.version          = 1.22 -- incrementing this number one up will force a re-cache
fonts.afm.syncspace        = true -- when true, nicer stretch values
fonts.afm.enhance_data     = true -- best leave this set to true
fonts.afm.trace_features   = false
fonts.afm.features         = { }
fonts.afm.features.aux     = { }
fonts.afm.features.data    = { }
fonts.afm.features.list    = { }
fonts.afm.features.default = { }
fonts.afm.cache            = containers.define("fonts", "afm", fonts.afm.version, true)

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

    function fonts.afm.scan_comment(str)
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
        local pfbname = input.find_file(texmf.instance,file.removesuffix(file.basename(filename))..".pfb","pfb") or ""
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
                            logs.report("define font", string.format("getting index data from %s",pfbname))
                        end
                        -- local offset = (glyphs[0] and glyphs[0] != .notdef) or 0
                        for index, glyph in pairs(glyphs) do
                            local name = glyph.name
                            if name then
                                local char = characters[name]
                                if char then
                                    if trace then
                                        logs.report("define font", string.format("glyph %s has index %s",name,index))
                                    end
                                    char.index = index
                                end
                            end
                        end
                    elseif trace then
                        logs.report("define font", string.format("no glyph data in pfb file %s",pfbname))
                    end
                elseif trace then
                    logs.report("define font", string.format("no data in pfb file %s",pfbname))
                end
            elseif trace then
                logs.report("define font", string.format("invalid pfb file %s",pfbname))
            end
        elseif trace then
            logs.report("define font", string.format("no pfb file for %s",filename))
        end
    end

    function fonts.afm.read_afm(filename)
        local ok, afmblob, size = input.loadbinfile(texmf.instance,filename) -- has logging
    --  local ok, afmblob = true, file.readdata(filename)
        if ok and afmblob then
            local data = {
                version = version or '0',
                characters = { },
                filename = file.removesuffix(file.basename(filename))
            }
            afmblob = afmblob:gsub("StartCharMetrics(.-)EndCharMetrics", function(charmetrics)
                if fonts.trace then
                    logs.report("define font", "loading char metrics")
                end
                get_charmetrics(data,charmetrics,vector)
                return ""
            end)
            afmblob = afmblob:gsub("StartKernPairs(.-)EndKernPairs", function(kernpairs)
                if fonts.trace then
                    logs.report("define font", "loading kern pairs")
                end
                get_kernpairs(data,kernpairs)
                return ""
            end)
            afmblob = afmblob:gsub("StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics", function(version,fontmetrics)
                if fonts.trace then
                    logs.report("define font", "loading variables")
                end
                data.afmversion = version
                get_variables(data,fontmetrics)
                data.fontdimens = fonts.afm.scan_comment(fontmetrics) -- todo: all lpeg, no time now
                return ""
            end)
            get_indexes(data,filename)
            return data
        else
            if fonts.trace then
                logs.report("define font", "no valid afm file " .. filename)
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

function fonts.afm.load(filename)
    local name = file.removesuffix(filename)
    local data = containers.read(fonts.afm.cache,name)
    if not data then
        local foundname = input.find_file(texmf.instance,filename,'afm')
        if foundname and foundname ~= "" then
            data = fonts.afm.read_afm(foundname)
            if data then
                fonts.afm.unify(data,filename)
                if fonts.afm.enhance_data then
                    fonts.afm.add_ligatures(data,'ligatures') -- easier this way
                    fonts.afm.add_ligatures(data,'texligatures') -- easier this way
                    fonts.afm.add_kerns(data) -- faster this way
                end
                data = containers.write(fonts.afm.cache, name, data)
            end
        end
    end
    return data
end

function fonts.afm.unify(data, filename)
    local unicode, private, unicodes = containers.content(fonts.enc.cache,'unicode').hash, 0x0F0000, { }
    for name, blob in pairs(data.characters) do
        local code = unicode[name] -- or characters.name_to_unicode[name]
        if not code then
            code = private
            private = private + 1
        end
        blob.unicode = code
        unicodes[name] = code
    end
    data.luatex = {
        filename = file.basename(filename),
    --  version  = fonts.afm.version,
        unicodes = unicodes
    }
end

--[[ldx--
<p>These helpers extend the basic table with extra ligatures, texligatures
and extra kerns. This saves quite some lookups later.</p>
--ldx]]--

function fonts.afm.add_ligatures(afmdata,ligatures)
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

function fonts.afm.add_kerns(afmdata)
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

function fonts.afm.add_dimensions(data) -- we need to normalize afm to otf i.e. indexed table instead of name
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

function fonts.afm.copy_to_tfm(data)
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
        parameters[1] = 0          -- slant
        parameters[2] = spaceunits -- space
        parameters[3] = 500        -- space_stretch
        parameters[4] = 333        -- space_shrink
        parameters[5] = 400        -- x_height
        parameters[6] = 1000       -- quad
        parameters[7] = 0          -- extra_space (todo)
        if spaceunits < 200 then
            -- todo: warning
        end
        tfm.italicangle = data.italicangle
        tfm.ascender    = math.abs(data.ascender  or 0)
        tfm.descender   = math.abs(data.descender or 0)
        if data.italicangle then
            parameters[1] = parameters[1] - math.round(math.tan(data.italicangle*math.pi/180))
        end
        if data.isfixedpitch then
          parameters[3] = 0
          parameters[4] = 0
        elseif fonts.afm.syncspace then
            parameters[3] = spaceunits/2  -- space_stretch
            parameters[4] = spaceunits/3  -- space_shrink
        end
        if data.xheight and data.xheight > 0 then
            parameters[5] = data.xheight
        elseif afmcharacters['x'] and afmcharacters['x'].height then
            parameters[5] = afmcharacters['x'].height or 0
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

function fonts.afm.features.register(name,default)
    fonts.afm.features.list[#fonts.afm.features.list+1] = name
    fonts.afm.features.default[name] = default
end

function fonts.afm.set_features(tfmdata)
    local shared = tfmdata.shared
    local afmdata = shared.afmdata
    shared.features = fonts.define.check(shared.features,fonts.afm.features.default)
    local features = shared.features
--~ texio.write_nl(table.serialize(features))
    if not table.is_empty(features) then
        local mode = tfmdata.mode or fonts.mode
        local fi = fonts.initializers[mode]
        if fi and fi.afm then
            local function initialize(list) -- using tex lig and kerning
                if list then
                    for _, f in ipairs(list) do
                        local value = features[f]
                        if  value and fi.afm[f] then -- brr
                            if fonts.afm.trace_features then
                                logs.report("define afm",string.format("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown'))
                            end
                            fi.afm[f](tfmdata,value)
                            mode = tfmdata.mode or fonts.mode
                            fi = fonts.initializers[mode]
                        end
                    end
                end
            end
            initialize(fonts.triggers)
            initialize(fonts.afm.features.list)
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
            register(fonts.afm.features.list)
        end
    end
end

function fonts.afm.afm_to_tfm(specification)
    local afmname = specification.filename or specification.name
    local encoding, filename = afmname:match("^(.-)%-(.*)$") -- context: encoding-name.*
    if encoding and filename and fonts.enc.known[encoding] then
        fonts.tfm.set_normal_feature(specification,'encoding',encoding) -- will go away
        if fonts.trace then
            logs.report("define font", string.format("stripping encoding prefix from filename %s",afmname))
        end
        afmname = filename
    elseif specification.forced == "afm" then
        if fonts.trace then
            logs.report("define font", string.format("forcing afm format for %s",afmname))
        end
    else
        local tfmname = input.findbinfile(texmf.instance,afmname,"ofm") or ""
        if tfmname ~= "" then
            if fonts.trace then
                logs.report("define font", string.format("fallback from afm to tfm for %s",afmname))
            end
            afmname = ""
        end
    end
    if afmname == "" then
        return nil
    else
        local features = specification.features.normal
        local cache_id = specification.hash
        local tfmdata  = containers.read(fonts.tfm.cache, cache_id) -- cache with features applied
        if not tfmdata then
            local afmdata = fonts.afm.load(afmname)
            if not table.is_empty(afmdata) then
                fonts.afm.add_dimensions(afmdata)
                tfmdata = fonts.afm.copy_to_tfm(afmdata)
                if not table.is_empty(tfmdata) then
                    tfmdata.shared = tfmdata.shared or { }
                    tfmdata.unique = tfmdata.unique or { }
                    tfmdata.shared.afmdata  = afmdata
                    tfmdata.shared.features = features
                    fonts.afm.set_features(tfmdata)
                end
            elseif fonts.trace then
                logs.report("define font", string.format("no (valid) afm file found with name %s",afmname))
            end
            tfmdata = containers.write(fonts.tfm.cache,cache_id,tfmdata)
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

fonts.tfm.default_encoding = 'unicode'

function fonts.tfm.set_normal_feature(specification,name,value)
    if specification and name then
        specification.features = specification.features or { }
        specification.features.normal = specification.features.normal or { }
        specification.features.normal[name] = value
    end
end

function fonts.tfm.read_from_afm(specification)
--~ local fullname = input.findbinfile(texmf.instance,specification.name,"afm") or ""
--~ if fullname ~= "" then
--~     specification.filename = fullname
--~ end
    local tfmtable = fonts.afm.afm_to_tfm(specification)
    if tfmtable then
        tfmtable.name = specification.name
        tfmtable = fonts.tfm.scale(tfmtable, specification.size)
        local afmdata = tfmtable.shared.afmdata
        local filename = afmdata and afmdata.luatex and afmdata.luatex.filename
        if not filename then
            -- try to locate anyway and set afmdata.luatex.filename
        end
        if filename then
            tfmtable.encodingbytes = 2
            tfmtable.filename = input.findbinfile(texmf.instance,filename,"") or filename
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

function fonts.afm.features.prepare_ligatures(tfmdata,ligatures,value) -- probably faulty / check index
    if value then
        local charlist = tfmdata.shared.afmdata.characters
        for k,v in pairs(tfmdata.characters) do
            local ac = charlist[v.name]
            if ac then
                local al = ac[ligatures]
                if al then
                    local ligatures = { }
                    for k,v in pairs(al) do
                        ligatures[charlist[k].unicode] = {
                            char = charlist[v].unicode,
                            type = 0
                        }
                    end
                    v.ligatures = ligatures
                end
            end
        end
    end
end

function fonts.afm.features.prepare_kerns(tfmdata,kerns,value)
    if value then
        local charlist = tfmdata.shared.afmdata.characters
        for _, chr in pairs(tfmdata.characters) do
            local newkerns = charlist[chr.description.name][kerns]
            if newkerns then
                local t = chr.kerns or { }
                for k,v in pairs(newkerns) do
                    t[charlist[k].unicode] = v
                end
                chr.kerns = t
            end
        end
    end
end

function fonts.initializers.base.afm.ligatures(tfmdata,value)
    fonts.afm.features.prepare_ligatures(tfmdata,'ligatures',value)
end

function fonts.initializers.base.afm.texligatures(tfmdata,value)
    fonts.afm.features.prepare_ligatures(tfmdata,'texligatures',value)
end

function fonts.initializers.base.afm.kerns(tfmdata,value)
    fonts.afm.features.prepare_kerns(tfmdata,'kerns',value)
end

function fonts.initializers.base.afm.extrakerns(tfmdata,value)
    fonts.afm.features.prepare_kerns(tfmdata,'extrakerns',value)
end

fonts.afm.features.register('liga',true)
fonts.afm.features.register('kerns',true)
fonts.afm.features.register('extrakerns') -- needed?

fonts.initializers.node.afm.ligatures    = fonts.initializers.base.afm.ligatures
fonts.initializers.node.afm.texligatures = fonts.initializers.base.afm.texligatures
fonts.initializers.node.afm.kerns        = fonts.initializers.base.afm.kerns
fonts.initializers.node.afm.extrakerns   = fonts.initializers.base.afm.extrakerns

fonts.initializers.base.afm.liga         = fonts.initializers.base.afm.ligatures
fonts.initializers.node.afm.liga         = fonts.initializers.base.afm.ligatures
fonts.initializers.base.afm.tlig         = fonts.initializers.base.afm.texligatures
fonts.initializers.node.afm.tlig         = fonts.initializers.base.afm.texligatures

fonts.initializers.base.afm.trep         = fonts.tfm.replacements
fonts.initializers.node.afm.trep         = fonts.tfm.replacements

fonts.afm.features.register('trep') -- todo: also proper features for afm

-- tfm features

fonts.initializers.base.afm.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.node.afm.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.base.afm.lineheight  = fonts.initializers.common.lineheight
fonts.initializers.node.afm.lineheight  = fonts.initializers.common.lineheight

-- afm specific, encodings ...kind of obsolete

fonts.afm.features.register('encoding')

fonts.initializers.base.afm.encoding = fonts.initializers.common.encoding
fonts.initializers.node.afm.encoding = fonts.initializers.common.encoding

-- todo: oldstyle smallcaps as features for afm files
