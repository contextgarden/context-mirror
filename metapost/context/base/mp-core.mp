%D \module
%D   [       file=mp-core.mp,
%D        version=2000.something, % 1999.08.12,
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

pair    lxy[], rxy[], cxy[], llxy[], lrxy[], ulxy[], urxy[] ;
path    pxy[] ;
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

def set_par_line_height (expr ph, pd) =
  par_strut_height :=
    if ph>0 : ph elseif StrutHeight>0 : StrutHeight else : 8pt fi ;
  par_strut_depth  :=
    if pd>0 : pd elseif StrutDepth >0 : StrutDepth  else : 3pt fi ;
  par_line_height  :=
    par_strut_height + par_strut_depth ;
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

  set_par_line_height (ph, pd) ;

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

  set_par_line_height (wh, wd) ;

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

TopSkip     := 0 ; % will move
StrutHeight := 0 ; % will move

pair last_multi_par_shift ; last_multi_par_shift := origin ;

def relocate_multipars (expr xy) =
  last_multi_par_shift := xy ;
  for i=1 upto nofmultipars :
    multipars[i] := multipars[i] shifted last_multi_par_shift ;
  endfor ;
enddef ;

boolean compensate_multi_par_topskip ;
boolean span_multi_column_pars ;
boolean auto_multi_par_hsize ;
boolean enable_multi_par_fallback ;

compensate_multi_par_topskip := true ;
span_multi_column_pars       := false ;
auto_multi_par_hsize         := false ; % true ;
enable_multi_par_fallback    := true ;

vardef multi_par_at_top (expr i) =
  (round (ypart ulcorner multipars[i]) = round (ypart ulcorner
     (TextAreas[multirefs[i]] shifted last_multi_par_shift)))
enddef ;

numeric nofmultipars ; nofmultipars := 0 ;

boolean obey_multi_par_hang    ; obey_multi_par_hang    := true  ;
boolean obey_multi_par_more    ; obey_multi_par_more    := true  ;
boolean snap_multi_par_tops    ; snap_multi_par_tops    := true  ;
boolean local_multi_par_area   ; local_multi_par_area   := false ;
boolean ignore_multi_par_page  ; ignore_multi_par_page  := false ;
boolean force_multi_par_chain  ; force_multi_par_chain  := true  ;
boolean one_piece_multi_par    ; one_piece_multi_par    := false ;
boolean check_multi_par_chain  ; check_multi_par_chain  := true  ; % extra page check

def simplify_multi_pars = % boundingbox ipv shape als optie
  for i := 1 upto nofmultipars :
    multipars[i] := boundingbox multipars[i] ;
  endfor ;
enddef ;

def save_multipar (expr i, l, p) =
  nofmultipars := nofmultipars + 1 ;
  multirefs[nofmultipars] := i ;
  multilocs[nofmultipars] := l ;
  multipars[nofmultipars] := unspiked (simplified p) ;
enddef ;

def prepare_multi_pars (expr fn,fx,fy,fw,fh,fd,
                             tn,tx,ty,tw,th,td,
                             wn,wx,wy,ww,wh,wd,
                             pn,px,py,pw,ph,pd,
                             rw,rl,rr,rh,ra,ri) =

  if span_multi_column_pars :
    begingroup ;
    save TextAreas ; path TextAreas[] ;
    save NOfTextAreas ; numeric NOfTextAreas ;
    for i=1 upto NOfTextColumns :
      TextAreas[i] := TextColumns[i] ;
    endfor ;
    NOfTextAreas := NOfTextColumns ;
  fi ;

  last_multi_par_shift := origin ;

  numeric fpos ; fpos := 1 ; initialize_box_pos(fpos,fn,fx,fy,fw,fh,fd) ;
  numeric tpos ; tpos := 2 ; initialize_box_pos(tpos,tn,tx,ty,tw,th,td) ;
  numeric wpos ; wpos := 3 ; initialize_box_pos(wpos,wn,wx,wy,ww,wh,wd) ;
  numeric ppos ; ppos := 4 ; initialize_box_pos(ppos,pn,px,py,pw,ph,pd) ;

  if local_multi_par_area :
    RealPageNumber := fn ;
    NOfTextAreas := 1 ;
    NOfSavedTextAreas := 0 ;
    TextAreas[1] := TextAreas[0] ;
    TextColumns[1] := TextColumns[0] ;
    nxy[fpos] := nxy[tpos] := nxy[wpos] := nxy[ppos] := RealPageNumber ;
   % draw TextColumns[1] withcolor green ;
   % draw TextAreas[1] withcolor green ;
  elseif ignore_multi_par_page :
    RealPageNumber := fn ;
    nxy[fpos] := nxy[tpos] := nxy[wpos] := nxy[ppos] := RealPageNumber ;
  fi ;

  numeric par_strut_height, par_strut_depth, par_line_height ;

  set_par_line_height (ph, pd) ;

  numeric par_hang_indent, par_hang_after, par_indent, par_left_skip ;

  par_hang_indent  := rh ;
  par_hang_after   := ra ;
  par_indent       := ri ;
  par_left_skip    := rl ;

  pair par_start_pos ;

% par_start_pos := llxy[fpos] if par_indent<0: shifted (-par_indent,0) fi ;

  par_start_pos := llxy[fpos]
    if par_indent   <0: shifted (-par_indent,   0) fi
    if par_left_skip<0: shifted (-par_left_skip,0) fi ;

  if wxy[wpos]>0 :
    left_skip  := rl + xpart llxy[wpos] - xpart llxy[ppos] ;
    right_skip := rw - left_skip - ww ;
  else :
    left_skip  := rl ;
    right_skip := rr ;
  fi ;

  path    multipar, multipars[] ;
  numeric multiref, multirefs[] ;
  numeric multiloc, multilocs[] ; % 1=begin 2=between 3=end

  numeric multi_par_pages ; multi_par_pages := nxy[tpos]-nxy[fpos]+1 ;

  ii := 0 ; nn := NOfTextAreas+1 ; nofmultipars := 0 ;

  vardef snapped_multi_pos (expr p) =
    if snap_multi_par_tops :
      if abs(ypart p - ypart ulcorner multipar) < par_line_height :
        (xpart p,ypart ulcorner multipar)
      else :
        p
      fi
    else :
      p
    fi
  enddef ;

  % def set_multipar (expr i) =
  %   ((TextAreas[i] leftenlarged -left_skip) rightenlarged -right_skip)
  % enddef ;

  vardef set_multipar (expr i) =
    ( (TextAreas[i] leftenlarged -left_skip) rightenlarged (-right_skip
      if auto_multi_par_hsize : + rw - bbwidth(TextAreas[i]) fi) )
  enddef ;

  vardef top_multi_par(expr p) =
    (round(estimated_par_lines(bbheight(p)*par_line_height))=round(bbheight(p)))
  enddef ;

  vardef multi_par_tsc(expr p) =
    if top_multi_par(p) : TopSkipCorrection else : 0 fi
  enddef ;

  vardef estimated_par_lines (expr h) =
    round(h/par_line_height)
  enddef ;

  vardef estimated_multi_par_height (expr n, t) =
    if round(par_line_height)=0 :
      0
    else :
      save ok, h ; boolean ok ;
      numeric h ; h := 0 ;
      ok := false ;
      if (nxy[fpos]=RealPageNumber-1) :
        for i := 1 upto NOfSavedTextAreas :
          if (InsideSavedTextArea(i,par_start_pos)) :
            ok := true ;
            h := h + estimated_par_lines(ypart ulxy[fpos] -
                   ypart llcorner SavedTextAreas[i]) ;
          elseif ok :
            h := h + estimated_par_lines(bbheight(SavedTextAreas[i])) ;
          fi ;
        endfor ;
      fi ;
      if ok :
        for i := 1 upto n-1 :
          h := h + estimated_par_lines(bbheight(TextAreas[i])) ;
        endfor ;
      else :
        % already: ok := false ;
        for i := 1 upto n-1 :
          if (InsideTextArea(i,par_start_pos)) :
            ok := true ;
            h := h + estimated_par_lines(ypart ulxy[fpos] - ypart llcorner TextAreas[i]) ;
          elseif ok :
            h := h + estimated_par_lines(bbheight(TextAreas[i])) ;
          fi ;
        endfor ;
      fi ;
      h
    fi
  enddef ;

  vardef left_top_hang (expr same_area) =

par_hang_after := ra + estimated_par_lines(py-fy) ;

    if (par_hang_indent>0) and (par_hang_after<0) and obey_multi_par_hang :
      pair _ul_ ; _ul_ := (xpart ulcorner multipar, ypart snapped_multi_pos(ulxy[fpos]));
      pair _pa_ ; _pa_ := _ul_ shifted (0,par_hang_after*par_line_height) ;
%       _pa_ := (xpart _pa_,max(ypart _pa_,ypart llcorner multipar)) ;
      _pa_ := (xpart _pa_,max(ypart _pa_ -TopSkipCorrection,ypart llcorner multipar)) ;
      if same_area :
%         _pa_ := (xpart _pa_,max(ypart _pa_,ypart llxy[tpos])) ;
        _pa_ := (xpart _pa_,max(ypart _pa_ -TopSkipCorrection,ypart llxy[tpos])) ;
      fi ;
      if obey_multi_par_more and (round(par_line_height)>0) :
        par_hang_after := min(0,round(par_hang_after +
          (ypart urxy[fpos]-ypart _pa_)/par_line_height)) ;
      fi ;
      (xpart _ul_ + par_hang_indent, ypart lrxy[fpos]) --
      (xpart _ul_ + par_hang_indent, ypart _pa_) --
      (xpart ulcorner multipar, ypart _pa_)
    else :
      (xpart ulcorner multipar, ypart lrxy[fpos])
    fi
  enddef ;

  vardef right_top_hang (expr same_area) =

% par_hang_after := ra - estimated_par_lines(py-fy) ;
par_hang_after := ra + estimated_par_lines(py-fy) ;

    if (par_hang_indent<0) and (par_hang_after<0) and obey_multi_par_hang :
      pair _ur_ ; _ur_ := (xpart urcorner multipar, ypart snapped_multi_pos(urxy[fpos])) ;
      pair _pa_ ; _pa_ := _ur_ shifted (0,par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_ -TopSkipCorrection,ypart llcorner multipar)) ;
      if same_area :
        _pa_ := (xpart _pa_,max(ypart _pa_ -TopSkipCorrection,ypart snapped_multi_pos(ulxy[tpos]))) ;
      fi ;
      if obey_multi_par_more and (round(par_line_height)>0) :
        par_hang_after := min(0,round(par_hang_after +
          (ypart urxy[fpos]-ypart _pa_)/par_line_height)) ;
      fi ;
      (xpart urcorner multipar, ypart _pa_) --
      (xpart _ur_ + par_hang_indent, ypart _pa_) --
      (xpart _ur_ + par_hang_indent, ypart snapped_multi_pos(urxy[fpos]))
    else :
      (xpart urcorner multipar, ypart snapped_multi_pos(urxy[fpos]))
    fi
  enddef ;

  vardef x_left_top_hang (expr i, t) =
    par_hang_after := min(0,ra + estimated_multi_par_height(i,t)) ;
    if (par_hang_indent>0) and (par_hang_after<0) :
      pair _ul_ ; _ul_ := ulcorner multipar ;
      pair _pa_ ; _pa_ := _ul_ shifted (0,par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart llcorner multipar)) ;

if t :
  _pa_ := (xpart _pa_,max(ypart _pa_,ypart llxy[tpos]));
fi ;
if abs(ypart _pa_-ypart llxy[tpos])<par_line_height :
  _pa_ := (xpart _pa_,ypart llxy[tpos]);
fi ;
if abs(ypart _pa_-ypart llcorner multipar)<par_line_height :
  _pa_ := (xpart _pa_,ypart llcorner multipar);
fi ;

      (xpart _ul_, ypart _pa_) --
      (xpart _ul_ + par_hang_indent, ypart _pa_) --
      (xpart _ul_ + par_hang_indent, ypart _ul_)
    else :
      ulcorner multipar
    fi
  enddef ;

% here

  vardef x_right_top_hang (expr i, t) =
    par_hang_after := min(0,ra + estimated_multi_par_height(i,t)) ;
    if (par_hang_indent<0) and (par_hang_after<0) :
      pair _ur_ ; _ur_ := urcorner multipar ;
      pair _pa_ ; _pa_ := _ur_ shifted (0,par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart lrcorner multipar)) ;
if t :
  _pa_ := (xpart _pa_,max(ypart _pa_,ypart snapped_multi_pos(urxy[tpos]))) ;
fi ;

%todo
%
%if abs(ypart _pa_-ypart llxy[tpos])<par_line_height :
%  _pa_ := (xpart _pa_,ypart llxy[tpos]);
%fi ;
%if abs(ypart _pa_-ypart llcorner multipar)<par_line_height :
%  _pa_ := (xpart _pa_,ypart llcorner multipar);
%fi ;

      (xpart _ur_ + par_hang_indent, ypart _ur_) --
      (xpart _ur_ + par_hang_indent, ypart _pa_) --
      (xpart _ur_, ypart _pa_)
    else :
      urcorner multipar
    fi
  enddef ;

  vardef left_bottom_hang (expr same_area) =
    pair _ll_, _sa_, _pa_ ;
    _sa_ := if same_area : llxy[tpos] else : lrcorner multipar fi ;
    if (par_hang_indent>0) and (par_hang_after>0) and obey_multi_par_hang :
      _ll_ := (xpart ulcorner multipar, ypart snapped_multi_pos(ulxy[fpos])) ;
      _pa_ := _ll_ shifted (0,-par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart llcorner multipar)) ;
      if same_area :
        _pa_ := (xpart _pa_,max(ypart _pa_,ypart _sa_)) ;
      fi ;
      if obey_multi_par_more and (round(par_line_height)>0) :
        par_hang_after := max(0,round(par_hang_after -
          (ypart urxy[fpos]-ypart _pa_)/par_line_height)) ;
      fi ;
      _pa_ --
      (xpart _pa_ + par_hang_indent,ypart _pa_) --
      (xpart _pa_ + par_hang_indent,ypart _sa_)
    else :
      (xpart llcorner multipar, ypart _sa_)
    fi
  enddef ;

  vardef right_bottom_hang (expr same_area) =
    pair _lr_, _sa_, _pa_ ;
    _sa_ := if same_area : snapped_multi_pos(ulxy[tpos]) else : lrcorner multipar fi ;
    if (par_hang_indent<0) and (par_hang_after>0) and obey_multi_par_hang :
      _lr_ := (xpart urcorner multipar, ypart snapped_multi_pos(urxy[fpos])) ;
      _pa_ := _lr_ shifted (0,-par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart lrcorner multipar)) ;
      if same_area :
        _pa_ := (xpart _pa_,max(ypart _pa_,ypart snapped_multi_pos(ulxy[tpos]))) ;
      fi ;
      if obey_multi_par_more and (round(par_line_height)>0) :
        par_hang_after := max(0,round(par_hang_after -
          (ypart urxy[fpos]-ypart _pa_)/par_line_height)) ;
      fi ;
      (xpart _pa_ + par_hang_indent,ypart _sa_) --
      (xpart _pa_ + par_hang_indent,ypart _pa_) --
      _pa_
    else :
     (xpart lrcorner multipar, ypart _sa_)
    fi
  enddef ;

  vardef x_left_bottom_hang (expr i, t) =
    pair _ll_, _sa_, _pa_ ;
    _sa_ := if t : llxy[tpos] else : llcorner multipar fi ;
    if (par_hang_indent>0) and (ra>0) :
      par_hang_after := max(0,ra - estimated_multi_par_height(i,t)) ;
      _ll_ := ulcorner multipar ;
      _pa_ := _ll_ shifted (0,-par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart llcorner multipar)) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart _sa_)) ;
      % we need to compensate for topskip enlarged areas
      if abs(ypart _pa_ - ypart _sa_) > par_line_height :
        (xpart _pa_ + par_hang_indent,ypart _sa_) --
        (xpart _pa_ + par_hang_indent,ypart _pa_) --
      fi
      _pa_
    else :
      (xpart llcorner multipar, ypart _sa_)
    fi
  enddef ;

  vardef x_right_bottom_hang (expr i, t) =
    pair _lr_, _sa_, _pa_ ;
    _sa_ := if t : snapped_multi_pos(ulxy[tpos]) else : llcorner multipar fi ;
    if (par_hang_indent<0) and (ra>0) :
      par_hang_after := max(0,ra - estimated_multi_par_height(i, t)) ;
      _lr_ := urcorner multipar ;
      _pa_ := _lr_ shifted (0,-par_hang_after*par_line_height) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart lrcorner multipar)) ;
      _pa_ := (xpart _pa_,max(ypart _pa_,ypart _sa_)) ;
      % we need to compensate for topskip enlarged areas
      _pa_
      if abs(ypart _pa_ - ypart _sa_) > par_line_height :
        -- (xpart _pa_ + par_hang_indent,ypart _pa_)
        -- (xpart _pa_ + par_hang_indent,ypart _sa_)
      fi
    else :
     (xpart lrcorner multipar, ypart _sa_)
    fi
  enddef ;

  def test_multipar =
%     multipar :=
%       llcorner multipar --
%       urcorner multipar --
%       lrcorner multipar --
%       ulcorner multipar --
%       cycle ;
    multipar := boundingbox multipar ;
  enddef ;

  % first loop

  if enable_multi_par_fallback  and
     (nxy[fpos]=RealPageNumber) and
     (nxy[tpos]=RealPageNumber) and not
     (InsideSomeTextArea(lxy[fpos]) and
      InsideSomeTextArea(rxy[tpos])) :

  % fallback

    % multipar :=
    %   llxy[fpos] --
    %   lrxy[tpos] --
    %   urxy[tpos] --
    %   ulxy[fpos] -- cycle ;
    %
    % save_multipar (1,1,multipar) ;

    % we need to take the boundingbox because there can be
    % more lines and we want a proper rectange

    multipar :=
      ulxy[fpos] --
      urxy[tpos] --
      lrxy[fpos] --
      llxy[tpos] -- cycle ;

    save_multipar (1,1,boundingbox(multipar)) ;

  else :

  % normal

  for i=1 upto NOfTextAreas :

    TopSkipCorrection := 0 ;

    multipar := set_multipar(i) ;

    % watch how we compensate for negative indentation

    if (nxy[fpos]=RealPageNumber) and (InsideTextArea(i,par_start_pos)) :

      % first one in chain

      ii := i ;

      if (nxy[tpos]=RealPageNumber) and (InsideTextArea(i,llxy[tpos])) :

        % in same area

        nn := i ;

        if compensate_multi_par_topskip and (round(LineHeight-ph-pd)=0) :

          TopSkipCorrection := TopSkip - StrutHeight ;

          if round(ypart ulxy[fpos] + TopSkipCorrection) =
             round(ypart ulcorner TextAreas[i]) :
            ulxy[fpos] := ulxy[fpos] shifted (0,TopSkipCorrection) ;
            urxy[fpos] := urxy[fpos] shifted (0,TopSkipCorrection) ;
          else :
            TopSkipCorrection := 0 ;
          fi ;

        fi ;

        if ypart llxy[fpos] = ypart llxy[tpos] :

          multipar :=
            llxy[fpos] --
            lrxy[tpos] --
           %urxy[tpos] --
            snapped_multi_pos(urxy[tpos]) --
           %ulxy[fpos] --
            snapped_multi_pos(ulxy[fpos]) --
            cycle ;

          save_multipar (i,1,multipar) ;

        elseif (ypart llxy[fpos] = ypart ulxy[tpos]) and
               (xpart llxy[tpos] < xpart llxy[fpos]) :

          % two loners

          multipar := if obey_multi_par_hang :

            right_bottom_hang(true) --
            right_top_hang(true) --
            snapped_multi_pos(urxy[fpos]) --
            lrxy[fpos] --

          else :

            llxy[fpos] --
            (xpart urcorner multipar, ypart llxy[fpos]) --
            (xpart urcorner multipar, ypart ulxy[fpos]) --
            snapped_multi_pos(ulxy[fpos]) --

          fi cycle ;

          save_multipar (i,1,multipar) ;

          multipar := set_multipar(i) ;

          multipar := if obey_multi_par_hang :

            left_bottom_hang(true) --
            llxy[tpos] --
            snapped_multi_pos(ulxy[tpos]) --
            left_top_hang(true) --

          else :

            (xpart llcorner multipar, ypart llxy[tpos]) --
            llxy[tpos] --
            snapped_multi_pos(ulxy[tpos]) --
            (xpart llcorner multipar, ypart ulxy[tpos]) --

          fi cycle ;

          save_multipar (i,1,multipar) ;

        else :

          multipar := if obey_multi_par_hang :

            left_bottom_hang(true) --
            llxy[tpos] --
           %ulxy[tpos] --
            snapped_multi_pos(ulxy[tpos]) --
            right_bottom_hang(true) --
            right_top_hang(true) --
           %urxy[fpos] --
            snapped_multi_pos(urxy[fpos]) --
            lrxy[fpos] --
            left_top_hang(true) --

          else :

            (xpart llcorner multipar, ypart llxy[tpos]) --
            llxy[tpos] --
           %ulxy[tpos] --
            snapped_multi_pos(ulxy[tpos]) --
            (xpart lrcorner multipar, ypart ulxy[tpos]) --
            (xpart urcorner multipar, ypart urxy[fpos]) --
           %urxy[fpos] --
            snapped_multi_pos(urxy[fpos]) --
            lrxy[fpos] --
            (xpart ulcorner multipar, ypart lrxy[fpos]) --

          fi cycle ;

          save_multipar (i,1,multipar) ;

        fi ;

      else :

        multipar := if obey_multi_par_hang :

          left_bottom_hang(false) --
          right_bottom_hang(false) --
          right_top_hang(false) --
         %urxy[fpos] --
          snapped_multi_pos(urxy[fpos]) --
          lrxy[fpos] --
          left_top_hang(false) --

        else :

          llcorner multipar --
          lrcorner multipar --
          (xpart urcorner multipar, ypart urxy[fpos]) --
         %urxy[fpos] --
          snapped_multi_pos(urxy[fpos]) --
          lrxy[fpos] --
          (xpart ulcorner multipar, ypart lrxy[fpos]) --

        fi cycle ;

        save_multipar (i,1,multipar) ;

      fi ;

    elseif (nxy[tpos]=RealPageNumber) and (InsideTextArea(i,llxy[tpos])) :

      % last one in chain

      nn := i ;

      if obey_multi_par_hang and obey_multi_par_more :

        multipar :=
          x_left_top_hang(i,true) --
          x_right_top_hang(i,true) --
          x_right_bottom_hang(i,true) --
%          ulxy[tpos] --
snapped_multi_pos(ulxy[tpos]) --
          llxy[tpos] --
          x_left_bottom_hang(i,true) --
          cycle ;

      else :

        multipar :=
          ulcorner multipar --
          urcorner multipar --
          (xpart lrcorner multipar, ypart urxy[tpos]) --
%          ulxy[tpos] --
snapped_multi_pos(ulxy[tpos]) --
          llxy[tpos] --
          (xpart llcorner multipar, ypart llxy[tpos]) --
          cycle ;

      fi ;

      save_multipar (i,3,multipar) ;

    else :

      % handled later

    fi ;

  endfor ;

  % second loop

if force_multi_par_chain or (ii > 1) :

  for i=ii+1 upto nn-1 :

    % rest of chain / todo : hang

% we need to test, else we get a <lineheight bottom one
% triggering a whole text frame; weird

if (not check_multi_par_chain) or ((nxy[fpos]<RealPageNumber) and (nxy[tpos]>RealPageNumber)) :

    multipar := set_multipar(i) ;

    if obey_multi_par_hang and obey_multi_par_more :

      multipar :=
        x_left_top_hang(i,false) --
        x_right_top_hang(i,false) --
        x_right_bottom_hang(i,false) --
        x_left_bottom_hang(i,false) --
        cycle ;

    fi ;

    save_multipar(i,2,multipar) ;

fi ;

  endfor ;

fi ;

  % end of normal/fallback

fi ;

  if span_multi_column_pars :
    endgroup ;
  fi ;

  % potential safeguard:

  % for i=1 upto nofmultipars :
  %   if length p <= 4 :
  %     multipars[i] := boundingbox(multipars[i]) ;
  %   fi ;
  % end ;

  % quick hack for gb:

  one_piece_multi_par := (nofmultipars=1) and (pn=tn) ;

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
numeric boxfilloffset    ; boxfilloffset    := 0pt ;
numeric boxgriddistance  ; boxgriddistance  := .5cm ;

def draw_box =
  draw pxy withcolor boxlinecolor withpen pencircle scaled boxlinewidth ;
  draw lxy -- rxy withcolor boxlinecolor withpen pencircle scaled boxgridwidth ;
enddef ;

def draw_par  = % 1 2 3 11 12
  do_draw_par(pxy) ; do_draw_par(txy) ; do_draw_par(bxy) ;
  for i = pxy, txy, bxy :
        if boxgridtype = 1 :
      boxgriddirection := origin ;
      draw baseline_grid (i,boxgriddirection,true ) withcolor boxgridcolor ;
    elseif boxgridtype = 2 :
      boxgriddirection := origin ;
      draw baseline_grid (i,boxgriddirection,false) withcolor boxgridcolor ;
    elseif boxgridtype = 3 :
      boxgriddirection := origin ;
      draw baseline_grid (i,boxgriddirection,true ) withcolor boxgridcolor ;
      draw baseline_grid (i,boxgriddirection,true )
        shifted (0,ExHeight) withcolor boxgridcolor ;
    elseif boxgridtype = 4 :
      boxgriddirection := origin ;
      draw baseline_grid (i,boxgriddirection,true )
        shifted (0,ExHeight/2) withcolor boxgridcolor ;
    elseif boxgridtype = 11 :
      draw graphic_grid(i,boxgriddistance,boxgriddistance,boxgriddistance/2,boxgriddistance/2) ;
    elseif boxgridtype = 12 :
      draw graphic_grid(i,boxgriddistance,boxgriddistance,0,0) ;
    fi ;
  endfor ;
enddef ;

def do_show_par (expr p, r, c) =
  if length(p) > 2 : for i=0 upto length(p) :
    draw fullcircle scaled r shifted point i of p
      withpen pencircle scaled .5pt withcolor c ;
  endfor ; fi ;
  draw p withpen pencircle scaled .5pt withcolor c ;
enddef ;

def show_par  =
  if length(mxy) > 2 :
    draw mxy dashed evenly
      withpen pencircle scaled .5pt withcolor .5white ;
  fi ;
  do_show_par(txy, 4pt, .5green) ;
  do_show_par(bxy, 6pt, .5blue ) ;
  do_show_par(pxy, 8pt, .5red  ) ;
  draw pref withpen pencircle scaled 2pt ;
enddef ;

def sort_multi_pars =
  if nofmultipars>1 :
    begingroup ; save _p_, _n_ ; path _p_ ; numeric _n_ ;
      for i := 1 upto nofmultipars :
        if multilocs[i] = 3 :
          _p_ := multipars[nofmultipars] ;
          multipars[nofmultipars] := multipars[i] ;
          multipars[i] := _p_ ;
          _n_ := multirefs[nofmultipars] ;
          multirefs[nofmultipars] := multirefs[i] ;
          multirefs[i] := _n_ ;
          _n_ := multilocs[nofmultipars] ;
          multilocs[nofmultipars] := multilocs[i] ;
          multilocs[i] := _n_ ;
        fi ;
      endfor ;
    endgroup ;
  fi ;
enddef ;

% This collapses successive areas (possibly interrupted by
% floats. First we need to sort the areas, since they are
% normally in de order start, end, inbetween.

def collapse_multi_pars =
  if nofmultipars>1 :
    begingroup ; save _nofmultipars_ ; numeric _nofmultipars_ ;
    _nofmultipars_ := 1 ;
    sort_multi_pars ; % block not in order: 1, 3, 2....
    for i:=1 upto nofmultipars-1 :
      if (round(xpart(llcorner multipars[i]-llcorner multipars[i+1]))=0) and
         (round(xpart(lrcorner multipars[i]-lrcorner multipars[i+1]))=0) :
multilocs[_nofmultipars_] := multilocs[i+1] ;
multirefs[_nofmultipars_] := multirefs[i+1] ;
        multipars[_nofmultipars_] :=
          ulcorner multipars[_nofmultipars_] --
          urcorner multipars[_nofmultipars_] --
          lrcorner multipars[i+1] --
          llcorner multipars[i+1] -- cycle ;
      else :
        _nofmultipars_ := _nofmultipars_ + 1 ;
        multipars[_nofmultipars_] := multipars[i+1] ;
        multilocs[_nofmultipars_] := multilocs[i+1] ;
        multirefs[_nofmultipars_] := multirefs[i+1] ;
      fi  ;
    endfor ;
    nofmultipars := _nofmultipars_ ;
    endgroup ;
  fi ;
enddef ;

def draw_multi_pars  =
  for i=1 upto nofmultipars :
    do_draw_par(multipars[i]) ;
        if boxgridtype= 1 :
      draw baseline_grid (multipars[i],up,true ) withcolor boxgridcolor ;
    elseif boxgridtype= 2 :
      draw baseline_grid (multipars[i],up,false) withcolor boxgridcolor ;
    elseif boxgridtype= 3 :
      draw baseline_grid (multipars[i],up,true ) withcolor boxgridcolor ;
      draw baseline_grid (multipars[i],up,true )
        shifted (0,ExHeight) withcolor boxgridcolor ;
    elseif boxgridtype= 4 :
      draw baseline_grid (multipars[i],up,true )
        shifted (0,ExHeight/2) withcolor boxgridcolor ;
    elseif boxgridtype=11 :
      draw graphic_grid(multipars[i],boxgriddistance,boxgriddistance,boxgriddistance/2,boxgriddistance/2) ;
    elseif boxgridtype=12 :
      draw graphic_grid(multipars[i],boxgriddistance,boxgriddistance,0,0) ;
    fi ;
  endfor ;
enddef ;

def show_multi_pars  =
  for i=1 upto nofmultipars :
    do_show_par(multipars[i], 6pt, .5blue) ;
  endfor ;
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
      if boxfilloffset>0 :
        % temporary hack
        begingroup ; interim linejoin := mitered ;
          filldraw pp withcolor boxfillcolor withpen pencircle scaled (2*boxfilloffset) ;
        endgroup ;
      else :
        fill pp withcolor boxfillcolor ;
      fi ;
    fi ;
    if boxlinetype>0 :
      draw pp withcolor boxlinecolor withpen pencircle scaled boxlinewidth ;
    fi ;
  fi ;
enddef ;

vardef baseline_grid (expr pxy, pdir, at_baseline) =
  if (par_line_height>0) and (bbheight(pxy)>1) and (bbwidth(pxy)>1) and (boxgridwidth>0) :
    save i, grid ; picture grid ; pair start ;
    def _do_ (expr start) =
      draw start -- start shifted (bbwidth(pxy),0)
        withpen pencircle scaled boxgridwidth
        withcolor boxgridcolor ;
    enddef ;
    grid := image
      ( %fails with inlinespace
        %
        if pdir=up :
          for i = if at_baseline : par_strut_depth else : 0 fi
                  step  par_line_height
                  until max(bbheight(pxy),par_line_height) :
            _do_ (llcorner pxy shifted (0,+i)) ;
          endfor ;
        else :
          for i = if at_baseline : par_strut_height else : 0 fi
                  step  par_line_height
                  until bbheight(pxy) :
            _do_ (ulcorner pxy shifted (0,-i)) ;
          endfor ;
        fi ;
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
        endfor ) shifted (x,y) ;
    clip grid to pxy ;
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

% new and experimental and yet undocumented

numeric sync_n[], sync_p[][], sync_w[][], sync_h[][], sync_d[][], sync_t[][] ;
pair sync_xy[][] ; color sync_c[][] ;

def ResetSyncTasks =
  path SyncPaths[] ; numeric SyncTasks[], NOfSyncPaths, CurrentSyncClass ;
  NOfSyncPaths := CurrentSyncClass := 0 ;
  if unknown SyncLeftOffset : numeric SyncLeftOffset ; SyncLeftOffset := 0          ; fi ;
  if unknown SyncWidth      : numeric SyncWidth      ; SyncWidth      := 0          ; fi ;
  if unknown SyncThreshold  : numeric SyncThreshold  ; SyncThreshold  := LineHeight ; fi ;
  if unknown SyncColor      : color   SyncColor      ; SyncColor      := .5white    ; fi ;
  if (SyncLeftOffset = 0) and (SyncWidth = 0) :
    SyncWidth := if known TextWidth : TextWidth else : -1cm fi ;
  fi ;
enddef ;

ResetSyncTasks ;

vardef SyncBox(expr n, i, leftoffset, width, topoffset, bottomoffset) =
   save o ; pair o ; o := (xpart llcorner PlainTextArea,ypart sync_xy[n][i]) ;
   o shifted (leftoffset,sync_h[n][i]+topoffset) --
   o shifted (width+leftoffset,sync_h[n][i]+topoffset) --
   o shifted (width+leftoffset,bottomoffset) --
   o shifted (leftoffset,bottomoffset) -- cycle
enddef ;

def SetSyncColor(expr n, i, c) =
  sync_c[n][i] := c ;
enddef ;

def SetSyncThreshold(expr n, i, th) =
  sync_th[n][i] := th ;
enddef ;

vardef TheSyncColor(expr n, i) =
  if known sync_c[n][i] : sync_c[n][i] else : SyncColor fi
enddef ;

vardef TheSyncThreshold(expr n, i) =
  if known sync_th[n][i] : sync_th[n][i] else : SyncThreshold fi
enddef ;

vardef PrepareSyncTasks(expr n, collapse, extendtop, prestartnext) =
  ResetSyncTasks ;
  if known sync_n[n] :
    CurrentSyncClass := n ;
    save ok, l, d ; boolean ok ; ok := false ; NOfSyncPaths := l := 0 ;
    for i=1 upto sync_n[n] :
      if RealPageNumber > sync_p[n][i] :
        l := i ;
      elseif RealPageNumber = sync_p[n][i] :
        NOfSyncPaths := NOfSyncPaths + 1 ;
        if not ok :
          if i>1 :
% not yet correct when two of the same follow each other
            if sync_t[n][i-1] = sync_t[n][i] :
              SyncPaths[NOfSyncPaths] := SyncBox(n, i, SyncLeftOffset, SyncWidth, PaperHeight, -PaperHeight) ;
              SyncTasks[NOfSyncPaths] := i ;
            else :
              SyncPaths[NOfSyncPaths] := SyncBox(n, i-1, SyncLeftOffset, SyncWidth, PaperHeight, -PaperHeight) ;
              SyncTasks[NOfSyncPaths] := i-1 ;
              NOfSyncPaths := NOfSyncPaths + 1 ;
              SyncPaths[NOfSyncPaths] := SyncBox(n, i, SyncLeftOffset, SyncWidth, 0, -PaperHeight) ;
              SyncTasks[NOfSyncPaths] := i ;
            fi ;
          else :
            SyncPaths[NOfSyncPaths] := SyncBox(n, i, SyncLeftOffset, SyncWidth, 0, -PaperHeight) ;
            SyncTasks[NOfSyncPaths] := i ;
          fi ;
        else :
          SyncPaths[NOfSyncPaths] := SyncBox(n, i, SyncLeftOffset, SyncWidth, 0, -PaperHeight) ;
          SyncTasks[NOfSyncPaths] := i ;
        fi ;
        ok := true ;
      fi ;
    endfor ;
    if (NOfSyncPaths = 0) and (l > 0) :
      NOfSyncPaths := 1 ;
      SyncPaths[NOfSyncPaths] := SyncBox(n, l, SyncLeftOffset, SyncWidth, PaperHeight, -PaperHeight) ;
      SyncTasks[NOfSyncPaths] := l ;
    fi ;
    if NOfSyncPaths > 0 :
      for i = 1 upto NOfSyncPaths-1 :
        SyncPaths[i] := topboundary SyncPaths[i] -- reverse topboundary SyncPaths[i+1] -- cycle ;
      endfor ;
      if unknown SyncThresholdMethod :
        numeric SyncThresholdMethod ; SyncThresholdMethod := 2 ;
      fi ;
      if extendtop :
        if SyncThresholdMethod = 1 :
          if NOfSyncPaths>1 :
            d := ypart (ulcorner PlainTextArea - sync_xy[n][SyncTasks[2]]) ;
            if (SyncTasks[2]>1) and (d > 0pt) and (d <= TheSyncThreshold(n,sync_t[n][SyncTasks[2]])) and (sync_p[n][SyncTasks[2]] = RealPageNumber) :
              SyncPaths[2] := SyncPaths[2] topenlarged PaperHeight ;
            fi ;
          fi ;
        else :
          for i = 1 upto NOfSyncPaths :
            d := ypart (ulcorner PlainTextArea - sync_xy[n][SyncTasks[i]]) ;
            if (d > 0) and (d <= TheSyncThreshold(n,sync_t[n][SyncTasks[i]])) and (sync_p[n][SyncTasks[i]] = RealPageNumber) :
              SyncPaths[i] := SyncPaths[i] topenlarged PaperHeight ;
            fi ;
          endfor ;
        fi ;
      fi ;
      if prestartnext :
        if NOfSyncPaths>1 :
          if SyncTasks[NOfSyncPaths] < sync_n[n] : % there is a next one
            d := ypart (ulcorner PlainTextArea - sync_xy[n][SyncTasks[NOfSyncPaths]+1]) ;
            if (d > 0) and (d <= TheSyncThreshold(n, sync_t[n][SyncTasks[i]])) and (sync_p[n][SyncTasks[NOfSyncPaths]+1] = RealPageNumber+1) :
              SyncPaths[NOfSyncPaths+1] :=
                (xpart ulcorner SyncPaths[NOfSyncPaths],ypart llcorner PlainTextArea) --
                (xpart urcorner SyncPaths[NOfSyncPaths],ypart llcorner PlainTextArea) --
                lrcorner SyncPaths[NOfSyncPaths] --
                llcorner SyncPaths[NOfSyncPaths] -- cycle ;
              SyncTasks[NOfSyncPaths+1] := SyncTasks[NOfSyncPaths]+1 ;
              NOfSyncPaths := NOfSyncPaths + 1 ;
            fi ;
          fi ;
        fi ;
      else :
        if NOfSyncPaths>1 :
          d := ypart (sync_xy[n][SyncTasks[NOfSyncPaths]] - llcorner PlainTextArea) ;
          if (d < TheSyncThreshold(n, SyncTasks[NOfSyncPaths])) :
            NOfSyncPaths := NOfSyncPaths - 1 ;
            SyncPaths[NOfSyncPaths] := SyncPaths[NOfSyncPaths] bottomenlarged PaperHeight ;
          fi ;
        fi ;
      fi ;
      if (NOfSyncPaths>1) and collapse :
        save j ; numeric j ; j := 1 ;
        for i = 2 upto NOfSyncPaths :
          if sync_t[n][SyncTasks[i]] = sync_t[n][SyncTasks[j]] :
            SyncPaths[j] := boundingbox image (draw SyncPaths[i] ; draw SyncPaths[j] ; ) ;
            SyncTasks[j] := SyncTasks[i] ;
          else :
            j := j + 1 ;
            SyncPaths[j] := SyncPaths[i] ;
            SyncTasks[j] := SyncTasks[i] ;
          fi ;
        endfor ;
        NOfSyncPaths := j ;
      fi ;
    fi ;
  fi ;
enddef ;

def SyncTask(expr n) =
  if known SyncTasks[n] : SyncTasks[n] else : 0 fi
enddef ;

def FlushSyncTasks =
  for i = 1 upto NOfSyncPaths :
    ProcessSyncTask(SyncPaths[i], TheSyncColor(CurrentSyncClass,sync_t[CurrentSyncClass][SyncTasks[i]])) ;
  endfor ;
enddef ;

def ProcessSyncTask(expr p, c) =
  fill p withcolor c ;
enddef ;

endinput ;
