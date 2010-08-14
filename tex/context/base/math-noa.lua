if not modules then modules = { } end modules ['math-noa'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware: this is experimental code and there will be a more
-- generic (attribute value driven) interface too but for the
-- moment this is ok
--
-- we will also make dedicated processors (faster)

local utf = unicode.utf8

local set_attribute  = node.set_attribute
local has_attribute  = node.has_attribute
local mlist_to_hlist = node.mlist_to_hlist
local font_of_family = node.family_font
local fontdata       = fonts.identifiers
local nodecodes      = nodes.nodecodes

local format, rep  = string.format, string.rep
local utfchar, utfbyte = utf.char, utf.byte

noads = noads or { }

local trace_remapping  = false  trackers.register("math.remapping",  function(v) trace_remapping  = v end)
local trace_processing = false  trackers.register("math.processing", function(v) trace_processing = v end)
local trace_analyzing  = false  trackers.register("math.analyzing",  function(v) trace_analyzing  = v end)

local report_noads = logs.new("mathematics")

-- todo: nodes.noadcodes

local noad_ord              =  0
local noad_op_displaylimits =  1
local noad_op_limits        =  2
local noad_op_nolimits      =  3
local noad_bin              =  4
local noad_rel              =  5
local noad_open             =  6
local noad_close            =  7
local noad_punct            =  8
local noad_inner            =  9
local noad_under            = 10
local noad_over             = 11
local noad_vcenter          = 12

-- obsolete:
--
--    math_ord       = nodecodes.ord")            -- attr nucleus sub sup
--    math_op        = nodecodes.op")             -- attr nucleus sub sup subtype
--    math_bin       = nodecodes.bin")            -- attr nucleus sub sup
--    math_rel       = nodecodes.rel")            -- attr nucleus sub sup
--    math_punct     = nodecodes.punct")          -- attr nucleus sub sup
--_
--    math_open      = nodecodes.open")           -- attr nucleus sub sup
--    math_close     = nodecodes.close")          -- attr nucleus sub sup
--_
--    math_inner     = nodecodes.inner")          -- attr nucleus sub sup
--    math_vcenter   = nodecodes.vcenter")        -- attr nucleus sub sup
--    math_under     = nodecodes.under")          -- attr nucleus sub sup
--    math_over      = nodecodes.over")           -- attr nucleus sub sup

local math_noad      = nodecodes.noad           -- attr nucleus sub sup

local math_accent    = nodecodes.accent         -- attr nucleus sub sup accent
local math_radical   = nodecodes.radical        -- attr nucleus sub sup left degree
local math_fraction  = nodecodes.fraction       -- attr nucleus sub sup left right

local math_box       = nodecodes.sub_box        -- attr list
local math_sub       = nodecodes.sub_mlist      -- attr list
local math_char      = nodecodes.math_char      -- attr fam char
local math_text_char = nodecodes.math_text_char -- attr fam char
local math_delim     = nodecodes.delim          -- attr small_fam small_char large_fam large_char
local math_style     = nodecodes.style          -- attr style
local math_choice    = nodecodes.choice         -- attr display text script scriptscript
local math_fence     = nodecodes.fence          -- attr subtype

local simple_noads = table.tohash {
    math_noad,
}

local all_noads = {
    math_noad,
    math_box, math_sub,
    math_char, math_text_char, math_delim, math_style,
    math_accent, math_radical, math_fraction, math_choice, math_fence,
}

noads.processors = noads.processors or { }

local function process(start,what,n,parent)
    if n then n = n + 1 else n = 0 end
    while start do
        if trace_processing then
            report_noads("%s%s",rep("  ",n or 0),tostring(start))
        end
        local id = start.id
        local proc = what[id]
        if proc then
            local done, newstart = proc(start,what,n,parent or start.prev)
            if newstart then
                start = newstart
            end
        elseif id == math_char or id == math_text_char or id == math_delim then
            break
        elseif id == math_style then
            -- has a next
        elseif id == math_noad then
            local noad = start.nucleus      if noad then process(noad,what,n,start) end -- list
                  noad = start.sup          if noad then process(noad,what,n,start) end -- list
                  noad = start.sub          if noad then process(noad,what,n,start) end -- list
        elseif id == math_box or id == math_sub then
            local noad = start.list         if noad then process(noad,what,n,start) end -- list
        elseif id == math_fraction then
            local noad = start.num          if noad then process(noad,what,n,start) end -- list
                  noad = start.denom        if noad then process(noad,what,n,start) end -- list
                  noad = start.left         if noad then process(noad,what,n,start) end -- delimiter
                  noad = start.right        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == math_choice then
            local noad = start.display      if noad then process(noad,what,n,start) end -- list
                  noad = start.text         if noad then process(noad,what,n,start) end -- list
                  noad = start.script       if noad then process(noad,what,n,start) end -- list
                  noad = start.scriptscript if noad then process(noad,what,n,start) end -- list
        elseif id == math_fence then
            local noad = start.delim        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == math_radical then
            local noad = start.nucleus      if noad then process(noad,what,n,start) end -- list
                  noad = start.sup          if noad then process(noad,what,n,start) end -- list
                  noad = start.sub          if noad then process(noad,what,n,start) end -- list
                  noad = start.left         if noad then process(noad,what,n,start) end -- delimiter
                  noad = start.degree       if noad then process(noad,what,n,start) end -- list
        elseif id == math_accent then
            local noad = start.nucleus      if noad then process(noad,what,n,start) end -- list
                  noad = start.sup          if noad then process(noad,what,n,start) end -- list
                  noad = start.sub          if noad then process(noad,what,n,start) end -- list
                  noad = start.accent       if noad then process(noad,what,n,start) end -- list
                  noad = start.bot_accent   if noad then process(noad,what,n,start) end -- list
        else
            -- glue, penalty, etc
        end
        start = start.next
    end
end

noads.process = process

-- character remapping

local mathalphabet = attributes.private("mathalphabet")
local mathgreek    = attributes.private("mathgreek")

noads.processors.relocate = { }

local function report_remap(tag,id,old,new,extra)
    report_noads("remapping %s in font %s from U+%04X (%s) to U+%04X (%s)%s",tag,id,old,utfchar(old),new,utfchar(new),extra or "")
end

local remap_alphabets = mathematics.remap_alphabets
local fcs = fonts.color.set

-- we can have a global famdata == fonts.famdata and chrdata == fonts.chrdata

--~ This does not work out well, as there are no fallbacks. Ok, we could
--~ define a poor mans simplify mechanism.
--~
--~ local function checked(pointer)
--~     local char = pointer.char
--~     local fam = pointer.fam
--~     local id = font_of_family(fam)
--~     local tfmdata = fontdata[id]
--~     local tc = tfmdata and tfmdata.characters
--~     if not tc[char] then
--~         local specials = characters.data[char].specials
--~         if specials and (specials[1] == "char" or specials[1] == "font") then
--~             newchar = specials[#specials]
--~             if trace_remapping then
--~                 report_remap("fallback",id,char,newchar)
--~             end
--~             if trace_analyzing then
--~                 fcs(pointer,"font:isol")
--~             end
--~             pointer.char = newchar
--~             return true
--~         end
--~     end
--~ end

noads.processors.relocate[math_char] = function(pointer)
    local g = has_attribute(pointer,mathgreek) or 0
    local a = has_attribute(pointer,mathalphabet) or 0
    if a > 0 or g > 0 then
        if a > 0 then
            set_attribute(pointer,mathgreek,0)
        end
        if g > 0 then
            set_attribute(pointer,mathalphabet,0)
        end
        local char = pointer.char
        local newchar = remap_alphabets(char,a,g)
        if newchar then
            local fam = pointer.fam
            local id = font_of_family(fam)
            local tfmdata = fontdata[id]
            if tfmdata and tfmdata.characters[newchar] then -- we could probably speed this up
                if trace_remapping then
                    report_remap("char",id,char,newchar)
                end
                if trace_analyzing then
                    fcs(pointer,"font:isol")
                end
                pointer.char = newchar
                return true
            elseif trace_remapping then
                report_remap("char",id,char,newchar," fails")
            end
        else
            -- return checked(pointer)
        end
    else
        -- return checked(pointer)
    end
    if trace_analyzing then
        fcs(pointer,"font:medi")
    end
end

noads.processors.relocate[math_text_char] = function(pointer)
    if trace_analyzing then
        fcs(pointer,"font:init")
    end
end

noads.processors.relocate[math_delim] = function(pointer)
    if trace_analyzing then
        fcs(pointer,"font:fina")
    end
end

function noads.relocate_characters(head,style,penalties)
    process(head,noads.processors.relocate)
    return true
end

-- some resize options (this works ok because the content is
-- empty and no larger next will be forced)
--
-- beware: we don't use \delcode but \Udelcode and as such have
-- no large_fam; also, we need to check for subtype and/or
-- small_fam not being 0 because \. sits in 0,0 by default
--
-- todo: just replace the character by an ord noad
-- and remove the right delimiter as well

local mathsize = attributes.private("mathsize")

local resize = { } noads.processors.resize = resize

resize[math_fence] = function(pointer)
    if pointer.subtype == 1 then -- left
        local a = has_attribute(pointer,mathsize)
        if a and a > 0 then
            set_attribute(pointer,mathsize,0)
            local d = pointer.delim
            local df = d.small_fam
            local id = font_of_family(df)
            if id > 0 then
                local ch = d.small_char
                d.small_char = mathematics.big(fontdata[id],ch,a)
            end
        end
    end
end

function noads.resize_characters(head,style,penalties)
    process(head,resize)
    return true
end

-- respacing

local mathpunctuation = attributes.private("mathpunctuation")

local respace = { } noads.processors.respace = respace

local chardata = characters.data

-- only [nd,ll,ul][po][nd,ll,ul]

respace[math_noad] = function(pointer)
    if pointer.subtype == noad_ord then
        local a = has_attribute(pointer,mathpunctuation)
        if a and a > 0 then
            set_attribute(pointer,mathpunctuation,0)
            local current_nucleus = pointer.nucleus
            if current_nucleus.id == math_char then
                local current_char = current_nucleus.char
                local fc = chardata[current_char]
                fc = fc and fc.category
                if fc == "nd" or fc == "ll" or fc == "lu" then
                    local next_noad = pointer.next
                    if next_noad and next_noad.id == math_noad and next_noad.subtype == noad_punct then
                        local next_nucleus = next_noad.nucleus
                        if next_nucleus.id == math_char then
                            local next_char = next_nucleus.char
                            local nc = chardata[next_char]
                            nc = nc and nc.category
                            if nc == "po" then
                                local last_noad = next_noad.next
                                if last_noad and last_noad.id == math_noad and last_noad.subtype == noad_ord then
                                    local last_nucleus = last_noad.nucleus
                                    if last_nucleus.id == math_char then
                                        local last_char = last_nucleus.char
                                        local lc = chardata[last_char]
                                        lc = lc and lc.category
                                        if lc == "nd" or lc == "ll" or lc == "lu" then
                                            local ord = node.new(math_noad) -- todo: pool
                                            ord.subtype, ord.nucleus, ord.sub, ord.sup, ord.attr = noad_ord, next_noad.nucleus, next_noad.sub, next_noad.sup, next_noad.attr
                                        --  next_noad.nucleus, next_noad.sub, next_noad.sup, next_noad.attr = nil, nil, nil, nil
                                            next_noad.nucleus, next_noad.sub, next_noad.sup = nil, nil, nil -- else crash with attributes ref count
                                        --~ next_noad.attr = nil
                                            ord.next = last_noad
                                            pointer.next = ord
                                            node.free(next_noad)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function noads.respace_characters(head,style,penalties)
    process(head,respace)
    return true
end

-- math alternates

function fonts.initializers.common.mathalternates(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        for i=1,#goodies do
            -- first one counts
            -- we can consider sharing the attributes ... todo (only once scan)
            local mathgoodies = goodies[i].mathematics
            local alternates = mathgoodies and mathgoodies.alternates
            if alternates then
                local lastattribute, attributes = 0, { }
                for k, v in next, alternates do
                    lastattribute = lastattribute + 1
                    v.attribute = lastattribute
                    attributes[lastattribute] = v
                end
                tfmdata.shared.mathalternates           = alternates -- to be checked if shared is ok here
                tfmdata.shared.mathalternatesattributes = attributes -- to be checked if shared is ok here
                return
            end
        end
    end
end

fonts.otf.tables.features['mathalternates'] = 'Additional math alternative shapes'

fonts.otf.features.register('mathalternates') -- true
table.insert(fonts.triggers,"mathalternates")

fonts.initializers.base.otf.mathalternates = fonts.initializers.common.mathalternates
fonts.initializers.node.otf.mathalternates = fonts.initializers.common.mathalternates

local get_alternate = fonts.otf.get_alternate

local mathalternate = attributes.private("mathalternate")

local alternate = { } -- noads.processors.alternate = alternate

function mathematics.setalternate(fam,tag)
    local id = font_of_family(fam)
    local tfmdata = fontdata[id]
    local mathalternates = tfmdata.shared.mathalternates
    if mathalternates then
        local m = mathalternates[tag]
        tex.attribute[mathalternate] = m and m.attribute or attributes.unsetvalue
    end
end

alternate[math_char] = function(pointer)
    local a = has_attribute(pointer,mathalternate)
    if a and a > 0 then
        set_attribute(pointer,mathalternate,0)
        local tfmdata = fontdata[font_of_family(pointer.fam)] -- we can also have a famdata
        local mathalternatesattributes = tfmdata.shared.mathalternatesattributes
        if mathalternatesattributes then
            local what = mathalternatesattributes[a]
            local alt = get_alternate(tfmdata,pointer.char,what.feature,what.value)
            if alt then
                pointer.char = alt
            end
        end
    end
end

function noads.check_alternates(head,style,penalties)
    process(head,alternate)
    return true
end

-- the normal builder

function noads.mlist_to_hlist(head,style,penalties)
    return mlist_to_hlist(head,style,penalties), true
end

tasks.new (
    "math",
    {
        "before",
        "normalizers",
        "builders",
        "after",
    }
)

local actions = tasks.actions("math",2) -- head, style, penalties

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

function nodes.processors.mlist_to_hlist(head,style,penalties)
    starttiming(noads)
    local head, done = actions(head,style,penalties)
    stoptiming(noads)
    return head, done
end

callbacks.register('mlist_to_hlist',nodes.processors.mlist_to_hlist,"preprocessing math list")

-- tracing

statistics.register("math processing time", function()
    return statistics.elapsedseconds(noads)
end)
