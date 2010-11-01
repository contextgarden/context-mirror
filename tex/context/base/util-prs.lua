if not modules then modules = { } end modules ['util-prs'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities         = utilities or {}
utilities.parsers = utilities.parsers or { }
local parsers     = utilities.parsers
parsers.patterns  = parsers.patterns or { }

-- we could use a Cf Cg construct

local P, R, V, C, Ct, Carg = lpeg.P, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Carg
local lpegmatch = lpeg.match
local concat, format, gmatch = table.concat, string.format, string.gmatch
local tostring, type, next, setmetatable = tostring, type, next, setmetatable
local sortedhash = table.sortedhash

local escape, left, right = P("\\"), P('{'), P('}')

lpeg.patterns.balanced = P {
    [1] = ((escape * (left+right)) + (1 - (left+right)) + V(2))^0,
    [2] = left * V(1) * right
}

local space     = P(' ')
local equal     = P("=")
local comma     = P(",")
local lbrace    = P("{")
local rbrace    = P("}")
local nobrace   = 1 - (lbrace+rbrace)
local nested    = P { lbrace * (nobrace + V(1))^0 * rbrace }
local spaces    = space^0

local value     = P(lbrace * C((nobrace + nested)^0) * rbrace) + C((nested + (1-comma))^0)

local key       = C((1-equal-comma)^1)
local pattern_a = (space+comma)^0 * (key * equal * value + key * C(""))
local pattern_c = (space+comma)^0 * (key * equal * value)

local key       = C((1-space-equal-comma)^1)
local pattern_b = spaces * comma^0 * spaces * (key * ((spaces * equal * spaces * value) + C("")))

-- "a=1, b=2, c=3, d={a{b,c}d}, e=12345, f=xx{a{b,c}d}xx, g={}" : outer {} removes, leading spaces ignored

local hash = { }

local function set(key,value) -- using Carg is slower here
    hash[key] = value
end

local function set(key,value) -- using Carg is slower here
    hash[key] = value
end

local pattern_a_s = (pattern_a/set)^1
local pattern_b_s = (pattern_b/set)^1
local pattern_c_s = (pattern_c/set)^1

parsers.patterns.settings_to_hash_a = pattern_a_s
parsers.patterns.settings_to_hash_b = pattern_b_s
parsers.patterns.settings_to_hash_c = pattern_c_s

function parsers.make_settings_to_hash_pattern(set,how)
    if how == "strict" then
        return (pattern_c/set)^1
    elseif how == "tolerant" then
        return (pattern_b/set)^1
    else
        return (pattern_a/set)^1
    end
end

function parsers.settings_to_hash(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_a_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_tolerant(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_b_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_strict(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_c_s,str)
        return next(hash) and hash
    else
        return nil
    end
end

local separator = comma * space^0
local value     = P(lbrace * C((nobrace + nested)^0) * rbrace) + C((nested + (1-comma))^0)
local pattern   = Ct(value*(separator*value)^0)

-- "aap, {noot}, mies" : outer {} removes, leading spaces ignored

parsers.patterns.settings_to_array = pattern

-- we could use a weak table as cache

function parsers.settings_to_array(str)
    if not str or str == "" then
        return { }
    else
        return lpegmatch(pattern,str)
    end
end

local function set(t,v)
    t[#t+1] = v
end

local value   = P(Carg(1)*value) / set
local pattern = value*(separator*value)^0 * Carg(1)

function parsers.add_settings_to_array(t,str)
    return lpegmatch(pattern,str,nil,t)
end

function parsers.hash_to_string(h,separator,yes,no,strict,omit)
    if h then
        local t, tn, s = { }, 0, table.sortedkeys(h)
        omit = omit and table.tohash(omit)
        for i=1,#s do
            local key = s[i]
            if not omit or not omit[key] then
                local value = h[key]
                if type(value) == "boolean" then
                    if yes and no then
                        if value then
                            tn = tn + 1
                            t[tn] = key .. '=' .. yes
                        elseif not strict then
                            tn = tn + 1
                            t[tn] = key .. '=' .. no
                        end
                    elseif value or not strict then
                        tn = tn + 1
                        t[tn] = key .. '=' .. tostring(value)
                    end
                else
                    tn = tn + 1
                    t[tn] = key .. '=' .. value
                end
            end
        end
        return concat(t,separator or ",")
    else
        return ""
    end
end

function parsers.array_to_string(a,separator)
    if a then
        return concat(a,separator or ",")
    else
        return ""
    end
end

function parsers.settings_to_set(str,t) -- tohash? -- todo: lpeg -- duplicate anyway
    t = t or { }
    for s in gmatch(str,"%s*([^, ]+)") do -- space added
        t[s] = true
    end
    return t
end

function parsers.simple_hash_to_string(h, separator)
    local t, tn = { }, 0
    for k, v in sortedhash(h) do
        if v then
            tn = tn + 1
            t[tn] = k
        end
    end
    return concat(t,separator or ",")
end

local value   = lbrace * C((nobrace + nested)^0) * rbrace
local pattern = Ct((space + value)^0)

function parsers.arguments_to_table(str)
    return lpegmatch(pattern,str)
end

-- temporary here (unoptimized)

function parsers.getparameters(self,class,parentclass,settings)
    local sc = self[class]
    if not sc then
        sc = { }
        self[class] = sc
        if parentclass then
            local sp = self[parentclass]
            if not sp then
                sp = { }
                self[parentclass] = sp
            end
            setmetatable(sc, { __index = sp })
        end
    end
    parsers.settings_to_hash(settings,sc)
end
