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

% (r,g,b) => cmyk             : r=123 g=   1 b=hash
%         => transparent rgb  : r=123 g=   2 b=hash
%         => transparent cmyk : r=123 g=   3 b=hash
%         => rest             : r=123 g=n>10 b=whatever 

%D This module is rather preliminary and subjected to
%D changes. Here we closely cooperates with the \METAPOST\
%D to \PDF\ converter module built in \CONTEXT\ and provides
%D for instance shading. More information can be found in
%D type {supp-mpe.tex}.

if unknown context_tool :    input mp-tool ; fi ;
if   known context_spec : endinput         ; fi ;

boolean context_spec ; context_spec := true ;

numeric _special_counter_ ; _special_counter_ :=   0 ;
numeric _color_counter_   ; _color_counter_   :=  11 ; % < 10 reserved  
numeric _special_signal_  ; _special_signal_  := 123 ;

%D When set to \type {true}, shading will be supported. Some
%D day I will also write an additional directive.

boolean _inline_specials_ ; _inline_specials_ := false ;

%D Because we want to output only those specials that are
%D actually used in a figure, we need a bit complicated
%D bookkeeping and collection of specials. At the cost of some
%D obscurity, we now have rather efficient resources.

string _global_specials_ ; _global_specials_ := "" ;
string _local_specials_  ; _local_specials_  := "" ;

vardef add_special_signal = % write the version number
  if (length _global_specials_>0) or (length _local_specials_ >0) : 
    special ("%%MetaPostSpecials: 1.0 " & decimal _special_signal_ ) ;
  fi ;
enddef ;

vardef add_extra_specials =
  scantokens _global_specials_ ;
  scantokens _local_specials_ ;
enddef ;

vardef reset_extra_specials =
  % only local ones 
  _local_specials_ := "" ;
enddef ;

boolean insidefigure ; insidefigure := false ;

% todo: alleen als special gebruikt flush 

extra_beginfig := 
  " insidefigure := true ; " & 
  " reset_extra_specials ; " & 
    extra_beginfig ;  

extra_endfig :=
  " add_special_signal ; "    &
    extra_endfig              &
  " add_extra_specials ; "    &
  " reset_extra_specials ; "  & 
  " insidefigure := false ; " ;

def set_extra_special (expr s) = 
  if insidefigure : 
    _local_specials_  := _local_specials_  & s ; 
  else : 
    _global_specials_ := _global_specials_ & s ; 
  fi 
enddef ; 

def flush_special (expr typ, siz, dat) =
  _special_counter_ := _special_counter_ + 1 ;
  if _inline_specials_ :
    set_extra_special
      ( "special "
      & "(" & ditto
      & dat & " "
      & decimal _special_counter_ & " "
      & decimal typ & " "
      & decimal siz
      & " special"
      & ditto & ");" ) ; 
  else :
    set_extra_special
      ( "special "
      & "(" & ditto
      & "%%MetaPostSpecial: "
      & decimal siz & " "
      & dat & " "
      & decimal _special_counter_ & " "
      & decimal typ
      & ditto & ");" ) ;
  fi ;
enddef ;

%D The next hack is needed in case you use a version of
%D \METAPOST\ that does not provide you the means to configure
%D the buffer size. Patrick Gundlach suggested to use arrays 
%D in this case. 

boolean bufferhack ; bufferhack := false ; % true ; 

if bufferhack : 

  string _global_specials_[] ; numeric _nof_global_specials_ ;
  string _local_specials_[]  ; numeric _nof_local_specials_ ;

  _nof_global_specials_ := _nof_local_specials_ := 0 ;

  vardef add_special_signal = % write the version number
    if (_nof_global_specials_>0) or (_nof_local_specials_>0) : 
      special ("%%MetaPostSpecials: 1.0 " & decimal _special_signal_ ) ;
    fi ;
  enddef ;
 
  vardef add_extra_specials =
    for i=1 upto _nof_global_specials_ : 
      scantokens _global_specials_[i] ; 
    endfor;
    for i=1 upto _nof_local_specials_ : 
      scantokens _local_specials_[i] ;   
    endfor;
  enddef ;

  vardef reset_extra_specials =
    string _local_specials_[]  ; _nof_local_specials_ := 0 ;
  enddef ;

  def set_extra_special (expr s) = 
    if insidefigure : 
      _local_specials_[incr(_nof_local_specials_)]   := s ;   
    else : 
      _global_specials_[incr(_nof_global_specials_)] := s ;
    fi 
  enddef ; 

fi ; 

%D So far for this hack. 

%D Shade allocation.

vardef define_linear_shade (expr a, b, ca, cb) =
  flush_special(30, 15, "0 1 1" &
    dddecimal ca & ddecimal a &
    dddecimal cb & ddecimal b ) ;
  _special_counter_
enddef ;

vardef define_circular_shade (expr a, b, ra, rb, ca, cb) =
  flush_special(31, 17, "0 1 1" &
    dddecimal ca & ddecimal a & " " & decimal ra &
    dddecimal cb & ddecimal b & " " & decimal rb ) ;
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

vardef predefined_linear_shade (expr p, n, ca, cb) =
  save a, b, sh ; pair a, b ;
  if     (n=1) : a := llcorner p ; b := urcorner p ;
  elseif (n=2) : a := llcorner p ; b := ulcorner p ;
  elseif (n=3) : a := lrcorner p ; b := ulcorner p ;
  else         : a := llcorner p ; b := lrcorner p ;
  fi ;
  define_linear_shade (a,b,ca,cb) 
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

vardef predefined_circular_shade (expr p, n, ca, cb) =
  save ab, r ; pair ab ; numeric r ;
  r := (xpart lrcorner p - xpart llcorner p) ++
       (ypart urcorner p - ypart lrcorner p) ;
  if     (n=1) : ab := llcorner p ;
  elseif (n=2) : ab := lrcorner p ;
  elseif (n=3) : ab := urcorner p ;
  elseif (n=4) : ab := ulcorner p ;
  else         : ab := center p ; r := .5r ;
  fi ;
  define_circular_shade(ab,ab,0,r,ca,cb) 
enddef ;

%D Since a \type {fill p withshade s} syntax looks better
%D than some macro, we implement a new primary.

primarydef p withshade sc =
  hide (_color_counter_ := _color_counter_ + 1)
  p withcolor (_special_signal_/1000,_color_counter_/1000,sc/1000)
enddef ;

%D Figure inclusion.

%numeric cef ; cef := 0 ;

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
  _color_counter_ := _color_counter_ + 1 ; 
  draw p withcolor (_special_signal_/1000,_color_counter_/1000,_special_counter_/1000) ;
%draw p withcolor (_special_signal_/1000,cef/1000,_special_counter_/1000) ;
  endgroup ;
enddef ;

%D Experimental:

%numeric currenthyperlink ; currenthyperlink := 0 ;

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
%  currenthyperlink := currenthyperlink + 1 ;
  _color_counter_ := _color_counter_ + 1 ;
  fill boundingbox unitsquare scaled 0 withcolor
    (_special_signal_/1000,_color_counter_/1000,_special_counter_/1000) ;
%    (_special_signal_/1000,currenthyperlink/1000,_special_counter_/1000) ;
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

extra_endfig := " resetcmykcolors ; " & extra_endfig ;

def resetcmykcolors =
  numeric cmykcolorhash[][][][] ;
enddef ;

resetcmykcolors ; boolean cmykcolors ; cmykcolors := false ; % true

% vardef cmyk(expr c,m,y,k) =
%   if cmykcolors :
%     if not known cmykcolorhash[c][m][y][k] :
%       _cmyk_counter_ := _cmyk_counter_ + 1 ;
%       cmykcolorhash[c][m][y][k] := _cmyk_counter_ ;
%       flush_special(1, 7,
%         decimal _cmyk_counter_ & " "  &
%         decimal c & " " &
%         decimal m & " " &
%         decimal y & " " &
%         decimal k) ;
%     fi
%     (_special_signal_/1000,1/1000,cmykcolorhash[c][m][y][k]/1000)
%   else :
%     (1-c-k,1-m-k,1-y-k)
%   fi
% enddef ;

string cmykcolorpattern[] ; % needed for transparancies 

vardef cmyk(expr c,m,y,k) =
  if cmykcolors :
    save ok ; boolean ok ; 
    if unknown cmykcolorhash[c][m][y][k] :
      ok := false ; % not yet defined 
    elseif cmykcolorhash[c][m][y][k] = -1 : 
      ok := false ; % locally defined and undefined  
    else : 
     ok := true ;  % globally already defined 
    fi ; 
    if not ok : 
      save s ; string s ; s := dddecimal (c,m,y) & " " & decimal k ;
      _cmyk_counter_ := _cmyk_counter_ + 1 ;
      cmykcolorpattern[_cmyk_counter_/1000] := s ;  
      cmykcolorhash[c][m][y][k] := _cmyk_counter_ ;
      flush_special(1, 7, decimal _cmyk_counter_ & " " & s) ; 
      _local_specials_ := _local_specials_ & 
        " cmykcolorhash[" & decimal c & "][" & decimal m & 
        "][" & decimal y & "][" & decimal k & "] := -1 ; " ;  
    fi ;
    (_special_signal_/1000,1/1000,cmykcolorhash[c][m][y][k]/1000)
  else :
    (1-c-k,1-m-k,1-y-k)
  fi
enddef ;

% newcolor truecyan, truemagenta, trueyellow ; 
%
% truecyan    = cmyk (1,0,0,0) ; 
% truemagenta = cmyk (0,1,0,0) ; 
% trueyellow  = cmyk (0,0,1,0) ; 

%D Transparency 

normaltransparent     :=  1 ; multiplytransparent   :=  2 ; 
screentransparent     :=  3 ; overlaytransparent    :=  4 ; 
softlighttransparent  :=  5 ; hardlighttransparent  :=  6 ; 
colordodgetransparent :=  7 ; colorburntransparent  :=  8 ; 
darkentransparent     :=  9 ; lightentransparent    := 10 ; 
differencetransparent := 11 ; exclusiontransparent  := 12 ; 

% nottransparent        :=  0 ; 
% compatibletransparent := 99 ; 

% fill fullcircle scaled 10cm withcolor transparant(.8,3,color) ; 

vardef transparent(expr n, t, c) =
  save s, ss, nn, cc, is_cmyk, ok ;
  string s, ss ; numeric nn ; color cc ; boolean is_cmyk, ok ;
  % transparancy type
  if string n :
    if expandafter known scantokens(n&"transparent") :
      nn := scantokens(n&"transparent") ;
    else :
      nn := 0 ;
    fi
  else : % nn := min(n,13)
    nn := if n<13 : n else : nn := 0 fi ;
  fi ;
  % we need to expand the color (can be cmyk(..) or predefined)
  cc := c ; % expand color
  % check for cmyk special
  is_cmyk := (redpart   cc = _special_signal_/1000)
         and (greenpart cc = 1/1000) ;
  % build special string, fetch cmyk components
  s := decimal nn & " " & decimal t & " " & if is_cmyk :
         cmykcolorpattern[bluepart cc] else : dddecimal cc fi ;
  % check if this one is already used
  ss := "tr_" & s ;
  % efficiency hack
  if expandafter unknown scantokens(ss) :
    ok := false ; % not yet defined 
  elseif scantokens(ss) < 0  :  
    ok := false ; % locally defined and undefined  
  else : 
    ok := true ;  % globally already defined 
  fi ; 
  if not ok : 
    if is_cmyk :
      flush_special(3, 8, s) ;
    else :
      flush_special(2, 7, s) ;
    fi ;
    scantokens(ss) := _special_counter_ ;
    _local_specials_ := _local_specials_ & 
      "scantokens(" & ditto & ss & ditto & ") := -1 ;" ; 
  fi ; 
  % go ahead
  if is_cmyk :
    (_special_signal_/1000,3/1000,scantokens(ss)/1000)
  else :
    (_special_signal_/1000,2/1000,scantokens(ss)/1000)
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
