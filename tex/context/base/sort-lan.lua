-- filename : sort-lan.lua
-- comment  : companion to sort-lan.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['sort-lan'] = 1.001

-- this is a rather preliminary and incomplete file
-- maybe we should load this kind of stuff runtime

-- english

do
    -- The next one can be more efficient when not indexed this way, but
    -- other languages are sparse so for the moment we keep this one.

    sorters.entries['en'] = {
        [ 1] = "a", [ 3] = "b", [ 5] = "c", [ 7] = "d", [ 9] = "e",
        [11] = "f", [13] = "g", [15] = "h", [17] = "i", [19] = "j",
        [21] = "k", [23] = "l", [25] = "m", [27] = "n", [29] = "o",
        [31] = "p", [33] = "q", [35] = "r", [37] = "s", [39] = "t",
        [41] = "u", [43] = "v", [45] = "w", [47] = "x", [49] = "y",
        [51] = "z",
        [ 2] =   1, [ 4] =   3, [ 6] =   5, [ 8] =   7, [10] =   9,
        [12] =  11, [14] =  13, [16] =  15, [18] =  17, [20] =  19,
        [22] =  21, [24] =  23, [26] =  25, [28] =  27, [30] =  29,
        [32] =  31, [34] =  33, [36] =  35, [38] =  37, [40] =  39,
        [42] =  41, [44] =  43, [46] =  45, [48] =  47, [50] =  49,
        [52] =  51,
    }
    sorters.mappings['en'] = {
        ["a"] =  1, ["b"] =  3, ["c"] =  5, ["d"] =  7, ["e"] =  9,
        ["f"] = 11, ["g"] = 13, ["h"] = 15, ["i"] = 17, ["j"] = 19,
        ["k"] = 21, ["l"] = 23, ["m"] = 25, ["n"] = 27, ["o"] = 29,
        ["p"] = 31, ["q"] = 33, ["r"] = 35, ["s"] = 37, ["t"] = 39,
        ["u"] = 41, ["v"] = 43, ["w"] = 45, ["x"] = 47, ["y"] = 49,
        ["z"] = 51,
        ["A"] =  2, ["B"] =  4, ["C"] =  6, ["D"] =  8, ["E"] = 10,
        ["F"] = 12, ["G"] = 14, ["H"] = 16, ["I"] = 18, ["J"] = 20,
        ["K"] = 22, ["L"] = 24, ["M"] = 26, ["N"] = 28, ["O"] = 30,
        ["P"] = 32, ["Q"] = 34, ["R"] = 36, ["S"] = 38, ["T"] = 40,
        ["U"] = 42, ["V"] = 44, ["W"] = 46, ["X"] = 48, ["Y"] = 50,
        ["Z"] = 52,
    }
end

-- dutch

do
    sorters.replacements['nl'] = { { "ij", 'y' }, { "IJ", 'Y' } }
    sorters.entries     ['nl'] = sorters.entries ['en']
    sorters.mappings    ['nl'] = sorters.mappings['en']
end

-- czech

do

    local uc = unicode.utf8.char
    local ub = unicode.utf8.byte

    sorters.replacements['cz'] = {
        [1] = { "ch", uc(0xFF01) }
    }

    sorters.entries['cz'] = {
        [ 1] = "a",
        [ 2] = 1,
        [ 3] = "b",
        [ 4] = "c",
        [ 5] = uc(0x010D), -- ccaron
        [ 6] = "d",
        [ 7] = uc(0x010F), -- dcaron
        [ 8] = "e",
        [ 9] = 8,
        [10] = 8,
        [11] = "f",
        [12] = "g",
        [13] = "h",
        [14] = "ch",
        [15] = "i",
        [16] = 15,
        [17] = "j",
        [18] = "k",
        [19] = "l",
        [20] = "m",
        [21] = "n",
        [22] = uc(0x0147), -- ncaron
        [23] = "o",
        [24] = "p",
        [25] = "q",
        [26] = "r",
        [27] = uc(0x0147), -- rcaron
        [28] = "s",
        [29] = uc(0x0161), -- scaron
        [30] = "t",
        [31] = uc(0x0165), -- tcaron
        [32] = "u",
        [33] = 32,
        [34] = 32,
        [35] = "v",
        [36] = "w",
        [37] = "x",
        [38] = "y",
        [49] = "z",
        [40] = uc(0x017E), -- zcaron
    }

    sorters.mappings['cz'] = {
        ['a']        =  1, -- a
        [uc(0x00E1)] =  2, -- aacute
        ['b']        =  3, -- b
        ['c']        =  4, -- c
        [uc(0x010D)] =  5, -- ccaron
        ['d']        =  6, -- d
        [uc(0x010F)] =  7, -- dcaron
        ['e']        =  8, -- e
        [uc(0x00E9)] =  9, -- eacute
        [uc(0x011B)] = 10, -- ecaron
        ['f']        = 11, -- f
        ['g']        = 12, -- g
        ['h']        = 13, -- h
        [uc(0xFF01)] = 14, -- ch
        ['i']        = 15, -- i
        [uc(0x00ED)] = 16, -- iacute
        ['j']        = 17, -- j
        ['k']        = 18, -- k
        ['l']        = 19, -- l
        ['m']        = 20, -- m
        ['n']        = 21, -- n
        [uc(0x0147)] = 22, -- ncaron
        ['o']        = 23, -- o
        ['p']        = 24, -- p
        ['q']        = 25, -- q
        ['s']        = 26, -- r
        [uc(0x0147)] = 27, -- rcaron
        ['s']        = 28, -- s
        [uc(0x0161)] = 29, -- scaron
        ['t']        = 30, -- t
        [uc(0x0165)] = 31, -- tcaron
        ['u']        = 32, -- u
        [uc(0x00FA)] = 33, -- uacute
        [uc(0x01F6)] = 34, -- uring
        ['v']        = 35, -- v
        ['w']        = 36, -- w
        ['x']        = 37, -- x
        ['y']        = 38, -- y
        ['z']        = 49, -- z
        [uc(0x017E)] = 40, -- zcaron
    }

end

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
