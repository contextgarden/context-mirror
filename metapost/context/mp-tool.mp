%D \module
%D   [       file=mp-tool.mp,
%D        version=1998.02.15,
%D          title=PRAGMA graphics,
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

if known stripe_angle: endinput ; fi ; 

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

vardef set_inner_boundingbox text q = 
  setbounds q to inner_boundingbox q;
enddef;

vardef set_outer_boundingbox text q = 
  setbounds q to outer_boundingbox q;
enddef;

%D Some missing functions can be implemented rather 
%D straightforward:

def tand (expr x) = (sind(x)/cosd(x))                enddef;
def sqr  (expr x) = (x*x)                            enddef;
def ln   (expr x) = (if x=0: 0 else: mlog(x)/256 fi) enddef;
def exp  (expr x) = ((mexp 256)**x)                  enddef;
def pow  (expr x) = (x**power)                       enddef;
def inv  (expr x) = (if x=0: 0 else: x**-1 fi)       enddef;
def asin (expr x) = (x+(x**3)/6+3(x**5)/40)          enddef;
def acos (expr x) = (asin(-x))                       enddef;
def atan (expr x) = (x-(x**3)/3+(x**5)/5-(x**7)/7)   enddef;

%D We provide two macros for drawing striped across a shape.
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
  save curpic, newpic, pp; 
  picture curpic, newpic;
  path pp; 
  pp := s_path;
  curpic := currentpicture;
  currentpicture := nullpicture;
  draw pp s_text; 
  s_max := max
   (xpart llcorner currentpicture, xpart urcorner currentpicture,
    ypart llcorner currentpicture, ypart urcorner currentpicture);
  newpic := currentpicture;
  currentpicture := nullpicture;
  for i=-s_max-.5stripe_gap step stripe_gap until s_max:  
    draw (-s_max,i)--(s_max,i) s_spec;
  endfor;
  currentpicture := currentpicture 
    rotatedaround(center newpic, stripe_angle);
  clip currentpicture to pp;
  addto newpic also currentpicture;
  currentpicture := curpic;
  addto currentpicture also newpic;
  endgroup 
enddef;

%D A few normalizing macros:
%D
%D \starttypen
%D xscale_currentpicture ( width )
%D yscale_currentpicture ( height )
%D scale_currentpicture  ( width, height )
%D \stoptypen

def xscale_currentpicture(expr the_width) =  
  natural_width  := xpart urcorner currentpicture - xpart llcorner currentpicture; 
  currentpicture := currentpicture scaled (the_width/natural_width) ;
enddef;

def yscale_currentpicture(expr the_height ) =  
  natural_height := ypart urcorner currentpicture - ypart llcorner currentpicture; 
  currentpicture := currentpicture scaled (the_height/natural_height) ;
enddef;

def scale_currentpicture(expr the_width, the_height) =  
  xscale_currentpicture(the_width) ;  
  yscale_currentpicture(the_height) ;  
enddef;

%D A full circle is centered at the origin, while a unitsquare 
%D is located in the first quadrant. Now guess what kind of 
%D path fullsquare and unitcircle do return. 

def fullsquare = (unitsquare shifted - center unitsquare) enddef ; 
def unitcircle = (fullcircle shifted urcorner fullcircle) enddef ; 

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

%D Some colors.

color cyan    ; cyan    = (0,1,1) ;
color yellow  ; yellow  = (1,1,0) ;
color magenta ; magenta = (1,0,1) ;

endinput ;
