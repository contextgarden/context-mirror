eval '(exit $?0)' && eval 'exec perl -w -S $0 ${1+"$@"}' && eval 'exec perl -w -S $0 $argv:q'
        if 0;

#D \module
#D   [       file=texshow.pl,
#D        version=2006.08.04,
#D          title=TeXShow,
#D       subtitle=showing \CONTEXT\ commands,
#D         author=Taco Hoekwater,
#D           date=\currentdate,
#D      copyright={Taco Hoekwater}]

#D Early 1999 \TEXSHOW\ showed up in the \CONTEXT\ distribution. At that time
#D the user interface was described in files named \type {setup*.tex}. The
#D program used a stripped down version of these definition files, generated
#D by \CONTEXT\ itself. \TEXSHOW\ shows you the commands, their (optional)
#D arguments, as well as the parameters and their values. For some five years
#D there was no need to change \TEXSHOW. However, when a few years ago we
#D started providing an \XML\ variant of the user interface definitions, Taco
#D came up with \TEXSHOW||\XML. Because Patricks \CONTEXT\ garden and tools
#D like \CTXTOOLS\ also use the \XML\ definitions, it's time to drop the old
#D \TEX\ based definitions and move forward. From now on Taco's version is the
#D one to be used.
#D
#D Hans Hagen - Januari 2005
#D
#D ChangeLog:
#D \startitemize
#D \item Add keyboard bindings for quitting the app: Ctrl-q,Ctrl-x,Alt-F4 (2006/07/19)
#D \item Support for define --resolve (2006/08/04)
#D \stopitemize

use strict;
use Getopt::Long ;
use XML::Parser;
use Data::Dumper;
use Tk;
use Tk::ROText ;
use Config;
use Time::HiRes;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

my $ShowHelp  = 0;
my $Debug     = 0;
my $Editmode  = 0;
my $Interface = 'cont-en';
my $current_command;
my $current_interface;
my $current_part;
my @setup_files;

my %setups;
my %commes;
my %descrs;
my %examps;
my %trees;
my %positions;
my %locations;
my %crosslinks;


&GetOptions
  (      "help" => \$ShowHelp ,
  "interface=s" => \$Interface ,
        "debug" => \$Debug,
         "edit" => \$Editmode) ;

print "\n";

show('TeXShow-XML 0.3 beta','Taco Hoekwater 2006',"/");

print "\n";

if ($ShowHelp) {
  show('--help','print this help');
  show('--interface=lg','primary interface');
  show('--debug','print debugging info');
  show('string','show info about command \'string\'');
  show('string lg','show info about \'string\' in language \'lg\'');
  print "\n";
  exit 0;
}

my $command = $ARGV[0] || '';
my $interface = $ARGV[1] || '';
if ($interface =~ /^[a-z][a-z]$/i) {
  $Interface = 'cont-' . lc($interface);
} elsif ($interface && $command =~ /^[a-z][a-z]$/i) {
  show('debug',"switching '$interface' and '$command'");
  $Interface = 'cont-' . lc($command);
  $command = $interface;
}

if ($command =~ s/^\\//) {
  show('debug','removed initial command backslash');
}

show('interface', $Interface);
if ($command){
  show ('command', "\\$command") ;
}

print "\n";

show('status','searching for setup files');

my $setup_path;
my ($mainwindow,$interfaceframe,$partframe,$leftframe,$rightframe,$buttonframe);
my ($request,$listbox,$textwindow,%interfacebuttons,%partbuttons);

my ($textfont,$userfont,$buttonfont);

my $Part;

if (setups_found($Interface)) {
  $current_interface = '';
  $current_command = '';
  $current_part = 'Command';
  show('status','loading setups') ;
  load_setups($Interface) ;
  show ('status','initializing display') ;
  initialize_display();
  change_setup();
  show_command ($command);
  $mainwindow->deiconify();
  show ('status','entering main loop') ;
  MainLoop () ;
  show ('status','closing down') ;
} else {
  show ('error','no setup files found') ;
}
print "\n";

sub initialize_display  {
  my $dosish       = ($Config{'osname'} =~ /dos|win/i) ;
  my $default_size = $dosish ? 9 : 12 ;
  my $s_vertical   = 30 ;
  my $s_horizontal = 72 ;
  my $c_horizontal = 24 ;
  if (!$dosish) {
    $textfont   = "-adobe-courier-bold-r-normal--$default_size-120-75-75-m-70-iso8859-1" ;
    $userfont   = "-adobe-courier-bold-o-normal--$default_size-120-75-75-m-70-iso8859-1" ;
    $buttonfont = "-adobe-helvetica-bold-r-normal--$default_size-120-75-75-p-69-iso8859-1";
  } else {
    $textfont     = "Courier   $default_size       " ;
    $userfont     = "Courier   $default_size italic" ;
    $buttonfont   = "Helvetica $default_size bold  " ;
  }
  $mainwindow = MainWindow -> new ( -title => 'ConTeXt commands' ) ;
  $buttonframe   = $mainwindow -> Frame () ; # buttons
  $leftframe     = $mainwindow -> Frame () ; # leftside
  $rightframe    = $mainwindow -> Frame();
  $request  = $rightframe -> Entry (-font => $textfont,
			    -background => 'ivory1',
			    -width => $c_horizontal);
  $listbox  = $rightframe -> Scrolled ('Listbox',
			  -scrollbars => 'e',
			  -font => $textfont,
			  -width => $c_horizontal,
			  -selectbackground => 'gray',
			  -background => 'ivory1',
			  -selectmode => 'browse') ;
  $textwindow = $leftframe -> Scrolled ('ROText',
			 -scrollbars => 'se',
			 -height => $s_vertical,
			 -width => $s_horizontal,
			 -wrap => 'none',
			 -background => 'ivory1',
			 -font => $textfont);
  $interfaceframe = $leftframe -> Frame();
  $mainwindow -> withdraw() ;
  $mainwindow -> resizable ('y', 'y') ;
  foreach (@setup_files) {
    $interfacebuttons{$_} = $buttonframe -> Radiobutton (-text => $_,
				  -value => $_,
				  -font => $buttonfont,
				  -selectcolor => 'ivory1',
				  -indicatoron => 0,
				  -command => \&change_setup,
				  -variable => \$Interface );

    $interfacebuttons{$_} -> pack (-padx => '2p',-pady => '2p','-side' => 'left' );
  }
  foreach (qw(Command Description Comments Examples)) {
    $partbuttons{$_} = $interfaceframe -> Radiobutton (-text => $_,
				  -value => $_,
				  -font => $buttonfont,
				  -selectcolor => 'ivory1',
				  -indicatoron => 0,
				  -command => \&change_part,
				  -variable => \$Part );
    $partbuttons{$_} -> pack (-padx => '2p',-pady => '2p','-side' => 'left' );
  }
  # global top
  $buttonframe     -> pack ( -side => 'top'   , -fill => 'x' ,    -expand => 0 ) ;
  # top in left
  $interfaceframe  -> pack ( -side => 'top'   , -fill => 'x' ,    -expand => 0 ) ;
  $textwindow      -> pack ( -side => 'top'  , -fill => 'both' , -expand => 1 ) ;
  $leftframe       -> pack ( -side => 'left' , -fill => 'both' ,    -expand => 1 ) ;
  # right
  $request          -> pack ( -side => 'top'    , -fill => 'x' ) ;
  $listbox          -> pack ( -side => 'bottom' , -fill => 'both' , -expand => 1 ) ;
  $rightframe      -> pack ( -side => 'right' , -fill => 'both' ,    -expand => 1 ) ;
  $listbox -> bind ('<B1-Motion>', \&show_command ) ;
  $listbox -> bind ('<1>'        , \&show_command ) ;
  $listbox -> bind ('<Key>'      , \&show_command ) ;
  $textwindow -> tag ('configure', 'user'     ,       -font => $userfont ) ;
  $textwindow -> tag ('configure', 'optional' ,       -font => $userfont ) ;
  $textwindow -> tag ('configure', 'command'  , -foreground => 'green3'  ) ;
  $textwindow -> tag ('configure', 'variable' ,       -font => $userfont ) ;
  $textwindow -> tag ('configure', 'default'  ,  -underline => 1         ) ;
  $textwindow -> tag ('configure', 'symbol'   , -foreground => 'blue3'   ) ;
  $textwindow -> tag ('configure', 'or'       , -foreground => 'yellow3' ) ;
  $textwindow -> tag ('configure', 'argument' , -foreground => 'red3'    ) ;
  $textwindow -> tag ('configure', 'par'      ,   -lmargin1 => '4m'      ,
	                                     -wrap  => 'word'    ,
	                                  -lmargin2 => '6m'      ) ;
  foreach my $chr ('a'..'z','A'..'Z') {
    $mainwindow -> bind ( "<KeyPress-$chr>", sub { insert_request(shift, $chr) } );
  }
  $request -> bind ('<Return>', sub { handle_request() } ) ;
  $mainwindow -> bind ( "<backslash>", sub { insert_request(shift, "\\") } ) ;
  $mainwindow -> bind ( "<space>", sub { new_request() } ) ;
  $mainwindow -> bind ( "<BackSpace>", sub { delete_request() } ) ;
  $mainwindow -> bind ( "<Prior>", sub { prev_command() } ) ;
  $mainwindow -> bind ( "<Next>", sub { next_command() } ) ;
  $mainwindow -> bind ( "<Control-x>", sub { exit(0) } ) ;
  $mainwindow -> bind ( "<Control-X>", sub { exit(0) } ) ;
  $mainwindow -> bind ( "<Control-q>", sub { exit(0) } ) ;
  $mainwindow -> bind ( "<Control-Q>", sub { exit(0) } ) ;
  $mainwindow -> bind ( "<Alt-F4>",    sub { exit(0) } ) ;
}

sub show {
  my ($pre,$post,$sep) = @_;
  unless ($pre eq 'debug' && !$Debug) {
    $sep = ':' unless defined $sep;
    print sprintf("%22s $sep %+s\n",$pre,$post);
  }
}

sub change_setup {
  # switches to another setup file
  if ($current_interface ne $Interface ) {
    my $loc = 0;
    if ($current_command) {
      $loc = $positions{$Interface}{$current_command} || 0;
    }
    my @list = sort {lc $a cmp lc $b} keys %{$setups{$Interface}} ;
    my $num = 0;
    map { $locations{$Interface}{$_} = $num++; } @list;
    $listbox -> delete ('0.0', 'end') ;
    $listbox -> insert ('end', @list) ;
    # try to switch to other command as well, here.
    if ($current_command ne '') {
      show_command($crosslinks{$Interface}[$loc] || '');
    } else {
      $listbox -> selectionSet ('0.0', '0.0') ;
      $listbox -> activate ('0.0') ;
    }
  }
  $current_interface = $Interface;
  $mainwindow -> focus ;
}

sub change_part {
  if ($Part ne $current_part) {
    if($Part eq 'Command') {
      show_command();
    } elsif ($Part eq 'Description') {
      show_description();
    } elsif ($Part eq 'Comments') {
      show_comments();
    } elsif ($Part eq 'Examples') {
      show_examples();
    }
  }
  $current_part = $Part;
}


sub setups_found {
  # find the setup files
  my ($primary) = @_;
  $setup_path = `kpsewhich --progname=context cont-en.xml` ;
  chomp $setup_path;
  show ('debug', "path = '$setup_path'");
  if ($setup_path) {
    $setup_path =~ s/cont-en\.xml.*// ;
    @setup_files = glob ("${setup_path}cont\-??.xml") ; # HH: pattern patched, too greedy
    show ('debug', "globbed path into '@setup_files'");
    if (@setup_files) {
      my $found = 0;
      foreach (@setup_files) {
	s/\.xml.*$//;
	s/^.*?cont-/cont-/;
	if ($_ eq $primary) {
	  $found = 1;
	  show ('debug', "found primary setup '$primary'");
	} else {
	  show ('debug', "found non-primary setup '$_'");
	}
      }
      if ($found) {
	return 1;
      } else {
	show('error',"setup file for '$primary' not found, using 'cont-en'");
	$Interface = 'cont-en';
	return 1;
      }
    } else {
      show('error',"setup file glob failed");
    }
  } elsif ($!) {
    show('error','kpsewhich not found');
  } else {
    show('error','setup files not found');
  }
  return 0;
}

sub load_setup {
  my ($path,$filename) = @_;
  my $localdefs = {};
  unless (keys %{$setups{$filename}}) {
    if (open(IN,"<${path}$filename.xml")) {
      my $position = 0 ;
      local $/ = '</cd:command>';
      while (my $data= <IN>) {
		next if $data =~ /\<\/cd:interface/;
		if ($data =~ /\<cd:interface/) {
		  $data =~ s/^(.*?)\<cd:command/\<cd:command/sm;
		  my $meta = $1;
		  while ($meta =~ s!<cd:define name=(['"])(.*?)\1>(.*?)</cd:define>!!sm) {
			my $localdef = $2;
			my $localval = $3;
			$localdefs->{$localdef} = $localval;
		  }
		}
		#
		if (keys %$localdefs) {
		  while ($data =~ /<cd:resolve/) {
			$data =~ s/<cd:resolve name=(['"])(.*?)\1\/>/$localdefs->{$2}/ms;
		  }
		}
		$data =~ s/\s*\n\s*//g;
		$data =~ /\<cd:command(.*?)\>/;
		my $info = $1;
		my ($name,$environment) = ('','');
		while ($info =~ s/^\s*(.*?)\s*=\s*(["'])(.*?)\2\s*//) {
		  my $a = $1; my $b = $3;
		  if ($a eq 'name') {
			$name = $b;
		  } elsif ($a eq 'type') {
			$environment = $b;
		  }
		}
		my $cmd = $name;
		if ($environment) {
		  $cmd = "start" . $name;
		}
		$setups    {$filename}{$cmd}   = $data ;
		$trees     {$filename}{$cmd}   = undef;
		$positions {$filename}{$cmd}   = ++$position ;
		$crosslinks{$filename}[$position] = $cmd ;
	  }
	close IN;
	  # now get explanations as well ...
	  my $explname = $filename;
	  $explname =~ s/cont-/expl-/;
	  my $extras = 0 ;
	  if (open(IN,"<${path}$explname.xml")) {
		local $/ = '</cd:explanation>';
		while (my $data= <IN>) {
		  if ($data =~ /\<\/cd:explanations/) {
			next;
		  }
		  if ($data =~ /\<cd:explanations/) {
			$data =~ s/^(.*?)\<cd:explanation /\<cd:explanation /sm;
			my $meta = $1;
		  }
		  #
		  $extras++;
		  $data =~ /\<cd:explanation(.*?)\>/;
		  my $info = $1;
		  my ($name,$environment) = ('','');
		  while ($info =~ s/^\s*(.*?)\s*=\s*(["'])(.*?)\2\s*//) {
			my $a = $1; my $b = $3;
			if ($a eq 'name') {
			  $name = $b;
			} elsif ($a eq 'type') {
			  $environment = $b;
			}
		  }
		  my $cmd = $name;
		  if ($environment) {
			$cmd = "start" . $name;
		  }
		  my $comment = '';
		  my $description = '';
		  my @examples = ();
		  $data =~ /\<cd:description\>(.*)\<\/cd:description\>/s and $description = $1;
		  $data =~ /\<cd:comment\>(.*)\<\/cd:comment\>/s and $comment = $1;
		  while ($data =~ s/\<cd:example\>(.*?)\<\/cd:example\>//s) {
			push @examples, $1;
		  }
		  if (length($comment) && $comment =~ /\S/) {
			$commes    {$filename}{$cmd}   = $comment;
		  }
		  if (length($description) && $description =~ /\S/) {
			$descrs    {$filename}{$cmd}   = $description;
		  }
		  my $testex = "@examples";
		  if (length($testex) && $testex =~ /\S/) {
			$examps    {$filename}{$cmd}   = [@examples];
		  }
		}
	  }
	  if ($extras) {
		show('debug',"interface '$filename', $position\&$extras commands");
	  } else {
		show('debug',"interface '$filename', $position commands");
	  }
    }  else {
      show ('debug',"open() of ${path}$filename.xml failed");
    }
  }
  $Interface = $filename ;
}

sub load_setups {
  my ($primary) = @_;
  # load all setup files, but default to $primary
  my $t0 = [Time::HiRes::gettimeofday()];
  foreach my $setup (@setup_files) {
    if ($setup ne $primary) {
      load_setup ($setup_path,$setup);
      show('status',"loading '$setup' took " .Time::HiRes::tv_interval($t0) . " seconds");
      $t0 = [Time::HiRes::gettimeofday()];
    };
  };
  load_setup ($setup_path,$primary);
  show('status',"loading '$primary' took " .Time::HiRes::tv_interval($t0) . " seconds");
}

my @history = ();
my $current_history = 0;

sub show_command {
  my ($command,$nofix) = @_;
  if (keys %{$setups{$Interface}}) {
    my $key = '';
    if (defined $command && $command &&
	(defined $setups{$Interface}{$command} ||
	 defined $setups{$Interface}{"start" . $command})) {
      $key = $command;
      my $whence =$locations{$Interface}{$command};
      $listbox -> selectionClear ('0.0','end') ;
      $listbox -> selectionSet($whence,$whence);
      $listbox -> activate($whence);
      $listbox -> see($whence);
    } else {
      $listbox -> selectionSet('0.0','0.0') unless $listbox->curselection();
      $key = $listbox -> get($listbox->curselection()) ;
    }
    show('debug',"current command: $current_command");
    show('debug',"    new command: $key");
    $current_command = $key ;
    $textwindow -> delete ('1.0', 'end' ) ;
	$partbuttons{"Command"}->select();
	$partbuttons{"Command"}->configure('-state' => 'normal');
	$partbuttons{"Description"}->configure('-state' => 'disabled');
	$partbuttons{"Comments"}->configure('-state' => 'disabled');
	$partbuttons{"Examples"}->configure('-state' => 'disabled');
	if (defined $commes{$Interface}{$key}) {
	  $partbuttons{"Comments"}->configure('-state' => 'normal');
	}
	if (defined $descrs{$Interface}{$key}) {
	  $partbuttons{"Description"}->configure('-state' => 'normal');
	}
	if (defined $examps{$Interface}{$key}) {
	  $partbuttons{"Examples"}->configure('-state' => 'normal');
	}
	unless (defined $nofix && $nofix) {
	  push @history, $key;
	  $current_history = $#history;
	}
    do_update_command ($key) ;
    $mainwindow -> update();
    $mainwindow -> focus() ;
  }
}

sub prev_command {
  if ($current_history > 0) {
	$current_history--;
	show_command($history[$current_history],1);
  }
}

sub next_command {
  unless ($current_history == $#history) {
	$current_history++;
	show_command($history[$current_history],1);
  }
}

sub show_description {
  $textwindow -> delete ('1.0', 'end' ) ;
  if (defined $descrs{$current_interface}{$current_command}) {
	$textwindow-> insert ('end',$descrs{$current_interface}{$current_command});
  }
  $mainwindow -> update();
  $mainwindow -> focus() ;
}

sub show_comments {
  $textwindow -> delete ('1.0', 'end' ) ;
  if (defined $commes{$current_interface}{$current_command}) {
	$textwindow-> insert ('end',$commes{$current_interface}{$current_command});
  }
  $mainwindow -> update();
  $mainwindow -> focus() ;
}


sub show_examples {
  $textwindow -> delete ('1.0', 'end' ) ;
  if (defined $examps{$current_interface}{$current_command}) {
	$textwindow-> insert ('end',join("\n\n",@{$examps{$current_interface}{$current_command}}));
  }
  $mainwindow -> update();
  $mainwindow -> focus() ;
}




sub has_attr {
  my ($elem,$att,$val) = @_;
  return 1 if (attribute($elem,$att) eq $val);
  return 0;
}


sub view_post {
  my ($stuff,$extra) = @_;
  $extra = '' unless defined $extra;
  $stuff =~ /^(.)(.*?)(.)$/;
  my ($l,$c,$r) = ($1,$2,$3);
  if ($l eq '[' || $l eq '(') {
    return ($l,['symbol','par',$extra],$c,['par',$extra],$r,['symbol','par',$extra],"\n",'par');
  } else {
    return ($l,['argument','par',$extra],$c,['par',$extra],$r,['argument','par',$extra],"\n",'par');
  }
}

sub view_pre {
  my ($stuff) = @_;
  $stuff =~ /^(.)(.*?)(.)$/;
  my ($l,$c,$r) = ($1,$2,$3);
  if ($l eq '[' || $l eq '(') {
    return ($l,['symbol'],$c,'',$r,['symbol']);
  } else {
    return ($l,['argument'],$c,'',$r,['argument']);
  }
}

sub create_setup_arguments {
  my $argx = shift;
  my @predisp = ();
  my @postdisp = ();
  foreach my $arg (children($argx)) {
  if (name($arg) eq 'cd:keywords') {
    # children are Constant* & Inherit?  &  Variable*
    my @children = children($arg);
    my $optional = (attribute($arg,'optional') eq 'yes' ? 'optional' : '');
    if (@children){
      push @predisp,'[', ['symbol',$optional];
      if (has_attr($arg,'list', 'yes')) {
	if (has_attr($arg,'interactive', 'exclusive')) {
	  push @predisp, '...', '';
	} else {
	  push @predisp, '..,...,..', '';
	}
      } else {
	push @predisp,'...', '';
      }
      push @predisp,']', ['symbol',$optional];
    }
    push @postdisp,'[', ['symbol','par',$optional];
    my $firsttrue = 1;
    foreach my $kwd (@children) {
      if ($firsttrue) {
	$firsttrue = 0;
      } else {
	push @postdisp,', ', ['symbol','par'];
      }
      if      (name($kwd) eq 'cd:constant' ||
               name($kwd) eq 'cd:variable') {
	my $v = attribute($kwd,'type');
	my $def = '';
	my $var = '';
	$var = 'variable' if (name($kwd) eq 'cd:variable') ;
	$def = 'default'  if (has_attr($kwd,'default', 'yes'));
	if ($v =~ /^cd:/) {
	  $v =~ s/^cd://;
	  $v .= "s" if (has_attr($arg,'list', 'yes'));
	  push @postdisp, $v, ['user',$def,'par',$var];
	} else {
	  push @postdisp, $v, [$def,'par',$var];
	}
      } elsif (name($kwd) eq 'cd:inherit') {
	my $v = attribute($kwd,'name');
	$textwindow -> tag ('configure', $v , -foreground => 'blue3',-underline => 1 ) ;
	$textwindow -> tagBind($v,'<ButtonPress>',sub {show_command($v)} );
	push @postdisp,"see ","par", "$v", [$v,'par'];
      }
    }
    push @postdisp,']', ['symbol','par',$optional];
    push @postdisp,"\n", 'par';
  } elsif (name($arg) eq 'cd:assignments') {
    # children are Parameter* & Inherit?
    my @children = children($arg);
    my $optional = (attribute($arg,'optional') eq 'yes' ? 'optional' : '');
    if (@children) {
      push @predisp,'[', ['symbol',$optional];
      if (has_attr($arg,'list', 'yes')) {
	push @predisp, '..,..=..,..', '';
      } else {
	push @predisp,'..=..', '';
      }
      push @predisp,']', ['symbol',$optional];
      push @postdisp,'[', ['symbol','par',$optional];
      my $isfirst = 1;
      foreach my $assn (@children) {
	if ($isfirst) {
	  $isfirst = 0;
	} else  {
	  push @postdisp,",\n ", ['symbol','par'];
	}
	if (name($assn) eq 'cd:parameter') {
	  push @postdisp,attribute($assn,'name'), 'par';
	  push @postdisp,'=', ['symbol','par'];
	  my $firstxtrue = 1;
	  foreach my $par (children($assn)) {
	    if ($firstxtrue) {
	      $firstxtrue = 0;
	    } else {
	      push @postdisp,'|', ['or','par'];
	    }
	    if (name($par) eq 'cd:constant' || name($par) eq 'cd:variable') {
	      my $var = '';
	      $var = 'variable' if name($par) eq 'cd:variable';
	      my $v = attribute($par,'type');
	      if ($v =~ /^cd:/) {
		$v =~ s/^cd://;
		push @postdisp,$v, ['user','par',$var];
	      } else {
		push @postdisp,$v, ['par',$var];
	      }
	    }
	  }
	} elsif (name($assn) eq 'cd:inherit') {
	  my $v = attribute($assn,'name');
	  $textwindow -> tag ('configure', $v , -foreground => 'blue3',-underline => 1 ) ;
	  $textwindow -> tagBind($v,'<ButtonPress>',sub {show_command($v)} );
	  push @postdisp,"see ","par", "$v", [$v,'par'];
	}
      }
      push @postdisp,"]", ['symbol','par',$optional], "\n", '';
    }
  } elsif (name($arg) eq 'cd:content') {
      push @predisp,  view_pre('{...}');
      push @postdisp, view_post('{...}');
  } elsif (name($arg) eq 'cd:triplet') {
    if (has_attr($arg,'list','yes')) {
      push @predisp, view_pre('[x:y:z=,..]');
      push @postdisp,view_post('[x:y:z=,..]');
    } else {
      push @predisp, view_pre('[x:y:z=]');
      push @postdisp,view_post('[x:y:z=]');
    }
  } elsif (name($arg) eq 'cd:reference') {
    my $optional = (attribute($arg,'optional') eq 'yes' ? 'optional' : '');
    if (has_attr($arg,'list','yes')) {
      push @postdisp, view_post('[ref,..]',$optional);
      push @predisp, view_pre('[ref,..]');
    } else {
      push @postdisp, view_post('[ref]',$optional);
      push @predisp,  view_pre('[ref]');;
    }
  } elsif (name($arg) eq 'cd:word') {
    if (has_attr($arg,'list','yes')) {
      push @predisp, view_pre ('{...,...}');
      push @postdisp,view_post('{...,...}');
    } else {
      push @predisp,  view_pre('{...}');
      push @postdisp, view_post('{...}');
    }
  } elsif (name($arg) eq 'cd:nothing') {
    my $sep = attribute($arg,'separator');
    if ($sep) {
      if($sep eq 'backslash') {
#	push @postdisp,'\\\\','par';
	push @predisp,'\\\\','';
      } else {
#	push @postdisp,$sep,'par';
	push @predisp,$sep,'';
      }
    }
    push @predisp,'...','';
    push @postdisp,'text',['variable','par'],"\n",'par';
  } elsif (name($arg) eq 'cd:file') {
    push @predisp,'...',['default'];
    push @postdisp,'...',['default','par'],"\n",'par';
  } elsif (name($arg) eq 'cd:csname') {
    push @predisp,'\command',['command'];
    push @postdisp,'\command',['command','par'],"\n",'par';
  } elsif (name($arg) eq 'cd:index') {
    if (has_attr($arg,'list','yes')) {
      push @predisp,view_pre('{..+...+..}');
      push @postdisp,view_post('{..+...+..}');
    } else {
      push @predisp, view_pre('{...}');
      push @postdisp,view_post('{...}');
    }
  } elsif (name($arg) eq 'cd:position') {
    if (has_attr($arg,'list','yes')) {
      push @predisp,view_pre('(...,...)');
      push @postdisp,view_post('(...,...)');
    } else {
      push @predisp,view_pre('(...)');
      push @postdisp,view_post('(...)');
    }
  } elsif (name($arg) eq 'cd:displaymath') {
    push @predisp,  ('$$',['argument'],'...','','$$',['argument']);
    push @postdisp, ('$$',['argument','par'],'...',['par'],'$$',['argument','par']);
  } elsif (name($arg) eq 'cd:tex') {
    my $sep = attribute($arg,'separator');
    if ($sep) {
      if($sep eq 'backslash') {
#	push @postdisp,'\\\\','par';
	push @predisp,'\\\\','';
      } else {
#	push @postdisp,$sep,'par';
	push @predisp,$sep,'';
      }
    }
    my $cmd = "\\" . attribute($arg,'command');
    push @predisp,$cmd,'';
#    push @postdisp,$cmd,['command','par'],"\n",'par';
  }
  }
  return (\@predisp,\@postdisp);
}


#  <foo><head id="a">Hello <em>there</em></head><bar>Howdy<ref/></bar>do</foo>
#
#       would be:
#
#                    Tag   Content
#         ==================================================================
#         [foo, [{}, head, [{id => "a"}, 0, "Hello ",  em, [{}, 0, "there"]],
#                     bar, [         {}, 0, "Howdy",  ref, [{}]],
#                       0, "do"
#               ]
#         ]

sub attribute {
  my ($elem,$att) = @_;
  if (defined $elem->[1] && defined $elem->[1]->[0] && defined $elem->[1]->[0]->{$att}) {
    my $ret = $elem->[1]->[0]->{$att};
    show ('debug',"returning attribute $att=$ret");
    return $elem->[1]->[0]->{$att};
  } else {
    return '';
  }
}

sub name {
  my ($elem) = @_;
  if (defined $elem->[0] ) {
    return $elem->[0];
  } else {
    return '';
  }
}

# return all children at a certain level
sub children {
  my ($elem) = @_;
  if (defined $elem->[1] && defined $elem->[1]->[1]) {
    my @items = @{$elem->[1]};
    shift @items ; # deletes the attribute.
    my @ret = ();
    while (@items) {
      push @ret, [shift @items, shift @items];
    }
    return @ret;
  } else {
    return ();
  }
}

# return the first child with the right name
sub find {
  my ($elem,$name) = @_;
  if ($elem->[0] eq $name) {
    return $elem;
  }
  if (ref($elem->[1]) eq 'ARRAY') {
    my @contents = @{$elem->[1]};
    shift @contents;
    while (my $ename = shift @contents) {
      my $con = shift @contents;
      if ($ename eq $name) {
	return [$ename,$con];
      }
    }
  }
  return [];
}

sub do_update_command                # type: 0=display, 1=compute only
  { my ($command, $type) = @_ ;
    $type = 0 unless defined $type;
    my $setup;
    if (!defined $trees{$Interface}{$command}) {
      my $parser = XML::Parser->new('Style' => 'Tree');
      $trees{$Interface}{$command} = $parser->parse($setups{$Interface}{$command});
    }
    $setup = $trees{$Interface}{$command} ;
    my $predisp = undef;
    my $postdisp = undef;
    my @cmddisp = ();
    my @cmddispafter = ();
    my $pradisp = undef;
    my $altdisp = undef;
    if (attribute($setup,'file')) {
      my $filename = attribute($setup,'file');
      my $fileline = attribute($setup,'line') || 0;
      $textwindow->insert ('end',"$filename:${fileline}::\n\n", '' );
    }
    # start with backslash
    push @cmddisp, "\\", 'command' ;
    my $env = 0;
    if (has_attr($setup,'type','environment')) {
      $env = 1;
    }
    if ($env) { push @cmddisp, "start", 'command' ; }
    if ($env) { push @cmddispafter, " ... ", '', "\\stop", 'command' ; }
    my $seq = find($setup,'cd:sequence');
    # display rest of command name
    foreach my $seqpart (children($seq)) {
      my $text = attribute($seqpart,'value');
      if (name($seqpart) eq 'cd:variable') {
	push @cmddisp, $text, ['command','user'];
	if ($env) { push @cmddispafter, $text, ['command','user']; }
      } elsif (name($seqpart) eq 'cd:string') {
	push @cmddisp, $text, 'command';
	if ($env) { push @cmddispafter, $text, 'command'; }
      }
    }
    #
    my $args = find($setup,'cd:arguments');
    # display commands
    if ($args) {
      my $curarg = 0;
      foreach my $arg (children($args)) {
	if (name($arg) eq 'cd:choice') {
	  my ($a,$b) = children($arg);
	  ($predisp,$postdisp) = create_setup_arguments(['cd:arguments',[{}, @$a]]);
	  ($pradisp,$altdisp)  = create_setup_arguments(['cd:arguments',[{}, @$b]]);
	} else {
	  ($predisp,$postdisp) = create_setup_arguments($args);
	}
	$curarg++;
      }
    }
    return if $type;
    if(defined $postdisp) {
      if(defined $altdisp) {
	$textwindow->insert('end',@cmddisp,@$predisp,@cmddispafter,  "\n",'',
                          @cmddisp,@$pradisp,@cmddispafter, "\n\n",'',
		          @cmddisp, "\n",'',
		          @$postdisp, "\n",'',
                          @cmddisp, "\n",'',
		          @$altdisp);
      } else {
	$textwindow->insert('end',@cmddisp,@$predisp, @cmddispafter ,"\n\n",'',
		          @cmddisp,"\n",'',
		          @$postdisp);
      }
    } else {
      $textwindow->insert('end',@cmddisp);
    }
}


#D The next feature is dedicated to Tobias, who suggested
#D it, and Taco, who saw it as yet another proof of the
#D speed of \PERL. It's also dedicated to Ton, who needs it
#D for translating the big manual.

sub handle_request  {
  my $index = $listbox -> index('end') ;
  return unless $index;
  my $req = $request -> get ;
  return unless $req;
  $req =~ s/\\//o ;
  $req =~ s/\s//go ;
  $request -> delete('0','end') ;
  $request -> insert('0',$req) ;
  return unless $req;
  my ($l,$c) = split (/\./,$index) ;
  for (my $i=0;$i<=$l;$i++) {
    $index = "$i.0" ;
    my $str = $listbox -> get ($index, $index) ;
	if (defined $str && ref($str) eq 'ARRAY')  {
	  $str = "@{$str}";
	}
    if (defined $str && $str =~ /^$req/) {
      show_command($str) ;
      return ;
    }
  }
}

sub insert_request {
  my ($self, $chr) = @_ ;
  # don't echo duplicate if $chr was keyed in in the (focussed) entrybox
  $request -> insert ('end', $chr) unless $self eq $request;
  handle_request();
}

sub delete_request {
  my $self = shift ;
  # delete last character, carefully
  if ($self ne $request) {
    my $to = $request -> index ('end') ;
    my $from = $to - 1 ;
    if ($from<0) { $from = 0 }
    $request -> delete ($from,$to);
  }
  handle_request();
}

sub new_request {
  $request -> delete (0,'end') ;
  handle_request();
}

