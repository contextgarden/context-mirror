#D \module
#D   [       file=fdf2tan.pl,
#D        version=2000.02.06,
#D          title=converting \FDF\ annotations,
#D       subtitle=fdf2tan,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

#D This is a preliminary version, that will probably be changed 
#D and merged into a more general module. 

use Text::Wrap ; 

my $filename = $ARGV[0] ; exit if ($filename eq '') ;

$filename =~ s/\..*$//o ;

my $D  = "[0-9\-\.]" ;
my $nn = 0 ; 

my %stack ;

sub saveobject
  { $n = shift ; $str = shift ;
    if ($n>$max) { $max = $n } 
    if ($str =~ s/\/Type\s+\/Annot\s+\/Subtype\s+\/Text//o)
      { ++$nn ; 
        $str =~ s/\/Page\s+(\d+)//o ;
        $page = $1 ; ++$page ;  
        $str =~ s/\/Rect\s+\[\s*(.*?)\s*\]//o ;
        $rec = $1 ; 
        if ($rec =~ /($D+)\s*($D+)\s*($D+)\s*($D+)/o) 
         { $FDFllx = $1 ; $FDFlly = $2 ; $FDFurx = $3 ; $FDFury = $4 }  
        $X = $FDFllx - $PDFllx ; 
        $Y = $PDFury - $FDFury ; 
        $str =~ s/\/M\s.*$//o ;
        $str =~ s/\/T\s.*$//o ;
        $str =~ s/^.*\/Contents\s.*?\(//o ;
        $str =~ s/\)\s+$//o ;
        $str =~ s/\\\\r/@@@@@@/o ;
        $str =~ s/\\r/\n/go; 
        $str =~ s/@@@@@@/\\r/o ;
        $str =~ s/\\([\<\>\(\)\{\}\\])/$1/go  ; 
        $stack{sprintf("test:%3d %3d %3d\n",$page,$Y,$X)} = 
          "\\startFDFcomment[$page]" . 
          sprintf("[%.3f,%.3f]",$X,$Y) . 
          "\n$str\n\\stopFDFcomment\n\n" } } 

exit unless (open (PDF,"<$filename.pdf")) ; binmode PDF ; 
exit unless (open (FDF,"<$filename.fdf")) ; 
exit unless (open (TAN,">$filename.tan")) ; 

print "processing $filename ... " ; 

$PDFllx = 0 ; $PDFlly = 0 ; $PDFurx = 597 ; $PDFury = 847 ;

while (<PDF>) 
  { if (/\/MediaBox\s*\[\s*($D+)\s*($D+)\s*($D+)\s*($D+)/o) 
      { $PDFllx = $1 ; $PDFlly = $2 ; $PDFurx = $3 ; $PDFury = $4 ;
        last } }
 
$_ = "" ; while ($Line=<FDF>) { chomp $Line; $_ .= $Line }

s/\\n/ /go ; 
s/\\\s//go ;

s/\\225/\\\/L/go ; s/\\226/\\OE/go ; s/\\227/\\vS/go  ;
s/\\230/\\"Y/go  ; s/\\231/\\vZ/go ; s/\\233/\\\/l/go ;
s/\\234/\\oe/go  ; s/\\235/\\vs/go ; s/\\236/\\vz/go  ;
s/\\253/\\<</go  ; s/\\273/\\>>/go ; s/\\300/\\`A/go  ; 
s/\\301/\\'A/go  ; s/\\302/\\^A/go ; s/\\303/\\~A/go  ;
s/\\304/\\"A/go  ; s/\\305/\\oA/go ; s/\\306/\\AE/go  ;
s/\\307/\\,C/go  ; s/\\310/\\`E/go ; s/\\311/\\'E/go  ;
s/\\312/\\^E/go  ; s/\\313/\\"E/go ; s/\\314/\\`I/go  ;
s/\\315/\\'I/go  ; s/\\316/\\^I/go ; s/\\317/\\"I/go  ;
s/\\321/\\~N/go  ; s/\\322/\\`O/go ; s/\\323/\\'O/go  ;
s/\\324/\\^O/go  ; s/\\325/\\~O/go ; s/\\326/\\"O/go  ;
s/\\330/\\\/O/go ; s/\\331/\\`U/go ; s/\\332/\\'U/go  ; 
s/\\333/\\^U/go  ; s/\\334/\\"U/go ; s/\\335/\\'Y/go  ;
s/\\337/\\SS/go  ; s/\\340/\\`a/go ; s/\\341/\\'a/go  ;
s/\\342/\\^a/go  ; s/\\343/\\~a/go ; s/\\344/\\"a/go  ; 
s/\\345/\\oa/go  ; s/\\346/\\ae/go ; s/\\347/\\,c/go  ; 
s/\\350/\\`e/go  ; s/\\351/\\'e/go ; s/\\352/\\^e/go  ;
s/\\353/\\"e/go  ; s/\\354/\\`i/go ; s/\\355/\\'i/go  ;
s/\\356/\\^i/go  ; s/\\357/\\"i/go ; s/\\361/\\~n/go  ;
s/\\362/\\`o/go  ; s/\\363/\\'o/go ; s/\\364/\\^o/go  ;
s/\\365/\\~o/go  ; s/\\366/\\"o/go ; s/\\370/\\\/o/go ;
s/\\371/\\`u/go  ; s/\\372/\\'u/go ; s/\\373/\\^u/go  ;
s/\\374/\\"u/go  ; s/\\375/\\'y/go ; s/\\377/\\"y/go  ;

s/\\(\d\d\d)/[$1]/go  ; 

while (s/(\d+)(\s+\d+\s+obj)(.*?)endobj/saveobject($1,$3)/goe) { } 

$wrap::columns = 80 ; 

foreach $key (sort keys %stack) 
  { print TAN wrap("","",$stack{$key}) } 

close (PDF) ; close (FDF) ; close (TAN) ; 

if (open (TAN,">fdf-tan.tex")) 
  { print TAN "% interface=en output=pdftex\n\n"    .
              "\\setupcolors[state=start]\n\n"      .
              "\\setupinteraction[state=start]\n\n" .
              "\\setupbodyfont[pos,10pt]\n\n"       .
              "\\starttext\n\n"                     . 
              "\\usemodule[fdfann]\n\n"             .
              "\\annotatepages[$filename]\n\n"      .
              "\\stoptext\n" ; 
    close (TAN) } 

print "$nn annotations found, run 'texexec fdf-tan'\n" ; 
