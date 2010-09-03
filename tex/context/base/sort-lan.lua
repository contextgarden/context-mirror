if not modules then modules = { } end modules ['sort-lan'] = {
    version   = 1.001,
    comment   = "companion to sort-lan.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Many vectors were supplied by Wolfgang Schuster and Philipp
-- Gesang.
--
-- Replacements are indexed as they need to be applied in sequence
--
-- Maybe we should load these tables runtime, just like patterns.

local utf = unicode.utf8
local uc = utf.char
local ub = utf.byte

local sorters = sorters

local mappings                 = sorters.mappings
local entries                  = sorters.entries
local replacements             = sorters.replacements

local adduppercasereplacements = sorters.adduppercasereplacements
local adduppercaseentries      = sorters.adduppercaseentries
local adduppercasemappings     = sorters.adduppercasemappings

local replacementoffset        = sorters.constants.replacementoffset

-- english

entries['en'] = {
    ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
    ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
    ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
    ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
    ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
    ["z"] = "z",
    ["A"] = "a", ["B"] = "b", ["C"] = "c", ["D"] = "d", ["E"] = "e",
    ["F"] = "f", ["G"] = "g", ["H"] = "h", ["I"] = "i", ["J"] = "j",
    ["K"] = "k", ["L"] = "l", ["M"] = "m", ["N"] = "n", ["O"] = "o",
    ["P"] = "p", ["Q"] = "q", ["R"] = "r", ["S"] = "s", ["T"] = "t",
    ["U"] = "u", ["V"] = "v", ["W"] = "w", ["X"] = "x", ["Y"] = "y",
    ["Z"] = "z",
}

mappings['en'] = {
    ["a"] =  1, ["b"] =  3, ["c"] =  5, ["d"] =  7, ["e"] =  9,
    ["f"] = 11, ["g"] = 13, ["h"] = 15, ["i"] = 17, ["j"] = 19,
    ["k"] = 21, ["l"] = 23, ["m"] = 25, ["n"] = 27, ["o"] = 29,
    ["p"] = 31, ["q"] = 33, ["r"] = 35, ["s"] = 37, ["t"] = 39,
    ["u"] = 41, ["v"] = 43, ["w"] = 45, ["x"] = 47, ["y"] = 49,
    ["z"] = 51,
    ["A"] =  1, ["B"] =  3, ["C"] =  5, ["D"] =  7, ["E"] =  9,
    ["F"] = 11, ["G"] = 13, ["H"] = 15, ["I"] = 17, ["J"] = 19,
    ["K"] = 21, ["L"] = 23, ["M"] = 25, ["N"] = 27, ["O"] = 29,
    ["P"] = 31, ["Q"] = 33, ["R"] = 35, ["S"] = 37, ["T"] = 39,
    ["U"] = 41, ["V"] = 43, ["W"] = 45, ["X"] = 47, ["Y"] = 49,
    ["Z"] = 51,
 --
 -- uppercase after lowercase
 --
 -- ["A"] =  2, ["B"] =  4, ["C"] =  6, ["D"] =  8, ["E"] = 10,
 -- ["F"] = 12, ["G"] = 14, ["H"] = 16, ["I"] = 18, ["J"] = 20,
 -- ["K"] = 22, ["L"] = 24, ["M"] = 26, ["N"] = 28, ["O"] = 30,
 -- ["P"] = 32, ["Q"] = 34, ["R"] = 36, ["S"] = 38, ["T"] = 40,
 -- ["U"] = 42, ["V"] = 44, ["W"] = 46, ["X"] = 48, ["Y"] = 50,
 -- ["Z"] = 52,
}

-- dutch

replacements['nl'] = { { "ij", 'y' }, { "IJ", 'Y' } }
entries     ['nl'] = entries ['en']
mappings    ['nl'] = mappings['en']

--~ -- czech (defined later)
--~
--~ local cz_ch = uc(replacementoffset + 1)
--~ local cz_CH = uc(replacementoffset + 2)
--~
--~ replacements['cz'] = {
--~     [1] = { "ch", cz_ch }
--~ }
--~
--~ entries['cz'] = {
--~     ['a']        = "a",        -- a
--~     [uc(0x00E1)] = "a",        -- aacute
--~     ['b']        = "b",        -- b
--~     ['c']        = "c",        -- c
--~     [uc(0x010D)] = uc(0x010D), -- ccaron
--~     ['d']        = "d",        -- d
--~     [uc(0x010F)] = "d",        -- dcaron
--~     ['e']        = "e",        -- e
--~     [uc(0x00E9)] = "e",        -- eacute
--~     [uc(0x011B)] = "e",        -- ecaron
--~     ['f']        = "f",        -- f
--~     ['g']        = "g",        -- g
--~     ['h']        = "h",        -- h
--~     [cz_ch]      = "ch",       -- ch
--~     ['i']        = "i",        -- i
--~     [uc(0x00ED)] = "i",        -- iacute
--~     ['j']        = "j",        -- j
--~     ['k']        = "k",        -- k
--~     ['l']        = "l",        -- l
--~     ['m']        = "m",        -- m
--~     ['n']        = "n",        -- n
--~     ['ň']        = "n",        -- ncaron
--~     ['o']        = "o",        -- o
--~     ['p']        = "p",        -- p
--~     ['q']        = "q",        -- q
--~     ['r']        = "r",        -- r
--~     ['ř']        = "ř",        -- rcaron
--~     ['s']        = "s",        -- s
--~     [uc(0x0161)] = uc(0x0161), -- scaron
--~     ['t']        = "t",        -- t
--~     [uc(0x0165)] = "t",        -- tcaron
--~     ['u']        = "u",        -- u
--~     [uc(0x00FA)] = "u",        -- uacute
--~     [uc(0x016F)] = "u",        -- uring
--~     ['v']        = "v",        -- v
--~     ['w']        = "w",        -- w
--~     ['x']        = "x",        -- x
--~     ['y']        = "y",        -- y
--~     [uc(0x00FD)] = "y",        -- yacute
--~     ['z']        = "z",        -- z
--~     [uc(0x017E)] = uc(0x017E), -- zcaron
--~ }
--~
--~ mappings['cz'] = {
--~     ['a']        =  1, -- a
--~     [uc(0x00E1)] =  3, -- aacute
--~     ['b']        =  5, -- b
--~     ['c']        =  7, -- c
--~     [uc(0x010D)] =  9, -- ccaron
--~     ['d']        = 11, -- d
--~     [uc(0x010F)] = 13, -- dcaron
--~     ['e']        = 15, -- e
--~     [uc(0x00E9)] = 17, -- eacute
--~     [uc(0x011B)] = 19, -- ecaron
--~     ['f']        = 21, -- f
--~     ['g']        = 23, -- g
--~     ['h']        = 25, -- h
--~     [cz_ch]      = 27, -- ch
--~     ['i']        = 29, -- i
--~     [uc(0x00ED)] = 31, -- iacute
--~     ['j']        = 33, -- j
--~     ['k']        = 35, -- k
--~     ['l']        = 37, -- l
--~     ['m']        = 39, -- m
--~     ['n']        = 41, -- n
--~     ['ň']        = 43, -- ncaron
--~     ['o']        = 45, -- o
--~     ['p']        = 47, -- p
--~     ['q']        = 49, -- q
--~     ['r']        = 51, -- r
--~     ['ř']        = 53, -- rcaron
--~     ['s']        = 55, -- s
--~     [uc(0x0161)] = 57, -- scaron
--~     ['t']        = 59, -- t
--~     [uc(0x0165)] = 61, -- tcaron
--~     ['u']        = 63, -- u
--~     [uc(0x00FA)] = 65, -- uacute
--~     [uc(0x016F)] = 67, -- uring
--~     ['v']        = 69, -- v
--~     ['w']        = 71, -- w
--~     ['x']        = 73, -- x
--~     ['y']        = 75, -- y
--~     [uc(0x00FD)] = 77, -- yacute
--~     ['z']        = 79, -- z
--~     [uc(0x017E)] = 81, -- zcaron
--~ }
--~
--~ adduppercaseentries ("cz")
--~ adduppercasemappings("cz") -- 1 can be option (but then we need a runtime variant)
--~
--~ entries ['cz'][cz_CH] = entries ['cz'][cz_ch]
--~ mappings['cz'][cz_CH] = mappings['cz'][cz_ch]
--~
--~ replacements['cs'] = replacements['cz']
--~ entries     ['cs'] = entries     ['cz']
--~ mappings    ['cs'] = mappings    ['cz']

--~ print(table.serialize(mappings.cs))

-- French

entries ['fr'] = entries ['en']
mappings['fr'] = mappings['en']

-- German (by Wolfgang Schuster)

-- DIN 5007-1

entries  ['DIN 5007-1'] = entries ['en']
mappings ['DIN 5007-1'] = mappings['en']

-- DIN 5007-2

replacements['DIN 5007-2'] = { -- todo: adduppercasereplacements
    { "ä", 'ae' },
    { "ö", 'oe' },
    { "ü", 'ue' },
    { "Ä", 'Ae' },
    { "Ö", 'Oe' },
    { "Ü", 'Ue' },
}

--~ adduppercasereplacements('DIN 5007-2')

entries     ['DIN 5007-2'] = entries ['en']
mappings    ['DIN 5007-2'] = mappings['en']

-- Duden

replacements['Duden'] = { { "ß", 's' } }
entries     ['Duden'] = entries ['en']
mappings    ['Duden'] = mappings['en']

-- new german

entries     ['de'] = entries ['en']
mappings    ['de'] = mappings['en']

-- old german

entries     ['deo'] = entries ['de']
mappings    ['deo'] = mappings['de']

-- german - Germany

entries     ['de-DE'] = entries ['de']
mappings    ['de-DE'] = mappings['de']

-- german - Swiss

entries     ['de-CH'] = entries ['de']
mappings    ['de-CH'] = mappings['de']

-- german - Austria

entries['de-AT'] = {
    ["a"] = "a", ["ä"] = "ä", ["b"] = "b", ["c"] = "c", ["d"] = "d",
    ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
    ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n",
    ["o"] = "o", ["ö"] = "ö", ["p"] = "p", ["q"] = "q", ["r"] = "r",
    ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ü"] = "ü", ["v"] = "v",
    ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
--  ["A"] = "a", ["Ä"] = "ä", ["B"] = "b", ["C"] = "c", ["D"] = "d",
--  ["E"] = "e", ["F"] = "f", ["G"] = "g", ["H"] = "h", ["I"] = "i",
--  ["J"] = "j", ["K"] = "k", ["L"] = "l", ["M"] = "m", ["N"] = "n",
--  ["O"] = "o", ["Ö"] = "ö", ["P"] = "p", ["Q"] = "q", ["R"] = "r",
--  ["S"] = "s", ["T"] = "t", ["U"] = "u", ["Ü"] = "ü", ["V"] = "v",
--  ["W"] = "w", ["X"] = "x", ["Y"] = "y", ["Z"] = "z",
}

mappings['de-AT'] = {
    ["a"] =  1, ["ä"] =  3, ["b"] =  5, ["c"] =  7, ["d"] =  9,
    ["e"] = 11, ["f"] = 13, ["g"] = 15, ["h"] = 17, ["i"] = 19,
    ["j"] = 21, ["k"] = 23, ["l"] = 25, ["m"] = 27, ["n"] = 29,
    ["o"] = 31, ["ö"] = 33, ["p"] = 35, ["q"] = 37, ["r"] = 39,
    ["s"] = 41, ["t"] = 43, ["u"] = 45, ["ü"] = 47, ["v"] = 49,
    ["w"] = 51, ["x"] = 53, ["y"] = 55, ["z"] = 57,
--  ["A"] =  2, ["Ä"] =  4, ["B"] =  6, ["C"] =  8, ["D"] = 10,
--  ["E"] = 12, ["F"] = 14, ["G"] = 16, ["H"] = 18, ["I"] = 20,
--  ["J"] = 22, ["K"] = 24, ["L"] = 26, ["M"] = 28, ["N"] = 30,
--  ["O"] = 32, ["Ö"] = 34, ["P"] = 36, ["Q"] = 38, ["R"] = 40,
--  ["S"] = 42, ["T"] = 44, ["U"] = 46, ["Ü"] = 48, ["V"] = 50,
--  ["W"] = 52, ["X"] = 54, ["Y"] = 56, ["Z"] = 58,
}

adduppercaseentries ('de-AT')
adduppercasemappings('de-AT',1)

-- finish (by Wolfgang Schuster)

entries['fi'] = {
    ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
    ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
    ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
    ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
    ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
    ["z"] = "z", ["å"] = "å", ["ä"] = "ä", ["ö"] = "ö",
}

mappings['fi'] = {
    ["a"] =  1, ["b"] =  3, ["c"] =  5, ["d"] =  7, ["e"] =  9,
    ["f"] = 11, ["g"] = 13, ["h"] = 15, ["i"] = 17, ["j"] = 19,
    ["k"] = 21, ["l"] = 23, ["m"] = 25, ["n"] = 27, ["o"] = 29,
    ["p"] = 31, ["q"] = 33, ["r"] = 35, ["s"] = 37, ["t"] = 39,
    ["u"] = 41, ["v"] = 43, ["w"] = 45, ["x"] = 47, ["y"] = 49,
    ["z"] = 51, ["å"] = 53, ["ä"] = 55, ["ö"] = 57,
}

adduppercaseentries ("fi")
adduppercasemappings("fi")

-- slovenian
--
-- MM: this will change since we need to add accented vowels

entries['sl'] = {
    ["a"] = "a", ["b"] = "b", ["c"] = "c", ["č"] = "č", ["ć"] = "ć", ["d"] = "d",
    ["đ"] = "đ", ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
    ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
    ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["š"] = "š", ["t"] = "t",
    ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
    ["ž"] = "ž",
}

mappings['sl'] = {
    ["a"] =  1, ["b"] =  3, ["c"] =  5, ["č"] =  7, ["ć"] =  9, ["d"] = 11,
    ["đ"] = 13, ["e"] = 15, ["f"] = 17, ["g"] = 19, ["h"] = 21, ["i"] = 23,
    ["j"] = 25, ["k"] = 27, ["l"] = 29, ["m"] = 31, ["n"] = 33, ["o"] = 35,
    ["p"] = 37, ["q"] = 39, ["r"] = 41, ["s"] = 43, ["š"] = 45, ["t"] = 47,
    ["u"] = 49, ["v"] = 51, ["w"] = 53, ["x"] = 55, ["y"] = 57, ["z"] = 59,
    ["ž"] = 61,
}

adduppercaseentries ("sl")
adduppercasemappings("sl") -- cf. MM

-- The following (quite some) languages were provided by Philipp
-- Gesang (Phg), megas.kapaneus@gmail.com.

replacements["ru"] = { --[[ None, do you miss any? ]] }

entries["ru"] = {
    ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
    ["е"] = "е", ["ё"] = "е", ["ж"] = "ж", ["з"] = "з", ["и"] = "и",
    ["і"] = "и", ["й"] = "й", ["к"] = "к", ["л"] = "л", ["м"] = "м",
    ["н"] = "н", ["о"] = "о", ["п"] = "п", ["р"] = "р", ["с"] = "с",
    ["т"] = "т", ["у"] = "у", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
    ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ", ["ъ"] = "ъ", ["ы"] = "ы",
    ["ь"] = "ь", ["ѣ"] = "ѣ", ["э"] = "э", ["ю"] = "ю", ["я"] = "я",
    ["ѳ"] = "ѳ", ["ѵ"] = "ѵ",
}

mappings["ru"] = {
    ["а"] =  1, ["б"] =  2, ["в"] =  3, ["г"] =  4, ["д"] =  5,
    ["е"] =  6, ["ё"] =  6, ["ж"] =  7, ["з"] =  8, ["и"] =  9,
    ["і"] =  9, ["й"] = 10, ["к"] = 11, ["л"] = 12, ["м"] = 13,
    ["н"] = 14, ["о"] = 15, ["п"] = 16, ["р"] = 17, ["с"] = 18,
    ["т"] = 19, ["у"] = 20, ["ф"] = 21, ["х"] = 22, ["ц"] = 23,
    ["ч"] = 24, ["ш"] = 25, ["щ"] = 26, ["ъ"] = 27, ["ы"] = 28,
    ["ь"] = 29, ["ѣ"] = 30, ["э"] = 31, ["ю"] = 32, ["я"] = 33,
    ["ѳ"] = 34, ["ѵ"] = 35,
}

adduppercaseentries ("ru")
adduppercasemappings("ru")

--- Basic Ukrainian

replacements["uk"] = { --[[ None, do you miss any? ]] }

entries["uk"] = {
    ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["ґ"] = "ґ",
    ["д"] = "д", ["е"] = "е", ["є"] = "є", ["ж"] = "ж", ["з"] = "з",
    ["и"] = "и", ["і"] = "і", ["ї"] = "ї", ["й"] = "й", ["к"] = "к",
    ["л"] = "л", ["м"] = "м", ["н"] = "н", ["о"] = "о", ["п"] = "п",
    ["р"] = "р", ["с"] = "с", ["т"] = "т", ["у"] = "у", ["ф"] = "ф",
    ["х"] = "х", ["ц"] = "ц", ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ",
    ["ь"] = "ь", ["ю"] = "ю", ["я"] = "я",
}

mappings["uk"] = {
    ["а"] =  1, ["б"] =  2, ["в"] =  3, ["г"] =  4, ["ґ"] =  5,
    ["д"] =  6, ["е"] =  7, ["є"] =  8, ["ж"] =  9, ["з"] = 10,
    ["и"] = 11, ["і"] = 12, ["ї"] = 13, ["й"] = 14, ["к"] = 15,
    ["л"] = 16, ["м"] = 17, ["н"] = 18, ["о"] = 19, ["п"] = 20,
    ["р"] = 21, ["с"] = 22, ["т"] = 23, ["у"] = 24, ["ф"] = 25,
    ["х"] = 26, ["ц"] = 27, ["ч"] = 28, ["ш"] = 29, ["щ"] = 30,
    ["ь"] = 31, ["ю"] = 32, ["я"] = 33,
}

adduppercaseentries ("uk")
adduppercasemappings("uk")

--- Belarusian

replacements["be"] = { --[[ None, do you miss any? ]] }

entries["be"] = {
    ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
    ["е"] = "е", ["ё"] = "е", ["ж"] = "ж", ["з"] = "з", ["і"] = "і",
    ["й"] = "й", ["к"] = "к", ["л"] = "л", ["м"] = "м", ["н"] = "н",
    ["о"] = "о", ["п"] = "п", ["р"] = "р", ["с"] = "с", ["т"] = "т",
    ["у"] = "у", ["ў"] = "ў", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
    ["ч"] = "ч", ["ш"] = "ш", ["ы"] = "ы", ["ь"] = "ь", ["э"] = "э",
    ["ю"] = "ю", ["я"] = "я",
}

mappings["be"] = {
    ["а"] =  1, ["б"] =  2, ["в"] =  3, ["г"] =  4, ["д"] =  5,
    ["е"] =  6, ["ё"] =  6, ["ж"] =  7, ["з"] =  8, ["і"] =  9,
    ["й"] = 10, ["к"] = 11, ["л"] = 12, ["м"] = 13, ["н"] = 14,
    ["о"] = 15, ["п"] = 16, ["р"] = 17, ["с"] = 18, ["т"] = 19,
    ["у"] = 20, ["ў"] = 21, ["ф"] = 22, ["х"] = 23, ["ц"] = 24,
    ["ч"] = 25, ["ш"] = 26, ["ы"] = 27, ["ь"] = 28, ["э"] = 29,
    ["ю"] = 30, ["я"] = 31,
}

adduppercaseentries ("be")
adduppercasemappings("be")

--- Bulgarian

replacements["bg"] = { --[[ None, do you miss any? ]] }

entries["bg"] = {
    ["а"]   = "а",
    ["б"]   = "б",
    ["в"]   = "в",
    ["г"]   = "г",
    ["д"]   = "д",
    ["е"]   = "е",
    ["ж"]   = "ж",
    ["з"]   = "з",
    ["и"]   = "и",
    ["й"]   = "й",
    ["к"]   = "к",
    ["a"]   = "a",
    ["л"]   = "л",
    ["a"]   = "a",
    ["м"]   = "м",
    ["н"]   = "н",
    ["о"]   = "о",
    ["п"]   = "п",
    ["р"]   = "р",
    ["с"]   = "с",
    ["т"]   = "т",
    ["у"]   = "у",
    ["ф"]   = "ф",
    ["х"]   = "х",
    ["ц"]   = "ц",
    ["ч"]   = "ч",
    ["ш"]   = "ш",
    ["щ"]   = "щ",
    ["ъ"]   = "ъ",
    ["ь"]   = "ь",
    ["ю"]   = "ю",
    ["я"]   = "я",
}

mappings["bg"] = {
    ["а"]   =  1,
    ["б"]   =  2,
    ["в"]   =  3,
    ["г"]   =  4,
    ["д"]   =  5,
    ["е"]   =  6,
    ["ж"]   =  7,
    ["з"]   =  8,
    ["и"]   =  9,
    ["й"]   = 10,
    ["к"]   = 11,
    ["a"]   = 12,
    ["л"]   = 13,
    ["a"]   = 14,
    ["м"]   = 15,
    ["н"]   = 16,
    ["о"]   = 17,
    ["п"]   = 18,
    ["р"]   = 19,
    ["с"]   = 20,
    ["т"]   = 21,
    ["у"]   = 22,
    ["ф"]   = 23,
    ["х"]   = 24,
    ["ц"]   = 25,
    ["ч"]   = 26,
    ["ш"]   = 27,
    ["щ"]   = 28,
    ["ъ"]   = 29,
    ["ь"]   = 30,
    ["ю"]   = 31,
    ["я"]   = 32,
}

adduppercaseentries ("bg")
adduppercasemappings("bg")

--- Old Church Slavonic

-- The language symbol “cu” is taken from the Wikipedia subdomain
-- cu.wikipedia.org.

local cu_uk  = uc(replacementoffset + 1)
local cu_UK  = uc(replacementoffset + 2)

replacements["cu"] = {
    [1] = { "оу", cu_uk  },
}

entries["cu"] = {
    ["а"] = "а",
    ["б"] = "б",
    ["в"] = "в",
    ["г"] = "г",
    ["д"] = "д",
    ["є"] = "є",
    ["ж"] = "ж",
    ["ѕ"] = "ѕ",
    ["ꙃ"] = "ѕ",      --  Dzělo, U+0292, alternative: ǳ U+01f3
    ["з"] = "з",
    ["ꙁ"] = "з",      --  Zemlja
    ["и"] = "и",
    ["і"] = "и",
    ["ї"] = "и",
    ["ћ"] = "ћ",
    ["к"] = "к",
    ["л"] = "л",
    ["м"] = "м",
    ["н"] = "н",
    ["о"] = "о",
    ["п"] = "п",
    ["р"] = "р",
    ["с"] = "с",
    ["т"] = "т",
    ["у"] = "у",
    ["ѹ"] = "у",     -- U+0478 uk, horizontal ligature
    ["ꙋ"] = "у",     -- U+0479 uk, vertical ligature
  [cu_uk] = "у",
    ["ф"] = "ф",
    ["х"] = "х",
    ["ѡ"] = "ѡ",     --"ō"
    ["ѿ"] = "ѡ",     -- U+047f  \
    ["ѽ"] = "ѡ",     -- U+047d   > Omega variants
    ["ꙍ"] = "ѡ",     -- U+064D  /
    ["ц"] = "ц",
    ["ч"] = "ч",
    ["ш"] = "ш",
    ["щ"] = "щ",
    ["ъ"] = "ъ",
    ["ы"] = "ы",
    ["ꙑ"] = "ы",      -- Old jery (U+a651) as used e.g. by the OCS Wikipedia.
    ["ь"] = "ь",
    ["ѣ"] = "ѣ",
    ["ю"] = "ю",
    ["ꙗ"] = "ꙗ",      --  IOTIFIED A
    ["ѥ"] = "ѥ",
    ["ѧ"] = "ѧ",
    ["ѩ"] = "ѩ",
    ["ѫ"] = "ѫ",
    ["ѭ"] = "ѭ",
    ["ѯ"] = "ѯ",
    ["ѱ"] = "ѱ",
    ["ѳ"] = "ѳ",
    ["ѵ"] = "ѵ",
    ["ѷ"] = "ѵ",      -- Why does this even have its own codepoint????
}

mappings["cu"] = {
    ["а"] =  1,
    ["б"] =  2,
    ["в"] =  3,
    ["г"] =  4,
    ["д"] =  5,
    ["є"] =  6,
    ["ж"] =  7,
    ["ѕ"] =  8,
    ["ꙃ"] =  8,      --  Dzělo, U+0292, alternative: ǳ U+01f3
    ["з"] =  9,
    ["ꙁ"] =  9,      --  Zemlja
    ["и"] = 10,
    ["і"] = 10,
    ["ї"] = 10,
    ["ћ"] = 11,
    ["к"] = 12,
    ["л"] = 13,
    ["м"] = 14,
    ["н"] = 15,
    ["о"] = 16,
    ["п"] = 17,
    ["р"] = 18,
    ["с"] = 19,
    ["т"] = 20,
    ["у"] = 21,
    ["ѹ"] = 21,     -- U+0478 uk, horizontal ligature
    ["ꙋ"] = 21,     -- U+0479 uk, vertical ligature
  [cu_uk] = 21,
    ["ф"] = 22,
    ["х"] = 23,
    ["ѡ"] = 24,     --"ō"
    ["ѿ"] = 24,     -- U+047f  \
    ["ѽ"] = 24,     -- U+047d   > Omega variants
    ["ꙍ"] = 24,     -- U+064D  /
    ["ц"] = 25,
    ["ч"] = 26,
    ["ш"] = 27,
    ["щ"] = 28,
    ["ъ"] = 29,
    ["ы"] = 30,
    ["ꙑ"] = 30,      -- Old jery (U+a651) as used e.g. by the OCS Wikipedia.
    ["ь"] = 31,
    ["ѣ"] = 32,
    ["ю"] = 33,
    ["ꙗ"] = 34,      --  IOTIFIED A
    ["ѥ"] = 35,
    ["ѧ"] = 36,
    ["ѩ"] = 37,
    ["ѫ"] = 38,
    ["ѭ"] = 39,
    ["ѯ"] = 40,
    ["ѱ"] = 41,
    ["ѳ"] = 42,
    ["ѵ"] = 43,
    ["ѷ"] = 43,      -- Why does this even have its own codepoint????
}

adduppercaseentries ("cu")
adduppercasemappings("cu")

entries ["cu"] [cu_UK] = entries ["cu"] [cu_uk]
mappings["cu"] [cu_UK] = mappings["cu"] [cu_uk]

--- Polish (including the letters q, v, x)

-- Cf. ftp://ftp.gust.org.pl/pub/GUST/bulletin/03/02-bl.pdf.

replacements["pl"] = {
    -- none
}

entries["pl"] = {
    ["a"] = "a", ["ą"] = "ą", ["b"] = "b", ["c"] = "c", ["ć"] = "ć",
    ["d"] = "d", ["e"] = "e", ["ę"] = "ę", ["f"] = "f", ["g"] = "g",
    ["h"] = "h", ["i"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",
    ["ł"] = "ł", ["m"] = "m", ["n"] = "n", ["ń"] = "ń", ["o"] = "o",
    ["ó"] = "ó", ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s",
    ["ś"] = "ś", ["t"] = "t", ["u"] = "u", ["v"] = "v", ["w"] = "w",
    ["x"] = "x", ["y"] = "y", ["z"] = "z", ["ź"] = "ź", ["ż"] = "ż",
}

mappings["pl"] = {
    ["a"] =  1, ["ą"] =  2, ["b"] =  3, ["c"] =  4, ["ć"] =  5,
    ["d"] =  6, ["e"] =  7, ["ę"] =  8, ["f"] =  9, ["g"] = 10,
    ["h"] = 11, ["i"] = 12, ["j"] = 13, ["k"] = 14, ["l"] = 15,
    ["ł"] = 16, ["m"] = 17, ["n"] = 18, ["ń"] = 19, ["o"] = 20,
    ["ó"] = 21, ["p"] = 22, ["q"] = 23, ["r"] = 24, ["s"] = 25,
    ["ś"] = 26, ["t"] = 27, ["u"] = 28, ["v"] = 29, ["w"] = 30,
    ["x"] = 31, ["y"] = 32, ["z"] = 33, ["ź"] = 34, ["ż"] = 35,
}

adduppercaseentries ("pl")
adduppercasemappings("pl")

--- Czech
-- Modified to treat quantities and other secondary characteristics indifferently.
-- Cf. <http://racek.vlada.cz/usneseni/usneseni_webtest.nsf/WebGovRes/0AD8FEF4CC04B7A4C12571B6006D69D0?OpenDocument>
-- (2.4.3; via <http://cs.wikipedia.org/wiki/Abecední_řazení#.C4.8Ce.C5.A1tina>).

local cz_ch = uc(replacementoffset + 1)
local cz_CH = uc(replacementoffset + 2) -- Is this actually used somewhere (e.g. with “adduppercaseentries”)?

replacements["cz"] = {
    [1] = { "ch", cz_ch }
}

entries["cz"] = {
    ["a"]   = "a",        -- a
    ["á"]   = "a",        -- aacute
    ["b"]   = "b",        -- b
    ["c"]   = "c",        -- c
    ["č"]   = "č",        -- ccaron
    ["d"]   = "d",        -- d
    ["ď"]   = "d",        -- dcaron
    ["e"]   = "e",        -- e
    ["é"]   = "e",        -- eacute
    ["ě"]   = "e",        -- ecaron
    ["f"]   = "f",        -- f
    ["g"]   = "g",        -- g
    ["h"]   = "h",        -- h
    [cz_ch] = "ch",       -- ch
    ["i"]   = "i",        -- i
    ["í"]   = "i",        -- iacute
    ["j"]   = "j",        -- j
    ["k"]   = "k",        -- k
    ["l"]   = "l",        -- l
    ["m"]   = "m",        -- m
    ["n"]   = "n",        -- n
    ["ň"]   = "n",        -- ncaron
    ["o"]   = "o",        -- o
    ["ó"]   = "o",        -- ó
    ["p"]   = "p",        -- p
    ["q"]   = "q",        -- q
    ["r"]   = "r",        -- r
    ["ř"]   = "ř",        -- rcaron
    ["s"]   = "s",        -- s
    ["š"]   = "š",        -- scaron
    ["t"]   = "t",        -- t
    ["ť"]   = "t",        -- tcaron
    ["u"]   = "u",        -- u
    ["ú"]   = "u",        -- uacute
    ["ů"]   = "u",        -- uring
    ["v"]   = "v",        -- v
    ["w"]   = "w",        -- w
    ["x"]   = "x",        -- x
    ["y"]   = "y",        -- y
    ["ý"]   = "y",        -- yacute
    ["z"]   = "z",        -- z
    ["ž"]   = "ž",        -- zcaron
}

mappings["cz"] = {
    ["a"]   =  1, -- a
    ["á"]   =  1, -- aacute -> a
    ["b"]   =  2, -- b
    ["c"]   =  3, -- c
    ["č"]   =  4, -- ccaron
    ["d"]   =  5, -- d
    ["ď"]   =  5, -- dcaron -> ď
    ["e"]   =  6, -- e
    ["é"]   =  6, -- eacute -> e
    ["ě"]   =  6, -- ecaron -> e
    ["f"]   =  7, -- f
    ["g"]   =  8, -- g
    ["h"]   =  9, -- h
    [cz_ch] = 10, -- ch
    ["i"]   = 11, -- i
    ["í"]   = 11, -- iacute -> i
    ["j"]   = 12, -- j
    ["k"]   = 13, -- k
    ["l"]   = 14, -- l
    ["m"]   = 15, -- m
    ["n"]   = 16, -- n
    ["ň"]   = 16, -- ncaron -> n
    ["o"]   = 17, -- o
    ["ó"]   = 17, -- o      -> o
    ["p"]   = 18, -- p
    ["q"]   = 19, -- q
    ["r"]   = 20, -- r
    ["ř"]   = 21, -- rcaron
    ["s"]   = 22, -- s
    ["š"]   = 23, -- scaron
    ["t"]   = 24, -- t
    ["ť"]   = 24, -- tcaron -> t
    ["u"]   = 25, -- u
    ["ú"]   = 25, -- uacute -> u
    ["ů"]   = 25, -- uring  -> u
    ["v"]   = 26, -- v
    ["w"]   = 27, -- w
    ["x"]   = 28, -- x
    ["y"]   = 29, -- y
    ["ý"]   = 29, -- yacute -> y
    ["z"]   = 30, -- z
    ["ž"]   = 31, -- zcaron         Checksum: 42
}

adduppercaseentries ("cz")
adduppercasemappings("cz") -- 1 can be option (but then we need a runtime variant)

entries ["cz"][cz_CH] = entries ["cz"][cz_ch]
mappings["cz"][cz_CH] = mappings["cz"][cz_ch]

replacements["cs"] = replacements["cz"]
entries     ["cs"] = entries     ["cz"]
mappings    ["cs"] = mappings    ["cz"]

--- Slovak.

-- Vowel and consonant quantities, "ď", "ľ", "ň", "ť", "ô", and "ä" are treated
-- indifferently as their base character, as in my dictionary. If you prefer them
-- to affect collation order, then use the values given in the comments. We could
-- define an additional vector for that.

local sk_dz  = uc(replacementoffset + 1)
local sk_DZ  = uc(replacementoffset + 2)
local sk_dzh = uc(replacementoffset + 3)
local sk_DZH = uc(replacementoffset + 4)
local sk_ch  = uc(replacementoffset + 5)
local sk_CH  = uc(replacementoffset + 6)

replacements["sk"] = {
    [1] = { "dz", sk_dz  },
    [2] = { "dž", sk_dzh },
    [3] = { "ch", sk_ch  },
}

entries["sk"] = {
    ["a"]       = "a",
    ["á"]       = "a", -- "á",
    ["ä"]       = "a", -- "ä",
    ["b"]       = "b",
    ["c"]       = "c",
    ["č"]       = "č",
    ["d"]       = "d",
    ["ď"]       = "d", -- "ď",
    [sk_dz]     = "dz",
    [sk_dzh]    = "dž",
    ["e"]       = "e",
    ["é"]       = "e", -- "é",
    ["f"]       = "f",
    ["g"]       = "g",
    ["h"]       = "h",
    [sk_ch]     = "ch",
    ["i"]       = "i",
    ["í"]       = "i", -- "í",
    ["j"]       = "j",
    ["k"]       = "k",
    ["l"]       = "l",
    ["ĺ"]       = "l", -- "ĺ",
    ["ľ"]       = "l", -- "ľ",
    ["m"]       = "m",
    ["n"]       = "n",
    ["ň"]       = "n", -- "ň",
    ["o"]       = "o",
    ["ó"]       = "o", -- "ó",
    ["ô"]       = "o", -- "ô",
    ["p"]       = "p",
    ["q"]       = "q",
    ["r"]       = "r",
    ["ŕ"]       = "r", -- "ŕ",
    ["s"]       = "s",
    ["š"]       = "š",
    ["t"]       = "t",
    ["ť"]       = "t", -- "ť",
    ["u"]       = "u",
    ["ú"]       = "u", -- "ú",
    ["v"]       = "v",
    ["w"]       = "w",
    ["x"]       = "x",
    ["y"]       = "y",
    ["ý"]       = "y", -- "ý",
    ["z"]       = "z",
    ["ž"]       = "ž",
}

mappings["sk"] = {
    ["a"]       =  1,
    ["á"]       =  1, -- 2,
    ["ä"]       =  1, -- 3,
    ["b"]       =  4,
    ["c"]       =  5,
    ["č"]       =  6,
    ["d"]       =  7,
    ["ď"]       =  7, -- 8,
    [sk_dz]     =  9,
    [sk_dzh]    = 10,
    ["e"]       = 11,
    ["é"]       = 11, -- 12,
    ["f"]       = 13,
    ["g"]       = 14,
    ["h"]       = 15,
    [sk_ch]     = 16,
    ["i"]       = 17,
    ["í"]       = 17, -- 18,
    ["j"]       = 19,
    ["k"]       = 20,
    ["l"]       = 21,
    ["ĺ"]       = 21, -- 22,
    ["ľ"]       = 21, -- 23,
    ["m"]       = 24,
    ["n"]       = 25,
    ["ň"]       = 25, -- 26,
    ["o"]       = 27,
    ["ó"]       = 27, -- 28,
    ["ô"]       = 27, -- 29,
    ["p"]       = 30,
    ["q"]       = 31,
    ["r"]       = 32,
    ["ŕ"]       = 32, -- 33,
    ["s"]       = 34,
    ["š"]       = 35,
    ["t"]       = 36,
    ["ť"]       = 36, -- 37,
    ["u"]       = 38,
    ["ú"]       = 38, -- 39,
    ["v"]       = 40,
    ["w"]       = 41,
    ["x"]       = 42,
    ["y"]       = 43,
    ["ý"]       = 43, -- 44,
    ["z"]       = 45,
    ["ž"]       = 46, -- Checksum: 46, přesně!
}

adduppercaseentries ("sk")
adduppercasemappings("sk")

entries ["sk"] [sk_DZ] = entries ["sk"] [sk_dz]
mappings["sk"] [sk_DZ] = mappings["sk"] [sk_dz]
entries ["sk"][sk_DZH] = entries ["sk"][sk_dzh]
mappings["sk"][sk_DZH] = mappings["sk"][sk_dzh]
entries ["sk"] [sk_CH] = entries ["sk"] [sk_ch]
mappings["sk"] [sk_CH] = mappings["sk"] [sk_ch]

--- Croatian

local hr_dzh = uc(replacementoffset + 1)
local hr_DZH = uc(replacementoffset + 2)
local hr_lj  = uc(replacementoffset + 3)
local hr_LJ  = uc(replacementoffset + 4)
local hr_nj  = uc(replacementoffset + 5)
local hr_NJ  = uc(replacementoffset + 6)

replacements["hr"] = {
    [1] = { "dž", hr_dzh },
    [2] = { "lj", hr_lj  },
    [3] = { "nj", hr_nj  },
}

entries["hr"] = {
    ["a"]   =  "a", -- Why do you sometimes encounter “â” (where Old Slavonic
    ["b"]   =  "b", -- has “ѣ”) and how does it collate?
    ["c"]   =  "c",
    ["č"]   =  "č",
    ["ć"]   =  "ć",
    ["d"]   =  "d",
 [hr_dzh]   = "dž",
    ["đ"]   =  "đ",
    ["e"]   =  "e",
    ["f"]   =  "f",
    ["g"]   =  "g",
    ["h"]   =  "h",
    ["i"]   =  "i",
    ["j"]   =  "j",
    ["k"]   =  "k",
    ["l"]   =  "l",
  [hr_lj]   = "lj",
    ["m"]   =  "m",
    ["n"]   =  "n",
  [hr_nj]   = "nj",
    ["o"]   =  "o",
    ["p"]   =  "p",
    ["r"]   =  "r",
    ["s"]   =  "s",
    ["š"]   =  "š",
    ["t"]   =  "t",
    ["u"]   =  "u",
    ["v"]   =  "v",
    ["z"]   =  "z",
    ["ž"]   =  "ž",
}

mappings["hr"] = {
    ["a"]   =  1,
    ["b"]   =  2,
    ["c"]   =  3,
    ["č"]   =  4,
    ["ć"]   =  5,
    ["d"]   =  6,
 [hr_dzh]   =  7,
    ["đ"]   =  8,
    ["e"]   =  9,
    ["f"]   = 10,
    ["g"]   = 11,
    ["h"]   = 12,
    ["i"]   = 13,
    ["j"]   = 14,
    ["k"]   = 15,
    ["l"]   = 16,
  [hr_lj]   = 17,
    ["m"]   = 18,
    ["n"]   = 19,
  [hr_nj]   = 20,
    ["o"]   = 21,
    ["p"]   = 22,
    ["r"]   = 23,
    ["s"]   = 24,
    ["š"]   = 25,
    ["t"]   = 26,
    ["u"]   = 27,
    ["v"]   = 28,
    ["z"]   = 29,
    ["ž"]   = 30,
}

adduppercaseentries ("hr")
adduppercasemappings("hr")

entries ["hr"][hr_DZH] = entries ["hr"][hr_dzh]
mappings["hr"][hr_DZH] = mappings["hr"][hr_dzh]
entries ["hr"] [hr_LJ] = entries ["hr"] [hr_lj]
mappings["hr"] [hr_LJ] = mappings["hr"] [hr_lj]
entries ["hr"] [hr_NJ] = entries ["hr"] [hr_nj]
mappings["hr"] [hr_NJ] = mappings["hr"] [hr_nj]

--- Serbian

replacements["sr"] = {
    -- none
}

entries["sr"] = {
    ["а"]   = "а",
    ["б"]   = "б",
    ["в"]   = "в",
    ["г"]   = "г",
    ["д"]   = "д",
    ["ђ"]   = "ђ",
    ["е"]   = "е",
    ["ж"]   = "ж",
    ["з"]   = "з",
    ["и"]   = "и",
    ["ј"]   = "ј",
    ["к"]   = "к",
    ["л"]   = "л",
    ["љ"]   = "љ",
    ["м"]   = "м",
    ["н"]   = "н",
    ["њ"]   = "њ",
    ["о"]   = "о",
    ["п"]   = "п",
    ["р"]   = "р",
    ["с"]   = "с",
    ["т"]   = "т",
    ["ћ"]   = "ћ",
    ["у"]   = "у",
    ["ф"]   = "ф",
    ["х"]   = "х",
    ["ц"]   = "ц",
    ["ч"]   = "ч",
    ["џ"]   = "џ",
    ["ш"]   = "ш",
}

mappings["sr"] = {
    ["а"]   =  1,
    ["б"]   =  2,
    ["в"]   =  3,
    ["г"]   =  4,
    ["д"]   =  5,
    ["ђ"]   =  6,
    ["е"]   =  7,
    ["ж"]   =  8,
    ["з"]   =  9,
    ["и"]   = 10,
    ["ј"]   = 11,
    ["к"]   = 12,
    ["л"]   = 13,
    ["љ"]   = 14,
    ["м"]   = 15,
    ["н"]   = 16,
    ["њ"]   = 17,
    ["о"]   = 18,
    ["п"]   = 19,
    ["р"]   = 20,
    ["с"]   = 21,
    ["т"]   = 22,
    ["ћ"]   = 23,
    ["у"]   = 24,
    ["ф"]   = 25,
    ["х"]   = 26,
    ["ц"]   = 27,
    ["ч"]   = 28,
    ["џ"]   = 29,
    ["ш"]   = 30,
}

adduppercaseentries ("sr")
adduppercasemappings("sr")

--- Transliteration: Russian|ISO9-1995

-- Keeping the same collation order as Russian (v.s.).
-- Matches the tables from:
-- http://bitbucket.org/phg/transliterator/src/tip/tex/context/third/transliterator/trans_tables_iso9.lua

local ru_iso9_yer = uc(replacementoffset + 1)

replacements["ru-iso9"] = {
    [1] = { "''", ru_iso9_yer  },
}

entries["ru-iso9"] = {
    ["a"] = "a",
    ["b"] = "b",
    ["v"] = "v",
    ["g"] = "g",
    ["d"] = "d",
    ["e"] = "e",
    ["ë"] = "ë",
    ["ž"] = "ž",
    ["z"] = "z",
    ["i"] = "i",
    ["ì"] = "ì",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["f"] = "f",
    ["h"] = "h",
    ["c"] = "c",
    ["č"] = "č",
    ["š"] = "š",
    ["ŝ"] = "ŝ",
    ["ʺ"] = "ʺ",
    [ru_iso9_yer] = "ʺ",
    ["y"] = "y",
    ["ʹ"] = "ʹ",
    ["'"] = "ʹ",
    ["ě"] = "ě",
    ["è"] = "è",
    ["û"] = "û",
    ["â"] = "â",
    ["û"] = "û",
    ["â"] = "â",
}

mappings["ru-iso9"] = {
    ["a"] =  1,
    ["b"] =  2,
    ["v"] =  3,
    ["g"] =  4,
    ["d"] =  5,
    ["e"] =  6,
    ["ë"] =  6,
    ["ž"] =  7,
    ["z"] =  8,
    ["i"] =  9,
    ["ì"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["o"] = 15,
    ["p"] = 16,
    ["r"] = 17,
    ["s"] = 18,
    ["t"] = 19,
    ["u"] = 20,
    ["f"] = 21,
    ["h"] = 22,
    ["c"] = 23,
    ["č"] = 24,
    ["š"] = 25,
    ["ŝ"] = 26,
    ["ʺ"] = 27,
    [ru_iso9_yer] = 27,
    ["y"] = 28,
    ["ʹ"] = 29,
    ["'"] = 29,
    ["ě"] = 30,
    ["è"] = 31,
    ["û"] = 32,
    ["â"] = 33,
    ["û"] = 34,
    ["â"] = 35,
}

adduppercaseentries ("ru-iso9")
adduppercasemappings("ru-iso9")

--- Transliteration: Old Slavonic|scientific

-- Matches the tables from:
-- http://bitbucket.org/phg/transliterator/src/tip/tex/context/third/transliterator/trans_tables_scntfc.lua

local ocs_scn_uk      = uc(replacementoffset +  1)
local ocs_scn_tshe    = uc(replacementoffset +  2)
local ocs_scn_sht     = uc(replacementoffset +  3)
local ocs_scn_ju      = uc(replacementoffset +  4)
local ocs_scn_ja      = uc(replacementoffset +  5)
local ocs_scn_je      = uc(replacementoffset +  6)
local ocs_scn_ijus    = uc(replacementoffset +  7)
local ocs_scn_ibigjus = uc(replacementoffset +  8)
local ocs_scn_xi      = uc(replacementoffset +  9)
local ocs_scn_psi     = uc(replacementoffset + 10)
local ocs_scn_theta   = uc(replacementoffset + 11)
local ocs_scn_shch    = uc(replacementoffset + 12)

local ocs_scn_UK      = uc(replacementoffset + 13)
local ocs_scn_TSHE    = uc(replacementoffset + 14)
local ocs_scn_SHT     = uc(replacementoffset + 15)
local ocs_scn_JU      = uc(replacementoffset + 16)
local ocs_scn_JA      = uc(replacementoffset + 17)
local ocs_scn_JE      = uc(replacementoffset + 18)
local ocs_scn_IJUS    = uc(replacementoffset + 19)
local ocs_scn_IBIGJUS = uc(replacementoffset + 20)
local ocs_scn_XI      = uc(replacementoffset + 21)
local ocs_scn_PSI     = uc(replacementoffset + 22)
local ocs_scn_THETA   = uc(replacementoffset + 23)
local ocs_scn_SHCH    = uc(replacementoffset + 24)

replacements["ocs-scn"] = {
     [1] = { "ou", ocs_scn_uk      },
     [2] = { "g’", ocs_scn_tshe    },
     [3] = { "št", ocs_scn_sht     },
     [4] = { "ju", ocs_scn_ju      },
     [5] = { "ja", ocs_scn_ja      },
     [6] = { "je", ocs_scn_je      },
     [7] = { "ję", ocs_scn_ijus    },
     [8] = { "jǫ", ocs_scn_ibigjus },
     [9] = { "ks", ocs_scn_xi      },
    [10] = { "ps", ocs_scn_psi     },
    [11] = { "th", ocs_scn_theta   },
    [12] = { "šč", ocs_scn_shch    },
}

entries["ocs-scn"] = {
            ["a"] =  "a",
            ["b"] =  "b",
            ["v"] =  "v",
            ["g"] =  "g",
            ["d"] =  "d",
            ["e"] =  "e",
            ["ž"] =  "ž",
            ["ʒ"] =  "ʒ",
            ["z"] =  "z",
            ["i"] =  "i",
            ["ï"] =  "ï",
   [ocs_scn_tshe] = "g’",
            ["k"] =  "k",
            ["l"] =  "l",
            ["m"] =  "m",
            ["n"] =  "n",
            ["o"] =  "o",
            ["p"] =  "p",
            ["r"] =  "r",
            ["s"] =  "s",
            ["t"] =  "t",
            ["u"] =  "u",
            ["f"] =  "f",
            ["x"] =  "x",
            ["o"] =  "o",
            ["c"] =  "c",
            ["č"] =  "č",
            ["š"] =  "š",
    [ocs_scn_sht] = "št",
   [ocs_scn_shch] = "šč",
            ["ъ"] =  "ъ",
            ["y"] =  "y",
     [ocs_scn_uk] =  "y",
            ["ь"] =  "ь",
            ["ě"] =  "ě",
     [ocs_scn_ju] = "ju",
     [ocs_scn_ja] = "ja",
     [ocs_scn_je] = "je",
            ["ę"] =  "ę",
   [ocs_scn_ijus] = "ję",
            ["ǫ"] =  "ǫ",
[ocs_scn_ibigjus] = "jǫ",
     [ocs_scn_xi] = "ks",
    [ocs_scn_psi] = "ps",
  [ocs_scn_theta] = "th",
            ["ü"] =  "ü",
}

mappings["ocs-scn"] = {
            ["a"] =  1,
            ["b"] =  2,
            ["v"] =  3,
            ["g"] =  4,
            ["d"] =  5,
            ["e"] =  6,
            ["ž"] =  7,
            ["ʒ"] =  8,
            ["z"] =  9,
            ["i"] = 10,
            ["ï"] = 10,
   [ocs_scn_tshe] = 11,
            ["k"] = 12,
            ["l"] = 13,
            ["m"] = 14,
            ["n"] = 15,
            ["o"] = 16,
            ["p"] = 17,
            ["r"] = 18,
            ["s"] = 19,
            ["t"] = 20,
            ["u"] = 21,
            ["f"] = 22,
            ["x"] = 23,
            ["o"] = 24,
            ["c"] = 25,
            ["č"] = 26,
            ["š"] = 27,
    [ocs_scn_sht] = 28,
   [ocs_scn_shch] = 28,
            ["ъ"] = 29,
            ["y"] = 30,
     [ocs_scn_uk] = 30,
            ["ь"] = 31,
            ["ě"] = 32,
     [ocs_scn_ju] = 33,
     [ocs_scn_ja] = 34,
     [ocs_scn_je] = 35,
            ["ę"] = 36,
   [ocs_scn_ijus] = 37,
            ["ǫ"] = 38,
[ocs_scn_ibigjus] = 39,
     [ocs_scn_xi] = 40,
    [ocs_scn_psi] = 41,
  [ocs_scn_theta] = 42,
            ["ü"] = 43,
}

adduppercaseentries ("ocs-scn")
adduppercasemappings("ocs-scn")

 entries["ocs-scn"][ocs_scn_UK     ] =  entries["ocs-scn"][ocs_scn_uk     ]
mappings["ocs-scn"][ocs_scn_UK     ] = mappings["ocs-scn"][ocs_scn_uk     ]

 entries["ocs-scn"][ocs_scn_TSHE   ] =  entries["ocs-scn"][ocs_scn_tshe   ]
mappings["ocs-scn"][ocs_scn_TSHE   ] = mappings["ocs-scn"][ocs_scn_tshe   ]

 entries["ocs-scn"][ocs_scn_SHT    ] =  entries["ocs-scn"][ocs_scn_sht    ]
mappings["ocs-scn"][ocs_scn_SHT    ] = mappings["ocs-scn"][ocs_scn_sht    ]

 entries["ocs-scn"][ocs_scn_JU     ] =  entries["ocs-scn"][ocs_scn_ju     ]
mappings["ocs-scn"][ocs_scn_JU     ] = mappings["ocs-scn"][ocs_scn_ju     ]

 entries["ocs-scn"][ocs_scn_JA     ] =  entries["ocs-scn"][ocs_scn_ja     ]
mappings["ocs-scn"][ocs_scn_JA     ] = mappings["ocs-scn"][ocs_scn_ja     ]

 entries["ocs-scn"][ocs_scn_JE     ] =  entries["ocs-scn"][ocs_scn_je     ]
mappings["ocs-scn"][ocs_scn_JE     ] = mappings["ocs-scn"][ocs_scn_je     ]

 entries["ocs-scn"][ocs_scn_IJUS   ] =  entries["ocs-scn"][ocs_scn_ijus   ]
mappings["ocs-scn"][ocs_scn_IJUS   ] = mappings["ocs-scn"][ocs_scn_ijus   ]

 entries["ocs-scn"][ocs_scn_IBIGJUS] =  entries["ocs-scn"][ocs_scn_ibigjus]
mappings["ocs-scn"][ocs_scn_IBIGJUS] = mappings["ocs-scn"][ocs_scn_ibigjus]

 entries["ocs-scn"][ocs_scn_XI     ] =  entries["ocs-scn"][ocs_scn_xi     ]
mappings["ocs-scn"][ocs_scn_XI     ] = mappings["ocs-scn"][ocs_scn_xi     ]

 entries["ocs-scn"][ocs_scn_PSI    ] =  entries["ocs-scn"][ocs_scn_psi    ]
mappings["ocs-scn"][ocs_scn_PSI    ] = mappings["ocs-scn"][ocs_scn_psi    ]

 entries["ocs-scn"][ocs_scn_THETA  ] =  entries["ocs-scn"][ocs_scn_theta  ]
mappings["ocs-scn"][ocs_scn_THETA  ] = mappings["ocs-scn"][ocs_scn_theta  ]

 entries["ocs-scn"][ocs_scn_SHCH   ] =  entries["ocs-scn"][ocs_scn_shch   ]
mappings["ocs-scn"][ocs_scn_SHCH   ] = mappings["ocs-scn"][ocs_scn_shch   ]

--- Norwegian (bokmål).

replacements["no"] = { --[[ None, do you miss any? ]] }

entries["no"] = {
    ["a"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["v"] = "v",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
    ["æ"] = "æ",
    ["ø"] = "ø",
    ["å"] = "å",
}

mappings["no"] = {
    ["a"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["d"] =  4,
    ["e"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["o"] = 15,
    ["p"] = 16,
    ["q"] = 17,
    ["r"] = 18,
    ["s"] = 19,
    ["t"] = 20,
    ["u"] = 21,
    ["v"] = 22,
    ["w"] = 23,
    ["x"] = 24,
    ["y"] = 25,
    ["z"] = 26,
    ["æ"] = 27,
    ["ø"] = 28,
    ["å"] = 29,
}

adduppercaseentries ("no")
adduppercasemappings("no")

--- Danish (-> Norwegian).

replacements["da"] = { --[[ None, do you miss any? ]] }
     entries["da"] = entries["no"]
    mappings["da"] = mappings["no"]

--- Swedish

replacements["sv"] = { --[[ None, do you miss any? ]] }

entries["sv"] = {
    ["a"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["v"] = "v",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
    ["å"] = "å",
    ["ä"] = "ä",
    ["ö"] = "ö",
}

mappings["sv"] = {
    ["a"] =   1,
    ["b"] =   2,
    ["c"] =   3,
    ["d"] =   4,
    ["e"] =   5,
    ["f"] =   6,
    ["g"] =   7,
    ["h"] =   8,
    ["i"] =   9,
    ["j"] =  10,
    ["k"] =  11,
    ["l"] =  12,
    ["m"] =  13,
    ["n"] =  14,
    ["o"] =  15,
    ["p"] =  16,
    ["q"] =  17,
    ["r"] =  18,
    ["s"] =  19,
    ["t"] =  20,
    ["u"] =  21,
    ["v"] =  22,
    ["w"] =  23,
    ["x"] =  24,
    ["y"] =  25,
    ["z"] =  26,
    ["å"] =  27,
    ["ä"] =  28,
    ["ö"] =  29,
}

adduppercaseentries ("sv")
adduppercasemappings("sv")

--- Icelandic

-- Treating quantities as allographs.

replacements["is"] = { --[[ None, do you miss any? ]] }

entries["is"] = {
    ["a"] = "a",
    ["á"] = "a",
    ["b"] = "b",
    ["d"] = "d",
    ["ð"] = "ð",
    ["e"] = "e",
    ["é"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["í"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["ó"] = "o",
    ["p"] = "p",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["ú"] = "u",
    ["v"] = "v",
    ["x"] = "x",
    ["y"] = "y",
    ["ý"] = "y",
    ["þ"] = "þ",
    ["æ"] = "æ",
    ["ö"] = "ö",
}

mappings["is"] = {
    ["a"] =  1,
    ["á"] =  1,
    ["b"] =  2,
    ["d"] =  3,
    ["ð"] =  4,
    ["e"] =  5,
    ["é"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["í"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["o"] = 15,
    ["ó"] = 15,
    ["p"] = 16,
    ["r"] = 17,
    ["s"] = 18,
    ["t"] = 19,
    ["u"] = 20,
    ["ú"] = 20,
    ["v"] = 21,
    ["x"] = 22,
    ["y"] = 23,
    ["ý"] = 23,
    ["þ"] = 24,
    ["æ"] = 25,
    ["ö"] = 26,
}

adduppercaseentries ("is")
adduppercasemappings("is")

--- Greek

replacements["gr"] = { --[[ None, do you miss any? ]] }

entries["gr"] = {
    ["α"] = "α",
    ["ά"] = "α",
    ["ὰ"] = "α",
    ["ᾶ"] = "α",
    ["ᾳ"] = "α",
    ["ἀ"] = "α",
    ["ἁ"] = "α",
    ["ἄ"] = "α",
    ["ἂ"] = "α",
    ["ἆ"] = "α",
    ["ἁ"] = "α",
    ["ἅ"] = "α",
    ["ἃ"] = "α",
    ["ἇ"] = "α",
    ["ᾁ"] = "α",
    ["ᾴ"] = "α",
    ["ᾲ"] = "α",
    ["ᾷ"] = "α",
    ["ᾄ"] = "α",
    ["ᾂ"] = "α",
    ["ᾅ"] = "α",
    ["ᾃ"] = "α",
    ["ᾆ"] = "α",
    ["ᾇ"] = "α",
    ["β"] = "β",
    ["γ"] = "γ",
    ["δ"] = "δ",
    ["ε"] = "ε",
    ["έ"] = "ε",
    ["ὲ"] = "ε",
    ["ἐ"] = "ε",
    ["ἔ"] = "ε",
    ["ἒ"] = "ε",
    ["ἑ"] = "ε",
    ["ἕ"] = "ε",
    ["ἓ"] = "ε",
    ["ζ"] = "ζ",
    ["η"] = "η",
    ["η"] = "η",
    ["ή"] = "η",
    ["ὴ"] = "η",
    ["ῆ"] = "η",
    ["ῃ"] = "η",
    ["ἠ"] = "η",
    ["ἤ"] = "η",
    ["ἢ"] = "η",
    ["ἦ"] = "η",
    ["ᾐ"] = "η",
    ["ἡ"] = "η",
    ["ἥ"] = "η",
    ["ἣ"] = "η",
    ["ἧ"] = "η",
    ["ᾑ"] = "η",
    ["ῄ"] = "η",
    ["ῂ"] = "η",
    ["ῇ"] = "η",
    ["ᾔ"] = "η",
    ["ᾒ"] = "η",
    ["ᾕ"] = "η",
    ["ᾓ"] = "η",
    ["ᾖ"] = "η",
    ["ᾗ"] = "η",
    ["θ"] = "θ",
    ["ι"] = "ι",
    ["ί"] = "ι",
    ["ὶ"] = "ι",
    ["ῖ"] = "ι",
    ["ἰ"] = "ι",
    ["ἴ"] = "ι",
    ["ἲ"] = "ι",
    ["ἶ"] = "ι",
    ["ἱ"] = "ι",
    ["ἵ"] = "ι",
    ["ἳ"] = "ι",
    ["ἷ"] = "ι",
    ["ϊ"] = "ι",
    ["ΐ"] = "ι",
    ["ῒ"] = "ι",
    ["ῗ"] = "ι",
    ["κ"] = "κ",
    ["λ"] = "λ",
    ["μ"] = "μ",
    ["ν"] = "ν",
    ["ξ"] = "ξ",
    ["ο"] = "ο",
    ["ό"] = "ο",
    ["ὸ"] = "ο",
    ["ὀ"] = "ο",
    ["ὄ"] = "ο",
    ["ὂ"] = "ο",
    ["ὁ"] = "ο",
    ["ὅ"] = "ο",
    ["ὃ"] = "ο",
    ["π"] = "π",
    ["ρ"] = "ρ",
    ["ῤ"] = "ῤ",
    ["ῥ"] = "ῥ",
    ["σ"] = "σ",
    ["ς"] = "ς",
    ["τ"] = "τ",
    ["υ"] = "υ",
    ["ύ"] = "υ",
    ["ὺ"] = "υ",
    ["ῦ"] = "υ",
    ["ὐ"] = "υ",
    ["ὔ"] = "υ",
    ["ὒ"] = "υ",
    ["ὖ"] = "υ",
    ["ὑ"] = "υ",
    ["ὕ"] = "υ",
    ["ὓ"] = "υ",
    ["ὗ"] = "υ",
    ["ϋ"] = "υ",
    ["ΰ"] = "υ",
    ["ῢ"] = "υ",
    ["ῧ"] = "υ",
    ["φ"] = "φ",
    ["χ"] = "χ",
    ["ψ"] = "ω",
    ["ω"] = "ω",
    ["ώ"] = "ω",
    ["ὼ"] = "ω",
    ["ῶ"] = "ω",
    ["ῳ"] = "ω",
    ["ὠ"] = "ω",
    ["ὤ"] = "ω",
    ["ὢ"] = "ω",
    ["ὦ"] = "ω",
    ["ᾠ"] = "ω",
    ["ὡ"] = "ω",
    ["ὥ"] = "ω",
    ["ὣ"] = "ω",
    ["ὧ"] = "ω",
    ["ᾡ"] = "ω",
    ["ῴ"] = "ω",
    ["ῲ"] = "ω",
    ["ῷ"] = "ω",
    ["ᾤ"] = "ω",
    ["ᾢ"] = "ω",
    ["ᾥ"] = "ω",
    ["ᾣ"] = "ω",
    ["ᾦ"] = "ω",
    ["ᾧ"] = "ω",
}

mappings["gr"] = {
    ["α"] =  1,
    ["ά"] =  1,
    ["ὰ"] =  1,
    ["ᾶ"] =  1,
    ["ᾳ"] =  1,
    ["ἀ"] =  1,
    ["ἁ"] =  1,
    ["ἄ"] =  1,
    ["ἂ"] =  1,
    ["ἆ"] =  1,
    ["ἁ"] =  1,
    ["ἅ"] =  1,
    ["ἃ"] =  1,
    ["ἇ"] =  1,
    ["ᾁ"] =  1,
    ["ᾴ"] =  1,
    ["ᾲ"] =  1,
    ["ᾷ"] =  1,
    ["ᾄ"] =  1,
    ["ᾂ"] =  1,
    ["ᾅ"] =  1,
    ["ᾃ"] =  1,
    ["ᾆ"] =  1,
    ["ᾇ"] =  1,
    ["β"] =  2,
    ["γ"] =  3,
    ["δ"] =  4,
    ["ε"] =  5,
    ["έ"] =  5,
    ["ὲ"] =  5,
    ["ἐ"] =  5,
    ["ἔ"] =  5,
    ["ἒ"] =  5,
    ["ἑ"] =  5,
    ["ἕ"] =  5,
    ["ἓ"] =  5,
    ["ζ"] =  6,
    ["η"] =  7,
    ["η"] =  7,
    ["ή"] =  7,
    ["ὴ"] =  7,
    ["ῆ"] =  7,
    ["ῃ"] =  7,
    ["ἠ"] =  7,
    ["ἤ"] =  7,
    ["ἢ"] =  7,
    ["ἦ"] =  7,
    ["ᾐ"] =  7,
    ["ἡ"] =  7,
    ["ἥ"] =  7,
    ["ἣ"] =  7,
    ["ἧ"] =  7,
    ["ᾑ"] =  7,
    ["ῄ"] =  7,
    ["ῂ"] =  7,
    ["ῇ"] =  7,
    ["ᾔ"] =  7,
    ["ᾒ"] =  7,
    ["ᾕ"] =  7,
    ["ᾓ"] =  7,
    ["ᾖ"] =  7,
    ["ᾗ"] =  7,
    ["θ"] =  8,
    ["ι"] =  9,
    ["ί"] =  9,
    ["ὶ"] =  9,
    ["ῖ"] =  9,
    ["ἰ"] =  9,
    ["ἴ"] =  9,
    ["ἲ"] =  9,
    ["ἶ"] =  9,
    ["ἱ"] =  9,
    ["ἵ"] =  9,
    ["ἳ"] =  9,
    ["ἷ"] =  9,
    ["ϊ"] =  9,
    ["ΐ"] =  9,
    ["ῒ"] =  9,
    ["ῗ"] =  9,
    ["κ"] = 10,
    ["λ"] = 11,
    ["μ"] = 12,
    ["ν"] = 13,
    ["ξ"] = 14,
    ["ο"] = 15,
    ["ό"] = 15,
    ["ὸ"] = 15,
    ["ὀ"] = 15,
    ["ὄ"] = 15,
    ["ὂ"] = 15,
    ["ὁ"] = 15,
    ["ὅ"] = 15,
    ["ὃ"] = 15,
    ["π"] = 16,
    ["ρ"] = 17,
    ["ῤ"] = 17,
    ["ῥ"] = 17,
    ["σ"] = 18,
    ["ς"] = 18,
    ["τ"] = 19,
    ["υ"] = 20,
    ["ύ"] = 20,
    ["ὺ"] = 20,
    ["ῦ"] = 20,
    ["ὐ"] = 20,
    ["ὔ"] = 20,
    ["ὒ"] = 20,
    ["ὖ"] = 20,
    ["ὑ"] = 20,
    ["ὕ"] = 20,
    ["ὓ"] = 20,
    ["ὗ"] = 20,
    ["ϋ"] = 20,
    ["ΰ"] = 20,
    ["ῢ"] = 20,
    ["ῧ"] = 20,
    ["φ"] = 21,
    ["χ"] = 22,
    ["ψ"] = 23,
    ["ω"] = 24,
    ["ώ"] = 24,
    ["ὼ"] = 24,
    ["ῶ"] = 24,
    ["ῳ"] = 24,
    ["ὠ"] = 24,
    ["ὤ"] = 24,
    ["ὢ"] = 24,
    ["ὦ"] = 24,
    ["ᾠ"] = 24,
    ["ὡ"] = 24,
    ["ὥ"] = 24,
    ["ὣ"] = 24,
    ["ὧ"] = 24,
    ["ᾡ"] = 24,
    ["ῴ"] = 24,
    ["ῲ"] = 24,
    ["ῷ"] = 24,
    ["ᾤ"] = 24,
    ["ᾢ"] = 24,
    ["ᾥ"] = 24,
    ["ᾣ"] = 24,
    ["ᾦ"] = 24,
    ["ᾧ"] = 24,
}

adduppercaseentries ("gr")
adduppercasemappings("gr")

--- Latin

-- Treating the post-classical fricatives “j” and “v” as “i” and “u”
-- respectively.

replacements["la"] = {
    [1] = { "æ", "ae" },
}

entries["la"] = {
    ["a"] = "a",
    ["ā"] = "a",
    ["ă"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["ē"] = "e",
    ["ĕ"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["ī"] = "i",
    ["ĭ"] = "i",
    ["j"] = "i",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["ō"] = "o",
    ["ŏ"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["ū"] = "u",
    ["ŭ"] = "u",
    ["v"] = "u",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["ȳ"] = "y", -- Should exist in Greek words.
    ["y̆"] = "y", -- Should exist in Greek words.
    ["z"] = "z",
}

mappings["la"] = {
    ["a"] =  1,
    ["ā"] =  1,
    ["ă"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["d"] =  4,
    ["e"] =  5,
    ["ē"] =  5,
    ["ĕ"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["ī"] =  9,
    ["ĭ"] =  9,
    ["j"] =  9,
    ["k"] = 10,
    ["l"] = 11,
    ["m"] = 12,
    ["n"] = 13,
    ["o"] = 14,
    ["ō"] = 14,
    ["ŏ"] = 14,
    ["p"] = 15,
    ["q"] = 16,
    ["r"] = 17,
    ["s"] = 18,
    ["t"] = 19,
    ["u"] = 20,
    ["ū"] = 20,
    ["ŭ"] = 20,
    ["v"] = 20,
    ["w"] = 21,
    ["x"] = 22,
    ["y"] = 23,
    ["ȳ"] = 23,
    ["y̆"] = 23,
    ["z"] = 24,
}

adduppercaseentries ("la")
adduppercasemappings("la")

--- Italian

replacements["it"] = { --[[ None, do you miss any? ]] }

entries["it"] = {
    ["a"] = "a",
    ["á"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["é"] = "e",
    ["è"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["í"] = "i",
    ["ì"] = "i",
    ["j"] = "i",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["ó"] = "o",
    ["ò"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["ú"] = "u",
    ["ù"] = "u",
    ["v"] = "u",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
}

mappings["it"] = {
    ["a"] =  1,
    ["á"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["d"] =  4,
    ["e"] =  5,
    ["é"] =  5,
    ["è"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["í"] =  9,
    ["ì"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["o"] = 15,
    ["ó"] = 15,
    ["ò"] = 15,
    ["p"] = 16,
    ["q"] = 17,
    ["r"] = 18,
    ["s"] = 19,
    ["t"] = 20,
    ["u"] = 21,
    ["ú"] = 21,
    ["ù"] = 21,
    ["v"] = 22,
    ["w"] = 23,
    ["x"] = 24,
    ["y"] = 25,
    ["z"] = 26,
}

adduppercaseentries ("it")
adduppercasemappings("it")

--- Romanian


replacements["ro"] = { --[[ None, do you miss any? ]] }

entries["ro"] = {
    ["a"] = "a",
    ["ă"] = "ă",
    ["â"] = "â",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["î"] = "î",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["ș"] = "ș",
    ["t"] = "t",
    ["ț"] = "ț",
    ["u"] = "u",
    ["v"] = "v",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
}

mappings["ro"] = {
    ["a"] =  1,
    ["ă"] =  2,
    ["â"] =  3,
    ["b"] =  4,
    ["c"] =  5,
    ["d"] =  6,
    ["e"] =  7,
    ["f"] =  8,
    ["g"] =  9,
    ["h"] = 10,
    ["i"] = 11,
    ["î"] = 12,
    ["j"] = 13,
    ["k"] = 14,
    ["l"] = 15,
    ["m"] = 16,
    ["n"] = 17,
    ["o"] = 18,
    ["p"] = 19,
    ["q"] = 20,
    ["r"] = 21,
    ["s"] = 22,
    ["ș"] = 23,
    ["t"] = 24,
    ["ț"] = 25,
    ["u"] = 26,
    ["v"] = 27,
    ["w"] = 28,
    ["x"] = 29,
    ["y"] = 30,
    ["z"] = 31,
}

adduppercaseentries ("ro")
adduppercasemappings("ro")

--- Spanish

replacements["es"] = { --[[ None, do you miss any? ]] }

entries["es"] = {
    ["a"] = "a",
    ["á"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["é"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["í"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["ñ"] = "ñ",
    ["o"] = "o",
    ["ó"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["ú"] = "u",
    ["ü"] = "u",
    ["v"] = "v",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
}

mappings["es"] = {
    ["a"] =  1,
    ["á"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["d"] =  4,
    ["e"] =  5,
    ["é"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["í"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["ñ"] = 15,
    ["o"] = 16,
    ["ó"] = 16,
    ["p"] = 17,
    ["q"] = 18,
    ["r"] = 19,
    ["s"] = 20,
    ["t"] = 21,
    ["u"] = 22,
    ["ú"] = 22,
    ["ü"] = 22,
    ["v"] = 23,
    ["w"] = 24,
    ["x"] = 25,
    ["y"] = 26,
    ["z"] = 27,
}

adduppercaseentries ("es")
adduppercasemappings("es")

--- Portuguese

replacements["pt"] = { --[[ None, do you miss any? ]] }

entries["pt"] = {
    ["a"] = "a",
    ["á"] = "a",
    ["â"] = "a",
    ["ã"] = "a",
    ["à"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["ç"] = "c",
    ["d"] = "d",
    ["e"] = "e",
    ["é"] = "e",
    ["ê"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["í"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["ó"] = "o",
    ["ô"] = "o",
    ["õ"] = "o",
    ["p"] = "p",
    ["q"] = "q",
    ["r"] = "r",
    ["s"] = "s",
    ["t"] = "t",
    ["u"] = "u",
    ["ú"] = "u",
    ["ü"] = "u", -- qüinqüelíngüe
    ["v"] = "v",
    ["w"] = "w",
    ["x"] = "x",
    ["y"] = "y",
    ["z"] = "z",
}

mappings["pt"] = {
    ["a"] =  1,
    ["á"] =  1,
    ["â"] =  1,
    ["ã"] =  1,
    ["à"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["ç"] =  3,
    ["d"] =  4,
    ["e"] =  5,
    ["é"] =  5,
    ["ê"] =  5,
    ["f"] =  6,
    ["g"] =  7,
    ["h"] =  8,
    ["i"] =  9,
    ["í"] =  9,
    ["j"] = 10,
    ["k"] = 11,
    ["l"] = 12,
    ["m"] = 13,
    ["n"] = 14,
    ["o"] = 15,
    ["ó"] = 15,
    ["ô"] = 15,
    ["õ"] = 15,
    ["p"] = 16,
    ["q"] = 17,
    ["r"] = 18,
    ["s"] = 19,
    ["t"] = 20,
    ["u"] = 21,
    ["ú"] = 21,
    ["ü"] = 21,
    ["v"] = 22,
    ["w"] = 23,
    ["x"] = 24,
    ["y"] = 25,
    ["z"] = 26,
}

adduppercaseentries ("pt")
adduppercasemappings("pt")


--- Lithuanian

local lt_ch = uc(replacementoffset + 1)
local lt_CH = uc(replacementoffset + 2)

replacements["lt"] = {
    [1] = { "ch", lt_ch }
}

entries["lt"] = {
    ["a"] = "a",
    ["ą"] = "a",
    ["b"] = "b",
    ["c"] = "c",
  [lt_ch] = "c",
    ["č"] = "č",
    ["d"] = "d",
    ["e"] = "e",
    ["ę"] = "e",
    ["ė"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["į"] = "i",
    ["y"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["r"] = "r",
    ["s"] = "s",
    ["š"] = "š",
    ["t"] = "t",
    ["u"] = "u",
    ["ų"] = "u",
    ["ū"] = "u",
    ["v"] = "v",
    ["z"] = "z",
    ["ž"] = "ž",
}

mappings["lt"] = {
    ["a"] =  1,
    ["ą"] =  1,
    ["b"] =  2,
    ["c"] =  3,
  [lt_ch] =  3,
    ["č"] =  4,
    ["d"] =  5,
    ["e"] =  6,
    ["ę"] =  6,
    ["ė"] =  6,
    ["f"] =  7,
    ["g"] =  8,
    ["h"] =  9,
    ["i"] = 10,
    ["į"] = 10,
    ["y"] = 10,
    ["j"] = 11,
    ["k"] = 12,
    ["l"] = 13,
    ["m"] = 14,
    ["n"] = 15,
    ["o"] = 16,
    ["p"] = 17,
    ["r"] = 18,
    ["s"] = 19,
    ["š"] = 20,
    ["t"] = 21,
    ["u"] = 22,
    ["ų"] = 22,
    ["ū"] = 22,
    ["v"] = 23,
    ["z"] = 24,
    ["ž"] = 25,
}

adduppercaseentries ("lt")
adduppercasemappings("lt")

entries ["lt"][lt_CH] = entries ["lt"][lt_ch]
mappings["lt"][lt_CH] = mappings["lt"][lt_ch]

--- Latvian

replacements["lv"] = { --[[ None, do you miss any? ]] }

entries["lv"] = {
    ["a"] = "a",
    ["ā"] = "a",
    ["b"] = "b",
    ["c"] = "c",
    ["č"] = "č",
    ["d"] = "d",
    ["e"] = "e",
    ["ē"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["ģ"] = "ģ",
    ["h"] = "h",
    ["i"] = "i",
    ["ī"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["ķ"] = "ķ",
    ["l"] = "l",
    ["ļ"] = "ļ",
    ["m"] = "m",
    ["n"] = "n",
    ["ņ"] = "ņ",
    ["o"] = "o",
    ["ō"] = "o",
    ["p"] = "p",
    ["r"] = "r",
    ["ŗ"] = "ŗ",
    ["s"] = "s",
    ["š"] = "š",
    ["t"] = "t",
    ["u"] = "u",
    ["ū"] = "u",
    ["v"] = "v",
    ["z"] = "z",
    ["ž"] = "ž",
}

mappings["lv"] = {
    ["a"] =  1,
    ["ā"] =  1,
    ["b"] =  2,
    ["c"] =  3,
    ["č"] =  4,
    ["d"] =  5,
    ["e"] =  6,
    ["ē"] =  6,
    ["f"] =  7,
    ["g"] =  8,
    ["ģ"] =  9,
    ["h"] = 10,
    ["i"] = 11,
    ["ī"] = 11,
    ["j"] = 12,
    ["k"] = 13,
    ["ķ"] = 14,
    ["l"] = 15,
    ["ļ"] = 16,
    ["m"] = 17,
    ["n"] = 18,
    ["ņ"] = 19,
    ["o"] = 20,
    ["ō"] = 20,
    ["p"] = 21,
    ["r"] = 22,
    ["ŗ"] = 23,
    ["s"] = 24,
    ["š"] = 25,
    ["t"] = 26,
    ["u"] = 27,
    ["ū"] = 27,
    ["v"] = 28,
    ["z"] = 29,
    ["ž"] = 30,
}

adduppercaseentries ("lv")
adduppercasemappings("lv")

--- Hungarian

-- Helpful but disturbing:
-- http://en.wikipedia.org/wiki/Hungarian_alphabet#Alphabetical_ordering_.28collation.29
-- (In short: you'd have to analyse word-compounds to realize a correct order
-- for sequences like “nny”, “ssz”, and “zsz”. This is left as an exercise to
-- the reader…)

local hu_cs  = uc(replacementoffset +  1)
local hu_CS  = uc(replacementoffset +  2)

local hu_dz  = uc(replacementoffset +  3)
local hu_DZ  = uc(replacementoffset +  4)

local hu_dzs = uc(replacementoffset +  5)
local hu_DZS = uc(replacementoffset +  6)

local hu_gy  = uc(replacementoffset +  7)
local hu_GY  = uc(replacementoffset +  8)

local hu_ly  = uc(replacementoffset +  9)
local hu_LY  = uc(replacementoffset + 10)

local hu_ny  = uc(replacementoffset + 11)
local hu_NY  = uc(replacementoffset + 12)

local hu_sz  = uc(replacementoffset + 13)
local hu_SZ  = uc(replacementoffset + 14)

local hu_ty  = uc(replacementoffset + 15)
local hu_TY  = uc(replacementoffset + 16)

local hu_zs  = uc(replacementoffset + 17)
local hu_ZS  = uc(replacementoffset + 18)

replacements["hu"] = {
    [1] = { "cs",  hu_cs  },
    [2] = { "dz",  hu_dz  },
    [3] = { "dzs", hu_dzs },
    [4] = { "gy",  hu_gy  },
    [5] = { "ly",  hu_ly  },
    [6] = { "ny",  hu_ny  },
    [7] = { "sz",  hu_sz  },
    [8] = { "ty",  hu_ty  },
    [9] = { "zs",  hu_zs  },
}

entries["hu"] = {
    ["a"] =   "a",
    ["á"] =   "a",
    ["b"] =   "b",
    ["c"] =   "c",
  [hu_cs] =  "cs",
    ["d"] =   "d",
  [hu_dz] =  "dz",
 [hu_dzs] = "dzs",
    ["e"] =   "e",
    ["é"] =   "e",
    ["f"] =   "f",
    ["g"] =   "g",
  [hu_gy] =  "gy",
    ["h"] =   "h",
    ["i"] =   "i",
    ["í"] =   "i",
    ["j"] =   "j",
    ["k"] =   "k",
    ["l"] =   "l",
  [hu_ly] =  "ly",
    ["m"] =   "m",
    ["n"] =   "n",
  [hu_ny] =  "ny",
    ["o"] =   "o",
    ["ó"] =   "o",
    ["ö"] =   "ö",
    ["ő"] =   "ö",
    ["p"] =   "p",
    ["q"] =   "q",
    ["r"] =   "r",
    ["s"] =   "s",
  [hu_sz] =  "sz",
    ["t"] =   "t",
  [hu_ty] =  "ty",
    ["u"] =   "u",
    ["ú"] =   "u",
    ["ü"] =   "ü",
    ["ű"] =   "ü",
    ["v"] =   "v",
    ["w"] =   "w",
    ["x"] =   "x",
    ["y"] =   "y",
    ["z"] =   "z",
  [hu_zs] =  "zs",
}

mappings["hu"] = {
    ["a"] =  1,
    ["á"] =  1, -- -> a
    ["b"] =  2,
    ["c"] =  3,
  [hu_cs] =  4,
    ["d"] =  5,
  [hu_dz] =  6,
 [hu_dzs] =  7,
    ["e"] =  8,
    ["é"] =  8, -- -> e
    ["f"] =  9,
    ["g"] = 10,
  [hu_gy] = 11,
    ["h"] = 12,
    ["i"] = 13,
    ["í"] = 13, -- -> i
    ["j"] = 14,
    ["k"] = 15,
    ["l"] = 16,
  [hu_ly] = 17,
    ["m"] = 18,
    ["n"] = 19,
  [hu_ny] = 20,
    ["o"] = 21,
    ["ó"] = 21, -- -> o
    ["ö"] = 22,
    ["ő"] = 22, -- -> ö
    ["p"] = 23,
    ["q"] = 24,
    ["r"] = 25,
    ["s"] = 26,
  [hu_sz] = 27,
    ["t"] = 28,
  [hu_ty] = 29,
    ["u"] = 30,
    ["ú"] = 30, -- -> u
    ["ü"] = 31,
    ["ű"] = 31, -- -> ü
    ["v"] = 32,
    ["w"] = 33,
    ["x"] = 34,
    ["y"] = 35,
    ["z"] = 36,
  [hu_zs] = 37,
}

adduppercaseentries ("hu")
adduppercasemappings("hu")

entries ["hu"] [hu_CS] = entries ["hu"] [hu_cs]
mappings["hu"] [hu_CS] = mappings["hu"] [hu_cs]
entries ["hu"] [hu_DZ] = entries ["hu"] [hu_dz]
mappings["hu"] [hu_DZ] = mappings["hu"] [hu_dz]
entries ["hu"][hu_DZS] = entries ["hu"][hu_dzs]
mappings["hu"][hu_DZS] = mappings["hu"][hu_dzs]
entries ["hu"] [hu_GY] = entries ["hu"] [hu_gy]
mappings["hu"] [hu_GY] = mappings["hu"] [hu_gy]
entries ["hu"] [hu_LY] = entries ["hu"] [hu_ly]
mappings["hu"] [hu_LY] = mappings["hu"] [hu_ly]
entries ["hu"] [hu_NY] = entries ["hu"] [hu_ny]
mappings["hu"] [hu_NY] = mappings["hu"] [hu_ny]
entries ["hu"] [hu_SZ] = entries ["hu"] [hu_sz]
mappings["hu"] [hu_SZ] = mappings["hu"] [hu_sz]
entries ["hu"] [hu_TY] = entries ["hu"] [hu_ty]
mappings["hu"] [hu_TY] = mappings["hu"] [hu_ty]
entries ["hu"] [hu_ZS] = entries ["hu"] [hu_zs]
mappings["hu"] [hu_ZS] = mappings["hu"] [hu_zs]

--- Estonian

replacements["et"] = { --[[ None, do you miss any? ]] }

entries["et"] = {
    ["a"] = "a",
    ["b"] = "b",
    ["d"] = "d",
    ["e"] = "e",
    ["f"] = "f",
    ["g"] = "g",
    ["h"] = "h",
    ["i"] = "i",
    ["j"] = "j",
    ["k"] = "k",
    ["l"] = "l",
    ["m"] = "m",
    ["n"] = "n",
    ["o"] = "o",
    ["p"] = "p",
    ["r"] = "r",
    ["s"] = "s",
    ["š"] = "š",
    ["z"] = "z",
    ["ž"] = "ž",
    ["t"] = "t",
    ["u"] = "u",
    ["v"] = "v",
    ["w"] = "v", -- foreign words only
    ["õ"] = "õ",
    ["ä"] = "ä",
    ["ö"] = "ö",
    ["ü"] = "ü",
    ["x"] = "x", --foreign words only
    ["y"] = "y", --foreign words only
}

mappings["et"] = {
    ["a"] =  1,
    ["b"] =  2,
    ["d"] =  3,
    ["e"] =  4,
    ["f"] =  5,
    ["g"] =  6,
    ["h"] =  7,
    ["i"] =  8,
    ["j"] =  9,
    ["k"] = 10,
    ["l"] = 11,
    ["m"] = 12,
    ["n"] = 13,
    ["o"] = 14,
    ["p"] = 15,
    ["r"] = 16,
    ["s"] = 17,
    ["š"] = 18,
    ["z"] = 19,
    ["ž"] = 20,
    ["t"] = 21,
    ["u"] = 22,
    ["v"] = 23,
    ["w"] = 23,
    ["õ"] = 24,
    ["ä"] = 25,
    ["ö"] = 26,
    ["ü"] = 27,
    ["x"] = 28,
    ["y"] = 29,
}

adduppercaseentries ("et")
adduppercasemappings("et")
