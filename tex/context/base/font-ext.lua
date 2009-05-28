if not modules then modules = { } end modules ['font-ext'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex and hand-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type, byte = next, type, string.byte

--[[ldx--
<p>When we implement functions that deal with features, most of them
will depend of the font format. Here we define the few that are kind
of neutral.</p>
--ldx]]--

fonts.triggers            = fonts.triggers            or { }
fonts.initializers        = fonts.initializers        or { }
fonts.initializers.common = fonts.initializers.common or { }

local initializers = fonts.initializers

--[[ldx--
<p>This feature will remove inter-digit kerns.</p>
--ldx]]--

table.insert(fonts.triggers,"equaldigits")

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

table.insert(fonts.triggers,"lineheight")

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

--[[ldx--
<p>It does not make sense any more to support messed up encoding vectors
so we stick to those that implement oldstyle and small caps. After all,
we move on. We can extend the next function on demand. This features is
only used with <l n='afm'/> files.</p>
--ldx]]--

--~ do
--~
--~     local smallcaps = lpeg.P(".sc") + lpeg.P(".smallcaps") + lpeg.P(".caps") + lpeg.P("small")
--~     local oldstyle  = lpeg.P(".os") + lpeg.P(".oldstyle")  + lpeg.P(".onum")
--~
--~     smallcaps = lpeg.Cs((1-smallcaps)^1) * smallcaps^1
--~     oldstyle  = lpeg.Cs((1-oldstyle )^1) * oldstyle ^1
--~
--~     function initializers.common.encoding(tfmdata,value)
--~         if value then
--~             local afmdata = tfmdata.shared.afmdata
--~             if afmdata then
--~                 local encodingfile = value .. '.enc'
--~                 local encoding = fonts.enc.load(encodingfile)
--~                 if encoding then
--~                     local vector = encoding.vector
--~                     local characters = tfmdata.characters
--~                     local unicodes = afmdata.luatex.unicodes
--~                     local function remap(pattern,name)
--~                         local p = pattern:match(name)
--~                         if p then
--~                             local oldchr, newchr = unicodes[p], unicodes[name]
--~                             if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
--~                              -- logs.report("encoding","%s (%s) -> %s (%s)",p,oldchr or -1,name,newchr or -1)
--~                                 characters[oldchr] = characters[newchr]
--~                             end
--~                         end
--~                         return p
--~                     end
--~                     for _, name in next, vector do
--~                         local ok = remap(smallcaps,name) or remap(oldstyle,name)
--~                     end
--~                     if fonts.map.data[tfmdata.name] then
--~                         fonts.map.data[tfmdata.name].encoding = encodingfile
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~
--~     -- when needed we can provide this as features in e.g. afm files
--~
--~     function initializers.common.remap(tfmdata,value,pattern) -- will go away
--~         if value then
--~             local afmdata = tfmdata.shared.afmdata
--~             if afmdata then
--~                 local characters = tfmdata.characters
--~                 local descriptions = tfmdata.descriptions
--~                 local unicodes = afmdata.luatex.unicodes
--~                 local done = false
--~                 for u, _ in next, characters do
--~                     local name = descriptions[u].name
--~                     if name then
--~                         local p = pattern:match(name)
--~                         if p then
--~                             local oldchr, newchr = unicodes[p], unicodes[name]
--~                             if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
--~                                 characters[oldchr] = characters[newchr]
--~                             end
--~                         end
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~
--~     function initializers.common.oldstyle(tfmdata,value)
--~         initializers.common.remap(tfmdata,value,oldstyle)
--~     end
--~     function initializers.common.smallcaps(tfmdata,value)
--~         initializers.common.remap(tfmdata,value,smallcaps)
--~     end
--~
--~     function initializers.common.fakecaps(tfmdata,value)
--~         if value then
--~             -- todo: scale down
--~             local afmdata = tfmdata.shared.afmdata
--~             if afmdata then
--~                 local characters = tfmdata.characters
--~                 local descriptions = tfmdata.descriptions
--~                 local unicodes = afmdata.luatex.unicodes
--~                 for u, _ in next, characters do
--~                     local name = descriptions[u].name
--~                     if name then
--~                         local p = lower(name)
--~                         if p then
--~                             local oldchr, newchr = unicodes[p], unicodes[name]
--~                             if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
--~                                 characters[oldchr] = characters[newchr]
--~                             end
--~                         end
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~
--~ end
--~
--~ function initializers.common.install(format,feature) -- 'afm','lineheight'
--~     initializers.base[format][feature] = initializers.common[feature]
--~     initializers.node[format][feature] = initializers.common[feature]
--~ end

-- -- -- -- -- --
-- expansion (hz)
-- -- -- -- -- --

fonts.expansions         = fonts.expansions         or { }
fonts.expansions.classes = fonts.expansions.classes or { }
fonts.expansions.vectors = fonts.expansions.vectors or { }

local expansions = fonts.expansions
local classes    = fonts.expansions.classes
local vectors    = fonts.expansions.vectors

-- beware, pdftex itself uses percentages * 10

classes.preset = { stretch = 2, shrink = 2, step = .5, factor = 1 }

function commands.setupfontexpansion(class,settings)
    aux.getparameters(classes,class,'preset',settings)
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

function initializers.common.expansion(tfmdata,value)
    if value then
        local class = classes[value]
        if class then
            local vector = vectors[class.vector]
            if vector then
                tfmdata.stretch = (class.stretch or 0) * 10
                tfmdata.shrink = (class.shrink  or 0) * 10
                tfmdata.step = (class.step or 0) * 10
                tfmdata.auto_expand = true
                local factor = class.factor or 1
                local data = characters.data
                for i, chr in next, tfmdata.characters do
                    local v = vector[i]
                    if not v then
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
            end
        end
    end
end

table.insert(fonts.manipulators,"expansion")

initializers.base.otf.expansion = initializers.common.expansion
initializers.node.otf.expansion = initializers.common.expansion

initializers.base.afm.expansion = initializers.common.expansion
initializers.node.afm.expansion = initializers.common.expansion

-- -- -- -- -- --
-- protrusion
-- -- -- -- -- --

fonts.protrusions         = fonts.protrusions         or { }
fonts.protrusions.classes = fonts.protrusions.classes or { }
fonts.protrusions.vectors = fonts.protrusions.vectors or { }

local protrusions = fonts.protrusions
local classes     = fonts.protrusions.classes
local vectors     = fonts.protrusions.vectors

-- the values need to be revisioned

classes.preset = { factor = 1 }

function commands.setupfontprotrusion(class,settings)
    aux.getparameters(classes,class,'preset',settings)
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

vectors['quality'] = table.merge( {},
    vectors['punctuation'],
    vectors['alpha']
)

function initializers.common.protrusion(tfmdata,value)
    if value then
        local class = classes[value]
        if class then
            local vector = vectors[class.vector]
            if vector then
                local factor = class.factor or 1
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
                    if pl and pl ~= 0 then chr.left_protruding  = pl*factor end
                    if pr and pr ~= 0 then chr.right_protruding = pr*factor end
                end
            end
        end
    end
end

table.insert(fonts.manipulators,"protrusion")

initializers.base.otf.protrusion = initializers.common.protrusion
initializers.node.otf.protrusion = initializers.common.protrusion

initializers.base.afm.protrusion = initializers.common.protrusion
initializers.node.afm.protrusion = initializers.common.protrusion

function initializers.common.nostackmath(tfmdata,value)
    tfmdata.ignore_stack_math = value
end

table.insert(fonts.manipulators,"nostackmath")

initializers.base.otf.nostackmath = initializers.common.nostackmath
initializers.node.otf.nostackmath = initializers.common.nostackmath

table.insert(fonts.triggers,"itlc")

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
