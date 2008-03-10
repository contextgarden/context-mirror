if not modules then modules = { } end modules ['font-ext'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex and hand-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte = string.byte

-- -- -- -- -- --
-- expansion (hz)
-- -- -- -- -- --

fonts.expansions         = fonts.expansions         or { }
fonts.expansions.classes = fonts.expansions.classes or { }
fonts.expansions.vectors = fonts.expansions.vectors or { }

-- beware, pdftex itself uses percentages * 10

fonts.expansions.classes.preset = { stretch = 2, shrink = 2, step = .5, factor = 1 }

function commands.setupfontexpansion(class,settings)
    aux.getparameters(fonts.expansions.classes,class,'preset',settings)
end

fonts.expansions.classes['quality'] = {
    stretch = 2, shrink = 2, step = .5, vector = 'default', factor = 1
}

fonts.expansions.vectors['default'] = {
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

function fonts.initializers.common.expansion(tfmdata,value)
    if value then
        local class = fonts.expansions.classes[value]
        if class then
            local vector = fonts.expansions.vectors[class.vector]
            if vector then
                tfmdata.stretch = (class.stretch or 0) * 10
                tfmdata.shrink = (class.shrink  or 0) * 10
                tfmdata.step = (class.step or 0) * 10
                tfmdata.auto_expand = true
                local factor = class.factor or 1
                local data = characters.data
                for i, chr in pairs(tfmdata.characters) do
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

fonts.initializers.base.otf.expansion = fonts.initializers.common.expansion
fonts.initializers.node.otf.expansion = fonts.initializers.common.expansion

fonts.initializers.base.afm.expansion = fonts.initializers.common.expansion
fonts.initializers.node.afm.expansion = fonts.initializers.common.expansion

-- -- -- -- -- --
-- protrusion
-- -- -- -- -- --

fonts.protrusions         = fonts.protrusions         or { }
fonts.protrusions.classes = fonts.protrusions.classes or { }
fonts.protrusions.vectors = fonts.protrusions.vectors or { }

-- the values need to be revisioned

fonts.protrusions.classes.preset = { factor = 1 }

function commands.setupfontprotrusion(class,settings)
    aux.getparameters(fonts.protrusions.classes,class,'preset',settings)
end

fonts.protrusions.classes['pure'] = {
    vector = 'pure', factor = 1
}
fonts.protrusions.classes['punctuation'] = {
    vector = 'punctuation', factor = 1
}
fonts.protrusions.classes['alpha'] = {
    vector = 'alpha', factor = 1
}
fonts.protrusions.classes['quality'] = {
    vector = 'quality', factor = 1
}

fonts.protrusions.vectors['pure'] = {

    [0x002C] = { 0, 1    }, -- comma
    [0x002E] = { 0, 1    }, -- period
    [0x003A] = { 0, 1    }, -- colon
    [0x003B] = { 0, 1    }, -- semicolon
    [0x002D] = { 0, 1    }, -- hyphen
    [0x2013] = { 0, 0.50 }, -- endash
    [0x2014] = { 0, 0.33 }, -- emdash

}

fonts.protrusions.vectors['punctuation'] = {

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

    -- todo: left and right quotes: .5 double, .7 single

}

fonts.protrusions.vectors['alpha'] = {

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

fonts.protrusions.vectors['quality'] = table.merge( {},
    fonts.protrusions.vectors['punctuation'],
    fonts.protrusions.vectors['alpha']
)

function fonts.initializers.common.protrusion(tfmdata,value)
    if value then
        local class = fonts.protrusions.classes[value]
        if class then
            local vector = fonts.protrusions.vectors[class.vector]
            if vector then
                local factor = class.factor or 1
                local data = characters.data
                local emwidth = tfmdata.parameters[6]
                for i, chr in pairs(tfmdata.characters) do
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

fonts.initializers.base.otf.protrusion = fonts.initializers.common.protrusion
fonts.initializers.node.otf.protrusion = fonts.initializers.common.protrusion

fonts.initializers.base.afm.protrusion = fonts.initializers.common.protrusion
fonts.initializers.node.afm.protrusion = fonts.initializers.common.protrusion
