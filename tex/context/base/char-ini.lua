if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tex = tex or { }
xml = xml or { }

local format, texsprint, utfchar, utfbyte, concat = string.format, tex.sprint, unicode.utf8.char, unicode.utf8.byte, table.concat

--[[ldx--
<p>This module implements some methods and creates additional datastructured
from the big character table that we use for all kind of purposes:
<type>char-def.lua</type>.</p>
--ldx]]--

characters          = characters          or { }
characters.data     = characters.data     or { }
characters.synonyms = characters.synonyms or { }
characters.context  = characters.context  or { }

characters.blocks={
    ["aegeannumbers"] = { 0x10100, 0x1013F, "Aegean Numbers" },
    ["alphabeticpresentationforms"] = { 0xFB00, 0xFB4F, "Alphabetic Presentation Forms" },
    ["ancientgreekmusicalnotation"] = { 0x1D200, 0x1D24F, "Ancient Greek Musical Notation" },
    ["ancientgreeknumbers"] = { 0x10140, 0x1018F, "Ancient Greek Numbers" },
    ["ancientsymbols"] = { 0x10190, 0x101CF, "Ancient Symbols" },
    ["arabic"] = { 0x0600, 0x06FF, "Arabic" },
    ["arabicpresentationformsa"] = { 0xFB50, 0xFDFF, "Arabic Presentation Forms-A" },
    ["arabicpresentationformsb"] = { 0xFE70, 0xFEFF, "Arabic Presentation Forms-B" },
    ["arabicsupplement"] = { 0x0750, 0x077F, "Arabic Supplement" },
    ["armenian"] = { 0x0530, 0x058F, "Armenian" },
    ["arrows"] = { 0x2190, 0x21FF, "Arrows" },
    ["balinese"] = { 0x1B00, 0x1B7F, "Balinese" },
    ["basiclatin"] = { 0x0000, 0x007F, "Basic Latin" },
    ["bengali"] = { 0x0980, 0x09FF, "Bengali" },
    ["blockelements"] = { 0x2580, 0x259F, "Block Elements" },
    ["bopomofo"] = { 0x3100, 0x312F, "Bopomofo" },
    ["bopomofoextended"] = { 0x31A0, 0x31BF, "Bopomofo Extended" },
    ["boxdrawing"] = { 0x2500, 0x257F, "Box Drawing" },
    ["braillepatterns"] = { 0x2800, 0x28FF, "Braille Patterns" },
    ["buginese"] = { 0x1A00, 0x1A1F, "Buginese" },
    ["buhid"] = { 0x1740, 0x175F, "Buhid" },
    ["byzantinemusicalsymbols"] = { 0x1D000, 0x1D0FF, "Byzantine Musical Symbols" },
    ["carian"] = { 0x102A0, 0x102DF, "Carian" },
    ["cham"] = { 0xAA00, 0xAA5F, "Cham" },
    ["cherokee"] = { 0x13A0, 0x13FF, "Cherokee" },
    ["cjkcompatibility"] = { 0x3300, 0x33FF, "CJK Compatibility" },
    ["cjkcompatibilityforms"] = { 0xFE30, 0xFE4F, "CJK Compatibility Forms" },
    ["cjkcompatibilityideographs"] = { 0xF900, 0xFAFF, "CJK Compatibility Ideographs" },
    ["cjkcompatibilityideographssupplement"] = { 0x2F800, 0x2FA1F, "CJK Compatibility Ideographs Supplement" },
    ["cjkradicalssupplement"] = { 0x2E80, 0x2EFF, "CJK Radicals Supplement" },
    ["cjkstrokes"] = { 0x31C0, 0x31EF, "CJK Strokes" },
    ["cjksymbolsandpunctuation"] = { 0x3000, 0x303F, "CJK Symbols and Punctuation" },
    ["cjkunifiedideographs"] = { 0x4E00, 0x9FFF, "CJK Unified Ideographs" },
    ["cjkunifiedideographsextensiona"] = { 0x3400, 0x4DBF, "CJK Unified Ideographs Extension A" },
    ["cjkunifiedideographsextensionb"] = { 0x20000, 0x2A6DF, "CJK Unified Ideographs Extension B" },
    ["combiningdiacriticalmarks"] = { 0x0300, 0x036F, "Combining Diacritical Marks" },
    ["combiningdiacriticalmarksforsymbols"] = { 0x20D0, 0x20FF, "Combining Diacritical Marks for Symbols" },
    ["combiningdiacriticalmarkssupplement"] = { 0x1DC0, 0x1DFF, "Combining Diacritical Marks Supplement" },
    ["combininghalfmarks"] = { 0xFE20, 0xFE2F, "Combining Half Marks" },
    ["controlpictures"] = { 0x2400, 0x243F, "Control Pictures" },
    ["coptic"] = { 0x2C80, 0x2CFF, "Coptic" },
    ["countingrodnumerals"] = { 0x1D360, 0x1D37F, "Counting Rod Numerals" },
    ["cuneiform"] = { 0x12000, 0x123FF, "Cuneiform" },
    ["cuneiformnumbersandpunctuation"] = { 0x12400, 0x1247F, "Cuneiform Numbers and Punctuation" },
    ["currencysymbols"] = { 0x20A0, 0x20CF, "Currency Symbols" },
    ["cypriotsyllabary"] = { 0x10800, 0x1083F, "Cypriot Syllabary" },
    ["cyrillic"] = { 0x0400, 0x04FF, "Cyrillic" },
    ["cyrillicextendeda"] = { 0x2DE0, 0x2DFF, "Cyrillic Extended-A" },
    ["cyrillicextendedb"] = { 0xA640, 0xA69F, "Cyrillic Extended-B" },
    ["cyrillicsupplement"] = { 0x0500, 0x052F, "Cyrillic Supplement" },
    ["deseret"] = { 0x10400, 0x1044F, "Deseret" },
    ["devanagari"] = { 0x0900, 0x097F, "Devanagari" },
    ["dingbats"] = { 0x2700, 0x27BF, "Dingbats" },
    ["dominotiles"] = { 0x1F030, 0x1F09F, "Domino Tiles" },
    ["enclosedalphanumerics"] = { 0x2460, 0x24FF, "Enclosed Alphanumerics" },
    ["enclosedcjklettersandmonths"] = { 0x3200, 0x32FF, "Enclosed CJK Letters and Months" },
    ["ethiopic"] = { 0x1200, 0x137F, "Ethiopic" },
    ["ethiopicextended"] = { 0x2D80, 0x2DDF, "Ethiopic Extended" },
    ["ethiopicsupplement"] = { 0x1380, 0x139F, "Ethiopic Supplement" },
    ["generalpunctuation"] = { 0x2000, 0x206F, "General Punctuation" },
    ["geometricshapes"] = { 0x25A0, 0x25FF, "Geometric Shapes" },
    ["georgian"] = { 0x10A0, 0x10FF, "Georgian" },
    ["georgiansupplement"] = { 0x2D00, 0x2D2F, "Georgian Supplement" },
    ["glagolitic"] = { 0x2C00, 0x2C5F, "Glagolitic" },
    ["gothic"] = { 0x10330, 0x1034F, "Gothic" },
    ["greekandcoptic"] = { 0x0370, 0x03FF, "Greek and Coptic" },
    ["greekextended"] = { 0x1F00, 0x1FFF, "Greek Extended" },
    ["gujarati"] = { 0x0A80, 0x0AFF, "Gujarati" },
    ["gurmukhi"] = { 0x0A00, 0x0A7F, "Gurmukhi" },
    ["halfwidthandfullwidthforms"] = { 0xFF00, 0xFFEF, "Halfwidth and Fullwidth Forms" },
    ["hangulcompatibilityjamo"] = { 0x3130, 0x318F, "Hangul Compatibility Jamo" },
    ["hanguljamo"] = { 0x1100, 0x11FF, "Hangul Jamo" },
    ["hangulsyllables"] = { 0xAC00, 0xD7AF, "Hangul Syllables" },
    ["hanunoo"] = { 0x1720, 0x173F, "Hanunoo" },
    ["hebrew"] = { 0x0590, 0x05FF, "Hebrew" },
    ["highprivateusesurrogates"] = { 0xDB80, 0xDBFF, "High Private Use Surrogates" },
    ["highsurrogates"] = { 0xD800, 0xDB7F, "High Surrogates" },
    ["hiragana"] = { 0x3040, 0x309F, "Hiragana" },
    ["ideographicdescriptioncharacters"] = { 0x2FF0, 0x2FFF, "Ideographic Description Characters" },
    ["ipaextensions"] = { 0x0250, 0x02AF, "IPA Extensions" },
    ["kanbun"] = { 0x3190, 0x319F, "Kanbun" },
    ["kangxiradicals"] = { 0x2F00, 0x2FDF, "Kangxi Radicals" },
    ["kannada"] = { 0x0C80, 0x0CFF, "Kannada" },
    ["katakana"] = { 0x30A0, 0x30FF, "Katakana" },
    ["katakanaphoneticextensions"] = { 0x31F0, 0x31FF, "Katakana Phonetic Extensions" },
    ["kayahli"] = { 0xA900, 0xA92F, "Kayah Li" },
    ["kharoshthi"] = { 0x10A00, 0x10A5F, "Kharoshthi" },
    ["khmer"] = { 0x1780, 0x17FF, "Khmer" },
    ["khmersymbols"] = { 0x19E0, 0x19FF, "Khmer Symbols" },
    ["lao"] = { 0x0E80, 0x0EFF, "Lao" },
    ["latinextendeda"] = { 0x0100, 0x017F, "Latin Extended-A" },
    ["latinextendedadditional"] = { 0x1E00, 0x1EFF, "Latin Extended Additional" },
    ["latinextendedb"] = { 0x0180, 0x024F, "Latin Extended-B" },
    ["latinextendedc"] = { 0x2C60, 0x2C7F, "Latin Extended-C" },
    ["latinextendedd"] = { 0xA720, 0xA7FF, "Latin Extended-D" },
    ["latinsupplement"] = { 0x0080, 0x00FF, "Latin-1 Supplement" },
    ["lepcha"] = { 0x1C00, 0x1C4F, "Lepcha" },
    ["letterlikesymbols"] = { 0x2100, 0x214F, "Letterlike Symbols" },
    ["limbu"] = { 0x1900, 0x194F, "Limbu" },
    ["linearbideograms"] = { 0x10080, 0x100FF, "Linear B Ideograms" },
    ["linearbsyllabary"] = { 0x10000, 0x1007F, "Linear B Syllabary" },
    ["lowsurrogates"] = { 0xDC00, 0xDFFF, "Low Surrogates" },
    ["lycian"] = { 0x10280, 0x1029F, "Lycian" },
    ["lydian"] = { 0x10920, 0x1093F, "Lydian" },
    ["mahjongtiles"] = { 0x1F000, 0x1F02F, "Mahjong Tiles" },
    ["malayalam"] = { 0x0D00, 0x0D7F, "Malayalam" },
    ["mathematicalalphanumericsymbols"] = { 0x1D400, 0x1D7FF, "Mathematical Alphanumeric Symbols" },
    ["mathematicaloperators"] = { 0x2200, 0x22FF, "Mathematical Operators" },
    ["miscellaneousmathematicalsymbolsa"] = { 0x27C0, 0x27EF, "Miscellaneous Mathematical Symbols-A" },
    ["miscellaneousmathematicalsymbolsb"] = { 0x2980, 0x29FF, "Miscellaneous Mathematical Symbols-B" },
    ["miscellaneoussymbols"] = { 0x2600, 0x26FF, "Miscellaneous Symbols" },
    ["miscellaneoussymbolsandarrows"] = { 0x2B00, 0x2BFF, "Miscellaneous Symbols and Arrows" },
    ["miscellaneoustechnical"] = { 0x2300, 0x23FF, "Miscellaneous Technical" },
    ["modifiertoneletters"] = { 0xA700, 0xA71F, "Modifier Tone Letters" },
    ["mongolian"] = { 0x1800, 0x18AF, "Mongolian" },
    ["musicalsymbols"] = { 0x1D100, 0x1D1FF, "Musical Symbols" },
    ["myanmar"] = { 0x1000, 0x109F, "Myanmar" },
    ["newtailue"] = { 0x1980, 0x19DF, "New Tai Lue" },
    ["nko"] = { 0x07C0, 0x07FF, "NKo" },
    ["numberforms"] = { 0x2150, 0x218F, "Number Forms" },
    ["ogham"] = { 0x1680, 0x169F, "Ogham" },
    ["olchiki"] = { 0x1C50, 0x1C7F, "Ol Chiki" },
    ["olditalic"] = { 0x10300, 0x1032F, "Old Italic" },
    ["oldpersian"] = { 0x103A0, 0x103DF, "Old Persian" },
    ["opticalcharacterrecognition"] = { 0x2440, 0x245F, "Optical Character Recognition" },
    ["oriya"] = { 0x0B00, 0x0B7F, "Oriya" },
    ["osmanya"] = { 0x10480, 0x104AF, "Osmanya" },
    ["phagspa"] = { 0xA840, 0xA87F, "Phags-pa" },
    ["phaistosdisc"] = { 0x101D0, 0x101FF, "Phaistos Disc" },
    ["phoenician"] = { 0x10900, 0x1091F, "Phoenician" },
    ["phoneticextensions"] = { 0x1D00, 0x1D7F, "Phonetic Extensions" },
    ["phoneticextensionssupplement"] = { 0x1D80, 0x1DBF, "Phonetic Extensions Supplement" },
    ["privateusearea"] = { 0xE000, 0xF8FF, "Private Use Area" },
    ["rejang"] = { 0xA930, 0xA95F, "Rejang" },
    ["runic"] = { 0x16A0, 0x16FF, "Runic" },
    ["saurashtra"] = { 0xA880, 0xA8DF, "Saurashtra" },
    ["shavian"] = { 0x10450, 0x1047F, "Shavian" },
    ["sinhala"] = { 0x0D80, 0x0DFF, "Sinhala" },
    ["smallformvariants"] = { 0xFE50, 0xFE6F, "Small Form Variants" },
    ["spacingmodifierletters"] = { 0x02B0, 0x02FF, "Spacing Modifier Letters" },
    ["specials"] = { 0xFFF0, 0xFFFF, "Specials" },
    ["sundanese"] = { 0x1B80, 0x1BBF, "Sundanese" },
    ["superscriptsandsubscripts"] = { 0x2070, 0x209F, "Superscripts and Subscripts" },
    ["supplementalarrowsa"] = { 0x27F0, 0x27FF, "Supplemental Arrows-A" },
    ["supplementalarrowsb"] = { 0x2900, 0x297F, "Supplemental Arrows-B" },
    ["supplementalmathematicaloperators"] = { 0x2A00, 0x2AFF, "Supplemental Mathematical Operators" },
    ["supplementalpunctuation"] = { 0x2E00, 0x2E7F, "Supplemental Punctuation" },
    ["supplementaryprivateuseareaa"] = { 0xF0000, 0xFFFFF, "Supplementary Private Use Area-A" },
    ["supplementaryprivateuseareab"] = { 0x100000, 0x10FFFF, "Supplementary Private Use Area-B" },
    ["sylotinagri"] = { 0xA800, 0xA82F, "Syloti Nagri" },
    ["syriac"] = { 0x0700, 0x074F, "Syriac" },
    ["tagalog"] = { 0x1700, 0x171F, "Tagalog" },
    ["tagbanwa"] = { 0x1760, 0x177F, "Tagbanwa" },
    ["tags"] = { 0xE0000, 0xE007F, "Tags" },
    ["taile"] = { 0x1950, 0x197F, "Tai Le" },
    ["taixuanjingsymbols"] = { 0x1D300, 0x1D35F, "Tai Xuan Jing Symbols" },
    ["tamil"] = { 0x0B80, 0x0BFF, "Tamil" },
    ["telugu"] = { 0x0C00, 0x0C7F, "Telugu" },
    ["thaana"] = { 0x0780, 0x07BF, "Thaana" },
    ["thai"] = { 0x0E00, 0x0E7F, "Thai" },
    ["tibetan"] = { 0x0F00, 0x0FFF, "Tibetan" },
    ["tifinagh"] = { 0x2D30, 0x2D7F, "Tifinagh" },
    ["ugaritic"] = { 0x10380, 0x1039F, "Ugaritic" },
    ["unifiedcanadianaboriginalsyllabics"] = { 0x1400, 0x167F, "Unified Canadian Aboriginal Syllabics" },
    ["vai"] = { 0xA500, 0xA63F, "Vai" },
    ["variationselectors"] = { 0xFE00, 0xFE0F, "Variation Selectors" },
    ["variationselectorssupplement"] = { 0xE0100, 0xE01EF, "Variation Selectors Supplement" },
    ["verticalforms"] = { 0xFE10, 0xFE1F, "Vertical Forms" },
    ["yijinghexagramsymbols"] = { 0x4DC0, 0x4DFF, "Yijing Hexagram Symbols" },
    ["yiradicals"] = { 0xA490, 0xA4CF, "Yi Radicals" },
    ["yisyllables"] = { 0xA000, 0xA48F, "Yi Syllables" },
}

function characters.getrange(name)
    local tag = name:lower()
    tag = name:gsub("[^a-z]", "")
    local range = characters.blocks[tag]
    if range then
        return range[1], range[2], range[3]
    end
    name = name:gsub('"',"0x") -- goodie: tex hex notation
    local start, stop = name:match("^(.-)[%-%:](.-)$")
    if start and stop then
        start, stop = tonumber(start,16) or tonumber(start), tonumber(stop,16) or tonumber(stop)
        if start and stop then
            return start, stop, nil
        end
    end
    local slot = tonumber(name,16) or tonumber(name)
    return slot, slot, nil
end

characters.categories = {
    lu = "Letter Uppercase",
    ll = "Letter Lowercase",
    lt = "Letter Titlecase",
    lm = "Letter Modifier",
    lo = "Letter Other",
    mn = "Mark Nonspacing",
    mc = "Mark Spacing Combining",
    me = "Mark Enclosing",
    nd = "Number Decimal Digit",
    nl = "Number Letter",
    no = "Number Other",
    pc = "Punctuation Connector",
    pd = "Punctuation Dash",
    ps = "Punctuation Open",
    pe = "Punctuation Close",
    pi = "Punctuation Initial Quote",
    pf = "Punctuation Final Quote",
    po = "Punctuation Other",
    sm = "Symbol Math",
    sc = "Symbol Currency",
    sk = "Symbol Modifier",
    so = "Symbol Other",
    zs = "Separator Space",
    zl = "Separator Line",
    zp = "Separator Paragraph",
    cc = "Other Control",
    cf = "Other Format",
    cs = "Other Surrogate",
    co = "Other Private Use",
    cn = "Other Not Assigned",
}

--~ special   : cf (softhyphen) zs (emspace)
--~ characters: ll lm lo lt lu mn nl no pc pd pe pf pi po ps sc sk sm so

characters.is_character = table.tohash {
    "ll","lm","lo","lt","lu","mn","nl","no","pc","pd","pe","pf","pi","po","ps","sc","sk","sm","so"
}

characters.is_command = table.tohash {
    "cf","zs"
}

-- linebreak: todo: hash
--
-- normative   : BK CR LF CM SG GL CB SP ZW NL WJ JL JV JT H2 H3
-- informative : XX OP CL QU NS EX SY IS PR PO NU AL ID IN HY BB BA SA AI B2

-- east asian width:
--
-- N A H W F Na

characters.bidi = {
    l   = "Left-to-Right",
    lre = "Left-to-Right Embedding",
    lro = "Left-to-Right Override",
    r   = "Right-to-Left",
    al  = "Right-to-Left Arabic",
    rle = "Right-to-Left Embedding",
    rlo = "Right-to-Left Override",
    pdf = "Pop Directional Format",
    en  = "European Number",
    es  = "European Number Separator",
    et  = "European Number Terminator",
    an  = "Arabic Number",
    cs  = "Common Number Separator",
    nsm = "Non-Spacing Mark",
    bn  = "Boundary Neutral",
    b   = "Paragraph Separator",
    s   = "Segment Separator",
    ws  = "Whitespace",
    on  = "Other Neutrals",
}

local _empty_table_ = { __index = function(t,k) return "" end }

function table.set_empty_metatable(t)
    setmetatable(t,_empty_table_)
end

table.set_empty_metatable(characters.data)

--[[ldx--
<p>At this point we assume that the big data table is loaded. From this
table we derive a few more.</p>
--ldx]]--

-- used ?

characters.unicodes   = characters.unicodes   or { }
characters.utfcodes   = characters.utfcodes   or { }
characters.enccodes   = characters.enccodes   or { }
characters.fallbacks  = characters.fallbacks  or { }
characters.directions = characters.directions or { }

function characters.context.rehash()
    local unicodes, utfcodes, enccodes, fallbacks, directions = characters.unicodes, characters.utfcodes, characters.enccodes, characters.fallbacks, characters.directions
    for k,v in pairs(characters.data) do
        local contextname, adobename, specials = v.contextname, v.adobename, v.specials
        if contextname then
            local slot = v.unicodeslot
            unicodes[contextname] = slot
            utfcodes[contextname] = utfchar(slot)
        end
        local encname = adobename or contextname
        if encname then
            enccodes[encname] = k
        end
        if specials and specials[1] == "compat" and specials[2] == 0x0020 and specials[3] then
            local s = specials[3]
            fallbacks[k] = s
            fallbacks[s] = k
        end
        directions[k] = v.direction
    end
    for name,code in pairs(characters.synonyms) do
        if not enccodes[name] then enccodes[name] = code end
    end
end

-- maybe some day, no significate speed up now

--~ input.storage.register(false, "characters.unicodes", characters.unicodes, "characters.unicodes")
--~ input.storage.register(false, "characters.utfcodes", characters.utfcodes, "characters.utfcodes")
--~ input.storage.register(false, "characters.enccodes", characters.enccodes, "characters.enccodes")
--~ input.storage.register(false, "characters.fallbacks", characters.fallbacks, "characters.fallbacks")
--~ input.storage.register(false, "characters.directions", characters.directions, "characters.directions")

--[[ldx--
<p>The <type>context</type> namespace is used to store methods and data
which is rather specific to <l n='context'/>.</p>
--ldx]]--

function characters.context.show(n)
    local n = characters.number(n)
    local d = characters.data[n]
    if d then
        local function entry(label,name)
            texsprint(tex.ctxcatcodes,format("\\NC %s\\NC %s\\NC\\NR",label,characters.valid(d[name])))
        end
        texsprint(tex.ctxcatcodes,"\\starttabulate[|Tl|Tl|]")
        entry("unicode index" , "unicodeslot")
        entry("context name"  , "contextname")
        entry("adobe name"    , "adobename")
        entry("category"      , "category")
        entry("description"   , "description")
        entry("uppercase code", "uccode")
        entry("lowercase code", "lccode")
        entry("specials"      , "specials")
        texsprint(tex.ctxcatcodes,"\\stoptabulate ")
    end
end

--[[ldx--
<p>Instead of using a <l n='tex'/> file to define the named glyphs, we
use the table. After all, we have this information available anyway.</p>
--ldx]]--

function characters.makeactive(n,name) -- let ?
    texsprint(tex.ctxcatcodes,format("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utfchar(n),name))
end

function tex.uprint(n)
    texsprint(tex.ctxcatcodes,utfchar(n))
end

function characters.context.define(tobelettered, tobeactivated)
    local unicodes, utfcodes = characters.unicodes, characters.utfcodes
    local tc = tex.ctxcatcodes
    local is_character, is_command = characters.is_character, characters.is_command
    local lettered, activated = { }, { }
    for u, chr in pairs(characters.data) do
        local fallback = chr.fallback
        if fallback then
            texsprint("{\\catcode"..u.."=13\\unexpanded\\gdef "..utfchar(u).."{\\checkedchar{"..u.."}{"..fallback.."}}}")
            activated[#activated+1] = "\\c"..u.."=".."13"
        else
            local contextname = chr.contextname
            local category = chr.category
            if contextname then
                if is_character[category] then
                 -- by this time, we're still in normal catcode mode
                    if chr.unicodeslot < 128 then
                        texsprint(tc, "\\chardef\\" .. contextname .. "=" .. u) -- unicodes[contextname])
                    else
                        texsprint(tc, "\\let\\" .. contextname .. "=" .. utfchar(u)) -- utfcodes[contextname])
                        lettered[#lettered+1] = "\\c"..u.."=".."11"
                    end
                elseif is_command[category] then
                    texsprint("{\\catcode"..u.."=13\\unexpanded\\gdef "..utfchar(u).."{\\"..contextname.."}}")
                    activated[#activated+1] = "\\c"..u.."=".."13"
                end
            else
                if is_character[category] then
                    if u >= 128 and u <= 65536 then
                        lettered[#lettered+1] = "\\c"..u.."=".."11"
                    end
                end
            end
        end
    end
    lettered[#lettered+1] = "\\c"..0x200C.."=".."11" -- non-joiner
    lettered[#lettered+1] = "\\c"..0x200D.."=".."11" -- joiner
    lettered = concat(lettered)
    for _, i in ipairs(tobelettered or { }) do
        texsprint(tc,format("\\startextendcatcodetable{%s}\\let\\c\\catcode%s\\stopextendcatcodetable",i,lettered))
    end
    activated = concat(activated)
    for _, i in ipairs(tobeactivated or { } ) do
        texsprint(tc,format("\\startextendcatcodetable{%s}\\let\\c\\catcode%s\\stopextendcatcodetable",i,activated))
    end
end

function characters.charcode(box)
    local b = tex.box[box]
    local l = b.list
    texsprint((l and l.id == node.id('glyph') and l.char) or 0)
end

--[[ldx--
<p>Setting the lccodes is also done in a loop over the data table.</p>
--ldx]]--

function characters.setcodes()
    local tc = tex.ctxcatcodes
    for code, chr in pairs(characters.data) do
        local cc = chr.category
        if cc == 'll' or cc == 'lu' or cc == 'lt' then
            local lc, uc = chr.lccode, chr.uccode
            if not lc then chr.lccode, lc = code, code end
            if not uc then chr.uccode, uc = code, code end
            texsprint(tc, format("\\setcclcuc %i %i %i ",code,lc,uc))
        end
    end
end

--[[ldx--
<p>Next comes a whole series of helper methods. These are (will be) part
of the official <l n='api'/>.</p>
--ldx]]--

--[[ldx--
<p>This converts a string (if given) into a number.</p>
--ldx]]--

function characters.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

--[[ldx--
<p>Checking for valid characters.</p>
--ldx]]--

function characters.is_valid(s)
    return s or ""
end

function characters.checked(s, default)
    return s or default
end

characters.valid = characters.is_valid

--[[ldx--
<p>The next method is used when constructing the main table, although nowadays
we do this in one step. The index can be a string or a number.</p>
--ldx]]--

function characters.define(c)
    characters.data[characters.number(c.unicodeslot)] = c
end

--[[ldx--
<p></p>
--ldx]]--
-- set a table entry; index is number (can be different from unicodeslot)

function characters.set(n, c)
    characters.data[characters.number(n)] = c
end

--[[ldx--
<p>Get a table entry happens by number. Keep in mind that the unicodeslot
can be different (not likely).</p>
--ldx]]--

function characters.get(n)
    return characters.data[characters.number(n)]
end

--[[ldx--
<p>A couple of convenience methods. Beware, these are not that fast due
to the checking.</p>
--ldx]]--

function characters.hexindex(n)
    return format("%04X", characters.valid(characters.data[characters.number(n)].unicodeslot))
end

function characters.contextname(n)
    return characters.valid(characters.data[characters.number(n)].contextname)
end

function characters.adobename(n)
    return characters.valid(characters.data[characters.number(n)].adobename)
end

function characters.description(n)
    return characters.valid(characters.data[characters.number(n)].description)
end

function characters.category(n)
    return characters.valid(characters.data[characters.number(n)].category)
end

--[[ldx--
<p>Requesting lower and uppercase codes:</p>
--ldx]]--

function characters.uccode(n) return characters.data[n].uccode or n end
function characters.lccode(n) return characters.data[n].lccode or n end

function characters.flush(n)
    local c = characters.data[n]
    if c and c.contextname then
        texsprint(tex.texcatcodes, "\\"..c.contextname)
    else
        texsprint(unicode.utf8.char(n))
    end
end

function characters.shape(n)
    local shcode = characters.data[n].shcode
    if not shcode then
        return n, nil
    elseif type(shcode) == "table" then
        return shcode[1], shcode[#shcode]
    else
        return shcode, nil
    end
end

--[[ldx--
<p>Categories play an important role, so here are some checkers.</p>
--ldx]]--

function characters.is_of_category(token,category)
    if type(token) == "string" then
        return characters.data[utfbyte(token)].category == category
    else
        return characters.data[token].category == category
    end
end

function characters.i_is_of_category(i,category) -- by index (number)
    local cd = characters.data[i]
    return cd and cd.category == category
end

function characters.n_is_of_category(n,category) -- by name (string)
    local cd = characters.data[utfbyte(n)]
    return cd and cd.category == category
end

--[[ldx--
<p>The following code is kind of messy. It is used to generate the right
unicode reference tables.</p>
--ldx]]--

function characters.setpdfunicodes()
--~     local tc = tex.ctxcatcodes
--~     for _,v in pairs(characters.data) do
--~         if v.adobename then
--~             texsprint(tc,format("\\pdfglyphtounicode{%s}{%04X}", v.adobename, v.unicodeslot))
--~         end
--~     end
end

-- xml support

characters.active_offset = 0x10000

xml.entities = xml.entities or { }

input.storage.register(false,"xml/entities",xml.entities,"xml.entities") -- this will move to lxml

function characters.remapentity(chr,slot)
    texsprint(format("{\\catcode%s=13\\xdef%s{\\string%s}}",slot,utfchar(slot),chr))
end

function characters.setmkiventities()
    local entities = xml.entities
    entities.lt  = "<"
    entities.amp = "&"
    entities.gt  = ">"
end

function characters.setmkiientities()
    local entities = xml.entities
    entities.lt  = utfchar(characters.active_offset + utfbyte("<"))
    entities.amp = utfchar(characters.active_offset + utfbyte("&"))
    entities.gt  = utfchar(characters.active_offset + utfbyte(">"))
end
