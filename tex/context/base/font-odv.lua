if not modules then modules = { } end modules ['font-odv'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Kai Eigner, TAT Zetwerk / Hans Hagen, PRAGMA ADE",
    copyright = "TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if true then
    -- Not yet as there is some change in headnode handling as needed
    -- for this mechanism and I won't adapt this code because soon there's
    -- another adaption coming (already in my private tree) but that need
    -- a newer luatex.
    return
end

-- Kai: we're leaking nodes (happens when assigning start nodes behind start, also
-- in the original code) so this needs to be sorted out. As I touched nearly all code,
-- reshuffled, etc. etc. (imagine how much can get messed up in nearly a week work) it
-- could be that I introduced bugs. There is more to gain (esp in the functions applied
-- to a range) but I'll do that when everything works as expected.

-- A few remarks:
--
-- This code is a partial rewrite of the code that deals with devanagari. The data and logic
-- is by Kai Eigner and based based on Microsoft's OpenType specifications for specific
-- scripts, but with a few improvements. More information can be found at:
--
-- deva: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/introO.mspx
-- dev2: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/intro.mspx
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
-- as that serves as reference. I kept the comments but added a few more. Due to the lots
-- of reshuffling glyphs quite some leaks occur(red) but once I'm satisfied with the rewrite
-- I'll weed them. I also integrated initialization etc into the regular mechanisms.
--
-- In the meantime, we're down from 25.5-3.5=22 seconds to 17.7-3.5=14.2 seconds for a 100
-- page sample with both variants so it's worth the effort. Due to the method chosen it will
-- never be real fast. If I ever become a power user I'll have a go at some further speed
-- up. I will rename some functions (and features) once we don't need to check the original
-- code. We now use a special subset sequence for use inside the analyzer (after all we could
-- can store this in the dataset and save redundant analysis).
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

local set_attribute      = node.set_attribute
local unset_attribute    = node.unset_attribute
local has_attribute      = node.has_attribute
local insert_node_after  = node.insert_after
local copy_node          = node.copy
local free_node          = node.free
local remove_node        = node.remove
local flush_list         = node.flush_list

local fontdata           = fonts.hashes.identifiers

local a_state            = attributes.private('state')
local a_syllabe          = attributes.private('syllabe')

local dotted_circle      = 0x25CC

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

local nukta = {
    [0x093C] = true,
}

local halant = {
    [0x094D] = true,
}

local ra = {
    [0x0930] = true,
}

local anudatta = {
    [0x0952] = true,
}

local nbsp = { -- might become a constant instead of table
    [0x00A0] = true,
}

local zwnj = { -- might become a constant instead of table
    [0x200C] = true,
}

local zwj = { -- might become a constant instead of table
    [0x200D] = true,
}

local zw_char = {
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

local both_joiners_true = { [0x200C] = true, [0x200D] = true }

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
    local script, language = otf.scriptandlanguage(tfmdata,attr) -- take fast variant
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

    if ra[start.char] and halant[n.char] and reph then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph
        -- from candidates for base consonants
        if n == stop then
            return head, stop
        end
        if zwj[n.next.char] then
            current = start
        else
            current = n.next
            set_attribute(start,a_state,5) -- rphf
        end
    end

    if nbsp[current.char] then
        -- Stand Alone cluster
        if current == stop then
            stop = stop.prev
            head = remove_node(head, current)
            free_node(current)
            return head, stop
        else
            base, firstcons, lastcons = current, current, current
            current = current.next
            if current ~= stop then
                if nukta[current.char] then
                    current = current.next
                end
                if zwj[current.char] then
                    if current ~= stop then
                        local next = current.next
                        if next ~= stop and halant[next.char] then
                            current = next
                            next = current.next
                            local tmp = next.next
                            local changestop = next == stop
                            local tempcurrent = copy_node(next)
                            local nextcurrent = copy_node(current)
                            tempcurrent.next = nextcurrent
                            nextcurrent.prev = tempcurrent
                            set_attribute(tempcurrent,a_state,8)    --blwf
                            tempcurrent = processcharacters(tempcurrent)
                            unset_attribute(tempcurrent,a_state)
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
            set_attribute(current,a_state,6)    --    half
            if not firstcons then
                firstcons = current
            end
            lastcons = current
            if not base then
                base = current
            elseif blwfcache[current.char] then
                -- consonant has below-base (or post-base) form
                set_attribute(current,a_state,8)    --    blwf
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
        if nukta[n.char] then
            np = n
            n = n.next
        end
        if halant[n.char] then
            if lastcons ~= stop then
                local ln = lastcons.next
                if nukta[ln.char] then
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
    if ra[start.char] and halant[n.char] and not (n ~= stop and zw_char[n.next.char]) then
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
        if next ~= stop and halant[next.char] and zwnj[next.next.char] then
            unset_attribute(current,a_state)
        end
        current = next
    end

    if base ~= stop and has_attribute(base,a_state) then
        local next = base.next
        if halant[next.char] and not (next ~= stop and zwj[next.next.char]) then
            unset_attribute(base,a_state)
        end
    end

    -- ToDo: split two- or three-part matras into their parts. Then, move the left 'matra' part to the beginning of the syllable.
    -- Not necessary for Devanagari. However it is necessay for other scripts, such as Tamil (e.g. TAMIL VOWEL SIGN O - 0BCA)

    -- classify consonants and 'matra' parts as pre-base, above-base (Reph), below-base or post-base, and group elements of the syllable (consonants and 'matras') according to this classification

    local current, allreordered, moved = start, false, { [base] = true }
    local a, b, p, bn = base, base, base, base.next
    if base ~= stop and nukta[bn.char] then
        a, b, p = bn, bn, bn
    end
    while not allreordered do
        -- current is always consonant
        local c = current
        local n = current.next
        local l = nil -- used ?
        if c ~= stop then
            if nukta[n.char] then
                c = n
                n = n.next
            end
            if c ~= stop then
                if halant[n.char] then
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
            if ra[current.char] and halant[n.char] then
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
                if has_attribute(current,a_state) == 5 then
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
                if consonant[char] or nbsp[char] then -- maybe combined hash
                    cns = current
                    local next = cns.next
                    if halant[next.char] then
                        cns = next
                    end
                end
            end
            current = current.next
        end
    end

    if nbsp[base.char] then
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

function handlers.devanagari_reorder_matras(start,kind,lookupname,replacement) -- no leak
    local current = start -- we could cache attributes here
    local startfont = start.font
    local startattr = has_attribute(start,a_syllabe)
    -- can be fast loop
    while current and current.id == glyph_code and current.subtype<256 and current.font == font and has_attribute(current,a_syllabe) == startattr do
        local next = current.next
        if halant[current.char] and not has_attribute(current,a_state) then
            if next and next.id == glyph_code and next.subtype<256 and next.font == font and has_attribute(next,a_syllabe) == startattr and zw_char[next.char] then
                current = next
            end
            local startnext = start.next
            remove_node(start,start)
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
    return start, true
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

function handlers.devanagari_reorder_reph(start,kind,lookupname,replacement)
    -- since in Devanagari reph has reordering position 'before postscript' dev2 only follows step 2, 4, and 6,
    -- the other steps are still ToDo (required for scripts other than dev2)
    local current   = start.next
    local startnext = nil
    local startprev = nil
    local startfont = start.font
    local startattr = has_attribute(start,a_syllabe)
    while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and has_attribute(current,a_syllabe) == startattr do    --step 2
        if halant[current.char] and not has_attribute(current,a_state) then
            local next = current.next
            if next and next.id == glyph_code and next.subtype<256 and next.font == startfont and has_attribute(next,a_syllabe) == startattr and zw_char[next.char] then
                current = next
            end
            startnext = start.next
            remove_node(start,start)
            local next = current.next
            if next then
                next.prev = start
            end
            start.next = next
            current.next = start
            start.prev = current
            start = startnext
            startattr = has_attribute(start,a_syllabe)
            break
        end
        current = current.next
    end
    if not startnext then
        current = start.next
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and has_attribute(current,a_syllabe) == startattr do    --step 4
            if has_attribute(current,a_state) == 9 then    --post-base
                startnext = start.next
                remove_node(start,start)
                local prev = current.prev
                start.prev = prev
                prev.next = start
                start.next = current
                current.prev = start
                start = startnext
                startattr = has_attribute(start,a_syllabe)
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
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and has_attribute(current,a_syllabe) == startattr do    --step 5
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
            remove_node(start,start)
            local prev = c.prev
            start.prev = prev
            prev.next = start
            start.next = c
            c.prev = start
            start = startnext
            startattr = has_attribute(start,a_syllabe)
        end
    end
    -- leaks
    if not startnext then
        current = start
        local next = current.next
        while next and next.id == glyph_code and next.subtype<256 and next.font == startfont and has_attribute(next,a_syllabe) == startattr do    --step 6
            current = next
            next = current.next
        end
        if start ~= current then
            startnext = start.next
            remove_node(start,start)
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
    return start, true
end

-- we can cache some checking (v)

-- If a pre-base reordering consonant is found, reorder it according to the following rules:
--
-- 1  Only reorder a glyph produced by substitution during application of the feature.
--    (Note that a font may shape a Ra consonant with the feature generally but block it in certain contexts.)
-- 2  Try to find a target position the same way as for pre-base matra. If it is found, reorder pre-base consonant glyph.
-- 3  If position is not found, reorder immediately before main consonant.

-- UNTESTED: NOT CALLED IN EXAMPLE

function handlers.devanagari_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
    local current = start
    local startnext = nil
    local startprev = nil
    local startfont = start.font
    local startattr = has_attribute(start,a_syllabe)
    -- can be fast for loop + caching state
    while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and has_attribute(current,a_syllabe) == startattr do
        local next = current.next
        if halant[current.char] and not has_attribute(current,a_state) then
            if next and next.id == glyph_code and next.subtype<256 and next.font == font and has_attribute(next,a_syllabe) == startattr then
                local char = next.char
                if zw_char[char] then
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
        startattr = has_attribute(start,a_syllabe)
        while current and current.id == glyph_code and current.subtype<256 and current.font == startfont and has_attribute(current,a_syllabe) == startattr do
            if not consonant[current.char] and has_attribute(current,a_state) then    --main
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
    return start, true
end

function handlers.devanagari_remove_joiners(start,kind,lookupname,replacement)
    local stop = start.next
    local startfont = start.font
    while stop and stop.id == glyph_code and stop.subtype<256 and stop.font == startfont do
        local char = stop.char
        if zw_char[char] then
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
    return stop, true
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
                                set_attribute(current,a_state,5)
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
                            set_attribute(current,a_state,7)
                            set_attribute(next,a_state,7)
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
                            if next ~= stop and zwnj[next.next.char] then    --ZWNJ prevent creation of half
                                current = current.next
                            else
                                set_attribute(current,a_state,6)
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
                            set_attribute(current,a_state,8)
                            set_attribute(next,a_state,8)
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
                            set_attribute(current,a_state,9)
                            set_attribute(next,a_state,9)
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

    if has_attribute(start,a_state) == 5 then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph from candidates for base consonants
        current = start.next.next
    end

    if current ~= stop.next and nbsp[current.char] then
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
                if nukta[char] then
                    current = current.next
                    char = current.char
                end
                if zwj[char] then
                    local next = current.next
                    if current ~= stop and next ~= stop and halant[next.char] then
                        current = next
                        next = current.next
                        local tmp = next.next
                        local changestop = next == stop
                        next.next = nil
                        set_attribute(current,a_state,7)    --pref
                        current = processcharacters(current)
                        set_attribute(current,a_state,8)    --blwf
                        current = processcharacters(current)
                        set_attribute(current,a_state,9)    --pstf
                        current = processcharacters(current)
                        unset_attribute(current,a_state)
                        if halant[current.char] then
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
                if not (current ~= stop and next ~= stop and halant[next.char] and zwj[next.next.char]) then
                    if not firstcons then
                        firstcons = current
                    end
                    -- check whether consonant has below-base or post-base form or is pre-base reordering Ra
                    local a = has_attribute(current,a_state)
                    if not (a == 7 or a == 8 or a == 9) then
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
        if has_attribute(start,a_state) == 5 then
            unset_attribute(start,a_state)
        end
        return head, stop
    else
        if has_attribute(base,a_state) then
            unset_attribute(base,a_state)
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
        if halant[char] or stress_tone_mark[char] then
            if not c then
                c = current
            end
        else
            c = nil
        end
        local next = current.next
        if c and nukta[next.char] then
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

    if nbsp[base.char] then
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
imerge(separator,nukta)
imerge(separator,halant)

local function analyze_next_chars_one(c,font,variant) -- skip one dependent vowel
    -- why two variants ... the comment suggests that it's the same ruleset
    local n = c.next
    if not n then
        return c
    end
    if variant == 1 then
        local v = n.id == glyph_code and n.subtype<256 and n.font == font
        if v and nukta[n.char] then
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
                    if zwj[nnc] and consonant[nnnc] then
                        c = nnn
                    elseif zw_char[nnc] and halant[nnnc] then
                        local nnnn = nnn.next
                        if nnnn and nnnn.id == glyph_code and consonant[nnnn.char] and nnnn.subtype<256 and nnnn.font == font then
                            c = nnnn
                        end
                    end
                end
            end
        end
    elseif variant == 2 then
        if n.id == glyph_code and nukta[n.char] and n.subtype<256 and n.font == font then
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
                if nn and nv and halant[n.char] and consonant[nn.char] then
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
    if nukta[char] then
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
    if halant[char] then
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
    if n.id == glyph_code and nukta[n.char] and n.subtype<256 and n.font == font then
        c = n
    end
    n = c
    while true do
        local nn = n.next
        if nn and nn.id == glyph_code and nn.subtype<256 and nn.font == font then
            local char = nn.char
            if halant[char] then
                n = nn
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and zw_char[nnn.char] and nnn.subtype<256 and nnn.font == font then
                    n = nnn
                end
            elseif zw_char[char] then
             -- n = nn -- not here (?)
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and halant[nnn.char] and nnn.subtype<256 and nnn.font == font then
                    n = nnn
                end
            else
                break
            end
            local nn = n.next
            if nn and nn.id == glyph_code and consonant[nn.char] and nn.subtype<256 and nn.font == font then
                n = nn
                local nnn = nn.next
                if nnn and nnn.id == glyph_code and nukta[nnn.char] and nnn.subtype<256 and nnn.font == font then
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
    if anudatta[char] then
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
    if halant[char] then
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
        if zw_char[char] then
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
        if nukta[char] then
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
        if halant[char] then
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
            if n and ra[c.char] and n.id == glyph_code and halant[n.char] and n.subtype<256 and n.font == font then
                local n = n.next
                if n and n.id == glyph_code and n.subtype<256 and n.font == font then
                    c = n
                end
            end
            local standalone = nbsp[c.char]
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
                -- we can delay the n.subtype and n.font and test for say halant[c] first
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
                        if nukta[c] then
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
                        if halant[c] then
                            n = n.next
                            if not n then
                                break
                            end
                            v = n.id == glyph_code and n.subtype<256 and n.font == font
                            if not v then
                                break
                            end
                            c = n.char
                            if zw_char[c] then
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
                    if n and n.id == glyph_code and nukta[n.char] and n.subtype<256 and n.font == font then
                        -- nukta (not specified in Microsft Devanagari OpenType specification)
                        current = n
                        n = current.next
                    end
                    syllableend = current
                    current = n
                    if current then
                        local v = current.id == glyph_code and current.subtype<256 and current.font == font
                        if v then
                            if halant[current.char] then
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

-- handler(start,kind,lookupname,lookupmatch,sequence,lookuphash,1)

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
            if n and ra[c.char] and n.id == glyph_code and halant[n.char] and n.subtype<256 and n.font == font then
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
                local standalone = nbsp[char]
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
                set_attribute(c,a_syllabe,syllabe)
                c = c.next
            end
        end
        if syllableend and syllablestart ~= syllableend then
            head, current = dev2_reorder(head,syllablestart,syllableend,font,attr)
        end
        if not syllableend and current.id == glyph_code and current.subtype<256 and current.font == font and not has_attribute(current,a_state) then
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

-- Temporary checker:

if false then -- when true we can see how much nodes bleed

    local function check(what,action,head,kind,lookupname,replacement)
        local n_before   = nodes.count(head)
        local s_before   = nodes.listtoutf(head)
        local head, done = action(head,kind,lookupname,replacement)
        local n_after    = nodes.count(head)
        local s_after    = nodes.listtoutf(head)
        if n_before ~= n_after then
            print("leak",what)
            print(n_before,s_before)
            print(n_after,s_after)
        end
        return head, done
    end

    local devanagari_reorder_matras                         = handlers.devanagari_reorder_matras
    local devanagari_reorder_reph                           = handlers.devanagari_reorder_reph
    local devanagari_reorder_pre_base_reordering_consonants = handlers.devanagari_reorder_pre_base_reordering_consonants
    local devanagari_remove_joiners                         = handlers.devanagari_remove_joiners

    function handlers.devanagari_reorder_matras(start,kind,lookupname,replacement)
        if trace then
            return check("matras",devanagari_reorder_matras,start,kind,lookupname,replacement)
        else
            return devanagari_reorder_matras(start,kind,lookupname,replacement)
        end
    end

    function handlers.devanagari_reorder_reph(start,kind,lookupname,replacement)
        if trace then
            return check("reph",devanagari_reorder_reph,start,kind,lookupname,replacement)
        else
            return devanagari_reorder_reph(start,kind,lookupname,replacement)
        end
    end

    function handlers.devanagari_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
        if trace then
            return check("consonants",devanagari_reorder_pre_base_reordering_consonants,start,kind,lookupname,replacement)
        else
            return devanagari_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
        end
    end

    function handlers.devanagari_remove_joiners(start,kind,lookupname,replacement)
        if trace then
            return check("joiners",devanagari_remove_joiners,start,kind,lookupname,replacement)
        else
            return devanagari_remove_joiners(start,kind,lookupname,replacement)
        end
    end

end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- We keep the original around for a while so that we can check it   --
-- when the above code does it wrong (data tables are not included). --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- local state = attributes.private('state')
-- local sylnr = attributes.private('syllabe')
--
-- local function install_dev(tfmdata)
--     local features = tfmdata.resources.features
--     local sequences = tfmdata.resources.sequences
--
--     local insertpos = 1
--     for s=1,#sequences do    -- classify chars
--         for k in pairs(basic_shaping_forms) do
--             if sequences[s].features and ( sequences[s].features[k] or sequences[s].features.locl ) then insertpos = s + 1 end
--         end
--     end
--
--     features.gsub["dev2_reorder_matras"] = { ["dev2"] = { ["dflt"] = true } }
--     features.gsub["dev2_reorder_reph"] = { ["dev2"] = { ["dflt"] = true } }
--     features.gsub["dev2_reorder_pre_base_reordering_consonants"] = { ["dev2"] = { ["dflt"] = true } }
--     features.gsub["remove_joiners"] = { ["deva"] = { ["dflt"] = true }, ["dev2"] = { ["dflt"] = true } }
--
--     local sequence_dev2_reorder_matras = {
--         chain = 0,
--         features = { dev2_reorder_matras = { dev2 = { dflt = true } } },
--         flags = { false, false, false, false },
--         name = "dev2_reorder_matras",
--         subtables = { "dev2_reorder_matras" },
--         type = "dev2_reorder_matras",
--     }
--     local sequence_dev2_reorder_reph = {
--         chain = 0,
--         features = { dev2_reorder_reph = { dev2 = { dflt = true } } },
--         flags = { false, false, false, false },
--         name = "dev2_reorder_reph",
--         subtables = { "dev2_reorder_reph" },
--         type = "dev2_reorder_reph",
--     }
--     local sequence_dev2_reorder_pre_base_reordering_consonants = {
--         chain = 0,
--         features = { dev2_reorder_pre_base_reordering_consonants = { dev2 = { dflt = true } } },
--         flags = { false, false, false, false },
--         name = "dev2_reorder_pre_base_reordering_consonants",
--         subtables = { "dev2_reorder_pre_base_reordering_consonants" },
--         type = "dev2_reorder_pre_base_reordering_consonants",
--     }
--     local sequence_remove_joiners = {
--         chain = 0,
--         features = { remove_joiners = { deva = { dflt = true }, dev2 = { dflt = true } } },
--         flags = { false, false, false, false },
--         name = "remove_joiners",
--         subtables = { "remove_joiners" },
--         type = "remove_joiners",
--     }
--     table.insert(sequences, insertpos, sequence_dev2_reorder_pre_base_reordering_consonants)
--     table.insert(sequences, insertpos, sequence_dev2_reorder_reph)
--     table.insert(sequences, insertpos, sequence_dev2_reorder_matras)
--     table.insert(sequences, insertpos, sequence_remove_joiners)
-- end
--
-- local function deva_reorder(head,start,stop,font,attr)
--     local tfmdata = fontdata[font]
--     local lookuphash = tfmdata.resources.lookuphash
--     local sequences = tfmdata.resources.sequences
--
--     if not lookuphash["remove_joiners"] then install_dev(tfmdata) end    --install Devanagari-features
--
--     local sharedfeatures = tfmdata.shared.features
--     sharedfeatures["remove_joiners"] = true
--     local datasets = otf.dataset(tfmdata,font,attr)
--
--     lookuphash["remove_joiners"] = { [0x200C] = true, [0x200D] = true }
--
--     local current, n, base, firstcons, lastcons, basefound = start, start.next, nil, nil, nil, false
--     local reph, vattu = false, false
--     for s=1,#sequences do
--         local dataset = datasets[s]
--         featurevalue = dataset and dataset[1]
--         if featurevalue and dataset[4] == "rphf" then reph = true end
--         if featurevalue and dataset[4] == "blwf" then vattu = true end
--     end
--     if ra[start.char] and halant[n.char] and reph then    -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph from candidates for base consonants
--         if n == stop then return head, stop end
--         if zwj[n.next.char] then
--             current = start
--         else
--             current = n.next
--             set_attribute(start,state,5) -- rphf
--         end
--     end
--
--     if nbsp[current.char] then    --Stand Alone cluster
--         if current == stop then
--             stop = stop.prev
--             head = node.remove(head, current)
--             node.free(current)
--             return head, stop
--         else
--             base, firstcons, lastcons = current, current, current
--             current = current.next
--             if current ~= stop then
--                 if nukta[current.char] then current = current.next end
--                 if zwj[current.char] then
--                     if current ~= stop and current.next ~= stop and halant[current.next.char] then
--                         current = current.next
--                         local tmp = current.next.next
--                         local changestop = current.next == stop
--                         local tempcurrent = node.copy(current.next)
--                         tempcurrent.next = node.copy(current)
--                         tempcurrent.next.prev = tempcurrent
--                         set_attribute(tempcurrent,state,8)    --blwf
--                         tempcurrent = nodes.handlers.characters(tempcurrent)
--                         unset_attribute(tempcurrent,state)
--                         if current.next.char == tempcurrent.char then
--                             node.flush_list(tempcurrent)
--                             local n = node.copy(current)
--                             current.char = dotted_circle
--                             head = node.insert_after(head, current, n)
--                         else
--                             current.char = tempcurrent.char    -- (assumes that result of blwf consists of one node)
--                             local freenode = current.next
--                             current.next = tmp
--                             tmp.prev = current
--                             node.free(freenode)
--                             node.flush_list(tempcurrent)
--                             if changestop then stop = current end
--                         end
--                     end
--                 end
--             end
--         end
--     end
--
--     while not basefound do    -- find base consonant
--         if consonant[current.char] then
--             set_attribute(current, state, 6)    --    half
--             if not firstcons then firstcons = current end
--             lastcons = current
--             if not base then
--                 base = current
--             else    --check whether consonant has below-base (or post-base) form
--                 local baseform = true
--                 for s=1,#sequences do
--                     local sequence = sequences[s]
--                     local dataset = datasets[s]
--                     featurevalue = dataset and dataset[1]
--                     if featurevalue and dataset[4] == "blwf" then
--                         local subtables = sequence.subtables
--                         for i=1,#subtables do
--                             local lookupname = subtables[i]
--                             local lookupcache = lookuphash[lookupname]
--                             if lookupcache then
--                                 local lookupmatch = lookupcache[current.char]
--                                 if lookupmatch then
--                                     set_attribute(current, state, 8)    --    blwf
--                                     baseform = false
--                                 end
--                             end
--                         end
--                     end
--                 end
--                 if baseform then base = current end
--             end
--         end
--         basefound = current == stop
--         current = current.next
--     end
--     if base ~= lastcons then    -- if base consonant is not last one then move halant from base consonant to last one
--         n = base.next
--         if nukta[n.char] then n = n.next end
--         if halant[n.char] then
--             if lastcons ~= stop then
--                 local ln = lastcons.next
--                 if nukta[ln.char] then lastcons = ln end
--             end
--             local np, nn, ln = n.prev, n.next, lastcons.next
--             np.next = n.next
--             nn.prev = n.prev
--             lastcons.next = n
--             if ln then ln.prev = n end
--             n.next = ln
--             n.prev = lastcons
--             if lastcons == stop then stop = n end
--         end
--     end
--
--     n = start.next
--     if ra[start.char] and halant[n.char] and not ( n ~= stop and ( zwj[n.next.char] or zwnj[n.next.char] ) ) then    -- if syllable starts with Ra + H then move this combination so that it follows either: the post-base 'matra' (if any) or the base consonant
--         local matra = base
--         if base ~= stop and dependent_vowel[base.next.char] then matra = base.next end
--         local sp, nn, mn = start.prev, n.next, matra.next
--         if sp then sp.next = nn end
--         nn.prev = sp
--         matra.next = start
--         start.prev = matra
--         n.next = mn
--         if mn then mn.prev = n end
--         if head == start then head = nn end
--         start = nn
--         if matra == stop then stop = n end
--     end
--
--     local current = start
--     while current ~= stop do
--         if halant[current.next.char] and current.next ~= stop and zwnj[current.next.next.char] then unset_attribute(current, state) end
--         current = current.next
--     end
--
--     if has_attribute(base, state) and base ~= stop and halant[base.next.char] and not ( base.next ~= stop and zwj[base.next.next.char] ) then unset_attribute(base, state) end
--
--     local current, allreordered, moved = start, false, { [base] = true }
--     local a, b, p, bn = base, base, base, base.next
--     if base ~= stop and nukta[bn.char] then a, b, p = bn, bn, bn end
--     while not allreordered do
--         local c, n, l = current, current.next, nil    --current is always consonant
--         if c ~= stop and nukta[n.char] then c = n n = n.next end
--         if c ~= stop and halant[n.char] then c = n n = n.next end
--         while c ~= stop and dependent_vowel[n.char] do c = n n = n.next end
--         if c ~= stop and vowel_modifier[n.char] then c = n n = n.next end
--         if c ~= stop and stress_tone_mark[n.char] then c = n n = n.next end
--         local bp, cn = firstcons.prev, current.next
--         while cn ~= c.next do    -- move pre-base matras...
--             if pre_mark[cn.char] then
--                 if bp then bp.next = cn end
--                 cn.prev.next = cn.next
--                 if cn.next then cn.next.prev = cn.prev end
--                 if cn == stop then stop = cn.prev end
--                 cn.prev = bp
--                 cn.next = firstcons
--                 firstcons.prev = cn
--                 if firstcons == start then
--                     if head == start then head = cn end
--                     start = cn
--                 end
--                 break
--             end
--             cn = cn.next
--         end
--         allreordered = c == stop
--         current = c.next
--     end
--
--     if reph or vattu then
--         local current, cns = start, nil
--         while current ~= stop do
--             local c, n = current, current.next
--             if ra[current.char] and halant[n.char] then
--                 c, n = n, n.next
--                 local b, bn = base, base
--                 while bn ~= stop  do
--                     if dependent_vowel[bn.next.char] then b = bn.next end
--                     bn = bn.next
--                 end
--                 if has_attribute(current,state,attribute) == 5 then    -- position Reph (Ra + H) after post-base 'matra' (if any) since these become marks on the 'matra', not on the base glyph
--                     if b ~= current then
--                         if current == start then
--                             if head == start then head = n end
--                             start = n
--                         end
--                         if b == stop then stop = c end
--                         if current.prev then current.prev.next = n end
--                         if n then n.prev = current.prev end
--                         c.next = b.next
--                         if b.next then b.next.prev = c end
--                         b.next = current
--                         current.prev = b
--                     end
--                 elseif cns and cns.next ~= current then    -- position below-base Ra (vattu) following the consonants on which it is placed (either the base consonant or one of the pre-base consonants)
--                     local cp, cnsn = current.prev, cns.next
--                     if cp then cp.next = n end
--                     if n then n.prev = cp end
--                     cns.next = current
--                     current.prev = cns
--                     c.next = cnsn
--                     if cnsn then cnsn.prev = c end
--                     if c == stop then stop = cp break end
--                     current = n.prev
--                 end
--             elseif consonant[current.char] or nbsp[current.char] then
--                 cns = current
--                 if halant[cns.next.char] then cns = cns.next end
--             end
--             current = current.next
--         end
--     end
--
--     if nbsp[base.char] then
--         head = node.remove(head, base)
--         node.free(base)
--     end
--
--     return head, stop
-- end
--
-- function dev2_reorder_matras(start,kind,lookupname,replacement)
--     local current = start
--     while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do
--         if halant[current.char] and not has_attribute(current, state) then
--             if current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == start.font and has_attribute(current.next, sylnr) == has_attribute(start, sylnr) and ( zwj[current.next.char] or zwnj[current.next.char] ) then current = current.next end
--             local sn = start.next
--             start.next.prev = start.prev
--             if start.prev then start.prev.next = start.next end
--             if current.next then current.next.prev = start end
--             start.next = current.next
--             current.next = start
--             start.prev = current
--             start = sn
--             break
--         end
--         current = current.next
--     end
--     return start, true
-- end
--
-- function dev2_reorder_reph(start,kind,lookupname,replacement)
--     local current, sn = start.next, nil
--     while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do    --step 2
--         if halant[current.char] and not has_attribute(current, state) then
--             if current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == start.font and has_attribute(current.next, sylnr) == has_attribute(start, sylnr) and ( zwj[current.next.char] or zwnj[current.next.char] ) then current = current.next end
--             sn = start.next
--             start.next.prev = start.prev
--             if start.prev then start.prev.next = start.next end
--             if current.next then current.next.prev = start end
--             start.next = current.next
--             current.next = start
--             start.prev = current
--             start = sn
--             break
--         end
--         current = current.next
--     end
--     if not sn then
--         current = start.next
--         while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do    --step 4
--             if has_attribute(current, state) == 9 then    --post-base
--                 sn = start.next
--                 start.next.prev = start.prev
--                 if start.prev then start.prev.next = start.next end
--                 start.prev = current.prev
--                 current.prev.next = start
--                 start.next = current
--                 current.prev = start
--                 start = sn
--                 break
--             end
--             current = current.next
--         end
--     end
--     if not sn then
--         current = start.next
--         local c = nil
--         while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do    --step 5
--             if not c and ( above_mark[current.char] or below_mark[current.char] or post_mark[current.char] ) and ReorderClass[current.char] ~= "after subscript" then c = current end
--             current = current.next
--         end
--         if c then
--             sn = start.next
--             start.next.prev = start.prev
--             if start.prev then start.prev.next = start.next end
--             start.prev = c.prev
--             c.prev.next = start
--             start.next = c
--             c.prev = start
--             start = sn
--         end
--     end
--     if not sn then
--         current = start
--         while current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == start.font and has_attribute(current.next, sylnr) == has_attribute(start, sylnr) do    --step 6
--             current = current.next
--         end
--         if start ~= current then
--             sn = start.next
--             start.next.prev = start.prev
--             if start.prev then start.prev.next = start.next end
--             if current.next then current.next.prev = start end
--             start.next = current.next
--             current.next = start
--             start.prev = current
--             start = sn
--         end
--     end
--     return start, true
-- end
--
-- function dev2_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
--     local current, sn = start, nil
--     while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do
--         if halant[current.char] and not has_attribute(current, state) then
--             if current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == start.font and has_attribute(current.next, sylnr) == has_attribute(start, sylnr) and ( zwj[current.next.char] or zwnj[current.next.char] ) then current = current.next end
--             sn = start.next
--             start.next.prev = start.prev
--             if start.prev then start.prev.next = start.next end
--             if current.next then current.next.prev = start end
--             start.next = current.next
--             current.next = start
--             start.prev = current
--             start = sn
--             break
--         end
--         current = current.next
--     end
--     if not sn then
--         current = start.next
--         while current and current.id == glyph and current.subtype<256 and current.font == start.font and has_attribute(current, sylnr) == has_attribute(start, sylnr) do
--             if not consonant[current.char] and has_attribute(current, state) then    --main
--                 sn = start.next
--                 start.next.prev = start.prev
--                 if start.prev then start.prev.next = start.next end
--                 start.prev = current.prev
--                 current.prev.next = start
--                 start.next = current
--                 current.prev = start
--                 start = sn
--                 break
--             end
--             current = current.next
--         end
--     end
--     return start, true
-- end
--
-- function remove_joiners(start,kind,lookupname,replacement)
--     local stop = start.next
--     while stop and stop.id == glyph and stop.subtype<256 and stop.font == start.font and (zwj[stop.char] or zwnj[stop.char]) do stop = stop.next end
--     if stop then stop.prev.next = nil stop.prev = start.prev end
--     if start.prev then start.prev.next = stop end
--     node.flush_list(start)
--     return stop, true
-- end
--
-- local function dev2_reorder(head,start,stop,font,attr)
--     local tfmdata = fontdata[font]
--     local lookuphash = tfmdata.resources.lookuphash
--     local sequences = tfmdata.resources.sequences
--
--     if not lookuphash["remove_joiners"] then install_dev(tfmdata) end    --install Devanagari-features
--
--     local sharedfeatures = tfmdata.shared.features
--     sharedfeatures["dev2_reorder_matras"] = true
--     sharedfeatures["dev2_reorder_reph"] = true
--     sharedfeatures["dev2_reorder_pre_base_reordering_consonants"] = true
--     sharedfeatures["remove_joiners"] = true
--     local datasets = otf.dataset(tfmdata,font,attr)
--
--     local reph, pre_base_reordering_consonants = false, nil
--     local halfpos, basepos, subpos, postpos = nil, nil, nil, nil
--     local locl = { }
--
--     for s=1,#sequences do    -- classify chars
--         local sequence = sequences[s]
--         local dataset = datasets[s]
--         featurevalue = dataset and dataset[1]
--         if featurevalue and dataset[4] then
--             local subtables = sequence.subtables
--             for i=1,#subtables do
--                 local lookupname = subtables[i]
--                 local lookupcache = lookuphash[lookupname]
--                 if lookupcache then
--                     if dataset[4] == "rphf" then
--                         if dataset[3] ~= 0 then --rphf is result of of chain
--                         else
--                             reph = lookupcache[0x0930] and lookupcache[0x0930][0x094D] and lookupcache[0x0930][0x094D]["ligature"]
--                         end
--                     end
--                     if dataset[4] == "pref" and not pre_base_reordering_consonants then
--                         for k, v in pairs(lookupcache[0x094D]) do
--                             pre_base_reordering_consonants[k] = v and v["ligature"]    --ToDo: reph might also be result of chain
--                         end
--                     end
--                     local current = start
--                     while current ~= stop.next do
--                         if dataset[4] == "locl" then locl[current] = lookupcache[current.char] end    --ToDo: locl might also be result of chain
--                         if current ~= stop then
--                             local c, n = locl[current] or current.char, locl[current.next] or current.next.char
--                             if dataset[4] == "rphf" and lookupcache[c] and lookupcache[c][n] then    --above-base: rphf    Consonant + Halant
--                             if current.next ~= stop and ( zwj[current.next.next.char] or zwnj[current.next.next.char] ) then    --ZWJ and ZWNJ prevent creation of reph
--                                 current = current.next
--                             elseif current == start then
--                                 set_attribute(current,state,5)
--                                 end
--                                 current = current.next
--                             end
--                             if dataset[4] == "half" and lookupcache[c] and lookupcache[c][n] then    --half forms: half    Consonant + Halant
--                                 if current.next ~= stop and zwnj[current.next.next.char] then    --ZWNJ prevent creation of half
--                                     current = current.next
--                                 else
--                                     set_attribute(current,state,6)
--                                     if not halfpos then halfpos = current end
--                                 end
--                                 current = current.next
--                             end
--                             if dataset[4] == "pref" and lookupcache[c] and lookupcache[c][n] then    --pre-base: pref    Halant + Consonant
--                                 set_attribute(current,state,7)
--                                 set_attribute(current.next,state,7)
--                                 current = current.next
--                             end
--                             if dataset[4] == "blwf" and lookupcache[c] and lookupcache[c][n] then    --below-base: blwf    Halant + Consonant
--                                 set_attribute(current,state,8)
--                                 set_attribute(current.next,state,8)
--                                 current = current.next
--                                 subpos = current
--                             end
--                             if dataset[4] == "pstf" and lookupcache[c] and lookupcache[c][n] then    --post-base: pstf    Halant + Consonant
--                                 set_attribute(current,state,9)
--                                 set_attribute(current.next,state,9)
--                                 current = current.next
--                                 postpos = current
--                             end
--                         end
--                         current = current.next
--                     end
--                 end
--             end
--         end
--     end
--
--     lookuphash["dev2_reorder_matras"] = pre_mark
--     lookuphash["dev2_reorder_reph"] = { [reph] = true }
--     lookuphash["dev2_reorder_pre_base_reordering_consonants"] = pre_base_reordering_consonants or { }
--     lookuphash["remove_joiners"] = { [0x200C] = true, [0x200D] = true }
--
--     local current, base, firstcons = start, nil, nil
--     if has_attribute(start,state) == 5 then current = start.next.next end    -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph from candidates for base consonants
--
--     if current ~= stop.next and nbsp[current.char] then    --Stand Alone cluster
--         if current == stop then
--             stop = stop.prev
--             head = node.remove(head, current)
--             node.free(current)
--             return head, stop
--         else
--             base = current
--             current = current.next
--             if current ~= stop then
--                 if nukta[current.char] then current = current.next end
--                 if zwj[current.char] then
--                     if current ~= stop and current.next ~= stop and halant[current.next.char] then
--                         current = current.next
--                         local tmp = current.next.next
--                         local changestop = current.next == stop
--                         current.next.next = nil
--                         set_attribute(current,state,7)    --pref
--                         current = nodes.handlers.characters(current)
--                         set_attribute(current,state,8)    --blwf
--                         current = nodes.handlers.characters(current)
--                         set_attribute(current,state,9)    --pstf
--                         current = nodes.handlers.characters(current)
--                         unset_attribute(current,state)
--                         if halant[current.char] then
--                             current.next.next = tmp
--                             local nc = node.copy(current)
--                             current.char = dotted_circle
--                             head = node.insert_after(head, current, nc)
--                         else
--                             current.next = tmp    -- (assumes that result of pref, blwf, or pstf consists of one node)
--                             if changestop then stop = current end
--                         end
--                     end
--                 end
--             end
--         end
--     else    --not Stand Alone cluster
--         while current ~= stop.next do    -- find base consonant
--             if consonant[current.char] and not ( current ~= stop and halant[current.next.char] and current.next ~= stop and zwj[current.next.next.char] ) then
--                 if not firstcons then firstcons = current end
--                 if not ( has_attribute(current, state) == 7 or has_attribute(current, state) == 8 or has_attribute(current, state) == 9 ) then base = current end    --check whether consonant has below-base or post-base form or is pre-base reordering Ra
--             end
--             current = current.next
--         end
--         if not base then
--             base = firstcons
--         end
--     end
--
--     if not base then
--         if has_attribute(start, state) == 5 then unset_attribute(start, state) end
--         return head, stop
--     else
--         if has_attribute(base, state) then unset_attribute(base, state) end
--         basepos = base
--     end
--     if not halfpos then halfpos = base end
--     if not subpos then subpos = base end
--     if not postpos then postpos = subpos or base end
--
--     --Matra characters are classified and reordered by which consonant in a conjunct they have affinity for
--     local moved = { }
--     current = start
--     while current ~= stop.next do
--         local char, target, cn = locl[current] or current.char, nil, current.next
--         if not moved[current] and dependent_vowel[char] then
--             if pre_mark[char] then            -- Before first half form in the syllable
--                 moved[current] = true
--                 if current.prev then current.prev.next = current.next end
--                 if current.next then current.next.prev = current.prev end
--                 if current == stop then stop = current.prev end
--                 if halfpos == start then
--                     if head == start then head = current end
--                     start = current
--                 end
--                 if halfpos.prev then halfpos.prev.next = current end
--                 current.prev = halfpos.prev
--                 halfpos.prev = current
--                 current.next = halfpos
--                 halfpos = current
--             elseif above_mark[char] then    -- After main consonant
--                 target = basepos
--                 if subpos == basepos then subpos = current end
--                 if postpos == basepos then postpos = current end
--                 basepos = current
--             elseif below_mark[char] then    -- After subjoined consonants
--                 target = subpos
--                 if postpos == subpos then postpos = current end
--                 subpos = current
--             elseif post_mark[char] then    -- After post-form consonant
--                 target = postpos
--                 postpos = current
--             end
--             if ( above_mark[char] or below_mark[char] or post_mark[char] ) and current.prev ~= target then
--                 if current.prev then current.prev.next = current.next end
--                 if current.next then current.next.prev = current.prev end
--                 if current == stop then stop = current.prev end
--                 if target.next then target.next.prev = current end
--                 current.next = target.next
--                 target.next = current
--                 current.prev = target
--             end
--         end
--         current = cn
--     end
--
--     --Reorder marks to canonical order: Adjacent nukta and halant or nukta and vedic sign are always repositioned if necessary, so that the nukta is first.
--     local current, c = start, nil
--     while current ~= stop do
--         if halant[current.char] or stress_tone_mark[current.char] then
--             if not c then c = current end
--         else
--             c = nil
--         end
--         if c and nukta[current.next.char] then
--             if head == c then head = current.next end
--             if stop == current.next then stop = current end
--             if c.prev then c.prev.next = current.next end
--             current.next.prev = c.prev
--             current.next = current.next.next
--             if current.next.next then current.next.next.prev = current end
--             c.prev = current.next
--             current.next.next = c
--         end
--         if stop == current then break end
--         current = current.next
--     end
--
--     if nbsp[base.char] then
--         head = node.remove(head, base)
--         node.free(base)
--     end
--
--     return head, stop
-- end
--
-- function fonts.analyzers.methods.deva(head,font,attr)
-- local orighead = head
--     local current, start, done = head, true, false
--     while current do
--         if current.id == glyph and current.subtype<256 and current.font == font then
--             done = true
--             local syllablestart, syllableend = current, nil
--
--             local c = current    --Checking Stand Alone cluster (this behavior is copied from dev2)
--             if ra[c.char] and c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] and c.next.next and c.next.next.id == glyph and c.next.next.subtype<256 and c.next.next.font == font then c = c.next.next end
--             if nbsp[c.char] and ( not current.prev or current.prev.id ~= glyph or current.prev.subtype>=256 or current.prev.font ~= font or
--                                         ( not consonant[current.prev.char] and not independent_vowel[current.prev.char] and not dependent_vowel[current.prev.char] and
--                                         not vowel_modifier[current.prev.char] and not stress_tone_mark[current.prev.char] and not nukta[current.prev.char] and not halant[current.prev.char] )
--                                     ) then    --Stand Alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 local n = c.next
--                 if n and n.id == glyph and n.subtype<256 and n.font == font then
--                     local ni = n.next
--                     if ( zwj[n.char] or zwnj[n.char] ) and ni and ni.id == glyph and ni.subtype<256 and ni.font == font then n = ni ni = ni.next end
--                     if halant[n.char] and ni and ni.id == glyph and ni.subtype<256 and ni.font == font and consonant[ni.char] then c = ni end
--                 end
--                 while c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and dependent_vowel[c.next.char] do c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and vowel_modifier[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 current = c.next
--                 syllableend = c
--                 if syllablestart ~= syllableend then
--                     head, current = deva_reorder(head, syllablestart,syllableend,font,attr)
--                     current = current.next
--                 end
--             elseif consonant[current.char] then    -- syllable containing consonant
--                 prevc = true
--                 while prevc do
--                     prevc = false
--                     local n = current.next
--                     if n and n.id == glyph and n.subtype<256 and n.font == font and nukta[n.char] then n = n.next end
--                     if n and n.id == glyph and n.subtype<256 and n.font == font and halant[n.char] then
--                         local n = n.next
--                         if n and n.id == glyph and n.subtype<256 and n.font == font and ( zwj[n.char] or zwnj[n.char] ) then n = n.next end
--                         if n and n.id == glyph and n.subtype<256 and n.font == font and consonant[n.char] then
--                             prevc = true
--                             current = n
--                         end
--                     end
--                 end
--                 if current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == font and nukta[current.next.char] then current = current.next end    -- nukta (not specified in Microsft Devanagari OpenType specification)
--                 syllableend = current
--                 current = current.next
--                 if current and current.id == glyph and current.subtype<256 and current.font == font and halant[current.char] then    -- syllable containing consonant without vowels: {C + [Nukta] + H} + C + H
--                     if current.next and current.next.id == glyph and current.next.subtype<256 and current.next.font == font and ( zwj[current.next.char] or zwnj[current.next.char] ) then current = current.next end
--                     syllableend = current
--                     current = current.next
--                 else    -- syllable containing consonant with vowels: {C + [Nukta] + H} + C + [M] + [VM] + [SM]
--                     if current and current.id == glyph and current.subtype<256 and current.font == font and dependent_vowel[current.char] then
--                         syllableend = current
--                         current = current.next
--                     end
--                     if current and current.id == glyph and current.subtype<256 and current.font == font and vowel_modifier[current.char] then
--                         syllableend = current
--                         current = current.next
--                     end
--                     if current and current.id == glyph and current.subtype<256 and current.font == font and stress_tone_mark[current.char] then
--                         syllableend = current
--                         current = current.next
--                     end
--                 end
--                 if syllablestart ~= syllableend then
--                     head, current = deva_reorder(head,syllablestart,syllableend,font,attr)
--                     current = current.next
--                 end
--             elseif current.id == glyph and current.subtype<256 and current.font == font and independent_vowel[current.char] then -- syllable without consonants: VO + [VM] + [SM]
--                 syllableend = current
--                 current = current.next
--                 if current and current.id == glyph and current.subtype<256 and current.font == font and vowel_modifier[current.char] then
--                     syllableend = current
--                     current = current.next
--                 end
--                 if current and current.id == glyph and current.subtype<256 and current.font == font and stress_tone_mark[current.char] then
--                     syllableend = current
--                     current = current.next
--                 end
--             else    -- Syntax error
--                 if pre_mark[current.char] or above_mark[current.char] or below_mark[current.char] or post_mark[current.char] then
--                     local n = node.copy(current)
--                     if pre_mark[current.char] then
--                         n.char = dotted_circle
--                     else
--                         current.char = dotted_circle
--                     end
--                     head, current = node.insert_after(head, current, n)
--                 end
--                 current = current.next
--             end
--         else
--             current = current.next
--         end
--         start = false
--     end
--
--     return head, done
-- end
--
-- function fonts.analyzers.methods.dev2(head,font,attr)
--     local current, start, done, syl_nr = head, true, false, 0
--     while current do
--         local syllablestart, syllableend = nil, nil
--         if current.id == glyph and current.subtype<256 and current.font == font then
--             syllablestart = current
--             done = true
--             local c, n = current, current.next
--             if ra[current.char] and n and n.id == glyph and n.subtype<256 and n.font == font and halant[n.char] and n.next and n.next.id == glyph and n.next.subtype<256 and n.next.font == font then c = n.next end
--             if independent_vowel[c.char] then --Vowel-based syllable: [Ra+H]+V+[N]+[<[<ZWJ|ZWNJ>]+H+C|ZWJ+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
--                 n = c.next
--                 local ni, nii = nil, nil
--                 if n and n.id == glyph and n.subtype<256 and n.font == font and nukta[n.char] then n = n.next end
--                 if n and n.id == glyph and n.subtype<256 and n.font == font then local ni = n.next end
--                 if ni and ni.id == glyph and ni.subtype<256 and ni.font == font and ni.next and ni.next.id == glyph and ni.next.subtype<256 and ni.next.font == font then
--                     nii = ni.next
--                     if zwj[ni.char] and consonant[nii.char] then
--                         c = nii
--                     elseif (zwj[ni.char] or zwnj[ni.char]) and halant[nii.char] and nii.next and nii.next.id == glyph and nii.next.subtype<256 and nii.next.font == font and consonant[nii.next.char] then
--                         c = nii.next
--                     end
--                 end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and dependent_vowel[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and vowel_modifier[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 current = c
--                 syllableend = c
--             elseif nbsp[c.char] and ( not current.prev or current.prev.id ~= glyph or current.prev.subtype>=256 or current.prev.font ~= font or
--                                         ( not consonant[current.prev.char] and not independent_vowel[current.prev.char] and not dependent_vowel[current.prev.char] and
--                                         not vowel_modifier[current.prev.char] and not stress_tone_mark[current.prev.char] and not nukta[current.prev.char] and not halant[current.prev.char] )
--                                     ) then    --Stand Alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 n = c.next
--                 if n and n.id == glyph and n.subtype<256 and n.font == font then
--                     local ni = n.next
--                     if ( zwj[n.char] or zwnj[n.char] ) and ni and ni.id == glyph and ni.subtype<256 and ni.font == font then n = ni ni = ni.next end
--                     if halant[n.char] and ni and ni.id == glyph and ni.subtype<256 and ni.font == font and consonant[ni.char] then c = ni end
--                 end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and dependent_vowel[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and vowel_modifier[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 current = c
--                 syllableend = c
--             elseif consonant[current.char] then    --Consonant syllable: {C+[N]+<H+[<ZWNJ|ZWJ>]|<ZWNJ|ZWJ>+H>} + C+[N]+[A] + [< H+[<ZWNJ|ZWJ>] | {M}+[N]+[H]>]+[SM]+[(VD)]
--                 c = current
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                 n = c
--                 while n.next and n.next.id == glyph and n.next.subtype<256 and n.next.font == font and ( halant[n.next.char] or zwnj[n.next.char] or zwj[n.next.char] ) do
--                     if halant[n.next.char] then
--                         n = n.next
--                         if n.next and n.next.id == glyph and n.next.subtype<256 and n.next.font == font and ( zwnj[n.next.char] or zwj[n.next.char] ) then n = n.next end
--                     else
--                         if n.next.next and n.next.next.id == glyph and n.next.next.subtype<256 and n.next.next.font == font and halant[n.next.next.char] then n = n.next.next end
--                     end
--                     if n.next and n.next.id == glyph and n.next.subtype<256 and n.next.font == font and consonant[n.next.char] then
--                         n = n.next
--                         if n.next and n.next.id == glyph and n.next.subtype<256 and n.next.font == font and nukta[n.next.char] then n = n.next end
--                         c = n
--                     else
--                         break
--                     end
--                 end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and anudatta[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] then
--                     c = c.next
--                     if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and ( zwnj[c.next.char] or zwj[c.next.char] ) then c = c.next end
--                 else
--                     if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and dependent_vowel[c.next.char] then c = c.next end
--                     if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and nukta[c.next.char] then c = c.next end
--                     if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and halant[c.next.char] then c = c.next end
--                 end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and vowel_modifier[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 if c.next and c.next.id == glyph and c.next.subtype<256 and c.next.font == font and stress_tone_mark[c.next.char] then c = c.next end
--                 current = c
--                 syllableend = c
--             end
--         end
--
--         if syllableend then
--             syl_nr = syl_nr + 1
--             c = syllablestart
--             while c ~= syllableend.next do
--                 set_attribute(c,sylnr,syl_nr)
--                 c = c.next
--             end
--         end
--         if syllableend and syllablestart ~= syllableend then
--             head, current = dev2_reorder(head,syllablestart,syllableend,font,attr)
--         end
--
--         if not syllableend and not has_attribute(current, state) and current.id == glyph and current.subtype<256 and current.font == font then    -- Syntax error
--             if pre_mark[current.char] or above_mark[current.char] or below_mark[current.char] or post_mark[current.char] then
--                 local n = node.copy(current)
--                 if pre_mark[current.char] then
--                     n.char = dotted_circle
--                 else
--                     current.char = dotted_circle
--                 end
--                 head, current = node.insert_after(head, current, n)
--             end
--         end
--
--         start = false
--         current = current.next
--     end
--
--     return head, done
-- end
--
-- function otf.handlers.dev2_reorder_matras(start,kind,lookupname,replacement)
--     return dev2_reorder_matras(start,kind,lookupname,replacement)
-- end
--
-- function otf.handlers.dev2_reorder_reph(start,kind,lookupname,replacement)
--     return dev2_reorder_reph(start,kind,lookupname,replacement)
-- end
--
-- function otf.handlers.dev2_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
--     return dev2_reorder_pre_base_reordering_consonants(start,kind,lookupname,replacement)
-- end
--
-- function otf.handlers.remove_joiners(start,kind,lookupname,replacement)
--     return remove_joiners(start,kind,lookupname,replacement)
-- end
