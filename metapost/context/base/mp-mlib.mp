%D \module
%D   [       file=mp-mlib.mp,
%D        version=2008.03.21,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=plugins,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for
%C details.

if unknown mplib        : endinput ; fi ;
if known   context_mlib : endinput ; fi ;

boolean context_mlib ; context_mlib := true ;

%D Color and transparency

newinternal normaltransparent     ; normaltransparent     :=  1 ;
newinternal multiplytransparent   ; multiplytransparent   :=  2 ;
newinternal screentransparent     ; screentransparent     :=  3 ;
newinternal overlaytransparent    ; overlaytransparent    :=  4 ;
newinternal softlighttransparent  ; softlighttransparent  :=  5 ;
newinternal hardlighttransparent  ; hardlighttransparent  :=  6 ;
newinternal colordodgetransparent ; colordodgetransparent :=  7 ;
newinternal colorburntransparent  ; colorburntransparent  :=  8 ;
newinternal darkentransparent     ; darkentransparent     :=  9 ;
newinternal lightentransparent    ; lightentransparent    := 10 ;
newinternal differencetransparent ; differencetransparent := 11 ;
newinternal exclusiontransparent  ; exclusiontransparent  := 12 ;

def spotcolor(expr n, v) =
    1
    withprescript "sp_name="  & n
    withprescript "sp_value=" & v
enddef ;

def multitonecolor(expr name, fractions, components, value) =
    1
    withprescript "sp_name="       & name
    withprescript "sp_fractions="  & decimal fractions
    withprescript "sp_components=" & components
    withprescript "sp_value="      & value
enddef ;

def transparent(expr alternative, transparency)(text c) =
     c
     withprescript "tr_alternative="  & decimal alternative
     withprescript "tr_transparency=" & decimal transparency
enddef ;

def withtransparency(expr alternative, transparency) =
     withprescript "tr_alternative="  & decimal alternative
     withprescript "tr_transparency=" & decimal transparency
enddef ;

def cmyk(expr c, m, y, k) =
    (c,m,y,k)
enddef ;

% Texts

numeric _tt_w_[], _tt_h_[], _tt_d_[] ;
numeric _tt_n_ ; _tt_n_ := 0 ;
picture _tt_p_ ; _tt_p_ := nullpicture ;
boolean _trial_run_ ; _trial_run_ := false ;

def resettextexts =
    _tt_n_ := 0 ;
    _tt_p_ := nullpicture ;
enddef ;

def flushtextexts =
    addto currentpicture also _tt_p_
enddef ;

extra_endfig   := "flushtextexts;" & extra_endfig;
extra_beginfig := extra_beginfig & "resettextexts;";

% We collect and flush them all, as we can also have temporary textexts
% that gets never really flushed but are used for calculations. So, we
% flush twice: once in location in order to pick up e.g. color properties,
% and once at the end because we need to flush missing ones.

vardef rawtextext(expr str) =
    if str = "" :
        nullpicture
    elseif _trial_run_ :
        _tt_n_ := _tt_n_ + 1 ;
        addto _tt_p_ doublepath unitsquare
            withprescript "tx_number=" & decimal _tt_n_
            withprescript "tx_stage=extra"
            withpostscript str ;
        image (
            addto currentpicture doublepath unitsquare
                withprescript "tx_number=" & decimal _tt_n_
                withprescript "tx_stage=trial"
                withpostscript str
        )
    else :
        _tt_n_ := _tt_n_ + 1 ;
        if known _tt_d_[_tt_n_] :
            image (
                addto currentpicture doublepath unitsquare
                    xscaled _tt_w_[_tt_n_]
                    yscaled (_tt_h_[_tt_n_] + _tt_d_[_tt_n_])
                    withprescript "tx_number=" & decimal _tt_n_
                    withprescript "tx_stage=final"
                    ; % withpostscript str ;
            ) shifted (0,-_tt_d_[_tt_n_])
        else :
            image (
                addto currentpicture doublepath unitsquare ;
            )
        fi
    fi
enddef ;

% More text

pair laboff.d, laboff.dlft, laboff.drt ; % new positional suffixes
pair laboff.origin, laboff.raw         ; % graph mess

laboff.d    := laboff     ; labxf.d    := labxf     ; labyf.d    := labyf     ;
laboff.dlft := laboff.lft ; labxf.dlft := labxf.lft ; labyf.dlft := labyf.lft ;
laboff.drt  := laboff.rt  ; labxf.drt  := labxf.rt  ; labyf.drt  := labyf.rt  ;

labtype        :=  0 ; labtype.lft  :=  1 ; labtype.rt   :=  2 ;
labtype.bot    :=  3 ; labtype.top  :=  4 ; labtype.ulft :=  5 ;
labtype.urt    :=  6 ; labtype.llft :=  7 ; labtype.lrt  :=  8 ;
labtype.d      := 10 ; labtype.dlft := 11 ; labtype.drt  := 12 ;
labtype.origin :=  0 ; labtype.raw  :=  0 ;

% laboff.origin = (infinity,infinity) ; labxf.origin := 0 ; labyf.origin := 0 ;
% laboff.raw    = (infinity,infinity) ; labxf.raw    := 0 ; labyf.raw    := 0 ;

% todo: thelabel.origin("xxxx",origin) (overflows)

laboff.origin = (0,0) ; labxf.origin := 0 ; labyf.origin := 0 ;
laboff.raw    = (0,0) ; labxf.raw    := 0 ; labyf.raw    := 0 ;

pair laboff.l   ; laboff.l  = laboff.lft  ;
pair laboff.r   ; laboff.r  = laboff.rt   ;
pair laboff.b   ; laboff.b  = laboff.bot  ;
pair laboff.t   ; laboff.t  = laboff.top  ;
pair laboff.l_t ; laboff.l_t = laboff.ulft ;
pair laboff.r_t ; laboff.r_t = laboff.urt  ;
pair laboff.l_b ; laboff.l_b = laboff.llft ;
pair laboff.r_b ; laboff.r_b = laboff.lrt  ;
pair laboff.t_l ; laboff.t_l = laboff.ulft ;
pair laboff.t_r ; laboff.t_r = laboff.urt  ;
pair laboff.b_l ; laboff.b_l = laboff.llft ;
pair laboff.b_r ; laboff.b_r = laboff.lrt  ;

numeric labxf.l   ; labxf.l  = labxf.lft  ;
numeric labxf.r   ; labxf.r  = labxf.rt   ;
numeric labxf.b   ; labxf.b  = labxf.bot  ;
numeric labxf.t   ; labxf.t  = labxf.top  ;
numeric labxf.l_t ; labxf.l_t = labxf.ulft ;
numeric labxf.r_t ; labxf.r_t = labxf.urt  ;
numeric labxf.l_b ; labxf.l_b = labxf.llft ;
numeric labxf.r_b ; labxf.r_b = labxf.lrt  ;
numeric labxf.t_l ; labxf.t_l = labxf.ulft ;
numeric labxf.t_r ; labxf.t_r = labxf.urt  ;
numeric labxf.b_l ; labxf.b_l = labxf.llft ;
numeric labxf.b_r ; labxf.b_r = labxf.lrt  ;

numeric labyf.l   ; labyf.l  = labyf.lft  ;
numeric labyf.r   ; labyf.r  = labyf.rt   ;
numeric labyf.b   ; labyf.b  = labyf.bot  ;
numeric labyf.t   ; labyf.t  = labyf.top  ;
numeric labyf.l_t ; labyf.l_t = labyf.ulft ;
numeric labyf.r_t ; labyf.r_t = labyf.urt  ;
numeric labyf.l_b ; labyf.l_b = labyf.llft ;
numeric labyf.r_b ; labyf.r_b = labyf.lrt  ;
numeric labyf.t_l ; labyf.t_l = labyf.ulft ;
numeric labyf.t_r ; labyf.t_r = labyf.urt  ;
numeric labyf.b_l ; labyf.b_l = labyf.llft ;
numeric labyf.b_r ; labyf.b_r = labyf.lrt  ;

numeric labtype.l   ; labtype.l   = labtype.lft  ;
numeric labtype.r   ; labtype.r   = labtype.rt   ;
numeric labtype.b   ; labtype.b   = labtype.bot  ;
numeric labtype.t   ; labtype.t   = labtype.top  ;
numeric labtype.l_t ; labtype.l_t = labtype.ulft ;
numeric labtype.r_t ; labtype.r_t = labtype.urt  ;
numeric labtype.l_b ; labtype.l_b = labtype.llft ;
numeric labtype.r_b ; labtype.r_b = labtype.lrt  ;
numeric labtype.t_l ; labtype.t_l = labtype.ulft ;
numeric labtype.t_r ; labtype.t_r = labtype.urt  ;
numeric labtype.b_l ; labtype.b_l = labtype.llft ;
numeric labtype.b_r ; labtype.b_r = labtype.lrt  ;

vardef thetextext@#(expr p,z) = % adapted copy of thelabel@
    if string p :
        thetextext@#(rawtextext(p),z)
    else :
        p
            if (labtype@# >= 10) : shifted (0,ypart center p) fi
            shifted (z + labeloffset*laboff@# - (labxf@#*lrcorner p + labyf@#*ulcorner p + (1-labxf@#-labyf@#)*llcorner p))
    fi
enddef ;

vardef textext@#(expr txt) =
    interim labeloffset := textextoffset ;
    if string txt :
        thetextext@#(rawtextext(txt),origin)
    else :
        thetextext@#(txt,origin)
    fi
enddef ;

% \starttext
%   \startMPpage
%     numeric value ; value = 123 ;
%     label.lft(decimal value,origin) ;
%     draw "oeps" infont defaultfont ;
%   \stopMPpage
% \stoptext

vardef thelabel@#(expr s, z) =
    save p ; picture p ;
    if picture s :
        p = s ;
    else :
        p = textext("\definedfont[" & defaultfont & "]" & s) scaled defaultscale ;
    fi ;
    p shifted (z + labeloffset*laboff@# - (labxf@#*lrcorner p + labyf@#*ulcorner p + (1-labxf@#-labyf@#)*llcorner p))
enddef;

let normalinfont = infont ;

primarydef str infont name = % very naughty !
    if name = "" :
        textext(str)
    else :
        textext("\definedfont[" & name & "]" & str)
    fi
enddef ;

% Shades

newinternal shadefactor  ; shadefactor  := 1 ;
pair        shadeoffset  ; shadeoffset  := origin ;
boolean     trace_shades ; trace_shades := false ;

def set_linear_vector (suffix a,b)(expr p,n) =
    if     (n=1) : a := llcorner p ; b := urcorner p ;
    elseif (n=2) : a := lrcorner p ; b := ulcorner p ;
    elseif (n=3) : a := urcorner p ; b := llcorner p ;
    elseif (n=4) : a := ulcorner p ; b := lrcorner p ;
    elseif (n=5) : a := .5[ulcorner p,llcorner p] ; b := .5[urcorner p,lrcorner p] ;
    elseif (n=6) : a := .5[llcorner p,lrcorner p] ; b := .5[ulcorner p,urcorner p] ;
    elseif (n=7) : a := .5[lrcorner p,urcorner p] ; b := .5[llcorner p,ulcorner p] ;
    elseif (n=8) : a := .5[urcorner p,ulcorner p] ; b := .5[lrcorner p,llcorner p] ;
    else         : a := .5[ulcorner p,llcorner p] ; b := .5[urcorner p,lrcorner p] ;
    fi ;
enddef ;

def set_circular_vector (suffix ab, r)(expr p,n) =
    if     (n=1) : ab := llcorner p ;
    elseif (n=2) : ab := lrcorner p ;
    elseif (n=3) : ab := urcorner p ;
    elseif (n=4) : ab := ulcorner p ;
    else         : ab := center   p ; r := .5r ;
    fi ;
enddef ;

def circular_shade (expr p, n, ca, cb) =
    begingroup ;
        save ab, r ; pair ab ; numeric r ;
        r := (xpart lrcorner p - xpart llcorner p) ++ (ypart urcorner p - ypart lrcorner p) ;
        set_circular_vector(ab,r)(p,n) ;
        fill p withcircularshade(ab,ab,0,r,ca,cb) ;
        if trace_shades :
            drawarrow ab -- ab shifted (0,r) withpen pencircle scaled 1pt withcolor .5white ;
        fi ;
    endgroup ;
enddef ;

def linear_shade (expr p, n, ca, cb) =
    begingroup ;
        save a, b, sh ; pair a, b ;
        set_linear_vector(a,b)(p,n) ;
        fill p withlinearshade(a,b,ca,cb) ;
        if trace_shades :
            drawarrow a -- b withpen pencircle scaled 1pt withcolor .5white ;
        fi ;
    endgroup ;
enddef ;

def withcircularshade (expr a, b, ra, rb, ca, cb) =
    withprescript "sh_type=circular"
    withprescript "sh_domain=0 1"
    withprescript "sh_factor="   & decimal shadefactor
    withprescript "sh_color_a="  & colordecimals ca
    withprescript "sh_color_b="  & colordecimals cb
    withprescript "sh_center_a=" & ddecimal (a shifted shadeoffset)
    withprescript "sh_center_b=" & ddecimal (b shifted shadeoffset)
    withprescript "sh_radius_a=" & decimal ra
    withprescript "sh_radius_b=" & decimal rb
enddef ;

def withlinearshade (expr a, b, ca, cb) =
    withprescript "sh_type=linear"
    withprescript "sh_domain=0 1"
    withprescript "sh_factor="   & decimal shadefactor
    withprescript "sh_color_a="  & colordecimals ca
    withprescript "sh_color_b="  & colordecimals cb
    withprescript "sh_center_a=" & ddecimal (a shifted shadeoffset)
    withprescript "sh_center_b=" & ddecimal (b shifted shadeoffset)
enddef ;

string _defined_cs_pre_[] ; numeric _defined_cs_ ; _defined_cs_:= 0 ;
string prescript_separator ; prescript_separator := char(13) ;

vardef define_circular_shade (expr a, b, ra, rb, ca, cb) =
    _defined_cs_ := _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] := "sh_type=circular"
      & prescript_separator & "sh_domain=0 1"
      & prescript_separator & "sh_factor="   & decimal shadefactor
      & prescript_separator & "sh_color_a="  & colordecimals ca
      & prescript_separator & "sh_color_b="  & colordecimals cb
      & prescript_separator & "sh_center_a=" & ddecimal (a shifted shadeoffset)
      & prescript_separator & "sh_center_b=" & ddecimal (b shifted shadeoffset)
      & prescript_separator & "sh_radius_a=" & decimal ra
      & prescript_separator & "sh_radius_b=" & decimal rb
    ;
    _defined_cs_
enddef ;

vardef define_linear_shade (expr a, b, ca, cb) =
    _defined_cs_ := _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] := "sh_type=linear"
      & prescript_separator & "sh_domain=0 1"
      & prescript_separator & "sh_factor=" & decimal shadefactor
      & prescript_separator & "sh_color_a=" & colordecimals ca
      & prescript_separator & "sh_color_b=" & colordecimals cb
      & prescript_separator & "sh_center_a=" & ddecimal (a shifted shadeoffset)
      & prescript_separator & "sh_center_b=" & ddecimal (b shifted shadeoffset)
    ;
    _defined_cs_
enddef ;

primarydef p withshade sc =
    p
        withprescript _defined_cs_pre_[sc]
enddef ;

% vardef predefined_linear_shade (expr p, n, ca, cb) =
%     save a, b, sh ; pair a, b ;
%     set_linear_vector(a,b)(p,n) ;
%     define_linear_shade (a,b,ca,cb)
% enddef ;
%
% vardef predefined_circular_shade (expr p, n, ca, cb) =
%     save ab, r ; pair ab ; numeric r ;
%     r := (xpart lrcorner p - xpart llcorner p) ++ (ypart urcorner p - ypart lrcorner p) ;
%     set_circular_vector(ab,r)(p,n) ;
%     define_circular_shade(ab,ab,0,r,ca,cb)
% enddef ;

% Graphic text (we will move code here)

def graphictext primary t =
    if _trial_run_ :
        let dographictextindeed = nographictext ;
    else :
        let dographictextindeed = dographictext ;
    fi
    dographictextindeed(t)
enddef ;

def dographictext (expr t) =
    % withprescript "gt_stage=final"
    begingroup ;
    save figurepicture ; picture figurepicture ;
    figurepicture := currentpicture ; currentpicture := nullpicture ;
    currentgraphictext := currentgraphictext + 1 ;
    dofinishgraphictext
enddef ;

def nographictext (expr t) text rest =
    draw unitsquare withprescript "gt_stage=trial" withpostscript t ;
enddef ;

% def savegraphictext (expr str) =
% enddef ;

% def erasegraphictextfile =
% enddef ;

% Figures

% def externalfigure primary filename =
%     doexternalfigure (filename)
% enddef ;
%
% def doexternalfigure (expr filename) text transformation =
%     if true : % a bit incompatible esp scaled 1cm now scaled the natural size
%         draw rawtextext("\externalfigure[" & filename & "]") transformation ;
%     else :
%         draw unitsquare transformation withprescript "fg_name=" & filename ;
%     fi ;
% enddef ;

def externalfigure primary filename =
    if true :
        draw rawtextext("\externalfigure[" & filename & "]")
    else :
        image (
            addto currentpicture doublepath unitsquare
                withprescript "fg_name=" & filename ;
        )
    fi
enddef ;

def figure primary filename =
    rawtextext("\externalfigure[" & filename & "]")
enddef ;

% Positions

def register (expr label, width, height, offset) =
    image (
        addto currentpicture doublepath unitsquare xscaled width yscaled height shifted offset
            withprescript "ps_label=" & label ;
    ) ; % no transformations
enddef ;

% Housekeeping

extra_beginfig := extra_beginfig & "currentgraphictext := 0 ; " ;
extra_endfig   := extra_endfig   & "finishsavingdata ; " ;
extra_endfig   := extra_endfig   & "resettextexts ; " ;

boolean cmykcolors ; cmykcolors := true ;
boolean spotcolors ; spotcolors := true ;

% Bonus

vardef verbatim(expr str) =
    ditto & "\detokenize{" & str & "}" & ditto
enddef ;

% New

def bitmapimage(expr xresolution, yresolution, data) =
    image (
        addto currentpicture doublepath unitsquare
            withprescript  "bm_xresolution=" & decimal xresolution
            withprescript  "bm_yresolution=" & decimal yresolution
            withpostscript data ;
    )
enddef ;
