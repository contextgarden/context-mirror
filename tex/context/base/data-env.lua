if not modules then modules = { } end modules ['data-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local allocate = utilities.storage.allocate

local resolvers = resolvers

local formats      = allocate()  resolvers.formats      = formats
local suffixes     = allocate()  resolvers.suffixes     = suffixes
local dangerous    = allocate()  resolvers.dangerous    = dangerous
local suffixmap    = allocate()  resolvers.suffixmap    = suffixmap
local alternatives = allocate()  resolvers.alternatives = alternatives

formats['afm']          = 'AFMFONTS'       suffixes['afm']          = { 'afm' }
formats['enc']          = 'ENCFONTS'       suffixes['enc']          = { 'enc' }
formats['fmt']          = 'TEXFORMATS'     suffixes['fmt']          = { 'fmt' }
formats['map']          = 'TEXFONTMAPS'    suffixes['map']          = { 'map' }
formats['mp']           = 'MPINPUTS'       suffixes['mp']           = { 'mp' }
formats['ocp']          = 'OCPINPUTS'      suffixes['ocp']          = { 'ocp' }
formats['ofm']          = 'OFMFONTS'       suffixes['ofm']          = { 'ofm', 'tfm' }
formats['otf']          = 'OPENTYPEFONTS'  suffixes['otf']          = { 'otf' }
formats['opl']          = 'OPLFONTS'       suffixes['opl']          = { 'opl' }
formats['otp']          = 'OTPINPUTS'      suffixes['otp']          = { 'otp' }
formats['ovf']          = 'OVFFONTS'       suffixes['ovf']          = { 'ovf', 'vf' }
formats['ovp']          = 'OVPFONTS'       suffixes['ovp']          = { 'ovp' }
formats['tex']          = 'TEXINPUTS'      suffixes['tex']          = { 'tex' }
formats['tfm']          = 'TFMFONTS'       suffixes['tfm']          = { 'tfm' }
formats['ttf']          = 'TTFONTS'        suffixes['ttf']          = { 'ttf', 'ttc', 'dfont' }
formats['pfb']          = 'T1FONTS'        suffixes['pfb']          = { 'pfb', 'pfa' }
formats['vf']           = 'VFFONTS'        suffixes['vf']           = { 'vf' }
formats['fea']          = 'FONTFEATURES'   suffixes['fea']          = { 'fea' }
formats['cid']          = 'FONTCIDMAPS'    suffixes['cid']          = { 'cid', 'cidmap' }
formats['icc']          = 'ICCPROFILES'    suffixes['icc']          = { 'icc' }
formats['texmfscripts'] = 'TEXMFSCRIPTS'   suffixes['texmfscripts'] = { 'rb', 'pl', 'py' }
formats['lua']          = 'LUAINPUTS'      suffixes['lua']          = { 'lua', 'luc', 'tma', 'tmc' }
formats['lib']          = 'CLUAINPUTS'     suffixes['lib']          = (os.libsuffix and { os.libsuffix }) or { 'dll', 'so' }

-- backward compatible ones

alternatives['map files']            = 'map'
alternatives['enc files']            = 'enc'
alternatives['cid maps']             = 'cid' -- great, why no cid files
alternatives['font feature files']   = 'fea' -- and fea files here
alternatives['opentype fonts']       = 'otf'
alternatives['truetype fonts']       = 'ttf'
alternatives['truetype collections'] = 'ttc'
alternatives['truetype dictionary']  = 'dfont'
alternatives['type1 fonts']          = 'pfb'
alternatives['icc profiles']         = 'icc'

--[[ldx--
<p>If you wondered about some of the previous mappings, how about
the next bunch:</p>
--ldx]]--

-- kpse specific ones (a few omitted) .. we only add them for locating
-- files that we don't use anyway

formats['base']                      = 'MFBASES'         suffixes['base']                     = { 'base', 'bas' }
formats['bib']                       = ''                suffixes['bib']                      = { 'bib' }
formats['bitmap font']               = ''                suffixes['bitmap font']              = { }
formats['bst']                       = ''                suffixes['bst']                      = { 'bst' }
formats['cmap files']                = 'CMAPFONTS'       suffixes['cmap files']               = { 'cmap' }
formats['cnf']                       = ''                suffixes['cnf']                      = { 'cnf' }
formats['cweb']                      = ''                suffixes['cweb']                     = { 'w', 'web', 'ch' }
formats['dvips config']              = ''                suffixes['dvips config']             = { }
formats['gf']                        = ''                suffixes['gf']                       = { '<resolution>gf' }
formats['graphic/figure']            = ''                suffixes['graphic/figure']           = { 'eps', 'epsi' }
formats['ist']                       = ''                suffixes['ist']                      = { 'ist' }
formats['lig files']                 = 'LIGFONTS'        suffixes['lig files']                = { 'lig' }
formats['ls-R']                      = ''                suffixes['ls-R']                     = { }
formats['mem']                       = 'MPMEMS'          suffixes['mem']                      = { 'mem' }
formats['MetaPost support']          = ''                suffixes['MetaPost support']         = { }
formats['mf']                        = 'MFINPUTS'        suffixes['mf']                       = { 'mf' }
formats['mft']                       = ''                suffixes['mft']                      = { 'mft' }
formats['misc fonts']                = ''                suffixes['misc fonts']               = { }
formats['other text files']          = ''                suffixes['other text files']         = { }
formats['other binary files']        = ''                suffixes['other binary files']       = { }
formats['pdftex config']             = 'PDFTEXCONFIG'    suffixes['pdftex config']            = { }
formats['pk']                        = ''                suffixes['pk']                       = { '<resolution>pk' }
formats['PostScript header']         = 'TEXPSHEADERS'    suffixes['PostScript header']        = { 'pro' }
formats['sfd']                       = 'SFDFONTS'        suffixes['sfd']                      = { 'sfd' }
formats['TeX system documentation']  = ''                suffixes['TeX system documentation'] = { }
formats['TeX system sources']        = ''                suffixes['TeX system sources']       = { }
formats['Troff fonts']               = ''                suffixes['Troff fonts']              = { }
formats['type42 fonts']              = 'T42FONTS'        suffixes['type42 fonts']             = { }
formats['web']                       = ''                suffixes['web']                      = { 'web', 'ch' }
formats['web2c files']               = 'WEB2C'           suffixes['web2c files']              = { }
formats['fontconfig files']          = 'FONTCONFIG_PATH' suffixes['fontconfig files']         = { } -- not unique

alternatives['subfont definition files'] = 'sfd'

-- A few accessors, mostly for command line tool.

function resolvers.suffixofformat(str)
    local s = suffixes[str]
    return s and s[1] or ""
end

function resolvers.suffixesofformat(str)
    return suffixes[str] or { }
end

-- As we don't register additional suffixes anyway, we can as well
-- freeze the reverse map here.

for name, suffixlist in next, suffixes do
    for i=1,#suffixlist do
        suffixmap[suffixlist[i]] = name
    end
end

local mt = getmetatable(suffixes)

mt.__newindex = function(suffixes,name,suffixlist)
    rawset(suffixes,name,suffixlist)
    suffixes[name] = suffixlist
    for i=1,#suffixlist do
        suffixmap[suffixlist[i]] = name
    end
end

for name, format in next, formats do
    dangerous[name] = true
end

-- because vf searching is somewhat dangerous, we want to prevent
-- too liberal searching esp because we do a lookup on the current
-- path anyway; only tex (or any) is safe

dangerous.tex = nil

--~ print(table.serialize(dangerous))

-- more helpers

function resolvers.formatofvariable(str)
    return formats[str] or formats[alternatives[str]] or ''
end

function resolvers.formatofsuffix(str) -- of file
    return suffixmap[file.extname(str)] or 'tex' -- so many map onto tex (like mkiv, cld etc)
end

function resolvers.variableofformat(str)
    return formats[str] or formats[alternatives[str]] or ''
end

function resolvers.variableofformatorsuffix(str)
    local v = formats[str]
    if v then
        return v
    end
    v = formats[alternatives[str]]
    if v then
        return v
    end
    v = suffixmap[fileextname(str)]
    if v then
        return formats[v]
    end
    return ''
end

