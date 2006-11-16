eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

# MikTeX users can set environment variable TEXSYSTEM to "miktex".

#D \module
#D   [       file=mptopdf.pl,
#D        version=2000.05.29,
#D          title=converting MP to PDF,
#D       subtitle=\MPTOPDF,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D            url=www.pragma-ade.nl,
#D      copyright={PRAGMA ADE / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

# use File::Copy ; # not in every perl

use Config ;
use Getopt::Long ;
use strict ;
use File::Basename ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

my $Help = my $Latex = my $RawMP = my $MetaFun = 0 ;
my $PassOn = '' ;

&GetOptions
  ( "help"    => \$Help  ,
    "rawmp"   => \$RawMP,
    "metafun" => \$MetaFun,
    "passon"  => \$PassOn,
    "latex"   => \$Latex ) ;

my $program = "MPtoPDF 1.3.2" ;
my $pattern = "@ARGV" ; # was $ARGV[0]
my $miktex  = 0 ;
my $done    = 0 ;
my $report  = '' ;
my $texlatexswitch = " --tex=latex --format=latex " ;
my $mplatexswitch = " --tex=latex " ;

my $dosish      = ($Config{'osname'} =~/^(ms)?dos|^os\/2|^mswin/i) ;
my $escapeshell = (($ENV{'SHELL'}) && ($ENV{'SHELL'} =~ m/sh/i ));

if ($ENV{"TEXSYSTEM"}) {
    $miktex = ($ENV{"TEXSYSTEM"} =~ /miktex/io) ;
}

my @files ;
my $command = my $mpbin = ''  ;

# agressive copy, works for open files like in gs

sub CopyFile {
    my ($From,$To) = @_ ;
    return unless open(INP,"<$From") ;
    return unless open(OUT,">$To") ;
    binmode INP ;
    binmode OUT ;
    while (<INP>) {
        print OUT $_ ;
    }
    close (INP) ;
    close (OUT) ;
}

if (($pattern eq '')||($Help)) {
    print "\n$program : provide MP output file (or pattern)\n" ;
    exit ;
} elsif ($pattern =~ /\.mp$/io) {
    shift @ARGV ; my $rest = join(" ", @ARGV) ;
    if (open(INP,$pattern)) {
        while (<INP>) {
            if (/(documentstyle|documentclass|begin\{document\})/io) {
                $Latex = 1 ; last ;
            }
        }
        close (INP) ;
    }
    if ($RawMP) {
        if ($Latex) {
            $rest .= " $mplatexswitch" ;
        }
        if ($MetaFun) {
            $mpbin = "mpost --progname=mpost --mem=metafun" ;
        } else {
            $mpbin = "mpost --mem=mpost" ;
        }
    } else {
        if ($Latex) {
            $rest .= " $texlatexswitch" ;
        }
        $mpbin = "texexec --mptex $PassOn" ;
    }
    print "\n$program : running '$mpbin'\n" ;
    my $error =  system ("$mpbin $rest $pattern") ;
    if ($error) {
        print "\n$program : error while processing mp file\n" ;
        exit ;
    } else {
        $pattern =~ s/\.mp$//io ;
        @files = glob "$pattern.*" ;
    }
} elsif (-e $pattern) {
    @files = ($pattern) ;
} elsif ($pattern =~ /.\../o) {
    @files = glob "$pattern" ;
} else {
    $pattern .= '.*' ;
    @files = glob "$pattern" ;
}

foreach my $file (@files) {
    $_ = $file ;
    if (s/\.(\d+|mps)$// && -e $file) {
        if ($miktex) {
            $command = "pdftex -undump=mptopdf" ;
        } else {
            $command = "pdftex -fmt=mptopdf -progname=context" ;
        }
        if ($dosish) {
            $command = "$command \\relax $file" ;
        } else {
            $command = "$command \\\\relax $file" ;
        }
        system($command) ;
        my $pdfsrc = basename($_).".pdf";
        rename ($pdfsrc, "$_-$1.pdf") ;
        if (-e $pdfsrc) {
            CopyFile ($pdfsrc, "$_-$1.pdf") ;
        }
        if ($done) {
            $report .= " +" ;
        }
        $report .= " $_-$1.pdf" ;
        ++$done  ;
    }
}

if ($report eq '') {
    $report = '*' ;
}

if ($done) {
    print "\n$program : $pattern is converted to$report\n" ;
} else {
    print "\n$program : no filename matches $pattern\n" ;
}
