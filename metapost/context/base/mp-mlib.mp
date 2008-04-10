
if unknown mplib        : endinput ; fi ;
if known   context_mlib : endinput ; fi ;

boolean context_mlib ; context_mlib := true ;

numeric _tt_w_[], _tt_h_[], _tt_d_[] ;
numeric _tt_n_ ; _tt_n_ := 0 ;
boolean _trial_run_ ; _trial_run_ := false ;

vardef textext(expr str) =
    if _trial_run_ :
        image (
            draw unitsquare
                withprescript "tf"
                withpostscript str ;
        )
    else :
        image (
            _tt_n_ := _tt_n_ + 1 ;
            draw unitsquare
                xscaled _tt_w_[_tt_n_]
                yscaled (_tt_h_[_tt_n_] + _tt_d_[_tt_n_])
                withprescript "ts"
                withpostscript decimal _tt_n_ ;
        )
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
    _defined_cs_ = _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] = "cs" ;
    _defined_cs_post_[_defined_cs_] = "0 1 " & decimal shadefactor & " " &
        colordecimals ca & " " & ddecimal (a shifted shadeoffset) & " " & decimal ra & " " &
        colordecimals cb & " " & ddecimal (b shifted shadeoffset) & " " & decimal rb ;
    _defined_cs_
enddef ;
vardef define_linear_shade (expr a, b, ca, cb) =
    _defined_cs_ = _defined_cs_ + 1 ;
    _defined_cs_pre_ [_defined_cs_] = "ls" ;
    _defined_cs_post_[_defined_cs_] = "0 1 " & decimal shadefactor & " " &
        colordecimals ca & " " & ddecimal (a shifted shadeoffset) & " "
        colordecimals cb & " " & ddecimal (b shifted shadeoffset) ;
    _defined_cs_
enddef ;
def withshade(expr sc) =
    withprescript _defined_cs_pre_[sc] withpostscript _defined_cs_post_[sc]
enddef ;
def shadecolor(expr sc) = % obsolete
    1 withprescript _defined_cs_pre_[sc] withpostscript _defined_cs_post_[sc]
enddef ;

% def _graphic_text_f_(expr t) text rest =
%     draw unitsquare withprescript "gt" withpostscript t ;
% enddef ;
% def _graphic_text_s_(expr t) =
%     begingroup ;
%     save figurepicture ; picture figurepicture ;
%     figurepicture := currentpicture ; currentpicture := nullpicture ;
%     currentgraphictext := currentgraphictext + 1 ;
%     dofinishgraphictext
% enddef ;

vardef graphictext primary t =
    save next ;
    if _trial_run_ :
        let next = nographictext ;
    else :
        let next = dographictext ;
    fi
    next(t)
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


def doexternalfigure (expr filename) text transformation =
    draw unitsquare transformation withprescript "fg" withpostscript filename ;
enddef ;

extra_beginfig := extra_beginfig & "currentgraphictext := 0 ; " ;

boolean cmykcolors ; cmykcolors := true ;
boolean spotcolors ; spotcolors := true ;
