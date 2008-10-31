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
    if _trial_run_ :
        image (
            _tt_n_ := _tt_n_ + 1 ;
            _tt_p_ := image (
                draw _tt_p_ ;
                addto currentpicture doublepath unitsquare withprescript "tf" withpostscript decimal _tt_n_ & ":" & str ;
            ) ;
            draw unitsquare withpen pencircle scaled 0 ;
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

laboff.origin = (infinity,infinity) ; labxf.origin := 0 ; labyf.origin := 0 ;
laboff.raw    = (infinity,infinity) ; labxf.raw    := 0 ; labyf.raw    := 0 ;

vardef thetextext@#(expr p,z) = % adapted copy of thelabel@
    p
        if (labtype@# >= 10) : shifted (0,ypart center p) fi
        shifted (z + labeloffset*laboff@# - (labxf@#*lrcorner p + labyf@#*ulcorner p + (1-labxf@#-labyf@#)*llcorner p))
enddef;

vardef textext@#(expr txt) =
    interim labeloffset := textextoffset ;
    if string txt :
        thetextext@#(rawtextext(txt),origin)
    else :
        thetextext@#(txt,origin)
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

def doexternalfigure (expr filename) text transformation =
    draw unitsquare transformation withprescript "fg" withpostscript filename ;
enddef ;

extra_beginfig := extra_beginfig & "currentgraphictext := 0 ; " ;
extra_endfig   := extra_endfig   & "finishsavingdata ; " ;
extra_endfig   := extra_endfig   & "resettextexts ; " ;

boolean cmykcolors ; cmykcolors := true ;
boolean spotcolors ; spotcolors := true ;
