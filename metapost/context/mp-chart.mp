%D \module
%D   [       file=mp-chart.mp,
%D        version=1998.10.10,
%D          title=PRAGMA graphics,
%D       subtitle=shapes and charts,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This METAPOST program is copyrighted by Hans Hagen and
%C Ton Otten, Ridderstraat 27, 8061GH Hasselt NL. No part of
%C this program may be used by third parties without
%C explicit permission.

input mp-tool.mp ;

vardef enlarged_path (expr p, w) =              % NAAR mp-tool
  (llcorner p shifted (-w,-w) --
   lrcorner p shifted ( w,-w) --
   urcorner p shifted ( w, w) --
   ulcorner p shifted (-w, w) -- cycle)
enddef;

secondarydef p peepholed q = 
  begingroup ; 
  save start ; pair start ; start := point 0 of p ; 
 %drawdot start scaled_to_grid withpen pencircle scaled 2shape_line_width withcolor red ;
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

current_position := 0 ;

def save_text_position (expr p) =  % beware: clip shift needed
  current_position := current_position + 1 ;
  write
    "\MPposition{" & decimal current_position & "}{"
                   & decimal xpart p          & "}{"
                   & decimal ypart p          & "}"
    to jobname & ".tmp" ;
enddef ;

%D inclusions

input mp-tool ;

%D settings

grid_width   := 60pt ;
grid_height  := 40pt ;

shape_width  := 45pt ;
shape_height := 30pt ;

chart_offset :=  2pt ;

color chart_background_color ; chart_background_color := white ; 

%D test mode

boolean show_mid_points ; show_mid_points := false ;
boolean show_con_points ; show_con_points := false ;
boolean show_all_points ; show_all_points := false ;

%D shapes

color shape_line_color, shape_fill_color ;

shape_line_width := 2pt ;
shape_line_color := .5white ;
shape_fill_color := .9white ;

shape_node           :=  0 ;
shape_action         := 24 ;
shape_procedure      :=  5 ;
shape_product        := 12 ;
shape_decision       := 14 ;
shape_archive        := 19 ;
shape_loop           := 35 ;
shape_wait           :=  6 ;
shape_subprocedure   := 20 ; shape_sub_procedure   := 20 ;
shape_singledocument := 32 ; shape_single_document := 32 ;
shape_multidocument  := 33 ; shape_multi_document  := 33 ;
shape_right          := 66 ;
shape_left           := 67 ;
shape_up             := 68 ;
shape_down           := 69 ;

vardef some_shape (expr type) =

    begingroup ;

    save border, xradius, yradius, 
         normal, mirror, rotate, 
         lc, rc, tc, bc, ll, lr, ur, ul, 
         llx, lrx, urx, ulx, lly, lry, ury, uly ;

    path border ;

    xradius := .15 ; xxradius := .10 ; 
    yradius := .15 ; yyradius := .10 ; 

    pair ll ; ll := llcorner (unitsquare shifted (-.5,-.5)) ;
    pair lr ; lr := lrcorner (unitsquare shifted (-.5,-.5)) ;
    pair ur ; ur := urcorner (unitsquare shifted (-.5,-.5)) ;
    pair ul ; ul := ulcorner (unitsquare shifted (-.5,-.5)) ;

    pair llx ; llx := ll shifted (xradius,0)  ;
    pair lly ; lly := ll shifted (0,yradius)  ;

    pair lrx ; lrx := lr shifted (-xradius,0) ;
    pair lry ; lry := lr shifted (0,yradius)  ;

    pair urx ; urx := ur shifted (-xradius,0) ;
    pair ury ; ury := ur shifted (0,-yradius) ;

    pair ulx ; ulx := ul shifted (xradius,0)  ;
    pair uly ; uly := ul shifted (0,-yradius) ;

    pair llxx ; llxx := ll shifted (xxradius,0)  ;
    pair llyy ; llyy := ll shifted (0,yyradius)  ;

    pair lrxx ; lrxx := lr shifted (-xxradius,0) ;
    pair lryy ; lryy := lr shifted (0,yyradius)  ;

    pair urxx ; urxx := ur shifted (-xxradius,0) ;
    pair uryy ; uryy := ur shifted (0,-yyradius) ;

    pair ulxx ; ulxx := ul shifted (xxradius,0)  ;
    pair ulyy ; ulyy := ul shifted (0,-yyradius) ;

    pair lc  ; lc  := ll shifted (0,.5) ;
    pair rc  ; rc  := lr shifted (0,.5) ;
    pair tc  ; tc  := ul shifted (.5,0) ;
    pair bc  ; bc  := ll shifted (.5,0) ;

    def mirror (expr p) =
      p rotatedaround(origin,180)
    enddef ;

    def normal (expr p ) =
      p
    enddef ;

    def rotate (expr p) = 
      p rotated 45 
    enddef ; 

    if     type= 0 :
      border := normal (origin--cycle) ;

    elseif type= 5 :
      border := normal (llx--lrx{right}...rc...{left}urx--ulx{left}...lc...{right}cycle) ;
    elseif type= 6 :
      border := normal (ll--lrx{right}...rc...{left}urx--ul--cycle) ;
    elseif type= 7 :
      border := mirror (ll--lrx{right}...rc...{left}urx--ul--cycle) ;
    elseif type= 8 :
      border := normal (lr--ury{up}...tc...{down}uly--ll--cycle) ;
    elseif type= 9 :
      border := mirror (lr--ury{up}...tc...{down}uly--ll--cycle) ;
    elseif type=10 :
      border := normal (ll--lr--ur--ul--ll--ur--ul--ll--cycle) ; 
    elseif type=11 :
      border := normal (ll--lr--ur--ul--ll--lr--ul--ll--cycle) ; 
    elseif type=12 :
      border := normal (ll--lrx--ur--ulx--cycle) ;
    elseif type=13 :
      border := normal (llx--lr--urx--ul--cycle) ;
    elseif type=14 :
      border := normal (lly--bc--lry--ury--tc--uly--cycle) ;
    elseif type=15 :
      border := normal (llx--lrx--rc--urx--ulx--lc--cycle) ;
    elseif type=16 :
      border := normal (ll--lrx--rc--urx--ul--cycle) ;
    elseif type=17 :
      border := mirror (ll--lrx--rc--urx--ul--cycle) ;
    elseif type=18 :
      border := normal (lr--ury--tc--uly--ll--cycle) ;
    elseif type=19 :
      border := mirror (lr--ury--tc--uly--ll--cycle) ;
    elseif type=20 :
      border := normal (ll--lr--ur--ul--ll--llxx--ulxx--ul--ll--
                        lr--ur--urxx--lrxx--cycle) ;
    elseif type=21 :
      border := normal (ul--ll--lr--ur--ul--ulyy--uryy--ur--ul--
                        ll--lr--lryy--llyy--cycle) ;
    elseif type=22 :
      border := normal (ll--lrx--lry--ur--ulx--uly--cycle) ;
    elseif type=23 :
      border := normal (llx--lr--ury--urx--ul--lly--cycle) ;
    elseif type=24 :
      border := normal (ll--lr--ur--ul--cycle) ;
    elseif type=25 :
      border := normal (llx--lrx--lry--ury--urx--ulx--uly--lly--cycle) ;
    elseif type=26 :
      border := normal (ll--lrx--lry--ur--ul--cycle) ;
    elseif type=27 :
      border := mirror (ll--lr--ury--urx--ul--cycle) ;
    elseif type=28 :
      border := normal (ll--lr--ury--urx--ul--cycle) ;
    elseif type=29 :
      border := mirror (ll--lrx--lry--ur--ul--cycle) ;
    elseif type=30 :
      border := rotate (bc{right}...{up}rc...tc{left}...{down}lc...{right}bc &
                        bc--tc & tc{left}..{down}lc & lc--rc & 
                        rc{up}..tc{left}...{down}lc...{right}bc & cycle) ;
    elseif type=31 :
      border := normal (bc{right}...{up}rc...tc{left}...{down}lc...{right}bc &
                        bc--tc & tc{left}..{down}lc & lc--rc & 
                        rc{up}..tc{left}...{down}lc...{right}bc & cycle) ;
    elseif type=32 :
      border := normal (ll{right}...{right}lry--ur--ul--ll--cycle) ;
    elseif type=33 :
      border := normal (ll{right}...{right}lry--ur--ul--ll--cycle
                        --ul--ulx--ulx shifted(0,yyradius)
                        --ur shifted(yyradius,yyradius)
                        --lry shifted(yyradius,yyradius)
                        --lry shifted(0,yyradius)
                        --ur--ul--cycle ) ;
    elseif type=34 :
      border := normal (uly..tc..ury & 
                        ury..tc shifted (0,-2yradius)..uly & 
                        uly--lly &
                        lly..bc..lry &
                        lry--ury & 
                        ury..tc shifted (0,-2yradius)..uly & cycle ) ;  
    elseif type=35 :
      border := normal (bc{right}...rc{up}...tc{left}...lc{down}...cycle) ;
    elseif type=36 :
      border := normal (ul--tc{right}..rc{down}..{left}bc--ll & 
                        ll..(xpart llx, ypart lc)..ul & cycle) ;
    elseif type=37 :
      border := mirror (ul--tc{right}..rc{down}..{left}bc--ll & 
                        ll..(xpart llx, ypart lc)..ul & cycle) ;
    elseif type=38 :
      border := normal (ll--lc{up}..tc{right}..{down}rc--lr & 
                        lr..(xpart bc, ypart lly)..ll & cycle) ;
    elseif type=39 :
      border := mirror (ll--lc{up}..tc{right}..{down}rc--lr & 
                        lr..(xpart bc, ypart lly)..ll & cycle) ;
    elseif type=40 :
      border := normal (ll--lr--ur--ul--ll--ur--ul--ll--lr--ul--ll--cycle) ; 
    elseif type=41 :
      border := normal (ll--lr--ur--ul--ll--lr--rc--lc--ll--bc--tc--ul--ll & cycle) ; 
    elseif type=42 :
      border := normal (ll--lr--origin shifted (+epsilon,0)--
                        ur--ul--origin shifted (-epsilon,0)--cycle) ; 
    elseif type=43 :
      border := normal (ll--ul--origin shifted (0,+epsilon)--
                        ur--lr--origin shifted (0,-epsilon)--cycle) ; 
    elseif type=45 :
      border := normal (bc--rc--tc--lc--cycle) ;
    elseif type=46 :
      border := normal (ll--ul--rc--cycle) ;
    elseif type=47 :
      border := mirror (ll--ul--rc--cycle) ;
    elseif type=48 :
      border := mirror (ul--ur--bc--cycle) ;
    elseif type=49 :
      border := normal (ul--ur--bc--cycle) ;
    elseif type=56 :
      border := normal (ll--lry--ury--ul--cycle) ;
    elseif type=57 :
      border := mirror (ll--lry--ury--ul--cycle) ;
    elseif type=58 :
      border := normal (ll--ulx--urx--lr--cycle) ;
    elseif type=59 :
      border := mirror (ll--ulx--urx--lr--cycle) ;
    elseif type= 66 :
      border := normal (rc--origin shifted ( epsilon,0) --cycle & 
                        rc--origin                      --cycle ) ;
    elseif type= 67 :
      border := normal (lc--origin shifted (-epsilon,0) --cycle & 
                        lc--origin                      --cycle ) ;
    elseif type= 68 :
      border := normal (tc--origin shifted (0, epsilon) --cycle & 
                        tc--origin                      --cycle ) ;
    elseif type= 69 :
      border := normal (bc--origin shifted (0,-epsilon) --cycle & 
                        bc--origin                      --cycle ) ;

    else :
      border := normal (origin--cycle) ;
     %border := normal (ll--lr--ur--ul--cycle) ;
    fi ;

    border

    endgroup

enddef;

def show_shapes (expr n) =

  begin_chart(n,7,10) ;
    show_con_points := true ; 
    for i=0 upto 6 :
      for j=0 upto 9 :
        new_shape(i+1,j+1,i*10+j);
      endfor ;
    endfor ;
  end_chart ;

enddef ; 

%D connections

color connection_line_color ;

connection_line_width  := shape_line_width ;
connection_line_color  := .8white ;
connection_smooth_size := 5pt ;
connection_arrow_size  := 4pt ;
connection_dash_size   := 3pt ;

max_x := 6 ;
max_y := 4 ;

numeric xypoint       ; xypoint := 0 ;

pair    xypoints []   ;

boolean xyfree   [][] ;
path    xypath   [][] ;
numeric xysx     [][] ;
numeric xysy     [][] ;
color   xyfill   [][] ;
color   xydraw   [][] ;
numeric xyline   [][] ;
boolean xypeep   [][] ;

numeric cpath         ; cpath := 0 ; 
path    cpaths    []  ; 
numeric cline     []  ;
color   ccolor    []  ;
boolean carrow    []  ;
boolean cdash     []  ;
boolean ccross    []  ; 

boolean smooth        ; smooth       := true  ;
boolean peepshape     ; peepshape    := false ;
boolean arrowtip      ; arrowtip     := true  ;
boolean dashline      ; dashline     := false ;
boolean forcevalid    ; forcevalid   := false ;
boolean touchshape    ; touchshape   := false ; 
boolean showcrossing  ; showcrossing := false ; 

picture dash_pattern ;

boolean reverse_y ; reverse_y := true ;

def y_pos (expr y) =
  if reverse_y : max_y + 1 - y else : y fi
enddef ;

def initialize_grid (expr maxx, maxy) =
  begingroup ; 
  save i, j ; 
  max_x := maxx ;
  max_y := maxy ;
  for x=1 upto max_x :
    for y=1 upto max_y :
      xyfree [x][y] := true ;
      xyfill [x][y] := shape_fill_color ;
      xydraw [x][y] := shape_line_color ;
      xyline [x][y] := shape_line_width ;
    endfor ;
  endfor ;
  endgroup ;
enddef ;

def scaled_to_grid =
  xscaled grid_width yscaled grid_height
enddef ;

def xy_offset (expr x, y) =
  (x+.5,y+.5)
enddef ;

def draw_shape (expr x, yy, p, sx, sy) =
  begingroup ;
  save y ;
  y := y_pos(yy) ;
  xypath [x][y] := (p xscaled sx yscaled sy) shifted xy_offset(x,y) ;
  xyfree [x][y] := false ;
  xysx   [x][y] := sx ;
  xysy   [x][y] := sy ;
  xyfill [x][y] := shape_fill_color ;
  xydraw [x][y] := shape_line_color ;
  xyline [x][y] := shape_line_width ;
  xypeep [x][y] := peepshape ;
  endgroup ;
enddef ;

vardef i_point (expr x, y, p, t) =
  begingroup ;
  save q, ok ;
  pair q ;
  boolean ok ;
  q := xypath[x][y] intersection_point ((p) shifted xy_offset(x,y)) ;
  ok := true ;
%  if xpart q < -.5 : ok := false ; q := (-.45,ypart q) fi ;
%  if xpart q >  .5 : ok := false ; q := ( .45,ypart q) fi ;
%  if ypart q < -.5 : ok := false ; q := (xpart q,-.45) fi ;
%  if ypart q >  .5 : ok := false ; q := (xpart q, .45) fi ;
  if not ok :
    message (t & " of shape (" & decimal x & "," & decimal y & ") limited") ;
  fi ;
  q
  endgroup
enddef ;

vardef trimmed (expr x, y, z, t) =
  if touchshape and t : xyline[x][y]/z else : epsilon fi  
enddef ;

zfactor := 1/3 ;

vardef xy_bottom (expr x, y, z, t) =
  i_point (x, y, ((0,0)--(0,-2)) shifted (zfactor*z*xysx[x][y],0), "bottom")
  shifted(0,-trimmed(x,y,grid_height,t)) 
enddef ;

vardef xy_top (expr x, y, z, t) =
  i_point (x, y, ((0,0)--(0,2))  shifted (zfactor*z*xysx[x][y],0), "top")
  shifted(0,trimmed(x,y,grid_height,t)) 
enddef ;

vardef xy_left (expr x, y, z, t) =
  i_point (x, y, ((0,0)--(-2,0)) shifted (0,zfactor*z*xysy[x][y]), "left")
  shifted(-trimmed(x,y,grid_width,t),0)
enddef ;

vardef xy_right (expr x, y, z, t) =
  i_point (x, y, ((0,0)--(2,0))  shifted (0,zfactor*z*xysy[x][y]), "right")
  shifted(trimmed(x,y,grid_width,t),0)
enddef ;

def flush_shapes =
  for x=1 upto max_x :
    for y=1 upto max_y :
      flush_shape (x, y) ;
    endfor ;
  endfor ;
enddef ;

def draw_connection_point (expr x, y, z) =
  pickup pencircle scaled if (z=0): 2 fi xyline[x][y] ;
  drawdot xy_bottom(x,y,z,false) scaled_to_grid withcolor (1,0,0) ;
  drawdot xy_top   (x,y,z,false) scaled_to_grid withcolor (0,1,0) ;
  drawdot xy_left  (x,y,z,false) scaled_to_grid withcolor (0,0,1) ;
  drawdot xy_right (x,y,z,false) scaled_to_grid withcolor (1,1,0) ;
enddef ;

def flush_shape (expr x, yy) =
  begingroup ;
  save y ;
  y := y_pos(yy) ;
  if not xyfree[x][y] :
    pickup pencircle scaled xyline[x][y] ;
    if xypeep[x][y] : 
      fill (xypath[x][y] peepholed (unitsquare shifted (x,y))) 
        scaled_to_grid withpen pencircle scaled 0
        withcolor chart_background_color ; 
    else :
      fill xypath[x][y] scaled_to_grid withcolor xyfill[x][y] ;
    fi ;
    draw xypath[x][y] scaled_to_grid withcolor xydraw[x][y] ;
    if show_con_points or show_all_points :
      draw_connection_point (x, y, 0) ;
    fi ;
    if show_all_points :
      for i=-1 upto 1 :
        draw_connection_point (x, y, i) ;
      endfor ;
    fi ;
  fi ;
  endgroup ;
enddef ;

vardef points_initialized (expr xfrom, yfrom, xto, yto, n) =
  if not xyfree[xfrom][yfrom] and not xyfree[xto][yto] :
    xypoint := n ; true
  else :
    xypoint := 0 ; false
  fi
enddef ;

def collapse_points =
  % remove redundant points
  n := 1 ;
  for i=2 upto xypoint:
    if not (xypoints[i]=xypoints[n]) :
      n := n + 1 ;
      xypoints[n] := xypoints[i]
    fi ;
  endfor ;
  xypoint := n ;
  % make straight lines
  if xypoints[2]=xypoints[xypoint-1] :
    xypoints[3] := xypoints[xypoint] ;
    xypoint := 3 ;
  fi ;
enddef ;

vardef smoothed (expr a,b) =
  sx := connection_smooth_size/grid_width ;
  sy := connection_smooth_size/grid_height ;
  if ypart a = ypart b :
    a shifted (if xpart a >= xpart b : - fi sx,0)
  else :
    a shifted (0,if ypart a >= ypart b : - fi sy)
  fi
enddef ;

vardef trim_points =      
  begingroup
  save p, a, b, d, i ; path p ; pair d ; 
  p := for i=1 upto xypoint-1 : xypoints[i]-- endfor xypoints[xypoint] ; 
  if touchshape : 
    a := shape_line_width/grid_width ;
    b := shape_line_width/grid_height ;
  else :
    a := epsilon ; 
    b := epsilon ;
  fi ;  
  d := direction infinity of p ;
  xypoints[xypoint] := xypoints[xypoint] shifted
  if     xpart d < 0 : (+a,0) ;
  elseif xpart d > 0 : (-a,0) ;
  elseif ypart d < 0 : (0,+b) ;
  elseif ypart d > 0 : (0,-b) ;
  else               : origin ; 
  fi ;
  d := direction 0 of p ;
  xypoints[1] := xypoints[1] shifted
  if     xpart d < 0 : (-a,0) ;
  elseif xpart d > 0 : (+a,0) ;
  elseif ypart d < 0 : (0,-b) ;
  elseif ypart d > 0 : (0,+b) ;
  else               : origin ; 
  fi ;
  endgroup
enddef ; 

vardef trim_points = enddef ; 

vardef connection_path =
  if reverse_connection : reverse fi (xypoints[1]--
  for i=2 upto xypoint-1 :
    if smooth :
      smoothed(xypoints[i],xypoints[i-1])  ..
      controls xypoints[i] and xypoints[i] ..
      smoothed(xypoints[i],xypoints[i+1])  --
    else :
      xypoints[i]--
    fi
  endfor
  xypoints[xypoint])
enddef ;

def draw_connection =
  if xypoint>0 :
    collapse_points ;
    trim_points ;  
    cpath := cpath + 1 ; 
    cpaths[cpath] := connection_path scaled_to_grid ;
    cline[cpath]  := connection_line_width ;
    ccolor[cpath] := connection_line_color ;
    carrow[cpath] := arrowtip ;
    cdash[cpath]  := dashline ;
    ccross[cpath] := showcrossing ;
  else :
    message("no connection defined") ;
  fi ;
  reverse_connection := false ;
enddef ;

def flush_connections =
  pair ip ; 
  boolean crossing ; 
  ahlength     := connection_arrow_size ;
  dash_pattern := dashpattern(on connection_dash_size off connection_dash_size ) ;
  for i=1 upto cpath : 
    if ccross[i] :
      crossing := false ;
      for j=1 upto i :
       %if not ((point infinity of cpaths[i] = point infinity of cpaths[j]) or 
       %        (point 0        of cpaths[i] = point 0        of cpaths[j])) :
        if not  (point infinity of cpaths[i] = point infinity of cpaths[j]) :
          ip := cpaths[i] intersection_point cpaths[j] ;
          if intersection_found : crossing := true fi ;
        fi ;  
      endfor ; 
      if crossing : 
        pickup pencircle scaled 2cline[i] ;
%        draw cpaths[i] withcolor chart_background_color ;
path cp ; cp := cpaths[i] ; 
cp := cp cutbefore point .05 length cp of cp ;  
cp := cp cutafter  point .95 length cp of cp ;  
draw cp withcolor chart_background_color ;
      fi ; 
    fi ; 
    pickup pencircle scaled cline[i] ;
    if carrow[i] :
      if cdash[i] :
        drawarrow cpaths[i] withcolor ccolor[i] dashed dash_pattern ;
      else :
        drawarrow cpaths[i] withcolor ccolor[i] ;
      fi ;
    else :
      if cdash[i] :
        draw cpaths[i] withcolor ccolor[i] dashed dash_pattern ;
      else :
        draw cpaths[i] withcolor ccolor[i] ;
      fi ;
    fi ;
    draw_midpoint (i) ;
  endfor ;
enddef ;

def draw_midpoint (expr n) =
  begingroup
  save p ;
  pair p ;
  p := point .5*length(cpaths[n]) of cpaths[n];
  pickup pencircle scaled 2cline[n] ;
  save_text_position (p) ;
  if show_mid_points :
    drawdot p withcolor .7white ;
  fi ;
  endgroup ;
enddef ;

boolean reverse_connection ; reverse_connection := false ;

vardef up_on_grid (expr n) =
  (xpart xypoints[n],(ypart xypoints[n]+1) div 1)
enddef ;

vardef down_on_grid (expr n) =
  (xpart xypoints[n],(ypart xypoints[n]) div 1)
enddef ;

vardef left_on_grid (expr n) =
  ((xpart xypoints[n]) div 1, ypart xypoints[n])
enddef ;

vardef right_on_grid (expr n) =
  ((xpart xypoints[n]+1) div 1, ypart xypoints[n])
enddef ;

vardef x_on_grid (expr n, xfrom, xto, zfrom) =
  if (xfrom=xto) and not (zfrom=0) :
    if (zfrom=1) : right_on_grid(2) else : left_on_grid(2) fi
  elseif xpart xypoints[1] < xpart xypoints[6] :
    right_on_grid(n)
  else :
    left_on_grid(n)
  fi
enddef ;

vardef y_on_grid (expr n, yfrom, yto, zfrom) =
  if (yfrom=yto) and not (zfrom=0) :
    if (zfrom=1) : up_on_grid(2) else : down_on_grid(2) fi
  elseif ypart xypoints[1] < ypart xypoints[6] :
    up_on_grid(n)
  else :
    down_on_grid(n)
  fi
enddef ;

vardef xy_on_grid (expr n, m) =
  (xpart xypoints[n], ypart xypoints[m])
enddef ;

vardef down_to_grid (expr a,b) =
  (xpart xypoints[a],
   ypart xypoints[if ypart xypoints[a]<ypart xypoints[b]:a else:b fi])
enddef ;

vardef up_to_grid (expr a,b) =
  (xpart xypoints[a],
   ypart xypoints[if ypart xypoints[a]>ypart xypoints[b]:a else:b fi])
enddef ;

vardef left_to_grid (expr a,b) =
  (xpart xypoints[if xpart xypoints[a]<xpart xypoints[b]:a else:b fi],
   ypart xypoints[a])
enddef ;

vardef right_to_grid (expr a,b) =
  (xpart xypoints[if xpart xypoints[a]>xpart xypoints[b]:a else:b fi],
   ypart xypoints[a])
enddef ;

vardef valid_connection (expr xfrom, yfrom, xto, yto) =
  begingroup ;
  save ok, vc, pp ;
  boolean ok ;
  % check for slanted lines
  ok := true ;
  for i=1 upto xypoint-1 :
    if not ((xpart xypoints[i]=xpart xypoints[i+1]) or
            (ypart xypoints[i]=ypart xypoints[i+1])) : ok := false ;
    fi ;
  endfor ;
  if not ok :
   %message("slanted");
    false
  elseif forcevalid :
   %message("force");
    true
  elseif (xfrom=xto) and (yfrom=yto) : 
   %message("self");
    false 
  else :
    % check for crossing shapes
    pair vc ;
    path pp ;

    pair xyfirst, xylast ; 
    xyfirst := xypoints[1] ; 
    xylast := xypoints[xypoint] ;
    trim_points ;  
    pp := for i=1 upto xypoint-1 : xypoints[i]-- endfor xypoints[xypoint] ;
    xypoints[1] := xyfirst ; 
    xypoints[xypoint] := xylast ;

    for i=1 upto max_x :
      for j=1 upto max_y :
if not ( ( (i,j) = (xfrom,yfrom) ) or ( (i,j) = (yfrom,yto) ) ) : 
        if not xyfree[i][j] : 
          vc := pp intersection_point xypath[i][j] ;
          if intersection_found : ok := false fi ;
        fi ;
fi ; 
      endfor ;
    endfor ;
   %if not ok: message("crossing") ; fi ;
    ok
  fi
  endgroup
enddef ;

def connect_top_bottom (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_top(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_bottom(xto,yto,zto,true) ;
    xypoints[2] := up_on_grid(1) ;
    xypoints[5] := down_on_grid(6) ;
    xypoints[3] := up_to_grid(2,5) ;
    xypoints[4] := up_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := x_on_grid(2,xfrom,xto,zfrom) ;
      xypoints[4] := xy_on_grid(3,5) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_left_right (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_left(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_right(xto,yto,zto,true) ;
    xypoints[2] := left_on_grid(1) ;
    xypoints[5] := right_on_grid(6) ;
    xypoints[3] := left_to_grid(2,5) ;
    xypoints[4] := left_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := y_on_grid(2,yfrom,yto,zfrom) ;
      xypoints[4] := xy_on_grid(5,3) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_left_top (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,5) :
    xypoints[1] := xy_left(xfrom,yfrom,zfrom,true) ;
    xypoints[5] := xy_top(xto,yto,zto,true) ;
    xypoints[2] := left_on_grid(1) ;
    xypoints[4] := up_on_grid(5) ;
    xypoints[3] := left_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := xy_on_grid(2,4) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_left_bottom (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,5) :
    xypoints[1] := xy_left(xfrom,yfrom,zfrom,true) ;
    xypoints[5] := xy_bottom(xto,yto,zto,true) ;
    xypoints[2] := left_on_grid(1) ;
    xypoints[4] := down_on_grid(5) ;
    xypoints[3] := left_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := xy_on_grid(2,4) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_right_top (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,5) :
    xypoints[1] := xy_right(xfrom,yfrom,zfrom,true) ;
    xypoints[5] := xy_top(xto,yto,zto,true) ;
    xypoints[2] := right_on_grid(1) ;
    xypoints[4] := up_on_grid(5) ;
    xypoints[3] := right_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := xy_on_grid(2,4) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_right_bottom (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,5) :
    xypoints[1] := xy_right(xfrom,yfrom,zfrom,true) ;
    xypoints[5] := xy_bottom(xto,yto,zto,true) ;
    xypoints[2] := right_on_grid(1) ;
    xypoints[4] := down_on_grid(5) ;
    xypoints[3] := right_to_grid(2,5) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := xy_on_grid(2,4) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_left_left (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_left(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_left(xto,yto,zto,true) ;
    xypoints[2] := left_on_grid(1) ;
    xypoints[5] := left_on_grid(6) ;
    xypoints[3] := left_to_grid(2,5) ;
    xypoints[4] := left_to_grid(5,2) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := y_on_grid(2,yfrom,yto,zfrom) ;
      xypoints[4] := xy_on_grid(5,3) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_right_right (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_right(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_right(xto,yto,zto,true) ;
    xypoints[2] := right_on_grid(1) ;
    xypoints[5] := right_on_grid(6) ;
    xypoints[3] := right_to_grid(2,5) ;
    xypoints[4] := right_to_grid(5,2) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := y_on_grid(2,yfrom,yto,zfrom) ;
      xypoints[4] := xy_on_grid(5,3) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_top_top (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_top(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_top(xto,yto,zto,true) ;
    xypoints[2] := up_on_grid(1) ;
    xypoints[5] := up_on_grid(6) ;
    xypoints[3] := up_to_grid(2,5) ;
    xypoints[4] := up_to_grid(5,2) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := x_on_grid(2,xfrom,xto,zfrom) ;
      xypoints[4] := xy_on_grid(3,5) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_bottom_bottom (expr xfrom,yyfrom,zfrom) (expr xto,yyto,zto) =
  yfrom := y_pos(yyfrom) ; yto := y_pos(yyto) ;
  if points_initialized(xfrom,yfrom,xto,yto,6) :
    xypoints[1] := xy_bottom(xfrom,yfrom,zfrom,true) ;
    xypoints[6] := xy_bottom(xto,yto,zto,true) ;
    xypoints[2] := down_on_grid(1) ;
    xypoints[5] := down_on_grid(6) ;
    xypoints[3] := down_to_grid(2,5) ;
    xypoints[4] := down_to_grid(5,2) ;
    if not valid_connection(xfrom,yfrom,xto,yto) :
      xypoints[3] := x_on_grid(2,xfrom,xto,zfrom) ;
      xypoints[4] := xy_on_grid(3,5) ;
    fi ;
    draw_connection ;
  fi ;
enddef ;

def connect_bottom_top (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_top_bottom (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def connect_right_left (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_left_right (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def connect_top_left (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_left_top (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def connect_bottom_left (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_left_bottom (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def connect_top_right (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_right_top (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def connect_bottom_right (expr xfrom,yfrom,zfrom) (expr xto,yto,zto) =
  reverse_connection := true ;
  connect_right_bottom (xto,yto,zto) (xfrom,yfrom,zfrom) ;
enddef ;

def draw_test_shape (expr x, y) =
  draw_shape(x,y,fullcircle, .7, .7) ;
enddef ;

def draw_test_shapes =
  for i=1 upto max_x :
    for j=1 upto max_y :
      draw_test_shape(i,j) ;
    endfor ;
  endfor ;
enddef;

def draw_test_area =
  pickup pencircle scaled .5shape_line_width ;
  draw (unitsquare xscaled max_x yscaled max_y shifted (1,1))
    scaled_to_grid withcolor blue ;
enddef ;

def show_connection (expr n, m) =

  begin_chart(100+n,6,6) ;

    draw_test_area ;

    smooth   := true ;
    arrowtip := true ;
    dashline := true ;

    draw_test_shape(2,2) ; draw_test_shape(4,5) ;
    draw_test_shape(3,3) ; draw_test_shape(5,1) ;
    draw_test_shape(2,5) ; draw_test_shape(1,3) ;
    draw_test_shape(6,2) ; draw_test_shape(4,6) ;

    if     (m=1) :
      connect_top_bottom (2,2,0) (4,5,0) ;
      connect_top_bottom (3,3,0) (5,1,0) ;
      connect_top_bottom (2,5,0) (1,3,0) ;
      connect_top_bottom (6,2,0) (4,6,0) ;
    elseif (m=2) :
      connect_top_top (2,2,0) (4,5,0) ;
      connect_top_top (3,3,0) (5,1,0) ;
      connect_top_top (2,5,0) (1,3,0) ;
      connect_top_top (6,2,0) (4,6,0) ;
    elseif (m=3) :
      connect_bottom_bottom (2,2,0) (4,5,0) ;
      connect_bottom_bottom (3,3,0) (5,1,0) ;
      connect_bottom_bottom (2,5,0) (1,3,0) ;
      connect_bottom_bottom (6,2,0) (4,6,0) ;
    elseif (m=4) :
      connect_left_right (2,2,0) (4,5,0) ;
      connect_left_right (3,3,0) (5,1,0) ;
      connect_left_right (2,5,0) (1,3,0) ;
      connect_left_right (6,2,0) (4,6,0) ;
    elseif (m=5) :
      connect_left_left (2,2,0) (4,5,0) ;
      connect_left_left (3,3,0) (5,1,0) ;
      connect_left_left (2,5,0) (1,3,0) ;
      connect_left_left (6,2,0) (4,6,0) ;
    elseif (m=6) :
      connect_right_right (2,2,0) (4,5,0) ;
      connect_right_right (3,3,0) (5,1,0) ;
      connect_right_right (2,5,0) (1,3,0) ;
      connect_right_right (6,2,0) (4,6,0) ;
    elseif (m=7) :
      connect_left_top (2,2,0) (4,5,0) ;
      connect_left_top (3,3,0) (5,1,0) ;
      connect_left_top (2,5,0) (1,3,0) ;
      connect_left_top (6,2,0) (4,6,0) ;
    elseif (m=8) :
      connect_left_bottom (2,2,0) (4,5,0) ;
      connect_left_bottom (3,3,0) (5,1,0) ;
      connect_left_bottom (2,5,0) (1,3,0) ;
      connect_left_bottom (6,2,0) (4,6,0) ;
    elseif (m=9) :
      connect_right_top (2,2,0) (4,5,0) ;
      connect_right_top (3,3,0) (5,1,0) ;
      connect_right_top (2,5,0) (1,3,0) ;
      connect_right_top (6,2,0) (4,6,0) ;
    else :
      connect_right_bottom (2,2,0) (4,5,0) ;
      connect_right_bottom (3,3,0) (5,1,0) ;
      connect_right_bottom (2,5,0) (1,3,0) ;
      connect_right_bottom (6,2,0) (4,6,0) ;
    fi ;

  end_chart ;

enddef ;

def show_connections =
  for f=1 upto 10 :
    show_connection(f,f) ;
  endfor ;
enddef ;

%D charts

def clip_chart (expr minx, miny, maxx, maxy) =
  cmin_x := minx ;
  cmax_x := maxx ;
  cmin_y := miny ; 
  cmax_y := maxy ; 
enddef ;

def begin_chart (expr n, maxx, maxy) =
  chart_figure := n ;
  chart_scale := 1 ; 
  if chart_figure>0: beginfig(chart_figure) ; fi ;
  initialize_grid (maxx, maxy) ;
  bboxmargin := 0 ;
  cmin_x := 1 ; 
  cmax_x := maxx ;
  cmin_y := 1 ; 
  cmax_y := maxy ; 
enddef ;

def end_chart =
  flush_shapes ;
  flush_connections ; 
  cmin_x := cmin_x ; 
  cmax_x := cmin_x+cmax_x ; 
  cmin_y := cmin_y-1 ; 
  cmax_y := cmin_y+cmax_y ;  
  if reverse_y : 
   cmin_y := y_pos(cmin_y) ;
   cmax_y := y_pos(cmax_y) ; 
  fi ; 
  path p ;
  p := (((cmin_x,cmin_y)--(cmax_x,cmin_y)--
         (cmax_x,cmax_y)--(cmin_x,cmax_y)--cycle))
       scaled_to_grid ;
 %draw p withcolor red ; 
  p := enlarged_path (p,chart_offset) ;
  clip currentpicture to p ;
  setbounds currentpicture to p ;
  write
    "\MPclippath{" &
    decimal xpart llcorner p & "}{" &
    decimal ypart llcorner p & "}{" &
    decimal xpart urcorner p & "}{" &
    decimal ypart urcorner p & "}" to jobname & ".tmp" ;
  write
    "\MPareapath{" &
    decimal (xpart llcorner p + 2chart_offset) & "}{" &
    decimal (ypart llcorner p + 2chart_offset) & "}{" &
    decimal (xpart urcorner p - 2chart_offset) & "}{" &
    decimal (ypart urcorner p - 2chart_offset) & "}" to jobname & ".tmp" ;
currentpicture := currentpicture scaled chart_scale ;
  if chart_figure>0: endfig ; fi ;
enddef ;

def new_shape (expr x, y, n) =
  if known n :
    if (x>0) and (x<=max_x) and (y>0) and (y<=max_y) :
      sx := shape_width/grid_width ;
      sy := shape_height/grid_height ;
      draw_shape(x,y,some_shape(n), sx, sy) ;
    else :
      message ("shape outside grid ignored") ;
    fi ;
  else
    message ("shape not known" ) ;
  fi ;
enddef ;

def begin_sub_chart =
  begingroup ;
  save    shape_line_width , connection_line_width ;
  save    shape_line_color, shape_fill_color, connection_line_color ;
  color   shape_line_color, shape_fill_color, connection_line_color ;
  save    smooth, arrowtip, dashline, peepshape ;
  boolean smooth, arrowtip, dashline, peepshape ;
enddef ;

def end_sub_chart =
  endgroup ;
enddef ;

%D done

endinput

%D testing

show_shapes(100) ;
show_connections ;

begin_chart (1,4,5) ;
 %clip_chart(1,1,1,2) ;
  new_shape (1,1,31) ;
  new_shape (1,2,3) ;
  new_shape (4,4,5) ;
  connect_top_left   (1,1,0) (4,4,0) ;
  connect_bottom_top (1,2,0) (4,4,0) ;
  connect_left_right (1,2,0) (1,1,0) ;
end_chart ;

end
