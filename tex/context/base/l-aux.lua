-- filename : l-aux.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-aux'] = 1.001
if not aux      then aux      = { } end

do

    hash = { }

    function set(key,value)
        hash[key] = value
    end

    local space    = lpeg.S(' ')^0
    local equal    = lpeg.S("=")^1
    local comma    = lpeg.S(",")^0
    local nonspace = lpeg.P(1-lpeg.S(' '))^1
    local nonequal = lpeg.P(1-lpeg.S('='))^1
    local noncomma = lpeg.P(1-lpeg.S(','))^1
    local nonbrace = lpeg.P(1-lpeg.S('{}'))^1
    local nested   = lpeg.S('{') * lpeg.C(nonbrace^1) * lpeg.S('}')

    local key   = lpeg.C(nonequal)
    local value = nested + lpeg.C(noncomma)

    local pattern = ((space * key * equal * value * comma) / set)^1

    function aux.settings_to_hash(str)
        hash = { }
        lpeg.match(pattern,str)
        return hash
    end

end

--~ print(table.serialize(aux.settings_to_hash("aaa=bbb, ccc={d,d,d}")))
