%D \module
%D   [       file=mp-tool.mp,
%D        version=1998.02.15,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=auxiliary macros,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See mreadme.pdf for
%C details.

%D This module is rather preliminary and subjected to
%D changes.

if known context_tool : endinput ; fi ;

boolean context_tool ; context_tool := true ;

%D We always want \EPS\ conforming output, so we say:

prologues    := 2 ; % 1 = troff, 2 = tex
warningcheck := 0 ;

%D A semicolor to be used in specials:

string semicolor ; semicolor := char 59 ;

%D By including this module, \METAPOST\ automatically writes a
%D high resolution boundingbox to the \POSTSCRIPT\ file. This
%D hack is due to John Hobby himself.

% somehow the first one gets no HiRes.

vardef ddecimal primary p =
  " " & decimal xpart p &
  " " & decimal ypart p
enddef ;

extra_endfig := extra_endfig
 & "special "
       & "("
       & ditto
       & "%%HiResBoundingBox:"
       & ditto
       & "&ddecimal llcorner currentpicture"
       & "&ddecimal urcorner currentpicture"
       & ");";

%D Also handy (when we flush colors):

vardef dddecimal primary c =
  " " & decimal redpart   c &
  " " & decimal greenpart c &
  " " & decimal bluepart  c
enddef ;

%D We have standardized data file names:

if not known _data_prefix_ :

  string _data_prefix_ ; _data_prefix_ = "mpd-" ;
  string _data_suffix_ ; _data_suffix_ = ".tmp" ;

fi ;

def data_file =
  _data_prefix_ & decimal charcode & _data_suffix_
enddef ;

%D Because \METAPOST\ has a hard coded limit of 4~datafiles,
%D we need some trickery when we have multiple files.

if unknown collapse_data : 
  boolean collapse_data ; collapse_data := false ; 
fi ; 

boolean savingdata ; savingdata := false ; 

def savedata expr txt =
  if collapse_data : 
    write if savingdata : txt else :
      "\MPdata{" & decimal charcode & "}{" & txt & "}" 
    fi 
    & "%" to jobname & _data_suffix_ ;
  else : 
    write txt to data_file ;
  fi ; 
enddef ;

def startsavingdata = 
  savingdata := true ; 
  if collapse_data : 
    write 
      "\MPdata{" & decimal charcode & "}{%" 
    to 
      jobname & _data_suffix_ ;
  fi ; 
enddef ;

def stopsavingdata = 
  savingdata := false ; 
  if collapse_data : 
    write "}%" to jobname & _data_suffix_ ;
  fi ; 
enddef ;

%D Instead of a keystroke eating save and allocation 
%D sequence, you can use the \citeer {new} alternatives to 
%D save and allocate in one command. 

def newcolor     text v = forsuffixes i=v : save i ; color     i ; endfor ; enddef ;
def newnumeric   text v = forsuffixes i=v : save i ; numeric   i ; endfor ; enddef ;
def newboolean   text v = forsuffixes i=v : save i ; boolean   i ; endfor ; enddef ;
def newtransform text v = forsuffixes i=v : save i ; transform i ; endfor ; enddef ;
def newpath      text v = forsuffixes i=v : save i ; path      i ; endfor ; enddef ;
def newpicture   text v = forsuffixes i=v : save i ; picture   i ; endfor ; enddef ;
def newstring    text v = forsuffixes i=v : save i ; string    i ; endfor ; enddef ;

%D Sometimes we don't want parts of the graphics add to the
%D bounding box. One way of doing this is to save the bounding
%D box, draw the graphics that may not count, and restore the
%D bounding box.
%D
%D \starttypen
%D push_boundingbox currentpicture;
%D pop_boundingbox currentpicture;
%D \stoptypen
%D
%D The bounding box can be called with:
%D
%D \starttypen
%D boundingbox currentpicture
%D inner_boundingbox currentpicture
%D outer_boundingbox currentpicture
%D \stoptypen
%D
%D Especially the latter one can be of use when we include
%D the graphic in a document that is clipped to the bounding
%D box. In such occasions one can use:
%D
%D \starttypen
%D set_outer_boundingbox currentpicture;
%D \stoptypen
%D
%D Its counterpart is:
%D
%D \starttypen
%D set_inner_boundingbox p
%D \stoptypen

path pushed_boundingbox;

def push_boundingbox text p =
  pushed_boundingbox := boundingbox p;
enddef;

def pop_boundingbox text p =
  setbounds p to pushed_boundingbox;
enddef;

vardef boundingbox primary p =
  llcorner p --
  lrcorner p --
  urcorner p --
  ulcorner p -- cycle
enddef;

vardef inner_boundingbox primary p =
  top  rt llcorner p --
  top lft lrcorner p --
  bot lft urcorner p --
  bot  rt ulcorner p -- cycle
enddef;

vardef outer_boundingbox primary p =
  bot lft llcorner p --
  bot  rt lrcorner p --
  top  rt urcorner p --
  top lft ulcorner p -- cycle
enddef;

def innerboundingbox = inner_boundingbox enddef ;
def outerboundingbox = outer_boundingbox enddef ;

vardef set_inner_boundingbox text q =
  setbounds q to inner_boundingbox q;
enddef;

vardef set_outer_boundingbox text q =
  setbounds q to outer_boundingbox q;
enddef;

%D Some missing functions can be implemented rather
%D straightforward:

def tand (expr x) = (sind(x)/cosd(x))                     enddef ;
def sqr  (expr x) = (x*x)                                 enddef ;
def log  (expr x) = (if x=0: 0 else: mlog(x)/mlog(10) fi) enddef ;
def ln   (expr x) = (if x=0: 0 else: mlog(x)/256 fi)      enddef ;
def exp  (expr x) = ((mexp 256)**x)                       enddef ;
def pow  (expr x) = (x**power)                            enddef ;
def inv  (expr x) = (if x=0: 0 else: x**-1 fi)            enddef ;
def asin (expr x) = (x+(x**3)/6+3(x**5)/40)               enddef ;
def acos (expr x) = (asin(-x))                            enddef ;
def atan (expr x) = (x-(x**3)/3+(x**5)/5-(x**7)/7)        enddef ;

numeric Pi ; Pi := 3.14159 ;

%D We provide two macros for drawing stripes across a shape.
%D The first method (with the n suffix) uses another method,
%D slower in calculation, but more efficient when drawn. The
%D first macro divides the sides into n equal parts. The
%D first argument specifies the way the lines are drawn, while
%D the second argument identifier the way the shape is to be
%D drawn.
%D
%D \starttypen
%D stripe_path_n
%D   (dashed evenly withcolor blue)
%D   (filldraw)
%D   fullcircle xscaled 100 yscaled 40 shifted (50,50) withpen pencircle scaled 4;
%D \stoptypen
%D
%D The a (or angle) alternative supports arbitrary angles and
%D is therefore more versatile.
%D
%D \starttypen
%D stripe_path_a
%D   (withpen pencircle scaled 2 withcolor red)
%D   (draw)
%D   fullcircle xscaled 100 yscaled 40 withcolor blue;
%D \stoptypen
%D
%D The first alternative obeys:

stripe_n     := 10;
stripe_slot  :=  3;

%D When no pen dimensions are passed, the slot determines
%D the spacing.
%D
%D The angle alternative is influenced by:

stripe_gap   :=  5;
stripe_angle := 45;

def stripe_path_n (text s_spec) (text s_draw) expr s_path =
  do_stripe_path_n (s_spec) (s_draw) (s_path)
enddef;

def do_stripe_path_n (text s_spec) (text s_draw) (expr s_path) text s_text =
  begingroup
  save curpic, newpic, bb, pp, ww;
  picture curpic, newpic;
  path bb, pp;
  pp := s_path;
  curpic := currentpicture;
  currentpicture := nullpicture;
  s_draw pp s_text;
  bb := boundingbox currentpicture;
  newpic := currentpicture;
  currentpicture := nullpicture;
  ww := min(ypart urcorner newpic - ypart llcorner newpic,
            xpart urcorner newpic - xpart llcorner newpic);
  ww := ww/(stripe_slot*stripe_n);
  for i=1/stripe_n step 1/stripe_n until 1:
    draw point (1+i) of bb -- point (3-i) of bb
      withpen pencircle scaled ww s_spec ;
  endfor;
  for i=0 step 1/stripe_n until 1:
    draw point (3+i) of bb -- point (1-i) of bb
      withpen pencircle scaled ww s_spec;
  endfor;
  clip currentpicture to pp;
  addto newpic also currentpicture;
  currentpicture := curpic;
  addto currentpicture also newpic;
  endgroup
enddef;

def stripe_path_a (text s_spec) (text s_draw) expr s_path =
  do_stripe_path_a (s_spec) (s_draw) (s_path)
enddef;

def do_stripe_path_a (text s_spec) (text s_draw) (expr s_path) text s_text =
  begingroup
  save curpic, newpic, pp; picture curpic, newpic; path pp ;
  pp := s_path ;
  curpic := currentpicture;
  currentpicture := nullpicture;
  s_draw pp s_text ;
  def do_stripe_rotation (expr p) =
    (currentpicture rotatedaround(center p,stripe_angle))
  enddef ;
  s_max := max
   (xpart llcorner do_stripe_rotation(currentpicture),
    xpart urcorner do_stripe_rotation(currentpicture),
    ypart llcorner do_stripe_rotation(currentpicture),
    ypart urcorner do_stripe_rotation(currentpicture));
  newpic := currentpicture;
  currentpicture := nullpicture;
  for i=-s_max-.5stripe_gap step stripe_gap until s_max:
    draw (-s_max,i)--(s_max,i) s_spec;
  endfor;
  currentpicture := do_stripe_rotation(newpic);
  clip currentpicture to pp ;
  addto newpic also currentpicture;
  currentpicture := curpic;
  addto currentpicture also newpic;
  endgroup
enddef;

%D A few normalizing macros:
%D
%D \starttypen
%D xscale_currentpicture  ( width )
%D yscale_currentpicture  ( height )
%D xyscale_currentpicture ( width, height )
%D scale_currentpicture   ( width, height )
%D \stoptypen

% def xscale_currentpicture(expr the_width) =
%   natural_width  := xpart urcorner currentpicture - xpart llcorner currentpicture;
%   currentpicture := currentpicture scaled (the_width/natural_width) ;
% enddef;
% 
% def yscale_currentpicture(expr the_height ) =
%   natural_height := ypart urcorner currentpicture - ypart llcorner currentpicture;
%   currentpicture := currentpicture scaled (the_height/natural_height) ;
% enddef;
% 
% def xyscale_currentpicture(expr the_width, the_height) =
%   natural_width  := xpart urcorner currentpicture - xpart llcorner currentpicture;
%   natural_height := ypart urcorner currentpicture - ypart llcorner currentpicture;
%   currentpicture := currentpicture
%     xscaled (the_width/natural_width)
%     yscaled (the_height/natural_height) ;
% enddef;
% 
% def scale_currentpicture(expr the_width, the_height) =
%   xscale_currentpicture(the_width) ;
%   yscale_currentpicture(the_height) ;
% enddef;

% nog eens uitbreiden zodat path en pic worden afgehandeld. 

%   natural_width  := xpart urcorner currentpicture - xpart llcorner currentpicture;
%   currentpicture := currentpicture scaled (the_width/natural_width) ;

% TODO TODO TODO TODO, not yet ok 

primarydef p xsized w =
  (p scaled (w/(xpart urcorner p - xpart llcorner p)))  
enddef ;

primarydef p ysized h =
  (p scaled (h/(ypart urcorner p - ypart llcorner p)))  
enddef ;

primarydef p sized wh =
  (p xscaled (xpart wh/(xpart urcorner p - xpart llcorner p))  
     yscaled (ypart wh/(ypart urcorner p - ypart llcorner p)))  
enddef ;

primarydef p xysized wh =
  (p xscaled (xpart wh/(xpart urcorner p - xpart llcorner p))  
     yscaled (ypart wh/(ypart urcorner p - ypart llcorner p)))  
enddef ;

def xscale_currentpicture(expr w) =
  currentpicture := currentpicture xsized w ;
enddef;

def yscale_currentpicture(expr h) =
  currentpicture := currentpicture ysized h ;
enddef;

def xyscale_currentpicture(expr w, h) =
  currentpicture := currentpicture xysized (w,h) ;
enddef;

def scale_currentpicture(expr w, h) =
  currentpicture := currentpicture xsized w ;
  currentpicture := currentpicture ysized h ;
enddef;

%D A full circle is centered at the origin, while a unitsquare
%D is located in the first quadrant. Now guess what kind of
%D path fullsquare and unitcircle do return.

path fullsquare, unitcircle ;

fullsquare := unitsquare shifted - center unitsquare ;
unitcircle := fullcircle shifted urcorner fullcircle ;

%D Some more paths:

path urcircle, ulcircle, llcircle, lrcircle ;

urcircle := origin--(+.5,0)&(+.5,0){up}   ..(0,+.5)&(0,+.5)--cycle ;
ulcircle := origin--(0,+.5)&(0,+.5){left} ..(-.5,0)&(-.5,0)--cycle ;
llcircle := origin--(-.5,0)&(-.5,0){down} ..(0,-.5)&(0,-.5)--cycle ;
lrcircle := origin--(0,-.5)&(0,-.5){right}..(+.5,0)&(+.5,0)--cycle ;

path tcircle, bcircle, lcircle, rcircle ;

tcircle = origin--(+.5,0)&(+.5,0){up}   ..(0,+.5)..{down} (-.5,0)--cycle ;
bcircle = origin--(-.5,0)&(-.5,0){down} ..(0,-.5)..{up}   (+.5,0)--cycle ;
lcircle = origin--(0,+.5)&(0,+.5){left} ..(-.5,0)..{right}(0,-.5)--cycle ;
rcircle = origin--(0,-.5)&(0,-.5){right}..(+.5,0)..{left} (0,+.5)--cycle ;

path urtriangle, ultriangle, lltriangle, lrtriangle ;

urtriangle := origin--(+.5,0)--(0,+.5)--cycle ;
ultriangle := origin--(0,+.5)--(-.5,0)--cycle ;
lltriangle := origin--(-.5,0)--(0,-.5)--cycle ;
lrtriangle := origin--(0,-.5)--(+.5,0)--cycle ;

path unitdiamond, fulldiamond ;

unitdiamond := (.5,0)--(1,.5)--(.5,1)--(0,.5)--cycle ;
fulldiamond := unitdiamond shifted - center unitdiamond ;

%D shorter

primarydef p xyscaled q =
  p xscaled (xpart paired(q)) yscaled (ypart paired(q))
enddef ;

%D Experimenteel, zie folder-3.tex.

def set_grid(expr w, h, nx, ny) =
  boolean grid[][] ; boolean grid_full ;
  grid_w := w ;
  grid_h := h ;
  grid_nx := nx ;
  grid_ny := ny ;
  grid_x := round(w/grid_nx) ; % +.5) ;
  grid_y := round(h/grid_ny) ; % +.5) ;
  grid_left := (1+grid_x)*(1+grid_y) ;
  grid_full := false ;
  for i=0 upto grid_x:
    for j=0 upto grid_y:
      grid[i][j] := false ;
    endfor ;
  endfor ;
enddef ;

vardef new_on_grid(expr _dx_, _dy_) =
  dx := _dx_ ;
  dy := _dy_ ;
  ddx := min(round(dx/grid_nx),grid_x) ; % +.5),grid_x) ;
  ddy := min(round(dy/grid_ny),grid_y) ; % +.5),grid_y) ;
  if not grid_full and not grid[ddx][ddy]:
    grid[ddx][ddy] := true ;
    grid_left := grid_left-1 ;
    grid_full := (grid_left=0) ;
    true
  else:
    false
  fi
enddef ;

%D usage: \type{innerpath peepholed outerpath}.
%D
%D beginfig(1);
%D   def fullsquare = (unitsquare shifted -center unitsquare) enddef ;
%D   fill (fullsquare scaled 200) withcolor red ;
%D   path p ; p := (fullcircle scaled 100) ; bboxmargin := 0 ;
%D   fill p peepholed bbox p ;
%D endfig;

secondarydef p peepholed q =
  begingroup ;
  save start ; pair start ; start := point 0 of p ;
  if xpart start >= xpart center p :
    if ypart start >= ypart center p :
      urcorner q -- ulcorner q -- llcorner q -- lrcorner q --
      reverse  p -- lrcorner q -- cycle
    else :
      lrcorner q -- urcorner q -- ulcorner q -- llcorner q --
      reverse  p -- llcorner q -- cycle
    fi
  else :
    if ypart start > ypart center p :
      ulcorner q -- llcorner q -- lrcorner q -- urcorner q --
      reverse  p -- urcorner q -- cycle
    else :
      llcorner q -- lrcorner q -- urcorner q -- ulcorner q --
      reverse  p -- ulcorner q -- cycle
    fi
  fi
  endgroup
enddef ;

boolean intersection_found ;

secondarydef p intersection_point q =
  begingroup
    save x_, y_ ;
    (x_,y_) = p intersectiontimes q ;
    if x_<0 :
      intersection_found := false ;
      center p % origin
    else :
      intersection_found := true ;
      .5[point x_ of p, point y_ of q]
    fi
  endgroup
enddef ;

%D New, undocumented, experimental:

vardef tensecircle (expr width, height, offset) =
  ((-width/2,-height/2) ... (0,-height/2-offset) ...
   (+width/2,-height/2) ... (+width/2+offset,0) ...
   (+width/2,+height/2) ... (0,+height/2+offset) ...
   (-width/2,+height/2) ... (-width/2-offset,0) ... cycle)
enddef ;

%vardef tensecircle (expr width, height, offset) =
%  ((-width/2,-height/2)..(0,-height/2-offset)..(+width/2,-height/2) &
%   (+width/2,-height/2)..(+width/2+offset,0)..(+width/2,+height/2) &
%   (+width/2,+height/2)..(0,+height/2+offset)..(-width/2,+height/2) &
%   (-width/2,+height/2)..(-width/2-offset,0)..(-width/2,-height/2)..cycle)
%enddef ;

vardef roundedsquare (expr width, height, offset) =
  ((offset,0)--(width-offset,0){right}          ..
   (width,offset)--(width,height-offset){up}    ..
   (width-offset,height)--(offset,height){left} ..
   (0,height-offset)--(0,offset){down}          .. cycle)  
enddef ;

%D Some colors.

color cyan    ; cyan    = (0,1,1) ;
color magenta ; magenta = (1,0,1) ;
color yellow  ; yellow  = (1,1,0) ;

%D Well, this is the dangerous and naive version:

def drawfill text t =
  fill t ;
  draw t ;
enddef;

%D This two step approach saves the path first, since it can
%D be a function. Attributes must not be randomized. 

def drawfill expr c =
  path _c_ ; _c_ := c ;
  do_drawfill
enddef ;

def do_drawfill text t =
  draw _c_ t ;
  fill _c_ t ;
enddef;

def undrawfill expr c =
  drawfill c withcolor background
enddef ;

%D Moved from mp-char.mp

vardef paired (expr d) =
  if pair d : d else : (d,d) fi
enddef ;

%primarydef p enlarged d =
%  begingroup ; save dd ; pair dd ;
%  dd := if pair d : d else : (d,d) fi ;
%  (llcorner p shifted (-xpart dd,-ypart dd) --
%   lrcorner p shifted (+xpart dd,-ypart dd) --
%   urcorner p shifted (+xpart dd,+ypart dd) --
%   ulcorner p shifted (-xpart dd,+ypart dd) --
%   cycle)
%  endgroup
%enddef;

primarydef p enlarged d =
  (p llmoved d -- p lrmoved d -- p urmoved d -- p ulmoved d -- cycle)
enddef;

primarydef p llenlarged d =
  (p llmoved d -- lrcorner p -- urcorner p -- ulcorner p -- cycle)
enddef ;

primarydef p lrenlarged d =
  (llcorner p -- p lrmoved d -- urcorner p -- ulcorner p -- cycle)
enddef ;

primarydef p urenlarged d =
  (llcorner p -- lrcorner p -- p urmoved d -- ulcorner p -- cycle)
enddef ;

primarydef p ulenlarged d =
  (llcorner p -- lrcorner p -- urcorner p -- p ulmoved d -- cycle)
enddef ;

primarydef p llmoved d =
  ((llcorner p) shifted (-xpart paired(d),-ypart paired(d)))
enddef ;

primarydef p lrmoved d =
  ((lrcorner p) shifted (+xpart paired(d),-ypart paired(d)))
enddef ;

primarydef p urmoved d =
  ((urcorner p) shifted (+xpart paired(d),+ypart paired(d)))
enddef ;

primarydef p ulmoved d =
  ((ulcorner p) shifted (-xpart paired(d),+ypart paired(d)))
enddef ;

%D Nice too:

primarydef p superellipsed s =
  superellipse
   (.5[lrcorner p,urcorner p],
    .5[urcorner p,ulcorner p],
    .5[ulcorner p,llcorner p],
    .5[llcorner p,lrcorner p],
    s)
enddef ;

primarydef p squeezed s =
  ((llcorner p .. .5[llcorner p,lrcorner p] shifted ( 0, ypart paired(s)) .. lrcorner p) &
   (lrcorner p .. .5[lrcorner p,urcorner p] shifted (-xpart paired(s), 0) .. urcorner p) &
   (urcorner p .. .5[urcorner p,ulcorner p] shifted ( 0,-ypart paired(s)) .. ulcorner p) &
   (ulcorner p .. .5[ulcorner p,llcorner p] shifted ( xpart paired(s), 0) .. llcorner p) & cycle) 
enddef ;

primarydef p randomshifted s = 
  begingroup ; save ss ; pair ss ; ss := paired(s) ; 
  p shifted (-.5xpart ss + uniformdeviate xpart ss,
             -.5ypart ss + uniformdeviate ypart ss) 
  endgroup 
enddef ; 

%primarydef p randomized s =
%  for i=0 upto length(p)-1 : 
%   ((point       i    of p) randomshifted s) .. controls 
%   ((postcontrol i    of p) randomshifted s) and 
%   ((precontrol (i+1) of p) randomshifted s) .. 
%  endfor cycle 
%enddef ;

primarydef p randomized s =
  (if path p : 
    for i=0 upto length(p)-1 :
      ((point       i    of p) randomshifted s) .. controls 
      ((postcontrol i    of p) randomshifted s) and 
      ((precontrol (i+1) of p) randomshifted s) .. 
    endfor 
    if cycle p : 
      cycle 
    else :
      ((point length(p) of p) randomshifted s) 
    fi
  elseif pair p :
   p randomshifted s  
  else :
   p + uniformdeviate s  
  fi)  
enddef ; 

%D Rather fundamental. 

% vardef rightpath expr p = 
%   save q, t, b ; path q ; pair t, b ;  
%   t := (ulcorner p -- urcorner p) intersection_point p ; 
%   b := (llcorner p -- lrcorner p) intersection_point p ; 
%   if xpart directionpoint t of p < 0 : p := reverse p ; fi ;
%   q := p cutbefore b ;
%   q := q if xpart point 0 of p > 0 : & p fi cutafter t ;
%   q 
% enddef ; 
% 
% vardef leftpath expr p = 
%   save q, t, b ; path q ; pair t, b ;  
%   t := (ulcorner p -- urcorner p) intersection_point p ; 
%   b := (llcorner p -- lrcorner p) intersection_point p ; 
%   if xpart directionpoint t of p < 0 : p := reverse p ; fi ;
%   q := p cutbefore t ;
%   q := q if xpart point 0 of p > 0 : & p fi cutafter b ;
%   q 
% enddef ; 

def leftrightpath(expr p, l) = 
  save q, t, b ; path q ; pair t, b ;  
  t := (ulcorner p -- urcorner p) intersection_point p ; 
  b := (llcorner p -- lrcorner p) intersection_point p ; 
  if xpart directionpoint t of p < 0 : p := reverse p ; fi ;
  q := p    cutbefore if l: t else: b fi ;
  q := q if xpart point 0 of p > 0 : & 
       p fi cutafter  if l: b else: t fi ;
  q 
enddef ; 

vardef  leftpath expr p = leftrightpath(p,true ) enddef ; 
vardef rightpath expr p = leftrightpath(p,false) enddef ; 

%D Tracing. 

let normaldraw = draw ;
let normalfill = fill ;

def drawlineoptions   (text t) = def _lin_opt_ = t enddef ; enddef ;
def drawpointoptions  (text t) = def _pnt_opt_ = t enddef ; enddef ;
def drawcontroloptions(text t) = def _ctr_opt_ = t enddef ; enddef ;
def drawlabeloptions  (text t) = def _lab_opt_ = t enddef ; enddef ;
def draworiginoptions (text t) = def _ori_opt_ = t enddef ; enddef ;
def drawboundoptions  (text t) = def _bnd_opt_ = t enddef ; enddef ;
def drawpathoptions   (text t) = def _pth_opt_ = t enddef ; enddef ;

drawlineoptions   (withpen pencircle scaled 1   withcolor .5white) ;
drawpointoptions  (withpen pencircle scaled 4   withcolor   black) ;
drawcontroloptions(withpen pencircle scaled 2.5 withcolor   black) ;
drawlabeloptions  () ;
draworiginoptions (withpen pencircle scaled 1   withcolor .5white) ;
drawboundoptions  (dashed evenly _ori_opt_) ;
drawpathoptions   (withpen pencircle scaled 5   withcolor .8white) ;

%D Path.

def drawpath expr p =
  normaldraw p _pth_opt_
enddef;

%D Arrow.

vardef drawarrowpath expr p = 
  save autoarrows ; boolean autoarrows ; autoarrows := true ; 
  drawarrow p _pth_opt_ 
enddef ; 

%D Points.

def drawpoint expr c = 
  if string c : 
    string _c_ ; _c_ := "(" & c & ")" ; 
    dotlabel.urt(_c_, scantokens _c_) ; 
    drawdot scantokens _c_ 
  else : 
    dotlabel.urt("(" & decimal xpart c & "," & decimal ypart c & ")", c) ; 
    drawdot c 
  fi _pnt_opt_ 
enddef ; 

%D PathPoints. 

def drawpoints        expr c = path _c_ ; _c_ := c ; do_drawpoints        enddef ;
def drawcontrolpoints expr c = path _c_ ; _c_ := c ; do_drawcontrolpoints enddef ;
def drawcontrollines  expr c = path _c_ ; _c_ := c ; do_drawcontrollines  enddef ;
def drawpointlabels   expr c = path _c_ ; _c_ := c ; do_drawpointlabels   enddef ;

def do_drawpoints text t =
  for _i_=0 upto length(_c_) :
    normaldraw point _i_ of _c_ _pnt_opt_ t ;
  endfor ;
enddef;

def do_drawcontrolpoints text t =
  for _i_=0 upto length(_c_) :
    normaldraw precontrol  _i_ of _c_ _ctr_opt_ t ;
    normaldraw postcontrol _i_ of _c_ _ctr_opt_ t ;
  endfor ;
enddef;

def do_drawcontrollines text t =
  for _i_=0 upto length(_c_) :
    normaldraw point _i_ of _c_ -- precontrol  _i_ of _c_ _lin_opt_ t ;
    normaldraw point _i_ of _c_ -- postcontrol _i_ of _c_ _lin_opt_ t ;
  endfor ;
enddef;

boolean swappointlabels ; swappointlabels := false ; 

def do_drawpointlabels text t =
  for _i_=0 upto length(_c_) :
    pair _u_ ; _u_ := unitvector(direction _i_ of _c_) 
      rotated if swappointlabels : - fi 90 ;
    pair _p_ ; _p_ := (point _i_ of _c_) ;
    _u_ := 12 * defaultscale * _u_ ;
    normaldraw thelabel ( decimal _i_, 
    _p_ shifted if cycle _c_ and (_i_=0) : - fi _u_ ) _lab_opt_ t ;
  endfor ;
enddef;

%D Bounding box. 

def drawboundingbox expr p =
  normaldraw boundingbox p _bnd_opt_
enddef ;

%D Origin. 

numeric originlength ; originlength := .5cm ;

def draworigin text t =
  normaldraw (origin shifted (0, originlength) --
              origin shifted (0,-originlength)) _ori_opt_ t ;
  normaldraw (origin shifted ( originlength,0) -- 
              origin shifted (-originlength,0)) _ori_opt_ t ;
enddef;

%D Axis. 

numeric tickstep   ; tickstep   := 5mm ;
numeric ticklength ; ticklength := 2mm ;

def drawxticks expr c = path _c_ ; _c_ := c ; do_drawxticks enddef ;
def drawyticks expr c = path _c_ ; _c_ := c ; do_drawyticks enddef ;
def drawticks  expr c = path _c_ ; _c_ := c ; do_drawticks  enddef ;

% Adding eps prevents disappearance due to rounding errors. 

def do_drawxticks text t = 
  for i=0 step -tickstep until xpart llcorner _c_ - eps :
    if (i<=xpart lrcorner _c_) :
      normaldraw (i,-ticklength)--(i,ticklength) _ori_opt_ t ;
    fi ;
  endfor ;
  for i=0 step  tickstep until xpart lrcorner _c_ + eps :
    if (i>=xpart llcorner _c_) :
      normaldraw (i,-ticklength)--(i,ticklength) _ori_opt_ t ;
    fi ;
  endfor ;
  normaldraw (llcorner _c_ -- ulcorner _c_)
    shifted (-xpart llcorner _c_,0) _ori_opt_ t ;
enddef ;

def do_drawyticks text t =
  for i=0 step -tickstep until ypart llcorner _c_ - eps :
    if (i<=ypart ulcorner _c_) :
      normaldraw (-ticklength,i)--(ticklength,i) _ori_opt_ t ;
    fi ;
  endfor ;
  for i=0 step  tickstep until ypart ulcorner _c_ + eps :
    if (i>=ypart llcorner _c_) :
      normaldraw (-ticklength,i)--(ticklength,i) _ori_opt_ t ;
    fi ;
  endfor ;
  normaldraw (llcorner _c_ -- lrcorner _c_)
    shifted (0,-ypart llcorner _c_) _ori_opt_ t ;
enddef ;

def do_drawticks text t =
  drawxticks _c_ t ;
  drawyticks _c_ t ;
enddef ;

%D All of it except axis.

def drawwholepath expr p =
  draworigin          ;
  drawpath          p ;
  drawcontrollines  p ;
  drawcontrolpoints p ;
  drawpoints        p ;
  drawboundingbox   p ;
  drawpointlabels   p ;
enddef ;

%D Tracing. 

def visualizeddraw expr c = 
  if picture c : normaldraw c else : path _c_ ; _c_ := c ; do_visualizeddraw fi 
enddef ;

def visualizedfill expr c = 
  if picture c : normalfill c else : path _c_ ; _c_ := c ; do_visualizedfill fi 
enddef ;

def do_visualizeddraw text t =
  draworigin              ;
  drawpath          _c_ t ;
  drawcontrollines  _c_ ;
  drawcontrolpoints _c_ ;
  drawpoints        _c_ ;
  drawboundingbox   _c_ ;
  drawpointlabels   _c_ ;
enddef ;

def do_visualizedfill text t =
  if cycle _c_ : normalfill _c_ t fi ;
  draworigin            ; 
  drawcontrollines  _c_ ;
  drawcontrolpoints _c_ ;
  drawpoints        _c_ ;
  drawboundingbox   _c_ ;
  drawpointlabels   _c_ ;
enddef ;

def visualizepaths =
  let fill = visualizedfill ;
  let draw = visualizeddraw ;
enddef ;

def naturalizepaths =
  let fill = normalfill ;
  let draw = normaldraw ;
enddef ;

extra_endfig := extra_endfig & " naturalizepaths ; " ;

%D Normally, arrowheads don't scale well. So we provide a 
%D hack. 

boolean autoarrows ; autoarrows := false ; 
numeric ahfactor   ; ahfactor   := 2.5 ; 

def set_ahlength (text t) = 
  ahlength := (ahfactor*pen_size(t)) ; 
enddef ; 

vardef pen_size (text t) = 
  save p ; picture p ; p := nullpicture ; 
  addto p doublepath (top origin -- bot origin) t ; 
  (ypart urcorner p - ypart lrcorner p) 
enddef ; 

%D The next two macros are adapted versions of plain 
%D \METAPOST\ definitions. 

def _finarr text t =
  if autoarrows : set_ahlength (t) fi ;  
  draw               _apth t ;
  filldraw arrowhead _apth t ;
enddef;

def _findarr text t =
  if autoarrows : set_ahlength (t) fi ;  
  draw                   _apth                    t ;
  fill arrowhead         _apth withpen currentpen t ;
  fill arrowhead reverse _apth withpen currentpen t ;
enddef ;

%D Handy too ...... 

vardef pointarrow (expr pat, loc, len, off) =
  save l, r, s, t ; path l, r ; numeric s ; pair t ;  
  t := if pair loc : loc else : point loc along pat fi ; 
% draw t withpen pencircle scaled 10 withcolor .5white ; 
  s := len/2 - off ; if s<=0 : s := 0 elseif s>len : s := len fi ;  
  r := pat cutbefore t ;
  r := (r cutafter point (arctime s of r) of r) ;
  s := len/2 + off ; if s<=0 : s := 0 elseif s>len : s := len fi ;  
  l := reverse (pat cutafter t) ;
  l := (reverse (l cutafter point (arctime s of l) of l)) ;
  (l..r) 
enddef ; 

def rightarrow  (expr pat,tim,len) = pointarrow(pat,tim,len,-len) enddef ; 
def leftarrow   (expr pat,tim,len) = pointarrow(pat,tim,len,+len) enddef ; 
def centerarrow (expr pat,tim,len) = pointarrow(pat,tim,len,   0) enddef ;

%D The \type {along} and \type {on} operators can be used 
%D as follows: 
%D
%D \starttypen
%D drawdot point .5  along somepath ; 
%D drawdot point 3cm on    somepath ; 
%D \stoptypen
%D 
%D The number denotes a percentage (fraction). 

primarydef pct along pat = % also negative 
  (arctime (pct * (arclength pat)) of pat) of pat  
enddef ;   

% primarydef len on pat =
%   (arctime len of pat) of pat
% enddef ;   

primarydef len on pat =
  (arctime if len>0 : len else : (arclength(pat)+len) fi of pat) of pat 
enddef ;   

% this cuts of a piece from both ends 

tertiarydef pat cutends len =
  begingroup ; save tap ; path tap ; 
  tap := pat cutbefore (point len on pat) ; 
  (tap cutafter (point -len on tap))  
  endgroup 
enddef ;   

%D To be documented. 

path freesquare ; 

freesquare := ((-1,0)--(-1,-1)--(0,-1)--(+1,-1)--
               (+1,0)--(+1,+1)--(0,+1)--(-1,+1)--cycle) scaled .5 ;

numeric freelabeloffset  ; freelabeloffset  := 3pt ; 
numeric freedotlabelsize ; freedotlabelsize := 3pt ; 

vardef thefreelabel (expr str, loc, ori) = 
  save s, p, q, l ; picture s ; path p, q ; pair l ; 
  interim labeloffset := freelabeloffset ; 
  s := if string str : thelabel(str,loc) else : str shifted -center str shifted loc fi ;
  setbounds s to boundingbox s enlarged freelabeloffset ; 
  p := fullcircle scaled (2*length(loc-ori)) shifted ori ;
  q := freesquare xyscaled (urcorner s - llcorner s) ;
%  l := point (xpart (p intersectiontimes (ori--loc))) of q ;
  l := point xpart (p intersectiontimes 
   (ori--((1+eps)*arclength(ori--loc)*unitvector(loc-ori)))) of q ;
  setbounds s to boundingbox s enlarged -freelabeloffset ; % new  
 %draw boundingbox s shifted -l withpen pencircle scaled .5pt withcolor red ; 
  (s shifted -l) 
enddef ; 

% better? 

vardef thefreelabel (expr str, loc, ori) =
  save s, p, q, l ; picture s ; path p, q ; pair l ;
  interim labeloffset := freelabeloffset ;
  s := if string str : thelabel(str,loc) else : str shifted -center str shifted loc fi ;
  setbounds s to boundingbox s enlarged freelabeloffset ;
  p := fullcircle scaled (2*length(loc-ori)) shifted ori ;
  q := freesquare xyscaled (urcorner s - llcorner s) ;
  l := point xpart (p intersectiontimes (ori--loc shifted (loc-ori))) of q ;
  setbounds s to boundingbox s enlarged -freelabeloffset ; % new
  draw boundingbox s shifted -l withpen pencircle scaled .5pt withcolor red ;
  (s shifted -l)
enddef ;

vardef freelabel (expr str, loc, ori) = 
  draw thefreelabel(str,loc,ori) ;
enddef ; 

vardef freedotlabel (expr str, loc, ori) = 
  interim linecap:=rounded ;
  draw loc withpen pencircle scaled freedotlabelsize ;
  draw thefreelabel(str,loc,ori) ;
enddef ; 

%D \starttypen
%D drawarrow anglebetween(line_a,line_b,somelabel) ;
%D \stoptypen

%       angleoffset ; angleoffset :=  0pt ;
numeric anglelength ; anglelength := 20pt ;
numeric anglemethod ; anglemethod :=    1 ;

% vardef anglebetween (expr a, b, str) = % path path string 
%   save pointa, pointb, common, middle, offset ;
%   pair pointa, pointb, common, middle, offset ;
%   save curve ; path curve ; 
%   save where ; numeric where ; 
%   if round point 0 of a = round point 0 of b : 
%     common := point 0 of a ;
%   else :
%     common := a intersectionpoint b ;
%   fi ; 
%   pointa := point anglelength on a ; 
%   pointb := point anglelength on b ; 
%   where  := turningnumber (common--pointa--pointb--cycle) ; 
%   middle := ((common--pointa) rotatedaround (pointa,-where*90))
%                             intersectionpoint 
%             ((common--pointb) rotatedaround (pointb, where*90)) ;  
%   if     anglemethod = 0 :
%     curve  := pointa{unitvector(middle-pointa)}.. pointb; 
%     middle := point .5 along curve ; 
%     curve  := common ;  
%   elseif anglemethod = 1 :  
%     curve  := pointa{unitvector(middle-pointa)}.. pointb; 
%     middle := point .5 along curve ; 
%   elseif anglemethod = 2 :  
%     middle := common rotatedaround(.5[pointa,pointb],180) ; 
%     curve  := pointa--middle--pointb ; 
%   elseif anglemethod = 3 :    
%     curve  := pointa--middle--pointb ; 
%   elseif anglemethod = 4 :    
%     curve  := pointa..controls middle..pointb ; 
%     middle := point .5 along curve ; 
%   fi ; 
%   draw thefreelabel(str, middle, common) withcolor black ;
%   curve
% enddef ;

vardef anglebetween (expr a, b, str) = % path path string
  save pointa, pointb, common, middle, offset ;
  pair pointa, pointb, common, middle, offset ;
  save curve ; path curve ;
  save where ; numeric where ;
  if round point 0 of a = round point 0 of b :
    common := point 0 of a ;
  else :
    common := a intersectionpoint b ;
  fi ;
  pointa := point anglelength on a ;
  pointb := point anglelength on b ;
  where  := turningnumber (common--pointa--pointb--cycle) ;
  middle := (reverse(common--pointa) rotatedaround (pointa,-where*90))
                            intersection_point
            (reverse(common--pointb) rotatedaround (pointb, where*90)) ;
  if not intersection_found :
    middle := point .5 along
      ((reverse(common--pointa) rotatedaround (pointa,-where*90)) --
       (       (common--pointb) rotatedaround (pointb, where*90))) ;
  fi ;
  if     anglemethod = 0 :
    curve  := pointa{unitvector(middle-pointa)}.. pointb;
    middle := point .5 along curve ;
    curve  := common ;
  elseif anglemethod = 1 :
    curve  := pointa{unitvector(middle-pointa)}.. pointb;
    middle := point .5 along curve ;
  elseif anglemethod = 2 :
    middle := common rotatedaround(.5[pointa,pointb],180) ;
    curve  := pointa--middle--pointb ;
  elseif anglemethod = 3 :
    curve  := pointa--middle--pointb ;
  elseif anglemethod = 4 :
    curve  := pointa..controls middle..pointb ;
    middle := point .5 along curve ;
  fi ;
  draw thefreelabel(str, middle, common) withcolor black ;
  curve
enddef ;



% Stack

picture currentpicturestack[] ; 
numeric currentpicturedepth ; currentpicturedepth := 0 ; 

def pushcurrentpicture = 
  currentpicturedepth := currentpicturedepth + 1 ; 
  currentpicturestack[currentpicturedepth] := currentpicture ; 
  currentpicture := nullpicture ; 
enddef ;

def popcurrentpicture = 
  if currentpicturedepth > 0 : 
    addto currentpicturestack[currentpicturedepth] also currentpicture ;
    currentpicture := currentpicturestack[currentpicturedepth] ;
    currentpicturedepth := currentpicturedepth - 1 ; 
  fi ;
enddef ;

%D colorcircle(size, red, green, blue) ; 

% vardef colorcircle (expr size, red, green, blue) = 
%   save r, g, b, rr, gg, bb, cc, mm, yy ; save radius ;
%   path r, g, b, rr, bb, gg, cc, mm, yy ; numeric radius ; 
% 
%   radius := 5cm ; pickup pencircle scaled (radius/25) ; 
% 
%   r := g := b := fullcircle scaled radius shifted (0,radius/4) ;
% 
%   r := r rotatedaround (origin, 15) ; 
%   g := g rotatedaround (origin,135) ; 
%   b := b rotatedaround (origin,255) ; 
% 
%   r := r rotatedaround(center r,-90) ; 
%   g := g rotatedaround(center g, 90) ; 
% 
%   gg := buildcycle(buildcycle(reverse r,b),g) ; 
%   cc := buildcycle(buildcycle(b,reverse g),r) ; 
% 
%   rr := gg rotatedaround(origin,120) ; 
%   bb := gg rotatedaround(origin,240) ; 
% 
%   yy := cc rotatedaround(origin,120) ; 
%   mm := cc rotatedaround(origin,240) ; 
% 
%   pushcurrentpicture ; 
% 
%   fill fullcircle scaled radius withcolor white ;
% 
%   fill rr withcolor red   ; fill cc withcolor white-red   ; 
%   fill gg withcolor green ; fill mm withcolor white-green ; 
%   fill bb withcolor blue  ; fill yy withcolor white-blue  ; 
% 
%   for i = rr,gg,bb,cc,mm,yy : draw i withcolor .5white ; endfor ;   
% 
%   currentpicture := currentpicture xsized size ; 
% 
%   popcurrentpicture ;
% enddef ;   

% vardef colorcircle (expr size, red, green, blue) = 
%   save r, g, b, rr, gg, bb, cc, mm, yy ; save radius ;
%   path r, g, b, rr, bb, gg, cc, mm, yy ; numeric radius ; 
% 
%   radius := 5cm ; pickup pencircle scaled (radius/25) ; 
% 
%   transform t ; t := identity rotatedaround(origin,120) ; 
% 
%   r := fullcircle scaled radius 
%    shifted (0,radius/4) rotatedaround(origin,15) ; 
% 
%   g := r transformed t ; b := g transformed t ; 
% 
%   r := r rotatedaround(center r,-90) ; 
%   g := g rotatedaround(center g, 90) ; 
% 
%   gg := buildcycle(buildcycle(reverse r,b),g) ; 
%   cc := buildcycle(buildcycle(b,reverse g),r) ; 
% 
%   rr := gg transformed t ; bb := rr transformed t ; 
%   yy := cc transformed t ; mm := yy transformed t ; 
% 
%   pushcurrentpicture ; 
% 
%   fill fullcircle scaled radius withcolor white ;
% 
%   fill rr withcolor red   ; fill cc withcolor white-red   ; 
%   fill gg withcolor green ; fill mm withcolor white-green ; 
%   fill bb withcolor blue  ; fill yy withcolor white-blue  ; 
% 
%   for i = rr,gg,bb,cc,mm,yy : draw i withcolor .5white ; endfor ;   
% 
%   currentpicture := currentpicture xsized size ; 
% 
%   popcurrentpicture ;
% enddef ;   

vardef colorcircle (expr size, red, green, blue) = 
  save r, g, b, c, m, y, w ; save radius ; 
  path r, g, b, c, m, y, w ; numeric radius ; 

  radius := 5cm ; pickup pencircle scaled (radius/25) ; 

  transform t ; t := identity rotatedaround(origin,120) ; 

  r := fullcircle rotated 90 scaled radius 
         shifted (0,radius/4) rotatedaround(origin,135) ; 

  b := r transformed t ; g := b transformed t ; 

  c := buildcycle(subpath(1,7) of g,subpath(1,7) of b) ;  
  y := c transformed t ; m := y transformed t ; 

  w := buildcycle(subpath(3,5) of r, subpath(3,5) of g,subpath(3,5) of b) ;  

  pushcurrentpicture ;

  fill r withcolor red   ; 
  fill g withcolor green ; 
  fill b withcolor blue  ; 
  fill c withcolor white-red   ; 
  fill m withcolor white-green ; 
  fill y withcolor white-blue  ; 
  fill w withcolor white ; 

  for i = r,g,b,c,m,y : draw i withcolor .5white ; endfor ;   

  currentpicture := currentpicture xsized size ; 

  popcurrentpicture ;
enddef ;   

% penpoint (i,2) of somepath -> inner / outer point 

vardef penpoint expr pnt of p = 
  save n, d ; numeric n, d ; 
  (n,d) = if pair pnt : pnt else : (pnt,1) fi ; 
  (point n of p shifted ((penoffset direction n of p of currentpen) scaled d))
enddef ;

% nice: currentpicture := inverted currentpicture ;  

vardef inverted expr p = 
  save pp ; picture pp ; pp := nullpicture ; 
  for i within p : 
    addto pp 
    if stroked i or filled i : 
      if filled i : contour else : doublepath fi pathpart i  
      dashed dashpart i withpen penpart i 
    else : 
      also i  
    fi  
    withcolor white-(redpart i, greenpart i, bluepart i) ;    
  endfor ; 
  pp 
enddef ; 

% yes or no: "text" infont "cmr12" at 24pt ; 

% let normalinfont = infont ;
% 
% numeric lastfontsize ; lastfontsize = fontsize defaultfont ;  
% 
% def infont primary name =  % no vardef, no expr 
%   hide(lastfontsize := fontsize name) % no ; 
%   normalinfont name 
% enddef ; 
% 
% def scaledat expr size =  
%   scaled (size/lastfontsize)  
% enddef ; 
% 
% let at = scaledat ; 

% like decimal

def condition primary b = if b : "true" else : "false" fi enddef ; 

% undocumented

primarydef p stretched s = 
  begingroup
  save pp ; path pp ; pp := p scaled s ;
  (pp shifted ((point 0 of p) - (point 0 of pp)))  
  endgroup
enddef ; 

% yes or no, untested -) 

def xshifted expr dx = shifted(dx,0) enddef ;  
def yshifted expr dy = shifted(0,dy) enddef ;  

% also handy 

% right: str = readfrom ("abc" & ".def" ) ; 
% wrong: str = readfrom  "abc" & ".def"   ;

def readfile (expr name) = 
  if (readfrom (name) <> EOF) : 
    scantokens("input " & name & " ") 
  fi  
enddef ; 

% permits redefinition of end in macro 

inner end ; 

% real fun

color color_map[][][] ;

%color_map_resolution := 1000 ;
%
%def r_color primary c = round(color_map_resolution*redpart   c) enddef ;
%def g_color primary c = round(color_map_resolution*greenpart c) enddef ;
%def b_color primary c = round(color_map_resolution*bluepart  c) enddef ;

def r_color primary c = redpart   c enddef ;
def g_color primary c = greenpart c enddef ;
def b_color primary c = bluepart  c enddef ;

def remapcolor(expr old, new) =
  color_map[r_color old][g_color old][b_color old] := new ;
enddef ;

def remappedcolor(expr c) =
  if known color_map[r_color c][g_color c][b_color c] :
    color_map[r_color c][g_color c][b_color c]
  else :
    c
  fi
enddef ;

let normalwithcolor = withcolor ;

def remapcolors =
  def withcolor primary c = normalwithcolor remappedcolor(c) enddef ;
enddef ;

def normalcolors =
  let withcolor = normalwithcolor ;
enddef ;

def refill  suffix c = do_repath (1) (c) enddef ;
def redraw  suffix c = do_repath (2) (c) enddef ;
def recolor suffix c = do_repath (0) (c) enddef ;

def do_repath (expr mode) (suffix c) text t =
  begingroup ;
  if mode=0 : save withcolor ; remapcolors ; fi ; 
  save _c_, _f_, _b_ ; picture _c_ ; color _f_ ; path _b_ ; 
  _c_ := c ; _b_ := boundingbox c ; c := nullpicture ; 
  for i within _c_ : 
    _f_ := (redpart i, greenpart i, bluepart i) ;
    if     bounded i : 
      setbounds c to pathpart i ; 
    elseif clipped i : 
      clip c to pathpart i ; 
    elseif stroked i : 
      addto c doublepath pathpart i 
        dashed dashpart i withpen penpart i 
        withcolor (redpart i, greenpart i, bluepart i) 
        if mode=2 : t fi ;
    elseif filled  i : 
      addto c contour pathpart i 
      withcolor (redpart i, greenpart i, bluepart i) 
      if mode=1 : t if _f_ = background : withcolor background fi fi ;
    fi ;
  endfor ;   
  setbounds c to _b_ ; 
  endgroup ; 
enddef ; 

% After a question of Denis on how to erase a z variable, Jacko 
% suggested to assign whatever to x and y. So a clearz 
% variable can be defined as: 
%
% vardef clearz@# = 
%   x@# := whatever ; 
%   y@# := whatever ; 
% enddef ; 
%
% but Jacko suggested a redefinition of clearxy: 
%
% def clearxy text s =
%  clearxy_index_:=0; 
%  for $:=s: 
%    clearxy_index_:=clearxy_index_+1; endfor;
%  if clearxy_index_=0: 
%    save x,y;
%  else: 
%    forsuffixes $:=s: x$:=whatever; y$:=whatever; endfor;
%  fi
% enddef;
%
% which i decided to simplify to: 

def clearxy text s =
  if false for $ := s : or true endfor : 
    forsuffixes $ := s : x$ := whatever ; y$ := whatever ; endfor ;
  else : 
    save x, y ;
  fi
enddef ;

% so now we can say: clearxy ; as well as clearxy 1, 2, 3 ; 

% show x0 ; z0 = (10,10) ; 
% show x0 ; x0 := whatever ; y0 := whatever ; 
% show x0 ; z0 = (20,20) ;
% show x0 ; clearxy 0 ; 
% show x0 ; z0 = (30,30) ;

primarydef p smoothed d =
  (p llmoved (-xpart paired(d),0) -- p lrmoved (-xpart paired(d),0) {right} .. 
   p lrmoved (0,-ypart paired(d)) -- p urmoved (0,-ypart paired(d)) {up}    .. 
   p urmoved (-xpart paired(d),0) -- p ulmoved (-xpart paired(d),0) {left}  ..
   p ulmoved (0,-ypart paired(d)) -- p llmoved (0,-ypart paired(d)) {down}  .. cycle) 
enddef ;

primarydef p cornered c = 
  ((point 0 of p) shifted (c*(unitvector(point 1 of p - point 0 of p))) -- 
   for i=1 upto length(p) :
     (point i-1 of p) shifted (c*(unitvector(point i   of p - point i-1 of p))) -- 
     (point i   of p) shifted (c*(unitvector(point i-1 of p - point i   of p))) ..
     controls point i of p .. 
   endfor cycle) 
enddef ;

% cmyk color support 

vardef cmyk(expr c,m,y,k) =
  (1-c-k,1-m-k,1-y-k)
enddef ;

% done 

endinput ;
