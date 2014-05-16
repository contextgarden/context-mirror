if not modules then modules = { } end modules ['mult-low'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for syntax highlighters, only the ones that are for users (boring to collect them)

return {
    ["constants"] = {
        --
        "zerocount", "minusone", "minustwo", "plusone", "plustwo", "plusthree", "plusfour", "plusfive",
        "plussix", "plusseven", "pluseight", "plusnine", "plusten", "plussixteen", "plushundred",
        "plusthousand", "plustenthousand", "plustwentythousand", "medcard", "maxcard",
        "zeropoint", "onepoint", "halfapoint", "onebasepoint", "maxdimen", "scaledpoint", "thousandpoint",
        "points", "halfpoint",
        "zeroskip",
        "zeromuskip", "onemuskip",
        "pluscxxvii", "pluscxxviii", "pluscclv", "pluscclvi",
        "normalpagebox",
        --        --
        "endoflinetoken", "outputnewlinechar",
        --
        "emptytoks", "empty", "undefined",
        --
        "voidbox", "emptybox", "emptyvbox", "emptyhbox",
        --
        "bigskipamount", "medskipamount", "smallskipamount",
        --
        "fmtname", "fmtversion", "texengine", "texenginename", "texengineversion",
        "luatexengine", "pdftexengine", "xetexengine", "unknownengine",
        "etexversion", "pdftexversion", "xetexversion", "xetexrevision",
        --
        "activecatcode",
        --
        "bgroup", "egroup",
        "endline",
        --
        "conditionaltrue", "conditionalfalse",
        --
        "attributeunsetvalue",
        --
        "uprotationangle", "rightrotationangle", "downrotationangle", "leftrotationangle",
        --
        "inicatcodes",
        "ctxcatcodes", "texcatcodes", "notcatcodes", "txtcatcodes", "vrbcatcodes",
        "prtcatcodes", "nilcatcodes", "luacatcodes", "tpacatcodes", "tpbcatcodes",
        "xmlcatcodes", "ctdcatcodes",
        --
        "escapecatcode", "begingroupcatcode", "endgroupcatcode", "mathshiftcatcode", "alignmentcatcode",
        "endoflinecatcode", "parametercatcode", "superscriptcatcode", "subscriptcatcode", "ignorecatcode",
        "spacecatcode", "lettercatcode", "othercatcode", "activecatcode", "commentcatcode", "invalidcatcode",
        --
        "tabasciicode", "newlineasciicode", "formfeedasciicode", "endoflineasciicode", "endoffileasciicode",
        "spaceasciicode", "hashasciicode", "dollarasciicode", "commentasciicode", "ampersandasciicode",
        "colonasciicode", "backslashasciicode", "circumflexasciicode", "underscoreasciicode",
        "leftbraceasciicode", "barasciicode", "rightbraceasciicode", "tildeasciicode", "delasciicode",
        "lessthanasciicode", "morethanasciicode", "doublecommentsignal",
        "atsignasciicode", "exclamationmarkasciicode", "questionmarkasciicode",
        "doublequoteasciicode", "singlequoteasciicode", "forwardslashasciicode",
        "primeasciicode",
        --
        "activemathcharcode",
        --
        "activetabtoken", "activeformfeedtoken", "activeendoflinetoken",
        --
        "batchmodecode", "nonstopmodecode", "scrollmodecode", "errorstopmodecode",
        --
        "bottomlevelgroupcode", "simplegroupcode", "hboxgroupcode", "adjustedhboxgroupcode", "vboxgroupcode",
        "vtopgroupcode", "aligngroupcode", "noaligngroupcode", "outputgroupcode", "mathgroupcode",
        "discretionarygroupcode", "insertgroupcode", "vcentergroupcode", "mathchoicegroupcode",
        "semisimplegroupcode", "mathshiftgroupcode", "mathleftgroupcode", "vadjustgroupcode",
        --
        "charnodecode", "hlistnodecode", "vlistnodecode", "rulenodecode", "insertnodecode", "marknodecode",
        "adjustnodecode", "ligaturenodecode", "discretionarynodecode", "whatsitnodecode", "mathnodecode",
        "gluenodecode", "kernnodecode", "penaltynodecode", "unsetnodecode", "mathsnodecode",
        --
        "charifcode", "catifcode", "numifcode", "dimifcode", "oddifcode", "vmodeifcode", "hmodeifcode",
        "mmodeifcode", "innerifcode", "voidifcode", "hboxifcode", "vboxifcode", "xifcode", "eofifcode",
        "trueifcode", "falseifcode", "caseifcode", "definedifcode", "csnameifcode", "fontcharifcode",
        --
        "fontslantperpoint", "fontinterwordspace", "fontinterwordstretch", "fontinterwordshrink",
        "fontexheight", "fontemwidth", "fontextraspace", "slantperpoint",
        "interwordspace", "interwordstretch", "interwordshrink", "exheight", "emwidth", "extraspace",
        "mathsupdisplay", "mathsupnormal", "mathsupcramped", "mathsubnormal", "mathsubcombined",  "mathaxisheight",
        --
        -- maybe a different class
        --
        "startmode", "stopmode", "startnotmode", "stopnotmode", "startmodeset", "stopmodeset",
        "doifmode", "doifmodeelse", "doifnotmode",
        "startmodeset","stopmodeset",
        "startallmodes", "stopallmodes", "startnotallmodes", "stopnotallmodes", "doifallmodes", "doifallmodeselse", "doifnotallmodes",
        "startenvironment", "stopenvironment", "environment",
        "startcomponent", "stopcomponent", "component",
        "startproduct", "stopproduct", "product",
        "startproject", "stopproject", "project",
        "starttext", "stoptext", "startnotext", "stopnotext","startdocument", "stopdocument", "documentvariable", "setupdocument",
        "startmodule", "stopmodule", "usemodule", "usetexmodule", "useluamodule","setupmodule","currentmoduleparameter","moduleparameter",
        "everystarttext",
        --
        "startTEXpage", "stopTEXpage",
    --  "startMPpage", "stopMPpage", -- already catched by nested lexer
        --
        "enablemode", "disablemode", "preventmode",
        "globalenablemode", "globaldisablemode", "globalpreventmode",
        "pushmode", "popmode",
        --
        "typescriptone", "typescripttwo", "typescriptthree", "mathsizesuffix",
        --
        "mathordcode", "mathopcode", "mathbincode", "mathrelcode", "mathopencode", "mathclosecode",
        "mathpunctcode", "mathalphacode", "mathinnercode", "mathnothingcode", "mathlimopcode",
        "mathnolopcode", "mathboxcode", "mathchoicecode", "mathaccentcode", "mathradicalcode",
        --
        "constantnumber", "constantnumberargument", "constantdimen", "constantdimenargument", "constantemptyargument",
        --
        "continueifinputfile",
        --
        "luastringsep", "!!bs", "!!es",
        --
        "lefttorightmark", "righttoleftmark",
        --
        "breakablethinspace", "nobreakspace", "narrownobreakspace", "zerowidthnobreakspace",
        "ideographicspace", "ideographichalffillspace",
        "twoperemspace", "threeperemspace", "fourperemspace", "fiveperemspace", "sixperemspace",
        "figurespace", "punctuationspace", "hairspace",
        "zerowidthspace", "zerowidthnonjoiner", "zerowidthjoiner", "zwnj", "zwj",
        "optionalspace",
    },
    ["helpers"] = {
        --
        "startsetups", "stopsetups",
        "startxmlsetups", "stopxmlsetups",
        "startluasetups", "stopluasetups",
        "starttexsetups", "stoptexsetups",
        "startrawsetups", "stoprawsetups",
        "startlocalsetups", "stoplocalsetups",
        "starttexdefinition", "stoptexdefinition",
        "starttexcode", "stoptexcode",
        "startcontextcode", "stopcontextcode",
        "startcontextdefinitioncode", "stopcontextdefinitioncode",
        --
        "doifsetupselse", "doifsetups", "doifnotsetups", "setup", "setups", "texsetup", "xmlsetup", "luasetup", "directsetup",
        "doifelsecommandhandler","doifnotcommandhandler","doifcommandhandler",
        --
        "newmode", "setmode", "resetmode",
        "newsystemmode", "setsystemmode", "resetsystemmode", "pushsystemmode", "popsystemmode",
        "booleanmodevalue",
        --
        "newcount", "newdimen", "newskip", "newmuskip", "newbox", "newtoks", "newread", "newwrite", "newmarks", "newinsert", "newattribute", "newif",
        "newlanguage", "newfamily", "newfam", "newhelp", -- not used
        --
        "then",
        "begcsname",
        --
        "strippedcsname",
        --
        "firstargumentfalse", "firstargumenttrue",
        "secondargumentfalse", "secondargumenttrue",
        "thirdargumentfalse", "thirdargumenttrue",
        "fourthargumentfalse", "fourthargumenttrue",
        "fifthargumentfalse", "fifthsargumenttrue",
        "sixthargumentfalse", "sixtsargumenttrue",
        --
        "doglobal", "dodoglobal", "redoglobal", "resetglobal",
        --
        "donothing", "dontcomplain", "forgetall",
        --
        "donetrue", "donefalse",
        --
        "htdp",
        "unvoidbox",
        "hfilll", "vfilll",
        --
        "mathbox", "mathlimop", "mathnolop", "mathnothing", "mathalpha",
        --
        "currentcatcodetable", "defaultcatcodetable", "catcodetablename",
        "newcatcodetable", "startcatcodetable", "stopcatcodetable", "startextendcatcodetable", "stopextendcatcodetable",
        "pushcatcodetable", "popcatcodetable", "restorecatcodes",
        "setcatcodetable", "letcatcodecommand", "defcatcodecommand", "uedcatcodecommand",
        --
        "hglue", "vglue", "hfillneg", "vfillneg", "hfilllneg", "vfilllneg",
        --
        "ruledhss", "ruledhfil", "ruledhfill", "ruledhfilneg", "ruledhfillneg", "normalhfillneg",
        "ruledvss", "ruledvfil", "ruledvfill", "ruledvfilneg", "ruledvfillneg", "normalvfillneg",
        "ruledhbox", "ruledvbox", "ruledvtop", "ruledvcenter", "ruledmbox",
        "ruledhskip", "ruledvskip", "ruledkern", "ruledmskip", "ruledmkern",
        "ruledhglue", "ruledvglue", "normalhglue", "normalvglue",
        "ruledpenalty",
        --
        "filledhboxb", "filledhboxr", "filledhboxg", "filledhboxc", "filledhboxm", "filledhboxy", "filledhboxk",
        --
        "scratchcounter", "globalscratchcounter",
        "scratchdimen", "globalscratchdimen",
        "scratchskip", "globalscratchskip",
        "scratchmuskip", "globalscratchmuskip",
        "scratchtoks", "globalscratchtoks",
        "scratchbox", "globalscratchbox",
        --
        "normalbaselineskip", "normallineskip", "normallineskiplimit",
        --
        "availablehsize", "localhsize", "setlocalhsize",
        --
        "nextbox", "dowithnextbox", "dowithnextboxcs", "dowithnextboxcontent", "dowithnextboxcontentcs",
        --
        "scratchwidth", "scratchheight", "scratchdepth", "scratchoffset", "scratchdistance",
        "scratchhsize", "scratchvsize",
        "scratchxoffset", "scratchyoffset", "scratchhoffset", "scratchvoffset",
        "scratchxposition", "scratchyposition",
        "scratchtopoffset", "scratchbottomoffset", "scratchleftoffset", "scratchrightoffset",
        --
        "scratchcounterone", "scratchcountertwo", "scratchcounterthree",
        "scratchdimenone", "scratchdimentwo", "scratchdimenthree",
        "scratchskipone", "scratchskiptwo", "scratchskipthree",
        "scratchmuskipone", "scratchmuskiptwo", "scratchmuskipthree",
        "scratchtoksone", "scratchtokstwo", "scratchtoksthree",
        "scratchboxone", "scratchboxtwo", "scratchboxthree",
        "scratchnx", "scratchny", "scratchmx", "scratchmy",
        "scratchunicode",
        --
        "scratchleftskip", "scratchrightskip", "scratchtopskip", "scratchbottomskip",
        --
        "doif", "doifnot", "doifelse",
        "doifinset", "doifnotinset", "doifinsetelse",
        "doifnextcharelse", "doifnextoptionalelse", "doifnextoptionalcselse", "doiffastoptionalcheckelse",
        "doifnextbgroupelse", "doifnextbgroupcselse",
        "doifnextparenthesiselse",
        "doifundefinedelse", "doifdefinedelse", "doifundefined", "doifdefined",
        "doifelsevalue", "doifvalue", "doifnotvalue",
        "doifnothing", "doifsomething", "doifelsenothing", "doifsomethingelse",
        "doifvaluenothing", "doifvaluesomething", "doifelsevaluenothing",
        "doifdimensionelse", "doifnumberelse", "doifnumber", "doifnotnumber",
        "doifcommonelse", "doifcommon", "doifnotcommon",
        "doifinstring", "doifnotinstring", "doifinstringelse",
        "doifassignmentelse", "docheckassignment",
        --
        "tracingall", "tracingnone", "loggingall",
        --
        "removetoks", "appendtoks", "prependtoks", "appendtotoks", "prependtotoks", "to",
        --
        "endgraf", "endpar", "everyendpar", "reseteverypar", "finishpar", "empty", "null", "space", "quad", "enspace",
        "obeyspaces", "obeylines", "obeyedspace", "obeyedline",
        "normalspace",
        --
        "executeifdefined",
        --
        "singleexpandafter", "doubleexpandafter", "tripleexpandafter",
        --
        "dontleavehmode", "removelastspace", "removeunwantedspaces", "keepunwantedspaces",
        --
        "wait", "writestatus", "define", "defineexpandable", "redefine",
        --
        "setmeasure", "setemeasure", "setgmeasure", "setxmeasure", "definemeasure", "freezemeasure", "measure", "measured",
        --
        "installcorenamespace",
        --
        "getvalue", "getuvalue", "setvalue", "setevalue", "setgvalue", "setxvalue", "letvalue", "letgvalue",
        "resetvalue", "undefinevalue", "ignorevalue",
        "setuvalue", "setuevalue", "setugvalue", "setuxvalue",
        --
        "globallet", "glet", "udef", "ugdef", "uedef", "uxdef", "checked", "unique",
        --
        "getparameters", "geteparameters", "getgparameters", "getxparameters", "forgetparameters", "copyparameters",
        --
        "getdummyparameters", "dummyparameter", "directdummyparameter", "setdummyparameter", "letdummyparameter",
        "usedummystyleandcolor", "usedummystyleparameter", "usedummycolorparameter",
        --
        "processcommalist", "processcommacommand", "quitcommalist", "quitprevcommalist",
        "processaction", "processallactions", "processfirstactioninset", "processallactionsinset",
        --
        "unexpanded", "expanded", "startexpanded", "stopexpanded", "protected", "protect", "unprotect",
        --
        "firstofoneargument",
        "firstoftwoarguments", "secondoftwoarguments",
        "firstofthreearguments", "secondofthreearguments", "thirdofthreearguments",
        "firstoffourarguments", "secondoffourarguments", "thirdoffourarguments", "fourthoffourarguments",
        "firstoffivearguments", "secondoffivearguments", "thirdoffivearguments", "fourthoffivearguments", "fifthoffivearguments",
        "firstofsixarguments", "secondofsixarguments", "thirdofsixarguments", "fourthofsixarguments", "fifthofsixarguments", "sixthofsixarguments",
        --
        "firstofoneunexpanded",
        --
        "gobbleoneargument", "gobbletwoarguments", "gobblethreearguments", "gobblefourarguments", "gobblefivearguments", "gobblesixarguments", "gobblesevenarguments", "gobbleeightarguments", "gobbleninearguments", "gobbletenarguments",
        "gobbleoneoptional", "gobbletwooptionals", "gobblethreeoptionals", "gobblefouroptionals", "gobblefiveoptionals",
        --
        "dorecurse", "doloop", "exitloop", "dostepwiserecurse", "recurselevel", "recursedepth", "dofastloopcs", "dowith",
        --
        "newconstant", "setnewconstant", "setconstant", "setconstantvalue",
        "newconditional", "settrue", "setfalse", "settruevalue", "setfalsevalue",
        --
        "newmacro", "setnewmacro", "newfraction",
        "newsignal",
        --
        "dosingleempty", "dodoubleempty", "dotripleempty", "doquadrupleempty", "doquintupleempty", "dosixtupleempty", "doseventupleempty",
        "dosingleargument", "dodoubleargument", "dotripleargument", "doquadrupleargument", "doquintupleargument", "dosixtupleargument", "doseventupleargument",
        "dosinglegroupempty", "dodoublegroupempty", "dotriplegroupempty", "doquadruplegroupempty", "doquintuplegroupempty",
        "permitspacesbetweengroups", "dontpermitspacesbetweengroups",
        --
        "nopdfcompression", "maximumpdfcompression", "normalpdfcompression",
        --
        "modulonumber", "dividenumber",
        --
        "getfirstcharacter", "doiffirstcharelse",
        --
        "startnointerference", "stopnointerference",
        --
        "twodigits","threedigits",
        --
        "leftorright",
        --
        "offinterlineskip", "oninterlineskip", "nointerlineskip",
        --
        "strut", "setstrut", "strutbox", "strutht", "strutdp", "strutwd", "struthtdp", "begstrut", "endstrut", "lineheight",
        --
        "ordordspacing", "ordopspacing", "ordbinspacing", "ordrelspacing",
        "ordopenspacing", "ordclosespacing", "ordpunctspacing", "ordinnerspacing",
        --
        "opordspacing", "opopspacing", "opbinspacing", "oprelspacing",
        "opopenspacing", "opclosespacing", "oppunctspacing", "opinnerspacing",
        --
        "binordspacing", "binopspacing", "binbinspacing", "binrelspacing",
        "binopenspacing", "binclosespacing", "binpunctspacing", "bininnerspacing",
        --
        "relordspacing", "relopspacing", "relbinspacing", "relrelspacing",
        "relopenspacing", "relclosespacing", "relpunctspacing", "relinnerspacing",
        --
        "openordspacing", "openopspacing", "openbinspacing", "openrelspacing",
        "openopenspacing", "openclosespacing", "openpunctspacing", "openinnerspacing",
        --
        "closeordspacing", "closeopspacing", "closebinspacing", "closerelspacing",
        "closeopenspacing", "closeclosespacing", "closepunctspacing", "closeinnerspacing",
        --
        "punctordspacing", "punctopspacing", "punctbinspacing", "punctrelspacing",
        "punctopenspacing", "punctclosespacing", "punctpunctspacing", "punctinnerspacing",
        --
        "innerordspacing", "inneropspacing", "innerbinspacing", "innerrelspacing",
        "inneropenspacing", "innerclosespacing", "innerpunctspacing", "innerinnerspacing",
        --
        "normalreqno",
        --
        "startimath", "stopimath", "normalstartimath", "normalstopimath",
        "startdmath", "stopdmath", "normalstartdmath", "normalstopdmath",
        --
        "uncramped", "cramped", "triggermathstyle", "mathstylefont", "mathsmallstylefont", "mathstyleface", "mathsmallstyleface", "mathstylecommand", "mathpalette",
        "mathstylehbox", "mathstylevbox", "mathstylevcenter", "mathstylevcenteredhbox", "mathstylevcenteredvbox",
        "mathtext", "setmathsmalltextbox", "setmathtextbox",
        --
        "triggerdisplaystyle", "triggertextstyle", "triggerscriptstyle", "triggerscriptscriptstyle",
        "triggeruncrampedstyle", "triggercrampedstyle",
        "triggersmallstyle", "triggeruncrampedsmallstyle", "triggercrampedsmallstyle",
        "triggerbigstyle", "triggeruncrampedbigstyle", "triggercrampedbigstyle",
        --
        "luaexpr", "expdoifelse", "expdoif", "expdoifnot", "expdoifcommonelse", "expdoifinsetelse",
        --
        "ctxdirectlua", "ctxlatelua", "ctxsprint", "ctxwrite", "ctxcommand", "ctxdirectcommand", "ctxlatecommand", "ctxreport",
        "ctxlua", "luacode", "lateluacode", "directluacode",
        "registerctxluafile", "ctxloadluafile",
        "luaversion", "luamajorversion", "luaminorversion",
        "ctxluacode", "luaconditional", "luaexpanded",
        "startluaparameterset", "stopluaparameterset", "luaparameterset",
        "definenamedlua",
        "obeylualines", "obeyluatokens",
        "startluacode", "stopluacode", "startlua", "stoplua",
        "startctxfunction","stopctxfunction","ctxfunction",
        "startctxfunctiondefinition","stopctxfunctiondefinition",
        --
        "carryoverpar",
        --
        "assumelongusagecs",
        --
        "Umathbotaccent",
        --
        "righttolefthbox", "lefttorighthbox", "righttoleftvbox", "lefttorightvbox", "righttoleftvtop", "lefttorightvtop",
        "rtlhbox", "ltrhbox", "rtlvbox", "ltrvbox", "rtlvtop", "ltrvtop",
        "autodirhbox", "autodirvbox", "autodirvtop",
        "lefttoright", "righttoleft","synchronizelayoutdirection","synchronizedisplaydirection","synchronizeinlinedirection",
        --
        "lesshyphens", "morehyphens", "nohyphens", "dohyphens",
        --
        "Ucheckedstartdisplaymath", "Ucheckedstopdisplaymath",
        --
    }
}
