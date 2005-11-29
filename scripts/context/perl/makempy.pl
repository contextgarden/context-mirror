eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D \module
#D   [       file=makempy.pl,
#D        version=2000.12.14,
#D          title=\METAFUN,
#D       subtitle=\METAPOST\ Text Graphics,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

# Tobias Burnus provided the code needed to proper testing
# of binaries on UNIX as well as did some usefull suggestions
# to improve the functionality.

# This script uses GhostScript and PStoEdit as well as
# pdfTeX, and if requested TeXEdit and ConTeXt.

# todo: we can nowadays do without the intermediate step, because GS
# can now handle PDF quite good

use Getopt::Long ;
use Config ;
use strict ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

my $help    = 0 ;
my $silent  = 0 ;
my $force   = 0 ;
my $noclean = 0 ;

my $amethod = my $pmethod = my $gmethod = 0 ;

my $format  = "plain" ; # can be "context" for plain users too

&GetOptions
  ( "help"        => \$help    ,
    "silent"      => \$silent  ,
    "force"       => \$force   ,
    "pdftops"     => \$pmethod ,
    "xpdf"        => \$pmethod ,
    "gs"          => \$gmethod ,
    "ghostscript" => \$gmethod ,
    "noclean"     => \$noclean ) ;

my $mpochecksum = 0 ;

my %tex ; my %start ; my %stop ;

$tex{plain}     = "pdftex" ;
$tex{latex}     = "pdflatex" ;
$tex{context}   = "texexec --batch --once --interface=en --pdf" ;

$start{plain}   = '' ;
$stop{plain}    = '\end' ;

$start{latex}   = '\begin{document}' ;
$stop{latex}    = '\end{document}' ;

$start{context} = '\starttext' ;
$stop{context}  = '\stoptext' ;

my $ghostscript  = "" ;
my $pstoedit     = "" ;
my $pdftops      = "" ;
my $acroread     = "" ;

my $wereondos    = ($Config{'osname'} =~ /dos|mswin/io) ;

# Unix only: assume that "gs" in the path. We could also
# use $ghostscipt = system "which gs" but this would require
# that which is installedd on the system.

sub checkenv
  { my ($var, $env) = @_ ;
    if ($var)
      { return $var }
    elsif ($ENV{$env})
      { return $ENV{$env} }
    else
      { return $var } }

$ghostscript = checkenv ($ghostscript, "GS_PROG" ) ;
$ghostscript = checkenv ($ghostscript, "GS"      ) ;
$pstoedit    = checkenv ($pstoedit   , "PSTOEDIT") ;
$pdftops     = checkenv ($pdftops    , "PDFTOPS" ) ;
$acroread    = checkenv ($acroread   , "ACROREAD") ;

sub setenv
  { my ($var, $unix, $win) = @_ ;
    if ($var)
      { return $var }
    elsif ($wereondos)
      { return $win }
    else
      { return $unix } }

$ghostscript = setenv($ghostscript, "gs"      , "gswin32c") ;
$pstoedit    = setenv($pstoedit   , "pstoedit", "pstoedit") ;
$pdftops     = setenv($pdftops    , "pdftops" , "pdftops" ) ;
$acroread    = setenv($acroread   , "acroread", ""        ) ;

# Force a method if unknown.

unless ($pmethod||$amethod||$gmethod)
  { if ($wereondos) { $pmethod = 1 } else { $amethod = 1 } }

# Set the error redirection used under Unix:
# stderr -> stdout

my $logredirection = '>>' ;

# This unfortunally doesn't work with the ksh and simple sh
#
# if (!$wereondos)
#   { $logredirection = '2>&1 >>' ; # Bash
#     $logredirection = '>>&' ;     # tcsh, Bash
#     default $logredirection. }

# Some TeX Code Snippets.

my $macros = '

% auxiliary macros

\input supp-mis.tex

\def\startTEXpage[scale=#1]%
  {\output{}
   \batchmode
   \pdfoutput=1
   \pdfcompresslevel=9
   \hoffset=-1in
   \voffset=\hoffset
   \scratchcounter=#1
   \divide\scratchcounter1000
   \edef\TEXscale{\the\scratchcounter\space}
   \forgetall
   \setbox0=\vbox\bgroup}

\def\stopTEXpage
  {\egroup
   \dimen0=\ht0 \advance\dimen0 \dp0
   \setbox2=\vbox to 10\dimen0
     {\pdfliteral{\TEXscale 0 0 \TEXscale 0 0 cm}
      \copy0
      \pdfliteral{1 0 0 1 0 0 cm}
      \vfill}
   \wd2=10\wd0
   \pdfpageheight=\ht2
   \pdfpagewidth=\wd2
   \ScaledPointsToBigPoints{\number\pdfpageheight}\pdfcropheight
   \ScaledPointsToBigPoints{\number\pdfpagewidth }\pdfcropwidth
   \expanded{\pdfpageattr{/CropBox [0 0 \pdfcropwidth \space \pdfcropheight]}}
   \shipout\hbox{\box2}}

% end of auxiliary macros' ;

sub report
  { return if $silent ;
    my $str = shift ;
    if ($str =~ /(.*?)\s+([\:\/])\s+(.*)/o)
      { if ($1 eq "") { $str = " " } else { $str = $2 }
        print sprintf("%22s $str %s\n",$1,$3) } }

sub error
  { report("processing aborted : " . shift) ;
    exit }

sub process
  { report("generating : " . shift) }

sub banner
  { return if $silent ;
    print "\n" ;
    report ("MakeMPY 1.1 - MetaFun / PRAGMA ADE 2000-2004") ;
    print "\n" }

my $metfile = "" ; # main metapost file
my $mpofile = "" ; # metapost text specifiation file (provided)
my $mpyfile = "" ; # metapost text picture file (generated)
my $texfile = "" ; # temporary tex file
my $pdffile = "" ; # temporary pdf file
my $tmpfile = "" ; # temporary metapost file
my $posfile = "" ; # temporary postscript file
my $logfile = "" ; # temporary log file
my $errfile = "" ; # final log file (with suffix log)

sub show_help_info
  { banner ;
    report ("--help : this message" ) ;
    report ("--noclean : don't remove temporary files" ) ;
    report ("--force : force processing (ignore checksum)" ) ;
    report ("--silent : don't show messages" ) ;
    print "\n" ;
    report ("--pdftops : use pdftops (xpdf) pdf->ps") ;
    report ("--ghostscript : use ghostscript (gs) for pdf->ps") ;
    print "\n" ;
    report ("input file : metapost file with graphics") ;
    report ("programs needed : texexec and english context") ;
    report (" : pdftops from the xpdf suite, or") ; # page size buggy
    report (" : pdf2ps and ghostscript, and") ;
    report (" : pstoedit and ghostscript") ;
    report ("output file : metapost file with pictures") ;
    exit }

sub check_input_file
  { my $file = $ARGV[0] ;
    if ((!defined($file))||($file eq ""))
      { banner ; error("no filename given") }
    else
      { $file =~ s/\.mp.*$//o ;
        $metfile =     "$file.mp"  ;
        $mpofile =     "$file.mpo" ;
        $mpyfile =     "$file.mpy" ;
        $logfile =     "$file.log" ;
        $texfile = "mpy-$file.tex" ;
        $pdffile = "mpy-$file.pdf" ;
        $posfile = "mpy-$file.pos" ;
        $tmpfile = "mpy-$file.tmp" ;
        $errfile = "mpy-$file.log" ;
        if (! -f $metfile)
          { banner ; error("$metfile is empty") }
        elsif (-s $mpofile < 32)
          { unlink $mpofile ; # may exist with zero length
            unlink $mpyfile ; # get rid of left overs
            exit }
        else
          { banner ; report("processing file : $mpofile") } } }

sub verify_check_sum # checksum calculation from perl documentation
  { return unless (open (MPO,"$mpofile")) ;
    $mpochecksum = do { local $/ ; unpack("%32C*",<MPO>) % 65535 } ;
    close (MPO) ;
    return unless open (MPY,"$mpyfile") ;
    my $str = <MPY> ; chomp $str ;
    close (MPY) ;
    if ($str =~ /^\%\s*mpochecksum\s*\:\s*(\d+)/o)
      { if ($mpochecksum eq $1)
          { report("mpo checksum : $mpochecksum / unchanged") ;
            exit unless $force }
        else
          { report("mpo checksum : $mpochecksum / changed") } } }

sub cleanup_files
  { my @files = <mpy-*.*> ;
    foreach (@files) { unless (/\.log/o) { unlink $_ } } }

sub construct_tex_file
  { my $n = 0 ;
    unless (open (MPO, "<$mpofile"))
      { error("unable to open $mpofile") }
    unless (open (TEX, ">$texfile"))
      { error("unable to open $texfile") }
    my $textext = "" ;
    while (<MPO>)
     { s/\s*$//mois ;
       if (/\%\s*format=(\w+)/)
         { $format = $1 }
       else # if (!/^\%/)
         { if (/startTEXpage/o)
             { ++$n ;
               $textext .= "$start{$format}\n" ;
               $start{$format} = "" }
           $textext .= "$_\n" } }
    unless (defined($tex{$format})) { $format = "plain" }
    if ($format eq "context") { $macros = "" }
  # print TEX "$start{$format}\n$macros\n$textext\n$stop{$format}\n" ;
    print TEX "$start{$format}\n\n" if $start{$format} ;
    print TEX "$macros\n"           if $macros ;
    print TEX "$textext\n"          if $textext ;
    print TEX "$stop{$format}\n"    if $stop{$format} ;
    close (MPO) ;
    close (TEX) ;
    report("tex format : $format") ;
    report("requested texts : $n") }

sub construct_mpy_file
  { unless (open (TMP, "<$tmpfile"))
      { error("unable to open $tmpfile file") }
    unless (open (MPY, ">$mpyfile"))
      { error("unable to open $mpyfile file") }
    print MPY "% mpochecksum : $mpochecksum\n" ;
    my $copying = my $n = 0 ;
    while (<TMP>)
     { if (s/beginfig/begingraphictextfig/o)
         { print MPY $_ ; $copying = 1 ; ++$n }
       elsif (s/endfig/endgraphictextfig/o)
         { print MPY $_ ; $copying = 0 }
       elsif ($copying)
         { print MPY $_ } }
   close (TMP) ;
   close (MPY) ;
   report("processed texts : $n") ;
   report("produced file : $mpyfile") }

sub run
  { my ($resultfile, $program,$arguments) = @_ ;
    my $result = system("$program $arguments $logredirection $logfile") ;
    unless (-f $resultfile) { error("invalid `$program' run") } }

sub make_pdf_pages
  { process ("pdf file") ;
    run ($pdffile, "$tex{$format}", "$texfile") }

sub make_mp_figures
  { process ("postscript file") ;
    if ($pmethod) { run($posfile, "$pdftops",
      "-paper match $pdffile $posfile") }
    if ($gmethod) { run($posfile, "$ghostscript",
      "-q -sOutputFile=$posfile -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pswrite $pdffile") }
    if ($amethod) { run($posfile, "$acroread",
      "-toPostScript -pairs $pdffile $posfile") } }

sub make_mp_pictures_ps
  { process ("metapost file") ;
    run ($tmpfile, "$pstoedit", "-ssp -dt -f mpost $posfile $tmpfile") }

sub make_mp_pictures_pdf
  { process ("metapost file") ;
    run ($tmpfile, "$pstoedit", "-ssp -dt -f mpost $pdffile $tmpfile") }

if ($help) { show_help_info }

check_input_file ;
verify_check_sum ;
cleanup_files ;
construct_tex_file ;
make_pdf_pages ;
if (1)
  { make_mp_pictures_pdf ; }
else
  { make_mp_figures ;
    make_mp_pictures_ps ; }
construct_mpy_file ; # less save : rename $tmpfile, $mpyfile ;
unless ($noclean) { cleanup_files }

# a simple test file (needs context)
#
# % output=pdftex
#
# \starttext
#
# \startMPpage
#   graphictext
#     "\bf MAKE"
#     scaled 8
#     zscaled (1,2)
#     withdrawcolor \MPcolor{blue}
#     withfillcolor \MPcolor{gray}
#     withpen pencircle scaled 5pt ;
# \stopMPpage
#
# \stoptext
