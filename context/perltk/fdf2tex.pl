eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

# not yet public 

# We're dealing with:

$InpFile = $ARGV[0] ; $OutFile = $ARGV[1] ; $Field = $ARGV[2] ; 

# beware: fields are funny sorted

$Program = "fdf2tex 1.02 - ConTeXt / PRAGMA 1997-2000" ;

if ($Field eq "") 
 { print "\n$Program\n\n" }

# filter \type{filename.fdf} into \type{filename.fdt}

unless ($OutFile)
  { $OutFile = $InpFile ;
    $OutFile =~ s/\..*// }

unless ($InpFile=~/\./)
  { if (-e "$InpFile.fdf") 
      { $InpFile .= ".fdf" }
    elsif (-e "$InpFile.xml") 
      { $InpFile .= ".xml" } }

unless ($OutFile=~/\./)
  { $OutFile .= ".fdt" }

if (open (FDF, "<$InpFile"))
  { binmode FDF ;
    open (FDT, ">$OutFile") ;
    if ($Field eq "") 
      { print "            input file : $InpFile\n" ;
        print "           output file : $OutFile\n" } }
else
  { if ($Field eq "") 
      { print "                 error : $InpFile not found\n" }
    exit }

# load the whole file in the buffer

$_ = "" ; while ($Line=<FDF>) { chomp $Line; $_ .= $Line }

# or faster: dan ///s gebruiken (ipv m) 

# $/ = "\0777" ; $_ = <FDF> ;

# zoom in on the objects and remove the header and trialer

if ($InpFile =~ /\.xml$/) 

{ # begin kind of xml alternative 

s/\>\s*\</\>\</goms ; 
$N = s/\<field\s+(.*?)\/\>/\\FDFfield\[$1\]\n/goms ;
s/(name|value)\=\"(.*?)\"/$1=\{$2\}/goms ; 
s/\} (name|value)/\}\,$1/goms ; 
s/\<fdfobject\>(.*?)\<\/fdfobject\>/\\beginFDFobject\n$1\\endFDFobject\n/goms ; 
s/\<fdfdata\>(.*?)\<\/fdfdata\>/\\beginFDFdata\n$1\\endFDFdata\n/goms ; 
s/\<fdffields\>(.*?)\<\/fdffields\>/\\beginFDFfields\n$1\\endFDFfields\n/goms ; 

} # end kind of xml alternative 

else 

{ # begin fdf alternative

s/.*?obj\s*?<<(.*?)>>\s*?endobj/\n\\beginFDFobject$1\n\\endFDFobject/go;
s/trailer.*//;

# zoom in on the FDF data

s/\/FDF.*?<<(.*)>>/\n\\beginFDFdata$1\n\\endFDFdata/go;

# zoom in on the Field collection and remove whatever else

s/\/Fields.*?\[.*?<<.*?(.*).*?>>.*?\]/\n\\beginFDFfields<<$1>>\n\\endFDFfields/go;
s/\\endFDFfields.*\n\\endFDFdata/\\endFDFfields\n\\endFDFdata/go;

# tag each field

$N = s/\<<(.*?)>>/\n\\FDFfield[$1]/go;

# remove non relevant entries, but keep \type{/T} and \type{/V}

s/\s*?\/[Kids|Opt]\s*?<<.*?>>//go;
s/\s*?\/[Ff|setFf|ClrFf|F|SetF|ClrF]\s*?\d*?//go;
s/\s*?\/[AP|A|AS]\s*?\[.*?\]//go;
s/\s*?\/AS\s*?\/.*?\s//go;

# format the field identifier

s/(.*?)\/T.*?\((.*?)\)/$1 name=$2,/go;

# format the value, which can be a name or string

s/\/V\s?\((.*?)\)/value=\{$1\},/go;
s/\/V\s?\/(.*?)[\s|\/]/value=\{$1\},/go;

# sanitize some special \TeX\ tokens

s/(\#|\$|\&|\^|\_|\|)/\\$1/go;

# remove spaces and commas

#s/\s?([name|value])/$1/go;
s/\[\s*/\[/go;
s/,\]/\]/go;

# convert PDFDocEncoding

s/\\225/\\\/L/ ;
s/\\226/\\OE/ ;
s/\\227/\\vS/ ;
s/\\230/\\"Y/ ;
s/\\231/\\vZ/ ;
s/\\233/\\\/l/ ;
s/\\234/\\oe/ ;
s/\\235/\\vs/ ;
s/\\236/\\vz/ ;
s/\\253/\\<</ ;
s/\\273/\\>>/ ;
s/\\300/\\`A/ ;
s/\\301/\\'A/ ;
s/\\302/\\^A/ ;
s/\\303/\\~A/ ;
s/\\304/\\"A/ ;
s/\\305/\\oA/ ;
s/\\306/\\AE/ ;
s/\\307/\\,C/ ;
s/\\310/\\`E/ ;
s/\\311/\\'E/ ;
s/\\312/\\^E/ ;
s/\\313/\\"E/ ;
s/\\314/\\`I/ ;
s/\\315/\\'I/ ;
s/\\316/\\^I/ ;
s/\\317/\\"I/ ;
s/\\321/\\~N/ ;
s/\\322/\\`O/ ;
s/\\323/\\'O/ ;
s/\\324/\\^O/ ;
s/\\325/\\~O/ ;
s/\\326/\\"O/ ;
s/\\330/\\\/O/ ;
s/\\331/\\`U/ ;
s/\\332/\\'U/ ;
s/\\333/\\^U/ ;
s/\\334/\\"U/ ;
s/\\335/\\'Y/ ;
s/\\337/\\ss/ ;
s/\\340/\\`a/ ;
s/\\341/\\'a/ ;
s/\\342/\\^a/ ;
s/\\343/\\~a/ ;
s/\\344/\\"a/ ;
s/\\345/\\oa/ ;
s/\\346/\\ae/ ;
s/\\347/\\,c/ ;
s/\\350/\\`e/ ;
s/\\351/\\'e/ ;
s/\\352/\\^e/ ;
s/\\353/\\"e/ ;
s/\\354/\\`i/ ;
s/\\355/\\'i/ ;
s/\\356/\\^i/ ;
s/\\357/\\"i/ ;
s/\\361/\\~n/ ;
s/\\362/\\`o/ ;
s/\\363/\\'o/ ;
s/\\364/\\^o/ ;
s/\\365/\\~o/ ;
s/\\366/\\"o/ ;
s/\\370/\\\/o/ ;
s/\\371/\\`u/ ;
s/\\372/\\'u/ ;
s/\\373/\\^u/ ;
s/\\374/\\"u/ ;
s/\\375/\\'y/ ;
s/\\377/\\"y/ ;

s/\\\</\</ ; 
s/\\\>/\>/ ; 
s/\\\(/\(/ ; 
s/\\\)/\)/ ; 
s/\#/\\#/ ;

# convert newline and return commands

s/\\n/ /go;
s/\\r/\\par /go;

} # end fdf alternative 

# flush buffer

print FDT $_ ;

close FDT ;
close FDF ;

# report some characteristics

if ($Field eq "") 
  { print "      number of fields : $N\n" }
else 
  { if (/\\FDFfield\[value\=\{(.*)\}\,\s*name=$Field/mos)
      { print "$1" }       
    elsif (/\\FDFfield\[name=$Field\,\s*value\=\{(.*)\}/mos)
      { print "$1" } }      
