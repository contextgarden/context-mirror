-- filename : type-mp.lua
-- comment  : companion to core-buf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not buffers                then buffers                = { } end
if not buffers.visualizers    then buffers.visualizers    = { } end
if not buffers.visualizers.mp then buffers.visualizers.mp = { } end

buffers.visualizers.mp.identifiers = { }

buffers.visualizers.mp.identifiers.primitives = {
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

buffers.visualizers.mp.identifiers.plain = {
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

buffers.visualizers.mp.identifiers.metafun = {
    'unitcircle', 'fulldiamond', 'unitdiamond',
    'halfcircle', 'quartercircle',
    'llcircle', 'lrcircle', 'urcircle', 'ulcircle',
    'tcircle', 'bcircle', 'lcircle', 'rcircle',
    'lltriangle', 'lrtriangle', 'urtriangle', 'ultriangle',
    'smoothed', 'cornered', 'superellipsed', 'randomized', 'squeezed',
    'punked', 'curved', 'unspiked', 'simplified', 'blownup', 'stretched',
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

buffers.visualizers.mp.words = { }

for k,v in pairs(buffers.visualizers.mp.identifiers) do
    for _,w in pairs(v) do
        buffers.visualizers.mp.words[w] = k
    end
end

buffers.visualizers.mp.styles = { }

buffers.visualizers.mp.styles.primitives = ""
buffers.visualizers.mp.styles.plain      = "\\sl "
buffers.visualizers.mp.styles.metafun    = "\\sl "

-- btex .. etex

buffers.visualizers.mp.colors = {
    "prettyone",
    "prettytwo",
    "prettythree",
    "prettyfour",
}

buffers.visualizers.mp.states = {
    [';']=1, ['$']=1, ['@']=1, ['#']=1,
   ['\\']=2,
    ['(']=3, [')']=3, ['[']=3, [']']=3, [':']=3, ['=']=3, ['<']=3, ['>']=3,
    ['-']=4, ['+']=4, ['/']=4, ['*']=4, ['|']=4, ['`']=4, ['!']=4, ['?']=4, ['^']=4, ['&']=4, ['%']=4,
    ['%']=4, ['.']=4, [',']=4
}

function buffers.flush_mp_word(state, word, intex, result)
    if #word>0 then
        if intex then
            if word == 'etex' then
                state = buffers.change_state(2, state, result)
                result[#result+1] = word
                state = buffers.finish_state(state,result)
                return state, false
           else
                result[#result+1] = word
                return state, true
            end
        else
            local id = buffers.visualizers.mp.words[word]
            if id then
                state = buffers.change_state(2, state, result)
                if buffers.visualizers.mp.styles[id] then
                    result[#result+1] = buffers.visualizers.mp.styles[id] .. word
                else
                    result[#result+1] = word
                end
                state = buffers.finish_state(state,result)
                return state, (word == 'btex') or (word == 'verbatimtex')
            else
                state = buffers.finish_state(state,result)
                result[#result+1] = word
                return state, intex
            end
        end
    else
        state = buffers.finish_state(state,result)
        return state, intex
    end
end

-- todo: split string in code and comment, and escape comment fast
-- could be generic

-- to be considered: visualizer => table [result, instr, incomment, word]

function buffers.visualizers.mp.flush_line_(str,nested)
    local result, state, word = { }, 0, ""
    local instr, intex, incomment = false, false, false
    local byte, find = utf.byte, utf.find
    local finish, change = buffers.finish_state, buffers.change_state
    buffers.currentcolors = buffers.visualizers.mp.colors
    for c in string.utfcharacters(str) do
        if incomment then
            result[#result+1] = buffers.escaped_chr(c)
        elseif c == '%' then
            state = change(buffers.visualizers.mp.states[c], state, result)
            incomment = true
            result[#result+1] =  "\\char" .. byte(c) .. " "
            state = finish(state,result)
        elseif instr then
            if c == '"' then
                state = change(buffers.visualizers.mp.states[c], state, result)
                instr = false
                result[#result+1] = "\\char" .. byte(c) .. " "
                state = finish(state,result)
            elseif find(c,"^[%a%d]$") then
                result[#result+1] = c
            else
                result[#result+1] = "\\char" .. byte(c) .. " "
            end
        elseif c == " " then
            state, intex = buffers.flush_mp_word_(state, word, intex, result)
            word = ""
            result[#result+1] = "\\obs "
        elseif intex then
            if find(c,"^[%a]$") then
                word = word .. c
            else
                state, intex = buffers.flush_mp_word_(state, word, intex, result)
                word = ""
                if intex then
                    if find(c,"^[%d]$") then
                        result[#result+1] = c
                    else
                        result[#result+1] = "\\char" .. byte(c) .. " "
                    end
                else
                    state = change(buffers.visualizers.mp.states[c], state, result)
                    result[#result+1] = "\\char" .. byte(c) .. " "
                end
            end
        elseif find(c,"^[%a]$") then
            state = finish(state,result)
            word = word .. c
        else
            state, intex = buffers.flush_mp_word_(state, word, intex, result)
            word = ""
            state = change(buffers.visualizers.mp.states[c], state, result)
            result[#result+1] = "\\char" .. byte(c) .. " "
            instr = (c == '"')
        end
    end
    state, intex = buffers.flush_mp_word_(state, word, intex, result)
    state = finish(state,result)
    buffers.flush_result(result,false)
end
