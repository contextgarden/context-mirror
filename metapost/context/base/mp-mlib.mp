%D \module
%D   [       file=mp-mlib.mp,
%D        version=2008.03.21,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=specials,
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

numeric _tt_w_[], _tt_h_[], _tt_d_[] ;
numeric _tt_n_ ; _tt_n_ := 0 ;
picture _tt_p_ ; _tt_p_ := nullpicture ;
boolean _trial_run_ ; _trial_run_ := false ;

def resettextexts =
    _tt_n_ := 0 ;
    _tt_p_ := nullpicture ;
enddef ;

extra_endfig   := ";addto currentpicture also _tt_p_; " & extra_endfig; % was draw _tt_p_
extra_beginfig := extra_beginfig & "resettextexts;";

vardef rawtextext(expr str) =
    if str = "" :
        nullpicture
    elseif _trial_run_ :
        image (
            _tt_n_ := _tt_n_ + 1 ;
            _tt_p_ := image (
                addto currentpicture also _tt_p_ ;
                addto currentpicture doublepath unitsquare withprescript "tf" withpostscript decimal _tt_n_ & ":" & str ;
            ) ;
            addto currentpicture doublepath unitsquare withpen pencircle scaled 0 ;
        )
    else :
        image (
            _tt_n_ := _tt_n_ + 1 ;
            addto currentpicture doublepath unitsquare
                xscaled _tt_w_[_tt_n_]
                yscaled (_tt_h_[_tt_n_] + _tt_d_[_tt_n_])
                withprescript "ts"
                withpostscript decimal _tt_n_ & ":" & str ;
        ) shifted (0,-_tt_d_[_tt_n_])
    fi
enddef ;

% not ok yet

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

labxf.l   ; labxf.l  = labxf.lft  ;
labxf.r   ; labxf.r  = labxf.rt   ;
labxf.b   ; labxf.b  = labxf.bot  ;
labxf.t   ; labxf.t  = labxf.top  ;
labxf.l_t ; labxf.l_t = labxf.ulft ;
labxf.r_t ; labxf.r_t = labxf.urt  ;
labxf.l_b ; labxf.l_b = labxf.llft ;
labxf.r_b ; labxf.r_b = labxf.lrt  ;
labxf.t_l ; labxf.t_l = labxf.ulft ;
labxf.t_r ; labxf.t_r = labxf.urt  ;
labxf.b_l ; labxf.b_l = labxf.llft ;
labxf.b_r ; labxf.b_r = labxf.lrt  ;

labyf.l   ; labyf.l  = labyf.lft  ;
labyf.r   ; labyf.r  = labyf.rt   ;
labyf.b   ; labyf.b  = labyf.bot  ;
labyf.t   ; labyf.t  = labyf.top  ;
labyf.l_t ; labyf.l_t = labyf.ulft ;
labyf.r_t ; labyf.r_t = labyf.urt  ;
labyf.l_b ; labyf.l_b = labyf.llft ;
labyf.r_b ; labyf.r_b = labyf.lrt  ;
labyf.t_l ; labyf.t_l = labyf.ulft ;
labyf.t_r ; labyf.t_r = labyf.urt  ;
labyf.b_l ; labyf.b_l = labyf.llft ;
labyf.b_r ; labyf.b_r = labyf.lrt  ;

labtype.l   ; labtype.l   = labtype.lft  ;
labtype.r   ; labtype.r   = labtype.rt   ;
labtype.b   ; labtype.b   = labtype.bot  ;
labtype.t   ; labtype.t   = labtype.top  ;
labtype.l_t ; labtype.l_t = labtype.ulft ;
labtype.r_t ; labtype.r_t = labtype.urt  ;
labtype.l_b ; labtype.l_b = labtype.llft ;
labtype.r_b ; labtype.r_b = labtype.lrt  ;
labtype.t_l ; labtype.t_l = labtype.ulft ;
labtype.t_r ; labtype.t_r = labtype.urt  ;
labtype.b_l ; labtype.b_l = labtype.llft ;
labtype.b_r ; labtype.b_r = labtype.lrt  ;

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
    withprescript
        "cs"
    withpostscript
        "0 1 " & decimal shadefactor & " " &
        colordecimals ca & " " & ddecimal (a shifted shadeoffset) & " " & decimal ra & " " &
        colordecimals cb & " " & ddecimal (b shifted shadeoffset) & " " & decimal rb
enddef ;
def withlinearshade (expr a, b, ca, cb) =
    withprescript
        "ls"
    withpostscript
        "0 1 " & decimal shadefactor & " " &
        colordecimals ca  & " " & ddecimal (a shifted shadeoffset) & " " &
        colordecimals cb  & " " & ddecimal (b shifted shadeoffset)
enddef ;
string _defined_cs_pre_[], _defined_cs_post_[] ; numeric _defined_cs_ ; _defined_cs_:= 0 ;
vardef define_circular_shade (expr a, b, ra, rb, ca, cb) =
    _defined_cs_ := _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] := "cs" ;
    _defined_cs_post_[_defined_cs_] := "0 1 " & decimal shadefactor & " " &
        colordecimals ca & " " & ddecimal (a shifted shadeoffset) & " " & decimal ra & " " &
        colordecimals cb & " " & ddecimal (b shifted shadeoffset) & " " & decimal rb ;
    _defined_cs_
enddef ;
vardef define_linear_shade (expr a, b, ca, cb) =
    _defined_cs_ := _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] := "ls" ;
    _defined_cs_post_[_defined_cs_] := "0 1 " & decimal shadefactor & " " &
        colordecimals ca & " " & ddecimal (a shifted shadeoffset) & " " &
        colordecimals cb & " " & ddecimal (b shifted shadeoffset) ;
    _defined_cs_
enddef ;
primarydef p withshade sc =
    p withprescript _defined_cs_pre_[sc] withpostscript _defined_cs_post_[sc]
enddef ;
def shadecolor(expr sc) = % obsolete
    1 withprescript _defined_cs_pre_[sc] withpostscript _defined_cs_post_[sc]
enddef ;

def graphictext primary t =
    if _trial_run_ :
        let dographictextindeed = nographictext ;
    else :
        let dographictextindeed = dographictext ;
    fi
    dographictextindeed(t)
enddef ;
def dographictext (expr t) =
    begingroup ;
    save figurepicture ; picture figurepicture ;
    figurepicture := currentpicture ; currentpicture := nullpicture ;
    currentgraphictext := currentgraphictext + 1 ;
    dofinishgraphictext
enddef ;
def nographictext (expr t) text rest =
    draw unitsquare withprescript "gt" withpostscript t ;
enddef ;
def savegraphictext (expr str) =
enddef ;
def erasegraphictextfile =
enddef ;

def externalfigure primary filename =
    doexternalfigure (filename)
enddef ;
def doexternalfigure (expr filename) text transformation =
    draw unitsquare transformation withprescript "fg" withpostscript filename ;
enddef ;

def register (expr label, width, height, offset) =
    draw unitsquare xscaled width yscaled height shifted offset withprescript "ps" withpostscript label ;
enddef ;

extra_beginfig := extra_beginfig & "currentgraphictext := 0 ; " ;
extra_endfig   := extra_endfig   & "finishsavingdata ; " ;
extra_endfig   := extra_endfig   & "resettextexts ; " ;

boolean cmykcolors ; cmykcolors := true ;
boolean spotcolors ; spotcolors := true ;

vardef verbatim(expr str) =
    ditto & "\detokenize{" & str & "}" & ditto
enddef ;
