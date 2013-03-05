if not modules then modules = { } end modules ['scrp-cjk'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We can speed this up by preallocating nodes and copying them but the
-- gain is not that large.

local utfchar = utf.char

local insert_node_after  = node.insert_after
local insert_node_before = node.insert_before
local remove_node        = nodes.remove

local nodepool           = nodes.pool
local new_glue           = nodepool.glue
local new_kern           = nodepool.kern
local new_penalty        = nodepool.penalty

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local a_prestat          = attributes.private('prestat')
local a_preproc          = attributes.private('preproc')

local categorytonumber   = scripts.categorytonumber
local numbertocategory   = scripts.numbertocategory
local hash               = scripts.hash
local numbertodataset    = scripts.numbertodataset

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local quaddata           = fonthashes.quads

local trace_details      = false  trackers.register("scripts.details", function(v) trace_details = v end)

local report_details     = logs.reporter("scripts","detail")

-- raggedleft is controlled by leftskip and we might end up with a situation where
-- the intercharacter spacing interferes with this; the solution is to patch the
-- nodelist but better is to use veryraggedleft

local inter_char_shrink          = 0
local inter_char_stretch         = 0
local inter_char_half_shrink     = 0
local inter_char_half_stretch    = 0
local inter_char_quarter_shrink  = 0
local inter_char_quarter_stretch = 0

local full_char_width            = 0
local half_char_width            = 0
local quarter_char_width         = 0

local inter_char_hangul_penalty  = 0

local function set_parameters(font,data)
    -- beware: parameters can be nil in e.g. punk variants
    local quad = quaddata[font]
    full_char_width            = quad
    half_char_width            = quad/2
    quarter_char_width         = quad/4
    inter_char_shrink          = data.inter_char_shrink_factor          * quad
    inter_char_stretch         = data.inter_char_stretch_factor         * quad
    inter_char_half_shrink     = data.inter_char_half_shrink_factor     * quad
    inter_char_half_stretch    = data.inter_char_half_stretch_factor    * quad
    inter_char_quarter_shrink  = data.inter_char_quarter_shrink_factor  * quad
    inter_char_quarter_stretch = data.inter_char_quarter_stretch_factor * quad
    inter_char_hangul_penalty  = data.inter_char_hangul_penalty
end

-- a test version did compensate for crappy halfwidth but we can best do that
-- at font definition time and/or just assume a correct font

local function trace_detail(current,what)
    local prev = current.prev
    local c_id = current.id
    local p_id = prev and prev.id
    if c_id == glyph_code then
        local c_ch = current.char
        if p_id == glyph_code then
            local p_ch = p_id and prev.char
            report_details("[U+%05X %s %s] [%s] [U+%05X %s %s]",p_ch,utfchar(p_ch),hash[p_ch] or "unknown",what,c_ch,utfchar(c_ch),hash[c_ch] or "unknown")
        else
            report_details("[%s] [U+%05X %s %s]",what,c_ch,utfchar(c_ch),hash[c_ch] or "unknown")
        end
    else
        if p_id == glyph_code then
            local p_ch = p_id and prev.char
            report_details("[U+%05X %s %s] [%s]",p_ch,utfchar(p_ch),hash[p_ch] or "unknown",what)
        else
            report_details("[%s]",what)
        end
    end
end

local function nobreak(head,current)
    if trace_details then
        trace_detail(current,"break")
    end
    insert_node_before(head,current,new_penalty(10000))
end

local function stretch_break(head,current)
    if trace_details then
        trace_detail(current,"stretch break")
    end
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function shrink_break(head,current)
    if trace_details then
        trace_detail(current,"shrink break")
    end
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"no break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function korean_break(head,current)
    if trace_details then
        trace_detail(current,"korean break")
    end
    insert_node_before(head,current,new_penalty(inter_char_hangul_penalty))
end

local function nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_shrink_nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink nobreak stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink nobreak stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_break_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function japanese_between_full_close_open(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese between full close open")
    end
    insert_node_before(head,current,new_kern(-half_char_width))
    insert_node_before(head,current,new_glue(half_char_width,0,inter_char_half_shrink))
    insert_node_before(head,current,new_kern(-half_char_width))
end

local function japanese_between_full_close_full_close(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese between full close full close")
    end
    insert_node_before(head,current,new_kern(-half_char_width))
 -- insert_node_before(head,current,new_glue(half_char_width,0,inter_char_half_shrink))
end

local function japanese_before_full_width_punct(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese before full width punct")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(quarter_char_width,0,inter_char_quarter_shrink))
    insert_node_before(head,current,new_kern(-quarter_char_width))
end

local function japanese_after_full_width_punct(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese after full width punct")
    end
    insert_node_before(head,current,new_kern(-quarter_char_width))
    insert_node_before(head,current,new_glue(quarter_char_width,0,inter_char_quarter_shrink))
end

local function nobreak_autoshrink_break_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_autoshrink_break_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_shrink_break_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_stretch_break_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch break shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_break_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch break autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

-- Korean: hangul

local korean_0 = {
}

local korean_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = korean_break,
    hiragana         = korean_break,
    katakana         = korean_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = korean_break,
    other            = korean_break,
}

local korean_2 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = stretch_break,
    other            = stretch_break,
}

local korean_3 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
    other            = nobreak,
}

local korean_4 = {
    jamo_initial     = nobreak,
    korean           = nobreak,
    chinese          = nobreak,
    hiragana         = nobreak,
    katakana         = nobreak,
    half_width_open  = nobreak,
    half_width_close = nobreak,
    full_width_open  = nobreak,
    full_width_close = nobreak,
    full_width_punct = nobreak,
    hyphen           = nobreak,
    non_starter      = nobreak,
    other            = nobreak,
}

local korean_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak_stretch,
    full_width_open  = stretch_break,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local injectors = { -- [previous] [current]
    jamo_final       = korean_1,
    korean           = korean_1,
    chinese          = korean_1,
    hiragana         = korean_1,
    katakana         = korean_1,
    hyphen           = korean_2,
    start            = korean_0,
    other            = korean_2,
    non_starter      = korean_3,
    full_width_open  = korean_4,
    half_width_open  = korean_4,
    full_width_close = korean_5,
    full_width_punct = korean_5,
    half_width_close = korean_5,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont, previous, last = nil, "start", nil
        while true do
            local upcoming, id = first.next, first.id
            if id == glyph_code then
                local a = first[a_prestat]
                local current = numbertocategory[a]
                local action = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = first.font
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[first[a_preproc]])
                        end
                        action(head,first)
                    end
                end
                previous = current
            else -- glue
                local p, n = first.prev, upcoming
                if p and n then
                    local pid, nid = p.id, n.id
                    if pid == glyph_code and nid == glyph_code then
                        local pa, na = p[a_prestat], n[a_prestat]
                        local pcjk, ncjk = pa and numbertocategory[pa], na and numbertocategory[na]
                        if not pcjk                 or not ncjk
                            or pcjk == "korean"     or ncjk == "korean"
                            or pcjk == "other"      or ncjk == "other"
                            or pcjk == "jamo_final" or ncjk == "jamo_initial" then
                            previous = "start"
                        else -- if head ~= first then
                            remove_node(head,first,true)
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "hangul",
    process  = process,
    datasets = { -- todo: metatables
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.50, -- of quad
            inter_char_quarter_stretch_factor = 0.50, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}

-- Chinese: hanzi

local chinese_0 = {
}

local chinese_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_2 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_3 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_4 = {
--  jamo_initial     = nil,
--  korean           = nil,
--  chinese          = nil,
--  hiragana         = nil,
--  katakana         = nil,
    half_width_open  = nobreak_autoshrink,
    half_width_close = nil,
    full_width_open  = nobreak_shrink,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
--  other            = nil,
}

local chinese_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_6 = {
    jamo_initial     = nobreak_stretch,
    korean           = nobreak_stretch,
    chinese          = nobreak_stretch,
    hiragana         = nobreak_stretch,
    katakana         = nobreak_stretch,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = nobreak_stretch,
}

local chinese_7 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_shrink_break_stretch,
    chinese          = stretch_break, -- nobreak_shrink_break_stretch,
    hiragana         = stretch_break, -- nobreak_shrink_break_stretch,
    katakana         = stretch_break, -- nobreak_shrink_break_stretch,
    half_width_open  = nobreak_shrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_shrink_nobreak_stretch,
    full_width_open  = nobreak_shrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_shrink_nobreak_stretch,
    full_width_punct = nobreak_shrink_nobreak_stretch,
    hyphen           = nobreak_shrink_break_stretch,
    non_starter      = nobreak_shrink_break_stretch,
    other            = nobreak_shrink_break_stretch,
}

local chinese_8 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_autoshrink_break_stretch,
    chinese          = stretch_break, -- nobreak_autoshrink_break_stretch,
    hiragana         = stretch_break, -- nobreak_autoshrink_break_stretch,
    katakana         = stretch_break, -- nobreak_autoshrink_break_stretch,
    half_width_open  = nobreak_autoshrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_open  = nobreak_autoshrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_punct = nobreak_autoshrink_nobreak_stretch,
    hyphen           = nobreak_autoshrink_break_stretch,
    non_starter      = nobreak_autoshrink_break_stretch,
    other            = nobreak_autoshrink_break_stretch,
}

local injectors = { -- [previous] [current]
    jamo_final       = chinese_1,
    korean           = chinese_1,
    chinese          = chinese_2,
    hiragana         = chinese_2,
    katakana         = chinese_2,
    hyphen           = chinese_3,
    start            = chinese_4,
    other            = chinese_5,
    non_starter      = chinese_5,
    full_width_open  = chinese_6,
    half_width_open  = chinese_6,
    full_width_close = chinese_7,
    full_width_punct = chinese_7,
    half_width_close = chinese_8,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont, previous, last = nil, "start", nil
        while true do
            local upcoming, id = first.next, first.id
            if id == glyph_code then
                local a = first[a_prestat]
                local current = numbertocategory[a]
                local action = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = first.font
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[first[a_preproc]])
                        end
                        action(head,first)
                    end
                end
                previous = current
            else -- glue
                local p, n = first.prev, upcoming
                if p and n then
                    local pid, nid = p.id, n.id
                    if pid == glyph_code and nid == glyph_code then
                        local pa, na = p[a_prestat], n[a_prestat]
                        local pcjk, ncjk = pa and numbertocategory[pa], na and numbertocategory[na]
                        if not pcjk                       or not ncjk
                            or pcjk == "korean"           or ncjk == "korean"
                            or pcjk == "other"            or ncjk == "other"
                            or pcjk == "jamo_final"       or ncjk == "jamo_initial"
                            or pcjk == "half_width_close" or ncjk == "half_width_open" then -- extra compared to korean
                            previous = "start"
                        else -- if head ~= first then
                            remove_node(head,first,true)
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "hanzi",
    process  = process,
    datasets = {
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.50, -- of quad
            inter_char_quarter_stretch_factor = 0.50, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}

-- Japanese: idiographic, hiragana, katakana, romanji / jis

local japanese_0 = {
}

local japanese_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_2 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = japanese_before_full_width_punct, -- nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_3 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_4 = {
--  jamo_initial     = nil,
--  korean           = nil,
--  chinese          = nil,
--  hiragana         = nil,
--  katakana         = nil,
    half_width_open  = nobreak_autoshrink,
    half_width_close = nil,
    full_width_open  = nobreak_shrink,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
--  other            = nil,
}

local japanese_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_6 = {
    jamo_initial     = nobreak_stretch,
    korean           = nobreak_stretch,
    chinese          = nobreak_stretch,
    hiragana         = nobreak_stretch,
    katakana         = nobreak_stretch,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = nobreak_stretch,
}

local japanese_7 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_shrink_break_stretch,
    chinese          = japanese_after_full_width_punct, -- stretch_break
    hiragana         = japanese_after_full_width_punct, -- stretch_break
    katakana         = japanese_after_full_width_punct, -- stretch_break
    half_width_open  = nobreak_shrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_shrink_nobreak_stretch,
    full_width_open  = japanese_between_full_close_open, -- !!
    full_width_close = japanese_between_full_close_full_close, -- nobreak_shrink_nobreak_stretch,
    full_width_punct = nobreak_shrink_nobreak_stretch,
    hyphen           = nobreak_shrink_break_stretch,
    non_starter      = nobreak_shrink_break_stretch,
    other            = nobreak_shrink_break_stretch,
}

local japanese_8 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_autoshrink_break_stretch,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_autoshrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_open  = nobreak_autoshrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_punct = nobreak_autoshrink_nobreak_stretch,
    hyphen           = nobreak_autoshrink_break_stretch,
    non_starter      = nobreak_autoshrink_break_stretch,
    other            = nobreak_autoshrink_break_stretch,
}

local injectors = { -- [previous] [current]
    jamo_final       = japanese_1,
    korean           = japanese_1,
    chinese          = japanese_2,
    hiragana         = japanese_2,
    katakana         = japanese_2,
    hyphen           = japanese_3,
    start            = japanese_4,
    other            = japanese_5,
    non_starter      = japanese_5,
    full_width_open  = japanese_6,
    half_width_open  = japanese_6,
    full_width_close = japanese_7,
    full_width_punct = japanese_7,
    half_width_close = japanese_8,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont, previous, last = nil, "start", nil
        while true do
            local upcoming, id = first.next, first.id
            if id == glyph_code then
                local a = first[a_prestat]
                local current = numbertocategory[a]
                local action = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = first.font
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[first[a_preproc]])
                        end
                        action(head,first)
                    end
                end
                previous = current
            else -- glue
                local p, n = first.prev, upcoming
                if p and n then
                    local pid, nid = p.id, n.id
                    if pid == glyph_code and nid == glyph_code then
                        local pa, na = p[a_prestat], n[a_prestat]
                        local pcjk, ncjk = pa and numbertocategory[pa], na and numbertocategory[na]
                        if not pcjk                       or not ncjk
                            or pcjk == "korean"           or ncjk == "korean"
                            or pcjk == "other"            or ncjk == "other"
                            or pcjk == "jamo_final"       or ncjk == "jamo_initial"
                            or pcjk == "half_width_close" or ncjk == "half_width_open" then -- extra compared to korean
                            previous = "start"
                        else -- if head ~= first then
                            remove_node(head,first,true)
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "nihongo", -- what name to use?
    process  = process,
    datasets = {
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.25, -- of quad
            inter_char_quarter_stretch_factor = 0.25, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}

