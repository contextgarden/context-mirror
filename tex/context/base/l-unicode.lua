if not modules then modules = { } end modules ['l-unicode'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not unicode then

    unicode = { utf8 = { } }

    local floor, char = math.floor, string.char

    function unicode.utf8.utfchar(n)
        if n < 0x80 then
            return char(n)
        elseif n < 0x800 then
            return char(
                0xC0 + floor(n/0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x10000 then
            return char(
                0xE0 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x40000 then
            return char(
                0xF0 + floor(n/0x40000),
                0x80 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        else
         -- return char(
         --     0xF1 + floor(n/0x1000000),
         --     0x80 + floor(n/0x40000),
         --     0x80 + floor(n/0x1000),
         --     0x80 + (floor(n/0x40) % 0x40),
         --     0x80 + (n % 0x40)
         -- )
            return "?"
        end
    end

end

local unicode = unicode

utf = utf or unicode.utf8

local concat = table.concat
local utfchar, utfbyte, utfgsub = utf.char, utf.byte, utf.gsub
local char, byte, find, bytepairs, utfvalues, format = string.char, string.byte, string.find, string.bytepairs, string.utfvalues, string.format
local type = type

local utfsplitlines = string.utfsplitlines

-- 0  EF BB BF      UTF-8
-- 1  FF FE         UTF-16-little-endian
-- 2  FE FF         UTF-16-big-endian
-- 3  FF FE 00 00   UTF-32-little-endian
-- 4  00 00 FE FF   UTF-32-big-endian

unicode.utfname = {
    [0] = 'utf-8',
    [1] = 'utf-16-le',
    [2] = 'utf-16-be',
    [3] = 'utf-32-le',
    [4] = 'utf-32-be'
}

-- \000 fails in <= 5.0 but is valid in >=5.1 where %z is depricated

function unicode.utftype(f)
    local str = f:read(4)
    if not str then
        f:seek('set')
        return 0
 -- elseif find(str,"^%z%z\254\255") then            -- depricated
 -- elseif find(str,"^\000\000\254\255") then        -- not permitted and bugged
    elseif find(str,"\000\000\254\255",1,true) then  -- seems to work okay (TH)
        return 4
 -- elseif find(str,"^\255\254%z%z") then            -- depricated
 -- elseif find(str,"^\255\254\000\000") then        -- not permitted and bugged
    elseif find(str,"\255\254\000\000",1,true) then  -- seems to work okay (TH)
        return 3
    elseif find(str,"^\254\255") then
        f:seek('set',2)
        return 2
    elseif find(str,"^\255\254") then
        f:seek('set',2)
        return 1
    elseif find(str,"^\239\187\191") then
        f:seek('set',3)
        return 0
    else
        f:seek('set')
        return 0
    end
end

--~ function unicode.utf16_to_utf8(str, endian) -- maybe a gsub is faster or an lpeg
--~     local result, tmp, n, m, p, r, t = { }, { }, 0, 0, 0, 0, 0 -- we reuse tmp
--~     -- lf | cr | crlf / (cr:13, lf:10)
--~     local function doit() -- inline this
--~         if n == 10 then
--~             if p ~= 13 then
--~                 if t > 0 then
--~                     r = r + 1
--~                     result[r] = concat(tmp,"",1,t)
--~                     t = 0
--~                 end
--~                 p = 0
--~             end
--~         elseif n == 13 then
--~             if t > 0 then
--~                 r = r + 1
--~                 result[r] = concat(tmp,"",1,t)
--~                 t = 0
--~             end
--~             p = n
--~         else
--~             t = t + 1
--~             tmp[t] = utfchar(n)
--~             p = 0
--~         end
--~     end
--~     for l,r in bytepairs(str) do
--~         if r then
--~             if endian then -- maybe make two loops
--~                 n = 256*l + r
--~             else
--~                 n = 256*r + l
--~             end
--~             if m > 0 then
--~                 n = (m-0xD800)*0x400 + (n-0xDC00) + 0x10000
--~                 m = 0
--~                 doit()
--~             elseif n >= 0xD800 and n <= 0xDBFF then
--~                 m = n
--~             else
--~                 doit()
--~             end
--~         end
--~     end
--~     if t > 0 then
--~         r = r + 1
--~         result[r] = concat(tmp,"",1,t) -- we reused tmp, hence t
--~     end
--~     return result
--~ end

--~ function unicode.utf32_to_utf8(str, endian)
--~     local result, tmp, n, m, p, r, t = { }, { }, 0, -1, 0, 0, 0
--~     -- lf | cr | crlf / (cr:13, lf:10)
--~     local function doit() -- inline this
--~         if n == 10 then
--~             if p ~= 13 then
--~                 if t > 0 then
--~                     r = r + 1
--~                     result[r] = concat(tmp,"",1,t)
--~                     t = 0
--~                 end
--~                 p = 0
--~             end
--~         elseif n == 13 then
--~             if t > 0 then
--~                 r = r + 1
--~                 result[r] = concat(tmp,"",1,t)
--~                 t = 0
--~             end
--~             p = n
--~         else
--~             t = t + 1
--~             tmp[t] = utfchar(n)
--~             p = 0
--~         end
--~     end
--~     for a,b in bytepairs(str) do
--~         if a and b then
--~             if m < 0 then
--~                 if endian then -- maybe make two loops
--~                     m = 256*256*256*a + 256*256*b
--~                 else
--~                     m = 256*b + a
--~                 end
--~             else
--~                 if endian then -- maybe make two loops
--~                     n = m + 256*a + b
--~                 else
--~                     n = m + 256*256*256*b + 256*256*a
--~                 end
--~                 m = -1
--~                 doit()
--~             end
--~         else
--~             break
--~         end
--~     end
--~     if #tmp > 0 then
--~         r = r + 1
--~         result[r] = concat(tmp,"",1,t) -- we reused tmp, hence t
--~     end
--~     return result
--~ end

local function utf16_to_utf8_be(t)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, 0
        for left, right in bytepairs(t[i]) do
            if right then
                local now = 256*left + right
                if more > 0 then
                    now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000
                    more = 0
                    r = r + 1
                    result[r] = utfchar(now)
                elseif now >= 0xD800 and now <= 0xDBFF then
                    more = now
                else
                    r = r + 1
                    result[r] = utfchar(now)
                end
            end
        end
        t[i] = concat(result,"",1,r) -- we reused tmp, hence t
    end
    return t
end

local function utf16_to_utf8_le(t)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, 0
        for left, right in bytepairs(t[i]) do
            if right then
                local now = 256*right + left
                if more > 0 then
                    now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000
                    more = 0
                    r = r + 1
                    result[r] = utfchar(now)
                elseif now >= 0xD800 and now <= 0xDBFF then
                    more = now
                else
                    r = r + 1
                    result[r] = utfchar(now)
                end
            end
        end
        t[i] = concat(result,"",1,r) -- we reused tmp, hence t
    end
    return t
end

local function utf32_to_utf8_be(str)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, -1
        for a,b in bytepairs(str) do
            if a and b then
                if more < 0 then
                    more = 256*256*256*a + 256*256*b
                else
                    r = r + 1
                    result[t] = utfchar(more + 256*a + b)
                    more = -1
                end
            else
                break
            end
        end
        t[i] = concat(result,"",1,r)
    end
    return result
end

local function utf32_to_utf8_le(str)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, -1
        for a,b in bytepairs(str) do
            if a and b then
                if more < 0 then
                    more = 256*b + a
                else
                    r = r + 1
                    result[t] = utfchar(more + 256*256*256*b + 256*256*a)
                    more = -1
                end
            else
                break
            end
        end
        t[i] = concat(result,"",1,r)
    end
    return result
end

unicode.utf32_to_utf8_be = utf32_to_utf8_be
unicode.utf32_to_utf8_le = utf32_to_utf8_le
unicode.utf16_to_utf8_be = utf16_to_utf8_be
unicode.utf16_to_utf8_le = utf16_to_utf8_le

function unicode.utf8_to_utf8(t)
    return type(t) == "string" and utfsplitlines(t) or t
end

function unicode.utf16_to_utf8(t,endian)
    return endian and utf16_to_utf8_be(t) or utf16_to_utf8_le(t) or t
end

function unicode.utf32_to_utf8(t,endian)
    return endian and utf32_to_utf8_be(t) or utf32_to_utf8_le(t) or t
end

local function little(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b%256,b/256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1%256,b1/256,b2%256,b2/256)
    end
end

local function big(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b/256,b%256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1/256,b1%256,b2/256,b2%256)
    end
end

function unicode.utf8_to_utf16(str,littleendian)
    if littleendian then
        return char(255,254) .. utfgsub(str,".",little)
    else
        return char(254,255) .. utfgsub(str,".",big)
    end
end

function unicode.utfcodes(str)
    local t, n = { }, 0
    for u in utfvalues(str) do
        n = n + 1
        t[n] = format("0x%04X",u)
    end
    return concat(t,separator or " ")
end

function unicode.ustring(s)
    return format("U+%05X",type(s) == "number" and s or utfbyte(s))
end

function unicode.xstring(s)
    return format("0x%05X",type(s) == "number" and s or utfbyte(s))
end

--~ print(unicode.utfcodes(str))

local lpegmatch = lpeg.match
local utftype = lpeg.patterns.utftype

function unicode.filetype(data)
    return data and lpegmatch(utftype,data) or "unknown"
end

--~ local utfchr = { } -- 60K -> 2.638 M extra mem but currently not called that often (on latin)
--~
--~ setmetatable(utfchr, { __index = function(t,k) local v = utfchar(k) t[k] = v return v end } )
--~
--~ collectgarbage("collect")
--~ local u = collectgarbage("count")*1024
--~ local t = os.clock()
--~ for i=1,1000 do
--~     for i=1,600 do
--~         local a = utfchr[i]
--~     end
--~ end
--~ print(os.clock()-t,collectgarbage("count")*1024-u)

--~ collectgarbage("collect")
--~ local t = os.clock()
--~ for i=1,1000 do
--~     for i=1,600 do
--~         local a = utfchar(i)
--~     end
--~ end
--~ print(os.clock()-t,collectgarbage("count")*1024-u)
