if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make two files, one for format generation, one for format use

local tex = tex
local utf = unicode.utf8

local utfchar, utfbyte, utfvalues = utf.char, utf.byte, string.utfvalues
local ustring = unicode.ustring
local concat, unpack = table.concat, table.unpack
local next, tonumber, type, rawget, rawset = next, tonumber, type, rawget, rawset
local texsprint, texprint = tex.sprint, tex.print
local format, lower, gsub, match, gmatch = string.format, string.lower, string.gsub, string.match, string.match, string.gmatch
local P, R, lpegmatch = lpeg.P, lpeg.R, lpeg.match

local allocate          = utilities.storage.allocate
local mark              = utilities.storage.mark
local texsetlccode      = tex.setlccode
local texsetuccode      = tex.setuccode
local texsetsfcode      = tex.setsfcode
local texsetcatcode     = tex.setcatcode
local ctxcatcodes       = tex.ctxcatcodes
local texcatcodes       = tex.texcatcodes
local setmetatableindex = table.setmetatableindex

local trace_defining    = false  trackers.register("characters.defining",   function(v) characters_defining = v end)

local report_defining   = logs.reporter("characters")

--[[ldx--
<p>This module implements some methods and creates additional datastructured
from the big character table that we use for all kind of purposes:
<type>char-def.lua</type>.</p>

<p>We assume that at this point <type>characters.data</type> is already
loaded!</p>
--ldx]]--

characters       = characters or { }
local characters = characters

local data       = characters.data

if data then
    mark(data) -- why does this fail
else
    report_defining("fatal error: 'char-def.lua' is not loaded")
    os.exit()
end

--[[ldx--
<p>This converts a string (if given) into a number.</p>
--ldx]]--

local pattern = (P("0x") + P("U+")) * ((R("09","AF")^1 * P(-1)) / function(s) return tonumber(s,16) end)

lpeg.patterns.chartonumber = pattern

local function chartonumber(k)
    if type(k) == "string" then
        local u = lpegmatch(pattern,k)
        if u then
            return utfbyte(u)
        else
            return utfbyte(k) or 0
        end
    else
        return k or 0
    end
end

local function charfromnumber(k)
    if type(k) == "number" then
        return utfchar(k) or ""
    else
        local u = lpegmatch(pattern,k)
        if u then
            return utfchar(u)
        else
            return k
        end
    end
end

--~ print(chartonumber(97), chartonumber("a"), chartonumber("0x61"), chartonumber("U+61"))

characters.tonumber   = chartonumber
characters.fromnumber = charfromnumber

local private = {
    description = "PRIVATE SLOT",
}

local ranges      = allocate()
characters.ranges = ranges

setmetatableindex(data, function(t,k)
    local tk = type(k)
    if tk == "string" then
        k = lpegmatch(pattern,k) or utfbyte(k)
        if k then
            local tk = rawget(t,k)
            if tk then
                return tk
            else
                -- goes to ranges
            end
        else
            return private
        end
    end
    if tk == "number" and k < 0xF0000 then
        for r=1,#ranges do
            local rr = ranges[r]
            if k >= rr.first and k <= rr.last then
                local extender = rr.extender
                if extender then
                    v = extender(k,v)
                end
                t[k] = v
                return v
            end
        end
    end
    return private -- handy for when we loop over characters in fonts and check for a property
end)

local blocks = allocate {
    ["aegeannumbers"]                        = { first = 0x10100, last = 0x1013F, description = "Aegean Numbers" },
    ["alphabeticpresentationforms"]          = { first = 0x0FB00, last = 0x0FB4F, description = "Alphabetic Presentation Forms" },
    ["ancientgreekmusicalnotation"]          = { first = 0x1D200, last = 0x1D24F, description = "Ancient Greek Musical Notation" },
    ["ancientgreeknumbers"]                  = { first = 0x10140, last = 0x1018F, description = "Ancient Greek Numbers" },
    ["ancientsymbols"]                       = { first = 0x10190, last = 0x101CF, description = "Ancient Symbols" },
    ["arabic"]                               = { first = 0x00600, last = 0x006FF, description = "Arabic" },
    ["arabicpresentationformsa"]             = { first = 0x0FB50, last = 0x0FDFF, description = "Arabic Presentation Forms-A" },
    ["arabicpresentationformsb"]             = { first = 0x0FE70, last = 0x0FEFF, description = "Arabic Presentation Forms-B" },
    ["arabicsupplement"]                     = { first = 0x00750, last = 0x0077F, description = "Arabic Supplement" },
    ["armenian"]                             = { first = 0x00530, last = 0x0058F, description = "Armenian" },
    ["arrows"]                               = { first = 0x02190, last = 0x021FF, description = "Arrows" },
    ["balinese"]                             = { first = 0x01B00, last = 0x01B7F, description = "Balinese" },
    ["basiclatin"]                           = { first = 0x00000, last = 0x0007F, description = "Basic Latin" },
    ["bengali"]                              = { first = 0x00980, last = 0x009FF, description = "Bengali" },
    ["blockelements"]                        = { first = 0x02580, last = 0x0259F, description = "Block Elements" },
    ["bopomofo"]                             = { first = 0x03100, last = 0x0312F, description = "Bopomofo" },
    ["bopomofoextended"]                     = { first = 0x031A0, last = 0x031BF, description = "Bopomofo Extended" },
    ["boxdrawing"]                           = { first = 0x02500, last = 0x0257F, description = "Box Drawing" },
    ["braillepatterns"]                      = { first = 0x02800, last = 0x028FF, description = "Braille Patterns" },
    ["buginese"]                             = { first = 0x01A00, last = 0x01A1F, description = "Buginese" },
    ["buhid"]                                = { first = 0x01740, last = 0x0175F, description = "Buhid" },
    ["byzantinemusicalsymbols"]              = { first = 0x1D000, last = 0x1D0FF, description = "Byzantine Musical Symbols" },
    ["carian"]                               = { first = 0x102A0, last = 0x102DF, description = "Carian" },
    ["cham"]                                 = { first = 0x0AA00, last = 0x0AA5F, description = "Cham" },
    ["cherokee"]                             = { first = 0x013A0, last = 0x013FF, description = "Cherokee" },
    ["cjkcompatibility"]                     = { first = 0x03300, last = 0x033FF, description = "CJK Compatibility" },
    ["cjkcompatibilityforms"]                = { first = 0x0FE30, last = 0x0FE4F, description = "CJK Compatibility Forms" },
    ["cjkcompatibilityideographs"]           = { first = 0x0F900, last = 0x0FAFF, description = "CJK Compatibility Ideographs" },
    ["cjkcompatibilityideographssupplement"] = { first = 0x2F800, last = 0x2FA1F, description = "CJK Compatibility Ideographs Supplement" },
    ["cjkradicalssupplement"]                = { first = 0x02E80, last = 0x02EFF, description = "CJK Radicals Supplement" },
    ["cjkstrokes"]                           = { first = 0x031C0, last = 0x031EF, description = "CJK Strokes" },
    ["cjksymbolsandpunctuation"]             = { first = 0x03000, last = 0x0303F, description = "CJK Symbols and Punctuation" },
    ["cjkunifiedideographs"]                 = { first = 0x04E00, last = 0x09FFF, description = "CJK Unified Ideographs" },
    ["cjkunifiedideographsextensiona"]       = { first = 0x03400, last = 0x04DBF, description = "CJK Unified Ideographs Extension A" },
    ["cjkunifiedideographsextensionb"]       = { first = 0x20000, last = 0x2A6DF, description = "CJK Unified Ideographs Extension B" },
    ["combiningdiacriticalmarks"]            = { first = 0x00300, last = 0x0036F, description = "Combining Diacritical Marks" },
    ["combiningdiacriticalmarksforsymbols"]  = { first = 0x020D0, last = 0x020FF, description = "Combining Diacritical Marks for Symbols" },
    ["combiningdiacriticalmarkssupplement"]  = { first = 0x01DC0, last = 0x01DFF, description = "Combining Diacritical Marks Supplement" },
    ["combininghalfmarks"]                   = { first = 0x0FE20, last = 0x0FE2F, description = "Combining Half Marks" },
    ["controlpictures"]                      = { first = 0x02400, last = 0x0243F, description = "Control Pictures" },
    ["coptic"]                               = { first = 0x02C80, last = 0x02CFF, description = "Coptic" },
    ["countingrodnumerals"]                  = { first = 0x1D360, last = 0x1D37F, description = "Counting Rod Numerals" },
    ["cuneiform"]                            = { first = 0x12000, last = 0x123FF, description = "Cuneiform" },
    ["cuneiformnumbersandpunctuation"]       = { first = 0x12400, last = 0x1247F, description = "Cuneiform Numbers and Punctuation" },
    ["currencysymbols"]                      = { first = 0x020A0, last = 0x020CF, description = "Currency Symbols" },
    ["cypriotsyllabary"]                     = { first = 0x10800, last = 0x1083F, description = "Cypriot Syllabary" },
    ["cyrillic"]                             = { first = 0x00400, last = 0x004FF, description = "Cyrillic" },
    ["cyrillicextendeda"]                    = { first = 0x02DE0, last = 0x02DFF, description = "Cyrillic Extended-A" },
    ["cyrillicextendedb"]                    = { first = 0x0A640, last = 0x0A69F, description = "Cyrillic Extended-B" },
    ["cyrillicsupplement"]                   = { first = 0x00500, last = 0x0052F, description = "Cyrillic Supplement" },
    ["deseret"]                              = { first = 0x10400, last = 0x1044F, description = "Deseret" },
    ["devanagari"]                           = { first = 0x00900, last = 0x0097F, description = "Devanagari" },
    ["dingbats"]                             = { first = 0x02700, last = 0x027BF, description = "Dingbats" },
    ["dominotiles"]                          = { first = 0x1F030, last = 0x1F09F, description = "Domino Tiles" },
    ["enclosedalphanumerics"]                = { first = 0x02460, last = 0x024FF, description = "Enclosed Alphanumerics" },
    ["enclosedcjklettersandmonths"]          = { first = 0x03200, last = 0x032FF, description = "Enclosed CJK Letters and Months" },
    ["ethiopic"]                             = { first = 0x01200, last = 0x0137F, description = "Ethiopic" },
    ["ethiopicextended"]                     = { first = 0x02D80, last = 0x02DDF, description = "Ethiopic Extended" },
    ["ethiopicsupplement"]                   = { first = 0x01380, last = 0x0139F, description = "Ethiopic Supplement" },
    ["generalpunctuation"]                   = { first = 0x02000, last = 0x0206F, description = "General Punctuation" },
    ["geometricshapes"]                      = { first = 0x025A0, last = 0x025FF, description = "Geometric Shapes" },
    ["georgian"]                             = { first = 0x010A0, last = 0x010FF, description = "Georgian" },
    ["georgiansupplement"]                   = { first = 0x02D00, last = 0x02D2F, description = "Georgian Supplement" },
    ["glagolitic"]                           = { first = 0x02C00, last = 0x02C5F, description = "Glagolitic" },
    ["gothic"]                               = { first = 0x10330, last = 0x1034F, description = "Gothic" },
    ["greekandcoptic"]                       = { first = 0x00370, last = 0x003FF, description = "Greek and Coptic" },
    ["greekextended"]                        = { first = 0x01F00, last = 0x01FFF, description = "Greek Extended" },
    ["gujarati"]                             = { first = 0x00A80, last = 0x00AFF, description = "Gujarati" },
    ["gurmukhi"]                             = { first = 0x00A00, last = 0x00A7F, description = "Gurmukhi" },
    ["halfwidthandfullwidthforms"]           = { first = 0x0FF00, last = 0x0FFEF, description = "Halfwidth and Fullwidth Forms" },
    ["hangulcompatibilityjamo"]              = { first = 0x03130, last = 0x0318F, description = "Hangul Compatibility Jamo" },
    ["hanguljamo"]                           = { first = 0x01100, last = 0x011FF, description = "Hangul Jamo" },
    ["hangulsyllables"]                      = { first = 0x0AC00, last = 0x0D7AF, description = "Hangul Syllables" },
    ["hanunoo"]                              = { first = 0x01720, last = 0x0173F, description = "Hanunoo" },
    ["hebrew"]                               = { first = 0x00590, last = 0x005FF, description = "Hebrew" },
    ["highprivateusesurrogates"]             = { first = 0x0DB80, last = 0x0DBFF, description = "High Private Use Surrogates" },
    ["highsurrogates"]                       = { first = 0x0D800, last = 0x0DB7F, description = "High Surrogates" },
    ["hiragana"]                             = { first = 0x03040, last = 0x0309F, description = "Hiragana" },
    ["ideographicdescriptioncharacters"]     = { first = 0x02FF0, last = 0x02FFF, description = "Ideographic Description Characters" },
    ["ipaextensions"]                        = { first = 0x00250, last = 0x002AF, description = "IPA Extensions" },
    ["kanbun"]                               = { first = 0x03190, last = 0x0319F, description = "Kanbun" },
    ["kangxiradicals"]                       = { first = 0x02F00, last = 0x02FDF, description = "Kangxi Radicals" },
    ["kannada"]                              = { first = 0x00C80, last = 0x00CFF, description = "Kannada" },
    ["katakana"]                             = { first = 0x030A0, last = 0x030FF, description = "Katakana" },
    ["katakanaphoneticextensions"]           = { first = 0x031F0, last = 0x031FF, description = "Katakana Phonetic Extensions" },
    ["kayahli"]                              = { first = 0x0A900, last = 0x0A92F, description = "Kayah Li" },
    ["kharoshthi"]                           = { first = 0x10A00, last = 0x10A5F, description = "Kharoshthi" },
    ["khmer"]                                = { first = 0x01780, last = 0x017FF, description = "Khmer" },
    ["khmersymbols"]                         = { first = 0x019E0, last = 0x019FF, description = "Khmer Symbols" },
    ["lao"]                                  = { first = 0x00E80, last = 0x00EFF, description = "Lao" },
    ["latinextendeda"]                       = { first = 0x00100, last = 0x0017F, description = "Latin Extended-A" },
    ["latinextendedadditional"]              = { first = 0x01E00, last = 0x01EFF, description = "Latin Extended Additional" },
    ["latinextendedb"]                       = { first = 0x00180, last = 0x0024F, description = "Latin Extended-B" },
    ["latinextendedc"]                       = { first = 0x02C60, last = 0x02C7F, description = "Latin Extended-C" },
    ["latinextendedd"]                       = { first = 0x0A720, last = 0x0A7FF, description = "Latin Extended-D" },
    ["latinsupplement"]                      = { first = 0x00080, last = 0x000FF, description = "Latin-1 Supplement" },
    ["lepcha"]                               = { first = 0x01C00, last = 0x01C4F, description = "Lepcha" },
    ["letterlikesymbols"]                    = { first = 0x02100, last = 0x0214F, description = "Letterlike Symbols" },
    ["limbu"]                                = { first = 0x01900, last = 0x0194F, description = "Limbu" },
    ["linearbideograms"]                     = { first = 0x10080, last = 0x100FF, description = "Linear B Ideograms" },
    ["linearbsyllabary"]                     = { first = 0x10000, last = 0x1007F, description = "Linear B Syllabary" },
    ["lowsurrogates"]                        = { first = 0x0DC00, last = 0x0DFFF, description = "Low Surrogates" },
    ["lycian"]                               = { first = 0x10280, last = 0x1029F, description = "Lycian" },
    ["lydian"]                               = { first = 0x10920, last = 0x1093F, description = "Lydian" },
    ["mahjongtiles"]                         = { first = 0x1F000, last = 0x1F02F, description = "Mahjong Tiles" },
    ["malayalam"]                            = { first = 0x00D00, last = 0x00D7F, description = "Malayalam" },
    ["mathematicalalphanumericsymbols"]      = { first = 0x1D400, last = 0x1D7FF, description = "Mathematical Alphanumeric Symbols" },
    ["mathematicaloperators"]                = { first = 0x02200, last = 0x022FF, description = "Mathematical Operators" },
    ["miscellaneousmathematicalsymbolsa"]    = { first = 0x027C0, last = 0x027EF, description = "Miscellaneous Mathematical Symbols-A" },
    ["miscellaneousmathematicalsymbolsb"]    = { first = 0x02980, last = 0x029FF, description = "Miscellaneous Mathematical Symbols-B" },
    ["miscellaneoussymbols"]                 = { first = 0x02600, last = 0x026FF, description = "Miscellaneous Symbols" },
    ["miscellaneoussymbolsandarrows"]        = { first = 0x02B00, last = 0x02BFF, description = "Miscellaneous Symbols and Arrows" },
    ["miscellaneoustechnical"]               = { first = 0x02300, last = 0x023FF, description = "Miscellaneous Technical" },
    ["modifiertoneletters"]                  = { first = 0x0A700, last = 0x0A71F, description = "Modifier Tone Letters" },
    ["mongolian"]                            = { first = 0x01800, last = 0x018AF, description = "Mongolian" },
    ["musicalsymbols"]                       = { first = 0x1D100, last = 0x1D1FF, description = "Musical Symbols" },
    ["myanmar"]                              = { first = 0x01000, last = 0x0109F, description = "Myanmar" },
    ["newtailue"]                            = { first = 0x01980, last = 0x019DF, description = "New Tai Lue" },
    ["nko"]                                  = { first = 0x007C0, last = 0x007FF, description = "NKo" },
    ["numberforms"]                          = { first = 0x02150, last = 0x0218F, description = "Number Forms" },
    ["ogham"]                                = { first = 0x01680, last = 0x0169F, description = "Ogham" },
    ["olchiki"]                              = { first = 0x01C50, last = 0x01C7F, description = "Ol Chiki" },
    ["olditalic"]                            = { first = 0x10300, last = 0x1032F, description = "Old Italic" },
    ["oldpersian"]                           = { first = 0x103A0, last = 0x103DF, description = "Old Persian" },
    ["opticalcharacterrecognition"]          = { first = 0x02440, last = 0x0245F, description = "Optical Character Recognition" },
    ["oriya"]                                = { first = 0x00B00, last = 0x00B7F, description = "Oriya" },
    ["osmanya"]                              = { first = 0x10480, last = 0x104AF, description = "Osmanya" },
    ["phagspa"]                              = { first = 0x0A840, last = 0x0A87F, description = "Phags-pa" },
    ["phaistosdisc"]                         = { first = 0x101D0, last = 0x101FF, description = "Phaistos Disc" },
    ["phoenician"]                           = { first = 0x10900, last = 0x1091F, description = "Phoenician" },
    ["phoneticextensions"]                   = { first = 0x01D00, last = 0x01D7F, description = "Phonetic Extensions" },
    ["phoneticextensionssupplement"]         = { first = 0x01D80, last = 0x01DBF, description = "Phonetic Extensions Supplement" },
    ["privateusearea"]                       = { first = 0x0E000, last = 0x0F8FF, description = "Private Use Area" },
    ["rejang"]                               = { first = 0x0A930, last = 0x0A95F, description = "Rejang" },
    ["runic"]                                = { first = 0x016A0, last = 0x016FF, description = "Runic" },
    ["saurashtra"]                           = { first = 0x0A880, last = 0x0A8DF, description = "Saurashtra" },
    ["shavian"]                              = { first = 0x10450, last = 0x1047F, description = "Shavian" },
    ["sinhala"]                              = { first = 0x00D80, last = 0x00DFF, description = "Sinhala" },
    ["smallformvariants"]                    = { first = 0x0FE50, last = 0x0FE6F, description = "Small Form Variants" },
    ["spacingmodifierletters"]               = { first = 0x002B0, last = 0x002FF, description = "Spacing Modifier Letters" },
    ["specials"]                             = { first = 0x0FFF0, last = 0x0FFFF, description = "Specials" },
    ["sundanese"]                            = { first = 0x01B80, last = 0x01BBF, description = "Sundanese" },
    ["superscriptsandsubscripts"]            = { first = 0x02070, last = 0x0209F, description = "Superscripts and Subscripts" },
    ["supplementalarrowsa"]                  = { first = 0x027F0, last = 0x027FF, description = "Supplemental Arrows-A" },
    ["supplementalarrowsb"]                  = { first = 0x02900, last = 0x0297F, description = "Supplemental Arrows-B" },
    ["supplementalmathematicaloperators"]    = { first = 0x02A00, last = 0x02AFF, description = "Supplemental Mathematical Operators" },
    ["supplementalpunctuation"]              = { first = 0x02E00, last = 0x02E7F, description = "Supplemental Punctuation" },
    ["supplementaryprivateuseareaa"]         = { first = 0xF0000, last = 0xFFFFF, description = "Supplementary Private Use Area-A" },
    ["supplementaryprivateuseareab"]         = { first = 0x100000,last = 0x10FFFF,description = "Supplementary Private Use Area-B" },
    ["sylotinagri"]                          = { first = 0x0A800, last = 0x0A82F, description = "Syloti Nagri" },
    ["syriac"]                               = { first = 0x00700, last = 0x0074F, description = "Syriac" },
    ["tagalog"]                              = { first = 0x01700, last = 0x0171F, description = "Tagalog" },
    ["tagbanwa"]                             = { first = 0x01760, last = 0x0177F, description = "Tagbanwa" },
    ["tags"]                                 = { first = 0xE0000, last = 0xE007F, description = "Tags" },
    ["taile"]                                = { first = 0x01950, last = 0x0197F, description = "Tai Le" },
    ["taixuanjingsymbols"]                   = { first = 0x1D300, last = 0x1D35F, description = "Tai Xuan Jing Symbols" },
    ["tamil"]                                = { first = 0x00B80, last = 0x00BFF, description = "Tamil" },
    ["telugu"]                               = { first = 0x00C00, last = 0x00C7F, description = "Telugu" },
    ["thaana"]                               = { first = 0x00780, last = 0x007BF, description = "Thaana" },
    ["thai"]                                 = { first = 0x00E00, last = 0x00E7F, description = "Thai" },
    ["tibetan"]                              = { first = 0x00F00, last = 0x00FFF, description = "Tibetan" },
    ["tifinagh"]                             = { first = 0x02D30, last = 0x02D7F, description = "Tifinagh" },
    ["ugaritic"]                             = { first = 0x10380, last = 0x1039F, description = "Ugaritic" },
    ["unifiedcanadianaboriginalsyllabics"]   = { first = 0x01400, last = 0x0167F, description = "Unified Canadian Aboriginal Syllabics" },
    ["vai"]                                  = { first = 0x0A500, last = 0x0A63F, description = "Vai" },
    ["variationselectors"]                   = { first = 0x0FE00, last = 0x0FE0F, description = "Variation Selectors" },
    ["variationselectorssupplement"]         = { first = 0xE0100, last = 0xE01EF, description = "Variation Selectors Supplement" },
    ["verticalforms"]                        = { first = 0x0FE10, last = 0x0FE1F, description = "Vertical Forms" },
    ["yijinghexagramsymbols"]                = { first = 0x04DC0, last = 0x04DFF, description = "Yijing Hexagram Symbols" },
    ["yiradicals"]                           = { first = 0x0A490, last = 0x0A4CF, description = "Yi Radicals" },
    ["yisyllables"]                          = { first = 0x0A000, last = 0x0A48F, description = "Yi Syllables" },
}

characters.blocks = blocks

setmetatableindex(blocks, function(t,k)
    return k and rawget(t,lower(gsub(k,"[^a-zA-Z]","")))
end)

function characters.getrange(name) -- used in font fallback definitions (name or range)
    local range = blocks[name]
    if range then
        return range.first, range.last, range.description
    end
    name = gsub(name,'"',"0x") -- goodie: tex hex notation
    local start, stop = match(name,"^(.-)[%-%:](.-)$")
    if start and stop then
        start, stop = tonumber(start,16) or tonumber(start), tonumber(stop,16) or tonumber(stop)
        if start and stop then
            return start, stop, nil
        end
    end
    local slot = tonumber(name,16) or tonumber(name)
    return slot, slot, nil
end

local categorytags = allocate {
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

characters.categorytags = categorytags

--~ special   : cf (softhyphen) zs (emspace)
--~ characters: ll lm lo lt lu mn nl no pc pd pe pf pi po ps sc sk sm so

local is_character = allocate ( table.tohash {
    "lu","ll","lt","lm","lo",
    "nd","nl","no",
    "mn",
    "nl","no",
    "pc","pd","ps","pe","pi","pf","po",
    "sm","sc","sk","so"
} )

local is_letter = allocate ( table.tohash {
    "ll","lm","lo","lt","lu"
} )

local is_command = allocate ( table.tohash {
    "cf","zs"
} )

local is_spacing = allocate ( table.tohash {
    "zs", "zl","zp",
} )

local is_mark = allocate ( table.tohash {
    "mn", "ms",
} )

characters.is_character = is_character
characters.is_letter    = is_letter
characters.is_command   = is_command
characters.is_spacing   = is_spacing
characters.is_mark      = is_mark

local mt = { -- yes or no ?
    __index = function(t,k)
        if type(k) == "number" then
            local c = characters.data[k].category
            return c and rawget(t,c)
        else
            -- avoid auto conversion in data.characters lookups
        end
    end
}

setmetatableindex(characters.is_character, mt)
setmetatableindex(characters.is_letter,    mt)
setmetatableindex(characters.is_command,   mt)
setmetatableindex(characters.is_spacing,   mt)

-- linebreak: todo: hash
--
-- normative   : BK CR LF CM SG GL CB SP ZW NL WJ JL JV JT H2 H3
-- informative : XX OP CL QU NS EX SY IS PR PO NU AL ID IN HY BB BA SA AI B2

-- east asian width:
--
-- N A H W F Na

characters.bidi = allocate {
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

--[[ldx--
<p>At this point we assume that the big data table is loaded. From this
table we derive a few more.</p>
--ldx]]--

if not characters.fallbacks then

    -- we could the definition by using a metatable

    characters.fallbacks   = { }
    characters.directions  = { }

    local fallbacks  = characters.fallbacks
    local directions = characters.directions

    for k,v in next, data do
        local specials = v.specials
        if specials and specials[1] == "compat" and specials[2] == 0x0020 and specials[3] then
            local s = specials[3]
            fallbacks[k] = s
            fallbacks[s] = k
        end
        directions[k] = v.direction
    end

end

storage.register("characters/fallbacks",  characters.fallbacks,  "characters.fallbacks") -- accents and such
storage.register("characters/directions", characters.directions, "characters.directions")

--[[ldx--
<p>The <type>context</type> namespace is used to store methods and data
which is rather specific to <l n='context'/>.</p>
--ldx]]--

--[[ldx--
<p>Instead of using a <l n='tex'/> file to define the named glyphs, we
use the table. After all, we have this information available anyway.</p>
--ldx]]--

function characters.makeactive(n,name) -- let ?
    texsprint(ctxcatcodes,format("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utfchar(n),name))
 -- context("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utfchar(n),name)
end

function tex.uprint(c,n)
    if n then
     -- texsprint(c,charfromnumber(n))
        texsprint(c,utfchar(n))
    else
     -- texsprint(charfromnumber(c))
        texsprint(utfchar(c))
    end
end

function characters.define(tobelettered, tobeactivated) -- catcodetables

    if trace_defining then
        report_defining("defining active character commands")
    end

    local activated, a = { }, 0

    for u, chr in next, data do -- these will be commands
        local fallback = chr.fallback
        if fallback then
            texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\checkedchar{",u,"}{",fallback,"}}}") -- no texprint
            a = a + 1
            activated[a] = u
        else
            local contextname = chr.contextname
            if contextname then
                local category = chr.category
                if is_character[category] then
                    if chr.unicodeslot < 128 then
                        if is_letter[category] then
                            texprint(ctxcatcodes,format("\\def\\%s{%s}",contextname,utfchar(u)))
                        else
                            texprint(ctxcatcodes,format("\\chardef\\%s=%s",contextname,u))
                        end
                    else
                        texprint(ctxcatcodes,format("\\def\\%s{%s}",contextname,utfchar(u)))
                    end
                elseif is_command[category] then
                    texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\"..contextname,"}}") -- no texprint
                    a = a + 1
                    activated[a] = u
                end
            end
        end
    end

    if tobelettered then -- shared
        local saved = tex.catcodetable
        for i=1,#tobelettered do
            tex.catcodetable = tobelettered[i]
            if trace_defining then
                report_defining("defining letters (global, shared)")
            end
            for u, chr in next, data do
                if not chr.fallback and is_letter[chr.category] and u >= 128 and u <= 65536 then
                    texsetcatcode(u,11)
                end
                local range = chr.range
                if range then
                    for i=1,range.first,range.last do
                        texsetcatcode(i,11)
                    end
                end
            end
            texsetcatcode(0x200C,11) -- non-joiner
            texsetcatcode(0x200D,11) -- joiner
        end
        tex.catcodetable = saved
    end

    local nofactivated = #tobeactivated
    if tobeactivated and nofactivated > 0 then
        for i=1,nofactivated do
            local u = activated[i]
            report_defining("character 0x%05X is active in sets %s (%s)",u,concat(tobeactivated,","),data[u].description)
        end
        local saved = tex.catcodetable
        for i=1,#tobeactivated do
            local vector = tobeactivated[i]
            if trace_defining then
                report_defining("defining %s active characters in vector %s",nofactivated,vector)
            end
            tex.catcodetable = vector
            for i=1,nofactivated do
                texsetcatcode(activated[i],13)
            end
        end
        tex.catcodetable = saved
    end

end

--[[ldx--
<p>Setting the lccodes is also done in a loop over the data table.</p>
--ldx]]--

--~ function tex.setsfcode (index,sf) ... end
--~ function tex.setlccode (index,lc,[uc]) ... end -- optional third value, safes call
--~ function tex.setuccode (index,uc,[lc]) ... end
--~ function tex.setcatcode(index,cc) ... end

-- we need a function ...

--~ tex.lccode
--~ tex.uccode
--~ tex.sfcode
--~ tex.catcode

function characters.setcodes()
    if trace_defining then
        report_defining("defining lc and uc codes")
    end
    for code, chr in next, data do
        local cc = chr.category
        if is_letter[cc] then
            local range = chr.range
            if range then
                for i=range.first,range.last do
                    texsetcatcode(i,11) -- letter
                    texsetlccode(i,i,i) -- self self
                end
            else
                local lc, uc = chr.lccode, chr.uccode
                if not lc then chr.lccode, lc = code, code end
                if not uc then chr.uccode, uc = code, code end
                texsetcatcode(code,11)   -- letter
                if type(lc) == "table" then
                    lc = code
                end
                if type(uc) == "table" then
                    uc = code
                end
                texsetlccode(code,lc,uc)
                if cc == "lu" then
                    texsetsfcode(code,999)
                end
            end
        elseif is_mark[cc] then
            texsetlccode(code,code,code) -- for hyphenation
        end
    end
end

--[[ldx--
<p>Next comes a whole series of helper methods. These are (will be) part
of the official <l n='api'/>.</p>
--ldx]]--

--[[ldx--
<p>A couple of convenience methods. Beware, these are slower than directly
accessing the data table.</p>
--ldx]]--

-- we could make them virtual: characters.contextnames[n]

function characters.contextname(n) return data[n].contextname or "" end
function characters.adobename  (n) return data[n].adobename   or "" end
function characters.description(n) return data[n].description or "" end
-------- characters.category   (n) return data[n].category    or "" end

function characters.category(n,verbose)
    local c = data[n].category
    if not c then
        return ""
    elseif verbose then
        return categorytags[c]
    else
        return c
    end
end

-- xml support (moved)

function characters.remapentity(chr,slot)
    texsprint(format("{\\catcode%s=13\\xdef%s{\\string%s}}",slot,utfchar(slot),chr))
end

characters.activeoffset = 0x10000 -- there will be remapped in that byte range

-- xml.entities = xml.entities or { }
--
-- storage.register("xml/entities",xml.entities,"xml.entities") -- this will move to lxml
--
-- function characters.setmkiventities()
--     local entities = xml.entities
--     entities.lt  = "<"
--     entities.amp = "&"
--     entities.gt  = ">"
-- end
--
-- function characters.setmkiientities()
--     local entities = xml.entities
--     entities.lt  = utfchar(characters.activeoffset + utfbyte("<"))
--     entities.amp = utfchar(characters.activeoffset + utfbyte("&"))
--     entities.gt  = utfchar(characters.activeoffset + utfbyte(">"))
-- end

-- some day we will make a table

local function utfstring(s)
    if type(s) == "table" then
        return utfchar(unpack(s)) -- concat { utfchar( unpack(s) ) }
    else
        return utfchar(s)
    end
end

utf.string = utf.string or utfstring

local categories = allocate()  characters.categories = categories -- lazy table

setmetatableindex(categories, function(t,u) if u then local c = data[u] c = c and c.category or u t[u] = c return c end end)

local lccodes = allocate()  characters.lccodes = lccodes -- lazy table
local uccodes = allocate()  characters.uccodes = uccodes -- lazy table
local shcodes = allocate()  characters.shcodes = shcodes -- lazy table
local fscodes = allocate()  characters.fscodes = fscodes -- lazy table

setmetatableindex(lccodes, function(t,u) if u then local c = data[u] c = c and c.lccode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(uccodes, function(t,u) if u then local c = data[u] c = c and c.uccode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(shcodes, function(t,u) if u then local c = data[u] c = c and c.shcode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(fscodes, function(t,u) if u then local c = data[u] c = c and c.fscode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)

local lcchars = allocate()  characters.lcchars = lcchars -- lazy table
local ucchars = allocate()  characters.ucchars = ucchars -- lazy table
local shchars = allocate()  characters.shchars = shchars -- lazy table
local fschars = allocate()  characters.fschars = fschars -- lazy table

setmetatableindex(lcchars, function(t,u) if u then local c = data[u] c = c and c.lccode c = c and utfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(ucchars, function(t,u) if u then local c = data[u] c = c and c.uccode c = c and utfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(shchars, function(t,u) if u then local c = data[u] c = c and c.shcode c = c and utfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(fschars, function(t,u) if u then local c = data[u] c = c and c.fscode c = c and utfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)

local decomposed = allocate()  characters.decomposed = decomposed   -- lazy table

setmetatableindex(decomposed, function(t,u) -- either a table or false
    if u then
        local c = data[u]
        local s = c and c.decomposed or false
        t[u] = s
        return s
    end
end)

local specialchars = allocate()  characters.specialchars = specialchars -- lazy table
local descriptions = allocate()  characters.descriptions = descriptions -- lazy table

setmetatableindex(specialchars, function(t,u)
    if u then
        local c = data[u]
        local s = c and c.specials
        if s then
            local tt, ttn = { }, 0
            for i=2,#s do
                local si = s[i]
                local c = data[si]
                if is_letter[c.category] then
                    ttn = ttn + 1
                    tt[ttn] = utfchar(si)
                end
            end
            c = concat(tt)
            t[u] = c
            return c
        else
            if type(u) == "number" then
                u = utfchar(u)
            end
            t[u] = u
            return u
        end
    end
end)

setmetatableindex(descriptions, function(t,k)
    -- 0.05 - 0.10 sec
    for u, c in next, data do
        local d = c.description
        if d then
            d = gsub(d," ","")
            d = lower(d)
            t[d] = u
        end
    end
    local d = rawget(t,k)
    if not d then
        t[k] = k
    end
    return d
end)

function characters.unicodechar(asked)
    local n = tonumber(asked)
    if n then
        return n
    elseif type(asked) == "string" then
        asked = gsub(asked," ","")
        return descriptions[asked]
    end
end

function characters.lower(str)
    local new, n = { }, 0
    for u in utfvalues(str) do
        n = n + 1
        new[n] = lcchars[u]
    end
    return concat(new)
end

function characters.upper(str)
    local new, n = { }, 0
    for u in utfvalues(str) do
        n = n + 1
        new[n] = ucchars[u]
    end
    return concat(new)
end

function characters.shaped(str)
    local new, n = { }, 0
    for u in utfvalues(str) do
        n = n + 1
        new[n] = shchars[u]
    end
    return concat(new)
end

function characters.lettered(str,spacing)
    local new, n = { }, 0
    if spacing then
        local done = false
        for u in utfvalues(str) do
            local c = data[u].category
            if is_letter[c] then
                if done and n > 1 then
                    n = n + 1
                    new[n] = " "
                    done = false
                end
                n = n + 1
                new[n] = utfchar(u)
            elseif spacing and is_spacing[c] then
                done = true
            end
        end
    else
        for u in utfvalues(str) do
            if is_letter[data[u].category] then
                n = n + 1
                new[n] = utfchar(u)
            end
        end
    end
    return concat(new)
end
--[[ldx--
<p>Requesting lower and uppercase codes:</p>
--ldx]]--

function characters.uccode(n) return uccodes[n] end -- obsolete
function characters.lccode(n) return lccodes[n] end -- obsolete

function characters.flush(n,direct)
    local c = data[n]
    if c and c.contextname then
        c = "\\" .. c.contextname
    else
        c = utfchar(n)
    end
    if direct then
        return c
    else
        texsprint(c)
    end
end

function characters.shape(n)
    local shcode = shcodes[n]
    if not shcode then
        return n, nil
    elseif type(shcode) == "table" then
        return shcode[1], shcode[#shcode]
    else
        return shcode, nil
    end
end

-- -- some day we might go this route, but it does not really save that much
-- -- so not now (we can generate a lot using mtx-unicode that operates on the
-- -- database)
--
-- -- category cjkwd direction linebreak
--
-- -- adobename comment contextcommand contextname description fallback lccode
-- -- mathclass mathfiller mathname mathspec mathstretch mathsymbol mirror
-- -- range shcode specials uccode uccodes unicodeslot
--
-- local data = {
--     ['one']={
--         common = {
--             category="cc",
--             direction="bn",
--             linebreak="cm",
--         },
--         vector = {
--             [0x0000] = {
--                 description="NULL",
--                 group='one',
--                 unicodeslot=0x0000,
--             },
--             {
--                 description="START OF HEADING",
--                 group='one',
--                 unicodeslot=0x0001,
--             },
--         }
--     }
-- }
--
-- local chardata, groupdata = { }, { }
--
-- for group, gdata in next, data do
--     local common, vector = { __index = gdata.common }, gdata.vector
--     for character, cdata in next, vector do
--         chardata[character] = cdata
--         setmetatable(cdata,common)
--     end
--     groupdata[group] = gdata
-- end

--~ characters.data, characters.groups = chardata, groupdata

--~  [0xF0000]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x000F Private Use, First>",
--~   direction="l",
--~   unicodeslot=0xF0000,
--~  },
--~  [0xFFFFD]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x000F Private Use, Last>",
--~   direction="l",
--~   unicodeslot=0xFFFFD,
--~  },
--~  [0x100000]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x0010 Private Use, First>",
--~   direction="l",
--~   unicodeslot=0x100000,
--~  },
--~  [0x10FFFD]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x0010 Private Use, Last>",
--~   direction="l",
--~   unicodeslot=0x10FFFD,
--~  },

if not characters.superscripts then

    local superscripts = allocate()   characters.superscripts = superscripts
    local subscripts   = allocate()   characters.subscripts   = subscripts

    -- skipping U+02120 (service mark) U+02122 (trademark)

    for k, v in next, data do
        local specials = v.specials
        if specials then
            local what = specials[1]
            if what == "super" then
                if #specials == 2 then
                    superscripts[k] = specials[2]
                else
                    report_defining("ignoring superscript %s %s: %s",ustring(k),utfchar(k),v.description)
                end
            elseif what == "sub" then
                if #specials == 2 then
                    subscripts[k] = specials[2]
                else
                    report_defining("ignoring subscript %s %s: %s",ustring(k),utfchar(k),v.description)
                end
            end
        end
    end

 -- print(table.serialize(superscripts, "superscripts", { hexify = true }))
 -- print(table.serialize(subscripts,   "subscripts",   { hexify = true }))

    storage.register("characters/superscripts", superscripts, "characters.superscripts")
    storage.register("characters/subscripts",   subscripts,   "characters.subscripts")

end
