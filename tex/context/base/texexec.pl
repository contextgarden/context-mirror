#!/usr/bin/perl 
#-w

# nog doen: automatisch log scannen op overfull en missing 
#
# fastmode tzt anders: \iffastmode \fi

#D \module
#D   [       file=texexec.pl,
#D        version=1999.01.07,
#D          title=running \ConTeXt,
#D       subtitle=\TEXEXEC,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This script is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. Non||commercial use is
#C granted.

# sample 'texexec.ini' file 
#
# set UsedInterfaces  to nl,en
# set UserInterface   to nl
# set TeXExecutable   to pdfetex
# set TeXFormatFlag   to & 
# set TeXVirginFlag   to -ini
# set TeXFormatPath   to t:/tex/web2c/fmt/
# set ConTeXtPath     to t:/pragma/sources/
# set SetupPath       to t:/pragma/sources/
# set TeXScriptsPath  to t:/pragma/programs/

use Getopt::Long ;
use Cwd ;
use Time::Local ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

$ConTeXtInterface = "unknown"  ; 
$OutputFormat     = "standard" ; 
$MainLanguage     = "standard" ; 
$PaperFormat      = "standard" ; 
$PrintFormat      = "standard" ; 
$NOfRuns          =  10 ; 
$SetupPath        = "" ;
$Format           = "" ;
$Environment      = "" ; 

$UserInterface    = "en" ; # default
$UsedInterfaces   = "" ;     

&GetOptions
  ( "interface=s"   => \$ConTeXtInterface ,
    "output=s"      => \$OutputFormat     ,
    "language=s"    => \$MainLanguage     ,
    "paper=s"       => \$PaperFormat      ,
    "print=s"       => \$PrintFormat      ,
    "help"          => \$HelpAsked        ,
    "fast"          => \$FastMode         ,
    "nomp"          => \$NoMPMode         ,
    "final"         => \$FinalMode        ,
    "runs=s"        => \$NOfRuns          ,
    "tex=s"         => \$TeXProgram       ,
    "verbose"       => \$Verbose          ,
    "module"        => \$TypesetModule    ,
    "make"          => \$MakeFormats      ,
    "mode=s"        => \$Mode             , 
    "pages=s"       => \$Pages            , 
    "format=s"      => \$Format           ,
    "pdf"           => \$ProducePdf       ,
    "convert=s"     => \$Convert          , 
    "once"          => \$RunOnce          ,
    "batch"         => \$EnterBatchMode   ,
    "color"         => \$UseColor         ,
    "environment=s" => \$Environment      ,
    "result=s"      => \$Result           ) ;

if ($ProducePdf)  { $OutputFormat = "pdf" } 
if ($RunOnce) { $NOfRuns = 1 } 

$Program = " TeXExec 1.1 - ConTeXt / PRAGMA ADE 1997-1999" ;

$Script  = "texexec" ;

print "\n$Program\n\n";

$SIG{INT} = "IGNORE" ;

sub CheckPath 
  { ($Key, $Value) = @_ ;
    if ($Value =~ /\//)
      { $Last = chop $Value ;
        unless ($Last eq "/" ) { $Value = $Value . $Last } 
        unless (-d $Value) 
          { print "                 error : $Key set to unknown path $Value\n" } } }

if ($ENV{TEXEXEC_INI_FILE})
  { $_ = $ENV{TEXEXEC_INI_FILE} }
else
  { $_ = $0 }

s/\.(pl|ini)//io ;

$IniPath = $_ . ".ini" ;

# set <variable> to <value> 
# for <script> set <variable> to <value> 

if (open(INI, $IniPath))
  { if ($Verbose) 
      { print "               reading : $IniPath\n\n" }
    while (<INI>) 
      { if (!/^[a-zA-Z\s]/oi)
          { } 
#        elsif (/for\s+(\w+)\s+set\s+(\w+)\s*to\s*([\w|\:|\/]+)/goi)
        elsif (/for\s+(\S+)\s+set\s+(\S+)\s*to\s*(\S+)/goi)
          { if ($1 eq $Script) # not yet used  
              { if ($Verbose) 
                  { print "               setting : '$2' to '$3' for '$1'\n" }
                $Done{$2} = 1 ; 
                ${$2} = $3 ; CheckPath ($2, $3) } } 
#        elsif (/set\s+(\w+)\s*to\s*([\w|\:|\/|\,]+)/goi)
        elsif (/set\s+(\S+)\s*to\s*(\S+)/goi)
          { unless ($Done{$1})
              { if ($Verbose) 
                  { print "               setting : '$1' to '$2' for 'all'\n" }
                ${$1} = $2 ; CheckPath ($1, $2) } } }
    close (INI) ; 
    if ($Verbose) 
      { print "\n" } } 
else
  { print "               warning : $IniPath not found\n" ;
    exit 1 }

if ($TeXProgram) 
  { $TeXExecutable = $TeXProgram }
elsif (!$TeXExecutable) 
  { $TeXExecutable = "tex" } 

unless ($TeXFormatFlag) { $TeXFormatFlag="&" }  
unless ($TeXVirginFlag) { $TeXVirginFlag="-ini" }

# $_ = $0 ; s/texexec\.pl//io ; $TeXScriptsPath = $_ ;

unless ($TeXScriptsPath) 
  { $_ = $0 ; s/texexec\.pl//io ; $TeXScriptsPath = $_ }

unless ($ConTeXtPath) 
  { $ConTeXtPath = $TeXScriptsPath }

if ($ENV{"HOME"})  
  { if ($SetupPath) { $SetupPath .= "," }
    $SetupPath .= $ENV{"HOME"} } 

$OutputFormats{pdf}      = "pdftex" ;
$OutputFormats{pdftex}   = "pdftex" ;
$OutputFormats{dvips}    = "dvips" ;
$OutputFormats{dvipsone} = "dvipsone" ;
$OutputFormats{acrobat}  = "acrobat" ;
$OutputFormats{dviwindo} = "dviwindo" ;
$OutputFormats{dviview}  = "dviview" ;

@ConTeXtFormats = ("nl", "en", "de", "cz", "uk") ;

$ConTeXtInterfaces{nl} = "nl" ; $ConTeXtInterfaces{dutch}    = "nl" ;
$ConTeXtInterfaces{en} = "en" ; $ConTeXtInterfaces{english}  = "en" ;
$ConTeXtInterfaces{de} = "de" ; $ConTeXtInterfaces{german}   = "de" ;
$ConTeXtInterfaces{cz} = "cz" ; $ConTeXtInterfaces{czech}    = "cz" ;
$ConTeXtInterfaces{uk} = "uk" ; $ConTeXtInterfaces{brittish} = "uk" ;

$Help{HELP} = 
  "                --help   show this or more, e.g. '--help interface'\n" ; 

$Help{LANGUAGE} = 
  "            --language   main hyphenation language \n" ;

$Help{language} = $Help{LANGUAGE} .
  "                           =xx : standard abbreviation \n" ;

$Help{TEX} = 
  "                 --tex   tex binary \n" ;

$Help{tex} = $Help{TEX} .
  "                           =name : binary of executable \n" ;

$Help{FORMAT} = 
  "              --format   fmt file \n" ;

$Help{format} = $Help{FORMAT} .
  "                           =name : format file (memory dump) \n" ;

$Help{MODE}= 
  "                --mode   running mode \n" ;

$Help{mode} = $Help{MODE} .
  "                           =list : modes to set \n" ;

$Help{OUTPUT} = 
  "              --output   specials to use \n" ;

$Help{output} = $Help{OUTPUT} . 
  "                           =pdftex \n" .
  "                           =dvips dvipsone \n" .
  "                           =dviwindo dviview \n" ;

$Help{PAPER} = 
  "               --paper   paper input and output format \n" ;

$Help{paper} = $Help{PAPER} . 
  "                           =a4a3 : A4 printed on A3 \n" .
  "                           =a5a4 : A5 printed on A4 \n" ;

$Help{PRINT} = 
  "               --print   page imposition scheme \n" ;

$Help{PAGES} = 
  "               --pages   pages to output \n" ; 

$Help{paper} = $Help{PAPER} . 
  "                           =odd : odd pages \n" .
  "                           =even : even pages \n" .
  "                           =x,y,z : pages x, y and z \n" ;

$Help{"print"} = $Help{PRINT} . 
  "                           =up : 2 pages per sheet doublesided           \n" .
  "                           =down : 2 rotated pages per sheet doublesided \n" ;

$Help{INTERFACE} = 
  "           --interface   user interface \n" ;

$Help{interface} = $Help{INTERFACE} .
  "                           =en : english  \n" . 
  "                           =nl : dutch    \n" . 
  "                           =de : german   \n" ;
  "                           =cz : czech    \n" ;
  "                           =uk : brittish \n" ;

$Help{RUNS} = 
  "                --runs   maximum number of TeX runs \n" ;

$Help{FAST} = 
  "                --fast   skip as much as possible \n" ;

$Help{NOMP} = 
  "                --nomp   don't run MetaPost \n" ;

$Help{FINAL} = 
  "                --final  add a final run without skipping \n" ;

$Help{MODULE} = 
  "              --module   typeset tex/pl/mp module \n" ;

$Help{MAKE} = 
  "                --make   build format files \n" ;

$Help{VERBOSE} = 
  "             --verbose   shows some additional info \n" ;

$Help{CONVERT} = 
  "             --convert   converts file first \n" ;

$Help{convert} = $Help{CONVERT} .
  "                          =xml : xml => tex \n" . 
  "                         =sgml : sgml => tex \n" ;

$Help{RESULTS} = 
  "             --results   resulting file \n" ;

# nog Result in help 

if ($HelpAsked) 
  { if (@ARGV) 
      { foreach (@ARGV) { print "$Help{$_}\n" } }
    else
      { print $Help{LANGUAGE}    ;  
        print $Help{OUTPUT}      ; 
        print $Help{PRINT}       ;  
        print $Help{PAPER}       ;  
        print $Help{PAGES}       ;  
        print $Help{INTERFACE}   ; 
        print $Help{RUNS}        ;
        print $Help{TEX}         ;
        print $Help{MODE}        ;
        print $Help{FAST}        ;
        print $Help{NOMP}        ;
        print $Help{FINAL}       ;
        print $Help{VERBOSE}     ;
        print $Help{MODULE}      ;
        print $Help{MAKE}        ;
        print $Help{FORMAT}      ;
        print $Help{CONVERT}     ;
        print "\n"               ;
        print $Help{HELP}        ;
        print "\n"               }
    exit 0 } 

$FinalRunNeeded = 0 ; 

sub ConvertXMLFile 
  { ($FileName) = @_ ; 
    system ("sgml2tex $FileName.xml") }

sub ConvertSGMLFile 
  { ($FileName) = @_ ; 
    system ("sgml2tex $FileName.sgm") }

sub MakeOptionFile 
  { ($FinalRun, $FastDisabled) = @_ ; 
    open (OPT, ">cont-opt.tex") ;
    print OPT "\\unprotect\n" ;
    $MainLanguage = lc $MainLanguage ;
    unless ($MainLanguage eq "standard")
      { print OPT "\\setuplanguage[$MainLanguage]\n" }
    $FullFormat = "" ;
    $Ok = 1 ; 
    @OutputFormat = split(/,/,$OutputFormat) ; 
    foreach $Format (@OutputFormat)
      { if ($OutputFormats{lc $Format})
          { if ($FullFormat) { $FullFormat .= "," }  
            $FullFormat .= "$OutputFormats{lc $Format}" }
        elsif ($Format ne "standard") 
          { $Ok = 0 } } 
    if (!$Ok) 
      { print $Help{output} }
    elsif ($FullFormat)
      { print OPT "\\setupoutput[$FullFormat]\n" }
    else 
      { $FullFormat = "standard" } 
    if ($EnterBatchMode) 
      { print OPT "\\batchmode\n" }
    if ($UseColor) 
      { print OPT "\\setupcolors[\\c!status=\\v!start]\n" }
    if ($NoMPMode) 
      { print OPT "\\runMPgraphicsfalse\n" }
    if (($FastMode)&&(!$FastDisabled)) 
      { print OPT "\\fastmode\n" }
    if ($SetupPath) 
      { print OPT "\\setupsystem[\\c!gebied=\{$SetupPath\}]\n" }
    $_ = $PaperFormat ;
    if (/.4.3/goi)
      { print OPT "\\stelpapierformaatin[A4][A3]\n" }
    elsif (/.5.4/goi)
      { print OPT "\\stelpapierformaatin[A5][A4]\n" }
    else
      { unless (/standard/) { print $Help{paper} } } 
    $_ = $PrintFormat ;
    if (/.*up/goi)
      { $FinalRunNeeded = 1 ; 
        if ($FinalRun) 
          { print OPT "\\stelarrangerenin[2UP,\\v!geroteerd,\\v!dubbelzijdig]\n" } }
    elsif (/.*down/goi)  
      { $FinalRunNeeded = 1 ;
        if ($FinalRun) 
          { print OPT "\\stelarrangerenin[2DOWN,\\v!geroteerd,\\v!dubbelzijdig]\n" } } 
    else
      { unless (/standard/goi) { print $Help{"print"} } }
    if ($Mode)
      { print OPT "\\enablemode[$Mode]\n" } 
    if ($Pages)
      { if (lc $Pages eq "odd")
          { print OPT "\\chardef\\whichpagetoshipout=1\n" } 
        elsif (lc $Pages eq "even")
          { print OPT "\\chardef\\whichpagetoshipout=2\n" }
        else
          { print OPT "\\def\\pagestoshipout\{$Pages\}\n" } }
    print OPT "\\protect\n" ;
    if ($Environment) 
      { foreach $E ($Environment) { print OPT "\\omgeving $E\n" } }
    close (OPT) }

sub CompareFiles 
 { $Ok = open (TUO1, $_[0]) && open (TUO2, $_[1]);
   while (($Line1=<TUO1>)&&($Line2=<TUO2>)&&$Ok)
     { $Ok = ($Line1 eq $Line2) }
   close (TUO1) ;
   close (TUO2) ;
   return ($Ok) }  

$ConTeXtVersion = "unknown" ; 
$ConTeXtModes   = "" ; 

sub ScanPreamble
  { my ($FileName) = @_ ; 
    open (TEX, $FileName) ; 
    while (<TEX>) 
     { chomp ;
       if (!$_) 
         { last } 
       elsif (/^\%/) 
         { if (/^\%\&(.*\w)/) 
             { $ConTeXtInterface = $ConTeXtInterfaces{$1} }
           else
             { if (/tex=([a-z]*)/goi)       { $TeXExecutable    = $1 }
               if (/program=([a-z]*)/goi)   { $TeXExecutable    = $1 }
               if (/modes=([a-z\,]*)/goi)   { $ConTeXtModes     = $1 }
               if (/output=([a-z\,]*)/goi)  { $OutputFormat     = $1 }
               if (/format=([a-z]*)/goi)    { $ConTeXtInterface = $ConTeXtInterfaces{$1}  }
               if (/interface=([a-z]*)/goi) { $ConTeXtInterface = $ConTeXtInterfaces{$1}  }
               if (/version=([a-z]*)/goi)   { $ConTeXtVersion   = $1 } } }
       else 
         { last } }
    close(TEX) }

sub ScanContent
  { ($ConTeXtInput) = @_ ; 
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
  { my $StartTime = time ;
    $Problems = system 
      ( "$TeXProgramPath$TeXExecutable " .
        "$TeXFormatFlag$TeXFormatPath$Format $JobName" ) ;
    my $StopTime = time - $StartTime ;
    print "\n              run time : $StopTime\n" ;
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
  { ($JobName) = @_ ;
    $JobName =~ s/\\/\//goi ;
    if (-e "$JobName.tex")
      { if ($ConTeXtInterface eq "unknown") 
          { ScanPreamble ("$JobName.tex") }
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
        MakeOptionFile ( 0, 0 ) ;
        $StopRunning = 0 ;
        $Format = "cont-$ConTeXtInterface" ;
        unless ($FullFormat) { $FullFormat = "standard" } 
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        print "             inputfile : $JobName\n" ; 
        print "                output : $FullFormat\n" ; # OutputFormat\n" ; 
        print "             interface : $ConTeXtInterface\n" ; 
        $Options = "" ; 
        if ($FastMode)      { $Options .= " fast" }    
        if ($FinalMode)     { $Options .= " final" }    
        if ($Verbose)       { $Options .= " verbose" } 
        if ($TypesetModule) { $Options .= " module" }
        if ($MakeFormats)   { $Options .= " make" } 
        if ($RunOnce)       { $Options .= " once" } 
        if ($UseColor)      { $Options .= " color" } 
        if ($EnterBatchMode){ $Options .= " batch" } 
        if ($NoMPMode)      { $Options .= " nomp" }    
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
        while (!$StopRunning&&($TeXRuns<$NOfRuns)) 
          { ++$TeXRuns ;     
            print "               TeX run : $TeXRuns\n\n" ; 
            $Problems = RunTeX() ;
            if ($Problems) 
              { last } 
            if ($NOfRuns>1)
              { unlink "texutil.tuo" ;
                rename "$JobName.tuo", "texutil.tuo" ;
                system
                 ( "perl " . "$TeXScriptsPath" . "texutil.pl " .
                   "--references --ij --high $JobName" ) ;
                $StopRunning = 
                   CompareFiles("texutil.tuo", "$JobName.tuo") } }
        if ((!$Problems)&&(($FinalMode||$FinalRunNeeded))&&($NOfRuns>1)) 
          { MakeOptionFile ( 1 , $FinalMode) ;
            print "         final TeX run : $TeXRuns\n\n" ; 
            $Problems = RunTeX() } 
        PopResult($JobName) } }

sub RunSomeTeXFile 
  { ($JobName) = @_ ;
    if (-e "$JobName.tex")
      { PushResult($JobName) ;
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "                format : $TeXFormatPath$Format\n" ;
        print "             inputfile : $JobName\n" ; 
        $Problems = RunTeX() ;
        PopResult($JobName) } } 

sub RunModule
  { my ($FileName) = @_ ;
    if ((-e "$FileName.tex")||(-e "$FileName.pl")||(-e "$FileName.mp")||
                              (-e "$FileName.pm"))
      { system 
          ( "perl " . "$TeXScriptsPath" . "texutil.pl " .
            "--documents $FileName.pl $FileName.pm $FileName.mp $FileName.tex" ) ;
        print "                module : $FileName\n\n" ;
        open (MOD, ">$Script.tex") ;
        print MOD "% format=dutch        \n" ;
        print MOD "\\starttekst          \n" ;
        print MOD "\\input modu-abr      \n" ;
        print MOD "\\input modu-arg      \n" ;
        print MOD "\\input modu-env      \n" ;
        print MOD "\\input modu-mod      \n" ;
        print MOD "\\input modu-pap      \n" ;
        print MOD "\\input modu-opt      \n" ;
        print MOD "\\def\\ModuleNumber{1}\n" ;
        print MOD "\\input $FileName.ted \n" ;
        print MOD "\\stoptekst           \n" ;
        close (MOD) ; 
        $ConTeXtInterface = "nl" ; 
        RunConTeXtFile($Script) ;
        if ($FileName ne $Script) 
          { foreach $FileSuffix ("dvi", "pdf", "tui", "tuo", "log")
             { unlink ("$FileName.$FileSuffix") ;
               rename ("$Script.$FileSuffix", "$FileName.$FileSuffix") } } 
        unlink ("$Script.tex") } }

sub RunFormats
  { if (@ARGV) 
      { @ConTeXtFormats = @ARGV }
    elsif ($UsedInterfaces ne "")  
      { @ConTeXtFormats = split /\,/,$UsedInterfaces }     
    $CurrentPath = cwd() ;
    if ($TeXExecutable =~ /etex|eetex|pdfetex|pdfeetex/gio)
      {$TeXPrefix = "*" }
    else
      {$TeXPrefix = "" }
    if (chdir "$TeXFormatPath")
      { if ($Format) 
         { system 
            ( "$TeXProgramPath$TeXExecutable " .
              "$TeXVirginFlag " . 
              "${TeXPrefix}$Format" ) ;
           @ConTeXtFormats = $Format } 
        else
         { foreach $Interface (@ConTeXtFormats)
             { system 
                 ( "$TeXProgramPath$TeXExecutable " . 
                   "$TeXVirginFlag " .
                   "${TeXPrefix}cont-$Interface" ) } }  
        print "\n" ;
        print "            executable : $TeXProgramPath$TeXExecutable\n" ;
        print "             format(s) : @ConTeXtFormats\n\n" ;
        chdir $CurrentPath } }

sub RunFiles 
  { foreach $JobName (@ARGV)
      { $JobName =~ s/\.tex//goi ;
        if ($TypesetModule) 
          { unless ($Format) { RunModule ($JobName) } } 
        else 
          { if ($Format) 
              { RunSomeTeXFile ($JobName) }  
            else
              { RunConTeXtFile ($JobName) } } 
    unless (-s "$JobName.log") { unlink ("$JobName.log") }
    unless (-s "$JobName.tui") { unlink ("$JobName.tui") } } }

if ($MakeFormats) 
  { RunFormats } 
elsif (@ARGV) 
  { RunFiles } 
else
  { print $Help{HELP} }

if (-f "cont-opt.tex")
  { unlink ("cont-opt.bak") ; 
    rename ("cont-opt.tex", "cont-opt.bak") }

if ($Problems) { exit 1 }
