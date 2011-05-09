if not modules then modules = { } end modules ['scrp-cjk'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local has_attribute      = node.has_attribute
local insert_node_after  = node.insert_after
local insert_node_before = node.insert_before
local remove_node        = nodes.remove

local nodepool           = nodes.pool
local new_glue           = nodepool.glue
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

-- raggedleft is controlled by leftskip and we might end up with a situation where
-- the intercharacter spacing interferes with this; the solution is to patch the
-- nodelist but better is to use veryraggedleft

local inter_char_stretch        = 0
local inter_char_half_shrink    = 0
local inter_char_hangul_penalty = 0

local function set_parameters(font,data)
    -- beware: parameters can be nil in e.g. punk variants
    local quad = quaddata[font]
    inter_char_half_shrink    = data.inter_char_half_shrink_factor * quad
    inter_char_stretch        = data.inter_char_stretch_factor * quad
    inter_char_hangul_penalty = data.inter_char_hangul_penalty
end

-- a test version did compensate for crappy halfwidth but we can best do that
-- at font definition time and/or just assume a correct font

local function nobreak(head,current)
    insert_node_before(head,current,new_penalty(10000))
end

local function stretch_break(head,current)
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function shrink_break(head,current)
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function korean_break(head,current)
    insert_node_before(head,current,new_penalty(inter_char_hangul_penalty))
end

local function nobreak_shrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_autoshrink(head,current)
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
end

local function nobreak_stretch_nobreak_shrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_nobreak_autoshrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
end

local function nobreak_shrink_nobreak_stretch(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_nobreak_stretch(head,current)
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_break_stretch(head,current)
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch_nobreak_shrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_break_stretch_nobreak_autoshrink(head,current)
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
end

local function nobreak_autoshrink_break_stretch_nobreak_shrink(head,current)
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_shrink_break_stretch_nobreak_autoshrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    if true then
        insert_node_before(head,current,new_penalty(10000))
        insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    end
end

local function nobreak_stretch_break_shrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_break_autoshrink(head,current)
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    if true then
        insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    end
end

-- hangul (korean)

local injectors = { -- [previous] [current]
    jamo_final = {
        jamo_initial     = korean_break,
        korean           = korean_break,
        chinese          = korean_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = korean_break,
        other            = korean_break,
    },
    korean = {
        jamo_initial     = korean_break,
        korean           = korean_break,
        chinese          = korean_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = korean_break,
        other            = korean_break,
    },
    chinese = {
        jamo_initial     = korean_break,
        korean           = korean_break,
        chinese          = korean_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = korean_break,
        other            = korean_break,
    },
    hyphen = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = stretch_break,
        other            = stretch_break,
    },
    start = {
    --  jamo_initial     = nil,
    --  korean           = nil,
    --  chinese          = nil,
    --  half_width_open  = nil,
    --  half_width_close = nil,
    --  full_width_open  = nil,
    --  full_width_close = nil,
    --  hyphen           = nil,
    --  non_starter      = nil,
    --  other            = nil,
    },
    other = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = stretch_break,
        other            = stretch_break,
    },
    non_starter = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak,
        full_width_open  = stretch_break,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = nobreak,
        other            = nobreak,
    },
    full_width_open = {
        jamo_initial     = nobreak,
        korean           = nobreak,
        chinese          = nobreak,
        half_width_open  = nobreak,
        half_width_close = nobreak,
        full_width_open  = nobreak,
        full_width_close = nobreak,
        hyphen           = nobreak,
        non_starter      = nobreak,
        other            = nobreak,
    },
    half_width_open = {
        jamo_initial     = nobreak,
        korean           = nobreak,
        chinese          = nobreak,
        half_width_open  = nobreak,
        half_width_close = nobreak,
        full_width_open  = nobreak,
        full_width_close = nobreak,
        hyphen           = nobreak,
        non_starter      = nobreak,
        other            = nobreak,
    },
    full_width_close = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak_stretch,
        full_width_open  = stretch_break,
        full_width_close = nobreak_stretch,
        hyphen           = nobreak_stretch,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    half_width_close = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = stretch_break,
        half_width_close = nobreak_stretch,
        full_width_open  = stretch_break,
        full_width_close = nobreak_stretch,
        hyphen           = nobreak_stretch,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
}

local function process(head,first,last)
    if first ~= last then
        local lastfont, previous, last = nil, "start", nil
        while true do
            local upcoming, id = first.next, first.id
            if id == glyph_code then
                local a = has_attribute(first,a_prestat)
                local current = numbertocategory[a]
                local action = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = first.font
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[has_attribute(first,a_preproc)])
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
                        local pa, na = has_attribute(p,a_prestat), has_attribute(n,a_prestat)
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
    datasets = {
        default = {
            inter_char_stretch_factor     = 0.50, -- of quad
            inter_char_half_shrink_factor = 0.50, -- of quad
            inter_char_hangul_penalty     =   50,
        },
    },
}

-- hanzi (chinese)

local injectors = { -- [previous] [current]
    jamo_final = {
        jamo_initial     = korean_break,
        korean           = korean_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
    --  hyphen           = nil,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    korean = {
        jamo_initial     = korean_break,
        korean           = korean_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
    --  hyphen           = nil,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    chinese = {
        jamo_initial     = korean_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
        hyphen           = nobreak_stretch,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    hyphen = {
        jamo_initial     = korean_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
    --  hyphen           = nil,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    start = {
    --  jamo_initial     = nil,
    --  korean           = nil,
    --  chinese          = nil,
        half_width_open  = nobreak_autoshrink,
        half_width_close = nil,
        full_width_open  = nobreak_shrink,
        full_width_close = nobreak,
    --  hyphen           = nil,
        non_starter      = nobreak,
    --  other            = nil,
    },
    other = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
    --  hyphen           = nil,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    non_starter = {
        jamo_initial     = stretch_break,
        korean           = stretch_break,
        chinese          = stretch_break,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
    --  hyphen           = nil,
        non_starter      = nobreak_stretch,
        other            = stretch_break,
    },
    full_width_open = {
        jamo_initial     = nobreak_stretch,
        korean           = nobreak_stretch,
        chinese          = nobreak_stretch,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_break_shrink,
        full_width_close = nobreak_stretch,
        hyphen           = nobreak_stretch,
        non_starter      = nobreak_stretch,
        other            = nobreak_stretch,
    },
    half_width_open = {
        jamo_initial     = nobreak_stretch,
        korean           = nobreak_stretch,
        chinese          = nobreak_stretch,
        half_width_open  = nobreak_stretch_break_autoshrink,
        half_width_close = nobreak_stretch,
        full_width_open  = nobreak_stretch_nobreak_shrink,
        full_width_close = nobreak_stretch,
        hyphen           = nobreak_stretch,
        non_starter      = nobreak_stretch,
        other            = nobreak_stretch,
    },
    full_width_close = {
        jami_initial     = nobreak_shrink_break_stretch,
        korean           = nobreak_shrink_break_stretch,
        chinese          = stretch_break, -- nobreak_shrink_break_stretch,
        half_width_open  = nobreak_shrink_break_stretch_nobreak_autoshrink,
        half_width_close = nobreak_shrink_nobreak_stretch,
        full_width_open  = nobreak_shrink_break_stretch_nobreak_shrink,
        full_width_close = nobreak_shrink_nobreak_stretch,
        hyphen           = nobreak_shrink_break_stretch,
        non_starter      = nobreak_shrink_break_stretch,
        other            = nobreak_shrink_break_stretch,
    },
    half_width_close = {
        jami_initial     = nobreak_shrink_break_stretch,
        korean           = nobreak_autoshrink_break_stretch,
        chinese          = stretch_break, -- nobreak_autoshrink_break_stretch,
        half_width_open  = nobreak_autoshrink_break_stretch_nobreak_autoshrink,
        half_width_close = nobreak_autoshrink_nobreak_stretch,
        full_width_open  = nobreak_autoshrink_break_stretch_nobreak_shrink,
        full_width_close = nobreak_autoshrink_nobreak_stretch,
        hyphen           = nobreak_autoshrink_break_stretch,
        non_starter      = nobreak_autoshrink_break_stretch,
        other            = nobreak_autoshrink_break_stretch,
    },
}

local function process(head,first,last)
    if first ~= last then
        local lastfont, previous, last = nil, "start", nil
        while true do
            local upcoming, id = first.next, first.id
            if id == glyph_code then
                local a = has_attribute(first,a_prestat)
                local current = numbertocategory[a]
                local action = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = first.font
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[has_attribute(first,a_preproc)])
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
                        local pa, na = has_attribute(p,a_prestat), has_attribute(n,a_prestat)
                        local pcjk, ncjk = pa and numbertocategory[pa], na and numbertocategory[na]
                        if not pcjk                 or not ncjk
                            or pcjk == "korean"     or ncjk == "korean"
                            or pcjk == "other"      or ncjk == "other"
                         -- or pcjk == "jamo_final" or ncjk == "jamo_initial" then
                            or pcjk == "jamo_final" or ncjk == "jamo_initial" or pcjk == "half_width_close" or ncjk == "half_width_open" then
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
            inter_char_stretch_factor     = 0.50, -- of quad
            inter_char_half_shrink_factor = 0.50, -- of quad
            inter_char_hangul_penalty     =   50,
        },
    },
}
