eval '(exit $?0)' && eval 'exec perl -w -S $0 ${1+"$@"}' && eval 'exec perl -w -S $0 $argv:q'
  if 0 ;

#D \module
#D   [       file=texexec.pl,
#D        version=2004.08.29,
#D          title=running \ConTeXt,
#D       subtitle=\TEXEXEC,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See readme.pdf for
#C details.

#  Thanks to Tobias  Burnus    for the german translations.
#  Thanks to Thomas  Esser     for hooking it into web2c
#  Thanks to Taco    Hoekwater for suggesting improvements
#  Thanks to Wybo    Dekker    for the advanced help interface and making it strict
#  Thanks to Fabrice Popineau  for windows path trickery and fixes

# (I still have to completely understand the help code -)

#D We started with a hack provided by Thomas Esser. This
#D expression replaces the unix specific line \type
#D {#!/usr/bin/perl}.

#D History has learned that writing wrappers like this is quite painful
#D because of differences between platforms, changes in the tex command
#D line flags (fmt), default behaviour (e.g. 8 bit), and the assumption
#D that everyone runs the same tex and that distributers take care of
#D everything. Well, the result is a messy script like this ... Sorry.

use strict ;

my $OriginalArgs = join(' ',@ARGV) ;

#~ use warnings ; # strange warnings, todo

# todo: second run of checksum of mp file with --nomprun changes
# todo: warning if no args
# todo: <<<< in messages
# todo: cleanup

use Cwd;
use Time::Local;
use Config;
use Getopt::Long;
use Class::Struct;    # needed for help subsystem
use FindBin;
use File::Compare;
use File::Temp;
use Digest::MD5;

#~ use IO::Handle; autoflush STDOUT 1;

my %ConTeXtInterfaces;    # otherwise problems with strict
my %ResponseInterface;    # since i dunno how to allocate else

my %Help;

#D In this script we will launch some programs and other
#D scripts. \TEXEXEC\ uses an ini||file to sort out where
#D those programs are stored. Two boolean variables keep
#D track of the way to call the programs. In \TEXEXEC,
#D \type {$dosish} keeps track of the operating system.
#D It will be no surprise that Thomas Esser provided me
#D the neccessary code to accomplish this.

$ENV{"MPXCOMMAND"} = "0";    # otherwise loop

my $TotalTime = time;

# start random seed hack
#
# This hack is needed since tex has 1 minute resolution, so
# we need to be smaller about 1440 (== 24*60 == tex's max time)
# in which case (david a's) random calculator will overflow.

# my ( $sec, $min, $rest ) = gmtime;
# my $RandomSeed = $min * 60 + $sec;
#
# # i have to look up the mod function -)
#
# if ( $RandomSeed > 2880 ) { $RandomSeed -= 2880 }
# if ( $RandomSeed > 1440 ) { $RandomSeed -= 1440 }

my ($sec, $min) = gmtime;
my $RandomSeed = ($min * 60 + $sec) % 2880; # else still overflow

# See usage of $Random and $RandomSeed later on.
#
# end random seed hack

my $dosish      = ( $Config{'osname'} =~ /^(ms)?dos|^os\/2|^mswin/i );
my $escapeshell = ( ($ENV{'SHELL'}) && ($ENV{'SHELL'} =~ m/sh/i ));

my $TeXUtil   = 'texutil';
my $TeXExec   = 'texexec';
my $MetaFun   = 'metafun';
my $MpToPdf   = 'mptopdf';

$Getopt::Long::passthrough = 1;    # no error message
$Getopt::Long::autoabbrev  = 1;    # partial switch accepted

my $AddEmpty         = '';
my $Alone            = 0;
my $Optimize         = 0;
my $ForceTeXutil     = 0;
my $Arrange          = 0;
my $BackSpace        = '0pt';
my $Background       = '';
my $CenterPage       = 0;
my $ConTeXtInterface = 'unknown';
my $Convert          = '';
my $DoMPTeX          = 0;
my $DoMPXTeX         = 0;
my $EnterBatchMode   = 0;
my $EnterNonStopMode = 0;
my $Environments     = '';
my $Modules          = '';
my $FastMode         = 0;
my $FinalMode        = 0;
my $Format           = '';
my $MpDoFormat       = '';
my $HelpAsked        = 0;
my $Version          = 0;
my $MainBodyFont     = 'standard';
my $MainLanguage     = 'standard';
my $MainResponse     = 'standard';
my $MakeFormats      = 0;
my $Markings         = 0;
my $Mode             = '';
my $NoArrange        = 0;
my $NoDuplex         = 0;
my $NOfRuns          = 8;
my $NoMPMode         = 0;
my $NoMPRun          = 0;
my $NoBanner         = 0;
my $AutoMPRun        = 0;
my $OutputFormat     = 'standard';
my $Pages            = '';
my $PageScale        = '1000';       # == 1.0
my $PaperFormat      = 'standard';
my $PaperOffset      = '0pt';
my $PassOn           = '';
my $PdfArrange       = 0;
my $PdfSelect        = 0;
my $PdfCombine       = 0;
my $PdfOpen          = 0;
my $PdfClose         = 0;
my $AutoPdf          = 0;
my $UseXPdf          = 0;
my $PrintFormat      = 'standard';
my $ProducePdfT      = 0;
my $ProducePdfM      = 0;
my $ProducePdfX      = 0;
my $ProducePdfXTX    = 0;
my $ProducePs        = 0;
my $Input            = "";
my $Result           = '';
my $Suffix           = '';
my $RunOnce          = 0;
my $Selection        = '';
my $Combination      = '2*4';
my $SilentMode       = 0;
my $TeXProgram       = '';
my $TeXTranslation   = '';
my $TextWidth        = '0pt';
my $TopSpace         = '0pt';
my $TypesetFigures   = 0;
my $ForceFullScreen  = 0;
my $ScreenSaver      = 0;
my $TypesetListing   = 0;
my $TypesetModule    = 0;
my $UseColor         = 0;
my $Verbose          = 0;
my $PdfCopy          = 0;
my $PdfTrim          = 0;
my $LogFile          = "";
my $MpyForce         = 0;
my $InpPath          = "";
my $AutoPath         = 0;
my $RunPath          = "";
my $Arguments        = "";
my $Pretty           = 0;
my $SetFile          = "";
my $TeXTree          = "";
my $TeXRoot          = "";
my $Purge            = 0;
my $Separation       = "";
my $ModeFile         = "";
my $GlobalFile       = 0;
my $AllPatterns      = 0;
my $ForceXML         = 0;
my $Random           = 0;
my $Filters          = '';
my $NoMapFiles       = 0 ;
my $Foxet            = 0 ;
my $TheEnginePath    = 0 ;
my $Paranoid         = 0 ;
my $NotParanoid      = 0 ;
my $BoxType          = '' ;
my $Local            = '' ;

my $TempDir          = '' ;

my $StartLine        = 0 ;
my $StartColumn      = 0 ;
my $EndLine          = 0 ;
my $EndColumn        = 0 ;

my $MpEngineSupport  = 0 ; # not now, we also need to patch executemp in context itself

# makempy :

my $MakeMpy = '';

&GetOptions(
    "arrange"        => \$Arrange,
    "batch"          => \$EnterBatchMode,
    "nonstop"        => \$EnterNonStopMode,
    "color"          => \$UseColor,
    "centerpage"     => \$CenterPage,
    "convert=s"      => \$Convert,
    "environments=s" => \$Environments,
    "usemodules=s"   => \$Modules,
    "xml"            => \$ForceXML,
    "xmlfilters=s"   => \$Filters,
    "fast"           => \$FastMode,
    "final"          => \$FinalMode,
    "format=s"       => \$Format,
    "mpformat=s"     => \$MpDoFormat,
    "help"           => \$HelpAsked,
    "version"        => \$Version,
    "interface=s"    => \$ConTeXtInterface,
    "language=s"     => \$MainLanguage,
    "bodyfont=s"     => \$MainBodyFont,
    "results=s"      => \$Result,
    "response=s"     => \$MainResponse,
    "make"           => \$MakeFormats,
    "mode=s"         => \$Mode,
    "module"         => \$TypesetModule,
    "figures=s"      => \$TypesetFigures,
    "fullscreen"     => \$ForceFullScreen,
    "screensaver"    => \$ScreenSaver,
    "listing"        => \$TypesetListing,
    "mptex"          => \$DoMPTeX,
    "mpxtex"         => \$DoMPXTeX,
    "noarrange"      => \$NoArrange,
    "nomp"           => \$NoMPMode,
    "nomprun"        => \$NoMPRun,
    "nobanner"       => \$NoBanner,
    "automprun"      => \$AutoMPRun,
    "once"           => \$RunOnce,
    "output=s"       => \$OutputFormat,
    "pages=s"        => \$Pages,
    "paper=s"        => \$PaperFormat,
    "paperformat=s"  => \$PaperFormat,
    "passon=s"       => \$PassOn,
    "path=s"         => \$InpPath,
    "autopath"       => \$AutoPath,
    "pdf"            => \$ProducePdfT,
    "pdm"            => \$ProducePdfM,
    "dpm"            => \$ProducePdfM,
    "pdx"            => \$ProducePdfX,
    "dpx"            => \$ProducePdfX,
    "xtx"            => \$ProducePdfXTX,
    "ps"             => \$ProducePs,
    "pdfarrange"     => \$PdfArrange,
    "pdfselect"      => \$PdfSelect,
    "pdfcombine"     => \$PdfCombine,
    "pdfcopy"        => \$PdfCopy,
    "pdftrim"        => \$PdfTrim,
    "scale=s"        => \$PageScale,
    "selection=s"    => \$Selection,
    "combination=s"  => \$Combination,
    "noduplex"       => \$NoDuplex,
    "offset=s"       => \$PaperOffset,
    "paperoffset=s"  => \$PaperOffset,
    "backspace=s"    => \$BackSpace,
    "topspace=s"     => \$TopSpace,
    "markings"       => \$Markings,
    "textwidth=s"    => \$TextWidth,
    "addempty=s"     => \$AddEmpty,
    "background=s"   => \$Background,
    "logfile=s"      => \$LogFile,
    "print=s"        => \$PrintFormat,
    "suffix=s"       => \$Suffix,
    "runs=s"         => \$NOfRuns,
    "silent"         => \$SilentMode,
    "tex=s"          => \$TeXProgram,
    "verbose"        => \$Verbose,
    "alone"          => \$Alone,
    "optimize"       => \$Optimize,
    "texutil"        => \$ForceTeXutil,
    "mpyforce"       => \$MpyForce,
    "input=s"        => \$Input,
    "arguments=s"    => \$Arguments,
    "pretty"         => \$Pretty,
    "setfile=s"      => \$SetFile, # obsolete
    "purge"          => \$Purge,
    #### yet undocumented #################
    "runpath=s"      => \$RunPath,
    "random"         => \$Random,
    "makempy=s"      => \$MakeMpy,
    "allpatterns"    => \$AllPatterns,
    "separation=s"   => \$Separation,
    "textree=s"      => \$TeXTree,
    "texroot=s"      => \$TeXRoot,
    "translate=s"    => \$TeXTranslation,
    "pdfclose"       => \$PdfClose,
    "pdfopen"        => \$PdfOpen,
    "autopdf"        => \$AutoPdf,
    "xpdf"           => \$UseXPdf,
    "modefile=s"     => \$ModeFile,         # additional modes file
    "globalfile"     => \$GlobalFile,
    "nomapfiles"     => \$NoMapFiles,
    "foxet"          => \$Foxet,
    "engine"         => \$TheEnginePath,
    "paranoid"       => \$Paranoid,
    "notparanoid"    => \$NotParanoid,
    "boxtype=s"      => \$BoxType, # media art crop bleed trim
    "local"          => \$Local,
    #### unix is unsafe (symlink viruses)
    "tempdir=s"      => \$TempDir,
    #### experiment
    "startline=s"    => \$StartLine,
    "startcolumn=s"  => \$StartColumn,
    "endline=s"      => \$EndLine,
    "endcolumn=s"    => \$EndColumn
);                                          # don't check name

if ($Foxet) {
    $ProducePdfT = 1 ;
    $ForceXML    = 1 ;
    $Modules     = "foxet" ;
    $Purge       = 1 ;
}

# a set file (like blabla.bat) can set paths now

if ( $SetFile ne "" ) { load_set_file( $SetFile, $Verbose ); $SetFile = "" }

# later we will do a second attempt.

$SIG{INT} = "IGNORE";

if ( $ARGV[0] && $ARGV[0] =~ /\.mpx$/io ) {    # catch -tex=.... bug in mpost
    $TeXProgram = '';
    $DoMPXTeX   = 1;
    $NoMPMode   = 1;
}

####

if ($Version) {
    $Purge = 1 ;
    }

####

if ($Paranoid) {
    $ENV{shell_escape} = 'f' ;
    $ENV{openout_any}  = 'p' ;
    $ENV{openin_any}   = 'p' ;
} elsif ($NotParanoid) {
    $ENV{shell_escape} = 't' ;
    $ENV{openout_any}  = 'p' ;
    $ENV{openin_any}   = 'a' ;
}

if (defined $ENV{openin_any} && $ENV{openin_any} eq 'p') {
    $Paranoid = 1 ; # extra test in order to set readlevel
}

if ((defined $ENV{shell_escape} && $ENV{shell_escape} eq 'f') ||
    (defined $ENV{SHELL_ESCAPE} && $ENV{SHELL_ESCAPE} eq 'f')) {
    $AutoMPRun = 1 ;
}

if ($ScreenSaver) {
    $ForceFullScreen = 1;
    $TypesetFigures  = 'c';
    $ProducePdfT     = 1;
    $Purge           = 1;
}

if ( $DoMPTeX || $DoMPXTeX ) {
    $RunOnce       = 1;
    $ProducePdfT   = 0;
    $ProducePdfX   = 0;
    $ProducePdfM   = 0;
    $ProducePdfXTX = 0;
    $ProducePs     = 0;
}

if ( $PdfArrange || $PdfSelect || $PdfCopy || $PdfTrim || $PdfCombine ) {
    $ProducePdfT = 1;
    $RunOnce     = 1;
}

if    ($ProducePdfT)   { $OutputFormat = "pdftex" }
elsif ($ProducePdfM)   { $OutputFormat = "dvipdfm" }
elsif ($ProducePdfX)   { $OutputFormat = "dvipdfmx" }
elsif ($ProducePdfXTX) { $OutputFormat = "xetex" }
elsif ($ProducePs)     { $OutputFormat = "dvips" }

if ( $ProducePdfXTX ) {
    $TeXProgram = 'xetex'  ; # ignore the default pdfetex engine
    $PassOn .= ' -no-pdf ' ; # Adam Lindsay's preference
}

if ($AutoPdf) {
    $PdfOpen = $PdfClose = 1 ;
}

my $PdfOpenCall = "" ;

if ($PdfOpen) {
    $PdfOpenCall = "pdfopen --file" ;
}

if ($UseXPdf && !$dosish) {
    $PdfOpenCall = "xpdfopen" ;
}

# this is our hook into paranoid path extensions, assumes that
# these three vars are part of path specs in texmf.cnf

foreach my $i ('TXRESOURCES','MPRESOURCES','MFRESOURCES') {
    foreach my $j ($RunPath,$InpPath) {
        if ($j ne '') {
            if ($ENV{$i} ne '') {
                $ENV{$i} = $ENV{$i} . ',' . $j ;
            } else {
                $ENV{$i} = $j ;
            }
        }
    }
}

if ( $RunOnce || $Pages || $TypesetFigures || $TypesetListing ) { $NOfRuns = 1 }

if ( ( $LogFile ne '' ) && ( $LogFile =~ /\w+\.log$/io ) ) {
    open( LOGFILE, ">$LogFile" );
    *STDOUT = *LOGFILE;
    *STDERR = *LOGFILE;
}

my $Program = " TeXExec 5.4.3 - ConTeXt / PRAGMA ADE 1997-2005";

print "\n$Program\n\n";

if ($Verbose) { print "          current path : " . cwd . "\n" }

my $pathslash = '/';
if ( $FindBin::Bin =~ /\\/ ) { $pathslash = "\\" }
my $cur_path = ".$pathslash";

# we need to handle window's "Program Files" path (patch by Fabrice P)

my $own_path  = "$FindBin::Bin/";
my $own_type  = $FindBin::Script;
my $own_quote = ( $own_path =~ m/^[^\"].* / ? "\"" : "" );
my $own_stub  = "";

if ( $own_type =~ /(\.pl|perl)/oi ) { $own_stub = "perl " }

if ( $own_type =~ /(\.(pl|bin|exe))$/io ) { $own_type = $1 }
else { $own_type = '' }

sub checked_path {
    my $path = shift;
    if ( ( defined($path) ) && ( $path ne '' ) ) {
        $path =~ s/[\/\\]/$pathslash/go;
        $path =~ s/[\/\\]*$//go;
        $path .= $pathslash;
    } else {
        $path = '';
    }
    return $path;
}

sub checked_file {
    my $path = shift;
    if ( ( defined($path) ) && ( $path ne '' ) ) {
        $path =~ s/[\/\\]/$pathslash/go;
    } else {
        $path = '';
    }
    return $path;
}

sub CheckPath {
    my ( $Key, $Value ) = @_;
    if ( ( $Value =~ /\// ) && ( $Value !~ /\;/ ) )    # no multipath test yet
    {
        $Value = checked_path($Value);
        unless ( -d $Value ) {
            print "                 error : $Key set to unknown path $Value\n";
        }
    }
}

# set <variable> to <value>
# for <script> set <variable> to <value>
# except for <script> set <variable> to <value>

my $IniPath = '';

#D The kpsewhich program is not available in all tex distributions, so
#D we have to locate it before running it (as suggested by Thomas).

my @paths;

if ( $ENV{PATH} =~ /\;/ ) { @paths = split( /\;/, $ENV{PATH} ) }
else { @paths = split( /\:/, $ENV{PATH} ) }

my $kpsewhich = '';

sub found_ini_file {
    my $suffix = shift ;
    #~ $IniPath = $0 ;
    #~ $IniPath ~= s/\.pl$//io ;
    #~ $IniPath = $InPath . ".'" + $suffix ;
    #~ if (-e $IniPath) {
    #~ }
    # not really needed to check on texmfscripts, better on own path
    print "     locating ini file : kpsewhiching texexec.$suffix on scripts\n" if $Verbose ;
    my $IniPath = `$kpsewhich --format="texmfscripts" -progname=context texexec.$suffix` ;
    chomp($IniPath) ;
    if ($IniPath eq '') {
        print "     locating ini file : kpsewhiching texexec.$suffix elsewhere\n" if $Verbose ;
        $IniPath = `$kpsewhich --format="other text files" -progname=context texexec.$suffix` ;
        chomp($IniPath) ;
    }
    return $IniPath ;
}

if ( $IniPath eq '' ) {
    foreach (@paths) {
        my $p = checked_path($_) . 'kpsewhich';
        if ( ( -e $p ) || ( -e $p . '.exe' ) ) {
            $kpsewhich = $p;
            # FP: catch spurious error messages here if there $p has
            # spaces and $own_quote is not set
            $kpsewhich = ($kpsewhich =~ m/^[^\"].* / ? "\"$kpsewhich\"" : "$kpsewhich") ;
            $IniPath   = found_ini_file("ini");
            unless ( -e $IniPath ) { $IniPath = found_ini_file("rme") }
            last;
        }
    }
    if ($Verbose) {
        if ( $kpsewhich eq '' ) {
            print "     locating ini file : kpsewhich not found in path\n";
        } elsif ( $IniPath eq '' ) {
            print "     locating ini file : not found by kpsewhich\n";
        } else {
            if ( $IniPath =~ /rme/oi ) {
                print "     locating ini file : not found by kpsewhich, using '.rme' file\n";
            } else {
                print "     locating ini file : found by kpsewhich\n";
            }
        }
    }
}

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

use File::Find;
# use File::Copy ; no standard in perl

my ( $ReportPath, $ReportName, $ReportFile ) = ( 0, 0, 1 );
my ( $FileToLocate, $PathToStartOn ) = ( '', '' );
my ( $LocatedPath, $LocatedName, $LocatedFile ) = ( '', '', '' );

sub DoLocateFile {    # we have to keep on pruning
    if ( lc $_ eq $FileToLocate ) {
        $LocatedPath = $File::Find::dir;
        $LocatedName = $_;
        $LocatedFile = $File::Find::name;
    }
    if ($LocatedName) { $File::Find::prune = 1 }
}

sub LocatedFile {
    $PathToStartOn = shift;
    $FileToLocate  = lc shift;
    if ( $FileToLocate eq '' ) {
        $FileToLocate  = $PathToStartOn;
        $PathToStartOn = $own_path;
    }
    ( $LocatedPath, $LocatedName, $LocatedFile ) = ( '', '', '' );
    if ( $FileToLocate ne '' ) {
        if ( -e $cur_path . $FileToLocate ) {
            $LocatedPath = $cur_path;
            $LocatedName = $FileToLocate;
            $LocatedFile = $cur_path . $FileToLocate;
        } else {
            $_ = checked_path($PathToStartOn);
            if ( -e $_ . $FileToLocate ) {
                $LocatedPath = $_;
                $LocatedName = $FileToLocate;
                $LocatedFile = $_ . $FileToLocate;
            } else {
                $_ = checked_path($PathToStartOn);
                if (/(.*?[\/\\]texmf[\/\\]).*/i) {
                    my $SavedRoot = $1;
                    File::Find::find( \&DoLocateFile,
                        checked_path( $1 . 'context/' ) );
                    unless ($LocatedFile) {
                        File::Find::find( \&DoLocateFile, $SavedRoot );
                    }
                } else {
                    $_ = checked_path($_);
                    File::Find::find( \&DoLocateFile, $_ );
                }
            }
        }
    }
    return ( $LocatedPath, $LocatedName, $LocatedFile );
}

#D So now we can say:

unless ($IniPath) {
    ( $LocatedPath, $LocatedName, $IniPath ) =
      LocatedFile( $own_path, 'texexec.ini' );
    if ($Verbose) {
        if ( $IniPath eq '' ) {
            print "     locating ini file : not found by searching\n";
        } else {
            print "     locating ini file : found by searching\n";
        }
    }
}

#D The last resorts:

unless ($IniPath) {
    if ( $ENV{TEXEXEC_INI_FILE} ) {
        $IniPath = checked_path( $ENV{TEXEXEC_INI_FILE} ) . 'texexec.ini';
        unless ( -e $IniPath ) { $IniPath = '' }
    }
    if ($Verbose) {
        if ( $IniPath eq '' ) {
            print "     locating ini file : no environment variable set\n";
        } else {
            print "     locating ini file : found by environment variable\n";
        }
    }
}

unless ($IniPath) {
    $IniPath = $own_path . 'texexec.ini';
    unless ( -e $IniPath ) { $IniPath = '' }
    if ($Verbose) {
        if ( $IniPath eq '' ) {
            print "     locating ini file : not found in own path\n";
        } else {
            print "     locating ini file : found in own path\n";
        }
    }
}

#D Now we're ready for loading the initialization file! We
#D also define some non strict variables. Using \type {$Done}
#D permits assignments.

my %Done;

unless ($IniPath) { $IniPath = 'texexec.ini' }

if ( open( INI, $IniPath ) ) {
    if ($Verbose) { print "               reading : $IniPath\n" }
    while (<INI>) {
        if ( !/^[a-zA-Z\s]/oi ) { }
        elsif (/except for\s+(\S+)\s+set\s+(\S+)\s*to\s*(.*)\s*/goi) {
            my $one   = $1;
            my $two   = $2;
            my $three = $3;
            if ( $one ne $Done{"TeXShell"} ) {
                $three =~ s/^[\'\"]//o;
                $three =~ s/[\'\"]$//o;
                $three =~ s/\s*$//o;
                if ($Verbose) {
                    print "               setting : '$two' to '$three' except for '$one'\n";
                }
                $Done{"$two"} = $three;
                CheckPath( $two, $three );
            }
        } elsif (/for\s+(\S+)\s+set\s+(\S+)\s*to\s*(.*)\s*/goi) {
            my $one   = $1;
            my $two   = $2;
            my $three = $3;
            $three =~ s/\s*$//o;
            if ( $one eq $Done{"TeXShell"} ) {
                $three =~ s/^[\'\"]//o;
                $three =~ s/[\'\"]$//o;
                if ($Verbose) {
                    print
"               setting : '$two' to '$three' for '$one'\n";
                }
                $Done{"$two"} = $three;
                CheckPath( $two, $three );
            }
        } elsif (/set\s+(\S+)\s*to\s*(.*)\s*/goi) {
            my $one = $1;
            my $two = $2;
            unless ( defined( $Done{"$one"} ) ) {
                $two =~ s/^[\'\"]//o;
                $two =~ s/[\'\"]$//o;
                $two =~ s/\s*$//o;
                if ($Verbose) {
                    print
                      "               setting : '$one' to '$two' for 'all'\n";
                }
                $Done{"$one"} = $two;
                CheckPath( $one, $two );
            }
        }
    }
    close(INI);
    if ($Verbose) { print "\n" }
} elsif ($Verbose) {
    print
      "               warning : $IniPath not found, did you read 'texexec.rme'?\n";
    exit 1;
} else {
    print
      "               warning : $IniPath not found, try 'texexec --verbose'\n";
    exit 1;
}

sub IniValue {
    my ( $Key, $Default ) = @_;
    if ( defined( $Done{$Key} ) ) { $Default = $Done{$Key} }
    if ($Default =~ /^(true|yes|on)$/io) {
        $Default = 1 ;
    } elsif ($Default =~ /^(false|no|off)$/io) {
        $Default = 0 ;
    }
    if ($Verbose) { print "          used setting : $Key = $Default\n" }
    return $Default;
}

my $TeXShell          = IniValue( 'TeXShell',          '' );
my $SetupPath         = IniValue( 'SetupPath',         '' );
my $UserInterface     = IniValue( 'UserInterface',     'en' );
my $UsedInterfaces    = IniValue( 'UsedInterfaces',    'en' );
my $TeXFontsPath      = IniValue( 'TeXFontsPath',      '.' );
my $MpExecutable      = IniValue( 'MpExecutable',      'mpost' );
my $MpToTeXExecutable = IniValue( 'MpToTeXExecutable', 'mpto' );
my $DviToMpExecutable = IniValue( 'DviToMpExecutable', 'dvitomp' );
my $TeXProgramPath    = IniValue( 'TeXProgramPath',    '' );
my $TeXFormatPath     = IniValue( 'TeXFormatPath',     '' );
my $ConTeXtPath       = IniValue( 'ConTeXtPath',       '' );
my $TeXScriptsPath    = IniValue( 'TeXScriptsPath',    '' );
my $TeXHashExecutable = IniValue( 'TeXHashExecutable', '' );
my $TeXExecutable     = IniValue( 'TeXExecutable',     'tex' );
my $TeXVirginFlag     = IniValue( 'TeXVirginFlag',     '-ini' );
my $TeXBatchFlag      = IniValue( 'TeXBatchFlag',      '-interaction=batchmode' );
my $TeXNonStopFlag    = IniValue( 'TeXNonStopFlag',    '-interaction=nonstopmode' );
my $MpBatchFlag       = IniValue( 'MpBatchFlag',       '-interaction=batchmode' );
my $MpNonStopFlag     = IniValue( 'MpNonStopFlag',     '-interaction=nonstopmode' );
my $TeXPassString     = IniValue( 'TeXPassString',     '' );
my $TeXFormatFlag     = IniValue( 'TeXFormatFlag',     '' );
my $MpFormatFlag      = IniValue( 'MpFormatFlag',      '' );
my $MpVirginFlag      = IniValue( 'MpVirginFlag',      '-ini' );
my $MpPassString      = IniValue( 'MpPassString',      '' );
my $MpFormat          = IniValue( 'MpFormat',          $MetaFun );
my $MpFormatPath      = IniValue( 'MpFormatPath',      $TeXFormatPath );
my $UseEnginePath     = IniValue( 'UseEnginePath',     '');

if ($TheEnginePath) { $UseEnginePath = 1 }

# ok, let's force the engine; let's also forget about
# fmtutil, since it does not support $engine subpaths
# we will replace texexec anyway

$UseEnginePath = 1 ;
$Alone         = 1 ;

my $FmtLanguage = IniValue( 'FmtLanguage', '' );
my $FmtBodyFont = IniValue( 'FmtBodyFont', '' );
my $FmtResponse = IniValue( 'FmtResponse', '' );
my $TcXPath     = IniValue( 'TcXPath',     '' );


$SetFile = IniValue( 'SetFile', $SetFile );

if ( ($Verbose) && ( $kpsewhich ne '' ) ) {
    print "\n";
    my $CnfFile = `$kpsewhich -progname=context texmf.cnf`;
    chomp($CnfFile);
    print " applications will use : $CnfFile\n";
}

if ( ($FmtLanguage) && ( $MainLanguage eq 'standard' ) ) {
    $MainLanguage = $FmtLanguage;
}
if ( ($FmtBodyFont) && ( $MainBodyFont eq 'standard' ) ) {
    $MainBodyFont = $FmtBodyFont;
}
if ( ($FmtResponse) && ( $MainResponse eq 'standard' ) ) {
    $MainResponse = $FmtResponse;
}

# new versions, > 2004 will have -fmt as switch

if ( $TeXFormatFlag eq "" ) {
    if ($TeXProgram =~ /(etex|pdfetex)/) {
        $TeXFormatFlag = "-efmt=" ; # >=2004 -fmt=
    } elsif ($TeXProgram =~ /(eomega)/) {
        $TeXFormatFlag = "-eoft=" ; # >=2004 obsolete
    } elsif ($TeXProgram =~ /(aleph)/) {
        $TeXFormatFlag = "-fmt=" ;
    } else {
        $TeXFormatFlag = "-fmt=" ;
    }
}

if ( $MpFormatFlag eq "" ) {
        $MpFormatFlag = "-mem=" ;
}

if ($TeXProgram) { $TeXExecutable = $TeXProgram }

my $fmtutil = '';

# obsolete
#
# if ( $MakeFormats || $Verbose ) {
#     if ($Alone || $UseEnginePath) {
#         if ($Verbose) { print "     generating format : not using fmtutil\n" }
#     } elsif ( $TeXShell =~ /tetex|fptex/i ) {
#         foreach (@paths) {
#             my $p = checked_path($_) . 'fmtutil';
#             if    ( -e $p )          { $fmtutil = $p;          last }
#             elsif ( -e $p . '.exe' ) { $fmtutil = $p . '.exe'; last }
#         }
#      	$fmtutil = ($fmtutil =~ m/^[^\"].* / ? "\"$fmtutil\"" : "$fmtutil") ;
#         if ($Verbose) {
#             if ( $fmtutil eq '' ) {
#                 print "      locating fmtutil : not found in path\n";
#             } else {
#                 print "      locating fmtutil : $fmtutil\n";
#             }
#         }
#     }
# }

if ($Verbose) { print "\n" }

unless ($TeXScriptsPath) { $TeXScriptsPath = $own_path }

unless ($ConTeXtPath) { $ConTeXtPath = $TeXScriptsPath }

if ( $ENV{"HOME"} ) {
    if ($SetupPath) { $SetupPath .= "," }
#     my $home = $ENV{"HOME"};
#     $home = ($home =~ m/^[^\"].* / ? "\"$home\"" : "$home") ;
#     $SetupPath .= $home;
    $SetupPath .= $ENV{"HOME"};
}

if ($TeXFormatPath)  { $TeXFormatPath  =~ s/[\/\\]$//; $TeXFormatPath  .= '/' }
if ($MpFormatPath)   { $MpFormatPath   =~ s/[\/\\]$//; $MpFormatPath   .= '/' }
if ($ConTeXtPath)    { $ConTeXtPath    =~ s/[\/\\]$//; $ConTeXtPath    .= '/' }
if ($SetupPath)      { $SetupPath      =~ s/[\/\\]$//; $SetupPath      .= '/' }
if ($TeXScriptsPath) { $TeXScriptsPath =~ s/[\/\\]$//; $TeXScriptsPath .= '/' }

sub QuotePath {
  my ($path) = @_;
  my @l = split(",", $path);
  map { my $e = $_; $e = ($e =~ m/^[^\"].* / ? "\"$e\"" : "$e"); $_ = $e ;} @l;
  return join(",", @l);
}

$SetupPath = &QuotePath($SetupPath);

$SetupPath =~ s/\\/\//go;

my %OutputFormats;

# the mother of all drivers

$OutputFormats{dvips}    = "dvips";

# needs an update

$OutputFormats{acrobat}  = "acrobat";

# the core drivers

$OutputFormats{pdftex}   = "pdftex";    $OutputFormats{pdf}      = "pdftex";
$OutputFormats{dvipdfm}  = "dvipdfm";   $OutputFormats{dpm}      = "dvipdfm";
$OutputFormats{dvipdfmx} = "dvipdfmx";  $OutputFormats{dpx}      = "dvipdfmx";
$OutputFormats{xetex}    = "xetex";     $OutputFormats{xtx}      = "xetex";
$OutputFormats{dvips}    = "dvips";     $OutputFormats{ps}       = "dvips";

# kind of obsolete now that yandy is gone

$OutputFormats{dvipsone} = "dvipsone";
$OutputFormats{dviwindo} = "dviwindo";

# it was never finished

$OutputFormats{dviview}  = "dviview";

my @ConTeXtFormats = ( "nl", "en", "de", "fr", "cz", "uk", "it", "ro", "xx");

sub SetInterfaces {
    my ( $short, $long, $full ) = @_;
    $ConTeXtInterfaces{$short} = $short;
    $ConTeXtInterfaces{$long}  = $short;
    $ResponseInterface{$short} = $full;
    $ResponseInterface{$long}  = $full;
}

#SetInterfaces ( "en" , "unknown"      , "english"   ) ;

SetInterfaces( "nl", "dutch",        "dutch" );
SetInterfaces( "en", "english",      "english" );
SetInterfaces( "de", "german",       "german" );
SetInterfaces( "fr", "french",       "french" );
SetInterfaces( "cz", "czech",        "czech" );
SetInterfaces( "uk", "british",      "english" );
SetInterfaces( "it", "italian",      "italian" );
SetInterfaces( "no", "norwegian",    "norwegian" );
SetInterfaces( "ro", "romanian",     "romanian" );

# Sub-option

struct Subopt => {
    desc => '$',    # description
    vals => '%'     # assignable values
};

# Main option

struct Opt => {
    desc => '$',    # desciption
    vals => '%',    # assignable values
    subs => '%'     # suboptions
};

my $helpdone = 0;

sub print_subopt {
    my ( $k, $opt ) = @_;
    $~ = 'H3';
    write;
    for $k ( sort keys %{ $opt->vals } ) {
        print_val( $k, ${ $opt->vals }{$k} );
    }
    format H3 =
@>>>>>>>>>>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"--$k",$opt->desc
.
}

sub print_val {
    my ( $k, $opt ) = @_;
    $~ = 'H2';
    write;
    format H2 =
                           @<<<<<<<< : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$k,$opt
.
}

# read all options

my $recurse = -1 ;
my $shorthelp;
my @help;
my @opts = <DATA>;
while (@opts) {
    $_ = shift @opts;
    last if /^--+/;
    my ( $k, $v ) = split( /\s+/, $_, 2 );    # was \t
    $Help{$k} = read_options($v);
}

# read a main option plus its
#   description,
#   assignable values and
#     sub-options and their
#       description and
#       assignable values

sub read_options {
    $recurse++;
    my $v = shift;
    chomp;
    my $opt = $recurse ? Subopt->new() : Opt->new();
    $opt->desc($v);

    while (@opts) {
        $_ = shift @opts;
        if (/^--+/) { unshift @opts, $_ if $recurse; last }
        if ( $recurse && !/^=/ ) { unshift @opts, $_; last }
        chomp;
        my ( $kk, $vv ) = split( /\s+/, $_, 2 );    # was \t
        $vv ||= '';
        if (/^=/) { $opt->vals( $kk, $vv ) }
        elsif ( !$recurse ) { $opt->subs( $kk, read_options($vv) ) }
    }
    $recurse--;
    $opt;
}

sub print_opt {
    my ( $k, $opt ) = @_;
    if ($helpdone) { $shorthelp or print "\n" }
    $helpdone = 1;                                  # hh
    $~        = 'H1';
    write;
    return if $shorthelp < 0;
    for $k ( sort keys %{ $opt->vals } ) {
        print_val( $k, ${ $opt->vals }{$k} );
    }
    return if $shorthelp > 0;

    for $k ( sort keys %{ $opt->subs } ) {
        print_subopt( $k, ${ $opt->subs }{$k} );
    }
    format H1 =
@>>>>>>>>>>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"--$k",$opt->desc
.
}

# help to help

sub show_help_options {
    print    # "\n" .
        "                --help   overview of all options and their values\n"
      . "            --help all   all about all options\n"
      . "          --help short   just the main options\n"
      . "   --help mode ... pdf   all about a few options\n"
      . "        --help '*.pdf'   all about options containing 'pdf'\n"
      . "\n"
      . "            more info    http://www.pragma-ade.com/general/manuals/mtexexec.pdf\n"
      . "                         http://www.ntg.nl/mailman/listinfo/ntg-context\n";
}

# determine what user wants to see

if ($HelpAsked) {
    $shorthelp = 0;
    @help      = ( sort keys %Help );
    if ( "@ARGV" eq "all" ) {    # everything
    } elsif ( "@ARGV" eq "short" ) {    # nearly everything
        $shorthelp--;
    } elsif ( "@ARGV" eq "help" ) {     # help on help
        show_help_options;
        exit;
    } elsif (@ARGV) {                   # one or a few options, completely
        my @h = @ARGV;
        @help = ();
        for (@h) {                      # print "testing $_\n";
                                        # next if (/^[\*\?]/) ; # HH, else error
            if (/^[\*\?]/) { $_ = ".$_" }    # HH, else error
            $Help{$_} and push( @help, $_ ) or do {
                my $unknown = $_;
                for ( keys %Help ) { /$unknown/ and push( @help, $_ ) }
              }
        }
    } else {    # all main option and their assignable values
        $shorthelp++;
    }
}

sub show_help_info {
    map { print_opt( $_, $Help{$_} ) } @help;
}

# uncomment this to see the structure of a Help element:
# print Dumper($Help{pdfselect});

#### end of help system

my $FinalRunNeeded = 0;

sub MPJobName {
    my $JobName   = shift;
    my $MPfile    = shift;
    my $MPJobName = '';
    if ( -e "$JobName-$MPfile.mp" && -s "$JobName-$MPfile.mp" > 100 ) {
       $MPJobName = "$JobName-$MPfile.mp"
    } elsif ( -e "$MPfile.mp" && -s "$MPfile.mp" > 100 ) {
       $MPJobName = "$MPfile.mp"
    } else { $MPJobName = "" }
    return $MPJobName;
}

sub System {
    my $cmd = shift ;
    unless ( $dosish && ! $escapeshell ) {
        $cmd =~ s/([^\\])\&/$1\\\&/io ;
    }
    if ($Verbose) {
        print "\n$cmd\n\n" ;
    }
	system($cmd)
}

sub Pipe {
    my $cmd = shift ;
    unless ( $dosish && ! $escapeshell ) {
        $cmd =~ s/([^\\])\&/$1\\\&/io ;
    }
    if ($Verbose) {
        print "\n$cmd\n\n" ;
    }
	return `$cmd`
}


sub RunPerlScript {
    my ( $ScriptName, $Options ) = @_;
    my $cmd = '';
    $own_quote = ($own_path =~ m/^[^\"].* / ? "\"" : "") ;
    if ($Verbose) {
        $Options .= ' --verbose' ;
    }
    if ($dosish) {
        if ( -e "own_path$ScriptName$own_type" ) {
            $cmd =
"$own_stub$own_quote$own_path$ScriptName$own_type$own_quote $Options";
        } elsif ( -e "$TeXScriptsPath$ScriptName$own_type" ) {
            $cmd =
"$own_stub$own_quote$TeXScriptsPath$ScriptName$own_type$own_quote $Options";
        } else {
            $cmd = "";
        }
    } else {
        $cmd = "$ScriptName $Options";
    }
    unless ( $cmd eq "" ) {
        System($cmd) ;
    }
}

my $FullFormat = '';

sub CheckOutputFormat {
    my $Ok = 1;
    if ( $OutputFormat ne 'standard' ) {
        my @OutputFormat = split( /,/, $OutputFormat );
        foreach my $F (@OutputFormat) {
            if ( defined( $OutputFormats{ lc $F } ) ) {
                my $OF = $OutputFormats{ lc $F };
                next if ( ",$FullFormat," =~ /\,$OF\,/ );
                if ($FullFormat) { $FullFormat .= "," }
                $FullFormat .= "$OutputFormats{lc $F}";
            } else {
                $Ok = 0;
            }
        }
        if ( !$Ok ) {
            print(" unknown output format : $OutputFormat\n");
        }
    }
    unless ($FullFormat) { $FullFormat = $OutputFormat }
}    # 'standard' to terminal

sub MakeOptionFile {
    my ( $FinalRun, $FastDisabled, $JobName, $JobSuffix, $KindOfRun ) = @_;
    open( OPT, ">$JobName.top" );
    print OPT "\% $JobName.top\n";
    print OPT "\\unprotect\n";
    if ($EnterBatchMode)   { print OPT "\\batchmode\n" }
    if ($EnterNonStopMode) { print OPT "\\nonstopmode\n" }
    if ($Paranoid)         {
        print "    paranoid file mode : very true\n";
        print OPT "\\def\\maxreadlevel{1}\n" ;
    }
    $ModeFile =~ s/\\/\//gio ; # do this at top of file
    $Result =~ s/\\/\//gio ; # do this at top of file
    if ( $ModeFile ne '' ) { print OPT "\\readlocfile{$ModeFile}{}{}" }
    if ( $Result   ne '' ) { print OPT "\\setupsystem[file=$Result]\n" }
    elsif ($Suffix) { print OPT "\\setupsystem[file=$JobName$Suffix]\n" }
    if ( $InpPath ne "" ) {
        $InpPath =~ s/\\/\//go;
        $InpPath =~ s/\/$//go;
        print OPT "\\usepath[$InpPath]\n";
    }
    $MainLanguage = lc $MainLanguage;
    unless ( $MainLanguage eq "standard" ) {
        print OPT "\\setuplanguage[$MainLanguage]\n";
    }
    # can best become : \use...[mik] / [web]
    if ( $TeXShell =~ /MikTeX/io ) {
        print OPT "\\def\\MPOSTbatchswitch   \{$MpBatchFlag\}";
        print OPT "\\def\\MPOSTnonstopswitch \{$MpNonStopFlag\}";
        print OPT "\\def\\MPOSTformatswitch  \{$MpPassString $MpFormatFlag\}";
    }
    #
    if ( $FullFormat ne 'standard' ) {
        print OPT "\\setupoutput[$FullFormat]\n";
    }
    if ($UseColor)         { print OPT "\\setupcolors[\\c!state=\\v!start]\n" }
    if ( $NoMPMode || $NoMPRun || $AutoMPRun ) {
        print OPT "\\runMPgraphicsfalse\n";
    }
    if ( ($FastMode) && ( !$FastDisabled ) ) { print OPT "\\fastmode\n" }
    if ($SilentMode) { print OPT "\\silentmode\n" }
    if ( $Separation ne "" ) {
        print OPT "\\setupcolors[\\c!split=$Separation]\n";
    }
    if ($SetupPath) { print OPT "\\setupsystem[\\c!directory=\{$SetupPath\}]\n" }
    if ($dosish) {
        print OPT "\\setupsystem[\\c!type=mswin]\n"
    } else { # no darwin handling in old texexec
        print OPT "\\setupsystem[\\c!type=unix]\n"
    }
    print OPT "\\setupsystem[\\c!n=$KindOfRun]\n";
    $_ = $PaperFormat;
    #unless (($PdfArrange)||($PdfSelect)||($PdfCombine)||($PdfCopy))
    unless ( ($PdfSelect) || ($PdfCombine) || ($PdfCopy) || ($PdfTrim) ) {
        if (/.4.3/goi) {
            print OPT "\\setuppapersize[A4][A3]\n" ;
        } elsif (/.5.4/goi) {
            print OPT "\\setuppapersize[A5][A4]\n" ;
        } elsif ( !/standard/ ) {
            s/x/\*/io;
            if (/\w+\d+/) { $_ = uc $_ }
            my ( $from, $to ) = split(/\*/);
            if ( $to eq "" ) { $to = $from }
            print OPT "\\setuppapersize[$from][$to]\n";
        }
    }
    if (   ( $PdfSelect || $PdfCombine || $PdfCopy || $PdfTrim || $PdfArrange )
        && ( $Background ne '' ) )
    {
        print "    background graphic : $Background\n";
        print OPT "\\defineoverlay[whatever][{\\externalfigure[$Background][\\c!factor=\\v!max]}]\n";
        print OPT "\\setupbackgrounds[\\v!page][\\c!background=whatever]\n";
    }
    if ($CenterPage) {
        print OPT
          "\\setuplayout[\\c!location=\\v!middle,\\c!marking=\\v!on]\n";
    }
    if ($NoMapFiles) {
        print OPT "\\disablemapfiles\n";
    }
    if ($NoArrange) { print OPT "\\setuparranging[\\v!disable]\n" }
    elsif ( $Arrange || $PdfArrange ) {
        $FinalRunNeeded = 1;
        if ($FinalRun) {
            my $DupStr;
            if ($NoDuplex) { $DupStr = "" }
            else { $DupStr = ",\\v!doublesided" }
            if ( $PrintFormat eq '' ) {
                print OPT "\\setuparranging[\\v!normal]\n";
            } elsif ( $PrintFormat =~ /.*up/goi ) {
                print OPT "\\setuparranging[2UP,\\v!rotated$DupStr]\n";
            } elsif ( $PrintFormat =~ /.*down/goi ) {
                print OPT "\\setuparranging[2DOWN,\\v!rotated$DupStr]\n";
            } elsif ( $PrintFormat =~ /.*side/goi ) {
                print OPT "\\setuparranging[2SIDE,\\v!rotated$DupStr]\n";
            } else {
                print OPT "\\setuparranging[$PrintFormat]\n";
            }
        } else {
            print OPT "\\setuparranging[\\v!disable]\n";
        }
    }
    if ($Arguments) { print OPT "\\setupenv[$Arguments]\n" }
    if ($Input)     { print OPT "\\setupsystem[inputfile=$Input]\n" }
    else { print OPT "\\setupsystem[inputfile=$JobName.$JobSuffix]\n" }
    if ($Random) { print OPT "\\setupsystem[\\c!random=$RandomSeed]\n" }
    if ($Mode)   { print OPT "\\enablemode[$Mode]\n" }
    if ($Pages)  {
        if ( lc $Pages eq "odd" ) {
            print OPT "\\chardef\\whichpagetoshipout=1\n";
        } elsif ( lc $Pages eq "even" ) {
            print OPT "\\chardef\\whichpagetoshipout=2\n";
        } else {
            my @Pages = split( /\,/, $Pages );
            $Pages = '';
            foreach my $page (@Pages) {
                if ( $page =~ /\:/ ) {
                    my ( $from, $to ) = split( /\:/, $page );
                    foreach ( my $i = $from ; $i <= $to ; $i++ ) {
                        $Pages .= $i . ',';
                    }
                } else {
                    $Pages .= $page . ',';
                }
            }
            chop $Pages;
            print OPT "\\def\\pagestoshipout\{$Pages\}\n";
        }
    }
    print OPT "\\protect\n";
    if ( $Filters ne "" ) {
        foreach my $F ( split( /,/, $Filters ) ) {
            print OPT "\\useXMLfilter[$F]\n";
        }
    }
    if ( $Modules ne "" ) {
        foreach my $M ( split( /,/, $Modules ) ) {
            print OPT "\\usemodule[$M]\n";
        }
    }
    if ( $Environments ne "" ) {
        foreach my $E ( split( /,/, $Environments ) ) {
            print OPT "\\environment $E\n";
        }
    }
    close(OPT);
}

my $UserFileOk = 0;
my @MainLanguages;
my $AllLanguages = '';

sub MakeUserFile {
    $UserFileOk = 0;
    if ($AllPatterns) {
        open( USR, ">cont-fmt.tex" );
        print USR "\\preloadallpatterns\n";
    } else {
        return
          if ( ( $MainLanguage eq 'standard' )
            && ( $MainBodyFont eq 'standard' ) );
        print "   preparing user file : cont-fmt.tex\n";
        open( USR, ">cont-fmt.tex" );
        print USR "\\unprotect\n";
        $AllLanguages = $MainLanguage;
        if ( $MainLanguage ne 'standard' ) {
            @MainLanguages = split( /\,/, $MainLanguage );
            foreach (@MainLanguages) {
                print USR "\\installlanguage[\\s!$_][\\c!state=\\v!start]\n";
            }
            $MainLanguage = $MainLanguages[0];
            print USR "\\setupcurrentlanguage[\\s!$MainLanguage]\n";
        }
        if ( $MainBodyFont ne 'standard' ) {
            print USR "\\definetypescriptsynonym[cmr][$MainBodyFont]";
            print USR "\\definefilesynonym[font-cmr][font-$MainBodyFont]\n";
        }
        print USR "\\protect\n";
    }
    print USR "\\endinput\n";
    close(USR);
    ReportUserFile();
    print "\n";
    $UserFileOk = 1;
}

sub RemoveResponseFile { unlink "mult-def.tex" }

sub MakeResponseFile {
    if ( $MainResponse eq 'standard' ) { RemoveResponseFile() }
    elsif ( !defined( $ResponseInterface{$MainResponse} ) ) {
        RemoveResponseFile();
    } else {
        my $MR = $ResponseInterface{$MainResponse};
        print "   preparing interface file : mult-def.tex\n";
        print "          response language : $MR\n";
        open( DEF, ">mult-def.tex" );
        print DEF "\\def\\currentresponses\{$MR\}\n\\endinput\n";
        close(DEF);
    }
}

sub RestoreUserFile {
    unlink "cont-fmt.log";
    rename "cont-fmt.tex", "cont-fmt.log";
    ReportUserFile();
}

sub ReportUserFile {
    return unless ($UserFileOk);
    print "\n";
    if ( $MainLanguage ne 'standard' ) {
        print "   additional patterns : $AllLanguages\n";
        print "      default language : $MainLanguage\n";
    }
    if ( $MainBodyFont ne 'standard' ) {
        print "      default bodyfont : $MainBodyFont\n";
    }
}

sub CheckPositions { }

my $ConTeXtVersion = "unknown";
my $ConTeXtModes   = '';

sub ScanTeXPreamble {
    my ($FileName) = @_;
    open( TEX, $FileName );
    while (<TEX>) {
        chomp;
        if (/^\%.*/) {
            if (/tex=([a-z]*)/goi)                  { $TeXExecutable  = $1 }
            if (/translat.*?=([\:\/0-9\-a-z]*)/goi) { $TeXTranslation = $1 }
            if (/program=([a-z]*)/goi)              { $TeXExecutable  = $1 }
            if (/output=([a-z\,\-]*)/goi)           { $OutputFormat   = $1 }
            if (/modes=([a-z\,\-]*)/goi)            { $ConTeXtModes   = $1 }
            if (/textree=([a-z\-]*)/goi)            { $TeXTree        = $1 }
            if (/texroot=([a-z\-]*)/goi)            { $TeXRoot        = $1 }
            if ( $ConTeXtInterface eq "unknown" ) {

                if (/format=([a-z]*)/goi) {
                    $ConTeXtInterface = $ConTeXtInterfaces{$1};
                }
                if (/interface=([a-z]*)/goi) {
                    $ConTeXtInterface = $ConTeXtInterfaces{"$1"};
                }
            }
            if (/version=([a-z]*)/goi) { $ConTeXtVersion = $1 }
        } else {
            last;
        }
    }
    close(TEX);

    # handy later on

    $ProducePdfT   = ($OutputFormat eq "pdftex") ;
    $ProducePdfM   = ($OutputFormat eq "dvipdfm") ;
    $ProducePdfX   = ($OutputFormat eq "dvipdfmx") ;
    $ProducePdfXTX = ($OutputFormat eq "xetex") ;
    $ProducePs     = ($OutputFormat eq "dvips") ;
}

sub ScanContent {
    my ($ConTeXtInput) = @_;
    open( TEX, $ConTeXtInput );
    while (<TEX>) {
        next if (/^\%/) ;
        if (
/\\(starttekst|stoptekst|startonderdeel|startdocument|startoverzicht)/
          )
        {
            $ConTeXtInterface = "nl";
            last;
        } elsif (/\\(stelle|verwende|umgebung|benutze)/) {
            $ConTeXtInterface = "de";
            last;
        } elsif (/\\(stel|gebruik|omgeving)/) {
            $ConTeXtInterface = "nl";
            last;
        } elsif (/\\(use|setup|environment)/) {
            $ConTeXtInterface = "en";
            last;
        } elsif (/\\(usa|imposta|ambiente)/) {
            $ConTeXtInterface = "it";
            last;
        } elsif (/(height|width|style)=/) {
            $ConTeXtInterface = "en";
            last;
        } elsif (/(hoehe|breite|schrift)=/) {
            $ConTeXtInterface = "de";
            last;
        }
        # brr, can be \c!
        elsif (/(hoogte|breedte|letter)=/)  { $ConTeXtInterface = "nl"; last }
        elsif (/(altezza|ampiezza|stile)=/) { $ConTeXtInterface = "it"; last }
        elsif (/externfiguur/)              { $ConTeXtInterface = "nl"; last }
        elsif (/externalfigure/)            { $ConTeXtInterface = "en"; last }
        elsif (/externeabbildung/)          { $ConTeXtInterface = "de"; last }
        elsif (/figuraesterna/)             { $ConTeXtInterface = "it"; last }
    }
    close(TEX);
}

if ( $ConTeXtInterfaces{$ConTeXtInterface} ) {
    $ConTeXtInterface = $ConTeXtInterfaces{$ConTeXtInterface};
}

my $Problems = my $Ok = 0;

sub PrepRunTeX {
    my ( $JobName, $JobSuffix, $PipeString ) = @_;
    my $cmd;
    my $TeXProgNameFlag = '';
    if ( !$dosish )    # we assume tetex on linux
    {
        $TeXProgramPath = '';
        $TeXFormatPath  = '';
        if (   !$TeXProgNameFlag
            && ( $Format =~ /^cont/ )
            && ( $TeXPassString !~ /progname/io ) )
        {
            $TeXProgNameFlag = "-progname=context";
        }
    }
    $own_quote = ($TeXProgramPath =~ m/^[^\"].* / ? "\"" : "") ;
    $cmd = join( ' ',
        "$own_quote$TeXProgramPath$TeXExecutable$own_quote",
        $TeXProgNameFlag, $TeXPassString, $PassOn, "" );
    if ($EnterBatchMode)   { $cmd .= "$TeXBatchFlag " }
    if ($EnterNonStopMode) { $cmd .= "$TeXNonStopFlag " }
    if ( $TeXTranslation ne '' ) { $cmd .= "-translate-file=$TeXTranslation " }
    $cmd .= "$TeXFormatFlag$TeXFormatPath$Format $JobName.$JobSuffix $PipeString";
	return $cmd;
}

my $emergencyend = "" ;
#~ my $emergencyend = "\\emergencyend" ;

sub RunTeX {
    my ( $JobName, $JobSuffix ) = @_;
    my $StartTime = time;
    my $cmd = PrepRunTeX($JobName, $JobSuffix, '');
    if ($EnterBatchMode) {
        $Problems = System("$cmd $emergencyend");
    } else {
        $Problems = System("$cmd $emergencyend");
    }
    my $StopTime = time - $StartTime;
    print "\n           return code : $Problems";
    print "\n              run time : $StopTime seconds\n";
    return $Problems;
}

sub PushResult {
    my $File = shift;
    $File   =~ s/\..*$//o;
    $Result =~ s/\..*$//o;
    if ( ( $Result ne '' ) && ( $Result ne $File ) ) {
        print "            outputfile : $Result\n";
        unlink "texexec.tuo";
        rename "$File.tuo", "texexec.tuo";
        unlink "texexec.log";
        rename "$File.log", "texexec.log";
        unlink "texexec.dvi";
        rename "$File.dvi", "texexec.dvi";
        unlink "texexec.pdf";
        rename "$File.pdf", "texexec.pdf";

        if ( -e "$Result.tuo" ) {
            unlink "$File.tuo";
            rename "$Result.tuo", "$File.tuo";
        }
    }
    if ($Optimize) { unlink "$File.tuo" }
}

sub PopResult {
    my $File = shift;
    $File   =~ s/\..*$//o;
    $Result =~ s/\..*$//o;
    if ( ( $Result ne '' ) && ( $Result ne $File ) ) {
        print "              renaming : $File to $Result\n";
        unlink "$Result.tuo";
        rename "$File.tuo", "$Result.tuo";
        unlink "$Result.log";
        rename "$File.log", "$Result.log";
        unlink "$Result.dvi";
        rename "$File.dvi", "$Result.dvi";
        if ( -e "$File.dvi" ) { CopyFile( "$File.dvi", "$Result.dvi" ) }
        unlink "$Result.pdf";
        rename "$File.pdf", "$Result.pdf";
        if ( -e "$File.pdf" ) { CopyFile( "$File.pdf", "$Result.pdf" ) }
        return if ( $File ne "texexec" );
        rename "texexec.tuo", "$File.tuo";
        rename "texexec.log", "$File.log";
        rename "texexec.dvi", "$File.dvi";
        rename "texexec.pdf", "$File.pdf";
    }
}

sub RunTeXutil {
    my $StopRunning;
    my $JobName = shift;
    unlink "$JobName.tup";
    rename "$JobName.tuo", "$JobName.tup";
    print "  sorting and checking : running texutil\n";
    my $TcXSwitch = '';
    if ( $TcXPath ne '' ) { $TcXSwitch = "--tcxpath=$TcXPath" }
    RunPerlScript( $TeXUtil, "--ref --ij --high $TcXPath $JobName" );

    if ( -e "$JobName.tuo" ) {
        CheckPositions($JobName);
        #~ print "    utility file check : $JobName.tup <-> $JobName.tuo\n";
        $StopRunning = !compare( "$JobName.tup", "$JobName.tuo" );
    } else {
        $StopRunning = 1;
    }    # otherwise potential loop
    if ( !$StopRunning ) {
        print "\n utility file analysis : another run needed\n";
    }
    return $StopRunning;
}

sub PurgeFiles {
    my $JobName = shift;
    print "\n         purging files : $JobName\n";
    RunPerlScript( $TeXUtil, "--purge $JobName" );
    unlink( $Result . '.log' ) if ( -f $Result . '.log' );
}

sub RunTeXMP {
    my $JobName        = shift;
    my $MPfile         = shift;
    my $MPrundone      = 0;
    my $MPJobName      = MPJobName( $JobName, $MPfile );
    my $MPFoundJobName = "";
    if ( $MPJobName ne "" ) {
        if ( open( MP, "$MPJobName" ) ) {
            $_ = <MP>;
            chomp;    # we should handle the prefix as well
            if (/^\%\s+translate.*?\=([\w\d\-]+)/io)   { $TeXTranslation = $1 }
            if (/collected graphics of job \"(.+)\"/i) { $MPFoundJobName = $1 }
            close(MP);
            if ( $MPFoundJobName ne "" ) {
                if ( $JobName =~ /$MPFoundJobName$/i ) {
                    if ( $MpExecutable ne '' ) {
                        print
                          "   generating graphics : metaposting $MPJobName\n";
                        my $ForceMpy = "";
                        if ($MpyForce) { $ForceMpy = "--mpyforce" }
                        my $ForceTCX = '';
                        if ( $TeXTranslation ne '' ) {
                            $ForceTCX = "--translate=$TeXTranslation ";
                        }
                        if ($EnterBatchMode) {
                            RunPerlScript( $TeXExec,
"$ForceTCX $ForceMpy --mptex --nomp --batch $MPJobName"
                            );
                        } elsif ($EnterNonStopMode) {
                            RunPerlScript( $TeXExec,
"$ForceTCX $ForceMpy --mptex --nomp --nonstop $MPJobName"
                            );
                        } else {
                            RunPerlScript( $TeXExec,
                                "$ForceTCX $ForceMpy --mptex --nomp $MPJobName"
                            );
                        }
                    } else {
                        print
                          "   generating graphics : metapost cannot be run\n";
                    }
                    $MPrundone = 1;
                }
            }
        }
    }
    return $MPrundone;
}

sub CopyFile {    # agressive copy, works for open files like in gs
    my ( $From, $To ) = @_;
    return unless open( INP, "<$From" );
    binmode INP;
    return unless open( OUT, ">$To" );
    binmode OUT;
    while (<INP>) { print OUT $_ }
    close(INP);
    close(OUT);
}

#~ sub CheckMPChanges {
    #~ my $JobName   = shift;
    #~ my $checksum  = 0;
    #~ my $MPJobName = MPJobName( $JobName, "mpgraph" );
    #~ if ( open( MP, $MPJobName ) ) {
        #~ while (<MP>) {
            #~ unless (/random/oi) {
                #~ $checksum += do { unpack( "%32C*", <MP> ) % 65535 }
            #~ }
        #~ }
        #~ close(MP);
    #~ }
    #~ $MPJobName = MPJobName( $JobName, "mprun" );
    #~ if ( open( MP, $MPJobName ) ) {
        #~ while (<MP>) {
            #~ unless (/random/oi) {
                #~ $checksum += do { unpack( "%32C*", <MP> ) % 65535 }
            #~ }
        #~ }
        #~ close(MP);
    #~ }
    #~ print "         mpgraph/mprun : $checksum\n";
    #~ return $checksum;
#~ }

sub CheckMPChanges {
    my $JobName = shift; my $str = '' ;
    my $MPJobName = MPJobName( $JobName, "mpgraph" );
    if ( open( MP, $MPJobName ) ) {
        $str .= do { local $/ ; <MP> ; } ;
        close(MP) ;
    }
    $MPJobName = MPJobName( $JobName, "mprun" );
    if ( open( MP, $MPJobName ) ) {
        $str .= do { local $/ ; <MP> ; } ;
        close(MP) ;
    }
    $str =~ s/^.*?random.*?$//oim ;
    return Digest::MD5::md5_hex($str) ;
}

#~ sub CheckTubChanges {
    #~ my $JobName   = shift;
    #~ my $checksum  = 0;
    #~ if ( open( TUB, "$JobName.tub" ) ) {
        #~ while (<TUB>) {
            #~ $checksum += do { unpack( "%32C*", <TUB> ) % 65535 }
        #~ }
        #~ close(TUB);
    #~ }
    #~ return $checksum;
#~ }

sub CheckTubChanges {
    my $JobName   = shift; my $str = '' ;
    if ( open( TUB, "$JobName.tub" ) ) {
        $str = do { local $/ ; <TUB> ; } ;
        close(TUB);
    }
    return Digest::MD5::md5_hex($str);
}


my $DummyFile = 0;

sub isXMLfile {
    my $Name = shift;
    if ( ($ForceXML) || ( $Name =~ /\.(xml|fo|fox)$/io ) ) { return 1 }
    else {
        open( XML, $Name );
        my $str = <XML>;
        close(XML);
        return ( $str =~ /\<\?xml /io );
    }
}

sub RunConTeXtFile {
    my ( $JobName, $JobSuffix ) = @_;
    if ($AutoPath) {
        if ($JobName =~ /^(.*)[\/\\](.*?)$/o) {
            $InpPath = $1 ;
            $JobName = $2 ;
        }
    }
    $JobName =~ s/\\/\//goi;
    $InpPath =~ s/\\/\//goi;
    my $OriSuffix = $JobSuffix;
    if ($JobSuffix =~ /\_fo$/i) {
        if (! -f $JobName) {
            print "stripping funny suffix : _fo\n";
            $JobName =~ s/\_fo$//io ;
            $JobSuffix =~ s/\_fo$//io ;
            $OriSuffix =~ s/\_fo$//io ;
        }
    }
    if (($dosish) && ($PdfClose)) {
        my $ok = System("pdfclose --file $JobName.pdf") if -e "$JobName.pdf" ;
        if (($Result ne '') && (-e "$Result.pdf")) {
            $ok = System("pdfclose --file $Result.pdf") ;
        }
        System("pdfclose --all") unless $ok ;
    }
    if ( -e "$JobName.$JobSuffix" ) {
        $DummyFile = ( ($ForceXML) || ( $JobSuffix =~ /(xml|fo|fox)/io ) );
    }
    # to be considered :
    # { $DummyFile = isXMLfile("$JobName.$JobSuffix") }
    elsif ( $InpPath ne "" ) {
        my @InpPaths = split( /,/, $InpPath );
        foreach my $rp (@InpPaths) {
            if ( -e "$rp/$JobName.$JobSuffix" ) { $DummyFile = 1; last }
        }
    }
    if ($DummyFile) {
        open( TMP, ">$JobName.run" );
        if ( ( $JobSuffix =~ /(xml|fo|fox)/io ) || $ForceXML ) {
            # scan xml preamble
            open(XML,"<$JobName.$JobSuffix") ;
            while (<XML>) {
                if (/\<\?context\-directive\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*?)\s*\?\>/o) {
                    my ($class, $key, $value, $rest) = ($1, $2, $3, $4) ;
                    if ($class eq 'job') {
                        if (($key eq 'mode') || ($key eq 'modes')) {
                            print TMP "\\enablemode[$value]\n" ;
                        } elsif (($key eq 'stylefile') || ($key eq 'environment')) {
                            print TMP "\\environment $value\n" ;
                        } elsif ($key eq 'module') {
                            print TMP "\\usemodule[$value]\n" ;
                        } elsif ($key eq 'interface') {
                            $ConTeXtInterface = $value ;
                        } elsif ($key eq 'control') {
                            if ($rest == 'purge') { $Purge = 1 }
                        }
                    }
                } elsif (/\<[a-z]+/io) {
                    last ;
                }
            }
            close(XML) ;
            if ( $Filters ne "" ) {
                print "     using xml filters : $Filters\n";
            }
            print TMP "\\starttext\n";
            print TMP "\\processXMLfilegrouped{$JobName.$JobSuffix}\n";
            print TMP "\\stoptext\n";
        } else {
            print TMP "\\starttext\n";
            print TMP "\\processfile{$JobName.$JobSuffix}\n";
            print TMP "\\stoptext\n";
        }
        close(TMP);
        $JobSuffix = "run";
    }
    if ( ( -e "$JobName.$JobSuffix" ) || ($GlobalFile) ) {
        unless ($DummyFile) {    # we don't need this for xml
            ScanTeXPreamble("$JobName.$JobSuffix");
            if ( $ConTeXtInterface eq "unknown" ) {
                ScanContent("$JobName.$JobSuffix");
            }
        }
        if ( $ConTeXtInterface eq "unknown" ) {
            $ConTeXtInterface = $UserInterface;
        }
        if ( $ConTeXtInterface eq "unknown" ) { $ConTeXtInterface = "en" }
        if ( $ConTeXtInterface eq "" )        { $ConTeXtInterface = "en" }
        CheckOutputFormat;
        my $StopRunning = 0;
        my $MPrundone   = 0;
        if ( $Format eq '' ) { $Format = "cont-$ConTeXtInterface" }
        print "            executable : $TeXProgramPath$TeXExecutable\n";
        print "                format : $TeXFormatPath$Format\n";
        if ($InpPath) { print "           source path : $InpPath\n" }

        if ($DummyFile) {
            print "            dummy file : $JobName.$JobSuffix\n";
        }
        print "             inputfile : $JobName\n";
        print "                output : $FullFormat\n";
        print "             interface : $ConTeXtInterface\n";
        if ( $TeXTranslation ne '' ) {
            print "           translation : $TeXTranslation\n";
        }
        my $Options = '';
        if ($Random)           { $Options .= " random" }
        if ($FastMode)         { $Options .= " fast" }
        if ($FinalMode)        { $Options .= " final" }
        if ($Verbose)          { $Options .= " verbose" }
        if ($TypesetListing)   { $Options .= " listing" }
        if ($TypesetModule)    { $Options .= " module" }
        if ($TypesetFigures)   { $Options .= " figures" }
        if ($MakeFormats)      { $Options .= " make" }
        if ($RunOnce)          { $Options .= " once" }
        if ($UseColor)         { $Options .= " color" }
        if ($EnterBatchMode)   { $Options .= " batch" }
        if ($EnterNonStopMode) { $Options .= " nonstop" }
        if ($NoMPMode)         { $Options .= " nomp" }
        if ($CenterPage)       { $Options .= " center" }
        if ($Arrange)          { $Options .= " arrange" }
        if ($NoArrange)        { $Options .= " no-arrange" }
        if ($Options)      { print "               options :$Options\n" }
        if ($ConTeXtModes) { print "        possible modes : $ConTeXtModes\n" }
        if ($Mode)         { print "          current mode : $Mode\n" }
        else { print "          current mode : none\n" }
        if ($Arguments)    { print "             arguments : $Arguments\n" }
        if ($Modules)      { print "               modules : $Modules\n" }
        if ($Environments) { print "          environments : $Environments\n" }
        if ($Suffix)       { $Result = "$JobName$Suffix" }
        PushResult($JobName);
        $Problems = 0;
        my $TeXRuns = 0;

        if ( ($PdfArrange) || ($PdfSelect) || ($RunOnce) ) {
            MakeOptionFile( 1, 1, $JobName, $OriSuffix, 3 );
            print "\n";
            $Problems = RunTeX( $JobName, $JobSuffix );
            if ($ForceTeXutil) { $Ok = RunTeXutil($JobName) }
            CopyFile( "$JobName.top", "$JobName.tmp" );
            unlink "$JobName.top";    # runtime option file
            PopResult($JobName);
        } else {
            while ( !$StopRunning && ( $TeXRuns < $NOfRuns ) && ( !$Problems ) )
            {
                ++$TeXRuns;
                if ( $TeXRuns == 1 ) {
                    MakeOptionFile( 0, 0, $JobName, $OriSuffix, 1 );
                } else {
                    MakeOptionFile( 0, 0, $JobName, $OriSuffix, 2 );
                }
                print "               TeX run : $TeXRuns\n\n";
                my ( $mpchecksumbefore, $mpchecksumafter ) = ( '', '' );
                my ( $tubchecksumbefore, $tubchecksumafter ) = ( '', '' );
                if ($AutoMPRun) { $mpchecksumbefore = CheckMPChanges($JobName) }
                $tubchecksumbefore = CheckTubChanges($JobName) ;
                $Problems = RunTeX( $JobName, $JobSuffix );
                $tubchecksumafter = CheckTubChanges($JobName) ;
                if ($AutoMPRun) { $mpchecksumafter = CheckMPChanges($JobName) }
                if ( ( !$Problems ) && ( $NOfRuns > 1 ) ) {
                    unless ( $NoMPMode ) {
                        $MPrundone = RunTeXMP( $JobName, "mpgraph" );
                        $MPrundone = RunTeXMP( $JobName, "mprun" );
                    }
                    $StopRunning = RunTeXutil($JobName);
                    if ($AutoMPRun) {
                        $StopRunning =
                          ( $StopRunning
                              && ( $mpchecksumafter eq $mpchecksumbefore ) );
                    }
                    $StopRunning =
                          ( $StopRunning
                              && ( $tubchecksumafter eq $tubchecksumbefore ) );
                }
            }
            if ( ( $NOfRuns == 1 ) && $ForceTeXutil ) {
                $Ok = RunTeXutil($JobName);
            }
            if (   ( !$Problems )
                && ( ( $FinalMode || $FinalRunNeeded ) )
                && ( $NOfRuns > 1 ) )
            {
                MakeOptionFile( 1, $FinalMode, $JobName, $OriSuffix, 4 );
                print "         final TeX run : $TeXRuns\n\n";
                $Problems = RunTeX( $JobName, $JobSuffix );
            }
            CopyFile( "$JobName.top", "$JobName.tmp" );
            unlink "$JobName.tup";    # previous tuo file
            unlink "$JobName.top";    # runtime option file
            if ($ProducePdfX) {
                $ENV{'backend'} = $ENV{'progname'} = 'dvipdfm' ;
                $ENV{'TEXFONTMAPS'} = '.;$TEXMF/fonts/map/{dvipdfm,dvips,}//' ;
                System("dvipdfmx -d 4 $JobName") ;
            } elsif ($ProducePdfM) {
                $ENV{'backend'} = $ENV{'progname'} = 'dvipdfm' ;
                $ENV{'TEXFONTMAPS'} = '.;$TEXMF/fonts/map/{dvipdfm,dvips,}//' ;
                System("dvipdfm $JobName") ;
            } elsif ($ProducePdfXTX) {
                $ENV{'backend'} = $ENV{'progname'} = 'xetex' ;
                $ENV{'TEXFONTMAPS'} = '.;$TEXMF/fonts/map/{xetex,pdftex,dvips,}//' ;
                System("xdv2pdf $JobName.xdv") ;
            } elsif ($ProducePs) {
                $ENV{'backend'} = $ENV{'progname'} = 'dvips' ;
                $ENV{'TEXFONTMAPS'} = '.;$TEXMF/fonts/map/{dvips,pdftex,}//' ;
                # temp hack, some day there will be map file loading in specials
                my $mapfiles = '' ;
                if (-f "$JobName.tui") {
                    open(TUI,"$JobName.tui") ;
                    while (<TUI>) {
                        if (/c \\usedmapfile\{.\}\{(.*?)\}/o) {
                            $mapfiles .= "-u +$1 " ;
                        }
                    }
                    close(TUI) ;
                }
                System("dvips $mapfiles $JobName.dvi") ;
            }
            PopResult($JobName);
        }
        if ($Purge) { PurgeFiles($JobName) }
        if ($DummyFile)               # $JobSuffix == run
        {
            unlink "$JobName.$JobSuffix";
        }
        if ((!$Problems) && ($PdfOpen) && ($PdfOpenCall)) {
            if ($Result ne '') {
                System("$PdfOpenCall $Result.pdf") if -f "$Result.pdf"
            } else {
                System("$PdfOpenCall $JobName.pdf") if -f "$JobName.pdf"
            }
        }
    }
}

sub RunSomeTeXFile {
    my ( $JobName, $JobSuffix ) = @_;
    if ( -e "$JobName.$JobSuffix" ) {
        PushResult($JobName);
        print "            executable : $TeXProgramPath$TeXExecutable\n";
        print "                format : $TeXFormatPath$Format\n";
        print "             inputfile : $JobName.$JobSuffix\n";
        $Problems = RunTeX( $JobName, $JobSuffix );
        PopResult($JobName);
    }
}

my $ModuleFile  = "texexec";
my $ListingFile = "texexec";
my $FiguresFile = "texexec";
my $ArrangeFile = "texexec";
my $SelectFile  = "texexec";
my $CopyFile    = "texexec";
my $CombineFile = "texexec";

sub RunModule {
    my @FileNames = sort @_;
    if ($FileNames[0]) {
        unless ( -e $FileNames[0] ) {
            my $Name = $FileNames[0];
            @FileNames = ( "$Name.tex", "$Name.mp", "$Name.pl", "$Name.pm" );
        }
        foreach my $FileName (@FileNames) {
            next unless -e $FileName;
            my ( $Name, $Suffix ) = split( /\./, $FileName );
            next unless $Suffix =~ /(tex|mp|pl|pm)/io;
            DoRunModule( $Name, $Suffix );
        }
    } else {
        print "                module : no modules found\n\n";
    }
}

# the next one can be more efficient: directly process ted
# file a la --use=abr-01,mod-01

sub checktexformatpath {
    # engine support is either broken of not implemented in some
    # distributions, so we need to take care of it ourselves
    my $texformats ;
    if (defined($ENV{'TEXFORMATS'})) {
        $texformats = $ENV{'TEXFORMATS'} ;
    } else {
        $texformats = '' ;
    }
    if ($texformats eq '') {
        if ($UseEnginePath) {
            if ($dosish) {
                if ( $TeXShell =~ /MikTeX/io ) {
                    $texformats = `kpsewhich --alias=$TeXExecutable --expand-var=\$TEXFORMATS` ;
                } else {
                    $texformats = `kpsewhich --engine=$TeXExecutable --expand-var=\$TEXFORMATS` ;
                }
            } else {
                $texformats = `kpsewhich --engine=$TeXExecutable --expand-var=\\\$TEXFORMATS` ;
            }
        } else {
            if ($dosish) {
                $texformats = `kpsewhich --expand-var=\$TEXFORMATS` ;
            } else {
                $texformats = `kpsewhich --expand-var=\\\$TEXFORMATS` ;
            }
        }
        chomp($texformats) ;
    }
    if (($texformats !~ /web2c\/.*$TeXExecutable/) && ($texformats !~ /web2c[\/\\].*\$engine/i)) {
        $texformats =~ s/(web2c\/\{)(\,\})/$1\$engine$2/ ; # needed for empty engine flags
        if ($texformats !~ /web2c[\/\\].*\$ENGINE/) {
            $texformats =~ s/web2c/web2c\/{\$engine,}/ ; # needed for me
        }
        $ENV{'TEXFORMATS'} = $texformats ;
        print " fixing texformat path : $ENV{'TEXFORMATS'}\n";
    } else {
        print "  using texformat path : $ENV{'TEXFORMATS'}\n" if ($Verbose) ;
    }
    if (! defined($ENV{'ENGINE'})) {
        if ($MpEngineSupport) {
            $ENV{'ENGINE'} .= $MpExecutable ;
        } ;
        $ENV{'ENGINE'} = $TeXExecutable ;
        print "fixing engine variable : $ENV{'ENGINE'}\n";
    }
}

sub DoRunModule {
    my ( $FileName, $FileSuffix ) = @_;
    RunPerlScript( $TeXUtil, "--documents $FileName.$FileSuffix" );
    print "                module : $FileName\n\n";
    open( MOD, ">$ModuleFile.tex" );
    # we need to signal to texexec what interface to use
    open( TED, "$FileName.ted" );
    my $firstline = <TED>;
    close(TED);
    if ( $firstline =~ /interface=/ ) {
        print MOD $firstline ;
    } else {
        print MOD "% interface=en\n" ;
    }
    # so far
    print MOD "\\usemodule[abr-01,mod-01]\n";
    print MOD "\\def\\ModuleNumber{1}\n";
    print MOD "\\starttext\n";
    print MOD "\\readlocfile{$FileName.ted}{}{}\n";
    print MOD "\\stoptext\n";
    close(MOD);
    checktexformatpath ;
    RunConTeXtFile( $ModuleFile, "tex" );
    if ( $FileName ne $ModuleFile ) {
        foreach my $FileSuffix ( "dvi", "pdf", "tui", "tuo", "log" ) {
            unlink("$FileName.$FileSuffix");
            rename( "$ModuleFile.$FileSuffix", "$FileName.$FileSuffix" );
        }
    }
    unlink("$ModuleFile.tex");
}

sub RunFigures {
    my @Files = @_ ;
    $TypesetFigures = lc $TypesetFigures;
    return unless ( $TypesetFigures =~ /[abcd]/o );
    unlink "$FiguresFile.pdf";
    if (@Files) { RunPerlScript( $TeXUtil, "--figures @Files" ) }
    open( FIG, ">$FiguresFile.tex" );
    print FIG "% format=english\n";
    print FIG "\\setuplayout\n";
    print FIG "  [topspace=1.5cm,backspace=1.5cm,\n";
    print FIG "   header=1.5cm,footer=0pt,\n";
    print FIG "   width=middle,height=middle]\n";
    if ($ForceFullScreen) {
        print FIG "\\setupinteraction\n";
        print FIG "  [state=start]\n";
        print FIG "\\setupinteractionscreen\n";
        print FIG "  [option=max]\n";
    }
    if ($BoxType ne '') {
        if ($BoxType !~ /box$/io) {
            $BoxType .= "box" ;
        }
    }
    print FIG "\\starttext\n";
    print FIG "\\showexternalfigures[alternative=$TypesetFigures,offset=$PaperOffset,size=$BoxType]\n";
    print FIG "\\stoptext\n";
    close(FIG);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $FiguresFile, "tex" );
    unlink('texutil.tuf') if ( -f 'texutil.tuf' );
}

sub CleanTeXFileName {
    my $str = shift;
    $str =~ s/([\$\_\#])/\\$1/go;
    $str =~ s/([\~])/\\string$1/go;
    return $str;
}

sub RunListing {
    my $FileName = my $CleanFileName = shift;
    my @FileNames = glob $FileName;
    return unless -f $FileNames[0];
    print "            input file : $FileName\n";
    if ( $BackSpace eq "0pt" ) { $BackSpace = "1.5cm" }
    else { print "             backspace : $BackSpace\n" }
    if ( $TopSpace eq "0pt" ) { $TopSpace = "1.5cm" }
    else { print "              topspace : $TopSpace\n" }
    open( LIS, ">$ListingFile.tex" );
    print LIS "% format=english\n";
    print LIS "\\setupbodyfont[11pt,tt]\n";
    print LIS "\\setuplayout\n";
    print LIS "  [topspace=$TopSpace,backspace=$BackSpace,\n";
    print LIS "   header=0cm,footer=1.5cm,\n";
    print LIS "   width=middle,height=middle]\n";
    print LIS "\\setuptyping[lines=yes]\n";
    if ($Pretty) { print LIS "\\setuptyping[option=color]\n" }
    print LIS "\\starttext\n";

    foreach $FileName (@FileNames) {
        $CleanFileName = lc CleanTeXFileName($FileName);
        print LIS "\\page\n";
        print LIS "\\setupfootertexts[\\tttf $CleanFileName][\\tttf \\pagenumber]\n";
        print LIS "\\typefile\{$FileName\}\n";
    }
    print LIS "\\stoptext\n";
    close(LIS);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $ListingFile, "tex" );
}

sub RunArrange {
    my @files = @_;
    print "             backspace : $BackSpace\n";
    print "              topspace : $TopSpace\n";
    print "           paperoffset : $PaperOffset\n";
    if ( $AddEmpty eq '' ) { print "     empty pages added : none\n" }
    else { print "     empty pages added : $AddEmpty\n" }
    if ( $TextWidth eq '0pt' ) { print "             textwidth : unknown\n" }
    else { print "             textwidth : $TextWidth\n" }
    open( ARR, ">$ArrangeFile.tex" );
    print ARR "% format=english\n";
    print ARR "\\definepapersize\n";
    print ARR "  [offset=$PaperOffset]\n";
    print ARR "\\setuplayout\n";
    print ARR "  [backspace=$BackSpace,\n";
    print ARR "    topspace=$TopSpace,\n";

    if ($Markings) {
        print ARR "     marking=on,\n";
        print "           cutmarkings : on\n";
    }
    print ARR "       width=middle,\n";
    print ARR "      height=middle,\n";
    print ARR "    location=middle,\n";
    print ARR "      header=0pt,\n";
    print ARR "      footer=0pt]\n";
    if ($NoDuplex) { print "                duplex : off\n" }
    else {
        print "                duplex : on\n";
        print ARR "\\setuppagenumbering\n";
        print ARR "  [alternative=doublesided]\n";
    }
    print ARR "\\starttext\n";
    foreach my $FileName (@files) {
        print "               pdffile : $FileName\n";
        print ARR "\\insertpages\n  [$FileName]";
        if ( $AddEmpty ne '' ) { print ARR "[$AddEmpty]" }
        print ARR "[width=$TextWidth]\n";
    }
    print ARR "\\stoptext\n";
    close(ARR);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $ModuleFile, "tex" );
}

sub RunSelect {
    my $FileName = shift;
    print "               pdffile : $FileName\n";
    print "             backspace : $BackSpace\n";
    print "              topspace : $TopSpace\n";
    print "           paperoffset : $PaperOffset\n";
    if ( $TextWidth eq '0pt' ) { print "             textwidth : unknown\n" }
    else { print "             textwidth : $TextWidth\n" }
    open( SEL, ">$SelectFile.tex" );
    print SEL "% format=english\n";
    print SEL "\\definepapersize\n";
    print SEL "  [offset=$PaperOffset]\n";
    if ($PaperFormat =~ /fit/) {
        print SEL "\\getfiguredimensions[$FileName]\n" ;
        print SEL "\\expanded{\\definepapersize[fit][width=\\figurewidth,height=\\figureheight]}\n" ;
        print SEL "\\setuppapersize[fit][fit]\n";
        $PaperFormat = '' ; # avoid overloading in option file
    } elsif ( $PaperFormat ne 'standard' ) {
        $_ = $PaperFormat;    # NO UPPERCASE !
        s/x/\*/io;
        my ( $from, $to ) = split(/\*/);
        if ( $to eq "" ) { $to = $from }
        print "             papersize : $PaperFormat\n";
        print SEL "\\setuppapersize[$from][$to]\n";
        $PaperFormat = '' ; # avoid overloading in option file
    }
    #
    print SEL "\\setuplayout\n";
    print SEL "  [backspace=$BackSpace,\n";
    print SEL "    topspace=$TopSpace,\n";
    if ($Markings) {
        print SEL "     marking=on,\n";
        print "           cutmarkings : on\n";
    }
    print SEL "       width=middle,\n";
    print SEL "      height=middle,\n";
    print SEL "    location=middle,\n";
    print SEL "      header=0pt,\n";
    print SEL "      footer=0pt]\n";
    print SEL "\\setupexternalfigures\n";
    print SEL "  [directory=]\n";
    print SEL "\\starttext\n";

    if ( $Selection ne '' ) {
        print SEL "\\filterpages\n";
        print SEL "  [$FileName][$Selection][width=$TextWidth]\n";
    }
    print SEL "\\stoptext\n";
    close(SEL);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $SelectFile, "tex" );
}

sub RunCopy {
    my $DoTrim = shift ;
    my @Files = @_ ;
    if ( $PageScale == 1000 ) {
        print "                offset : $PaperOffset\n";
    } else {
        print "                 scale : $PageScale\n";
        if ( $PageScale < 10 ) { $PageScale = int( $PageScale * 1000 ) }
    }
    open( COP, ">$CopyFile.tex" );
    print COP "% format=english\n";
    print COP "\\starttext\n";
    for my $FileName (@Files) {
        print "               pdffile : $FileName\n";
        print COP "\\getfiguredimensions\n";
        print COP "  [$FileName]\n";
        print COP "  [page=1";
        if ($DoTrim) {
            print COP ",\n   size=trimbox";
        }
        print COP "]\n";
        print COP "\\definepapersize\n";
        print COP "  [copy]\n";
        print COP "  [width=\\naturalfigurewidth,\n";
        print COP "   height=\\naturalfigureheight]\n";
        print COP "\\setuppapersize\n";
        print COP "  [copy][copy]\n";
        print COP "\\setuplayout\n";
        print COP "  [page]\n";
        print COP "\\setupexternalfigures\n";
        print COP "  [directory=]\n";
        print COP "\\copypages\n";
        print COP "  [$FileName]\n";
        print COP "  [scale=$PageScale,\n";
        if ($Markings) {
            print COP "   marking=on,\n";
            print "           cutmarkings : on\n";
        }
        if ($DoTrim) {
            print COP "   size=trimbox,\n";
            print "           cropping to : trimbox\n";
        }
        print COP "   offset=$PaperOffset]\n";
    }
    print COP "\\stoptext\n";
    close(COP);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $CopyFile, "tex" );
}

sub RunCombine {
    my @Files = @_;
    $Combination =~ s/x/\*/io;
    my ( $nx, $ny ) = split( /\*/, $Combination, 2 );
    return unless ( $nx && $ny );
    print "           combination : $Combination\n";
    open( COM, ">$CombineFile.tex" );
    print COM "% format=english\n";
    if ( $PaperFormat ne 'standard' ) {
        $_ = $PaperFormat;    # NO UPPERCASE !
        s/x/\*/io;
        my ( $from, $to ) = split(/\*/);
        if ( $to eq "" ) { $to = $from }
        print "             papersize : $PaperFormat\n";
        print COM "\\setuppapersize[$from][$to]\n";
    }
    #
    if ( $PaperOffset eq '0pt' ) { $PaperOffset = '1cm' }
    print "          paper offset : $PaperOffset\n";
    print COM "\\setuplayout\n";
    print COM "  [topspace=$PaperOffset,\n";
    print COM "   backspace=$PaperOffset,\n";
    print COM "   header=0pt,\n";
    print COM "   footer=1cm,\n";
    print COM "   width=middle,\n";
    print COM "   height=middle]\n";

    if ($NoBanner) {
        print COM "\\setuplayout\n";
        print COM "  [footer=0cm]\n";
    }
    print COM "\\setupexternalfigures\n";
    print COM "  [directory=]\n";
    print COM "\\starttext\n";
    for my $FileName (@Files) {
        next if ( $FileName =~ /^texexec/io );
        next if (($Result ne '') && ( $FileName =~ /^$Result/i ));
        print "               pdffile : $FileName\n";
        my $CleanFileName = CleanTeXFileName($FileName);
        print COM "\\setupfootertexts\n";
        print COM "  [\\tttf $CleanFileName\\quad\\quad\\currentdate\\quad\\quad\\pagenumber]\n";
        print COM "\\combinepages[$FileName][nx=$nx,ny=$ny]\n";
        print COM "\\page\n";
    }
    print COM "\\stoptext\n";
    close(COM);
    $ConTeXtInterface = "en";
    checktexformatpath ;
    RunConTeXtFile( $CombineFile, "tex" );
}

sub LocatedFormatPath { # watch out $engine is lowercase in kpse
    my $FormatPath = shift;
    my $EnginePath = shift;
    my $EngineDone = shift;
    if ($Local) {
        $FormatPath = '.' ; # for patrick
    } else {
        if ( ( $FormatPath eq '' ) && ( $kpsewhich ne '' ) ) {
            unless ($EngineDone) {
                my $str = $ENV{"TEXFORMATS"} ;
                $str =~ s/\$engine//io ;
                $ENV{"TEXFORMATS"} = $str ;
            }
            # expanded paths
            print "       assuming engine : $EnginePath\n";
            if (($UseEnginePath)&&($EngineDone)) {
                if ( $TeXShell =~ /MikTeX/io ) {
                    $FormatPath = `$kpsewhich --alias=$EnginePath --show-path=fmt` ;
                } else {
                    $FormatPath = `$kpsewhich --engine=$EnginePath --show-path=fmt` ;
                }
            } else {
                $FormatPath = `$kpsewhich --show-path=fmt` ;
            }
            chomp($FormatPath) ;
            if ( ( $FormatPath ne '' ) && $Verbose ) {
                print "located formatpath (1) : $FormatPath\n";
            }
            # fall back
            if ($FormatPath eq '') {
                if (($UseEnginePath)&&($EngineDone)) {
                    if ($dosish) {
                        if ( $TeXShell =~ /MikTeX/io ) {
                            $FormatPath = `$kpsewhich --alias=$EnginePath --expand-path=\$TEXFORMATS` ;
                        } else {
                            $FormatPath = `$kpsewhich --engine=$EnginePath --expand-path=\$TEXFORMATS` ;
                        }
                    } else {
                        $FormatPath = `$kpsewhich --engine=$EnginePath --expand-path=\\\$TEXFORMATS` ;
                    }
                }
                chomp($FormatPath) ;
                # either no enginepath or failed run
                if ($FormatPath eq '') {
                    if ($dosish) {
                        $FormatPath = `$kpsewhich --expand-path=\$TEXFORMATS` ;
                    } else {
                        $FormatPath = `$kpsewhich --expand-path=\\\$TEXFORMATS` ;
                    }
                }
                chomp $FormatPath ;
            }
            chomp($FormatPath) ;
            if ( ( $FormatPath ne '' ) && $Verbose ) {
                print "located formatpath (2) : $FormatPath\n";
            }
            $FormatPath =~ s/\\/\//g ;
            if ($FormatPath ne '') {
                my @fpaths ;
                if ($dosish) {
                    @fpaths = split(';', $FormatPath) ;
                } else {
                    @fpaths = split(':', $FormatPath) ;
                }
                #  take first writable unless current
                foreach my $fp (@fpaths) {
                    # remove funny patterns
                    $fp =~ s/\/+$// ;
                    $fp =~ s/^!!// ;
                    $fp =~ s/unsetengine/$EnginePath/ ;
                    if (($fp ne '') && ($fp ne '.')) {
                        # correct if needed
                        # append engine unless engine is already there
                        $fp =~ "$fp/$EnginePath" if ($fp =~ /[\\\/]$EnginePath[\\\/]*$/) ;
                        # path may not yet be present
                        # check if usable format path
                        my $fpp = $fp ;
                        $fpp =~ s/\/*$EnginePath\/*// ;
                        if ((-d $fpp) && (-w $fpp)) {
                            $FormatPath = $fpp ;
                            last ;
                        }
                    }
                }
            }
            $FormatPath = '.' if (($FormatPath eq '') || (! -w $FormatPath)) ;
            if ( ( $FormatPath ne '' ) && $Verbose ) {
                print "located formatpath (3) : $FormatPath\n";
            }
            $FormatPath .= '/';
        }
        if ($UseEnginePath && $EngineDone && ($FormatPath ne '') && ($FormatPath !~ /$EnginePath\/$/)) {
            $FormatPath .= $EnginePath ;
            unless (-d $FormatPath) {
                mkdir $FormatPath ;
            }
            $FormatPath .= '/' ;
        }
    }
    print "      using formatpath : $FormatPath\n" if $Verbose ;
    return $FormatPath;
}

sub RunOneFormat {
    my ($FormatName) = @_;
    my @TeXFormatPath;
    my $TeXPrefix = "";
    if ( ( $fmtutil ne "" ) && ( $FormatName !~ /metafun|mptopdf/io ) ) {
        # could not happen, not supported any more
        my $cmd = "$fmtutil --byfmt $FormatName";
        MakeUserFile;    # this works only when the path is kept
        MakeResponseFile;
        $Problems = System("$cmd");
        RemoveResponseFile;
        RestoreUserFile;
    } else {
        $Problems = 1;
    }
    if ($Problems) {
        $Problems = 0;
        if ( $TeXExecutable =~ /etex|eetex|pdfetex|pdfeetex|pdfxtex|xpdfetex|eomega|aleph|xetex/io ) {
            $TeXPrefix = "*";
        }
        my $CurrentPath = cwd();
        my $TheTeXFormatPath = LocatedFormatPath($TeXFormatPath, $TeXExecutable,1);
        if ( $TheTeXFormatPath ne '' ) { chdir $TheTeXFormatPath }
        MakeUserFile;
        MakeResponseFile;
	    $own_quote = ($TeXProgramPath =~ m/^[^\"].* / ? "\"" : "") ;
        my $cmd =
            "$own_quote$TeXProgramPath$TeXExecutable$own_quote $TeXVirginFlag "
          . "$TeXPassString $PassOn ${TeXPrefix}$FormatName";
        $Problems = System($cmd) ;
        RemoveResponseFile;
        RestoreUserFile;

        if ( ( $TheTeXFormatPath ne '' ) && ( $CurrentPath ne '' ) ) {
            print "\n";
            if ($UseEnginePath) {
                print " used engineformatpath : $TheTeXFormatPath\n";
            } else {
                print "       used formatpath : $TheTeXFormatPath\n";
            }
            print "\n";
            chdir $CurrentPath;
        }
    }
}

sub RunFormats {
    my $ConTeXtFormatsPrefix;
    my $MetaFunDone = 0;
    if (@ARGV) { @ConTeXtFormats = @ARGV }
    elsif ( $UsedInterfaces ne '' ) {
        @ConTeXtFormats = split /[\,\s]/, $UsedInterfaces;
    }
    if ($Format) { @ConTeXtFormats = $Format; $ConTeXtFormatsPrefix = ''; }
    else { $ConTeXtFormatsPrefix = "cont-"; }
    if ( $TeXHashExecutable ne '' ) {
        unless ($FastMode) {
            $own_quote = ($TeXProgramPath =~ m/^[^\"].* / ? "\"" : "") ;
            my $cmd = "$own_quote$TeXProgramPath$TeXHashExecutable$own_quote";
            print "\n";
            print "       TeX hash binary : $TeXProgramPath$TeXHashExecutable\n";
            print "               comment : hashing may take a while ...\n";
            System($cmd);
        }
    }
    foreach my $Interface (@ConTeXtFormats) {
        if ( $Interface eq $MetaFun ) {
            RunMpFormat($MetaFun);
            $MetaFunDone = 1;
        } elsif ( $Interface eq $MpToPdf ) {
            if ( $TeXExecutable =~ /pdf/io ) { RunOneFormat("$MpToPdf") }
        } else {
            RunOneFormat("$ConTeXtFormatsPrefix$Interface");
        }
    }
    print "\n";
    print "            TeX binary : $TeXProgramPath$TeXExecutable\n";
    print "             format(s) : @ConTeXtFormats\n\n";
}

sub RunMpFormat {
    # engine is not supported by MP
    my $MpFormat = shift;
    return if ( $MpFormat eq '' );
    my $CurrentPath = cwd();
    my $TheMpFormatPath = LocatedFormatPath($MpFormatPath,$MpExecutable,$MpEngineSupport);
    if ( $TheMpFormatPath ne '' ) { chdir $TheMpFormatPath }
    $own_quote = ($MpExecutable =~ m/^[^\"].* / ? "\"" : "") ;
    my $cmd =
      "$own_quote$MpExecutable$own_quote $MpVirginFlag $MpPassString $MpFormat";
    System($cmd ) ;
    if ( ( $TheMpFormatPath ne '' ) && ( $CurrentPath ne '' ) ) {
        print "\n";
        print "       used formatpath : $TheMpFormatPath\n";
        print "\n";
        chdir $CurrentPath;
    }
}


my $dir = File::Temp::tempdir(CLEANUP=>1) ;
my ($fh, $filename) = File::Temp::tempfile(DIR=>$dir, UNLINK=>1);

sub RunFiles {
    my $currentpath = cwd() ;
    my $oldrunpath = $RunPath ;
    # new
    checktexformatpath ;
    # test if current path is writable
    if (! -w "$currentpath") {
        print " current path readonly : $currentpath\n";
        #
        # we cannot use the following because then the result will
        # also be removed and users will not know where to look
        #
        # $RunPath = File::Temp::tempdir(CLEANUP=>1) ;
        # if ($RunPath) {
        #     print "       using temp path : $RunPath\n";
        # } else {
        #     print " problematic temp path : $currentpath\n";
        #     exit ;
        # }
        #
        foreach my $d ($ENV{"TMPDIR"},$ENV{"TEMP"},$ENV{"TMP"},"/tmp") {
            if ($d && -e $d) { $RunPath = $d ; last ; }
        }
        if ($TempDir eq '') {
            print " provide temp path for : $RunPath\n";
            exit ;
        } elsif ($RunPath ne $oldrunpath) {
            chdir ($RunPath) ;
            unless (-e $TempDir) {
                print " creating texexec path : $TempDir\n";
                mkdir ("$TempDir", 077)
            }
            if (-e $TempDir) {
                $RunPath += $TempDir ;
            } else {
                # we abort this run because on unix an invalid tmp
                # path can be an indication of a infected system
                print " problematic temp path : $RunPath\n";
                exit ;
            }
        } else {
            print " no writable temp path : $RunPath\n";
            exit ;
        }
    }
    # test if we need to change paths
    if (($RunPath ne "") && (-w "$RunPath")) {
        print "      changing to path : $RunPath\n";
        $InpPath = $currentpath ;
        chdir ($RunPath) ;
    }
    # start working
    if ($PdfArrange) {
        my @arrangedfiles = ();
        foreach my $JobName (@ARGV) {
            unless ( $JobName =~ /.*\.pdf$/oi ) {
                if ( -f "$JobName.pdf" ) { $JobName .= ".pdf" }
                else { $JobName .= ".PDF" }
            }
            push @arrangedfiles, $JobName;
        }
        if (@arrangedfiles) { RunArrange(@arrangedfiles) }
    } elsif ( ($PdfSelect) || ($PdfCopy) || ($PdfTrim) || ($PdfCombine) ) {
        my $JobName = $ARGV[0];
        if ( $JobName ne '' ) {
            unless ( $JobName =~ /.*\.pdf$/oi ) {
                if ( -f "$JobName.pdf" ) { $JobName .= ".pdf" }
                else { $JobName .= ".PDF" }
            }
            if    ($PdfSelect) {
                RunSelect($JobName) ;
            } elsif ($PdfCopy) {
                # RunCopy($JobName) ;
                RunCopy(0,@ARGV) ;
            } elsif ($PdfTrim) {
                # RunCopy($JobName) ;
                RunCopy(1,@ARGV) ;
            } else {
                # RunCombine ($JobName) ;
                RunCombine(@ARGV);
            }
        }
    } elsif ($TypesetModule) {
        RunModule(@ARGV);
    } else {
        my $JobSuffix = "tex";
        foreach my $JobName (@ARGV) {
            next if ($JobName =~ /^\-/io) ;
            # start experiment - full name spec including suffix is prerequisite
            if (($StartLine>0) && ($EndLine>=$StartLine) && (-e $JobName)) {
                if (open(INP,$JobName) && open(OUT,'>texexec.tex')) {
                    print "  writing partial file : $JobName\n";
                    my $Line = 1 ;
                    my $Preamble = 1 ;
                    while (my $str = <INP>) {
                        if ($Preamble) {
                            if ($str =~ /\\start(text|tekst|product|project|component)/io) {
                                $Preamble = 0 ;
                            } else {
                                print OUT $str;
                            }
                        } elsif ($Line==$StartLine) {
                            print OUT "\\starttext\n" ; # todo: multilingual
                            print OUT $str ;
                        } elsif ($Line==$EndLine) {
                            print OUT $str ;
                            print OUT "\\stoptext\n" ; # todo: multilingual
                            last ;
                        } elsif (($Line>$StartLine) && ($Line<$EndLine)) {
                            print OUT $str ;
                        }
                        $Line += 1 ;
                    }
                    close(INP) ;
                    close(OUT) ;
                    $JobName = 'texexec.tex' ;
                    print "        using job name : $JobName\n";
                }
            }
            # end experiment
            if ( $JobName =~ s/\.(\w+)$//io ) { $JobSuffix = $1 }
            if ( ( $Format eq '' ) || ( $Format =~ /^cont.*/io ) ) {
                RunConTeXtFile( $JobName, $JobSuffix );
            } else {
                RunSomeTeXFile( $JobName, $JobSuffix );
            }
            unless ( -s "$JobName.log" ) { unlink("$JobName.log") }
            unless ( -s "$JobName.tui" ) { unlink("$JobName.tui") }
        }
    }
}

my $MpTmp = "tmpgraph";      # todo: prefix met jobname
my $MpKep = "$MpTmp.kep";    # sub => MpTmp("kep")
my $MpLog = "$MpTmp.log";
my $MpBck = "$MpTmp.bck";
my $MpTex = "$MpTmp.tex";
my $MpDvi = "$MpTmp.dvi";

my %mpbetex;

sub RunMP {                  ###########
    if ( ($MpExecutable) && ($MpToTeXExecutable) && ($DviToMpExecutable) ) {
        foreach my $RawMpName (@ARGV) {
            my ( $MpName, $Rest ) = split( /\./, $RawMpName, 2 );
            my $MpFile = "$MpName.mp";
            if ( -e $MpFile
                and ( -s $MpFile > 25 ) )    # texunlink makes empty file
            {
                unlink "$MpName.mpt";
                doRunMP( $MpName, 0 );
                # test for graphics, new per 14/12/2000
                my $mpgraphics = checkMPgraphics($MpName);
                # test for labels
                my $mplabels = checkMPlabels($MpName);
                if ( $mpgraphics || $mplabels ) {
                    doRunMP( $MpName, $mplabels );
                }
            }
        }
    }
}

my $mpochecksum = '';

#~ sub checkMPgraphics {    # also see makempy
    #~ my $MpName = shift;
    #~ if ( $MakeMpy ne '' ) { $MpName .= " --$MakeMpy " }    # extra switches
    #~ if ($MpyForce)        { $MpName .= " --force " }       # dirty
    #~ else {
        #~ return 0 unless -s "$MpName.mpo" > 32;
        #~ return 0 unless ( open( MPO, "$MpName.mpo" ) );
        #~ $mpochecksum = do { local $/; unpack( "%32C*", <MPO> ) % 65535 };
        #~ close(MPO);
        #~ if ( open( MPY, "$MpName.mpy" ) ) {
            #~ my $str = <MPY>;
            #~ chomp $str;
            #~ close(MPY);
            #~ if ( $str =~ /^\%\s*mpochecksum\s*\:\s*(\d+)/o ) {
                #~ return 0 if ( ( $mpochecksum eq $1 ) && ( $mpochecksum ne 0 ) );
            #~ }
        #~ }
    #~ }
    #~ RunPerlScript( "makempy", "$MpName" );
    #~ print "  second MP run needed : text graphics found\n";
    #~ return 1;
#~ }

sub checkMPgraphics {    # also see makempy
    my $MpName = shift;
    if ( $MakeMpy ne '' ) { $MpName .= " --$MakeMpy " }    # extra switches
    if ($MpyForce)        { $MpName .= " --force " }       # dirty
    else {
        return 0 unless -s "$MpName.mpo" > 32;
        return 0 unless ( open( MPO, "$MpName.mpo" ) );
        $mpochecksum = do { local $/; Digest::MD5::md5_hex(<MPO>) ; };
        close(MPO);
        if ( open( MPY, "$MpName.mpy" ) ) {
            my $str = <MPY>;
            chomp $str;
            close(MPY);
            if ( $str =~ /^\%\s*mpochecksum\s*\:\s*([a-fA-F0-9]+)/o ) {
                return 0 if ( ( $mpochecksum eq $1 ) && ( $mpochecksum ne '' ) );
            }
        }
    }
    RunPerlScript( "makempy", "$MpName" );
    print "  second MP run needed : text graphics found\n";
    return 1;
}

sub checkMPlabels {
    my $MpName = shift;
    return 0 unless ((-f "$MpName.mpt") && ((-s "$MpName.mpt")>10) );
    return 0 unless open( MP, "$MpName.mpt" );
    my $n = 0;
    my $t = "" ;
    while (<MP>) {
        if (/% setup : (.*)/o) {
            $t = $1 ;
        } else {
            $t = "" ;
        }
        if (/% figure (\d+) : (.*)/o) {
            if ($t ne "") {
                $mpbetex{$1} .= "$t\n" ;
                $t = "" ;
            }
            $mpbetex{$1} .= "$2\n";
            ++$n ;
        }
    }
    close(MP);
    print "  second MP run needed : $n tex labels found\n" if $n;
    return $n;
}

sub doMergeMP {
    # make sure that the verbatimtex ends up before btex etc
    my ($n,$str) = @_ ;
    if ($str =~ /(.*?)(verbatimtex.*?etex)\s*\;(.*)/mois) {
        return "beginfig($n)\;\n$1$2\;\n$mpbetex{$n}\n$3\;endfig\;\n" ;
    } else {
        return "beginfig($n)\;\n$mpbetex{$n}\n$str\;endfig\;\n" ;
    }
}

sub doRunMP {    ###########
    my ( $MpName, $MergeBE ) = @_;
    my $TexFound = 0;
    my $MpFile   = "$MpName.mp";
    if ( open( MP, $MpFile ) ) {    # fails with %
        my $MPdata = "";
        while (<MP>) {
            unless (/^\%/) { $MPdata .= $_ }
        }
        $_ = $MPdata;
        close(MP);

        # save old file
        unlink($MpKep);
        return if ( -e $MpKep );
        rename( $MpFile, $MpKep );
        # check for tex stuff

        $TexFound = $MergeBE || /btex .*? etex/o;

        # shorten lines into new file if okay
        unless ( -e $MpFile ) {
            open( MP, ">$MpFile" );
            s/(btex.*?)\;(.*?etex)/$1\@\@\@$2/gmois;
            s/(\".*?)\;(.*?\")/$1\@\@\@$2/gmois; # added
            s/\;/\;\n/gmois;
            s/\n\n/\n/gmois;
            s/(btex.*?)\@\@\@(.*?etex)/$1\;$2/gmois;
            s/(\".*?)\@\@\@(.*?\")/$1\;$2/gmois; # added
            # merge labels
            if ($MergeBE) {
                # i hate this indirect (sub regexp) mess
                s/beginfig\s*\((\d+)\)\s*\;(.*?)endfig\s*\;/doMergeMP($1,$2)/gems ;
            }
            unless (/beginfig\s*\(\s*0\s*\)/gmois) {
                if (defined($mpbetex{0})) { # test added, warning
                    print MP $mpbetex{0} ;
                }
            }
            print MP $_;
            print MP "\n" . "end" . "\n";
            close(MP);
        }
        if ($TexFound) {
            print "       metapost to tex : $MpName\n";
            $own_quote = ($MpToTeXExecutable =~ m/^[^\"].* / ? "\"" : "") ;
            $Problems =
              System("$own_quote$MpToTeXExecutable$own_quote $MpFile > $MpTex");
            if ( -e $MpTex && !$Problems ) {
                open( TMP, ">>$MpTex" );
                print TMP "\\end\{document\}\n";    # to be sure
                close(TMP);
                if ( ( $Format eq '' ) || ( $Format =~ /^cont.*/io ) ) {
                    $OutputFormat = "dvips";
                    RunConTeXtFile( $MpTmp, "tex" );
                } else {
                    RunSomeTeXFile( $MpTmp, "tex" );
                }
                if ( -e $MpDvi && !$Problems ) {
                    print "       dvi to metapost : $MpName\n";
                    $own_quote = ($DviToMpExecutable =~ m/^[^\"].* / ? "\"" : "") ;
                    $Problems = System("$own_quote$DviToMpExecutable$own_quote $MpDvi $MpName.mpx");
                }
                unlink $MpBck;
                rename $MpTex, $MpBck;
                unlink $MpDvi;
            }
        }
        print "              metapost : $MpName\n";
        $own_quote = ($MpExecutable =~ m/^[^\"].* / ? "\"" : "") ;
        my $cmd = "$own_quote$MpExecutable$own_quote";
        if ($EnterBatchMode)   { $cmd .= " $MpBatchFlag " }
        if ($EnterNonStopMode) { $cmd .= " $MpNonStopFlag " }
        if ( ( $MpFormat ne '' ) && ( $MpFormat !~ /(plain|mpost)/oi ) ) {
            print "                format : $MpFormat\n";
            $cmd .= " $MpPassString $MpFormatFlag$MpFormat ";
        }
        # prevent nameclash, experimental
        my $MpMpName = "$MpName";
        $Problems = System("$cmd $MpMpName");
        open( MPL, "$MpName.log" );
        while (<MPL>)    # can be one big line unix under win
        {
            while (/^l\.(\d+)\s/gmois) {
                print " error in metapost run : $MpName.mp:$1\n";
            }
        }
        close(MPL) ;
        unlink "mptrace.tmp";
        rename( $MpFile, "mptrace.tmp" );
        if ( -e $MpKep ) {
            unlink($MpFile);
            rename( $MpKep, $MpFile );
        }
    }
}

sub RunMPX {
    my $MpName = shift;
    $MpName =~ s/\..*$//o;
    my $MpFile = $MpName . ".mp";
    if (   ($MpToTeXExecutable)
        && ($DviToMpExecutable)
        && ( -e $MpFile )
        && ( -s $MpFile > 5 )
        && open( MP, $MpFile ) )
    {
        local $/ = "\0777";
        $_ = <MP>;
        close(MP);
        if (/(btex|etex|verbatimtex)/mos) {
            print "   generating mpx file : $MpName\n";
	    $own_quote = ($MpToTeXExecutable =~ m/^[^\"].* / ? "\"" : "") ;
            $Problems =
              System("$own_quote$MpToTeXExecutable$own_quote $MpFile > $MpTex");
            if ( -e $MpTex && !$Problems ) {
                open( TMP, ">>$MpTex" );
                print TMP "\\end\n";    # to be sure
                close(TMP);
                checktexformatpath ;
                if ( ( $Format eq '' ) || ( $Format =~ /^cont.*/io ) ) {
                    RunConTeXtFile( $MpTmp, "tex" );
                } else {
                    RunSomeTeXFile( $MpTmp, "tex" );
                }
                if ( -e $MpDvi && !$Problems ) {
		    $own_quote = ($DviToMpExecutable =~ m/^[^\"].* / ? "\"" : "") ;
                    $Problems =
                      System("$own_quote$DviToMpExecutable$own_quote $MpDvi $MpName.mpx");
                }
                unlink $MpTex;
                unlink $MpDvi;
            }
        }
    }
}

sub load_set_file {
    my %new;
    my %old;
    my ( $file, $trace ) = @_;
    if ( open( BAT, $file ) ) {
        while (<BAT>) {
            chomp;
            if (/\s*SET\s+(.+?)\=(.+)\s*/io) {
                my ( $var, $val ) = ( $1, $2 );
                $val =~ s/\%(.+?)\%/$ENV{$1}/goi;
                unless ( defined( $old{$var} ) ) {
                    if ( defined( $ENV{$var} ) ) { $old{$var} = $ENV{$var} }
                    else { $old{$var} = "" }
                }
                $ENV{$var} = $new{$var} = $val;
            }
        }
        close(BAT);
    }
    if ($trace) {
        foreach my $key ( sort keys %new ) {
            if ( $old{$key} ne $new{$key} ) {
                print " changing env variable : '$key' from '$old{$key}' to '$new{$key}'\n";
            } elsif ( $old{$key} eq "" ) {
                print "  setting env variable : '$key' to '$new{$key}'\n";
            } else {
                print "  keeping env variable : '$key' at '$new{$key}'\n";
            }
        }
        print "\n";
    }
}

if ( $SetFile ne "" ) { load_set_file( $SetFile, $Verbose ) }

sub check_texmf_root { }
sub check_texmf_tree { }

sub AnalyzeVersion
  { my $str = join("\n", @_) ;
    my ($texengine,$type) = ('unknown', 'unknown');
    open (LOG, "<texvers.log") ;
    while (<LOG>)
       { /^\s*This is (.*(pdf)?(|e|x)TeX.*?)$/o and $texengine = $1 ;
	    /^\s*ConTeXt  (.*int: ([a-z]+).*?)\s*$/o and  $type   = $1; }
	 $type =~ s/  int: ([a-z]+)//;
	 $texengine =~ s/ Version//;
	 $texengine =~ s/ \(format.*$//;
     close (LOG);
    return ($texengine,$type) }

sub show_version_info {
  my ($texengine,$type);
  open (TEX,">texvers.tex") ;
  print TEX "\\bye " ;
  close (TEX) ;
  my $texutil = `$TeXUtil --help`;
  $texutil =~ s/.*(TeXUtil[^\n]+)\n.*?$/$1/s;
  print "               texexec :$Program\n" ;
  print "               texutil : $texutil" ;
  my $contexttext =  `$kpsewhich context.tex`;
  my $contextversion = "<not found>";
  if ($contexttext) {
	chop $contexttext;
	{ local $/;
	  open (IN,"<$contexttext");
	  $contextversion = <IN>;
	  close IN;
	}
	$contextversion =~ s/.*contextversion\{([0-9\.\:\s]+)\}.*/$1/s;
  }
  $EnterBatchMode = 1;
  $Format = 'cont-en';
  my $cmd = PrepRunTeX("texvers","tex",'') ;
  ($texengine,$type) = AnalyzeVersion(Pipe($cmd)) ;
  print "                   tex : $texengine\n" ;
  print "               context : ver: $contextversion\n" ;
  print "               cont-en : $type\n" ;
  foreach my $a (qw(cz de fr it nl ro uk xx)) {
	my $test = Pipe("$kpsewhich -format='fmt' cont-$a") ;
	if (defined $test && $test) {
	  $Format = 'cont-' . $a;
	  $cmd = PrepRunTeX("texvers","tex",'');
	  ($texengine,$type) = AnalyzeVersion(Pipe($cmd)) ;
	  print "               cont-$a : $type\n" ;
	}
  }
  unlink <texvers.*>;
}

# the main thing

if ($HelpAsked) {
    show_help_info
} elsif ($Version) {
    show_version_info
} elsif ($TypesetListing) {
    check_texmf_root;
    check_texmf_tree;
    RunListing(@ARGV);
} elsif ($TypesetFigures) {
    check_texmf_root;
    check_texmf_tree;
    RunFigures(@ARGV);
} elsif ($DoMPTeX) {
    check_texmf_root;
    check_texmf_tree;
    RunMP;
} elsif ($DoMPXTeX) {
    check_texmf_root;
    check_texmf_tree;
    RunMPX( $ARGV[0] );
} elsif ($MakeFormats) {
    check_texmf_root;
    check_texmf_tree;
    if ( $MpDoFormat ne '' ) {
        RunMpFormat($MpDoFormat) ;
    }
    else {
        RunFormats ;
    }
} elsif (@ARGV) {
    check_texmf_root;
    check_texmf_tree;
    @ARGV = <@ARGV>;
    RunFiles;
} elsif ( !$HelpAsked ) {
    show_help_options;
}

$TotalTime = time - $TotalTime;

unless ($HelpAsked) { print "\n        total run time : $TotalTime seconds\n" }

print "\n" ;
print "               warning : use 'texmfstart texexec' instead\n" ;

if ($Problems) { exit 1 }

__DATA__
arrange process and arrange
-----------
batch run in batch mode (don't pause)
-----------
nonstop run in non stop mode (don't pause)
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
fullscreen force full screen mode (pdf)
-----------
screensaver turn graphic file into a (pdf) full screen file
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
=fr French
=cz Czech
=uk British
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
mpxtex generate an MetaPost mpx file
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
=pdftex   Han The Thanh's pdf backend
=dvips    Tomas Rokicky's dvi to ps converter
=dvipsone YandY's dvi to ps converter
=dviwindo YandY's windows previewer
=dvipdfm  Mark Wicks' dvi to pdf converter
=dvipdfmx Jin-Hwan Cho's extended dvipdfm
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
nobanner no footerline
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
textree additional texmf tree to be used
=path subpath of tex root
-----------
texroot root of tex trees
=path tex root
-----------
verbose shows some additional info
-----------
help show this or more, e.g. '--help interface'
-----------
alone bypass utilities (e.g. fmtutil for non-standard fmts)
-----------
texutil force TeXUtil run
-----------
version display various version information
-----------
setfile load environment (batch) file
