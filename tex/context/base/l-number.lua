if not modules then modules = { } end modules ['l-number'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring = tostring
local format, floor, insert, match = string.format, math.floor, string.match
local concat, insert = table.concat, table.insert
local lpegmatch = lpeg.match

number       = number or { }
local number = number

-- a,b,c,d,e,f = number.toset(100101)

function number.toset(n)
    return match(tostring(n),"(.?)(.?)(.?)(.?)(.?)(.?)(.?)(.?)")
end

function number.toevenhex(n)
    local s = format("%X",n)
    if #s % 2 == 0 then
        return s
    else
        return "0" .. s
    end
end

-- the lpeg way is slower on 8 digits, but faster on 4 digits, some 7.5%
-- on
--
-- for i=1,1000000 do
--     local a,b,c,d,e,f,g,h = number.toset(12345678)
--     local a,b,c,d         = number.toset(1234)
--     local a,b,c           = number.toset(123)
-- end
--
-- of course dedicated "(.)(.)(.)(.)" matches are even faster

local one = lpeg.C(1-lpeg.S(''))^1

function number.toset(n)
    return lpegmatch(one,tostring(n))
end

function number.bits(n,zero)
    local t, i = { }, (zero and 0) or 1
    while n > 0 do
        local m = n % 2
        if m > 0 then
            insert(t,1,i)
        end
        n = floor(n/2)
        i = i + 1
    end
    return t
end

--~ http://ricilake.blogspot.com/2007/10/iterating-bits-in-lua.html

function number.bit(p)
    return 2 ^ (p - 1) -- 1-based indexing
end

function number.hasbit(x, p) -- typical call: if hasbit(x, bit(3)) then ...
    return x % (p + p) >= p
end

function number.setbit(x, p)
    return hasbit(x, p) and x or x + p
end

function number.clearbit(x, p)
    return hasbit(x, p) and x - p or x
end

function number.tobitstring(n)
    if n == 0 then
        return "0"
    else
        local t = { }
        while n > 0 do
            insert(t,1,n % 2 > 0 and 1 or 0)
            n = floor(n/2)
        end
        return concat(t)
    end
end
