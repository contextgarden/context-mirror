%D \module
%D   [       file=mp-page.mp,
%D        version=1999.03.10,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=page enhancements,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See mreadme.pdf for
%C details.

%D This module is rather preliminary and subjected to
%D changes.

if unknown context_tool : input mp-tool ; fi ;
if   known context_page : endinput      ; fi ;

boolean context_page ; context_page := true ;

if unknown PageStateAvailable :
  boolean PageStateAvailable ; PageStateAvailable := false ;
fi ;

if unknown OnRightPage :
  boolean OnRightPage ; OnRightPage := true ;
fi ;

if unknown OnOddPage :
  boolean OnOddPage ; OnOddPage := true ;
fi ;

if unknown InPageBody :
  boolean InPageBody ; InPageBody := false ;
fi ;

def SaveTextAreas =
  path    SavedTextAreas  []  ;
  path    SavedTextColumns[]  ;
  numeric NOfSavedTextAreas   ;
  numeric NOfSavedTextColumns ;
  for i=1 upto NOfTextAreas :
    SavedTextAreas[i] := TextAreas[i] ;
  endfor ;
  for i=1 upto NOfTextColumns :
    SavedTextColumns[i] := TextColumns[i] ;
  endfor ;
  NOfSavedTextAreas   := NOfTextAreas ;
  NOfSavedTextColumns := NOfTextColumns ;
enddef ;

def ResetTextAreas =
  path TextAreas[], TextColumns[] ;
  numeric NOfTextAreas   ; NOfTextAreas   := 0 ;
  numeric NOfTextColumns ; NOfTextColumns := 0 ;
  numeric nofmultipars   ; nofmultipars   := 0 ;
  TextAreas[0] := TextColumns[0] := origin -- cycle ;
enddef ;

ResetTextAreas ; SaveTextAreas ; ;

def RegisterTextArea (expr x, y, w, h, d) =
  begingroup ; save p ; path p ;
    p := unitsquare xyscaled(w,h+d) shifted (x,y-d) ;
    if NOfTextAreas>0 :
      % if needed, concatenate areas
      if (round(llcorner TextAreas[NOfTextAreas]) = round(ulcorner p)) and
         (round(lrcorner TextAreas[NOfTextAreas]) = round(urcorner p)) :
        p := ulcorner TextAreas[NOfTextAreas] --
             urcorner TextAreas[NOfTextAreas] --
             lrcorner p --
             llcorner p --
             cycle ;
      else :
        NOfTextAreas := NOfTextAreas + 1 ;
      fi ;
    else :
      NOfTextAreas := NOfTextAreas + 1 ;
    fi ;
    TextAreas[NOfTextAreas] := p ;
    if NOfTextColumns>0 :
      if (round(xpart llcorner TextColumns[NOfTextColumns]) = round(xpart ulcorner p)) and
         (round(xpart lrcorner TextColumns[NOfTextColumns]) = round(xpart urcorner p)) :
        p := ulcorner TextColumns[NOfTextColumns] --
             urcorner TextColumns[NOfTextColumns] --
             lrcorner p --
             llcorner p --
             cycle ;
      else :
        NOfTextColumns := NOfTextColumns + 1 ;
      fi ;
    else :
      NOfTextColumns := NOfTextColumns + 1 ;
    fi ;
    TextColumns[NOfTextColumns] := p ;
  endgroup ;
enddef ;

%D We store a local area in slot zero.

def RegisterLocalTextArea (expr x, y, w, h, d) =
  TextAreas[0] := TextColumns[0] := unitsquare xyscaled(w,h+d) shifted (x,y-d) ;
enddef ;

def ResetLocalTextArea =
  TextAreas[0] := TextColumns[0] := origin -- cycle ;
enddef ;

ResetLocalTextArea ;

vardef InsideTextArea (expr _i_, _xy_) =
  ( (round(xpart _xy_) >= round(xpart llcorner TextAreas[_i_])) and
    (round(xpart _xy_) <= round(xpart lrcorner TextAreas[_i_])) and
    (round(ypart _xy_) >= round(ypart llcorner TextAreas[_i_])) and
    (round(ypart _xy_) <= round(ypart urcorner TextAreas[_i_])) )
enddef ;

vardef InsideSavedTextArea (expr _i_, _xy_) =
  ( (round(xpart _xy_) >= round(xpart llcorner SavedTextAreas[_i_])) and
    (round(xpart _xy_) <= round(xpart lrcorner SavedTextAreas[_i_])) and
    (round(ypart _xy_) >= round(ypart llcorner SavedTextAreas[_i_])) and
    (round(ypart _xy_) <= round(ypart urcorner SavedTextAreas[_i_])) )
enddef ;

vardef InsideSomeTextArea(expr _xy_) =
  save ok ; boolean ok ; ok := false ;
  for i := 1 upto NOfTextAreas :
    if InsideTextArea(i,_xy_) : ok := true ; fi ;
    exitif ok ;
  endfor ;
  ok
enddef ;

vardef InsideSomeSavedTextArea(expr _xy_) =
  save ok ; boolean ok ; ok := false ;
  for i := 1 upto NOfSavedTextAreas :
    if InsideSavedTextArea(i,_xy_) : ok := true ; fi ;
    exitif ok ;
  endfor ;
  ok
enddef ;

vardef TextAreaX (expr x) =
  numeric _TextAreaX_ ; _TextAreaX_ := 0 ;
  for i := 1 upto NOfTextAreas :
    if (round(x) >= round(xpart llcorner TextAreas[i])) and
       (round(x) <= round(xpart lrcorner TextAreas[i])) :
      _TextAreaX_ := xpart llcorner TextAreas[i] ;
    fi ;
  endfor ;
  _TextAreaX_
enddef ;

vardef TextAreaY (expr y) =
  numeric _TextAreaY_ ; _TextAreaY_ := 0 ;
  for i := 1 upto NOfTextAreas :
    if (round(y) >= round(ypart llcorner TextAreas[NOfTextAreas])) and
       (round(y) <= round(ypart ulcorner TextAreas[NOfTextAreas])) :
      _TextAreaY_ := ypart llcorner TextAreas[NOfTextAreas] ;
    fi ;
  endfor ;
  _TextAreaY_
enddef ;

vardef TextAreaXY (expr x, y) =
  pair _TextAreaXY_ ; _TextAreaXY_ := origin ;
  for i := 1 upto NOfTextAreas :
    if (round(x) >= round(xpart llcorner TextAreas[i])) and
       (round(x) <= round(xpart lrcorner TextAreas[i])) and
       (round(y) >= round(ypart llcorner TextAreas[i])) and
       (round(y) <= round(ypart ulcorner TextAreas[i])) :
      _TextAreaXY_ := llconer TextAreas[i] ;
    fi ;
  endfor ;
  _TextAreaXY_
enddef ;

vardef TextAreaW (expr x) =
  numeric _TextAreaW_ ; _TextAreaW_ := 0 ;
  for i := 1 upto NOfTextAreas :
    if (round(x) >= round(xpart llcorner TextAreas[i])) and
       (round(x) <= round(xpart lrcorner TextAreas[i])) :
      _TextAreaW_ := bbwidth(TextAreas[i]) ;
    fi ;
  endfor ;
  _TextAreaW_
enddef ;

vardef TextAreaH (expr y) =
  numeric _TextAreaH_ ; _TextAreaH_ := 0 ;
  for i := 1 upto NOfTextAreas :
    if (round(y) >= round(ypart llcorner TextAreas[i])) and
       (round(y) <= round(ypart ulcorner TextAreas[i])) :
      _TextAreaH_ := bbheight(TextAreas[i]) ;
    fi ;
  endfor ;
  _TextAreaH_
enddef ;

vardef TextAreaWH (expr x, y) =
  pair _TextAreaWH_ ; _TextAreaWH_ := origin ;
  for i := 1 upto NOfTextAreas :
    if (round(x) >= round(xpart llcorner TextAreas[i])) and
       (round(x) <= round(xpart lrcorner TextAreas[i])) and
       (round(y) >= round(ypart llcorner TextAreas[i])) and
       (round(y) <= round(ypart ulcorner TextAreas[i])) :
      _TextAreaWH_ := (bbwidth(TextAreas[i]),bbheight(TextAreas[i])) ;
    fi ;
  endfor ;
  _TextAreaWH_
enddef ;

PageNumber          := 0 ;
PaperHeight         := 845.04684pt  ;
PaperWidth          := 597.50787pt  ;
PrintPaperHeight    := 845.04684pt  ;
PrintPaperWidth     := 597.50787pt  ;
TopSpace            :=  71.12546pt  ;
BottomSpace         :=   0.0pt      ;
BackSpace           :=  71.13275pt  ;
CutSpace            :=   0.0pt      ;
MakeupHeight        := 711.3191pt   ;
MakeupWidth         := 426.78743pt  ;
TopHeight           :=   0.0pt      ;
TopDistance         :=   0.0pt      ;
HeaderHeight        :=  56.90294pt  ;
HeaderDistance      :=   0.0pt      ;
TextHeight          := 597.51323pt  ;
FooterDistance      :=   0.0pt      ;
FooterHeight        :=  56.90294pt  ;
BottomDistance      :=   0.0pt      ;
BottomHeight        :=   0.0pt      ;
LeftEdgeWidth       :=   0.0pt      ;
LeftEdgeDistance    :=   0.0pt      ;
LeftMarginWidth     :=   75.58197pt ;
LeftMarginDistance  :=   11.99829pt ;
TextWidth           :=  426.78743pt ;
RightMarginDistance :=   11.99829pt ;
RightMarginWidth    :=   75.58197pt ;
RightEdgeDistance   :=    0.0pt     ;
RightEdgeWidth      :=    0.0pt     ;

PageOffset          :=    0.0pt     ;
PageDepth           :=    0.0pt     ;

LayoutColumns       :=    0         ;
LayoutColumnDistance:=    0.0pt     ;
LayoutColumnWidth   :=    0.0pt     ;

LeftEdge             :=  -4 ; Top             := -40 ;
LeftEdgeSeparator    :=  -3 ; TopSeparator    := -30 ;
LeftMargin           :=  -2 ; Header          := -20 ;
LeftMarginSeparator  :=  -1 ; HeaderSeparator := -10 ;
Text                 :=   0 ; Text            :=   0 ;
RightMarginSeparator :=  +1 ; FooterSeparator := +10 ;
RightMargin          :=  +2 ; Footer          := +20 ;
RightEdgeSeparator   :=  +3 ; BottomSeparator := +30 ;
RightEdge            :=  +4 ; Bottom          := +40 ;

Margin      := LeftMargin  ; % obsolete
Edge        := LeftEdge    ; % obsolete
InnerMargin := RightMargin ; % obsolete
InnerEdge   := RightEdge   ; % obsolete
OuterMargin := LeftMargin  ; % obsolete
OuterEdge   := LeftEdge    ; % obsolete

InnerMarginWidth     := 0pt ;
OuterMarginWidth     := 0pt ;
InnerMarginDistance  := 0pt ;
OuterMarginDistance  := 0pt ;

InnerEdgeWidth     := 0pt ;
OuterEdgeWidth     := 0pt ;
InnerEdgeDistance  := 0pt ;
OuterEdgeDistance  := 0pt ;

path Area [][] ; pair Location [][] ; path Field [][] ;  path Page ;
numeric HorPos ; numeric Hstep [] ; numeric Hsize [] ;
numeric VerPos ; numeric Vstep [] ; numeric Vsize [] ;

for VerPos=Top step 10 until Bottom:
  for HorPos=LeftEdge step 1 until RightEdge:
    Area[HorPos][VerPos] := origin--cycle ;
    Area[VerPos][HorPos] := Area[HorPos][VerPos] ;
    Location[HorPos][VerPos] := origin ;
    Location[VerPos][HorPos] := Location[HorPos][VerPos] ;
    Field[HorPos][VerPos] := origin--cycle ;
    Field[VerPos][HorPos] := Field[HorPos][VerPos] ;
  endfor ;
endfor ;

% def LoadPageState =
%   scantokens "input mp-state.tmp" ;
% enddef ;

def SwapPageState =
  if not OnRightPage :
           BackSpace := PaperWidth-MakeupWidth-BackSpace ;
            CutSpace := PaperWidth-MakeupWidth-CutSpace ;
                   i := LeftMarginWidth ;
     LeftMarginWidth := RightMarginWidth ;
    RightMarginWidth := i ;
                   i := LeftMarginDistance ;
  LeftMarginDistance := RightMarginDistance ;
 RightMarginDistance := i ;
                   i := LeftEdgeWidth ;
       LeftEdgeWidth := RightEdgeWidth ;
      RightEdgeWidth := i ;
                   i := LeftEdgeDistance ;
    LeftEdgeDistance := RightEdgeDistance ;
   RightEdgeDistance := i ;

% these are now available as ..Width and ..Distance

              Margin := LeftMargin ;
                Edge := LeftEdge ;
         InnerMargin := RightMargin ;
           InnerEdge := RightEdge ;
         OuterMargin := LeftMargin ;
           OuterEdge := LeftEdge ;
  else :
              Margin := RightMargin ;
                Edge := RightEdge ;
         InnerMargin := LeftMargin ;
           InnerEdge := LeftEdge ;
         OuterMargin := RightMargin ;
           OuterEdge := RightEdge ;
  fi ;
enddef ;

def SetPageAreas =

  numeric Vsize[], Hsize[], Vstep[], Hstep[] ;

  Vsize[Top]             = TopHeight ;
  Vsize[TopSeparator]    = TopDistance ;
  Vsize[Header]          = HeaderHeight ;
  Vsize[HeaderSeparator] = HeaderDistance ;
  Vsize[Text]            = TextHeight ;
  Vsize[FooterSeparator] = FooterDistance ;
  Vsize[Footer]          = FooterHeight ;
  Vsize[BottomSeparator] = BottomDistance ;
  Vsize[Bottom]          = BottomHeight ;

  Vstep[Top]             = Vstep[TopSeparator]   +Vsize[TopSeparator] ;
  Vstep[TopSeparator]    = PaperHeight-TopSpace ;
  Vstep[Header]          = Vstep[TopSeparator]   -Vsize[Header] ;
  Vstep[HeaderSeparator] = Vstep[Header]         -Vsize[HeaderSeparator] ;
  Vstep[Text]            = Vstep[HeaderSeparator]-Vsize[Text] ;
  Vstep[FooterSeparator] = Vstep[Text]           -Vsize[FooterSeparator] ;
  Vstep[Footer]          = Vstep[FooterSeparator]-Vsize[Footer] ;
  Vstep[BottomSeparator] = Vstep[Footer]         -Vsize[BottomSeparator] ;
  Vstep[Bottom]          = Vstep[BottomSeparator]-Vsize[Bottom] ;

  Hsize[LeftEdge]             = LeftEdgeWidth ;
  Hsize[LeftEdgeSeparator]    = LeftEdgeDistance ;
  Hsize[LeftMargin]           = LeftMarginWidth ;
  Hsize[LeftMarginSeparator]  = LeftMarginDistance ;
  Hsize[Text]                 = MakeupWidth ;
  Hsize[RightMarginSeparator] = RightMarginDistance ;
  Hsize[RightMargin]          = RightMarginWidth ;
  Hsize[RightEdgeSeparator]   = RightEdgeDistance ;
  Hsize[RightEdge]            = RightEdgeWidth ;

  Hstep[LeftEdge]             = Hstep[LeftEdgeSeparator]   -Hsize[LeftEdge] ;
  Hstep[LeftEdgeSeparator]    = Hstep[LeftMargin]          -Hsize[LeftEdgeSeparator] ;
  Hstep[LeftMargin]           = Hstep[LeftMarginSeparator] -Hsize[LeftMargin] ;
  Hstep[LeftMarginSeparator]  = Hstep[Text]                -Hsize[LeftMarginSeparator] ;
  Hstep[Text]                 = BackSpace ;
  Hstep[RightMarginSeparator] = Hstep[Text]                +Hsize[Text] ;
  Hstep[RightMargin]          = Hstep[RightMarginSeparator]+Hsize[RightMarginSeparator] ;
  Hstep[RightEdgeSeparator]   = Hstep[RightMargin]         +Hsize[RightMargin] ;
  Hstep[RightEdge]            = Hstep[RightEdgeSeparator]  +Hsize[RightEdgeSeparator] ;

  for VerPos=Top step 10 until Bottom:
    for HorPos=LeftEdge step 1 until RightEdge:
      Area[HorPos][VerPos] := unitsquare xscaled Hsize[HorPos] yscaled Vsize[VerPos] ;
      Area[VerPos][HorPos] := Area[HorPos][VerPos] ;
      Location[HorPos][VerPos] := (Hstep[HorPos],Vstep[VerPos]) ;
      Location[VerPos][HorPos] := Location[HorPos][VerPos] ;
      Field[HorPos][VerPos] := Area[HorPos][VerPos] shifted Location[HorPos][VerPos] ;
      Field[VerPos][HorPos] := Field[HorPos][VerPos] ;
    endfor ;
  endfor ;

  Page := unitsquare xscaled PaperWidth yscaled PaperHeight ;

enddef ;

def BoundPageAreas =

 % pickup pencircle scaled 0pt ;

  bboxmargin := 0 ; setbounds currentpicture to Page ;

enddef ;

def StartPage =

  if PageStateAvailable :
    LoadPageState ;
    SwapPageState ;
  fi ;

  SetPageAreas ;
  BoundPageAreas ;

enddef ;

def StopPage =

  BoundPageAreas ;

enddef ;

def OverlayBox =
  (unitsquare xyscaled (OverlayWidth,OverlayHeight))
enddef ;

% handy

def innerenlarged =
  hide(LoadPageState)
  if OnRightPage : leftenlarged  else : rightenlarged fi
enddef ;

def outerenlarged =
  hide(LoadPageState)
  if OnRightPage : rightenlarged else : leftenlarged  fi
enddef ;

% obsolete

def llEnlarged (expr p,d) = (llcorner p shifted (-d,-d)) enddef ;
def lrEnlarged (expr p,d) = (lrcorner p shifted (+d,-d)) enddef ;
def urEnlarged (expr p,d) = (urcorner p shifted (+d,+d)) enddef ;
def ulEnlarged (expr p,d) = (ulcorner p shifted (-d,+d)) enddef ;

def Enlarged (expr p, d) =
  (llEnlarged (p,d) --
   lrEnlarged (p,d) --
   urEnlarged (p,d) --
   ulEnlarged (p,d) -- cycle)
enddef ;

endinput ;