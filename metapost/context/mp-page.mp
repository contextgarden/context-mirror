%D \module
%D   [       file=mp-page.mp,
%D        version=1999.03.10,
%D          title=PRAGMA graphics,
%D       subtitle=page macros,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See mreadme.pdf for 
%C details. 

%D This module is rather preliminary and subjected to 
%D changes. 

if known StartPage: endinput ; fi ; 

PaperHeight         := 845.04684pt  ;
PaperWidth          := 597.50787pt  ;
PrintPaperHeight    := 845.04684pt  ;
PrintPaperWidth     := 597.50787pt  ;
TopSpace            :=  71.12546pt  ;
BackSpace           :=  71.13275pt  ;
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

LeftEdge             :=  -4 ; Top             := -40 ;
LeftEdgeSeparator    :=  -3 ; TopSeparator    := -30 ; 
LeftMargin           :=  -2 ; Header          := -20 ; 
LeftMarginSeparator  :=  -1 ; HeaderSeparator := -10 ; 
Text                 :=   0 ; Text            :=   0 ;
RightMarginSeparator :=  +1 ; FooterSeparator := +10 ; 
RightMargin          :=  +2 ; Footer          := +20 ; 
RightEdgeSeparator   :=  +3 ; BottomSeparator := +30 ; 
RightEdge            :=  +4 ; Bottom          := +40 ; 

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

def LoadPageState = 
  scantokens "input mp-state.tmp" ;
enddef ; 

def StartPage =
  LoadPageState ;

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

  Page = unitsquare xscaled PaperWidth yscaled PaperHeight ;  
  bboxmargin := 0 ; setbounds currentpicture to Page ;
enddef ; 

def StopPage =
  bboxmargin := 0 ; setbounds currentpicture to Page ;
enddef ; 

def llEnlarged (expr p,d) = llcorner p shifted (-d,-d) enddef ; 
def lrEnlarged (expr p,d) = lrcorner p shifted (+d,-d) enddef ; 
def urEnlarged (expr p,d) = urcorner p shifted (+d,+d) enddef ; 
def ulEnlarged (expr p,d) = ulcorner p shifted (-d,+d) enddef ; 

def Enlarged (expr p, d) = 
  (llEnlarged (p,d) --
   lrEnlarged (p,d) --
   urEnlarged (p,d) --
   ulEnlarged (p,d) -- cycle) 
enddef ; 

