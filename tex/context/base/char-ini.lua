if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tex = tex
local utf = unicode.utf8

local utfchar, utfbyte, utfvalues = utf.char, utf.byte, string.utfvalues
local concat, unpack = table.concat, table.unpack
local next, tonumber, type, rawget, rawset = next, tonumber, type, rawget, rawset
local texsprint, texprint = tex.sprint, tex.print
local format, lower, gsub, match, gmatch = string.format, string.lower, string.gsub, string.match, string.match, string.gmatch
local texsetlccode, texsetuccode, texsetsfcode, texsetcatcode  = tex.setlccode, tex.setuccode, tex.setsfcode, tex.setcatcode
local P, R, lpegmatch = lpeg.P, lpeg.R, lpeg.match

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local ctxcatcodes = tex.ctxcatcodes
local texcatcodes = tex.texcatcodes

local trace_defining = false  trackers.register("characters.defining",   function(v) characters_defining = v end)

local report_defining = logs.new("characters")

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

if not characters.ranges then
    local ranges = allocate { }
    characters.ranges = ranges
    for k, v in next, data do
        ranges[#ranges+1] = k
    end
end

storage.register("characters/ranges",characters.ranges,"characters.ranges")

local ranges = characters.ranges

--[[ldx--
<p>This converts a string (if given) into a number.</p>
--ldx]]--

local pattern = (P("0x") + P("U+")) * ((R("09","AF")^1 * P(-1)) / function(s) return tonumber(s,16) end)

lpeg.patterns.chartonumber = pattern

local function chartonumber(k)
    return type(k) == "string" and (lpegmatch(pattern,k) or utfbyte(k)) or k
end

--~ print(chartonumber(97), chartonumber("a"), chartonumber("0x61"), chartonumber("U+61"))

characters.tonumber = chartonumber

setmetatablekey(data, "__index", function(t,k)
    if type(k) == "string" then
        k = lpegmatch(pattern,k) or utfbyte(k)
        if k then
            local tk = rawget(t,k)
            if tk then
                return tk
            else
                -- goes to ranges
            end
        else
            return nil
        end
    end
    for r=1,#ranges do
        local rr = ranges[r] -- first in range
        if k > rr and k <= data[rr].range then
            t[k] = t[rr]
            return t[k]
        end
    end
    return nil
end )

characters.blocks = allocate {
    ["aegeannumbers"]                        = { 0x10100, 0x1013F, "Aegean Numbers" },
    ["alphabeticpresentationforms"]          = { 0x0FB00, 0x0FB4F, "Alphabetic Presentation Forms" },
    ["ancientgreekmusicalnotation"]          = { 0x1D200, 0x1D24F, "Ancient Greek Musical Notation" },
    ["ancientgreeknumbers"]                  = { 0x10140, 0x1018F, "Ancient Greek Numbers" },
    ["ancientsymbols"]                       = { 0x10190, 0x101CF, "Ancient Symbols" },
    ["arabic"]                               = { 0x00600, 0x006FF, "Arabic" },
    ["arabicpresentationformsa"]             = { 0x0FB50, 0x0FDFF, "Arabic Presentation Forms-A" },
    ["arabicpresentationformsb"]             = { 0x0FE70, 0x0FEFF, "Arabic Presentation Forms-B" },
    ["arabicsupplement"]                     = { 0x00750, 0x0077F, "Arabic Supplement" },
    ["armenian"]                             = { 0x00530, 0x0058F, "Armenian" },
    ["arrows"]                               = { 0x02190, 0x021FF, "Arrows" },
    ["balinese"]                             = { 0x01B00, 0x01B7F, "Balinese" },
    ["basiclatin"]                           = { 0x00000, 0x0007F, "Basic Latin" },
    ["bengali"]                              = { 0x00980, 0x009FF, "Bengali" },
    ["blockelements"]                        = { 0x02580, 0x0259F, "Block Elements" },
    ["bopomofo"]                             = { 0x03100, 0x0312F, "Bopomofo" },
    ["bopomofoextended"]                     = { 0x031A0, 0x031BF, "Bopomofo Extended" },
    ["boxdrawing"]                           = { 0x02500, 0x0257F, "Box Drawing" },
    ["braillepatterns"]                      = { 0x02800, 0x028FF, "Braille Patterns" },
    ["buginese"]                             = { 0x01A00, 0x01A1F, "Buginese" },
    ["buhid"]                                = { 0x01740, 0x0175F, "Buhid" },
    ["byzantinemusicalsymbols"]              = { 0x1D000, 0x1D0FF, "Byzantine Musical Symbols" },
    ["carian"]                               = { 0x102A0, 0x102DF, "Carian" },
    ["cham"]                                 = { 0x0AA00, 0x0AA5F, "Cham" },
    ["cherokee"]                             = { 0x013A0, 0x013FF, "Cherokee" },
    ["cjkcompatibility"]                     = { 0x03300, 0x033FF, "CJK Compatibility" },
    ["cjkcompatibilityforms"]                = { 0x0FE30, 0x0FE4F, "CJK Compatibility Forms" },
    ["cjkcompatibilityideographs"]           = { 0x0F900, 0x0FAFF, "CJK Compatibility Ideographs" },
    ["cjkcompatibilityideographssupplement"] = { 0x2F800, 0x2FA1F, "CJK Compatibility Ideographs Supplement" },
    ["cjkradicalssupplement"]                = { 0x02E80, 0x02EFF, "CJK Radicals Supplement" },
    ["cjkstrokes"]                           = { 0x031C0, 0x031EF, "CJK Strokes" },
    ["cjksymbolsandpunctuation"]             = { 0x03000, 0x0303F, "CJK Symbols and Punctuation" },
    ["cjkunifiedideographs"]                 = { 0x04E00, 0x09FFF, "CJK Unified Ideographs" },
    ["cjkunifiedideographsextensiona"]       = { 0x03400, 0x04DBF, "CJK Unified Ideographs Extension A" },
    ["cjkunifiedideographsextensionb"]       = { 0x20000, 0x2A6DF, "CJK Unified Ideographs Extension B" },
    ["combiningdiacriticalmarks"]            = { 0x00300, 0x0036F, "Combining Diacritical Marks" },
    ["combiningdiacriticalmarksforsymbols"]  = { 0x020D0, 0x020FF, "Combining Diacritical Marks for Symbols" },
    ["combiningdiacriticalmarkssupplement"]  = { 0x01DC0, 0x01DFF, "Combining Diacritical Marks Supplement" },
    ["combininghalfmarks"]                   = { 0x0FE20, 0x0FE2F, "Combining Half Marks" },
    ["controlpictures"]                      = { 0x02400, 0x0243F, "Control Pictures" },
    ["coptic"]                               = { 0x02C80, 0x02CFF, "Coptic" },
    ["countingrodnumerals"]                  = { 0x1D360, 0x1D37F, "Counting Rod Numerals" },
    ["cuneiform"]                            = { 0x12000, 0x123FF, "Cuneiform" },
    ["cuneiformnumbersandpunctuation"]       = { 0x12400, 0x1247F, "Cuneiform Numbers and Punctuation" },
    ["currencysymbols"]                      = { 0x020A0, 0x020CF, "Currency Symbols" },
    ["cypriotsyllabary"]                     = { 0x10800, 0x1083F, "Cypriot Syllabary" },
    ["cyrillic"]                             = { 0x00400, 0x004FF, "Cyrillic" },
    ["cyrillicextendeda"]                    = { 0x02DE0, 0x02DFF, "Cyrillic Extended-A" },
    ["cyrillicextendedb"]                    = { 0x0A640, 0x0A69F, "Cyrillic Extended-B" },
    ["cyrillicsupplement"]                   = { 0x00500, 0x0052F, "Cyrillic Supplement" },
    ["deseret"]                              = { 0x10400, 0x1044F, "Deseret" },
    ["devanagari"]                           = { 0x00900, 0x0097F, "Devanagari" },
    ["dingbats"]                             = { 0x02700, 0x027BF, "Dingbats" },
    ["dominotiles"]                          = { 0x1F030, 0x1F09F, "Domino Tiles" },
    ["enclosedalphanumerics"]                = { 0x02460, 0x024FF, "Enclosed Alphanumerics" },
    ["enclosedcjklettersandmonths"]          = { 0x03200, 0x032FF, "Enclosed CJK Letters and Months" },
    ["ethiopic"]                             = { 0x01200, 0x0137F, "Ethiopic" },
    ["ethiopicextended"]                     = { 0x02D80, 0x02DDF, "Ethiopic Extended" },
    ["ethiopicsupplement"]                   = { 0x01380, 0x0139F, "Ethiopic Supplement" },
    ["generalpunctuation"]                   = { 0x02000, 0x0206F, "General Punctuation" },
    ["geometricshapes"]                      = { 0x025A0, 0x025FF, "Geometric Shapes" },
    ["georgian"]                             = { 0x010A0, 0x010FF, "Georgian" },
    ["georgiansupplement"]                   = { 0x02D00, 0x02D2F, "Georgian Supplement" },
    ["glagolitic"]                           = { 0x02C00, 0x02C5F, "Glagolitic" },
    ["gothic"]                               = { 0x10330, 0x1034F, "Gothic" },
    ["greekandcoptic"]                       = { 0x00370, 0x003FF, "Greek and Coptic" },
    ["greekextended"]                        = { 0x01F00, 0x01FFF, "Greek Extended" },
    ["gujarati"]                             = { 0x00A80, 0x00AFF, "Gujarati" },
    ["gurmukhi"]                             = { 0x00A00, 0x00A7F, "Gurmukhi" },
    ["halfwidthandfullwidthforms"]           = { 0x0FF00, 0x0FFEF, "Halfwidth and Fullwidth Forms" },
    ["hangulcompatibilityjamo"]              = { 0x03130, 0x0318F, "Hangul Compatibility Jamo" },
    ["hanguljamo"]                           = { 0x01100, 0x011FF, "Hangul Jamo" },
    ["hangulsyllables"]                      = { 0x0AC00, 0x0D7AF, "Hangul Syllables" },
    ["hanunoo"]                              = { 0x01720, 0x0173F, "Hanunoo" },
    ["hebrew"]                               = { 0x00590, 0x005FF, "Hebrew" },
    ["highprivateusesurrogates"]             = { 0x0DB80, 0x0DBFF, "High Private Use Surrogates" },
    ["highsurrogates"]                       = { 0x0D800, 0x0DB7F, "High Surrogates" },
    ["hiragana"]                             = { 0x03040, 0x0309F, "Hiragana" },
    ["ideographicdescriptioncharacters"]     = { 0x02FF0, 0x02FFF, "Ideographic Description Characters" },
    ["ipaextensions"]                        = { 0x00250, 0x02AF, "IPA Extensions" },
    ["kanbun"]                               = { 0x03190, 0x0319F, "Kanbun" },
    ["kangxiradicals"]                       = { 0x02F00, 0x02FDF, "Kangxi Radicals" },
    ["kannada"]                              = { 0x00C80, 0x00CFF, "Kannada" },
    ["katakana"]                             = { 0x030A0, 0x030FF, "Katakana" },
    ["katakanaphoneticextensions"]           = { 0x031F0, 0x031FF, "Katakana Phonetic Extensions" },
    ["kayahli"]                              = { 0x0A900, 0x0A92F, "Kayah Li" },
    ["kharoshthi"]                           = { 0x10A00, 0x10A5F, "Kharoshthi" },
    ["khmer"]                                = { 0x01780, 0x017FF, "Khmer" },
    ["khmersymbols"]                         = { 0x019E0, 0x019FF, "Khmer Symbols" },
    ["lao"]                                  = { 0x00E80, 0x00EFF, "Lao" },
    ["latinextendeda"]                       = { 0x00100, 0x0017F, "Latin Extended-A" },
    ["latinextendedadditional"]              = { 0x01E00, 0x01EFF, "Latin Extended Additional" },
    ["latinextendedb"]                       = { 0x00180, 0x0024F, "Latin Extended-B" },
    ["latinextendedc"]                       = { 0x02C60, 0x02C7F, "Latin Extended-C" },
    ["latinextendedd"]                       = { 0x0A720, 0x0A7FF, "Latin Extended-D" },
    ["latinsupplement"]                      = { 0x00080, 0x000FF, "Latin-1 Supplement" },
    ["lepcha"]                               = { 0x01C00, 0x01C4F, "Lepcha" },
    ["letterlikesymbols"]                    = { 0x02100, 0x0214F, "Letterlike Symbols" },
    ["limbu"]                                = { 0x01900, 0x0194F, "Limbu" },
    ["linearbideograms"]                     = { 0x10080, 0x100FF, "Linear B Ideograms" },
    ["linearbsyllabary"]                     = { 0x10000, 0x1007F, "Linear B Syllabary" },
    ["lowsurrogates"]                        = { 0x0DC00, 0x0DFFF, "Low Surrogates" },
    ["lycian"]                               = { 0x10280, 0x1029F, "Lycian" },
    ["lydian"]                               = { 0x10920, 0x1093F, "Lydian" },
    ["mahjongtiles"]                         = { 0x1F000, 0x1F02F, "Mahjong Tiles" },
    ["malayalam"]                            = { 0x00D00, 0x00D7F, "Malayalam" },
    ["mathematicalalphanumericsymbols"]      = { 0x1D400, 0x1D7FF, "Mathematical Alphanumeric Symbols" },
    ["mathematicaloperators"]                = { 0x02200, 0x022FF, "Mathematical Operators" },
    ["miscellaneousmathematicalsymbolsa"]    = { 0x027C0, 0x027EF, "Miscellaneous Mathematical Symbols-A" },
    ["miscellaneousmathematicalsymbolsb"]    = { 0x02980, 0x029FF, "Miscellaneous Mathematical Symbols-B" },
    ["miscellaneoussymbols"]                 = { 0x02600, 0x026FF, "Miscellaneous Symbols" },
    ["miscellaneoussymbolsandarrows"]        = { 0x02B00, 0x02BFF, "Miscellaneous Symbols and Arrows" },
    ["miscellaneoustechnical"]               = { 0x02300, 0x023FF, "Miscellaneous Technical" },
    ["modifiertoneletters"]                  = { 0x0A700, 0x0A71F, "Modifier Tone Letters" },
    ["mongolian"]                            = { 0x01800, 0x018AF, "Mongolian" },
    ["musicalsymbols"]                       = { 0x1D100, 0x1D1FF, "Musical Symbols" },
    ["myanmar"]                              = { 0x01000, 0x0109F, "Myanmar" },
    ["newtailue"]                            = { 0x01980, 0x019DF, "New Tai Lue" },
    ["nko"]                                  = { 0x007C0, 0x007FF, "NKo" },
    ["numberforms"]                          = { 0x02150, 0x0218F, "Number Forms" },
    ["ogham"]                                = { 0x01680, 0x0169F, "Ogham" },
    ["olchiki"]                              = { 0x01C50, 0x01C7F, "Ol Chiki" },
    ["olditalic"]                            = { 0x10300, 0x1032F, "Old Italic" },
    ["oldpersian"]                           = { 0x103A0, 0x103DF, "Old Persian" },
    ["opticalcharacterrecognition"]          = { 0x02440, 0x0245F, "Optical Character Recognition" },
    ["oriya"]                                = { 0x00B00, 0x00B7F, "Oriya" },
    ["osmanya"]                              = { 0x10480, 0x104AF, "Osmanya" },
    ["phagspa"]                              = { 0x0A840, 0x0A87F, "Phags-pa" },
    ["phaistosdisc"]                         = { 0x101D0, 0x101FF, "Phaistos Disc" },
    ["phoenician"]                           = { 0x10900, 0x1091F, "Phoenician" },
    ["phoneticextensions"]                   = { 0x01D00, 0x01D7F, "Phonetic Extensions" },
    ["phoneticextensionssupplement"]         = { 0x01D80, 0x01DBF, "Phonetic Extensions Supplement" },
    ["privateusearea"]                       = { 0x0E000, 0x0F8FF, "Private Use Area" },
    ["rejang"]                               = { 0x0A930, 0x0A95F, "Rejang" },
    ["runic"]                                = { 0x016A0, 0x016FF, "Runic" },
    ["saurashtra"]                           = { 0x0A880, 0x0A8DF, "Saurashtra" },
    ["shavian"]                              = { 0x10450, 0x1047F, "Shavian" },
    ["sinhala"]                              = { 0x00D80, 0x00DFF, "Sinhala" },
    ["smallformvariants"]                    = { 0x0FE50, 0x0FE6F, "Small Form Variants" },
    ["spacingmodifierletters"]               = { 0x002B0, 0x002FF, "Spacing Modifier Letters" },
    ["specials"]                             = { 0x0FFF0, 0x0FFFF, "Specials" },
    ["sundanese"]                            = { 0x01B80, 0x01BBF, "Sundanese" },
    ["superscriptsandsubscripts"]            = { 0x02070, 0x0209F, "Superscripts and Subscripts" },
    ["supplementalarrowsa"]                  = { 0x027F0, 0x027FF, "Supplemental Arrows-A" },
    ["supplementalarrowsb"]                  = { 0x02900, 0x0297F, "Supplemental Arrows-B" },
    ["supplementalmathematicaloperators"]    = { 0x02A00, 0x02AFF, "Supplemental Mathematical Operators" },
    ["supplementalpunctuation"]              = { 0x02E00, 0x02E7F, "Supplemental Punctuation" },
    ["supplementaryprivateuseareaa"]         = { 0xF0000, 0xFFFFF, "Supplementary Private Use Area-A" },
    ["supplementaryprivateuseareab"]         = { 0x100000,0x10FFFF,"Supplementary Private Use Area-B" },
    ["sylotinagri"]                          = { 0x0A800, 0x0A82F, "Syloti Nagri" },
    ["syriac"]                               = { 0x00700, 0x0074F, "Syriac" },
    ["tagalog"]                              = { 0x01700, 0x0171F, "Tagalog" },
    ["tagbanwa"]                             = { 0x01760, 0x0177F, "Tagbanwa" },
    ["tags"]                                 = { 0xE0000, 0xE007F, "Tags" },
    ["taile"]                                = { 0x01950, 0x0197F, "Tai Le" },
    ["taixuanjingsymbols"]                   = { 0x1D300, 0x1D35F, "Tai Xuan Jing Symbols" },
    ["tamil"]                                = { 0x00B80, 0x00BFF, "Tamil" },
    ["telugu"]                               = { 0x00C00, 0x00C7F, "Telugu" },
    ["thaana"]                               = { 0x00780, 0x007BF, "Thaana" },
    ["thai"]                                 = { 0x00E00, 0x00E7F, "Thai" },
    ["tibetan"]                              = { 0x00F00, 0x00FFF, "Tibetan" },
    ["tifinagh"]                             = { 0x02D30, 0x02D7F, "Tifinagh" },
    ["ugaritic"]                             = { 0x10380, 0x1039F, "Ugaritic" },
    ["unifiedcanadianaboriginalsyllabics"]   = { 0x01400, 0x0167F, "Unified Canadian Aboriginal Syllabics" },
    ["vai"]                                  = { 0x0A500, 0x0A63F, "Vai" },
    ["variationselectors"]                   = { 0x0FE00, 0x0FE0F, "Variation Selectors" },
    ["variationselectorssupplement"]         = { 0xE0100, 0xE01EF, "Variation Selectors Supplement" },
    ["verticalforms"]                        = { 0x0FE10, 0x0FE1F, "Vertical Forms" },
    ["yijinghexagramsymbols"]                = { 0x04DC0, 0x04DFF, "Yijing Hexagram Symbols" },
    ["yiradicals"]                           = { 0x0A490, 0x0A4CF, "Yi Radicals" },
    ["yisyllables"]                          = { 0x0A000, 0x0A48F, "Yi Syllables" },
}

function characters.getrange(name)
    local tag = lower(name)
    tag = gsub(name,"[^a-z]", "")
    local range = characters.blocks[tag]
    if range then
        return range[1], range[2], range[3]
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

characters.categories = allocate {
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

characters.is_character = is_character
characters.is_letter    = is_letter
characters.is_command   = is_command

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

table.setemptymetatable(data) -- so each key resolves to ""

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
        texsprint(c,utfchar(n))
    else
        texsprint(utfchar(c))
    end
end

if texsetcatcode then

    -- todo -- define per table and then also register name (for tracing)

    function characters.define(tobelettered, tobeactivated) -- catcodetables

        if trace_defining then
            report_defining("defining active character commands")
        end

        local activated = { }

        for u, chr in next, data do -- these will be commands
            local fallback = chr.fallback
            if fallback then
                texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\checkedchar{",u,"}{",fallback,"}}}") -- no texprint
                activated[#activated+1] = u
            else
                local contextname = chr.contextname
                if contextname then
                    local category = chr.category
                    if is_character[category] then
                        if chr.unicodeslot < 128 then
                            texprint(ctxcatcodes,format("\\chardef\\%s=%s",contextname,u))
                        else
                            texprint(ctxcatcodes,format("\\let\\%s=%s",contextname,utfchar(u)))
                        end
                    elseif is_command[category] then
                        texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\"..contextname,"}}") -- no texprint
                        activated[#activated+1] = u
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
                    if chr.range then
                        for i=1,u,chr.range do
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

else -- char-obs

    local template_a = "\\startextendcatcodetable{%s}\\chardef\\l=11\\chardef\\a=13\\let\\c\\catcode%s\\let\\a\\undefined\\let\\l\\undefined\\let\\c\\undefined\\stopextendcatcodetable"
    local template_b = "\\chardef\\l=11\\chardef\\a=13\\let\\c\\catcode%s\\let\\a\\undefined\\let\\l\\undefined\\let\\c\\undefined"

    function characters.define(tobelettered, tobeactivated) -- catcodetables
        local lettered, activated = { }, { }
        for u, chr in next, data do
            -- we can use a macro instead of direct settings
            local fallback = chr.fallback
            if fallback then
            --  texprint(format("{\\catcode %s=13\\unexpanded\\gdef %s{\\checkedchar{%s}{%s}}}",u,utfchar(u),u,fallback))
                texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\checkedchar{",u,"}{",fallback,"}}}") -- no texprint
                activated[#activated+1] = "\\c"..u.."\\a"
            else
                local contextname = chr.contextname
                local category = chr.category
                if contextname then
                    if is_character[category] then
                     -- by this time, we're still in normal catcode mode
                     -- subtle: not "\\",contextname but "\\"..contextname
                        if chr.unicodeslot < 128 then
                            texprint(ctxcatcodes,format("\\chardef\\%s=%s",contextname,u))
                        else
                            texprint(ctxcatcodes,format("\\let\\%s=%s",contextname,utfchar(u)))
                            if is_letter[category] then
                                lettered[#lettered+1] = "\\c"..u.."\\l"
                            end
                        end
                    elseif is_command[category] then
                        -- this might change: contextcommand ipv contextname
                    --  texprint(format("{\\catcode %s=13\\unexpanded\\gdef %s{\\%s}}",u,utfchar(u),contextname))
                        texsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\"..contextname,"}}") -- no texprint
                        activated[#activated+1] = "\\c"..u.."\\a"
                    end
                elseif is_letter[category] then
                    if u >= 128 and u <= 65536 then -- catch private mess
                        lettered[#lettered+1] = "\\c"..u.."\\l"
                    end
                end
            end
            if chr.range then
                lettered[#lettered+1] = format('\\dofastrecurse{"%05X}{"%05X}{1}{\\c\\fastrecursecounter\\l}',u,chr.range)
            end
        end
     -- if false then
        lettered[#lettered+1] = "\\c"..0x200C.."\\l" -- non-joiner
        lettered[#lettered+1] = "\\c"..0x200D.."\\l" -- joiner
     -- fi
        if tobelettered then
            lettered = concat(lettered)
            if true then
                texsprint(ctxcatcodes,format(template_b,lettered)) -- global
            else
                for l=1,#tobelettered do
                    texsprint(ctxcatcodes,format(template_a,tobelettered[l],lettered))
                end
            end
        end
        if tobeactivated then
            activated = concat(activated)
            for a=1,#tobeactivated do
                texsprint(ctxcatcodes,format(template_a,tobeactivated[a],activated))
            end
        end
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

if texsetcatcode then

    function characters.setcodes()
        if trace_defining then
            report_defining("defining lc and uc codes")
        end
        for code, chr in next, data do
            local cc = chr.category
            if cc == 'll' or cc == 'lu' or cc == 'lt' then
                local lc, uc = chr.lccode, chr.uccode
                if not lc then chr.lccode, lc = code, code end
                if not uc then chr.uccode, uc = code, code end
                texsetcatcode(code,11)   -- letter
                texsetlccode(code,lc,uc)
                if cc == "lu" then
                    texsetsfcode(code,999)
                end
            elseif cc == "lo" and chr.range then
                for i=code,chr.range do
                    texsetcatcode(code,11)       -- letter
                    texsetlccode(code,code,code) -- self self
                end
            end
        end
    end

else -- char-obs

    function characters.setcodes()
        for code, chr in next, data do
            local cc = chr.category
            if cc == 'll' or cc == 'lu' or cc == 'lt' then
                local lc, uc = chr.lccode, chr.uccode
                if not lc then chr.lccode, lc = code, code end
                if not uc then chr.uccode, uc = code, code end
                texsprint(ctxcatcodes,format("\\setcclcuc{%i}{%i}{%i}",code,lc,uc))
            end
            if cc == "lu" then
                texprint(ctxcatcodes,"\\sfcode ",code,"999 ")
            end
            if cc == "lo" and chr.range then
                texsprint(ctxcatcodes,format('\\dofastrecurse{"%05X}{"%05X}{1}{\\setcclcucself\\fastrecursecounter}',code,chr.range))
            end
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
function characters.category   (n) return data[n].category    or "" end

--[[ldx--
<p>Requesting lower and uppercase codes:</p>
--ldx]]--

function characters.uccode(n) return data[n].uccode or n end
function characters.lccode(n) return data[n].lccode or n end

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
    local shcode = data[n].shcode
    if not shcode then
        return n, nil
    elseif type(shcode) == "table" then
        return shcode[1], shcode[#shcode]
    else
        return shcode, nil
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
        return concat { utfchar( unpack(s) ) }
    else
        return utfchar(s)
    end
end

utf.string = utf.string or utfstring

characters.categories = allocate()  local categories = characters.categories -- lazy table

setmetatable(categories, { __index = function(t,u) if u then local c = data[u] c = c and c.category or u t[u] = c return c end end } )

characters.lccodes    = allocate()  local lccodes    = characters.lccodes    -- lazy table
characters.uccodes    = allocate()  local uccodes    = characters.uccodes    -- lazy table
characters.shcodes    = allocate()  local shcodes    = characters.shcodes    -- lazy table

setmetatable(lccodes,    { __index = function(t,u) if u then local c = data[u] c = c and c.lccode   or u t[u] = c return c end end } )
setmetatable(uccodes,    { __index = function(t,u) if u then local c = data[u] c = c and c.uccode   or u t[u] = c return c end end } )
setmetatable(shcodes,    { __index = function(t,u) if u then local c = data[u] c = c and c.shcode   or u t[u] = c return c end end } )

characters.lcchars = allocate()  local lcchars = characters.lcchars -- lazy table
characters.ucchars = allocate()  local ucchars = characters.ucchars -- lazy table
characters.shchars = allocate()  local shchars = characters.shchars -- lazy table

setmetatable(lcchars, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.lccode c = c and utfchar  (c) or u t[u] = c return c end end } )
setmetatable(ucchars, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.uccode c = c and utfchar  (c) or u t[u] = c return c end end } )
setmetatable(shchars, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.shcode c = c and utfstring(c) or u t[u] = c return c end end } )

--~ characters.lccharcodes = allocate()  local lccharcodes = characters.lccharcodes -- lazy table
--~ characters.uccharcodes = allocate()  local uccharcodes = characters.uccharcodes -- lazy table
--~ characters.shcharcodes = allocate()  local shcharcodes = characters.shcharcodes -- lazy table

--~ setmetatable(lccharcodes, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.lccode or u t[u] = c return c end end } )
--~ setmetatable(uccharcodes, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.uccode or u t[u] = c return c end end } )
--~ setmetatable(shcharcodes, { __index = function(t,u) if u then local c = data[utfbyte(u)] c = c and c.shcode or u t[u] = c return c end end } )

characters.specialchars = allocate()  local specialchars = characters.specialchars -- lazy table

setmetatable(specialchars, { __index = function(t,u)
    if u then
        local c = data[utfbyte(u)]
        local s = c and c.specials
        if s then
            local t = { }
            for i=2,#s do
                local si = s[i]
                local c = data[si]
                if is_letter[c.category] then
                    t[#t+1] = utfchar(si)
                end
            end
            c = concat(t)
            t[u] = c
            return c
        else
            t[u] = u
            return u
        end
    end
end } )

function characters.lower(str)
    local new = { }
    for u in utfvalues(str) do
        new[#new+1] = utfchar(lccodes[u])
    end
    return concat(new)
end

function characters.upper(str)
    local new = { }
    for u in utfvalues(str) do
        new[#new+1] = utfchar(uccodes[u])
    end
    return concat(new)
end

function characters.lettered(str)
    local new = { }
    for u in utfvalues(str) do
        local d = data[u]
        if is_letter[d.category] then
            new[#new+1] = utfchar(lccodes[u])
        end
    end
    return concat(new)
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
