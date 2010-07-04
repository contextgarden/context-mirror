%D \module
%D   [       file=mp-shap.mp,
%D        version=2000.05.31, 
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=shapes,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
%C details. 

if unknown context_tool :    input mp-tool ; fi ; 
if   known context_shap : endinput         ; fi ; 

boolean context_shap ; context_shap := true ; 

vardef some_shape_path (expr type) =

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

    elseif type=61 : 
      border := normal (fullcircle scaled (1.5*yradius) xscaled (grid_height/grid_width)) ;
    elseif type=62 : 
      border := normal (fullcircle scaled (2.0*yradius) xscaled (grid_height/grid_width)) ;

    elseif type=66 :
      border := normal (rc--origin shifted ( epsilon,0) --cycle & 
                        rc--origin                      --cycle ) ;
    elseif type=67 :
      border := normal (lc--origin shifted (-epsilon,0) --cycle & 
                        lc--origin                      --cycle ) ;
    elseif type=68 :
      border := normal (tc--origin shifted (0, epsilon) --cycle & 
                        tc--origin                      --cycle ) ;
    elseif type=69 :
      border := normal (bc--origin shifted (0,-epsilon) --cycle & 
                        bc--origin                      --cycle ) ;

    elseif type=75 : 
      border := mirror (lly--lry--ury--uly--cycle) ;
    elseif type=76 : 
      border := mirror (ll--lr--ur--uly--cycle) ;
    elseif type=77 : 
      border := mirror (ll--lr--ury--ul--cycle) ;
    elseif type=78 : 
      border := mirror (lly--lr--ur--ul--cycle) ;
    elseif type=79 : 
      border := mirror (ll--lry--ur--ul--cycle) ;

    else :
      border := normal (origin--cycle) ;
     %border := normal (ll--lr--ur--ul--cycle) ;
    fi ;

    border

    endgroup

enddef;

def some_shape ( expr shape_type      , 
                      shape_width     , 
                      shape_height    , 
                      shape_linewidth , 
                      shape_linecolor ,     
                      shape_fillcolor ) = 

  path p ; p := 
    some_shape_path (shape_type) 
      xscaled shape_width 
      yscaled shape_height ; 

  pickup pencircle scaled shape_linewidth ;

  fill p withcolor shape_fillcolor ; 
  draw p withcolor shape_linecolor ; 
 
enddef ; 

vardef drawshape (expr t, p, lw, lc, fc) =
  save pp ; 
  if t>1 : % normal shape
    path pp ;
    pp := some_shape_path(t) xyscaled(bbwidth(p), bbheight(p)) shifted center p ;
    fill pp withcolor fc ;
    draw pp withpen pencircle scaled lw withcolor lc ;
  elseif t=1 : % background only 
    path pp ; 
    pp := fullsquare xyscaled(bbwidth(p), bbheight(p)) shifted center p ;
    fill pp withcolor fc ;
  else : % dimensions only 
    picture pp ; pp := nullpicture ; 
    setbounds pp to fullsquare xyscaled(bbwidth(p), bbheight(p)) shifted center p ;
    draw pp ; 
  fi ; 
enddef ;

vardef drawline (expr t, p, lw, lc) =
  if (t>0) and (length(p)>1) :
    saveoptions ;
    drawoptions(withpen pencircle scaled lw withcolor lc) ;
    draw p ;
    if     t =  1 : 
      draw arrowheadonpath(p,1) ;
    elseif t =  2 :
      draw arrowheadonpath(reverse p,1) ;
    elseif t =  3 :
      for $ = p,reverse p : draw arrowheadonpath($,1) ; endfor ; 
    elseif t = 11 :
      draw arrowheadonpath(p,1/2) ;
    elseif t = 12 :
      draw arrowheadonpath(reverse p,1/2) ;
    elseif t = 13 :
      for $=p,reverse p : draw arrowheadonpath($,1) ; endfor ;
      for $=p,reverse p : draw arrowheadonpath($,3/4) ; endfor ;
    elseif t = 21 :
      for $=1/5,1/2,4/5 : draw arrowheadonpath(p,$) ; endfor ;
    elseif t = 22 :
      for $=1/5,1/2,4/5 : draw arrowheadonpath(reverse p,$) ; endfor ;
    elseif t = 23 :
      for $=p,reverse p : draw arrowheadonpath($,1/4) ; endfor ;
    fi ;
  fi ; 
enddef ;

endinput ;  
