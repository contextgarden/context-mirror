if not modules then modules = { } end modules ['sort-lan'] = {
    version   = 1.001,
    comment   = "companion to sort-lan.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a rather preliminary and incomplete file
-- maybe we should load this kind of stuff runtime

-- replacements are indexed as they need to be applied in sequence

local utf = unicode.utf8
local uc = utf.char
local ub = utf.byte

local mappings                   = sorters.mappings
local entries                    = sorters.entries
local replacements               = sorters.replacements

local add_uppercase_replacements = sorters.add_uppercase_replacements
local add_uppercase_entries      = sorters.add_uppercase_entries
local add_uppercase_mappings     = sorters.add_uppercase_mappings

local replacement_offset         = sorters.replacement_offset

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

-- czech

local cz_ch = uc(replacement_offset + 1)
local cz_CH = uc(replacement_offset + 2)

replacements['cz'] = {
    [1] = { "ch", cz_ch }
}

entries['cz'] = {
    ['a']        = "a",        -- a
    [uc(0x00E1)] = "a",        -- aacute
    ['b']        = "b",        -- b
    ['c']        = "c",        -- c
    [uc(0x010D)] = uc(0x010D), -- ccaron
    ['d']        = "d",        -- d
    [uc(0x010F)] = "d",        -- dcaron
    ['e']        = "e",        -- e
    [uc(0x00E9)] = "e",        -- eacute
    [uc(0x011B)] = "e",        -- ecaron
    ['f']        = "f",        -- f
    ['g']        = "g",        -- g
    ['h']        = "h",        -- h
    [cz_ch]      = "ch",       -- ch
    ['i']        = "i",        -- i
    [uc(0x00ED)] = "i",        -- iacute
    ['j']        = "j",        -- j
    ['k']        = "k",        -- k
    ['l']        = "l",        -- l
    ['m']        = "m",        -- m
    ['n']        = "n",        -- n
    ['ň']        = "n",        -- ncaron
    ['o']        = "o",        -- o
    ['p']        = "p",        -- p
    ['q']        = "q",        -- q
    ['r']        = "r",        -- r
    ['ř']        = "ř",        -- rcaron
    ['s']        = "s",        -- s
    [uc(0x0161)] = uc(0x0161), -- scaron
    ['t']        = "t",        -- t
    [uc(0x0165)] = "t",        -- tcaron
    ['u']        = "u",        -- u
    [uc(0x00FA)] = "u",        -- uacute
    [uc(0x016F)] = "u",        -- uring
    ['v']        = "v",        -- v
    ['w']        = "w",        -- w
    ['x']        = "x",        -- x
    ['y']        = "y",        -- y
    [uc(0x00FD)] = "y",        -- yacute
    ['z']        = "z",        -- z
    [uc(0x017E)] = uc(0x017E), -- zcaron
}

mappings['cz'] = {
    ['a']        =  1, -- a
    [uc(0x00E1)] =  3, -- aacute
    ['b']        =  5, -- b
    ['c']        =  7, -- c
    [uc(0x010D)] =  9, -- ccaron
    ['d']        = 11, -- d
    [uc(0x010F)] = 13, -- dcaron
    ['e']        = 15, -- e
    [uc(0x00E9)] = 17, -- eacute
    [uc(0x011B)] = 19, -- ecaron
    ['f']        = 21, -- f
    ['g']        = 23, -- g
    ['h']        = 25, -- h
    [cz_ch]      = 27, -- ch
    ['i']        = 29, -- i
    [uc(0x00ED)] = 31, -- iacute
    ['j']        = 33, -- j
    ['k']        = 35, -- k
    ['l']        = 37, -- l
    ['m']        = 39, -- m
    ['n']        = 41, -- n
    ['ň']        = 43, -- ncaron
    ['o']        = 45, -- o
    ['p']        = 47, -- p
    ['q']        = 49, -- q
    ['r']        = 51, -- r
    ['ř']        = 53, -- rcaron
    ['s']        = 55, -- s
    [uc(0x0161)] = 57, -- scaron
    ['t']        = 59, -- t
    [uc(0x0165)] = 61, -- tcaron
    ['u']        = 63, -- u
    [uc(0x00FA)] = 65, -- uacute
    [uc(0x016F)] = 67, -- uring
    ['v']        = 69, -- v
    ['w']        = 71, -- w
    ['x']        = 73, -- x
    ['y']        = 75, -- y
    [uc(0x00FD)] = 77, -- yacute
    ['z']        = 79, -- z
    [uc(0x017E)] = 81, -- zcaron
}

add_uppercase_entries ("cz")
add_uppercase_mappings("cz") -- 1 can be option (but then we need a runtime variant)

entries ['cz'][cz_CH] = entries ['cz'][cz_ch]
mappings['cz'][cz_CH] = mappings['cz'][cz_ch]

replacements['cs'] = replacements['cz']
entries     ['cs'] = entries     ['cz']
mappings    ['cs'] = mappings    ['cz']

--~ print(table.serialize(mappings.cs))

-- French

entries ['fr'] = entries ['en']
mappings['fr'] = mappings['en']

-- German (by Wolfgang Schuster)

-- DIN 5007-1

entries  ['DIN 5007-1'] = entries ['en']
mappings ['DIN 5007-1'] = mappings['en']

-- DIN 5007-2

replacements['DIN 5007-2'] = { -- todo: add_uppercase_replacements
    { "ä", 'ae' },
    { "ö", 'oe' },
    { "ü", 'ue' },
    { "Ä", 'Ae' },
    { "Ö", 'Oe' },
    { "Ü", 'Ue' },
}

--~ add_uppercase_replacements('DIN 5007-2')

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

add_uppercase_entries ('de-AT')
add_uppercase_mappings('de-AT',1)

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

add_uppercase_entries ("fi")
add_uppercase_mappings("fi")

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

add_uppercase_entries ("sl")
add_uppercase_mappings("sl") -- cf. MM
