if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

lpeg = require("lpeg")

local P, R, S, Ct, C, Cs, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc
local match = lpeg.match

--~ l-lpeg.lua :

--~ lpeg.digit         = lpeg.R('09')^1
--~ lpeg.sign          = lpeg.S('+-')^1
--~ lpeg.cardinal      = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.integer       = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.float         = lpeg.P(lpeg.sign^0 * lpeg.digit^0 * lpeg.P('.') * lpeg.digit^1)
--~ lpeg.number        = lpeg.float + lpeg.integer
--~ lpeg.oct           = lpeg.P("0") * lpeg.R('07')^1
--~ lpeg.hex           = lpeg.P("0x") * (lpeg.R('09') + lpeg.R('AF'))^1
--~ lpeg.uppercase     = lpeg.P("AZ")
--~ lpeg.lowercase     = lpeg.P("az")

--~ lpeg.eol           = lpeg.S('\r\n\f')^1 -- includes formfeed
--~ lpeg.space         = lpeg.S(' ')^1
--~ lpeg.nonspace      = lpeg.P(1-lpeg.space)^1
--~ lpeg.whitespace    = lpeg.S(' \r\n\f\t')^1
--~ lpeg.nonwhitespace = lpeg.P(1-lpeg.whitespace)^1

local hash = { }

function lpeg.anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * lpeg.V(1) }
end

function lpeg.startswith(pattern) --slightly adapted
    return P(pattern)
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

-- variant:

--~ local parser = lpeg.Ct(lpeg.splitat(newline))

local crlf     = P("\r\n")
local cr       = P("\r")
local lf       = P("\n")
local space    = S(" \t\f\v")  -- + string.char(0xc2, 0xa0) if we want utf (cf mail roberto)
local newline  = crlf + cr + lf
local spacing  = space^0 * newline

local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

local capture = Ct(content^0)

function string:splitlines()
    return match(capture,self)
end

lpeg.linebyline = content -- better make a sublibrary

--~ local p = lpeg.splitat("->",false)  print(match(p,"oeps->what->more"))  -- oeps what more
--~ local p = lpeg.splitat("->",true)   print(match(p,"oeps->what->more"))  -- oeps what->more
--~ local p = lpeg.splitat("->",false)  print(match(p,"oeps"))              -- oeps
--~ local p = lpeg.splitat("->",true)   print(match(p,"oeps"))              -- oeps

local splitters_s, splitters_m = { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        if single then
            local other, any = C((1 - separator)^0), P(1)
            splitter = other * (separator * C(any^0) + "") -- ?
            splitters_s[separator] = splitter
        else
            local other = C((1 - separator)^0)
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

lpeg.splitat = splitat

local cache = { }

function string:split(separator)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return match(c,self)
end

local cache = { }

function string:checkedsplit(separator)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^0)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,self)
end

--~ function lpeg.L(list,pp)
--~     local p = pp
--~     for l=1,#list do
--~         if p then
--~             p = p + lpeg.P(list[l])
--~         else
--~             p = lpeg.P(list[l])
--~         end
--~     end
--~     return p
--~ end

--~ from roberto's site:
--~
--~ -- decode a two-byte UTF-8 sequence
--~ local function f2 (s)
--~   local c1, c2 = string.byte(s, 1, 2)
--~   return c1 * 64 + c2 - 12416
--~ end
--~
--~ -- decode a three-byte UTF-8 sequence
--~ local function f3 (s)
--~   local c1, c2, c3 = string.byte(s, 1, 3)
--~   return (c1 * 64 + c2) * 64 + c3 - 925824
--~ end
--~
--~ -- decode a four-byte UTF-8 sequence
--~ local function f4 (s)
--~   local c1, c2, c3, c4 = string.byte(s, 1, 4)
--~   return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168
--~ end
--~
--~ local cont = lpeg.R("\128\191")   -- continuation byte
--~
--~ local utf8 = lpeg.R("\0\127") / string.byte
--~            + lpeg.R("\194\223") * cont / f2
--~            + lpeg.R("\224\239") * cont * cont / f3
--~            + lpeg.R("\240\244") * cont * cont * cont / f4
--~
--~ local decode_pattern = lpeg.Ct(utf8^0) * -1


local cont = R("\128\191")   -- continuation byte

lpeg.utf8 = R("\0\127") + R("\194\223") * cont + R("\224\239") * cont * cont + R("\240\244") * cont * cont * cont

