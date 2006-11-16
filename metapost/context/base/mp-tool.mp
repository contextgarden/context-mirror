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

% a cleanup is needed, like using image and alike
% use a few more "newinternal"'s

%D This module is rather preliminary and subjected to
%D changes.

if known context_tool : endinput ; fi ;

boolean context_tool ; context_tool := true ;

%D New, version number testing:
%D
%D \starttyping
%D fill fullcircle scaled 2cm withcolor if mpversiongt("0.6") : red  else : green fi ;
%D fill fullcircle scaled 1cm withcolor if mpversionlt(0.6)   : blue else : white fi ;
%D \stoptyping

if not known mpversion : string mpversion ; mpversion := "0.641" ; fi ;

% vardef mpversiongt(expr s) =
%     scantokens (mpversion & " > " & if numeric s : decimal s else : s fi)
% enddef ;
% vardef mpversionlt(expr s) =
%     scantokens (mpversion & " < " & if numeric s : decimal s else : s fi)
% enddef ;
% vardef mpversioneq(expr s) =
%     scantokens (mpversion & " = " & if numeric s : decimal s else : s fi)
% enddef ;

%D More interesting:
%D
%D \starttyping
%D fill fullcircle scaled 4cm withcolor if mpversiongt("0.6")     : red    else : green fi ;
%D fill fullcircle scaled 2cm withcolor if mpversionlt(0.6)       : blue   else : white fi ;
%D fill fullcircle scaled 1cm withcolor if mpversioncmp(0.6,">=") : yellow else : black fi ;
%D \stoptyping

vardef mpversioncmp(expr s, c) =
    scantokens (mpversion & c & if numeric s : decimal s else : s fi)
enddef ;

vardef mpversionlt (expr s) = mpversioncmp(s, "<") enddef ;
vardef mpversioneq (expr s) = mpversioncmp(s, "=") enddef ;
vardef mpversiongt (expr s) = mpversioncmp(s, ">") enddef ;

%D We always want \EPS\ conforming output, so we say:

prologues    := 1 ;
warningcheck := 0 ;
mpprocset    := 1 ;

%D Namespace handling:

% let exclamationmark = ! ;
% let questionmark    = ? ;
%
% def unprotect =
%   let ! = relax ;
%   let ? = relax ;
% enddef ;
%
% def protect =
%   let ! = exclamationmark ;
%   let ? = questionmark ;
% enddef ;
%
% unprotect ;
%
% mp!some!module = 10 ; show mp!some!module ; show somemodule ;
%
% protect ;

%D A semicolor to be used in specials: ? ? ?

string semicolor ; semicolor := char 59 ;

%D By including this module, \METAPOST\ automatically writes a
%D high resolution boundingbox to the \POSTSCRIPT\ file. This
%D hack is due to John Hobby himself.

% When somehow the first one gets no HiRes, then make sure
% that the format matches the mem sizes in the config file.

% eerste " " er uit

string space ; space = char 32 ;

vardef ddecimal primary p =
  decimal xpart p & " " & decimal ypart p
enddef ;

extra_endfig := extra_endfig
  & "special "
       & "("
       & ditto
       & "%%HiResBoundingBox: "
       & ditto
       & "&ddecimal llcorner currentpicture"
       & "&space"
       & "&ddecimal urcorner currentpicture"
       & ");";

%D Also handy (when we flush colors):

vardef dddecimal primary c =
  decimal redpart c & " " & decimal greenpart c & " " & decimal bluepart  c
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
  if (path p) or (picture p) :
    llcorner p -- lrcorner p -- urcorner p -- ulcorner p
  else :
    origin
  fi -- cycle
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

numeric Pi ; Pi := 3.1415926 ;

vardef sqr  primary x = (x*x)                                 enddef ;
vardef log  primary x = (if x=0: 0 else: mlog(x)/mlog(10) fi) enddef ;
vardef ln   primary x = (if x=0: 0 else: mlog(x)/256 fi)      enddef ;
vardef exp  primary x = ((mexp 256)**x)                       enddef ;
vardef inv  primary x = (if x=0: 0 else: x**-1 fi)            enddef ;

vardef pow (expr x,p) = (x**p)                              enddef ;

vardef asin primary x = (x+(x**3)/6+3(x**5)/40)               enddef ;
vardef acos primary x = (asin(-x))                            enddef ;
vardef atan primary x = (x-(x**3)/3+(x**5)/5-(x**7)/7)        enddef ;
vardef tand primary x = (sind(x)/cosd(x))                     enddef ;

%D Here are Taco Hoekwater's alternatives (but
%D vardef'd and primaried).

pi := 3.1415926 ; radian := 180/pi ; % 2pi*radian = 360 ;

vardef tand   primary x = (sind(x)/cosd(x))  enddef ;
vardef cotd   primary x = (cosd(x)/sind(x))  enddef ;

vardef sin    primary x = (sind(x*radian))   enddef ;
vardef cos    primary x = (cosd(x*radian))   enddef ;
vardef tan    primary x = (sin(x)/cos(x))    enddef ;
vardef cot    primary x = (cos(x)/sin(x))    enddef ;

vardef asin   primary x = angle((1+-+x,x))   enddef ;
vardef acos   primary x = angle((x,1+-+x))   enddef ;

vardef invsin primary x = ((asin(x))/radian) enddef ;
vardef invcos primary x = ((acos(x))/radian) enddef ;

vardef acosh  primary x = ln(x+(x+-+1))      enddef ;
vardef asinh  primary x = ln(x+(x++1))       enddef ;

vardef sinh   primary x = save xx ; xx = exp x ; (xx-1/xx)/2 enddef ;
vardef cosh   primary x = save xx ; xx = exp x ; (xx+1/xx)/2 enddef ;

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
  (p if (bbwidth (p)>0) and (w>0) : scaled (w/bbwidth (p)) fi)
enddef ;

primarydef p ysized h =
  (p if (bbheight(p)>0) and (h>0) : scaled (h/bbheight(p)) fi)
enddef ;

primarydef p xysized s =
  begingroup ;
    save wh, w, h ; pair wh ; numeric w, h ;
    wh := paired (s) ; w := bbwidth(p) ; h := bbheight(p) ;
    (p if (w>0) and (h>0) :
         if xpart wh > 0 : xscaled (xpart wh/w) fi
         if ypart wh > 0 : yscaled (ypart wh/h) fi
       fi)
  endgroup
enddef ;

primarydef p sized wh =
  (p xysized wh)
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

%D More robust:

% let  normalscaled =  scaled ;
% let normalxscaled = xscaled ;
% let normalyscaled = yscaled ;
%
% def  scaled expr s =  normalscaled (s) enddef ;
% def xscaled expr s = normalxscaled (s) enddef ;
% def yscaled expr s = normalyscaled (s) enddef ;

%D Shorter

primarydef p xyscaled q =
  begingroup ; save qq ; pair qq ; qq = paired(q) ;
    ( p
      if xpart qq<>0 : xscaled (xpart qq) fi
      if ypart qq<>0 : yscaled (ypart qq) fi )
  endgroup
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

vardef tripled (expr d) =
  if color d : d else : (d,d,d) fi
enddef ;

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

primarydef p leftenlarged d =
  ((llcorner p) shifted (-d,0) -- lrcorner p --
   urcorner p -- (ulcorner p) shifted (-d,0) -- cycle)
enddef ;

primarydef p rightenlarged d =
  (llcorner p -- (lrcorner p) shifted (d,0) --
   (urcorner p) shifted (d,0) -- ulcorner p -- cycle)
enddef ;

primarydef p topenlarged d =
  (llcorner p -- lrcorner p --
   (urcorner p) shifted (0,d) -- (ulcorner p) shifted (0,d) -- cycle)
enddef ;

primarydef p bottomenlarged d =
  (llcorner p shifted (0,-d) -- lrcorner p shifted (0,-d) --
   urcorner p -- ulcorner p -- cycle)
enddef ;

%D Handy for testing/debugging:

primarydef p crossed d =
  (center p shifted (-d, 0) -- llcorner p --
   center p shifted ( 0,-d) -- lrcorner p --
   center p shifted (+d, 0) -- urcorner p --
   center p shifted ( 0,+d) -- ulcorner p -- cycle)
enddef ;

%D Saves typing:

% vardef bottomboundary primary p = (llcorner p -- lrcorner p) enddef ;
% vardef rightboundary  primary p = (lrcorner p -- urcorner p) enddef ;
% vardef topboundary    primary p = (urcorner p -- ulcorner p) enddef ;
% vardef leftboundary   primary p = (ulcorner p -- llcorner p) enddef ;

vardef bottomboundary primary p =
  if pair p : p else : (llcorner p -- lrcorner p) fi
enddef ;

vardef rightboundary  primary p =
  if pair p : p else : (lrcorner p -- urcorner p) fi
enddef ;

vardef topboundary    primary p =
  if pair p : p else : (urcorner p -- ulcorner p) fi
enddef ;

vardef leftboundary   primary p =
  if pair p : p else : (ulcorner p -- llcorner p) fi
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
  elseif color p :
    if color s :
      (uniformdeviate redpart   s * redpart   p,
       uniformdeviate greenpart s * greenpart p,
       uniformdeviate bluepart  s * bluepart  p)
    elseif pair s :
      ((xpart s + uniformdeviate (ypart s - xpart s)) * p)
    else :
      (uniformdeviate s * p)
    fi
  else :
    p + uniformdeviate s
  fi)
enddef ;

%D Not perfect (alternative for interpath)

vardef interpolated(expr s, p, q) =
  save m ; m := max(length(p),length(q)) ;
  (if path p :
     for i=0 upto m-1 :
       s[point       (i   /m) along p,
         point       (i   /m) along q] .. controls
       s[postcontrol (i   /m) along p,
         postcontrol (i   /m) along q] and
       s[precontrol ((i+1)/m) along p,
         precontrol ((i+1)/m) along q] ..
     endfor
     if cycle p :
       cycle
     else :
       s[point infinity of p,
         point infinity of q]
     fi
   else :
     a[p,q]
   fi)
enddef ;

%D Interesting too:

% primarydef p parallel s =
%   begingroup ; save q, b ; path q ; numeric b ;
%   b := xpart (lrcorner p - llcorner p) ;
%   q := p if b>0 : scaled ((b+2s)/b) fi ;
%   (q shifted (center p-center q))
%   endgroup
% enddef ;

%primarydef p parallel s =
%  begingroup ; save q, w,h ; path q ; numeric w, h ;
%  w := bbwidth(p) ; h := bbheight(p) ;
%  q := p if (w>0) and (h>0) :
%    xyscaled ((w+2*xpart paired(s))/w,(h+2*ypart paired(s))/h) fi ;
%  (q shifted (center p-center q))
%  endgroup
%enddef ;

vardef punked primary p =
  (point 0 of p for i=1 upto length(p)-1 : -- point i of p endfor
   if cycle p : -- cycle else : -- point length(p) of p fi)
enddef ;

vardef curved primary p =
  (point 0 of p for i=1 upto length(p)-1 : .. point i of p endfor
   if cycle p : .. cycle else : .. point length(p) of p fi)
enddef ;

primarydef p blownup s =
  begingroup
    save _p_ ; path _p_ ; _p_ := p xysized
     (bbwidth (p)+2(xpart paired(s)),
      bbheight(p)+2(ypart paired(s))) ;
    (_p_ shifted (center p - center _p_))
  endgroup
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

%D Drawoptions

def saveoptions =
  save _op_ ; def _op_ = enddef ;
enddef ;

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

def resetdrawoptions =
  drawlineoptions   (withpen pencircle scaled 1pt   withcolor .5white) ;
  drawpointoptions  (withpen pencircle scaled 4pt   withcolor   black) ;
  drawcontroloptions(withpen pencircle scaled 2.5pt withcolor   black) ;
  drawlabeloptions  () ;
  draworiginoptions (withpen pencircle scaled 1pt   withcolor .5white) ;
  drawboundoptions  (dashed evenly _ori_opt_) ;
  drawpathoptions   (withpen pencircle scaled 5pt   withcolor .8white) ;
enddef ;

resetdrawoptions ;

%D Path.

def drawpath expr p =
  normaldraw p _pth_opt_
enddef ;

%D Arrow.

vardef drawarrowpath expr p =
  save autoarrows ; boolean autoarrows ; autoarrows := true ;
  drawarrow p _pth_opt_
enddef ;

%def drawarrowpath expr p =
%  begingroup ;
%  save autoarrows ; boolean autoarrows ; autoarrows := true ;
%  save arrowpath ; path arrowpath ; arrowpath := p ;
%  _drawarrowpath_
%enddef ;
%
%def _drawarrowpath_ text t =
%  drawarrow arrowpath _pth_opt_ t ;
%  endgroup ;
%enddef ;

def midarrowhead expr p =
  arrowhead p cutafter
    (point length(p cutafter point .5 along p)+ahlength on p)
enddef ;

vardef arrowheadonpath (expr p, s) =
  save autoarrows ; boolean autoarrows ; autoarrows := true ;
  set_ahlength(scaled ahfactor) ; % added
  arrowhead p if s<1 : cutafter (point (s*arclength(p)+.5ahlength) on p) fi
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
% ahlength := (ahfactor*pen_size(_op_ t)) ; % _op_ added
% problem: _op_ can contain color so a no-go, we could apply the transform
% but i need to figure out the best way (fakepicture and take components).
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

% tertiarydef pat cutends len =
%   begingroup ; save tap ; path tap ;
%   tap := pat cutbefore (point len on pat) ;
%   (tap cutafter (point -len on tap))
%   endgroup
% enddef ;

tertiarydef pat cutends len =
  begingroup ; save tap ; path tap ;
  tap := pat cutbefore (point (xpart paired(len)) on pat) ;
  (tap cutafter (point -(ypart paired(len)) on tap))
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
 %draw boundingbox s shifted -l withpen pencircle scaled .5pt withcolor red ;
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
  draw thefreelabel(str, middle, common) ; % withcolor black ;
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

def popcurrentpicture text t = % optional text
  if currentpicturedepth > 0 :
    addto currentpicturestack[currentpicturedepth] also currentpicture t ;
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

  fill r withcolor       red   ;
  fill g withcolor       green ;
  fill b withcolor       blue  ;
  fill c withcolor white-red   ;
  fill m withcolor white-green ;
  fill y withcolor white-blue  ;
  fill w withcolor white       ;

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

primarydef p uncolored c =
  if color p :
    c - p
  else :
      image
        (for i within p :
           addto currentpicture
           if stroked i or filled i :
             if filled i : contour else : doublepath fi pathpart i
             dashed dashpart i withpen penpart i
           else :
             also i
           fi
           withcolor c-(redpart i, greenpart i, bluepart i) ;
         endfor ; )
  fi
enddef ;

vardef inverted primary p =
  (p uncolored white)
enddef ;

% primarydef p softened c =
%   if color p :
%     tripled(c) * p
%   else :
%     image
%       (save cc ; color cc ; cc := tripled(c) ;
%        for i within p :
%          addto currentpicture
%          if stroked i or filled i :
%            if filled i : contour else : doublepath fi pathpart i
%            dashed dashpart i withpen penpart i
%          else :
%           also i
%          fi
%          withcolor (redpart   cc * redpart   i,
%                     greenpart cc * greenpart i,
%                     bluepart  cc * bluepart  i) ;
%        endfor ;)
%   fi
% enddef ;

primarydef p softened c =
  begingroup
  save cc ; color cc ; cc := tripled(c) ;
  if color p :
    (redpart   cc * redpart   p,
     greenpart cc * greenpart p,
     bluepart  cc * bluepart  p)
  else :
    image
      (for i within p :
         addto currentpicture
         if stroked i or filled i :
           if filled i : contour else : doublepath fi pathpart i
           dashed dashpart i withpen penpart i
         else :
          also i
         fi
         withcolor (redpart   cc * redpart   i,
                    greenpart cc * greenpart i,
                    bluepart  cc * bluepart  i) ;
       endfor ;)
  fi
  endgroup
enddef ;

vardef grayed primary p =
  if color p :
    tripled(.30redpart p+.59greenpart p+.11bluepart p)
  else :
    image
      (for i within p :
         addto currentpicture
         if stroked i or filled i :
           if filled i : contour else : doublepath fi pathpart i
           dashed dashpart i withpen penpart i
         else :
           also i
         fi
         withcolor tripled(.30redpart i+.59greenpart i+.11bluepart i) ;
       endfor ; )
  fi
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
% save pp ; path pp ; pp := p scaled s ;
  save pp ; path pp ; pp := p xyscaled s ;
  (pp shifted ((point 0 of p) - (point 0 of pp)))
  endgroup
enddef ;

% yes or no, untested -)

def xshifted expr dx = shifted(dx,0) enddef ;
def yshifted expr dy = shifted(0,dy) enddef ;

% also handy

% right: str = readfrom ("abc" & ".def" ) ;
% wrong: str = readfrom  "abc" & ".def"   ;

% Every 62th read fails so we need to try again!

% def readfile (expr name) =
%   if (readfrom (name) <> EOF) :
%     scantokens("input " & name & ";") ;
%   elseif (readfrom (name) <> EOF) :
%     scantokens("input " & name & ";") ;
%   fi ;
%   closefrom (name) ;
% enddef ;
%
% this sometimes fails on the elseif, so :
%

def readfile (expr name) =
  begingroup ; save ok ; boolean ok ;
  if (readfrom (name) <> EOF) :
    ok := false ;
  elseif (readfrom (name) <> EOF) :
    ok := false ;
  else :
    ok := true ;
  fi ;
  if not ok :
    scantokens("input " & name & " ") ;
  fi ;
  closefrom (name) ;
  endgroup ;
enddef ;

% permits redefinition of end in macro

inner end ;

% real fun

let normalwithcolor = withcolor ;

def remapcolors =
  def withcolor primary c = normalwithcolor remappedcolor(c) enddef ;
enddef ;

def normalcolors =
  let withcolor = normalwithcolor ;
enddef ;

def resetcolormap =
  color color_map[][][] ;
  normalcolors ;
enddef ;

resetcolormap ;

% color_map_resolution := 1000 ;
%
% def r_color primary c = round(color_map_resolution*redpart   c) enddef ;
% def g_color primary c = round(color_map_resolution*greenpart c) enddef ;
% def b_color primary c = round(color_map_resolution*bluepart  c) enddef ;

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

% def refill  suffix c = do_repath (1) (c) enddef ;
% def redraw  suffix c = do_repath (2) (c) enddef ;
% def recolor suffix c = do_repath (0) (c) enddef ;
%
% color refillbackground ; refillbackground := (1,1,1) ;
%
% def do_repath (expr mode) (suffix c) text t = % can it be stroked and filled at the same time ?
%   begingroup ;
%   if mode=0 : save withcolor ; remapcolors ; fi ;
%   save _c_, _cc_, _f_, _b_ ; picture _c_, _cc_ ; color _f_ ; path _b_ ;
%   _c_ := c ; _b_ := boundingbox c ; c := nullpicture ;
%   for i within _c_ :
%     _f_ := (redpart i, greenpart i, bluepart i) ;
%     if     bounded i :
%       setbounds c to pathpart i ;
%     elseif clipped i :
%       clip c to pathpart i ;
%     elseif stroked i :
%       addto c doublepath pathpart i
%         dashed dashpart i withpen penpart i
%         withcolor _f_ % (redpart i, greenpart i, bluepart i)
%         if mode=2 : t fi ;
%     elseif filled  i :
%       addto c contour pathpart i
%         withcolor _f_
%         if (mode=1) and (_f_<>refillbackground) : t fi ;
%     else :
%       addto c also i ;
%     fi ;
%   endfor ;
%   setbounds c to _b_ ;
%   endgroup ;
% enddef ;

% Thanks to Jens-Uwe Morawski for pointing out that we need
% to treat bounded and clipped components as local pictures.

def recolor   suffix p = p := repathed (0,p) enddef ;
def refill    suffix p = p := repathed (1,p) enddef ;
def redraw    suffix p = p := repathed (2,p) enddef ;
def retext    suffix p = p := repathed (3,p) enddef ;
def untext    suffix p = p := repathed (4,p) enddef ;

% primarydef p recolored t = repathed(0,p) t enddef ;
% primarydef p refilled  t = repathed(1,p) t enddef ;
% primarydef p redrawn   t = repathed(2,p) t enddef ;
% primarydef p retexted  t = repathed(3,p) t enddef ;
% primarydef p untexted  t = repathed(4,p) t enddef ;

color refillbackground ; refillbackground := (1,1,1) ;

% vardef repathed (expr mode, p) text t =
%   begingroup ;
%   if mode=0 : save withcolor ; remapcolors ; fi ;
%   save _p_, _pp_, _f_, _b_, _t_ ;
%   picture _p_, _pp_ ; color _f_ ; path _b_ ; transform _t_ ;
%   _b_ := boundingbox p ; _p_ := nullpicture ;
%   for i within p :
%     _f_ := (redpart i, greenpart i, bluepart i) ;
%     if     bounded i :
%       _pp_ := repathed(mode,i) t ;
%       setbounds _pp_ to pathpart i ;
%       addto _p_ also _pp_ ;
%     elseif clipped i :
%       _pp_ := repathed(mode,i) t ;
%       clip _pp_ to pathpart i ;
%       addto _p_ also _pp_ ;
%     elseif stroked i :
%       addto _p_ doublepath pathpart i
%         dashed dashpart i withpen penpart i
%         withcolor _f_ % (redpart i, greenpart i, bluepart i)
%         if mode=2 : t fi ;
%     elseif filled  i :
%       addto _p_ contour pathpart i
%         withcolor _f_
%         if (mode=1) and (_f_<>refillbackground) : t fi ;
%     elseif textual i : % textpart i <> "" :
%       if mode <> 4 :
%         % transform _t_ ;
%         % (xpart _t_, xxpart _t_, xypart _t_)  = (xpart  i, xxpart i, xypart i) ;
%         % (ypart _t_, yypart _t_, yxpart _t_)  = (ypart  i, yypart i, yxpart i) ;
%         % addto _p_ also
%         %   textpart i infont fontpart i % todo : other font
%         %   transformed _t_
%         %   withpen penpart i
%         %   withcolor _f_
%         %   if mode=3 : t fi ;
%         addto _p_ also i if mode=3 : t fi ;
%       fi ;
%     else :
%       addto _p_ also i ;
%     fi ;
%   endfor ;
%   setbounds _p_ to _b_ ;
%   _p_
%   endgroup
% enddef ;

def restroke  suffix p = p := repathed (21,p) enddef ; % keep attributes
def reprocess suffix p = p := repathed (22,p) enddef ; % no attributes

% also 11 and 12

vardef repathed (expr mode, p) text t =
  begingroup ;
  if mode=0 : save withcolor ; remapcolors ; fi ;
  save _p_, _pp_, _ppp_, _f_, _b_, _t_ ;
  picture _p_, _pp_, _ppp_ ; color _f_ ; path _b_ ; transform _t_ ;
  _b_ := boundingbox p ; _p_ := nullpicture ;
  for i within p :
    _f_ := (redpart i, greenpart i, bluepart i) ;
    if     bounded i :
      _pp_ := repathed(mode,i) t ;
      setbounds _pp_ to pathpart i ;
      addto _p_ also _pp_ ;
    elseif clipped i :
      _pp_ := repathed(mode,i) t ;
      clip _pp_ to pathpart i ;
      addto _p_ also _pp_ ;
    elseif stroked i :
      if mode=21 :
        _ppp_ := i ; % indirectness is needed
        addto _p_ also image(scantokens(t & " pathpart _ppp_")
          dashed dashpart i withpen penpart i
          withcolor _f_ ; ) ;
      elseif mode=22 :
        _ppp_ := i ; % indirectness is needed
        addto _p_ also image(scantokens(t & " pathpart _ppp_")) ;
      else :
        addto _p_ doublepath pathpart i
          dashed dashpart i withpen penpart i
          withcolor _f_ % (redpart i, greenpart i, bluepart i)
          if mode=2 : t fi ;
      fi ;
    elseif filled  i :
      if mode=11 :
        _ppp_ := i ; % indirectness is needed
        addto _p_ also image(scantokens(t & " pathpart _ppp_")
          withcolor _f_ ; ) ;
      elseif mode=12 :
        _ppp_ := i ; % indirectness is needed
        addto _p_ also image(scantokens(t & " pathpart _ppp_")) ;
      else :
        addto _p_ contour pathpart i
          withcolor _f_
        if (mode=1) and (_f_<>refillbackground) : t fi ;
      fi ;
    elseif textual i : % textpart i <> "" :
      if mode <> 4 :
        % transform _t_ ;
        % (xpart _t_, xxpart _t_, xypart _t_)  = (xpart  i, xxpart i, xypart i) ;
        % (ypart _t_, yypart _t_, yxpart _t_)  = (ypart  i, yypart i, yxpart i) ;
        % addto _p_ also
        %   textpart i infont fontpart i % todo : other font
        %   transformed _t_
        %   withpen penpart i
        %   withcolor _f_
        %   if mode=3 : t fi ;
        addto _p_ also i if mode=3 : t fi ;
      fi ;
    else :
      addto _p_ also i ;
    fi ;
  endfor ;
  setbounds _p_ to _b_ ;
  _p_
  endgroup
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

% handy

vardef bbwidth  (expr p) =
  (if known p :
     if path p or picture p :
       xpart (lrcorner p - llcorner p)
     else : 0 fi else : 0
   fi )
enddef ;

vardef bbheight (expr p) =
  (if known p : if path p or picture p :
     ypart (urcorner p - lrcorner p)
     else : 0 fi else : 0
   fi)
enddef ;

color nocolor ; numeric noline ; % both unknown signals

def dowithpath (expr p, lw, lc, bc) =
  if known p :
    if known bc :
      fill p withcolor bc ;
    fi ;
    if known lw and known lc :
      draw p withpen pencircle scaled lw withcolor lc ;
    elseif known lw :
      draw p withpen pencircle scaled lw ;
    elseif known lc :
      draw p withcolor lc ;
    fi ;
  fi ;
enddef ;

% result from metafont discussion list (denisr/boguslawj)

def ]]  = ] ] enddef ; def ]]] = ] ] ] enddef ;
def [[  = [ [ enddef ; def [[[ = [ [ [ enddef ;

% not perfect, but useful since it removes redundant points.

% vardef dostraightened(expr sign, p) =
%   if length(p)>2 : % was 1, but straight lines are ok
%     save pp ; path pp ;
%     pp := point 0 of p ;
%     for i=1 upto length(p)-1 :
%       if round(point i of p) <> round(point length(pp) of pp) :
%         pp := pp -- point i of p ;
%       fi ;
%     endfor ;
%     save n, ok ; numeric n ; boolean ok ;
%     n := length(pp) ; ok := false ;
% if n>2 :
%     for i=0 upto n : % evt hier ook round
%      if unitvector(round(point i                        of pp  -
%                    point if i=0 : n else : i-1 fi of pp)) <>
%  sign * unitvector(round(point if i=n : 0 else : i+1 fi of pp  -
%                    point i                        of pp)) :
%         if ok : -- else : ok := true ; fi point i of pp
%       fi
%     endfor
%     if ok and (cycle p) : -- cycle fi
% else :
%   pp
% fi
%   else :
%     p
%   fi
% enddef ;

% vardef simplified expr p =
%   (reverse dostraightened(+1,dostraightened(+1,reverse p)))
% enddef ;

% vardef unspiked   expr p =
%   (reverse dostraightened(-1,dostraightened(-1,reverse p)))
% enddef ;

% simplified : remove same points as well as redundant points
% unspiked   : remove same points as well as areas with zero distance

vardef dostraightened(expr sign, p) =
  save _p_, _q_ ; path _p_, _q_ ;
  _p_ := p ;
  forever :
    _q_ := dodostraightened(sign, _p_) ;
    exitif length(_p_) = length(_q_) ;
    _p_ := _q_ ;
  endfor ;
  _q_
enddef ;

vardef dodostraightened(expr sign, p) =
  if length(p)>2 : % was 1, but straight lines are ok
    save pp ; path pp ;
    pp := point 0 of p ;
    for i=1 upto length(p)-1 :
      if round(point i of p) <> round(point length(pp) of pp) :
        pp := pp -- point i of p ;
      fi ;
    endfor ;
    save n, ok ; numeric n ; boolean ok ;
    n := length(pp) ; ok := false ;
    if n>2 :
      for i=0 upto n : % evt hier ook round
        if unitvector(round(point i                        of pp  -
                            point if i=0 : n else : i-1 fi of pp)) <>
    sign * unitvector(round(point if i=n : 0 else : i+1 fi of pp  -
                            point i                        of pp)) :
          if ok : -- else : ok := true ; fi point i of pp
        fi
      endfor
      if ok and (cycle p) : -- cycle fi
    else :
      pp
    fi
  else :
    p
  fi
enddef ;

% vardef simplified expr p =
%   dostraightened(+1,p)
% enddef ;

% vardef unspiked   expr p =
%   dostraightened(-1,p)
% enddef ;

vardef simplified expr p =
  (reverse dostraightened(+1,dostraightened(+1,reverse p)))
enddef ;

vardef unspiked   expr p =
  (reverse dostraightened(-1,dostraightened(-1,reverse p)))
enddef ;

% path p ;
% p := (2cm,1cm) -- (2cm,1cm) -- (2cm,1cm) -- (3cm,1cm) --
%      (4cm,1cm) -- (4cm,2cm) -- (4cm,2.5cm) -- (4cm,3cm) --
%      (3cm,3cm) -- (2cm,3cm) -- (1cm,3cm) -- (-1cm,3cm) --
%      .5[(-1cm,3cm),(1cm,1cm)] -- (1cm,1cm) -- cycle ;
%
% p := unitcircle scaled 4cm ;
%
% drawpath p ; drawpoints p ; drawpointlabels p ;
% p := p shifted (4cm,0) ; p := straightened p ;
% drawpath p ; drawpoints p ; drawpointlabels p ;
% p := p shifted (4cm,0) ; p := straightened p ;
% drawpath p ; drawpoints p ; drawpointlabels p ;

% new

path originpath ; originpath := origin -- cycle ;

vardef unitvector primary z =
  if abs z = abs origin : z else : z/abs z fi
enddef;

% also new

vardef anchored@#(expr p, z) =
  p shifted (z + (labxf@#*lrcorner p + labyf@#*ulcorner p
       + (1-labxf@#-labyf@#)*llcorner p))
enddef ;

% epsed(1.2345)

vardef epsed (expr e) =
  e if e>0 : + eps elseif e<0 : - eps fi
enddef ;

% handy

def withgray primary g =
  withcolor (g,g,g)
enddef ;

% for metafun

if unknown darkred    : color darkred    ; darkred    := .625(1,0,0) fi ;
if unknown darkyellow : color darkyellow ; darkyellow := .625(1,1,0) fi ;
if unknown darkgray   : color darkgray   ; darkgray   := .625(1,1,1) fi ;
if unknown lightgray  : color lightgray  ; lightgray  := .875(1,1,1) fi ;

% an improved plain mp macro

vardef center primary p =
  if pair p : p else : .5[llcorner p, urcorner p] fi
enddef;

% new, yet undocumented

vardef rangepath (expr p, d, a) =
  (if length p>0 :
     (d*unitvector(direction 0 of p) rotated a)
      shifted point 0 of p
     -- p --
     (d*unitvector(direction length(p) of p) rotated a)
      shifted point length(p) of p
   else :
     p
   fi)
enddef ;

% under construction

vardef straightpath(expr a, b, method) =
  if (method<1) or (method>6)  :
    (a--b)
  elseif method = 1 :
    (a --
     if xpart a > xpart b :
       if ypart a > ypart b :
         (xpart b,ypart a) --
       elseif ypart a < ypart b :
         (xpart a,ypart b) --
       fi
     elseif xpart a < xpart b :
       if ypart a > ypart b :
         (xpart a,ypart b) --
       elseif ypart a < ypart b :
         (xpart b,ypart a) --
        fi
    fi
    b)
  elseif method = 3 :
    (a --
     if xpart a > xpart b :
       (xpart b,ypart a) --
     elseif xpart a < xpart b :
       (xpart a,ypart b) --
     fi
     b)
  elseif method = 5 :
    (a --
     if ypart a > ypart b :
       (xpart b,ypart a) --
     elseif ypart a < ypart b :
     (xpart a,ypart b) --
     fi
     b)
  else :
    (reverse straightpath(b,a,method-1))
  fi
enddef ;

% handy for myself

def addbackground text t =
  begingroup ; save p ; picture p ;
  p := currentpicture ; currentpicture := nullpicture ;
  fill boundingbox p t ; addto currentpicture also p ;
  endgroup ;
enddef ;

% makes a (line) into an infinite one (handy for calculating
% intersection points

vardef infinite expr p =
  (-infinity*unitvector(direction 0 of p)
    shifted point 0 of p
   -- p --
   +infinity*unitvector(direction length(p) of p)
    shifted point length(p) of p)
enddef ;

% obscure macros: create var from string and replace - and :
% (needed for process color id's)

string _clean_ascii_[] ;

def register_dirty_chars(expr str) =
    for i = 0 upto length(str)-1 :
        _clean_ascii_[ASCII substring(i,i+1) of str] := "_" ;
    endfor ;
enddef ;

register_dirty_chars("+-*/:;., ") ;

vardef cleanstring (expr s) =
  save ss ; string ss, si ; ss = "" ; save i ;
  for i=0 upto length(s) :
    si := substring(i,i+1) of s ;
    ss := ss & if known _clean_ascii_[ASCII si] : _clean_ascii_[ASCII si] else : si fi ;
  endfor ;
  ss
enddef ;

vardef asciistring (expr s) =
  save ss ; string ss, si ; ss = "" ; save i ;
  for i=0 upto length(s) :
    si := substring(i,i+1) of s ;
    if (ASCII si >= ASCII "0") and (ASCII si <= ASCII "9") :
        ss := ss & char(scantokens(si) + ASCII "A") ;
    else :
        ss := ss & si ;
    fi ;
  endfor ;
  ss
enddef ;

vardef setunstringed (expr s, v) =
  scantokens(cleanstring(s)) := v ;
enddef ;

vardef setunstringed (expr s, v) =
  scantokens(cleanstring(s)) := v ;
enddef ;

vardef getunstringed (expr s) =
  scantokens(cleanstring(s))
enddef ;

vardef unstringed (expr s) =
  expandafter known scantokens(cleanstring(s))
enddef ;

% new

vardef colorpart(expr i) =
  (redpart i, greenpart i,bluepart i)
enddef ;

% for david arnold:

% showgrid(-5,10,1cm,-10,10,1cm);

def showgrid (expr MinX, MaxX, DeltaX, MinY, MaxY, DeltaY)=
  begingroup
    save defaultfont, defaultscale, size ;
    string  defaultfont  ; defaultfont  := "cmtt10"; % i.e. infofont
    numeric defaultscale ; defaultscale := 8pt / fontsize defaultfont;
    numeric size         ; size         := 2pt ;
    for x=MinX upto MaxX :
      for y=MinY upto MaxY :
    	draw (x*DeltaX, y*DeltaY)
          withpen pencircle scaled
          if (x mod 5 = 0) and (y mod 5 = 0) :
            1.5size withcolor .50white
          else :
               size withcolor .75white
          fi ;
      endfor ;
    endfor ;
    for x=MinX upto MaxX:
      label.bot(decimal x, (x*DeltaX,-size));
    endfor ;
    for y=MinY upto MaxY:
      label.lft(decimal y, (-size,y*DeltaY)) ;
    endfor ;
  endgroup
enddef;

% new, handy for:
%
% \startuseMPgraphic{map}{n}
%   \includeMPgraphic{map:germany} ;
%   c_phantom (\MPvar{n}<1) (
%     fill map_germany withcolor \MPcolor{lightgray} ;
%     draw map_germany withpen pencircle scaled 1pt withcolor \MPcolor{darkgray} ;
%   ) ;
%   \includeMPgraphic{map:austria} ;
%   c_phantom (\MPvar{n}<2) (
%     fill map_austria withcolor \MPcolor{lightgray} ;
%     draw map_austria withpen pencircle scaled 1pt withcolor \MPcolor{darkgray} ;
%   ) ;
%   c_phantom (\MPvar{n}<3) (
%   \includeMPgraphic{map:swiss} ;
%     fill map_swiss withcolor \MPcolor{lightgray} ;
%     draw map_swiss withpen pencircle scaled 1pt withcolor \MPcolor{darkgray}  ;
%   ) ;
%   c_phantom (\MPvar{n}<4) (
%   \includeMPgraphic{map:luxembourg} ;
%     fill map_luxembourg withcolor \MPcolor{lightgray} ;
%     draw map_luxembourg withpen pencircle scaled 1pt withcolor \MPcolor{darkgray}  ;
%   ) ;
% \stopuseMPgraphic
%
% \useMPgraphic{map}{n=3}

vardef phantom (text t) =
   picture _p_ ; _p_ := image(t) ; addto _p_ also currentpicture ;
   setbounds currentpicture to boundingbox _p_ ;
enddef ;

vardef c_phantom (expr b) (text t) =
   if b :
     picture _p_ ; _p_ := image(t) ; addto _p_ also currentpicture ;
     setbounds currentpicture to boundingbox _p_ ;
   else :
     t ;
   fi ;
enddef ;

% mark paths (for external progs to split)

% def somepath(expr p)
%     p
% enddef ;

% done

endinput ;
