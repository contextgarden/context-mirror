-- filename : l-unicode.lua
-- comment  : split off from luat-inp
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-unicode'] = 1.001
if not unicode  then unicode  = { } end

if not garbagecollector then
    garbagecollector = {
        push = function() collectgarbage("stop")    end,
        pop  = function() collectgarbage("restart") end,
    }
end

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

function unicode.utftype(f) -- \000 fails !
    local str = f:read(4)
    if not str then
        f:seek('set')
        return 0
    elseif str:find("^%z%z\254\255") then
        return 4
    elseif str:find("^\255\254%z%z") then
        return 3
    elseif str:find("^\254\255") then
        f:seek('set',2)
        return 2
    elseif str:find("^\255\254") then
        f:seek('set',2)
        return 1
    elseif str:find("^\239\187\191") then
        f:seek('set',3)
        return 0
    else
        f:seek('set')
        return 0
    end
end

function unicode.utf16_to_utf8(str, endian) -- maybe a gsub is faster or an lpeg
--~     garbagecollector.push()
    local result = { }
    local tc, uc = table.concat, unicode.utf8.char
    local tmp, n, m, p = { }, 0, 0, 0
    -- lf | cr | crlf / (cr:13, lf:10)
    local function doit()
        if n == 10 then
            if p ~= 13 then
                result[#result+1] = tc(tmp,"")
                tmp = { }
                p = 0
            end
        elseif n == 13 then
            result[#result+1] = tc(tmp,"")
            tmp = { }
            p = n
        else
            tmp[#tmp+1] = uc(n)
            p = 0
        end
    end
    for l,r in str:bytepairs() do
        if r then
            if endian then
                n = l*256 + r
            else
                n = r*256 + l
            end
            if m > 0 then
                n = (m-0xD800)*0x400 + (n-0xDC00) + 0x10000
                m = 0
                doit()
            elseif n >= 0xD800 and n <= 0xDBFF then
                m = n
            else
                doit()
            end
        end
    end
    if #tmp > 0 then
        result[#result+1] = tc(tmp,"")
    end
--~     garbagecollector.pop()
    return result
end

function unicode.utf32_to_utf8(str, endian)
--~     garbagecollector.push()
    local result = { }
    local tc, uc = table.concat, unicode.utf8.char
    local tmp, n, m, p = { }, 0, -1, 0
    -- lf | cr | crlf / (cr:13, lf:10)
    local function doit()
        if n == 10 then
            if p ~= 13 then
                result[#result+1] = tc(tmp,"")
                tmp = { }
                p = 0
            end
        elseif n == 13 then
            result[#result+1] = tc(tmp,"")
            tmp = { }
            p = n
        else
            tmp[#tmp+1] = uc(n)
            p = 0
        end
    end
    for a,b in str:bytepairs() do
        if a and b then
            if m < 0 then
                if endian then
                    m = a*256*256*256 + b*256*256
                else
                    m = b*256 + a
                end
            else
                if endian then
                    n = m + a*256 + b
                else
                    n = m + b*256*256*256 + a*256*256
                end
                m = -1
                doit()
            end
        else
            break
        end
    end
    if #tmp > 0 then
        result[#result+1] = tc(tmp,"")
    end
--~     garbagecollector.pop()
    return result
end

function unicode.utf8_to_utf16(str,littleendian)
    if littleendian then
        return char(255,254) .. utf.gsub(str,".",function(c)
            local b = byte(c)
            if b < 0x10000 then
                return char(b%256,b/256)
            else
                b = b - 0x10000
                local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
                return char(b1%256,b1/256,b2%256,b2/256)
            end
        end)
    else
        return char(254,255) .. utf.gsub(str,".",function(c)
            local b = byte(c)
            if b < 0x10000 then
                return char(b/256,b%256)
            else
                b = b - 0x10000
                local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
                return char(b1/256,b1%256,b2/256,b2%256)
            end
        end)
    end
end
