eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D \module
#D   [       file=texfont.pl,
#D        version=2000.12.14,
#D          title=Font Handling, 
#D       subtitle=installing and generating,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

#D For usage information, see \type {mfonts.pdf}.

#D ToDo: list of encodings [texnansi, ec, textext]

use File::Copy ;
use Getopt::Long ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

$encoding        = "texnansi" ;
$vendor          = "" ;
$collection      = "" ;
$fontroot        = `kpsewhich -expand-path=\$TEXMFLOCAL` ; chomp $fontroot ;
$help            = 0 ;
$makepath        = 0 ;
$show            = 0 ;
$install         = 0 ;
$namespace       = 0 ;
$append          = 0 ;
$sourcepath      = "." ;
$passon          = "" ;
$extend          = "" ;
$narrow          = "" ;
$slant           = "" ;
$caps            = "" ;
$noligs          = 0 ; 
$userfontsuffix  = "" ;
$usernamesuffix  = "" ;
$test            = 0 ; 
$auto            = 0 ; 

$fontsuffix  = "" ;
$namesuffix  = "" ;

&GetOptions
  ( "help"         => \$help,
    "makepath"     => \$makepath,
    "noligs"       => \$noligs,
    "show"         => \$show,
    "append"       => \$append,
    "install"      => \$install,
    "namespace"    => \$namespace,
    "encoding=s"   => \$encoding,
    "vendor=s"     => \$vendor,
    "collection=s" => \$collection,
    "fontroot=s"   => \$fontroot,
    "sourcepath=s" => \$sourcepath,
    "passon=s"     => \$passon,
    "fontsuffix=s" => \$userfontsuffix,
    "namesuffix=s" => \$usernamesuffix,
    "slant=s"      => \$slant,
    "extend=s"     => \$extend,
    "narrow=s"     => \$narrow,
    "test"         => \$test,
    "auto"         => \$auto, 
    "caps=s"       => \$caps) ;

if ($test) 
  { $vendor = $collection = "test" ;
    $make = $install = 1 } 

if ($auto) 
  { $make = $install = 1 ; 
    $append = ("$slant$extend$caps$noligs" ne "") }

if (($slant  ne "") && ($slant  !~ /\d/)) { $slant  = "0.167" } 
if (($extend ne "") && ($extend !~ /\d/)) { $extend = "1.200" } 
if (($narrow ne "") && ($narrow !~ /\d/)) { $narrow = "0.800" } 
if (($caps   ne "") && ($caps   !~ /\d/)) { $caps   = "0.800" } 

$encoding   = lc $encoding ; 
$vendor     = lc $vendor ; 
$collection = lc $collection ; 
$lcfontroot = lc $fontroot ; 

sub report
  { return if $silent ;
    my $str = shift ;
    $str =~ s/  / /goi ;
    if ($str =~ /(.*?)\s+([\:\/])\s+(.*)/o)
      { if ($1 eq "") { $str = " " } else { $str = $2 }
        print sprintf("%22s $str %s\n",$1,$3) } }

print "\n" ;
report ("TeXFont 1.1 - ConTeXt / PRAGMA ADE 2000-2001 (BETA)") ;
print "\n" ;

if ($help)
  { report "--fontroot=path     : texmf font root (default: $lcfontroot)" ;
    report "--sourcepath=path   : when installing, copy from this path (default: $sourcepath)" ;
    print  "\n" ;
    report "--vendor=name       : vendor name/directory" ;
    report "--collection=name   : font collection" ;
    report "--encoding=name     : encoding vector (default: $encoding)" ;
    report "--fontsuffix=string : force string to be prepended to font file" ;
    report "--namesuffix=string : force string to be appended to font name" ;
    print  "\n" ;
    report "--slant=s           : slant glyphs in font by factor (0.0 - 1.5)" ;
    report "--extend=s          : extend glyphs in font by factor (0.0 - 1.5)" ;
    report "--caps=s            : capitalize lowercase chars by factor (0.5 - 1.0)" ;
    report "--noligs            : remove ligatures" ;
    print  "\n" ;
    report "--install           : copy files from source to font tree" ;
    report "--append            : append map entries to existing file" ;
    report "--namespace         : prefix tfm files by encoding" ;
    report "--makepath          : when needed, create the paths" ;
    print  "\n" ;
    report "--test              : use test paths for vendor/collection" ;
    report "--auto              : equals --make --install --append" ;
    report "--show              : run tex on texfont.tex" ;
    print  "\n" ;
    report "example : --ma --in --ve=abc --co=foo\n" ;
    report "        : --ma --in --ve=abc --co=foo --na\n" ;
    report "        : --ma --in --ve=abc --co=foo --ap --sl=.15 bar\n" ;
    exit }

sub error
  { report("processing aborted : " . shift) ;
    print "\n" ;
    report "--help : show some more info" ;
    exit }

error ("unknown vendor      $vendor")      unless    $vendor ;
error ("unknown collection  $collection")  unless    $collection ;
error ("unknown tex root    $lcfontroot")  unless -d $fontroot ;
error ("unknown source path $sourcepath")  unless -d $sourcepath ;

error ("unknown option $ARGV[0]") if ($ARGV[0] =~ /\-\-/) ; 

$afmpath = "$fontroot/fonts/afm/$vendor/$collection" ;
$tfmpath = "$fontroot/fonts/tfm/$vendor/$collection" ;
$vfpath  = "$fontroot/fonts/vf/$vendor/$collection" ;
$pfbpath = "$fontroot/fonts/type1/$vendor/$collection" ;
$pdfpath = "$fontroot/pdftex/config" ;

sub do_make_path
  { my $str = shift ; mkdir $str unless -d $str }

sub make_path
  { my $str = shift ;
    do_make_path("$fontroot/fonts/$str/$vendor") ;
    do_make_path("$fontroot/fonts/$str/$vendor/$collection") }

if ($makepath)
  { foreach ("afm", "tfm", "vf", "type1") { make_path ($_) }
    do_make_path("$fontroot/pdftex") ;
    do_make_path("$fontroot/pdftex/config") }
else
  { make_path ("tfm") }

error ("unknown afm path $afmpath") unless -d $afmpath ;
error ("unknown tfm path $tfmpath") unless -d $tfmpath ;
error ("unknown vf  path $vfpath" ) unless -d $vfpath  ;
error ("unknown pfb path $pfbpath") unless -d $pfbpath ;
error ("unknown pdf path $pdfpath") unless -d $pdfpath ;

$identifier = "$encoding-$vendor-$collection" ;

$mapfile = "$identifier.map" ;
$bakfile = "$identifier.bak" ;
$texfile = "$identifier.tex" ;

report "encoding vector : $encoding" ;
report     "vendor name : $vendor" ;
report "font collection : $collection" ;
report "texmf font root : $lcfontroot" ;
report "pdftex map file : $mapfile" ;

if ($namespace && ($encoding ne""))
  { $encodingprefix = "$encoding-" }
else
  { $encodingprefix = "" }

if ($install)        { report "source path : $sourcepath" }
if ($userfontsuffix) { report "file prefix : $userfontsuffix" }
if ($usernamesuffix) { report "name suffix : $usernamesuffix" }
if ($namespace)      { report   "namespace : $encodingprefix*.tfm" }

$fntlist = "" ;

$runpath = $sourcepath ; 

if ($ARGV[0] ne "")
  { $pattern = $ARGV[0] ;
    report ("processing files : all in pattern $ARGV[0]") ; 
    @files = glob("$runpath/$pattern.afm") }
elsif ("$extend$narrow$slant$caps" ne "")
  { error ("transformation needs file spec") }  
else
  { $pattern = "*" ;
    report ("processing files : all on afm path") ; 
    @files = glob("$runpath/$pattern.afm") }

sub copy_files
  { my ($suffix,$topath) = @_ ;
    my @files = glob ("$sourcepath/$pattern.$suffix") ;
    report ("copying files : $suffix") ;
    foreach my $file (@files)
      { $ok = $file =~ /(.*)\/(.+?)\.(.*)/ ;
        ($path,$name,$suffix) = ($1,$2,$3) ;
        unlink "$topath/$name.$suffix" ;
        copy ($file,"$topath/$name.$suffix") } }

if ($install)
  { copy_files("afm",$afmpath) ;
    copy_files("pfb",$pfbpath) }

error ("no afm files found") unless @files ;  

my $map = $tex = 0 ; my $mapdata = "" ;

copy ("$pdfpath/$mapfile","$pdfpath/$bakfile") ;

if ($append)
  { copy ("$pdfpath/$mapfile","./$mapfile") ;
    if (open (MAP,"<$mapfile"))
      { while (<MAP>)
          { chomp ; s/\s//gmois ; $mapdata .= "$_\n" }
        close (MAP) }
    $map = open (MAP,">>$mapfile") }
else
  { $map = open (MAP,">$mapfile") }

$tex = open (TEX,">$texfile") ;

unless ($map) { report "warning : can't open $mapfile" }
unless ($tex) { report "warning : can't open $texfile" }

if (($map)&&(!$append))
  { print MAP "% This file is generated by the TeXFont Perl script.\n" ;
    print MAP "%\n" ;
    print MAP "% You need to add the following line to pdftex.cfg:\n" ;
    print MAP "%\n" ;
    print MAP "%   map +$mapfile\n" ;
    print MAP "%\n" ;
    print MAP "% Alternatively in your TeX source you can say:\n" ;
    print MAP "%\n" ;
    print MAP "%   \\pdfmapfile\{+$mapfile\}\n" ;
    print MAP "%\n" ;
    print MAP "% In ConTeXt you can best use:\n" ;
    print MAP "%\n" ;
    print MAP "%   \\loadmapfile\[$mapfile\]\n\n" }

if ($tex)
  { print TEX "% output=pdftex interface=en\n" ;
    print TEX "\n" ;
    print TEX "\\pdfmapfile\{+$encoding-$vendor-$collection.map\}\n" ;
    print TEX "\n" ;
    print TEX "\\dontcomplain\n" ;
    print TEX "\n" ;
    print TEX "\\setuplayout[backspace=60pt,footer=0pt,header=36pt,width=middle,height=middle]\n" ;
    print TEX "\n" ;
    print TEX "\\setupcolors[state=start]\n" ;
    print TEX "\n" ;
    print TEX "\\def\\ShowFont[\#1][\#2]\%\n" ;
    print TEX "  \{\\bgroup\n" ;
    print TEX "   \\definefontsynonym[WhateverName][\#2][encoding=$encoding]\n" ;
    print TEX "   \\definefont[WhateverFont][WhateverName]\n" ;
    print TEX "   \\setupheadertexts[\\tttf \#2\\quad\#1]\n" ;
    print TEX "   \\WhateverFont\n" ;
    print TEX "   \\setupinterlinespace\n" ;
    print TEX "   \\showfont[\#2]\n" ;
    print TEX "   \\showaccents\n" ;
    print TEX "   \\showcharacters\n" ;
    print TEX "   \\page\n" ;
    print TEX "   \\egroup\}\n" ;
    print TEX "\n" ;
    print TEX "\\starttext\n" }

$shape = $fake = "" ;

if ($noligs) 
  { report ("ligatures : removed") ;
    $fontsuffix .= "-unligatured" ; 
    $namesuffix .= "-NoLigs" }

if ($caps ne "")
  {    if ($caps <0.5) { $caps = 0.5 }
    elsif ($caps >1.0) { $caps = 1.0 }
    $shape .= " -c $caps " ;
    report ("caps factor : $caps") ;
    $fontsuffix .= "-capitalized-" . int(1000*$caps)  ;
    $namesuffix .= "-Caps" }

if ($extend ne "")
  { if    ($extend<0.0) { $extend = 0.0 }
    elsif ($extend>1.5) { $extend = 1.5 }
    report ("extend factor : $extend") ;
    $shape .= " -e $extend " ;
    $fontsuffix .= "-extended-" . int(1000*$extend) ;
    $namesuffix .= "-Extended" }

if ($narrow ne "") # goodie 
  { $extend = $narrow ; 
    if    ($extend<0.0) { $extend = 0.0 }
    elsif ($extend>1.5) { $extend = 1.5 }
    report ("narrow factor : $extend") ;
    $shape .= " -e $extend " ;
    $fontsuffix .= "-narrowed-" . int(1000*$extend) ;
    $namesuffix .= "-Narrowed" }

if ($slant ne "")
  {    if ($slant <0.0) { $slant = 0.0 }
    elsif ($slant >1.5) { $slant = 1.5 }
    report ("slant factor : $slant") ;
    $shape .= " -s $slant " ;
    $fontsuffix .= "-slanted-" . int(1000*$slant) ;
    $namesuffix .= "-Slanted" }

if ($fontsuffix ne "") 
  { foreach $file (@files)
      { $file = lc $file ; $ok = $file =~ /(.*)\/(.+?)\.(.*)/ ;
        ($path,$name,$suffix) = ($1,$2,$3) ;
        $name =~ s/\_//gio ;
        $ok = `kpsewhich $name.tfm` ; chomp $ok ;
        if ($ok eq "") { error ("unknown tfm file $name") } } } 

if ($userfontsuffix ne "") { $fontsuffix = $userfontsuffix }
if ($usernamesuffix ne "") { $namesuffix = $usernamesuffix }

sub removeligatures 
  { my $filename = shift ; 
    copy ("$filename.vpl","$filename.tmp") ; 
    if ((open(TMP,"<$filename.tmp"))&&(open(VPL,">$filename.vpl")))
      { report "removing ligatures : $filename" ; 
        $skip = 0 ; 
        while (<TMP>) 
         { chomp ; 
           if ($skip) 
             { if (/^\s*\)\s*$/o) { $skip = 0 ; print VPL "$_\n" } } 
           elsif (/\(LIGTABLE/o) 
             { $skip = 1 ; print VPL "$_\n" } 
           else 
             { print VPL "$_\n" } }
        close(TMP) ; close(VPL) }
    unlink ("$filename.tmp") } 

foreach $file (@files)
  { $file = lc $file ; $ok = $file =~ /(.*)\/(.+?)\.(.*)/ ;
    ($path,$name,$suffix) = ($1,$2,$3) ;
    # remove trailing _'s
    $fontname = $name ;
    $cleanname = $fontname ; $cleanname =~ s/\_//gio ;
    # cleanup 
    foreach $suf ("tfm", "vf", "vpl") 
      { unlink "$cleanname$fontsuffix.$suf" }
    unlink "texfont.log" ;
    # generate tfm and vpl, $file is on afm path 
    report "generating tfm : $cleanname$fontsuffix (from $cleanname)" ;
    $passon .= " -t $encoding.enc" ; 
    $virtualfont = ($caps ne "") || ($noligs) ;
    if ($caps ne "") 
      { $passon .= " -V $fontname$fontsuffix" }
    elsif ($virtualfont) 
      { $passon .= " -v $fontname$fontsuffix" }
    $font = `afm2tfm $file $shape $passon` ;
    # generate vf file if needed 
    chomp $font ; $option = $slant = $extend = "" ;
    if ($font =~ /.*?([\d\.]+)\s*ExtendFont/io) { $extend = $1 }
    if ($font =~ /.*?([\d\.]+)\s*SlantFont/io)  { $slant  = $1 }
    if ($extend ne "") { $option .= " $1 ExtendFont " }
    if ($slant ne "")  { $option .= " $1 SlantFont " }
    if ($noligs) { removeligatures "$fontname$fontsuffix" } 
    if ($virtualfont)
      { report "generating vf : $cleanname$fontsuffix (from $cleanname)" ;
        $ok = `vptovf $fontname$fontsuffix` }
    # report results 
    ($rawfont,$cleanfont,$restfont) = split(/\s/,$font) ;
    $cleanfont =~ s/\_/\-/goi ;
    report ("font identifier : $cleanfont$namesuffix") ;
    # copy files 
    if ($virtualfont)
      { unlink "$vfpath/$encodingprefix$cleanname$fontsuffix.vf" ;
        copy ("$fontname$fontsuffix.vf" ,"$vfpath/$encodingprefix$cleanname$fontsuffix.vf") ;
        unlink "$tfmpath/$encodingprefix$cleanname$fontsuffix.tfm" ;
        copy ("$fontname$fontsuffix.tfm","$tfmpath/$encodingprefix$cleanname$fontsuffix.tfm") }
    else 
      { unlink "$tfmpath/$encodingprefix$cleanname$fontsuffix.tfm" ;
        copy ("$fontname.tfm","$tfmpath/$encodingprefix$cleanname$fontsuffix.tfm") }
    # cleanup 
    foreach $suf ("tfm", "vf", "vpl") 
      { unlink "$fontname.$suf" ;
        unlink "$cleanname$fontsuffix.$suf" ;
        unlink "$fontname$fontsuffix.$suf" }
    # add line to maps file 
    $option =~ s/^\s+(.*)/$1/o ;
    $option =~ s/(.*)\s+$/$1/o ;
    $option =~ s/  / /o ;
    if ($option ne "")
      { $option = "\"$option\" 4" }
    else
      { $option = "4" }
    $str = "$encodingprefix$cleanname$fontsuffix $option < $fontname.pfb $encoding.enc\n" ;
    if ($virtualfont) 
      { if ($append) { $str = "" }
        $str .= "$encodingprefix$cleanname$fontsuffix $option < $fontname.pfb $encoding.enc\n" }
    if ($map) # check for redundant entries
      { $strstr = $str ; $strstr =~ s/\s//gmois ;
        unless ($mapdata =~ /^$strstr$/gmis) { print MAP $str } } 
    # write lines to tex file 
    if ($tex) { print TEX "\\ShowFont[$cleanfont$namesuffix][$encodingprefix$cleanname$fontsuffix]\n" }
    $fntlist .= "\\definefontsynonym[$cleanfont$namesuffix][$encodingprefix$cleanname$fontsuffix][encoding=$encoding]\n" }

if ($tex)
  { print TEX "\\setupheadertexts[\\tttf example definitions]\n" ;
    print TEX "\\starttyping\n" ;
    print TEX "$fntlist" ;
    print TEX "\\stoptyping\n" ;
    print TEX "\\page\n" ;
    print TEX "\\setupheadertexts[\\tttf $mapfile]\n" ;
    print TEX "\\typefile\{$mapfile\}\n" ;
    print TEX "\\stoptext\n" }

if ($tex) { close (TEX) }
if ($map) { close (MAP) }

unlink "$pdfpath/$mapfile" ; copy ($mapfile,"$pdfpath/$mapfile") ;

print "\n" ; report ("generating : ls-r databases") ;

print "\n" ; system ("mktexlsr $fontroot") ; print "\n" ;

if ($show) { system ("texexec --once --silent $texfile") }

@files = glob ("$identifier.*") ;

foreach $file (@files)
  { unless ($file =~ /(tex|pdf|log)$/io) { unlink $file } }

exit ; 

# personal test file / batch 
# 
# rem we assume that there is a font demofont.afm and demofont.pfb 
# 
# texfont --ve=test --co=test --ma --in                 demofont
# texfont --ve=test --co=test --ma --in --ap --sla=.167 demofont
# texfont --ve=test --co=test --ma --in --ap --ext=1.50 demofont
# texfont --ve=test --co=test --ma --in --ap --cap=.750 demofont
# 
# rem more convenient
# 
# rem texfont --ve=test --co=test --auto               demofont
# rem texfont --ve=test --co=test --auto --sla=default demofont
# rem texfont --ve=test --co=test --auto --ext=default demofont
# rem texfont --ve=test --co=test --auto --cap=default demofont
# 
# rem faster for testing 
# 
# rem texfont --test --auto               demofont
# rem texfont --test --auto --sla=default demofont
# rem texfont --test --auto --ext=default demofont
# rem texfont --test --auto --cap=default demofont

# personal test file / tex 
# 
# % output=pdftex
# 
# \starttext 
# 
# \starttyping
# we assume that test.afm and test.pfb are there 
# \stoptyping 
# 
# \loadmapfile[texnansi-test-test.map]
# 
# \starttyping
# texfont --ve=test --co=test --ma --in demofont
# \stoptyping
# 
# \ruledhbox{\definedfont[demofont at 50pt]Interesting}
# 
# \starttyping
# texfont --ve=test --co=test --ma --in --ap --sla=.167 demofont
# \stoptyping
# 
# \ruledhbox{\definedfont[demofont-slanted-167 at 50pt]Interesting}
# 
# \starttyping
# texfont --ve=test --co=test --ma --in --ap --ext=1.50 demofont
# \stoptyping
# 
# \ruledhbox{\definedfont[demofont-extended-1500 at 50pt]Interesting}
# 
# \starttyping
# texfont --ve=test --co=test --ma --in --ap --cap=0.75 demofont
# \stoptyping
# 
# \ruledhbox{\definedfont[demofont-capitalized-750 at 50pt]Interesting}
