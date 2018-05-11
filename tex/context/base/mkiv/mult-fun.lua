return {
    internals = {
        --
        "nocolormodel", "greycolormodel", "graycolormodel", "rgbcolormodel", "cmykcolormodel",
        "shadefactor",
        "textextoffset",
        "normaltransparent", "multiplytransparent", "screentransparent", "overlaytransparent",
        "softlighttransparent", "hardlighttransparent", "colordodgetransparent", "colorburntransparent",
        "darkentransparent", "lightentransparent", "differencetransparent", "exclusiontransparent",
        "huetransparent", "saturationtransparent", "colortransparent", "luminositytransparent",
     -- "originlength", "tickstep ", "ticklength",
     -- "autoarrows", "ahfactor",
     -- "angleoffset", anglelength", anglemethod",
        "ahvariant", "ahdimple", "ahfactor", "ahscale",
        "metapostversion",
        "maxdimensions",
        "drawoptionsfactor",
        "dq", "sq",
        "crossingscale", "crossingoption",
    },
    commands = {
        "loadfile", "loadimage", "loadmodule",
        "dispose", "nothing", "transparency", "tolist", "topath", "tocycle",
        --
        "sqr", "log", "ln", "exp", "inv", "pow", "pi", "radian",
        "tand", "cotd", "sin", "cos", "tan", "cot", "atan", "asin", "acos",
        "invsin", "invcos", "invtan", "acosh", "asinh", "sinh", "cosh", "tanh",
        "zmod",
        "paired", "tripled",
        "unitcircle", "fulldiamond", "unitdiamond", "fullsquare", "unittriangle", "fulltriangle",
     -- "halfcircle", "quartercircle",
        "llcircle", "lrcircle", "urcircle", "ulcircle",
        "tcircle", "bcircle", "lcircle", "rcircle",
        "lltriangle", "lrtriangle", "urtriangle", "ultriangle",
        "uptriangle", "downtriangle", "lefttriangle", "righttriangle", "triangle",
        "smoothed", "cornered", "superellipsed", "randomized", "randomizedcontrols", "squeezed", "enlonged", "shortened",
        "punked", "curved", "unspiked", "simplified", "blownup", "stretched",
        "enlarged", "leftenlarged", "topenlarged", "rightenlarged", "bottomenlarged",
        "crossed", "laddered", "randomshifted", "interpolated", "perpendicular", "paralleled", "cutends", "peepholed",
        "llenlarged", "lrenlarged", "urenlarged", "ulenlarged",
        "llmoved", "lrmoved", "urmoved", "ulmoved",
        "rightarrow", "leftarrow", "centerarrow", "drawdoublearrows",
        "boundingbox", "innerboundingbox", "outerboundingbox", "pushboundingbox", "popboundingbox",
        "boundingradius", "boundingcircle", "boundingpoint",
        "crossingunder", "insideof", "outsideof",
        "bottomboundary", "leftboundary", "topboundary", "rightboundary",
        "xsized", "ysized", "xysized", "sized", "xyscaled",
        "intersection_point", "intersection_found", "penpoint",
        "bbwidth", "bbheight",
        "withshade", "withcircularshade", "withlinearshade", -- old but kept
        "defineshade", "shaded",
     -- "withshading", "withlinearshading", "withcircularshading", "withfromshadecolor", "withtoshadecolor",
        "shadedinto", "withshadecolors",
        "withshadedomain", "withshademethod", "withshadefactor", "withshadevector",
        "withshadecenter", "withshadedirection", "withshaderadius", "withshadetransform",
        "withshadestep", "withshadefraction", "withshadeorigin", "shownshadevector", "shownshadeorigin",
        "cmyk", "spotcolor", "multitonecolor", "namedcolor",
        "drawfill", "undrawfill",
        "inverted", "uncolored", "softened", "grayed", "greyed",
        "onlayer",
        "along",
        "graphictext", "loadfigure", "externalfigure", "figure", "register", "outlinetext", -- "lua",
        "checkedbounds", "checkbounds", "strut", "rule",
        "withmask", "bitmapimage",
        "colordecimals", "ddecimal", "dddecimal", "ddddecimal", "colordecimalslist",
        "textext", "thetextext", "rawtextext", "textextoffset", "texbox", "thetexbox", "rawtexbox", "istextext",
        "verbatim",
        "thelabel", "label",
        "autoalign",
        "transparent", "withtransparency",
        "property", "properties", "withproperties",
        "asgroup",
        "infont", -- redefined using textext
     -- "set_linear_vector", "set_circular_vector",
     -- "linear_shade", "circular_shade",
     -- "define_linear_shade", "define_circular_shade",
     -- "define_circular_linear_shade", "define_circular_linear_shade",
     -- "define_sampled_linear_shade", "define_sampled_circular_shade",
        "space", "crlf", "dquote", "percent", "SPACE", "CRLF", "DQUOTE", "PERCENT",
        "grayscale", "greyscale", "withgray", "withgrey",
        "colorpart", "colorlike",
        "readfile",
        "clearxy", "unitvector", "center", -- redefined
        "epsed", "anchored",
        "originpath", "infinite",
        "break",
        "xstretched", "ystretched", "snapped",
        --
        "pathconnectors", "function",
        "constructedfunction", "constructedpath", "constructedpairs",
     -- "punkedfunction", "punkedpath", "punkedpairs",
        "straightfunction", "straightpath", "straightpairs",
        "curvedfunction", "curvedpath", "curvedpairs",
     -- "tightfunction", "tightpath", "tightpairs",
        --
        "evenly", "oddly",
        --
        "condition",
        --
        "pushcurrentpicture", "popcurrentpicture",
        --
        "arrowpath", "resetarrows",
     -- "colorlike",  "dowithpath", "rangepath", "straightpath", "addbackground",
     -- "cleanstring", "asciistring", "setunstringed", "getunstringed", "unstringed",
     -- "showgrid",
     -- "phantom",
     -- "xshifted", "yshifted",
     -- "drawarrowpath", "midarrowhead", "arrowheadonpath",
     -- "drawxticks", "drawyticks", "drawticks",
     -- "pointarrow",
     -- "thefreelabel", "freelabel", "freedotlabel",
     -- "anglebetween", "colorcircle",
     -- "remapcolors", "normalcolors", "resetcolormap", "remapcolor", "remappedcolor",
     -- "recolor", "refill", "redraw", "retext", "untext", "restroke", "reprocess", "repathed",
        "tensecircle", "roundedsquare",
        "colortype", "whitecolor", "blackcolor", "basiccolors", "complementary", "complemented",
        "resolvedcolor",
        --
     -- "swappointlabels",
        "normalfill", "normaldraw", "visualizepaths", "detailpaths", "naturalizepaths",
        "drawboundary", "drawwholepath", "drawpathonly",
        "visualizeddraw", "visualizedfill", "detaileddraw",
        "draworigin", "drawboundingbox",
        "drawpath",
        "drawpoint", "drawpoints", "drawcontrolpoints", "drawcontrollines",
        "drawpointlabels",
        "drawlineoptions", "drawpointoptions", "drawcontroloptions", "drawlabeloptions",
        "draworiginoptions", "drawboundoptions", "drawpathoptions", "resetdrawoptions",
        --
        "undashed", "pencilled",
        --
        "decorated", "redecorated", "undecorated",
        --
        "passvariable", "passarrayvariable", "tostring", "topair", "format", "formatted", "quotation", "quote",
        "startpassingvariable", "stoppassingvariable",
        --
        "eofill", "eoclip", "nofill", "fillup", "eofillup",
        "area",
        --
        "addbackground",
        --
        "shadedup", "shadeddown", "shadedleft", "shadedright",
        --
        "sortlist", "copylist", "shapedlist", "listtocurves", "listtolines", "listsize", "listlast", "uniquelist",
        --
        "circularpath", "squarepath", "linearpath",
    },
}
