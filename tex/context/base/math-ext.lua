if not modules then modules = { } end modules ['math-ext'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_virtual = false trackers.register("math.virtual", function(v) trace_virtual = v end)

local mathematics = mathematics
local characters  = characters

local report_math = logs.reporter("mathematics")

mathematics.extras = mathematics.extras or { }
local extras       = mathematics.extras

characters.math    = characters.math or { }
local mathdata     = characters.math
local chardata     = characters.data

function extras.add(unicode,t)
    local min, max = mathematics.extrabase, mathematics.privatebase - 1
    if unicode >= min and unicode <= max then
        mathdata[unicode], chardata[unicode] = t, t
    else
        report_math("extra U+%05X should be in range U+%05X - U+%05X",unicode,min,max)
    end
end

function extras.copy(target,original)
    local characters = target.characters
    local properties = target.properties
    local parameters = target.parameters
    for unicode, extradesc in next, mathdata do
        -- always, because in an intermediate step we can have a non math font
        local extrachar = characters[unicode]
        local nextinsize = extradesc.nextinsize
        if nextinsize then
            for i=1,#nextinsize do
                local nextslot = nextinsize[i]
                local nextbase = characters[nextslot]
                if nextbase then
                    local nextnext = nextbase and nextbase.next
                    if nextnext then
                        local nextchar = characters[nextnext]
                        if nextchar then
                            if trace_virtual then
                                report_math("extra U+%05X in %s at %s maps on U+%05X (class: %s, name: %s)",unicode,
                                    file.basename(properties.fullname),parameters.size,nextslot,extradesc.mathclass or "?",extradesc.mathname or "?")
                            end
                            characters[unicode] = nextchar
                            break
                        end
                    end
                end
            end
            if not characters[unicode] then -- can be set in previous loop
                for i=1,#nextinsize do
                    local nextslot = nextinsize[i]
                    local nextbase = characters[nextslot]
                    if nextbase then
                        characters[unicode] = nextbase -- still ok?
                        break
                    end
                end
            end
        end
    end
end

utilities.sequencers.appendaction(mathactions,"system","mathematics.extras.copy")

-- 0xFE302 -- 0xFE320 for accents

extras.add(0xFE302, {
    category="mn",
    description="WIDE MATHEMATICAL HAT",
    direction="nsm",
    linebreak="cm",
    mathclass="accent",
    mathname="widehat",
    mathstretch="h",
    unicodeslot=0xFE302,
    nextinsize={ 0x00302, 0x0005E },
} )

extras.add(0xFE303, {
    category="mn",
    cjkwd="a",
    description="WIDE MATHEMATICAL TILDE",
    direction="nsm",
    linebreak="cm",
    mathclass="accent",
    mathname="widetilde",
    mathstretch="h",
    unicodeslot=0xFE303,
    nextinsize={ 0x00303, 0x0007E },
} )

-- 0xFE321 -- 0xFE340 for missing characters

extras.add(0xFE321, {
    category="sm",
    description="MATHEMATICAL SHORT BAR",
--  direction="on",
--  linebreak="nu",
    mathclass="relation",
    mathname="mapstochar",
    unicodeslot=0xFE321,
} )

extras.add(0xFE322, {
    category="sm",
    description="MATHEMATICAL LEFT HOOK",
    mathclass="relation",
    mathname="lhook",
    unicodeslot=0xFE322,
} )

extras.add(0xFE323, {
    category="sm",
    description="MATHEMATICAL RIGHT HOOK",
    mathclass="relation",
    mathname="rhook",
    unicodeslot=0xFE323,
} )

extras.add(0xFE324, {
    category="sm",
    description="MATHEMATICAL SHORT BAR MIRRORED",
--  direction="on",
--  linebreak="nu",
    mathclass="relation",
    mathname="mapsfromchar",
    unicodeslot=0xFE324,
} )

--~ extras.add(0xFE304, {
--~   category="sm",
--~   description="TOP AND BOTTOM PARENTHESES",
--~   direction="on",
--~   linebreak="al",
--~   mathclass="doubleaccent",
--~   mathname="doubleparent",
--~   unicodeslot=0xFE304,
--~   accents={ 0x023DC, 0x023DD },
--~ } )

--~ extras.add(0xFE305, {
--~   category="sm",
--~   description="TOP AND BOTTOM BRACES",
--~   direction="on",
--~   linebreak="al",
--~   mathclass="doubleaccent",
--~   mathname="doublebrace",
--~   unicodeslot=0xFE305,
--~   accents={ 0x023DE, 0x023DF },
--~ } )

--~ \Umathchardef\braceld="0 "1 "FF07A
--~ \Umathchardef\bracerd="0 "1 "FF07B
--~ \Umathchardef\bracelu="0 "1 "FF07C
--~ \Umathchardef\braceru="0 "1 "FF07D
