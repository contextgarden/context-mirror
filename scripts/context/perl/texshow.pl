eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D \module
#D   [       file=texshow.pl,
#D        version=1999.03.30,
#D          title=\TEXSHOW,
#D       subtitle=showing \CONTEXT\ commands,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten},
#D    suggestions={Tobias Burnus \& Taco Hoekwater}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for
#C details.

#D We need to find the module path. We could have used:
#D
#D \starttypen
#D use FindBin ;
#D use lib $FindBin::Bin ;
#D \stoptypen
#D
#D But because we're sort of depending on \WEBC\ anyway, the
#D next few lines are more appropriate:

BEGIN {
    $cont_pm_path = `kpsewhich --format="texmfscripts" --progname=context cont_mis.pm` ;
    chomp($cont_pm_path) ;
    if ($cont_pm_path eq '') {
        $cont_pm_path = `kpsewhich --format="other text files" --progname=context cont_mis.pm` ;
        chomp($cont_pm_path) ;
    }
    $cont_pm_path =~ s/cont_mis\.pm.*// ;
}

use lib $cont_pm_path ;

#D Now we can load some modules:

use Getopt::Long ;

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

&GetOptions
  (      "help" => \$ShowHelp ,
    "interface" => \$Interface ) ;

cont_mis::banner ('TeXShow 0.1 - ConTeXt', 'PRAGMA ADE 1999') ;

if ($ShowHelp)
  { cont_mis::help ('--help', "print this help") ;
    cont_mis::help ('--interface', "primary interface") ;
    cont_mis::help ('string', "show info about command 'string'") ;
    cont_mis::help ('string lg', "show info about 'string' in language 'lg'") ;
    cont_mis::crlf () ;
    exit 0 }

use cont_mis ;
use cont_set ;

use Tk ;

#D This scripts is rather simple, because most of the action
#D takes place in the module \type {cont_set.pm}.

cont_mis::status ('searching for setup files') ;

if (cont_set::setups_found)
  { cont_mis::status ('loading setups') ;
    cont_set::load_setups ;
    cont_mis::status ('preparing display') ;
    cont_set::show_setups ;
    $command = $ARGV[0] ;
    $interface = $ARGV[1] ;
    if ($interface)
      { $Interface = $interface }
    if ($Interface)
      { cont_set::set_setup_interface($Interface) ;
        cont_mis::message ('primary interface', $Interface) }
    if ($command)
      { cont_mis::message ('searching command', $command) ;
        cont_set::show_setup ($command) }
    else
      { cont_mis::warning ('no command specified') ;
        cont_set::set_setup_title('TeXShow : ConTeXt commands') }
    cont_mis::status ('entering main loop') ;
    #$mw -> bind ('<ctrl-q>', exit ) ;
    #$mw -> bind ('<esc>', exit ) ;
    MainLoop () }
else
  { cont_mis::error ('no setup files found') }

END { cont_mis::crlf ;
      cont_mis::status ('closing down') }
