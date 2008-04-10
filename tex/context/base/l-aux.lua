-- filename : l-aux.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-aux'] = 1.001
if not aux      then aux      = { } end

do

    local hash = { }

    local function set(key,value) -- using Carg is slower here
        hash[key] = value
    end

    local space     = lpeg.P(' ')
    local equal     = lpeg.P("=")
    local comma     = lpeg.P(",")
    local lbrace    = lpeg.P("{")
    local rbrace    = lpeg.P("}")
    local nobrace   = 1 - (lbrace+rbrace)
    local nested    = lpeg.P{ lbrace * (nobrace + lpeg.V(1))^0 * rbrace }

    local key       = lpeg.C((1-equal)^1)
    local value     = lpeg.P(lbrace * lpeg.C((nobrace + nested)^0) * rbrace) + lpeg.C((nested + (1-comma))^0)
    local pattern   = ((space^0 * key * equal * value * comma^0) / set)^1

    -- "a=1, b=2, c=3, d={a{b,c}d}, e=12345, f=xx{a{b,c}d}xx, g={}" : outer {} removes, leading spaces ignored

    function aux.settings_to_hash(str)
        if str and str ~= "" then
            hash = { }
            pattern:match(str)
            return hash
        else
            return { }
        end
    end

    local seperator = comma * space^0
    local value     = lpeg.P(lbrace * lpeg.C((nobrace + nested)^0) * rbrace) + lpeg.C((nested + (1-comma))^0)
    local pattern   = lpeg.Ct(value*(seperator*value)^0)

    -- "aap, {noot}, mies" : outer {} removes, leading spaces ignored

    function aux.settings_to_array(str)
        return pattern:match(str)
    end

    local function set(t,v)
        t[#t+1] = v
    end

    local value   = lpeg.P(lpeg.Carg(1)*value) / set
    local pattern = value*(seperator*value)^0 * lpeg.Carg(1)

    function aux.add_settings_to_array(t,str)
        return pattern:match(str, nil, t)
    end

end

function aux.hash_to_string(h,separator,yes,no,strict,omit)
    if h then
        local t, s = { }, table.sortedkeys(h)
        omit = omit and table.tohash(omit)
        for i=1,#s do
            local key = s[i]
            if not omit or not omit[key] then
                local value = h[key]
                if type(value) == "boolean" then
                    if yes and no then
                        if value then
                            t[#t+1] = key .. '=' .. yes
                        elseif not strict then
                            t[#t+1] = key .. '=' .. no
                        end
                    elseif value or not strict then
                        t[#t+1] = key .. '=' .. tostring(value)
                    end
                else
                    t[#t+1] = key .. '=' .. value
                end
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

-- temporary here

function aux.getparameters(self,class,parentclass,settings)
    local sc = self[class]
    if not sc then
        sc = table.clone(self[parent])
        self[class] = sc
    end
    aux.add_settings_to_array(sc, settings)
end
