if not modules then modules = { } end modules ['font-odv'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Kai Eigner, TAT Zetwerk / Hans Hagen, PRAGMA ADE",
    copyright = "TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- One day I'll speed this up ... char swapping and properties.

-- A few remarks:
--
-- This code is a partial rewrite of the code that deals with devanagari. The data and logic
-- is by Kai Eigner and based based on Microsoft's OpenType specifications for specific
-- scripts, but with a few improvements. More information can be found at:
--
-- deva: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/introO.mspx
-- dev2: http://www.microsoft.com/typography/OpenType%20Dev/devanagari/intro.mspx
--
-- Rajeesh Nambiar provided patches for the malayalam variant. Thansk to feedback from
-- the mailing list some aspects could be improved.
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
-- Some data will move to char-def.lua (some day).
--
-- Hans Hagen, PRAGMA-ADE, Hasselt NL
--
-- We could have c_nukta, c_halant, c_ra is we know that they are never used mixed within
-- one script .. yes or no?
--
-- Matras: according to Microsoft typography specifications "up to one of each type:
-- pre-, above-, below- or post- base", but that does not seem to be right. It could
-- become an option.
--
-- The next code looks weird anyway: the "and boolean" should move inside the if
-- or we should check differently (case vs successive).
--
-- local function ms_matra(c)
--     local prebase, abovebase, belowbase, postbase = true, true, true, true
--     local n = getnext(c)
--     while n and getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font do
--         local char = getchar(n)
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
--         c = getnext(c)
--     end
--     return c
-- end

-- todo: first test for font then for subtype

local insert, imerge = table.insert, table.imerge
local next = next

local report_devanagari  = logs.reporter("otf","devanagari")

fonts                    = fonts                   or { }
fonts.analyzers          = fonts.analyzers         or { }
fonts.analyzers.methods  = fonts.analyzers.methods or { node = { otf = { } } }

local otf                = fonts.handlers.otf

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local handlers           = otf.handlers
local methods            = fonts.analyzers.methods

local otffeatures        = fonts.constructors.features.otf
local registerotffeature = otffeatures.register

local nuts               = nodes.nuts
local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getnext            = nuts.getnext
local setnext            = nuts.setnext
local getprev            = nuts.getprev
local setprev            = nuts.setprev
local getid              = nuts.getid
local getchar            = nuts.getchar
local setchar            = nuts.setchar
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getprop            = nuts.getprop
local setprop            = nuts.setprop

local insert_node_after  = nuts.insert_after
local copy_node          = nuts.copy
local remove_node        = nuts.remove
local flush_list         = nuts.flush_list
local flush_node         = nuts.flush_node

local copyinjection      = nodes.injections.copy -- KE: is this necessary? HH: probably not as positioning comes later and we rawget/set

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

local replace_all_nbsp   = nil

replace_all_nbsp = function(head) -- delayed definition
    replace_all_nbsp = typesetters and typesetters.characters and typesetters.characters.replacenbspaces or function(head)
        return head
    end
    return replace_all_nbsp(head)
end

local xprocesscharacters = nil

if context then
    xprocesscharacters = function(head,font)
        xprocesscharacters = nodes.handlers.characters
        return xprocesscharacters(head,font)
    end
else
    xprocesscharacters = function(head,font)
        xprocesscharacters = nodes.handlers.nodepass -- generic
        return xprocesscharacters(head,font)
    end
end

local function processcharacters(head,font)
    return tonut(xprocesscharacters(tonode(head)))
end

-- local fontprocesses = fonts.hashes.processes
--
-- function processcharacters(head,font)
--     local processors = fontprocesses[font]
--     for i=1,#processors do
--         head = processors[i](head,font,0)
--     end
--     return head, true
-- end

-- In due time there will be entries here for scripts like Bengali, Gujarati,
-- Gurmukhi, Kannada, Malayalam, Oriya, Tamil, Telugu. Feel free to provide the
-- code points.

-- We can assume that script are not mixed in the source but if that is the case
-- we might need to have consonants etc per script and initialize a local table
-- pointing to the right one.

-- new, to be checked:
--
-- U+00978 : DEVANAGARI LETTER MARWARI DDA
-- U+00980 : BENGALI ANJI
-- U+00C00 : TELUGU SIGN COMBINING CANDRABINDU ABOVE
-- U+00C34 : TELUGU LETTER LLLA
-- U+00C81 : KANNADA SIGN CANDRABINDU
-- U+00D01 : MALAYALAM SIGN CANDRABINDU
-- U+00DE6 : SINHALA LITH DIGIT ZERO
-- U+00DE7 : SINHALA LITH DIGIT ONE
-- U+00DE8 : SINHALA LITH DIGIT TWO
-- U+00DE9 : SINHALA LITH DIGIT THREE
-- U+00DEA : SINHALA LITH DIGIT FOUR
-- U+00DEB : SINHALA LITH DIGIT FIVE
-- U+00DEC : SINHALA LITH DIGIT SIX
-- U+00DED : SINHALA LITH DIGIT SEVEN
-- U+00DEE : SINHALA LITH DIGIT EIGHT
-- U+00DEF : SINHALA LITH DIGIT NINE

local consonant = {
    -- devanagari
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
    -- kannada
    [0x0C95] = true, [0x0C96] = true, [0x0C97] = true, [0x0C98] = true,
    [0x0C99] = true, [0x0C9A] = true, [0x0C9B] = true, [0x0C9C] = true,
    [0x0C9D] = true, [0x0C9E] = true, [0x0C9F] = true, [0x0CA0] = true,
    [0x0CA1] = true, [0x0CA2] = true, [0x0CA3] = true, [0x0CA4] = true,
    [0x0CA5] = true, [0x0CA6] = true, [0x0CA7] = true, [0x0CA8] = true,
    [0x0CA9] = true, [0x0CAA] = true, [0x0CAB] = true, [0x0CAC] = true,
    [0x0CAD] = true, [0x0CAE] = true, [0x0CAF] = true, [0x0CB0] = true,
    [0x0CB1] = true, [0x0CB2] = true, [0x0CB3] = true, [0x0CB4] = true,
    [0x0CB5] = true, [0x0CB6] = true, [0x0CB7] = true, [0x0CB8] = true,
    [0x0CB9] = true,
    [0x0CDE] = true, -- obsolete
    -- malayalam
    [0x0D15] = true, [0x0D16] = true, [0x0D17] = true, [0x0D18] = true,
    [0x0D19] = true, [0x0D1A] = true, [0x0D1B] = true, [0x0D1C] = true,
    [0x0D1D] = true, [0x0D1E] = true, [0x0D1F] = true, [0x0D20] = true,
    [0x0D21] = true, [0x0D22] = true, [0x0D23] = true, [0x0D24] = true,
    [0x0D25] = true, [0x0D26] = true, [0x0D27] = true, [0x0D28] = true,
    [0x0D29] = true, [0x0D2A] = true, [0x0D2B] = true, [0x0D2C] = true,
    [0x0D2D] = true, [0x0D2E] = true, [0x0D2F] = true, [0x0D30] = true,
    [0x0D31] = true, [0x0D32] = true, [0x0D33] = true, [0x0D34] = true,
    [0x0D35] = true, [0x0D36] = true, [0x0D37] = true, [0x0D38] = true,
    [0x0D39] = true, [0x0D3A] = true,
}

local independent_vowel = {
    -- devanagari
    [0x0904] = true, [0x0905] = true, [0x0906] = true, [0x0907] = true,
    [0x0908] = true, [0x0909] = true, [0x090A] = true, [0x090B] = true,
    [0x090C] = true, [0x090D] = true, [0x090E] = true, [0x090F] = true,
    [0x0910] = true, [0x0911] = true, [0x0912] = true, [0x0913] = true,
    [0x0914] = true, [0x0960] = true, [0x0961] = true, [0x0972] = true,
    [0x0973] = true, [0x0974] = true, [0x0975] = true, [0x0976] = true,
    [0x0977] = true,
    -- kannada
    [0x0C85] = true, [0x0C86] = true, [0x0C87] = true, [0x0C88] = true,
    [0x0C89] = true, [0x0C8A] = true, [0x0C8B] = true, [0x0C8C] = true,
    [0x0C8D] = true, [0x0C8E] = true, [0x0C8F] = true, [0x0C90] = true,
    [0x0C91] = true, [0x0C92] = true, [0x0C93] = true, [0x0C94] = true,
    -- malayalam
    [0x0D05] = true, [0x0D06] = true, [0x0D07] = true, [0x0D08] = true,
    [0x0D09] = true, [0x0D0A] = true, [0x0D0B] = true, [0x0D0C] = true,
    [0x0D0E] = true, [0x0D0F] = true, [0x0D10] = true, [0x0D12] = true,
    [0x0D13] = true, [0x0D14] = true,
}

local dependent_vowel = { -- matra
    -- devanagari
    [0x093A] = true, [0x093B] = true, [0x093E] = true, [0x093F] = true,
    [0x0940] = true, [0x0941] = true, [0x0942] = true, [0x0943] = true,
    [0x0944] = true, [0x0945] = true, [0x0946] = true, [0x0947] = true,
    [0x0948] = true, [0x0949] = true, [0x094A] = true, [0x094B] = true,
    [0x094C] = true, [0x094E] = true, [0x094F] = true, [0x0955] = true,
    [0x0956] = true, [0x0957] = true, [0x0962] = true, [0x0963] = true,
    -- kannada
    [0x0CBE] = true, [0x0CBF] = true, [0x0CC0] = true, [0x0CC1] = true,
    [0x0CC2] = true, [0x0CC3] = true, [0x0CC4] = true, [0x0CC5] = true,
    [0x0CC6] = true, [0x0CC7] = true, [0x0CC8] = true, [0x0CC9] = true,
    [0x0CCA] = true, [0x0CCB] = true, [0x0CCC] = true,
    -- malayalam
    [0x0D3E] = true, [0x0D3F] = true, [0x0D40] = true, [0x0D41] = true,
    [0x0D42] = true, [0x0D43] = true, [0x0D44] = true, [0x0D46] = true,
    [0x0D47] = true, [0x0D48] = true, [0x0D4A] = true, [0x0D4B] = true,
    [0x0D4C] = true, [0x0D57] = true,
}

local vowel_modifier = {
    -- devanagari
    [0x0900] = true, [0x0901] = true, [0x0902] = true, [0x0903] = true,
    -- A8E0 - A8F1 are cantillation marks for the Samaveda and may not belong here.
    [0xA8E0] = true, [0xA8E1] = true, [0xA8E2] = true, [0xA8E3] = true,
    [0xA8E4] = true, [0xA8E5] = true, [0xA8E6] = true, [0xA8E7] = true,
    [0xA8E8] = true, [0xA8E9] = true, [0xA8EA] = true, [0xA8EB] = true,
    [0xA8EC] = true, [0xA8ED] = true, [0xA8EE] = true, [0xA8EF] = true,
    [0xA8F0] = true, [0xA8F1] = true,
    -- malayalam
    [0x0D02] = true, [0x0D03] = true,
}

local stress_tone_mark = {
    [0x0951] = true, [0x0952] = true, [0x0953] = true, [0x0954] = true,
    -- kannada
    [0x0CCD] = true,
    -- malayalam
    [0x0D4D] = true,
}

local nukta = {
    -- devanagari
    [0x093C] = true,
    -- kannada:
    [0x0CBC] = true,
}

local halant = {
    -- devanagari
    [0x094D] = true,
    -- kannada
    [0x0CCD] = true,
    -- malayalam
    [0x0D4D] = true,
}

local ra = {
    -- devanagari
    [0x0930] = true,
    -- kannada
    [0x0CB0] = true,
    -- malayalam
    [0x0D30] = true,
}

local c_anudatta = 0x0952 -- used to be tables
local c_nbsp     = 0x00A0 -- used to be tables
local c_zwnj     = 0x200C -- used to be tables
local c_zwj      = 0x200D -- used to be tables

local zw_char = { -- could also be inlined
    [0x200C] = true,
    [0x200D] = true,
}

-- 0C82 anusvara
-- 0C83 visarga
-- 0CBD avagraha
-- 0CD5 length mark
-- 0CD6 ai length mark
-- 0CE0 letter ll
-- 0CE1 letter rr
-- 0CE2 vowel sign l
-- 0CE2 vowel sign ll
-- 0CF1 sign
-- 0CF2 sign
-- OCE6 - OCEF digits

local pre_mark = {
    [0x093F] = true, [0x094E] = true,
    -- malayalam
    [0x0D46] = true, [0x0D47] = true, [0x0D48] = true,
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
    -- malayalam
    [0x0D4E] = true,
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

local twopart_mark = {
    -- malayalam
    [0x0D4A] = { 0x0D46, 0x0D3E, },	-- ൊ
    [0x0D4B] = { 0x0D47, 0x0D3E, },	-- ോ
    [0x0D4C] = { 0x0D46, 0x0D57, },	-- ൌ
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
-- for ConTeXt this kind of data is kept elsewhere so eventually we might move
-- tables to someplace else.

local reorder_class = {
    -- devanagari
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
    -- kannada:
    [0x0CB0] = "after postscript", -- todo in code below
    [0x0CBF] = "before subscript", -- todo in code below
    [0x0CC6] = "before subscript", -- todo in code below
    [0x0CCC] = "before subscript", -- todo in code below
    [0x0CBE] = "before subscript", -- todo in code below
    [0x0CE2] = "before subscript", -- todo in code below
    [0x0CE3] = "before subscript", -- todo in code below
    [0x0CC1] = "before subscript", -- todo in code below
    [0x0CC2] = "before subscript", -- todo in code below
    [0x0CC3] = "after subscript",
    [0x0CC4] = "after subscript",
    [0x0CD5] = "after subscript",
    [0x0CD6] = "after subscript",
    -- malayalam
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
    order     = { "dv01" },
    subtables = { "dv01_reorder_matras" },
    type      = "devanagari_reorder_matras",
}

local sequence_reorder_reph = {
    chain     = 0,
    features  = { dv02 = dev2_defaults },
    flags     = false_flags,
    name      = "dv02_reorder_reph",
    order     = { "dv02" },
    subtables = { "dv02_reorder_reph" },
    type      = "devanagari_reorder_reph",
}

local sequence_reorder_pre_base_reordering_consonants = {
    chain     = 0,
    features  = { dv03 = dev2_defaults },
    flags     = false_flags,
    name      = "dv03_reorder_pre_base_reordering_consonants",
    order     = { "dv03" },
    subtables = { "dv03_reorder_pre_base_reordering_consonants" },
    type      = "devanagari_reorder_pre_base_reordering_consonants",
}

local sequence_remove_joiners = {
    chain     = 0,
    features  = { dv04 = deva_defaults },
    flags     = false_flags,
    name      = "dv04_remove_joiners",
    order     = { "dv04" },
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
    if script == "deva" or script == "dev2" or script =="mlym" or script == "mlm2" then
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
            elseif script == "dev2" then
                sharedfeatures["dv01"] = true -- dv01_reorder_matras
                sharedfeatures["dv02"] = true -- dv02_reorder_reph
                sharedfeatures["dv03"] = true -- dv03_reorder_pre_base_reordering_consonants
                sharedfeatures["dv04"] = true -- dv04_remove_joiners
            elseif script == "mlym" then
                sharedfeatures["pstf"] = true
            elseif script == "mlm2" then
                sharedfeatures["pstf"] = true
                sharedfeatures["pref"] = true
                sharedfeatures["dv03"] = true        -- dv03_reorder_pre_base_reordering_consonants
                gsubfeatures["dv03"] = dev2_defaults -- reorder pre base reordering consonants
                insert(sequences,insertindex,sequence_reorder_pre_base_reordering_consonants)
            end
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
                    local subtables = dataset[3].subtables
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

local function deva_reorder(head,start,stop,font,attr,nbspaces)

    local lookuphash, reph, vattu, blwfcache = deva_initialize(font,attr) -- could be inlines but ugly

    local current   = start
    local n         = getnext(start)
    local base      = nil
    local firstcons = nil
    local lastcons  = nil
    local basefound = false

    if ra[getchar(start)] and halant[getchar(n)] and reph then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph
        -- from candidates for base consonants
        if n == stop then
            return head, stop, nbspaces
        end
        if getchar(getnext(n)) == c_zwj then
            current = start
        else
            current = getnext(n)
            setprop(start,a_state,s_rphf)
        end
    end

    if getchar(current) == c_nbsp then
        -- Stand Alone cluster
        if current == stop then
            stop = getprev(stop)
            head = remove_node(head,current)
            flush_node(current)
            return head, stop, nbspaces
        else
            nbspaces  = nbspaces + 1
            base      = current
            firstcons = current
            lastcons  = current
            current   = getnext(current)
            if current ~= stop then
                if nukta[getchar(current)] then
                    current = getnext(current)
                end
                if getchar(current) == c_zwj then
                    if current ~= stop then
                        local next = getnext(current)
                        if next ~= stop and halant[getchar(next)] then
                            current = next
                            next = getnext(current)
                            local tmp = next and getnext(next) or nil -- needs checking
                            local changestop = next == stop
                            local tempcurrent = copy_node(next)
							copyinjection(tempcurrent,next)
                            local nextcurrent = copy_node(current)
							copyinjection(nextcurrent,current) -- KE: necessary? HH: probably not as positioning comes later and we rawget/set
                            setnext(tempcurrent,nextcurrent)
                            setprev(nextcurrent,tempcurrent)
                            setprop(tempcurrent,a_state,s_blwf)
                            tempcurrent = processcharacters(tempcurrent,font)
                            setprop(tempcurrent,a_state,unsetvalue)
                            if getchar(next) == getchar(tempcurrent) then
                                flush_list(tempcurrent)
                                local n = copy_node(current)
								copyinjection(n,current) -- KE: necessary? HH: probably not as positioning comes later and we rawget/set
                                setchar(current,dotted_circle)
                                head = insert_node_after(head, current, n)
                            else
                                setchar(current,getchar(tempcurrent)) -- we assumes that the result of blwf consists of one node
                                local freenode = getnext(current)
                                setnext(current,tmp)
                                if tmp then
                                    setprev(tmp,current)
                                end
                                flush_node(freenode)
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
        if consonant[getchar(current)] then
            setprop(current,a_state,s_half)
            if not firstcons then
                firstcons = current
            end
            lastcons = current
            if not base then
                base = current
            elseif blwfcache[getchar(current)] then
                -- consonant has below-base (or post-base) form
                setprop(current,a_state,s_blwf)
            else
                base = current
            end
        end
        basefound = current == stop
        current = getnext(current)
    end

    if base ~= lastcons then
        -- if base consonant is not last one then move halant from base consonant to last one
        local np = base
        local n = getnext(base)
        if nukta[getchar(n)] then
            np = n
            n = getnext(n)
        end
        if halant[getchar(n)] then
            if lastcons ~= stop then
                local ln = getnext(lastcons)
                if nukta[getchar(ln)] then
                    lastcons = ln
                end
            end
         -- local np = getprev(n)
            local nn = getnext(n)
            local ln = getnext(lastcons) -- what if lastcons is nn ?
            setnext(np,nn)
            setprev(nn,np)
            setnext(lastcons,n)
            if ln then
                setprev(ln,n)
            end
            setnext(n,ln)
            setprev(n,lastcons)
            if lastcons == stop then
                stop = n
            end
        end
    end

    n = getnext(start)
    if n ~= stop and ra[getchar(start)] and halant[getchar(n)] and not zw_char[getchar(getnext(n))] then
        -- if syllable starts with Ra + H then move this combination so that it follows either:
        -- the post-base 'matra' (if any) or the base consonant
        local matra = base
        if base ~= stop then
            local next = getnext(base)
            if dependent_vowel[getchar(next)] then
                matra = next
            end
        end
        -- [sp][start][n][nn] [matra|base][?]
        -- [matra|base][start]  [n][?] [sp][nn]
        local sp = getprev(start)
        local nn = getnext(n)
        local mn = getnext(matra)
        if sp then
            setnext(sp,nn)
        end
        setprev(nn,sp)
        setnext(matra,start)
        setprev(start,matra)
        setnext(n,mn)
        if mn then
            setprev(mn,n)
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
        local next = getnext(current)
        if next ~= stop and halant[getchar(next)] and getchar(getnext(next)) == c_zwnj then
            setprop(current,a_state,unsetvalue)
        end
        current = next
    end

    if base ~= stop and getprop(base,a_state) then
        local next = getnext(base)
        if halant[getchar(next)] and not (next ~= stop and getchar(getnext(next)) == c_zwj) then
            setprop(base,a_state,unsetvalue)
        end
    end

    -- ToDo: split two- or three-part matras into their parts. Then, move the left 'matra' part to the beginning of the syllable.
    -- Not necessary for Devanagari. However it is necessay for other scripts, such as Tamil (e.g. TAMIL VOWEL SIGN O - 0BCA)

    -- classify consonants and 'matra' parts as pre-base, above-base (Reph), below-base or post-base, and group elements of the syllable (consonants and 'matras') according to this classification

    local current, allreordered, moved = start, false, { [base] = true }
    local a, b, p, bn = base, base, base, getnext(base)
    if base ~= stop and nukta[getchar(bn)] then
        a, b, p = bn, bn, bn
    end
    while not allreordered do
        -- current is always consonant
        local c = current
        local n = getnext(current)
        local l = nil -- used ?
        if c ~= stop then
            if nukta[getchar(n)] then
                c = n
                n = getnext(n)
            end
            if c ~= stop then
                if halant[getchar(n)] then
                    c = n
                    n = getnext(n)
                end
                while c ~= stop and dependent_vowel[getchar(n)] do
                    c = n
                    n = getnext(n)
                end
                if c ~= stop then
                    if vowel_modifier[getchar(n)] then
                        c = n
                        n = getnext(n)
                    end
                    if c ~= stop and stress_tone_mark[getchar(n)] then
                        c = n
                        n = getnext(n)
                    end
                end
            end
        end
        local bp = getprev(firstcons)
        local cn = getnext(current)
        local last = getnext(c)
        while cn ~= last do
            -- move pre-base matras...
            if pre_mark[getchar(cn)] then
                if bp then
                    setnext(bp,cn)
                end
                local next = getnext(cn)
                local prev = getprev(cn)
                if next then
                    setprev(next,prev)
                end
                setnext(prev,next)
                if cn == stop then
                    stop = prev
                end
                setprev(cn,bp)
                setnext(cn,firstcons)
                setprev(firstcons,cn)
                if firstcons == start then
                    if head == start then
                        head = cn
                    end
                    start = cn
                end
                break
            end
            cn = getnext(cn)
        end
        allreordered = c == stop
        current = getnext(c)
    end

    if reph or vattu then
        local current, cns = start, nil
        while current ~= stop do
            local c = current
            local n = getnext(current)
            if ra[getchar(current)] and halant[getchar(n)] then
                c = n
                n = getnext(n)
                local b, bn = base, base
                while bn ~= stop  do
                    local next = getnext(bn)
                    if dependent_vowel[getchar(next)] then
                        b = next
                    end
                    bn = next
                end
                if getprop(current,a_state) == s_rphf then
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
                        local prev = getprev(current)
                        if prev then
                            setnext(prev,n)
                        end
                        if n then
                            setprev(n,prev)
                        end
                        local next = getnext(b)
                        setnext(c,next)
                        if next then
                            setprev(next,c)
                        end
                        setnext(c,next)
                        setnext(b,current)
                        setprev(current,b)
                    end
                elseif cns and getnext(cns) ~= current then -- todo: optimize next
                    -- position below-base Ra (vattu) following the consonants on which it is placed (either the base consonant or one of the pre-base consonants)
                    local cp, cnsn = getprev(current), getnext(cns)
                    if cp then
                        setnext(cp,n)
                    end
                    if n then
                        setprev(n,cp)
                    end
                    setnext(cns,current)
                    setprev(current,cns)
                    setnext(c,cnsn)
                    if cnsn then
                        setprev(cnsn,c)
                    end
                    if c == stop then
                        stop = cp
                        break
                    end
                    current = getprev(n)
                end
            else
                local char = getchar(current)
                if consonant[char] then
                    cns = current
                    local next = getnext(cns)
                    if halant[getchar(next)] then
                        cns = next
                    end
                elseif char == c_nbsp then
                    nbspaces   = nbspaces + 1
                    cns        = current
                    local next = getnext(cns)
                    if halant[getchar(next)] then
                        cns = next
                    end
                end
            end
            current = getnext(current)
        end
    end

    if getchar(base) == c_nbsp then
        nbspaces = nbspaces - 1
        head = remove_node(head,base)
        flush_node(base)
    end

    return head, stop, nbspaces
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
    local startfont = getfont(start)
    local startattr = getprop(start,a_syllabe)
    -- can be fast loop
    while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font and getprop(current,a_syllabe) == startattr do
        local next = getnext(current)
        if halant[getchar(current)] and not getprop(current,a_state) then
            if next and getid(next) == glyph_code and getsubtype(next) < 256 and getfont(next) == font and getprop(next,a_syllabe) == startattr and zw_char[getchar(next)] then
                current = next
            end
            local startnext = getnext(start)
            head = remove_node(head,start)
            local next = getnext(current)
            if next then
                setprev(next,start)
            end
            setnext(start,next)
            setnext(current,start)
            setprev(start,current)
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
    local current   = getnext(start)
    local startnext = nil
    local startprev = nil
    local startfont = getfont(start)
    local startattr = getprop(start,a_syllabe)
    while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == startfont and getprop(current,a_syllabe) == startattr do    --step 2
        if halant[getchar(current)] and not getprop(current,a_state) then
            local next = getnext(current)
            if next and getid(next) == glyph_code and getsubtype(next) < 256 and getfont(next) == startfont and getprop(next,a_syllabe) == startattr and zw_char[getchar(next)] then
                current = next
            end
            startnext = getnext(start)
            head = remove_node(head,start)
            local next = getnext(current)
            if next then
                setprev(next,start)
            end
            setnext(start,next)
            setnext(current,start)
            setprev(start,current)
            start = startnext
            startattr = getprop(start,a_syllabe)
            break
        end
        current = getnext(current)
    end
    if not startnext then
        current = getnext(start)
        while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == startfont and getprop(current,a_syllabe) == startattr do    --step 4
            if getprop(current,a_state) == s_pstf then    --post-base
                startnext = getnext(start)
                head = remove_node(head,start)
                local prev = getprev(current)
                setprev(start,prev)
                setnext(prev,start)
                setnext(start,current)
                setprev(current,start)
                start = startnext
                startattr = getprop(start,a_syllabe)
                break
            end
            current = getnext(current)
        end
    end
    -- ToDo: determine position for reph with reordering position other than 'before postscript'
    -- (required for scripts other than dev2)
    -- leaks
    if not startnext then
        current = getnext(start)
        local c = nil
        while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == startfont and getprop(current,a_syllabe) == startattr do    --step 5
            if not c then
                local char = getchar(current)
                -- todo: combine in one
                if mark_above_below_post[char] and reorder_class[char] ~= "after subscript" then
                    c = current
                end
            end
            current = getnext(current)
        end
        -- here we can loose the old start node: maybe best split cases
        if c then
            startnext = getnext(start)
            head = remove_node(head,start)
            local prev = getprev(c)
            setprev(start,prev)
            setnext(prev,start)
            setnext(start,c)
            setprev(c,start)
            -- end
            start = startnext
            startattr = getprop(start,a_syllabe)
        end
    end
    -- leaks
    if not startnext then
        current = start
        local next = getnext(current)
        while next and getid(next) == glyph_code and getsubtype(next) < 256 and getfont(next) == startfont and getprop(next,a_syllabe) == startattr do    --step 6
            current = next
            next = getnext(current)
        end
        if start ~= current then
            startnext = getnext(start)
            head = remove_node(head,start)
            local next = getnext(current)
            if next then
                setprev(next,start)
            end
            setnext(star,next)
            setnext(current,start)
            setprev(start,current)
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
    local startfont = getfont(start)
    local startattr = getprop(start,a_syllabe)
    -- can be fast for loop + caching state
    while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == startfont and getprop(current,a_syllabe) == startattr do
        local next = getnext(current)
        if halant[getchar(current)] and not getprop(current,a_state) then
            if next and getid(next) == glyph_code and getsubtype(next) < 256 and getfont(next) == font and getprop(next,a_syllabe) == startattr then
                local char = getchar(next)
                if char == c_zwnj or char == c_zwj then
                    current = next
                end
            end
            startnext = getnext(start)
            removenode(start,start)
            local next = getnext(current)
            if next then
                setprev(next,start)
            end
            setnext(start,next)
            setnext(current,start)
            setprev(start,current)
            start = startnext
            break
        end
        current = next
    end
    if not startnext then
        current = getnext(start)
        startattr = getprop(start,a_syllabe)
        while current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == startfont and getprop(current,a_syllabe) == startattr do
            if not consonant[getchar(current)] and getprop(current,a_state) then    --main
                startnext = getnext(start)
                removenode(start,start)
                local prev = getprev(current)
                setprev(start,prev)
                setnext(prev,start)
                setnext(start,current)
                setprev(current,start)
                start = startnext
                break
            end
            current = getnext(current)
        end
    end
    return head, start, true
end

function handlers.devanagari_remove_joiners(head,start,kind,lookupname,replacement)
    local stop = getnext(start)
    local startfont = getfont(start)
    while stop and getid(stop) == glyph_code and getsubtype(stop) < 256 and getfont(stop) == startfont do
        local char = getchar(stop)
        if char == c_zwnj or char == c_zwj then
            stop = getnext(stop)
        else
            break
        end
    end
    if stop then
        setnext(getprev(stop),nil)
        setprev(stop,getprev(start))
    end
    local prev = getprev(start)
    if prev then
        setnext(prev,stop)
    end
    if head == start then
    	head = stop
    end
    flush_list(start)
    return head, stop, true
end

local valid = {
    akhn = true, -- malayalam
    rphf = true,
    pref = true,
    half = true,
    blwf = true,
    pstf = true,
    pres = true, -- malayalam
    blws = true, -- malayalam
    psts = true, -- malayalam
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
                    local subtables = dataset[3].subtables
                    for i=1,#subtables do
                        local lookupname = subtables[i]
                        local lookupcache = lookuphash[lookupname]
                        if lookupcache then
                            local reph = false
                            local chain = dataset[3]
                            if chain ~= 0 then --rphf is result of of chain
                                -- rphf might be result of other handler/chainproc
                            else
                                -- rphf acts on consonant + halant
                                for k, v in next, ra do
                                    local r = lookupcache[k]
                                    if r then
                                        local h = false
                                        for k, v in next, halant do
                                            local h = r[k]
                                            if h then
                                                reph = h.ligature or false
                                                break
                                            end
                                        end
                                        if reph then
                                            break
                                        end
                                    end
                                end
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

local function dev2_reorder(head,start,stop,font,attr,nbspaces) -- maybe do a pass over (determine stop in sweep)

    local lookuphash, seqsubset = dev2_initialize(font,attr)

    local pre_base_reordering_consonants = { } -- was nil ... probably went unnoticed because never assigned

    local reph     = false -- was nil ... probably went unnoticed because never assigned
    local halfpos  = nil
    local basepos  = nil
    local subpos   = nil
    local postpos  = nil
    local locl     = { }

    for i=1,#seqsubset do

        -- maybe quit if start == stop

        local subset = seqsubset[i]
        local kind = subset[1]
        local lookupcache = subset[2]
        if kind == "rphf" then
            for k, v in next, ra do
                local r = lookupcache[k]
                if r then
                    for k, v in next, halant do
                        local h = r[k]
                        if h then
                            reph = h.ligature or false
                            break
                        end
                    end
                    if reph then
                        break
                    end
                end
            end
            local current = start
            local last = getnext(stop)
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or getchar(current)
                    local found = lookupcache[c]
                    if found then
                        local next = getnext(current)
                        local n = locl[next] or getchar(next)
                        if found[n] then    --above-base: rphf    Consonant + Halant
                            local afternext = next ~= stop and getnext(next)
                            if afternext and zw_char[getchar(afternext)] then -- ZWJ and ZWNJ prevent creation of reph
                                current = next
                                current = getnext(current)
                            elseif current == start then
                                setprop(current,a_state,s_rphf)
                                current = next
                            else
                                current = next
                            end
                        end
                    end
                end
                current = getnext(current)
            end
        elseif kind == "pref" then
            -- why not global? pretty ineffient this way
            -- this will move to the initializer and we will store the hash in dataset
            -- todo: reph might also be result of chain
            for k, v in next, halant do
                local h = lookupcache[k]
                if h then
                    local found = false
                    for k, v in next, h do
                        found = v and v.ligature
                        if found then
                            pre_base_reordering_consonants[k] = found
                            break
                        end
                    end
                    if found then
                        break
                    end
                end
            end
            --
            local current = start
            local last = getnext(stop)
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or getchar(current)
                    local found = lookupcache[c]
                    if found then
                        local next = getnext(current)
                        local n = locl[next] or getchar(next)
                        if found[n] then
                            setprop(current,a_state,s_pref)
                            setprop(next,a_state,s_pref)
                            current = next
                        end
                    end
                end
                current = getnext(current)
            end
        elseif kind == "half" then -- half forms: half / Consonant + Halant
            local current = start
            local last = getnext(stop)
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or getchar(current)
                    local found = lookupcache[c]
                    if found then
                        local next = getnext(current)
                        local n = locl[next] or getchar(next)
                        if found[n] then
                            if next ~= stop and getchar(getnext(next)) == c_zwnj then    -- zwnj prevent creation of half
                                current = next
                            else
                                setprop(current,a_state,s_half)
                                if not halfpos then
                                    halfpos = current
                                end
                            end
                            current = getnext(current)
                        end
                    end
                end
                current = getnext(current)
            end
        elseif kind == "blwf" then -- below-base: blwf / Halant + Consonant
            local current = start
            local last = getnext(stop)
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or getchar(current)
                    local found = lookupcache[c]
                    if found then
                        local next = getnext(current)
                        local n = locl[next] or getchar(next)
                        if found[n] then
                            setprop(current,a_state,s_blwf)
                            setprop(next,a_state,s_blwf)
                            current = next
                            subpos = current
                        end
                    end
                end
                current = getnext(current)
            end
        elseif kind == "pstf" then -- post-base: pstf / Halant + Consonant
            local current = start
            local last = getnext(stop)
            while current ~= last do
                if current ~= stop then
                    local c = locl[current] or getchar(current)
                    local found = lookupcache[c]
                    if found then
                        local next = getnext(current)
                        local n = locl[next] or getchar(next)
                        if found[n] then
                            setprop(current,a_state,s_pstf)
                            setprop(next,a_state,s_pstf)
                            current = next
                            postpos = current
                        end
                    end
                end
                current = getnext(current)
            end
        end
    end

    -- this one changes per word

    lookuphash["dv02_reorder_reph"] = { [reph] = true }
    lookuphash["dv03_reorder_pre_base_reordering_consonants"] = pre_base_reordering_consonants

    local current, base, firstcons = start, nil, nil

    if getprop(start,a_state) == s_rphf then
        -- if syllable starts with Ra + H and script has 'Reph' then exclude Reph from candidates for base consonants
        current = getnext(getnext(start))
    end

    if current ~= getnext(stop) and getchar(current) == c_nbsp then
        -- Stand Alone cluster
        if current == stop then
            stop = getprev(stop)
            head = remove_node(head,current)
            flush_node(current)
            return head, stop, nbspaces
        else
            nbspaces = nbspaces + 1
            base     = current
            current  = getnext(current)
            if current ~= stop then
                local char = getchar(current)
                if nukta[char] then
                    current = getnext(current)
                    char = getchar(current)
                end
                if char == c_zwj then
                    local next = getnext(current)
                    if current ~= stop and next ~= stop and halant[getchar(next)] then
                        current = next
                        next = getnext(current)
                        local tmp = getnext(next)
                        local changestop = next == stop
                        setnext(next,nil)
                        setprop(current,a_state,s_pref)
                        current = processcharacters(current,font)
                        setprop(current,a_state,s_blwf)
                        current = processcharacters(current,font)
                        setprop(current,a_state,s_pstf)
                        current = processcharacters(current,font)
                        setprop(current,a_state,unsetvalue)
                        if halant[getchar(current)] then
                            setnext(getnext(current),tmp)
                            local nc = copy_node(current)
							copyinjection(nc,current)
                            setchar(current,dotted_circle)
                            head = insert_node_after(head,current,nc)
                        else
                            setnext(current,tmp) -- assumes that result of pref, blwf, or pstf consists of one node
                            if changestop then
                                stop = current
                            end
                        end
                    end
                end
            end
        end
    else -- not Stand Alone cluster
        local last = getnext(stop)
        while current ~= last do    -- find base consonant
            local next = getnext(current)
            if consonant[getchar(current)] then
                if not (current ~= stop and next ~= stop and halant[getchar(next)] and getchar(getnext(next)) == c_zwj) then
                    if not firstcons then
                        firstcons = current
                    end
                    -- check whether consonant has below-base or post-base form or is pre-base reordering Ra
                    local a = getprop(current,a_state)
                    if not (a == s_pref or a == s_blwf or a == s_pstf) then
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
        if getprop(start,a_state) == s_rphf then
            setprop(start,a_state,unsetvalue)
        end
        return head, stop, nbspaces
    else
        if getprop(base,a_state) then
            setprop(base,a_state,unsetvalue)
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
    local last = getnext(stop)
    while current ~= last do
        local char, target, cn = locl[current] or getchar(current), nil, getnext(current)
-- not so efficient (needed for malayalam)
local tpm = twopart_mark[char]
if tpm then
    local extra = copy_node(current)
	copyinjection(extra,current)
    char = tpm[1]
    setchar(current,char)
    setchar(extra,tpm[2])
    head = insert_node_after(head,current,extra)
end
--
        if not moved[current] and dependent_vowel[char] then
            if pre_mark[char] then            -- Before first half form in the syllable
                moved[current] = true
                local prev = getprev(current)
                local next = getnext(current)
                if prev then
                    setnext(prev,next)
                end
                if next then
                    setprev(next,prev)
                end
                if current == stop then
                    stop = getprev(current)
                end
                if halfpos == start then
                    if head == start then
                        head = current
                    end
                    start = current
                end
                local prev = getprev(halfpos)
                if prev then
                    setnext(prev,current)
                end
                setprev(current,prev)
                setprev(halfpos,current)
                setnext(current,halfpos)
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
                local prev = getprev(current)
                if prev ~= target then
                    local next = getnext(current)
                    if prev then -- not needed, already tested with target
                        setnext(prev,next)
                    end
                    if next then
                        setprev(next,prev)
                    end
                    if current == stop then
                        stop = prev
                    end
                    local next = getnext(target)
                    if next then
                        setprev(next,current)
                    end
                    setnext(current,next)
                    setnext(target,current)
                    setprev(current,target)
                end
            end
        end
        current = cn
    end

    -- Reorder marks to canonical order: Adjacent nukta and halant or nukta and vedic sign are always repositioned if necessary, so that the nukta is first.

    local current, c = start, nil
    while current ~= stop do
        local char = getchar(current)
        if halant[char] or stress_tone_mark[char] then
            if not c then
                c = current
            end
        else
            c = nil
        end
        local next = getnext(current)
        if c and nukta[getchar(next)] then
            if head == c then
                head = next
            end
            if stop == next then
                stop = current
            end
            local prev = getprev(c)
            if prev then
                setnext(prev,next)
            end
            setprev(next,prev)
            local nextnext = getnext(next)
            setnext(current,nextnext)
            local nextnextnext = getnext(nextnext)
            if nextnextnext then
                setprev(nextnextnext,current)
            end
            setprev(c,nextnext)
            setnext(nextnext,c)
        end
        if stop == current then break end
        current = getnext(current)
    end

    if getchar(base) == c_nbsp then
        nbspaces = nbspaces - 1
        head = remove_node(head, base)
        flush_node(base)
    end

    return head, stop, nbspaces
end

-- cleaned up and optimized ... needs checking (local, check order, fixes, extra hash, etc)

local separator = { }

imerge(separator,consonant)
imerge(separator,independent_vowel)
imerge(separator,dependent_vowel)
imerge(separator,vowel_modifier)
imerge(separator,stress_tone_mark)

for k, v in next, nukta  do separator[k] = true end
for k, v in next, halant do separator[k] = true end

local function analyze_next_chars_one(c,font,variant) -- skip one dependent vowel
    -- why two variants ... the comment suggests that it's the same ruleset
    local n = getnext(c)
    if not n then
        return c
    end
    if variant == 1 then
        local v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if v and nukta[getchar(n)] then
            n = getnext(n)
            if n then
                v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
            end
        end
        if n and v then
            local nn = getnext(n)
            if nn and getid(nn) == glyph_code and getsubtype(nn) < 256 and getfont(nn) == font then
                local nnn = getnext(nn)
                if nnn and getid(nnn) == glyph_code and getsubtype(nnn) < 256 and getfont(nnn) == font then
                    local nnc = getchar(nn)
                    local nnnc = getchar(nnn)
                    if nnc == c_zwj and consonant[nnnc] then
                        c = nnn
                    elseif (nnc == c_zwnj or nnc == c_zwj) and halant[nnnc] then
                        local nnnn = getnext(nnn)
                        if nnnn and getid(nnnn) == glyph_code and consonant[getchar(nnnn)] and getsubtype(nnnn) < 256 and getfont(nnnn) == font then
                            c = nnnn
                        end
                    end
                end
            end
        end
    elseif variant == 2 then
        if getid(n) == glyph_code and nukta[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
            c = n
        end
        n = getnext(c)
        if n and getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font then
            local nn = getnext(n)
            if nn then
                local nv = getid(nn) == glyph_code and getsubtype(nn) < 256 and getfont(nn) == font
                if nv and zw_char[getchar(n)] then
                    n = nn
                    nn = getnext(nn)
                    nv = nn and getid(nn) == glyph_code and getsubtype(nn) < 256 and getfont(nn) == font
                end
                if nv and halant[getchar(n)] and consonant[getchar(nn)] then
                    c = nn
                end
            end
        end
    end
    -- c = ms_matra(c)
    local n = getnext(c)
    if not n then
        return c
    end
    local v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
    if not v then
        return c
    end
    local char = getchar(n)
    if dependent_vowel[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if nukta[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if halant[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if vowel_modifier[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if stress_tone_mark[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if stress_tone_mark[char] then
        return n
    else
        return c
    end
end

local function analyze_next_chars_two(c,font)
    local n = getnext(c)
    if not n then
        return c
    end
    if getid(n) == glyph_code and nukta[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
        c = n
    end
    n = c
    while true do
        local nn = getnext(n)
        if nn and getid(nn) == glyph_code and getsubtype(nn) < 256 and getfont(nn) == font then
            local char = getchar(nn)
            if halant[char] then
                n = nn
                local nnn = getnext(nn)
                if nnn and getid(nnn) == glyph_code and zw_char[getchar(nnn)] and getsubtype(nnn) < 256 and getfont(nnn) == font then
                    n = nnn
                end
            elseif char == c_zwnj or char == c_zwj then
             -- n = nn -- not here (?)
                local nnn = getnext(nn)
                if nnn and getid(nnn) == glyph_code and halant[getchar(nnn)] and getsubtype(nnn) < 256 and getfont(nnn) == font then
                    n = nnn
                end
            else
                break
            end
            local nn = getnext(n)
            if nn and getid(nn) == glyph_code and consonant[getchar(nn)] and getsubtype(nn) < 256 and getfont(nn) == font then
                n = nn
                local nnn = getnext(nn)
                if nnn and getid(nnn) == glyph_code and nukta[getchar(nnn)] and getsubtype(nnn) < 256 and getfont(nnn) == font then
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
    local n = getnext(c)
    if not n then
        return c
    end
    local v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
    if not v then
        return c
    end
    local char = getchar(n)
    if char == c_anudatta then
        c = n
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if halant[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
        if char == c_zwnj or char == c_zwj then
            c = getnext(c)
            n = getnext(c)
            if not n then
                return c
            end
            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
            if not v then
                return c
            end
            char = getchar(n)
        end
    else
        -- c = ms_matra(c)
        -- same as one
        if dependent_vowel[char] then
            c = getnext(c)
            n = getnext(c)
            if not n then
                return c
            end
            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
            if not v then
                return c
            end
            char = getchar(n)
        end
        if nukta[char] then
            c = getnext(c)
            n = getnext(c)
            if not n then
                return c
            end
            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
            if not v then
                return c
            end
            char = getchar(n)
        end
        if halant[char] then
            c = getnext(c)
            n = getnext(c)
            if not n then
                return c
            end
            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
            if not v then
                return c
            end
            char = getchar(n)
        end
    end
    -- same as one
    if vowel_modifier[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if stress_tone_mark[char] then
        c = getnext(c)
        n = getnext(c)
        if not n then
            return c
        end
        v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
        if not v then
            return c
        end
        char = getchar(n)
    end
    if stress_tone_mark[char] then
        return n
    else
        return c
    end
end

local function inject_syntax_error(head,current,mark)
    local signal = copy_node(current)
	copyinjection(signal,current)
    if mark == pre_mark then
        setchar(signal,dotted_circle)
    else
        setchar(current,dotted_circle)
    end
    return insert_node_after(head,current,signal)
end

-- It looks like these two analyzers were written independently but they share
-- a lot. Common code has been synced.

function methods.deva(head,font,attr)
    head           = tonut(head)
    local current  = head
    local start    = true
    local done     = false
    local nbspaces = 0
    while current do
        if getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font then
            done = true
            local syllablestart = current
            local syllableend = nil
            local c = current
            local n = getnext(c)
            if n and ra[getchar(c)] and getid(n) == glyph_code and halant[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
                local n = getnext(n)
                if n and getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font then
                    c = n
                end
            end
            local standalone = getchar(c) == c_nbsp
            if standalone then
                local prev = getprev(current)
                if not prev then
                    -- begin of paragraph or box
                elseif getid(prev) ~= glyph_code or getsubtype(prev) >= 256 or getfont(prev) ~= font then
                    -- different font or language so quite certainly a different word
                elseif not separator[getchar(prev)] then
                    -- something that separates words
                else
                    standalone = false
                end
            end
            if standalone then
                -- stand alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
				local syllableend = analyze_next_chars_one(c,font,2)
				current = getnext(syllableend)
                if syllablestart ~= syllableend then
                    head, current, nbspaces = deva_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
                    current = getnext(current)
                end
            else
                -- we can delay the getsubtype(n) and getfont(n) and test for say halant first
                -- as an table access is faster than two function calls (subtype and font are
                -- pseudo fields) but the code becomes messy (unless we make it a function)
                local char = getchar(current)
                if consonant[char] then
                    -- syllable containing consonant
                    local prevc = true
                    while prevc do
                        prevc = false
                        local n = getnext(current)
                        if not n then
                            break
                        end
                        local v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
                        if not v then
                            break
                        end
                        local c = getchar(n)
                        if nukta[c] then
                            n = getnext(n)
                            if not n then
                                break
                            end
                            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
                            if not v then
                                break
                            end
                            c = getchar(n)
                        end
                        if halant[c] then
                            n = getnext(n)
                            if not n then
                                break
                            end
                            v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
                            if not v then
                                break
                            end
                            c = getchar(n)
                            if c == c_zwnj or c == c_zwj then
                                n = getnext(n)
                                if not n then
                                    break
                                end
                                v = getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font
                                if not v then
                                    break
                                end
                                c = getchar(n)
                            end
                            if consonant[c] then
                                prevc = true
                                current = n
                            end
                        end
                    end
                    local n = getnext(current)
                    if n and getid(n) == glyph_code and nukta[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
                        -- nukta (not specified in Microsft Devanagari OpenType specification)
                        current = n
                        n = getnext(current)
                    end
                    syllableend = current
                    current = n
                    if current then
                        local v = getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font
                        if v then
                            if halant[getchar(current)] then
                                -- syllable containing consonant without vowels: {C + [Nukta] + H} + C + H
                                local n = getnext(current)
                                if n and getid(n) == glyph_code and zw_char[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
                                    -- code collapsed, probably needs checking with intention
                                    syllableend = n
                                    current = getnext(n)
                                else
                                    syllableend = current
                                    current = n
                                end
                            else
                                -- syllable containing consonant with vowels: {C + [Nukta] + H} + C + [M] + [VM] + [SM]
                                local c = getchar(current)
                                if dependent_vowel[c] then
                                    syllableend = current
                                    current = getnext(current)
                                    v = current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font
                                    if v then
                                        c = getchar(current)
                                    end
                                end
                                if v and vowel_modifier[c] then
                                    syllableend = current
                                    current = getnext(current)
                                    v = current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font
                                    if v then
                                        c = getchar(current)
                                    end
                                end
                                if v and stress_tone_mark[c] then
                                    syllableend = current
                                    current = getnext(current)
                                end
                            end
                        end
                    end
                    if syllablestart ~= syllableend then
                        head, current, nbspaces = deva_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
                        current = getnext(current)
                    end
                elseif independent_vowel[char] then
                    -- syllable without consonants: VO + [VM] + [SM]
                    syllableend = current
                    current = getnext(current)
                    if current then
                        local v = getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font
                        if v then
                            local c = getchar(current)
                            if vowel_modifier[c] then
                                syllableend = current
                                current = getnext(current)
                                v = current and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font
                                if v then
                                    c = getchar(current)
                                end
                            end
                            if v and stress_tone_mark[c] then
                                syllableend = current
                                current = getnext(current)
                            end
                        end
                    end
                else
                    local mark = mark_four[char]
                    if mark then
                        head, current = inject_syntax_error(head,current,mark)
                    end
                    current = getnext(current)
                end
            end
        else
            current = getnext(current)
        end
        start = false
    end

    if nbspaces > 0 then
        head = replace_all_nbsp(head)
    end

    head = tonode(head)

    return head, done
end

-- there is a good change that when we run into one with subtype < 256 that the rest is also done
-- so maybe we can omit this check (it's pretty hard to get glyphs in the stream out of the blue)

-- handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,1)

function methods.dev2(head,font,attr)
    head           = tonut(head)
    local current  = head
    local start    = true
    local done     = false
    local syllabe  = 0
    local nbspaces = 0
    while current do
        local syllablestart, syllableend = nil, nil
        if getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font then
            done = true
            syllablestart = current
            local c = current
            local n = getnext(current)
            if n and ra[getchar(c)] and getid(n) == glyph_code and halant[getchar(n)] and getsubtype(n) < 256 and getfont(n) == font then
                local n = getnext(n)
                if n and getid(n) == glyph_code and getsubtype(n) < 256 and getfont(n) == font then
                    c = n
                end
            end
            local char = getchar(c)
            if independent_vowel[char] then
                -- vowel-based syllable: [Ra+H]+V+[N]+[<[<ZWJ|ZWNJ>]+H+C|ZWJ+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
                current = analyze_next_chars_one(c,font,1)
                syllableend = current
            else
                local standalone = char == c_nbsp
                if standalone then
                    nbspaces = nbspaces + 1
                    local p = getprev(current)
                    if not p then
                        -- begin of paragraph or box
                    elseif getid(p) ~= glyph_code or getsubtype(p) >= 256 or getfont(p) ~= font then
                        -- different font or language so quite certainly a different word
                    elseif not separator[getchar(p)] then
                        -- something that separates words
                    else
                        standalone = false
                    end
                end
                if standalone then
                    -- Stand Alone cluster (at the start of the word only): #[Ra+H]+NBSP+[N]+[<[<ZWJ|ZWNJ>]+H+C>]+[{M}+[N]+[H]]+[SM]+[(VD)]
                    current = analyze_next_chars_one(c,font,2)
                    syllableend = current
                elseif consonant[getchar(current)] then
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
            local n = getnext(syllableend)
            while c ~= n do
                setprop(c,a_syllabe,syllabe)
                c = getnext(c)
            end
        end
        if syllableend and syllablestart ~= syllableend then
            head, current, nbspaces = dev2_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
        end
        if not syllableend and getid(current) == glyph_code and getsubtype(current) < 256 and getfont(current) == font and not getprop(current,a_state) then
            local mark = mark_four[getchar(current)]
            if mark then
                head, current = inject_syntax_error(head,current,mark)
            end
        end
        start = false
        current = getnext(current)
    end

    if nbspaces > 0 then
        head = replace_all_nbsp(head)
    end

    head = tonode(head)

    return head, done
end

methods.mlym = methods.deva
methods.mlm2 = methods.dev2
