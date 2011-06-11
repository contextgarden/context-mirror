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

local next, type, tonumber = next, type, tonumber
local format, match, gmatch, lower, gsub, strip = string.format, string.match, string.gmatch, string.lower, string.gsub, string.strip
local abs = math.abs
local P, S, C, R, lpegmatch, patterns = lpeg.P, lpeg.S, lpeg.C, lpeg.R, lpeg.match, lpeg.patterns
local derivetable = table.derive

local fonts              = fonts
local afm                = { }
local pfb                = { }
fonts.handlers.afm       = afm
fonts.handlers.pfb       = pfb

afm.version              = 1.410 -- incrementing this number one up will force a re-cache
afm.cache                = containers.define("fonts", "afm", afm.version, true)
afm.autoprefixed         = true -- this will become false some day (catches texnansi-blabla.*)

afm.syncspace            = true -- when true, nicer stretch values
afm.addligatures         = true -- best leave this set to true
afm.addtexligatures      = true -- best leave this set to true
afm.addkerns             = true -- best leave this set to true

local definers           = fonts.definers
local readers            = fonts.readers
local constructors       = fonts.constructors

local findbinfile        = resolvers.findbinfile

local afmfeatures        = constructors.newfeatures("afm")
local registerafmfeature = afmfeatures.register

local function setmode(tfmdata,value)
    if value then
        tfmdata.properties.mode = lower(value)
    end
end

registerafmfeature {
    name         = "mode",
    description  = "mode",
    initializers = {
        base = setmode,
        node = setmode,
    }
}

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

local comment = P("Comment")
local spacing = patterns.spacer  -- S(" \t")^1
local lineend = patterns.newline -- S("\n\r")
local words   = C((1 - lineend)^1)
local number  = C((R("09") + S("."))^1) / tonumber * spacing^0
local data    = lpeg.Carg(1)

local pattern = ( -- needs testing ... not used anyway as we no longer need math afm's
    comment * spacing *
        (
            data * (
                ("CODINGSCHEME" * spacing * words                                      ) / function(fd,a)                                      end +
                ("DESIGNSIZE"   * spacing * number * words                             ) / function(fd,a)     fd[ 1]                 = a       end +
                ("CHECKSUM"     * spacing * number * words                             ) / function(fd,a)     fd[ 2]                 = a       end +
                ("SPACE"        * spacing * number * "plus" * number * "minus" * number) / function(fd,a,b,c) fd[ 3], fd[ 4], fd[ 5] = a, b, c end +
                ("QUAD"         * spacing * number                                     ) / function(fd,a)     fd[ 6]                 = a       end +
                ("EXTRASPACE"   * spacing * number                                     ) / function(fd,a)     fd[ 7]                 = a       end +
                ("NUM"          * spacing * number * number * number                   ) / function(fd,a,b,c) fd[ 8], fd[ 9], fd[10] = a, b, c end +
                ("DENOM"        * spacing * number * number                            ) / function(fd,a,b  ) fd[11], fd[12]         = a, b    end +
                ("SUP"          * spacing * number * number * number                   ) / function(fd,a,b,c) fd[13], fd[14], fd[15] = a, b, c end +
                ("SUB"          * spacing * number * number                            ) / function(fd,a,b)   fd[16], fd[17]         = a, b    end +
                ("SUPDROP"      * spacing * number                                     ) / function(fd,a)     fd[18]                 = a       end +
                ("SUBDROP"      * spacing * number                                     ) / function(fd,a)     fd[19]                 = a       end +
                ("DELIM"        * spacing * number * number                            ) / function(fd,a,b)   fd[20], fd[21]         = a, b    end +
                ("AXISHEIGHT"   * spacing * number                                     ) / function(fd,a)     fd[22]                 = a       end
            )
          + (1-lineend)^0
        )
  + (1-comment)^1
)^0

local function scan_comment(str)
    local fd = { }
    lpegmatch(pattern,str,1,fd)
    return fd
end

-- On a rainy day I will rewrite this in lpeg ... or we can use the (slower) fontloader
-- as in now supports afm/pfb loading but it's not too bad to have different methods
-- for testing approaches.

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
    local chr, ind = { }, 0
    for k,v in gmatch(charmetrics,"([%a]+) +(.-) *;") do
        if k == 'C'  then
            v = tonumber(v)
            if v < 0 then
                ind = ind + 1 -- ?
            else
                ind = v
            end
            chr = {
                index = ind
            }
        elseif k == 'WX' then
            chr.width = tonumber(v)
        elseif k == 'N'  then
            characters[v] = chr
        elseif k == 'B'  then
            local llx, lly, urx, ury = match(v,"^ *(.-) +(.-) +(.-) +(.-)$")
            chr.boundingbox = { tonumber(llx), tonumber(lly), tonumber(urx), tonumber(ury) }
        elseif k == 'L'  then
            local plus, becomes = match(v,"^(.-) +(.-)$")
            local ligatures = chr.ligatures
            if ligatures then
                ligatures[plus] = becomes
            else
                chr.ligatures = { [plus] = becomes }
            end
        end
    end
end

local function get_kernpairs(data,kernpairs)
    local characters = data.characters
    for one, two, value in gmatch(kernpairs,"KPX +(.-) +(.-) +(.-)\n") do
        local chr = characters[one]
        if chr then
            local kerns = chr.kerns
            if kerns then
                kerns[two] = tonumber(value)
            else
                chr.kerns = { [two] = tonumber(value) }
            end
        end
    end
end

local function get_variables(data,fontmetrics)
    for key, rest in gmatch(fontmetrics,"(%a+) *(.-)[\n\r]") do
        local keyhandler = keys[key]
        if keyhandler then
            keyhandler(data,rest)
        end
    end
end

local function get_indexes(data,pfbname)
    data.resources.filename = resolvers.unresolve(pfbname) -- no shortcut
    local pfbblob = fontloader.open(pfbname)
    if pfbblob then
        local characters = data.characters
        local pfbdata = fontloader.to_table(pfbblob)
        if pfbdata then
            local glyphs = pfbdata.glyphs
            if glyphs then
                if trace_loading then
                    report_afm("getting index data from %s",pfbname)
                end
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
    if ok and afmblob then
        local data = {
            resources = {
                filename = resolvers.unresolve(filename),
                version  = afm.version,
                creator  = "context mkiv",
            },
            properties = {
                italic_correction = false,
            },
            goodies = {
            },
            metadata   = {
                filename = file.removesuffix(file.basename(filename))
            },
            characters = {
                -- a temporary store
            },
            descriptions = {
                -- the final store
            },
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

local addkerns, addligatures, addtexligatures, unify, normalize -- we will implement these later

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
            pfbsize = attr.size or 0
            pfbtime = attr.modification or 0
        end
        if not data or data.size ~= size or data.time ~= time or data.pfbsize ~= pfbsize or data.pfbtime ~= pfbtime then
            report_afm( "reading %s",filename)
            data = readafm(filename)
            if data then
                if pfbname ~= "" then
                    get_indexes(data,pfbname)
                elseif trace_loading then
                    report_afm("no pfb file for %s",filename)
                end
                report_afm( "unifying %s",filename)
                unify(data,filename)
                if afm.addligatures then
                    report_afm( "add ligatures")
                    addligatures(data)
                end
                if afm.addtexligatures then
                    report_afm( "add tex ligatures")
                    addtexligatures(data)
                end
                if afm.addkerns then
                    report_afm( "add extra kerns")
                    addkerns(data)
                end
                normalize(data)
                report_afm( "add tounicode data")
                fonts.mappings.addtounicode(data,filename)
                data.size = size
                data.time = time
                data.pfbsize = pfbsize
                data.pfbtime = pfbtime
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

local uparser = fonts.mappings.makenameparser()

unify = function(data, filename)
    local unicodevector = fonts.encodings.agl.unicodes -- loaded runtime in context
    local unicodes, names = { }, { }
    local private = constructors.privateoffset
    local descriptions = data.descriptions
    for name, blob in next, data.characters do
        local code = unicodevector[name] -- or characters.name_to_unicode[name]
        if not code then
            code = lpegmatch(uparser,name)
            if not code then
                code = private
                private = private + 1
                report_afm("assigning private slot U+%05X for unknown glyph name %s", code, name)
            end
        end
        local index = blob.index
        unicodes[name] = code
        names[name] = index
        blob.name = name
        descriptions[code] = {
            boundingbox = blob.boundingbox,
            width       = blob.width,
            kerns       = blob.kerns,
            index       = index,
            name        = name,
        }
    end
    for unicode, description in next, descriptions do
        local kerns = description.kerns
        if kerns then
            local krn = { }
            for name, kern in next, kerns do
                local unicode = unicodes[name]
                if unicode then
                    krn[unicode] = kern
                else
                    print(unicode,name)
                end
            end
            description.kerns = krn
        end
    end
    data.characters = nil
    local resources = data.resources
    local filename = resources.filename or file.removesuffix(file.basename(filename))
    resources.filename = resolvers.unresolve(filename) -- no shortcut
    resources.unicodes = unicodes -- name to unicode
    resources.marks = { } -- todo
    resources.names = names -- name to index
    resources.private = private
end

normalize = function(data)
end

--[[ldx--
<p>These helpers extend the basic table with extra ligatures, texligatures
and extra kerns. This saves quite some lookups later.</p>
--ldx]]--

--[[ldx--
<p>Only characters with a code smaller than 128 make sense,
anything larger is encoding dependent. An interesting complication
is that a character can be in an encoding twice but is hashed
once.</p>
--ldx]]--

local ligatures = { -- okay, nowadays we could parse the name but type 1 fonts
    ['f'] = {       -- don't have that many ligatures anyway
        { 'f', 'ff' },
        { 'i', 'fi' },
        { 'l', 'fl' },
    },
    ['ff'] = {
        { 'i', 'ffi' }
    },
    ['fi'] = {
        { 'i', 'fii' }
    },
    ['fl'] = {
        { 'i', 'fli' }
    },
    ['s'] = {
        { 't', 'st' }
    },
    ['i'] = {
        { 'j', 'ij' }
    },
}

local texligatures = {
 -- ['space'] = {
 --     { 'L', 'Lslash' },
 --     { 'l', 'lslash' }
 -- },
 -- ['question'] = {
 --     { 'quoteleft', 'questiondown' }
 -- },
 -- ['exclam'] = {
 --     { 'quoteleft', 'exclamdown' }
 -- },
    ['quoteleft'] = {
        { 'quoteleft', 'quotedblleft' }
    },
    ['quoteright'] = {
        { 'quoteright', 'quotedblright' }
    },
    ['hyphen'] = {
        { 'hyphen', 'endash' }
    },
    ['endash'] = {
        { 'hyphen', 'emdash' }
    }
}

local addthem = function(rawdata,ligatures)
    local descriptions = rawdata.descriptions
    local resources    = rawdata.resources
    local unicodes     = resources.unicodes
    local names        = resources.names
    for ligname, ligdata in next, ligatures do
        local one = descriptions[unicodes[ligname]]
        if one then
            for _, pair in next, ligdata do
                local two, three = unicodes[pair[1]], unicodes[pair[2]]
                if two and three then
                    local ol = one.ligatures
                    if ol then
                        if not ol[two] then
                            ol[two] = three
                        end
                    else
                        one.ligatures = { [two] = three }
                    end
                end
            end
        end
    end
end

addligatures    = function(rawdata) addthem(rawdata,ligatures   ) end
addtexligatures = function(rawdata) addthem(rawdata,texligatures) end

--[[ldx--
<p>We keep the extra kerns in separate kerning tables so that we can use
them selectively.</p>
--ldx]]--

-- This is rather old code (from the beginning when we had only tfm). If
-- we unify the afm data (now we have names all over the place) then
-- we can use shcodes but there will be many more looping then. But we
-- could get rid of the tables in char-cmp then. Als, in the generic version
-- we don't use the character database. (Ok, we can have a context specific
-- variant).

-- we can make them numbers

local left = {
    AEligature = "A",  aeligature = "a",
    OEligature = "O",  oeligature = "o",
    IJligature = "I",  ijligature = "i",
    AE         = "A",  ae         = "a",
    OE         = "O",  oe         = "o",
    IJ         = "I",  ij         = "i",
    Ssharp     = "S",  ssharp     = "s",
}

local right = {
    AEligature = "E",  aeligature = "e",
    OEligature = "E",  oeligature = "e",
    IJligature = "J",  ijligature = "j",
    AE         = "E",  ae         = "e",
    OE         = "E",  oe         = "e",
    IJ         = "J",  ij         = "j",
    Ssharp     = "S",  ssharp     = "s",
}

local both = {
    Acircumflex = "A",  acircumflex = "a",
    Ccircumflex = "C",  ccircumflex = "c",
    Ecircumflex = "E",  ecircumflex = "e",
    Gcircumflex = "G",  gcircumflex = "g",
    Hcircumflex = "H",  hcircumflex = "h",
    Icircumflex = "I",  icircumflex = "i",
    Jcircumflex = "J",  jcircumflex = "j",
    Ocircumflex = "O",  ocircumflex = "o",
    Scircumflex = "S",  scircumflex = "s",
    Ucircumflex = "U",  ucircumflex = "u",
    Wcircumflex = "W",  wcircumflex = "w",
    Ycircumflex = "Y",  ycircumflex = "y",

    Agrave = "A",  agrave = "a",
    Egrave = "E",  egrave = "e",
    Igrave = "I",  igrave = "i",
    Ograve = "O",  ograve = "o",
    Ugrave = "U",  ugrave = "u",
    Ygrave = "Y",  ygrave = "y",

    Atilde = "A",  atilde = "a",
    Itilde = "I",  itilde = "i",
    Otilde = "O",  otilde = "o",
    Utilde = "U",  utilde = "u",
    Ntilde = "N",  ntilde = "n",

    Adiaeresis = "A",  adiaeresis = "a",  Adieresis = "A",  adieresis = "a",
    Ediaeresis = "E",  ediaeresis = "e",  Edieresis = "E",  edieresis = "e",
    Idiaeresis = "I",  idiaeresis = "i",  Idieresis = "I",  idieresis = "i",
    Odiaeresis = "O",  odiaeresis = "o",  Odieresis = "O",  odieresis = "o",
    Udiaeresis = "U",  udiaeresis = "u",  Udieresis = "U",  udieresis = "u",
    Ydiaeresis = "Y",  ydiaeresis = "y",  Ydieresis = "Y",  ydieresis = "y",

    Aacute = "A",  aacute = "a",
    Cacute = "C",  cacute = "c",
    Eacute = "E",  eacute = "e",
    Iacute = "I",  iacute = "i",
    Lacute = "L",  lacute = "l",
    Nacute = "N",  nacute = "n",
    Oacute = "O",  oacute = "o",
    Racute = "R",  racute = "r",
    Sacute = "S",  sacute = "s",
    Uacute = "U",  uacute = "u",
    Yacute = "Y",  yacute = "y",
    Zacute = "Z",  zacute = "z",

    Dstroke = "D",  dstroke = "d",
    Hstroke = "H",  hstroke = "h",
    Tstroke = "T",  tstroke = "t",

    Cdotaccent = "C",  cdotaccent = "c",
    Edotaccent = "E",  edotaccent = "e",
    Gdotaccent = "G",  gdotaccent = "g",
    Idotaccent = "I",  idotaccent = "i",
    Zdotaccent = "Z",  zdotaccent = "z",

    Amacron = "A",  amacron = "a",
    Emacron = "E",  emacron = "e",
    Imacron = "I",  imacron = "i",
    Omacron = "O",  omacron = "o",
    Umacron = "U",  umacron = "u",

    Ccedilla = "C",  ccedilla = "c",
    Kcedilla = "K",  kcedilla = "k",
    Lcedilla = "L",  lcedilla = "l",
    Ncedilla = "N",  ncedilla = "n",
    Rcedilla = "R",  rcedilla = "r",
    Scedilla = "S",  scedilla = "s",
    Tcedilla = "T",  tcedilla = "t",

    Ohungarumlaut = "O",  ohungarumlaut = "o",
    Uhungarumlaut = "U",  uhungarumlaut = "u",

    Aogonek = "A",  aogonek = "a",
    Eogonek = "E",  eogonek = "e",
    Iogonek = "I",  iogonek = "i",
    Uogonek = "U",  uogonek = "u",

    Aring = "A",  aring = "a",
    Uring = "U",  uring = "u",

    Abreve = "A",  abreve = "a",
    Ebreve = "E",  ebreve = "e",
    Gbreve = "G",  gbreve = "g",
    Ibreve = "I",  ibreve = "i",
    Obreve = "O",  obreve = "o",
    Ubreve = "U",  ubreve = "u",

    Ccaron = "C",  ccaron = "c",
    Dcaron = "D",  dcaron = "d",
    Ecaron = "E",  ecaron = "e",
    Lcaron = "L",  lcaron = "l",
    Ncaron = "N",  ncaron = "n",
    Rcaron = "R",  rcaron = "r",
    Scaron = "S",  scaron = "s",
    Tcaron = "T",  tcaron = "t",
    Zcaron = "Z",  zcaron = "z",

    dotlessI = "I",  dotlessi = "i",
    dotlessJ = "J",  dotlessj = "j",

    AEligature = "AE",  aeligature = "ae",  AE         = "AE",  ae         = "ae",
    OEligature = "OE",  oeligature = "oe",  OE         = "OE",  oe         = "oe",
    IJligature = "IJ",  ijligature = "ij",  IJ         = "IJ",  ij         = "ij",

    Lstroke    = "L",   lstroke    = "l",   Lslash     = "L",   lslash     = "l",
    Ostroke    = "O",   ostroke    = "o",   Oslash     = "O",   oslash     = "o",

    Ssharp     = "SS",  ssharp     = "ss",

    Aumlaut = "A",  aumlaut = "a",
    Eumlaut = "E",  eumlaut = "e",
    Iumlaut = "I",  iumlaut = "i",
    Oumlaut = "O",  oumlaut = "o",
    Uumlaut = "U",  uumlaut = "u",

}

addkerns = function(rawdata) -- using shcodes is not robust here
    local descriptions = rawdata.descriptions
    local resources    = rawdata.resources
    local unicodes     = resources.unicodes
    local function do_it_left(what)
        for unicode, description in next, descriptions do
            local kerns = description.kerns
            if kerns then
                local extrakerns
                for complex, simple in next, what do
                    complex = unicodes[complex]
                    simple = unicodes[simple]
                    if complex and simple then
                        local ks = kerns[simple]
                        if ks and not kerns[complex] then
                            if extrakerns then
                                extrakerns[complex] = ks
                            else
                                extrakerns = { [complex] = ks }
                            end
                        end
                    end
                end
                if extrakerns then
                    description.extrakerns = extrakerns
                end
            end
        end
    end
    local function do_it_copy(what)
        for complex, simple in next, what do
            complex = unicodes[complex]
            simple = unicodes[simple]
            if complex and simple then
                local complexdescription = descriptions[complex]
                if complexdescription then -- optional
                    local simpledescription = descriptions[complex]
                    if simpledescription then
                        local extrakerns
                        local kerns = simpledescription.kerns
                        if kerns then
                            for unicode, kern in next, kerns do
                                if extrakerns then
                                    extrakerns[unicode] = kern
                                else
                                    extrakerns = { [unicode] = kern }
                                end
                            end
                        end
                        local extrakerns = simpledescription.extrakerns
                        if extrakerns then
                            for unicode, kern in next, extrakerns do
                                if extrakerns then
                                    extrakerns[unicode] = kern
                                else
                                    extrakerns = { [unicode] = kern }
                                end
                            end
                        end
                        if extrakerns then
                            complexdescription.extrakerns = extrakerns
                        end
                    end
                end
            end
        end
    end
    -- add complex with values of simplified when present
    do_it_left(left)
    do_it_left(both)
    -- copy kerns from simple char to complex char unless set
    do_it_copy(both)
    do_it_copy(right)
end

--[[ldx--
<p>The copying routine looks messy (and is indeed a bit messy).</p>
--ldx]]--

local function adddimensions(data) -- we need to normalize afm to otf i.e. indexed table instead of name
    if data then
        for unicode, description in next, data.descriptions do
            local bb = description.boundingbox
            if bb then
                local ht, dp = bb[4], -bb[2]
                if ht == 0 or ht < 0 then
                    -- no need to set it and no negative heights, nil == 0
                else
                    description.height = ht
                end
                if dp == 0 or dp < 0 then
                    -- no negative depths and no negative depths, nil == 0
                else
                    description.depth  = dp
                end
            end
        end
    end
end

local function copytotfm(data)
    if data and data.descriptions then
        local metadata     = data.metadata
        local resources    = data.resources
        local properties   = derivetable(data.properties)
        local descriptions = derivetable(data.descriptions)
        local goodies      = derivetable(data.goodies)
        local characters   = { }
        local parameters   = { }
        local unicodes     = resources.unicodes
        --
        for unicode, description in next, data.descriptions do -- use parent table
            characters[unicode] = { }
        end
        --
        local filename   = constructors.checkedfilename(resources)
        local fontname   = metadata.fontname or metadata.fullname
        local fullname   = metadata.fullname or metadata.fontname
        local endash     = unicodes['space']
        local emdash     = unicodes['emdash']
        local spacer     = "space"
        local spaceunits = 500
        --
        local monospaced  = metadata.isfixedpitch
        local charwidth   = metadata.charwidth
        local italicangle = metadata.italicangle
        local charxheight = metadata.xheight and metadata.xheight > 0 and metadata.xheight
        properties.monospaced  = monospaced
        parameters.italicangle = italicangle
        parameters.charwidth   = charwidth
        parameters.charxheight = charxheight
        -- same as otf
        if properties.monospaced then
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
            end
        else
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
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
        --
        if italicangle then
            parameters.italicangle  = italicangle
            parameters.italicfactor = math.cos(math.rad(90+italicangle))
            parameters.slant        = - math.round(math.tan(italicangle*math.pi/180))
        end
        if monospaced then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif afm.syncspace then
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        parameters.extra_space = parameters.space_shrink
        if charxheight then
            parameters.x_height = charxheight
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
        parameters.designsize = (metadata.designsize or 10)*65536
        parameters.ascender   = abs(metadata.ascender  or 0)
        parameters.descender  = abs(metadata.descender or 0)
        parameters.units      = 1000
        --
        properties.spacer        = spacer
        properties.encodingbytes = 2
        properties.format        = fonts.formats[filename] or "type1"
        properties.filename      = filename
        properties.fontname      = fontname
        properties.fullname      = fullname
        properties.psname        = fullname
        properties.name          = filename or fullname or fontname
        --
        if next(characters) then
            return {
                characters   = characters,
                descriptions = descriptions,
                parameters   = parameters,
                resources    = resources,
                properties   = properties,
                goodies      = goodies,
            }
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

function afm.setfeatures(tfmdata,features)
    local okay = constructors.initializefeatures("afm",tfmdata,features,trace_features,report_afm)
    if okay then
        return constructors.collectprocessors("afm",tfmdata,features,trace_features,report_afm)
    else
        return { } -- will become false
    end
end

local function checkfeatures(specification)
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
            return -- just that
        end
    end
    if afmname ~= "" then
        -- weird, isn't this already done then?
        local features = constructors.checkedfeatures("afm",specification.features.normal)
        specification.features.normal = features
        constructors.hashinstance(specification,true) -- also weird here
        --
        specification = definers.resolve(specification) -- new, was forgotten
        local cache_id = specification.hash
        local tfmdata  = containers.read(constructors.cache, cache_id) -- cache with features applied
        if not tfmdata then
            local rawdata = afm.load(afmname)
            if rawdata and next(rawdata) then
                adddimensions(rawdata)
                tfmdata = copytotfm(rawdata)
                if tfmdata and next(tfmdata) then
                    local shared = tfmdata.shared
                    if not shared then
                        shared         = { }
                        tfmdata.shared = shared
                    end
                    shared.rawdata   = rawdata
                    shared.features  = features
                    shared.processes = afm.setfeatures(tfmdata,features)
                end
            elseif trace_loading then
                report_afm("no (valid) afm file found with name %s",afmname)
            end
            tfmdata = containers.write(constructors.cache,cache_id,tfmdata)
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

local function read_from_afm(specification)
    local tfmdata = afmtotfm(specification)
    if tfmdata then
        tfmdata.properties.name = specification.name
        tfmdata = constructors.scale(tfmdata, specification)
        constructors.applymanipulators("afm",tfmdata,specification.features.normal,trace_features,report_afm)
        fonts.loggers.register(tfmdata,'afm',specification)
    end
    return tfmdata
end

--[[ldx--
<p>Here comes the implementation of a few features. We only implement
those that make sense for this format.</p>
--ldx]]--

local function prepareligatures(tfmdata,ligatures,value)
    if value then
        local descriptions = tfmdata.descriptions
        for unicode, character in next, tfmdata.characters do
            local description = descriptions[unicode]
            local dligatures = description.ligatures
            if dligatures then
                local cligatures = character.ligatures
                if not cligatures then
                    cligatures = { }
                    character.ligatures = cligatures
                end
                for unicode, ligature in next, dligatures do
                    cligatures[unicode] = {
                        char = ligature,
                        type = 0
                    }
                end
            end
        end
    end
end

local function preparekerns(tfmdata,kerns,value)
    if value then
        local rawdata = tfmdata.shared.rawdata
        local resources = rawdata.resources
        local unicodes = resources.unicodes
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

local list = {
 -- [0x0022] = 0x201D,
    [0x0027] = 0x2019,
 -- [0x0060] = 0x2018,
}

local function texreplacements(tfmdata,value)
    local descriptions = tfmdata.descriptions
    local characters   = tfmdata.characters
    for k, v in next, list do
        characters  [k] = characters  [v] -- we forget about kerns
        descriptions[k] = descriptions[v] -- we forget about kerns
    end
end

local function ligatures   (tfmdata,value) prepareligatures(tfmdata,'ligatures',   value) end
local function texligatures(tfmdata,value) prepareligatures(tfmdata,'texligatures',value) end
local function kerns       (tfmdata,value) preparekerns    (tfmdata,'kerns',       value) end
local function extrakerns  (tfmdata,value) preparekerns    (tfmdata,'extrakerns',  value) end

registerafmfeature {
    name         = "liga",
    description  = "traditional ligatures",
    initializers = {
        base = ligatures,
        node = ligatures,
    }
}

registerafmfeature {
    name         = "kern",
    description  = "intercharacter kerning",
    initializers = {
        base = kerns,
        node = kerns,
    }
}

registerafmfeature {
    name         = "extrakerns",
    description  = "additional intercharacter kerning",
    initializers = {
        base = extrakerns,
        node = extrakerns,
    }
}

registerafmfeature {
    name         = 'tlig',
    description  = 'tex ligatures',
    initializers = {
        base = texligatures,
        node = texligatures,
    }
}

registerafmfeature {
    name         = 'trep',
    description  = 'tex replacements',
    initializers = {
        base = texreplacements,
        node = texreplacements,
    }
}

-- readers

local check_tfm   = readers.check_tfm

fonts.formats.afm = "type1"
fonts.formats.pfb = "type1"

local function check_afm(specification,fullname)
    local foundname = findbinfile(fullname, 'afm') or "" -- just to be sure
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"afm")
    end
    if foundname == "" and afm.autoprefixed then
        local encoding, shortname = match(fullname,"^(.-)%-(.*)$") -- context: encoding-name.*
        if encoding and shortname and fonts.encodings.known[encoding] then
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
        specification.filename = foundname
        specification.format   = "afm"
        return read_from_afm(specification)
    end
end

function readers.afm(specification,method)
    local fullname, tfmdata = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmdata = check_afm(specification,specification.name .. "." .. forced)
        end
        if not tfmdata then
            method = method or definers.method or "afm or tfm"
            if method == "tfm" then
                tfmdata = check_tfm(specification,specification.name)
            elseif method == "afm" then
                tfmdata = check_afm(specification,specification.name)
            elseif method == "tfm or afm" then
                tfmdata = check_tfm(specification,specification.name) or check_afm(specification,specification.name)
            else -- method == "afm or tfm" or method == "" then
                tfmdata = check_afm(specification,specification.name) or check_tfm(specification,specification.name)
            end
        end
    else
        tfmdata = check_afm(specification,fullname)
    end
    return tfmdata
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
