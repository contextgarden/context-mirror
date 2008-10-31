-- filename : l-aux.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-aux'] = 1.001
if not aux      then aux      = { } end

local concat, format = table.concat, string.format
local tostring, type = tostring, type

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

    local key       = lpeg.C((1-equal-comma)^1)
    local value     = lpeg.P(lbrace * lpeg.C((nobrace + nested)^0) * rbrace) + lpeg.C((nested + (1-comma))^0)
--  local pattern   = (((space+comma)^0 * (key * equal * value + key) * comma^0) / set)^1
    local pattern   = (((space+comma)^0 * (key * equal * value + key * lpeg.C(""))) / set)^1

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
        return concat(t,separator or ",")
    else
        return ""
    end
end

function aux.array_to_string(a,separator)
    if a then
        return concat(a,separator or ",")
    else
        return ""
    end
end

function aux.settings_to_set(str)
    local t = { }
    for s in str:gmatch("%s*([^,]+)") do
        t[s] = true
    end
    return t
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

-- temporary here

local digit    = lpeg.R("09")
local period   = lpeg.P(".")
local zero     = lpeg.P("0")

--~ local finish   = lpeg.P(-1)
--~ local nodigit  = (1-digit) + finish
--~ local case_1   = (period * zero^1 * #nodigit)/"" -- .000
--~ local case_2   = (period * (1-(zero^0/"") * #nodigit)^1 * (zero^0/"") * nodigit) -- .010 .10 .100100

local trailingzeros = zero^0 * -digit -- suggested by Roberto R
local case_1 = period * trailingzeros / ""
local case_2 = period * (digit - trailingzeros)^1 * (trailingzeros / "")

local number   = digit^1 * (case_1 + case_2)
local stripper = lpeg.Cs((number + 1)^0)

--~ local sample = "bla 11.00 bla 11 bla 0.1100 bla 1.00100 bla 0.00 bla 0.001 bla 1.1100 bla 0.100100100 bla 0.00100100100"
--~ collectgarbage("collect")
--~ str = string.rep(sample,10000)
--~ local ts = os.clock()
--~ stripper:match(str)
--~ print(#str, os.clock()-ts, stripper:match(sample))

function aux.strip_zeros(str)
    return stripper:match(str)
end

function aux.definetable(target) -- defines undefined tables
    local composed, t = nil, { }
    for name in target:gmatch("([^%.]+)") do
        if composed then
            composed = composed .. "." .. name
        else
            composed = name
        end
        t[#t+1] = format("%s = %s or { }",composed,composed)
    end
    return concat(t,"\n")
end

function aux.accesstable(target)
    local t = _G
    for name in target:gmatch("([^%.]+)") do
        t = t[name]
    end
    return t
end
