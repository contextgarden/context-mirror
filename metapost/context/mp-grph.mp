%D \module
%D   [       file=mp-grph.mp,
%D        version=2000.12.14,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=graphic text support, 
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
%C details. 

%D Under construction.

if unknown context_tool :    input mp-tool ; fi ; 
if   known context_grph : endinput         ; fi ; 

boolean context_grph ; context_grph := true ; 

string CRLF ; CRLF := char 10 & char 13 ; 

picture _currentpicture_ ; 

def protectgraphicmacros = 
  save showtext ; 
  save beginfig ; let beginfig = begingraphictextfig ;
  save endfig   ; let endfig   = endgraphictextfig ;
  save end      ; let end      = relax ; 
  interim prologues := prologues ; 
  interim linecap   := butt ; 
  interim linejoin  := mitered ; 
enddef ; 

numeric currentgraphictext ; currentgraphictext := 0 ; 
string  graphictextformat  ; graphictextformat  := "plain" ;
string  graphictextstring  ; graphictextstring  := "" ; 
string  graphictextfile    ; graphictextfile    := "dummy.mpo" ;

def savegraphictext (expr str) = 
  graphictextfile := jobname & ".mpo" ;
  if (graphictextstring<>"") :
    write graphictextstring to graphictextfile ;
    graphictextstring := "" ; 
  fi ; 
  write str to graphictextfile ;
  let erasegraphictextfile = relax ; 
enddef ; 

def erasegraphictextfile = 
  graphictextfile := jobname & ".mpo" ;
  write EOF to graphictextfile  ;
  let erasegraphictextfile = relax ; 
enddef ; 

extra_beginfig := extra_beginfig & "erasegraphictextfile ;" ; 

def begingraphictextfig (expr n) =
  foundpicture := n ; scratchpicture := nullpicture ;
enddef ;

def endgraphictextfig =
  if foundpicture = currentgraphictext : 
    expandafter endinput 
  else : 
    scratchpicture := nullpicture ; 
  fi ;
enddef ;

% def loadfigure (expr filename, n) =
%   begingroup ;
%   protectgraphicmacros ; % also save linewidth, color, options etc ?
%   save sp ; picture sp ; sp := currentpicture ; 
%   save ok ; boolean ok ; ok := false ; 
%   def beginfig (expr m) = 
%    if n=m : 
%      currentpicture := sp ; ok := true ;
%      def endfig = endinput ; enddef ; 
%    else : 
%      currentpicture := nullpicture ; 
%    fi ; 
%   enddef ; 
%   let endfig = relax ; 
%   readfile(filename) ; 
%   if not ok : currentpicture := sp ; fi ; 
%   endgroup ;
% enddef ;

def loadfigure primary filename = 
  doloadfigure (filename) 
enddef ; 

def doloadfigure (expr filename) text figureattributes =
  begingroup ;
  save figurenumber, figurepicture, number ; 
  numeric figurenumber  ; figurenumber  := 1 ; 
  picture figurepicture ; figurepicture := currentpicture ; 
  def number primary n = hide(figurenumber := n) enddef ; 
  protectgraphicmacros ; 
  currentpicture := nullpicture ; 
  def beginfig (expr n) = 
    currentpicture := nullpicture ; 
    if figurenumber=n : let endfig = endinput ; fi ; 
  enddef ; 
  let endfig = relax ; 
  readfile(filename) ; 
  currentpicture := currentpicture shifted -llcorner currentpicture ;   
  addto figurepicture also currentpicture figureattributes ;   
  currentpicture := figurepicture  ; 
  endgroup ;
enddef ;

def graphictext primary t =
  dographictext(t)
enddef ;

def dographictext (expr t) text x_op_x =
  begingroup ;
  protectgraphicmacros ; 
  if graphictextformat<>"" :
    graphictextstring := 
      "% format=" & graphictextformat & CRLF & graphictextstring ;
    graphictextformat := "" ; 
  fi ;
  let normalwithshade = withshade ; 
  save foundpicture, scratchpicture, str ;
  save fill, draw, withshade, reversefill, outlinefill ;
  numeric foundpicture ; picture scratchpicture ; string str ; 
  currentgraphictext := currentgraphictext + 1 ;
  savegraphictext ("\startTEXpage[scale=10000]" & t & "\stopTEXpage") ;
  def draw expr p =
    addto scratchpicture doublepath p withpen currentpen ;
  enddef ;
  def fill expr p =
    addto scratchpicture contour p withpen currentpen ;
  enddef ;
  def f_op_f = enddef ; boolean f_color ; f_color := false ; 
  def d_op_d = enddef ; boolean d_color ; d_color := false ; 
  def s_op_s = enddef ; boolean s_color ; s_color := false ; 
  boolean reverse_fill ; reverse_fill := false ;  
  boolean outline_fill ; outline_fill := false ;  
  def reversefill = 
    hide(reverse_fill := true ) 
  enddef ; 
  def outlinefill = 
    hide(outline_fill := true ) 
  enddef ; 
  def withshade primary c =
    hide(def s_op_s = normalwithshade c enddef ; s_color := true )
  enddef ;
  def withfillcolor primary c =
    hide(def f_op_f = withcolor c enddef ; f_color := true )
  enddef ;
  def withdrawcolor primary c =
    hide(def d_op_d = withcolor c enddef ; d_color := true )
  enddef ;
  scratchpicture := nullpicture ;
  addto scratchpicture doublepath origin x_op_x ; % pre-roll
  for i within scratchpicture : % Below here is a dirty tricky test! 
    if (urcorner dashpart i) = origin : outline_fill := false ; fi ; 
  endfor ; 
  scratchpicture := nullpicture ;
  readfile(jobname & ".mpy") ; 
  scratchpicture := (scratchpicture shifted -llcorner scratchpicture) scaled (1/10) ;
  if not d_color and not f_color : d_color := true ; fi 
  if s_color : d_color := false ; f_color := false ; fi ; 
  if d_color and not reverse_fill : 
    for i within scratchpicture : 
      if f_color and outline_fill : 
        addto currentpicture doublepath pathpart i _op_ x_op_x f_op_f 
          dashed nullpicture ;
      fi ; 
      if filled i : 
        addto currentpicture doublepath pathpart i _op_ x_op_x d_op_d ;
      fi ; 
    endfor ;
  fi ;
  if f_color : 
    for i within scratchpicture :
      if filled i : 
        addto currentpicture contour pathpart i _op_ x_op_x f_op_f 
          withpen pencircle scaled 0 ; 
      fi ; 
    endfor ;
  fi ;
  if d_color and reverse_fill : 
    for i within scratchpicture :
      if filled i : 
        addto currentpicture doublepath pathpart i _op_ x_op_x d_op_d ;
      fi ; 
    endfor ;
  fi ;
  if s_color : 
    for i within scratchpicture :
      if filled i : 
        addto currentpicture contour pathpart i _op_ x_op_x s_op_s ;
      fi ; 
    endfor ;
  else : 
    for i within scratchpicture :
      if stroked i : 
        addto currentpicture doublepath pathpart i _op_ x_op_x d_op_d ;
      fi ; 
    endfor ;
  fi ; 
  endgroup ;
enddef ;

def resetgraphictextdirective = 
  graphictextstring := "" ; 
enddef ; 

def graphictextdirective text t = 
  graphictextstring := graphictextstring & t & CRLF ; 
enddef ; 

endinput  

% example

input mp-grph ; 

  graphictextformat := "context" ; 
% graphictextformat := "plain" ; 
% graphictextformat := "latex" ; graphictextdirective "\documentclass[]{article}" ;

beginfig (1) ;
  graphictext
    "\vbox{\hsize10cm \input tufte }"
    scaled 8
    withdrawcolor blue
    withfillcolor red
    withpen pencircle scaled 2pt ;
endfig ; 

beginfig(1) ; 
  loadfigure "gracht.mp" rotated 20 ; 
  loadfigure "koe.mp" number 1 scaled 2 ; 
endfig ; 

end
