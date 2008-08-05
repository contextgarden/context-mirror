eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

# This is an example of a crappy unstructured file but once
# I know what should happen exactly, I will clean it up.

# once it works all right, afmpl will be default

# todo : ttf (partially doen already)

# added: $pattern in order to avoid fuzzy shelle expansion of
# filenames (not consistent over perl and shells); i hate that
# kind of out of control features.

#D \module
#D   [       file=texfont.pl,
#D        version=2004.02.06, % 2000.12.14
#D          title=Font Handling,
#D       subtitle=installing and generating,
#D         author=Hans Hagen ++,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

#D For usage information, see \type {mfonts.pdf}.

#D Todo : copy afm/pfb from main to local files to ensure metrics
#D Todo : Wybo's help system
#D Todo : list of encodings [texnansi, ec, textext]

#D Thanks to George N. White III for solving a couple of bugs.
#D Thanks to Adam T. Lindsay for adding Open Type support (and more).

use strict ;

my $savedoptions = join (" ",@ARGV) ;

use Config ;
use FindBin ;
use File::Copy ;
use Getopt::Long ;
use Data::Dumper;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

# Unless a user has specified an installation path, we take
# the dedicated font path or the local path.

## $dosish = ($Config{'osname'} =~ /dos|mswin/i) ;
my $dosish = ($Config{'osname'} =~ /^(ms)?dos|^os\/2|^(ms|cyg)win/i) ;

my $IsWin32 = ($^O =~ /MSWin32/i);
my $SpacyPath = 0 ;

# great, the win32api is not present in all perls

BEGIN {
    $IsWin32 = ($^O =~ /MSWin32/i) ;
    $SpacyPath = 0 ;
    if ($IsWin32) {
        my $str = `kpsewhich -expand-path=\$TEXMF` ;
        $SpacyPath = ($str =~ / /) ;
        if ($SpacyPath) {
            require Win32::API; import Win32::API;
        }
    }
}

# great, glob changed to bsd glob in an incompatible way ... sigh, we now
# have to catch a failed glob returning the pattern
#
# to stupid either:
#
# sub validglob {
#     my @globbed = glob(shift) ;
#     if ((@globbed) &&  (! -e $globbed[0])) {
#        return () ;
#     } else {
#        return @globbed ;
#     }
# }
#
# so now we have:

sub validglob {
    my @globbed = glob(shift) ;
    my @globout = () ;
    foreach my $file (@globbed) {
        push (@globout,$file) if (-e $file) ;
    }
    return @globout ;
}

sub GetShortPathName {
    my ($filename) = @_ ;
    return $filename unless (($IsWin32)&&($SpacyPath)) ;
    my $GetShortPathName = new Win32::API('kernel32', 'GetShortPathName', 'PPN', 'N') ;
    if(not defined $GetShortPathName) {
      die "Can't import API GetShortPathName: $!\n" ;
    }
    my $buffer = " " x 260;
    my $len = $GetShortPathName->Call($filename, $buffer, 260) ;
    return substr($buffer, 0, $len) ;
}

my $installpath = "" ;

if (defined($ENV{TEXMFLOCAL})) {
    $installpath = "TEXMFLOCAL" ;
}

if (defined($ENV{TEXMFFONTS})) {
    $installpath = "TEXMFFONTS" ;
}

if ($installpath eq "") {
    $installpath = "TEXMFLOCAL" ; # redundant
}

my $encoding        = "texnansi" ;
my $vendor          = "" ;
my $collection      = "" ;
my $fontroot        = "" ; #/usr/people/gwhite/texmf-fonts" ;
my $help            = 0 ;
my $makepath        = 0 ;
my $show            = 0 ;
my $install         = 0 ;
my $sourcepath      = "." ;
my $passon          = "" ;
my $extend          = "" ;
my $narrow          = "" ;
my $slant           = "" ;
my $spaced          = "" ;
my $caps            = "" ;
my $noligs          = 0 ;
my $nofligs         = 0 ;
my $test            = 0 ;
my $virtual         = 0 ;
my $novirtual       = 0 ;
my $listing         = 0 ;
my $remove          = 0 ;
my $expert          = 0 ;
my $trace           = 0 ;
my $afmpl           = 0 ;
my $trees           = 'TEXMFFONTS,TEXMFLOCAL,TEXMFEXTRA,TEXMFMAIN,TEXMFDIST' ;
my $pattern         = '' ;
my $uselmencodings  = 0 ;

my $fontsuffix  = "" ;
my $namesuffix  = "" ;

my $batch = "" ;

my $weight = "" ;
my $width = "" ;

my $preproc         = 0 ;     # atl: formerly OpenType switch
my $variant         = "" ;    # atl: encoding variant
my $extension       = "pfb" ; # atl: default font extension
my $lcdf            = "" ;    # atl: trigger for lcdf otftotfm

my @cleanup         = () ;    # atl: build list of generated files to delete

# todo: parse name for style, take face from command line
#
# @Faces  = ("Serif","Sans","Mono") ;
# @Styles = ("Slanted","Spaced", "Italic","Bold","BoldSlanted","BoldItalic") ;
#
# for $fac (@Faces) { for $sty (@Styles) { $FacSty{"$fac$sty"} = "" } }

&GetOptions
  ( "help"         => \$help,
    "makepath"     => \$makepath,
    "noligs"       => \$noligs,
    "nofligs"      => \$nofligs,
    "show"         => \$show,
    "install"      => \$install,
    "encoding=s"   => \$encoding,
    "variant=s"    => \$variant,  # atl: used as a suffix to $encfile only
    "vendor=s"     => \$vendor,
    "collection=s" => \$collection,
    "fontroot=s"   => \$fontroot,
    "sourcepath=s" => \$sourcepath,
    "passon=s"     => \$passon,
    "slant=s"      => \$slant,
    "spaced=s"     => \$spaced,
    "extend=s"     => \$extend,
    "narrow=s"     => \$narrow,
    "listing"      => \$listing,
    "remove"       => \$remove,
    "test"         => \$test,
    "virtual"      => \$virtual,
    "novirtual"    => \$novirtual,
    "caps=s"       => \$caps,
    "batch"        => \$batch,
    "weight=s"     => \$weight,
    "width=s"      => \$width,
    "expert"       => \$expert,
    "afmpl"        => \$afmpl,
    "afm2pl"       => \$afmpl,
    "lm"           => \$uselmencodings,
    "rootlist=s"   => \$trees,
    "pattern=s"    => \$pattern,
    "trace"        => \$trace,    # --verbose conflicts with --ve
    "preproc"      => \$preproc,  # atl: trigger conversion to pfb
    "lcdf"         => \$lcdf ) ;  # atl: trigger use of lcdf fonttoools

# for/from Fabrice:

my $own_path = "$FindBin::Bin/" ;

$FindBin::RealScript =~ m/([^\.]*)(\.pl|\.bat|\.exe|)/io ;

my $own_name = $1 ;
my $own_type = $2 ;
my $own_stub = "" ;

if ($own_type =~ /pl/oi) {
    $own_stub = "perl "
}

if ($caps) { $afmpl = 0 } # for the moment

# so we can use both combined

if ($lcdf) {
    $novirtual = 1 ;
}

if (!$novirtual) {
    $virtual = 1 ;
}

# A couple of routines.

sub report {
    my $str = shift ;
    $str =~ s/  / /goi ;
    if ($str =~ /(.*?)\s+([\:\/])\s+(.*)/o) {
        if ($1 eq "") {
            $str = " " ;
        } else {
            $str = $2 ;
        }
        print sprintf("%22s $str %s\n",$1,$3) ;
    }
}

sub error {
    report("processing aborted : " . shift) ;
    print "\n" ;
    report "--help : show some more info" ;
    exit ;
}

# The banner.

print "\n" ;
report ("TeXFont 2.2.1 - ConTeXt / PRAGMA ADE 2000-2004") ;
print "\n" ;

# Handy for scripts: one can provide a preferred path, if it
# does not exist, the current path is taken.

if (!(-d $sourcepath)&&($sourcepath ne 'auto')) { $sourcepath = "." }

# Let's make multiple masters if requested.

sub create_mm_font
  { my ($name,$weight,$width) = @_ ; my $flag = my $args = my $tags = "" ;
    my $ok ;
    if ($name ne "")
      { report ("mm source file : $name") }
    else
      { error ("missing mm source file") }
    if ($weight ne "")
      { report ("weight : $weight") ;
        $flag .= " --weight=$weight " ;
        $tags .= "-weight-$weight" }
    if ($width ne "")
      { report ("width : $width") ;
        $flag .= " --width=$width " ;
        $tags .= "-width-$width" }
    error ("no specification given") if ($tags eq "") ;
    error ("no amfm file found") unless (-f "$sourcepath/$name.amfm") ;
    error ("no pfb file found") unless (-f "$sourcepath/$name.pfb") ;
    $args = "$flag --precision=5 --kern-precision=0 --output=$sourcepath/$name$tags.afm" ;
    my $command = "mmafm $args $sourcepath/$name.amfm" ;
    print "$command\n" if $trace ;
    $ok = `$command` ; chomp $ok ;
    if ($ok ne "") { report ("warning $ok") }
    $args = "$flag --precision=5 --output=$sourcepath/$name$tags.pfb" ;
    $command = "mmpfb $args $sourcepath/$name.pfb" ;
    print "$command\n" if $trace ;
    $ok = `$command` ; chomp $ok ;
    if ($ok ne "") { report ("warning $ok") }
    report ("mm result file : $name$tags") }

if (($weight ne "")||($width ne ""))
  { create_mm_font($ARGV[0],$weight,$width) ;
    exit }

# go on

if (($listing||$remove)&&($sourcepath eq "."))
  { $sourcepath = "auto" }

if ($fontroot eq "")
  { if ($dosish)
      { $fontroot = `kpsewhich -expand-path=\$$installpath` }
    else
      { $fontroot = `kpsewhich -expand-path=\\\$$installpath` }
    chomp $fontroot }


if ($fontroot =~ /\s+/)  # needed for windows, spaces in name
  { $fontroot = &GetShortPathName($fontroot) } # but ugly when not needed

if ($test)
  { $vendor = $collection = "test" ;
    $install = 1 }

if (($spaced ne "") && ($spaced !~ /\d/)) { $spaced = "50" }
if (($slant  ne "") && ($slant  !~ /\d/)) { $slant  = "0.167" }
if (($extend ne "") && ($extend !~ /\d/)) { $extend = "1.200" }
if (($narrow ne "") && ($narrow !~ /\d/)) { $narrow = "0.800" }
if (($caps   ne "") && ($caps   !~ /\d/)) { $caps   = "0.800" }

$encoding   = lc $encoding ;
$vendor     = lc $vendor ;
$collection = lc $collection ;

if ($encoding =~ /default/oi) { $encoding = "texnansi" }

my $lcfontroot = lc $fontroot ;

# Auto search paths

my @trees = split(/\,/,$trees) ;

# Test for help asked.

if ($help)
  { report "--fontroot=path     : texmf destination font root (default: $lcfontroot)" ;
    report "--rootlist=paths    : texmf source roots (default: $trees)" ;
    report "--sourcepath=path   : when installing, copy from this path (default: $sourcepath)" ;
    report "--sourcepath=auto   : locate and use vendor/collection" ;
    print  "\n" ;
    report "--vendor=name       : vendor name/directory" ;
    report "--collection=name   : font collection" ;
    report "--encoding=name     : encoding vector (default: $encoding)" ;
    report "--variant=name      : encoding variant (.enc file or otftotfm features)" ;
    print  "\n" ;
    report "--spaced=s          : space glyphs in font by promille of em (0 - 1000)" ;
    report "--slant=s           : slant glyphs in font by factor (0.0 - 1.5)" ;
    report "--extend=s          : extend glyphs in font by factor (0.0 - 1.5)" ;
    report "--caps=s            : capitalize lowercase chars by factor (0.5 - 1.0)" ;
    report "--noligs --nofligs  : remove ligatures" ;
    print  "\n" ;
    report "--install           : copy files from source to font tree" ;
    report "--listing           : list files on auto sourcepath" ;
    report "--remove            : remove files on auto sourcepath" ;
    report "--makepath          : when needed, create the paths" ;
    print  "\n" ;
    report "--test              : use test paths for vendor/collection" ;
    report "--show              : run tex on texfont.tex" ;
    print  "\n" ;
    report "--batch             : process given batch file" ;
    print  "\n" ;
    report "--weight            : multiple master weight" ;
    report "--width             : multiple master width" ;
    print  "\n" ;
    report "--expert            : also handle expert fonts" ;
    print  "\n" ;
    report "--afmpl             : use afm2pl instead of afm2tfm" ;
    report "--preproc           : pre-process ttf/otf, converting them to pfb" ;
    report "--lcdf              : use lcdf fonttools to create virtual encoding" ;
    exit }

if (($batch)||(($ARGV[0]) && ($ARGV[0] =~ /.+\.dat$/io)))
  { my $batchfile = $ARGV[0] ;
    unless (-f $batchfile)
      { if ($batchfile !~ /\.dat$/io) { $batchfile .= ".dat" } }
    unless (-f $batchfile)
      { report ("trying to locate : $batchfile") ;
        $batchfile = `kpsewhich -format="other text files" -progname=context $batchfile` ;
        chomp $batchfile }
    error ("unknown batch file $batchfile") unless -e $batchfile ;
    report ("processing batch file : $batchfile") ;
    my $select = (($vendor ne "")||($collection ne "")) ;
    my $selecting = 0 ;
    if (open(BAT, $batchfile))
      { while (<BAT>)
          { chomp ;
            s/(.+)\#.*/$1/o ;
            next if (/^\s*$/io) ;
            if ($select)
              { if ($selecting)
                  { if (/^\s*[\#\%]/io) { if (!/\-\-/o) { last } else { next } } }
                elsif ((/^\s*[\#\%]/io)&&(/$vendor/i)&&(/$collection/i))
                  { $selecting = 1 ; next }
                else
                  { next } }
            else
              { next if (/^\s*[\#\%]/io) ;
                next unless (/\-\-/oi) }
                s/\s+/ /gio ;
                s/(--en.*\=)\?/$1$encoding/io ;
                report ("batch line : $_") ;
              # system ("perl $0 --fontroot=$fontroot $_") }
	        my $own_quote = ( $own_path =~ m/^[^\"].* / ? "\"" : "" );
            my $switches = '' ;
            $switches .= "--afmpl " if $afmpl ;
            system ("$own_stub$own_quote$own_path$own_name$own_type$own_quote $switches --fontroot=$fontroot $_") }
            close (BAT) }
    exit }

error ("unknown vendor     $vendor")     unless    $vendor ;
error ("unknown collection $collection") unless    $collection ;
error ("unknown tex root   $lcfontroot") unless -d $fontroot ;

my $varlabel = $variant ;

if ($lcdf)
  { $varlabel =~ s/,/-/goi ;
    $varlabel =~ tr/a-z/A-Z/ }

if ($varlabel ne "")
  { $varlabel = "-$varlabel" }

my $identifier = "$encoding$varlabel-$vendor-$collection" ;

my $outlinepath = $sourcepath ; my $path = "" ;

my $shape = "" ;

if ($noligs||$nofligs)
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
    if ($lcdf)
      { $shape .= " -E $extend " }
    else
      { $shape .= " -e $extend " }
    $fontsuffix .= "-extended-" . int(1000*$extend) ;
    $namesuffix .= "-Extended" }

if ($narrow ne "") # goodie
  { $extend = $narrow ;
    if    ($extend<0.0) { $extend = 0.0 }
    elsif ($extend>1.5) { $extend = 1.5 }
    report ("narrow factor : $extend") ;
    if ($lcdf)
      { $shape .= " -E $extend " }
    else
      { $shape .= " -e $extend " }
    $fontsuffix .= "-narrowed-" . int(1000*$extend) ;
    $namesuffix .= "-Narrowed" }

if ($slant ne "")
  {    if ($slant <0.0) { $slant = 0.0 }
    elsif ($slant >1.5) { $slant = 1.5 }
    report ("slant factor : $slant") ;
    if ($lcdf)
      { $shape .= " -S $slant " }
    else
      { $shape .= " -s $slant " }
    $fontsuffix .= "-slanted-" . int(1000*$slant) ;
    $namesuffix .= "-Slanted" }

if ($spaced ne "")
  {    if ($spaced <   0) { $spaced =    0 }
    elsif ($spaced >1000) { $spaced = 1000 }
    report ("space factor : $spaced") ;
    if ($lcdf)
      { $shape .= " -L $spaced " }
    else
      { $shape .= " -m $spaced " }
    $fontsuffix .= "-spaced-" . $spaced ;
    $namesuffix .= "-Spaced" }

if ($sourcepath eq "auto") # todo uppercase root
  { foreach my $root (@trees)
      { if ($dosish)
          { $path = `kpsewhich -expand-path=\$$root` }
        else
          { $path = `kpsewhich -expand-path=\\\$$root` }
        chomp $path ;
        $path = $ENV{$root} if (($path eq '') && defined($ENV{$root})) ;
        report ("checking root : $root") ;
        if ($preproc)
          { $sourcepath = "$path/fonts/truetype/$vendor/$collection" }
        else
          { $sourcepath = "$path/fonts/afm/$vendor/$collection" }
        unless (-d $sourcepath)
          { my $ven = $vendor ; $ven =~ s/(........).*/$1/ ;
            my $col = $collection ; $col =~ s/(........).*/$1/ ;
            $sourcepath = "$path/fonts/afm/$ven/$col" ;
            if (-d $sourcepath)
              { $vendor = $ven ; $collection = $col } }
        $outlinepath = "$path/fonts/type1/$vendor/$collection" ;
        if (-d $sourcepath)
          { # $install = 0 ;  # no copy needed
            $makepath = 1 ; # make on local if needed
	    my @files = validglob("$sourcepath/*.afm") ;
	    if ($preproc)
	      { @files = validglob("$sourcepath/*.otf") ;
	        report("locating : otf files") }
	    unless (@files)
          { @files = validglob("$sourcepath/*.ttf") ;
	        report("locating : ttf files") }
        if (@files)
          { if ($listing)
              { report ("fontpath : $sourcepath" ) ;
                print "\n" ;
                foreach my $file (@files)
                  { if (open(AFM,$file))
                      { my $name = "unknown name" ;
                        while (<AFM>)
                          { chomp ;
                            if (/^fontname\s+(.*?)$/oi)
                              { $name = $1 ; last } }
                        close (AFM) ;
                        if ($preproc)
                          { $file =~ s/.*\/(.*)\..tf/$1/io }
                        else
                          { $file =~ s/.*\/(.*)\.afm/$1/io }
                        report ("$file : $name") } }
                exit }
            elsif ($remove)
              { error ("no removal from : $root") if ($root eq 'TEXMFMAIN') ;
                foreach my $file (@files)
                  { if ($preproc)
                      { $file =~ s/.*\/(.*)\..tf/$1/io }
                    else
                      { $file =~ s/.*\/(.*)\.afm/$1/io }
                    foreach my $sub ("tfm","vf")
                      { foreach my $typ ("","-raw")
                          { my $nam = "$path/fonts/$sub/$vendor/$collection/$encoding$varlabel$typ-$file.$sub" ;
                            if (-s $nam)
                              { report ("removing : $encoding$varlabel$typ-$file.$sub") ;
                                unlink $nam } } } }
                my $nam = "$encoding$varlabel-$vendor-$collection.tex" ;
                if (-e $nam)
                  { report ("removing : $nam") ;
                    unlink "$nam" }
                my $mapfile = "$encoding$varlabel-$vendor-$collection" ;
                foreach my $map ("pdftex","dvips", "dvipdfm")
                  { my $maproot = "$fontroot/fonts/map/$map/context/";
                    if (-e "$maproot$mapfile.map")
                       { report ("renaming : $mapfile.map -> $mapfile.bak") ;
                         unlink "$maproot$mapfile.bak" ;
                         rename "$maproot$mapfile.map", "$maproot$mapfile.bak" } }
                exit }
            else
              { last } } } }
    error ("unknown subpath ../fonts/afm/$vendor/$collection") unless -d $sourcepath }

error ("unknown source path $sourcepath") unless -d $sourcepath ;
error ("unknown option $ARGV[0]")         if (($ARGV[0]||'') =~ /\-\-/) ;

my $afmpath = "$fontroot/fonts/afm/$vendor/$collection" ;
my $tfmpath = "$fontroot/fonts/tfm/$vendor/$collection" ;
my $vfpath  = "$fontroot/fonts/vf/$vendor/$collection" ;
my $pfbpath = "$fontroot/fonts/type1/$vendor/$collection" ;
my $ttfpath = "$fontroot/fonts/truetype/$vendor/$collection" ;
my $otfpath = "$fontroot/fonts/opentype/$vendor/$collection" ;
my $encpath = "$fontroot/fonts/enc/dvips/context" ;

sub mappath
  { my $str = shift ;
    return "$fontroot/fonts/map/$str/context" }

# are not on local path ! ! ! !

foreach my $path ($afmpath, $pfbpath)
  { my @gzipped = <$path/*.gz> ;
    foreach my $file (@gzipped)
      { print "file = $file\n";
	system ("gzip -d $file") } }

# For gerben, we only generate a new database when an lsr file is present but for
# myself we force this when texmf-fonts is used (else I get compatibility problems).

if (($fontroot =~ /texmf\-fonts/o) || (-e "$fontroot/ls-R") || (-e "$fontroot/ls-r") || (-e "$fontroot/LS-R")) {
    system ("mktexlsr $fontroot") ;
}

sub do_make_path
  { my $str = shift ;
    if ($str =~ /^(.*)\/.*?$/)
      { do_make_path($1); }
    mkdir $str, 0755 unless -d $str }

sub make_path
  { my $str = shift ;
    do_make_path("$fontroot/fonts/$str/$vendor/$collection") }

if ($makepath&&$install)
  { make_path ("afm") ; make_path ("type1") }

do_make_path(mappath("pdftex")) ;
do_make_path(mappath("dvips")) ;
do_make_path(mappath("dvipdfm")) ;
do_make_path($encpath) ;

# now fonts/map and fonts/enc

make_path ("vf") ;
make_path ("tfm") ;

if ($install)
  { error ("unknown afm path $afmpath") unless -d $afmpath ;
    error ("unknown pfb path $pfbpath") unless -d $pfbpath }

error ("unknown tfm path $tfmpath") unless -d $tfmpath ;
error ("unknown vf  path $vfpath" ) unless -d $vfpath  ;
error ("unknown map path " . mappath("pdftex"))  unless -d mappath("pdftex");
error ("unknown map path " . mappath("dvips"))   unless -d mappath("dvips");
error ("unknown map path " . mappath("dvipdfm")) unless -d mappath("dvipdfm");

my $mapfile = "$identifier.map" ;
my $bakfile = "$identifier.bak" ;
my $texfile = "$identifier.tex" ;

                report "encoding vector : $encoding" ;
if ($variant) { report "encoding variant : $variant" }
                report      "vendor name : $vendor" ;
                report  "    source path : $sourcepath" ;
                report  "font collection : $collection" ;
                report  "texmf font root : $lcfontroot" ;
                report  "  map file name : $mapfile" ;

if ($install) { report "source path : $sourcepath" }

my $fntlist = "" ;

my $runpath = $sourcepath ;

my @files ;

sub UnLink
  { foreach my $f (@_)
     { if (unlink $f)
          { report "deleted : $f" if $trace } } }

sub globafmfiles
  { my ($runpath, $pattern)  = @_ ;
    my @files = validglob("$runpath/$pattern.afm") ;
    report("locating afm files : using pattern $runpath/$pattern.afm");
    if ($preproc && !$lcdf)
      { @files = validglob("$runpath/$pattern.*tf") ;
        report("locating otf files : using pattern $runpath/$pattern.*tf");
        unless (@files)
          { @files = validglob("$sourcepath/$pattern.ttf") ;
	        report("locating ttf files : using pattern $sourcepath/$pattern.ttf") }
          }
    if (@files) # also elsewhere
      { report("locating afm files : using pattern $pattern") }
    else
      { @files = validglob("$runpath/$pattern.ttf") ;
        if (@files)
          { report("locating afm files : using ttf files") ;
            $extension = "ttf" ;
            foreach my $file (@files)
                   { $file =~ s/\.ttf$//io ;
                     report ("generating afm file : $file.afm") ;
                     my $command = "ttf2afm \"$file.ttf\" -o \"$file.afm\"" ;
                     system($command) ;
                     print "$command\n" if $trace ;
                     push(@cleanup, "$file.afm") }
            @files = validglob("$runpath/$pattern.afm") }
        else # try doing the pre-processing earlier
          { report("locating afm files : using otf files") ;
            $extension = "otf" ;
            @files = validglob("$runpath/$pattern.otf") ;
            foreach my $file (@files)
              { $file =~ s/\.otf$//io ;
            if (!$lcdf)
            { report ("generating afm file : $file.afm") ;
              preprocess_font("$file.otf", "$file.bdf") ;
              push(@cleanup,"$file.afm") }
            if ($preproc)
            { my $command = "cfftot1 --output=$file.pfb $file.otf" ;
                      print "$command\n" if $trace ;
              report("converting : $file.otf to $file.pfb") ;
                      system($command) ;
                      push(@cleanup, "$file.pfb") ;
                }
              }
                if ($lcdf)
            { @files = validglob("$runpath/$pattern.otf") }
            else
            { @files = validglob("$runpath/$pattern.afm") }
          }
       }
    return @files }

if ($pattern eq '') { if ($ARGV[0]) { $pattern = $ARGV[0] } }

if ($pattern ne '')
  { report ("processing files : all in pattern $pattern") ;
    @files = globafmfiles($runpath,$pattern) }
elsif ("$extend$narrow$slant$spaced$caps" ne "")
  { error ("transformation needs file spec") }
else
  { $pattern = "*" ;
    report ("processing files : all on afm path") ;
    @files = globafmfiles($runpath,$pattern) }

sub copy_files
  { my ($suffix,$sourcepath,$topath) = @_ ;
    my @files = validglob("$sourcepath/$pattern.$suffix") ;
    return if ($topath eq $sourcepath) ;
    report ("copying files : $suffix") ;
    foreach my $file (@files)
      { my $ok = $file =~ /(.*)\/(.+?)\.(.*)/ ;
        my ($path,$name,$suffix) = ($1,$2,$3) ;
        UnLink "$topath/$name.$suffix" ;
        report ("copying : $name.$suffix") ;
        copy ($file,"$topath/$name.$suffix") } }

if ($install)
  { copy_files("afm",$sourcepath,$afmpath) ;
#   copy_files("tfm",$sourcepath,$tfmpath) ; # raw supplied names
    copy_files("pfb",$outlinepath,$pfbpath) ;
    if ($extension eq "ttf")
      { make_path("truetype") ;
        copy_files("ttf",$sourcepath,$ttfpath) }
    if ($extension eq "otf")
      { make_path("truetype") ;
	    copy_files("otf",$sourcepath,$ttfpath) } }

error ("no afm files found") unless @files ;

sub open_mapfile
  { my $type = shift;
	my $mappath = mappath($type);
    my $mapdata = "";
	my $mapptr = undef;
	my $fullmapfile = $mapfile;
	$fullmapfile = "$type-$fullmapfile" unless $type eq "pdftex";
	if ($install)
	  { copy ("$mappath/$mapfile","$mappath/$bakfile") ; }
    if (open ($mapptr,"<$mappath/$mapfile"))
      { report ("extending map file : $mappath/$mapfile") ;
        while (<$mapptr>) { unless (/^\%/o) { $mapdata .= $_ } }
        close ($mapptr) }
    else
      { report ("no map file at : $mappath/$mapfile") }
    #~ unless (open ($mapptr,">$fullmapfile") )
do_make_path($mappath) ;
    unless (open ($mapptr,">$mappath/$fullmapfile") )
      { report "warning : can't open $fullmapfile" }
    else
      { if ($type eq "pdftex")
          { print $mapptr "% This file is generated by the TeXFont Perl script.\n";
            print $mapptr "%\n" ;
            print $mapptr "% You need to add the following line to your file:\n" ;
            print $mapptr "%\n" ;
            print $mapptr "%   \\pdfmapfile{+$mapfile}\n" ;
            print $mapptr "%\n" ;
            print $mapptr "% In ConTeXt you can best use:\n" ;
            print $mapptr "%\n" ;
            print $mapptr "%   \\loadmapfile\[$mapfile\]\n\n" } }
    return ($mapptr,$mapdata) ; }

sub finish_mapfile
  { my ($type, $mapptr, $mapdata ) = @_;
	my $fullmapfile = $mapfile;
	$fullmapfile = "$type-$fullmapfile" unless $type eq "pdftex";
    if (defined $mapptr)
      { report ("updating map file : $mapfile (for $type)") ;
        while ($mapdata =~ s/\n\n+/\n/mois) {} ;
        $mapdata =~ s/^\s*//gmois ;
        print $mapptr $mapdata ;
        close ($mapptr) ;
        if ($install)
          { copy ("$fullmapfile", mappath($type) . "/$mapfile") ; } } }


my ($PDFTEXMAP,$pdftexmapdata)   = open_mapfile("pdftex");
my ($DVIPSMAP,$dvipsmapdata)     = open_mapfile("dvips");
my ($DVIPDFMMAP,$dvipdfmmapdata) = open_mapfile("dvipdfm");

my $tex = 0 ;
my $texdata = "" ;

if (open (TEX,"<$texfile"))
  { while (<TEX>) { unless (/stoptext/o) { $texdata .= $_ } }
    close (TEX) }

$tex = open (TEX,">$texfile") ;

unless ($tex) { report "warning : can't open $texfile" }

if ($tex)
  { if ($texdata eq "")
      { print TEX "% interface=en\n" ;
        print TEX "\n" ;
        print TEX "\\usemodule[fnt-01]\n" ;
        print TEX "\n" ;
        print TEX "\\loadmapfile[$mapfile]\n" ;
        print TEX "\n" ;
        print TEX "\\starttext\n\n" }
    else
      { print TEX "$texdata" ;
        print TEX "\n\%appended section\n\n\\page\n\n" } }

sub removeligatures
  { my $filename = shift ; my $skip = 0 ;
    copy ("$filename.vpl","$filename.tmp") ;
    if ((open(TMP,"<$filename.tmp"))&&(open(VPL,">$filename.vpl")))
      { report "removing ligatures : $filename" ;
        while (<TMP>)
         { chomp ;
           if ($skip)
             { if (/^\s*\)\s*$/o) { $skip = 0 ; print VPL "$_\n" } }
           elsif (/\(LIGTABLE/o)
             { $skip = 1 ; print VPL "$_\n" }
           else
             { print VPL "$_\n" } }
        close(TMP) ; close(VPL) }
    UnLink ("$filename.tmp") }

my $raw = my $use = my $maplist = my $texlist = my $report = "" ;

$use = "$encoding$varlabel-" ; $raw = $use . "raw-" ;

my $encfil = "" ;

if ($encoding ne "") # evt -progname=context
  { $encfil = `kpsewhich -progname=pdftex $encoding$varlabel.enc` ;
    chomp $encfil ; if ($encfil eq "") { $encfil = "$encoding$varlabel.enc" } }

sub build_pdftex_mapline
  { my ($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange)  = @_;
    my $cleanname = $fontname;
	$cleanname =~ s/\_//gio ;
    $option =~ s/^\s+(.*)/$1/o ;
    $option =~ s/(.*)\s+$/$1/o ;
    $option =~ s/  / /g ;
    if ($option ne "")
      { $option = "\"$option\" 4" }
    else
      { $option = "4" }
    # adding cleanfont is kind of dangerous
    my $thename = "";
	my $str = "";
    my $theencoding = "" ;
    if ($strange ne "")
      { $thename = $cleanname ; $theencoding = "" ; }
    elsif ($lcdf)
      { $thename = $usename ; $theencoding = " $encoding$varlabel-$cleanname.enc" }
    elsif ($afmpl)
      { $thename = $usename ; $theencoding = " $encoding$varlabel.enc" }
    elsif ($virtual)
      { $thename = $rawname ; $theencoding = " $encoding$varlabel.enc" }
    else
      { $thename = $usename ; $theencoding = " $encoding$varlabel.enc" }
if ($uselmencodings) {
    $theencoding =~ s/^(ec)\.enc/lm\-$1.enc/ ;
}
    # quit rest if no type 1 file
    my $pfb_sourcepath = $sourcepath ;
    $pfb_sourcepath =~ s@/afm/@/type1/@ ;
    unless ((-e "$pfbpath/$fontname.$extension")||
			(-e "$pfb_sourcepath/$fontname.$extension")||
			(-e "$sourcepath/$fontname.$extension")||
			(-e "$ttfpath/$fontname.$extension"))
	  { if ($tex) { $report .= "missing file: \\type \{$fontname.pfb\}\n" }
		report ("missing pfb file : $fontname.pfb") }
    # now add entry to map
    if ($strange eq "") {
	  if ($extension eq "otf") {
		if ($lcdf) {
		  my $mapline = "" ;
		  if (open(ALTMAP,"texfont.map")) {
			while (<ALTMAP>) {
			  chomp ;
			  # atl: we assume this b/c we always force otftotfm --no-type1
			  if (/<<(.*)\.otf$/oi) {
				$mapline = $_ ; last ;
			  }
			}
			close(ALTMAP) ;
		  } else {
			report("no mapfile from otftotfm : texfont.map") ;
		  }
		  if ($preproc) {
			$mapline =~ s/<\[/</;
			$mapline =~ s/<<(\S+)\.otf$/<$1\.pfb/ ;
		  } else {
			$mapline =~ s/<<(\S+)\.otf$/<< $ttfpath\/$fontname.$extension/ ;
		  }
		  $str = "$mapline\n" ;
		} else {
		  if ($preproc) {
			$str = "$thename $cleanfont $option < $fontname.pfb$theencoding\n" ;
		  } else {
			# PdfTeX can't subset OTF files, so we have to include the whole thing
			# It looks like we also need to be explicit on where to find the file
			$str = "$thename $cleanfont $option << $ttfpath/$fontname.$extension <$theencoding\n" ;
		  }
		}
	  } else {
		$str = "$thename $cleanfont $option < $fontname.$extension$theencoding\n" ;
	  }
    } else {
	  $str = "$thename $cleanfont < $fontname.$extension\n" ;
    }
    return ($str, $thename); }

sub build_dvips_mapline
  { my ($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange)  = @_;
    my $cleanname = $fontname;
	$cleanname =~ s/\_//gio ;
    $option =~ s/^\s+(.*)/$1/o ;
    $option =~ s/(.*)\s+$/$1/o ;
    $option =~ s/  / /g ;
    # adding cleanfont is kind of dangerous
    my $thename = "";
	my $str = "";
    my $optionencoding = "" ;
	my $encname = "";
    my $theencoding = "" ;
	if ($encoding ne "") # evt -progname=context
	  { $encfil = `kpsewhich -progname=dvips $encoding$varlabel.enc` ;
		chomp $encfil ;
		if ($encfil eq "")
         { $encfil = "$encoding$varlabel.enc" ; }
		if (open(ENC,"<$encfil"))
		  { while (<ENC>)
			{ if (/^\/([^ ]+)\s*\[/)
              { $encname = $1;
                last; } }
			close ENC; } }
    if ($strange ne "")
      { $thename = $cleanname ;
		$optionencoding = "\"$option\""  if length($option)>1; }
    elsif ($lcdf)
      { $thename = $usename ;
		$optionencoding = "\"$option $encname ReEncodeFont\" <$encoding$varlabel-$cleanname.enc" }
    elsif ($afmpl)
      { $thename = $usename ;
		$optionencoding = "\"$option $encname ReEncodeFont\" <$encoding$varlabel.enc" }
    elsif ($virtual)
      { $thename = $rawname ;
		$optionencoding = "\"$option $encname ReEncodeFont\" <$encoding$varlabel.enc" }
    else
      { $thename = $usename ;
		$optionencoding = "\"$option $encname ReEncodeFont\" <$encoding$varlabel.enc" }
if ($uselmencodings) {
    $theencoding =~ s/^(ec)\.enc/lm\-$1.enc/ ;
}
    # quit rest if no type 1 file
    my $pfb_sourcepath = $sourcepath ;
    $pfb_sourcepath =~ s@/afm/@/type1/@ ;
    unless ((-e "$pfbpath/$fontname.$extension")||
			(-e "$pfb_sourcepath/$fontname.$extension")||
			(-e "$sourcepath/$fontname.$extension")||
			(-e "$ttfpath/$fontname.$extension"))
	  { if ($tex) { $report .= "missing file: \\type \{$fontname.pfb\}\n" }
       report ("missing pfb file : $fontname.pfb") }
    # now add entry to map
    if ($strange eq "") {
	  if ($extension eq "otf") {
		if ($lcdf) {
		  my $mapline = "" ;
		  if (open(ALTMAP,"texfont.map")) {
			while (<ALTMAP>) {
			  chomp ;
			  # atl: we assume this b/c we always force otftotfm --no-type1
			  if (/<<(.*)\.otf$/oi) {
				$mapline = $_ ; last ;
			  }
			}
			close(ALTMAP) ;
		  } else {
			report("no mapfile from otftotfm : texfont.map") ;
		  }
		  if ($preproc) {
			$mapline =~ s/<\[/</;
			$mapline =~ s/<<(\S+)\.otf$/<$1\.pfb/ ;
		  } else {
			$mapline =~ s/<<(\S+)\.otf$/<< $ttfpath\/$fontname.$extension/ ;
		  }
		  $str = "$mapline\n" ;
		} else {
		  if ($preproc) {
			$str = "$thename $cleanfont $optionencoding <$fontname.pfb\n" ;
		  } else {
			# dvips can't subset OTF files, so we have to include the whole thing
			# It looks like we also need to be explicit on where to find the file
			$str = "$thename $cleanfont $optionencoding << $ttfpath/$fontname.$extension \n" ;
		  }
		}
	  } else {
		$str = "$thename $cleanfont $optionencoding <$fontname.$extension\n" ;
	  }
	} else {
	  $str = "$thename $cleanfont $optionencoding <$fontname.$extension\n" ;
	}
    return ($str, $thename); }
#	return $str; }


sub build_dvipdfm_mapline
  { my ($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange)  = @_;
    my $cleanname = $fontname;
	$cleanname =~ s/\_//gio ;
	$option =~ s/([\d\.]+)\s+SlantFont/ -s $1 /;
	$option =~ s/([\d\.]+)\s+ExtendFont/ -e $1 /;
    $option =~ s/^\s+(.*)/$1/o ;
    $option =~ s/(.*)\s+$/$1/o ;
    $option =~ s/  / /g ;
    # adding cleanfont is kind of dangerous
    my $thename = "";
	my $str = "";
    my $theencoding = "" ;
    if ($strange ne "")
      { $thename = $cleanname ; $theencoding = "" ; }
    elsif ($lcdf)
      { $thename = $usename ; $theencoding = " $encoding$varlabel-$cleanname" }
    elsif ($afmpl)
      { $thename = $usename ; $theencoding = " $encoding$varlabel" }
    elsif ($virtual)
      { $thename = $rawname ; $theencoding = " $encoding$varlabel" }
    else
      { $thename = $usename ; $theencoding = " $encoding$varlabel" }
if ($uselmencodings) {
    $theencoding =~ s/^(ec)\.enc/lm\-$1.enc/ ;
}
    # quit rest if no type 1 file
    my $pfb_sourcepath = $sourcepath ;
    $pfb_sourcepath =~ s@/afm/@/type1/@ ;
    unless ((-e "$pfbpath/$fontname.$extension")||
			(-e "$pfb_sourcepath/$fontname.$extension")||
			(-e "$sourcepath/$fontname.$extension")||
			(-e "$ttfpath/$fontname.$extension"))
	  { if ($tex) { $report .= "missing file: \\type \{$fontname.pfb\}\n" }
		report ("missing pfb file : $fontname.pfb") }
    # now add entry to map
    if ($strange eq "") {
	  if ($extension eq "otf") {
		#TH: todo
	  } else {
		$str = "$thename $theencoding $fontname $option\n" ;
	  }
	} else {
	  $str = "$thename $fontname $option\n" ;
	}
    return ($str, $thename); }
#	return $str; }


sub preprocess_font
  { my ($infont,$pfbfont) = @_ ;
    if ($infont ne "")
      { report ("otf/ttf source file : $infont") ;
        report ("destination file : $pfbfont") ; }
    else
      { error ("missing otf/ttf source file") }
    open (CONVERT, "| pfaedit -script -") || error ("couldn't open pipe to pfaedit") ;
    report ("pre-processing with : pfaedit") ;
    print CONVERT "Open('$infont');\n Generate('$pfbfont', '', 1) ;\n" ;
    close (CONVERT) }

foreach my $file (@files)
  { my $option = my $slant = my $spaced = my $extend = my $vfstr = my $encstr = "" ;
    my $strange = "" ; my ($rawfont,$cleanfont,$restfont) ;
    $file = $file ;
    my $ok = $file =~ /(.*)\/(.+?)\.(.*)/ ;
    my ($path,$name,$suffix) = ($1,$2,$3) ;
    # remove trailing _'s
    my $fontname = $name ;
    my $cleanname = $fontname ;
    $cleanname =~ s/\_//gio ;
    # atl: pre-process an opentype or truetype file by converting to pfb
    if ($preproc && !$lcdf)
      { unless (-f "$afmpath/$cleanname.afm" && -f "$pfbpath/$cleanname.pfb")
          { preprocess_font("$path/$name.$suffix", "$pfbpath/$cleanname.pfb") ;
            rename("$pfbpath/$cleanname.afm", "$afmpath/$cleanname.afm")
	      || error("couldn't move afm product of pre-process.") }
        $path = $afmpath ;
        $file = "$afmpath/$cleanname.afm" }
    # cleanup
    foreach my $suf ("tfm", "vf", "vpl")
      { UnLink "$raw$cleanname$fontsuffix.$suf" ;
        UnLink "$use$cleanname$fontsuffix.$suf" }
    UnLink "texfont.log" ;
    # set switches
    if ($encoding ne "")
      { $encstr = " -T $encfil" }
    if ($caps ne "")
      { $vfstr = " -V $use$cleanname$fontsuffix" }
    else # if ($virtual)
      { $vfstr = " -v $use$cleanname$fontsuffix" }
    my $font = "";
    # let's see what we have here (we force texnansi.enc to avoid error messages)
    if ($lcdf)
      { my $command = "otfinfo -p $file" ;
        print "$command\n" if $trace;
        $font = `$command` ;
        chomp $font ;
        $cleanname = $cleanfont = $font }
    else
      { my $command = "afm2tfm \"$file\" -p texnansi.enc texfont.tfm" ;
        print "$command (for testing)\n" if $trace ;
        $font = `$command` ;
        UnLink "texfont.tfm" ;
        ($rawfont,$cleanfont,$restfont) = split(/\s/,$font) }
    if ($font =~ /(math|expert)/io) { $strange = lc $1 }
    $cleanfont =~ s/\_/\-/goi ;
    $cleanfont =~ s/\-+$//goi ;
    print "\n" ;
    if (($strange eq "expert")&&($expert))
      { report ("font identifier : $cleanfont$namesuffix -> $strange -> tfm") }
    elsif ($strange ne "")
      { report ("font identifier : $cleanfont$namesuffix -> $strange -> skipping") }
    elsif ($afmpl)
      { report ("font identifier : $cleanfont$namesuffix -> text -> tfm") }
    elsif ($virtual)
      { report ("font identifier : $cleanfont$namesuffix -> text -> tfm + vf") }
    else
      { report ("font identifier : $cleanfont$namesuffix -> text -> tfm") }
    # don't handle strange fonts
    if ($strange eq "")
      { # atl: support for lcdf otftotfm
        if ($lcdf && $extension eq "otf")
          { # no vf, bypass afm, use otftotfm to get encoding and tfm
            my $varstr = my $encout = my $tfmout = "" ;
            report "processing files : otf -> tfm + enc" ;
            if ($encoding ne "")
              { $encfil = `kpsewhich -progname=pdftex $encoding.enc` ;
                chomp $encfil ; if ($encfil eq "") { $encfil = "$encoding.enc" }
                $encstr = " -e $encfil " }
            if ($variant ne "")
              { ( $varstr = $variant ) =~ s/,/ -f /goi ;
                $varstr = " -f $varstr" }
            $encout = "$encpath/$use$cleanfont.enc" ;
            if (-e $encout)
              { report ("renaming : $encout -> $use$cleanfont.bak") ;
                UnLink "$encpath/$use$cleanfont.bak" ;
                rename $encout, "$encpath/$use$cleanfont.bak" }
    	    UnLink "texfont.map" ;
            $tfmout = "$use$cleanfont$fontsuffix" ;
            my $otfcommand = "otftotfm -a $varstr $encstr $passon $shape --name=\"$tfmout\" --encoding-dir=\"$encpath/\" --tfm-dir=\"$tfmpath/\" --vf-dir=\"$vfpath/\" --no-type1 --map-file=./texfont.map \"$file\"" ;
            print "$otfcommand\n"  if $trace ;
            system("$otfcommand") ;
            $encfil = $encout }
        else
          { # generate tfm and vpl, $file is on afm path
            my $font = '' ;
            if ($afmpl)
              { report "         generating pl : $cleanname$fontsuffix (from $cleanname)" ;
                $encstr = " -p $encfil" ;
                if ($uselmencodings) {
                    $encstr =~ s/(ec)\.enc$/lm\-$1\.enc/ ;
                }
                my $command = "afm2pl -f afm2tfm $shape $passon $encstr $file $cleanname$fontsuffix.vpl" ;
                print "$command\n" if $trace ;
                my $ok = `$command` ;
                if (open (TMP,"$cleanname$fontsuffix.map"))
                   { $font = <TMP> ;
                     close(TMP) ;
                     UnLink "$cleanname$fontsuffix.map" } }
            else
              { report "generating raw tfm/vpl : $raw$cleanname$fontsuffix (from $cleanname)" ;
                my $command = "afm2tfm $file $shape $passon $encstr $vfstr $raw$cleanname$fontsuffix" ;
                print "$command\n" if $trace ;
                $font = `$command` }
			# generate vf file if needed
			chomp $font ;
			if ($font =~ /.*?([\d\.]+)\s*ExtendFont/io) { $extend = $1 }
			if ($font =~ /.*?([\d\.]+)\s*SlantFont/io)  { $slant  = $1 }
			if ($extend ne "") { $option .= " $extend ExtendFont " }
			if ($slant ne "")  { $option .= " $slant SlantFont " }
			if ($afmpl)
			  { if ($noligs||$nofligs) { removeligatures("$cleanname$fontsuffix") }
                report "generating new tfm : $use$cleanname$fontsuffix" ;
				my $command = "pltotf $cleanname$fontsuffix.vpl $use$cleanname$fontsuffix.tfm" ;
				print "$command\n" if $trace ;
				my $ok = `$command` }
			elsif ($virtual)
			  { if ($noligs||$nofligs) { removeligatures("$use$cleanname$fontsuffix") }
                report "generating new vf : $use$cleanname$fontsuffix (from $use$cleanname)" ;
				my $command = "vptovf $use$cleanname$fontsuffix.vpl $use$cleanname$fontsuffix.vf $use$cleanname$fontsuffix.tfm" ;
				print "$command\n" if $trace ;
				my $ok = `$command` }
			else
			  { if ($noligs||$nofligs) { removeligatures("$raw$cleanname$fontsuffix") }
                report "generating new tfm : $use$cleanname$fontsuffix (from $raw$cleanname)" ;
				my $command = "pltotf $raw$cleanname$fontsuffix.vpl $use$cleanname$fontsuffix.tfm" ;
				print "$command\n" if $trace ;
				my $ok = `$command` } } }
    elsif (-e "$sourcepath/$cleanname.tfm" )
      { report "using existing tfm : $cleanname.tfm" }
    elsif (($strange eq "expert")&&($expert))
      { report "creating tfm file : $cleanname.tfm" ;
        my $command = "afm2tfm $file $cleanname.tfm" ;
        print "$command\n" if $trace ;
        my $font = `$command` }
    else
      { report "use supplied tfm : $cleanname" }
    # report results
    if (!$lcdf)
    { ($rawfont,$cleanfont,$restfont) = split(/\s/,$font) }
    $cleanfont =~ s/\_/\-/goi ;
    $cleanfont =~ s/\-+$//goi ;
    # copy files
    my $usename = "$use$cleanname$fontsuffix" ;
    my $rawname = "$raw$cleanname$fontsuffix" ;

    if ($lcdf eq "")
    { if ($strange ne "")
        { UnLink ("$vfpath/$cleanname.vf", "$tfmpath/$cleanname.tfm") ;
          copy ("$cleanname.tfm","$tfmpath/$cleanname.tfm") ;
          copy ("$usename.tfm","$tfmpath/$usename.tfm") ;
          # or when available, use vendor one :
          copy ("$sourcepath/$cleanname.tfm","$tfmpath/$cleanname.tfm") }
      elsif ($virtual)
        { UnLink ("$vfpath/$rawname.vf", "$vfpath/$usename.vf") ;
          UnLink ("$tfmpath/$rawname.tfm", "$tfmpath/$usename.tfm") ;
          copy ("$usename.vf" ,"$vfpath/$usename.vf") ;
          copy ("$rawname.tfm","$tfmpath/$rawname.tfm") ;
          copy ("$usename.tfm","$tfmpath/$usename.tfm") }
      elsif ($afmpl)
        { UnLink ("$vfpath/$rawname.vf", "$vfpath/$usename.vf", "$vfpath/$cleanname.vf") ;
          UnLink ("$tfmpath/$rawname.tfm", "$tfmpath/$usename.tfm", "$tfmpath/$cleanname.tfm") ;
          copy ("$usename.tfm","$tfmpath/$usename.tfm") }
      else
        { UnLink ("$vfpath/$usename.vf", "$tfmpath/$usename.tfm") ;
          # slow but prevents conflicting vf's
          my $rubish = `kpsewhich $usename.vf` ; chomp $rubish ;
          if ($rubish ne "") { UnLink $rubish }
          #
          copy ("$usename.tfm","$tfmpath/$usename.tfm") } }
    # cleanup
    foreach my $suf ("tfm", "vf", "vpl")
      { UnLink ("$rawname.$suf", "$usename.$suf") ;
        UnLink ("$cleanname.$suf", "$fontname.$suf") ;
        UnLink ("$cleanname$fontsuffix.$suf", "$fontname$fontsuffix.$suf") }
    # add line to map files
	my $str = my $thename = "";
    ($str, $thename) = build_pdftex_mapline($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange);
	# check for redundant entries
    if (defined $PDFTEXMAP) {
	  $pdftexmapdata =~ s/^$thename\s.*?$//gmis ;
	  if ($afmpl) {
		if ($pdftexmapdata =~ s/^$rawname\s.*?$//gmis) {
		  report ("removing raw file : $rawname") ;
		}
	  }
	  $maplist .= $str ;
	  $pdftexmapdata .= $str ;
    }
    ($str, $thename) = build_dvips_mapline($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange);
	# check for redundant entries
    if (defined $DVIPSMAP) {
	  $dvipsmapdata =~ s/^$thename\s.*?$//gmis ;
	  if ($afmpl) {
		if ($dvipsmapdata =~ s/^$rawname\s.*?$//gmis) {
		  report ("removing raw file : $rawname") ;
		}
	  }
	  $dvipsmapdata .= $str ;
    }
    ($str, $thename) = build_dvipdfm_mapline($option, $usename, $fontname, $rawname, $cleanfont, $encoding, $varlabel, $strange);
	# check for redundant entries
    if (defined $DVIPDFMMAP) {
	  $dvipdfmmapdata =~ s/^$thename\s.*?$//gmis ;
	  if ($afmpl) {
		if ($dvipdfmmapdata =~ s/^$rawname\s.*?$//gmis) {
		  report ("removing raw file : $rawname") ;
		}
	  }
	  $dvipdfmmapdata .= $str ;
    }

    # write lines to tex file
    if (($strange eq "expert")&&($expert)) {
        $fntlist .= "\\definefontsynonym[$cleanfont$namesuffix][$cleanname] \% expert\n" ;
    } elsif ($strange ne "") {
        $fntlist .= "\%definefontsynonym[$cleanfont$namesuffix][$cleanname]\n" ;
    } else {
        $fntlist .= "\\definefontsynonym[$cleanfont$namesuffix][$usename][encoding=$encoding]\n" ;
    }
    next unless $tex ;
    if (($strange eq "expert")&&($expert)) {
        $texlist .= "\\ShowFont[$cleanfont$namesuffix][$cleanname]\n" ;
    } elsif ($strange ne "") {
        $texlist .= "\%ShowFont[$cleanfont$namesuffix][$cleanname]\n" ;
    } else {
        $texlist .= "\\ShowFont[$cleanfont$namesuffix][$usename][$encoding]\n"
    }
}

finish_mapfile("pdftex",  $PDFTEXMAP,  $pdftexmapdata);
finish_mapfile("dvipdfm", $DVIPDFMMAP, $dvipdfmmapdata);
finish_mapfile("dvips",   $DVIPSMAP,   $dvipsmapdata);

if ($tex)
  { my $mappath = mappath("pdftex");
    $mappath =~ s/\\/\//go ;
    $savedoptions =~ s/^\s+//gmois ; $savedoptions =~ s/\s+$//gmois ;
    $fntlist      =~ s/^\s+//gmois ; $fntlist      =~ s/\s+$//gmois ;
    $maplist      =~ s/^\s+//gmois ; $maplist      =~ s/\s+$//gmois ;
    print TEX "$texlist" ;
    print TEX "\n" ;
    print TEX "\\setupheadertexts[\\tttf example definitions]\n" ;
    print TEX "\n" ;
    print TEX "\\starttyping\n" ;
    print TEX "texfont $savedoptions\n" ;
    print TEX "\\stoptyping\n" ;
    print TEX "\n" ;
    print TEX "\\starttyping\n" ;
    print TEX "$mappath/$mapfile\n" ;
    print TEX "\\stoptyping\n" ;
    print TEX "\n" ;
    print TEX "\\starttyping\n" ;
    print TEX "$fntlist\n" ;
    print TEX "\\stoptyping\n" ;
    print TEX "\n" ;
    print TEX "\\page\n" ;
    print TEX "\n" ;
    print TEX "\\setupheadertexts[\\tttf $mapfile]\n" ;
    print TEX "\n" ;
    print TEX "\\starttyping\n" ;
    print TEX "$maplist\n" ;
    print TEX "\\stoptyping\n" ;
    print TEX "\n" ;
    print TEX "\\stoptext\n" }

if ($tex) { close (TEX) }

# atl: global cleanup with generated files (afm & ttf don't mix)

UnLink(@cleanup) ;

print "\n" ; report ("generating : ls-r databases") ;

# Refresh database.

print "\n" ; system ("mktexlsr $fontroot") ; print "\n" ;

# Process the test file.

if ($show) { system ("texexec --once --silent $texfile") }

@files = validglob("$identifier.* *-$identifier.map") ;

foreach my $file (@files)
  { unless ($file =~ /(tex|pdf|log|mp|tmp)$/io) { UnLink ($file) } }

exit ;
