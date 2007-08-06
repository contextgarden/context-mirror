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

<p>How about just forgetting abou them?</p>
--ldx]]--

input          = input          or { }
input.suffixes = input.suffixes or { }
input.formats  = input.formats  or { }

input.suffixes['gf']                       = { '<resolution>gf' }
input.suffixes['pk']                       = { '<resolution>pk' }
input.suffixes['base']                     = { 'base' }
input.suffixes['bib']                      = { 'bib' }
input.suffixes['bst']                      = { 'bst' }
input.suffixes['cnf']                      = { 'cnf' }
input.suffixes['mem']                      = { 'mem' }
input.suffixes['mf']                       = { 'mf' }
input.suffixes['mfpool']                   = { 'pool' }
input.suffixes['mft']                      = { 'mft' }
input.suffixes['mppool']                   = { 'pool' }
input.suffixes['graphic/figure']           = { 'eps', 'epsi' }
input.suffixes['texpool']                  = { 'pool' }
input.suffixes['PostScript header']        = { 'pro' }
input.suffixes['ist']                      = { 'ist' }
input.suffixes['web']                      = { 'web', 'ch' }
input.suffixes['cweb']                     = { 'w', 'web', 'ch' }
input.suffixes['cmap files']               = { 'cmap' }
input.suffixes['lig files']                = { 'lig' }
input.suffixes['bitmap font']              = { }
input.suffixes['MetaPost support']         = { }
input.suffixes['TeX system documentation'] = { }
input.suffixes['TeX system sources']       = { }
input.suffixes['dvips config']             = { }
input.suffixes['type42 fonts']             = { }
input.suffixes['web2c files']              = { }
input.suffixes['other text files']         = { }
input.suffixes['other binary files']       = { }
input.suffixes['opentype fonts']           = { 'otf' }

input.suffixes['fmt']                      = { 'fmt' }
input.suffixes['texmfscripts']             = { 'rb','lua','py','pl' }

input.suffixes['pdftex config']            = { }
input.suffixes['Troff fonts']              = { }

input.suffixes['ls-R']                     = { }

--[[ldx--
<p>If you wondered abou tsome of the previous mappings, how about
the next bunch:</p>
--ldx]]--

input.formats['bib']                      = ''
input.formats['bst']                      = ''
input.formats['mft']                      = ''
input.formats['ist']                      = ''
input.formats['web']                      = ''
input.formats['cweb']                     = ''
input.formats['MetaPost support']         = ''
input.formats['TeX system documentation'] = ''
input.formats['TeX system sources']       = ''
input.formats['Troff fonts']              = ''
input.formats['dvips config']             = ''
input.formats['graphic/figure']           = ''
input.formats['ls-R']                     = ''
input.formats['other text files']         = ''
input.formats['other binary files']       = ''

input.formats['gf']                       = ''
input.formats['pk']                       = ''
input.formats['base']                     = 'MFBASES'
input.formats['cnf']                      = ''
input.formats['mem']                      = 'MPMEMS'
input.formats['mf']                       = 'MFINPUTS'
input.formats['mfpool']                   = 'MFPOOL'
input.formats['mppool']                   = 'MPPOOL'
input.formats['texpool']                  = 'TEXPOOL'
input.formats['PostScript header']        = 'TEXPSHEADERS'
input.formats['cmap files']               = 'CMAPFONTS'
input.formats['type42 fonts']             = 'T42FONTS'
input.formats['web2c files']              = 'WEB2C'
input.formats['pdftex config']            = 'PDFTEXCONFIG'
input.formats['texmfscripts']             = 'TEXMFSCRIPTS'
input.formats['bitmap font']              = ''
input.formats['lig files']                = 'LIGFONTS'
