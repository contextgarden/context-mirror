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

$program = "MPtoPDF 1.1" ;
$pattern = $ARGV[0] ;
$done    = 0 ;
$report  = '' ;

my $dosish = ($Config{'osname'} =~ /dos|mswin/io) ;
my $miktex = ($ENV{"TEXSYSTEM"} =~ /miktex/io); 

sub CopyFile # agressive copy, works for open files like in gs 
  { my ($From,$To) = @_ ; 
    return unless open(INP,"<$From") ; binmode INP ; 
    return unless open(OUT,">$To") ; binmode OUT ; 
    while (<INP>) { print OUT $_ } 
    close (INP) ; 
    close (OUT) }

if (($pattern eq '')||($pattern =~ /^\-+(h|help)$/io))
  { print "\n$program: provide MP output file (or pattern)\n" ;
    exit }
elsif ($pattern =~ /\.mp$/io) 
  { $error = system ("texexec --mptex $pattern") ;
    if ($error) 
      { print "\n$program: error while processing mp file\n" ; exit } 
    else 
      { $pattern =~ s/\.mp$//io ; 
        @files = glob "$pattern.*" } } 
elsif (-e $pattern)
  { @files = ($pattern) }
elsif ($pattern =~ /.\../o)
  { @files = glob "$pattern" }
else
  { $pattern .= '.*' ;
    @files = glob "$pattern" }

foreach $file (@files)
  { $_ = $file ;
    if (s/\.(\d+|mps)$// && -e $file)
      { if ($miktex) 
          { if ($dosish) 
              { $command = "pdfetex   &mptopdf" } 
            else
              { $command = "pdfetex \\&mptopdf" } }
        else 
          { $command = "pdfetex -progname=pdfetex -efmt=mptopdf" } 
        if ($dosish)  
          { system ("$command   \\relax $file") }
        else
          { system ("$command \\\\relax $file") }
        rename ("$_.pdf", "$_-$1.pdf") ;
        if (-e "$_.pdf") { CopyFile ("$_.pdf", "$_-$1.pdf") }
        if ($done) { $report .= " +" }
        $report .= " $_-$1.pdf" ;
        ++$done } }

if ($done)
  { print "\n$program: $pattern is converted to$report\n" }
else
  { print "\n$program: no filename matches $pattern\n" }
