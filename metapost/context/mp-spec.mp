%D \module
%D   [       file=mp-spec.mp,
%D        version=1999.6.26,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=special extensions, 
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
%C details. 

%D This module is rather preliminary and subjected to 
%D changes. Here we closely cooperates with the \METAPOST\ 
%D to \PDF\ converter module built in \CONTEXT\ and provides 
%D for instance shading. More information can be found in 
%D type {supp-mpe.tex}. 

if unknown context_tool :    input mp-tool ; fi ; 
if   known context_spec : endinput         ; fi ; 

boolean context_spec ; context_spec := true ; 

numeric _special_counter_ ; _special_counter_ :=   0 ;
numeric _color_counter_   ; _color_counter_   :=   0 ; 
numeric _special_signal_  ; _special_signal_  := 123 ; 

%D When set to \type {true}, shading will be supported. Some
%D day I will also write an additional directive. 

boolean _inline_specials_ ; _inline_specials_ := false ; 

%D Because we want to output only those specials that are
%D actually used in a figure, we need a bit complicated
%D bookkeeping and collection of specials. At the cost of some
%D obscurity, we now have rather efficient resources. 

string _all_specials_ ; _all_specials_ := "" ; 

vardef add_special_signal = 
  if (length _all_specials_>0) :
    special ("%%MetaPostSpecials: 1.0 " & decimal _special_signal_ ) ; % version
  fi ; 
enddef ; 

vardef add_extra_specials = 
  scantokens _all_specials_ ; 
enddef ; 

vardef reset_extra_specials = 
  _all_specials_ := "" ;
enddef ; 

extra_endfig := 
  " add_special_signal ; "   &  
    extra_endfig             & 
  " add_extra_specials ; "   &  
  " reset_extra_specials ; " ; 

def flush_special (expr typ, siz, dat) = 
  _special_counter_ := _special_counter_ + 1 ; 
  if _inline_specials_ : 
    _all_specials_ := _all_specials_ 
      & "special "
      & "(" & ditto
      & dat & " " 
      & decimal _special_counter_ & " " 
      & decimal typ & " " 
      & decimal siz 
      & " special" 
      & ditto & ");" ;
  else :
   _all_specials_ := _all_specials_ 
      & "special " 
      & "(" & ditto
      & "%%MetaPostSpecial: "  
      & decimal siz & " " 
      & dat & " " 
      & decimal _special_counter_ & " "  
      & decimal typ 
      & ditto & ");" ;
  fi ; 
enddef ; 

%D Shade allocation. 

vardef define_circular_shade (expr a, b, ra, rb, ca, cb) = 
  flush_special(3, 17, "0 1 1" & 
    dddecimal ca & ddecimal a & " " & decimal ra &  
    dddecimal cb & ddecimal b & " " & decimal rb ) ;
  _special_counter_ 
enddef ;  

vardef define_linear_shade (expr a, b, ca, cb) = 
  flush_special(2, 15, "0 1 1" & 
    dddecimal ca & ddecimal a & 
    dddecimal cb & ddecimal b ) ; 
  _special_counter_ 
enddef ;  

%D A few predefined shading macros.

boolean trace_shades ; trace_shades := false ; 

def linear_shade (expr p, n, ca, cb) = 
  begingroup ; 
  save a, b, sh ; pair a, b ;
  if     (n=1) : a := llcorner p ; b := urcorner p ; 
  elseif (n=2) : a := llcorner p ; b := ulcorner p ; 
  elseif (n=3) : a := lrcorner p ; b := ulcorner p ; 
  else         : a := llcorner p ; b := lrcorner p ; 
  fi ;
  fill p withshade define_linear_shade (a,b,ca,cb) ; 
  if trace_shades : 
    drawarrow a -- b withpen pencircle scaled 1pt ; 
  fi ; 
  endgroup ; 
enddef ;  

def circular_shade (expr p, n, ca, cb) = 
  begingroup ; 
  save ab, r ; pair ab ; numeric r ; 
  r := (xpart lrcorner p - xpart llcorner p) ++ 
       (ypart urcorner p - ypart lrcorner p) ; 
  if     (n=1) : ab := llcorner p ; 
  elseif (n=2) : ab := lrcorner p ; 
  elseif (n=3) : ab := urcorner p ; 
  elseif (n=4) : ab := ulcorner p ; 
  else         : ab := center p ; r := .5r ; 
  fi ; 
  fill p withshade define_circular_shade(ab,ab,0,r,ca,cb) ;
  if trace_shades : 
    drawarrow ab -- ab shifted (0,r) withpen pencircle scaled 1pt ; 
  fi ; 
  endgroup ; 
enddef ;  

%D Since a \type {fill p withshade s} syntax looks better 
%D than some macro, we implement a new primary.  

primarydef p withshade sc = 
  hide (_color_counter_ := _color_counter_ + 1)
  p withcolor (_special_signal_/1000,_color_counter_/1000,sc/1000) 
enddef ; 

%D Figure inclusion. 

numeric cef ; cef := 0 ; 

def externalfigure primary filename = 
  doexternalfigure (filename) 
enddef ; 

def doexternalfigure (expr filename) text transformation = 
  begingroup ; save p, t ; picture p ; transform t ; 
  p := nullpicture ; t := identity transformation ; 
  flush_special(10, 9,
    dddecimal (xxpart t, yxpart t, xypart t) & " " & 
    dddecimal (yypart t,  xpart t,  ypart t) & " " & filename) ; 
  addto p contour unitsquare scaled 0 ;
  setbounds p to unitsquare transformed t ;   
  _color_counter_ := _color_counter_ + 1 ; cef := cef + 1 ; 
  draw p withcolor (_special_signal_/1000,_color_counter_/1000,cef/1000) ;
  endgroup ; 
enddef ; 

%D Experimental: 

numeric currenthyperlink ; currenthyperlink := 0 ; 

def hyperlink primary t = dohyperlink(t) enddef ;
def hyperpath primary t = dohyperpath(t) enddef ;

def dohyperlink (expr destination) text transformation  = 
  begingroup ; save somepath ; path somepath ; 
  somepath := fullsquare transformation ; 
  dohyperpath(destination) somepath ;
  endgroup ; 
enddef ; 

def dohyperpath (expr destination) expr somepath = 
  begingroup ; 
  flush_special(20, 7,
    ddecimal (xpart llcorner somepath, ypart llcorner somepath) & " " & 
    ddecimal (xpart urcorner somepath, ypart urcorner somepath) & " " & destination) ; 
  _color_counter_ := _color_counter_ + 1 ; 
  currenthyperlink := currenthyperlink + 1 ; 
  fill boundingbox unitsquare scaled 0 
    withcolor 
    (_special_signal_/1000,_color_counter_/1000,currenthyperlink/1000) ;
  endgroup ; 
enddef ; 

% \setupinteraction[state=start]
% \setupcolors     [state=start]
% 
% Hello There! \blank 
% 
% \startMPcode 
% pickup pencircle scaled 5 ; 
% draw fullcircle scaled 4cm withcolor red ;  
% hyperpath "nextpage" boundingbox currentpicture ; 
% draw origin withcolor blue ;
% \stopMPcode
% 
% \blank Does it work or not? 
% 
% \startMPcode 
% pickup pencircle scaled 5 ; 
% draw fullcircle scaled 4cm withcolor red ;  
% hyperpath "nextpage" fullcircle scaled 4cm ; 
% draw origin withcolor blue ;
% draw fullcircle scaled 4cm shifted (1cm,1cm);  
% \stopMPcode
% 
% \blank Does it work or not? \page Hello There! \blank 
% 
% \startMPcode 
% pickup pencircle scaled 5 ; 
% draw fullcircle scaled 2cm shifted (-2cm,-1cm) ;  
% draw fullcircle scaled 3cm shifted (2cm,1cm) withcolor red ;  
% draw fullcircle scaled 1cm ;  
% hyperlink "previouspage" scaled 3cm shifted (2cm,1cm) ; 
% draw origin withcolor blue ; 
% \stopMPcode
% 
% \blank Does it work or not?  

_cmyk_counter_ := 0 ;

numeric cmykcolorhash[][][][] ;

boolean cmykcolors ; % cmykcolors := true ;

let normalcmyk = cmyk ; % see mp-tool.mp 

vardef cmyk(expr c,m,y,k) =
  if cmykcolors :
    if not known cmykcolorhash[c][m][y][k] :
      _cmyk_counter_ := _cmyk_counter_ + 1 ;
      cmykcolorhash[c][m][y][k] := _cmyk_counter_ ;
      flush_special(1, 7,
        decimal _cmyk_counter_ & " "  & 
        decimal c & " " &
        decimal m & " " &
        decimal y & " " &
        decimal k) ;
    fi
    (_special_signal_/1000,1/1000,cmykcolorhash[c][m][y][k]/1000)
  else :
    normalcmyk(1-c-k,1-m-k,1-y-k)
  fi
enddef ;

%D Basic position tracking: 

def register (expr label, width, height, offset) = 
  begingroup ; 
  flush_special(50, 7,
    ddecimal offset & " " & 
    decimal  width  & " " & 
    decimal  height & " " & label) ; 
  endgroup ; 
enddef ; 

endinput ; 
