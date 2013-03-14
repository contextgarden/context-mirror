if not modules then modules = { } end modules ['font-odv'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Kai Eigner, TAT Zetwerk / Hans Hagen, PRAGMA ADE",
    copyright = "TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A few remarks:
--
-- This code is a partial rewrite of the code that deals with devanagari. The data and logic
-- is by Kai Eigner and based based on Microsoft's OpenType specifications for specific
-- scripts, but with a few improvements. More information can be found at:
--
-- deva: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/introO.mspx
-- dev2: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/intro.mspx
--
-- As I touched nearly all code, reshuffled it, optimized a lot, etc. etc. (imagine how
-- much can get messed up in over a week work) it could be that I introduced bugs. There
-- is more to gain (esp in the functions applied to a range) but I'll do that when
-- everything works as expected. Kai's original code is kept in font-odk.lua as a reference
-- so blame me (HH) for bugs.
--
-- Interesting is that Kai managed to write this on top of the existing otf handler. Only a
-- few extensions were needed, like a few more analyzing states and dealing with changed
-- head nodes in the core scanner as that only happens here. There's a lot going on here
-- and it's only because I touched nearly all code that I got a bit of a picture of what
-- happens. For in-depth knowledge one needs to consult Kai.
--
-- The rewrite mostly deals with efficiency, both in terms of speed and code. We also made
-- sure that it suits generic use as well as use in ConTeXt. I removed some buglets but can
-- as well have messed up the logic by doing this. For this we keep the original around
-- as that serves as reference. Due to the lots of reshuffling glyphs quite some leaks
-- occur(red) but once I'm satisfied with the rewrite I'll weed them. I also integrated
-- initialization etc into the regular mechanisms.
--
-- In the meantime, we're down from 25.5-3.5=22 seconds to 17.7-3.5=14.2 seconds for a 100
-- page sample (mid 2012) with both variants so it's worth the effort. Some more speedup is
-- to be expected. Due to the method chosen it will never be real fast. If I ever become a
-- power user I'll have a go at some further speed up. I will rename some functions (and
-- features) once we don't need to check the original code. We now use a special subset
-- sequence for use inside the analyzer (after all we could can store this in the dataset
-- and save redundant analysis).
--
-- I might go for an array approach with respect to attributes (and reshuffling). Easier.
--
-- Hans Hagen, PRAGMA-ADE, Hasselt NL

-- Matras: according to Microsoft typography specifications "up to one of each type:
-- pre-, above-, below- or post- base", but that does not seem to be right. It could
-- become an option.
--
-- The next code looks weird anyway: the "and boolean" should move inside the if
-- or we should check differently (case vs successive).
--
-- local function ms_matra(c)
--     local prebase, abovebase, belowbase, postbase = true, true, true, true
--     local n = c.next
--     while n and n.id == glyph_code and n.subtype<256 and n.font == font do
--         local char = n.char
--         if not dependent_vowel[char] then
--             break
--         elseif pre_mark[char] and prebase then
--             prebase = false
--         elseif above_mark[char] and abovebase then
--             abovebase = false
--         elseif below_mark[char] and belowbase then
--             belowbase = false
--         elseif post_mark[char] and postbase then
--             postbase = false
--         else
--             return c
--         end
--         c = c.next
--     end
--     return c
-- end

-- todo: first test for font then for subtype

local insert, imerge = table.insert, table.imerge
local next = next

local trace_analyzing    = false  trackers.register("otf.analyzing", function(v) trace_analyzing = v end)
local report_devanagari  = logs.reporter("otf","devanagari")

fonts                    = fonts                   or { }
fonts.analyzers          = fonts.analyzers         or { }
fonts.analyzers.methods  = fonts.analyzers.methods or { node = { otf = { } } }

local otf                = fonts.handlers.otf

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local handlers           = otf.handlers
local methods            = fonts.analyzers.methods

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local processcharacters  = nodes.handlers.characters

local insert_node_after  = node.insert_after
local copy_node          = node.copy
local free_node          = node.free
local remove_node        = node.remove
local flush_list         = node.flush_list

local unsetvalue         = attributes.unsetvalue

local fontdata           = fonts.hashes.identifiers

local a_state            = attributes.private('state')
local a_syllabe          = attributes.private('syllabe')

local dotted_circle      = 0x25CC

local states             = fonts.analyzers.states -- not features

local s_rphf             = states.rphf
local s_half             = states.half
local s_pref             = states.pref
local s_blwf             = states.blwf
local s_pstf             = states.pstf

-- In due time there will be entries here for scripts like Bengali, Gujarati,
-- Gurmukhi, Kannada, Malayalam, Oriya, Tamil, Telugu. Feel free to provide the
-- code points.

local consonant = {
    [0x0915] = true, [0x0916] = true, [0x0917] = true, [0x0918] = true,
    [0x0919] = true, [0x091A] = true, [0x091B] = true, [0x091C] = true,
    [0x091D] = true, [0x091E] = true, [0x091F] = true, [0x0920] = true,
    [0x0921] = true, [0x0922] = true, [0x0923] = true, [0x0924] = true,
    [0x0925] = true, [0x0926] = true, [0x0927] = true, [0x0928] = true,
    [0x0929] = true, [0x092A] = true, [0x092B] = true, [0x092C] = true,
    [0x092D] = true, [0x092E] = true, [0x092F] = true, [0x0930] = true,
    [0x0931] = true, [0x0932] = true, [0x0933] = true, [0x0934] = true,
    [0x0935] = true, [0x0936] = true, [0x0937] = true, [0x0938] = true,
    [0x0939] = true, [0x0958] = true, [0x0959] = true, [0x095A] = true,
    [0x095B] = true, [0x095C] = true, [0x095D] = true, [0x095E] = true,
    [0x095F] = true, [0x0979] = true, [0x097A] = true,
}

local independent_vowel = {
    [0x0904] = true, [0x0905] = true, [0x0906] = true, [0x0907] = true,
    [0x0908] = true, [0x0909] = true, [0x090A] = true, [0x090B] = true,
    [0x090C] = true, [0x090D] = true, [0x090E] = true, [0x090F] = true,
    [0x0910] = true, [0x0911] = true, [0x0912] = true, [0x0913] = true,
    [0x0914] = true, [0x0960] = true, [0x0961] = true, [0x0972] = true,
    [0x0973] = true, [0x0974] = true, [0x0975] = true, [0x0976] = true,
    [0x0977] = true,
}

local dependent_vowel = { -- matra
    [0x093A] = true, [0x093B] = true, [0x093E] = true, [0x093F] = true,
    [0x0940] = true, [0x0941] = true, [0x0942] = true, [0x0943] = true,
    [0x0944] = true, [0x0945] = true, [0x0946] = true, [0x0947] = true,
    [0x0948] = true, [0x0949] = true, [0x094A] = true, [0x094B] = true,
    [0x094C] = true, [0x094E] = true, [0x094F] = true, [0x0955] = true,
    [0x0956] = true, [0x0957] = true, [0x0962] = true, [0x0963] = true,
}

local vowel_modifier = {
    [0x0900] = true, [0x0901] = true, [0x0902] = true, [0x0903] = true,
 -- A8E0 - A8F1 are cantillation marks for the Samaveda and may not belong here.
    [0xA8E0] = true, [0xA8E1] = true, [0xA8E2] = true, [0xA8E3] = true,
    [0xA8E4] = true, [0xA8E5] = true, [0xA8E6] = true, [0xA8E7] = true,
    [0xA8E8] = true, [0xA8E9] = true, [0xA8EA] = true, [0xA8EB] = true,
    [0xA8EC] = true, [0xA8ED] = true, [0xA8EE] = true, [0xA8EF] = true,
    [0xA8F0] = true, [0xA8F1] = true,
}

local stress_tone_mark = {
    [0x0951] = true, [0x0952] = true, [0x0953] = true, [0x0954] = true,
}

local c_nukta    = 0x093C -- used to be tables
local c_halant   = 0x094D -- used to be tables
local c_ra       = 0x0930 -- used to be tables
local c_anudatta = 0x0952 -- used to be tables
local c_nbsp     = 0x00A0 -- used to be tables
local c_zwnj     = 0x200C -- used to be tables
local c_zwj      = 0x200D -- used to be tables

local zw_char = { -- could also be inlined
    [0x200C] = true,
    [0x200D] = true,
}

local pre_mark = {
    [0x093F] = true, [0x094E] = true,
}

local above_mark = {
    [0x0900] = true, [0x0901] = true, [0x0902] = true, [0x093A] = true,
    [0x0945] = true, [0x0946] = true, [0x0947] = true, [0x0948] = true,
    [0x0951] = true, [0x0953] = true, [0x0954] = true, [0x0955] = true,
    [0xA8E0] = true, [0xA8E1] = true, [0xA8E2] = true, [0xA8E3] = true,
    [0xA8E4] = true, [0xA8E5] = true, [0xA8E6] = true, [0xA8E7] = true,
    [0xA8E8] = true, [0xA8E9] = true, [0xA8EA] = true, [0xA8EB] = true,
    [0xA8EC] = true, [0xA8ED] = true, [0xA8EE] = true, [0xA8EF] = true,
    [0xA8F0] = true, [0xA8F1] = true,
}

local below_mark = {
    [0x093C] = true, [0x0941] = true, [0x0942] = true, [0x0943] = true,
    [0x0944] = true, [0x094D] = true, [0x0952] = true, [0x0956] = true,
    [0x0957] = true, [0x0962] = true, [0x0963] = true,
}

local post_mark = {
    [0x0903] = true, [0x093B] = true, [0x093E] = true, [0x0940] = true,
    [0x0949] = true, [0x094A] = true, [0x094B] = true, [0x094C] = true,
    [0x094F] = true,
}

local mark_four = { } -- As we access these frequently an extra hash is used.

for k, v in next, pre_mark   do mark_four[k] = pre_mark   end
for k, v in next, above_mark do mark_four[k] = above_mark end
for k, v in next, below_mark do mark_four[k] = below_mark end
for k, v in next, post_mark  do mark_four[k] = post_mark  end

local mark_above_below_post = { }

for k, v in next, above_mark do mark_above_below_post[k] = above_mark end
for k, v in next, below_mark do mark_above_below_post[k] = below_mark end
for k, v in next, post_mark  do mark_above_below_post[k] = post_mark  end

-- Again, this table can be extended for other scripts than devanagari. Actually,
-- for ConTeXt this kind of dat is kept elsewhere so eventually we might move
-- tables to someplace else.

local reorder_class = {
    [0x0930] = "before postscript",
    [0x093F] = "before half",
    [0x0940] = "after subscript",
    [0x0941] = "after subscript",
    [0x0942] = "after subscript",
    [0x0943] = "after subscript",
    [0x0944] = "after subscript",
    [0x0945] = "after subscript",
    [0x0946] = "after subscript",
    [0x0947] = "after subscript",
    [0x0948] = "after subscript",
    [0x0949] = "after subscript",
    [0x094A] = "after subscript",
    [0x094B] = "after subscript",
    [0x094C] = "after subscript",
    [0x0962] = "after subscript",
    [0x0963] = "after subscript",
    [0x093E] = "after subscript",
}

-- We use some pseudo features as we need to manipulate the nodelist based
-- on information in the font as well as already applied features.

local dflt_true = {
    dflt = true
}

local dev2_defaults = {
    dev2 = dflt_true,
}

local deva_defaults = {
    dev2 = dflt_true,
    deva = dflt_true,
}

local false_flags = { false, false, false, false }

local both_joiners_true = {
    [0x200C] = true,
    [0x200D] = true,
}

local sequence_reorder_matras = {
    chain     = 0,
    features  = { dv01 = dev2_defaults },
    flags     = false_flags,
    name      = "dv01_reorder_matras",
    subtables = { "dv01_reorder_matras" },
    type      = "devanagari_reorder_matras",
}

local sequence_reorder_reph = {
    chain     = 0,
    features  = { dv02 = dev2_defaults },
    flags     = false_flags,
    name      = "dv02_reorder_reph",
    subtables = { "dv02_reorder_reph" },
    type      = "devanagari_reorder_reph",
}

local sequence_reorder_pre_base_reordering_consonants = {
    chain     = 0,
    features  = { dv03 = dev2_defaults },
    flags     = false_flags,
    name      = "dv03_reorder_pre_base_reordering_consonants",
    subtables = { "dv03_reorder_pre_base_reordering_consonants" },
    type      = "devanagari_reorder_pre_base_reordering_consonants",
}

local sequence_remove_joiners = {
    chain     = 0,
    features  = { dv04 = deva_defaults },
    flags     = false_flags,
    name      = "dv04_remove_joiners",
    subtables = { "dv04_remove_joiners" },
    type      = "devanagari_remove_joiners",
}

-- Looping over feature twice as efficient as looping over basic forms (some
-- 350 checks instead of 750 for one font). This is something to keep an eye on
-- as it might depends on the font. Not that it's a bottleneck.

local basic_shaping_forms =  {
    nukt = true,
    akhn = true,
    rphf = true,
    pref = true,
    rkrf = true,
    blwf = true,
    half = true,
    pstf = true,
    vatu = true,
    cjct = true,
}

local function initializedevanagi(tfmdata)
    local script, language = otf.scriptandlanguage(tfmdata,attr) -- todo: take fast variant
    if script == "deva" or script == "dev2" then
        local resources  = tfmdata.resources
        local lookuphash = resources.lookuphash
        if not lookuphash["dv01"] then
            report_devanagari("adding devanagari features to font")
            --
            local features       = resources.features
            local gsubfeatures   = features.gsub
            local sequences      = resources.sequences
            local sharedfeatures = tfmdata.shared.features
            --
            local lastmatch      = 0
            for s=1,#sequences do -- classify chars
                local features = sequences[s].features
                if features then
                    for k, v in next, features do
                        if basic_shaping_forms[k] then
                            lastmatch = s
                        end
                    end
                end
            end
            local insertindex = lastmatch + 1
            --
            lookuphash["dv04_remove_joiners"] = both_joiners_true
            --
            gsubfeatures["dv01"] = dev2_defaults -- reorder matras
            gsubfeatures["dv02"] = dev2_defaults -- reorder reph
            gsubfeatures["dv03"] = dev2_defaults -- reorder pre base reordering consonants
            gsubfeatures["dv04"] = deva_defaults -- remove joiners
            --
            insert(sequences,insertindex,sequence_reorder_pre_base_reordering_consonants)
            insert(sequences,insertindex,sequence_reorder_reph)
            insert(sequences,insertindex,sequence_reorder_matras)
            insert(sequences,insertindex,sequence_remove_joiners)
            --
            if script == "deva" then
                sharedfeatures["dv04"] = true -- dv04_remove_joiners
            end
            --
            if script == "dev2" then
                sharedfeatures["dv01"] = true -- dv01_reorder_matras
                sharedfeatures["dv02"] = true -- dv02_reorder_reph
                sharedfeatures["dv03"] = true -- dv03_reorder_pre_base_reordering_consonants
                sharedfeatures["dv04"] = true -- dv04_remove_joiners
            end
            --
        end
    end
end

registerotffeature {
    name         = "devanagari",
    description  = "inject additional features",
    default      = true,
    initializers = {
        node     = initializedevanagi,
    },
}

-- hm, this is applied to one character:

local function deva_initialize(font,attr)

    local tfmdata        = fontdata[font]
    local resources      = tfmdata.resources
    local lookuphash     = resources.lookuphash

    local datasets       = otf.dataset(tfmdata,font,attr)
    local devanagaridata = datasets.devanagari

    if devanagaridata then -- maybe also check for e.g. reph

        return lookuphash, devanagaridata.reph, devanagaridata.vattu, devanagaridata.blwfcache

    else

        devanagaridata      = { }
        datasets.devanagari = devanagaridata

        local reph      = false
        local vattu     = false
        local blwfcache = { }

        local sequences = resources.sequences

        for s=1,#sequences do -- triggers creation of dataset
         -- local sequence = sequences[s]
            local dataset = datasets[s]
            if dataset and dataset[1] then -- value
                local kind = dataset[4]
                if kind == "rphf" then
                    -- deva
                    reph = true
                elseif kind == "blwf" then
                    -- deva
                    vattu = true
                    -- dev2
                 -- local subtables = sequence.subtables -- dataset[5].subtables
                    local subtables = dataset[5].subtables
                    for i=1,#subtables do
                        local lookupname = subtables[i]
                        local lookupcache = lookuphash[lookupname]
                        if lookupcache then
                            for k, v in next, lookupcache do
                                blwfcache[k] = blwfcache[k] or v
                            end
                        end
                    end
                end
            end
        end

        devanagaridata.reph      = reph
        devanagaridata.vattu     = vattu
        devanagaridata.blwfcache = blwfcache

        return lookuphash, reph, vattu, blwfcache

    end

end

local function deva_reorder(head,start,stop,font,attr)

    local lookuphash, reph, vattu, blwfcache = deva_initialize(font,attr) -- could be inlines but ugly

    local current = start
    local n = start.next
    local base = nil
    local firstcons = nil
    local lastcons = nil
    local basefound = false

    if start.char == c_ra and n.char == c_halant and reph then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph
        -- from candidates for base consonants
        if n == stop then
            return head, stop
        end
        if n.next.char == c_zwj then
            current = start
        else
            current = n.next
            start[a_state] = s_rphf
        end
    end

    if current.char == c_nbsp then
        -- Stand Alone cluster
        if current == stop then
            stop = stop.prev
            head = remove_node(head,current)
            free_node(current)
            return head, stop
        else
            base, firstcons, lastcons = current, current, current
            current = current.next
            if current ~= stop then
                if current.char == c_nukta then
                    current = current.next
                end
                if current.char == c_zwj then
                    if current ~= stop then
                        local next = current.next
                        if next ~= stop and next.char == c_halant then
                            current = next
                            next = current.next
                            local tmp = next.next
                            local changestop = next == stop
                            local tempcurrent = copy_node(next)
                            local nextcurrent = copy_node(current)
                            tempcurrent.next = nextcurrent
                            nextcurrent.prev = tempcurrent
                            tempcurrent[a_state] = s_blwf
                            tempcurrent = processcharacters(tempcurrent)
                            tempcurrent[a_state] = unsetvalue
                            if next.char == tempcurrent.char then
                                flush_list(tempcurrent)
                                local n = copy_node(current)
                                current.char = dotted_circle
                                head = insert_node_after(head, current, n)
                            else
                                current.char = tempcurrent.char    -- (assumes that result of blwf consists of one node)
                                local freenode = current.next
                                current.next = tmp
                                tmp.prev = current
                                free_node(freenode)
                                flush_list(tempcurrent)
                                if changestop then
                                    stop = current
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    while not basefound do
        -- find base consonant
        if consonant[current.char] then
            current[a_state] = s_half
            if not firstcons then
                firstcons = current
            end
            lastcons = current
            if not base then
                base = current
            elseif blwfcache[current.char] then
                -- consonant has below-base (or post-base) form
                current[a_state] = s_blwf
            else
                base = current
            end
        end
        basefound = current == stop
        current = current.next
    end

    if base ~= lastcons then
        -- if base consonant is not last one then move halant from base consonant to last one
        local np = base
        local n = base.next
        if n.char == c_nukta then
            np = n
            n = n.next
        end
        if n.char == c_halant then
            if lastcons ~= stop then
                local ln = lastcons.next
                if ln.char == c_nukta then
                    lastcons = ln
                end
            end
         -- local np = n.prev
            local nn = n.next
            local ln = lastcons.next -- what if lastcons is nn ?
            np.next = nn
            nn.prev = np
            lastcons.next = n
            if ln then
                ln.prev = n
            end
            n.next = ln
            n.prev = lastcons
            if lastcons == stop then
                stop = n
            end
        end
    end

    n = start.next
    if start.char == c_ra and n.char == c_halant and not (n ~= stop and zw_char[n.next.char]) then
        -- if syllable starts with Ra + H then move this combination so that it follows either:
        -- the post-base 'matra' (if any) or the base consonant
        local matra = base
        if base ~= stop then
            local next = base.next
            if dependent_vowel[next.char] then
                matra = next
            end
        end
        -- [sp][start][n][nn] [matra|base][?]
        -- [matra|base][start]  [n][?] [sp][nn]
        local sp = start.prev
        local nn = n.next
        local mn = matra.next
        if sp then
            sp.next = nn
        end
        nn.prev = sp
        matra.next = start
        start.prev = matra
        n.next = mn
        if mn then
            mn.prev = n
        end
        if head == start then
            head = nn
        end
        start = nn
        if matra == stop then
            stop = n
        end
    end

    local current = start
    while current ~= stop do
        local next = current.next
        if next ~= stop and next.char == c_halant and next.next.char == c_zwnj then
            current[a_state] = unsetvalue
        end
        current = next
    end

    if base ~= stop and base[a_state] then
        local next = base.next
        if next.char == c_halant and not (next ~= stop and next.next.char == c_zwj) then
            base[a_state] = unsetvalue
        end
    end

    -- ToDo: split two- or three-part matras into their parts. Then, move the left 'matra' part to the beginning of the syllable.
    -- Not necessary for Devanagari. However it is necessay for other scripts, such as Tamil (e.g. TAMIL VOWEL SIGN O - 0BCA)

    -- classify consonants and 'matra' parts as pre-base, above-base (Reph), below-base or post-base, and group elements of the syllable (consonants and 'matras') according to this classification

    local current, allreordered, moved = start, false, { [base] = true }
    local a, b, p, bn = base, base, base, base.next
    if base ~= stop and bn.char == c_nukta then
        a, b, p = bn, bn, bn
    end
    while not allreordered do
        -- current is always consonant
        local c = current
        local n = current.next
        local l = nil -- used ?
        if c ~= stop then
            if n.char == c_nukta then
                c = n
                n = n.next
            end
            if c ~= stop then
                if n.char == c_halant then
                    c = n
                    n = n.next
                end
                while c ~= stop and dependent_vowel[n.char] do
                    c = n
                    n = n.next
                end
                if c ~= stop then
                    if vowel_modifier[n.char] then
                        c = n
                        n = n.next
                    end
                    if c ~= stop and stress_tone_mark[n.char] then
                        c = n
                        n = n.next
                    end
                end
            end
        end
        local bp = firstcons.prev
        local cn = current.next
        local last = c.next
        while cn ~= last do
            -- move pre-base matras...
            if pre_mark[cn.char] then
                if bp then
                    bp.next = cn
                end
                local next = cn.next
                local prev = cn.prev
                if next then
                    next.prev = prev
                end
                prev.next = next
                if cn == stop then
                    stop = prev
                end
                cn.prev = bp
                cn.next = firstcons
                firstcons.prev = cn
                if firstcons == start then
                    if head == start then
                        head = cn
                    end
                    start = cn
                end
                break
            end
            cn = cn.next
        end
        allreordered = c == stop
        current = c.next
    end

    if reph or vattu then
        local current, cns = start, nil
        while current ~= stop do
            local c = current
            local n = current.next
            if current.char == c_ra and n.char == c_halant then
                c = n
                n = n.next
                local b, bn = base, base
                while bn ~= stop  do
                    local next = bn.next
                    if dependent_vowel[next.char] then
                        b = next
                    end
                    bn = next
                end
                if current[a_state] == s_rphf then
                    -- position Reph (Ra + H) after post-base 'matra' (if any) since these
                    -- become marks on the 'matra', not on the base glyph
                    if b ~= current then
                        if current == start then
                            if head == start then
                                head = n
                            end
                            start = n
                        end
                        if b == stop then
                            stop = c
                        end
                        local prev = current.prev
                        if prev then
                            prev.next = n
                        end
                        if n then
                            n.prev = prev
                        end
                        local next = b.next
                        c.next = next
                        if next then
                            next.prev = c
                        end
                        c.next = next
                        b.next = current
                        current.prev = b
                    end
                elseif cns and cns.next ~= current then
                    -- position below-base Ra (vattu) following the consonants on which it is placed (either the base consonant or one of the pre-base consonants)
                    local cp, cnsn = current.prev, cns.next
                    if cp then
                        cp.next = n
                    end
                    if n then
                        n.prev = cp
                    end
                    cns.next = current
                    current.prev = cns
                    c.next = cnsn
                    if cnsn then
                        cnsn.prev = c
                    end
                    if c == stop then
                        stop = cp
                        break
                    end
                    current = n.prev
                end
            else
                local char = current.char
                if consonant[char] or char == c_nbsp then -- maybe combined hash
                    cns = current
                    local next = cns.next
                    if next.char == c_halant then
                        cns = next
                    end
                end
            end
            current = current.next
        end
    end

    if base.char == c_nbsp then
        head = remove_node(head,base)
        free_node(base)
    end

    return head, stop
end

-- If a pre-base matra character had been reordered before applying basic features,
-- the glyph can be moved closer to the main consonant based on whether half-forms had been formed.
-- Actual position for the matra is defined as “after last standalone halant glyph,
-- after initial matra position and before the main consonant”.
-- If ZWJ or ZWNJ follow this halant, position is moved after it.

-- so we break out ... this is only done for the first 'word' (if we feed words we can as
-- well test for non glyph.

function handlers.devanagari_reorder_matras(head,start,kind,lookupname,replacement) -- no leak
    local current = start -- we could cache attributes here
    local startfont = start.font
    local startattr = start[a_syllabe]
    -- can be fast loop
    while current and current.id == glyph_code and current.subtype<256 and current.font == font and current[a_syllabe] == startattr do
        local next = current.next
        if current.char == c_halant and not current[a_state] then
            if next and next.id == glyph_code and next.subtype<256 and next.font == font and next[a_syllabe] == startattr and zw_char[next.char] then
                current = next
            end
            local startnext = start.next
            head = remove_node(head,start)
            local next = current.next
            if next then
                next.prev = start
            end
            start.next = next
            current.next = start
            start.prev = current
            start = startnext
            break
        end
        current = next
    end
    return head, start, true
end

-- todo: way more caching of attributes and font

-- Reph’s original position is always at the beginning of the syllable, (i.e. it is not reordered at the character reordering stage).
-- However, it will be reordered according to the basic-forms shaping results.
-- Possible positions for reph, depending on the script, are; after main, before post-base consonant forms,
-- and after post-base consonant forms.

-- 1  If reph should be positioned after post-base consonant forms, proceed to step 5.
-- 2  If the reph repositioning class is not after post-base: target position is after the first explicit halant glyph between
--    the first post-reph consonant and last main consonant. If ZWJ or ZWNJ are following this halant, position is moved after it.
--    If such position is found, this is the target position. Otherwise, proceed to the next step.
--    Note: in old-implementation fonts, where classifications were fixed in shaping engine,
--    there was no case where reph position will be found on this step.
-- 3  If reph should be repositioned after the main consonant: from the first consonant not ligated with main,
--    or find the first consonant that is not a potential pre-base reordering Ra.
-- 4  If reph should be positioned before post-base consonant, find first post-base classified consonant not ligated with main.
--    If no consonant is found, the target position should be before the first matra, syllable modifier sign or vedic sign.
-- 5  If no consonant is found in steps 3 or 4, move reph to a position immediately before the first post-base matra,
--    syllable modifier sign or vedic sign that has a reordering class after the intended reph position.
--    For example, if the reordering position for reph is post-main, it will skip above-base matras that also have a post-main position.
-- 6  Otherwise, reorder reph to the end of the syllable.

-- hm, this only looks at the start of a nodelist ... is this supposed to be line based?

function handlers.devanagari_reorder_reph(head,start,kind,lookupname,replacement)
    -- since in Devanagari reph has reordering position 'before postscript' dev2 only follows step 2, 4, and 6,
    -- the other steps are still ToDo (required for scripts other than dev2)
    local current   = start.next
    local startnext = nil
    local startprev = nil
    local startfont = start.font
    local startattr = start[a_syllabe]
    while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and current[a_syllabe] == startattr do    --step 2
        if current.char == c_halant and not current[a_state] then
            local next = current.next
            if next and next.id == glyph_code and next.subtype<256 and next.font == startfont and next[a_syllabe] == startattr and zw_char[next.char] then
                current = next
            end
            startnext = start.next
            head = remove_node(head,start)
            local next = current.next
            if next then
                next.prev = start
            end
            start.next = next
            current.next = start
            start.prev = current
            start = startnext
            startattr = start[a_syllabe]
            break
        end
        current = current.next
    end
    if not startnext then
        current = start.next
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and current[a_syllabe] == startattr do    --step 4
            if current[a_state] == s_pstf then    --post-base
                startnext = start.next
                head = remove_node(head,start)
                local prev = current.prev
                start.prev = prev
                prev.next = start
                start.next = current
                current.prev = start
                start = startnext
                startattr = start[a_syllabe]
                break
            end
            current = current.next
        end
    end
    -- ToDo: determine position for reph with reordering position other than 'before postscript'
    -- (required for scripts other than dev2)
    -- leaks
    if not startnext then
        current = start.next
        local c = nil
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and current[a_syllabe] == startattr do    --step 5
            if not c then
                local char = current.char
                -- todo: combine in one
                if mark_above_below_post[char] and reorder_class[char] ~= "after subscript" then
                    c = current
                end
            end
            current = current.next
        end
        -- here we can loose the old start node: maybe best split cases
        if c then
            startnext = start.next
            head = remove_node(head,start)
            local prev = c.prev
            start.prev = prev
            prev.next = start
            start.next = c
            c.prev = start
            -- end
            start = startnext
            startattr = start[a_syllabe]
        end
    end
    -- leaks
    if not startnext then
        current = start
        local next = current.next
        while next and next.id == glyph_code and next.subtype<256 and next.font == startfont and next[a_syllabe] == startattr do    --step 6
            current = next
            next = current.next
        end
        if start ~= current then
            startnext = start.next
            head = remove_node(head,start)
            local next = current.next
            if next then
                next.prev = start
            end
            start.next = next
            current.next = start
            start.prev = current
            start = startnext
        end
    end
    --
    return head, start, true
end

-- we can cache some checking (v)

-- If a pre-base reordering consonant is found, reorder it according to the following rules:
--
-- 1  Only reorder a glyph produced by substitution during application of the feature.
--    (Note that a font may shape a Ra consonant with the feature generally but block it in certain contexts.)
-- 2  Try to find a target position the same way as for pre-base matra. If it is found, reorder pre-base consonant glyph.
-- 3  If position is not found, reorder immediately before main consonant.

-- UNTESTED: NOT CALLED IN EXAMPLE

function handlers.devanagari_reorder_pre_base_reordering_consonants(head,start,kind,lookupname,replacement)
    local current = start
    local startnext = nil
    local startprev = nil
    local startfont = start.font
    local startattr = start[a_syllabe]
    -- can be fast for loop + caching state
    while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and current[a_syllabe] == startattr do
        local next = current.next
        if current.char == c_halant and not current[a_state] then
            if next and next.id == glyph_code and next.subtype<256 and next.font == font and next[a_syllabe] == startattr then
                local char = next.char
                if char == c_zwnj or char == c_zwj then
                    current = next
                end
            end
            startnext = start.next
            removenode(start,start)
            local next = current.next
            if next then
                next.prev = start
            end
            start.next = next
            current.next = start
            start.prev = current
            start = startnext
            break
        end
        current = next
    end
    if not startnext then
        current = start.next
        startattr = start[a_syllabe]
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and current[a_syllabe] == startattr do
            if not consonant[current.char] and current[a_state] then    --main
                startnext = start.next
                removenode(start,start)
                local prev = current.prev
                start.prev = prev
                prev.next = start
                start.next = current
                current.prev = start
                start = startnext
                break
            end
            current = current.next
        end
    end
    return head, start, true
end

function handlers.devanagari_remove_joiners(head,start,kind,lookupname,replacement)
    local stop = start.next
    local startfont = start.font
    while stop and stop.id == glyph_code and stop.subtype<256 and stop.font == startfont do
        local char = stop.char
        if char == c_zwnj or char == c_zwj then
            stop = stop.next
        else
            break
        end
    end
    if stop then
        stop.prev.next = nil
        stop.prev = start.prev
    end
    local prev = start.prev
    if prev then
        prev.next = stop
    end
    flush_list(start)
    return head, stop, true
end

local valid = {
    rphf = true,
    pref = true,
    half = true,
    blwf = true,
    pstf = true,
}

local function dev2_initialize(font,attr)

    local tfmdata        = fontdata[font]
    local resources      = tfmdata.resources
    local lookuphash     = resources.lookuphash

    local datasets       = otf.dataset(tfmdata,font,attr)
    local devanagaridata = datasets.devanagari

    if devanagaridata then -- maybe also check for e.g. seqsubset

        return lookuphash, devanagaridata.seqsubset

    else

        devanagaridata           = { }
        datasets.devanagari      = devanagaridata

        local seqsubset          = { }
        devanagaridata.seqsubset = seqsubset

        local sequences        = resources.sequences

        for s=1,#sequences do
         -- local sequence = sequences[s]
            local dataset = datasets[s]
            if dataset and dataset[1] then -- featurevalue
                local kind = dataset[4]
                if kind and valid[kind] then
                    -- could become a function call
                 -- local subtables = sequence.subtables
                    local subtables = dataset[5].subtables
                    for i=1,#subtables do
                        local lookupname = subtables[i]
                        local lookupcache = lookuphash[lookupname]
                        if lookupcache then
                            local reph = false
                            local chain = dataset[3]
                            if chain ~= 0 then --rphf is result of of chain
                                --ToDo: rphf might be result of other handler/chainproc
                            else
                                reph = lookupcache[0x0930]
                                if reph then
                                    reph = reph[0x094D]
                                    if reph then
                                        reph = reph["ligature"]
                                    end
                                end
                                --ToDo: rphf actualy acts on consonant + halant. This consonant might not necesseraly be 0x0930 ... (but fot dev2 it is)
                            end
                            seqsubset[#seqsubset+1] = { kind, lookupcache, reph }
                        end
                    end
                end
            end
        end

        lookuphash["dv01_reorder_matras"] = pre_mark -- move to initializer ?

        return lookuphash, seqsubset

    end

end

-- this one will be merged into the caller: it saves a call, but we will then make function
-- of the actions

local function dev2_reorder(head,start,stop,font,attr) -- maybe do a pass over (determine stop in sweep)

    local lookuphash, seqsubset = dev2_initialize(font,attr)

    local reph, pre_base_reordering_consonants = false, { } -- was nil ... probably went unnoticed because never assigned
    local halfpos, basepos, subpos, postpos = nil, nil, nil, nil
    local locl = { }

    for i=1,#seqsubset do

        -- maybe quit if start == stop

        local subset = seqsubset[i]
        local kind = subset[1]
        local lookupcache = subset[2]
        if kind == "rphf" then
            if subset[3] then
                reph = true
            end
            local current = start
            local last = stop.next
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or current.char
                    local found = lookupcache[c]
                    if found then
                        local next = current.next
                        local n = locl[next] or next.char
                        if found[n] then    --above-base: rphf    Consonant + Halant
                            local afternext = next ~= stop and next.next
                            if afternext and zw_char[afternext.char] then -- ZWJ and ZWNJ prevent creation of reph
                                current = next
                                current = current.next
                            elseif current == start then
                                current[a_state] = s_rphf
                                current = next
                            else
                                current = next
                            end
                        end
                    end
                end
                current = current.next
            end
        elseif kind == "pref" then
            -- why not global? pretty ineffient this way
            -- this will move to the initializer and we will store the hash in dataset
            for k, v in lookupcache[0x094D], next do
                pre_base_reordering_consonants[k] = v and v["ligature"]    --ToDo: reph might also be result of chain
            end
            --
            local current = start
            local last = stop.next
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or current.char
                    local found = lookupcache[c]
                    if found then
                        local next = current.next
                        local n = locl[next] or next.char
                        if found[n] then
                            current[a_state] = s_pref
                            next[a_state] = s_pref
                            current = next
                        end
                    end
                end
                current = current.next
            end
        elseif kind == "half" then -- half forms: half / Consonant + Halant
            local current = start
            local last = stop.next
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or current.char
                    local found = lookupcache[c]
                    if found then
                        local next = current.next
                        local n = locl[next] or next.char
                        if found[n] then
                            if next ~= stop and next.next.char == c_zwnj then    --ZWNJ prevent creation of half
                                current = current.next
                            else
                                current[a_state] = s_half
                                if not halfpos then
                                    halfpos = current
                                end
                            end
                            current = next
                        end
                    end
                end
                current = current.next
            end
        elseif kind == "blwf" then -- below-base: blwf / Halant + Consonant
            local current = start
            local last = stop.next
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or current.char
                    local found = lookupcache[c]
                    if found then
                        local next = current.next
                        local n = locl[next] or next.char
                        if found[n] then
                            current[a_state] = s_blwf
                            next[a_state] = s_blwf
                            current = next
                            subpos = current
                        end
                    end
                end
                current = current.next
            end
        elseif kind == "pstf" then -- post-base: pstf / Halant + Consonant
            local current = start
            local last = stop.next
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or current.char
                    local found = lookupcache[c]
                    if found then
                        local next = current.next
                        local n = locl[next] or next.char
                        if found[n] then
                            current[a_state] = s_pstf
                            next[a_state] = s_pstf
                            current = next
                            postpos = current
                        end
                    end
                end
                current = current.next
            end
        end
    end

    -- this one changes per word

    lookuphash["dv02_reorder_reph"] = { [reph] = true }
    lookuphash["dv03_reorder_pre_base_reordering_consonants"] = pre_base_reordering_consonants

    local current, base, firstcons = start, nil, nil

    if start[a_state] == s_rphf then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph from candidates for base consonants
        current = start.next.next
    end

    if current ~= stop.next and current.char == c_nbsp then
        -- Stand Alone cluster
        if current == stop then
            stop = stop.prev
            head = remove_node(head,current)
            free_node(current)
            return head, stop
        else
            base = current
            current = current.next
            if current ~= stop then
                local char = current.char
                if char == c_nukta then
                    current = current.next
                    char = current.char
                end
                if char == c_zwj then
                    local next = current.next
                    if current ~= stop and next ~= stop and next.char == c_halant then
                        current = next
                        next = current.next
                        local tmp = next.next
                        local changestop = next == stop
                        next.next = nil
                        current[a_state] = s_pref
                        current = processcharacters(current)
                        current[a_state] = s_blwf
                        current = processcharacters(current)
                        current[a_state] = s_pstf
                        current = processcharacters(current)
                        current[a_state] = unsetvalue
                        if current.char == c_halant then
                            current.next.next = tmp
                            local nc = copy_node(current)
                            current.char = dotted_circle
                            head = insert_node_after(head,current,nc)
                        else
                            current.next = tmp -- assumes that result of pref, blwf, or pstf consists of one node
                            if changestop then
                                stop = current
                            end
                        end
                    end
                end
            end
        end
    else -- not Stand Alone cluster
        local last = stop.next
        while current ~= last do    -- find base consonant
            local next = current.next
            if consonant[current.char] then
                if not (current ~= stop and next ~= stop and next.char == c_halant and next.next.char == c_zwj) then
                    if not firstcons then
                        firstcons = current
                    end
                    -- check whether consonant has below-base or post-base form or is pre-base reordering Ra
                    local a = current[a_state]
                    if not (a == s_pref or a == s_blwf or a == pstf) then
                        base = current
                    end
                end
            end
            current = next
        end
        if not base then
            base = firstcons
        end
    end

    if not base then
        if start[a_state] == s_rphf then
            start[a_state] = unsetvalue
        end
        return head, stop
    else
        if base[a_state] then
            base[a_state] = unsetvalue
        end
        basepos = base
    end
    if not halfpos then
        halfpos = base
    end
    if not subpos then
        subpos = base
    end
    if not postpos then
        postpos = subpos or base
    end

    -- Matra characters are classified and reordered by which consonant in a conjunct they have affinity for

    local moved = { }
    local current = start
    local last = stop.next
    while current ~= last do
        local char, target, cn = locl[current] or current.char, nil, current.next
        if not moved[current] and dependent_vowel[char] then
            if pre_mark[char] then            -- Before first half form in the syllable
                moved[current] = true
                local prev = current.prev
                local next = current.next
                if prev then
                    prev.next = next
                end
                if next then
                    next.prev = prev
                end
                if current == stop then
                    stop = current.prev
                end
                if halfpos == start then
                    if head == start then
                        head = current
                    end
                    start = current
                end
                local prev = halfpos.prev
                if prev then
                    prev.next = current
                end
                current.prev = prev
                halfpos.prev = current
                current.next = halfpos
                halfpos = current
            elseif above_mark[char] then    -- After main consonant
                target = basepos
                if subpos == basepos then
                    subpos = current
                end
                if postpos == basepos then
                    postpos = current
                end
                basepos = current
            elseif below_mark[char] then    -- After subjoined consonants
                target = subpos
                if postpos == subpos then
                    postpos = current
                end
                subpos = current
            elseif post_mark[char] then    -- After post-form consonant
                target = postpos
                postpos = current
            end
            if mark_above_below_post[char] then
                local prev = current.prev
                if prev ~= target then
                    local next = current.next
                    if prev then -- not needed, already tested with target
                        prev.next = next
                    end
                    if next then
                        next.prev = prev
                    end
                    if current == stop then
                        stop = prev
                    end
                    local next = target.next
                    if next then
                        next.prev = current
                    end
                    current.next = next
                    target.next = current
                    current.prev = target
                end
            end
        end
        current = cn
    end

    -- Reorder marks to canonical order: Adjacent nukta and halant or nukta and vedic sign are always repositioned if necessary, so that the nukta is first.

    local current, c = start, nil
    while current ~= stop do
        local char = current.char
        if char == c_halant or stress_tone_mark[char] then
            if not c then
                c = current
            end
        else
            c = nil
        end
        local next = current.next
        if c and next.char == c_nukta then
            if head == c then
                head = next
            end
            if stop == next then
                stop = current
            end
            local prev = c.prev
            if prev then
                prev.next = next
            end
            next.prev = prev
            local nextnext = next.next
            current.next = nextnext
            local nextnextnext = nextnext.next
            if nextnextnext then
                nextnextnext.prev = current
            end
            c.prev = nextnext
            nextnext.next = c
        end
        if stop == current then break end
        current = current.next
    end

    if base.char == c_nbsp then
        head = remove_node(head, base)
        free_node(base)
    end

    return head, stop
end

-- cleaned up and optimized ... needs checking (local, check order, fixes, extra hash, etc)

local separator = { }

imerge(separator,consonant)
imerge(separator,independent_vowel)
imerge(separator,dependent_vowel)
imerge(separator,vowel_modifier)
imerge(separator,stress_tone_mark)

separator[0x093C] = true -- nukta
separator[0x094D] = true -- halant

local function analyze_next_chars_one(c,font,variant) -- skip one dependent vowel
    -- why two variants ... the comment suggests that it's the same ruleset
    local n = c.next
    if not n then
        return c
    end
    if variant == 1 then
        local v = n.id == glyph_code and n.subtype<256 and n.font == font
        if v and n.char == c_nukta then
            n = n.next
            if n then
                v = n.id == glyph_code and n.subtype<256 and n.font == font
            end
        end
        if n and v then
            local nn = n.next
            if nn and nn.id == glyph_code and nn.subtype<256 and nn.font == font then
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and nnn.subtype<256 and nnn.font == font then
                    local nnc = nn.char
                    local nnnc = nnn.char
                    if nnc == c_zwj and consonant[nnnc] then
                        c = nnn
                    elseif (nnc == c_zwnj or nnc == c_zwj) and nnnc == c_halant then
                        local nnnn = nnn.next
                        if nnnn and nnnn.id == glyph_code and consonant[nnnn.char] and nnnn.subtype<256 and nnnn.font == font then
                            c = nnnn
                        end
                    end
                end
            end
        end
    elseif variant == 2 then
        if n.id == glyph_code and n.char == c_nukta and n.subtype<256 and n.font == font then
            c = n
        end
        n = c.next
        if n and n.id == glyph_code and n.subtype<256 and n.font == font then
            local nn = n.next
            if nn then
                local nv = nn.id == glyph_code and nn.subtype<256 and nn.font == font
                if nv and zw_char[n.char] then
                    n = nn
                    nn = nn.next
                    nv = nn.id == glyph_code and nn.subtype<256 and nn.font == font
                end
                if nn and nv and n.char == c_halant and consonant[nn.char] then
                    c = nn
                end
            end
        end
    end
    -- c = ms_matra(c)
    local n = c.next
    if not n then
        return c
    end
    local v = n.id == glyph_code and n.subtype<256 and n.font == font
    if not v then
        return c
    end
    local char = n.char
    if dependent_vowel[char] then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if char == c_nukta then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if char == c_halant then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if vowel_modifier[char] then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if stress_tone_mark[char] then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if stress_tone_mark[char] then
        return n
    else
        return c
    end
end

local function analyze_next_chars_two(c,font)
    local n = c.next
    if not n then
        return c
    end
    if n.id == glyph_code and n.char == c_nukta and n.subtype<256 and n.font == font then
        c = n
    end
    n = c
    while true do
        local nn = n.next
        if nn and nn.id == glyph_code and nn.subtype<256 and nn.font == font then
            local char = nn.char
            if char == c_halant then
                n = nn
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and zw_char[nnn.char] and nnn.subtype<256 and nnn.font == font then
                    n = nnn
                end
            elseif char == c_zwnj or char == c_zwj then
             -- n = nn -- not here (?)
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and nnn.char == c_halant and nnn.subtype<256 and nnn.font == font then
                    n = nnn
                end
            else
                break
            end
            local nn = n.next
            if nn and nn.id == glyph_code and consonant[nn.char] and nn.subtype<256 and nn.font == font then
                n = nn
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and nnn.char == c_nukta and nnn.subtype<256 and nnn.font == font then
                    n = nnn
                end
                c = n
            else
                break
            end
        else
            break
        end
    end
    --
    if not c then
        -- This shouldn't happen I guess.
        return
    end
    local n = c.next
    if not n then
        return c
    end
    local v = n.id == glyph_code and n.subtype<256 and n.font == font
    if not v then
        return c
    end
    local char = n.char
    if char == c_anudatta then
        c = n
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if char == c_halant then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
        if char == c_zwnj or char == c_zwj then
            c = c.next
            n = c.next
            if not n then
                return c
            end
            v = n.id == glyph_code and n.subtype<256 and n.font == font
            if not v then
                return c
            end
            char = n.char
        end
    else
        -- c = ms_matra(c)
        -- same as one
        if dependent_vowel[char] then
            c = c.next
            n = c.next
            if not n then
                return c
            end
            v = n.id == glyph_code and n.subtype<256 and n.font == font
            if not v then
                return c
            end
            char = n.char
        end
        if char == c_nukta then
            c = c.next
            n = c.next
            if not n then
                return c
            end
            v = n.id == glyph_code and n.subtype<256 and n.font == font
            if not v then
                return c
            end
            char = n.char
        end
        if char == c_halant then
            c = c.next
            n = c.next
            if not n then
                return c
            end
            v = n.id == glyph_code and n.subtype<256 and n.font == font
            if not v then
                return c
            end
            char = n.char
        end
    end
    -- same as one
    if vowel_modifier[char] then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if stress_tone_mark[char] then
        c = c.next
        n = c.next
        if not n then
            return c
        end
        v = n.id == glyph_code and n.subtype<256 and n.font == font
        if not v then
            return c
        end
        char = n.char
    end
    if stress_tone_mark[char] then
        return n
    else
        return c
    end
end

local function inject_syntax_error(head,current,mark)
    local signal = copy_node(current)
    if mark == pre_mark then
        signal.char = dotted_circle
    else
        current.char = dotted_circle
    end
    return insert_node_after(head,current,signal)
end

-- It looks like these two analyzers were written independently but they share
-- a lot. Common code has been synced.

function methods.deva(head,font,attr)
    local current, start, done = head, true, false
    while current do
        if current.id == glyph_code and current.subtype<256 and current.font == font then
            done = true
            local syllablestart = current
            local syllableend = nil
            local c = current
            local n = c.next
            if n and c.char == c_ra and n.id == glyph_code and n.char == c_halant and n.subtype<256 and n.font == font then
                local n = n.next
                if n and n.id == glyph_code and n.subtype<256 and n.font == font then
                    c = n
                end
            end
            local standalone = c.char == c_nbsp
            if standalone then
                local prev = current.prev
                if not prev then
                    -- begin of paragraph or box
                elseif prev.id ~= glyph_code or prev.subtype>=256 or prev.font ~= font then
                    -- different font or language so quite certainly a different word
                elseif not separator[prev.char] then
                    -- something that separates words
                else
                    standalone = false
                end
            end
            if standalone then
                -- stand alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
                local syllabeend, current = analyze_next_chars_one(c,font,2) -- watch out, here we set current to next
                if syllablestart ~= syllableend then
                    head, current = deva_reorder(head,syllablestart,syllableend,font,attr)
                    current = current.next
                end
            else
                -- we can delay the n.subtype and n.font and test for say halant first
                -- as an table access is faster than two function calls (subtype and font are
                -- pseudo fields) but the code becomes messy (unless we make it a function)
                local char = current.char
                if consonant[char] then
                    -- syllable containing consonant
                    local prevc = true
                    while prevc do
                        prevc = false
                        local n = current.next
                        if not n then
                            break
                        end
                        local v = n.id == glyph_code and n.subtype<256 and n.font == font
                        if not v then
                            break
                        end
                        local c = n.char
                        if c == c_nukta then
                            n = n.next
                            if not n then
                                break
                            end
                            v = n.id == glyph_code and n.subtype<256 and n.font == font
                            if not v then
                                break
                            end
                            c = n.char
                        end
                        if c == c_halant then
                            n = n.next
                            if not n then
                                break
                            end
                            v = n.id == glyph_code and n.subtype<256 and n.font == font
                            if not v then
                                break
                            end
                            c = n.char
                            if c == c_zwnj or c == c_zwj then
                                n = n.next
                                if not n then
                                    break
                                end
                                v = n.id == glyph_code and n.subtype<256 and n.font == font
                                if not v then
                                    break
                                end
                                c = n.char
                            end
                            if consonant[c] then
                                prevc = true
                                current = n
                            end
                        end
                    end
                    local n = current.next
                    if n and n.id == glyph_code and n.char == c_nukta and n.subtype<256 and n.font == font then
                        -- nukta (not specified in Microsft Devanagari OpenType specification)
                        current = n
                        n = current.next
                    end
                    syllableend = current
                    current = n
                    if current then
                        local v = current.id == glyph_code and current.subtype<256 and current.font == font
                        if v then
                            if current.char == c_halant then
                                -- syllable containing consonant without vowels: {C + [Nukta] + H} + C + H
                                local n = current.next
                                if n and n.id == glyph_code and zw_char[n.char] and n.subtype<256 and n.font == font then
                                    -- code collapsed, probably needs checking with intention
                                    syllableend = n
                                    current = n.next
                                else
                                    syllableend = current
                                    current = n
                                end
                            else
                                -- syllable containing consonant with vowels: {C + [Nukta] + H} + C + [M] + [VM] + [SM]
                                local c = current.char
                                if dependent_vowel[c] then
                                    syllableend = current
                                    current = current.next
                                    v = current and current.id == glyph_code and current.subtype<256 and current.font == font
                                    if v then
                                        c = current.char
                                    end
                                end
                                if v and vowel_modifier[c] then
                                    syllableend = current
                                    current = current.next
                                    v = current and current.id == glyph_code and current.subtype<256 and current.font == font
                                    if v then
                                        c = current.char
                                    end
                                end
                                if v and stress_tone_mark[c] then
                                    syllableend = current
                                    current = current.next
                                end
                            end
                        end
                    end
                    if syllablestart ~= syllableend then
                        head, current = deva_reorder(head,syllablestart,syllableend,font,attr)
                        current = current.next
                    end
                elseif independent_vowel[char] then
                    -- syllable without consonants: VO + [VM] + [SM]
                    syllableend = current
                    current = current.next
                    if current then
                        local v = current.id == glyph_code and current.subtype<256 and current.font == font
                        if v then
                            local c = current.char
                            if vowel_modifier[c] then
                                syllableend = current
                                current = current.next
                                v = current and current.id == glyph_code and current.subtype<256 and current.font == font
                                if v then
                                    c = current.char
                                end
                            end
                            if v and stress_tone_mark[c] then
                                syllableend = current
                                current = current.next
                            end
                        end
                    end
                else
                    local mark = mark_four[char]
                    if mark then
                        head, current = inject_syntax_error(head,current,mark)
                    end
                    current = current.next
                end
            end
        else
            current = current.next
        end
        start = false
    end

    return head, done
end

-- there is a good change that when we run into one with subtype < 256 that the rest is also done
-- so maybe we can omit this check (it's pretty hard to get glyphs in the stream out of the blue)

-- handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,1)

function methods.dev2(head,font,attr)
    local current = head
    local start = true
    local done = false
    local syllabe = 0
    while current do
        local syllablestart, syllableend = nil, nil
        if current.id == glyph_code and current.subtype<256 and current.font == font then
            done = true
            syllablestart = current
            local c = current
            local n = current.next
            if n and c.char == c_ra and n.id == glyph_code and n.char == c_halant and n.subtype<256 and n.font == font then
                local n = n.next
                if n and n.id == glyph_code and n.subtype<256 and n.font == font then
                    c = n
                end
            end
            local char = c.char
            if independent_vowel[char] then
                -- vowel-based syllable: [Ra+H]+V+[N]+[<[<ZWJ|ZWNJ>]+H+C|ZWJ+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
                current = analyze_next_chars_one(c,font,1)
                syllableend = current
            else
                local standalone = char == c_nbsp
                if standalone then
                    local p = current.prev
                    if not p then
                        -- begin of paragraph or box
                    elseif p.id ~= glyph_code or p.subtype>=256 or p.font ~= font then
                        -- different font or language so quite certainly a different word
                    elseif not separator[p.char] then
                        -- something that separates words
                    else
                        standalone = false
                    end
                end
                if standalone then
                    -- Stand Alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
                    current = analyze_next_chars_one(c,font,2)
                    syllableend = current
                elseif consonant[current.char] then
                    -- WHY current INSTEAD OF c ?

                    -- Consonant syllable: {C+[N]+<H+[<ZWNJ|ZWJ>]|<ZWNJ|ZWJ>+H>} + C+[N]+[A] + [< H+[<ZWNJ|ZWJ>] | {M}+[N]+[H]>]+[SM]+[(VD)]
                    current = analyze_next_chars_two(current,font) -- not c !
                    syllableend = current
                end
            end
        end
        if syllableend then
            syllabe = syllabe + 1
            local c = syllablestart
            local n = syllableend.next
            while c ~= n do
                c[a_syllabe] = syllabe
                c = c.next
            end
        end
        if syllableend and syllablestart ~= syllableend then
            head, current = dev2_reorder(head,syllablestart,syllableend,font,attr)
        end
        if not syllableend and current.id == glyph_code and current.subtype<256 and current.font == font and not current[a_state] then
            local mark = mark_four[current.char]
            if mark then
                head, current = inject_syntax_error(head,current,mark)
            end
        end
        start = false
        current = current.next
    end

    return head, done
end
