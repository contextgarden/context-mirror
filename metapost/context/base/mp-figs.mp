%D \module
%D   [       file=mp-tool.mp,
%D        version=2003.01.15,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=figures,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for
%C details.

if unknown context_tool :    input mp-tool ; fi ;
if   known context_figs : endinput         ; fi ;

boolean context_figs ; context_figs := true ;

% todo: check defined

def registerfigure(expr name,width,height) =
  begingroup ;
  save s ; string s ; s := cleanstring(name) ;
  scantokens( s & "_width := " & decimal(width)) ;
  scantokens( s & "_height := " & decimal(width)) ;
  endgroup ;
enddef ;

vardef figuresize(expr name) =
  save s ; string s ; s := cleanstring(name) ;
  save p ; pair p ;
  scantokens( "p := " & "(" & s & "_width" & "," & s & "_height" & ")" ) ;
  p
enddef ;

vardef figurewidth(expr name) =
  xpart figuresize(name)
enddef ;

vardef figureheight(expr name) =
  ypart figuresize(name)
enddef ;

def figuredimensions = figuresize enddef ; % for old times sake

def naturalfigure(expr name) =
    externalfigure name xyscaled(figuresize(name))
enddef ;

endinput
