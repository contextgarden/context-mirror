if not modules then modules = { } end modules ['buff-imp-mp'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-mp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local primitives = table.tohash {
    'charcode', 'day', 'linecap', 'linejoin', 'miterlimit', 'month', 'pausing',
    'prologues', 'showstopping', 'time', 'tracingcapsules', 'tracingchoices',
    'tracingcommands', 'tracingequations', 'tracinglostchars',
    'tracingmacros', 'tracingonline', 'tracingoutput', 'tracingrestores',
    'tracingspecs', 'tracingstats', 'tracingtitles', 'truecorners',
    'warningcheck', 'year', 'mpprocset',
    'false', 'nullpicture', 'pencircle', 'true',
    'and', 'angle', 'arclength', 'arctime', 'ASCII', 'bluepart', 'boolean', 'bot',
    'char', 'color', 'cosd', 'cycle', 'decimal', 'directiontime', 'floor', 'fontsize',
    'greenpart', 'hex', 'infont', 'intersectiontimes', 'known', 'length', 'llcorner',
    'lrcorner', 'makepath', 'makepen', 'mexp', 'mlog', 'normaldeviate', 'not',
    'numeric', 'oct', 'odd', 'or', 'path', 'pair', 'pen', 'penoffset', 'picture', 'point',
    'postcontrol', 'precontrol', 'redpart', 'reverse', 'rotated', 'scaled',
    'shifted', 'sind', 'slanted', 'sqrt', 'str', 'string', 'subpath', 'substring',
    'transform', 'transformed', 'ulcorner', 'uniformdeviate', 'unknown',
    'urcorner', 'xpart', 'xscaled', 'xxpart', 'xypart', 'ypart', 'yscaled', 'yxpart',
    'yypart', 'zscaled',
    'addto', 'clip', 'input', 'interim', 'let', 'newinternal', 'save', 'setbounds',
    'shipout', 'show', 'showdependencies', 'showtoken', 'showvariable',
    'special',
    'begingroup', 'endgroup', 'of', 'curl', 'tension', 'and', 'controls',
    'reflectedabout', 'rotatedaround', 'interpath', 'on', 'off', 'beginfig',
    'endfig', 'def', 'vardef', 'enddef', 'epxr', 'suffix', 'text', 'primary', 'secondary',
    'tertiary', 'primarydef', 'secondarydef', 'tertiarydef', 'top', 'bottom',
    'ulft', 'urt', 'llft', 'lrt', 'randomseed', 'also', 'contour', 'doublepath',
    'withcolor', 'withpen', 'dashed', 'if', 'else', 'elseif', 'fi', 'for', 'endfor', 'forever', 'exitif',
    'forsuffixes', 'downto', 'upto', 'step', 'until',
    'charlist', 'extensible', 'fontdimen', 'headerbyte', 'kern', 'ligtable',
    'boundarychar', 'chardp', 'charext', 'charht', 'charic', 'charwd', 'designsize',
    'fontmaking', 'charexists',
    'cullit', 'currenttransform', 'gfcorners', 'grayfont', 'hround',
    'imagerules', 'lowres_fix', 'nodisplays', 'notransforms', 'openit',
    'displaying', 'currentwindow', 'screen_rows', 'screen_cols',
    'pixels_per_inch', 'cull', 'display', 'openwindow', 'numspecial',
    'totalweight', 'autorounding', 'fillin', 'proofing', 'tracingpens',
    'xoffset', 'chardx', 'granularity', 'smoothing', 'turningcheck', 'yoffset',
    'chardy', 'hppp', 'tracingedges', 'vppp',
    'extra_beginfig', 'extra_endfig', 'mpxbreak',
    'end', 'btex', 'etex', 'verbatimtex'
}

local plain = table.tohash {
    'ahangle', 'ahlength', 'bboxmargin', 'defaultpen', 'defaultscale',
    'labeloffset', 'background', 'currentpen', 'currentpicture', 'cuttings',
    'defaultfont', 'extra_beginfig', 'extra_endfig',
    'beveled', 'black', 'blue', 'bp', 'butt', 'cc', 'cm', 'dd', 'ditto', 'down', 'epsilon',
    'evenly', 'fullcircle', 'green', 'halfcircle', 'identity', 'in', 'infinity', 'left',
    'mitered', 'mm', 'origin', 'pensquare', 'pt', 'quartercircle', 'red', 'right',
    'rounded', 'squared', 'unitsquare', 'up', 'white', 'withdots',
    'abs', 'bbox', 'ceiling', 'center', 'cutafter', 'cutbefore', 'dir',
    'directionpoint', 'div', 'dotprod', 'intersectionpoint', 'inverse', 'mod', 'lft',
    'round', 'rt', 'unitvector', 'whatever',
    'cutdraw', 'draw', 'drawarrow', 'drawdblarrow', 'fill', 'filldraw', 'drawdot',
    'loggingall', 'pickup', 'tracingall', 'tracingnone', 'undraw', 'unfill',
    'unfilldraw',
    'buildcycle', 'dashpattern', 'decr', 'dotlabel', 'dotlabels', 'drawoptions',
    'incr', 'label', 'labels', 'max', 'min', 'thelabel', 'z',
    'beginchar', 'blacker', 'capsule_end', 'change_width',
    'define_blacker_pixels', 'define_corrected_pixels',
    'define_good_x_pixels', 'define_good_y_pixels',
    'define_horizontal_corrected_pixels', 'define_pixels',
    'define_whole_blacker_pixels', 'define_whole_pixels',
    'define_whole_vertical_blacker_pixels',
    'define_whole_vertical_pixels', 'endchar', 'extra_beginchar',
    'extra_endchar', 'extra_setup', 'font_coding_scheme',
    'font_extra_space'
}

local metafun = table.tohash {
    'unitcircle', 'fulldiamond', 'unitdiamond',
    'halfcircle', 'quartercircle',
    'llcircle', 'lrcircle', 'urcircle', 'ulcircle',
    'tcircle', 'bcircle', 'lcircle', 'rcircle',
    'lltriangle', 'lrtriangle', 'urtriangle', 'ultriangle',
    'smoothed', 'cornered', 'superellipsed', 'randomized', 'squeezed',
    'punked', 'curved', 'unspiked', 'simplified', 'blownup', 'stretched',
    'paralled', 'enlonged', 'shortened',
    'enlarged', 'leftenlarged', 'topenlarged', 'rightenlarged', 'bottomenlarged',
    'llenlarged', 'lrenlarged', 'urenlarged', 'ulenlarged',
    'llmoved', 'lrmoved', 'urmoved', 'ulmoved',
    'boundingbox', 'innerboundingbox', 'outerboundingbox',
    'bottomboundary', 'leftboundary', 'topboundary', 'rightboundary',
    'xsized', 'ysized', 'xysized',
    'cmyk', 'transparent', 'withshade', 'spotcolor',
    'drawfill', 'undrawfill',
    'inverted', 'uncolored', 'softened', 'grayed',
    'textext', 'graphictext',
    'loadfigure', 'externalfigure'
}

local context                      = context
local verbatim                     = context.verbatim
local makepattern                  = visualizers.makepattern

local MetapostSnippet              = context.MetapostSnippet
local startMetapostSnippet         = context.startMetapostSnippet
local stopMetapostSnippet          = context.stopMetapostSnippet

local MetapostSnippetConstructor   = verbatim.MetapostSnippetConstructor
local MetapostSnippetBoundary      = verbatim.MetapostSnippetBoundary
local MetapostSnippetSpecial       = verbatim.MetapostSnippetSpecial
local MetapostSnippetComment       = verbatim.MetapostSnippetComment
local MetapostSnippetNamePrimitive = verbatim.MetapostSnippetNamePrimitive
local MetapostSnippetNamePlain     = verbatim.MetapostSnippetNamePlain
local MetapostSnippetNameMetafun   = verbatim.MetapostSnippetNameMetafun
local MetapostSnippetName          = verbatim.MetapostSnippetName

local function visualizename(s)
    if primitives[s] then
        MetapostSnippetNamePrimitive(s)
    elseif plain[s] then
        MetapostSnippetNamePlain(s)
    elseif metafun[s] then
        MetapostSnippetNameMetafun(s)
    else
        MetapostSnippetName(s)
    end
end

local handler = visualizers.newhandler {
    startinline  = function() MetapostSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startMetapostSnippet() end,
    stopdisplay  = function() stopMetapostSnippet() end ,
    constructor  = function(s) MetapostSnippetConstructor(s) end,
    boundary     = function(s) MetapostSnippetBoundary(s) end,
    special      = function(s) MetapostSnippetSpecial(s) end,
    comment      = function(s) MetapostSnippetComment(s) end,
    string       = function(s) MetapostSnippetString(s) end,
    quote        = function(s) MetapostSnippetQuote(s) end,
    name         = visualizename,
}

local comment     = S("%")
local name        = (patterns.letter + S("_"))^1
local constructor = S("$@#")
local boundary    = S('()[]:=<>;"')
local special     = S("-+/*|`!?^&%.,")

local grammar = visualizers.newgrammar("default", { "visualizer",

    comment     = makepattern(handler,"comment",comment)
                * (V("space") + V("content"))^0,
    dstring     = makepattern(handler,"quote",patterns.dquote)
                * makepattern(handler,"string",patterns.nodquote)
                * makepattern(handler,"quote",patterns.dquote),
    name        = makepattern(handler,"name",name),
    constructor = makepattern(handler,"constructor",constructor),
    boundary    = makepattern(handler,"boundary",boundary),
    special     = makepattern(handler,"special",special),

    pattern     =
        V("comment") + V("dstring") + V("name") + V("constructor") + V("boundary") + V("special")
      + V("newline") * V("emptyline")^0 * V("beginline")
      + V("space")
      + V("default"),

    visualizer  =
        V("pattern")^1

} )

local parser = P(grammar)

visualizers.register("mp", { parser = parser, handler = handler, grammar = grammar } )
