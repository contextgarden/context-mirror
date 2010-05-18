if not modules then modules = { } end modules ['sort-lan'] = {
    version   = 1.001,
    comment   = "companion to sort-lan.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local uc = utf.char
local ub = utf.byte

-- this is a rather preliminary and incomplete file
-- maybe we should load this kind of stuff runtime

-- english

-- The next one can be more efficient when not indexed this way, but
-- other languages are sparse so for the moment we keep this one.

-- replacements are indexed as they need to be applied in sequence

sorters = sorters or { entries = { }, replacements = { }, mappings =  { } }

sorters.entries['en'] = {
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

sorters.mappings['en'] = {
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

sorters.replacements['nl'] = { { "ij", 'y' }, { "IJ", 'Y' } }
sorters.entries     ['nl'] = sorters.entries ['en']
sorters.mappings    ['nl'] = sorters.mappings['en']

-- czech

sorters.replacements['cz'] = {
    [1] = { "ch", uc(0xFF01) }
}

sorters.entries['cz'] = {
    ['a']        = "a",        -- a
    [uc(0x00E1)] = "a",        -- aacute
    ['b']        = "b",        -- b
    ['c']        = "c",        -- c
    [uc(0x010D)] = uc(0x010D), -- ccaron
    ['d']        = "d",        -- d
    [uc(0x010F)] = uc(0x010F), -- dcaron
    ['e']        = "e",        -- e
    [uc(0x00E9)] = "e",        -- eacute
    [uc(0x011B)] = "e",        -- ecaron
    ['f']        = "f",        -- f
    ['g']        = "g",        -- g
    ['h']        = "h",        -- h
    [uc(0xFF01)] = "ch",       -- ch
    ['i']        = "i",        -- i
    [uc(0x00ED)] = "i",        -- iacute
    ['j']        = "j",        -- j
    ['k']        = "k",        -- k
    ['l']        = "l",        -- l
    ['m']        = "m",        -- m
    ['n']        = "n",        -- n
    [uc(0x0147)] = uc(0x0147), -- ncaron
    ['o']        = "o",        -- o
    ['p']        = "p",        -- p
    ['q']        = "q",        -- q
    ['r']        = "r",        -- r
    [uc(0x0147)] = uc(0x0147), -- rcaron
    ['s']        = "s",        -- s
    [uc(0x0161)] = uc(0x0161), -- scaron
    ['t']        = "t",        -- t
    [uc(0x0165)] = uc(0x0165), -- tcaron
    ['u']        = "u",        -- u
    [uc(0x00FA)] = "u",        -- uacute
    [uc(0x016F)] = "u",        -- uring
    ['v']        = "v",        -- v
    ['w']        = "w",        -- w
    ['x']        = "x",        -- x
    ['y']        = "y",        -- y
    [uc(0x00FD)] = uc(0x00FD), -- yacute
    ['z']        = "z",        -- z
    [uc(0x017E)] = uc(0x017E), -- zcaron
}

sorters.mappings['cz'] = {
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
    [uc(0xFF01)] = 27, -- ch
    ['i']        = 29, -- i
    [uc(0x00ED)] = 31, -- iacute
    ['j']        = 33, -- j
    ['k']        = 35, -- k
    ['l']        = 37, -- l
    ['m']        = 39, -- m
    ['n']        = 41, -- n
    [uc(0x0147)] = 43, -- ncaron
    ['o']        = 45, -- o
    ['p']        = 47, -- p
    ['q']        = 49, -- q
    ['r']        = 51, -- r
    [uc(0x0147)] = 53, -- rcaron
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

sorters.replacements['cs'] = sorters.replacements['cz']
sorters.entries     ['cs'] = sorters.entries     ['cz']
sorters.mappings    ['cs'] = sorters.mappings    ['cz']

sorters.add_uppercase_entries (sorters.entries.cs)
sorters.add_uppercase_mappings(sorters.mappings.cs,1)

--~ print(table.serialize(sorters.mappings.cs))

-- French

sorters.entries ['fr'] = sorters.entries ['en']
sorters.mappings['fr'] = sorters.mappings['en']

-- German (by Wolfgang Schuster)

-- DIN 5007-1

sorters.entries  ['DIN 5007-1'] = sorters.entries ['en']
sorters.mappings ['DIN 5007-1'] = sorters.mappings['en']

-- DIN 5007-2

sorters.replacements['DIN 5007-2'] = {
    { "ä", 'ae' },
    { "ö", 'oe' },
    { "ü", 'ue' },
    { "Ä", 'Ae' },
    { "Ö", 'Oe' },
    { "Ü", 'Ue' }
}

sorters.entries     ['DIN 5007-2'] = sorters.entries ['en']
sorters.mappings    ['DIN 5007-2'] = sorters.mappings['en']

-- Duden

sorters.replacements['Duden'] = { { "ß", 's' } }
sorters.entries     ['Duden'] = sorters.entries ['en']
sorters.mappings    ['Duden'] = sorters.mappings['en']

-- new german

sorters.entries     ['de'] = sorters.entries ['en']
sorters.mappings    ['de'] = sorters.mappings['en']

-- old german

sorters.entries     ['deo'] = sorters.entries ['de']
sorters.mappings    ['deo'] = sorters.mappings['de']

-- german - Germany

sorters.entries     ['de-DE'] = sorters.entries ['de']
sorters.mappings    ['de-DE'] = sorters.mappings['de']

-- german - Swiss

sorters.entries     ['de-CH'] = sorters.entries ['de']
sorters.mappings    ['de-CH'] = sorters.mappings['de']

-- german - Austria

sorters.entries['de-AT'] = {
    ["a"] = "a", ["ä"] = "ä", ["b"] = "b", ["c"] = "c", ["d"] = "d",
    ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
    ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n",
    ["o"] = "o", ["ö"] = "ö", ["p"] = "p", ["q"] = "q", ["r"] = "r",
    ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ü"] = "ü", ["v"] = "v",
    ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
    ["A"] = "a", ["Ä"] = "ä", ["B"] = "b", ["C"] = "c", ["D"] = "d",
    ["E"] = "e", ["F"] = "f", ["G"] = "g", ["H"] = "h", ["I"] = "i",
    ["J"] = "j", ["K"] = "k", ["L"] = "l", ["M"] = "m", ["N"] = "n",
    ["O"] = "o", ["Ö"] = "ö", ["P"] = "p", ["Q"] = "q", ["R"] = "r",
    ["S"] = "s", ["T"] = "t", ["U"] = "u", ["Ü"] = "ü", ["V"] = "v",
    ["W"] = "w", ["X"] = "x", ["Y"] = "y", ["Z"] = "z",
}

sorters.mappings['de-AT'] = {
    ["a"] =  1, ["ä"] =  3, ["b"] =  5, ["c"] =  7, ["d"] =  9,
    ["e"] = 11, ["f"] = 13, ["g"] = 15, ["h"] = 17, ["i"] = 19,
    ["j"] = 21, ["k"] = 23, ["l"] = 25, ["m"] = 27, ["n"] = 29,
    ["o"] = 31, ["ö"] = 33, ["p"] = 35, ["q"] = 37, ["r"] = 39,
    ["s"] = 41, ["t"] = 43, ["u"] = 45, ["ü"] = 47, ["v"] = 49,
    ["w"] = 51, ["x"] = 53, ["y"] = 55, ["z"] = 57,
    ["A"] =  2, ["Ä"] =  4, ["B"] =  6, ["C"] =  8, ["D"] = 10,
    ["E"] = 12, ["F"] = 14, ["G"] = 16, ["H"] = 18, ["I"] = 20,
    ["J"] = 22, ["K"] = 24, ["L"] = 26, ["M"] = 28, ["N"] = 30,
    ["O"] = 32, ["Ö"] = 34, ["P"] = 36, ["Q"] = 38, ["R"] = 40,
    ["S"] = 42, ["T"] = 44, ["U"] = 46, ["Ü"] = 48, ["V"] = 50,
    ["W"] = 52, ["X"] = 54, ["Y"] = 56, ["Z"] = 58,
}

-- finish (by Wolfgang Schuster)

sorters.entries['fi'] = {
    [ 1] = "a", [ 3] = "b", [ 5] = "c", [ 7] = "d", [ 9] = "e",
    [11] = "f", [13] = "g", [15] = "h", [17] = "i", [19] = "j",
    [21] = "k", [23] = "l", [25] = "m", [27] = "n", [29] = "o",
    [31] = "p", [33] = "q", [35] = "r", [37] = "s", [39] = "t",
    [41] = "u", [43] = "v", [45] = "w", [47] = "x", [49] = "y",
    [51] = "z", [53] = "å", [55] = "ä", [57] = "ö",
    [ 2] =   1, [ 4] =   3, [ 6] =   5, [ 8] =   7, [10] =   9,
    [12] =  11, [14] =  13, [16] =  15, [18] =  17, [20] =  19,
    [22] =  21, [24] =  23, [26] =  25, [28] =  27, [30] =  29,
    [32] =  31, [34] =  33, [36] =  35, [38] =  37, [40] =  39,
    [42] =  41, [44] =  43, [46] =  45, [48] =  47, [50] =  49,
    [52] =  51, [54] =  53, [56] =  55, [58] =  57,
}

sorters.entries['fi'] = {
    ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
    ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
    ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
    ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
    ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
    ["z"] = "z", ["å"] = "å", ["ä"] = "ä", ["ö"] = "ö",
    ["A"] = "a", ["B"] = "b", ["C"] = "c", ["D"] = "d", ["E"] = "e",
    ["F"] = "f", ["G"] = "g", ["H"] = "h", ["I"] = "i", ["J"] = "j",
    ["K"] = "k", ["L"] = "l", ["M"] = "m", ["N"] = "n", ["O"] = "o",
    ["P"] = "p", ["Q"] = "q", ["R"] = "r", ["S"] = "s", ["T"] = "t",
    ["U"] = "u", ["V"] = "v", ["W"] = "w", ["X"] = "x", ["Y"] = "y",
    ["Z"] = "z", ["Å"] = "å", ["Ä"] = "ä", ["Ö"] = "ö",
}

--~ sorters.test = ''
--~ sorters.test = 'nl'
--~ sorters.test = 'cz'

--~ if sorters.test == 'nl' then -- dutch test

--~     data = {
--~         { 'e', { {"ijsco",""} },2,"","","",""},
--~         { 'e', { {"ysco" ,""} },2,"","","",""},
--~         { 'e', { {"ijsco",""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"aap" ,""} },2,"","","",""},
--~         { 'e', { {"$a$"  ,""} },2,"","","",""},
--~         { 'e', { {"aap"  ,""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"aap" ,""} },6,"","","",""},
--~         { 'e', { {"hans" ,""}, {"noot",""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"mies",""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"mies",""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"mies",""}, [3] = {"oeps",""} },2,"","","",""},
--~         { 'e', { {"hans" ,""}, {"mies",""}, [3] = {"oeps",""} },4,"","","",""},
--~     }
--~     sorters.index.process({ entries = data, language = 'nl'})

--~ elseif sorters.test == 'cz' then -- czech test

--~     data = {
--~         { 'e', { {"blabla",""} },2,"","","",""},
--~         { 'e', { {"czacza",""} },2,"","","",""},
--~         { 'e', { {"albalb",""} },2,"","","",""},
--~         { 'e', { {"azcazc",""} },2,"","","",""},
--~         { 'e', { {"chacha",""} },2,"","","",""},
--~         { 'e', { {"hazzah",""} },2,"","","",""},
--~         { 'e', { {"iaccai",""} },2,"","","",""},
--~     }
--~     sorters.index.process({ entries = data, language = 'cz'})

--~ end


--~ print(table.serialize(sorters))
