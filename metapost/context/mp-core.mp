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
  lxy  := (x,y)                         ; lxy[pos]  := lxy  ;
  llxy := (x,y-d)                       ; llxy[pos] := llxy ; 
  lrxy := (x+w,y-d)                     ; lrxy[pos] := lrxy ; 
  urxy := (x+w,y+h)                     ; urxy[pos] := urxy ; 
  ulxy := (x,y+h)                       ; ulxy[pos] := ulxy ;
  wxy  := w                             ; wxy[pos]  := wxy  ; 
  hxy  := h                             ; hxy[pos]  := hxy  ; 
  dxy  := d                             ; dxy[pos]  := dxy  ;
  rxy  := lxy shifted (wxy,0)           ; rxy[pos]  := rxy  ;
  pxy  := llxy--lrxy--urxy--ulxy--cycle ; pxy[pos]  := pxy  ;
  cxy  := center pxy                    ; cxy[pos]  := cxy  ;
  nxy  := n                             ; nxy[pos]  := nxy  ;
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

def initialize_par (expr fn,fx,fy,fw,fh,fd, ln,lx,ly,lw,lh,ld,
                         rn,rx,ry,rw,rh,rd, tn,tx,ty,tw,th,td) =

  numeric fpos ; fpos := 1 ; initialize_box_pos(fpos,fn,fx,fy,fw,fh,fd) ;
  numeric lpos ; lpos := 3 ; initialize_box_pos(lpos,ln,lx,ly,lw,lh,ld) ;
  numeric rpos ; rpos := 4 ; initialize_box_pos(rpos,rn,rx,ry,rw,rh,rd) ;
  numeric tpos ; tpos := 2 ; initialize_box_pos(tpos,tn,tx,ty,tw,th,td) ;

  do_initialize_area (fpos, tpos) ;
  do_initialize_par  (fpos, lpos, rpos, tpos) ;

enddef ; 

def do_initialize_par (expr fpos, lpos, rpos, tpos) =

  pair leftxy, righxy ; path txy, mxy, bxy ; % top mid bot

  leftxy := if xpart ulxy[fpos] > xpart ulxy[lpos] : ulxy[fpos] else : ulxy[lpos]  fi ;
  righxy := if xpart urxy[tpos] < xpart urxy[rpos] : urxy[tpos] else : urxy[rpos] fi ;

  pxy := origin ; 

  if (round(ypart llxy[fpos]) = round(ypart ulxy[tpos])) and
     (round(xpart lrxy[tpos]) < round(xpart llxy[fpos])) :

    txy := llxy[fpos] -- (xpart lrxy[rpos], ypart lrxy[fpos]) --
           (xpart urxy[rpos], ypart urxy[fpos]) -- ulxy[fpos] -- cycle ;
    mxy := origin ;
    bxy := (xpart llxy[lpos], ypart llxy[tpos]) -- lrxy[tpos] --
           urxy[tpos] -- (xpart ulxy[lpos], ypart ulxy[tpos]) -- cycle ;

  elseif ypart llxy[fpos] = ypart llxy[tpos] :

    txy := llxy[fpos] -- lrxy[tpos] -- urxy[tpos] -- ulxy[fpos] --cycle ;
    mxy := origin ;
    bxy := origin ;

  else :

    txy := (xpart lrxy[rpos], ypart lrxy[fpos]) --
           (xpart urxy[rpos], ypart urxy[fpos]) --
           ulxy[fpos] -- llxy[fpos]  -- cycle ;
    mxy := (xpart llxy[lpos], ypart ulxy[tpos]) --
           (xpart llxy[rpos], ypart ulxy[tpos]) --
           (xpart lrxy[rpos], ypart lrxy[fpos]) --
           (xpart llxy[lpos], ypart llxy[fpos]) -- cycle ;
    bxy := (xpart llxy[lpos], ypart llxy[tpos]) --
           (xpart righxy, ypart lrxy[tpos]) --
           (xpart righxy, ypart urxy[tpos]) --
           (xpart llxy[lpos], ypart ulxy[tpos]) -- cycle ;

    if (round(point 0 of bxy) = round(point 1 of bxy)) or
       (round(point 0 of bxy) = round(point 2 of bxy)) :
      bxy := origin ;
    fi ;

    if (round(point 0 of mxy) = round(point 1 of mxy)) or
       (round(point 0 of mxy) = round(point 2 of mxy)) :
      mxy := origin ;
    fi ;

    if (round(point 0 of txy) = round(point 1 of txy)) or
       (round(point 0 of txy) = round(point 2 of txy)) :
      txy := origin ;
    fi ;

    if (round (length(mxy)) > 1) :
      if (round (length(txy)) < 2) :
        if (round (length(bxy)) < 2) :
          pxy := mxy ;
        else :
          pxy := point 0 of bxy -- point 1 of bxy -- point 2 of bxy --
                 point 1 of mxy -- point 2 of mxy -- point 3 of mxy --
                 cycle ;
        fi ;
      else :
        if (round (length(bxy)) < 2) :
          pxy := point 1 of mxy --
                 point 1 of txy -- point 2 of txy -- point 3 of txy --
                 point 3 of mxy -- point 0 of mxy --
                 cycle ;
        else : 
          pxy := point 1 of mxy --
                 point 1 of txy -- point 2 of txy -- point 3 of txy --
                 point 3 of mxy -- 
                 point 0 of bxy -- point 1 of bxy -- point 2 of bxy --
                 cycle ;
        fi ; 
      fi ;
    fi ;

  fi ;

enddef ;

color boxfillcolor ; boxfillcolor := .8white ;
color boxlinecolor ; boxlinecolor := .8blue  ;

def draw_box =
  pickup pencircle scaled .5 ;
  draw pxy withcolor boxlinecolor ;
  draw lxy -- rxy withcolor boxlinecolor ;
% pickup pencircle scaled 1.5 ;
% draw llxy withcolor green ;
% draw lrxy withcolor green ;
% draw urxy withcolor green ;
% draw ulxy withcolor green ;
% draw cxy withcolor red ;
% pickup pencircle scaled 1 ;
% draw lxy withcolor red ;
% draw rxy withcolor red ;
enddef ;

def draw_par =
  pickup pencircle scaled .5 ;
  if length pxy > 1 :
    fill pxy withcolor boxfillcolor ; draw pxy withcolor boxlinecolor ;
  else :
    draw_par_top ; draw_par_mid ; draw_par_bot ;
  fi ;
% pickup pencircle scaled 1.5 ;
% draw llxy[lpos] withcolor red ;
% draw llxy[rpos] withcolor red ;
% draw llxy[tpos] withcolor green ;
% draw llxy[fpos] withcolor green ;
enddef ;

def draw_par_top =
  pickup pencircle scaled .5 ;
  if length txy > 1 :
    fill txy withcolor boxfillcolor ; draw txy withcolor boxlinecolor ;
  fi ;
enddef ;

def draw_par_mid =
  pickup pencircle scaled .5 ;
  if length mxy > 1 :
    fill mxy withcolor boxfillcolor ; draw mxy withcolor boxlinecolor ;
  fi ;
enddef ;

def draw_par_bot =
  pickup pencircle scaled .5 ;
  if length bxy > 1 :
    fill bxy withcolor boxfillcolor ; draw bxy withcolor boxlinecolor ;
  fi ;
enddef ;

def anchor_box (expr n,x,y,w,h,d) =
% bboxmargin := 0 ;
% setbounds currentpicture to unitsquare shifted (x,y) ;
  currentpicture := currentpicture shifted (-x,-y) ;
enddef ;

let draw_area   = draw_box ;
let anchor_area = anchor_box ;
let anchor_par  = anchor_box ;

endinput ; 
