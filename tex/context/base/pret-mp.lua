if not modules then modules = { } end modules ['pret-mp'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utffind = utf.byte, utf.find
local texsprint, texwrite = tex.sprint, tex.write
local ctxcatcodes = tex.ctxcatcodes

local buffers = buffers

local changestate, finishstate = buffers.changestate, buffers.finishstate

local visualizer = buffers.newvisualizer("mp")

visualizer.identifiers = { }

visualizer.identifiers.primitives = {
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

visualizer.identifiers.plain = {
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

visualizer.identifiers.metafun = {
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

visualizer.styles = {
    primitives = "",
    plain      = "\\sl",
    metafun    = "\\sl",
}

local styles = visualizer.styles

-- btex .. etex

local colors = {
    "prettyone",
    "prettytwo",
    "prettythree",
    "prettyfour",
}

local states = {
    [';']=1, ['$']=1, ['@']=1, ['#']=1,
   ['\\']=2,
    ['(']=3, [')']=3, ['[']=3, [']']=3, [':']=3, ['=']=3, ['<']=3, ['>']=3,  ['"']=3,
    ['-']=4, ['+']=4, ['/']=4, ['*']=4, ['|']=4, ['`']=4, ['!']=4, ['?']=4, ['^']=4, ['&']=4, ['%']=4,
    ['%']=4, ['.']=4, [',']=4
}

local known_words = { }

for k,v in next, visualizer.identifiers do
    for _,w in next, v do
        known_words[w] = k
    end
end

local function flush_mp_word(state, word, intex)
    if word then
        if intex then
            if word == 'etex' then
                state = changestate(2,state)
                texwrite(word)
                state = finishstate(state)
                return state, false
           else
                texwrite(word)
                return state, true
            end
        else
            local id = known_words[word]
            if id then
                state = changestate(2,state)
                if styles[id] then
                    texsprint(ctxcatcodes,styles[id])
                end
                texwrite(word)
                state = finishstate(state)
                return state, (word == 'btex') or (word == 'verbatimtex')
            else
                state = finishstate(state)
                texwrite(word)
                return state, intex
            end
        end
    else
        state = finishstate(state)
        return state, intex
    end
end

-- todo: split string in code and comment, and escape comment fast
-- could be generic

-- to be considered: visualizer => table [result, instr, incomment, word]

function visualizer.flush_line(str,nested)
    local state, word, instr, intex, incomment = 0, nil, false, false, false
    buffers.currentcolors = colors
    for c in utfcharacters(str) do
        if c == " " then
            state, intex = flush_mp_word(state, word, intex)
            word = nil
            texsprint(ctxcatcodes,"\\obs")
        elseif incomment then
            texwrite(c)
        elseif c == '%' then
            state = changestate(states[c], state)
            incomment = true
            texwrite(c)
            state = finishstate(state)
        elseif instr then
            if c == '"' then
                state = changestate(states[c],state)
                instr = false
                texwrite(c)
                state = finishstate(state)
            else
                texwrite(c)
            end
        elseif intex then
            if utffind(c,"^[%a]$") then
                if word then word = word .. c else word = c end
            else
                state, intex = flush_mp_word(state, word, intex)
                word = nil
                if intex then
                    texwrite(c)
                else
                    state = changestate(states[c], state)
                    texwrite(c)
                end
            end
        elseif utffind(c,"^[%a]$") then
            state = finishstate(state)
            if word then word = word .. c else word = c end
        else
            state, intex = flush_mp_word(state, word, intex)
            word = nil
            state = changestate(states[c], state)
            texwrite(c)
            state = finishstate(state)
            instr = (c == '"')
        end
    end
    state, intex = flush_mp_word(state, word, intex)
    state = finishstate(state)
end
