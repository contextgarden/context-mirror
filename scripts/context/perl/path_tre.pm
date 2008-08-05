#D \module
#D   [       file=path\_tre.pm,
#D        version=1999.05.05,
#D          title=Path modules, 
#D       subtitle=selecting a path, 
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
#C details. 

#D Not yet documented, source will be cleaned up. 

package Tk::path_tre ; 

use Tk;
require Tk::DirTree ;

use base  qw(Tk::DirTree);
use strict;

Construct Tk::Widget 'PathTree';

sub ClassInit
  { my ($class,$mw) = @_ ;
    return $class -> SUPER::ClassInit ($mw) }

sub dirnames
  { my ( $w, $dir ) = @_ ;
    unless ($dir=~/\//) { $dir .= '/' }
    my @names = $w->Callback("-dircmd", $dir, $w->cget("-showhidden"));
    return( @names ) }

__END__
