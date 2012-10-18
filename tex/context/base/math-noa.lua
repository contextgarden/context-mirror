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
--
-- beware: names will change as we wil make noads.xxx.handler i.e. xxx
-- subnamespaces

-- 20D6 -> 2190
-- 20D7 -> 2192

local utf = unicode.utf8

local utfchar, utfbyte = utf.char, utf.byte
local format, rep  = string.format, string.rep
local concat = table.concat

local fonts, nodes, node, mathematics = fonts, nodes, node, mathematics

local otf                 = fonts.handlers.otf
local otffeatures         = fonts.constructors.newfeatures("otf")
local registerotffeature  = otffeatures.register

local trace_remapping     = false  trackers.register("math.remapping",   function(v) trace_remapping   = v end)
local trace_processing    = false  trackers.register("math.processing",  function(v) trace_processing  = v end)
local trace_analyzing     = false  trackers.register("math.analyzing",   function(v) trace_analyzing   = v end)
local trace_normalizing   = false  trackers.register("math.normalizing", function(v) trace_normalizing = v end)
local trace_collapsing    = false  trackers.register("math.collapsing",  function(v) trace_collapsing  = v end)
local trace_goodies       = false  trackers.register("math.goodies",     function(v) trace_goodies     = v end)
local trace_variants      = false  trackers.register("math.variants",    function(v) trace_variants    = v end)
local trace_italics       = false  trackers.register("math.italics",     function(v) trace_italics     = v end)
local trace_families      = false  trackers.register("math.families",    function(v) trace_families    = v end)

local check_coverage      = true   directives.register("math.checkcoverage", function(v) check_coverage = v end)

local report_processing   = logs.reporter("mathematics","processing")
local report_remapping    = logs.reporter("mathematics","remapping")
local report_normalizing  = logs.reporter("mathematics","normalizing")
local report_collapsing   = logs.reporter("mathematics","collapsing")
local report_goodies      = logs.reporter("mathematics","goodies")
local report_variants     = logs.reporter("mathematics","variants")
local report_italics      = logs.reporter("mathematics","italics")
local report_families     = logs.reporter("mathematics","families")

local set_attribute       = node.set_attribute
local has_attribute       = node.has_attribute
local mlist_to_hlist      = node.mlist_to_hlist
local font_of_family      = node.family_font
local insert_node_after   = node.insert_after
local free_node           = node.free
local new_node            = node.new -- todo: pool: math_noad math_sub

local new_kern            = nodes.pool.kern

local fonthashes          = fonts.hashes
local fontdata            = fonthashes.identifiers
local fontcharacters      = fonthashes.characters
local fontproperties      = fonthashes.properties
local fontitalics         = fonthashes.italics
local fontquads           = fonthashes.quads

local variables           = interfaces.variables
local texattribute        = tex.attribute
local unsetvalue          = attributes.unsetvalue

noads                     = noads or { }  -- todo: only here
local noads               = noads

noads.processors          = noads.processors or { }
local processors          = noads.processors

noads.handlers            = noads.handlers   or { }
local handlers            = noads.handlers

local tasks               = nodes.tasks

local nodecodes           = nodes.nodecodes
local noadcodes           = nodes.noadcodes

local noad_ord            = noadcodes.ord
local noad_rel            = noadcodes.rel
local noad_punct          = noadcodes.punct

local math_noad           = nodecodes.noad           -- attr nucleus sub sup
local math_accent         = nodecodes.accent         -- attr nucleus sub sup accent
local math_radical        = nodecodes.radical        -- attr nucleus sub sup left degree
local math_fraction       = nodecodes.fraction       -- attr nucleus sub sup left right
local math_box            = nodecodes.subbox         -- attr list
local math_sub            = nodecodes.submlist       -- attr list
local math_char           = nodecodes.mathchar       -- attr fam char
local math_textchar       = nodecodes.mathtextchar   -- attr fam char
local math_delim          = nodecodes.delim          -- attr small_fam small_char large_fam large_char
local math_style          = nodecodes.style          -- attr style
local math_choice         = nodecodes.choice         -- attr display text script scriptscript
local math_fence          = nodecodes.fence          -- attr subtype

local left_fence_code     = 1

local function process(start,what,n,parent)
    if n then n = n + 1 else n = 0 end
    while start do
        local id = start.id
        if trace_processing then
            local margin = rep("  ",n or 0)
            local detail = tostring(start)
            if id == math_noad then
                report_processing("%s%s (class: %s)",margin,detail,noadcodes[start.subtype] or "?")
            elseif id == math_char then
                local char = start.char
                local fam = start.fam
                local font = font_of_family(fam)
                report_processing("%s%s (family: %s, font: %s, char: %s, shape: %s)",margin,detail,fam,font,char,utfchar(char))
            else
                report_processing("%s%s",margin,detail)
            end
        end
        local proc = what[id]
        if proc then
         -- report_processing("start processing")
            local done, newstart = proc(start,what,n,parent) -- prev is bugged:  or start.prev
            if newstart then
                start = newstart
             -- report_processing("stop processing (new start)")
            else
             -- report_processing("stop processing")
            end
        elseif id == math_char or id == math_textchar or id == math_delim then
            break
        elseif id == math_style then
            -- has a next
        elseif id == math_noad then
            local noad = start.nucleus      if noad then process(noad,what,n,start) end -- list
                  noad = start.sup          if noad then process(noad,what,n,start) end -- list
                  noad = start.sub          if noad then process(noad,what,n,start) end -- list
        elseif id == math_box or id == math_sub then
         -- local noad = start.list         if noad then process(noad,what,n,start) end -- list
            local noad = start.head         if noad then process(noad,what,n,start) end -- list
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

local function processnoads(head,actions,banner)
    if trace_processing then
        report_processing("start '%s'",banner)
        process(head,actions)
        report_processing("stop '%s'",banner)
    else
        process(head,actions)
    end
end

noads.process = processnoads

-- character remapping

local mathalphabet = attributes.private("mathalphabet")
local mathgreek    = attributes.private("mathgreek")

processors.relocate = { }

local function report_remap(tag,id,old,new,extra)
    report_remapping("remapping %s in font %s from U+%05X (%s) to U+%05X (%s)%s",tag,id,old,utfchar(old),new,utfchar(new),extra or "")
end

local remapalphabets = mathematics.remapalphabets
local setnodecolor   = nodes.tracers.colors.set

--~ This does not work out well, as there are no fallbacks. Ok, we could
--~ define a poor mans simplify mechanism.

local function checked(pointer)
    local char = pointer.char
    local fam = pointer.fam
    local id = font_of_family(fam)
    local tc = fontcharacters[id]
    if not tc[char] then
        local specials = characters.data[char].specials
        if specials and (specials[1] == "char" or specials[1] == "font") then
            newchar = specials[#specials]
            if trace_remapping then
                report_remap("fallback",id,char,newchar)
            end
            if trace_analyzing then
                setnodecolor(pointer,"font:isol")
            end
            set_attribute(pointer,exportstatus,char) -- testcase: exponentiale
            pointer.char = newchar
            return true
        end
    end
end

processors.relocate[math_char] = function(pointer)
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
        local newchar = remapalphabets(char,a,g)
        if newchar then
            local fam = pointer.fam
            local id = font_of_family(fam)
            local characters = fontcharacters[id]
            if characters and characters[newchar] then
                if trace_remapping then
                    report_remap("char",id,char,newchar)
                end
                if trace_analyzing then
                    setnodecolor(pointer,"font:isol")
                end
                pointer.char = newchar
                return true
            else
                if trace_remapping then
                    report_remap("char",id,char,newchar," fails")
                end
            end
        end
    end
    if trace_analyzing then
        setnodecolor(pointer,"font:medi")
    end
    if check_coverage then
        return checked(pointer)
    end
end

processors.relocate[math_textchar] = function(pointer)
    if trace_analyzing then
        setnodecolor(pointer,"font:init")
    end
end

processors.relocate[math_delim] = function(pointer)
    if trace_analyzing then
        setnodecolor(pointer,"font:fina")
    end
end

function handlers.relocate(head,style,penalties)
    processnoads(head,processors.relocate,"relocate")
    return true
end

-- rendering (beware, not exported)

local a_mathrendering = attributes.private("mathrendering")
local a_exportstatus  = attributes.private("exportstatus")

processors.render = { }

local rendersets = mathematics.renderings.numbers or { } -- store

processors.render[math_char] = function(pointer)
    local attr = has_attribute(pointer,a_mathrendering)
    if attr and attr > 0 then
        local char = pointer.char
        local renderset = rendersets[attr]
        if renderset then
            local newchar = renderset[char]
            if newchar then
                local fam = pointer.fam
                local id = font_of_family(fam)
                local characters = fontcharacters[id]
                if characters and characters[newchar] then
                    pointer.char = newchar
                    set_attribute(pointer,a_exportstatus,char)
                end
            end
        end
    end
end

function handlers.render(head,style,penalties)
    processnoads(head,processors.render,"render")
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

local resize = { } processors.resize = resize

resize[math_fence] = function(pointer)
    if pointer.subtype == left_fence_code then
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

function handlers.resize(head,style,penalties)
    processnoads(head,resize,"resize")
    return true
end

-- respacing

local mathpunctuation = attributes.private("mathpunctuation")

local respace = { } processors.respace = respace

local chardata = characters.data

-- only [nd,ll,ul][po][nd,ll,ul]

respace[math_char] = function(pointer,what,n,parent) -- not math_noad .. math_char ... and then parent
    pointer = parent
    if pointer and pointer.subtype == noad_ord then
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
                                            local ord = new_node(math_noad) -- todo: pool
                                            ord.subtype, ord.nucleus, ord.sub, ord.sup, ord.attr = noad_ord, next_noad.nucleus, next_noad.sub, next_noad.sup, next_noad.attr
                                        --  next_noad.nucleus, next_noad.sub, next_noad.sup, next_noad.attr = nil, nil, nil, nil
                                            next_noad.nucleus, next_noad.sub, next_noad.sup = nil, nil, nil -- else crash with attributes ref count
                                        --~ next_noad.attr = nil
                                            ord.next = last_noad
                                            pointer.next = ord
                                            free_node(next_noad)
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

function handlers.respace(head,style,penalties)
    processnoads(head,respace,"respace")
    return true
end

-- The following code is dedicated to Luigi Scarso who pointed me
-- to the fact that \not= is not producing valid pdf-a code.
-- The code does not solve this for virtual characters but it does
-- a decent job on collapsing so that fonts that have the right
-- glyph will have a decent unicode point.

local collapse = { } processors.collapse = collapse

local mathpairs = characters.mathpairs

mathpairs[0x2032] = { [0x2032] = 0x2033, [0x2033] = 0x2034 } -- (prime,prime) (prime,doubleprime)
mathpairs[0x2033] = { [0x2032] = 0x2034 }                    -- (doubleprime,prime)

local function collapsepair(pointer,what,n,parent) -- todo: switch to turn in on and off
    if parent then
        local subtype = parent.subtype
        if subtype == noad_rel or subtype == noad_ord then -- ord is new
            local current_nucleus = parent.nucleus
            if not parent.sub and not parent.sup and current_nucleus.id == math_char then
                local current_char = current_nucleus.char
                local mathpair = mathpairs[current_char]
                if mathpair then
                    local next_noad = parent.next
                    if next_noad and next_noad.id == math_noad then
                        local next_subtype = next_noad.subtype
                        if next_subtype == noad_rel or next_subtype == noad_ord then -- ord is new
                            local next_nucleus = next_noad.nucleus
                            if next_nucleus.id == math_char then
                                local next_char = next_nucleus.char
                                local newchar = mathpair[next_char]
                                if newchar then
                                    local fam = current_nucleus.fam
                                    local id = font_of_family(fam)
                                    local characters = fontcharacters[id]
                                    if characters and characters[newchar] then
                                        if trace_collapsing then
                                            report_collapsing("U+%05X + U+%05X => U+%05X",current_char,next_char,newchar)
                                        end
                                        current_nucleus.char = newchar
                                        local next_next_noad = next_noad.next
                                        if next_next_noad then
                                            parent.next = next_next_noad
                                            next_next_noad.prev = parent
                                        else
                                            parent.next = nil
                                        end
                                        parent.sup = next_noad.sup
                                        parent.sub = next_noad.sub
                                        next_noad.sup = nil
                                        next_noad.sub = nil
                                        free_node(next_noad)
                                        collapsepair(pointer,what,n,parent)
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

collapse[math_char] = collapsepair

function noads.handlers.collapse(head,style,penalties)
    processnoads(head,collapse,"collapse")
    return true
end

-- normalize scripts

local unscript = { }  noads.processors.unscript = unscript

local superscripts = characters.superscripts
local subscripts   = characters.subscripts

local replaced = { }

local function replace(pointer,what,n,parent)
    pointer = parent -- we're following the parent list (chars trigger this)
    local next = pointer.next
    local start_super, stop_super, start_sub, stop_sub
    local mode = "unset"
    while next and next.id == math_noad do
        local nextnucleus = next.nucleus
        if nextnucleus and nextnucleus.id == math_char and not next.sub and not next.sup then
            local char = nextnucleus.char
            local s = superscripts[char]
            if s then
                if not start_super then
                    start_super = next
                    mode = "super"
                elseif mode == "sub" then
                    break
                end
                stop_super = next
                next = next.next
                nextnucleus.char = s
                replaced[char] = (replaced[char] or 0) + 1
                if trace_normalizing then
                    report_normalizing("superscript: U+05X (%s) => U+05X (%s)",char,utfchar(char),s,utfchar(s))
                end
            else
                local s = subscripts[char]
                if s then
                    if not start_sub then
                        start_sub = next
                        mode = "sub"
                    elseif mode == "super" then
                        break
                    end
                    stop_sub = next
                    next = next.next
                    nextnucleus.char = s
                    replaced[char] = (replaced[char] or 0) + 1
                    if trace_normalizing then
                        report_normalizing("subscript: U+05X (%s) => U+05X (%s)",char,utfchar(char),s,utfchar(s))
                    end
                else
                    break
                end
            end
        else
            break
        end
    end
    if start_super then
        if start_super == stop_super then
            pointer.sup = start_super.nucleus
        else
            local list = new_node(math_sub) -- todo attr
            list.head = start_super
            pointer.sup = list
        end
        if mode == "super" then
            pointer.next = stop_super.next
        end
        stop_super.next = nil
    end
    if start_sub then
        if start_sub == stop_sub then
            pointer.sub = start_sub.nucleus
        else
            local list = new_node(math_sub) -- todo attr
            list.head = start_sub
            pointer.sub = list
        end
        if mode == "sub" then
            pointer.next = stop_sub.next
        end
        stop_sub.next = nil
    end
    -- we could return stop
end

unscript[math_char] = replace -- not noads as we need to recurse

function handlers.unscript(head,style,penalties)
    processnoads(head,unscript,"unscript")
    return true
end

statistics.register("math script replacements", function()
    if next(replaced) then
        local n, t = 0, { }
        for k, v in table.sortedpairs(replaced) do
            n = n + v
            t[#t+1] = format("U+%05X:%s",k,utfchar(k))
        end
        return format("%s (n=%s)",concat(t," "),n)
    end
end)

-- math alternates: (in xits       lgf: $ABC$ $\cal ABC$ $\mathalternate{cal}\cal ABC$)
-- math alternates: (in lucidanova lgf: $ABC \mathalternate{italic} ABC$)

local function initializemathalternates(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        local shared = tfmdata.shared
        for i=1,#goodies do
            -- first one counts
            -- we can consider sharing the attributes ... todo (only once scan)
            local mathgoodies = goodies[i].mathematics
            local alternates = mathgoodies and mathgoodies.alternates
            if alternates then
                if trace_goodies then
                    report_goodies("loading alternates for font '%s'",tfmdata.properties.name)
                end
                local lastattribute, attributes = 0, { }
                for k, v in next, alternates do
                    lastattribute = lastattribute + 1
                    v.attribute = lastattribute
                    attributes[lastattribute] = v
                end
                shared.mathalternates           = alternates -- to be checked if shared is ok here
                shared.mathalternatesattributes = attributes -- to be checked if shared is ok here
                return
            end
        end
    end
end

registerotffeature {
    name        = "mathalternates",
    description = "additional math alternative shapes",
    initializers = {
        base = initializemathalternates,
        node = initializemathalternates,
    }
}

local getalternate = otf.getalternate

local a_mathalternate = attributes.private("mathalternate")

local alternate = { } -- processors.alternate = alternate

function mathematics.setalternate(fam,tag)
    local id = font_of_family(fam)
    local tfmdata = fontdata[id]
    local mathalternates = tfmdata.shared and tfmdata.shared.mathalternates
    if mathalternates then
        local m = mathalternates[tag]
        tex.attribute[a_mathalternate] = m and m.attribute or unsetvalue
    end
end

alternate[math_char] = function(pointer)
    local a = has_attribute(pointer,a_mathalternate)
    if a and a > 0 then
        set_attribute(pointer,a_mathalternate,0)
        local tfmdata = fontdata[font_of_family(pointer.fam)] -- we can also have a famdata
        local mathalternatesattributes = tfmdata.shared.mathalternatesattributes
        if mathalternatesattributes then
            local what = mathalternatesattributes[a]
            local alt = getalternate(tfmdata,pointer.char,what.feature,what.value)
            if alt then
                pointer.char = alt
            end
        end
    end
end

function handlers.check(head,style,penalties)
    processnoads(head,alternate,"check")
    return true
end

-- experiment (when not present fall back to fam 0) -- needs documentation

-- 0-2 regular
-- 3-5 bold
-- 6-8 pseudobold

local families     = { }
local a_mathfamily = attributes.private("mathfamily")
local boldmap      = mathematics.boldmap

local tracemap = { [0] =
    "regular",
    "regular",
    "regular",
    "bold",
    "bold",
    "bold",
    "pseudobold",
    "pseudobold",
    "pseudobold",
}

families[math_char] = function(pointer)
    if pointer.fam == 0 then
        local a = has_attribute(pointer,a_mathfamily)
        if a and a > 0 then
            set_attribute(pointer,a_mathfamily,0)
            if a > 5 then
                local char = pointer.char
                local bold = boldmap[char]
                local newa = a - 3
                if bold then
                    set_attribute(pointer,exportstatus,char)
                    pointer.char = bold
                    if trace_families then
                        report_families("replacing U+%05X by bold U+%05X, family %s (%s) becomes %s (%s)",
                            char,bold,a,tracemap[a],newa,tracemap[newa])
                    end
                else
                    if trace_families then
                        report_families("no bold replacement for U+%05X, family %s (%s) becomes %s (%s)",
                            char,a,tracemap[a],newa,tracemap[newa])
                    end
                end
                pointer.fam = newa
            else
                if trace_families then
                    report_families("family of U+%05X becomes %s (%s)",
                        pointer.char,a,tracemap[a])
                end
                pointer.fam = a
            end
        else
         -- pointer.fam = 0
        end
    end
end

families[math_delim] = function(pointer)
    if pointer.small_fam == 0 then
        local a = has_attribute(pointer,a_mathfamily)
        if a and a > 0 then
            set_attribute(pointer,a_mathfamily,0)
            if a > 5 then
                -- no bold delimiters in unicode
                a = a - 3
            end
            pointer.small_fam = a
            pointer.large_fam = a
        else
            pointer.small_fam = 0
            pointer.large_fam = 0
        end
    end
end

families[math_textchar] = families[math_char]

function handlers.families(head,style,penalties)
    processnoads(head,families,"families")
    return true
end

-- italics: we assume that only characters matter
--
-- = we check for correction first because accessing nodes is slower
-- = the actual glyph is not that important (we can control it with numbers)

local a_mathitalics = attributes.private("mathitalics")

local italics        = { }
local default_factor = 1/20

italics[math_char] = function(pointer,what,n,parent)
    local method = has_attribute(pointer,a_mathitalics)
    if method and method > 0 then
        local char = pointer.char
        local font = font_of_family(pointer.fam) -- todo: table
        local correction
        if method == 1 then
            -- only font data triggered by fontitalics
            local italics = fontitalics[font]
            if italics then
                local character = fontcharacters[font][char]
                correction = character and character.italic_correction -- or character.italic (this one is for tex)
            end
        elseif method == 2 then
            -- only font data triggered by fontdata
            local character = fontcharacters[font][char]
            correction = character and character.italic_correction -- or character.italic (this one is for tex)
        elseif method == 3 then
            -- only quad based by selective
            local visual = chardata[char].visual
            if not visual then
                -- skip
            elseif visual == "it" or visual == "bi" then
                correction = fontproperties[font].mathitalic_defaultvalue or default_factor*fontquads[font]
            end
        elseif method == 4 then
            -- combination of 1 and 3
            local italics = fontitalics[font]
            if italics then
                local character = fontcharacters[font][char]
                correction = character and character.italic_correction -- or character.italic (this one is for tex)
            end
            if not correction then
                local visual = chardata[char].visual
                if not visual then
                    -- skip
                elseif visual == "it" or visual == "bi" then
                    correction = fontproperties[font].mathitalic_defaultvalue or default_factor*fontquads[font]
                end
            end
        end
        if correction and correction ~= 0 then
            local next_noad = parent.next
            if next_noad and next_noad.id == math_noad then
                local next_subtype = next_noad.subtype
                if next_subtype == noad_punct or next_subtype == noad_ord then
                    local next_nucleus = next_noad.nucleus
                    if next_nucleus.id == math_char then
                        local next_char = next_nucleus.char
                        if not chardata[next_char].italic then -- or category
                            if trace_italics then
                                report_italics("method %s: adding %s italic correction between %s (0x%05X) and %s (0x%05X)",
                                    method,number.points(correction),utfchar(char),char,utfchar(next_char),next_char)
                            end
                            insert_node_after(parent,parent,new_kern(correction))
                        end
                    end
                end
            end
        end
    end
end

function handlers.italics(head,style,penalties)
    processnoads(head,italics,"italics")
    return true
end

local enable

enable = function()
    tasks.enableaction("math", "noads.handlers.italics")
    if trace_italics then
        report_italics("enabling math italics")
    end
    enable = false
end

-- best do this only on math mode (less overhead)

function mathematics.setitalics(n)
    if enable then
        enable()
    end
    if n == variables.reset then
        texattribute[a_mathitalics] = unsetvalue
    else
        texattribute[a_mathitalics] = tonumber(n) or unsetvalue
    end
end

function mathematics.resetitalics()
    texattribute[a_mathitalics] = unsetvalue
end

-- variants

local variants = { }

local validvariants = { -- fast check on valid
    [0x2229] = 0xFE00, [0x222A] = 0xFE00,
    [0x2268] = 0xFE00, [0x2269] = 0xFE00,
    [0x2272] = 0xFE00, [0x2273] = 0xFE00,
    [0x228A] = 0xFE00, [0x228B] = 0xFE00,
    [0x2293] = 0xFE00, [0x2294] = 0xFE00,
    [0x2295] = 0xFE00,
    [0x2297] = 0xFE00,
    [0x229C] = 0xFE00,
    [0x22DA] = 0xFE00, [0x22DB] = 0xFE00,
    [0x2A3C] = 0xFE00, [0x2A3D] = 0xFE00,
    [0x2A9D] = 0xFE00, [0x2A9E] = 0xFE00,
    [0x2AAC] = 0xFE00, [0x2AAD] = 0xFE00,
    [0x2ACB] = 0xFE00, [0x2ACC] = 0xFE00,
}

variants[math_char] = function(pointer,what,n,parent) -- also set export value
    local char = pointer.char
    local selector = validvariants[char]
    if selector then
        local next = parent.next
        if next and next.id == math_noad then
            local nucleus = next.nucleus
            if nucleus and nucleus.id == math_char and nucleus.char == selector then
                local variant
                local tfmdata = fontdata[font_of_family(pointer.fam)] -- we can also have a famdata
                local mathvariants = tfmdata.resources.variants -- and variantdata
                if mathvariants then
                    mathvariants = mathvariants[selector]
                    if mathvariants then
                        variant = mathvariants[char]
                    end
                end
                if variant then
                    pointer.char = variant
                    set_attribute(pointer,exportstatus,char) -- we don't export the variant as it's visual markup
                    if trace_variants then
                        report_variants("variant (U+%05X,U+%05X) replaced by U+%05X",char,selector,variant)
                    end
                else
                    if trace_variants then
                        report_variants("no variant (U+%05X,U+%05X)",char,selector)
                    end
                end
                next.prev = pointer
                parent.next = next.next
                free_node(next)
            end
        end
    end
end

function handlers.variants(head,style,penalties)
    processnoads(head,variants,"unicode variant")
    return true
end

-- the normal builder

function builders.kernel.mlist_to_hlist(head,style,penalties)
    return mlist_to_hlist(head,style,penalties), true
end

--~ function builders.kernel.mlist_to_hlist(head,style,penalties)
--~     print("!!!!!!! BEFORE",penalties)
--~     for n in node.traverse(head) do print(n) end
--~     print("!!!!!!!")
--~     head = mlist_to_hlist(head,style,penalties)
--~     print("!!!!!!! AFTER")
--~     for n in node.traverse(head) do print(n) end
--~     print("!!!!!!!")
--~     return head, true
--~ end

tasks.new {
    name      = "math",
    arguments = 2,
    processor = utilities.sequencers.nodeprocessor,
    sequence  = {
        "before",
        "normalizers",
        "builders",
        "after",
    },
}

tasks.freezegroup("math", "normalizers") -- experimental
tasks.freezegroup("math", "builders")    -- experimental

local actions = tasks.actions("math") -- head, style, penalties

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

function processors.mlist_to_hlist(head,style,penalties)
    starttiming(noads)
    local head, done = actions(head,style,penalties)
    stoptiming(noads)
    return head, done
end

callbacks.register('mlist_to_hlist',processors.mlist_to_hlist,"preprocessing math list")

-- tracing

statistics.register("math processing time", function()
    return statistics.elapsedseconds(noads)
end)

-- interface

commands.setmathalternate = mathematics.setalternate
commands.setmathitalics   = mathematics.setitalics
commands.resetmathitalics = mathematics.resetitalics
