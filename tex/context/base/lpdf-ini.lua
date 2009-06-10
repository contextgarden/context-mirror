if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable, getmetatable, type, next, tostring = setmetatable, getmetatable, type, next, tostring
local char, byte, format, gsub = string.char, string.byte, string.format, string.gsub
local concat = table.concat
local utfvalues = string.utfvalues

lpdf = lpdf or { }

local function tosixteen(str)
    if not str or str == "" then
        return "()"
    else
        local r = { "<feff" }
        for b in utfvalues(str) do
            if b < 0x10000 then
                r[#r+1] = format("%04x",b)
            else
                r[#r+1] = format("%04x%04x",b/1024+0xD800,b%1024+0xDC00)
            end
        end
        r[#r+1] = ">"
        return concat(r)
    end
end

local function merge_t(a,b)
    local t = { }
    for k,v in next, a do t[k] = v end
    for k,v in next, b do t[k] = v end
    return setmetatable(t,getmetatable(a))
end

local tostring_a, tostring_d, tosting_n, tostring_s, tostring_c

tostring_d = function(t)
    if not next(t) then
        return "<< >>"
    else
        local r = { "<<" }
        for k, v in next, t do
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = format("/%s %s",k,tosixteen(v))
            elseif tv == "table" then
                local mv = getmetatable(v)
                if mv and mv.__lpdftype then
                    r[#r+1] = format("/%s %s",k,tostring(v))
                elseif v[1] then
                    r[#r+1] = format("/%s %s",k,tostring_a(v))
                else
                    r[#r+1] = format("/%s %s",k,tostring_d(v))
                end
            else
                r[#r+1] = format("/%s %s",k,tostring(v))
            end
        end
        r[#r+1] = ">>"
        return concat(r, " ")
    end
end

tostring_a = function(t)
    if #t == 0 then
        return "[ ]"
    else
        local r = { "[" }
        for k, v in next, t do
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = tosixteen(v)
            elseif tv == "table" then
                local mv = getmetatable(v)
                if mv and mv.__lpdftype then
                    r[#r+1] = tostring(v)
                elseif v[1] then
                    r[#r+1] = tostring_a(v)
                else
                    r[#r+1] = tostring_d(v)
                end
            else
                r[#r+1] = tostring(v)
            end
        end
        r[#r+1] = "]"
        return concat(r, " ")
    end
end

tostring_n = function(t)
    return tostring(t[1]) -- tostring not needed
end

tostring_s = function(t)
    return tosixteen(t[1])
end

tostring_c = function(t)
    return t[1]
end

local mt_d = { __lpdftype = "dictionary", __tostring = tostring_d }
local mt_a = { __lpdftype = "array",      __tostring = tostring_a }
local mt_s = { __lpdftype = "string",     __tostring = tostring_s }
local mt_n = { __lpdftype = "number",     __tostring = tostring_n }
local mt_c = { __lpdftype = "constant",   __tostring = tostring_c }

local mt_z = { __lpdftype = "null",       __tostring = function(s) return "null"  end }
local mt_t = { __lpdftype = "true",       __tostring = function(s) return "true"  end }
local mt_f = { __lpdftype = "false",      __tostring = function(s) return "false" end }

function lpdf.dictionary(t)
    return setmetatable(t or { },mt_d)
end

function lpdf.array(t)
    return setmetatable(t or { },mt_a)
end

local cache = { } -- can be weak

function lpdf.string(str,default)
    str = str or default or ""
    local c = cache[str]
    if not c then
        c = setmetatable({ str },mt_s)
        cache[str] = c
    end
    return c
end

local cache = { } -- can be weak

function lpdf.number(n,default) -- 0-10
    n = n or default
    local c = cache[n]
    if not c then
        c = setmetatable({ n },mt_n)
    --  cache[n] = c -- too many numbers
    end
    return c
end

for i=-1,9 do cache[i] = lpdf.number(i) end

local cache = { } -- can be weak

function lpdf.constant(str,default)
    str = str or default or ""
    local c = cache[str]
    if not c then
        c = setmetatable({ "/" .. str },mt_c)
        cache[str] = c
    end
    return c
end

local p_null  = { } setmetatable(p_null, mt_z)
local p_true  = { } setmetatable(p_true, mt_t)
local p_false = { } setmetatable(p_false,mt_f)

function lpdf.null () return p_null  end

function lpdf.boolean(b,default)
    if (type(b) == boolean and b) or default then
        return p_true
    else
        return p_false
    end
end

--~ local d = lpdf.dictionary()
--~ local e = lpdf.dictionary { ["e"] = "abc" }
--~ local f = lpdf.dictionary { ["f"] = "ABC" }
--~ local a = lpdf.array()

--~ d["test"] = lpdf.string ("test")
--~ d["more"] = "more"
--~ d["bool"] = true
--~ d["numb"] = 1234
--~ d["oeps"] = lpdf.dictionary { ["hans"] = "ton" }
--~ d["whow"] = lpdf.array { lpdf.string("ton") }

--~ a[#a+1] = lpdf.string("xxx")
--~ a[#a+1] = lpdf.string("yyy")

--~ d.what = a

--~ print(d)

--~ local d = lpdf.dictionary()
--~ d["abcd"] = { 1, 2, 3, "test" }
--~ print(d)

--~ local d = lpdf.array()
--~ d[#d+1] = { 1, 2, 3, "test" }
--~ print(d)

--~ local d = lpdf.array()
--~ d[#d+1] = { a=1, b=2, c=3, d="test" }
--~ print(d)
