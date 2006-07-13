%D \module
%D   [       file=metafun.mp,
%D        version=2000.07.15,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=format generation file,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See mreadme.pdf for
%C details.

%D When generating many graphics at runtime, it can save run
%D time to use a format file. We could have named this file
%D \type {context}, but this is error prone, because it forces
%D to use the progname \type {mpost} or \type {context}
%D explicitly, depending on the needs. When using the format,
%D a mismatch in the memory specification of \type {mpost} or
%D \type {context} (the \TEX\ one) could lead to lost strings
%D (and as a result in buggy boundingbox and special
%D handling). By using the name \type {metatex} we make sure
%D that we use (unless overloaded) the settings of \type
%D {mpost}.

%D First we input John Hobby's metapost plain file. However,
%D because we want to prevent dependency problems and in the
%D end even may use a patched version, we prefer to use a
%D copy,

if unknown ahangle :
    input mp-base.mp ; % input plain.mp ;
else :
    let dump = relax ;
fi ;

input mp-tool.mp ;
input mp-spec.mp ;
input mp-core.mp ;
input mp-page.mp ;
input mp-text.mp ;
input mp-txts.mp ;
input mp-shap.mp ;
input mp-butt.mp ;
input mp-char.mp ;
input mp-step.mp ;
input mp-grph.mp ;
input mp-figs.mp ;

%     mp-form.mp ;
input mp-grid.mp ;
input mp-func.mp ;

string metafunversion ;

metafunversion = "metafun"                       & " " &
                 decimal year                    & "-" &
                 decimal month                   & "-" &
                 decimal day                     & " " &
                 decimal (time div 60)           & ":" &
                 decimal (time-(time div 60)*60) ;

let normalend = end ;

def end =
  ; message "" ; message metafunversion ; message "" ; normalend ;
enddef ;

dump ; endinput .
