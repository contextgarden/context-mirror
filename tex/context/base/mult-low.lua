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
        "xmlcatcodes",
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
        "startallmodes", "stopallmodes", "startnotallmodes", "stopnotallmodes", "doifallmodes", "doifallmodeselse", "doifnotallmodes",
        "startenvironment", "stopenvironment", "environment",
        "startcomponent", "stopcomponent", "component",
        "startproduct", "stopproduct", "product",
        "startproject", "stopproject", "project",
        "starttext", "stoptext", "startnotext", "stopnotext","startdocument", "stopdocument", "documentvariable",
        "startmodule", "stopmodule", "usemodule",
        --
        "startTEXpage", "stopTEXpage",
    --  "startMPpage", "stopMPpage", -- already catched by nested lexer
        --
        "enablemode", "disablemode", "preventmode", "pushmode", "popmode",
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
        --
        "doifsetupselse", "doifsetups", "doifnotsetups", "setup", "setups", "texsetup", "xmlsetup", "luasetup", "directsetup",
        --
        "newmode", "setmode", "resetmode",
        "newsystemmode", "setsystemmode", "resetsystemmode", "pushsystemmode", "popsystemmode",
        "booleanmodevalue",
        --
        "newcount", "newdimen", "newskip", "newmuskip", "newbox", "newtoks", "newread", "newwrite", "newmarks", "newinsert", "newattribute", "newif",
        "newlanguage", "newfamily", "newfam", "newhelp", -- not used
        --
        "then",
        --
        "donothing", "dontcomplain",
        --
        "donetrue", "donefalse",
        --
        "htdp",
        "unvoidbox",
        "vfilll",
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
        "ruledhbox", "ruledvbox", "ruledvtop", "ruledvcenter",
        "ruledhskip", "ruledvskip", "ruledkern", "ruledmskip", "ruledmkern",
        "ruledhglue", "ruledvglue", "normalhglue", "normalvglue",
        "ruledpenalty",
        --
        "scratchcounter", "globalscratchcounter",
        "scratchdimen", "globalscratchdimen",
        "scratchskip", "globalscratchskip",
        "scratchmuskip", "globalscratchmuskip",
        "scratchtoks", "globalscratchtoks",
        "scratchbox", "globalscratchbox",
        --
        "nextbox", "dowithnextbox", "dowithnextboxcs", "dowithnextboxcontent", "dowithnextboxcontentcs",
        --
        "scratchwidth", "scratchheight", "scratchdepth", "scratchoffset", "scratchdistance",
        "scratchhsize", "scratchvsize",
        --
        "scratchcounterone", "scratchcountertwo", "scratchcounterthree",
        "scratchdimenone", "scratchdimentwo", "scratchdimenthree",
        "scratchskipone", "scratchskiptwo", "scratchskipthree",
        "scratchmuskipone", "scratchmuskiptwo", "scratchmuskipthree",
        "scratchtoksone", "scratchtokstwo", "scratchtoksthree",
        "scratchboxone", "scratchboxtwo", "scratchboxthree",
        --
        "doif", "doifnot", "doifelse",
        "doifinset", "doifnotinset", "doifinsetelse",
        "doifnextcharelse", "doifnextoptionalelse", "doifnextbgroupelse", "doifnextparenthesiselse", "doiffastoptionalcheckelse",
        "doifundefinedelse", "doifdefinedelse", "doifundefined", "doifdefined",
        "doifelsevalue", "doifvalue", "doifnotvalue",
        "doifnothing", "doifsomething", "doifelsenothing", "doifsomethingelse",
        "doifvaluenothing", "doifvaluesomething", "doifelsevaluenothing",
        "doifdimensionelse", "doifnumberelse",
        "doifcommonelse", "doifcommon", "doifnotcommon",
        "doifinstring", "doifnotinstring", "doifinstringelse",
        "doifassignmentelse",
        --
        "tracingall", "tracingnone", "loggingall",
        --
        "appendtoks", "prependtoks", "appendtotoks", "prependtotoks", "to",
        --
        "endgraf", "empty", "null", "space", "quad", "enspace", "obeyspaces", "obeylines", "normalspace",
        --
        "executeifdefined",
        --
        "singleexpandafter", "doubleexpandafter", "tripleexpandafter",
        --
        "dontleavehmode", "removelastspace", "removeunwantedspaces",
        --
        "wait", "writestatus", "define", "redefine",
        --
        "setmeasure", "setemeasure", "setgmeasure", "setxmeasure", "definemeasure", "measure",
        --
        "getvalue", "setvalue", "setevalue", "setgvalue", "setxvalue", "letvalue", "letgvalue",
        "resetvalue", "undefinevalue", "ignorevalue",
        "setuvalue", "setuevalue", "setugvalue", "setuxvalue",
        "globallet", "glet",
        "getparameters", "geteparameters", "getgparameters", "getxparameters", "forgetparameters", "copyparameters",
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
        "dorecurse", "doloop", "exitloop", "dostepwiserecurse", "recurselevel", "recursedepth", "dofastloopcs",
        --
        "newconstant", "setnewconstant", "newconditional", "settrue", "setfalse", "setconstant",
        "newmacro", "setnewmacro", "newfraction",
        --
        "dosingleempty", "dodoubleempty", "dotripleempty", "doquadrupleempty", "doquintupleempty", "dosixtupleempty", "doseventupleempty",
        "dosingleargument", "dodoubleargument", "dotripleargument", "doquadrupleargument",
        "dosinglegroupempty", "dodoublegroupempty", "dotriplegroupempty", "doquadruplegroupempty", "doquintuplegroupempty",
        --
        "nopdfcompression", "maximumpdfcompression", "normalpdfcompression",
        --
        "modulonumber", "dividenumber",
        --
        "getfirstcharacter", "doiffirstcharelse",
        --
        "startnointerference", "stopnointerference",
        --
        "strut", "setstrut", "strutbox", "strutht", "strutdp", "strutwd", "begstrut", "endstrut",
    }
}
