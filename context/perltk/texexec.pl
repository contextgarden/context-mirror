eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D We started with a hack provided by Thomas Esser. This
#D expression replaces the unix specific line \type
#D {#!/usr/bin/perl}.

# in a few versions DetermineNOfPdfPages is obsolete

# nog doen: automatisch log scannen op overfull en missing
# fastmode tzt anders: \iffastmode \fi

#D \module
#D   [       file=texexec.pl,
#D        version=1999.11.03,
#D          title=running \ConTeXt,
#D       subtitle=\TEXEXEC,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

#  Thanks to Tobias Burnus    for the german translations.
#  Thanks to Thomas Esser     for hooking it into web2c
#  Thanks to Taco   Hoekwater for suggesting improvements

use Cwd ;
use Time::Local ;
use Config ;
use Getopt::Long ;

use strict ;

#D In this script we will launch some programs and other
#D scripts. \TEXEXEC\ uses an ini||file to sort out where
#D those programs are stored. Two boolean variables keep
#D track of the way to call the programs. In \TEXEXEC,
#D \type {$dosish} keeps track of the operating system.
#D It will be no surprise that Thomas Esser provided me
#D the neccessary code to accomplish this.

my $dosish  = ($Config{'osname'} =~ /dos|win/i) ;

my $TeXUtil   = 'texutil'  ;
my $SGMLtoTeX = 'sgml2tex' ;
my $FDFtoTeX  = 'fdf2tex'  ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

my $AddEmpty         = '' ;
my $Alone            = 0 ; 
my $Arrange          = 0 ;
my $BackSpace        = '0pt' ;
my $CenterPage       = 0 ;
my $ConTeXtInterface = 'unknown'  ;
my $Convert          = '' ;
my $DoMPTeX          = 0 ;
my $EnterBatchMode   = 0 ;
my $Environment      = '' ;
my $FastMode         = 0 ;
my $FinalMode        = 0 ;
my $Format           = '' ;
my $HelpAsked        = 0 ;
my $MainBodyFont     = 'standard' ;
my $MainLanguage     = 'standard' ;
my $MakeFormats      = 0 ;
my $Markings         = 0     ;
my $Mode             = '' ;
my $NoArrange        = 0 ;
my $NoDuplex         = 0 ;
my $NOfRuns          = 7 ;
my $NoMPMode         = 0 ;
my $OutputFormat     = 'standard' ;
my $Pages            = '' ;
my $PageScale        = '1000' ; # == 1.0 
my $PaperFormat      = 'standard' ;
my $PaperOffset      = '0pt' ;
my $PassOn           = '' ;
my $PdfArrange       = 0 ;
my $PdfSelect        = 0 ;
my $PdfCombine       = 0 ;
my $PrintFormat      = 'standard' ;
my $ProducePdf       = 0 ;
my $Result           = 0 ;
my $RunOnce          = 0 ;
my $Selection        = '' ;
my $Combination      = '2*4' ;
my $SilentMode       = 0 ;
my $TeXProgram       = '' ;
my $TeXTranslation   = '' ;
my $TextWidth        = '0pt' ;
my $TopSpace         = '0pt' ;
my $TypesetFigures   = 0 ;
my $TypesetListing   = 0 ;
my $TypesetModule    = 0 ;
my $UseColor         = 0 ;
my $Verbose          = 0 ;
my $PdfCopy          = 0 ; 

&GetOptions
  ( "arrange"       => \$Arrange          ,
    "batch"         => \$EnterBatchMode   ,
    "color"         => \$UseColor         ,
    "centerpage"    => \$CenterPage       ,
    "convert=s"     => \$Convert          ,
    "environment=s" => \$Environment      ,
    "fast"          => \$FastMode         ,
    "final"         => \$FinalMode        ,
    "format=s"      => \$Format           ,
    "help"          => \$HelpAsked        ,
    "interface=s"   => \$ConTeXtInterface ,
    "language=s"    => \$MainLanguage     ,
    "bodyfont=s"    => \$MainBodyFont     ,
    "make"          => \$MakeFormats      ,
    "mode=s"        => \$Mode             ,
    "module"        => \$TypesetModule    ,
    "figures=s"     => \$TypesetFigures   ,
    "listing"       => \$TypesetListing   ,
    "mptex"         => \$DoMPTeX          ,
    "noarrange"     => \$NoArrange        ,
    "nomp"          => \$NoMPMode         ,
    "once"          => \$RunOnce          ,
    "output=s"      => \$OutputFormat     ,
    "pages=s"       => \$Pages            ,
    "paper=s"       => \$PaperFormat      ,
    "passon=s"      => \$PassOn           ,
    "pdf"           => \$ProducePdf       ,
    "pdfarrange"    => \$PdfArrange       ,
    "pdfselect"     => \$PdfSelect        ,
    "pdfcombine"    => \$PdfCombine       ,
    "pdfcopy"       => \$PdfCopy          ,
    "scale=s"       => \$PageScale        ,
    "selection=s"   => \$Selection        ,
    "combination=s" => \$Combination      ,
    "noduplex"      => \$NoDuplex         ,
    "paperoffset=s" => \$PaperOffset      ,
    "backspace=s"   => \$BackSpace        ,
    "topspace=s"    => \$TopSpace         ,
    "markings"      => \$Markings         ,
    "textwidth=s"   => \$TextWidth        ,
    "addempty=s"    => \$AddEmpty         ,

    "print=s"       => \$PrintFormat      ,
    "results=s"     => \$Result           ,
    "runs=s"        => \$NOfRuns          ,
    "silent"        => \$SilentMode       ,
    "tex=s"         => \$TeXProgram       ,
    "verbose"       => \$Verbose          ,
    "alone"         => \$Alone            ) ;

$SIG{INT} = "IGNORE" ;

if ($PdfArrange||$PdfSelect||$PdfCopy||$PdfCombine)     
  { $ProducePdf = 1 ; 
    $RunOnce = 1 }

if ($ProducePdf)     
  { $OutputFormat = "pdf" }

if ($RunOnce||$Pages||$TypesetFigures||$TypesetListing) 
  { $NOfRuns = 1 }

my $Program = " TeXExec 1.9 - ConTeXt / PRAGMA ADE 1997-2000" ;

print "\n$Program\n\n";

my $pathslash = '/' ; if ($0 =~ /\\/) { $pathslash = "\\" }
my $cur_path  = ".$pathslash" ;
my $own_path  = $0 ; $own_path =~ s/texexec\.(pl|bat|)//io ;

sub checked_path
  { my $path = shift  ;
    if ((defined($path))&&($path ne ''))
      { $path =~ s/[\/\\]/$pathslash/go ;
        $path =~ s/[\/\\]*$//go ;
        $path .= $pathslash }
    else
      { $path = '' }
    return $path }

sub checked_file
  { my $path = shift  ;
    if ((defined($path))&&($path ne ''))
      { $path =~ s/[\/\\]/$pathslash/go }
    else
      { $path = '' }
    return $path }

sub CheckPath
  { my ($Key, $Value) = @_ ;
    if ($Value =~ /\//)
      { $Value = checked_path($Value) ;
        unless (-d $Value)
          { print "                 error : $Key set to unknown path $Value\n" } } }

# set <variable> to <value>
# for <script> set <variable> to <value>
# except for <script> set <variable> to <value>

my $IniPath = '' ;

#D The kpsewhich program is not available in all tex distributions, so
#D we have to locate it before running it (as suggested by Thomas).

my @paths ;

if ($ENV{PATH} =~ /\;/)
  { @paths = split(/\;/,$ENV{PATH}) }
else
  { @paths = split(/\:/,$ENV{PATH}) }

my $kpsewhich = '' ;

if ($IniPath eq '')
  { foreach (@paths)
      { my $p = checked_path($_) . 'kpsewhich' ;
        if ((-e $p)||(-e $p . '.exe'))
          { $kpsewhich = $p ;
            $IniPath = `$kpsewhich --format="other text files" -progname=context texexec.ini` ;
            chomp($IniPath) ;
            last } }
    if ($Verbose)
      { if ($IniPath eq '')
          { print "     locating ini file : kpsewhich not found in path\n" }
        else
          { print "     locating ini file : found by kpsewhich\n" } } }

#D Now, when we didn't find the \type {kpsewhich}, we have
#D to revert to some other method. We could have said:
#D
#D\starttypen
#D unless ($IniPath)
#D   { $IniPath = `perl texpath.pl texexec.ini` }
#D \stoptypen
#D
#D But loading perl (for the second time) take some time. Instead of
#D providing a module, which can introduce problems with loading, I
#D decided to copy the code of \type {texpath} into this file.

use File::Find ;

my ($ReportPath, $ReportName, $ReportFile)    = (0,0,1) ;
my ($FileToLocate, $PathToStartOn)            = ('','') ;
my ($LocatedPath, $LocatedName, $LocatedFile) = ('','','') ;

sub DoLocateFile # we have to keep on pruning
  { if (lc $_ eq $FileToLocate)
      { $LocatedPath = $File::Find::dir ;
        $LocatedName = $_ ;
        $LocatedFile = $File::Find::name }
    if ($LocatedName) { $File::Find::prune = 1  } }

sub LocatedFile
  { $PathToStartOn = shift ;
    $FileToLocate = lc shift ;
    if ($FileToLocate eq '')
      { $FileToLocate = $PathToStartOn ;
        $PathToStartOn = $own_path }
    ($LocatedPath, $LocatedName, $LocatedFile) = ('','','') ;
    if ($FileToLocate ne '')
      { if (-e $cur_path . $FileToLocate)
          { $LocatedPath = $cur_path ;
            $LocatedName = $FileToLocate ;
            $LocatedFile = $cur_path . $FileToLocate }
        else
          { $_ = checked_path($PathToStartOn) ;
            if (-e $_ . $FileToLocate)
              { $LocatedPath = $_ ;
                $LocatedName = $FileToLocate ;
                $LocatedFile = $_ . $FileToLocate }
            else
              { $_ = checked_path($PathToStartOn) ;
                if (/(.*?[\/\\]texmf[\/\\]).*/i)
                  { my $SavedRoot = $1 ;
                    File::Find::find(\&DoLocateFile, checked_path($1 . 'context/')) ;
                    unless ($LocatedFile)
                      { File::Find::find(\&DoLocateFile, $SavedRoot) } }
                else
                  { $_ = checked_path($_) ;
                    File::Find::find(\&DoLocateFile, $_) } } } }
    return ($LocatedPath, $LocatedName, $LocatedFile) }

#D So now we can say:

unless ($IniPath)
  { ($LocatedPath, $LocatedName, $IniPath) = LocatedFile($own_path,'texexec.ini') ;
    if ($Verbose)
      { if ($IniPath eq '')
          { print "     locating ini file : not found by searching\n" }
        else
          { print "     locating ini file : found by searching\n" } } }

#D The last resorts:

unless ($IniPath)
  { if ($ENV{TEXEXEC_INI_FILE})
      { $IniPath = checked_path($ENV{TEXEXEC_INI_FILE}) . 'texexec.ini' ;
        unless (-e $IniPath) { $IniPath = '' } }
    if ($Verbose)
      { if ($IniPath eq '')
          { print "     locating ini file : no environment variable set\n" }
        else
          { print "     locating ini file : found by environment variable\n" } } }

unless ($IniPath)
  { $IniPath = $own_path . 'texexec.ini' ;
    unless (-e $IniPath) { $IniPath = '' }
    if ($Verbose)
      { if ($IniPath eq '')
          { print "     locating ini file : not found in own path\n" }
        else
          { print "     locating ini file : found in own path\n" } } }

#D Now we're ready for loading the initialization file! We
#D also define some non strict variables. Using \type {$Done}
#D permits assignments.

my %Done ;

unless ($IniPath)
  { $IniPath = 'texexec.ini' }

if (open(INI, $IniPath))
  { if ($Verbose)
      { print "               reading : $IniPath\n" }
    while (<INI>)
      { if (!/^[a-zA-Z\s]/oi)
          { }
        elsif (/except for\s+(\S+)\s+set\s+(\S+)\s*to\s*(.*)\s*/goi)
          { my $one = $1 ; my $two= $2 ; my $three = $3 ;
            if ($one ne $Done{"TeXShell"})
              { $three =~ s/^[\'\"]// ; $three =~ s/[\'\"]$// ; $three =~ s/\s*$// ;
                if ($Verbose)
                  { print "               setting : '$two' to '$three' except for '$one'\n" }
                $Done{"$two"} = $three ;
                CheckPath ($two, $three) } }
        elsif (/for\s+(\S+)\s+set\s+(\S+)\s*to\s*(.*)\s*/goi)
          { my $one = $1 ; my $two= $2 ; my $three = $3 ; $three =~ s/\s*$// ;
            if ($one eq $Done{"TeXShell"})
              { $three =~ s/^[\'\"]// ; $three =~ s/[\'\"]$// ;
                if ($Verbose)
                  { print "               setting : '$two' to '$three' for '$one'\n" }
                $Done{"$two"} = $three ;
                CheckPath ($two, $three) } }
        elsif (/set\s+(\S+)\s*to\s*(.*)\s*/goi)
          { my $one = $1 ; my $two= $2 ;
            unless (defined($Done{"$one"}))
              { $two =~ s/^[\'\"]// ; $two =~ s/[\'\"]$// ; $two =~ s/\s*$// ;
                if ($Verbose)
                  { print "               setting : '$one' to '$two' for 'all'\n" }
                $Done{"$one"} = $two ;
                CheckPath ($one, $two) } } }
    close (INI) ;
    if ($Verbose)
      { print "\n" } }
elsif ($Verbose)
  { print "               warning : $IniPath not found, did you read 'texexec.rme'?\n" ;
    exit 1 }
else
  { print "               warning : $IniPath not found, try 'texexec --verbose'\n" ;
    exit 1 }

sub IniValue
  { my ($Key,$Default) = @_ ;
    if (defined($Done{$Key})) { $Default = $Done{$Key} }
    if ($Verbose)
      { print "          used setting : $Key = $Default\n" }
    return $Default }

my $TeXShell          = IniValue('TeXShell'          , ''        ) ;
my $SetupPath         = IniValue('SetupPath'         , ''        ) ;
my $UserInterface     = IniValue('UserInterface'     , 'en'      ) ;
my $UsedInterfaces    = IniValue('UsedInterfaces'    , 'en'      ) ;
my $MpExecutable      = IniValue('MpExecutable'      , 'mpost'   ) ;
my $MpToTeXExecutable = IniValue('MpToTeXExecutable' , 'mpto'    ) ;
my $DviToMpExecutable = IniValue('DviToMpExecutable' , 'dvitomp' ) ;
my $TeXProgramPath    = IniValue('TeXProgramPath'    , ''        ) ;
my $TeXFormatPath     = IniValue('TeXFormatPath'     , ''        ) ;
my $ConTeXtPath       = IniValue('ConTeXtPath'       , ''        ) ;
my $TeXScriptsPath    = IniValue('TeXScriptsPath'    , ''        ) ;
my $TeXExecutable     = IniValue('TeXExecutable'     , 'tex'     ) ;
my $TeXVirginFlag     = IniValue('TeXVirginFlag'     , '-ini'    ) ;
my $TeXPassString     = IniValue('TeXPassString'     , ''        ) ;
my $TeXFormatFlag     = IniValue('TeXFormatFlag'     , ''        ) ;

my $FmtLanguage       = IniValue('FmtLanguage'       , ''        ) ; 
my $FmtBodyFont       = IniValue('FmtBodyFont'       , ''        ) ; 
my $TcXPath           = IniValue('TcXPath'           , ''        ) ; 

if (($FmtLanguage)&&($MainLanguage eq 'standard')) 
  { $MainLanguage = $FmtLanguage } 
if (($FmtBodyFont)&&($MainBodyFont eq 'standard')) 
  { $MainBodyFont = $FmtBodyFont } 

if ($Verbose) { print "\n" }

unless ($TeXFormatFlag)
  { if ($dosish) { $TeXFormatFlag = "&" } else { $TeXFormatFlag = "\\&" } }

if ($TeXProgram)
  { $TeXExecutable = $TeXProgram }

my $fmtutil = '' ;

if ($Alone)
  { if ($Verbose)
      { print "     generating format : not using fmtutil\n" } }
elsif ($TeXShell =~ /tetex|fptex/i)
  { foreach (@paths)
      { my $p = checked_path($_) . 'fmtutil' ;
        if (-e $p)
          { $fmtutil = $p ; last }
        elsif (-e $p . '.exe')
          { $fmtutil = $p . '.exe' ; last } }
    if ($Verbose)
      { if ($fmtutil eq '')
          { print "      locating fmtutil : not found in path\n" }
        else
          { print "      locating fmtutil : found\n" } } }

unless ($TeXScriptsPath)
  { $TeXScriptsPath = $own_path }

unless ($ConTeXtPath)
  { $ConTeXtPath = $TeXScriptsPath }

if ($ENV{"HOME"})
  { if ($SetupPath) { $SetupPath .= "," }
    $SetupPath .= $ENV{"HOME"} }

if ($TeXFormatPath)  { $TeXFormatPath  =~ s/[\/\\]$// ; $TeXFormatPath  .= '/' }
if ($ConTeXtPath)    { $ConTeXtPath    =~ s/[\/\\]$// ; $ConTeXtPath    .= '/' }
if ($SetupPath)      { $SetupPath      =~ s/[\/\\]$// ; $SetupPath      .= '/' }
if ($TeXScriptsPath) { $TeXScriptsPath =~ s/[\/\\]$// ; $TeXScriptsPath .= '/' }

my %OutputFormats ;

$OutputFormats{pdf}      = "pdftex" ;
$OutputFormats{pdftex}   = "pdftex" ;
$OutputFormats{dvips}    = "dvips" ;
$OutputFormats{dvipsone} = "dvipsone" ;
$OutputFormats{acrobat}  = "acrobat" ;
$OutputFormats{dviwindo} = "dviwindo" ;
$OutputFormats{dviview}  = "dviview" ;

my @ConTeXtFormats = ("nl", "en", "de", "cz", "uk") ;

my %ConTeXtInterfaces ;

$ConTeXtInterfaces{nl} = "nl" ; $ConTeXtInterfaces{dutch}        = "nl" ;
$ConTeXtInterfaces{en} = "en" ; $ConTeXtInterfaces{english}      = "en" ;
$ConTeXtInterfaces{de} = "de" ; $ConTeXtInterfaces{german}       = "de" ;
$ConTeXtInterfaces{cz} = "cz" ; $ConTeXtInterfaces{czech}        = "cz" ;
$ConTeXtInterfaces{uk} = "uk" ; $ConTeXtInterfaces{brittish}     = "uk" ;
$ConTeXtInterfaces{xx} = "xx" ; $ConTeXtInterfaces{experimental} = "xx" ;

my %Help ;

$Help{ARRANGE}     = "             --arrange   process and arrange\n" ;
$Help{BATCH}       = "               --batch   run in batch mode (don't pause)\n" ;
$Help{CENTERPAGE}  = "          --centerpage   center the page on the paper\n" ;
$Help{COLOR}       = "               --color   enable color (when not yet enabled)\n" ;
$Help{CONVERT}     = "             --convert   converts file first\n" ;
$Help{convert}     =
$Help{CONVERT}     . "                           =xml  : XML => TeX\n"
                   . "                           =sgml : SGML => TeX\n" ;
$Help{ENVIRONMENT} = "         --environment   load some environments first\n" ;
$Help{environment} =
$Help{ENVIRONMENT} . "                           =name : list of environments\n" ;
$Help{FAST}        = "                --fast   skip as much as possible\n" ;
$Help{FIGURES}     = "             --figures   typeset figure directory\n" ;
$Help{figures}     =
$Help{FIGURES}     . "                           =a : room for corrections\n"
                   . "                           =b : just graphics\n"
                   . "                           =c : one (cropped) per page\n"
                   . "         --paperoffset   room left at paper border\n" ;
$Help{FINAL}       = "               --final   add a final run without skipping\n" ;
$Help{FORMAT}      = "              --format   fmt file\n" ;
$Help{format}      =
$Help{FORMAT}      . "                           =name : format file (memory dump) \n" ;
$Help{INTERFACE}   = "           --interface   user interface\n" ;
$Help{interface}   =
$Help{INTERFACE}   . "                           =en : English\n"
                   . "                           =nl : Dutch\n"
                   . "                           =de : German\n"
                   . "                           =cz : Czech\n"
                   . "                           =uk : Brittish\n" ;
$Help{LANGUAGE}    = "            --language   main hyphenation language \n" ;
$Help{language}    =
$Help{LANGUAGE}    . "                           =xx : standard abbreviation \n" ;
$Help{LISTING}     = "             --listing   produce a verbatim listing\n" ;
$Help{listing}     =
$Help{LISTING}     . "           --backspace   inner margin of the page\n" .
                     "            --topspace   top/bottom margin of the page\n" ;
$Help{MAKE}        = "                --make   build format files \n" ;
$Help{make}        =
$Help{MAKE}        . "            --language   patterns to include\n" .
                     "            --bodyfont   bodyfont to preload\n" ;
$Help{MODE}        = "                --mode   running mode \n" ;
$Help{mode}        =
$Help{MODE}        . "                           =list : modes to set\n" ;
$Help{MODULE}      = "              --module   typeset tex/pl/mp module\n" ;
$Help{MPTEX}       = "               --mptex   run an MetaPost btex-etex cycle\n" ;
$Help{NOARRANGE}   = "           --noarrange   process but ignore arrange\n" ;
$Help{NOMP}        = "                --nomp   don't run MetaPost\n" ;
$Help{ONCE}        = "                --once   run TeX only once (no TeXUtil either)\n" ;
$Help{OUTPUT}      = "              --output   specials to use\n" ;
$Help{output}      =
$Help{OUTPUT}      . "                           =pdftex\n"
                   . "                           =dvips\n"
                   . "                           =dvipsone\n"
                   . "                           =dviwindo\n"
                   . "                           =dviview\n" ;
$Help{PASSON}      = '              --passon   switches to pass to TeX ("--src" for MikTeX)' . "\n" ;
$Help{PAGES}       = "               --pages   pages to output\n" ;
$Help{pages}       =
$Help{PAGES}       . "                           =odd   : odd pages\n" .
                     "                           =even  : even pages\n" .
                     "                           =x,y:z : pages x and y to z\n" ;
$Help{PAPER}       = "               --paper   paper input and output format\n" ;
$Help{paper}       =
$Help{PAPER}       . "                           =a4a3 : A4 printed on A3\n" .
                     "                           =a5a4 : A5 printed on A4\n" ;
$Help{PDF}         = "                 --pdf   produce PDF directly using pdf(e)tex\n" ;
$Help{PDFARRANGE}  = "          --pdfarrange   arrange pdf pages\n" ;
$Help{pdfarrange}  =
$Help{PDFARRANGE}  . "         --paperoffset   room left at paper border\n" .
                     "               --paper   paper format\n" .
                     "            --noduplex   single sided\n" .
                     "           --backspace   inner margin of the page\n" .
                     "            --topspace   top/bottom margin of the page\n" .
                     "            --markings   add cutmarks\n" .
                     "            --addempty   add empty page after\n" .
                     "           --textwidth   width of the original (one sided) text\n" ;
$Help{PDFCOPY}     = "             --pdfcopy   scale pages down/up\n" ;
$Help{pdfcopy}     = 
$Help{PDFCOMBINE}  = "          --pdfcombine   combine pages to one page\n" ; 
$Help{pdfcombine}  =   
$Help{PDFCOMBINE}  . "         --paperformat   paper format\n" .
                     "         --combination   n*m pages per page\n" .
                     "         --paperoffset   room left at paper border\n" ;
$Help{PDFCOPY}     . "               --scale   new page scale\n" ;  
$Help{PDFSELECT}   = "           --pdfselect   select pdf pages\n" ;
$Help{pdfselect}   =
$Help{PDFSELECT}   = "           --selection   pages to select\n" .
                     "                           =odd   : odd pages\n" .
                     "                           =even  : even pages\n" .
                     "                           =x,y:z : pages x and y to z\n" ;
                     "         --paperoffset   room left at paper border\n" .
                     "         --paperformat   paper format\n" .
                     "           --backspace   inner margin of the page\n" .
                     "            --topspace   top/bottom margin of the page\n" .
                     "            --markings   add cutmarks\n" .
                     "            --addempty   add empty page after\n" .
                     "           --textwidth   width of the original (one sided) text\n" ;
$Help{PRINT}       = "               --print   page imposition scheme\n" ;
$Help{print}       =
$Help{PRINT}       . "                             =up : 2 pages per sheet doublesided           \n" .
                     "                           =down : 2 rotated pages per sheet doublesided \n" ;
$Help{RESULT}      = "              --result   resulting file \n" ;
$Help{result}      =
$Help{RESULT}      . "                           =name : filename \n" ;
$Help{RUNS}        = "                --runs   maximum number of TeX runs \n" ;
$Help{runs}        =
$Help{RUNS}        . "                           =n : number of runs\n" ;
$Help{SILENT}      = "              --silent   minimize (status) messages\n" ;
$Help{TEX}         = "                 --tex   TeX binary \n" ;
$Help{tex}         =
$Help{TEX}         . "                           =name : binary of executable \n" ;
$Help{VERBOSE}     = "             --verbose   shows some additional info \n" ;
$Help{HELP}        = "                --help   show this or more, e.g. '--help interface'\n" ;

if ($HelpAsked)
  { if (@ARGV)
      { foreach (@ARGV) { s/\-//go ; print "$Help{$_}\n" } }
    else
      { print $Help{ARRANGE}     ;
        print $Help{BATCH}       ;
        print $Help{CENTERPAGE}  ;
        print $Help{COLOR}       ;
        print $Help{CONVERT}     ;
        print $Help{ENVIRONMENT} ;
        print $Help{FAST}        ;
        print $Help{FIGURES}     ;
        print $Help{FINAL}       ;
        print $Help{FORMAT}      ;
        print $Help{INTERFACE}   ;
        print $Help{LISTING}     ;
        print $Help{LANGUAGE}    ;
        print $Help{MAKE}        ;
        print $Help{MODE}        ;
        print $Help{MODULE}      ;
        print $Help{MPTEX}       ;
        print $Help{NOARRANGE}   ;
        print $Help{NOMP}        ;
        print $Help{ONCE}        ;
        print $Help{OUTPUT}      ;
        print $Help{PAGES}       ;
        print $Help{PAPER}       ;
        print $Help{PASSON}      ;
        print $Help{PDFARRANGE}  ;
        print $Help{PDFCOMBINE}  ;
        print $Help{PDFCOPY}     ;
        print $Help{PDFSELECT}   ;
        print $Help{PDF}         ;
        print $Help{PRINT}       ;
        print $Help{RESULT}      ;
        print $Help{RUNS}        ;
        print $Help{SILENT}      ;
        print $Help{TEX}         ;
        print $Help{VERBOSE}     ;
        print "\n"               ;
        print $Help{HELP}        ;
        print "\n"               }
    exit 0 }

my $FinalRunNeeded = 0 ;

sub RunPerlScript
  { my ($ScriptName, $Options) = @_ ;
    if ($dosish)
      { system ("perl $TeXScriptsPath$ScriptName.pl $Options") }
    else
      { system ("$ScriptName $Options") } }

sub ConvertXMLFile
  { my $FileName = shift ; RunPerlScript($SGMLtoTeX, "$FileName.xml") }

sub ConvertSGMLFile
  { my $FileName = shift ; RunPerlScript($SGMLtoTeX, "$FileName.sgm") }

my $FullFormat = '' ;

sub CheckOutputFormat
  { my $Ok = 1 ;
    if ($OutputFormat ne 'standard')
      { my @OutputFormat = split(/,/,$OutputFormat) ;
        foreach my $F (@OutputFormat)
          { if (defined($OutputFormats{lc $F}))
              { my $OF = $OutputFormats{lc $F} ;
                next if (",$FullFormat," =~ /\,$OF\,/) ;
                if ($FullFormat) { $FullFormat .= "," }
                $FullFormat .= "$OutputFormats{lc $F}" }
            else
              { $Ok = 0 } }
        if (!$Ok)
          { print $Help{output} }
        elsif ($FullFormat)
          { print OPT "\\setupoutput[$FullFormat]\n" } }
    unless ($FullFormat)
      { $FullFormat = $OutputFormat } } # 'standard' to terminal

sub MakeOptionFile
  { my ($FinalRun, $FastDisabled, $JobName) = @_ ;
    open (OPT, ">$JobName.top") ;
    print OPT "\\unprotect\n" ;
    $MainLanguage = lc $MainLanguage ;
    unless ($MainLanguage eq "standard")
      { print OPT "\\setuplanguage[$MainLanguage]\n" }
#    my $Ok = 1 ;
#    if ($OutputFormat ne 'standard')
#      { my @OutputFormat = split(/,/,$OutputFormat) ;
#        foreach my $F (@OutputFormat)
#          { if (defined($OutputFormats{lc $F}))
#              { my $OF = $OutputFormats{lc $F} ;
#                next if (",$FullFormat," =~ /\,$OF\,/) ;
#                if ($FullFormat) { $FullFormat .= "," }
#                $FullFormat .= "$OutputFormats{lc $F}" }
#            else
#              { $Ok = 0 } }
#        if (!$Ok)
#          { print $Help{output} }
#        elsif ($FullFormat)
#          { print OPT "\\setupoutput[$FullFormat]\n" } }
#    unless ($FullFormat)
#      { $FullFormat = $OutputFormat } # 'standard' to terminal
#
    if ($FullFormat ne 'standard')
      { print OPT "\\setupoutput[$FullFormat]\n" }
#
    if ($EnterBatchMode)
      { print OPT "\\batchmode\n" }
    if ($UseColor)
      { print OPT "\\setupcolors[\\c!status=\\v!start]\n" }
    if ($NoMPMode)
      { print OPT "\\runMPgraphicsfalse\n" }
    if (($FastMode)&&(!$FastDisabled))
      { print OPT "\\fastmode\n" }
    if ($SilentMode)
      { print OPT "\\silentmode\n" }
    if ($SetupPath)
      { print OPT "\\setupsystem[\\c!gebied=\{$SetupPath\}]\n" }
    $_ = $PaperFormat ;
    unless (($PdfArrange)||($PdfSelect)||($PdfCombine)||($PdfCopy))
      { if (/.4.3/goi)
         { print OPT "\\stelpapierformaatin[A4][A3]\n" }
       elsif (/.5.4/goi)
         { print OPT "\\stelpapierformaatin[A5][A4]\n" }
       elsif (!/standard/)
         { print $Help{paper} } }
    if ($CenterPage)
      { print OPT "\\stellayoutin[\\c!plaats=\\v!midden,\\c!markering=\\v!aan]\n" }
    if ($NoArrange)
      { print OPT "\\stelarrangerenin[\\v!blokkeer]\n" }
    elsif ($Arrange)
      { $FinalRunNeeded = 1 ;
        unless ($FinalRun)
          { print OPT "\\stelarrangerenin[\\v!blokkeer]\n" } }
    else
      { $_ = $PrintFormat ;
        if (/.*up/goi)
          { $FinalRunNeeded = 1 ;
            if ($FinalRun)
              { print OPT "\\stelarrangerenin[2UP,\\v!geroteerd,\\v!dubbelzijdig]\n" } }
        elsif (/.*down/goi)
          { $FinalRunNeeded = 1 ;
            if ($FinalRun)
              { print OPT "\\stelarrangerenin[2DOWN,\\v!geroteerd,\\v!dubbelzijdig]\n" } }
        elsif (!/standard/goi) { print $Help{"print"} } }
    if ($Mode)
      { print OPT "\\enablemode[$Mode]\n" }
    if ($Pages)
      { if (lc $Pages eq "odd")
          { print OPT "\\chardef\\whichpagetoshipout=1\n" }
        elsif (lc $Pages eq "even")
          { print OPT "\\chardef\\whichpagetoshipout=2\n" }
        else
          { my @Pages = split (/\,/,$Pages) ;
            $Pages = '' ;
            foreach my $page (@Pages)
              { if ($page =~ /\:/)
                  { my ($from,$to) = split (/\:/,$page) ;
                    foreach (my $i=$from;$i<=$to;$i++)
                     { $Pages .= $i . ',' } }
                else
                  { $Pages .= $page . ',' } }
            chop $Pages ;
            print OPT "\\def\\pagestoshipout\{$Pages\}\n" } }
    print OPT "\\protect\n" ;
    if ($Environment)
      { foreach my $E ($Environment) { print OPT "\\omgeving $E\n" } }
    close (OPT) ;
    if (open(TMP,">cont-opt.bak")&&open(TMP,"<cont-opt.tex"))
      { while (<OPT>) { print TMP $_ } } }

my $UserFileOk = 0 ;
my @MainLanguages ;
my $AllLanguages = '' ; 

sub MakeUserFile
  { $UserFileOk = 0 ;
    return if (($MainLanguage eq 'standard')&&
               ($MainBodyFont eq 'standard')) ;
    print "   preparing user file : cont-fmt.tex\n" ;
    open (USR, ">cont-fmt.tex") ;
    print USR "\\unprotect\n" ;
    $AllLanguages = $MainLanguage ;  
    if ($MainLanguage ne 'standard')
      { @MainLanguages = split (/\,/,$MainLanguage) ;
        foreach (@MainLanguages)
          { print USR "\\installlanguage[\\s!$_][\\c!status=\\v!start]\n" }
        $MainLanguage = $MainLanguages[0] ;
        print USR "\\setupcurrentlanguage[\\s!$MainLanguage]\n" }
    if ($MainBodyFont ne 'standard')
      { print USR "\\definefilesynonym[font-cmr][font-$MainBodyFont]\n" }
    print USR "\\protect\n" ;
    print USR "\\endinput\n" ;
    close (USR) ;
    ReportUserFile () ;
    print "\n" ;
    $UserFileOk = 1 }

sub RestoreUserFile
  { unlink "cont-fmt.log" ;
    rename "cont-fmt.tex", "cont-fmt.log" ;
    ReportUserFile () }  

sub ReportUserFile
  { return unless ($UserFileOk) ; 
    print "\n" ; 
    if ($MainLanguage ne 'standard')
      { print "   additional patterns : $AllLanguages\n" ;
        print "      default language : $MainLanguage\n" }
    if ($MainBodyFont ne 'standard')
      { print "      default bodyfont : $MainBodyFont\n" } }

sub CompareFiles
 { my ($File1, $File2) = @_ ;
   my $Str1 = my $Str2 = '' ;
   if ((-s $File1 eq -s $File2)&&(open(TUO1,$File1))&&(open(TUO2,$File2)))
     { while(1)
        { $Str1 = <TUO1> ;
          $Str2 = <TUO2> ;
          if ($Str1 eq $Str2)
            { unless ($Str1) { close(TUO1) ; close(TUO2) ; return 1 } }
          else
            { close(TUO1) ; close(TUO2) ; return 0 } } }
   else
     { return 0 } }

my $ConTeXtVersion = "unknown" ;
my $ConTeXtModes   = '' ;

sub ScanPreamble
  { my ($FileName) = @_ ;
    open (TEX, $FileName) ;
    while (<TEX>)
     { chomp ;
       if (/^\%.*/)
         { if (/tex=([a-z]*)/goi)                  { $TeXExecutable    = $1 }
           if (/translat.*?=([\:\/0-9\-a-z]*)/goi) { $TeXTranslation   = $1 }
           if (/program=([a-z]*)/goi)              { $TeXExecutable    = $1 }
           if (/modes=([a-z\,]*)/goi)              { $ConTeXtModes     = $1 }
           if (/output=([a-z\,]*)/goi)             { $OutputFormat     = $1 }
           if ($ConTeXtInterface eq "unknown")
             { if (/format=([a-z]*)/goi)           { $ConTeXtInterface = $ConTeXtInterfaces{$1}  }
               if (/interface=([a-z]*)/goi)        { $ConTeXtInterface = $ConTeXtInterfaces{$1} } }
           if (/version=([a-z]*)/goi)              { $ConTeXtVersion   = $1 } }
       else
         { last } }
    close(TEX) }

sub ScanContent
  { my ($ConTeXtInput) = @_ ;
    open (TEX, $ConTeXtInput) ;
    while (<TEX>)
      { if    (/\\(starttekst|stoptekst|startonderdeel)/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/\\(stelle|verwende|umgebung|benutze)/)
          { $ConTeXtInterface = "de" ; last }
        elsif (/\\(stel|gebruik|omgeving)/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/\\(use|setup|environment)/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/(hoogte|breedte|letter)=/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/(height|width|style)=/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/(hoehe|breite|schrift)=/)
          { $ConTeXtInterface = "de" ; last }
        elsif (/externfiguur/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/externalfigure/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/externeabbildung/)
          { $ConTeXtInterface = "de" ; last } }
    close (TEX) }

if ($ConTeXtInterfaces{$ConTeXtInterface})
  { $ConTeXtInterface = $ConTeXtInterfaces{$ConTeXtInterface} }

my $Problems = 0 ;

sub RunTeX
  { my $JobName = shift ;
    my $StartTime = time ;
    my $cmd ;
    my $TeXProgNameFlag ;
    if (!$dosish)
      { $TeXProgramPath = '' ;
        $TeXFormatPath = '' ;
        if (!$TeXProgNameFlag&&($Format=~/^cont/))
          { $TeXProgNameFlag = "-progname=context" } }
    $cmd  = "$TeXProgramPath$TeXExecutable $TeXProgNameFlag " .
            "$TeXPassString $PassOn " ;
    if ($TeXTranslation ne '')
      { $cmd .= "-translate-file=$TeXTranslation " }
    $cmd .= "$TeXFormatFlag$TeXFormatPath$Format $JobName" ;
    if ($Verbose) { print "\n$cmd\n\n" }
    $Problems = system ( "$cmd" ) ;
    my $StopTime = time - $StartTime ;
    print "\n              run time : $StopTime seconds\n" ;
    return $Problems }

sub PushResult
  { if ($Result)
      { print "            outputfile : $Result\n" ;
        unlink ("texexec.tuo") ; rename ("$_[0].tuo", "texexec.tuo") ;
        unlink ("texexec.log") ; rename ("$_[0].log", "texexec.log") ;
        unlink ("texexec.dvi") ; rename ("$_[0].dvi", "texexec.dvi") ;
        unlink ("texexec.pdf") ; rename ("$_[0].pdf", "texexec.pdf") ;
        if (-f "$Result.tuo")
          { unlink ("$_[0].tuo") ;
            rename ("$Result.tuo", "$_[0].tuo") } } }

sub PopResult
  { if ($Result)
      { unlink ("$Result.tuo") ; rename ("$_[0].tuo", "$Result.tuo") ;
        unlink ("$Result.log") ; rename ("$_[0].log", "$Result.log") ;
        unlink ("$Result.dvi") ; rename ("$_[0].dvi", "$Result.dvi") ;
        unlink ("$Result.pdf") ; rename ("$_[0].pdf", "$Result.pdf") ;
        rename ("texexec.tuo", "$_[0].tuo") ;
        rename ("texexec.log", "$_[0].log") ;
        rename ("texexec.dvi", "$_[0].dvi") ;
        rename ("texexec.pdf", "$_[0].pdf") } }

sub RunConTeXtFile
  { my ($JobName) = @_ ;
    $JobName =~ s/\\/\//goi ;
    if (-e "$JobName.tex")
      { ScanPreamble ("$JobName.tex") ;
        if ($ConTeXtInterface eq "unknown")
          { ScanContent ("$JobName.tex") }
        if ($ConTeXtInterface eq "unknown")
          { $ConTeXtInterface = $UserInterface }
        if (lc $Convert eq "xml")
          { print "             xml input : $JobName.xml\n" ;
            ConvertXMLFile ($JobName) }
        elsif (lc $Convert eq "sgml")
          { print "            sgml input : $JobName.sgm\n" ;
            ConvertSGMLFile ($JobName) }
        CheckOutputFormat ;
        my $StopRunning = 0 ;
        if ($Format eq '')
          { $Format = "cont-$ConTeXtInterface" }
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        print "             inputfile : $JobName\n" ;
        print "                output : $FullFormat\n" ;
        print "             interface : $ConTeXtInterface\n" ;
        if ($TeXTranslation ne '')
          { print "           translation : $TeXTranslation\n" }
        my $Options = '' ;
        if ($FastMode)       { $Options .= " fast" }
        if ($FinalMode)      { $Options .= " final" }
        if ($Verbose)        { $Options .= " verbose" }
        if ($TypesetListing) { $Options .= " listing" }
        if ($TypesetModule)  { $Options .= " module" }
        if ($TypesetFigures) { $Options .= " figures" }
        if ($MakeFormats)    { $Options .= " make" }
        if ($RunOnce)        { $Options .= " once" }
        if ($UseColor)       { $Options .= " color" }
        if ($EnterBatchMode) { $Options .= " batch" }
        if ($NoMPMode)       { $Options .= " nomp" }
        if ($CenterPage)     { $Options .= " center" }
        if ($Arrange)        { $Options .= " arrange" }
        if ($NoArrange)      { $Options .= " no-arrange" }
        if ($Options)
          { print "               options :$Options\n" }
        if ($ConTeXtModes)
          { print "        possible modes : $ConTeXtModes\n" }
        if ($Mode)
          { print "          current mode : $Mode\n" }
        else
          { print "          current mode : all\n" }
        if ($Environment)
          { print "          environments : $Environment\n" }
        PushResult($JobName) ;
        $Problems = 0 ;
        my $TeXRuns = 0 ;
        if (($PdfArrange)||($PdfSelect)||($RunOnce))
          { MakeOptionFile (1, 1, $JobName) ;
            print "\n" ;
            $Problems = RunTeX($JobName) ;
            PopResult($JobName) }
        else
          { while (!$StopRunning&&($TeXRuns<$NOfRuns)&&(!$Problems))
             { MakeOptionFile (0, 0, $JobName) ;
               ++$TeXRuns ;
               print "               TeX run : $TeXRuns\n\n" ;
               $Problems = RunTeX($JobName) ;
               if ((!$Problems)&&($NOfRuns>1))
                 { if (!$NoMPMode)
                     { my $MPJobName = '' ;
                       if (-e "$JobName-mpgraph.mp")
                         { $MPJobName = "$JobName-mpgraph.mp" }
                       elsif (-e "mpgraph.mp")
                         { $MPJobName = "mpgraph.mp" }
                       if ($MPJobName ne "")  
                         { if (open(MP, "$MPJobName"))
                            { $_ = <MP> ;
                              my $RuntimeGraphic = /runtime generated graphic/i ;
                              close(MP) ;
                              if (!$RuntimeGraphic)
                                { if ($MpExecutable ne '')
                                    { print "   generating graphics : metaposting MPJobName\n" ;
                                      $Problems = system ("$MpExecutable $MPJobName") }
                                  else
                                    { print "   generating graphics : metapost cannot be run\n" } } } } }
                   unless ($Problems)
                     { unlink "$JobName.tup" ;
                       rename "$JobName.tuo", "$JobName.tup" ;
                       print "  sorting and checking : running texutil\n" ;
my $TcXSwitch = '' ; 
if ($TcXPath ne '') { $TcXSwitch = "--tcxpath=$TcXPath" }  
                       RunPerlScript
                         ($TeXUtil, "--ref --ij --high $TcXPath $JobName" );
                       if (-e "$JobName.tuo")
                         { $StopRunning =
                           CompareFiles("$JobName.tup", "$JobName.tuo") }
                       else
                         { $StopRunning = 1 } # otherwise potential loop
                       if (!$StopRunning)
                         { print "\n utility file analysis : another run needed\n" } } } }
           if ((!$Problems)&&(($FinalMode||$FinalRunNeeded))&&($NOfRuns>1))
             { MakeOptionFile (1, $FinalMode, $JobName) ;
               print "         final TeX run : $TeXRuns\n\n" ;
               $Problems = RunTeX($JobName) }
           unlink "$JobName.tup" ; # previous tuo file
           unlink "$JobName.top" ; # runtime option file
           PopResult($JobName) } } }

sub RunSomeTeXFile
  { my ($JobName) = @_ ;
    if (-e "$JobName.tex")
      { PushResult($JobName) ;
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        print "             inputfile : $JobName\n" ;
        $Problems = RunTeX($JobName) ;
        PopResult($JobName) } }

my $ModuleFile  = "texexec" ;
my $ListingFile = "texexec" ;
my $FiguresFile = "texexec" ;
my $ArrangeFile = "texexec" ;
my $SelectFile  = "texexec" ;
my $CopyFile    = "texexec" ;
my $CombineFile = "texexec" ;

sub RunModule
  { my ($FileName) = @_ ;
    if ((-e "$FileName.tex")||(-e "$FileName.pl")||(-e "$FileName.mp")||
                              (-e "$FileName.pm"))
      { RunPerlScript ($TeXUtil,
          "--documents $FileName.pl $FileName.pm $FileName.mp $FileName.tex" ) ;
        print "                module : $FileName\n\n" ;
        open (MOD, ">$ModuleFile.tex") ;
        print MOD "% format=dutch        \n" ;
        print MOD "\\starttekst          \n" ;
        print MOD "\\input modu-abr      \n" ;
        print MOD "\\input modu-arg      \n" ;
        print MOD "\\input modu-env      \n" ;
        print MOD "\\input modu-mod      \n" ;
        print MOD "\\input modu-pap      \n" ;
        print MOD "\\def\\ModuleNumber{1}\n" ;
        print MOD "\\input $FileName.ted \n" ;
        print MOD "\\stoptekst           \n" ;
        close (MOD) ;
        $ConTeXtInterface = "nl" ;
        RunConTeXtFile($ModuleFile) ;
        if ($FileName ne $ModuleFile)
          { foreach my $FileSuffix ("dvi", "pdf", "tui", "tuo", "log")
             { unlink ("$FileName.$FileSuffix") ;
               rename ("$ModuleFile.$FileSuffix", "$FileName.$FileSuffix") } }
        unlink ("$ModuleFile.tex") } }

sub RunFigures
  { my @Files = @_ ;
    $TypesetFigures = lc $TypesetFigures ;
    return unless ($TypesetFigures =~ /[abc]/o) ;
    unlink "$FiguresFile.pdf" ;
    if (@Files) { RunPerlScript ($TeXUtil, "--figures @Files" ) }
    open (FIG, ">$FiguresFile.tex") ;
    print FIG "% format=english\n" ;
    print FIG "\\starttext\n" ;
    print FIG "\\setuplayout\n" ;
    print FIG "  [topspace=1.5cm,backspace=1.5cm,\n" ;
    print FIG "   header=1.5cm,footer=0pt,\n" ;
    print FIG "   width=middle,height=middle]\n" ;
    print FIG "\\showexternalfigures[alternative=$TypesetFigures,offset=$PaperOffset]\n" ;
    print FIG "\\stoptext\n" ;
    close(FIG) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($FiguresFile) }

sub RunListing
  { my $FileName = shift ;
    return unless -f $FileName ;
    print "            input file : $FileName\n" ;
    if ($BackSpace eq "0pt")
      { $BackSpace="1.5cm" }
    else
      { print "             backspace : $BackSpace\n" }
    if ($TopSpace eq "0pt")
      { $TopSpace="1.5cm" }
    else
      { print "              topspace : $TopSpace\n" }
    open (LIS, ">$ListingFile.tex") ;
    print LIS "% format=english\n" ;
    print LIS "\\starttext\n" ;
    print LIS "\\setupbodyfont[11pt,tt]\n" ;
    print LIS "\\setuplayout\n" ;
    print LIS "  [topspace=$TopSpace,backspace=$BackSpace,\n" ;
    print LIS "   header=0cm,footer=1.5cm,\n" ;
    print LIS "   width=middle,height=middle]\n" ;
    print LIS "\\setupfootertexts[$FileName][pagenumber]\n" ;
    print LIS "\\typefile\{$FileName\}\n" ;
    print LIS "\\stoptext\n" ;
    close(LIS) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($ListingFile) }

sub DetermineNOfPdfPages
  { my $FileName = shift ;
    my $NOfPages = 0 ;
    if (($FileName =~ /\.pdf$/io)&&(open(PDF,$FileName)))
      { binmode PDF ;
        my $PagesFound = 0 ;
        while (<PDF>)
          { if (/\/Type \/Pages/o)
              { $PagesFound = 1 }
            if ($PagesFound)
              { if (/\/Count\s*(\d*)/o)
                  { if ($1>$NOfPages) { $NOfPages = $1 } }
                elsif (/endobj/o)
                  { $PagesFound = 0 } } }
        close ( PDF ) }
    return $NOfPages }

sub RunArrange
  { my @files = @_ ;
    print "             backspace : $BackSpace\n" ;
    print "              topspace : $TopSpace\n" ;
    print "           paperoffset : $PaperOffset\n" ;
    if ($AddEmpty eq '')
      { print "     empty pages added : none\n" }
    else
      { print "     empty pages added : $AddEmpty\n" }
    if ($TextWidth eq '0pt')
      { print "             textwidth : unknown\n" }
    else
      { print "             textwidth : $TextWidth\n" }
    open (ARR, ">$ArrangeFile.tex") ;
    print ARR "% format=english\n" ;
    if ($PaperFormat ne 'standard')
      { print "           paperformat : $PaperFormat\n" ;
        print ARR "\\setuppapersize[$PaperFormat][$PaperFormat]\n" }
    print ARR "\\definepapersize\n" ;
    print ARR "  [offset=$PaperOffset]\n";
    print ARR "\\setuplayout\n" ;
    print ARR "  [backspace=$BackSpace,\n" ;
    print ARR "    topspace=$TopSpace,\n" ;
    if ($Markings)
      { print ARR "     marking=on,\n" ;
        print "           cutmarkings : on\n" }
    print ARR "       width=middle,\n" ;
    print ARR "      height=middle,\n" ;
    print ARR "    location=middle,\n" ;
    print ARR "      header=0pt,\n" ;
    print ARR "      footer=0pt]\n" ;
    if ($NoDuplex)
      { print "                duplex : off\n" }
    else
      { print "                duplex : on\n" ;
        print ARR "\\setuppagenumbering\n" ;
        print ARR "  [alternative=doublesided]\n" }
    foreach my $FileName (@files)
      { my $NOfPages = DetermineNOfPdfPages($FileName) ;
        if ($NOfPages)
          { print "               pdffile : $FileName\n" ;
            print "       number of pages : $NOfPages\n\n" ;
            print ARR "\\insertpages\n" ;
            if ($AddEmpty eq '')
              { print ARR "  [$FileName][n=$NOfPages,width=$TextWidth]\n" }
            else
              { print ARR "  [$FileName][$AddEmpty][n=$NOfPages,width=$TextWidth]\n" } } }
    print ARR "\\stoptext\n" ;
    close (ARR) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($ModuleFile) }

sub RunSelect
  { my $FileName = shift ;
    print "             backspace : $BackSpace\n" ;
    print "              topspace : $TopSpace\n" ;
    print "           paperoffset : $PaperOffset\n" ;
    if ($TextWidth eq '0pt')
      { print "             textwidth : unknown\n" }
    else
      { print "             textwidth : $TextWidth\n" }
    open (SEL, ">$SelectFile.tex") ;
    print SEL "% format=english\n" ;
    if ($PaperFormat ne 'standard')
      { print "             papersize : $PaperFormat\n" ;
        print SEL "\\setuppapersize[$PaperFormat][$PaperFormat]\n" }
    print SEL "\\definepapersize\n" ;
    print SEL "  [offset=$PaperOffset]\n";
    print SEL "\\setuplayout\n" ;
    print SEL "  [backspace=$BackSpace,\n" ;
    print SEL "    topspace=$TopSpace,\n" ;
    if ($Markings)
      { print SEL "     marking=on,\n" ;
        print "           cutmarkings : on\n" }
    print SEL "       width=middle,\n" ;
    print SEL "      height=middle,\n" ;
    print SEL "    location=middle,\n" ;
    print SEL "      header=0pt,\n" ;
    print SEL "      footer=0pt]\n" ;
   #print SEL "\\setuppagenumbering\n" ;
   #print SEL "  [alternative=doublesided]\n" ;
    my $NOfPages = DetermineNOfPdfPages($FileName) ;
    if (($NOfPages)&&($Selection ne ''))
      { print "               pdffile : $FileName\n" ;
        print "       number of pages : $NOfPages\n\n" ;
        print SEL "\\filterpages\n" ;
        print SEL "  [$FileName][$Selection][n=$NOfPages,width=$TextWidth]\n" }
    print SEL "\\stoptext\n" ;
    close (SEL) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($SelectFile) }

sub RunCopy
  { my $FileName = shift ;
    print "                 scale : $PageScale\n" ;
    if ($PageScale<10) { $PageScale *= 1000 ; sprintf(".0f",$PageScale) } 
    open (COP, ">$CopyFile.tex") ;
    print COP "% format=english\n" ;
    print COP "\\getfiguredimensions\n" ; 
    print COP "  [$FileName][page=1]\n" ; 
    print COP "\\definepapersize\n" ; 
    print COP "  [copy]\n" ; 
    print COP "  [width=\\naturalfigurewidth,\n" ; 
    print COP "   height=\\naturalfigureheight]\n" ; 
    print COP "\\setuppapersize\n" ; 
    print COP "  [copy][copy]\n" ; 
    print COP "\\setuplayout\n" ; 
    print COP "  [location=middle,\n" ; 
    print COP "   topspace=0pt,\n" ; 
    print COP "   backspace=0pt,\n" ; 
    print COP "   header=0pt,\n" ; 
    print COP "   footer=0pt,\n" ; 
    print COP "   width=middle,\n" ; 
    print COP "   height=middle]\n" ; 
    print COP "\\starttext\n" ; 
    my $NOfPages = DetermineNOfPdfPages($FileName) ;
    if ($NOfPages)
      { print "               pdffile : $FileName\n" ;
        print "       number of pages : $NOfPages\n\n" ;
        print COP "\\copypages[$FileName][n=$NOfPages,scale=$PageScale]\n" }
    print COP "\\stoptext\n" ;
    close (COP) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($CopyFile) }

sub RunCombine
  { my $FileName = shift ;
    my ($nx,$ny) = split (/\*/,$Combination,2) ; 
    return unless ($nx&&$ny) ;
    print "           combination : $Combination\n" ;
    open (COM, ">$CombineFile.tex") ;
    print COM "% format=english\n" ;
    if ($PaperFormat ne 'standard') 
      { print "         papersize : $PaperFormat\n" ;
        print COM "\\setuppapersize\n" ; 
        print COM "  [$PaperFormat][$PaperFormat]\n" } 
    if ($PaperOffset eq '0pt') 
      { $PaperOffset = '1cm' } 
    print "          paper offset : $PaperOffset\n" ;
    print COM "\\setuplayout\n" ; 
    print COM "  [topspace=$PaperOffset,\n" ; 
    print COM "   backspace=$PaperOffset,\n" ; 
    print COM "   header=0pt,\n" ; 
    print COM "   footer=1cm,\n" ; 
    print COM "   width=middle,\n" ; 
    print COM "   height=middle]\n" ; 
    print COM "\\setupfootertexts\n" ; 
    print COM "  [$FileName\\space---\\space\\currentdate\\space---\\space\\pagenumber]\n" ; 
    print COM "\\starttext\n" ; 
    my $NOfPages = DetermineNOfPdfPages($FileName) ;
    if ($NOfPages)
      { print "               pdffile : $FileName\n" ;
        print "       number of pages : $NOfPages\n\n" ;
        print COM "\\combinepages[$FileName][n=$NOfPages,nx=$nx,ny=$ny]\n" }
    print COM "\\stoptext\n" ;
    close (COM) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($CombineFile) }

sub RunOneFormat
  { my ($FormatName) = @_ ;
    my @TeXFormatPath ;
    my $TeXPrefix = '' ;
    if ($fmtutil ne '')
      { my $cmd = "$fmtutil --byfmt $FormatName" ;
        if ($Verbose) { print "\n$cmd\n\n" }
        MakeUserFile ; # this works only when the path is kept 
        $Problems = system ( "$cmd" ) ;
        RestoreUserFile }
    else
      { $Problems = 1 }
    if ($Problems)
      { if ($TeXExecutable =~ /etex|eetex|pdfetex|pdfeetex/io)
          {$TeXPrefix = "*" }
        my $CurrentPath = cwd() ;
        if (($TeXFormatPath eq '')&&($kpsewhich ne ''))  
          { $TeXFormatPath = `$kpsewhich --show-path=fmt` ;
            chomp $TeXFormatPath ; 
            $TeXFormatPath =~ s/\.+\;//o ; # should be a sub 
            $TeXFormatPath =~ s/\;.*//o ; 
            $TeXFormatPath =~ s/\!//go ;
            $TeXFormatPath =~ s/\/\//\//go ;
            $TeXFormatPath =~ s/\\\\/\//go ;
            $TeXFormatPath =~ s/[\/\\]$// ; 
            $TeXFormatPath .= '/' ;
            if (($TeXFormatPath ne '')&&$Verbose) 
              { print "    located formatpath : $TeXFormatPath\n" } } 
        if ($TeXFormatPath ne '') 
          { chdir "$TeXFormatPath" }
        MakeUserFile ;
        my $cmd = "$TeXProgramPath$TeXExecutable $TeXVirginFlag " .
                  "$TeXPassString ${TeXPrefix}$FormatName" ;
        if ($Verbose) { print "\n$cmd\n\n" }
        system ( $cmd ) ;
        RestoreUserFile ;
        if (($TeXFormatPath ne '')&&($CurrentPath ne '')) 
          { chdir $CurrentPath } } }

sub RunFormats
  { my $ConTeXtFormatsPrefix;
    if (@ARGV)
      { @ConTeXtFormats = @ARGV }
    elsif ($UsedInterfaces ne '')
      { @ConTeXtFormats = split /\,/,$UsedInterfaces }
    if ($Format)
      { @ConTeXtFormats = $Format; $ConTeXtFormatsPrefix='' ; }
    else
      { $ConTeXtFormatsPrefix="cont-" ; }
    foreach my $Interface (@ConTeXtFormats)
      { RunOneFormat ("$ConTeXtFormatsPrefix$Interface") }
    print "\n" ;
    print "            executable : $TeXProgramPath$TeXExecutable\n" ;
    print "             format(s) : @ConTeXtFormats\n\n" ; }

sub RunFiles
  { if ($PdfArrange)
      { my @arrangedfiles = () ;
        foreach my $JobName (@ARGV)
          { unless ($JobName =~ /.*\.pdf$/oi)
              { if (-f "$JobName.pdf")
                  { $JobName .= ".pdf" }
                else
                  { $JobName .= ".PDF" } } 
            push @arrangedfiles, $JobName }
        if (@arrangedfiles)
          { RunArrange (@arrangedfiles) } }
    elsif (($PdfSelect)||($PdfCopy)||($PdfCombine))
      { my $JobName = $ARGV[0] ;
        if ($JobName ne '')
          { unless ($JobName =~ /.*\.pdf$/oi)
              { if (-f "$JobName.pdf")
                  { $JobName .= ".pdf" }
                else
                  { $JobName .= ".PDF" } }
            if ($PdfSelect)
              { RunSelect ($JobName) } 
            elsif ($PdfCopy) 
              { RunCopy ($JobName) } 
            else
              { RunCombine ($JobName) } } }
    else
      { foreach my $JobName (@ARGV)
          { $JobName =~ s/\.tex//goi ;
            if ($TypesetModule)
              { unless ($Format) { RunModule ($JobName) } }
            else
              { if (($Format eq '')||($Format =~ /^cont.*/io))
                  { RunConTeXtFile ($JobName) }
                else
                  { RunSomeTeXFile ($JobName) } }
            unless (-s "$JobName.log") { unlink ("$JobName.log") }
            unless (-s "$JobName.tui") { unlink ("$JobName.tui") } } } }

sub RunMP
  { if (($MpExecutable)&&($MpToTeXExecutable)&&($DviToMpExecutable))
      { foreach my $RawMpName (@ARGV)
          { my ($MpName, $Rest) = split (/\./, $RawMpName, 2) ;
            if (-e "$MpName.mp")
              { if (open(MP, "$MpName.mp"))
                  { local $/ = "\0777" ; $_ = <MP> ; close(MP) ;
                    if (/(btex|etex|verbatimtex)/)
                      { print "       metapost to tex : $MpName\n" ;
                        $Problems = system ("$MpToTeXExecutable $MpName.mp > $MpName.tex" ) ;
                        if (-e "$MpName.tex"&& !$Problems)
                          { if (($Format eq '')||($Format =~ /^cont.*/io))
                              { RunConTeXtFile ($MpName) }
                            else
                              { RunSomeTeXFile ($MpName) }
                            if (-e "$MpName.dvi"||!$Problems)
                              { print "       dvi to metapost : $MpName\n" ;
                               $Problems = system ("$DviToMpExecutable $MpName") } } } }

                print "              metapost : $MpName\n" ;
                $Problems = system ("$MpExecutable $MpName" ) } } } }

if ($TypesetListing)
  { RunListing (@ARGV) }
elsif ($TypesetFigures)
  { RunFigures (@ARGV) }
elsif ($DoMPTeX)
  { RunMP }
elsif ($MakeFormats)
  { RunFormats }
elsif (@ARGV)
  { RunFiles }
else
  { print $Help{HELP} ;
    unless ($Verbose) { print $Help{VERBOSE} } }

if (-f "cont-opt.tex")
  { unlink ("cont-opt.bak") ;
    rename ("cont-opt.tex", "cont-opt.bak") }

if ($Problems) { exit 1 }
