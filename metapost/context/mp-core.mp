%D \module
%D   [       file=mp-core.mp,
%D        version=1999.08.12,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=core interfacing,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for
%C details.

if unknown context_tool :    input mp-tool ; fi ;
if   known context_core : endinput         ; fi ;

boolean context_core ; context_core := true ;

pair lxy[], rxy[], cxy[], llxy[], lrxy[], ulxy[], urxy[] ;
path pxy[] ;
numeric hxy[], wxy[], dxy[], nxy[] ;

def box_found (expr n,x,y,w,h,d) =
  not ((x=0) and (y=0) and (w=0) and (h=0) and (d=0))
enddef ;

def initialize_box_pos (expr pos,n,x,y,w,h,d) =
  pair lxy, rxy, cxy, llxy, lrxy, ulxy, urxy ;
  path pxy ; numeric hxy, wxy, dxy, nxy;
  lxy  := (x,y) ;
  llxy := (x,y-d) ;
  lrxy := (x+w,y-d) ;
  urxy := (x+w,y+h) ;
  ulxy := (x,y+h) ;
  wxy  := w ;
  hxy  := h ;
  dxy  := d ;
  rxy  := lxy shifted (wxy,0) ;
  pxy  := llxy--lrxy--urxy--ulxy--cycle ;
  cxy  := center pxy ;
  nxy  := n ;
  freeze_box(pos) ; 
enddef ;

def freeze_box (expr pos) = 
  lxy[pos]  := lxy  ;
  llxy[pos] := llxy ;
  lrxy[pos] := lrxy ;
  urxy[pos] := urxy ;
  ulxy[pos] := ulxy ;
  wxy[pos]  := wxy  ;
  hxy[pos]  := hxy  ;
  dxy[pos]  := dxy  ;
  rxy[pos]  := rxy  ;
  pxy[pos]  := pxy  ;
  cxy[pos]  := cxy  ;
  nxy[pos]  := nxy  ;
enddef ; 

def initialize_box (expr n,x,y,w,h,d) =

  numeric bpos ; bpos := 0 ; initialize_box_pos(bpos,n,x,y,w,h,d) ;

enddef ;

def initialize_area (expr fn,fx,fy,fw,fh,fd,
                          tn,tx,ty,tw,th,td) =

  numeric fpos ; fpos := 1 ; initialize_box_pos(fpos,fn,fx,fy,fw,fh,fd) ;
  numeric tpos ; tpos := 2 ; initialize_box_pos(tpos,tn,tx,ty,tw,th,td) ;

  do_initialize_area (fpos, tpos) ;

enddef ;

def do_initialize_area (expr fpos, tpos) =
  lxy  := lxy[fpos] ;
  llxy := (xpart llxy[fpos], ypart llxy[tpos]) ;
  lrxy := lrxy[tpos] ;
  urxy := (xpart urxy[tpos], ypart urxy[fpos]) ;
  ulxy := ulxy[fpos] ;
  wxy  := xpart lrxy - xpart llxy ;
  hxy  := hxy[fpos] ;
  dxy  := dxy[tpos] ;
  rxy  := lxy shifted (wxy,0) ;
  pxy  := llxy--lrxy--urxy--ulxy--cycle ;
  cxy  := center pxy ;
enddef ;

def initialize_par (expr fn,fx,fy,fw,fh,fd,
                         tn,tx,ty,tw,th,td,
                         mn,mx,my,mw,mh,md,
                         pn,px,py,pw,ph,pd,
                         rw,rl,rr,rh,ra,ri) =

  numeric fpos ; fpos := 1 ; initialize_box_pos(fpos,fn,fx,fy,fw,fh,fd) ;
  numeric tpos ; tpos := 2 ; initialize_box_pos(tpos,tn,tx,ty,tw,th,td) ;
  numeric mpos ; mpos := 3 ; initialize_box_pos(mpos,mn,mx,my,mw,mh,md) ;
  numeric ppos ; ppos := 4 ; initialize_box_pos(ppos,pn,px,py,pw,ph,pd) ;

  numeric par_strut_height, par_strut_depth, par_line_height ;

  par_strut_height := ph ; 
  par_strut_depth  := pd ;
  par_line_height  := ph + pd ;

  do_initialize_area (fpos, tpos) ;
  do_initialize_par  (fpos, tpos, mpos, ppos, rw,rl,rr,rh,ra,ri) ;

enddef ;

def initialize_area_par (expr fn,fx,fy,fw,fh,fd,
                              tn,tx,ty,tw,th,td,
                              wn,wx,wy,ww,wh,wd) =

  numeric fpos ; fpos := 1 ; initialize_box_pos(fpos,fn,fx,fy,fw,fh,fd) ;
  numeric tpos ; tpos := 2 ; initialize_box_pos(tpos,tn,tx,ty,tw,th,td) ;
  numeric wpos ; wpos := 3 ; initialize_box_pos(wpos,wn,wx,wy,ww,wh,wd) ;

  numeric par_strut_height, par_strut_depth, par_line_height ;

  par_strut_height := wh ; 
  par_strut_depth  := wd ;
  par_line_height  := wh + wd ;

  numeric ffpos ; ffpos := 4 ; initialize_box_pos(ffpos,wn,wx,fy,0,wh,wd) ;
  numeric ttpos ; ttpos := 5 ; initialize_box_pos(ttpos,wn,wx+ww,ty,0,wh,wd) ;

  do_initialize_area (ffpos, ttpos) ; 

  numeric mpos ; mpos := 6 ; freeze_box(mpos) ; 

% do_initialize_area (fpos, tpos) ;
  do_initialize_par  (fpos, tpos, mpos, ffpos, 0,0,0,0,0,0) ;

enddef ;

def do_initialize_par (expr fpos, tpos, mpos, ppos, rw,rl,rr,rh,ra,ri) =

  pair lref, rref, pref, lhref, rhref ; 

  % clip the page area to the left and right skips

  llxy[mpos] := llxy[mpos] shifted (+rl,0) ; 
  lrxy[mpos] := lrxy[mpos] shifted (-rr,0) ; 
  urxy[mpos] := urxy[mpos] shifted (-rr,0) ; 
  ulxy[mpos] := ulxy[mpos] shifted (+rl,0) ; 

  % fixate the leftskip, rightskip and hanging indentation
  
  lref := (xpart llxy[mpos],ypart ulxy[ppos]) ; lhref := lref shifted (rh,0) ; 
  rref := (xpart lrxy[mpos],ypart urxy[ppos]) ; rhref := rref shifted (rh,0) ; 

  pref := lxy[ppos] ;  

  if nxy[tpos] > nxy[fpos] : 
    if nxy[fpos] = nxy[mpos] : 
      % first of multiple pages 
      llxy[tpos] := llxy[mpos] ; 
      lrxy[tpos] := lrxy[mpos] ; 
      urxy[tpos] := lrxy[mpos] shifted (0,par_line_height) ; 
      ulxy[tpos] := llxy[mpos] shifted (0,par_line_height) ; 
      boxgriddirection := down ; 
    elseif nxy[tpos] = nxy[mpos] : 
      % last of multiple pages 
      llxy[fpos] := ulxy[mpos] shifted (0,-par_line_height) ; 
      lrxy[fpos] := urxy[mpos] shifted (0,-par_line_height) ; 
      urxy[fpos] := urxy[mpos] ; 
      ulxy[fpos] := ulxy[mpos] ; 
      boxgriddirection := up ; 
    else : 
      % middle of multiple pages 
      llxy[fpos] := ulxy[mpos] shifted (0,-par_line_height) ; 
      lrxy[fpos] := urxy[mpos] shifted (0,-par_line_height) ; 
      urxy[fpos] := urxy[mpos] ; 
      ulxy[fpos] := ulxy[mpos] ; 
      llxy[tpos] := llxy[mpos] ; 
      lrxy[tpos] := lrxy[mpos] ; 
      urxy[tpos] := lrxy[mpos] shifted (0,par_line_height) ; 
      ulxy[tpos] := llxy[mpos] shifted (0,par_line_height) ; 
      boxgriddirection := up ; 
    fi ;
  else : 
    % just one page 
    boxgriddirection := up ; 
  fi ; 

  path txy, bxy, pxy, mxy ; 

  txy := originpath ; % top 
  bxy := originpath ; % bottom 
  pxy := originpath ; % composed

  boolean lefthang, righthang, somehang ; 

  % we only hang on the first of a multiple page background 

  if nxy[mpos] > nxy[fpos] : 
    lefthang := righthang := somehang := false ; 
  else : 
    lefthang := (rh>0) ; righthang := (rh<0) ; somehang := false ; 
  fi ; 

  if lefthang :
    mxy  := boundingbox (lref -- lref shifted (rh,ra*par_line_height)) ; 
  elseif righthang : 
    mxy  := boundingbox (rref -- rref shifted (rh,ra*par_line_height)) ; 
  else :
    mxy  := originpath ;  
  fi ;

  if round(ypart llxy[fpos]) = round(ypart llxy[tpos]) : 

    % We have a one-liner. Watch how er use the bottom pos for
    % determining the height.

    llxy[fpos] := (xpart llxy[fpos], ypart llxy[tpos]) ; 
    ulxy[fpos] := (xpart ulxy[fpos], ypart ulxy[tpos]) ; 

  else : 

    % We have a multi-liner. For convenience we now correct the 
    % begin and end points for indentation.  

    if lefthang and (round(ypart llxy[tpos]) >= round(ypart lrcorner mxy)) : 
      llxy[tpos] := (xpart lhref, ypart llxy[tpos]) ;
      ulxy[tpos] := (xpart lhref, ypart ulxy[tpos]) ;
    else :
      llxy[tpos] := (xpart  lref, ypart llxy[tpos]) ;
      ulxy[tpos] := (xpart  lref, ypart ulxy[tpos]) ;
    fi ;

    if righthang and (round(ypart lrxy[fpos]) >= round(ypart llcorner mxy)) :
      lrxy[fpos] := (xpart rhref, ypart lrxy[fpos]) ;
      urxy[fpos] := (xpart rhref, ypart urxy[fpos]) ;
    else :
      lrxy[fpos] := (xpart  rref, ypart lrxy[fpos]) ;
      urxy[fpos] := (xpart  rref, ypart urxy[fpos]) ;  
    fi ;

  fi ; 

  somehang := (ypart ulxy[fpos]>ypart llcorner mxy) and 
              (ypart llxy[tpos]<ypart llcorner mxy) ;

  if round(ypart llxy[fpos]) = round(ypart llxy[tpos]) : 

    % A (short) one-liner goes into the top box. 

    txy := llxy[fpos] -- lrxy[tpos] -- urxy[tpos] -- ulxy[fpos] -- cycle ;

  elseif (round(ypart llxy[fpos]) = round(ypart ulxy[tpos])) and
         (round(xpart lrxy[tpos]) < round(xpart llxy[fpos])) :

    % We have a sentence that spans two lines but with only end 
    % of line and begin of line segments. We need to take care of 
    % indentation. 

    txy := llxy[fpos] -- lrxy[fpos] -- urxy[fpos] -- ulxy[fpos] -- cycle ;
    bxy := llxy[tpos] -- lrxy[tpos] -- urxy[tpos] -- ulxy[tpos] -- cycle ;

  elseif (round(ypart llxy[fpos]) = round(ypart ulxy[tpos])) :

    % We have a sentence that spans two lines but with overlap.

    pxy := llxy[tpos] -- lrxy[tpos] -- urxy[tpos] -- lrxy[fpos] --
           urxy[fpos] -- ulxy[fpos] -- llxy[fpos] -- ulxy[tpos] -- cycle ;

  elseif lefthang and somehang : 

    % We have a sentence that spans more than two lines with 
    % left hanging indentation. 

    pxy := llxy[tpos] -- lrxy[tpos] -- urxy[tpos] -- 
           (xpart urxy[fpos],ypart urxy[tpos]) --
           urxy[fpos] -- ulxy[fpos] -- llxy[fpos] -- 
           if round(ypart urxy[tpos]) < round(ypart llcorner mxy) : 
             (xpart lrcorner mxy,ypart llxy[fpos]) -- 
             lrcorner mxy -- 
             (xpart llxy[tpos],ypart llcorner mxy) -- 
           else : 
             (xpart llxy[tpos],ypart llxy[fpos]) -- 
           fi 
           cycle ;

  elseif righthang and somehang :

    % We have a sentence that spans more than two lines with 
    % right hanging indentation. 

    pxy := llxy[tpos] -- lrxy[tpos] -- urxy[tpos] -- 
           if round(ypart urxy[tpos]) < round(ypart llcorner mxy) :  
             (xpart lrcorner mxy,ypart urxy[tpos]) --
             lrcorner mxy -- llcorner mxy --
           else : 
             (xpart urxy[fpos],ypart urxy[tpos]) --
           fi 
           urxy[fpos] -- ulxy[fpos] -- llxy[fpos] -- 
           (xpart llxy[tpos],ypart llxy[fpos]) -- 
           cycle ;

  else :       

    % We have a sentence that spans more than two lines with 
    % no hanging indentation. 

    pxy := llxy[tpos] -- lrxy[tpos] -- urxy[tpos] -- 
           (xpart urxy[fpos],ypart urxy[tpos]) --
           urxy[fpos] -- ulxy[fpos] -- llxy[fpos] -- 
           (xpart llxy[tpos],ypart llxy[fpos]) -- cycle ;

  fi ;

  pxy := simplified pxy ; 
  pxy := unspiked   pxy ; 

enddef ;

color   boxgridcolor     ; boxgridcolor     := .8red ;
color   boxlinecolor     ; boxlinecolor     := .8blue ;
color   boxfillcolor     ; boxfillcolor     := .8white ;
numeric boxgridtype      ; boxgridtype      := 0 ;
numeric boxlinetype      ; boxlinetype      := 1 ;
numeric boxfilltype      ; boxfilltype      := 1 ;
pair    boxgriddirection ; boxgriddirection := up ;
numeric boxgridwidth     ; boxgridwidth     := 1pt ;
numeric boxlinewidth     ; boxlinewidth     := 1pt ;
numeric boxlineradius    ; boxlineradius    := 0pt ; 

def draw_box =
  draw pxy withcolor boxlinecolor withpen pencircle scaled boxlinewidth ;
  draw lxy -- rxy withcolor boxlinecolor withpen pencircle scaled boxgridwidth ;
enddef ;

def draw_par  = % 1 2 11
  numeric distance ; distance := .5cm ; 
  do_draw_par(pxy) ; do_draw_par(txy) ; do_draw_par(bxy) ;
  for i = pxy, txy, bxy :
        if boxgridtype= 1 :
      draw baseline_grid (i,boxgriddirection,true ) withcolor boxgridcolor ;
    elseif boxgridtype= 2 :
      draw baseline_grid (i,boxgriddirection,false) withcolor boxgridcolor ;
    elseif boxgridtype=11 :
      draw graphic_grid(i,distance,distance,distance/2,distance/2) ;
    fi ;
  endfor ;
enddef ;

def show_par  =
  def do_show_par (expr p, r, c) =
    if length(p) > 2 : for i=0 upto length(p) :
      draw fullcircle scaled r shifted point i of p 
        withpen pencircle scaled .5pt withcolor c ;
    endfor ; fi ;
  enddef ; 
  if length(mxy) > 2 : 
    draw mxy dashed evenly 
      withpen pencircle scaled .5pt withcolor .5white ; 
  fi ;   
  do_show_par(txy, 4pt, .5green) ;
  do_show_par(bxy, 6pt, .5blue ) ;
  do_show_par(pxy, 8pt, .5red  ) ;
  draw pref withpen pencircle scaled 2pt ; 
enddef ;

vardef do_draw_par (expr p) =
  if (length p>2) and (bbwidth(p)>1) and (bbheight(p)>1) :
    save pp ; path pp ; 
    if (boxlineradius>0) and (boxlinetype=2) : 
      pp := p cornered boxlineradius ; 
    else : 
      pp := p ; 
    fi ; 
    if boxfilltype>0 :
      fill pp withcolor boxfillcolor ; 
    fi ;
    if boxlinetype>0 :
      draw pp withcolor boxlinecolor withpen pencircle scaled boxlinewidth ; 
    fi ; 
  fi ;
enddef ;

vardef baseline_grid (expr pxy, pdir, at_baseline) =
  if (par_line_height>0) and (bbheight(pxy)>1) and (bbwidth(pxy)>1) and (boxgridwidth>0) :
    save grid, start ; picture grid ; pair start ;
    grid := image
      ( %fails with inlinespace
        %
        %if pdir=up :
        %  for i = if at_baseline : par_strut_depth else : 0 fi
        %          step par_line_height until bbheight(pxy) :
        %    start := llcorner pxy shifted (0,+i) ;
        %    draw start -- start shifted (bbwidth(pxy),0) 
        %      withpen pencircle scaled boxgridwidth 
        %      withcolor boxgridcolor ; 
        %  endfor ;
        %else :
          for i = if at_baseline : par_strut_height else : 0 fi
                  step par_line_height until bbheight(pxy) :
            start := ulcorner pxy shifted (0,-i) ;
            draw start -- start shifted (bbwidth(pxy),0) 
              withpen pencircle scaled boxgridwidth 
              withcolor boxgridcolor ; 
          endfor ;
        %fi ; 
      ) ;
    clip grid to pxy ;
    grid
  else :
    nullpicture
  fi
enddef ;

vardef graphic_grid (expr pxy, dx, dy, x, y) =
  if (bbheight(pxy)>dy) and (bbwidth(pxy)>dx) and (boxgridwidth>0) :
    save grid ; picture grid ;
    grid := image
      ( for i = xpart llcorner pxy step dx until xpart lrcorner pxy :
          draw (i,ypart llcorner pxy) -- (i,ypart ulcorner pxy) 
            withpen pencircle scaled boxgridwidth ; 
        endfor ;
        for i = ypart llcorner pxy step dy until ypart ulcorner pxy :
          draw (xpart llcorner pxy,i) -- (xpart lrcorner pxy,i) 
            withpen pencircle scaled boxgridwidth ; 
        endfor ) ;
    clip grid shifted (x,y) to pxy ;
    grid
  else :
    nullpicture
  fi
enddef ;

def anchor_box (expr n,x,y,w,h,d) =
  currentpicture := currentpicture shifted (-x,-y) ;
enddef ;

let draw_area   = draw_box ;
let anchor_area = anchor_box ;
let anchor_par  = anchor_box ;

endinput ;
