#D \module
#D   [       file=cont\_set.pm,
#D        version=1999.04.01,
#D          title=General modules,
#D       subtitle=showing \CONTEXT\ commands,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten},
#D    suggestions={Tobias Burnus \& Taco Hoekater}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

# todo: tacos speed patch

#D As always: thanks to Taco and Tobias for testing this
#D module and providing suggestions and code snippets as
#D well as haunting bugs.

package cont_set ;

#D This module (package) deals with providing help information
#D about the \CONTEXT\ commands. The data needed is derived
#D from the setup files by \CONTEXT\ itself. The data is
#D stored in files with suffix \type {tws} (tex work setup).
#D This module introduces some subroutines:
#D
#D \starttabulatie[|Tl|p|]
#D \NC \type {set\_setup\_interface}   \NC sets the primary interface
#D                                     to search in \NC \NR
#D \NC \type {set\_setup\_title}       \NC sets the title of the main
#D                                     window title \NC \NR
#D \NC \type {setups\_found}           \NC locate the \type {tws} files
#D                                     using the \type {kpsewhich}
#D                                     program \NC \NR
#D \NC \type {show\_setups}            \NC allocate the radio buttons
#D                                     that can be used to select a
#D                                     command set \NC \NR
#D \NC \type {load\_setup(filename)}   \NC load the names \type {tws}
#D                                     file \NC \NR
#D \NC \type {load\_setups}            \NC all found command files can
#D                                     be loaded at once \NC \NR
#D \NC \type {setup\_found(filename)}  \NC this routine returns~1 when
#D                                     the file is loaded \NC \NR
#D \NC \type {update\_setup}           \NC when we browse the list with
#D                                     commands, this routine takes care
#D                                     of updating the text area \NC \NR
#D \NC \type {change\_setup}           \NC we can manually set the
#D                                     command set we want to browse,
#D                                     and this routine takes care of
#D                                     this \NC \NR
#D \NC \type {show\_setup(command)}    \NC context sensitive help can be
#D                                     provided by calling this sub \NC \NR
#D \stoptabulatie
#D
#D First we load some packages and set some constants.

use Tk ;
use Tk::ROText ;
use Config ;

use strict;

use subs qw/ update_setup / ;

my $dosish       = ($Config{'osname'} =~ /dos|win/i) ;
my $default_size = $dosish ? 9 : 12 ;

my $textfont     = "Courier   $default_size       " ;
my $userfont     = "Courier   $default_size italic" ;
my $buttonfont   = "Helvetica $default_size bold  " ;

unless ($dosish)
  { $textfont   = "-adobe-courier-bold-r-normal--$default_size-120-75-75-m-70-iso8859-1" ;
    $userfont   = "-adobe-courier-bold-o-normal--$default_size-120-75-75-m-70-iso8859-1" ;
    $buttonfont = "-adobe-helvetica-bold-r-normal--$default_size-120-75-75-p-69-iso8859-1" }

my $s_vertical   = 30 ;
my $s_horizontal = 72 ;
my $c_horizontal = 24 ;

#D The main window is not resizable, but the text area and
#D command list will have scrollbars.

my %lw ; # stack of lists

my $mw = MainWindow -> new ( -title => 'ConTeXt commands' ) ;

$mw -> withdraw() ; $mw -> resizable ('y', 'y') ;

sub SetupWindow { return $mw } ;

my $bw = $mw -> Frame () ; # buttons
my $tw = $mw -> Frame () ; # sw + fw
my $fw = $tw -> Frame () ; # string + list

my $request  = $fw -> Entry (       -font => $textfont ,
                              -background => 'ivory1' ,
                                   -width => $c_horizontal ) ;

my $cw       = $fw -> Scrolled (             'Listbox'     ,
                              -scrollbars => 'e'           ,
                                    -font => $textfont     ,
                                   -width => $c_horizontal ,
                        -selectbackground => 'gray'        ,
                              -background => 'ivory1'      ,
                              -selectmode => 'browse'      ) ;

$cw      -> pack ( -side => 'bottom' , -fill => 'both' , -expand => 1 ) ;
$request -> pack ( -side => 'top'    , -fill => 'x' ) ;

my $sw = $tw -> Scrolled (                'ROText'      ,
                           -scrollbars => 'se'          ,
                               -height => $s_vertical   ,
                                -width => $s_horizontal ,
                                 -wrap => 'none'        ,
                           -background => 'ivory1'      ,
                                 -font => $textfont     ) ;


#D And the whole bunch of widgets are packed in the main
#D window.

sub pack_them_all
  { $sw -> pack ( -side => 'left'  , -fill => 'both' , -expand => 1 ) ;
    $fw -> pack ( -side => 'right' , -fill => 'y'    , -expand => 0 ) ;
    $bw -> pack ( -side => 'top'   , -fill => 'x'    , -anchor => 'w'  , -expand => 1 ) ;
    $tw -> pack ( -side => 'bottom', -fill => 'both' , -expand => 1 ) }

sub unpack_them_all
  { }

pack_them_all ;

#D We scan for available setup files, with suffix \type {tws}.
#D These should be somewhere on the system, grouped in one
#D directory. At least the english file \type {cont-en.tws}
#D should be found.

my $tws_path        = '' ;
my @setup_files     = ('cont-en.tws') ;
my $setup_file      = $setup_files[0] ;
my $setup_interface = 'en' ;
my $old_setup_file  = '' ;

sub set_setup_interface
  { $setup_interface = shift }

sub set_setup_title
  { $mw -> configure ( -title => shift ) }

sub setups_found
  { $tws_path = `kpsewhich --format="other text files" --progname=context cont-en.tws` ;
    $tws_path =~ s/cont-en\.tws.*// ;
    chop $tws_path ;
    @setup_files = glob ("$tws_path*.tws") ;
    if (@setup_files)
      { foreach (@setup_files) { s/\.tws// ; s/.*\/// }
        $setup_file = $setup_files[0] ;
        return 1 }
    else
      { return 0 } }

#D A hide button

sub show_hide_button
  { my $hb = $bw -> Button (     -text => "hide" ,
                                  -font => $buttonfont    ,
                               -command => \&hide_widget  ) ;
    $hb -> pack ( -padx => '2p',
                  -pady => '2p',
                  -side => 'right' ) }

sub hide_widget
  { $mw -> withdraw() }

#D The setup files can be shown and chosen.

sub show_setups
  { unpack_them_all ;
    foreach (@setup_files)
      { $lw{$_} = $bw -> Radiobutton (     -text => lc $_          ,
                                          -value => $_             ,
                                           -font => $buttonfont    ,
                                    -selectcolor => 'ivory1'       ,
                                    -indicatoron => 0              ,
                                        -command => \&change_setup ,
                                       -variable => \$setup_file   ) ;
        $lw{$_} -> pack ( -padx => '2p',
                          -pady => '2p',
                          -side => 'left' ) }
    pack_them_all }

$cw -> bind ('<B1-Motion>', \&update_setup ) ;
$cw -> bind ('<1>'        , \&update_setup ) ;
$cw -> bind ('<Key>'      , \&update_setup ) ;

$sw -> tag ('configure', 'user'     ,       -font => $userfont ) ;
$sw -> tag ('configure', 'command'  , -foreground => 'green3'  ) ;
$sw -> tag ('configure', 'variable' ,       -font => $userfont ) ;
$sw -> tag ('configure', 'default'  ,  -underline => 1         ) ;
$sw -> tag ('configure', 'symbol'   , -foreground => 'blue3'   ) ;
$sw -> tag ('configure', 'or'       , -foreground => 'yellow3' ) ;
$sw -> tag ('configure', 'argument' , -foreground => 'red3'    ) ;
$sw -> tag ('configure', 'par'      ,   -lmargin1 => '4m'      ,
                                        -lmargin2 => '6m'      ) ;

my %setups ;
my %commands ;
my %loadedsetups ;
my %positions ;
my %crosslinks ;

my $current_setup  = '' ;

#D Setups are organized in files called \type {*.tws} and
#D alike. Several files can be loaded simultaneously. When
#D loading, we grab whole paragraphs. The variables and values
#D belonging to a command, are stored in the hash table \type
#D {setups}, one per language. The command templates are
#D stored in \type {commands}.
#D
#D A \type {tws} file is generated by \CONTEXT\ from the setup
#D definition files. Only \CONTEXT\ knows the current meaning
#D of commands and keywords. The files are generating by
#D simply saying something like:
#D
#D \starttypen
#D texexec  --interface=en  setupd
#D texexec  --interface=de  setupd
#D texexec  --interface=nl  setupd
#D texexec  --interface=cz  setupd
#D texexec  --interface=it  setupd
#D \stoptypen
#D
#D This results in files formatted as:
#D
#D \starttypen
#D startsetup
#D com:setupcolors
#D typ:vars/
#D var:state:start,stop,global,local:
#D var:conversion:yes,no,always:
#D var:reduction:yes,no:
#D var:rgb:yes,no:
#D var:cmyk:yes,no:
#D stopsetup
#D \stoptypen
#D
#D This format can be stored rather efficient and parsed rather
#D fast. What more do we need.

sub load_setup
  { my $filename = shift ;
    unless (keys %{$commands{$filename}})
      { local $/ = 'stopsetup' ; # in plaats van '' ivm unix ; (taco)
        $current_setup = '' ;
        if (open(SETUP, "$tws_path$filename.tws" ))
          { my $position = 0 ;
            while (<SETUP>)
              { chomp  ;
                s/startsetup//mso ;
                s/stopsetup//mso ; # redundant geworden
                s/\r\n //gms ;     # in plaats van s/ //gms ; (taco)
                s/com\:(.*?)\:\s(.*)//mso ;
                my $string = $1 ;
                my $command = $1 ;
                my $setup = $2 ;
                ++$position ;
                $string =~ s/(.*?)\<\<(.*?)\>\>(.*?)/$1$2$3/o ;
                $setups    {$filename}{$string}   = $setup ;
                $commands  {$filename}{$string}   = $command ;
                $positions {$filename}{$string}   = $position ;
                $crosslinks{$filename}[$position] = $string }
            close (SETUP) } }
    my @list = sort {lc $a cmp lc $b} keys %{$commands{$filename}} ;
    $cw -> delete ('0.0', 'end') ;
    $cw -> insert ('end', @list) ;
    $cw -> selectionSet ('0.0', '0.0') ;
    $cw -> activate ('0.0') ;
    $setup_file = $filename ;
    update_setup }

sub load_setups
  { foreach my $setup (@setup_files) { load_setup ($setup) } ;
    $mw -> deiconify() }

#D The core of this module deals with transforming the
#D definitions like shown earlier. Details on the format
#D can be found in the file \type {setupd.tex}. We use the
#D \type {Tk::Text} automatic hanging identation features.
#D The next subs are examples of the kind you write once
#D and never look at again.

my @arguments      = () ;
my $nested_setup   = 0  ;
my $continue_setup = 0  ;
my $argument       = 0  ;
my $stopsuffix     = '' ;
my $stopcommand    = '' ;

my %arg ;

$arg {repeat} = '//n*/'                   ;
$arg {arg}    = 'argument/{/.../}'        ;
$arg {args}   = 'argument/{/..,...,../}'  ;
$arg {dis}    = 'argument/$$/.../$$'      ;
$arg {idx}    = 'argument/{/.../}'        ;
$arg {idxs}   = 'argument/{/..+...+../}'  ;
$arg {mat}    = 'argument/$/...:$'        ;
$arg {nop}    = '//.../'                  ;
$arg {fil}    = '//.../'                  ;
$arg {pos}    = 'symbol/(/.../)'          ;
$arg {poss}   = 'symbol/(/...,.../)'      ;
$arg {sep}    = 'command//\\\\/'          ;
$arg {ref}    = 'symbol/[/ref/]'          ;
$arg {refs}   = 'symbol/[/ref,../]'       ;
$arg {val}    = 'symbol/[/.../]'          ;
$arg {vals}   = 'symbol/[/..,...,../]'    ;
$arg {var}    = 'symbol/[/..=../]'        ;
$arg {vars}   = 'symbol/[/..,..=..,../]'  ;
$arg {cmd}    = 'command//\cmd/'          ;
$arg {dest}   = 'symbol/[/..ref/]'        ;
$arg {dests}  = 'symbol/[/..,..refs,../]' ;
$arg {trip}   = 'symbol/[/x:y:z=/]'       ;
$arg {trips}  = 'symbol/[/x:y:z=,../]'    ;
$arg {wrd}    = 'argument/{/.../}'        ;
$arg {wrds}   = 'argument/{/......./}'    ;
$arg {par}    = 'command//\par/'          ;
$arg {stp}    = '//stop/'                 ;
$arg {par}    = 'command///'              ;

sub show_command
  { my $command = shift ;
    local $_ = $commands{$setup_file}{$command} ;
    if ($command eq $_)
      { $sw -> insert ('end', "\\$command", 'command' ) }
    elsif (/(.*?)\<\<(.*?)\>\>(.*?)/o)
      { $sw -> insert ('end', "\\", 'command' ) ;
        if ($1) { $sw -> insert ('end', $1, 'command' ) }
        if ($2) { $sw -> insert ('end', $2, ['command','user'] ) }
        if ($3) { $sw -> insert ('end', $3, 'command' ) }
        $stopsuffix = $2 } }

sub show_left_argument
  { local $_ = shift ;
    my @thearg = split (/\//, $arg{$arguments[$_]}) ;
    $sw -> insert ('end', $thearg[1], ['par',$thearg[0]] ) }

sub show_middle_argument
  { local $_ = shift ;
    my @thearg = split (/\//, $arg{$arguments[$_]}) ;
    if ($thearg[1])
      { $sw -> insert ('end', $thearg[2], 'par' ) }
    else
      { $sw -> insert ('end', $thearg[2], ['par',$thearg[0]] ) } }

sub show_right_argument
  { local $_ = shift ;
    my @thearg = split (/\//, $arg{$arguments[$_]}) ;
    $sw -> insert ('end', $thearg[3], ['par',$thearg[0]] ) ;
    ++$argument }

sub show_reference
  { if (($nested_setup<=1)&&(defined($arguments[$argument])))
      { if ($arguments[$argument]=~/ref/)
          { $sw -> insert ('end', "\n" ) ;
            show_left_argument ($argument) ;
            show_middle_argument ($argument) ;
            show_right_argument ($argument) } } }

sub show_stop_command
  { my $before_stop = shift ;
    if ($stopcommand)
      { if ($stopsuffix)
          { $sw -> insert ('end', '\\stop', 'command' ) ;
            $sw -> insert ('end', $stopsuffix, ['command','user'] ) }
        else
          { $sw -> insert ('end', $stopcommand, 'command' ) } } }

sub show_whatever_left
  { while ($argument<@arguments)
      { $sw -> insert ('end', "\n" ) ;
        show_left_argument ($argument) ;
        show_middle_argument ($argument) ;
        show_right_argument ($argument) ;
        ++$argument }
    if ($stopcommand)
      { $sw -> insert ('end', "\n...\n...\n...\n", 'par') ;
        show_stop_command } }

sub do_update_setup                # type: 0=all 1=vars 2=vals
  { my ($command, $type) = @_ ;
    my $setup = $setups{$setup_file}{$command} ;
    my $default = '' ;
    my $key = '' ;
    my $meaning = '' ;
    my @values = () ;
    local $_ ;
    ++$nested_setup ;
    while ($setup=~/(typ|var|val|ivr|ivl)\:(.*?)\:\s/mgo)
      { $key = $1 ;
        $meaning = $2 ;
        if    (($key=~/var/o)&&($type!=2))
          { $_ = $meaning ; s/(.*?)\:(.*?)\:(.*)//o ;
            if (($nested_setup>1)&&(!$2)) { next }
            $key = $1 ;
            if ($3) { $default = $3 } else { $default = '' }
            $_= $2 ; s/\s//go ; @values = split (/,/,$_) ;
            if ($continue_setup)
              { $sw -> insert ('end', ",\n ", 'par') }
            else
              { $continue_setup = 1 ;
                $sw -> insert ('end', "\n", 'par') ;
                show_left_argument($argument) }
            $sw -> insert ('end', $key , 'par' ) ;
            $sw -> insert ('end', '=', ['symbol','par'] ) ;
           #while (1)
            while (@values)
              { my $value = shift @values ;
                if ($value =~ /^\*/o)
                  { $value =~ s/^\*//o ;
                    $sw -> insert ('end', lc $value, ['variable','par'] ) }
                elsif ($value eq $default)
                  { $sw -> insert ('end', $value, ['default','par'] ) }
                else
                  { $sw -> insert ('end', $value, 'par' ) }
                if (@values)
                  { $sw -> insert ('end', '|' , ['or','par'] ) }
                else
                  { last } } }
        elsif (($key=~/val/o)&&($type!=1))
          { $_ = $meaning ; s/(.*)\:(.*)//o ;
            if (($nested_setup>1)&&(!$2)) { next }
            $_ = $1 ; s/\s//go ; @values = split (/,/,$_) ;
            if ($2) { $default = $2 } else { $default = '' }
            if ($continue_setup)
              { $continue_setup = 0 ;
                show_right_argument($argument) }
            $sw -> insert ('end', "\n" , 'par') ;
            show_left_argument($argument) ;
           #while (1)
            while (@values)
              { unless (@values) { last }
                my $value = shift (@values) ;
                if ($value =~ /^\*/o)
                  { $value =~ s/^\*//o ;
                    $sw -> insert ('end', lc $value, ['variable','par'] ) }
                elsif ($value eq $default)
                  { $sw -> insert ('end', $value, ['default','par'] ) }
                else
                  { $sw -> insert ('end', $value, 'par' ) }
                if (@values)
                  { $sw -> insert ('end', ', ', 'par' ) }
                else
                  { last } }
            show_right_argument($argument) }
        elsif ($key=~/typ/o)
         { if ($nested_setup==1)
             { show_command ($command) ;
               my $arguments = $meaning ;
               if ($arguments=~/stp/)
                 { $_ = $command ;
                   s/start(.*)/$1/o ;
                   $stopcommand = "\\stop$_" ;
                   $arguments =~ s/stp//go }
               @arguments = split (/\//,$arguments) ;
               if (@arguments)
                 { for (my $i=0;$i<@arguments;$i++)
                    { show_left_argument ($i) ;
                      show_middle_argument ($i) ;
                      show_right_argument ($i) }
                   if ($stopcommand)
                     { $sw -> insert ('end', ' ... ') ;
                       show_stop_command }
                   $sw -> insert ('end', "\n\n") ;
                   show_command ($command) }
               $argument = 0 ;
               $continue_setup = 0 } }
        elsif ($key=~/ivr/o)
          { $meaning =~ s/(.*)\:(.*)//o ;
            do_update_setup ($1,1) }
        elsif ($key=~/ivl/o)
          { $meaning =~ s/(.*)\:(.*)//o ;
            do_update_setup ($1,2) }
        show_reference }
   --$nested_setup ;
   if (($continue_setup)&&(!$nested_setup))
     { show_right_argument ;
       show_whatever_left } }

#D Now the real work is done, we only have to define a few
#D housekeeping routines. The next sub adapts the text area
#D to the current selected command and normally is bound to
#D the list browsing commands.

sub update_setup
 { $old_setup_file = $setup_file ;
   if (keys %{$commands{$setup_file}})
     { my $key ;
       unless ($cw->curselection)
         { $cw -> selectionSet('0.0','0.0') }
       $key = $cw -> get($cw->curselection) ;
       if ($current_setup ne $key)
         { $current_setup = $key ;
           $sw -> delete ('1.0', 'end' ) ;
           $nested_setup = 0 ;
           $argument = 0 ;
           $stopcommand = '' ;
           $stopsuffix = '' ;
           do_update_setup ($key,0) ;
           $mw -> raise ;
           $mw -> focus } } }

#D In editors we want to provide context sensitive help
#D information. The next sub first tries to locate the
#D commands asked for in the setup data currently selected,
#D and when not found takes a look at all the loaded files.

sub show_setup
  { my $asked_for = shift ;
    unless ($asked_for) { return }
    my $found = 0 ;
    $asked_for =~ s/^\\// ;
    if ($setup_interface)
      { $found = 0 ;
        foreach my $name (@setup_files)
          { if (($name=~/\-$setup_interface/)&&(exists($commands{$name}{$asked_for})))
              { $found = 1 ;
                $setup_file = $name ;
                last } } }
    if (!($found)&&(exists($commands{$setup_file}{$asked_for})))
      { $found = 1 }
    else
      { $found = 0 ;
        foreach my $name (@setup_files)
          { if (exists($commands{$name}{$asked_for}))
              { $found = 1 ;
                $setup_file = $name ;
                last } } }
    if ($found)
      { my @list = sort {lc $a cmp lc $b} keys %{$commands{$setup_file}} ;
        $cw -> delete ('0.0', 'end') ;
        $cw -> insert ('end', @list) ;
        $found = 0 ;
        foreach (@list) { if ($_ eq $asked_for) { last } ++$found }
        my $index = "$found.0" ;
        $cw -> selectionSet ($index, $index) ;
        $cw -> activate ($index) ;
        $cw -> see ($index) ;
        update_setup ;
        $mw -> raise ;
        $mw -> focus } }

#D Whenever a new set of commands is selected (by means of the
#D buttons on top the screen) the list and text are to be
#D updated.

sub change_setup
  { my $command = '' ;
    if ($old_setup_file)
      { unless ($cw->curselection)
         { $cw -> selectionSet('0.0','0.0') }
        $command = $cw -> get($cw->curselection) ;
        my $position = $positions{$old_setup_file}{$command} ;
        $command = $crosslinks{$setup_file}[$position] }
    load_setup($setup_file) ;
    my @list = sort {lc $a cmp lc $b} keys %{$commands{$setup_file}} ;
    $cw -> delete ('0.0', 'end') ;
    $cw -> insert ('end', @list) ;
    if ($command)
      { show_setup($command) }
    else
      { $cw -> selectionClear ('0.0','end') ;
        $cw -> selectionSet ('0.0', '0.0') ;
        $cw -> see ('0.0') ;
        $cw -> activate ('0.0') }
    update_setup ;
    $mw -> raise ;
    $mw -> focus }

#D Sometimes we want to make sure the dat is loaded indeed:

sub setup_found
  { my $filename = shift ;
    if (-e "$tws_path$filename.tws")
      { $setup_file = $filename ;
        return 1 }
    else
      { return 0 } }

#D The next feature is dedicated to Tobias, who suggested
#D it, and Taco, who saw it as yet another proof of the
#D speed of \PERL. It's also dedicated to Ton, who needs it
#D for translating the big manual.

sub handle_request
  { my $index = $cw -> index('end') ;
    unless ($index) { return }
    my $req = $request -> get ;
    unless ($req) { return }
    $req =~ s/\\//o ;
    $req =~ s/\s//go ;
    $request -> delete('0','end') ;
    $request -> insert('0',$req) ;
    unless ($req) { return }
    my ($l,$c) = split (/\./,$index) ;
    for (my $i=0;$i<=$l;$i++)
      { $index = "$i.0" ;
        my $str = $cw -> get ($index, $index) ;
        if ($str =~ /^$req/)
          { $cw -> selectionClear ('0.0','end') ;
            $cw -> selectionSet ($index, $index) ;
            $cw -> activate ($index) ;
            $cw -> see ($index) ;
            update_setup ;
            $mw -> raise ;
            $mw -> focus ;
            return } } }

$request -> bind ('<Return>', sub { handle_request } ) ;

sub insert_request
  { my ($self, $chr) = @_ ;
    if ($self ne $request)
      { $request -> insert ('end', $chr) }
    handle_request }

foreach my $chr ('a'..'z','A'..'Z')
  { $mw -> bind ( "<KeyPress-$chr>", sub { insert_request(shift, $chr) } ) }

$mw -> bind ( "<backslash>", sub { insert_request(shift, "\\") } ) ;

sub delete_request
  { my $self = shift ;
    if ($self ne $request)
      { my $to = $request -> index ('end') ;
        my $from = $to - 1 ;
        if ($from<0) { $from = 0 }
        $request -> delete ($from,$to) }
    handle_request }

$mw -> bind ( "<BackSpace>", sub { delete_request } ) ;

sub new_request
  { $request -> delete (0,'end') ;
    handle_request }

$mw -> bind ( "<space>", sub { new_request } ) ;

#D Just in case:

sub raise_setup
  { $mw -> raise }

sub dont_exit
  { $mw -> protocol( 'WM_DELETE_WINDOW' => sub { } ) }

#D An example use is:
#D
#D \starttypen
#D load_setup ("cont-$nl") ;
#D show_setup ('omlijnd') ;
#D MainLoop () ;
#D \stoptypen
#D
#D Now everything is done, we return 1:

1 ;
