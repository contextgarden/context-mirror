if not modules then modules = { } end modules ['s-math-coverage'] = {
    version   = 1.001,
    comment   = "companion to s-math-coverage.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.math          = moduledata.math          or { }
moduledata.math.coverage = moduledata.math.coverage or { }

local utfchar, utfbyte = utf.char, utf.byte
local formatters, lower, upper, find, format = string.formatters, string.lower, string.upper, string.find, string.format
local lpegmatch = lpeg.match
local concat = table.concat

local context = context
local NC, NR, HL = context.NC, context.NR, context.HL
local char, getglyph, bold, getvalue = context.char, context.getglyph, context.bold, context.getvalue

local ucgreek = {
    0x0391, 0x0392, 0x0393, 0x0394, 0x0395,
    0x0396, 0x0397, 0x0398, 0x0399, 0x039A,
    0x039B, 0x039C, 0x039D, 0x039E, 0x039F,
    0x03A0, 0x03A1, 0x03A3, 0x03A4, 0x03A5,
    0x03A6, 0x03A7, 0x03A8, 0x03A9
}

local lcgreek = {
    0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5,
    0x03B6, 0x03B7, 0x03B8, 0x03B9, 0x03BA,
    0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF,
    0x03C0, 0x03C1, 0x03C2, 0x03C3, 0x03C4,
    0x03C5, 0x03C6, 0x03C7, 0x03C8, 0x03C9,
    0x03D1, 0x03D5, 0x03D6, 0x03F0, 0x03F1,
    0x03F4, 0x03F5
}

local ucletters = {
    0x00041, 0x00042, 0x00043, 0x00044, 0x00045,
    0x00046, 0x00047, 0x00048, 0x00049, 0x0004A,
    0x0004B, 0x0004C, 0x0004D, 0x0004E, 0x0004F,
    0x00050, 0x00051, 0x00052, 0x00053, 0x00054,
    0x00055, 0x00056, 0x00057, 0x00058, 0x00059,
    0x0005A,
}

local lcletters = {
    0x00061, 0x00062, 0x00063, 0x00064, 0x00065,
    0x00066, 0x00067, 0x00068, 0x00069, 0x0006A,
    0x0006B, 0x0006C, 0x0006D, 0x0006E, 0x0006F,
    0x00070, 0x00071, 0x00072, 0x00073, 0x00074,
    0x00075, 0x00076, 0x00077, 0x00078, 0x00079,
    0x0007A,
}

local digits = {
    0x00030, 0x00031, 0x00032, 0x00033, 0x00034,
    0x00035, 0x00036, 0x00037, 0x00038, 0x00039,
}

local styles = {
    "regular", "sansserif", "monospaced", "fraktur", "script", "blackboard"
}

local alternatives = {
    "normal", "bold", "italic", "bolditalic"
}

local alphabets = {
    ucletters, lcletters, ucgreek, lcgreek, digits,
}

local getboth        = mathematics.getboth
local remapalphabets = mathematics.remapalphabets

local chardata     = characters.data
local superscripts = characters.superscripts
local subscripts   = characters.subscripts

function moduledata.math.coverage.showalphabets()
    context.starttabulate { "|lT|l|Tl|" }
    for i=1,#styles do
        local style = styles[i]
        for i=1,#alternatives do
            local alternative = alternatives[i]
            for i=1,#alphabets do
                local alphabet = alphabets[i]
                NC()
                    if i == 1 then
                        context("%s %s",style,alternative)
                    end
                NC()
                    context.startimath()
                    context.setmathattribute(style,alternative)
                    for i=1,#alphabet do
                        local letter = alphabet[i]
                        local id = getboth(style,alternative)
                        local unicode = remapalphabets(letter,id)
                        if not unicode then
                            context.underbar(utfchar(letter))
                        elseif unicode == letter then
                            context(utfchar(unicode))
                        else
                            context(utfchar(unicode))
                        end
                    end
                    context.stopimath()
                NC()
                    local first = alphabet[1]
                    local last = alphabet[#alphabet]
                    local id = getboth(style,alternative)
                    local f_unicode = remapalphabets(first,id) or utfbyte(first)
                    local l_unicode = remapalphabets(last,id) or utfbyte(last)
                    context("%05X - %05X",f_unicode,l_unicode)
                NC()
                NR()
            end
        end
    end
    context.stoptabulate()
end

function moduledata.math.coverage.showcharacters()
    context.startcolumns()
    context.setupalign { "nothyphenated" }
    context.starttabulate { "|T|i2|Tpl|" }
    for u, d in table.sortedpairs(chardata) do
        local mathclass = d.mathclass
        local mathspec = d.mathspec
        if mathclass or mathspec then
            NC()
                context("%05X",u)
            NC()
                getglyph("MathRoman",u)
            NC()
                if mathspec then
                    local t = { }
                    for i=1,#mathspec do
                        t[mathspec[i].class] = true
                    end
                    t = table.sortedkeys(t)
                    context("% t",t)
                else
                    context(mathclass)
                end
            NC()
            NR()
        end
    end
    context.stoptabulate()
    context.stopcolumns()
end

-- This is a somewhat tricky table as we need to bypass the math machinery.

function moduledata.math.coverage.showscripts()
    context.starttabulate { "|cT|c|cT|c|c|c|l|" }
    for k, v in table.sortedpairs(table.merged(superscripts,subscripts)) do
        local ck = utfchar(k)
        local cv = utfchar(v)
        local ss = superscripts[k] and "^" or "_"
        NC()
            context("%05X",k)
        NC()
            context(ck)
        NC()
            context("%05X",v)
        NC()
            context(cv)
        NC()
            context.formatted.rawmathematics("x%s = x%s%s",ck,ss,cv)
        NC()
            context.formatted.mathematics("x%s = x%s%s",ck,ss,cv)
        NC()
            context(lower(chardata[k].description))
        NC()
        NR()
    end
    context.stoptabulate()
end

function moduledata.math.coverage.showcomparison(specification)

    specification = interfaces.checkedspecification(specification)

    local fontfiles = utilities.parsers.settings_to_array(specification.list or "")
    local pattern   = upper(specification.pattern or "")

    local present = { }
    local names   = { }
    local files   = { }

    if not pattern then
        -- skip
    elseif pattern == "" then
        pattern = nil
    elseif tonumber(pattern) then
        pattern = tonumber(pattern)
    else
        pattern = lpeg.oneof(utilities.parsers.settings_to_array(pattern))
        pattern = (1-pattern)^0 * pattern
    end

    for i=1,#fontfiles do
        local fontname = format("testfont-%s",i)
        local fontfile = fontfiles[i]
        local fontsize = tex.dimen.bodyfontsize
        local id, fontdata = fonts.definers.define {
            name = fontfile,
            size = fontsize,
            cs   = fontname,
        }
        if id and fontdata then
            for k, v in next, fontdata.characters do
                present[k] = true
            end
            names[#names+1] = fontname
            files[#files+1] = fontfile
        end
    end

    local t = { }

    context.starttabulate { "|Tr" .. string.rep("|l",#names) .. "|" }
    for i=1,#files do
        local file = files[i]
        t[#t+1] = i .. "=" .. file
        NC()
            context(i)
        NC()
            context(file)
        NC()
        NR()
    end
    context.stoptabulate()

    context.setupfootertexts {
        table.concat(t," ")
    }

    context.starttabulate { "|Tl" .. string.rep("|c",#names) .. "|Tl|" }
    NC()
    bold("unicode")
    NC()
    for i=1,#names do
        bold(i)
        NC()
    end
    bold("description")
    NC()
    NR()
    HL()
    for k, v in table.sortedpairs(present) do
        if k > 0 then
            local description = chardata[k].description
            if not pattern or (pattern == k) or (description and lpegmatch(pattern,description)) then
                NC()
                    context("%05X",k)
                NC()
                for i=1,#names do
                    getvalue(names[i])
                    char(k)
                    NC()
                end
                    context(description)
                NC()
                NR()
            end
        end
    end
    context.stoptabulate()

end
