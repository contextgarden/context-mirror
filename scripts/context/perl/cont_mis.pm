#D \module
#D   [       file=cont\_mis.pm,
#D        version=1999.05.05,
#D          title=General modules, 
#D       subtitle=all kind of subs, 
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
#C details. 

#D Not yet documented, source will be cleaned up. 

package cont_mis ; 

use strict ; 

my ($message, $separator, $content) ; 

format = 
@>>>>>>>>>>>>>>>>>>>>> @ @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$message,$separator,$content
.

sub report 
  { ($message, $separator, $content) = @_ ; write } 

sub crlf     { print "\n" } 
sub banner   { crlf ; report  (shift     , '/', shift) ; crlf } 
sub message  {        report  (shift     , ':', shift) } 
sub help     {        report  (shift     , ' ', shift) } 
sub status   {        message ('status'  ,      shift) }
sub warning  {        message ('warning' ,      shift) }
sub error    {        message ('error'   ,      shift) } 
sub continue {        message (''        ,      shift) } 

sub hex_color 
  { my ($r,$g,$b) = @_ ;
    if ($r>1) { $r=0xffff } else { $r = 0xffff*$r } 
    if ($g>1) { $g=0xffff } else { $g = 0xffff*$g } 
    if ($b>1) { $b=0xffff } else { $b = 0xffff*$b } 
    local $_ = sprintf "%4x%4x%4x", $r, $g, $b ;   
    s/ /0/go ; 
    return $_ } 

sub InterfaceFound
  { local $_ = shift ; 
    if    (/^\%.*interface=(.*?)\b/)
      { return $1 } 
    elsif (/\\(starttekst|stoptekst|startonderdeel)/)
      { return 'nl' } 
    elsif (/\\(stelle|verwende|umgebung|benutze)/)
      { return 'de' } 
    elsif (/\\(stel|gebruik|omgeving)/)
      { return 'nl' } 
    elsif (/\\(use|setup|environment)/)
      { return 'en' }         
    elsif (/(hoogte|breedte|letter)=/)
      { return 'nl' } 
    elsif (/(height|width|style)=/)
      { return 'en' }         
    elsif (/(hoehe|breite|schrift)=/)
      { return 'de' } 
    else
      { return '' } } 

1;
