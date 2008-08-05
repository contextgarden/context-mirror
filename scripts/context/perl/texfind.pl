eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D \module
#D   [       file=texfind.pl,
#D        version=1998.05.10,
#D          title=\TEXFIND, 
#D       subtitle=searching files, 
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
#C details. 

# test with "doif(un|)defined"

use strict ; 
use Getopt::Long ;
use File::Find ;
use Cwd ;
use Tk ; 
use Tk::widgets  ; 
use Tk::ROText ;

use FindBin ;
use lib $FindBin::Bin ;
use path_tre ; 

my $FileSuffix    = 'tex' ; 
my $SearchString  = '' ; 
my $Recurse       = 0 ; 
my $NumberOfHits  = 0 ;
my $QuitSearch    = 0 ; 
my $Location      = '' ;
my $currentpath   = '.' ;

my @FileList ; 

my ($dw, $mw, $log, $sea, $fil, $num, $but, $dir, $loc) ; 

$mw = MainWindow -> new () ; 
$dw = MainWindow -> new () ; 

$mw -> protocol( 'WM_DELETE_WINDOW' => sub { exit } ) ;
$dw -> protocol( 'WM_DELETE_WINDOW' => sub { exit } ) ;

$log = $mw -> Scrolled  ( 'ROText' ,
                          -scrollbars => 'se'           ,
                                -font => 'courier'      ,
                                -wrap => 'none'         , 
                               -width => 65             ,
                              -height => 22             )
           -> pack      (       -side => 'bottom'       ,
                                -padx => 2              , 
                                -pady => 2              ,
                              -expand => 1              ,
                                -fill => 'both'         ) ;

$sea = $mw -> Entry  (  -textvariable => \$SearchString , 
                                -font => 'courier'      ,
                               -width => 20             )
           -> pack   (          -side => 'left'         , 
                                -padx => 2              , 
                                -pady => 2              ) ;

$fil = $mw -> Entry  (  -textvariable => \$FileSuffix   ,
                                -font => 'courier'      ,
                               -width => 5              ) 
           -> pack   (          -side => 'left'         , 
                                -padx => 2              , 
                                -pady => 2              ) ;

$but = $mw -> Checkbutton ( -variable => \$Recurse      ,
                                -text => 'recurse'      )  
           -> pack   (          -side => 'left'         ) ; 

$num = $mw -> Entry  (  -textvariable => \$NumberOfHits , 
                                -font => 'courier'      ,
                             -justify => 'right'        ,
                               -width => 5              )
           -> pack   (          -side => 'right'        , 
                                -padx => 2              , 
                                -pady => 2              ) ;

$loc = $mw -> Entry  (  -textvariable => \$Location     , 
                                -font => 'courier'      ,
                               -width => 8              )
           -> pack   (          -side => 'right'        , 
                                -padx => 2              , 
                                -pady => 2              ) ;

sub BuildDir 
  {  if (Exists($dir)) { $dir -> destroy } ;
     $dir = $dw -> Scrolled ( 'PathTree' ,
                               -scrollbars => 'se'         ) 
                -> pack     (      -expand => 1            , 
                                     -fill => 'both'       ,
                                     -padx => 2            , 
                                     -pady => 2            ) ;
     $dir -> configure      (        -font => 'courier'    ,
                                   -height => 24           , 
                                    -width => 65           , 
                         -selectbackground => 'blue3'      ,
                                -browsecmd => \&ChangePath ) ;
     $dir -> bind ('<Return>'   , \&ShowFile  ) ; 
     $dir -> bind ('<Double-1>' , \&ShowFile  ) }

BuildDir ;

sub ShowFile { $mw -> raise ; $sea -> focusForce } 
sub ShowPath { $dw -> raise ; $dir -> focusForce } 

$log -> tagConfigure ( 'found', -foreground => 'green3' ) ;
$log -> tagConfigure ( 'title', -foreground => 'blue3' ) ;

$sea -> bind ('<Return>'   , \&LocateStrings  ) ;
$fil -> bind ('<Return>'   , \&LocateStrings  ) ;
$loc -> bind ('<Return>'   , \&ChangeLocation ) ; 
$log -> bind ('<Return>'   , \&ShowPath       ) ; 

$sea -> bind ('<KeyPress>' , \&QuitSearch     ) ;
$fil -> bind ('<KeyPress>' , \&QuitSearch     ) ;
$loc -> bind ('<KeyPress>' , \&QuitSearch     ) ; 

$sea -> bind ('<Escape>'   , \&QuitSearch     ) ;
$fil -> bind ('<Escape>'   , \&QuitSearch     ) ;
$loc -> bind ('<Escape>'   , \&QuitSearch     ) ;
$log -> bind ('<Escape>'   , \&QuitSearch     ) ;

$sea -> bind ('<Double-1>' , \&LocateStrings  ) ; 
$fil -> bind ('<Double-1>' , \&LocateStrings  ) ; 
$loc -> bind ('<Double-1>' , \&ChangeLocation ) ; 
$log -> bind ('<Double-1>' , \&ShowPath       ) ; 

sub ChangePath 
  { my $currentpath = shift ; 
chdir($currentpath) ; 
    $QuitSearch = 1 ; 
    $log -> delete ('1.0', 'end') ;
    $log -> insert ('end', "$currentpath\n\n", 'title') }

sub ChangeLocation
  { $QuitSearch = 1 ;
    $log -> delete ('1.0', 'end') ;
    $Location =~ s/^\s*//o ;
    $Location =~ s/\s*$//o ;    
    $Location =~ s/(\\|\/\/)/\//go ;    
    unless (-d $Location) 
      { unless ($Location =~ /\//) { $Location .= '/' } }
    if (-d $Location) 
      { $log -> insert ('end', "changed to location '$Location'\n\n", 'title') ;
        $currentpath = $Location ;
        chdir ($currentpath) ;
        $dir -> destroy ; 
        BuildDir ;  
        $dw -> raise ; 
        $dw -> focusForce } 
    else
      { $log -> insert ('end', "unknown location '$Location'\n\n", 'title') ;
        $Location = '' } }

sub QuitSearch 
  { $QuitSearch = 1 } 

sub SearchFile 
  { my ($FileName, $SearchString) = @_ ; 
    my $Ok = 0 ; my $len ; 
    open (TEX, $FileName) ; 
    my $LineNumber = 0 ; 
    while (<TEX>) 
      { ++$LineNumber ; 
        if ($QuitSearch) 
          { if ($Ok) { $log -> see ('end') }
            last } 
        if (/$SearchString/i)
          { ++$NumberOfHits ; $num -> update ; 
            unless ($Ok) 
              { $Ok = 1 ; 
                $log -> insert ('end', "$FileName\n\n",'title') }
            $log -> insert ('end', sprintf("%5i : ",$LineNumber), 'title') ;
            s/^\s*//o ;
#
            $len = 0 ; 
            while (/(.*?)($SearchString)/gi)
              { $len += length($1) + length($2) ;  
                $log -> insert ('end', "$1") ; 
                $log -> insert ('end', "$2", 'found' ) }
            $_ = substr($_,$len) ;  
            $log -> insert ('end', "$_") ;
#
            $log -> update ;
            $log -> see ('end') } } 
    if ($Ok) { $log -> insert ('end', "\n") }
    close (TEX) } 

sub DoLocateFiles 
  { @FileList = () ; 
    $NumberOfHits = 0 ; 
    if ($FileSuffix ne "") 
      { $log -> delete ('1.0', 'end') ;
        if ($Recurse)
          { $log -> insert ('end', "recursively identifying files\n", 'title') ;
            $log -> see ('end') ;
            find (\&wanted, $currentpath) ;
            sub wanted 
              { if ($QuitSearch) { last ; return } 
                if (/.*\.$FileSuffix/i) 
                  { ++$NumberOfHits ; $num -> update ; 
                    push @FileList, $File::Find::name } } } 
        else  
          { $log -> insert ('end', "identifying files\n", 'title') ;
            $log -> see ('end') ;
            opendir(DIR, $currentpath) ; my @TEMPLIST = readdir(DIR) ; closedir(DIR) ;
            foreach my $FileName (@TEMPLIST) 
              { if ($FileName =~ /.*\.$FileSuffix/i) 
                  { ++$NumberOfHits ; $num -> update ; 
                    if ($QuitSearch) 
                      { last } 
                    push @FileList, $FileName } } } 
        @FileList = sort @FileList } }

sub DoLocateStrings
  { $log -> delete ('1.0', 'end') ; 
    $log -> update ; 
    $log -> see ('end') ; 
    $NumberOfHits = 0 ; 
    if ($SearchString ne "") 
      { foreach my $FileName (@FileList) 
          { if ($QuitSearch) 
              { $log -> insert ('end', "search aborted\n", 'title') ;
                $log -> see ('end') ; 
                last } 
            SearchFile($FileName,$SearchString) } } 
    unless ($QuitSearch) 
      { $log -> insert ('end', "done\n", 'title') ;
        $log -> see ('end') } }

sub LocateStrings
  { $QuitSearch = 0 ; 
    DoLocateFiles() ; 
    DoLocateStrings() } 

$log -> insert ('end', 

  "data fields\n\n" , '' ,  


  "string   :", 'title', " regular expression to search for\n"   , '' ,
  "suffix   :", 'title', " type of file to search in\n"          , '' ,
  "recurse  :", 'title', " enable searching subpaths\n"          , '' ,
  "location :", 'title', " drive of root path\n"                 , '' ,
  "counter  :", 'title', " file/hit counter\n\n"                 , '' ,

  "key bindings\n\n" , '' ,  

  "double 1 :", 'title', " directory window <-> search window\n" , '' ,
  "enter    :", 'title', " start searching\n"                    , '' ,
  "escape   :", 'title', " quit searching\n\n"                   , '' ,
  
  "current path\n\n" , '' , 
 
  cwd(), 'title', "\n\n" , 'title' ) ; 

$log -> update ; 

ShowPath ; 

MainLoop() ;
