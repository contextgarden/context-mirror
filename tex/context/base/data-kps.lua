if not modules then modules = { } end modules ['luat-kps'] = {
    version   = 1.001,
    comment   = "companion to luatools.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This file is used when we want the input handlers to behave like
<type>kpsewhich</type>. What to do with the following:</p>

<typing>
{$SELFAUTOLOC,$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}
$SELFAUTOLOC    : /usr/tex/bin/platform
$SELFAUTODIR    : /usr/tex/bin
$SELFAUTOPARENT : /usr/tex
</typing>

<p>How about just forgetting about them?</p>
--ldx]]--

local suffixes = resolvers.suffixes
local formats  = resolvers.formats

suffixes['gf']                       = { '<resolution>gf' }
suffixes['pk']                       = { '<resolution>pk' }
suffixes['base']                     = { 'base' }
suffixes['bib']                      = { 'bib' }
suffixes['bst']                      = { 'bst' }
suffixes['cnf']                      = { 'cnf' }
suffixes['mem']                      = { 'mem' }
suffixes['mf']                       = { 'mf' }
suffixes['mfpool']                   = { 'pool' }
suffixes['mft']                      = { 'mft' }
suffixes['mppool']                   = { 'pool' }
suffixes['graphic/figure']           = { 'eps', 'epsi' }
suffixes['texpool']                  = { 'pool' }
suffixes['PostScript header']        = { 'pro' }
suffixes['ist']                      = { 'ist' }
suffixes['web']                      = { 'web', 'ch' }
suffixes['cweb']                     = { 'w', 'web', 'ch' }
suffixes['cmap files']               = { 'cmap' }
suffixes['lig files']                = { 'lig' }
suffixes['bitmap font']              = { }
suffixes['MetaPost support']         = { }
suffixes['TeX system documentation'] = { }
suffixes['TeX system sources']       = { }
suffixes['dvips config']             = { }
suffixes['type42 fonts']             = { }
suffixes['web2c files']              = { }
suffixes['other text files']         = { }
suffixes['other binary files']       = { }
suffixes['opentype fonts']           = { 'otf' }

suffixes['fmt']                      = { 'fmt' }
suffixes['texmfscripts']             = { 'rb','lua','py','pl' }

suffixes['pdftex config']            = { }
suffixes['Troff fonts']              = { }

suffixes['ls-R']                     = { }

--[[ldx--
<p>If you wondered abou tsome of the previous mappings, how about
the next bunch:</p>
--ldx]]--

formats['bib']                      = ''
formats['bst']                      = ''
formats['mft']                      = ''
formats['ist']                      = ''
formats['web']                      = ''
formats['cweb']                     = ''
formats['MetaPost support']         = ''
formats['TeX system documentation'] = ''
formats['TeX system sources']       = ''
formats['Troff fonts']              = ''
formats['dvips config']             = ''
formats['graphic/figure']           = ''
formats['ls-R']                     = ''
formats['other text files']         = ''
formats['other binary files']       = ''

formats['gf']                       = ''
formats['pk']                       = ''
formats['base']                     = 'MFBASES'
formats['cnf']                      = ''
formats['mem']                      = 'MPMEMS'
formats['mf']                       = 'MFINPUTS'
formats['mfpool']                   = 'MFPOOL'
formats['mppool']                   = 'MPPOOL'
formats['texpool']                  = 'TEXPOOL'
formats['PostScript header']        = 'TEXPSHEADERS'
formats['cmap files']               = 'CMAPFONTS'
formats['type42 fonts']             = 'T42FONTS'
formats['web2c files']              = 'WEB2C'
formats['pdftex config']            = 'PDFTEXCONFIG'
formats['texmfscripts']             = 'TEXMFSCRIPTS'
formats['bitmap font']              = ''
formats['lig files']                = 'LIGFONTS'
