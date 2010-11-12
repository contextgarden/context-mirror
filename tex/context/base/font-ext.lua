if not modules then modules = { } end modules ['font-ext'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local next, type, byte = next, type, string.byte
local gmatch, concat = string.gmatch, table.concat
local utfchar = utf.char
local getparameters = utilities.parsers.getparameters

local allocate = utilities.storage.allocate

local trace_protrusion = false  trackers.register("fonts.protrusion", function(v) trace_protrusion = v end)
local trace_expansion  = false  trackers.register("fonts.expansion",  function(v) trace_expansion  = v end)

local report_fonts = logs.new("fonts")

commands = commands or { }

--[[ldx--
<p>When we implement functions that deal with features, most of them
will depend of the font format. Here we define the few that are kind
of neutral.</p>
--ldx]]--

local fonts = fonts

fonts.triggers      = fonts.triggers or { }
local triggers      = fonts.triggers

fonts.methods       = fonts.methods or { }
local methods       = fonts.methods

fonts.manipulators  = fonts.manipulators or { }
local manipulators  = fonts.manipulators

fonts.initializers  = fonts.initializers or { }
local initializers  = fonts.initializers
initializers.common = initializers.common or { }

local otf = fonts.otf

--[[ldx--
<p>This feature will remove inter-digit kerns.</p>
--ldx]]--

table.insert(triggers,"equaldigits")

function initializers.common.equaldigits(tfmdata,value)
    if value then
        local chr = tfmdata.characters
        for i = utfbyte('0'), utfbyte('9') do
            local c = chr[i]
            if c then
                c.kerns = nil
            end
        end
    end
end

--[[ldx--
<p>This feature will give all glyphs an equal height and/or depth. Valid
values are <type>none</type>, <type>height</type>, <type>depth</type> and
<type>both</type>.</p>
--ldx]]--

table.insert(triggers,"lineheight")

function initializers.common.lineheight(tfmdata,value)
    if value and type(value) == "string" then
        if value == "none" then
            for _,v in next, tfmdata.characters do
                v.height, v.depth = 0, 0
            end
        else
            local ascender, descender = tfmdata.ascender, tfmdata.descender
            if ascender and descender then
                local ht, dp = ascender or 0, descender or 0
                if value == "height" then
                    dp = 0
                elseif value == "depth" then
                    ht = 0
                end
                if ht > 0 then
                    if dp > 0 then
                        for _,v in next, tfmdata.characters do
                            v.height, v.depth = ht, dp
                        end
                    else
                        for _,v in next, tfmdata.characters do
                            v.height = ht
                        end
                    end
                elseif dp > 0 then
                    for _,v in next, tfmdata.characters do
                        v.depth  = dp
                    end
                end
            end
        end
    end
end

-- -- -- -- -- --
-- shared
-- -- -- -- -- --

local function get_class_and_vector(tfmdata,value,where) -- "expansions"
    local g_where = tfmdata.goodies and tfmdata.goodies[where]
    local f_where = fonts[where]
    local g_classes = g_where and g_where.classes
    local f_classes = f_where and f_where.classes
    local class = (g_classes and g_classes[value]) or (f_classes and f_classes[value])
--~ print(value,class,f_where,f_classes)
    if class then
        local class_vector = class.vector
        local g_vectors = g_where and g_where.vectors
        local f_vectors = f_where and f_where.vectors
        local vector = (g_vectors and g_vectors[class_vector]) or (f_vectors and f_vectors[class_vector])
        return class, vector
    end
end

-- -- -- -- -- --
-- expansion (hz)
-- -- -- -- -- --

fonts.expansions   = allocate()
local expansions   = fonts.expansions

expansions.classes = allocate()
local classes      = expansions.classes

expansions.vectors = allocate()
local vectors      = expansions.vectors

-- beware, pdftex itself uses percentages * 10

classes.preset = { stretch = 2, shrink = 2, step = .5, factor = 1 }

function commands.setupfontexpansion(class,settings)
    getparameters(classes,class,'preset',settings)
end

classes['quality'] = {
    stretch = 2, shrink = 2, step = .5, vector = 'default', factor = 1
}

vectors['default'] = {
    [byte('A')] = 0.5, [byte('B')] = 0.7, [byte('C')] = 0.7, [byte('D')] = 0.5, [byte('E')] = 0.7,
    [byte('F')] = 0.7, [byte('G')] = 0.5, [byte('H')] = 0.7, [byte('K')] = 0.7, [byte('M')] = 0.7,
    [byte('N')] = 0.7, [byte('O')] = 0.5, [byte('P')] = 0.7, [byte('Q')] = 0.5, [byte('R')] = 0.7,
    [byte('S')] = 0.7, [byte('U')] = 0.7, [byte('W')] = 0.7, [byte('Z')] = 0.7,
    [byte('a')] = 0.7, [byte('b')] = 0.7, [byte('c')] = 0.7, [byte('d')] = 0.7, [byte('e')] = 0.7,
    [byte('g')] = 0.7, [byte('h')] = 0.7, [byte('k')] = 0.7, [byte('m')] = 0.7, [byte('n')] = 0.7,
    [byte('o')] = 0.7, [byte('p')] = 0.7, [byte('q')] = 0.7, [byte('s')] = 0.7, [byte('u')] = 0.7,
    [byte('w')] = 0.7, [byte('z')] = 0.7,
    [byte('2')] = 0.7, [byte('3')] = 0.7, [byte('6')] = 0.7, [byte('8')] = 0.7, [byte('9')] = 0.7,
}

vectors['quality'] = vectors['default'] -- metatable ?

function initializers.common.expansion(tfmdata,value)
    if value then
        local class, vector = get_class_and_vector(tfmdata,value,"expansions")
        if class then
            if vector then
                local stretch, shrink, step, factor = class.stretch or 0, class.shrink or 0, class.step or 0, class.factor or 1
                if trace_expansion then
                    report_fonts("set expansion class %s, vector: %s, factor: %s, stretch: %s, shrink: %s, step: %s",
                        value,class.vector,factor,stretch,shrink,step)
                end
                tfmdata.stretch, tfmdata.shrink, tfmdata.step, tfmdata.auto_expand = stretch * 10, shrink * 10, step * 10, true
                local data = characters and characters.data
                for i, chr in next, tfmdata.characters do
                    local v = vector[i]
                    if data and not v then -- we could move the data test outside (needed for plain)
                        local d = data[i]
                        if d then
                            local s = d.shcode
                            if not s then
                                -- sorry
                            elseif type(s) == "table" then
                                v = ((vector[s[1]] or 0) + (vector[s[#s]] or 0)) / 2
                            else
                                v = vector[s] or 0
                            end
                        end
                    end
                    if v and v ~= 0 then
                        chr.expansion_factor = v*factor
                    else -- can be option
                        chr.expansion_factor = factor
                    end
                end
            elseif trace_expansion then
                report_fonts("unknown expansion vector '%s' in class '%s",class.vector,value)
            end
        elseif trace_expansion then
            report_fonts("unknown expansion class '%s'",value)
        end
    end
end

table.insert(manipulators,"expansion")

initializers.base.otf.expansion = initializers.common.expansion
initializers.node.otf.expansion = initializers.common.expansion

initializers.base.afm.expansion = initializers.common.expansion
initializers.node.afm.expansion = initializers.common.expansion

fonts.goodies.register("expansions",  function(...) return fonts.goodies.report("expansions", trace_expansion, ...) end)

local report_opbd = logs.new("otf opbd")

-- -- -- -- -- --
-- protrusion
-- -- -- -- -- --

fonts.protrusions   = allocate()
local protrusions   = fonts.protrusions

protrusions.classes = allocate()
protrusions.vectors = allocate()

local classes       = protrusions.classes
local vectors       = protrusions.vectors

-- the values need to be revisioned

classes.preset = { factor = 1, left = 1, right = 1 }

function commands.setupfontprotrusion(class,settings)
    getparameters(classes,class,'preset',settings)
end

classes['pure'] = {
    vector = 'pure', factor = 1
}
classes['punctuation'] = {
    vector = 'punctuation', factor = 1
}
classes['alpha'] = {
    vector = 'alpha', factor = 1
}
classes['quality'] = {
    vector = 'quality', factor = 1
}

vectors['pure'] = {

    [0x002C] = { 0, 1    }, -- comma
    [0x002E] = { 0, 1    }, -- period
    [0x003A] = { 0, 1    }, -- colon
    [0x003B] = { 0, 1    }, -- semicolon
    [0x002D] = { 0, 1    }, -- hyphen
    [0x00AD] = { 0, 1    }, -- also hyphen
    [0x2013] = { 0, 0.50 }, -- endash
    [0x2014] = { 0, 0.33 }, -- emdash
    [0x3001] = { 0, 1    }, -- ideographic comma      、
    [0x3002] = { 0, 1    }, -- ideographic full stop  。
    [0x060C] = { 0, 1    }, -- arabic comma           ،
    [0x061B] = { 0, 1    }, -- arabic semicolon       ؛
    [0x06D4] = { 0, 1    }, -- arabic full stop       ۔

}

vectors['punctuation'] = {

    [0x003F] = { 0,    0.20 }, -- ?
    [0x00BF] = { 0,    0.20 }, -- ¿
    [0x0021] = { 0,    0.20 }, -- !
    [0x00A1] = { 0,    0.20 }, -- ¡
    [0x0028] = { 0.05, 0    }, -- (
    [0x0029] = { 0,    0.05 }, -- )
    [0x005B] = { 0.05, 0    }, -- [
    [0x005D] = { 0,    0.05 }, -- ]
    [0x002C] = { 0,    0.70 }, -- comma
    [0x002E] = { 0,    0.70 }, -- period
    [0x003A] = { 0,    0.50 }, -- colon
    [0x003B] = { 0,    0.50 }, -- semicolon
    [0x002D] = { 0,    0.70 }, -- hyphen
    [0x00AD] = { 0,    0.70 }, -- also hyphen
    [0x2013] = { 0,    0.30 }, -- endash
    [0x2014] = { 0,    0.20 }, -- emdash
    [0x060C] = { 0,    0.70 }, -- arabic comma
    [0x061B] = { 0,    0.50 }, -- arabic semicolon
    [0x06D4] = { 0,    0.70 }, -- arabic full stop
    [0x061F] = { 0,    0.20 }, -- ؟

    -- todo: left and right quotes: .5 double, .7 single

    [0x2039] = { 0.70, 0.70 }, -- left single guillemet   ‹
    [0x203A] = { 0.70, 0.70 }, -- right single guillemet  ›
    [0x00AB] = { 0.50, 0.50 }, -- left guillemet          «
    [0x00BB] = { 0.50, 0.50 }, -- right guillemet         »

    [0x2018] = { 0.70, 0.70 }, -- left single quotation mark             ‘
    [0x2019] = { 0,    0.70 }, -- right single quotation mark            ’
    [0x201A] = { 0.70, 0    }, -- single low-9 quotation mark            ,
    [0x201B] = { 0.70, 0    }, -- single high-reversed-9 quotation mark  ‛
    [0x201C] = { 0.50, 0.50 }, -- left double quotation mark             “
    [0x201D] = { 0,    0.50 }, -- right double quotation mark            ”
    [0x201E] = { 0.50, 0    }, -- double low-9 quotation mark            „
    [0x201F] = { 0.50, 0    }, -- double high-reversed-9 quotation mark  ‟

}

vectors['alpha'] = {

    [byte("A")] = { .05, .05 },
    [byte("F")] = {   0, .05 },
    [byte("J")] = { .05,   0 },
    [byte("K")] = {   0, .05 },
    [byte("L")] = {   0, .05 },
    [byte("T")] = { .05, .05 },
    [byte("V")] = { .05, .05 },
    [byte("W")] = { .05, .05 },
    [byte("X")] = { .05, .05 },
    [byte("Y")] = { .05, .05 },

    [byte("k")] = {   0, .05 },
    [byte("r")] = {   0, .05 },
    [byte("t")] = {   0, .05 },
    [byte("v")] = { .05, .05 },
    [byte("w")] = { .05, .05 },
    [byte("x")] = { .05, .05 },
    [byte("y")] = { .05, .05 },

}

vectors['quality'] = table.merged(
    vectors['punctuation'],
    vectors['alpha']
)

-- As this is experimental code, users should not depend on it. The
-- implications are still discussed on the ConTeXt Dev List and we're
-- not sure yet what exactly the spec is (the next code is tested with
-- a gyre font patched by / fea file made by Khaled Hosny). The double
-- trick should not be needed it proper hanging punctuation is used in
-- which case values < 1 can be used.
--
-- preferred (in context, usine vectors):
--
-- \definefontfeature[whatever][default][mode=node,protrusion=quality]
--
-- using lfbd and rtbd, with possibibility to enable only one side :
--
-- \definefontfeature[whocares][default][mode=node,protrusion=yes,  opbd=yes,script=latn]
-- \definefontfeature[whocares][default][mode=node,protrusion=right,opbd=yes,script=latn]
--
-- idem, using multiplier
--
-- \definefontfeature[whocares][default][mode=node,protrusion=2,opbd=yes,script=latn]
-- \definefontfeature[whocares][default][mode=node,protrusion=double,opbd=yes,script=latn]
--
-- idem, using named feature file (less frozen):
--
-- \definefontfeature[whocares][default][mode=node,protrusion=2,opbd=yes,script=latn,featurefile=texgyrepagella-regularxx.fea]

classes['double'] = { -- for testing opbd
    factor = 2, left = 1, right = 1,
}

local function map_opbd_onto_protrusion(tfmdata,value,opbd)
    local characters, descriptions = tfmdata.characters, tfmdata.descriptions
    local otfdata = tfmdata.shared.otfdata
    local singles = otfdata.shared.featuredata.gpos_single
    local script, language = tfmdata.script, tfmdata.language
    local done, factor, left, right = false, 1, 1, 1
    local class = classes[value]
    if class then
        factor = class.factor or 1
        left   = class.left   or 1
        right  = class.right  or 1
    else
        factor = tonumber(value) or 1
    end
    if opbd ~= "right" then
        local validlookups, lookuplist = otf.collectlookups(otfdata,"lfbd",script,language)
        if validlookups then
            for i=1,#lookuplist do
                local lookup = lookuplist[i]
                local data = singles[lookup]
                if data then
                    if trace_protrusion then
                        report_fonts("set left protrusion using lfbd lookup '%s'",lookup)
                    end
                    for k, v in next, data do
                    --  local p = - v[3] / descriptions[k].width-- or 1 ~= 0 too but the same
                        local p = - (v[1] / 1000) * factor * left
                        characters[k].left_protruding = p
                        if trace_protrusion then
                            report_protrusions("lfbd -> %s -> 0x%05X (%s) -> %0.03f (%s)",lookup,k,utfchar(k),p,concat(v," "))
                        end
                    end
                    done = true
                end
            end
        end
    end
    if opbd ~= "left" then
        local validlookups, lookuplist = otf.collectlookups(otfdata,"rtbd",script,language)
        if validlookups then
            for i=1,#lookuplist do
                local lookup = lookuplist[i]
                local data = singles[lookup]
                if data then
                    if trace_protrusion then
                        report_fonts("set right protrusion using rtbd lookup '%s'",lookup)
                    end
                    for k, v in next, data do
                    --  local p = v[3] / descriptions[k].width -- or 3
                        local p = (v[1] / 1000) * factor * right
                        characters[k].right_protruding = p
                        if trace_protrusion then
                            report_protrusions("rtbd -> %s -> 0x%05X (%s) -> %0.03f (%s)",lookup,k,utfchar(k),p,concat(v," "))
                        end
                    end
                end
                done = true
            end
        end
    end
    tfmdata.auto_protrude = done
end

-- The opbd test is just there because it was discussed on the
-- context development list. However, the mentioned fxlbi.otf font
-- only has some kerns for digits. So, consider this feature not
-- supported till we have a proper test font.

function initializers.common.protrusion(tfmdata,value)
    if value then
        local opbd = tfmdata.shared.features.opbd
        if opbd then
            -- possible values: left right both yes no (experimental)
            map_opbd_onto_protrusion(tfmdata,value,opbd)
        else
            local class, vector = get_class_and_vector(tfmdata,value,"protrusions")
            if class then
                if vector then
                    local factor = class.factor or 1
                    local left   = class.left   or 1
                    local right  = class.right  or 1
                    if trace_protrusion then
                        report_fonts("set protrusion class %s, vector: %s, factor: %s, left: %s, right: %s",
                            value,class.vector,factor,left,right)
                    end
                    local data = characters.data
                    local emwidth = tfmdata.parameters.quad
                    tfmdata.auto_protrude = true
                    for i, chr in next, tfmdata.characters do
                        local v, pl, pr = vector[i], nil, nil
                        if v then
                            pl, pr = v[1], v[2]
                        else
                            local d = data[i]
                            if d then
                                local s = d.shcode
                                if not s then
                                    -- sorry
                                elseif type(s) == "table" then
                                    local vl, vr = vector[s[1]], vector[s[#s]]
                                    if vl then pl = vl[1] end
                                    if vr then pr = vr[2] end
                                else
                                    v = vector[s]
                                    if v then
                                        pl, pr = v[1], v[2]
                                    end
                                end
                            end
                        end
                        if pl and pl ~= 0 then
                            chr.left_protruding  = left *pl*factor
                        end
                        if pr and pr ~= 0 then
                            chr.right_protruding = right*pr*factor
                        end
                    end
                elseif trace_protrusion then
                    report_fonts("unknown protrusion vector '%s' in class '%s",class.vector,value)
                end
            elseif trace_protrusion then
                report_fonts("unknown protrusion class '%s'",value)
            end
        end
    end
end

table.insert(manipulators,"protrusion")

initializers.base.otf.protrusion = initializers.common.protrusion
initializers.node.otf.protrusion = initializers.common.protrusion

initializers.base.afm.protrusion = initializers.common.protrusion
initializers.node.afm.protrusion = initializers.common.protrusion

fonts.goodies.register("protrusions", function(...) return fonts.goodies.report("protrusions", trace_protrusion, ...) end)

-- -- --

function initializers.common.nostackmath(tfmdata,value)
    tfmdata.ignore_stack_math = value
end

table.insert(manipulators,"nostackmath")

initializers.base.otf.nostackmath = initializers.common.nostackmath
initializers.node.otf.nostackmath = initializers.common.nostackmath

table.insert(triggers,"itlc")

function initializers.common.itlc(tfmdata,value)
    if value then
        -- the magic 40 and it formula come from Dohyun Kim
        local fontdata = tfmdata.shared.otfdata or tfmdata.shared.afmdata
        local metadata = fontdata and fontdata.metadata
        if metadata then
            local italicangle = metadata.italicangle
            if italicangle and italicangle ~= 0 then
                local uwidth = (metadata.uwidth or 40)/2
                for unicode, d in next, tfmdata.descriptions do
                    local it = d.boundingbox[3] - d.width + uwidth
                    if it ~= 0 then
                        d.italic = it
                    end
                end
                tfmdata.has_italic = true
            end
        end
    end
end

initializers.base.otf.itlc = initializers.common.itlc
initializers.node.otf.itlc = initializers.common.itlc

initializers.base.afm.itlc = initializers.common.itlc
initializers.node.afm.itlc = initializers.common.itlc

-- slanting

table.insert(triggers,"slant")

function initializers.common.slant(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  1 then
        value =  1
    elseif value < -1 then
        value = -1
    end
    tfmdata.slant_factor = value
end

initializers.base.otf.slant = initializers.common.slant
initializers.node.otf.slant = initializers.common.slant

initializers.base.afm.slant = initializers.common.slant
initializers.node.afm.slant = initializers.common.slant

table.insert(triggers,"extend")

function initializers.common.extend(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  10 then
        value =  10
    elseif value < -10 then
        value = -10
    end
    tfmdata.extend_factor = value
end

initializers.base.otf.extend = initializers.common.extend
initializers.node.otf.extend = initializers.common.extend

initializers.base.afm.extend = initializers.common.extend
initializers.node.afm.extend = initializers.common.extend

-- historic stuff, move from font-ota

local delete_node = nodes.delete
local fontdata    = fonts.identifiers

local nodecodes  = nodes.nodecodes
local glyph_code = nodecodes.glyph

fonts.strippables = fonts.strippables or { -- just a placeholder
    [0x200C] = true, -- zwnj
    [0x200D] = true, -- zwj
}

local strippables = fonts.strippables

local function processformatters(head,font)
    local how = fontdata[font].shared.features.formatters
    if how == nil or how == "strip" then -- nil when forced
        local current, done = head, false
        while current do
            if current.id == glyph_code and current.subtype<256 and current.font == font then
                local char = current.char
                if strippables[char] then
                    head, current = delete_node(head,current)
                    done = true
                else
                    current = current.next
                end
            else
                current = current.next
            end
        end
        return head, done
    else
        return head, false
    end
end

methods.node.otf.formatters = processformatters
methods.base.otf.formatters = processformatters

otf.tables.features['formatters'] = 'Hide Formatting Characters'

otf.features.register("formatters")

table.insert(manipulators,"formatters") -- at end
