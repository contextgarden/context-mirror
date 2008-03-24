if not modules then modules = { } end modules ['math-ini'] = {
    version   = 1.001,
    comment   = "companion to math-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


--[[ldx--
<p>Math definitions. This code may move.</p>
--ldx]]--

-- if needed we can use the info here to set up xetex definition files
-- the "8000 hackery influences direct characters (utf) as indirect \char's

mathematics       = mathematics       or { }
mathematics.data  = mathematics.data  or { }
mathematics.slots = mathematics.slots or { }

mathematics.classes = {
    ord     = 0,  -- mathordcomm     mathord
    op      = 1,  -- mathopcomm      mathop
    bin     = 2,  -- mathbincomm     mathbin
    rel     = 3,  -- mathrelcomm     mathrel
    open    = 4,  -- mathopencomm    mathopen
    close   = 5,  -- mathclosecomm   mathclose
    punct   = 6,  -- mathpunctcomm   mathpunct
    alpha   = 7,  -- mathalphacomm   firstofoneargument
    accent  = 8,
    radical = 9,
    inner   = 0,  -- mathinnercomm   mathinner
    nothing = 0,  -- mathnothingcomm firstofoneargument
    choice  = 0,  -- mathchoicecomm  @@mathchoicecomm
    box     = 0,  -- mathboxcomm     @@mathboxcomm
    limop   = 1,  -- mathlimopcomm   @@mathlimopcomm
    nolop   = 1,  -- mathnolopcomm   @@mathnolopcomm
}

mathematics.classes.alphabetic  = mathematics.classes.alpha
mathematics.classes.unknown     = mathematics.classes.nothing
mathematics.classes.punctuation = mathematics.classes.punct
mathematics.classes.normal      = mathematics.classes.nothing
mathematics.classes.opening     = mathematics.classes.open
mathematics.classes.closing     = mathematics.classes.close
mathematics.classes.binary      = mathematics.classes.bin
mathematics.classes.relation    = mathematics.classes.rel
mathematics.classes.fence       = mathematics.classes.unknown
mathematics.classes.diacritic   = mathematics.classes.accent
mathematics.classes.large       = mathematics.classes.op
mathematics.classes.variable    = mathematics.classes.alphabetic
mathematics.classes.number      = mathematics.classes.nothing

mathematics.families = {
    mr = 0, bs  =  8,
    mi = 1, bi  =  9,
    sy = 2, sc  = 10,
    ex = 3, tf  = 11,
    it = 4, ma  = 12,
    sl = 5, mb  = 13,
    bf = 6, mc  = 14,
    nn = 7, md  = 15,
}

mathematics.families.letters   = mathematics.families.mr
mathematics.families.numbers   = mathematics.families.mr
mathematics.families.variables = mathematics.families.mi
mathematics.families.operators = mathematics.families.sy
mathematics.families.lcgreek   = mathematics.families.mi
mathematics.families.ucgreek   = mathematics.families.mr
mathematics.families.vargreek  = mathematics.families.mi
mathematics.families.mitfamily = mathematics.families.mi
mathematics.families.calfamily = mathematics.families.sy

mathematics.families[0] = mathematics.families.mr
mathematics.families[1] = mathematics.families.mi
mathematics.families[2] = mathematics.families.sy
mathematics.families[3] = mathematics.families.ex

function mathematics.mathcode(target,class,family,slot)
    return ("\\omathcode%s=\"%X%02X%04X"):format(target,class,family,slot)
end
function mathematics.delcode(target,small_family,small_slot,large_family,large_slot)
    return ("\\odelcode%s=\"%02X%04X\"%02X%04X"):format(target,small_family,small_slot,large_family,large_slot)
end
function mathematics.radical(small_family,small_slot,large_family,large_slot)
    return ("\\radical%s=\"%02X%04X%\"02X%04X"):format(target,small_family,small_slot,large_family,large_slot)
end
function mathematics.mathchar(class,family,slot)
    return ("\\omathchar\"%X%02X%04X"):format(class,family,slot)
end
function mathematics.mathaccent(class,family,slot)
    return ("\\omathaccent\"%X%02X%04X"):format(class,family,slot)
end
function mathematics.delimiter(class,family,slot,largefamily,largeslot)
    return ("\\odelimiter\"%X%02X%04X\"%02X%04X"):format(class,family,slot,largefamily,largeslot)
end
function mathematics.mathchardef(name,class,family,slot) -- we can avoid this one
    return ("\\omathchardef\\%s\"%X%02X%04X"):format(name,class,family,slot)
end

function mathematics.setmathsymbol(name,class,family,slot,largefamily,largeslot,unicode)
    class = mathematics.classes[class] or class -- no real checks needed
    family = mathematics.families[family] or family
    -- \unexpanded ? \relax needed for the codes?
    if largefamily and largeslot then
        largefamily = mathematics.families[largefamily] or largefamily
        if class == mathradical then
            tex.sprint(("\\xdef\\%s{%s\\relax}"):format(name,mathematics.radical(class,family,slot,largefamily,largeslot)))
        else
            tex.sprint(("\\xdef\\%s{%s\\relax}"):format(name,mathematics.delimiter(class,family,slot,largefamily,largeslot)))
        end
    elseif class == mathaccent then
        tex.sprint(("\\xdef\\%s{%s\\relax}"):format(name,mathematics.mathaccent(class,family,slot)))
    elseif unicode then
        tex.sprint(("\\xdef\\%s{%s}"):format(name,utf.char(unicode)))
    else
        tex.sprint(mathematics.mathchardef(name,class,family,slot))
    end
end

-- direct sub call

function mathematics.setmathcharacter(target,class,family,slot,largefamily,largeslot)
    class = mathematics.classes[class] or class -- no real checks needed
    family = mathematics.families[family] or family
    if largefamily and largeslot then
        largefamily = mathematics.families[largefamily] or largefamily
        tex.sprint(mathematics.delcode(target,family,slot,largefamily,largeslot))
    else
        tex.sprint(mathematics.mathcode(target,class,family,slot))
    end
end

-- definitions (todo: expand commands to utf instead of codes)

mathematics.trace = false

function mathematics.define()
    local slots = mathematics.slots.current
    local function trace(k,c,f,i,fe,ie)
        if fe then
            logs.report("mathematics",string.format("a - symbol 0x%05X -> %s -> %s %s (%s %s)",k,c,f,i,fe,ie))
        elseif c then
            logs.report("mathematics",string.format("b - symbol 0x%05X -> %s -> %s %s",k,c,f,i))
        else
            logs.report("mathematics",string.format("c - symbol 0x%05X -> %s %s",k,f,i))
        end
    end
    for k,v in pairs(characters.data) do
        local m = v.mathclass
        -- i need to clean this up a bit
        if m then
            local c = v.mathname
            if c == false then
                -- no command
                local s = slots[k]
                if s then
                    local f, i, fe, ie = s[1], s[2], s[3], s[4]
                    if mathematics.trace then
                        trace(k,c,f,i,fe,ie)
                    end
                    mathematics.setmathcharacter(k,m,f,i,fe,ie)
                end
            elseif c then
                local s = slots[k]
                if s then
                    local f, i, fe, ie = s[1], s[2], s[3], s[4]
                    if mathematics.trace then
                        trace(k,c,f,i,fe,ie)
                    end
                    mathematics.setmathsymbol(c,m,f,i,fe,ie,k)
                    mathematics.setmathcharacter(k,m,f,i,fe,ie)
                end
            elseif v.contextname then
                local s = slots[k]
                local c = v.contextname
                if s then
                    local f, i, fe, ie = s[1], s[2], s[3], s[4]
                    if mathematics.trace then
                        trace(k,c,f,i,fe,ie)
                    end
                    -- todo: mathortext
                    -- mathematics.setmathsymbol(c,m,f,i,fe,ie,k)
                    mathematics.setmathcharacter(k,m,f,i,fe,ie)
                end
            else
                local a = v.adobename
                if a and m then
                    local s, f, i, fe, ie = slots[k], nil, nil, nil, nil
                    if s then
                        f, i, fe, ie = s[1], s[2], s[3], s[4]
                    elseif m == "variable" then
                        f, i = mathematics.families.variables, k
                    elseif m == "number" then
                        f, i = mathematics.families.numbers, k
                    end
                    if mathematics.trace then
                        trace(k,a,f,i,fe,ie)
                    end
                    mathematics.setmathcharacter(k,m,f,i,fe,ie)
                end
            end
        end
    end
end

-- temporary here: will become separate

-- maybe we should define a nice virtual font so that we have
-- just the base n families repeated for diferent styles

mathematics.slots.traditional = {

    [0x03B1] = { "lcgreek", 0x0B },
    [0x03B2] = { "lcgreek", 0x0C },
    [0x03B3] = { "lcgreek", 0x0D },
    [0x03B4] = { "lcgreek", 0x0E },
--  [0x03B5] = { "lcgreek", 0x00 }, -- varepsilon
    [0x03B6] = { "lcgreek", 0x10 },
    [0x03B7] = { "lcgreek", 0x11 },
    [0x03B8] = { "lcgreek", 0x12 },
    [0x03B9] = { "lcgreek", 0x13 },
    [0x03BA] = { "lcgreek", 0x14 },
    [0x03BB] = { "lcgreek", 0x15 },
    [0x03BC] = { "lcgreek", 0x16 },
    [0x03BD] = { "lcgreek", 0x17 },
    [0x03BE] = { "lcgreek", 0x18 },
    [0x03BF] = { "lcgreek", 0x6F },
    [0x03C0] = { "lcgreek", 0x19 },
    [0x03C1] = { "lcgreek", 0x1A },
--  [0x03C2] = { "lcgreek", 0x00 }, -- varsigma
    [0x03C3] = { "lcgreek", 0x1B },
    [0x03C4] = { "lcgreek", 0x1C },
    [0x03C5] = { "lcgreek", 0x1D },
    [0x03C6] = { "lcgreek", 0x1E },
    [0x03C7] = { "lcgreek", 0x1F },
    [0x03C8] = { "lcgreek", 0x20 },
    [0x03C9] = { "lcgreek", 0x21 },

    [0x0391] = { "ucgreek", 0x41 },
    [0x0392] = { "ucgreek", 0x42 },
    [0x0393] = { "ucgreek", 0x00 },
    [0x0394] = { "ucgreek", 0x01 },
    [0x0395] = { "ucgreek", 0x45 },
    [0x0396] = { "ucgreek", 0x5A },
    [0x0397] = { "ucgreek", 0x48 },
    [0x0398] = { "ucgreek", 0x02 },
    [0x0399] = { "ucgreek", 0x49 },
    [0x039A] = { "ucgreek", 0x4B },
    [0x039B] = { "ucgreek", 0x03 },
    [0x039C] = { "ucgreek", 0x4D },
    [0x039D] = { "ucgreek", 0x4E },
    [0x039E] = { "ucgreek", 0x04 },
    [0x039F] = { "ucgreek", 0x4F },
    [0x03A0] = { "ucgreek", 0x05 },
    [0x03A1] = { "ucgreek", 0x52 },
    [0x03A3] = { "ucgreek", 0x06 },
    [0x03A4] = { "ucgreek", 0x54 },
    [0x03A5] = { "ucgreek", 0x07 },
    [0x03A6] = { "ucgreek", 0x08 },
    [0x03A7] = { "ucgreek", 0x58 },
    [0x03A8] = { "ucgreek", 0x09 },
    [0x03A9] = { "ucgreek", 0x0A },

    [0x03B5] = { "vargreek", 0x22 }, -- varepsilon
    [0x03D1] = { "vargreek", 0x23 }, -- vartheta
    [0x03D6] = { "vargreek", 0x24 }, -- varpi
    [0x03F1] = { "vargreek", 0x25 }, -- varrho
    [0x03C2] = { "vargreek", 0x26 }, -- varsigma
    [0x03C6] = { "vargreek", 0x27 }, -- varphi
--  [0x03F0] = { "",         0x00 }, -- varkappa

    [0x0021] = { "mr", 0x21 }, -- !
    [0x0028] = { "mr", 0x28 }, -- (
    [0x0029] = { "mr", 0x29 }, -- )
    [0x002A] = { "sy", 0x03 }, -- *
    [0x002B] = { "mr", 0x2B }, -- +
    [0x002C] = { "mi", 0x3B }, -- ,
    [0x002D] = { "sy", 0x00 }, -- -
    [0x2212] = { "sy", 0x00 }, -- -
    [0x002E] = { "mi", 0x3A }, -- .
    [0x002F] = { "mi", 0x3D }, -- /
    [0x003A] = { "mr", 0x3A }, -- :
    [0x003B] = { "mr", 0x3B }, -- ;
    [0x003C] = { "mi", 0x3C }, -- <
    [0x003D] = { "mr", 0x3D }, -- =
    [0x003E] = { "mi", 0x3E }, -- >
    [0x003F] = { "mr", 0x3F }, -- ?
    [0x005C] = { "sy", 0x6E }, -- \
    [0x007B] = { "sy", 0x66 }, -- {
    [0x007C] = { "sy", 0x6A }, -- |
    [0x007D] = { "sy", 0x67 }, -- }
    [0x00B1] = { "sy", 0x06 }, -- pm
    [0x00B7] = { "sy", 0x01 }, -- cdot
    [0x00D7] = { "sy", 0x02 }, -- times
    [0x2022] = { "sy", 0x0F }, -- bullet

    [0x2190] = { "sy", 0x20 }, -- leftarrow
    [0x2192] = { "sy", 0x21 }, -- rightarrow
    [0x2194] = { "sy", 0x24 }, -- leftrightarrow

    [0x21D0] = { "sy", 0x28 }, -- Leftarrow
    [0x21D2] = { "sy", 0x29 }, -- Rightarrow
    [0x21D4] = { "sy", 0x2C }, -- Leftrightarrow

    [0x2135] = { "sy", 0x40 }, -- aleph
    [0x2113] = { "mi", 0x60 }, -- ell

    [0x25B3] = { "sy", 0x34 }, -- triangle up

    [0x1D6A4] = { "mi", 0x7B }, -- imath
    [0x1D6A5] = { "mi", 0x7C }, -- jmath

    [0x0028] = { "mr", 0x28, "ex", 0x00 }, -- (
    [0x0029] = { "mr", 0x29, "ex", 0x01 }, -- )
    [0x002F] = { "mr", 0x2F, "ex", 0x0E }, -- /
    [0x003C] = { "sy", 0x3C, "ex", 0x0A }, -- <
    [0x003E] = { "sy", 0x3E, "ex", 0x0B }, -- >
    [0x005B] = { "mr", 0x5B, "ex", 0x02 }, -- [
    [0x005D] = { "mr", 0x5D, "ex", 0x03 }, -- ]
    [0x007C] = { "sy", 0x6A, "ex", 0x0C }, -- |
    [0x005C] = { "sy", 0x6E, "ex", 0x0F }, -- \

}

mathematics.slots.current = mathematics.slots.traditional

--~ already obsolete
--~
--~ do
--~     local template = "\\catcode%s=13\\gdef %s{\\%s}\\global\\mathcode%s=\"8000\\relax"
--~     function mathematics.traditional()
--~         tex.sprint(tex.ctxcatcodes,"\\begingroup")
--~         for k, v in pairs(mathematics.data) do
--~             if not v.ignore then
--~                 local c = v.contextname
--~                 if c then
--~                     tex.sprint(template:format(k,utf.char(k),c,k))
--~                 end
--~             end
--~         end
--~         tex.sprint(tex.ctxcatcodes,"\\endgroup")
--~     end
--~ end
