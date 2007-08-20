-- filename : l-aux.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-aux'] = 1.001
if not aux      then aux      = { } end

do

    hash = { }

    local function set(key,value)
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

    local pattern = lpeg.Ct((space * value * comma)^1)

    function aux.settings_to_array(str)
        return lpeg.match(pattern,str)
    end

end

--~ do
--~     str = "a=1, b=2, c=3, d={abc}"

--~     for k,v in pairs(aux.settings_to_hash (str)) do print(k,v) end
--~     for k,v in pairs(aux.settings_to_array(str)) do print(k,v) end
--~ end

function aux.hash_to_string(h,separator,yes,no,strict)
    if h then
        local t = { }
        for _,k in ipairs(table.sortedkeys(h)) do
            local v = h[k]
            if type(v) == "boolean" then
                if yes and no then
                    if v then
                        t[#t+1] = k .. '=' .. yes
                    elseif not strict then
                        t[#t+1] = k .. '=' .. no
                    end
                elseif v or not strict then
                    t[#t+1] = k .. '=' .. tostring(v)
                end
            else
                t[#t+1] = k .. '=' .. v
            end
        end
        return table.concat(t,separator or ",")
    else
        return ""
    end
end

function aux.array_to_string(a,separator)
    if a then
        return table.concat(a,separator or ",")
    else
        return ""
    end
end
