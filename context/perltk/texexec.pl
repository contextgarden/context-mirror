eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

# todo: second run of checksum of mp file with --nomprun changes
# todo: warning if no args
# todo: <<<< in messages
# todo: cleanup 

#D \module
#D   [       file=texexec.pl,
#D        version=2002.05.04,
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
#  Thanks to Wybo Dekker      for the advanced help interface 

# (I still have to completely understand the help code -)

#D We started with a hack provided by Thomas Esser. This
#D expression replaces the unix specific line \type
#D {#!/usr/bin/perl}.

use Cwd           ;
use Time::Local   ;
use Config        ;
use Getopt::Long  ;
use Class::Struct ; # needed for help subsystem
#   Data::Dumper  ; # needed for help subsystem

my %ConTeXtInterfaces ; # otherwise problems with strict
my %ResponceInterface ; # since i dunno how to allocate else
# my %Help ;

# use strict ;

#D In this script we will launch some programs and other
#D scripts. \TEXEXEC\ uses an ini||file to sort out where
#D those programs are stored. Two boolean variables keep
#D track of the way to call the programs. In \TEXEXEC,
#D \type {$dosish} keeps track of the operating system.
#D It will be no surprise that Thomas Esser provided me
#D the neccessary code to accomplish this.

$ENV{"MPXCOMMAND"} = "0" ; # otherwise loop

my $TotalTime = time ;

## $dosish    = ($Config{'osname'} =~ /dos|mswin/i) ;
my $dosish    = ($Config{'osname'} =~ /^(ms)?dos|^os\/2|^(ms|cyg)win/i) ;

my $TeXUtil   = 'texutil'  ;
my $TeXExec   = 'texexec'  ;
my $DVIspec   = 'dvispec'  ;
my $SGMLtoTeX = 'sgml2tex' ;
my $FDFtoTeX  = 'fdf2tex'  ;

my $MetaFun   = 'metafun'  ;
my $MpToPdf   = 'mptopdf'  ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

my $AddEmpty         = '' ;
my $Alone            = 0 ;
my $Optimize         = 0 ;
my $ForceTeXutil     = 0 ;
my $Arrange          = 0 ;
my $BackSpace        = '0pt' ;
my $Background       = '' ;
my $CenterPage       = 0 ;
my $ConTeXtInterface = 'unknown'  ;
my $Convert          = '' ;
my $DoMPTeX          = 0 ;
my $DoMPXTeX         = 0 ;
my $EnterBatchMode   = 0 ;
my $Environments     = '' ;
my $Modules          = '' ;
my $FastMode         = 0 ;
my $FinalMode        = 0 ;
my $Format           = '' ;
my $MpDoFormat       = '' ;
my $HelpAsked        = 0 ;
my $MainBodyFont     = 'standard' ;
my $MainLanguage     = 'standard' ;
my $MainResponse     = 'standard' ;
my $MakeFormats      = 0 ;
my $Markings         = 0     ;
my $Mode             = '' ;
my $NoArrange        = 0 ;
my $NoDuplex         = 0 ;
my $NOfRuns          = 7 ;
my $NoMPMode         = 0 ;
my $NoMPRun          = 0 ;
my $AutoMPRun        = 0 ;
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
my $Input            = "" ;
my $Result           = 0 ;
my $Suffix           = '' ;
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
my $LogFile          = "" ;
my $MpyForce         = 0 ;
my $RunPath          = "" ;
my $Arguments        = "" ;
my $Pretty           = 0 ;
my $SetFile          = "" ;

&GetOptions
  ( "arrange"       => \$Arrange          ,
    "batch"         => \$EnterBatchMode   ,
    "color"         => \$UseColor         ,
    "centerpage"    => \$CenterPage       ,
    "convert=s"     => \$Convert          ,
    "environments=s"=> \$Environments     ,
    "usemodules=s"  => \$Modules          ,
    "xmlfilters=s"  => \$Filters          ,
    "fast"          => \$FastMode         ,
    "final"         => \$FinalMode        ,
    "format=s"      => \$Format           ,
    "mpformat=s"    => \$MpDoFormat       ,
    "help"          => \$HelpAsked        ,
    "interface=s"   => \$ConTeXtInterface ,
    "language=s"    => \$MainLanguage     ,
    "bodyfont=s"    => \$MainBodyFont     ,
    "results=s"     => \$Result           ,
    "response=s"    => \$MainResponse     ,
    "make"          => \$MakeFormats      ,
    "mode=s"        => \$Mode             ,
    "module"        => \$TypesetModule    ,
    "figures=s"     => \$TypesetFigures   ,
    "listing"       => \$TypesetListing   ,
    "mptex"         => \$DoMPTeX          ,
    "mpxtex"        => \$DoMPXTeX         ,
    "noarrange"     => \$NoArrange        ,
    "nomp"          => \$NoMPMode         ,
    "nomprun"       => \$NoMPRun          ,
    "automprun"     => \$AutoMPRun        ,
    "once"          => \$RunOnce          ,
    "output=s"      => \$OutputFormat     ,
    "pages=s"       => \$Pages            ,
    "paper=s"       => \$PaperFormat      ,
    "passon=s"      => \$PassOn           ,
    "path=s"        => \$RunPath          ,
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
    "background=s"  => \$Background       ,
    "logfile=s"     => \$LogFile          ,
    "print=s"       => \$PrintFormat      ,
    "suffix=s"      => \$Suffix           ,
    "runs=s"        => \$NOfRuns          ,
    "silent"        => \$SilentMode       ,
    "tex=s"         => \$TeXProgram       ,
    "verbose"       => \$Verbose          ,
    "alone"         => \$Alone            ,
    "optimize"      => \$Optimize         ,
    "texutil"       => \$ForceTeXutil     ,
    "mpyforce"      => \$MpyForce         ,
    "input=s"       => \$Input            ,
    "arguments=s"   => \$Arguments        ,
    "pretty"        => \$Pretty           ,
    "setfile=s"     => \$SetFile          ) ;

# a set file (like blabla.bat) can set paths now

if ($SetFile ne "")
  { load_set_file ($SetFile,$Verbose) ; $SetFile = "" }

# later we will do a second attempt.

$SIG{INT} = "IGNORE" ;

if ($ARGV[0] =~ /\.mpx$/io) # catch -tex=.... bug in mpost
  { $TeXProgram = '' ; $DoMPXTeX = 1 ; $NoMPMode = 1 }

if ($DoMPTeX||$DoMPXTeX)
  { $RunOnce = 1 ;
    $ProducePdf = 0 }

if ($PdfArrange||$PdfSelect||$PdfCopy||$PdfCombine)
  { $ProducePdf = 1 ;
    $RunOnce = 1 }

if ($ProducePdf)
  { $OutputFormat = "pdf" }

if ($RunOnce||$Pages||$TypesetFigures||$TypesetListing)
  { $NOfRuns = 1 }

if (($LogFile ne '')&&($LogFile =~ /\w+\.log$/io))
  { open (LOGFILE,">$LogFile") ;
    *STDOUT = *LOGFILE ;
    *STDERR = *LOGFILE }

my $Program = " TeXExec 3.0 - ConTeXt / PRAGMA ADE 1997-2002" ;

print "\n$Program\n\n" ;

my $pathslash = '/' ; if ($0 =~ /\\/) { $pathslash = "\\" }
my $cur_path  = ".$pathslash" ;
my $own_path  = $0 ; $own_path =~ s/texexec(\.pl|\.bat|)//io ;
my $own_type  = $1 ; 
my $own_stub  = "" ; 

if ($own_type =~ /pl/oi) { $own_stub = "perl " } 

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
    if (($Value =~ /\//)&&($Value !~ /\;/)) # no multipath test yet
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

sub found_ini_file
  { my $suffix = shift ;
    my $IniPath = `$kpsewhich --format="other text files" -progname=context texexec.$suffix` ;
    chomp($IniPath) ;
    return $IniPath }

if ($IniPath eq '')
  { foreach (@paths)
      { my $p = checked_path($_) . 'kpsewhich' ;
        if ((-e $p)||(-e $p . '.exe'))
          { $kpsewhich = $p ;
            $IniPath = found_ini_file("ini") ;
            unless (-e $IniPath) { $IniPath = found_ini_file("rme") }
            last } }
    if ($Verbose)
      { if ($kpsewhich eq '')
          { print "     locating ini file : kpsewhich not found in path\n" }
        elsif ($IniPath eq '')
          { print "     locating ini file : not found by kpsewhich\n" }
        else
          { if ($IniPath =~ /rme/oi)
              { print "     locating ini file : not found by kpsewhich, using '.rme' file\n" }
            else
              { print "     locating ini file : found by kpsewhich\n" } } } }

#D Now, when we didn't find the \type {kpsewhich}, we have
#D to revert to some other method. We could have said:
#D
#D \starttypen
#D unless ($IniPath)
#D   { $IniPath = `perl texpath.pl texexec.ini` }
#D \stoptypen
#D
#D But loading perl (for the second time) take some time. Instead of
#D providing a module, which can introduce problems with loading, I
#D decided to copy the code of \type {texpath} into this file.

use File::Find ;
# use File::Copy ; no standard in perl

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

my $TeXShell          = IniValue('TeXShell'          , '' ) ;
my $SetupPath         = IniValue('SetupPath'         , '' ) ;
my $UserInterface     = IniValue('UserInterface'     , 'en' ) ;
my $UsedInterfaces    = IniValue('UsedInterfaces'    , 'en' ) ;
my $TeXFontsPath      = IniValue('TeXFontsPath'      , '.' ) ;
my $MpExecutable      = IniValue('MpExecutable'      , 'mpost' ) ;
my $MpToTeXExecutable = IniValue('MpToTeXExecutable' , 'mpto' ) ;
my $DviToMpExecutable = IniValue('DviToMpExecutable' , 'dvitomp' ) ;
my $TeXProgramPath    = IniValue('TeXProgramPath'    , '' ) ;
my $TeXFormatPath     = IniValue('TeXFormatPath'     , '' ) ;
my $ConTeXtPath       = IniValue('ConTeXtPath'       , '' ) ;
my $TeXScriptsPath    = IniValue('TeXScriptsPath'    , '' ) ;
my $TeXExecutable     = IniValue('TeXExecutable'     , 'tex' ) ;
my $TeXVirginFlag     = IniValue('TeXVirginFlag'     , '-ini' ) ;
my $TeXBatchFlag      = IniValue('TeXBatchFlag'      , '-int=batchmode' ) ;
my $MpBatchFlag       = IniValue('MpBatchFlag'       , '-int=batchmode' ) ;
my $TeXPassString     = IniValue('TeXPassString'     , '' ) ;
my $TeXFormatFlag     = IniValue('TeXFormatFlag'     , '' ) ;
my $MpFormatFlag      = IniValue('MpFormatFlag'      , '' ) ;
my $MpVirginFlag      = IniValue('MpVirginFlag'      , '-ini' ) ;
my $MpPassString      = IniValue('MpPassString'      , '' ) ;
my $MpFormat          = IniValue('MpFormat'          , $MetaFun ) ;
my $MpFormatPath      = IniValue('MpFormatPath'      , $TeXFormatPath ) ;

my $FmtLanguage       = IniValue('FmtLanguage'       , '' ) ;
my $FmtBodyFont       = IniValue('FmtBodyFont'       , '' ) ;
my $FmtResponse       = IniValue('FmtResponse'       , '' ) ;
my $TcXPath           = IniValue('TcXPath'           , '' ) ;

   $SetFile           = IniValue('SetFile'           , $SetFile ) ;

if (($Verbose)&&($kpsewhich ne ''))
  { print "\n" ;
    my $CnfFile = `$kpsewhich -progname=context texmf.cnf` ;
    chomp $CnfFile ;
    print " applications will use : $CnfFile\n" }

if (($FmtLanguage)&&($MainLanguage eq 'standard'))
  { $MainLanguage = $FmtLanguage }
if (($FmtBodyFont)&&($MainBodyFont eq 'standard'))
  { $MainBodyFont = $FmtBodyFont }
if (($FmtResponse)&&($MainResponse eq 'standard'))
  { $MainResponse = $FmtResponse }

if ($TeXFormatFlag eq "" )
  { $TeXFormatFlag = "&" }

if ($MpFormatFlag eq "")
  { $MpFormatFlag  = "&" }

unless ($dosish)
  { if ($TeXFormatFlag == "&") { $TeXFormatFlag = "\\&" }
    if ($MpFormatFlag  == "&") { $MpFormatFlag  = "\\&" } }

if ($TeXProgram)
  { $TeXExecutable = $TeXProgram }

my $fmtutil = '' ;

if ($MakeFormats||$Verbose)
  { if ($Alone)
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
              { print "      locating fmtutil : $fmtutil\n" } } } }

if ($Verbose) { print "\n" }

unless ($TeXScriptsPath)
  { $TeXScriptsPath = $own_path }

unless ($ConTeXtPath)
  { $ConTeXtPath = $TeXScriptsPath }

if ($ENV{"HOME"})
  { if ($SetupPath) { $SetupPath .= "," }
    $SetupPath .= $ENV{"HOME"} }

if ($TeXFormatPath)  { $TeXFormatPath  =~ s/[\/\\]$// ; $TeXFormatPath  .= '/' }
if ($MpFormatPath)   { $MpFormatPath   =~ s/[\/\\]$// ; $MpFormatPath   .= '/' }
if ($ConTeXtPath)    { $ConTeXtPath    =~ s/[\/\\]$// ; $ConTeXtPath    .= '/' }
if ($SetupPath)      { $SetupPath      =~ s/[\/\\]$// ; $SetupPath      .= '/' }
if ($TeXScriptsPath) { $TeXScriptsPath =~ s/[\/\\]$// ; $TeXScriptsPath .= '/' }

$SetupPath =~ s/\\/\//go ;  

my %OutputFormats ;

$OutputFormats{pdf}      = "pdftex" ;
$OutputFormats{pdftex}   = "pdftex" ;
$OutputFormats{dvips}    = "dvips" ;
$OutputFormats{dvipsone} = "dvipsone" ;
$OutputFormats{acrobat}  = "acrobat" ;
$OutputFormats{dviwindo} = "dviwindo" ;
$OutputFormats{dviview}  = "dviview" ;
$OutputFormats{dvipdfm}  = "dvipdfm" ;

my @ConTeXtFormats = ("nl", "en", "de", "cz", "uk", "it", "ro", "xx") ;

sub SetInterfaces
  { my ($short,$long,$full) = @_ ;
    $ConTeXtInterfaces{$short} = $short ;
    $ConTeXtInterfaces{$long}  = $short ;
    $ResponseInterface{$short} = $full ;
    $ResponseInterface{$long}  = $full }

#SetInterfaces ( "en" , "unknown"      , "english"   ) ;

SetInterfaces ( "nl" , "dutch"        , "dutch"     ) ;
SetInterfaces ( "en" , "english"      , "english"   ) ;
SetInterfaces ( "de" , "german"       , "german"    ) ;
SetInterfaces ( "cz" , "czech"        , "czech"     ) ;
SetInterfaces ( "uk" , "brittish"     , "english"   ) ;
SetInterfaces ( "it" , "italian"      , "italian"   ) ;
SetInterfaces ( "no" , "norwegian"    , "norwegian" ) ;
SetInterfaces ( "ro" , "romanian"     , "romanian"  ) ;
SetInterfaces ( "xx" , "experimental" , "english"   ) ;

#### old help system

# $Help{ARRANGE}     = "             --arrange   process and arrange\n" ;
# $Help{BATCH}       = "               --batch   run in batch mode (don't pause)\n" ;
# $Help{CENTERPAGE}  = "          --centerpage   center the page on the paper\n" ;
# $Help{COLOR}       = "               --color   enable color (when not yet enabled)\n" ;
# $Help{USEMODULE}   = "           --usemodule   load some modules first\n" ;
# $Help{usemodule}   =
# $Help{USEMODULE}   . "                           =name : list of modules\n" ;
# $Help{XMLFILTER}   = "           --xmlfilter   apply XML filter\n" ;
# $Help{xmlfilter}   =
# $Help{XMLFILTER}   . "                           =name : list of filters\n" ;
# $Help{ENVIRONMENT} = "         --environment   load some environments first\n" ;
# $Help{environment} =
# $Help{ENVIRONMENT} . "                           =name : list of environments\n" ;
# $Help{FAST}        = "                --fast   skip as much as possible\n" ;
# $Help{FIGURES}     = "             --figures   typeset figure directory\n" ;
# $Help{figures}     =
# $Help{FIGURES}     . "                           =a : room for corrections\n"
#                    . "                           =b : just graphics\n"
#                    . "                           =c : one (cropped) per page\n"
#                    . "         --paperoffset   room left at paper border\n" ;
# $Help{FINAL}       = "               --final   add a final run without skipping\n" ;
# $Help{FORMAT}      = "              --format   fmt file\n" ;
# $Help{format}      =
# $Help{FORMAT}      . "                           =name : format file (memory dump) \n" ;
# $Help{MPFORMAT}    = "            --mpformat   mem file\n" ;
# $Help{mpformat}    =
# $Help{MPFORMAT}    . "                           =name : format file (memory dump) \n" ;
# $Help{INTERFACE}   = "           --interface   user interface\n" ;
# $Help{interface}   =
# $Help{INTERFACE}   . "                           =en : English\n"
#                    . "                           =nl : Dutch\n"
#                    . "                           =de : German\n"
#                    . "                           =cz : Czech\n"
#                    . "                           =uk : Brittish\n"
#                    . "                           =it : Italian\n" ;
# $Help{LANGUAGE}    = "            --language   main hyphenation language \n" ;
# $Help{language}    =
# $Help{LANGUAGE}    . "                           =xx : standard abbreviation \n" ;
# $Help{LISTING}     = "             --listing   produce a verbatim listing\n" ;
# $Help{listing}     =
# $Help{LISTING}     . "           --backspace   inner margin of the page\n" .
#                      "            --topspace   top/bottom margin of the page\n" .
#                      "              --pretty   enable pretty printing\n" .
#                      "               --color   use color for pretty printing\n" ;
# $Help{MAKE}        = "                --make   build format files \n" ;
# $Help{make}        =
# $Help{MAKE}        . "            --language   patterns to include\n" .
#                      "            --bodyfont   bodyfont to preload\n" .
#                      "            --response   response interface language\n" .
#                      "              --format   TeX format\n" .
#                      "            --mpformat   MetaPost format\n" .
#                      "             --program   TeX program\n" ;
# $Help{MODE}        = "                --mode   running mode \n" ;
# $Help{mode}        =
# $Help{MODE}        . "                           =list : modes to set\n" ;
# $Help{MODULE}      = "              --module   typeset tex/pl/mp module\n" ;
# $Help{MPTEX}       = "               --mptex   run an MetaPost plus btex-etex cycle\n" ;
# $Help{MPXTEX}      = "              --mpxtex   generatet an MetaPostmpx file\n" ;
# $Help{NOARRANGE}   = "           --noarrange   process but ignore arrange\n" ;
# $Help{NOMP}        = "                --nomp   don't run MetaPost at all\n" ;
# $Help{NOMPRUN}     = "             --nomprun   don't run MetaPost at runtime\n" ;
# $Help{AUTOMPRUN}   = "           --automprun   MetaPost at runtime when needed\n" ;
# $Help{ONCE}        = "                --once   run TeX only once (no TeXUtil either)\n" ;
# $Help{OUTPUT}      = "              --output   specials to use\n" ;
# $Help{output}      =
# $Help{OUTPUT}      . "                           =pdftex\n"
#                    . "                           =dvips\n"
#                    . "                           =dvipsone\n"
#                    . "                           =dviwindo\n"
#                    . "                           =dviview\n"
#                    . "                           =dvipdfm\n" ;
# $Help{PASSON}      = '              --passon   switches to pass to TeX ("--src" for MikTeX)' . "\n" ;
# $Help{PAGES}       = "               --pages   pages to output\n" ;
# $Help{pages}       =
# $Help{PAGES}       . "                           =odd   : odd pages\n" .
#                      "                           =even  : even pages\n" .
#                      "                           =x,y:z : pages x and y to z\n" ;
# $Help{PAPER}       = "               --paper   paper input and output format\n" ;
# $Help{paper}       =
# $Help{PAPER}       . "                           =a4a3 : A4 printed on A3\n" .
#                      "                           =a5a4 : A5 printed on A4\n" ;
# $Help{PATH}        = "                --path   document source path\n" ;
# $Help{path}        =
# $Help{PATH}        . "                           =string : path\n" ;
# $Help{PDF}         = "                 --pdf   produce PDF directly using pdf(e)tex\n" ;
# $Help{PDFARRANGE}  = "          --pdfarrange   arrange pdf pages\n" ;
# $Help{pdfarrange}  =
# $Help{PDFARRANGE}  . "         --paperoffset   room left at paper border\n" .
#                      "               --paper   paper format\n" .
#                      "            --noduplex   single sided\n" .
#                      "           --backspace   inner margin of the page\n" .
#                      "            --topspace   top/bottom margin of the page\n" .
#                      "            --markings   add cutmarks\n" .
#                      "          --background     =background graphic\n" .
#                      "            --addempty   add empty page after\n" .
#                      "           --textwidth   width of the original (one sided) text\n" ;
# $Help{PDFCOMBINE}  = "          --pdfcombine   combine pages to one page\n" ;
# $Help{pdfcombine}  =
# $Help{PDFCOMBINE}  . "         --paperformat   paper format\n" .
#                      "         --combination   n*m pages per page\n" .
#                      "         --paperoffset   room left at paper border\n" ;
# $Help{PDFCOPY}     = "             --pdfcopy   scale pages down/up\n" ;
# $Help{pdfcopy}     =
# $Help{PDFCOPY}     . "               --scale   new page scale\n" .
#                      "         --paperoffset   room left at paper border\n" .
#                      "            --markings   add cutmarks\n" .
#                      "          --background     =background graphic\n" ;
# $Help{PDFSELECT}   = "           --pdfselect   select pdf pages\n" ;
# $Help{pdfselect}   =
# $Help{PDFSELECT}   . "           --selection   pages to select\n" .
#                      "                           =odd   : odd pages\n" .
#                      "                           =even  : even pages\n" .
#                      "                           =x,y:z : pages x and y to z\n" .
#                      "         --paperoffset   room left at paper border\n" .
#                      "         --paperformat   paper format\n" .
#                      "           --backspace   inner margin of the page\n" .
#                      "            --topspace   top/bottom margin of the page\n" .
#                      "            --markings   add cutmarks\n" .
#                      "          --background     =background graphic\n" .
#                      "            --addempty   add empty page after\n" .
#                      "           --textwidth   width of the original (one sided) text\n" ;
# $Help{PRINT}       = "               --print   page imposition scheme\n" ;
# $Help{print}       =
# $Help{PRINT}       . "                             =up : 2 pages per sheet doublesided           \n" .
#                      "                           =down : 2 rotated pages per sheet doublesided \n" ;
# $Help{RESULT}      = "              --result   resulting file \n" ;
# $Help{result}      =
# $Help{RESULT}      . "                           =name : filename \n" ;
# $Help{INPUT}       = "               --input   input file (if used)\n" ;
# $Help{input}       =
# $Help{INPUT}       . "                           =name : filename \n" ;
# $Help{SUFFIX}      = "              --suffix   resulting file suffix\n" ;
# $Help{suffix}      =
# $Help{SUFFIX}      . "                         =string : suffix \n" ;
# $Help{RUNS}        = "                --runs   maximum number of TeX runs \n" ;
# $Help{runs}        =
# $Help{RUNS}        . "                           =n : number of runs\n" ;
# $Help{SILENT}      = "              --silent   minimize (status) messages\n" ;
# $Help{TEX}         = "                 --tex   TeX binary \n" ;
# $Help{tex}         =
# $Help{TEX}         . "                           =name : binary of executable \n" ;
# $Help{VERBOSE}     = "             --verbose   shows some additional info \n" ;
# $Help{HELP}        = "                --help   show this or more, e.g. '--help interface'\n" ;
#
# $Help{ALONE}       = "               --alone   bypass utilities (e.g. fmtutil for non-standard fmt's)\n" ;
# $Help{TEXUTIL}     = "             --texutil   force TeXUtil run\n" ;
# $Help{SETFILE}     = "             --setfile   load environment (batch) file\n" ;
#
# if ($HelpAsked)
#   { if (@ARGV)
#       { foreach (@ARGV) { s/\-//go ; print "$Help{$_}\n" } }
#     else
#       { print $Help{ARRANGE}     ;
#         print $Help{BATCH}       ;
#         print $Help{CENTERPAGE}  ;
#         print $Help{COLOR}       ;
# #       print $Help{CONVERT}     ;
#         print $Help{INPUT}       ;
#         print $Help{USEMODULE}   ;
#         print $Help{XMLFILTER}   ;
#         print $Help{ENVIRONMENT} ;
#         print $Help{FAST}        ;
#         print $Help{FIGURES}     ;
#         print $Help{FINAL}       ;
#         print $Help{FORMAT}      ;
#         print $Help{INTERFACE}   ;
#         print $Help{LISTING}     ;
#         print $Help{LANGUAGE}    ;
#         print $Help{MAKE}        ;
#         print $Help{MODE}        ;
#         print $Help{MODULE}      ;
#         print $Help{MPTEX}       ;
#         print $Help{MPXTEX}      ;
#         print $Help{NOARRANGE}   ;
#         print $Help{NOMP}        ;
#         print $Help{NOMPRUN}     ;
#         print $Help{AUTOMPRUN}   ;
#         print $Help{ONCE}        ;
#         print $Help{OUTPUT}      ;
#         print $Help{PAGES}       ;
#         print $Help{PAPER}       ;
#         print $Help{PASSON}      ;
#         print $Help{PATH}        ;
#         print $Help{PDFARRANGE}  ;
#         print $Help{PDFCOMBINE}  ;
#         print $Help{PDFCOPY}     ;
#         print $Help{PDFSELECT}   ;
#         print $Help{PDF}         ;
#         print $Help{PRINT}       ;
#         print $Help{RESULT}      ;
#         print $Help{SUFFIX}      ;
#         print $Help{RUNS}        ;
#         print $Help{SILENT}      ;
#         print $Help{TEX}         ;
#         print $Help{VERBOSE}     ;
#         print $Help{ALONE}       ;
#         print $Help{TEXUTIL}     ;
#         print $Help{SETFILE}     ;
#         print "\n"               ;
#         print $Help{HELP}        ;
#         print "\n"               }
#     exit 0 }

#### new help system, written by Wybo Dekker

# Sub-option

struct Subopt => 
  { desc => '$' ,    # description
    vals => '%' } ;  # assignable values 

# Main option

struct Opt => 
  { desc => '$' ,   # desciption
    vals => '%' ,   # assignable values
    subs => '%' } ; # suboptions 

# read a main option plus its
#   description,
#   assignable values and
#     sub-options and their
#       description and
#       assignable values

sub read_options 
  { $recurse++ ;
    my $v = shift;
    chomp ;
    my $opt = $recurse ? Subopt->new() : Opt->new() ;
    $opt->desc($v) ;

    while(@opts) 
      { $_ = shift @opts ;
        if (/^--+/) 
          { unshift @opts, $_ if $recurse ; last }
        if ($recurse && !/^=/) 
          { unshift @opts, $_ ; last }
        chomp ;
        my ($kk,$vv) = split(/\s+/,$_,2); # was \t 
        $vv||='' ;
        if (/^=/) 
          { $opt->vals($kk,$vv) } 
        elsif (!$recurse)  
          { $opt->subs($kk,read_options($vv)) } }
    $recurse-- ;
    $opt }

my $helpdone = 0 ; 

sub print_opt 
  { my ($k,$opt)=@_ ;
    if ($helpdone) { $shorthelp or print "\n" } $helpdone = 1 ; # hh 
    $~ = 'H1' ; 
    write ;
    return if $shorthelp<0 ;
    for $k (sort keys %{$opt->vals}) {print_val($k,${$opt->vals}{$k}) }
    return if $shorthelp>0 ;
    for $k (sort keys %{$opt->subs}) {print_subopt($k,${$opt->subs}{$k}) }
format H1 =
@>>>>>>>>>>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"--$k",$opt->desc
. 
  }

sub print_subopt 
  { my ($k,$opt) = @_ ;
    $~ = 'H3' ; 
    write ;
    for $k (sort keys %{$opt->vals}) 
      {print_val($k,${$opt->vals}{$k}) }
format H3 =
@>>>>>>>>>>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"--$k",$opt->desc
. 
  }

sub print_val 
  { my ($k,$opt) = @_ ;
    $~ = 'H2' ; write ;
format H2 =
                           @<<<<<<< : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$k,$opt
.
  }

# read all options

$recurse-- ;
@opts = <DATA> ;
while(@opts) 
  { $_ = shift @opts ;
    last if /^--+/ ;
    my ($k,$v) = split(/\s+/,$_,2); # was \t
    $Help{$k} = read_options($v) }

# help to help

sub show_help_options
  { print # "\n" .
      "                --help   overview of all options and their values\n" . 
      "            --help all   all about all options\n" . 
      "          --help short   just the main options\n" . 
      "   --help mode ... pdf   all about a few options\n" . 
      "        --help '*.pdf'   all about options containing 'pdf'\n" } ;

# determine what user wants to see

if ($HelpAsked)
  { $shorthelp = 0 ;
    @help = (sort keys %Help) ;
    if ("@ARGV" eq "all") 
      { # everything
      } 
    elsif ("@ARGV" eq "short") 
      { # nearly everything 
        $shorthelp-- }  
    elsif ("@ARGV" eq "help") 
      { # help on help 
        show_help_options ; 
        exit } 
    elsif (@ARGV) 
      { # one or a few options, completely
        my @h=@ARGV ;
        @help = () ;
        for (@h) 
          { # print "testing $_\n";
            # next if (/^[\*\?]/) ; # HH, else error
            if (/^[\*\?]/) { $_ = ".$_" } # HH, else error
            $Help{$_} and push(@help,$_) or do 
              { my $unknown = $_ ;
                for (keys %Help) 
                  { /$unknown/ and push(@help,$_) } } } } 
   else 
     { # all main option and their assignable values
       $shorthelp++ } }

sub show_help_info
  { map { print_opt($_,$Help{$_}) } @help } 

# uncomment this to see the structure of a Help element:
# print Dumper($Help{pdfselect});

#### end of help system

my $FinalRunNeeded = 0 ;

sub MPJobName
  { my $JobName = shift ;
    my $MPfile = shift ;
    my $MPJobName = '' ;
    if (-s "$JobName-$MPfile.mp">100)
      { $MPJobName = "$JobName-$MPfile.mp" }
    elsif (-s "$MPfile.mp">100)
      { $MPJobName = "$MPfile.mp" }
    else
      { $MPJobName = "" }
    return $MPJobName }

sub RunPerlScript
  { my ($ScriptName, $Options) = @_ ;
    if ($dosish)
#      { if (-e "$TeXScriptsPath$ScriptName.pl")
      { if (-e "$TeXScriptsPath$ScriptName$own_type")
#          { system ("perl $TeXScriptsPath$ScriptName.pl $Options") } }
          { system ("$own_stub$TeXScriptsPath$ScriptName$own_type $Options") } }
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
  { my ($FinalRun, $FastDisabled, $JobName, $JobSuffix) = @_ ;
    open (OPT, ">$JobName.top") ;
    print OPT "\\unprotect\n" ;
    if ($Result) # no '' test
      { print OPT "\\setupsystem[file=$Result]\n" }
    elsif ($Suffix)
      { print OPT "\\setupsystem[file=$JobName$Suffix]\n" }
    if ($RunPath ne "")
      { $RunPath =~ s/\\/\//go ; print OPT "\\usepath[$RunPath]\n" }
    $MainLanguage = lc $MainLanguage ;
    unless ($MainLanguage eq "standard")
      { print OPT "\\setuplanguage[$MainLanguage]\n" }
    # can best become : \use...[mik] / [web]
    if ($TeXShell =~ /MikTeX/io)
      { print OPT "\\def\\MPOSTbatchswitch \{$MpBatchFlag\}" ;
        print OPT "\\def\\MPOSTformatswitch\{$MpPassString $MpFormatFlag\}" }
    #
    if ($FullFormat ne 'standard')
      { print OPT "\\setupoutput[$FullFormat]\n" }
    if ($EnterBatchMode)
      { print OPT "\\batchmode\n" }
    if ($UseColor)
      { print OPT "\\setupcolors[\\c!status=\\v!start]\n" }
    if ($NoMPMode||$NoMPRun||$AutoMPRun)
      { print OPT "\\runMPgraphicsfalse\n" }
    if (($FastMode)&&(!$FastDisabled))
      { print OPT "\\fastmode\n" }
    if ($SilentMode)
      { print OPT "\\silentmode\n" }
    if ($SetupPath)
      { print OPT "\\setupsystem[\\c!gebied=\{$SetupPath\}]\n" }
    $_ = $PaperFormat ;
   #unless (($PdfArrange)||($PdfSelect)||($PdfCombine)||($PdfCopy))
    unless (($PdfSelect)||($PdfCombine)||($PdfCopy))
      { if (/.4.3/goi)
          { print OPT "\\setuppapersize[A4][A3]\n" }
        elsif (/.5.4/goi)
          { print OPT "\\setuppapersize[A5][A4]\n" }
        elsif (!/standard/)
          { s/x/\*/io ; $_ = uc $_ ; my ($from,$to) = split (/\*/) ;
            if ($to eq "") { $to = $from }
            print OPT "\\setuppapersize[$from][$to]\n" } }
    if (($PdfSelect||$PdfCombine||$PdfCopy||$PdfArrange)&&($Background ne ''))
      { print "    background graphic : $Background\n" ;
        print OPT "\\defineoverlay[whatever][{\\externalfigure[$Background][\\c!factor=\\v!max]}]\n" ;
        print OPT "\\setupbackgrounds[\\v!pagina][\\c!achtergrond=whatever]\n" }
    if ($CenterPage)
      { print OPT "\\setuplayout[\\c!plaats=\\v!midden,\\c!markering=\\v!aan]\n" }
    if ($NoArrange)
      { print OPT "\\setuparranging[\\v!blokkeer]\n" }
    elsif ($Arrange||$PdfArrange)
      { $FinalRunNeeded = 1 ;
        if ($FinalRun)
          { if ($NoDuplex)
              {$DupStr = "" }
            else    
              {$DupStr = ",\\v!dubbelzijdig" }
            if ($PrintFormat =~ /.*up/goi)
              { print OPT "\\setuparranging[2UP,\\v!geroteerd$DupStr]\n" }
            elsif ($PrintFormat =~ /.*down/goi)
              { print OPT "\\setuparranging[2DOWN,\\v!geroteerd$DupStr]\n" }
            elsif ($PrintFormat =~ /.*side/goi)
              { print OPT "\\setuparranging[2SIDE,\\v!geroteerd$DupStr]\n" }
            else
              { print OPT "\\setuparranging[$PrintFormat]\n" } }
        else
          { print OPT "\\setuparranging[\\v!blokkeer]\n" } }
    if ($Arguments)
      { print OPT "\\setupenv[$Arguments]\n" }
    if ($Input)
      { print OPT "\\setupsystem[inputfile=$Input]\n" }
    else
      { print OPT "\\setupsystem[inputfile=$JobName.$JobSuffix]\n" }
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
    if ($Filters ne "")
      { foreach my $F (split(/,/,$Filters)) { print OPT "\\useXMLfilter[$F]\n" } }
    if ($Modules ne "")
      { foreach my $M (split(/,/,$Modules)) { print OPT "\\usemodule[$M]\n" } }
    if ($Environments ne "")
      { foreach my $E (split(/,/,$Environments)) { print OPT "\\environment $E\n" } }
    close (OPT) }

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
       { print USR "\\definetypescriptsynonym[cmr][$MainBodyFont]" ;
         print USR "\\definefilesynonym[font-cmr][font-$MainBodyFont]\n" }
    print USR "\\protect\n" ;
    print USR "\\endinput\n" ;
    close (USR) ;
    ReportUserFile () ;
    print "\n" ;
    $UserFileOk = 1 }

sub RemoveResponseFile
  { unlink "mult-def.tex" }

sub MakeResponseFile
  { if ($MainResponse eq 'standard')
      { RemoveResponseFile() }
    elsif (! defined ($ResponseInterface{$MainResponse}))
      { RemoveResponseFile() }
    else
      { my $MR = $ResponseInterface{$MainResponse} ;
        print "   preparing interface file : mult-def.tex\n" ;
        print "          response language : $MR\n" ;
        open (DEF, ">mult-def.tex") ;
        print DEF "\\def\\currentresponses\{$MR\}\n\\endinput\n" ;
        close (DEF) } }

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

sub CompareFiles # 2 = tuo
  { my ($File1, $File2) = @_ ;
    my $Str1 = my $Str2 = '' ;
    if ( ((-s $File1) eq (-s $File2))&&
         (open(TUO1,$File1))         &&
         (open(TUO2,$File2))            )
      { while (1)
         { $Str1 = <TUO1> ; chomp $Str1 ;
           $Str2 = <TUO2> ; chomp $Str2 ;
           if ($Str1 eq $Str2)
             { unless ($Str1) { close(TUO1) ; close(TUO2) ; return 1 } }
           else
             { close(TUO1) ; close(TUO2) ; return 0 } } }
    else
      { return 0 } }

sub CheckPositions
 { return if ($DVIspec eq '') ;
   my $JobName = shift ; my $TuoName = "$JobName.tuo" ;
   if (open(POS,"$TuoName"))
     { seek POS, (-s $TuoName) - 5000, 0 ;
       while (<POS>)
         { if (/\% *position commands *\: *(\d*) *\(unresolved\)/io)
             { if ($1)
                 { print "         dvi positions : $1 ($DVIspec ." ;
                   close (POS) ;
                   open(POS,">>$TuoName") ;
                   $ENV{uc "$DVIspec.TEXFONTSDIR"} = $TeXFontsPath ;
                   print POS "\%\n\% extracted from dvi file by $DVIspec:\n\%\n" ;
                   close(POS) ;
                   print "." ;
                   RunPerlScript ($DVIspec, "$JobName >> $TuoName") ;
                   print ".)\n" }
               last } }
       close (POS) } }

# my @ExtraPrograms = () ; 
# 
# sub CheckExtraPrograms
#   { my $JobName = shift ; my $TuoName = "$JobName.tuo" ;
#     if (open(PRO,"$TuoName"))
#       { seek PRO, (-s $TuoName) - 5000, 0 ;
#         while (<PRO>)
#           { if (/\%\s*extra\s*program\s*\:\s*(.*)\s*$/io)
#               { push @ExtraPrograms, $1 } }
#         close (PRO) } 
#     foreach my $EP (@ExtraPrograms) 
#       { if ($EP =~ /(.+)\s*(.*)/o) 
#           { print "\n         extra program : $1\n" ;
#             system($EP) ; 
#             print "\n" } } }

my $ConTeXtVersion = "unknown" ;
my $ConTeXtModes   = '' ;

sub ScanPreamble
  { my ($FileName) = @_ ;
    open (TEX, $FileName) ;
    while (<TEX>)
     { chomp ;
       if (/^\%.*/)
         { if (/tex=([a-z]*)/goi)                  { $TeXExecutable  = $1 }
           if (/translat.*?=([\:\/0-9\-a-z]*)/goi) { $TeXTranslation = $1 }
           if (/program=([a-z]*)/goi)              { $TeXExecutable  = $1 }
           if (/output=([a-z\,\-]*)/goi)           { $OutputFormat   = $1 }
           if (/modes=([a-z\,\-]*)/goi)            { $ConTeXtModes   = $1 }
           if ($ConTeXtInterface eq "unknown")
             { if (/format=([a-z]*)/goi)           { $ConTeXtInterface = $ConTeXtInterfaces{$1}  }
               if (/interface=([a-z]*)/goi)        { $ConTeXtInterface = $ConTeXtInterfaces{"$1"} } }
           if (/version=([a-z]*)/goi)              { $ConTeXtVersion   = $1 } }
       else
         { last } }
    close(TEX) }

sub ScanContent
  { my ($ConTeXtInput) = @_ ;
    open (TEX, $ConTeXtInput) ;
    while (<TEX>)
      { if    (/\\(starttekst|stoptekst|startonderdeel|startdocument|startoverzicht)/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/\\(stelle|verwende|umgebung|benutze)/)
          { $ConTeXtInterface = "de" ; last }
        elsif (/\\(stel|gebruik|omgeving)/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/\\(use|setup|environment)/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/\\(usa|imposta|ambiente)/)
          { $ConTeXtInterface = "it" ; last }
        elsif (/(hoogte|breedte|letter)=/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/(height|width|style)=/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/(hoehe|breite|schrift)=/)
          { $ConTeXtInterface = "de" ; last }
        elsif (/(altezza|ampiezza|stile)=/)
          { $ConTeXtInterface = "it" ; last }
        elsif (/externfiguur/)
          { $ConTeXtInterface = "nl" ; last }
        elsif (/externalfigure/)
          { $ConTeXtInterface = "en" ; last }
        elsif (/externeabbildung/)
          { $ConTeXtInterface = "de" ; last }
        elsif (/figuraesterna/)
          { $ConTeXtInterface = "it" ; last } }
    close (TEX) }

if ($ConTeXtInterfaces{$ConTeXtInterface})
  { $ConTeXtInterface = $ConTeXtInterfaces{$ConTeXtInterface} }

my $Problems = my $Ok = 0 ;

sub RunTeX
  { my ($JobName,$JobSuffix) = @_ ;
    my $StartTime = time ;
    my $cmd ;
    my $TeXProgNameFlag ;
    if (!$dosish) # we assume tetex on linux
      { $TeXProgramPath = '' ;
        $TeXFormatPath = '' ;
        if (!$TeXProgNameFlag &&
            ($Format =~ /^cont/) &&
            ($TeXPassString !~ /progname/io))
          { $TeXProgNameFlag = "-progname=context" } }
    $cmd  = "$TeXProgramPath$TeXExecutable $TeXProgNameFlag " .
            "$TeXPassString $PassOn " ;
   #$cmd .= " -kpathsea-debug=62536 " ;
    if ($EnterBatchMode)
      { $cmd .= "$TeXBatchFlag " }
    if ($TeXTranslation ne '')
      { $cmd .= "-translate-file=$TeXTranslation " }
    $cmd .= "$TeXFormatFlag$TeXFormatPath$Format $JobName.$JobSuffix" ;
    if ($Verbose) { print "\n$cmd\n\n" }
    if ($EnterBatchMode)
#     { $Problems = system("$cmd 1>batch.log 2>batch.err") ;
#       unlink "texexec.nul" }
      { $Problems = system("$cmd") }
    else
      { $Problems = system ("$cmd") }
    my $StopTime = time - $StartTime ;
    print "\n              run time : $StopTime seconds\n" ;
    return $Problems }

sub PushResult
  { my $File = shift ; $File =~ s/\..*$//o ; $Result =~ s/\..*$//o ;
    if ($Result)
      { print "            outputfile : $Result\n" ;
        unlink "texexec.tuo" ; rename "$File.tuo", "texexec.tuo" ;
        unlink "texexec.log" ; rename "$File.log", "texexec.log" ;
        unlink "texexec.dvi" ; rename "$File.dvi", "texexec.dvi" ;
        unlink "texexec.pdf" ; rename "$File.pdf", "texexec.pdf" ;
        if (-e "$Result.tuo")
          { unlink "$File.tuo" ;
            rename "$Result.tuo", "$File.tuo" } }
if ($Optimize)
  { unlink "$File.tuo" }
}

sub PopResult
  { my $File = shift ; $File =~ s/\..*$//o ; $Result =~ s/\..*$//o ;
    if ($Result)
      { print "              renaming : $File to $Result\n" ;
        unlink "$Result.tuo" ; rename "$File.tuo", "$Result.tuo" ;
        unlink "$Result.log" ; rename "$File.log", "$Result.log" ;
        unlink "$Result.dvi" ; rename "$File.dvi", "$Result.dvi" ;
        if (-e "$File.dvi") { CopyFile("$File.dvi", "$Result.dvi") }
        unlink "$Result.pdf" ; rename "$File.pdf", "$Result.pdf" ;
        if (-e "$File.pdf") { CopyFile("$File.pdf", "$Result.pdf") }
        return if ($File ne "texexec") ;
        rename "texexec.tuo", "$File.tuo" ;
        rename "texexec.log", "$File.log" ;
        rename "texexec.dvi", "$File.dvi" ;
        rename "texexec.pdf", "$File.pdf" } }

sub RunTeXutil
  { my $StopRunning ;
    my $JobName = shift ;
    unlink "$JobName.tup" ;
    rename "$JobName.tuo", "$JobName.tup" ;
    print "  sorting and checking : running texutil\n" ;
    my $TcXSwitch = '' ;
    if ($TcXPath ne '') { $TcXSwitch = "--tcxpath=$TcXPath" }
    RunPerlScript
      ($TeXUtil, "--ref --ij --high $TcXPath $JobName" );
    if (-e "$JobName.tuo")
      { CheckPositions ($JobName) ;
      # CheckExtraPrograms($JobName) ;
        $StopRunning = CompareFiles("$JobName.tup", "$JobName.tuo") }
    else
      { $StopRunning = 1 } # otherwise potential loop
    if (!$StopRunning)
      { print "\n utility file analysis : another run needed\n" }
    return $StopRunning }

sub RunTeXMP
  { my $JobName = shift ;
    my $MPfile = shift ;
    my $MPrundone = 0 ;
    my $MPJobName = MPJobName($JobName,$MPfile) ;
    my $MPFoundJobName = "" ;
    if ($MPJobName ne "")
      { if (open(MP, "$MPJobName"))
          { $_ = <MP> ; chomp ;  # we should handle the prefix as well
            if (/collected graphics of job \"(.+)\"/i)
              { $MPFoundJobName = $1 }
            close(MP) ;
            if ($MPFoundJobName ne "")
              { if ($JobName =~ /$MPFoundJobName$/i)
                  { if ($MpExecutable ne '')
                      { print "   generating graphics : metaposting $MPJobName\n" ;
                        my $ForceMpy = "" ;
                        if ($MpyForce) { $ForceMpy = "--mpyforce" }
                        if ($EnterBatchMode)
                          { RunPerlScript ($TeXExec,"$ForceMpy --mptex --nomp --batch $MPJobName") }
                        else
                          { RunPerlScript ($TeXExec,"$ForceMpy --mptex --nomp $MPJobName") } }
                    else
                      { print "   generating graphics : metapost cannot be run\n" }
                    $MPrundone = 1 } } } }
   return $MPrundone }

sub CopyFile # agressive copy, works for open files like in gs
  { my ($From,$To) = @_ ;
    return unless open(INP,"<$From") ; binmode INP ;
    return unless open(OUT,">$To") ; binmode OUT ;
    while (<INP>) { print OUT $_ }
    close (INP) ;
    close (OUT) }

sub CheckChanges # also tub
  { my $JobName = shift ;
    my $checksum = 0 ;
    my $MPJobName = MPJobName($JobName,"mpgraph") ;
    if (open(MP, $MPJobName))
      { while (<MP>)
          { unless (/random/oi)
              { $checksum += do { unpack("%32C*",<MP>) % 65535 } } }
        close (MP) }
    $MPJobName = MPJobName($JobName,"mprun") ;
    if (open(MP, $MPJobName))
      { while (<MP>)
          { unless (/random/oi)
              { $checksum += do { unpack("%32C*",<MP>) % 65535 } } }
        close(MP) }
    return $checksum }

my $DummyFile = 0 ;

sub RunConTeXtFile
  { my ($JobName, $JobSuffix) = @_ ;
    $JobName =~ s/\\/\//goi ;
    $RunPath =~ s/\\/\//goi ;
    my $OriSuffix = $JobSuffix ;
    if (-e "$JobName.$JobSuffix")
      { $DummyFile = ($JobSuffix =~ /(xml|xsd)/io) }
    elsif (($RunPath)&&(-e "$RunPath/$JobName.$JobSuffix"))
      { $DummyFile = 1 }
    if ($DummyFile)
      { open (TMP,">$JobName.run") ;
        if ($JobSuffix =~ /(xml|xsd)/io)
          { if ($Filters ne "")
              { print "     using xml filters : $Filters\n" }
            print TMP "\\starttext\n" ;
            print TMP "\\processXMLfilegrouped{$JobName.$JobSuffix}\n" ;
            print TMP "\\stoptext\n" }
        else
          { print TMP "\\processfile{$JobName}\n" }
        close (TMP) ;
        $JobSuffix = "run" }
    if (-e "$JobName.$JobSuffix")
      { unless ($Dummy) # we don't need this for xml
          { ScanPreamble ("$JobName.$JobSuffix") ;
            if ($ConTeXtInterface eq "unknown")
              { ScanContent ("$JobName.$JobSuffix") } }
        if ($ConTeXtInterface eq "unknown")
          { $ConTeXtInterface = $UserInterface }
        if ($ConTeXtInterface eq "unknown")
          { $ConTeXtInterface = "en" }
        if ($ConTeXtInterface eq "")
          { $ConTeXtInterface = "en" }
       # unless ($JobSuffix eq "tex") # hack, preprocessing will change
       #  { if (lc $Convert eq "xml")
       #      { print "             xml input : $JobName.xml\n" ;
       #        ConvertXMLFile ($JobName) }
       #    elsif (lc $Convert eq "sgml")
       #      { print "            sgml input : $JobName.sgm\n" ;
       #        ConvertSGMLFile ($JobName) } }
        CheckOutputFormat ;
        my $StopRunning = 0 ;
        my $MPrundone = 0 ;
        if ($Format eq '')
          { $Format = "cont-$ConTeXtInterface" }
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        if ($RunPath)
          { print "           source path : $RunPath\n" }
        if ($DummyFile)
          { print "            dummy file : $JobName.$JobSuffix\n" }
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
          { print "          current mode : none\n" }
        if ($Arguments)
          { print "             arguments : $Arguments\n" }
        if ($Modules)
          { print "               modules : $Modules\n" }
        if ($Environments)
          { print "          environments : $Environments\n" }
        if ($Suffix)
          { $Result = "$JobName$Suffix" }
        PushResult($JobName) ;
        $Problems = 0 ;
        my $TeXRuns = 0 ;
        if (($PdfArrange)||($PdfSelect)||($RunOnce))
          { MakeOptionFile (1, 1, $JobName, $OriSuffix) ;
            print "\n" ;
            $Problems = RunTeX($JobName, $JobSuffix) ;
            if ($ForceTeXutil)
              { $Ok = RunTeXutil ($JobName) }
            CopyFile("$JobName.top","$JobName.tmp") ;
            unlink "$JobName.top" ; # runtime option file
            PopResult($JobName) }
        else
          { while (!$StopRunning&&($TeXRuns<$NOfRuns)&&(!$Problems))
             { MakeOptionFile (0, 0, $JobName, $OriSuffix) ;
               ++$TeXRuns ;
               print "               TeX run : $TeXRuns\n\n" ;
               my $mpchecksumbefore = $mpchecksumafter = 0 ;
               if ($AutoMPRun) { $mpchecksumbefore = CheckChanges($JobName) }
               $Problems = RunTeX($JobName,$JobSuffix) ;
               if ($AutoMPRun) { $mpchecksumafter = CheckChanges($JobName) }
               if ((!$Problems)&&($NOfRuns>1))
                 { if (!$NoMPMode)
                     { $MPrundone = RunTeXMP ($JobName, "mpgraph") ;
                       $MPrundone = RunTeXMP ($JobName, "mprun") }
                   $StopRunning = RunTeXutil ($JobName) ;
                   if ($AutoMPRun)
                     { $StopRunning = ($StopRunning &&
                         ($mpchecksumafter==$mpchecksumbefore)) }
                   } }
            if (($NOfRuns==1)&&$ForceTeXutil)
              { $Ok = RunTeXutil ($JobName) }
            if ((!$Problems)&&(($FinalMode||$FinalRunNeeded))&&($NOfRuns>1))
              { MakeOptionFile (1, $FinalMode, $JobName, $OriSuffix) ;
                print "         final TeX run : $TeXRuns\n\n" ;
                $Problems = RunTeX($JobName, $JobSuffix) }
            CopyFile("$JobName.top","$JobName.tmp") ;
            unlink "$JobName.tup" ; # previous tuo file
            unlink "$JobName.top" ; # runtime option file
            PopResult($JobName) }
        if ($DummyFile) # $JobSuffix == run
          { unlink "$JobName.$JobSuffix" } } }

sub RunSomeTeXFile
  { my ($JobName, $JobSuffix) = @_ ;
    if (-e "$JobName.$JobSuffix")
      { PushResult($JobName) ;
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        print "             inputfile : $JobName.$JobSuffix\n" ;
        $Problems = RunTeX($JobName,$JobSuffix) ;
        PopResult($JobName) } }

my $ModuleFile  = "texexec" ;
my $ListingFile = "texexec" ;
my $FiguresFile = "texexec" ;
my $ArrangeFile = "texexec" ;
my $SelectFile  = "texexec" ;
my $CopyFile    = "texexec" ;
my $CombineFile = "texexec" ;

sub RunModule
  { my @FileNames = sort @_ ;
    unless (-e $FileNames[0])
      { my $Name = $FileNames[0] ;
        @FileNames = ("$Name.tex", "$Name.mp", "$Name.pl", "$Name.pm") }
    foreach $FileName (@FileNames)
      { next unless -e $FileName ;
        my ($Name, $Suffix) = split (/\./,$FileName) ;
        next unless $Suffix =~ /(tex|mp|pl|pm)/io ;
        DoRunModule($Name, $Suffix) } }

# the next one can be more efficient: directly process ted
# file a la --use=abr-01,mod-01

sub DoRunModule
  { my ($FileName,$FileSuffix) = @_ ;
    RunPerlScript ($TeXUtil, "--documents $FileName.$FileSuffix" ) ;
    print "                module : $FileName\n\n" ;
    open (MOD, ">$ModuleFile.tex") ;
    # we need to signal to texexec what interface to use
    open(TED, "$FileName.ted") ; my $firstline = <TED> ; close (TED) ;
    if ($firstline =~ /interface=en/)
      { print MOD $firstline }
    else
      { print MOD "% interface=nl\n" }
    # so far
    print MOD "\\usemodule[abr-01,mod-01]\n" ;
    print MOD "\\def\\ModuleNumber{1}\n" ;
    print MOD "\\starttekst\n" ;
    print MOD "\\readlocfile{$FileName.ted}{}{}\n" ;
    print MOD "\\stoptekst\n" ;
    close (MOD) ;
    RunConTeXtFile($ModuleFile, "tex") ;
    if ($FileName ne $ModuleFile)
      { foreach my $FileSuffix ("dvi", "pdf", "tui", "tuo", "log")
          { unlink ("$FileName.$FileSuffix") ;
            rename ("$ModuleFile.$FileSuffix", "$FileName.$FileSuffix") } }
    unlink ("$ModuleFile.tex") }

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
    RunConTeXtFile($FiguresFile, "tex") }

# sub RunGetXMLFigures
#   { return if (($Label eq "") or ($Base  eq "") ;
#     unlink "$FiguresFile.pdf" ;
#     open (FIG, ">$FiguresFile.tex") ;
#     print FIG "% format=english\n" ;
#     print FIG "\\starttext\n" ;
#     print FIG "\\usefigurebase[$Base]\n" ;
#     print FIG "\\pagefigure[$Label]\n" ;
#     print FIG "\\stoptext\n" ;
#     close(FIG) ;
#     $ConTeXtInterface = "en" ;
#     RunConTeXtFile($FiguresFile, "tex") }

sub CleanTeXFileName
  { my $str = shift ;
    $str =~ s/([\$\_\#])/\\$1/go ;
    $str =~ s/([\~])/\\string$1/go ;
    return $str }

sub RunListing
  { my $FileName = my $CleanFileName = shift ;
    my @FileNames = glob $FileName ;
    return unless -f $FileNames[0] ;
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
    print LIS "\\setuptyping[lines=yes]\n" ;
    if ($Pretty)
      { print LIS "\\setuptyping[option=color]\n" }
    foreach $FileName (@FileNames)
      { $CleanFileName = lc CleanTeXFileName($FileName) ;
        print LIS "\\page\n" ;
        print LIS "\\setupfootertexts[$CleanFileName][pagenumber]\n" ;
        print LIS "\\typefile\{$FileName\}\n" }
    print LIS "\\stoptext\n" ;
    close(LIS) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($ListingFile, "tex") }

# sub DetermineNOfPdfPages
#   { my $FileName = shift ;
#     my $NOfPages = 0 ;
#     if (($FileName =~ /\.pdf$/io)&&(open(PDF,$FileName)))
#       { binmode PDF ;
#         my $PagesFound = 0 ;
#         while (<PDF>)
#           { if (/\/Type \/Pages/o)
#               { $PagesFound = 1 }
#             if ($PagesFound)
#               { if (/\/Count\s*(\d*)/o)
#                   { if ($1>$NOfPages) { $NOfPages = $1 } }
#                 elsif (/endobj/o)
#                   { $PagesFound = 0 } } }
#         close ( PDF ) }
#     return $NOfPages }

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
#    if ($PaperFormat ne 'standard')
#      { print "           paperformat : $PaperFormat\n" ;
#        print ARR "\\setuppapersize[$PaperFormat][$PaperFormat]\n" }
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
      { print "               pdffile : $FileName\n" ;
        print ARR "\\insertpages\n  [$FileName]" ;
        if ($AddEmpty ne '') { print ARR "[$AddEmpty]" }
        print ARR "[width=$TextWidth]\n" }
    print ARR "\\stoptext\n" ;
    close (ARR) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($ModuleFile, "tex") }

sub RunSelect
  { my $FileName = shift ;
    print "               pdffile : $FileName\n" ;
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
#      { print "             papersize : $PaperFormat\n" ;
#        print SEL "\\setuppapersize[$PaperFormat][$PaperFormat]\n" }
#
          { $_ = $PaperFormat ; # NO UPPERCASE !
            s/x/\*/io ; my ($from,$to) = split (/\*/) ;
            if ($to eq "") { $to = $from }
            print "             papersize : $PaperFormat\n" ;
            print SEL "\\setuppapersize[$from][$to]\n" }
#
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
    print SEL "\\setupexternalfigures\n" ;
    print SEL "  [directory=]\n" ;
    if ($Selection ne '')
      { print SEL "\\filterpages\n" ;
        print SEL "  [$FileName][$Selection][width=$TextWidth]\n" }
    print SEL "\\stoptext\n" ;
    close (SEL) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($SelectFile, "tex") }

sub RunCopy
  { my $FileName = shift ;
    print "               pdffile : $FileName\n" ;
    if ($PageScale==1000)
      { print "                offset : $PaperOffset\n" }
    else
      { print "                 scale : $PageScale\n" ;
        if ($PageScale<10) { $PageScale = int($PageScale*1000) } }
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
    print COP "\\setupexternalfigures\n" ;
    print COP "  [directory=]\n" ;
    print COP "\\starttext\n" ;
    print COP "\\copypages\n" ;
    print COP "  [$FileName]\n" ;
    print COP "  [scale=$PageScale,\n" ;
    if ($Markings)
      { print COP "   marking=on,\n" ;
        print "           cutmarkings : on\n" }
    print COP "   offset=$PaperOffset]\n" ;
    print COP "\\stoptext\n" ;
    close (COP) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($CopyFile, "tex") }

sub RunCombine
  { my $FileName = shift ;
    print "               pdffile : $FileName\n" ;
    $Combination =~ s/x/\*/io ; my ($nx,$ny) = split (/\*/,$Combination,2) ;
    return unless ($nx&&$ny) ;
    print "           combination : $Combination\n" ;
    open (COM, ">$CombineFile.tex") ;
    print COM "% format=english\n" ;
    if ($PaperFormat ne 'standard')
#      { print "         papersize : $PaperFormat\n" ;
#        print COM "\\setuppapersize\n" ;
#        print COM "  [$PaperFormat][$PaperFormat]\n" }
# see RunSelect
          { $_ = $PaperFormat ; # NO UPPERCASE !
            s/x/\*/io ; my ($from,$to) = split (/\*/) ;
            if ($to eq "") { $to = $from }
            print "             papersize : $PaperFormat\n" ;
            print COM "\\setuppapersize[$from][$to]\n" }
#
    if ($PaperOffset eq '0pt')
      { $PaperOffset = '1cm' }
    my $CleanFileName = CleanTeXFileName($FileName) ;
    print "          paper offset : $PaperOffset\n" ;
    print COM "\\setuplayout\n" ;
    print COM "  [topspace=$PaperOffset,\n" ;
    print COM "   backspace=$PaperOffset,\n" ;
    print COM "   header=0pt,\n" ;
    print COM "   footer=1cm,\n" ;
    print COM "   width=middle,\n" ;
    print COM "   height=middle]\n" ;
    print COM "\\setupfootertexts\n" ;
    print COM "  [$CleanFileName\\space---\\space\\currentdate\\space---\\space\\pagenumber]\n" ;
    print COM "\\setupexternalfigures\n" ;
    print COM "  [directory=]\n" ;
    print COM "\\starttext\n" ;
    print COM "\\combinepages[$FileName][nx=$nx,ny=$ny]\n" ;
    print COM "\\stoptext\n" ;
    close (COM) ;
    $ConTeXtInterface = "en" ;
    RunConTeXtFile($CombineFile, "tex") }

sub LocatedFormatPath
  { my $FormatPath = shift ;
    if (($FormatPath eq '')&&($kpsewhich ne ''))
      { $FormatPath = `$kpsewhich --show-path=fmt` ;
        chomp $FormatPath ;
        $FormatPath =~ s/\.+\;//o ; # should be a sub
        $FormatPath =~ s/\;.*//o ;
        $FormatPath =~ s/\!//go ;
        $FormatPath =~ s/\/\//\//go ;
        $FormatPath =~ s/\\\\/\//go ;
        $FormatPath =~ s/[\/\\]$// ;
        $FormatPath .= '/' ;
        if (($FormatPath ne '')&&$Verbose)
          { print "    located formatpath : $FormatPath\n" } }
    return $FormatPath }

sub RunOneFormat
  { my ($FormatName) = @_ ;
    my @TeXFormatPath ;
    my $TeXPrefix = "" ;
    if (($fmtutil ne "")&&($FormatName !~ /metafun|mptopdf/io))
      { my $cmd = "$fmtutil --byfmt $FormatName" ;
        if ($Verbose) { print "\n$cmd\n\n" }
        MakeUserFile ; # this works only when the path is kept
        MakeResponseFile ;
        $Problems = system ( "$cmd" ) ;
        RemoveResponseFile ;
        RestoreUserFile }
    else
      { $Problems = 1 }
    if ($Problems)
      { if ($TeXExecutable =~ /etex|eetex|pdfetex|pdfeetex/io)
          {$TeXPrefix = "*" }
        my $CurrentPath = cwd() ;
        $TeXFormatPath = LocatedFormatPath($TeXFormatPath) ;
        if ($TeXFormatPath ne '')
          { chdir $TeXFormatPath }
        MakeUserFile ;
        MakeResponseFile ;
        my $cmd = "$TeXProgramPath$TeXExecutable $TeXVirginFlag " .
                  "$TeXPassString $PassOn ${TeXPrefix}$FormatName" ;
        if ($Verbose) { print "\n$cmd\n\n" }
        system ( $cmd ) ;
        RemoveResponseFile ;
        RestoreUserFile ;
        if (($TeXFormatPath ne '')&&($CurrentPath ne ''))
          { chdir $CurrentPath } } }

sub RunFormats
  { my $ConTeXtFormatsPrefix ; my $MetaFunDone = 0 ;
    if (@ARGV)
      { @ConTeXtFormats = @ARGV }
    elsif ($UsedInterfaces ne '')
      { @ConTeXtFormats = split /[\,\s]/,$UsedInterfaces }
    if ($Format)
      { @ConTeXtFormats = $Format; $ConTeXtFormatsPrefix='' ; }
    else
      { $ConTeXtFormatsPrefix="cont-" ; }
    foreach my $Interface (@ConTeXtFormats)
      { if ($Interface eq $MetaFun)
          { RunMpFormat ($MetaFun) ; $MetaFunDone = 1 }
        elsif ($Interface eq $MpToPdf)
          { if ($TeXExecutable =~ /pdf/io) { RunOneFormat ("$MpToPdf") } }
        else
          { RunOneFormat ("$ConTeXtFormatsPrefix$Interface") } }
    #
    # this will be default in a few months, or maybe better:
    # add it as interface (fake -) in texexec.ini
    #
    # if (($ConTeXtFormatsPrefix ne "")&&(!$MetaFunDone))
    #   { RunMpFormat ($MetaFun) } }
    #
    print "\n" ;
    print "            TeX binary : $TeXProgramPath$TeXExecutable\n" ;
    print "             format(s) : @ConTeXtFormats\n\n" }

sub RunMpFormat
  { my $MpFormat = shift ;
    return if ($MpFormat eq '') ;
    my $CurrentPath = cwd() ;
    $MpFormatPath = LocatedFormatPath($MpFormatPath) ;
    if ($MpFormatPath ne '') { chdir "$MpFormatPath" }
    my $cmd = "$MpExecutable $MpVirginFlag $MpPassString $MpFormat" ;
    if ($Verbose) { print "\n$cmd\n\n" }
    system ( $cmd ) ;
    if (($MpFormatPath ne '')&&($CurrentPath ne ''))
      { chdir $CurrentPath } }

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
    elsif ($TypesetModule)
      { RunModule (@ARGV) }
    else
      { my $JobSuffix = "tex" ;
        foreach my $JobName (@ARGV)
          { if ($JobName =~ s/\.(\w+)$//io)
              { $JobSuffix =  $1 }
            if (($Format eq '')||($Format =~ /^cont.*/io))
              { RunConTeXtFile ($JobName, $JobSuffix) }
            else
              { RunSomeTeXFile ($JobName, $JobSuffix) }
            unless (-s "$JobName.log") { unlink ("$JobName.log") }
            unless (-s "$JobName.tui") { unlink ("$JobName.tui") } } } }

my $MpTmp = "tmpgraph"   ;    # todo: prefix met jobname
my $MpKep = "$MpTmp.kep" ;    # sub => MpTmp("kep")
my $MpLog = "$MpTmp.log" ;
my $MpTex = "$MpTmp.tex" ;
my $MpDvi = "$MpTmp.dvi" ;

my %mpbetex ;

sub RunMP ###########
  { if (($MpExecutable)&&($MpToTeXExecutable)&&($DviToMpExecutable))
      { foreach my $RawMpName (@ARGV)
          { my ($MpName, $Rest) = split (/\./, $RawMpName, 2) ;
            my $MpFile = "$MpName.mp" ;
            if (-e $MpFile and (-s $MpFile>25)) # texunlink makes empty file
              { unlink "$MpName.mpt" ;
                doRunMP($MpName,0)  ;
                # test for graphics, new per 14/12/2000
                my $mpgraphics = checkMPgraphics($MpName) ;
                # test for labels
                my $mplabels = checkMPlabels($MpName) ;
                if ($mpgraphics||$mplabels)
                  { doRunMP($MpName,$mplabels) } } } } }

my $mpochecksum = 0 ;

sub checkMPgraphics # also see makempy
  { my $MpName = shift ;
    if ($MpyForce)
      { $MpName .= " --force " } # dirty
    else
      { return 0 unless -s "$MpName.mpo" > 32 ;
        return 0 unless (open (MPO,"$MpName.mpo")) ;
        $mpochecksum = do { local $/ ; unpack("%32C*",<MPO>) % 65535 } ;
        close (MPO) ;
        if (open (MPY,"$MpName.mpy"))
          { my $str = <MPY> ; chomp $str ; close (MPY) ;
            if ($str =~ /^\%\s*mpochecksum\s*\:\s*(\d+)/o)
              { return 0 if (($mpochecksum eq $1)&&($mpochecksum ne 0)) } } }
    RunPerlScript("makempy", "$MpName") ;
    print "  second MP run needed : text graphics found\n" ;
    return 1 }

sub checkMPlabels
  { my $MpName = shift ;
    return 0 unless (-s "$MpName.mpt" > 10) ;
    return 0 unless open(MP, "$MpName.mpt") ;
    my $n = 0 ;
    while (<MP>)
      { if (/% figure (\d+) : (.*)/o)
          { $mpbetex{$1} .= "$2\n" ; ++$n } }
    close (MP) ;
    print "  second MP run needed : $n tex labels found\n" if $n ;
    return $n }

sub doRunMP ###########
  { my ($MpName, $MergeBE) = @_ ;
    my $TexFound = 0 ;
    my $MpFile = "$MpName.mp" ;
    if (open(MP, $MpFile))
      { # fails with %
        # local $/ = "\0777" ; $_ = <MP> ; close(MP) ;

my $MPdata = "" ;
while (<MP>) { unless (/^\%/) { $MPdata .= $_ } }
$_ = $MPdata ;
close (MP) ;

        # save old file
        unlink ($MpKep) ;
        return if (-e $MpKep) ;
        rename ($MpFile, $MpKep) ;
        # check for tex stuff
# $TexFound = $MergeBE || /(btex|etex|verbatimtex)/o ;
# verbatim tex can be there due to an environment belonging to
# mpy (not really, but about)
# $TexFound = $MergeBE || /(btex|etex)/o ;
$TexFound = $MergeBE || /btex .*? etex/o ;
        # shorten lines into new file if okay
        unless (-e $MpFile)
          { open(MP, ">$MpFile") ;
            s/(btex.*?)\;(.*?etex)/$1\@\@\@$2/gmois ;
            s/\;/\;\n/gmois ;
            s/\n\n/\n/gmois ;
            s/(btex.*?)\@\@\@(.*?etex)/$1\;$2/gmois ;
            # merge labels
            if ($MergeBE)
              { s/beginfig\s*\((\d+)\)\s*\;/beginfig($1)\;\n$mpbetex{$1}\n/goims }
            # flush
            unless (/beginfig\s*\(\s*0\s*\)/gmois)
              { print MP $mpbetex{0} }
            print MP $_ ;
            print MP "end .\n" ;
            close(MP) }
        if ($TexFound)
          { print "       metapost to tex : $MpName\n" ;
            $Problems = system ("$MpToTeXExecutable $MpFile > $MpTex" ) ;
            if (-e $MpTex && !$Problems)
              { open (TMP,">>$MpTex") ;
                print TMP "\\end\{document\}\n" ; # to be sure
                close (TMP) ;
                if (($Format eq '')||($Format =~ /^cont.*/io))
                  { $OutputFormat = "dvips" ;
                    RunConTeXtFile ($MpTmp, "tex") }
                else
                  { RunSomeTeXFile ($MpTmp, "tex") }
                    if (-e $MpDvi && !$Problems)
                      { print "       dvi to metapost : $MpName\n" ;
                        $Problems = system ("$DviToMpExecutable $MpDvi $MpName.mpx") }
                    # $Problems = system ("dvicopy $MpDvi texexec.dvi") ;
                    # $Problems = system ("$DviToMpExecutable texexec.dvi $MpName.mpx") }
                    unlink $MpTex ;
                    unlink $MpDvi } }
            print "              metapost : $MpName\n" ;
            my $cmd = $MpExecutable ;
            if ($EnterBatchMode)
              { $cmd .= " $MpBatchFlag " }
            if (($MpFormat ne '')&&($MpFormat !~ /(plain|mpost)/oi))
              { print "                format : $MpFormat\n" ;
                $cmd .= " $MpPassString $MpFormatFlag$MpFormat " }
# prevent nameclash, experimental
my $MpMpName = "$MpName" ;
#my $MpMpName = "./$MpName" ; $MpMpName =~ s/\.\/\.\//\.\//o ;
$Problems = system ("$cmd $MpMpName" ) ;
#            $Problems = system ("$cmd $MpName" ) ;
            open (MPL,"$MpName.log") ;
            while (<MPL>) # can be one big line unix under win
             { while (/^l\.(\d+)\s/gmois)
                { print " error in metapost run : $MpName.mp:$1\n" } }
            unlink "mptrace.tmp" ; rename ($MpFile, "mptrace.tmp") ;
            if (-e $MpKep)
              { unlink ($MpFile) ;
                rename ($MpKep, $MpFile) } } }

sub RunMPX
  { my $MpName = shift ; $MpName =~ s/\..*$//o ;
    my $MpFile = $MpName . ".mp" ;
    if (($MpToTeXExecutable)&&($DviToMpExecutable)&&
        (-e $MpFile)&&(-s $MpFile>5)&&open(MP, $MpFile))
      { local $/ = "\0777" ; $_ = <MP> ; close(MP) ;
        if (/(btex|etex|verbatimtex)/o)
          { print "   generating mpx file : $MpName\n" ;
            $Problems = system ("$MpToTeXExecutable $MpFile > $MpTex" ) ;
            if (-e $MpTex && !$Problems)
              { open (TMP,">>$MpTex") ;
                print TMP "\\end\n" ; # to be sure
                close (TMP) ;
                if (($Format eq '')||($Format =~ /^cont.*/io))
                  { RunConTeXtFile ($MpTmp, "tex") }
                else
                  { RunSomeTeXFile ($MpTmp, "tex") }
                if (-e $MpDvi && !$Problems)
                  { $Problems = system ("$DviToMpExecutable $MpDvi $MpName.mpx") }
           unlink $MpTex ;
           unlink $MpDvi } } } }

sub load_set_file
  { my %new ; my %old ;
    my ($file, $trace) = @_ ;
    if (open(BAT,$file))
      { while (<BAT>)
          { chomp ;
            if (/\s*SET\s+(.+?)\=(.+)\s*/io)
              { my ($var,$val) = ($1, $2) ;
                $val =~ s/\%(.+?)\%/$ENV{$1}/goi ;
                unless (defined($old{$var}))
                  { if (defined($ENV{$var}))
                      { $old{$var} = $ENV{$var} }
                    else
                      { $old{$var} = "" } }
                $ENV{$var} = $new{$var} = $val } }
        close (BAT) }
    if ($trace)
      { foreach my $key (sort keys %new)
          { if ($old{$key} ne $new{$key})
              { print " changing env variable : '$key' from '$old{$key}' to '$new{$key}'\n" }
            elsif ($old{$key} eq "")
              { print "  setting env variable : '$key' to '$new{$key}'\n" }
            else
              { print "  keeping env variable : '$key' at '$new{$key}'\n" } }
        print "\n" } }

if ($SetFile ne "")
  { load_set_file ($SetFile,$Verbose) }

# todo : more consistent argv handling
#
# sub ifargs
#   { $problems = (@ARGV==0) ;
#     if ($problems)
#       { print "               warning : nothing to do\n" }
#     return $problems }

   if ($HelpAsked) 
  { show_help_info } 
elsif ($TypesetListing)
  { RunListing (@ARGV) }
elsif ($TypesetFigures)
  { RunFigures (@ARGV) }
elsif ($DoMPTeX)
  { RunMP }
elsif ($DoMPXTeX)
  { RunMPX ($ARGV[0]) }
elsif ($MakeFormats)
  { if ($MpDoFormat ne '')
      { RunMpFormat($MpDoFormat) }
    else
      { RunFormats } }
elsif (@ARGV)
  { @ARGV = <@ARGV> ; RunFiles }
# else
#   { # print $Help{HELP} ;
#     # unless ($Verbose) { print $Help{VERBOSE} } }
elsif (!$HelpAsked) 
  { show_help_options } 
    
$TotalTime = time - $TotalTime ;

unless ($HelpAsked) 
  { print "\n        total run time : $TotalTime seconds\n" }

if ($Problems) { exit 1 }

__DATA__
arrange process and arrange
-----------
batch run in batch mode (don't pause)
-----------
centerpage center the page on the paper
-----------
color enable color (when not yet enabled)
-----------
usemodule load some modules first
=name list of modules
-----------
xmlfilter apply XML filter
=name list of filters
-----------
environment load some environments first
=name list of environments
-----------
fast skip as much as possible
-----------
figures typeset figure directory
=a room for corrections
=b just graphics
=c one (cropped) per page
paperoffset room left at paper border
-----------
final add a final run without skipping
-----------
format fmt file
=name format file (memory dump) 
-----------
mpformat mem file
=name format file (memory dump) 
-----------
interface user interface
=en English
=nl Dutch
=de German
=cz Czech
=uk Brittish
=it Italian
-----------
language main hyphenation language 
=xx standard abbreviation 
-----------
listing produce a verbatim listing
backspace inner margin of the page
topspace top/bottom margin of the page 
pretty enable pretty printing 
color use color for pretty printing 
-----------
make build format files 
language patterns to include
bodyfont bodyfont to preload
response response interface language
format TeX format
mpformat MetaPost format
program TeX program
-----------
mode running mode 
=list modes to set
-----------
module typeset tex/pl/mp module
-----------
mptex run an MetaPost plus btex-etex cycle
-----------
mpxtex generatet an MetaPostmpx file
-----------
noarrange process but ignore arrange
-----------
nomp don't run MetaPost at all
-----------
nomprun don't run MetaPost at runtime
-----------
automprun MetaPost at runtime when needed
-----------
once run TeX only once (no TeXUtil either)
-----------
output specials to use
=pdftex   Han The Than's pdf backend  
=dvips    Thomas Rokicky's dvi to ps converter
=dvipsone YandY's dvi to ps converter 
=dviwindo YandY's windows previewer
=dvipdfm  Mark Wicks' dvi to pdf converter 
-----------
passon switches to pass to TeX (--src for MikTeX)
-----------
pages pages to output
=odd odd pages
=even even pages
=x,y:z pages x and y to z
-----------
paper paper input and output format
=a4a3 A4 printed on A3
=a5a4 A5 printed on A4
-----------
path document source path
=string path
-----------
pdf produce PDF directly using pdf(e)tex
-----------
pdfarrange arrange pdf pages
paperoffset room left at paper border
paper paper format
noduplex single sided
backspace inner margin of the page
topspace top/bottom margin of the page
markings add cutmarks
background  
=string background graphic
addempty add empty page after
textwidth width of the original (one sided) text
-----------
pdfcombine combine pages to one page
paperformat paper format
combination n*m pages per page
paperoffset room left at paper border
-----------
pdfcopy scale pages down/up
scale new page scale
paperoffset room left at paper border
markings add cutmarks
background 
=string background graphic
-----------
pdfselect select pdf pages
selection pages to select
=odd odd pages
=even even pages
=x,y:z pages x and y to z
paperoffset room left at paper border
paperformat paper format
backspace inner margin of the page
topspace top/bottom margin of the page
markings add cutmarks
background  
=string background graphic
addempty add empty page after
textwidth width of the original (one sided) text
-----------
print page imposition scheme
=up 2 pages per sheet doublesided   
=down 2 rotated pages per sheet doublesided 
-----------
result resulting file 
=name filename 
-----------
input input file (if used)
=name filename 
-----------
suffix resulting file suffix
=string suffix 
-----------
runs maximum number of TeX runs 
=n number of runs
-----------
silent minimize (status) messages
-----------
tex TeX binary 
=name binary of executable 
-----------
verbose shows some additional info 
-----------
help show this or more, e.g. '--help interface'
-----------
alone bypass utilities (e.g. fmtutil for non-standard fmt's)
-----------
texutil force TeXUtil run
-----------
setfile load environment (batch) file
