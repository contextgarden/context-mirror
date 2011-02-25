-- merged file : luatex-fonts-merged.lua
-- parent file : luatex-fonts.lua
-- merge date  : 02/25/11 22:03:53

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-string'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local string = string
local sub, gsub, find, match, gmatch, format, char, byte, rep, lower = string.sub, string.gsub, string.find, string.match, string.gmatch, string.format, string.char, string.byte, string.rep, string.lower
local lpegmatch, S, C, Ct = lpeg.match, lpeg.S, lpeg.C, lpeg.Ct

-- some functions may disappear as they are not used anywhere

if not string.split then

    -- this will be overloaded by a faster lpeg variant

    function string.split(str,pattern)
        local t = { }
        if #str > 0 then
            local n = 1
            for s in gmatch(str..pattern,"(.-)"..pattern) do
                t[n] = s
                n = n + 1
            end
        end
        return t
    end

end

function string.unquoted(str)
    return (gsub(str,"^([\"\'])(.*)%1$","%2"))
end

--~ function stringunquoted(str)
--~     if find(str,"^[\'\"]") then
--~         return sub(str,2,-2)
--~     else
--~         return str
--~     end
--~ end

function string.quoted(str)
    return format("%q",str) -- always "
end

function string.count(str,pattern) -- variant 3
    local n = 0
    for _ in gmatch(str,pattern) do -- not for utf
        n = n + 1
    end
    return n
end

function string.limit(str,n,sentinel) -- not utf proof
    if #str > n then
        sentinel = sentinel or "..."
        return sub(str,1,(n-#sentinel)) .. sentinel
    else
        return str
    end
end

local space    = S(" \t\v\n")
local nospace  = 1 - space
local stripper = space^0 * C((space^0 * nospace^1)^0) -- roberto's code

function string.strip(str)
    return lpegmatch(stripper,str) or ""
end

function string.is_empty(str)
    return not find(str,"%S")
end

local patterns_escapes = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

local simple_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

function string.escapedpattern(str,simple)
    return (gsub(str,".",simple and simple_escapes or patterns_escapes))
end

function string.topattern(str,lowercase,strict)
    if str == "" then
        return ".*"
    else
        str = gsub(str,".",simple_escapes)
        if lowercase then
            str = lower(str)
        end
        if strict then
            return "^" .. str .. "$"
        else
            return str
        end
    end
end

-- obsolete names:

string.quote   = string.quoted
string.unquote = string.unquoted

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg = require("lpeg")

local type = type

-- Beware, we predefine a bunch of patterns here and one reason for doing so
-- is that we get consistent behaviour in some of the visualizers.

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local P, R, S, V, match = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.match
local Ct, C, Cs, Cc = lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc
local lpegtype = lpeg.type

local utfcharacters    = string.utfcharacters
local utfgmatch        = unicode and unicode.utf8.gmatch

local anything         = P(1)
local endofstring      = P(-1)
local alwaysmatched    = P(true)

patterns.anything      = anything
patterns.endofstring   = endofstring
patterns.beginofstring = alwaysmatched
patterns.alwaysmatched = alwaysmatched

local digit, sign      = R('09'), S('+-')
local cr, lf, crlf     = P("\r"), P("\n"), P("\r\n")
local newline          = crlf + cr + lf
local escaped          = P("\\") * anything
local squote           = P("'")
local dquote           = P('"')
local space            = P(" ")

local utfbom_32_be     = P('\000\000\254\255')
local utfbom_32_le     = P('\255\254\000\000')
local utfbom_16_be     = P('\255\254')
local utfbom_16_le     = P('\254\255')
local utfbom_8         = P('\239\187\191')
local utfbom           = utfbom_32_be + utfbom_32_le
                       + utfbom_16_be + utfbom_16_le
                       + utfbom_8
local utftype          = utfbom_32_be / "utf-32-be" + utfbom_32_le  / "utf-32-le"
                       + utfbom_16_be / "utf-16-be" + utfbom_16_le  / "utf-16-le"
                       + utfbom_8     / "utf-8"     + alwaysmatched / "unknown"

local utf8next         = R("\128\191")

patterns.utf8one       = R("\000\127")
patterns.utf8two       = R("\194\223") * utf8next
patterns.utf8three     = R("\224\239") * utf8next * utf8next
patterns.utf8four      = R("\240\244") * utf8next * utf8next * utf8next
patterns.utfbom        = utfbom
patterns.utftype       = utftype

local utf8char         = patterns.utf8one + patterns.utf8two + patterns.utf8three + patterns.utf8four
local validutf8char    = utf8char^0 * endofstring * Cc(true) + Cc(false)

patterns.utf8          = utf8char
patterns.utf8char      = utf8char
patterns.validutf8     = validutf8char
patterns.validutf8char = validutf8char

patterns.digit         = digit
patterns.sign          = sign
patterns.cardinal      = sign^0 * digit^1
patterns.integer       = sign^0 * digit^1
patterns.float         = sign^0 * digit^0 * P('.') * digit^1
patterns.cfloat        = sign^0 * digit^0 * P(',') * digit^1
patterns.number        = patterns.float + patterns.integer
patterns.cnumber       = patterns.cfloat + patterns.integer
patterns.oct           = P("0") * R("07")^1
patterns.octal         = patterns.oct
patterns.HEX           = P("0x") * R("09","AF")^1
patterns.hex           = P("0x") * R("09","af")^1
patterns.hexadecimal   = P("0x") * R("09","AF","af")^1
patterns.lowercase     = R("az")
patterns.uppercase     = R("AZ")
patterns.letter        = patterns.lowercase + patterns.uppercase
patterns.space         = space
patterns.tab           = P("\t")
patterns.spaceortab    = patterns.space + patterns.tab
patterns.eol           = S("\n\r")
patterns.spacer        = S(" \t\f\v")  -- + string.char(0xc2, 0xa0) if we want utf (cf mail roberto)
patterns.newline       = newline
patterns.emptyline     = newline^1
patterns.nonspacer     = 1 - patterns.spacer
patterns.whitespace    = patterns.eol + patterns.spacer
patterns.nonwhitespace = 1 - patterns.whitespace
patterns.equal         = P("=")
patterns.comma         = P(",")
patterns.commaspacer   = P(",") * patterns.spacer^0
patterns.period        = P(".")
patterns.colon         = P(":")
patterns.semicolon     = P(";")
patterns.underscore    = P("_")
patterns.escaped       = escaped
patterns.squote        = squote
patterns.dquote        = dquote
patterns.nosquote      = (escaped + (1-squote))^0
patterns.nodquote      = (escaped + (1-dquote))^0
patterns.unsingle      = (squote/"") * patterns.nosquote * (squote/"")
patterns.undouble      = (dquote/"") * patterns.nodquote * (dquote/"")
patterns.unquoted      = patterns.undouble + patterns.unsingle -- more often undouble
patterns.unspacer      = ((patterns.spacer^1)/"")^0

patterns.somecontent   = (anything - newline - space)^1 -- (utf8char - newline - space)^1
patterns.beginline     = #(1-newline)

local unquoted = Cs(patterns.unquoted * endofstring) -- not C

function string.unquoted(str)
    return match(unquoted,str) or str
end

--~ print(string.unquoted("test"))
--~ print(string.unquoted([["t\"est"]]))
--~ print(string.unquoted([["t\"est"x]]))
--~ print(string.unquoted("\'test\'"))

function lpeg.anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * V(1) } -- why so complex?
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

local splitters_s, splitters_m = { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        local other = C((1 - separator)^0)
        if single then
            local any = anything
            splitter = other * (separator * C(any^0) + "") -- ?
            splitters_s[separator] = splitter
        else
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

lpeg.splitat = splitat

--~ local p = splitat("->",false)  print(match(p,"oeps->what->more"))  -- oeps what more
--~ local p = splitat("->",true)   print(match(p,"oeps->what->more"))  -- oeps what->more
--~ local p = splitat("->",false)  print(match(p,"oeps"))              -- oeps
--~ local p = splitat("->",true)   print(match(p,"oeps"))              -- oeps

local cache = { }

function lpeg.split(separator,str)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return match(c,str)
end

function string.split(str,separator)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return match(c,str)
end

local spacing  = patterns.spacer^0 * newline -- sort of strip
local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

patterns.textline = content

--~ local linesplitter = Ct(content^0)
--~
--~ function string.splitlines(str)
--~     return match(linesplitter,str)
--~ end

local linesplitter = Ct(splitat(newline))

patterns.linesplitter = linesplitter

function string.splitlines(str)
    return match(linesplitter,str)
end

local utflinesplitter = utfbom^-1 * Ct(splitat(newline))

patterns.utflinesplitter = utflinesplitter

function string.utfsplitlines(str)
    return match(utflinesplitter,str)
end

--~ lpeg.splitters = cache -- no longer public

local cache = { }

function lpeg.checkedsplit(separator,str)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,str)
end

function string.checkedsplit(str,separator)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,str)
end

--~ from roberto's site:

local f1 = string.byte

local function f2(s) local c1, c2         = f1(s,1,2) return   c1 * 64 + c2                       -    12416 end
local function f3(s) local c1, c2, c3     = f1(s,1,3) return  (c1 * 64 + c2) * 64 + c3            -   925824 end
local function f4(s) local c1, c2, c3, c4 = f1(s,1,4) return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168 end

local utf8byte = patterns.utf8one/f1 + patterns.utf8two/f2 + patterns.utf8three/f3 + patterns.utf8four/f4

patterns.utf8byte = utf8byte

--~ local str = " a b c d "

--~ local s = lpeg.stripper(lpeg.R("az"))   print("["..lpeg.match(s,str).."]")
--~ local s = lpeg.keeper(lpeg.R("az"))     print("["..lpeg.match(s,str).."]")
--~ local s = lpeg.stripper("ab")           print("["..lpeg.match(s,str).."]")
--~ local s = lpeg.keeper("ab")             print("["..lpeg.match(s,str).."]")

local cache = { }

function lpeg.stripper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs(((S(str)^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs(((str^1)/"" + 1)^0)
    end
end

local cache = { }

function lpeg.keeper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs((((1-S(str))^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs((((1-str)^1)/"" + 1)^0)
    end
end

function lpeg.frontstripper(str) -- or pattern (yet undocumented)
    return (P(str) + P(true)) * Cs(P(1)^0)
end

function lpeg.endstripper(str) -- or pattern (yet undocumented)
    return Cs((1 - P(str) * P(-1))^0)
end

-- Just for fun I looked at the used bytecode and
-- p = (p and p + pp) or pp gets one more (testset).

function lpeg.replacer(one,two)
    if type(one) == "table" then
        local no = #one
        if no > 0 then
            local p
            for i=1,no do
                local o = one[i]
                local pp = P(o[1]) / o[2]
                if p then
                    p = p + pp
                else
                    p = pp
                end
            end
            return Cs((p + 1)^0)
        end
    else
        two = two or ""
        return Cs((P(one)/two + 1)^0)
    end
end

local splitters_f, splitters_s = { }, { }

function lpeg.firstofsplit(separator) -- always return value
    local splitter = splitters_f[separator]
    if not splitter then
        separator = P(separator)
        splitter = C((1 - separator)^0)
        splitters_f[separator] = splitter
    end
    return splitter
end

function lpeg.secondofsplit(separator) -- nil if not split
    local splitter = splitters_s[separator]
    if not splitter then
        separator = P(separator)
        splitter = (1 - separator)^0 * separator * C(anything^0)
        splitters_s[separator] = splitter
    end
    return splitter
end

function lpeg.balancer(left,right)
    left, right = P(left), P(right)
    return P { left * ((1 - left - right) + V(1))^0 * right }
end

--~ print(1,match(lpeg.firstofsplit(":"),"bc:de"))
--~ print(2,match(lpeg.firstofsplit(":"),":de")) -- empty
--~ print(3,match(lpeg.firstofsplit(":"),"bc"))
--~ print(4,match(lpeg.secondofsplit(":"),"bc:de"))
--~ print(5,match(lpeg.secondofsplit(":"),"bc:")) -- empty
--~ print(6,match(lpeg.secondofsplit(":",""),"bc"))
--~ print(7,match(lpeg.secondofsplit(":"),"bc"))
--~ print(9,match(lpeg.secondofsplit(":","123"),"bc"))

--~ -- slower:
--~
--~ function lpeg.counter(pattern)
--~     local n, pattern = 0, (lpeg.P(pattern)/function() n = n + 1 end  + lpeg.anything)^0
--~     return function(str) n = 0 ; lpegmatch(pattern,str) ; return n end
--~ end

local nany = utf8char/""

function lpeg.counter(pattern)
    pattern = Cs((P(pattern)/" " + nany)^0)
    return function(str)
        return #match(pattern,str)
    end
end

if utfgmatch then

    function lpeg.count(str,what) -- replaces string.count
        if type(what) == "string" then
            local n = 0
            for _ in utfgmatch(str,what) do
                n = n + 1
            end
            return n
        else -- 4 times slower but still faster than / function
            return #match(Cs((P(what)/" " + nany)^0),str)
        end
    end

else

    local cache = { }

    function lpeg.count(str,what) -- replaces string.count
        if type(what) == "string" then
            local p = cache[what]
            if not p then
                p = Cs((P(what)/" " + nany)^0)
                cache[p] = p
            end
            return #match(p,str)
        else -- 4 times slower but still faster than / function
            return #match(Cs((P(what)/" " + nany)^0),str)
        end
    end

end

local patterns_escapes = { -- also defines in l-string
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%)", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

local simple_escapes = { -- also defines in l-string
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

local p = Cs((S("-.+*%()[]") / patterns_escapes + anything)^0)
local s = Cs((S("-.+*%()[]") / simple_escapes   + anything)^0)

function string.escapedpattern(str,simple)
    return match(simple and s or p,str)
end

-- utf extensies

lpeg.UP = lpeg.P

if utfcharacters then

    function lpeg.US(str)
        local p
        for uc in utfcharacters(str) do
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        return p
    end


elseif utfgmatch then

    function lpeg.US(str)
        local p
        for uc in utfgmatch(str,".") do
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        return p
    end

else

    function lpeg.US(str)
        local p
        local f = function(uc)
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        match((utf8char/f)^0,str)
        return p
    end

end

local range = Cs(utf8byte) * (Cs(utf8byte) + Cc(false))

local utfchar = unicode and unicode.utf8 and unicode.utf8.char

function lpeg.UR(str,more)
    local first, last
    if type(str) == "number" then
        first = str
        last = more or first
    else
        first, last = match(range,str)
        if not last then
            return P(str)
        end
    end
    if first == last then
        return P(str)
    elseif utfchar and last - first < 8 then -- a somewhat arbitrary criterium
        local p
        for i=first,last do
            if p then
                p = p + P(utfchar(i))
            else
                p = P(utfchar(i))
            end
        end
        return p -- nil when invalid range
    else
        local f = function(b)
            return b >= first and b <= last
        end
        return utf8byte / f -- nil when invalid range
    end
end

--~ lpeg.print(lpeg.R("ab","cd","gh"))
--~ lpeg.print(lpeg.P("a","b","c"))
--~ lpeg.print(lpeg.S("a","b","c"))

--~ print(lpeg.count("äáàa",lpeg.P("á") + lpeg.P("à")))
--~ print(lpeg.count("äáàa",lpeg.UP("áà")))
--~ print(lpeg.count("äáàa",lpeg.US("àá")))
--~ print(lpeg.count("äáàa",lpeg.UR("aá")))
--~ print(lpeg.count("äáàa",lpeg.UR("àá")))
--~ print(lpeg.count("äáàa",lpeg.UR(0x0000,0xFFFF)))

function lpeg.oneof(list,...) -- lpeg.oneof("elseif","else","if","then")
    if type(list) ~= "table" then
        list = { list, ... }
    end
 -- sort(list) -- longest match first
    local p = P(list[1])
    for l=2,#list do
        p = p + P(list[l])
    end
    return p
end

function lpeg.is_lpeg(p)
    return p and lpegtype(p) == "pattern"
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-boolean'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tonumber = type, tonumber

boolean = boolean or { }
local boolean = boolean

-- function boolean.tonumber(b)
--     return b and 1 or 0 -- test and test and return or return
-- end

function boolean.tonumber(b)
    if b then return 1 else return 0 end -- test and return or return
end

function toboolean(str,tolerant)
    if tolerant then
        local tstr = type(str)
        if tstr == "string" then
            return str == "true" or str == "yes" or str == "on" or str == "1" or str == "t"
        elseif tstr == "number" then
            return tonumber(str) ~= 0
        elseif tstr == "nil" then
            return false
        else
            return str
        end
    elseif str == "true" then
        return true
    elseif str == "false" then
        return false
    else
        return str
    end
end

string.toboolean = toboolean

function string.is_boolean(str,default)
    if type(str) == "string" then
        if str == "true" or str == "yes" or str == "on" or str == "t" then
            return true
        elseif str == "false" or str == "no" or str == "off" or str == "f" then
            return false
        end
    end
    return default
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-math'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local floor, sin, cos, tan = math.floor, math.sin, math.cos, math.tan

if not math.round then
    function math.round(x) return floor(x + 0.5) end
end

if not math.div then
    function math.div(n,m) return floor(n/m) end
end

if not math.mod then
    function math.mod(n,m) return n % m end
end

local pipi = 2*math.pi/360

if not math.sind then
    function math.sind(d) return sin(d*pipi) end
    function math.cosd(d) return cos(d*pipi) end
    function math.tand(d) return tan(d*pipi) end
end

if not math.odd then
    function math.odd (n) return n % 2 == 0 end
    function math.even(n) return n % 2 ~= 0 end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-table'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring, tonumber, ipairs, table, string = type, next, tostring, tonumber, ipairs, table, string
local concat, sort, insert, remove = table.concat, table.sort, table.insert, table.remove
local format, find, gsub, lower, dump, match = string.format, string.find, string.gsub, string.lower, string.dump, string.match
local getmetatable, setmetatable = getmetatable, setmetatable

-- Starting with version 5.2 Lua no longer provide ipairs, which makes
-- sense. As we already used the for loop and # in most places the
-- impact on ConTeXt was not that large; the remaining ipairs already
-- have been replaced. In a similar fashio we also hardly used pairs.
--
-- Just in case, we provide the fallbacks as discussed in Programming
-- in Lua (http://www.lua.org/pil/7.3.html):

if not ipairs then

    -- for k, v in ipairs(t) do                ... end
    -- for k=1,#t            do local v = t[k] ... end

    local function iterate(a,i)
        i = i + 1
        local v = a[i]
        if v ~= nil then
            return i, v --, nil
        end
    end

    function ipairs(a)
        return iterate, a, 0
    end

end

if not pairs then

    -- for k, v in pairs(t) do ... end
    -- for k, v in next, t  do ... end

    function pairs(t)
        return next, t -- , nil
    end

end

-- Also, unpack has been moved to the table table, and for compatiility
-- reasons we provide both now.

if not table.unpack then
    table.unpack = _G.unpack
elseif not unpack then
    _G.unpack = table.unpack
end

-- extra functions, some might go (when not used)

function table.strip(tab)
    local lst, l = { }, 0
    for i=1,#tab do
        local s = gsub(tab[i],"^%s*(.-)%s*$","%1")
        if s == "" then
            -- skip this one
        else
            l = l + 1
            lst[l] = s
        end
    end
    return lst
end

function table.keys(t)
    local keys, k = { }, 0
    for key, _ in next, t do
        k = k + 1
        keys[k] = key
    end
    return keys
end

local function compare(a,b)
    local ta, tb = type(a), type(b) -- needed, else 11 < 2
    if ta == tb then
        return a < b
    else
        return tostring(a) < tostring(b)
    end
end

local function sortedkeys(tab)
    local srt, kind, s = { }, 0, 0 -- 0=unknown 1=string, 2=number 3=mixed
    for key,_ in next, tab do
        s = s + 1
        srt[s] = key
        if kind == 3 then
            -- no further check
        else
            local tkey = type(key)
            if tkey == "string" then
                kind = (kind == 2 and 3) or 1
            elseif tkey == "number" then
                kind = (kind == 1 and 3) or 2
            else
                kind = 3
            end
        end
    end
    if kind == 0 or kind == 3 then
        sort(srt,compare)
    else
        sort(srt)
    end
    return srt
end

local function sortedhashkeys(tab) -- fast one
    local srt, s = { }, 0
    for key,_ in next, tab do
        if key then
            s= s + 1
            srt[s] = key
        end
    end
    sort(srt)
    return srt
end

table.sortedkeys     = sortedkeys
table.sortedhashkeys = sortedhashkeys

local function nothing() end

local function sortedhash(t)
    if t then
        local n, s = 0, sortedkeys(t) -- the robust one
        local function kv(s)
            n = n + 1
            local k = s[n]
            return k, t[k]
        end
        return kv, s
    else
        return nothing
    end
end

table.sortedhash  = sortedhash
table.sortedpairs = sortedhash

function table.append(t, list)
    local n = #t
    for i=1,#list do
        n = n + 1
        t[n] = list[i]
    end
    return t
end

function table.prepend(t, list)
    local nl = #list
    local nt = nl + #t
    for i=#t,1,-1 do
        t[nt] = t[i]
        nt = nt - 1
    end
    for i=1,#list do
        t[i] = list[i]
    end
    return t
end

function table.merge(t, ...) -- first one is target
    t = t or { }
    local lst = { ... }
    for i=1,#lst do
        for k, v in next, lst[i] do
            t[k] = v
        end
    end
    return t
end

function table.merged(...)
    local tmp, lst = { }, { ... }
    for i=1,#lst do
        for k, v in next, lst[i] do
            tmp[k] = v
        end
    end
    return tmp
end

function table.imerge(t, ...)
    local lst, nt = { ... }, #t
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            nt = nt + 1
            t[nt] = nst[j]
        end
    end
    return t
end

function table.imerged(...)
    local tmp, ntmp, lst = { }, 0, {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            ntmp = ntmp + 1
            tmp[ntmp] = nst[j]
        end
    end
    return tmp
end

local function fastcopy(old,metatabletoo) -- fast one
    if old then
        local new = { }
        for k,v in next, old do
            if type(v) == "table" then
                new[k] = fastcopy(v,metatabletoo) -- was just table.copy
            else
                new[k] = v
            end
        end
        if metatabletoo then
            -- optional second arg
            local mt = getmetatable(old)
            if mt then
                setmetatable(new,mt)
            end
        end
        return new
    else
        return { }
    end
end

-- todo : copy without metatable

local function copy(t, tables) -- taken from lua wiki, slightly adapted
    tables = tables or { }
    local tcopy = {}
    if not tables[t] then
        tables[t] = tcopy
    end
    for i,v in next, t do -- brrr, what happens with sparse indexed
        if type(i) == "table" then
            if tables[i] then
                i = tables[i]
            else
                i = copy(i, tables)
            end
        end
        if type(v) ~= "table" then
            tcopy[i] = v
        elseif tables[v] then
            tcopy[i] = tables[v]
        else
            tcopy[i] = copy(v, tables)
        end
    end
    local mt = getmetatable(t)
    if mt then
        setmetatable(tcopy,mt)
    end
    return tcopy
end

table.fastcopy = fastcopy
table.copy     = copy


function table.tohash(t,value)
    local h = { }
    if t then
        if value == nil then value = true end
        for _, v in next, t do -- no ipairs here
            h[v] = value
        end
    end
    return h
end

function table.fromhash(t)
    local hsh, h = { }, 0
    for k, v in next, t do -- no ipairs here
        if v then
            h = h + 1
            hsh[h] = k
        end
    end
    return hsh
end

table.serialize_functions = true
table.serialize_compact   = true
table.serialize_inline    = true

local noquotes, hexify, handle, reduce, compact, inline, functions

local reserved = table.tohash { -- intercept a language inconvenience: no reserved words as key
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}

local function simple_table(t)
    if #t > 0 then
        local n = 0
        for _,v in next, t do
            n = n + 1
        end
        if n == #t then
            local tt, nt = { }, 0
            for i=1,#t do
                local v = t[i]
                local tv = type(v)
                if tv == "number" then
                    nt = nt + 1
                    if hexify then
                        tt[nt] = format("0x%04X",v)
                    else
                        tt[nt] = tostring(v) -- tostring not needed
                    end
                elseif tv == "boolean" then
                    nt = nt + 1
                    tt[nt] = tostring(v)
                elseif tv == "string" then
                    nt = nt + 1
                    tt[nt] = format("%q",v)
                else
                    tt = nil
                    break
                end
            end
            return tt
        end
    end
    return nil
end

-- Because this is a core function of mkiv I moved some function calls
-- inline.
--
-- twice as fast in a test:
--
-- local propername = lpeg.P(lpeg.R("AZ","az","__") * lpeg.R("09","AZ","az", "__")^0 * lpeg.P(-1) )

-- problem: there no good number_to_string converter with the best resolution

local function do_serialize(root,name,depth,level,indexed)
    if level > 0 then
        depth = depth .. " "
        if indexed then
            handle(format("%s{",depth))
        else
            local tn = type(name)
            if tn == "number" then -- or find(k,"^%d+$") then
                if hexify then
                    handle(format("%s[0x%04X]={",depth,name))
                else
                    handle(format("%s[%s]={",depth,name))
                end
            elseif tn == "string" then
                if noquotes and not reserved[name] and find(name,"^%a[%w%_]*$") then
                    handle(format("%s%s={",depth,name))
                else
                    handle(format("%s[%q]={",depth,name))
                end
            elseif tn == "boolean" then
                handle(format("%s[%s]={",depth,tostring(name)))
            else
                handle(format("%s{",depth))
            end
        end
    end
    -- we could check for k (index) being number (cardinal)
    if root and next(root) then
        local first, last = nil, 0 -- #root cannot be trusted here (will be ok in 5.2 when ipairs is gone)
        if compact then
            -- NOT: for k=1,#root do (we need to quit at nil)
            for k,v in ipairs(root) do -- can we use next?
                if not first then first = k end
                last = last + 1
            end
        end
        local sk = sortedkeys(root)
        for i=1,#sk do
            local k = sk[i]
            local v = root[k]
            --~ if v == root then
                -- circular
            --~ else
            local t, tk = type(v), type(k)
            if compact and first and tk == "number" and k >= first and k <= last then
                if t == "number" then
                    if hexify then
                        handle(format("%s 0x%04X,",depth,v))
                    else
                        handle(format("%s %s,",depth,v)) -- %.99g
                    end
                elseif t == "string" then
                    if reduce and tonumber(v) then
                        handle(format("%s %s,",depth,v))
                    else
                        handle(format("%s %q,",depth,v))
                    end
                elseif t == "table" then
                    if not next(v) then
                        handle(format("%s {},",depth))
                    elseif inline then -- and #t > 0
                        local st = simple_table(v)
                        if st then
                            handle(format("%s { %s },",depth,concat(st,", ")))
                        else
                            do_serialize(v,k,depth,level+1,true)
                        end
                    else
                        do_serialize(v,k,depth,level+1,true)
                    end
                elseif t == "boolean" then
                    handle(format("%s %s,",depth,tostring(v)))
                elseif t == "function" then
                    if functions then
                        handle(format('%s loadstring(%q),',depth,dump(v)))
                    else
                        handle(format('%s "function",',depth))
                    end
                else
                    handle(format("%s %q,",depth,tostring(v)))
                end
            elseif k == "__p__" then -- parent
                if false then
                    handle(format("%s __p__=nil,",depth))
                end
            elseif t == "number" then
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%s]=%s,",depth,k,v)) -- %.99g
                    end
                elseif tk == "boolean" then
                    if hexify then
                        handle(format("%s [%s]=0x%04X,",depth,tostring(k),v))
                    else
                        handle(format("%s [%s]=%s,",depth,tostring(k),v)) -- %.99g
                    end
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    if hexify then
                        handle(format("%s %s=0x%04X,",depth,k,v))
                    else
                        handle(format("%s %s=%s,",depth,k,v)) -- %.99g
                    end
                else
                    if hexify then
                        handle(format("%s [%q]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v)) -- %.99g
                    end
                end
            elseif t == "string" then
                if reduce and tonumber(v) then
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%s,",depth,k,v))
                        else
                            handle(format("%s [%s]=%s,",depth,k,v))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=%s,",depth,tostring(k),v))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%s,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v))
                    end
                else
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%q,",depth,k,v))
                        else
                            handle(format("%s [%s]=%q,",depth,k,v))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=%q,",depth,tostring(k),v))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%q,",depth,k,v))
                    else
                        handle(format("%s [%q]=%q,",depth,k,v))
                    end
                end
            elseif t == "table" then
                if not next(v) then
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]={},",depth,k))
                        else
                            handle(format("%s [%s]={},",depth,k))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]={},",depth,tostring(k)))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s={},",depth,k))
                    else
                        handle(format("%s [%q]={},",depth,k))
                    end
                elseif inline then
                    local st = simple_table(v)
                    if st then
                        if tk == "number" then -- or find(k,"^%d+$") then
                            if hexify then
                                handle(format("%s [0x%04X]={ %s },",depth,k,concat(st,", ")))
                            else
                                handle(format("%s [%s]={ %s },",depth,k,concat(st,", ")))
                            end
                        elseif tk == "boolean" then -- or find(k,"^%d+$") then
                            handle(format("%s [%s]={ %s },",depth,tostring(k),concat(st,", ")))
                        elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                            handle(format("%s %s={ %s },",depth,k,concat(st,", ")))
                        else
                            handle(format("%s [%q]={ %s },",depth,k,concat(st,", ")))
                        end
                    else
                        do_serialize(v,k,depth,level+1)
                    end
                else
                    do_serialize(v,k,depth,level+1)
                end
            elseif t == "boolean" then
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%s,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%s,",depth,k,tostring(v)))
                    end
                elseif tk == "boolean" then -- or find(k,"^%d+$") then
                    handle(format("%s [%s]=%s,",depth,tostring(k),tostring(v)))
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%s,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%s,",depth,k,tostring(v)))
                end
            elseif t == "function" then
                if functions then
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=loadstring(%q),",depth,k,dump(v)))
                        else
                            handle(format("%s [%s]=loadstring(%q),",depth,k,dump(v)))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=loadstring(%q),",depth,tostring(k),dump(v)))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=loadstring(%q),",depth,k,dump(v)))
                    else
                        handle(format("%s [%q]=loadstring(%q),",depth,k,dump(v)))
                    end
                end
            else
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%q,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%q,",depth,k,tostring(v)))
                    end
                elseif tk == "boolean" then -- or find(k,"^%d+$") then
                    handle(format("%s [%s]=%q,",depth,tostring(k),tostring(v)))
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%q,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%q,",depth,k,tostring(v)))
                end
            end
            --~ end
        end
    end
   if level > 0 then
        handle(format("%s},",depth))
    end
end

-- replacing handle by a direct t[#t+1] = ... (plus test) is not much
-- faster (0.03 on 1.00 for zapfino.tma)

local function serialize(root,name,_handle,_reduce,_noquotes,_hexify)
    noquotes = _noquotes
    hexify = _hexify
    handle = _handle or print
    reduce = _reduce or false
    compact = table.serialize_compact
    inline  = compact and table.serialize_inline
    functions = table.serialize_functions
    local tname = type(name)
    if tname == "string" then
        if name == "return" then
            handle("return {")
        else
            handle(name .. "={")
        end
    elseif tname == "number" then
        if hexify then
            handle(format("[0x%04X]={",name))
        else
            handle("[" .. name .. "]={")
        end
    elseif tname == "boolean" then
        if name then
            handle("return {")
        else
            handle("{")
        end
    else
        handle("t={")
    end
    if root then
        -- The dummy access will initialize a table that has a delayed initialization
        -- using a metatable.
        local dummy = root._w_h_a_t_e_v_e_r_
        root._w_h_a_t_e_v_e_r_ = nil
        -- Let's forget about empty tables.
        if next(root) then
            do_serialize(root,name,"",0)
        end
    end
    handle("}")
end

--~ name:
--~
--~ true     : return     { }
--~ false    :            { }
--~ nil      : t        = { }
--~ string   : string   = { }
--~ 'return' : return     { }
--~ number   : [number] = { }

function table.serialize(root,name,reduce,noquotes,hexify) -- can be faster if flush == false and t as argument
    local t, n = { }, 0
    local function flush(s)
        n = n + 1
        t[n] = s
    end
    serialize(root,name,flush,reduce,noquotes,hexify)
    return concat(t,"\n")
end

function table.tohandle(handle,root,name,reduce,noquotes,hexify)
    serialize(root,name,handle,reduce,noquotes,hexify)
end

-- sometimes tables are real use (zapfino extra pro is some 85M) in which
-- case a stepwise serialization is nice; actually, we could consider:
--
-- for line in table.serializer(root,name,reduce,noquotes) do
--    ...(line)
-- end
--
-- so this is on the todo list

table.tofile_maxtab = 2*1024

function table.tofile(filename,root,name,reduce,noquotes,hexify)
    local f = io.open(filename,'w')
    if f then
        local maxtab = table.tofile_maxtab
        if maxtab > 1 then
            local t, n = { }, 0
            local function flush(s)
                n = n + 1
                t[n] = s
                if n > maxtab then
                    f:write(concat(t,"\n"),"\n") -- hm, write(sometable) should be nice
                    t, n = { }, 0 -- we could recycle t if needed
                end
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
            f:write(concat(t,"\n"),"\n")
        else
            local function flush(s)
                f:write(s,"\n")
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
        end
        f:close()
        io.flush()
    end
end

local function flattened(t,f,depth)
    if f == nil then
        f = { }
        depth = 0xFFFF
    elseif tonumber(f) then
        -- assume then only two arguments are given
        depth = f
        f = { }
    elseif not depth then
        depth = 0xFFFF
    end
    for k, v in next, t do
        if type(k) ~= "number" then
            if depth > 0 and type(v) == "table" then
                flattened(v,f,depth-1)
            else
                f[k] = v
            end
        end
    end
    local n = #f
    for k=1,#t do
        local v = t[k]
        if depth > 0 and type(v) == "table" then
            flattened(v,f,depth-1)
            n = #f
        else
            n = n + 1
            f[n] = v
        end
    end
    return f
end

table.flattened = flattened

local function unnest(t,f) -- only used in mk, for old times sake
    if not f then          -- and only relevant for token lists
        f = { }
    end
    for i=1,#t do
        local v = t[i]
        if type(v) == "table" then
            if type(v[1]) == "table" then
                unnest(v,f)
            else
                f[#f+1] = v
            end
        else
            f[#f+1] = v
        end
    end
    return f
end

function table.unnest(t) -- bad name
    return unnest(t)
end

--~ function table.unnest(t) -- for old times sake, undocumented (only in mk)
--~     return flattened(t,1)
--~ end

--~ function table.are_equal(a,b)
--~     return table.serialize(a) == table.serialize(b)
--~ end

local function are_equal(a,b,n,m) -- indexed
    if a and b and #a == #b then
        n = n or 1
        m = m or #a
        for i=n,m do
            local ai, bi = a[i], b[i]
            if ai==bi then
                -- same
            elseif type(ai)=="table" and type(bi)=="table" then
                if not are_equal(ai,bi) then
                    return false
                end
            else
                return false
            end
        end
        return true
    else
        return false
    end
end

local function identical(a,b) -- assumes same structure
    for ka, va in next, a do
        local vb = b[ka]
        if va == vb then
            -- same
        elseif type(va) == "table" and  type(vb) == "table" then
            if not identical(va,vb) then
                return false
            end
        else
            return false
        end
    end
    return true
end

table.identical = identical
table.are_equal = are_equal

-- maybe also make a combined one

function table.compact(t)
    if t then
        for k,v in next, t do
            if not next(v) then
                t[k] = nil
            end
        end
    end
end

function table.contains(t, v)
    if t then
        for i=1, #t do
            if t[i] == v then
                return i
            end
        end
    end
    return false
end

function table.count(t)
    local n = 0
    for k, v in next, t do
        n = n + 1
    end
    return n
end

function table.swapped(t,s) -- hash
    local n = { }
    if s then
--~         for i=1,#s do
--~             n[i] = s[i]
--~         end
        for k, v in next, s do
            n[k] = v
        end
    end
--~     for i=1,#t do
--~         local ti = t[i] -- don't ask but t[i] can be nil
--~         if ti then
--~             n[ti] = i
--~         end
--~     end
    for k, v in next, t do
        n[v] = k
    end
    return n
end

function table.reversed(t)
    if t then
        local tt, tn = { }, #t
        if tn > 0 then
            local ttn = 0
            for i=tn,1,-1 do
                ttn = ttn + 1
                tt[ttn] = t[i]
            end
        end
        return tt
    end
end

function table.sequenced(t,sep,simple) -- hash only
    local s, n = { }, 0
    for k, v in sortedhash(t) do
        if simple then
            if v == true then
                n = n + 1
                s[n] = k
            elseif v and v~= "" then
                n = n + 1
                s[n] = k .. "=" .. tostring(v)
            end
        else
            n = n + 1
            s[n] = k .. "=" .. tostring(v)
        end
    end
    return concat(s, sep or " | ")
end

function table.print(...)
    table.tohandle(print,...)
end

-- -- -- obsolete but we keep them for a while and might comment them later -- -- --

-- roughly: copy-loop : unpack : sub == 0.9 : 0.4 : 0.45 (so in critical apps, use unpack)

function table.sub(t,i,j)
    return { unpack(t,i,j) }
end

-- slower than #t on indexed tables (#t only returns the size of the numerically indexed slice)

function table.is_empty(t)
    return not t or not next(t)
end

function table.has_one_entry(t)
    return t and not next(t,next(t))
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-file'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup

file       = file or { }
local file = file

local insert, concat = table.insert, table.concat
local find, gmatch, match, gsub, sub, char, lower = string.find, string.gmatch, string.match, string.gsub, string.sub, string.char, string.lower
local lpegmatch = lpeg.match
local getcurrentdir, attributes = lfs.currentdir, lfs.attributes

local P, R, S, C, Cs, Cp, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cp, lpeg.Cc

local function dirname(name,default)
    return match(name,"^(.+)[/\\].-$") or (default or "")
end

local function basename(name)
    return match(name,"^.+[/\\](.-)$") or name
end

local function nameonly(name)
    return (gsub(match(name,"^.+[/\\](.-)$") or name,"%..*$",""))
end

local function extname(name,default)
    return match(name,"^.+%.([^/\\]-)$") or default or ""
end

local function splitname(name)
    local n, s = match(name,"^(.+)%.([^/\\]-)$")
    return n or name, s or ""
end

file.basename = basename
file.dirname  = dirname
file.nameonly = nameonly
file.extname  = extname
file.suffix   = extname

function file.removesuffix(filename)
    return (gsub(filename,"%.[%a%d]+$",""))
end

function file.addsuffix(filename, suffix, criterium)
    if not suffix or suffix == "" then
        return filename
    elseif criterium == true then
        return filename .. "." .. suffix
    elseif not criterium then
        local n, s = splitname(filename)
        if not s or s == "" then
            return filename .. "." .. suffix
        else
            return filename
        end
    else
        local n, s = splitname(filename)
        if s and s ~= "" then
            local t = type(criterium)
            if t == "table" then
                -- keep if in criterium
                for i=1,#criterium do
                    if s == criterium[i] then
                        return filename
                    end
                end
            elseif t == "string" then
                -- keep if criterium
                if s == criterium then
                    return filename
                end
            end
        end
        return n .. "." .. suffix
    end
end

--~ print("1 " .. file.addsuffix("name","new")                   .. " -> name.new")
--~ print("2 " .. file.addsuffix("name.old","new")               .. " -> name.old")
--~ print("3 " .. file.addsuffix("name.old","new",true)          .. " -> name.old.new")
--~ print("4 " .. file.addsuffix("name.old","new","new")         .. " -> name.new")
--~ print("5 " .. file.addsuffix("name.old","new","old")         .. " -> name.old")
--~ print("6 " .. file.addsuffix("name.old","new","foo")         .. " -> name.new")
--~ print("7 " .. file.addsuffix("name.old","new",{"foo","bar"}) .. " -> name.new")
--~ print("8 " .. file.addsuffix("name.old","new",{"old","bar"}) .. " -> name.old")

function file.replacesuffix(filename, suffix)
    return (gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
end

--~ function file.join(...)
--~     local pth = concat({...},"/")
--~     pth = gsub(pth,"\\","/")
--~     local a, b = match(pth,"^(.*://)(.*)$")
--~     if a and b then
--~         return a .. gsub(b,"//+","/")
--~     end
--~     a, b = match(pth,"^(//)(.*)$")
--~     if a and b then
--~         return a .. gsub(b,"//+","/")
--~     end
--~     return (gsub(pth,"//+","/"))
--~ end

local trick_1 = char(1)
local trick_2 = "^" .. trick_1 .. "/+"

function file.join(...)
    local lst = { ... }
    local a, b = lst[1], lst[2]
    if a == "" then
        lst[1] = trick_1
    elseif b and find(a,"^/+$") and find(b,"^/") then
        lst[1] = ""
        lst[2] = gsub(b,"^/+","")
    end
    local pth = concat(lst,"/")
    pth = gsub(pth,"\\","/")
    local a, b = match(pth,"^(.*://)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    a, b = match(pth,"^(//)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    pth = gsub(pth,trick_2,"")
    return (gsub(pth,"//+","/"))
end

--~ print(file.join("//","/y"))
--~ print(file.join("/","/y"))
--~ print(file.join("","/y"))
--~ print(file.join("/x/","/y"))
--~ print(file.join("x/","/y"))
--~ print(file.join("http://","/y"))
--~ print(file.join("http://a","/y"))
--~ print(file.join("http:///a","/y"))
--~ print(file.join("//nas-1","/y"))

function file.is_writable(name)
    local a = attributes(name) or attributes(dirname(name,"."))
    return a and sub(a.permissions,2,2) == "w"
end

function file.is_readable(name)
    local a = attributes(name)
    return a and sub(a.permissions,1,1) == "r"
end

file.isreadable = file.is_readable -- depricated
file.iswritable = file.is_writable -- depricated

-- todo: lpeg \\ / .. does not save much

local checkedsplit = string.checkedsplit

function file.splitpath(str,separator) -- string
    str = gsub(str,"\\","/")
    return checkedsplit(str,separator or io.pathseparator)
end

function file.joinpath(tab,separator) -- table
    return concat(tab,separator or io.pathseparator) -- can have trailing //
end

-- we can hash them weakly

--~ function file.collapsepath(str) -- fails on b.c/..
--~     str = gsub(str,"\\","/")
--~     if find(str,"/") then
--~         str = gsub(str,"^%./",(gsub(getcurrentdir(),"\\","/")) .. "/") -- ./xx in qualified
--~         str = gsub(str,"/%./","/")
--~         local n, m = 1, 1
--~         while n > 0 or m > 0 do
--~             str, n = gsub(str,"[^/%.]+/%.%.$","")
--~             str, m = gsub(str,"[^/%.]+/%.%./","")
--~         end
--~         str = gsub(str,"([^/])/$","%1")
--~     --  str = gsub(str,"^%./","") -- ./xx in qualified
--~         str = gsub(str,"/%.$","")
--~     end
--~     if str == "" then str = "." end
--~     return str
--~ end
--~
--~ The previous one fails on "a.b/c"  so Taco came up with a split based
--~ variant. After some skyping we got it sort of compatible with the old
--~ one. After that the anchoring to currentdir was added in a better way.
--~ Of course there are some optimizations too. Finally we had to deal with
--~ windows drive prefixes and thinsg like sys://.

function file.collapsepath(str,anchor)
    if anchor and not find(str,"^/") and not find(str,"^%a:") then
        str = getcurrentdir() .. "/" .. str
    end
    if str == "" or str =="." then
        return "."
    elseif find(str,"^%.%.") then
        str = gsub(str,"\\","/")
        return str
    elseif not find(str,"%.") then
        str = gsub(str,"\\","/")
        return str
    end
    str = gsub(str,"\\","/")
    local starter, rest = match(str,"^(%a+:/*)(.-)$")
    if starter then
        str = rest
    end
    local oldelements = checkedsplit(str,"/")
    local newelements = { }
    local i = #oldelements
    while i > 0 do
        local element = oldelements[i]
        if element == '.' then
            -- do nothing
        elseif element == '..' then
            local n = i -1
            while n > 0 do
                local element = oldelements[n]
                if element ~= '..' and element ~= '.' then
                    oldelements[n] = '.'
                    break
                else
                    n = n - 1
                end
             end
            if n < 1 then
               insert(newelements,1,'..')
            end
        elseif element ~= "" then
            insert(newelements,1,element)
        end
        i = i - 1
    end
    if #newelements == 0 then
        return starter or "."
    elseif starter then
        return starter .. concat(newelements, '/')
    elseif find(str,"^/") then
        return "/" .. concat(newelements,'/')
    else
        return concat(newelements, '/')
    end
end

file.collapse_path = file.collapsepath

--~ local function test(str)
--~    print(string.format("%-20s %-15s %-15s",str,file.collapsepath(str),file.collapsepath(str,true)))
--~ end
--~ test("a/b.c/d") test("b.c/d") test("b.c/..")
--~ test("/") test("c:/..") test("sys://..")
--~ test("") test("./") test(".") test("..") test("./..") test("../..")
--~ test("a") test("./a") test("/a") test("a/../..")
--~ test("a/./b/..") test("a/aa/../b/bb") test("a/.././././b/..") test("a/./././b/..")
--~ test("a/b/c/../..") test("./a/b/c/../..") test("a/b/c/../..")

function file.robustname(str,strict)
    str = gsub(str,"[^%a%d%/%-%.\\]+","-")
    if strict then
        return lower(gsub(str,"^%-*(.-)%-*$","%1"))
    else
        return str
    end
end

file.readdata = io.loaddata
file.savedata = io.savedata

function file.copy(oldname,newname)
    file.savedata(newname,io.loaddata(oldname))
end

-- lpeg variants, slightly faster, not always

--~ local period    = P(".")
--~ local slashes   = S("\\/")
--~ local noperiod  = 1-period
--~ local noslashes = 1-slashes
--~ local name      = noperiod^1

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * C(noperiod^1) * -1

--~ function file.extname(name)
--~     return lpegmatch(pattern,name) or ""
--~ end

--~ local pattern = Cs(((period * noperiod^1 * -1)/"" + 1)^1)

--~ function file.removesuffix(name)
--~     return lpegmatch(pattern,name)
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * C(noslashes^1) * -1

--~ function file.basename(name)
--~     return lpegmatch(pattern,name) or name
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * Cp() * noslashes^1 * -1

--~ function file.dirname(name)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return sub(name,1,p-2)
--~     else
--~         return ""
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * Cp() * noperiod^1 * -1

--~ function file.addsuffix(name, suffix)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return name
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * Cp() * noperiod^1 * -1

--~ function file.replacesuffix(name,suffix)
--~     local p = lpegmatch(pattern,name)
--~     if p then
--~         return sub(name,1,p-2) .. "." .. suffix
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * Cp() * ((noperiod^1 * period)^1 * Cp() + P(true)) * noperiod^1 * -1

--~ function file.nameonly(name)
--~     local a, b = lpegmatch(pattern,name)
--~     if b then
--~         return sub(name,a,b-2)
--~     elseif a then
--~         return sub(name,a)
--~     else
--~         return name
--~     end
--~ end

--~ local test = file.extname
--~ local test = file.basename
--~ local test = file.dirname
--~ local test = file.addsuffix
--~ local test = file.replacesuffix
--~ local test = file.nameonly

--~ print(1,test("./a/b/c/abd.def.xxx","!!!"))
--~ print(2,test("./../b/c/abd.def.xxx","!!!"))
--~ print(3,test("a/b/c/abd.def.xxx","!!!"))
--~ print(4,test("a/b/c/def.xxx","!!!"))
--~ print(5,test("a/b/c/def","!!!"))
--~ print(6,test("def","!!!"))
--~ print(7,test("def.xxx","!!!"))

--~ local tim = os.clock() for i=1,250000 do local ext = test("abd.def.xxx","!!!") end print(os.clock()-tim)

-- also rewrite previous

local letter    = R("az","AZ") + S("_-+")
local separator = P("://")

local qualified = P(".")^0 * P("/") + letter*P(":") + letter^1*separator + letter^1 * P("/")
local rootbased = P("/") + letter*P(":")

lpeg.patterns.qualified = qualified
lpeg.patterns.rootbased = rootbased

-- ./name ../name  /name c: :// name/name

function file.is_qualified_path(filename)
    return lpegmatch(qualified,filename) ~= nil
end

function file.is_rootbased_path(filename)
    return lpegmatch(rootbased,filename) ~= nil
end

-- actually these are schemes

local slash  = S("\\/")
local period = P(".")
local drive  = C(R("az","AZ")) * P(":")
local path   = C(((1-slash)^0 * slash)^0)
local suffix = period * C(P(1-period)^0 * P(-1))
local base   = C((1-suffix)^0)

local pattern = (drive + Cc("")) * (path + Cc("")) * (base + Cc("")) * (suffix + Cc(""))

function file.splitname(str) -- returns drive, path, base, suffix
    return lpegmatch(pattern,str)
end

-- function test(t) for k, v in next, t do print(v, "=>", file.splitname(v)) end end
--
-- test { "c:", "c:/aa", "c:/aa/bb", "c:/aa/bb/cc", "c:/aa/bb/cc.dd", "c:/aa/bb/cc.dd.ee" }
-- test { "c:", "c:aa", "c:aa/bb", "c:aa/bb/cc", "c:aa/bb/cc.dd", "c:aa/bb/cc.dd.ee" }
-- test { "/aa", "/aa/bb", "/aa/bb/cc", "/aa/bb/cc.dd", "/aa/bb/cc.dd.ee" }
-- test { "aa", "aa/bb", "aa/bb/cc", "aa/bb/cc.dd", "aa/bb/cc.dd.ee" }

--~ -- todo:
--~
--~ if os.type == "windows" then
--~     local currentdir = getcurrentdir
--~     function getcurrentdir()
--~         return (gsub(currentdir(),"\\","/"))
--~     end
--~ end

-- for myself:

function file.strip(name,dir)
    local b, a = match(name,"^(.-)" .. dir .. "(.*)$")
    return a ~= "" and a or name
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['l-io'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local io = io
local byte, find, gsub, format = string.byte, string.find, string.gsub, string.format
local concat = table.concat
local type = type

if string.find(os.getenv("PATH"),";") then
    io.fileseparator, io.pathseparator = "\\", ";"
else
    io.fileseparator, io.pathseparator = "/" , ":"
end

function io.loaddata(filename,textmode)
    local f = io.open(filename,(textmode and 'r') or 'rb')
    if f then
        local data = f:read('*all')
        f:close()
        return data
    else
        return nil
    end
end

function io.savedata(filename,data,joiner)
    local f = io.open(filename,"wb")
    if f then
        if type(data) == "table" then
            f:write(concat(data,joiner or ""))
        elseif type(data) == "function" then
            data(f)
        else
            f:write(data or "")
        end
        f:close()
        io.flush()
        return true
    else
        return false
    end
end

function io.exists(filename)
    local f = io.open(filename)
    if f == nil then
        return false
    else
        assert(f:close())
        return true
    end
end

function io.size(filename)
    local f = io.open(filename)
    if f == nil then
        return 0
    else
        local s = f:seek("end")
        assert(f:close())
        return s
    end
end

function io.noflines(f)
    if type(f) == "string" then
        local f = io.open(filename)
        local n = f and io.noflines(f) or 0
        assert(f:close())
        return n
    else
        local n = 0
        for _ in f:lines() do
            n = n + 1
        end
        f:seek('set',0)
        return n
    end
end

local nextchar = {
    [ 4] = function(f)
        return f:read(1,1,1,1)
    end,
    [ 2] = function(f)
        return f:read(1,1)
    end,
    [ 1] = function(f)
        return f:read(1)
    end,
    [-2] = function(f)
        local a, b = f:read(1,1)
        return b, a
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        return d, c, b, a
    end
}

function io.characters(f,n)
    if f then
        return nextchar[n or 1], f
    else
        return nil, nil
    end
end

local nextbyte = {
    [4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(a), byte(b), byte(c), byte(d)
        else
            return nil, nil, nil, nil
        end
    end,
    [2] = function(f)
        local a, b = f:read(1,1)
        if b then
            return byte(a), byte(b)
        else
            return nil, nil
        end
    end,
    [1] = function (f)
        local a = f:read(1)
        if a then
            return byte(a)
        else
            return nil
        end
    end,
    [-2] = function (f)
        local a, b = f:read(1,1)
        if b then
            return byte(b), byte(a)
        else
            return nil, nil
        end
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(d), byte(c), byte(b), byte(a)
        else
            return nil, nil, nil, nil
        end
    end
}

function io.bytes(f,n)
    if f then
        return nextbyte[n or 1], f
    else
        return nil, nil
    end
end

function io.ask(question,default,options)
    while true do
        io.write(question)
        if options then
            io.write(format(" [%s]",concat(options,"|")))
        end
        if default then
            io.write(format(" [%s]",default))
        end
        io.write(format(" "))
        io.flush()
        local answer = io.read()
        answer = gsub(answer,"^%s*(.*)%s*$","%1")
        if answer == "" and default then
            return default
        elseif not options then
            return answer
        else
            for k=1,#options do
                if options[k] == answer then
                    return answer
                end
            end
            local pattern = "^" .. answer
            for k=1,#options do
                local v = options[k]
                if find(v,pattern) then
                    return v
                end
            end
        end
    end
end

local function readnumber(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    if n == 1 then
        return byte(f:read(1))
    elseif n == 2 then
        local a, b = byte(f:read(2),1,2)
        return 256*a + b
    elseif n == 4 then
        local a, b, c, d = byte(f:read(4),1,4)
        return 256*256*256 * a + 256*256 * b + 256*c + d
    elseif n == 8 then
        local a, b = readnumber(f,4), readnumber(f,4)
        return 256 * a + b
    elseif n == 12 then
        local a, b, c = readnumber(f,4), readnumber(f,4), readnumber(f,4)
        return 256*256 * a + 256 * b + c
    else
        return 0
    end
end

io.readnumber = readnumber

function io.readstring(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    local str = gsub(f:read(n),"%z","")
    return str
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['luat-dum'] = {
    version   = 1.100,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local dummyfunction = function() end
local dummyreporter = function(c) return function(...) texio.write(c .. " : " .. string.format(...)) end end

statistics = {
    register      = dummyfunction,
    starttiming   = dummyfunction,
    stoptiming    = dummyfunction,
    elapsedtime   = nil,
}
directives = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
trackers = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
experiments = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
storage = { -- probably no longer needed
    register      = dummyfunction,
    shared        = { },
}
logs = {
    new           = dummyreporter,
    reporter      = dummyreporter,
    messenger     = dummyreporter,
    report        = dummyfunction,
}
callbacks = {
    register = function(n,f) return callback.register(n,f) end,
}
utilities = {
    storage = {
        allocate = function(t) return t or { } end,
        mark     = function(t) return t or { } end,
    },
}

characters = characters or {
    data = { }
}

-- we need to cheat a bit here

texconfig.kpse_init = true

resolvers = resolvers or { } -- no fancy file helpers used

local remapper = {
    otf   = "opentype fonts",
    ttf   = "truetype fonts",
    ttc   = "truetype fonts",
    dfont = "truetype fonts", -- "truetype dictionary",
    cid   = "cid maps",
    fea   = "font feature files",
}

function resolvers.findfile(name,kind)
    name = string.gsub(name,"\\","\/")
    kind = kind and string.lower(kind)
    local found = kpse.find_file(name,(kind and kind ~= "" and (remapper[kind] or kind)) or file.extname(name,"tex"))
    if not found or found == "" then
        found = kpse.find_file(name,"other text file")
    end
    return found
end

function resolvers.findbinfile(name,kind)
    if not kind or kind == "" then
        kind = file.extname(name) -- string.match(name,"%.([^%.]-)$")
    end
    return resolvers.findfile(name,(kind and remapper[kind]) or kind)
end

function resolvers.resolve(s)
    return s
end

function resolvers.unresolve(s)
    return s
end

-- Caches ... I will make a real stupid version some day when I'm in the
-- mood. After all, the generic code does not need the more advanced
-- ConTeXt features. Cached data is not shared between ConTeXt and other
-- usage as I don't want any dependency at all. Also, ConTeXt might have
-- different needs and tricks added.

--~ containers.usecache = true

caches = { }

local writable, readables = nil, { }

if not caches.namespace or caches.namespace == "" or caches.namespace == "context" then
    caches.namespace = 'generic'
end

do

    local cachepaths = kpse.expand_path('$TEXMFCACHE') or ""

    if cachepaths == "" then
        cachepaths = kpse.expand_path('$TEXMFVAR')
    end

    if cachepaths == "" then
        cachepaths = kpse.expand_path('$VARTEXMF')
    end

    if cachepaths == "" then
        cachepaths = "."
    end

    cachepaths = string.split(cachepaths,os.type == "windows" and ";" or ":")

    for i=1,#cachepaths do
        if file.is_writable(cachepaths[i]) then
            writable = file.join(cachepaths[i],"luatex-cache")
            lfs.mkdir(writable)
            writable = file.join(writable,caches.namespace)
            lfs.mkdir(writable)
            break
        end
    end

    for i=1,#cachepaths do
        if file.is_readable(cachepaths[i]) then
            readables[#readables+1] = file.join(cachepaths[i],"luatex-cache",caches.namespace)
        end
    end

    if not writable then
        texio.write_nl("quiting: fix your writable cache path")
        os.exit()
    elseif #readables == 0 then
        texio.write_nl("quiting: fix your readable cache path")
        os.exit()
    elseif #readables == 1 and readables[1] == writable then
        texio.write(string.format("(using cache: %s)",writable))
    else
        texio.write(string.format("(using write cache: %s)",writable))
        texio.write(string.format("(using read cache: %s)",table.concat(readables, " ")))
    end

end

function caches.getwritablepath(category,subcategory)
    local path = file.join(writable,category)
    lfs.mkdir(path)
    path = file.join(path,subcategory)
    lfs.mkdir(path)
    return path
end

function caches.getreadablepaths(category,subcategory)
    local t = { }
    for i=1,#readables do
        t[i] = file.join(readables[i],category,subcategory)
    end
    return t
end

local function makefullname(path,name)
    if path and path ~= "" then
        name = "temp-" .. name -- clash prevention
        return file.addsuffix(file.join(path,name),"lua")
    end
end

function caches.is_writable(path,name)
    local fullname = makefullname(path,name)
    return fullname and file.is_writable(fullname)
end

function caches.loaddata(paths,name)
    for i=1,#paths do
        local fullname = makefullname(paths[i],name)
        if fullname then
            texio.write(string.format("(load: %s)",fullname))
            local data = loadfile(fullname)
            return data and data()
        end
    end
end

function caches.savedata(path,name,data)
    local fullname = makefullname(path,name)
    if fullname then
        texio.write(string.format("(save: %s)",fullname))
        table.tofile(fullname,data,'return',false,true,false)
    end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['data-con'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache      = false  trackers.register("resolvers.cache",      function(v) trace_cache      = v end)
local trace_containers = false  trackers.register("resolvers.containers", function(v) trace_containers = v end)
local trace_storage    = false  trackers.register("resolvers.storage",    function(v) trace_storage    = v end)

--[[ldx--
<p>Once we found ourselves defining similar cache constructs
several times, containers were introduced. Containers are used
to collect tables in memory and reuse them when possible based
on (unique) hashes (to be provided by the calling function).</p>

<p>Caching to disk is disabled by default. Version numbers are
stored in the saved table which makes it possible to change the
table structures without bothering about the disk cache.</p>

<p>Examples of usage can be found in the font related code.</p>
--ldx]]--

containers          = containers or { }
local containers    = containers
containers.usecache = true

local report_containers = logs.reporter("resolvers","containers")

local function report(container,tag,name)
    if trace_cache or trace_containers then
        report_containers("container: %s, tag: %s, name: %s",container.subcategory,tag,name or 'invalid')
    end
end

local allocated = { }

local mt = {
    __index = function(t,k)
        if k == "writable" then
            local writable = caches.getwritablepath(t.category,t.subcategory) or { "." }
            t.writable = writable
            return writable
        elseif k == "readables" then
            local readables = caches.getreadablepaths(t.category,t.subcategory) or { "." }
            t.readables = readables
            return readables
        end
    end,
    __storage__ = true
}

function containers.define(category, subcategory, version, enabled)
    if category and subcategory then
        local c = allocated[category]
        if not c then
            c  = { }
            allocated[category] = c
        end
        local s = c[subcategory]
        if not s then
            s = {
                category    = category,
                subcategory = subcategory,
                storage     = { },
                enabled     = enabled,
                version     = version or math.pi, -- after all, this is TeX
                trace       = false,
             -- writable    = caches.getwritablepath  and caches.getwritablepath (category,subcategory) or { "." },
             -- readables   = caches.getreadablepaths and caches.getreadablepaths(category,subcategory) or { "." },
            }
            setmetatable(s,mt)
            c[subcategory] = s
        end
        return s
    end
end

function containers.is_usable(container, name)
    return container.enabled and caches and caches.is_writable(container.writable, name)
end

function containers.is_valid(container, name)
    if name and name ~= "" then
        local storage = container.storage[name]
        return storage and storage.cache_version == container.version
    else
        return false
    end
end

function containers.read(container,name)
    local storage = container.storage
    local stored = storage[name]
    if not stored and container.enabled and caches and containers.usecache then
        stored = caches.loaddata(container.readables,name)
        if stored and stored.cache_version == container.version then
            report(container,"loaded",name)
        else
            stored = nil
        end
        storage[name] = stored
    elseif stored then
        report(container,"reusing",name)
    end
    return stored
end

function containers.write(container, name, data)
    if data then
        data.cache_version = container.version
        if container.enabled and caches then
            local unique, shared = data.unique, data.shared
            data.unique, data.shared = nil, nil
            caches.savedata(container.writable, name, data)
            report(container,"saved",name)
            data.unique, data.shared = unique, shared
        end
        report(container,"stored",name)
        container.storage[name] = data
    end
    return data
end

function containers.content(container,name)
    return container.storage[name]
end

function containers.cleanname(name)
    return (gsub(lower(name),"[^%w%d]+","-"))
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['node-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

nodes      = nodes      or { }
fonts      = fonts      or { }
attributes = attributes or { }

nodes.pool     = nodes.pool     or { }
nodes.handlers = nodes.handlers or { }

local nodecodes  = { } for k,v in next, node.types   () do nodecodes[string.gsub(v,"_","")] = k end
local whatcodes  = { } for k,v in next, node.whatsits() do whatcodes[string.gsub(v,"_","")] = k end
local glyphcodes = { [0] = "character", "glyph", "ligature", "ghost", "left", "right" }

nodes.nodecodes    = nodecodes
nodes.whatcodes    = whatcodes
nodes.whatsitcodes = whatcodes
nodes.glyphcodes   = glyphcodes

local traverse_id = node.traverse_id
local free_node   = node.free
local remove_node = node.remove
local new_node    = node.new

local glyph_code = nodecodes.glyph

function nodes.simple_font_handler(head)
--  lang.hyphenate(head)
    head = nodes.handlers.characters(head)
    nodes.injections.handler(head)
    nodes.handlers.protectglyphs(head)
    head = node.ligaturing(head)
    head = node.kerning(head)
    return head
end

if tex.attribute[0] ~= 0 then

    texio.write_nl("log","!")
    texio.write_nl("log","! Attribute 0 is reserved for ConTeXt's font feature management and has to be")
    texio.write_nl("log","! set to zero. Also, some attributes in the range 1-255 are used for special")
    texio.write_nl("log","! purposes so setting them at the TeX end might break the font handler.")
    texio.write_nl("log","!")

    tex.attribute[0] = 0 -- else no features

end

nodes.handlers.protectglyphs   = node.protect_glyphs
nodes.handlers.unprotectglyphs = node.unprotect_glyphs

function nodes.handlers.characters(head)
    local fontdata = fonts.identifiers
    if fontdata then
        local usedfonts, done, prevfont = { }, false, nil
        for n in traverse_id(glyph_code,head) do
            local font = n.font
            if font ~= prevfont then
                prevfont = font
                local used = usedfonts[font]
                if not used then
                    local tfmdata = fontdata[font] --
                    if tfmdata then
                        local shared = tfmdata.shared -- we need to check shared, only when same features
                        if shared then
                            local processors = shared.processes
                            if processors and #processors > 0 then
                                usedfonts[font] = processors
                                done = true
                            end
                        end
                    end
                end
            end
        end
        if done then
            for font, processors in next, usedfonts do
                for i=1,#processors do
                    local h, d = processors[i](head,font,0)
                    head, done = h or head, done or d
                end
            end
        end
        return head, true
    else
        return head, false
    end
end

-- helper

function nodes.pool.kern(k)
    local n = new_node("kern",1)
    n.kern = k
    return n
end

function nodes.remove(head, current, free_too)
   local t = current
   head, current = remove_node(head,current)
   if t then
        if free_too then
            free_node(t)
            t = nil
        else
            t.next, t.prev = nil, nil
        end
   end
   return head, current, t
end

function nodes.delete(head,current)
    return nodes.remove(head,current,true)
end

nodes.before = node.insert_before
nodes.after  = node.insert_after

-- attributes

attributes.unsetvalue = -0x7FFFFFFF

local numbers, last = { }, 127

function attributes.private(name)
    local number = numbers[name]
    if not number then
        if last < 255 then
            last = last + 1
        end
        number = last
        numbers[name] = number
    end
    return number
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['node-inj'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- tricky ... fonts.identifiers is not yet defined .. to be solved (maybe general tex ini)

-- This is very experimental (this will change when we have luatex > .50 and
-- a few pending thingies are available. Also, Idris needs to make a few more
-- test fonts. Btw, future versions of luatex will have extended glyph properties
-- that can be of help.

local next = next

local trace_injections = false  trackers.register("nodes.injections", function(v) trace_injections = v end)

local report_injections = logs.reporter("nodes","injections")

local attributes, nodes, node = attributes, nodes, node

fonts                    = fonts or { }
fonts.tfm                = fonts.tfm or { }
fonts.identifiers        = fonts.identifiers or { }

nodes.injections         = nodes.injections or { }
local injections         = nodes.injections

local fontdata           = fonts.identifiers
local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local nodepool           = nodes.pool
local newkern            = nodepool.kern

local traverse_id        = node.traverse_id
local unset_attribute    = node.unset_attribute
local has_attribute      = node.has_attribute
local set_attribute      = node.set_attribute
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local markbase = attributes.private('markbase')
local markmark = attributes.private('markmark')
local markdone = attributes.private('markdone')
local cursbase = attributes.private('cursbase')
local curscurs = attributes.private('curscurs')
local cursdone = attributes.private('cursdone')
local kernpair = attributes.private('kernpair')

local cursives = { }
local marks    = { }
local kerns    = { }

-- currently we do gpos/kern in a bit inofficial way but when we
-- have the extra fields in glyphnodes to manipulate ht/dp/wd
-- explicitly i will provide an alternative; also, we can share
-- tables

-- for the moment we pass the r2l key ... volt/arabtype tests

function injections.setcursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext)
    local dx, dy = factor*(exit[1]-entry[1]), factor*(exit[2]-entry[2])
    local ws, wn = tfmstart.width, tfmnext.width
    local bound = #cursives + 1
    set_attribute(start,cursbase,bound)
    set_attribute(nxt,curscurs,bound)
    cursives[bound] = { rlmode, dx, dy, ws, wn }
    return dx, dy, bound
end

function injections.setpair(current,factor,rlmode,r2lflag,spec,tfmchr)
    local x, y, w, h = factor*spec[1], factor*spec[2], factor*spec[3], factor*spec[4]
    -- dy = y - h
    if x ~= 0 or w ~= 0 or y ~= 0 or h ~= 0 then
        local bound = has_attribute(current,kernpair)
        if bound then
            local kb = kerns[bound]
            -- inefficient but singles have less, but weird anyway, needs checking
            kb[2], kb[3], kb[4], kb[5] = (kb[2] or 0) + x, (kb[3] or 0) + y, (kb[4] or 0)+ w, (kb[5] or 0) + h
        else
            bound = #kerns + 1
            set_attribute(current,kernpair,bound)
            kerns[bound] = { rlmode, x, y, w, h, r2lflag, tfmchr.width }
        end
        return x, y, w, h, bound
    end
    return x, y, w, h -- no bound
end

function injections.setkern(current,factor,rlmode,x,tfmchr)
    local dx = factor*x
    if dx ~= 0 then
        local bound = #kerns + 1
        set_attribute(current,kernpair,bound)
        kerns[bound] = { rlmode, dx }
        return dx, bound
    else
        return 0, 0
    end
end

function injections.setmark(start,base,factor,rlmode,ba,ma,index) --ba=baseanchor, ma=markanchor
    local dx, dy = factor*(ba[1]-ma[1]), factor*(ba[2]-ma[2])
    local bound = has_attribute(base,markbase)
    if bound then
        local mb = marks[bound]
        if mb then
            if not index then index = #mb + 1 end
            mb[index] = { dx, dy }
            set_attribute(start,markmark,bound)
            set_attribute(start,markdone,index)
            return dx, dy, bound
        else
            report_injections("possible problem, U+%04X is base mark without data (id: %s)",base.char,bound)
        end
    end
    index = index or 1
    bound = #marks + 1
    set_attribute(base,markbase,bound)
    set_attribute(start,markmark,bound)
    set_attribute(start,markdone,index)
    marks[bound] = { [index] = { dx, dy, rlmode } }
    return dx, dy, bound
end

local function dir(n)
    return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or "unset"
end

local function trace(head)
    report_injections("begin run")
    for n in traverse_id(glyph_code,head) do
        if n.subtype < 256 then
            local kp = has_attribute(n,kernpair)
            local mb = has_attribute(n,markbase)
            local mm = has_attribute(n,markmark)
            local md = has_attribute(n,markdone)
            local cb = has_attribute(n,cursbase)
            local cc = has_attribute(n,curscurs)
            report_injections("char U+%05X, font=%s",n.char,n.font)
            if kp then
                local k = kerns[kp]
                if k[3] then
                    report_injections("  pairkern: dir=%s, x=%s, y=%s, w=%s, h=%s",dir(k[1]),k[2] or "?",k[3] or "?",k[4] or "?",k[5] or "?")
                else
                    report_injections("  kern: dir=%s, dx=%s",dir(k[1]),k[2] or "?")
                end
            end
            if mb then
                report_injections("  markbase: bound=%s",mb)
            end
            if mm then
                local m = marks[mm]
                if mb then
                    local m = m[mb]
                    if m then
                        report_injections("  markmark: bound=%s, index=%s, dx=%s, dy=%s",mm,md or "?",m[1] or "?",m[2] or "?")
                    else
                        report_injections("  markmark: bound=%s, missing index",mm)
                    end
                else
                    m = m[1]
                    report_injections("  markmark: bound=%s, dx=%s, dy=%s",mm,m[1] or "?",m[2] or "?")
                end
            end
            if cb then
                report_injections("  cursbase: bound=%s",cb)
            end
            if cc then
                local c = cursives[cc]
                report_injections("  curscurs: bound=%s, dir=%s, dx=%s, dy=%s",cc,dir(c[1]),c[2] or "?",c[3] or "?")
            end
        end
    end
    report_injections("end run")
end

-- todo: reuse tables (i.e. no collection), but will be extra fields anyway
-- todo: check for attribute

function injections.handler(head,where,keep)
    local has_marks, has_cursives, has_kerns = next(marks), next(cursives), next(kerns)
    if has_marks or has_cursives then
--~     if has_marks or has_cursives or has_kerns then
        if trace_injections then
            trace(head)
        end
        -- in the future variant we will not copy items but refs to tables
        local done, ky, rl, valid, cx, wx, mk, nofvalid = false, { }, { }, { }, { }, { }, { }, 0
        if has_kerns then -- move outside loop
            local nf, tm = nil, nil
            for n in traverse_id(glyph_code,head) do
                if n.subtype < 256 then
                    nofvalid = nofvalid + 1
                    valid[nofvalid] = n
                    if n.font ~= nf then
                        nf = n.font
                        tm = fontdata[nf].marks
                    end
                    mk[n] = tm[n.char]
                    local k = has_attribute(n,kernpair)
                    if k then
--~ unset_attribute(k,kernpair)
                        local kk = kerns[k]
                        if kk then
                            local x, y, w, h = kk[2] or 0, kk[3] or 0, kk[4] or 0, kk[5] or 0
                            local dy = y - h
                            if dy ~= 0 then
                                ky[n] = dy
                            end
                            if w ~= 0 or x ~= 0 then
                                wx[n] = kk
                            end
                            rl[n] = kk[1] -- could move in test
                        end
                    end
                end
            end
        else
            local nf, tm = nil, nil
            for n in traverse_id(glyph_code,head) do
                if n.subtype < 256 then
                    nofvalid = nofvalid + 1
                    valid[nofvalid] = n
                    if n.font ~= nf then
                        nf = n.font
                        tm = fontdata[nf].marks
                    end
                    mk[n] = tm[n.char]
                end
            end
        end
        if nofvalid > 0 then
            -- we can assume done == true because we have cursives and marks
            local cx = { }
            if has_kerns and next(ky) then
                for n, k in next, ky do
                    n.yoffset = k
                end
            end
            -- todo: reuse t and use maxt
            if has_cursives then
                local p_cursbase, p = nil, nil
                -- since we need valid[n+1] we can also use a "while true do"
                local t, d, maxt = { }, { }, 0
                for i=1,nofvalid do -- valid == glyphs
                    local n = valid[i]
                    if not mk[n] then
                        local n_cursbase = has_attribute(n,cursbase)
                        if p_cursbase then
                            local n_curscurs = has_attribute(n,curscurs)
                            if p_cursbase == n_curscurs then
                                local c = cursives[n_curscurs]
                                if c then
                                    local rlmode, dx, dy, ws, wn = c[1], c[2], c[3], c[4], c[5]
                                    if rlmode >= 0 then
                                        dx = dx - ws
                                    else
                                        dx = dx + wn
                                    end
                                    if dx ~= 0 then
                                        cx[n] = dx
                                        rl[n] = rlmode
                                    end
                                --  if rlmode and rlmode < 0 then
                                        dy = -dy
                                --  end
                                    maxt = maxt + 1
                                    t[maxt] = p
                                    d[maxt] = dy
                                else
                                    maxt = 0
                                end
                            end
                        elseif maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                local ti = t[i]
                                ti.yoffset = ti.yoffset + ny
                            end
                            maxt = 0
                        end
                        if not n_cursbase and maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                local ti = t[i]
                                ti.yoffset = ny
                            end
                            maxt = 0
                        end
                        p_cursbase, p = n_cursbase, n
                    end
                end
                if maxt > 0 then
                    local ny = n.yoffset
                    for i=maxt,1,-1 do
                        ny = ny + d[i]
                        local ti = t[i]
                        ti.yoffset = ny
                    end
                    maxt = 0
                end
                if not keep then
                    cursives = { }
                end
            end
            if has_marks then
                for i=1,nofvalid do
                    local p = valid[i]
                    local p_markbase = has_attribute(p,markbase)
                    if p_markbase then
                        local mrks = marks[p_markbase]
                        for n in traverse_id(glyph_code,p.next) do
                            local n_markmark = has_attribute(n,markmark)
                            if p_markbase == n_markmark then
                                local index = has_attribute(n,markdone) or 1
                                local d = mrks[index]
                                if d then
                                    local rlmode = d[3]
                                    if rlmode and rlmode > 0 then
                                        -- new per 2010-10-06
                                        local k = wx[p]
                                        if k then -- maybe (d[1] - p.width) and/or + k[2]
                                            n.xoffset = p.xoffset - (p.width - d[1]) - k[2]
                                        else
                                            n.xoffset = p.xoffset - (p.width - d[1])
                                        end
                                    else
                                        local k = wx[p]
                                        if k then
                                            n.xoffset = p.xoffset - d[1] - k[2]
                                        else
                                            n.xoffset = p.xoffset - d[1]
                                        end
                                    end
                                    if mk[p] then
                                        n.yoffset = p.yoffset + d[2]
                                    else
                                        n.yoffset = n.yoffset + p.yoffset + d[2]
                                    end
                                end
                            else
                                break
                            end
                        end
                    end
                end
                if not keep then
                    marks = { }
                end
            end
            -- todo : combine
            if next(wx) then
                for n, k in next, wx do
                 -- only w can be nil, can be sped up when w == nil
                    local rl, x, w, r2l = k[1], k[2] or 0, k[4] or 0, k[6]
                    local wx = w - x
                    if r2l then
                        if wx ~= 0 then
                            insert_node_before(head,n,newkern(wx))
                        end
                        if x ~= 0 then
                            insert_node_after (head,n,newkern(x))
                        end
                    else
                        if x ~= 0 then
                            insert_node_before(head,n,newkern(x))
                        end
                        if wx ~= 0 then
                            insert_node_after(head,n,newkern(wx))
                        end
                    end
                end
            end
            if next(cx) then
                for n, k in next, cx do
                    if k ~= 0 then
                        local rln = rl[n]
                        if rln and rln < 0 then
                            insert_node_before(head,n,newkern(-k))
                        else
                            insert_node_before(head,n,newkern(k))
                        end
                    end
                end
            end
            if not keep then
                kerns = { }
            end
            return head, true
        elseif not keep then
            kerns, cursives, marks = { }, { }, { }
        end
    elseif has_kerns then
        if trace_injections then
            trace(head)
        end
        for n in traverse_id(glyph_code,head) do
            if n.subtype < 256 then
                local k = has_attribute(n,kernpair)
                if k then
                    local kk = kerns[k]
                    if kk then
                        local rl, x, y, w = kk[1], kk[2] or 0, kk[3], kk[4]
                        if y and y ~= 0 then
                            n.yoffset = y -- todo: h ?
                        end
                        if w then
                            -- copied from above
                            local r2l = kk[6]
                            local wx = w - x
                            if r2l then
                                if wx ~= 0 then
                                    insert_node_before(head,n,newkern(wx))
                                end
                                if x ~= 0 then
                                    insert_node_after (head,n,newkern(x))
                                end
                            else
                                if x ~= 0 then
                                    insert_node_before(head,n,newkern(x))
                                end
                                if wx ~= 0 then
                                    insert_node_after(head,n,newkern(wx))
                                end
                            end
                        else
                            -- simple (e.g. kernclass kerns)
                            if x ~= 0 then
                                insert_node_before(head,n,newkern(x))
                            end
                        end
                    end
                end
            end
        end
        if not keep then
            kerns = { }
        end
        return head, true
    else
        -- no tracing needed
    end
    return head, false
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The font code will be upgraded and reorganized so that we have a
-- leaner generic code base and can do more tuning for context.

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local utf = unicode.utf8
local format, serialize = string.format, table.serialize
local write_nl = texio.write_nl
local lower = string.lower
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local report_defining = logs.reporter("fonts","defining")

fontloader.totable = fontloader.to_table

-- vtf comes first
-- fix comes last

fonts = fonts or { }

-- beware, some already defined

fonts.identifiers = mark(fonts.identifiers or { }) -- fontdata
-----.characters  = mark(fonts.characters  or { }) -- chardata
-----.csnames     = mark(fonts.csnames     or { }) -- namedata
-----.quads       = mark(fonts.quads       or { }) -- quaddata

--~ fonts.identifiers[0] = { -- nullfont
--~     characters   = { },
--~     descriptions = { },
--~     name         = "nullfont",
--~ }

fonts.tfm = fonts.tfm or { }
fonts.vf  = fonts.vf  or { }
fonts.afm = fonts.afm or { }
fonts.pfb = fonts.pfb or { }
fonts.otf = fonts.otf or { }

fonts.privateoffset = 0xF0000 -- 0x10FFFF
fonts.verbose       = false   -- more verbose cache tables (will move to context namespace)

fonts.methods = fonts.methods or {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { } },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
}

fonts.initializers = fonts.initializers or {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  }
}

fonts.triggers = fonts.triggers or {
    'mode',
    'language',
    'script',
    'strategy',
}

fonts.processors = fonts.processors or {
}

fonts.analyzers = fonts.analyzers or {
    useunicodemarks = false,
}

fonts.manipulators = fonts.manipulators or {
}

fonts.tracers = fonts.tracers or {
}

fonts.typefaces = fonts.typefaces or {
}

fonts.definers                     = fonts.definers                     or { }
fonts.definers.specifiers          = fonts.definers.specifiers          or { }
fonts.definers.specifiers.synonyms = fonts.definers.specifiers.synonyms or { }

-- tracing

if not fonts.colors then

    fonts.colors = allocate {
        set   = function() end,
        reset = function() end,
    }

end

-- format identification

fonts.formats = allocate()

function fonts.fontformat(filename,default)
    local extname = lower(file.extname(filename))
    local format = fonts.formats[extname]
    if format then
        return format
    else
        report_defining("unable to determine font format for '%s'",filename)
        return default
    end
end

-- readers

fonts.tfm.readers = fonts.tfm.readers or { }

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-tfm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local next, format, match, lower, gsub = next, string.format, string.match, string.lower, string.gsub
local concat, sortedkeys, utfbyte, serialize = table.concat, table.sortedkeys, utf.byte, table.serialize

local allocate = utilities.storage.allocate

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local trace_scaling  = false  trackers.register("fonts.scaling" , function(v) trace_scaling  = v end)

local report_defining = logs.reporter("fonts","defining")

-- tfmdata has also fast access to indices and unicodes
-- to be checked: otf -> tfm -> tfmscaled
--
-- watch out: no negative depths and negative eights permitted in regular fonts

--[[ldx--
<p>Here we only implement a few helper functions.</p>
--ldx]]--

local fonts = fonts
local tfm   = fonts.tfm

fonts.loaded              = allocate()
fonts.dontembed           = allocate()
fonts.triggers            = fonts.triggers or { } -- brrr
fonts.initializers        = fonts.initializers or { }
fonts.initializers.common = fonts.initializers.common or { }

local set_attribute = node.set_attribute
local findbinfile   = resolvers.findbinfile

local readers    = fonts.tfm.readers
local fontdata   = fonts.identifiers
local nodecodes  = nodes.nodecodes

local disc_code  = nodecodes.disc
local glyph_code = nodecodes.glyph

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

tfm.resolvevirtualtoo = true  -- false
tfm.sharebasekerns    = false -- true (.5 sec slower on mk but brings down mem from 410M to 310M, beware: then script/lang share too)
tfm.mathactions       = { }
tfm.fontnamemode      = "fullpath"

tfm.enhance = tfm.enhance or function() end

local function read_from_tfm(specification)
    local fname, tfmdata = specification.filename or "", nil
    if fname ~= "" then
        if trace_defining then
            report_defining("loading tfm file %s at size %s",fname,specification.size)
        end
        tfmdata = font.read_tfm(fname,specification.size) -- not cached, fast enough
        if tfmdata then
            tfmdata.descriptions = tfmdata.descriptions or { }
            if tfm.resolvevirtualtoo then
                fonts.logger.save(tfmdata,file.extname(fname),specification) -- strange, why here
                fname = findbinfile(specification.name, 'ovf')
                if fname and fname ~= "" then
                    local vfdata = font.read_vf(fname,specification.size) -- not cached, fast enough
                    if vfdata then
                        local chars = tfmdata.characters
                        for k,v in next, vfdata.characters do
                            chars[k].commands = v.commands
                        end
                        tfmdata.type = 'virtual'
                        tfmdata.fonts = vfdata.fonts
                    end
                end
            end
            tfm.enhance(tfmdata,specification)
        end
    elseif trace_defining then
        report_defining("loading tfm with name %s fails",specification.name)
    end
    return tfmdata
end

--[[ldx--
<p>We need to normalize the scale factor (in scaled points). This has to
do with the fact that <l n='tex'/> uses a negative multiple of 1000 as
a signal for a font scaled based on the design size.</p>
--ldx]]--

local factors = {
    pt = 65536.0,
    bp = 65781.8,
}

function tfm.setfactor(f)
    tfm.factor = factors[f or 'pt'] or factors.pt
end

tfm.setfactor()

function tfm.scaled(scaledpoints, designsize) -- handles designsize in sp as well
    if scaledpoints < 0 then
        if designsize then
            if designsize > tfm.factor then -- or just 1000 / when? mp?
                return (- scaledpoints/1000) * designsize -- sp's
            else
                return (- scaledpoints/1000) * designsize * tfm.factor
            end
        else
            return (- scaledpoints/1000) * 10 * tfm.factor
        end
    else
        return scaledpoints
    end
end

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

--~ function tfm.getvirtualid(tfmdata)
--~     --  since we don't know the id yet, we use 0 as signal
--~     local tf = tfmdata.fonts
--~     if not tf then
--~         tfmdata.type = "virtual"
--~         tfmdata.fonts = { { id = 0 } }
--~         return 1
--~     else
--~         local ntf = #tf + 1
--~         tf[ntf] = { id = 0 }
--~         return ntf
--~     end
--~ end

function tfm.getvirtualid(tfmdata)
    --  since we don't know the id yet, we use 0 as signal
    local tf = tfmdata.fonts
    if not tf then
        tf = { }
        tfmdata.type = "virtual"
        tfmdata.fonts = tf
    end
    local ntf = #tf + 1
    tf[ntf] = { id = 0 }
    return ntf
end

function tfm.checkvirtualid(tfmdata, id)
    if tfmdata and tfmdata.type == "virtual" then
        if not tfmdata.fonts or #tfmdata.fonts == 0 then
            tfmdata.type, tfmdata.fonts = "real", nil
        else
            local vfonts = tfmdata.fonts
            for f=1,#vfonts do
                local fnt = vfonts[f]
                if fnt.id and fnt.id == 0 then
                    fnt.id = id
                end
            end
        end
    end
end

--[[ldx--
<p>Beware, the boundingbox is passed as reference so we may not overwrite it
in the process; numbers are of course copies. Here 65536 equals 1pt. (Due to
excessive memory usage in CJK fonts, we no longer pass the boundingbox.)</p>
--ldx]]--

fonts.trace_scaling = false

-- the following hack costs a bit of runtime but safes memory
--
-- basekerns are scaled and will be hashed by table id
-- sharedkerns are unscaled and are be hashed by concatenated indexes

--~ function tfm.check_base_kerns(tfmdata)
--~     if tfm.sharebasekerns then
--~         local sharedkerns = tfmdata.sharedkerns
--~         if sharedkerns then
--~             local basekerns = { }
--~             tfmdata.basekerns = basekerns
--~             return sharedkerns, basekerns
--~         end
--~     end
--~     return nil, nil
--~ end

--~ function tfm.prepare_base_kerns(tfmdata)
--~     if tfm.sharebasekerns and not tfmdata.sharedkerns then
--~         local sharedkerns = { }
--~         tfmdata.sharedkerns = sharedkerns
--~         for u, chr in next, tfmdata.characters do
--~             local kerns = chr.kerns
--~             if kerns then
--~                 local hash = concat(sortedkeys(kerns), " ")
--~                 local base = sharedkerns[hash]
--~                 if not base then
--~                     sharedkerns[hash] = kerns
--~                 else
--~                     chr.kerns = base
--~                 end
--~             end
--~         end
--~     end
--~ end

-- we can have cache scaled characters when we are in node mode and don't have
-- protruding and expansion: hash == fullname @ size @ protruding @ expansion
-- but in practice (except from mk) the otf hash will be enough already so it
-- makes no sense to mess  up the code now

local charactercache = { }

-- The scaler is only used for otf and afm and virtual fonts. If
-- a virtual font has italic correction make sure to set the
-- has_italic flag. Some more flags will be added in the future.

--[[ldx--
<p>The reason why the scaler was originally split, is that for a while we experimented
with a helper function. However, in practice the <l n='api'/> calls are too slow to
make this profitable and the <l n='lua'/> based variant was just faster. A days
wasted day but an experience richer.</p>
--ldx]]--

tfm.autocleanup = true

local lastfont = nil

-- we can get rid of the tfm instance when we have fast access to the
-- scaled character dimensions at the tex end, e.g. a fontobject.width
--
-- flushing the kern and ligature tables from memory saves a lot (only
-- base mode) but it complicates vf building where the new characters
-- demand this data .. solution: functions that access them

-- we don't need the glyph data as we can use the description .. but we will
-- have to wait till we can access the internal tfm table efficiently in which
-- case characters will become a metatable afterwards

function tfm.cleanuptable(tfmdata) -- we need a cleanup callback, now we miss the last one
    if tfm.autocleanup then  -- ok, we can hook this into everyshipout or so ... todo
        if tfmdata.type == 'virtual' or tfmdata.virtualized then
            for k, v in next, tfmdata.characters do
                if v.commands then v.commands = nil end
            --  if v.kerns    then v.kerns    = nil end
            end
        else
        --  for k, v in next, tfmdata.characters do
        --     if v.kerns    then v.kerns    = nil end
        --  end
        end
    end
end

function tfm.cleanup(tfmdata) -- we need a cleanup callback, now we miss the last one
end

function tfm.calculatescale(tfmtable, scaledpoints)
    if scaledpoints < 0 then
        scaledpoints = (- scaledpoints/1000) * tfmtable.designsize -- already in sp
    end
    local units = tfmtable.units or 1000
    local delta = scaledpoints/units -- brr, some open type fonts have 2048
    return scaledpoints, delta, units
end

function tfm.scale(tfmtable, scaledpoints, relativeid)
 -- tfm.prepare_base_kerns(tfmtable) -- optimalization
    local t = { } -- the new table
    local scaledpoints, delta, units = tfm.calculatescale(tfmtable, scaledpoints, relativeid)
    -- is just a trigger for the backend
    t.units_per_em = units or 1000
    --
    local hdelta, vdelta = delta, delta
    -- unicoded unique descriptions shared cidinfo characters changed parameters indices
    for k,v in next, tfmtable do
        if type(v) == "table" then
        --  print(k)
        else
            t[k] = v
        end
    end
    local extend_factor = tfmtable.extend_factor or 0
    if extend_factor ~= 0 and extend_factor ~= 1 then
        hdelta = hdelta * extend_factor
        t.extend = extend_factor * 1000
    else
        t.extend = 1000
    end
    local slant_factor = tfmtable.slant_factor or 0
    if slant_factor ~= 0 then
        t.slant = slant_factor * 1000
    else
        t.slant = 0
    end
    -- status
    local isvirtual = tfmtable.type == "virtual" or tfmtable.virtualized
    local hasmath = (tfmtable.mathparameters ~= nil and next(tfmtable.mathparameters) ~= nil) or (tfmtable.MathConstants ~= nil and next(tfmtable.MathConstants) ~= nil)
    local nodemode = tfmtable.mode == "node"
    local hasquality = tfmtable.auto_expand or tfmtable.auto_protrude
    local hasitalic = tfmtable.has_italic
    local descriptions = tfmtable.descriptions or { }
    --
    if hasmath then
        t.has_math = true -- this will move to elsewhere
    end
    --
    t.parameters = { }
    t.characters = { }
    t.MathConstants = { }
    -- fast access
    t.unscaled = tfmtable -- the original unscaled one (temp)
    t.unicodes = tfmtable.unicodes
    t.indices = tfmtable.indices
    t.marks = tfmtable.marks
    -- this will move to some subtable so that it is copied at once
    t.goodies = tfmtable.goodies
    t.colorscheme = tfmtable.colorscheme
    t.postprocessors = tfmtable.postprocessors
    --
 -- t.embedding = tfmtable.embedding
    t.descriptions = descriptions
    if tfmtable.fonts then
        t.fonts = table.fastcopy(tfmtable.fonts) -- hm  also at the end
    end
    local tp = t.parameters
    local mp = t.mathparameters
    local tfmp = tfmtable.parameters -- let's check for indexes
    --
    tp.slant         = (tfmp.slant         or tfmp[1] or 0)
    tp.space         = (tfmp.space         or tfmp[2] or 0)*hdelta
    tp.space_stretch = (tfmp.space_stretch or tfmp[3] or 0)*hdelta
    tp.space_shrink  = (tfmp.space_shrink  or tfmp[4] or 0)*hdelta
    tp.x_height      = (tfmp.x_height      or tfmp[5] or 0)*vdelta
    tp.quad          = (tfmp.quad          or tfmp[6] or 0)*hdelta
    tp.extra_space   = (tfmp.extra_space   or tfmp[7] or 0)*hdelta
    local protrusionfactor = (tp.quad ~= 0 and 1000/tp.quad) or 0
    local tc = t.characters
    local characters = tfmtable.characters
    local nameneeded = not tfmtable.shared.otfdata --hack
    local changed = tfmtable.changed or { } -- for base mode
    local ischanged = changed and next(changed)
    local indices = tfmtable.indices
    local luatex = tfmtable.luatex
    local tounicode = luatex and luatex.tounicode
    local defaultwidth  = luatex and luatex.defaultwidth  or 0
    local defaultheight = luatex and luatex.defaultheight or 0
    local defaultdepth  = luatex and luatex.defaultdepth  or 0
    -- experimental, sharing kerns (unscaled and scaled) saves memory
    -- local sharedkerns, basekerns = tfm.check_base_kerns(tfmtable)
    -- loop over descriptions (afm and otf have descriptions, tfm not)
    -- there is no need (yet) to assign a value to chr.tonunicode
    local scaledwidth  = defaultwidth  * hdelta
    local scaledheight = defaultheight * vdelta
    local scaleddepth  = defaultdepth  * vdelta
    local stackmath = tfmtable.ignore_stack_math ~= true
    local private = fonts.privateoffset
    local sharedkerns = { }
    for k,v in next, characters do
        local chr, description, index
        if ischanged then
            -- basemode hack
            local c = changed[k]
            if c then
                description = descriptions[c] or v
                v = characters[c] or v
                index = (indices and indices[c]) or c
            else
                description = descriptions[k] or v
                index = (indices and indices[k]) or k
            end
        else
            description = descriptions[k] or v
            index = (indices and indices[k]) or k
        end
        local width  = description.width
        local height = description.height
        local depth  = description.depth
        if width  then width  = hdelta*width  else width  = scaledwidth  end
        if height then height = vdelta*height else height = scaledheight end
    --  if depth  then depth  = vdelta*depth  else depth  = scaleddepth  end
        if depth and depth ~= 0 then
            depth = delta*depth
            if nameneeded then
                chr = {
                    name   = description.name,
                    index  = index,
                    height = height,
                    depth  = depth,
                    width  = width,
                }
            else
                chr = {
                    index  = index,
                    height = height,
                    depth  = depth,
                    width  = width,
                }
            end
        else
            -- this saves a little bit of memory time and memory, esp for big cjk fonts
            if nameneeded then
                chr = {
                    name   = description.name,
                    index  = index,
                    height = height,
                    width  = width,
                }
            else
                chr = {
                    index  = index,
                    height = height,
                    width  = width,
                }
            end
        end
    --  if trace_scaling then
    --    report_defining("t=%s, u=%s, i=%s, n=%s c=%s",k,chr.tounicode or "",index or 0,description.name or '-',description.class or '-')
    --  end
        if tounicode then
            local tu = tounicode[index] -- nb: index!
            if tu then
                chr.tounicode = tu
            end
        end
        if hasquality then
            -- we could move these calculations elsewhere (saves calculations)
            local ve = v.expansion_factor
            if ve then
                chr.expansion_factor = ve*1000 -- expansionfactor, hm, can happen elsewhere
            end
            local vl = v.left_protruding
            if vl then
                chr.left_protruding  = protrusionfactor*width*vl
            end
            local vr = v.right_protruding
            if vr then
                chr.right_protruding  = protrusionfactor*width*vr
            end
        end
        -- todo: hasitalic
        if hasitalic then
            local vi = description.italic or v.italic
            if vi and vi ~= 0 then
                chr.italic = vi*hdelta
            end
        end
        -- to be tested
        if hasmath then
            -- todo, just operate on descriptions.math
            local vn = v.next
            if vn then
                chr.next = vn
            --~ if v.vert_variants or v.horiz_variants then
            --~     report_defining("glyph 0x%05X has combination of next, vert_variants and horiz_variants",index)
            --~ end
            else
                local vv = v.vert_variants
                if vv then
                    local t = { }
                    for i=1,#vv do
                        local vvi = vv[i]
                        t[i] = {
                            ["start"]    = (vvi["start"]   or 0)*vdelta,
                            ["end"]      = (vvi["end"]     or 0)*vdelta,
                            ["advance"]  = (vvi["advance"] or 0)*vdelta,
                            ["extender"] =  vvi["extender"],
                            ["glyph"]    =  vvi["glyph"],
                        }
                    end
                    chr.vert_variants = t
                --~ local ic = v.vert_italic_correction
                --~ if ic then
                --~     chr.italic = ic * hdelta
                --~     print(format("0x%05X -> %s",k,chr.italic))
                --~ end
                else
                    local hv = v.horiz_variants
                    if hv then
                        local t = { }
                        for i=1,#hv do
                            local hvi = hv[i]
                            t[i] = {
                                ["start"]    = (hvi["start"]   or 0)*hdelta,
                                ["end"]      = (hvi["end"]     or 0)*hdelta,
                                ["advance"]  = (hvi["advance"] or 0)*hdelta,
                                ["extender"] =  hvi["extender"],
                                ["glyph"]    =  hvi["glyph"],
                            }
                        end
                        chr.horiz_variants = t
                    end
                end
            end
            local vt = description.top_accent
            if vt then
                chr.top_accent = vdelta*vt
            end
            if stackmath then
                local mk = v.mathkerns
                if mk then
                    local kerns = { }
                    local v = mk.top_right    if v then local k = { } for i=1,#v do local vi = v[i]
                        k[i] = { height = vdelta*vi.height, kern = vdelta*vi.kern }
                    end     kerns.top_right    = k end
                    local v = mk.top_left     if v then local k = { } for i=1,#v do local vi = v[i]
                        k[i] = { height = vdelta*vi.height, kern = vdelta*vi.kern }
                    end     kerns.top_left     = k end
                    local v = mk.bottom_left  if v then local k = { } for i=1,#v do local vi = v[i]
                        k[i] = { height = vdelta*vi.height, kern = vdelta*vi.kern }
                    end     kerns.bottom_left  = k end
                    local v = mk.bottom_right if v then local k = { } for i=1,#v do local vi = v[i]
                        k[i] = { height = vdelta*vi.height, kern = vdelta*vi.kern }
                    end     kerns.bottom_right = k end
                    chr.mathkern = kerns -- singular
                end
            end
        end
        if not nodemode then
            local vk = v.kerns
            if vk then
            --~ if sharedkerns then
            --~     local base = basekerns[vk] -- hashed by table id, not content
            --~     if not base then
            --~         base = {}
            --~         for k,v in next, vk do base[k] = v*hdelta end
            --~         basekerns[vk] = base
            --~     end
            --~     chr.kerns = base
            --~ else
            --~     local tt = {}
            --~     for k,v in next, vk do tt[k] = v*hdelta end
            --~     chr.kerns = tt
            --~ end
                local s = sharedkerns[vk]
                if not s then
                    s = { }
                    for k,v in next, vk do s[k] = v*hdelta end
                    sharedkerns[vk] = s
                end
                chr.kerns = s
            end
            local vl = v.ligatures
            if vl then
                if true then
                    chr.ligatures = vl -- shared
                else
                    local tt = { }
                    for i,l in next, vl do
                        tt[i] = l
                    end
                    chr.ligatures = tt
                end
            end
        end
        if isvirtual then
            local vc = v.commands
            if vc then
                -- we assume non scaled commands here
                -- tricky .. we need to scale pseudo math glyphs too
                -- which is why we deal with rules too
                local ok = false
                for i=1,#vc do
                    local key = vc[i][1]
                    if key == "right" or key == "down" then
                        ok = true
                        break
                    end
                end
                if ok then
                    local tt = { }
                    for i=1,#vc do
                        local ivc = vc[i]
                        local key = ivc[1]
                        if key == "right" then
                            tt[i] = { key, ivc[2]*hdelta }
                        elseif key == "down" then
                            tt[i] = { key, ivc[2]*vdelta }
                        elseif key == "rule" then
                            tt[i] = { key, ivc[2]*vdelta, ivc[3]*hdelta }
                        else -- not comment
                            tt[i] = ivc -- shared since in cache and untouched
                        end
                    end
                    chr.commands = tt
                else
                    chr.commands = vc
                end
                chr.index = nil
            end
        end
        tc[k] = chr
    end
    -- t.encodingbytes, t.filename, t.fullname, t.name: elsewhere
    t.size = scaledpoints
    t.factor = delta
    t.hfactor = hdelta
    t.vfactor = vdelta
    if t.fonts then
        t.fonts = table.fastcopy(t.fonts) -- maybe we virtualize more afterwards
    end
    if hasmath then
     -- mathematics.extras.copy(t) -- can be done elsewhere if needed
        local ma = tfm.mathactions
        for i=1,#ma do
            ma[i](t,tfmtable,delta,hdelta,vdelta) -- what delta?
        end
    end
    -- needed for \high cum suis
    local tpx = tp.x_height
    if hasmath then
        if not tp[13] then tp[13] = .86*tpx end  -- mathsupdisplay
        if not tp[14] then tp[14] = .86*tpx end  -- mathsupnormal
        if not tp[15] then tp[15] = .86*tpx end  -- mathsupcramped
        if not tp[16] then tp[16] = .48*tpx end  -- mathsubnormal
        if not tp[17] then tp[17] = .48*tpx end  -- mathsubcombined
        if not tp[22] then tp[22] =   0     end  -- mathaxisheight
        if t.MathConstants then t.MathConstants.AccentBaseHeight = nil end -- safeguard
    end
    t.tounicode = 1
    t.cidinfo = tfmtable.cidinfo
    -- we have t.name=metricfile and t.fullname=RealName and t.filename=diskfilename
    -- when collapsing fonts, luatex looks as both t.name and t.fullname as ttc files
    -- can have multiple subfonts
    if hasmath then
        if trace_defining then
            report_defining("math enabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
        end
    else
        if trace_defining then
            report_defining("math disabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
        end
        t.nomath, t.MathConstants = true, nil
    end
    if not t.psname then
     -- name used in pdf file as well as for selecting subfont in ttc/dfont
        t.psname = t.fontname or (t.fullname and fonts.names.cleanname(t.fullname))
    end
    if trace_defining then
        report_defining("used for accessing (sub)font: '%s'",t.psname or "nopsname")
        report_defining("used for subsetting: '%s'",t.fontname or "nofontname")
    end
    -- this will move up (side effect of merging split call)
    t.factor    = delta
    t.ascender  = delta*(tfmtable.ascender  or 0)
    t.descender = delta*(tfmtable.descender or 0)
    t.shared    = tfmtable.shared or { }
    t.unique    = table.fastcopy(tfmtable.unique or {})
    tfm.cleanup(t)
 -- print(t.fontname,table.serialize(t.MathConstants))
    return t
end

--[[ldx--
<p>Analyzers run per script and/or language and are needed in order to
process features right.</p>
--ldx]]--

fonts.analyzers        = fonts.analyzers or { }
local analyzers        = fonts.analyzers

analyzers.aux          = analyzers.aux or { }
analyzers.methods      = analyzers.methods or { }
analyzers.initializers = analyzers.initializers or { }

-- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
-- e.g. latin -> hyphenate, arab -> 1/2/3 analyze

-- an example analyzer (should move to font-ota.lua)

local state = attributes.private('state')

function analyzers.aux.setstate(head,font)
    local useunicodemarks  = analyzers.useunicodemarks
    local tfmdata = fontdata[font]
    local characters = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
    while current do
        local id = current.id
        if id == glyph_code and current.font == font then
            local char = current.char
            local d = descriptions[char]
            if d then
                if d.class == "mark" or (useunicodemarks and categories[char] == "mn") then
                    done = true
                    set_attribute(current,state,5) -- mark
                elseif n == 0 then
                    first, last, n = current, current, 1
                    set_attribute(current,state,1) -- init
                else
                    last, n = current, n+1
                    set_attribute(current,state,2) -- medi
                end
            else -- finish
                if first and first == last then
                    set_attribute(last,state,4) -- isol
                elseif last then
                    set_attribute(last,state,3) -- fina
                end
                first, last, n = nil, nil, 0
            end
        elseif id == disc_code then
            -- always in the middle
            set_attribute(current,state,2) -- midi
            last = current
        else -- finish
            if first and first == last then
                set_attribute(last,state,4) -- isol
            elseif last then
                set_attribute(last,state,3) -- fina
            end
            first, last, n = nil, nil, 0
        end
        current = current.next
    end
    if first and first == last then
        set_attribute(last,state,4) -- isol
    elseif last then
        set_attribute(last,state,3) -- fina
    end
    return head, done
end

function tfm.replacements(tfm,value)
 -- tfm.characters[0x0022] = table.fastcopy(tfm.characters[0x201D])
 -- tfm.characters[0x0027] = table.fastcopy(tfm.characters[0x2019])
 -- tfm.characters[0x0060] = table.fastcopy(tfm.characters[0x2018])
 -- tfm.characters[0x0022] = tfm.characters[0x201D]
    tfm.characters[0x0027] = tfm.characters[0x2019]
 -- tfm.characters[0x0060] = tfm.characters[0x2018]
end

-- checking

function tfm.checkedfilename(metadata,whatever)
    local foundfilename = metadata.foundfilename
    if not foundfilename then
        local askedfilename = metadata.filename or ""
        if askedfilename ~= "" then
            askedfilename = resolvers.resolve(askedfilename) -- no shortcut
            foundfilename = findbinfile(askedfilename,"") or ""
            if foundfilename == "" then
                report_defining("source file '%s' is not found",askedfilename)
                foundfilename = findbinfile(file.basename(askedfilename),"") or ""
                if foundfilename ~= "" then
                    report_defining("using source file '%s' (cache mismatch)",foundfilename)
                end
            end
        elseif whatever then
            report_defining("no source file for '%s'",whatever)
            foundfilename = ""
        end
        metadata.foundfilename = foundfilename
    --  report_defining("using source file '%s'",foundfilename)
    end
    return foundfilename
end

-- status info

statistics.register("fonts load time", function()
    return statistics.elapsedseconds(fonts)
end)

-- readers

fonts.formats.tfm = "type1" -- we need to have at least a value here

local function check_tfm(specification,fullname)
    -- ofm directive blocks local path search unless set; btw, in context we
    -- don't support ofm files anyway as this format is obsolete
    local foundname = findbinfile(fullname, 'tfm') or "" -- just to be sure
    if foundname == "" then
        foundname = findbinfile(fullname, 'ofm') or "" -- bonus for usage outside context
    end
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"tfm")
    end
    if foundname ~= "" then
        specification.filename, specification.format = foundname, "ofm"
        return read_from_tfm(specification)
    end
end

readers.check_tfm = check_tfm

function readers.tfm(specification)
    local fullname, tfmtable = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmtable = check_tfm(specification,specification.name .. "." .. forced)
        end
        if not tfmtable then
            tfmtable = check_tfm(specification,specification.name)
        end
    else
        tfmtable = check_tfm(specification,fullname)
    end
    return tfmtable
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-cid'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (cidmaps)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, match, lower = string.format, string.match, string.lower
local tonumber = tonumber
local lpegmatch = lpeg.match

local trace_loading = false  trackers.register("otf.loading",      function(v) trace_loading      = v end)

local report_otf = logs.reporter("fonts","otf loading")

local fonts   = fonts

fonts.cid     = fonts.cid or { }
local cid     = fonts.cid
cid.map       = cid.map or { }
cid.max       = cid.max or 10

-- original string parser: 0.109, lpeg parser: 0.036 seconds for Adobe-CNS1-4.cidmap
--
-- 18964 18964 (leader)
-- 0 /.notdef
-- 1..95 0020
-- 99 3000

local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C

local number  = C(R("09","af","AF")^1)
local space   = S(" \n\r\t")
local spaces  = space^0
local period  = P(".")
local periods = period * period
local name    = P("/") * C((1-space)^1)

local unicodes, names = { }, { }

local function do_one(a,b)
    unicodes[tonumber(a)] = tonumber(b,16)
end

local function do_range(a,b,c)
    c = tonumber(c,16)
    for i=tonumber(a),tonumber(b) do
        unicodes[i] = c
        c = c + 1
    end
end

local function do_name(a,b)
    names[tonumber(a)] = b
end

local grammar = lpeg.P { "start",
    start  = number * spaces * number * lpeg.V("series"),
    series = (spaces * (lpeg.V("one") + lpeg.V("range") + lpeg.V("named")) )^1,
    one    = (number * spaces  * number) / do_one,
    range  = (number * periods * number * spaces * number) / do_range,
    named  = (number * spaces  * name) / do_name
}

function cid.load(filename)
    local data = io.loaddata(filename)
    if data then
        unicodes, names = { }, { }
        lpegmatch(grammar,data)
        local supplement, registry, ordering = match(filename,"^(.-)%-(.-)%-()%.(.-)$")
        return {
            supplement = supplement,
            registry   = registry,
            ordering   = ordering,
            filename   = filename,
            unicodes   = unicodes,
            names      = names
        }
    else
        return nil
    end
end

local template = "%s-%s-%s.cidmap"

local function locate(registry,ordering,supplement)
    local filename = format(template,registry,ordering,supplement)
    local hashname = lower(filename)
    local cidmap = cid.map[hashname]
    if not cidmap then
        if trace_loading then
            report_otf("checking cidmap, registry: %s, ordering: %s, supplement: %s, filename: %s",registry,ordering,supplement,filename)
        end
        local fullname = resolvers.findfile(filename,'cid') or ""
        if fullname ~= "" then
            cidmap = cid.load(fullname)
            if cidmap then
                if trace_loading then
                    report_otf("using cidmap file %s",filename)
                end
                cid.map[hashname] = cidmap
                cidmap.usedname = file.basename(filename)
                return cidmap
            end
        end
    end
    return cidmap
end

function cid.getmap(registry,ordering,supplement)
    -- cf Arthur R. we can safely scan upwards since cids are downward compatible
    local supplement = tonumber(supplement)
    if trace_loading then
        report_otf("needed cidmap, registry: %s, ordering: %s, supplement: %s",registry,ordering,supplement)
    end
    local cidmap = locate(registry,ordering,supplement)
    if not cidmap then
        local cidnum = nil
        -- next highest (alternatively we could start high)
        if supplement < cid.max then
            for supplement=supplement+1,cid.max do
                local c = locate(registry,ordering,supplement)
                if c then
                    cidmap, cidnum = c, supplement
                    break
                end
            end
        end
        -- next lowest (least worse fit)
        if not cidmap and supplement > 0 then
            for supplement=supplement-1,0,-1 do
                local c = locate(registry,ordering,supplement)
                if c then
                    cidmap, cidnum = c, supplement
                    break
                end
            end
        end
        -- prevent further lookups
        if cidmap and cidnum > 0 then
            for s=0,cidnum-1 do
                filename = format(template,registry,ordering,s)
                if not cid.map[filename] then
                    cid.map[filename] = cidmap -- copy of ref
                end
            end
        end
    end
    return cidmap
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otf'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (tables)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tonumber, tostring = type, next, tonumber, tostring
local gsub, lower, format = string.gsub, string.lower, string.format
local is_boolean = string.is_boolean

local allocate = utilities.storage.allocate

fonts          = fonts or { } -- needed for font server
local fonts    = fonts
fonts.otf      = fonts.otf or { }
local otf      = fonts.otf

otf.tables     = otf.tables or { }
local tables   = otf.tables

otf.meanings   = otf.meanings or { }
local meanings = otf.meanings

local scripts = allocate {
    ['dflt'] = 'Default',

    ['arab'] = 'Arabic',
    ['armn'] = 'Armenian',
    ['bali'] = 'Balinese',
    ['beng'] = 'Bengali',
    ['bopo'] = 'Bopomofo',
    ['brai'] = 'Braille',
    ['bugi'] = 'Buginese',
    ['buhd'] = 'Buhid',
    ['byzm'] = 'Byzantine Music',
    ['cans'] = 'Canadian Syllabics',
    ['cher'] = 'Cherokee',
    ['copt'] = 'Coptic',
    ['cprt'] = 'Cypriot Syllabary',
    ['cyrl'] = 'Cyrillic',
    ['deva'] = 'Devanagari',
    ['dsrt'] = 'Deseret',
    ['ethi'] = 'Ethiopic',
    ['geor'] = 'Georgian',
    ['glag'] = 'Glagolitic',
    ['goth'] = 'Gothic',
    ['grek'] = 'Greek',
    ['gujr'] = 'Gujarati',
    ['guru'] = 'Gurmukhi',
    ['hang'] = 'Hangul',
    ['hani'] = 'CJK Ideographic',
    ['hano'] = 'Hanunoo',
    ['hebr'] = 'Hebrew',
    ['ital'] = 'Old Italic',
    ['jamo'] = 'Hangul Jamo',
    ['java'] = 'Javanese',
    ['kana'] = 'Hiragana and Katakana',
    ['khar'] = 'Kharosthi',
    ['khmr'] = 'Khmer',
    ['knda'] = 'Kannada',
    ['lao' ] = 'Lao',
    ['latn'] = 'Latin',
    ['limb'] = 'Limbu',
    ['linb'] = 'Linear B',
    ['math'] = 'Mathematical Alphanumeric Symbols',
    ['mlym'] = 'Malayalam',
    ['mong'] = 'Mongolian',
    ['musc'] = 'Musical Symbols',
    ['mymr'] = 'Myanmar',
    ['nko' ] = "N'ko",
    ['ogam'] = 'Ogham',
    ['orya'] = 'Oriya',
    ['osma'] = 'Osmanya',
    ['phag'] = 'Phags-pa',
    ['phnx'] = 'Phoenician',
    ['runr'] = 'Runic',
    ['shaw'] = 'Shavian',
    ['sinh'] = 'Sinhala',
    ['sylo'] = 'Syloti Nagri',
    ['syrc'] = 'Syriac',
    ['tagb'] = 'Tagbanwa',
    ['tale'] = 'Tai Le',
    ['talu'] = 'Tai Lu',
    ['taml'] = 'Tamil',
    ['telu'] = 'Telugu',
    ['tfng'] = 'Tifinagh',
    ['tglg'] = 'Tagalog',
    ['thaa'] = 'Thaana',
    ['thai'] = 'Thai',
    ['tibt'] = 'Tibetan',
    ['ugar'] = 'Ugaritic Cuneiform',
    ['xpeo'] = 'Old Persian Cuneiform',
    ['xsux'] = 'Sumero-Akkadian Cuneiform',
    ['yi'  ] = 'Yi',
}

local languages = allocate {
    ['dflt'] = 'Default',

    ['aba'] = 'Abaza',
    ['abk'] = 'Abkhazian',
    ['ady'] = 'Adyghe',
    ['afk'] = 'Afrikaans',
    ['afr'] = 'Afar',
    ['agw'] = 'Agaw',
    ['als'] = 'Alsatian',
    ['alt'] = 'Altai',
    ['amh'] = 'Amharic',
    ['ara'] = 'Arabic',
    ['ari'] = 'Aari',
    ['ark'] = 'Arakanese',
    ['asm'] = 'Assamese',
    ['ath'] = 'Athapaskan',
    ['avr'] = 'Avar',
    ['awa'] = 'Awadhi',
    ['aym'] = 'Aymara',
    ['aze'] = 'Azeri',
    ['bad'] = 'Badaga',
    ['bag'] = 'Baghelkhandi',
    ['bal'] = 'Balkar',
    ['bau'] = 'Baule',
    ['bbr'] = 'Berber',
    ['bch'] = 'Bench',
    ['bcr'] = 'Bible Cree',
    ['bel'] = 'Belarussian',
    ['bem'] = 'Bemba',
    ['ben'] = 'Bengali',
    ['bgr'] = 'Bulgarian',
    ['bhi'] = 'Bhili',
    ['bho'] = 'Bhojpuri',
    ['bik'] = 'Bikol',
    ['bil'] = 'Bilen',
    ['bkf'] = 'Blackfoot',
    ['bli'] = 'Balochi',
    ['bln'] = 'Balante',
    ['blt'] = 'Balti',
    ['bmb'] = 'Bambara',
    ['bml'] = 'Bamileke',
    ['bos'] = 'Bosnian',
    ['bre'] = 'Breton',
    ['brh'] = 'Brahui',
    ['bri'] = 'Braj Bhasha',
    ['brm'] = 'Burmese',
    ['bsh'] = 'Bashkir',
    ['bti'] = 'Beti',
    ['cat'] = 'Catalan',
    ['ceb'] = 'Cebuano',
    ['che'] = 'Chechen',
    ['chg'] = 'Chaha Gurage',
    ['chh'] = 'Chattisgarhi',
    ['chi'] = 'Chichewa',
    ['chk'] = 'Chukchi',
    ['chp'] = 'Chipewyan',
    ['chr'] = 'Cherokee',
    ['chu'] = 'Chuvash',
    ['cmr'] = 'Comorian',
    ['cop'] = 'Coptic',
    ['cos'] = 'Corsican',
    ['cre'] = 'Cree',
    ['crr'] = 'Carrier',
    ['crt'] = 'Crimean Tatar',
    ['csl'] = 'Church Slavonic',
    ['csy'] = 'Czech',
    ['dan'] = 'Danish',
    ['dar'] = 'Dargwa',
    ['dcr'] = 'Woods Cree',
    ['deu'] = 'German',
    ['dgr'] = 'Dogri',
    ['div'] = 'Divehi',
    ['djr'] = 'Djerma',
    ['dng'] = 'Dangme',
    ['dnk'] = 'Dinka',
    ['dri'] = 'Dari',
    ['dun'] = 'Dungan',
    ['dzn'] = 'Dzongkha',
    ['ebi'] = 'Ebira',
    ['ecr'] = 'Eastern Cree',
    ['edo'] = 'Edo',
    ['efi'] = 'Efik',
    ['ell'] = 'Greek',
    ['eng'] = 'English',
    ['erz'] = 'Erzya',
    ['esp'] = 'Spanish',
    ['eti'] = 'Estonian',
    ['euq'] = 'Basque',
    ['evk'] = 'Evenki',
    ['evn'] = 'Even',
    ['ewe'] = 'Ewe',
    ['fan'] = 'French Antillean',
    ['far'] = 'Farsi',
    ['fin'] = 'Finnish',
    ['fji'] = 'Fijian',
    ['fle'] = 'Flemish',
    ['fne'] = 'Forest Nenets',
    ['fon'] = 'Fon',
    ['fos'] = 'Faroese',
    ['fra'] = 'French',
    ['fri'] = 'Frisian',
    ['frl'] = 'Friulian',
    ['fta'] = 'Futa',
    ['ful'] = 'Fulani',
    ['gad'] = 'Ga',
    ['gae'] = 'Gaelic',
    ['gag'] = 'Gagauz',
    ['gal'] = 'Galician',
    ['gar'] = 'Garshuni',
    ['gaw'] = 'Garhwali',
    ['gez'] = "Ge'ez",
    ['gil'] = 'Gilyak',
    ['gmz'] = 'Gumuz',
    ['gon'] = 'Gondi',
    ['grn'] = 'Greenlandic',
    ['gro'] = 'Garo',
    ['gua'] = 'Guarani',
    ['guj'] = 'Gujarati',
    ['hai'] = 'Haitian',
    ['hal'] = 'Halam',
    ['har'] = 'Harauti',
    ['hau'] = 'Hausa',
    ['haw'] = 'Hawaiin',
    ['hbn'] = 'Hammer-Banna',
    ['hil'] = 'Hiligaynon',
    ['hin'] = 'Hindi',
    ['hma'] = 'High Mari',
    ['hnd'] = 'Hindko',
    ['ho']  = 'Ho',
    ['hri'] = 'Harari',
    ['hrv'] = 'Croatian',
    ['hun'] = 'Hungarian',
    ['hye'] = 'Armenian',
    ['ibo'] = 'Igbo',
    ['ijo'] = 'Ijo',
    ['ilo'] = 'Ilokano',
    ['ind'] = 'Indonesian',
    ['ing'] = 'Ingush',
    ['inu'] = 'Inuktitut',
    ['iri'] = 'Irish',
    ['irt'] = 'Irish Traditional',
    ['isl'] = 'Icelandic',
    ['ism'] = 'Inari Sami',
    ['ita'] = 'Italian',
    ['iwr'] = 'Hebrew',
    ['jan'] = 'Japanese',
    ['jav'] = 'Javanese',
    ['jii'] = 'Yiddish',
    ['jud'] = 'Judezmo',
    ['jul'] = 'Jula',
    ['kab'] = 'Kabardian',
    ['kac'] = 'Kachchi',
    ['kal'] = 'Kalenjin',
    ['kan'] = 'Kannada',
    ['kar'] = 'Karachay',
    ['kat'] = 'Georgian',
    ['kaz'] = 'Kazakh',
    ['keb'] = 'Kebena',
    ['kge'] = 'Khutsuri Georgian',
    ['kha'] = 'Khakass',
    ['khk'] = 'Khanty-Kazim',
    ['khm'] = 'Khmer',
    ['khs'] = 'Khanty-Shurishkar',
    ['khv'] = 'Khanty-Vakhi',
    ['khw'] = 'Khowar',
    ['kik'] = 'Kikuyu',
    ['kir'] = 'Kirghiz',
    ['kis'] = 'Kisii',
    ['kkn'] = 'Kokni',
    ['klm'] = 'Kalmyk',
    ['kmb'] = 'Kamba',
    ['kmn'] = 'Kumaoni',
    ['kmo'] = 'Komo',
    ['kms'] = 'Komso',
    ['knr'] = 'Kanuri',
    ['kod'] = 'Kodagu',
    ['koh'] = 'Korean Old Hangul',
    ['kok'] = 'Konkani',
    ['kon'] = 'Kikongo',
    ['kop'] = 'Komi-Permyak',
    ['kor'] = 'Korean',
    ['koz'] = 'Komi-Zyrian',
    ['kpl'] = 'Kpelle',
    ['kri'] = 'Krio',
    ['krk'] = 'Karakalpak',
    ['krl'] = 'Karelian',
    ['krm'] = 'Karaim',
    ['krn'] = 'Karen',
    ['krt'] = 'Koorete',
    ['ksh'] = 'Kashmiri',
    ['ksi'] = 'Khasi',
    ['ksm'] = 'Kildin Sami',
    ['kui'] = 'Kui',
    ['kul'] = 'Kulvi',
    ['kum'] = 'Kumyk',
    ['kur'] = 'Kurdish',
    ['kuu'] = 'Kurukh',
    ['kuy'] = 'Kuy',
    ['kyk'] = 'Koryak',
    ['lad'] = 'Ladin',
    ['lah'] = 'Lahuli',
    ['lak'] = 'Lak',
    ['lam'] = 'Lambani',
    ['lao'] = 'Lao',
    ['lat'] = 'Latin',
    ['laz'] = 'Laz',
    ['lcr'] = 'L-Cree',
    ['ldk'] = 'Ladakhi',
    ['lez'] = 'Lezgi',
    ['lin'] = 'Lingala',
    ['lma'] = 'Low Mari',
    ['lmb'] = 'Limbu',
    ['lmw'] = 'Lomwe',
    ['lsb'] = 'Lower Sorbian',
    ['lsm'] = 'Lule Sami',
    ['lth'] = 'Lithuanian',
    ['ltz'] = 'Luxembourgish',
    ['lub'] = 'Luba',
    ['lug'] = 'Luganda',
    ['luh'] = 'Luhya',
    ['luo'] = 'Luo',
    ['lvi'] = 'Latvian',
    ['maj'] = 'Majang',
    ['mak'] = 'Makua',
    ['mal'] = 'Malayalam Traditional',
    ['man'] = 'Mansi',
    ['map'] = 'Mapudungun',
    ['mar'] = 'Marathi',
    ['maw'] = 'Marwari',
    ['mbn'] = 'Mbundu',
    ['mch'] = 'Manchu',
    ['mcr'] = 'Moose Cree',
    ['mde'] = 'Mende',
    ['men'] = "Me'en",
    ['miz'] = 'Mizo',
    ['mkd'] = 'Macedonian',
    ['mle'] = 'Male',
    ['mlg'] = 'Malagasy',
    ['mln'] = 'Malinke',
    ['mlr'] = 'Malayalam Reformed',
    ['mly'] = 'Malay',
    ['mnd'] = 'Mandinka',
    ['mng'] = 'Mongolian',
    ['mni'] = 'Manipuri',
    ['mnk'] = 'Maninka',
    ['mnx'] = 'Manx Gaelic',
    ['moh'] = 'Mohawk',
    ['mok'] = 'Moksha',
    ['mol'] = 'Moldavian',
    ['mon'] = 'Mon',
    ['mor'] = 'Moroccan',
    ['mri'] = 'Maori',
    ['mth'] = 'Maithili',
    ['mts'] = 'Maltese',
    ['mun'] = 'Mundari',
    ['nag'] = 'Naga-Assamese',
    ['nan'] = 'Nanai',
    ['nas'] = 'Naskapi',
    ['ncr'] = 'N-Cree',
    ['ndb'] = 'Ndebele',
    ['ndg'] = 'Ndonga',
    ['nep'] = 'Nepali',
    ['new'] = 'Newari',
    ['ngr'] = 'Nagari',
    ['nhc'] = 'Norway House Cree',
    ['nis'] = 'Nisi',
    ['niu'] = 'Niuean',
    ['nkl'] = 'Nkole',
    ['nko'] = "N'ko",
    ['nld'] = 'Dutch',
    ['nog'] = 'Nogai',
    ['nor'] = 'Norwegian',
    ['nsm'] = 'Northern Sami',
    ['nta'] = 'Northern Tai',
    ['nto'] = 'Esperanto',
    ['nyn'] = 'Nynorsk',
    ['oci'] = 'Occitan',
    ['ocr'] = 'Oji-Cree',
    ['ojb'] = 'Ojibway',
    ['ori'] = 'Oriya',
    ['oro'] = 'Oromo',
    ['oss'] = 'Ossetian',
    ['paa'] = 'Palestinian Aramaic',
    ['pal'] = 'Pali',
    ['pan'] = 'Punjabi',
    ['pap'] = 'Palpa',
    ['pas'] = 'Pashto',
    ['pgr'] = 'Polytonic Greek',
    ['pil'] = 'Pilipino',
    ['plg'] = 'Palaung',
    ['plk'] = 'Polish',
    ['pro'] = 'Provencal',
    ['ptg'] = 'Portuguese',
    ['qin'] = 'Chin',
    ['raj'] = 'Rajasthani',
    ['rbu'] = 'Russian Buriat',
    ['rcr'] = 'R-Cree',
    ['ria'] = 'Riang',
    ['rms'] = 'Rhaeto-Romanic',
    ['rom'] = 'Romanian',
    ['roy'] = 'Romany',
    ['rsy'] = 'Rusyn',
    ['rua'] = 'Ruanda',
    ['rus'] = 'Russian',
    ['sad'] = 'Sadri',
    ['san'] = 'Sanskrit',
    ['sat'] = 'Santali',
    ['say'] = 'Sayisi',
    ['sek'] = 'Sekota',
    ['sel'] = 'Selkup',
    ['sgo'] = 'Sango',
    ['shn'] = 'Shan',
    ['sib'] = 'Sibe',
    ['sid'] = 'Sidamo',
    ['sig'] = 'Silte Gurage',
    ['sks'] = 'Skolt Sami',
    ['sky'] = 'Slovak',
    ['sla'] = 'Slavey',
    ['slv'] = 'Slovenian',
    ['sml'] = 'Somali',
    ['smo'] = 'Samoan',
    ['sna'] = 'Sena',
    ['snd'] = 'Sindhi',
    ['snh'] = 'Sinhalese',
    ['snk'] = 'Soninke',
    ['sog'] = 'Sodo Gurage',
    ['sot'] = 'Sotho',
    ['sqi'] = 'Albanian',
    ['srb'] = 'Serbian',
    ['srk'] = 'Saraiki',
    ['srr'] = 'Serer',
    ['ssl'] = 'South Slavey',
    ['ssm'] = 'Southern Sami',
    ['sur'] = 'Suri',
    ['sva'] = 'Svan',
    ['sve'] = 'Swedish',
    ['swa'] = 'Swadaya Aramaic',
    ['swk'] = 'Swahili',
    ['swz'] = 'Swazi',
    ['sxt'] = 'Sutu',
    ['syr'] = 'Syriac',
    ['tab'] = 'Tabasaran',
    ['taj'] = 'Tajiki',
    ['tam'] = 'Tamil',
    ['tat'] = 'Tatar',
    ['tcr'] = 'TH-Cree',
    ['tel'] = 'Telugu',
    ['tgn'] = 'Tongan',
    ['tgr'] = 'Tigre',
    ['tgy'] = 'Tigrinya',
    ['tha'] = 'Thai',
    ['tht'] = 'Tahitian',
    ['tib'] = 'Tibetan',
    ['tkm'] = 'Turkmen',
    ['tmn'] = 'Temne',
    ['tna'] = 'Tswana',
    ['tne'] = 'Tundra Nenets',
    ['tng'] = 'Tonga',
    ['tod'] = 'Todo',
    ['trk'] = 'Turkish',
    ['tsg'] = 'Tsonga',
    ['tua'] = 'Turoyo Aramaic',
    ['tul'] = 'Tulu',
    ['tuv'] = 'Tuvin',
    ['twi'] = 'Twi',
    ['udm'] = 'Udmurt',
    ['ukr'] = 'Ukrainian',
    ['urd'] = 'Urdu',
    ['usb'] = 'Upper Sorbian',
    ['uyg'] = 'Uyghur',
    ['uzb'] = 'Uzbek',
    ['ven'] = 'Venda',
    ['vit'] = 'Vietnamese',
    ['wa' ] = 'Wa',
    ['wag'] = 'Wagdi',
    ['wcr'] = 'West-Cree',
    ['wel'] = 'Welsh',
    ['wlf'] = 'Wolof',
    ['xbd'] = 'Tai Lue',
    ['xhs'] = 'Xhosa',
    ['yak'] = 'Yakut',
    ['yba'] = 'Yoruba',
    ['ycr'] = 'Y-Cree',
    ['yic'] = 'Yi Classic',
    ['yim'] = 'Yi Modern',
    ['zhh'] = 'Chinese Hong Kong',
    ['zhp'] = 'Chinese Phonetic',
    ['zhs'] = 'Chinese Simplified',
    ['zht'] = 'Chinese Traditional',
    ['znd'] = 'Zande',
    ['zul'] = 'Zulu'
}

local features = allocate {
    ['aalt'] = 'Access All Alternates',
    ['abvf'] = 'Above-Base Forms',
    ['abvm'] = 'Above-Base Mark Positioning',
    ['abvs'] = 'Above-Base Substitutions',
    ['afrc'] = 'Alternative Fractions',
    ['akhn'] = 'Akhands',
    ['blwf'] = 'Below-Base Forms',
    ['blwm'] = 'Below-Base Mark Positioning',
    ['blws'] = 'Below-Base Substitutions',
    ['c2pc'] = 'Petite Capitals From Capitals',
    ['c2sc'] = 'Small Capitals From Capitals',
    ['calt'] = 'Contextual Alternates',
    ['case'] = 'Case-Sensitive Forms',
    ['ccmp'] = 'Glyph Composition/Decomposition',
    ['cjct'] = 'Conjunct Forms',
    ['clig'] = 'Contextual Ligatures',
    ['cpsp'] = 'Capital Spacing',
    ['cswh'] = 'Contextual Swash',
    ['curs'] = 'Cursive Positioning',
    ['dflt'] = 'Default Processing',
    ['dist'] = 'Distances',
    ['dlig'] = 'Discretionary Ligatures',
    ['dnom'] = 'Denominators',
    ['dtls'] = 'Dotless Forms', -- math
    ['expt'] = 'Expert Forms',
    ['falt'] = 'Final glyph Alternates',
    ['fin2'] = 'Terminal Forms #2',
    ['fin3'] = 'Terminal Forms #3',
    ['fina'] = 'Terminal Forms',
    ['flac'] = 'Flattened Accents Over Capitals', -- math
    ['frac'] = 'Fractions',
    ['fwid'] = 'Full Width',
    ['half'] = 'Half Forms',
    ['haln'] = 'Halant Forms',
    ['halt'] = 'Alternate Half Width',
    ['hist'] = 'Historical Forms',
    ['hkna'] = 'Horizontal Kana Alternates',
    ['hlig'] = 'Historical Ligatures',
    ['hngl'] = 'Hangul',
    ['hojo'] = 'Hojo Kanji Forms',
    ['hwid'] = 'Half Width',
    ['init'] = 'Initial Forms',
    ['isol'] = 'Isolated Forms',
    ['ital'] = 'Italics',
    ['jalt'] = 'Justification Alternatives',
    ['jp04'] = 'JIS2004 Forms',
    ['jp78'] = 'JIS78 Forms',
    ['jp83'] = 'JIS83 Forms',
    ['jp90'] = 'JIS90 Forms',
    ['kern'] = 'Kerning',
    ['lfbd'] = 'Left Bounds',
    ['liga'] = 'Standard Ligatures',
    ['ljmo'] = 'Leading Jamo Forms',
    ['lnum'] = 'Lining Figures',
    ['locl'] = 'Localized Forms',
    ['mark'] = 'Mark Positioning',
    ['med2'] = 'Medial Forms #2',
    ['medi'] = 'Medial Forms',
    ['mgrk'] = 'Mathematical Greek',
    ['mkmk'] = 'Mark to Mark Positioning',
    ['mset'] = 'Mark Positioning via Substitution',
    ['nalt'] = 'Alternate Annotation Forms',
    ['nlck'] = 'NLC Kanji Forms',
    ['nukt'] = 'Nukta Forms',
    ['numr'] = 'Numerators',
    ['onum'] = 'Old Style Figures',
    ['opbd'] = 'Optical Bounds',
    ['ordn'] = 'Ordinals',
    ['ornm'] = 'Ornaments',
    ['palt'] = 'Proportional Alternate Width',
    ['pcap'] = 'Petite Capitals',
    ['pnum'] = 'Proportional Figures',
    ['pref'] = 'Pre-base Forms',
    ['pres'] = 'Pre-base Substitutions',
    ['pstf'] = 'Post-base Forms',
    ['psts'] = 'Post-base Substitutions',
    ['pwid'] = 'Proportional Widths',
    ['qwid'] = 'Quarter Widths',
    ['rand'] = 'Randomize',
    ['rkrf'] = 'Rakar Forms',
    ['rlig'] = 'Required Ligatures',
    ['rphf'] = 'Reph Form',
    ['rtbd'] = 'Right Bounds',
    ['rtla'] = 'Right-To-Left Alternates',
    ['rtlm'] = 'Right To Left Math', -- math
    ['ruby'] = 'Ruby Notation Forms',
    ['salt'] = 'Stylistic Alternates',
    ['sinf'] = 'Scientific Inferiors',
    ['size'] = 'Optical Size',
    ['smcp'] = 'Small Capitals',
    ['smpl'] = 'Simplified Forms',
    ['ss01'] = 'Stylistic Set 1',
    ['ss02'] = 'Stylistic Set 2',
    ['ss03'] = 'Stylistic Set 3',
    ['ss04'] = 'Stylistic Set 4',
    ['ss05'] = 'Stylistic Set 5',
    ['ss06'] = 'Stylistic Set 6',
    ['ss07'] = 'Stylistic Set 7',
    ['ss08'] = 'Stylistic Set 8',
    ['ss09'] = 'Stylistic Set 9',
    ['ss10'] = 'Stylistic Set 10',
    ['ss11'] = 'Stylistic Set 11',
    ['ss12'] = 'Stylistic Set 12',
    ['ss13'] = 'Stylistic Set 13',
    ['ss14'] = 'Stylistic Set 14',
    ['ss15'] = 'Stylistic Set 15',
    ['ss16'] = 'Stylistic Set 16',
    ['ss17'] = 'Stylistic Set 17',
    ['ss18'] = 'Stylistic Set 18',
    ['ss19'] = 'Stylistic Set 19',
    ['ss20'] = 'Stylistic Set 20',
    ['ssty'] = 'Script Style', -- math
    ['subs'] = 'Subscript',
    ['sups'] = 'Superscript',
    ['swsh'] = 'Swash',
    ['titl'] = 'Titling',
    ['tjmo'] = 'Trailing Jamo Forms',
    ['tnam'] = 'Traditional Name Forms',
    ['tnum'] = 'Tabular Figures',
    ['trad'] = 'Traditional Forms',
    ['twid'] = 'Third Widths',
    ['unic'] = 'Unicase',
    ['valt'] = 'Alternate Vertical Metrics',
    ['vatu'] = 'Vattu Variants',
    ['vert'] = 'Vertical Writing',
    ['vhal'] = 'Alternate Vertical Half Metrics',
    ['vjmo'] = 'Vowel Jamo Forms',
    ['vkna'] = 'Vertical Kana Alternates',
    ['vkrn'] = 'Vertical Kerning',
    ['vpal'] = 'Proportional Alternate Vertical Metrics',
    ['vrt2'] = 'Vertical Rotation',
    ['zero'] = 'Slashed Zero',

    ['trep'] = 'Traditional TeX Replacements',
    ['tlig'] = 'Traditional TeX Ligatures',
}

local baselines = allocate {
    ['hang'] = 'Hanging baseline',
    ['icfb'] = 'Ideographic character face bottom edge baseline',
    ['icft'] = 'Ideographic character face tope edige baseline',
    ['ideo'] = 'Ideographic em-box bottom edge baseline',
    ['idtp'] = 'Ideographic em-box top edge baseline',
    ['math'] = 'Mathmatical centered baseline',
    ['romn'] = 'Roman baseline'
}


local function swap(h) -- can be a tables.swap when we get a better name
    local r = { }
    for k, v in next, h do
        r[v] = lower(gsub(k," ",""))
    end
    return r
end

local verbosescripts    = allocate(swap(scripts  ))
local verboselanguages  = allocate(swap(languages))
local verbosefeatures   = allocate(swap(features ))

tables.scripts          = scripts
tables.languages        = languages
tables.features         = features
tables.baselines        = baselines

tables.verbosescripts   = verbosescripts
tables.verboselanguages = verboselanguages
tables.verbosefeatures  = verbosefeatures

for k, v in next, verbosefeatures do
    local stripped = gsub(k,"%-"," ")
    verbosefeatures[stripped] = v
    local stripped = gsub(k,"[^a-zA-Z0-9]","")
    verbosefeatures[stripped] = v
end
for k, v in next, verbosefeatures do
    verbosefeatures[lower(k)] = v
end

local function resolve(tab,id)
    if tab and id then
        id = lower(id)
        return tab[id] or tab[gsub(id," ","")] or tab['dflt'] or ''
    else
        return "unknown"
    end
end

function meanings.script  (id) return resolve(scripts,  id) end
function meanings.language(id) return resolve(languages,id) end
function meanings.feature (id) return resolve(features, id) end
function meanings.baseline(id) return resolve(baselines,id) end

local checkers = {
    rand = function(v)
        return v and "random"
    end
}

meanings.checkers = checkers

function meanings.normalize(features)
    if features then
        local h = { }
        for k,v in next, features do
            k = lower(k)
            if k == "language" or k == "lang" then
                v = gsub(lower(v),"[^a-z0-9%-]","")
                if not languages[v] then
                    h.language = verboselanguages[v] or "dflt"
                else
                    h.language = v
                end
            elseif k == "script" then
                v = gsub(lower(v),"[^a-z0-9%-]","")
                if not scripts[v] then
                    h.script = verbosescripts[v] or "dflt"
                else
                    h.script = v
                end
            else
                if type(v) == "string" then
                    local b = is_boolean(v)
                    if type(b) == "nil" then
                        v = tonumber(v) or lower(v)
                    else
                        v = b
                    end
                end
                k = verbosefeatures[k] or k
                local c = checkers[k]
                h[k] = c and c(v) or v
            end
        end
        return h
    end
end

-- When I feel the need ...

--~ tables.aat = {
--~     [ 0] = {
--~         name = "allTypographicFeaturesType",
--~         [ 0] = "allTypeFeaturesOnSelector",
--~         [ 1] = "allTypeFeaturesOffSelector",
--~     },
--~     [ 1] = {
--~         name = "ligaturesType",
--~         [0 ] = "requiredLigaturesOnSelector",
--~         [1 ] = "requiredLigaturesOffSelector",
--~         [2 ] = "commonLigaturesOnSelector",
--~         [3 ] = "commonLigaturesOffSelector",
--~         [4 ] = "rareLigaturesOnSelector",
--~         [5 ] = "rareLigaturesOffSelector",
--~         [6 ] = "logosOnSelector    ",
--~         [7 ] = "logosOffSelector   ",
--~         [8 ] = "rebusPicturesOnSelector",
--~         [9 ] = "rebusPicturesOffSelector",
--~         [10] = "diphthongLigaturesOnSelector",
--~         [11] = "diphthongLigaturesOffSelector",
--~         [12] = "squaredLigaturesOnSelector",
--~         [13] = "squaredLigaturesOffSelector",
--~         [14] = "abbrevSquaredLigaturesOnSelector",
--~         [15] = "abbrevSquaredLigaturesOffSelector",
--~     },
--~     [ 2] = {
--~         name = "cursiveConnectionType",
--~         [ 0] = "unconnectedSelector",
--~         [ 1] = "partiallyConnectedSelector",
--~         [ 2] = "cursiveSelector    ",
--~     },
--~     [ 3] = {
--~         name = "letterCaseType",
--~         [ 0] = "upperAndLowerCaseSelector",
--~         [ 1] = "allCapsSelector    ",
--~         [ 2] = "allLowerCaseSelector",
--~         [ 3] = "smallCapsSelector  ",
--~         [ 4] = "initialCapsSelector",
--~         [ 5] = "initialCapsAndSmallCapsSelector",
--~     },
--~     [ 4] = {
--~         name = "verticalSubstitutionType",
--~         [ 0] = "substituteVerticalFormsOnSelector",
--~         [ 1] = "substituteVerticalFormsOffSelector",
--~     },
--~     [ 5] = {
--~         name = "linguisticRearrangementType",
--~         [ 0] = "linguisticRearrangementOnSelector",
--~         [ 1] = "linguisticRearrangementOffSelector",
--~     },
--~     [ 6] = {
--~         name = "numberSpacingType",
--~         [ 0] = "monospacedNumbersSelector",
--~         [ 1] = "proportionalNumbersSelector",
--~     },
--~     [ 7] = {
--~         name = "appleReserved1Type",
--~     },
--~     [ 8] = {
--~         name = "smartSwashType",
--~         [ 0] = "wordInitialSwashesOnSelector",
--~         [ 1] = "wordInitialSwashesOffSelector",
--~         [ 2] = "wordFinalSwashesOnSelector",
--~         [ 3] = "wordFinalSwashesOffSelector",
--~         [ 4] = "lineInitialSwashesOnSelector",
--~         [ 5] = "lineInitialSwashesOffSelector",
--~         [ 6] = "lineFinalSwashesOnSelector",
--~         [ 7] = "lineFinalSwashesOffSelector",
--~         [ 8] = "nonFinalSwashesOnSelector",
--~         [ 9] = "nonFinalSwashesOffSelector",
--~     },
--~     [ 9] = {
--~         name = "diacriticsType",
--~         [ 0] = "showDiacriticsSelector",
--~         [ 1] = "hideDiacriticsSelector",
--~         [ 2] = "decomposeDiacriticsSelector",
--~     },
--~     [10] = {
--~         name = "verticalPositionType",
--~         [ 0] = "normalPositionSelector",
--~         [ 1] = "superiorsSelector  ",
--~         [ 2] = "inferiorsSelector  ",
--~         [ 3] = "ordinalsSelector   ",
--~     },
--~     [11] = {
--~         name = "fractionsType",
--~         [ 0] = "noFractionsSelector",
--~         [ 1] = "verticalFractionsSelector",
--~         [ 2] = "diagonalFractionsSelector",
--~     },
--~     [12] = {
--~         name = "appleReserved2Type",
--~     },
--~     [13] = {
--~         name = "overlappingCharactersType",
--~         [ 0] = "preventOverlapOnSelector",
--~         [ 1] = "preventOverlapOffSelector",
--~     },
--~     [14] = {
--~         name = "typographicExtrasType",
--~          [0 ] = "hyphensToEmDashOnSelector",
--~          [1 ] = "hyphensToEmDashOffSelector",
--~          [2 ] = "hyphenToEnDashOnSelector",
--~          [3 ] = "hyphenToEnDashOffSelector",
--~          [4 ] = "unslashedZeroOnSelector",
--~          [5 ] = "unslashedZeroOffSelector",
--~          [6 ] = "formInterrobangOnSelector",
--~          [7 ] = "formInterrobangOffSelector",
--~          [8 ] = "smartQuotesOnSelector",
--~          [9 ] = "smartQuotesOffSelector",
--~          [10] = "periodsToEllipsisOnSelector",
--~          [11] = "periodsToEllipsisOffSelector",
--~     },
--~     [15] = {
--~         name = "mathematicalExtrasType",
--~          [ 0] = "hyphenToMinusOnSelector",
--~          [ 1] = "hyphenToMinusOffSelector",
--~          [ 2] = "asteriskToMultiplyOnSelector",
--~          [ 3] = "asteriskToMultiplyOffSelector",
--~          [ 4] = "slashToDivideOnSelector",
--~          [ 5] = "slashToDivideOffSelector",
--~          [ 6] = "inequalityLigaturesOnSelector",
--~          [ 7] = "inequalityLigaturesOffSelector",
--~          [ 8] = "exponentsOnSelector",
--~          [ 9] = "exponentsOffSelector",
--~     },
--~     [16] = {
--~         name = "ornamentSetsType",
--~         [ 0] = "noOrnamentsSelector",
--~         [ 1] = "dingbatsSelector   ",
--~         [ 2] = "piCharactersSelector",
--~         [ 3] = "fleuronsSelector   ",
--~         [ 4] = "decorativeBordersSelector",
--~         [ 5] = "internationalSymbolsSelector",
--~         [ 6] = "mathSymbolsSelector",
--~     },
--~     [17] = {
--~         name = "characterAlternativesType",
--~         [ 0] = "noAlternatesSelector",
--~     },
--~     [18] = {
--~         name = "designComplexityType",
--~         [ 0] = "designLevel1Selector",
--~         [ 1] = "designLevel2Selector",
--~         [ 2] = "designLevel3Selector",
--~         [ 3] = "designLevel4Selector",
--~         [ 4] = "designLevel5Selector",
--~     },
--~     [19] = {
--~         name = "styleOptionsType",
--~         [ 0] = "noStyleOptionsSelector",
--~         [ 1] = "displayTextSelector",
--~         [ 2] = "engravedTextSelector",
--~         [ 3] = "illuminatedCapsSelector",
--~         [ 4] = "titlingCapsSelector",
--~         [ 5] = "tallCapsSelector   ",
--~     },
--~     [20] = {
--~         name = "characterShapeType",
--~         [0 ] = "traditionalCharactersSelector",
--~         [1 ] = "simplifiedCharactersSelector",
--~         [2 ] = "jis1978CharactersSelector",
--~         [3 ] = "jis1983CharactersSelector",
--~         [4 ] = "jis1990CharactersSelector",
--~         [5 ] = "traditionalAltOneSelector",
--~         [6 ] = "traditionalAltTwoSelector",
--~         [7 ] = "traditionalAltThreeSelector",
--~         [8 ] = "traditionalAltFourSelector",
--~         [9 ] = "traditionalAltFiveSelector",
--~         [10] = "expertCharactersSelector",
--~     },
--~     [21] = {
--~         name = "numberCaseType",
--~         [ 0] = "lowerCaseNumbersSelector",
--~         [ 1] = "upperCaseNumbersSelector",
--~     },
--~     [22] = {
--~         name = "textSpacingType",
--~         [ 0] = "proportionalTextSelector",
--~         [ 1] = "monospacedTextSelector",
--~         [ 2] = "halfWidthTextSelector",
--~         [ 3] = "normallySpacedTextSelector",
--~     },
--~     [23] = {
--~         name = "transliterationType",
--~         [ 0] = "noTransliterationSelector",
--~         [ 1] = "hanjaToHangulSelector",
--~         [ 2] = "hiraganaToKatakanaSelector",
--~         [ 3] = "katakanaToHiraganaSelector",
--~         [ 4] = "kanaToRomanizationSelector",
--~         [ 5] = "romanizationToHiraganaSelector",
--~         [ 6] = "romanizationToKatakanaSelector",
--~         [ 7] = "hanjaToHangulAltOneSelector",
--~         [ 8] = "hanjaToHangulAltTwoSelector",
--~         [ 9] = "hanjaToHangulAltThreeSelector",
--~     },
--~     [24] = {
--~         name = "annotationType",
--~         [ 0] = "noAnnotationSelector",
--~         [ 1] = "boxAnnotationSelector",
--~         [ 2] = "roundedBoxAnnotationSelector",
--~         [ 3] = "circleAnnotationSelector",
--~         [ 4] = "invertedCircleAnnotationSelector",
--~         [ 5] = "parenthesisAnnotationSelector",
--~         [ 6] = "periodAnnotationSelector",
--~         [ 7] = "romanNumeralAnnotationSelector",
--~         [ 8] = "diamondAnnotationSelector",
--~     },
--~     [25] = {
--~         name = "kanaSpacingType",
--~         [ 0] = "fullWidthKanaSelector",
--~         [ 1] = "proportionalKanaSelector",
--~     },
--~     [26] = {
--~         name = "ideographicSpacingType",
--~         [ 0] = "fullWidthIdeographsSelector",
--~         [ 1] = "proportionalIdeographsSelector",
--~     },
--~     [103] = {
--~         name = "cjkRomanSpacingType",
--~         [ 0] = "halfWidthCJKRomanSelector",
--~         [ 1] = "proportionalCJKRomanSelector",
--~         [ 2] = "defaultCJKRomanSelector",
--~         [ 3] = "fullWidthCJKRomanSelector",
--~     },
--~ }

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local match, format, find, concat, gsub, lower = string.match, string.format, string.find, table.concat, string.gsub, string.lower
local lpegmatch = lpeg.match
local utfbyte = utf.byte

local trace_loading    = false  trackers.register("otf.loading",    function(v) trace_loading    = v end)
local trace_unimapping = false  trackers.register("otf.unimapping", function(v) trace_unimapping = v end)

local report_otf = logs.reporter("fonts","otf loading")

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
<p>The name to unciode related code will stay of course.</p>
--ldx]]--

local fonts = fonts
fonts.map   = fonts.map or { }

local function loadlumtable(filename) -- will move to font goodies
    local lumname = file.replacesuffix(file.basename(filename),"lum")
    local lumfile = resolvers.findfile(lumname,"map") or ""
    if lumfile ~= "" and lfs.isfile(lumfile) then
        if trace_loading or trace_unimapping then
            report_otf("enhance: loading %s ",lumfile)
        end
        lumunic = dofile(lumfile)
        return lumunic, lumfile
    end
end

local P, R, S, C, Ct, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc

local hex     = R("AF","09")
local hexfour = (hex*hex*hex*hex) / function(s) return tonumber(s,16) end
local hexsix  = (hex^1)           / function(s) return tonumber(s,16) end
local dec     = (R("09")^1)  / tonumber
local period  = P(".")
local unicode = P("uni")   * (hexfour * (period + P(-1)) * Cc(false) + Ct(hexfour^1) * Cc(true))
local ucode   = P("u")     * (hexsix  * (period + P(-1)) * Cc(false) + Ct(hexsix ^1) * Cc(true))
local index   = P("index") * dec * Cc(false)

local parser  = unicode + ucode + index

local parsers = { }

local function makenameparser(str)
    if not str or str == "" then
        return parser
    else
        local p = parsers[str]
        if not p then
            p = P(str) * period * dec * Cc(false)
            parsers[str] = p
        end
        return p
    end
end

--~ local parser = fonts.map.makenameparser("Japan1")
--~ local parser = fonts.map.makenameparser()
--~ local function test(str)
--~     local b, a = lpegmatch(parser,str)
--~     print((a and table.serialize(b)) or b)
--~ end
--~ test("a.sc")
--~ test("a")
--~ test("uni1234")
--~ test("uni1234.xx")
--~ test("uni12349876")
--~ test("index1234")
--~ test("Japan1.123")

local function tounicode16(unicode)
    if unicode < 0x10000 then
        return format("%04X",unicode)
    else
        return format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
    end
end

local function tounicode16sequence(unicodes)
    local t = { }
    for l=1,#unicodes do
        local unicode = unicodes[l]
        if unicode < 0x10000 then
            t[l] = format("%04X",unicode)
        else
            t[l] = format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
        end
    end
    return concat(t)
end

--~ This is quite a bit faster but at the cost of some memory but if we
--~ do this we will also use it elsewhere so let's not follow this route
--~ now. I might use this method in the plain variant (no caching there)
--~ but then I need a flag that distinguishes between code branches.
--~
--~ local cache = { }
--~
--~ function fonts.map.tounicode16(unicode)
--~     local s = cache[unicode]
--~     if not s then
--~         if unicode < 0x10000 then
--~             s = format("%04X",unicode)
--~         else
--~             s = format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
--~         end
--~         cache[unicode] = s
--~     end
--~     return s
--~ end

fonts.map.loadlumtable        = loadlumtable
fonts.map.makenameparser      = makenameparser
fonts.map.tounicode16         = tounicode16
fonts.map.tounicode16sequence = tounicode16sequence

local separator   = S("_.")
local other       = C((1 - separator)^1)
local ligsplitter = Ct(other * (separator * other)^0)

--~ print(table.serialize(lpegmatch(ligsplitter,"this")))
--~ print(table.serialize(lpegmatch(ligsplitter,"this.that")))
--~ print(table.serialize(lpegmatch(ligsplitter,"japan1.123")))
--~ print(table.serialize(lpegmatch(ligsplitter,"such_so_more")))
--~ print(table.serialize(lpegmatch(ligsplitter,"such_so_more.that")))

fonts.map.addtounicode = function(data,filename)
    local unicodes = data.luatex and data.luatex.unicodes
    if not unicodes then
        return
    end
    -- we need to move this code
    unicodes['space']  = unicodes['space']  or 32
    unicodes['hyphen'] = unicodes['hyphen'] or 45
    unicodes['zwj']    = unicodes['zwj']    or 0x200D
    unicodes['zwnj']   = unicodes['zwnj']   or 0x200C
    -- the tounicode mapping is sparse and only needed for alternatives
    local tounicode, originals, ns, nl, private, unknown = { }, { }, 0, 0, fonts.privateoffset, format("%04X",utfbyte("?"))
    data.luatex.tounicode, data.luatex.originals = tounicode, originals
    local lumunic, uparser, oparser
    if false then -- will become an option
        lumunic = loadlumtable(filename)
        lumunic = lumunic and lumunic.tounicode
    end
    local cidinfo, cidnames, cidcodes = data.cidinfo
    local usedmap = cidinfo and cidinfo.usedname
    usedmap = usedmap and lower(usedmap)
    usedmap = usedmap and fonts.cid.map[usedmap]
    if usedmap then
        oparser = usedmap and makenameparser(cidinfo.ordering)
        cidnames = usedmap.names
        cidcodes = usedmap.unicodes
    end
    uparser = makenameparser()
    local unicodevector = fonts.enc.agl.unicodes -- loaded runtime in context
    for index, glyph in next, data.glyphs do
        local name, unic = glyph.name, glyph.unicode or -1 -- play safe
        if unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
            local unicode = (lumunic and lumunic[name]) or unicodevector[name]
            if unicode then
                originals[index], tounicode[index], ns = unicode, tounicode16(unicode), ns + 1
            end
            -- cidmap heuristics, beware, there is no guarantee for a match unless
            -- the chain resolves
            if (not unicode) and usedmap then
                local foundindex = lpegmatch(oparser,name)
                if foundindex then
                    unicode = cidcodes[foundindex] -- name to number
                    if unicode then
                        originals[index], tounicode[index], ns = unicode, tounicode16(unicode), ns + 1
                    else
                        local reference = cidnames[foundindex] -- number to name
                        if reference then
                            local foundindex = lpegmatch(oparser,reference)
                            if foundindex then
                                unicode = cidcodes[foundindex]
                                if unicode then
                                    originals[index], tounicode[index], ns = unicode, tounicode16(unicode), ns + 1
                                end
                            end
                            if not unicode then
                                local foundcodes, multiple = lpegmatch(uparser,reference)
                                if foundcodes then
                                    if multiple then
                                        originals[index], tounicode[index], nl, unicode = foundcodes, tounicode16sequence(foundcodes), nl + 1, true
                                    else
                                        originals[index], tounicode[index], ns, unicode = foundcodes, tounicode16(foundcodes), ns + 1, foundcodes
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- a.whatever or a_b_c.whatever or a_b_c (no numbers)
            if not unicode then
                local split = lpegmatch(ligsplitter,name)
                local nplit = (split and #split) or 0
                if nplit == 0 then
                    -- skip
                elseif nplit == 1 then
                    local base = split[1]
                    unicode = unicodes[base] or unicodevector[base]
                    if unicode then
                        if type(unicode) == "table" then
                            unicode = unicode[1]
                        end
                        originals[index], tounicode[index], ns = unicode, tounicode16(unicode), ns + 1
                    end
                else
                    local t, n = { }, 0
                    for l=1,nplit do
                        local base = split[l]
                        local u = unicodes[base] or unicodevector[base]
                        if not u then
                            break
                        elseif type(u) == "table" then
                            n = n + 1
                            t[n] = u[1]
                        else
                            n = n + 1
                            t[n] = u
                        end
                    end
                    if n == 0 then -- done then
                        -- nothing
                    elseif n == 1 then
                        originals[index], tounicode[index], nl, unicode = t[1], tounicode16(t[1]), nl + 1, true
                    else
                        originals[index], tounicode[index], nl, unicode = t, tounicode16sequence(t), nl + 1, true
                    end
                end
            end
            -- last resort
            if not unicode then
                local foundcodes, multiple = lpegmatch(uparser,name)
                if foundcodes then
                    if multiple then
                        originals[index], tounicode[index], nl, unicode = foundcodes, tounicode16sequence(foundcodes), nl + 1, true
                    else
                        originals[index], tounicode[index], ns, unicode = foundcodes, tounicode16(foundcodes), ns + 1, foundcodes
                    end
                end
            end
            if not unicode then
                originals[index], tounicode[index] = 0xFFFD, "FFFD"
            end
        end
    end
    if trace_unimapping then
        for index, glyph in table.sortedhash(data.glyphs) do
            local toun, name, unic = tounicode[index], glyph.name, glyph.unicode or -1 -- play safe
            if toun then
                report_otf("internal: 0x%05X, name: %s, unicode: 0x%05X, tounicode: %s",index,name,unic,toun)
            else
                report_otf("internal: 0x%05X, name: %s, unicode: 0x%05X",index,name,unic)
            end
        end
    end
    if trace_loading and (ns > 0 or nl > 0) then
        report_otf("enhance: %s tounicode entries added (%s ligatures)",nl+ns, ns)
    end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-lua'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_lua = logs.reporter("fonts","lua loading")

fonts.formats.lua = "lua"

local readers = fonts.tfm.readers

local function check_lua(specification,fullname)
    -- standard tex file lookup
    local fullname = resolvers.findfile(fullname) or ""
    if fullname ~= "" then
        local loader = loadfile(fullname)
        loader = loader and loader()
        return loader and loader(specification)
    end
end

function readers.lua(specification)
    local original = specification.specification
    if trace_defining then
        report_lua("using lua reader for '%s'",original)
    end
    local fullname, tfmtable = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmtable = check_lua(specification,specification.name .. "." .. forced)
        end
        if not tfmtable then
            tfmtable = check_lua(specification,specification.name)
        end
    else
        tfmtable = check_lua(specification,fullname)
    end
    return tfmtable
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- langs -> languages enz
-- anchor_classes vs kernclasses
-- modification/creationtime in subfont is runtime dus zinloos
-- to_table -> totable

local utf = unicode.utf8

local utfbyte = utf.byte
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local abs = math.abs
local getn = table.getn
local lpegmatch = lpeg.match
local reversed, concat = table.reversed, table.concat
local ioflush = io.flush

local allocate = utilities.storage.allocate

local trace_private    = false  trackers.register("otf.private",    function(v) trace_private      = v end)
local trace_loading    = false  trackers.register("otf.loading",    function(v) trace_loading      = v end)
local trace_features   = false  trackers.register("otf.features",   function(v) trace_features     = v end)
local trace_dynamics   = false  trackers.register("otf.dynamics",   function(v) trace_dynamics     = v end)
local trace_sequences  = false  trackers.register("otf.sequences",  function(v) trace_sequences    = v end)
local trace_math       = false  trackers.register("otf.math",       function(v) trace_math         = v end)
local trace_defining   = false  trackers.register("fonts.defining", function(v) trace_defining     = v end)

local report_otf = logs.reporter("fonts","otf loading")

local starttiming, stoptiming, elapsedtime = statistics.starttiming, statistics.stoptiming, statistics.elapsedtime

local findbinfile = resolvers.findbinfile

local fonts            = fonts

fonts.otf              = fonts.otf or { }
local otf              = fonts.otf
local tfm              = fonts.tfm

local fontdata         = fonts.identifiers
local chardata         = characters and characters.data -- not used

-- todo: probably first time so local first

otf.features           = otf.features     or { }
local features         = otf.features
features.list          = features.list    or { }
local featurelist      = features.list
features.default       = features.default or { }
local defaultfeatures  = features.default

otf.enhancers          = allocate()
local enhancers        = otf.enhancers
enhancers.patches      = { }
local patches          = enhancers.patches

local definers         = fonts.definers
local readers          = fonts.tfm.readers

otf.glists             = { "gsub", "gpos" }

otf.version            = 2.710 -- beware: also sync font-mis.lua
otf.cache              = containers.define("fonts", "otf", otf.version, true)

local loadmethod       = "table" -- table, mixed, sparse
local forceload        = false
local cleanup          = 0
local usemetatables    = false -- .4 slower on mk but 30 M less mem so we might change the default -- will be directive
local packdata         = true
local syncspace        = true
local forcenotdef      = false

local wildcard         = "*"
local default          = "dflt"

local fontloaderfields = fontloader.fields
local mainfields       = nil
local glyphfields      = nil -- not used yet

directives.register("fonts.otf.loader.method", function(v)
    if v == "sparse" and fontloaderfields then
        loadmethod = "sparse"
    elseif v == "mixed" then
        loadmethod = "mixed"
    elseif v == "table" then
        loadmethod = "table"
    else
        loadmethod = "table"
        report_otf("no loader method '%s', using '%s' instead",v,loadmethod)
    end
end)

directives.register("fonts.otf.loader.cleanup",function(v)
    cleanup = tonumber(v) or (v and 1) or 0
end)

directives.register("fonts.otf.loader.force",          function(v) forceload     = v end)
directives.register("fonts.otf.loader.usemetatables",  function(v) usemetatables = v end)
directives.register("fonts.otf.loader.pack",           function(v) packdata      = v end)
directives.register("fonts.otf.loader.syncspace",      function(v) syncspace     = v end)
directives.register("fonts.otf.loader.forcenotdef",    function(v) forcenotdef   = v end)

local function load_featurefile(raw,featurefile)
    if featurefile and featurefile ~= "" then
        if trace_loading then
            report_otf("featurefile: %s", featurefile)
        end
        fontloader.apply_featurefile(raw, featurefile)
    end
end

local function showfeatureorder(otfdata,filename)
    local sequences = otfdata.luatex.sequences
    if sequences and #sequences > 0 then
        if trace_loading then
            report_otf("font %s has %s sequences",filename,#sequences)
            report_otf(" ")
        end
        for nos=1,#sequences do
            local sequence = sequences[nos]
            local typ = sequence.type or "no-type"
            local name = sequence.name or "no-name"
            local subtables = sequence.subtables or { "no-subtables" }
            local features = sequence.features
            if trace_loading then
                report_otf("%3i  %-15s  %-20s  [%s]",nos,name,typ,concat(subtables,","))
            end
            if features then
                for feature, scripts in next, features do
                    local tt = { }
                    for script, languages in next, scripts do
                        local ttt = { }
                        for language, _ in next, languages do
                            ttt[#ttt+1] = language
                        end
                        tt[#tt+1] = format("[%s: %s]",script,concat(ttt," "))
                    end
                    if trace_loading then
                        report_otf("       %s: %s",feature,concat(tt," "))
                    end
                end
            end
        end
        if trace_loading then
            report_otf("\n")
        end
    elseif trace_loading then
        report_otf("font %s has no sequences",filename)
    end
end

--[[ldx--
<p>We start with a lot of tables and related functions.</p>
--ldx]]--

local global_fields = table.tohash {
    "metadata",
    "lookups",
    "glyphs",
    "subfonts",
    "luatex",
    "pfminfo",
    "cidinfo",
    "tables",
    "names",
    "unicodes",
    "names",
 -- "math",
    "anchor_classes",
    "kern_classes",
    "gpos",
    "gsub"
}

local valid_fields = table.tohash {
 -- "anchor_classes",
    "ascent",
 -- "cache_version",
    "cidinfo",
    "copyright",
 -- "creationtime",
    "descent",
    "design_range_bottom",
    "design_range_top",
    "design_size",
    "encodingchanged",
    "extrema_bound",
    "familyname",
    "fontname",
    "fontstyle_id",
    "fontstyle_name",
    "fullname",
 -- "glyphs",
    "hasvmetrics",
    "head_optimized_for_cleartype",
    "horiz_base",
    "issans",
    "isserif",
    "italicangle",
 -- "kerns",
 -- "lookups",
 -- "luatex",
    "macstyle",
 -- "modificationtime",
    "onlybitmaps",
    "origname",
    "os2_version",
 -- "pfminfo",
 -- "private",
    "serifcheck",
    "sfd_version",
 -- "size",
    "strokedfont",
    "strokewidth",
    "subfonts",
    "table_version",
 -- "tables",
 -- "ttf_tab_saved",
    "ttf_tables",
    "uni_interp",
    "uniqueid",
    "units_per_em",
    "upos",
    "use_typo_metrics",
    "uwidth",
 -- "validation_state",
    "verbose",
    "version",
    "vert_base",
    "weight",
    "weight_width_slope_only",
 -- "xuid",
}

local ordered_enhancers = {
    "prepare tables",
    "prepare glyphs",
    "prepare unicodes",
    "prepare lookups",

    "analyze glyphs",
    "analyze math",

    "prepare tounicode", -- maybe merge with prepare

    "reorganize lookups",
    "reorganize mark classes",
    "reorganize anchor classes",

    "reorganize glyph kerns",
    "reorganize glyph lookups",
    "reorganize glyph anchors",

    "reorganize features",
    "reorganize subtables",

    "check glyphs",
    "check metadata",
    "check math parameters",
    "check extra features", -- after metadata
}

--[[ldx--
<p>Here we go.</p>
--ldx]]--

local actions = { }

patches.before = allocate()
patches.after  = allocate()

local before = patches.before
local after  = patches.after

local function enhance(name,data,filename,raw,verbose)
    local enhancer = actions[name]
    if enhancer then
        if verbose then
            report_otf("enhance: %s (%s)",name,filename)
            ioflush()
        end
        enhancer(data,filename,raw)
    else
        report_otf("enhance: %s is undefined",name)
    end
end

function enhancers.apply(data,filename,raw,verbose)
    local basename = file.basename(lower(filename))
    report_otf("start enhancing: %s",filename)
    ioflush() -- we want instant messages
    for e=1,#ordered_enhancers do
        local enhancer = ordered_enhancers[e]
        local b = before[enhancer]
        if b then
            for pattern, action in next, b do
                if find(basename,pattern) then
                    action(data,filename,raw)
                end
            end
        end
        enhance(enhancer,data,filename,raw,verbose)
        local a = after[enhancer]
        if a then
            for pattern, action in next, a do
                if find(basename,pattern) then
                    action(data,filename,raw)
                end
            end
        end
        ioflush() -- we want instant messages
    end
    report_otf("stop enhancing")
    ioflush() -- we want instant messages
end

-- patches.register("before","migrate metadata","cambria",function() end)

function patches.register(what,where,pattern,action)
    local ww = what[where]
    if ww then
        ww[pattern] = action
    else
        ww = { [pattern] = action}
    end
end

function patches.report(fmt,...)
    if trace_loading then
        report_otf("patching: " ..fmt,...)
    end
end

function enhancers.register(what,action) -- only already registered can be overloaded
    actions[what] = action
end

function otf.load(filename,format,sub,featurefile)
    local name = file.basename(file.removesuffix(filename))
    local attr = lfs.attributes(filename)
    local size, time = attr and attr.size or 0, attr and attr.modification or 0
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    if sub == "" then sub = false end
    local hash = name
    if sub then
        hash = hash .. "-" .. sub
    end
    hash = containers.cleanname(hash)
    local featurefiles
    if featurefile then
        featurefiles = { }
        for s in gmatch(featurefile,"[^,]+") do
            local name = resolvers.findfile(file.addsuffix(s,'fea'),'fea') or ""
            if name == "" then
                report_otf("loading: no featurefile '%s'",s)
            else
                local attr = lfs.attributes(name)
                featurefiles[#featurefiles+1] = {
                    name = name,
                    size = attr.size or 0,
                    time = attr.modification or 0,
                }
            end
        end
        if #featurefiles == 0 then
            featurefiles = nil
        end
    end
    local data = containers.read(otf.cache,hash)
    local reload = not data or data.verbose ~= fonts.verbose or data.size ~= size or data.time ~= time
    if forceload then
        report_otf("loading: forced reload due to hard coded flag")
        reload = true
    end
    if not reload then
        local featuredata = data.featuredata
        if featurefiles then
            if not featuredata or #featuredata ~= #featurefiles then
                reload = true
            else
                for i=1,#featurefiles do
                    local fi, fd = featurefiles[i], featuredata[i]
                    if fi.name ~= fd.name or fi.size ~= fd.size or fi.time ~= fd.time then
                        reload = true
                        break
                    end
                end
            end
        elseif featuredata then
            reload = true
        end
        if reload then
           report_otf("loading: forced reload due to changed featurefile specification: %s",featurefile or "--")
        end
     end
     if reload then
        report_otf("loading: %s (hash: %s)",filename,hash)
        local fontdata, messages, rawdata
        if sub then
            fontdata, messages = fontloader.open(filename,sub)
        else
            fontdata, messages = fontloader.open(filename)
        end
        if fontdata then
            mainfields = mainfields or (fontloaderfields and fontloaderfields(fontdata))
        end
        if trace_loading and messages and #messages > 0 then
            if type(messages) == "string" then
                report_otf("warning: %s",messages)
            else
                for m=1,#messages do
                    report_otf("warning: %s",tostring(messages[m]))
                end
            end
        else
            report_otf("font loaded okay")
        end
        if fontdata then
            if featurefiles then
                for i=1,#featurefiles do
                    load_featurefile(fontdata,featurefiles[i].name)
                end
            end
            report_otf("loading method: %s",loadmethod)
            if loadmethod == "sparse" then
                rawdata = fontdata
            else
                rawdata = fontloader.to_table(fontdata)
                fontloader.close(fontdata)
            end
            if rawdata then
                data = { }
                starttiming(data)
                local verboseindeed = verbose ~= nil and verbose or trace_loading
                report_otf("file size: %s", size)
                enhancers.apply(data,filename,rawdata,verboseindeed)
                if packdata and not fonts.verbose then
                    enhance("pack",data,filename,nil,verboseindeed)
                end
                data.size = size
                data.time = time
                data.format = format
                if featurefiles then
                    data.featuredata = featurefiles
                end
                data.verbose = fonts.verbose
                report_otf("saving in cache: %s",filename)
                data = containers.write(otf.cache, hash, data)
                if cleanup > 0 then
                    collectgarbage("collect")
                end
                stoptiming(data)
                if elapsedtime then -- not in generic
                    report_otf("preprocessing and caching took %s seconds",elapsedtime(data))
                end
                data = containers.read(otf.cache, hash) -- this frees the old table and load the sparse one
                if cleanup > 1 then
                    collectgarbage("collect")
                end
            else
                data = nil
                report_otf("loading failed (table conversion error)")
            end
            if loadmethod == "sparse" then
                fontloader.close(fontdata)
                if cleanup > 2 then
                 -- collectgarbage("collect")
                end
            end
        else
            data = nil
            report_otf("loading failed (file read error)")
        end
    end
    if data then
        if trace_defining then
            report_otf("loading from cache: %s",hash)
        end
        enhance("unpack",data,filename,nil,false)
        enhance("add dimensions",data,filename,nil,false)
        if trace_sequences then
            showfeatureorder(data,filename)
        end
    end
    return data
end

local mt = {
    __index = function(t,k) -- maybe set it
        if k == "height" then
            local ht = t.boundingbox[4]
            return ht < 0 and 0 or ht
        elseif k == "depth" then
            local dp = -t.boundingbox[2]
            return dp < 0 and 0 or dp
        elseif k == "width" then
            return 0
        elseif k == "name" then -- or maybe uni*
            return forcenotdef and ".notdef"
        end
    end
}

actions["add dimensions"] = function(data,filename)
    -- todo: forget about the width if it's the defaultwidth (saves mem)
    -- we could also build the marks hash here (instead of storing it)
    if data then
        local luatex = data.luatex
        local defaultwidth  = luatex.defaultwidth  or 0
        local defaultheight = luatex.defaultheight or 0
        local defaultdepth  = luatex.defaultdepth  or 0
        if usemetatables then
            for _, d in next, data.glyphs do
                local wd = d.width
                if not wd then
                    d.width = defaultwidth
                elseif wd ~= 0 and d.class == "mark" then
                    d.width  = -wd
                end
                setmetatable(d,mt)
            end
        else
            for _, d in next, data.glyphs do
                local bb, wd = d.boundingbox, d.width
                if not wd then
                    d.width = defaultwidth
                elseif wd ~= 0 and d.class == "mark" then
                    d.width  = -wd
                end
                if forcenotdef and not d.name then
                    d.name = ".notdef"
                end
                if bb then
                    local ht, dp = bb[4], -bb[2]
                    if ht == 0 or ht < 0 then
                        -- not set
                    else
                        d.height = ht
                    end
                    if dp == 0 or dp < 0 then
                        -- not set
                    else
                        d.depth  = dp
                    end
                end
            end
        end
    end
end

actions["prepare tables"] = function(data,filename,raw)
    local luatex = {
        filename = resolvers.unresolve(filename), -- no shortcut
        version  = otf.version,
        creator  = "context mkiv",
    }
    data.luatex = luatex
    data.metadata = { }
end

local function somecopy(old) -- fast one
    if old then
        local new = { }
        if type(old) == "table" then
            for k, v in next, old do
                if k == "glyphs" then
                    -- skip
                elseif type(v) == "table" then
                    new[k] = somecopy(v)
                else
                    new[k] = v
                end
            end
        else
            for i=1,#mainfields do
                local k = mainfields[i]
                local v = old[k]
                if k == "glyphs" then
                    -- skip
                elseif type(v) == "table" then
                    new[k] = somecopy(v)
                else
                    new[k] = v
                end
            end
        end
        return new
    else
        return { }
    end
end

-- not setting italic_correction and class (when nil) during
-- table cronstruction can save some mem

actions["prepare glyphs"] = function(data,filename,raw)
    -- we can also move the names to data.luatex.names which might
    -- save us some more memory (at the cost of harder tracing)
    local rawglyphs = raw.glyphs
    local glyphs, udglyphs
    if loadmethod == "sparse" then
        glyphs, udglyphs = { }, { }
    elseif loadmethod == "mixed" then
        glyphs, udglyphs = { }, rawglyphs
    else
        glyphs, udglyphs = rawglyphs, rawglyphs
    end
    data.glyphs, data.udglyphs = glyphs, udglyphs
    local subfonts = raw.subfonts
    if subfonts then
        if data.glyphs and next(data.glyphs) then
            report_otf("replacing existing glyph table due to subfonts")
        end
        local cidinfo = raw.cidinfo
        if cidinfo.registry then
            local cidmap, cidname = fonts.cid.getmap(cidinfo.registry,cidinfo.ordering,cidinfo.supplement)
            if cidmap then
                cidinfo.usedname = cidmap.usedname
                local uni_to_int, int_to_uni, nofnames, nofunicodes = { }, { }, 0, 0
                local unicodes, names = cidmap.unicodes, cidmap.names
                for cidindex=1,#subfonts do
                    local subfont = subfonts[cidindex]
                    if loadmethod == "sparse" then
                        local rawglyphs = subfont.glyphs
                        for index=0,subfont.glyphmax - 1 do
                            local g = rawglyphs[index]
                            if g then
                                local unicode, name = unicodes[index], names[index]
                                if unicode then
                                    uni_to_int[unicode] = index
                                    int_to_uni[index] = unicode
                                    nofunicodes = nofunicodes + 1
                                elseif name then
                                    nofnames = nofnames + 1
                                end
                                udglyphs[index] = g
                                glyphs[index] = {
                                    width       = g.width,
                                    italic      = g.italic_correction,
                                    boundingbox = g.boundingbox,
                                    class       = g.class,
                                    name        = g.name or name or "unknown", -- uniXXXX
                                    cidindex    = cidindex,
                                    unicode     = unicode,
                                }
                            end
                        end
                        -- If we had more userdata, we would need more of this
                        -- and it would start working against us in terms of
                        -- convenience and speed.
                        subfont = somecopy(subfont)
                        subfont.glyphs = nil
                        subfont[cidindex] = subfont
                    elseif loadmethod == "mixed" then
                        for index, g in next, subfont.glyphs do
                            local unicode, name = unicodes[index], names[index]
                            if unicode then
                                uni_to_int[unicode] = index
                                int_to_uni[index] = unicode
                                nofunicodes = nofunicodes + 1
                            elseif name then
                                nofnames = nofnames + 1
                            end
                            udglyphs[index] = g
                            glyphs[index] = {
                                width       = g.width,
                                italic      = g.italic_correction,
                                boundingbox = g.boundingbox,
                                class       = g.class,
                                name        = g.name or name or "unknown", -- uniXXXX
                                cidindex    = cidindex,
                                unicode     = unicode,
                            }
                        end
                        subfont.glyphs = nil
                    else
                        for index, g in next, subfont.glyphs do
                            local unicode, name = unicodes[index], names[index]
                            if unicode then
                                uni_to_int[unicode] = index
                                int_to_uni[index] = unicode
                                nofunicodes = nofunicodes + 1
                                g.unicode = unicode
                            elseif name then
                                nofnames = nofnames + 1
                            end
                            g.cidindex = cidindex
                            glyphs[index] = g
                        end
                        subfont.glyphs = nil
                    end
                end
                if trace_loading then
                    report_otf("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes, nofnames, nofunicodes+nofnames)
                end
                data.map = data.map or { }
                data.map.map = uni_to_int
                data.map.backmap = int_to_uni
            elseif trace_loading then
                report_otf("unable to remap cid font, missing cid file for %s",filename)
            end
            data.subfonts = subfonts
        elseif trace_loading then
            report_otf("font %s has no glyphs",filename)
        end
    else
        if loadmethod == "sparse" then
            -- we get fields from the userdata glyph table and create
            -- a minimal entry first
            for index=0,raw.glyphmax - 1 do
                local g = rawglyphs[index]
                if g then
                    udglyphs[index] = g
                    glyphs[index] = {
                        width       = g.width,
                        italic      = g.italic_correction,
                        boundingbox = g.boundingbox,
                        class       = g.class,
                        name        = g.name,
                        unicode     = g.unicode,
                    }
                end
            end
        elseif loadmethod == "mixed" then
            -- we get fields from the totable glyph table and copy to the
            -- final glyph table so first we create a minimal entry
            for index, g in next, rawglyphs do
                udglyphs[index] = g
                glyphs[index] = {
                    width       = g.width,
                    italic      = g.italic_correction,
                    boundingbox = g.boundingbox,
                    class       = g.class,
                    name        = g.name,
                    unicode     = g.unicode,
                }
            end
        else
            -- we use the totable glyph table directly and manipulate the
            -- entries in this (also final) table
        end
        data.map = raw.map
    end
    data.cidinfo = raw.cidinfo -- hack
end

-- watch copy of cidinfo: we can best make some more copies to data

actions["analyze glyphs"] = function(data,filename,raw) -- maybe integrate this in the previous
    local glyphs = data.glyphs
    -- collect info
    local has_italic, widths, marks = false, { }, { }
    for index, glyph in next, glyphs do
        local italic = glyph.italic_correction
        if not italic then
            -- skip
        elseif italic == 0 then
            glyph.italic_correction = nil
            glyph.italic = nil
        else
            glyph.italic_correction = nil
            glyph.italic = italic
            has_italic = true
        end
        local width = glyph.width
        widths[width] = (widths[width] or 0) + 1
        local class = glyph.class
        local unicode = glyph.unicode
        if class == "mark" then
            marks[unicode] = true
     -- elseif chardata[unicode].category == "mn" then
     --     marks[unicode] = true
     --     glyph.class = "mark"
        end
        local a = glyph.altuni     if a then glyph.altuni     = nil end
        local d = glyph.dependents if d then glyph.dependents = nil end
        local v = glyph.vwidth     if v then glyph.vwidth     = nil end
    end
    -- flag italic
    data.metadata.has_italic = has_italic
    -- flag marks
    data.luatex.marks = marks
    -- share most common width for cjk fonts
    local wd, most = 0, 1
    for k,v in next, widths do
        if v > most then
            wd, most = k, v
        end
    end
    if most > 1000 then -- maybe 500
        if trace_loading then
            report_otf("most common width: %s (%s times), sharing (cjk font)",wd,most)
        end
        for index, glyph in next, glyphs do
            if glyph.width == wd then
                glyph.width = nil
            end
        end
        data.luatex.defaultwidth = wd
    end
end

actions["reorganize mark classes"] = function(data,filename,raw)
    local mark_classes = raw.mark_classes
    if mark_classes then
        local luatex = data.luatex
        local unicodes = luatex.unicodes
        local reverse = { }
        luatex.markclasses = reverse
        for name, class in next, mark_classes do
            local t = { }
            for s in gmatch(class,"[^ ]+") do
                local us = unicodes[s]
                if type(us) == "table" then
                    for u=1,#us do
                        t[us[u]] = true
                    end
                else
                    t[us] = true
                end
            end
            reverse[name] = t
        end
        data.mark_classes = nil -- when using table
    end
end

actions["reorganize features"] = function(data,filename,raw) -- combine with other
    local features = { }
    data.luatex.features = features
    for k, what in next, otf.glists do
        local dw = raw[what]
        if dw then
            local f = { }
            features[what] = f
            for i=1,#dw do
                local d= dw[i]
                local dfeatures = d.features
                if dfeatures then
                    for i=1,#dfeatures do
                        local df = dfeatures[i]
                        local tag = strip(lower(df.tag))
                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                        local dscripts = df.scripts
                        for i=1,#dscripts do
                            local d = dscripts[i]
                            local languages = d.langs
                            local script = strip(lower(d.script))
                            local fts = ft[script] if not fts then fts = {} ft[script] = fts end
                            for i=1,#languages do
                                fts[strip(lower(languages[i]))] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

actions["reorganize anchor classes"] = function(data,filename,raw)
    local classes = raw.anchor_classes -- anchor classes not in final table
    local luatex = data.luatex
    local anchor_to_lookup, lookup_to_anchor = { }, { }
    luatex.anchor_to_lookup, luatex.lookup_to_anchor = anchor_to_lookup, lookup_to_anchor
    if classes then
        for c=1,#classes do
            local class = classes[c]
            local anchor = class.name
            local lookups = class.lookup
            if type(lookups) ~= "table" then
                lookups = { lookups }
            end
            local a = anchor_to_lookup[anchor]
            if not a then a = { } anchor_to_lookup[anchor] = a end
            for l=1,#lookups do
                local lookup = lookups[l]
                local l = lookup_to_anchor[lookup]
                if not l then l = { } lookup_to_anchor[lookup] = l end
                l[anchor] = true
                a[lookup] = true
            end
        end
    end
end

actions["prepare tounicode"] = function(data,filename,raw)
    fonts.map.addtounicode(data,filename)
end

actions["reorganize subtables"] = function(data,filename,raw)
    local luatex = data.luatex
    local sequences, lookups = { }, { }
    luatex.sequences, luatex.lookups = sequences, lookups
    for _, what in next, otf.glists do
        local dw = raw[what]
        if dw then
            for k=1,#dw do
                local gk = dw[k]
                local typ = gk.type
                local chain =
                    (typ == "gsub_contextchain"        or typ == "gpos_contextchain")        and  1 or
                    (typ == "gsub_reversecontextchain" or typ == "gpos_reversecontextchain") and -1 or 0
                --
                local subtables = gk.subtables
                if subtables then
                    local t = { }
                    for s=1,#subtables do
                        local subtable = subtables[s]
                        local name = subtable.name
                        t[#t+1] = name
                    end
                    subtables = t
                end
                local flags, markclass = gk.flags, nil
                if flags then
                    local t = { -- forcing false packs nicer
                        (flags.ignorecombiningmarks and "mark")     or false,
                        (flags.ignoreligatures      and "ligature") or false,
                        (flags.ignorebaseglyphs     and "base")     or false,
                         flags.r2l                                  or false,
                    }
                    markclass = flags.mark_class
                    if markclass then
                        markclass = luatex.markclasses[markclass]
                    end
                    flags = t
                end
                --
                local name = gk.name
                --
                local features = gk.features
                if features then
                    -- scripts, tag, ismac
                    local f = { }
                    for i=1,#features do
                        local df = features[i]
                        local tag = strip(lower(df.tag))
                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                        local dscripts = df.scripts
                        for i=1,#dscripts do
                            local d = dscripts[i]
                            local languages = d.langs
                            local script = strip(lower(d.script))
                            local fts = ft[script] if not fts then fts = {} ft[script] = fts end
                            for i=1,#languages do
                                fts[strip(lower(languages[i]))] = true
                            end
                        end
                    end
                    sequences[#sequences+1] = {
                        type      = typ,
                        chain     = chain,
                        flags     = flags,
                        name      = name,
                        subtables = subtables,
                        markclass = markclass,
                        features  = f,
                    }
                else
                    lookups[name] = {
                        type      = typ,
                        chain     = chain,
                        flags     = flags,
                        subtables = subtables,
                        markclass = markclass,
                    }
                end
            end
        end
    end
end

-- the next one is still messy but will get better when we have
-- flattened map/enc tables in the font loader

actions["prepare unicodes"] = function(data,filename,raw)
    local luatex = data.luatex
    local indices, unicodes, multiples, internals= { }, { }, { }, { }
    local mapdata = data.map or raw.map -- map already moved
    local mapmap
    if not mapdata then
        report_otf("no mapdata in '%s'",filename)
        mapmap = { }
        mapdata = { map = mapmap }
        data.map = mapdata
    elseif not mapdata.map then
        report_otf("no map in mapdata of '%s'",filename)
        mapmap = { }
        mapdata.map = mapmap
    else
        mapmap = mapdata.map
    end
    local encname = lower(data.enc_name or raw.enc_name or mapdata.enc_name or "")
    local criterium = fonts.privateoffset
    local private = criterium
    local glyphs = data.glyphs
    -- todo: nofmultiples
    for index, glyph in next, glyphs do
        if index > 0 then
            local name = glyph.name -- really needed ?
            if name then
                local unicode = glyph.unicode
                if not unicode or unicode == -1 or unicode >= criterium then
                    glyph.unicode = private
                    indices[private] = index
                    unicodes[name] = private
                    internals[index] = true
                    if trace_private then
                        report_otf("enhance: glyph %s at index U+%04X is moved to private unicode slot U+%04X",name,index,private)
                    end
                    private = private + 1
                else
                    indices[unicode] = index
                    unicodes[name] = unicode
                end
                -- maybe deal with altuni here in the future but first we need
                -- to encounter a proper font that sets them; we have to wait till
                -- a next luatex binary as currently the unicode numbers can be out
                -- of bounds
                if false then
                    local altuni = glyph.altuni
                    if altuni then
                        local un = { unicodes[name] }
                        for i=1,#altuni do
                            local unicode = altuni[i].unicode
                            multiples[#multiples+1] = name
                            un[i+1] = unicode
                            indices[unicode] = index -- maybe check for duplicates
                        end
                        unicodes[name] = un
                    end
                end
            else
                -- message that something is wrong
            end
        end
    end
    -- beware: the indices table is used to initialize the tfm table
    if find(encname,"unicode") then -- unicodebmp, unicodefull, ...
        if trace_loading then
            report_otf("using embedded unicode map '%s'",encname)
        end
        -- ok -- we can also consider using the altuni
        for unicode, index in next, mapmap do
            if not internals[index] then
                local name = glyphs[index].name
                if name then
                    local un = unicodes[name]
                    if not un then
                        unicodes[name] = unicode -- or 0
                    elseif type(un) == "number" then -- tonumber(un)
                        if un ~= unicode then
                            multiples[#multiples+1] = name
                            unicodes[name] = { un, unicode }
                            indices[unicode] = index
                        end
                    else
                        local ok = false
                        for u=1,#un do
                            if un[u] == unicode then
                                ok = true
                                break
                            end
                        end
                        if not ok then
                            multiples[#multiples+1] = name
                            un[#un+1] = unicode
                            indices[unicode] = index
                        end
                    end
                end
            end
        end
    else
        report_otf("warning: non unicode map '%s', only using glyph unicode data",encname or "whatever")
    end
    if trace_loading then
        if #multiples > 0 then
            report_otf("%s glyphs are reused: %s",#multiples, concat(multiples," "))
        else
            report_otf("no glyphs are reused")
        end
    end
    luatex.indices = indices
    luatex.unicodes = unicodes
    luatex.private = private
end

actions["prepare lookups"] = function(data,filename,raw)
    local lookups = raw.lookups
    if lookups then
        data.lookups = lookups
    end
end

actions["reorganize lookups"] = function(data,filename,raw)
    -- we prefer the before lookups in a normal order
    if data.lookups then
        for _, v in next, data.lookups do
            if v.rules then
                for _, vv in next, v.rules do
                    local c = vv.coverage
                    if c and c.before then
                        c.before = reversed(c.before)
                    end
                end
            end
        end
    end
end

actions["analyze math"] = function(data,filename,raw)
    if raw.math then
data.metadata.math = raw.math
        -- we move the math stuff into a math subtable because we then can
        -- test faster in the tfm copy
        local glyphs, udglyphs = data.glyphs, data.udglyphs
        local unicodes = data.luatex.unicodes
        for index, udglyph in next, udglyphs do
            local mk = udglyph.mathkern
            local hv = udglyph.horiz_variants
            local vv = udglyph.vert_variants
            if mk or hv or vv then
                local glyph = glyphs[index]
                local math = { }
                glyph.math = math
                if mk then
                    for k, v in next, mk do
                        if not next(v) then
                            mk[k] = nil
                        end
                    end
                    math.kerns = mk
                end
                if hv then
                    math.horiz_variants = hv.variants
                    local p = hv.parts
                    if p and #p > 0 then
                        for i=1,#p do
                            local pi = p[i]
                            pi.glyph = unicodes[pi.component] or 0
                        end
                        math.horiz_parts = p
                    end
                    local ic = hv.italic_correction
                    if ic and ic ~= 0 then
                        math.horiz_italic_correction = ic
                    end
                end
                if vv then
                    local uc = unicodes[index]
                    math.vert_variants = vv.variants
                    local p = vv.parts
                    if p and #p > 0 then
                        for i=1,#p do
                            local pi = p[i]
                            pi.glyph = unicodes[pi.component] or 0
                        end
                        math.vert_parts = p
                    end
                    local ic = vv.italic_correction
                    if ic and ic ~= 0 then
                        math.vert_italic_correction = ic
                    end
                end
                local ic = glyph.italic_correction
                if ic then
                    if ic ~= 0 then
                        math.italic_correction = ic
                    end
                end
            end
        end
    end
end

actions["reorganize glyph kerns"] = function(data,filename,raw)
    local luatex = data.luatex
    local udglyphs, glyphs, mapmap, unicodes = data.udglyphs, data.glyphs, luatex.indices, luatex.unicodes
    local mkdone = false
    local function do_it(lookup,first_unicode,extrakerns) -- can be moved inline but seldom used
        local glyph = glyphs[mapmap[first_unicode]]
        if glyph then
            local kerns = glyph.kerns
            if not kerns then
                kerns = { } -- unicode indexed !
                glyph.kerns = kerns
            end
            local lookupkerns = kerns[lookup]
            if not lookupkerns then
                lookupkerns = { }
                kerns[lookup] = lookupkerns
            end
            for second_unicode, kern in next, extrakerns do
                lookupkerns[second_unicode] = kern
            end
        elseif trace_loading then
            report_otf("no glyph data for U+%04X", first_unicode)
        end
    end
    for index, udglyph in next, data.udglyphs do
        local kerns = udglyph.kerns
        if kerns then
            local glyph = glyphs[index]
            local newkerns = { }
            for k,v in next, kerns do
                local vc, vo, vl = v.char, v.off, v.lookup
                if vc and vo and vl then -- brrr, wrong! we miss the non unicode ones
                    local uvc = unicodes[vc]
                    if not uvc then
                        if trace_loading then
                            report_otf("problems with unicode %s of kern %s at glyph %s",vc,k,index)
                        end
                    else
                        if type(vl) ~= "table" then
                            vl = { vl }
                        end
                        for l=1,#vl do
                            local vll = vl[l]
                            local mkl = newkerns[vll]
                            if not mkl then
                                mkl = { }
                                newkerns[vll] = mkl
                            end
                            if type(uvc) == "table" then
                                for u=1,#uvc do
                                    mkl[uvc[u]] = vo
                                end
                            else
                                mkl[uvc] = vo
                            end
                        end
                    end
                end
            end
            glyph.kerns = newkerns -- udglyph.kerns = nil when in mixed mode
            mkdone = true
        end
    end
    if trace_loading and mkdone then
        report_otf("replacing 'kerns' tables by a new 'kerns' tables")
    end
    local dgpos = raw.gpos
    if dgpos then
        local separator = lpeg.P(" ")
        local other = ((1 - separator)^0) / unicodes
        local splitter = lpeg.Ct(other * (separator * other)^0)
        for gp=1,#dgpos do
            local gpos = dgpos[gp]
            local subtables = gpos.subtables
            if subtables then
                for s=1,#subtables do
                    local subtable = subtables[s]
                    local kernclass = subtable.kernclass -- name is inconsistent with anchor_classes
                    if kernclass then -- the next one is quite slow
                        local split = { } -- saves time
                        for k=1,#kernclass do
                            local kcl = kernclass[k]
                            local firsts, seconds, offsets, lookups = kcl.firsts, kcl.seconds, kcl.offsets, kcl.lookup -- singular
                            if type(lookups) ~= "table" then
                                lookups = { lookups }
                            end
                            local maxfirsts, maxseconds = getn(firsts), getn(seconds)
                            -- here we could convert split into a list of unicodes which is a bit
                            -- faster but as this is only done when caching it does not save us much
                            for _, s in next, firsts do
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            for _, s in next, seconds do
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            for l=1,#lookups do
                                local lookup = lookups[l]
                                for fk=1,#firsts do
                                    local fv = firsts[fk]
                                    local splt = split[fv]
                                    if splt then
                                        local kerns, baseoffset = { }, (fk-1) * maxseconds
                                        for sk=2,maxseconds do
                                            local sv = seconds[sk]
                                            local splt = split[sv]
                                            if splt then
                                                local offset = offsets[baseoffset + sk]
                                                if offset then
                                                    for i=1,#splt do
                                                        local second_unicode = splt[i]
                                                        if tonumber(second_unicode) then
                                                            kerns[second_unicode] = offset
                                                        else for s=1,#second_unicode do
                                                            kerns[second_unicode[s]] = offset
                                                        end end
                                                    end
                                                end
                                            end
                                        end
                                        for i=1,#splt do
                                            local first_unicode = splt[i]
                                            if tonumber(first_unicode) then
                                                do_it(lookup,first_unicode,kerns)
                                            else for f=1,#first_unicode do
                                                do_it(lookup,first_unicode[f],kerns)
                                            end end
                                        end
                                    end
                                end
                            end
                        end
                        subtable.comment = "The kernclass table is merged into kerns in the indexed glyph tables."
                        subtable.kernclass = { }
                    end
                end
            end
        end
    end
end

actions["check glyphs"] = function(data,filename,raw)
    local verbose = fonts.verbose
    local int_to_uni = data.luatex.unicodes
    for k, v in next, data.glyphs do
        if verbose then
            local code = int_to_uni[k]
            -- looks like this is done twice ... bug?
            if code then
                local vu = v.unicode
                if not vu then
                    v.unicode = code
                elseif type(vu) == "table" then
                    if vu[#vu] == code then
                        -- weird
                    else
                        vu[#vu+1] = code
                    end
                elseif vu ~= code then
                    v.unicode = { vu, code }
                end
            end
        else
            v.unicode = nil
            v.index = nil
        end
        -- only needed on non sparse/mixed mode
        if v.math then
            if v.mathkern      then v.mathkern      = nil end
            if v.horiz_variant then v.horiz_variant = nil end
            if v.vert_variants then v.vert_variants = nil end
        end
        --
    end
    data.luatex.comment = "Glyph tables have their original index. When present, kern tables are indexed by unicode."
end

actions["check metadata"] = function(data,filename,raw)
    local metadata = data.metadata
    metadata.method = loadmethod
    if loadmethod == "sparse" then
        for _, k in next, mainfields do
            if valid_fields[k] then
                local v = raw[k]
                if global_fields[k] then
                    if not data[k] then
                        data[k] = v
                    end
                else
                    if not metadata[k] then
                        metadata[k] = v
                    end
                end
            end
        end
    else
        for k, v in next, raw do
            if valid_fields[k] then
                if global_fields[k] then
                    if not data[k] then
                        data[v] = v
                    end
                else
                    if not metadata[k] then
                        metadata[k] = v
                    end
                end
            end
        end
    end
    local pfminfo = raw.pfminfo
    if pfminfo then
        data.pfminfo = pfminfo
        metadata.isfixedpitch = metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose.proportion == "Monospaced")
        metadata.charwidth    = pfminfo and pfminfo.avgwidth
    end
    local ttftables = metadata.ttf_tables
    if ttftables then
        for i=1,#ttftables do
            ttftables[i].data = "deleted"
        end
    end
    metadata.xuid = nil
    data.udglyphs = nil
    data.map = nil
end

local private_mathparameters = {
    "FractionDelimiterSize",
    "FractionDelimiterDisplayStyleSize",
}

actions["check math parameters"] = function(data,filename,raw)
    local mathdata = data.metadata.math
    if mathdata then
        for m=1,#private_mathparameters do
            local pmp = private_mathparameters[m]
            if not mathdata[pmp] then
                if trace_loading then
                    report_otf("setting math parameter '%s' to 0", pmp)
                end
                mathdata[pmp] = 0
            end
        end
    end
end


-- kern: ttf has a table with kerns
--
-- Weird, as maxfirst and maxseconds can have holes, first seems to be indexed, but
-- seconds can start at 2 .. this need to be fixed as getn as well as # are sort of
-- unpredictable alternatively we could force an [1] if not set (maybe I will do that
-- anyway).

actions["reorganize glyph lookups"] = function(data,filename,raw)
    local glyphs = data.glyphs
    for index, udglyph in next, data.udglyphs do
        local lookups = udglyph.lookups
        if lookups then
            local glyph = glyphs[index]
            local l = { }
            for kk, vv in next, lookups do
                local aa = { }
                l[kk] = aa
                for kkk=1,#vv do
                    local vvv = vv[kkk]
                    local s = vvv.specification
                    local t = vvv.type
                    -- #aa+1
                    if t == "ligature" then
                        aa[kkk] = { "ligature", s.components, s.char }
                    elseif t == "alternate" then
                        aa[kkk] = { "alternate", s.components }
                    elseif t == "substitution" then
                        aa[kkk] = { "substitution", s.variant }
                    elseif t == "multiple" then
                        aa[kkk] = { "multiple", s.components }
                    elseif t == "position" then
                        aa[kkk] = { "position", { s.x or 0, s.y or 0, s.h or 0, s.v or 0 } }
                    elseif t == "pair" then
                        -- maybe flatten this one
                        local one, two, paired = s.offsets[1], s.offsets[2], s.paired or ""
                        if one then
                            if two then
                                aa[kkk] = { "pair", paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0 } }
                            else
                                aa[kkk] = { "pair", paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 } }
                            end
                        else
                            if two then
                                aa[kkk] = { "pair", paired, { }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0} } -- maybe nil instead of { }
                            else
                                aa[kkk] = { "pair", paired }
                            end
                        end
                    end
                end
            end
            -- we could combine this
            local slookups, mlookups
            for kk, vv in next, l do
                if #vv == 1 then
                    if not slookups then
                        slookups = { }
                        glyph.slookups = slookups
                    end
                    slookups[kk] = vv[1]
                else
                    if not mlookups then
                        mlookups = { }
                        glyph.mlookups = mlookups
                    end
                    mlookups[kk] = vv
                end
            end
            glyph.lookups = nil -- when using table
        end
    end
end

actions["reorganize glyph anchors"] = function(data,filename,raw)
    local glyphs = data.glyphs
    for index, udglyph in next, data.udglyphs do
        local anchors = udglyph.anchors
        if anchors then
            local glyph = glyphs[index]
            local a = { }
            glyph.anchors = a
            for kk, vv in next, anchors do
                local aa = { }
                a[kk] = aa
                for kkk, vvv in next, vv do
                    if vvv.x or vvv.y then
                        aa[kkk] = { vvv.x , vvv.y }
                    else
                        local aaa = { }
                        aa[kkk] = aaa
                        for kkkk=1,#vvv do
                            local vvvv = vvv[kkkk]
                            aaa[kkkk] = { vvvv.x, vvvv.y }
                        end
                    end
                end
            end
        end
    end
end

--~ actions["check extra features"] = function(data,filename,raw)
--~     -- later, ctx only
--~ end

-- -- -- -- -- --
-- -- -- -- -- --

function features.register(name,default,description)
    featurelist[#featurelist+1] = name
    defaultfeatures[name] = default
    if description and description ~= "" then
        fonts.otf.tables.features[name] = description
    end
end

-- for context this will become a task handler

local lists = { -- why local
    fonts.triggers,
    fonts.processors,
    fonts.manipulators,
}

function otf.setfeatures(tfmdata,features)
    local processes = { }
    if features and next(features) then
        local mode = tfmdata.mode or features.mode or "base"
        local initializers = fonts.initializers
        local fi = initializers[mode]
        if fi then
            local fiotf = fi.otf
            if fiotf then
                local done = { }
                for l=1,#lists do
                    local list = lists[l]
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            local value = features[f]
                            if value and fiotf[f] then -- brr
                                if not done[f] then -- so, we can move some to triggers
                                    if trace_features then
                                        report_otf("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown', tfmdata.fullname or 'unknown')
                                    end
                                    fiotf[f](tfmdata,value) -- can set mode (no need to pass otf)
                                    mode = tfmdata.mode or features.mode or "base"
                                    local im = initializers[mode]
                                    if im then
                                        fiotf = initializers[mode].otf
                                    end
                                    done[f] = true
                                end
                            end
                        end
                    end
                end
            end
        end
tfmdata.mode = mode
        local fm = fonts.methods[mode] -- todo: zonder node/mode otf/...
        if fm then
            local fmotf = fm.otf
            if fmotf then
                for l=1,#lists do
                    local list = lists[l]
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            if fmotf[f] then -- brr
                                if trace_features then
                                    report_otf("installing feature handler %s for mode %s for font %s",f,mode or 'unknown', tfmdata.fullname or 'unknown')
                                end
                                processes[#processes+1] = fmotf[f]
                            end
                        end
                    end
                end
            end
        else
            -- message
        end
    end
    return processes, features
end

-- the first version made a top/mid/not extensible table, now we just pass on the variants data
-- and deal with it in the tfm scaler (there is no longer an extensible table anyway)

-- we cannot share descriptions as virtual fonts might extend them (ok, we could
-- use a cache with a hash

local function copytotfm(data,cache_id) -- we can save a copy when we reorder the tma to unicode (nasty due to one->many)
    if data then
        local glyphs, pfminfo, metadata = data.glyphs or { }, data.pfminfo or { }, data.metadata or { }
        local luatex = data.luatex
        local unicodes = luatex.unicodes -- names to unicodes
        local indices = luatex.indices
        local mode = data.mode or "base"
        local characters, parameters, mathparameters, descriptions = { }, { }, { }, { }
        local designsize = metadata.designsize or metadata.design_size or 100
        if designsize == 0 then
            designsize = 100
        end
        local spaceunits, spacer = 500, "space"
        -- indices maps from unicodes to indices
        -- this wil stay as we can manipulate indices
        -- beforehand
        for u, i in next, indices do
            characters[u] = { } -- we need this because for instance we add protruding info and loop over characters
            descriptions[u] = glyphs[i]
        end
        -- math
        if metadata.math then
            -- parameters
            for name, value in next, metadata.math do
                mathparameters[name] = value
            end
            -- we could use a subset
            for u, char in next, characters do
                local d = descriptions[u]
                local m = d.math
                -- we have them shared because that packs nicer
                -- we could prepare the variants and keep 'm in descriptions
                if m then
                    local variants, parts, c = m.horiz_variants, m.horiz_parts, char
                    if variants then
                        for n in gmatch(variants,"[^ ]+") do
                            local un = unicodes[n]
                            if un and u ~= un then
                                c.next = un
                                c = characters[un]
                            end
                        end
                        c.horiz_variants = parts
                    elseif parts then
                        c.horiz_variants = parts
                    end
                    local variants, parts, c = m.vert_variants, m.vert_parts, char
                    if variants then
                        for n in gmatch(variants,"[^ ]+") do
                            local un = unicodes[n]
                            if un and u ~= un then
                                c.next = un
                                c = characters[un]
                            end
                        end -- c is now last in chain
                        c.vert_variants = parts
                    elseif parts then
                        c.vert_variants = parts
                    end
                    local italic_correction = m.vert_italic_correction
                    if italic_correction then
                        c.vert_italic_correction = italic_correction
                    end
                    local kerns = m.kerns
                    if kerns then
                        char.mathkerns = kerns
                    end
                end
            end
        end
        -- end math
        local space, emdash = 0x20, 0x2014 -- unicodes['space'], unicodes['emdash']
        if metadata.isfixedpitch then
            if descriptions[space] then
                spaceunits, spacer = descriptions[space].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        else
            if descriptions[space] then
                spaceunits, spacer = descriptions[space].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width/2, "emdash/2"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits) or 500 -- brrr
        -- we need a runtime lookup because of running from cdrom or zip, brrr (shouldn't we use the basename then?)
        local filename = fonts.tfm.checkedfilename(luatex)
        local fontname = metadata.fontname
        local fullname = metadata.fullname or fontname
        local cidinfo  = data.cidinfo -- or { }
        local units    = metadata.units_per_em or 1000
        --
        cidinfo.registry = cidinfo and cidinfo.registry or "" -- weird here, fix upstream
        --
        parameters.slant         = 0
        parameters.space         = spaceunits          -- 3.333 (cmr10)
        parameters.space_stretch = units/2   --  500   -- 1.666 (cmr10)
        parameters.space_shrink  = 1*units/3 --  333   -- 1.111 (cmr10)
        parameters.x_height      = 2*units/5 --  400
        parameters.quad          = units     -- 1000
        if spaceunits < 2*units/5 then
            -- todo: warning
        end
        local italicangle = metadata.italicangle
        if italicangle then -- maybe also in afm _
            parameters.slant = parameters.slant - math.round(math.tan(italicangle*math.pi/180))
        end
        if metadata.isfixedpitch then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif syncspace then --
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        parameters.extra_space = parameters.space_shrink -- 1.111 (cmr10)
        if pfminfo.os2_xheight and pfminfo.os2_xheight > 0 then
            parameters.x_height = pfminfo.os2_xheight
        else
            local x = 0x78 -- unicodes['x']
            if x then
                local x = descriptions[x]
                if x then
                    parameters.x_height = x.height
                end
            end
        end
        --
        local fileformat = data.format or fonts.fontformat(filename,"opentype")
        if units > 1000  then
            fileformat = "truetype"
        end
        return {
            characters         = characters,
            parameters         = parameters,
            mathparameters     = mathparameters,
            descriptions       = descriptions,
            indices            = indices,
            unicodes           = unicodes,
            type               = "real",
            direction          = 0,
            boundarychar_label = 0,
            boundarychar       = 65536,
            designsize         = (designsize/10)*65536,
            encodingbytes      = 2,
            mode               = mode,
            filename           = filename,
            fontname           = fontname,
            fullname           = fullname,
            psname             = fontname or fullname,
            name               = filename or fullname,
            units              = units,
            format             = fileformat,
            cidinfo            = cidinfo,
            ascender           = abs(metadata.ascent  or 0),
            descender          = abs(metadata.descent or 0),
            spacer             = spacer,
            italicangle        = italicangle,
        }
    else
        return nil
    end
end

local function otftotfm(specification)
    local name     = specification.name
    local sub      = specification.sub
    local filename = specification.filename
    local format   = specification.format
    local features = specification.features.normal
    local cache_id = specification.hash
    local tfmdata  = containers.read(tfm.cache,cache_id)
--~ print(cache_id)
    if not tfmdata then
        local otfdata = otf.load(filename,format,sub,features and features.featurefile)
        if otfdata and next(otfdata) then
            otfdata.shared = otfdata.shared or {
                featuredata = { },
                anchorhash  = { },
                initialized = false,
            }
            tfmdata = copytotfm(otfdata,cache_id)
            if tfmdata and next(tfmdata) then
                tfmdata.unique = tfmdata.unique or { }
                tfmdata.shared = tfmdata.shared or { } -- combine
                local shared = tfmdata.shared
                shared.otfdata = otfdata
                shared.features = features -- default
                shared.dynamics = { }
                shared.processes = { }
                shared.setdynamics = otf.setdynamics -- fast access and makes other modules independent
                -- this will be done later anyway, but it's convenient to have
                -- them already for fast access
                tfmdata.luatex = otfdata.luatex
                tfmdata.indices = otfdata.luatex.indices
                tfmdata.unicodes = otfdata.luatex.unicodes
                tfmdata.marks = otfdata.luatex.marks
                tfmdata.originals = otfdata.luatex.originals
                tfmdata.changed = { }
                tfmdata.has_italic = otfdata.metadata.has_italic
                if not tfmdata.language then tfmdata.language = 'dflt' end
                if not tfmdata.script   then tfmdata.script   = 'dflt' end
                -- at this moment no characters are assinged yet, only empty slots
                shared.processes, shared.features = otf.setfeatures(tfmdata,definers.check(features,defaultfeatures))
            end
        end
        containers.write(tfm.cache,cache_id,tfmdata)
    end
    return tfmdata
end

features.register('mathsize')

local function read_from_otf(specification) -- wrong namespace
    local tfmtable = otftotfm(specification)
    if tfmtable then
        local otfdata = tfmtable.shared.otfdata
        tfmtable.name = specification.name
        tfmtable.sub = specification.sub
        local s = specification.size
        local m = otfdata.metadata.math
        if m then
            -- this will move to a function
            local f = specification.features
            if f then
                local f = f.normal
                if f and f.mathsize then
                    local mathsize = specification.mathsize or 0
                    if mathsize == 2 then
                        local p = m.ScriptPercentScaleDown
                        if p then
                            local ps = p * specification.textsize / 100
                            if trace_math then
                                report_otf("asked script size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
                            end
                            s = ps
                        end
                    elseif mathsize == 3 then
                        local p = m.ScriptScriptPercentScaleDown
                        if p then
                            local ps = p * specification.textsize / 100
                            if trace_math then
                                report_otf("asked scriptscript size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
                            end
                            s = ps
                        end
                    end
                end
            end
        end
        tfmtable = tfm.scale(tfmtable,s,specification.relativeid)
        if tfm.fontnamemode == "specification" then
            -- not to be used in context !
            local specname = specification.specification
            if specname then
                tfmtable.name = specname
                if trace_defining then
                    report_otf("overloaded fontname: '%s'",specname)
                end
            end
        end
        fonts.logger.save(tfmtable,file.extname(specification.filename),specification)
    end
--~ print(tfmtable.fullname)
    return tfmtable
end

-- helpers

function otf.collectlookups(otfdata,kind,script,language)
    -- maybe store this in the font
    local sequences = otfdata.luatex.sequences
    if sequences then
        local featuremap, featurelist = { }, { }
        for s=1,#sequences do
            local sequence = sequences[s]
            local features = sequence.features
            features = features and features[kind]
            features = features and (features[script]   or features[default] or features[wildcard])
            features = features and (features[language] or features[default] or features[wildcard])
            if features then
                local subtables = sequence.subtables
                if subtables then
                    for s=1,#subtables do
                        local ss = subtables[s]
                        if not featuremap[s] then
                            featuremap[ss] = true
                            featurelist[#featurelist+1] = ss
                        end
                    end
                end
            end
        end
        if #featurelist > 0 then
            return featuremap, featurelist
        end
    end
    return nil, nil
end

-- readers

fonts.formats.dfont = "truetype"
fonts.formats.ttc   = "truetype"
fonts.formats.ttf   = "truetype"
fonts.formats.otf   = "opentype"

local function check_otf(forced,specification,suffix,what)
    local name = specification.name
    if forced then
        name = file.addsuffix(name,suffix,true)
    end
    local fullname, tfmtable = findbinfile(name,suffix) or "", nil -- one shot
 -- if false then  -- can be enabled again when needed
     -- if fullname == "" then
     --     local fb = fonts.names.old_to_new[name]
     --     if fb then
     --         fullname = findbinfile(fb,suffix) or ""
     --     end
     -- end
     -- if fullname == "" then
     --     local fb = fonts.names.new_to_old[name]
     --     if fb then
     --         fullname = findbinfile(fb,suffix) or ""
     --     end
     -- end
 -- end
    if fullname == "" then
        fullname = fonts.names.getfilename(name,suffix)
    end
    if fullname ~= "" then
        specification.filename, specification.format = fullname, what -- hm, so we do set the filename, then
        tfmtable = read_from_otf(specification)                       -- we need to do it for all matches / todo
    end
    return tfmtable
end

function readers.opentype(specification,suffix,what)
    local forced = specification.forced or ""
    if forced == "otf" then
        return check_otf(true,specification,forced,"opentype")
    elseif forced == "ttf" or forced == "ttc" or forced == "dfont" then
        return check_otf(true,specification,forced,"truetype")
    else
        return check_otf(false,specification,suffix,what)
    end
end

function readers.otf  (specification) return readers.opentype(specification,"otf","opentype") end
function readers.ttf  (specification) return readers.opentype(specification,"ttf","truetype") end
function readers.ttc  (specification) return readers.opentype(specification,"ttf","truetype") end -- !!
function readers.dfont(specification) return readers.opentype(specification,"ttf","truetype") end -- !!

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otd'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_dynamics = false  trackers.register("otf.dynamics", function(v) trace_dynamics = v end)

local report_otf = logs.reporter("fonts","otf loading")

local fonts          = fonts
local otf            = fonts.otf
local fontdata       = fonts.identifiers

otf.features         = otf.features         or { }
otf.features.default = otf.features.default or { }

local definers       = fonts.definers
local contextsetups  = definers.specifiers.contextsetups
local contextnumbers = definers.specifiers.contextnumbers

-- todo: dynamics namespace

local a_to_script   = { }
local a_to_language = { }

function otf.setdynamics(font,dynamics,attribute)
    local features = contextsetups[contextnumbers[attribute]] -- can be moved to caller
    if features then
        local script   = features.script   or 'dflt'
        local language = features.language or 'dflt'
        local ds = dynamics[script]
        if not ds then
            ds = { }
            dynamics[script] = ds
        end
        local dsl = ds[language]
        if not dsl then
            dsl = { }
            ds[language] = dsl
        end
        local dsla = dsl[attribute]
        if dsla then
        --  if trace_dynamics then
        --      report_otf("using dynamics %s: attribute %s, script %s, language %s",contextnumbers[attribute],attribute,script,language)
        --  end
            return dsla
        else
            local tfmdata = fontdata[font]
            a_to_script  [attribute] = script
            a_to_language[attribute] = language
            -- we need to save some values
            local saved = {
                script    = tfmdata.script,
                language  = tfmdata.language,
                mode      = tfmdata.mode,
                features  = tfmdata.shared.features
            }
            tfmdata.mode     = "node"
            tfmdata.dynamics = true -- handy for tracing
            tfmdata.language = language
            tfmdata.script   = script
            tfmdata.shared.features = { }
            -- end of save
            local set = definers.check(features,otf.features.default)
            dsla = otf.setfeatures(tfmdata,set)
            if trace_dynamics then
                report_otf("setting dynamics %s: attribute %s, script %s, language %s, set: %s",contextnumbers[attribute],attribute,script,language,table.sequenced(set))
            end
            -- we need to restore some values
            tfmdata.script          = saved.script
            tfmdata.language        = saved.language
            tfmdata.mode            = saved.mode
            tfmdata.shared.features = saved.features
            -- end of restore
            dynamics[script][language][attribute] = dsla -- cache
            return dsla
        end
    end
    return nil -- { }
end

function otf.scriptandlanguage(tfmdata,attr)
    if attr and attr > 0 then
        return a_to_script[attr] or tfmdata.script, a_to_language[attr] or tfmdata.language
    else
        return tfmdata.script, tfmdata.language
    end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-oti'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower = string.lower

local fonts = fonts

local otf          = fonts.otf
local initializers = fonts.initializers

local languages    = otf.tables.languages
local scripts      = otf.tables.scripts

local function set_language(tfmdata,value)
    if value then
        value = lower(value)
        if languages[value] then
            tfmdata.language = value
        end
    end
end

local function set_script(tfmdata,value)
    if value then
        value = lower(value)
        if scripts[value] then
            tfmdata.script = value
        end
    end
end

local function set_mode(tfmdata,value)
    if value then
        tfmdata.mode = lower(value)
    end
end

local base_initializers = initializers.base.otf
local node_initializers = initializers.node.otf

base_initializers.language = set_language
base_initializers.script   = set_script
base_initializers.mode     = set_mode
base_initializers.method   = set_mode

node_initializers.language = set_language
node_initializers.script   = set_script
node_initializers.mode     = set_mode
node_initializers.method   = set_mode

otf.features.register("features",true)     -- we always do features
table.insert(fonts.processors,"features")  -- we need a proper function for doing this


end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otb'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local lpegmatch = lpeg.match

local fonts = fonts
local otf   = fonts.otf
local tfm   = fonts.tfm

local trace_baseinit     = false  trackers.register("otf.baseinit",     function(v) trace_baseinit     = v end)
local trace_singles      = false  trackers.register("otf.singles",      function(v) trace_singles      = v end)
local trace_multiples    = false  trackers.register("otf.multiples",    function(v) trace_multiples    = v end)
local trace_alternatives = false  trackers.register("otf.alternatives", function(v) trace_alternatives = v end)
local trace_ligatures    = false  trackers.register("otf.ligatures",    function(v) trace_ligatures    = v end)
local trace_kerns        = false  trackers.register("otf.kerns",        function(v) trace_kerns        = v end)
local trace_preparing    = false  trackers.register("otf.preparing",    function(v) trace_preparing    = v end)

local report_prepare = logs.reporter("fonts","otf prepare")

local wildcard = "*"
local default  = "dflt"

local split_at_space = lpeg.Ct(lpeg.splitat(" ")) -- no trailing or multiple spaces anyway

local pcache, fcache = { }, { } -- could be weak

local function gref(descriptions,n)
    if type(n) == "number" then
        local name = descriptions[n].name
        if name then
            return format("U+%04X (%s)",n,name)
        else
            return format("U+%04X")
        end
    elseif n then
        local num, nam = { }, { }
        for i=1,#n do
            local ni = n[i]
            -- ! ! ! could be a helper ! ! !
            if type(ni) == "table" then
                local nnum, nnam = { }, { }
                for j=1,#ni do
                    local nj = ni[j]
                    nnum[j] = format("U+%04X",nj)
                    nnam[j] = descriptions[nj].name or "?"
                end
                num[i] = concat(nnum,"|")
                nam[i] = concat(nnam,"|")
            else
                num[i] = format("U+%04X",ni)
                nam[i] = descriptions[ni].name or "?"
            end
        end
        return format("%s (%s)",concat(num," "), concat(nam," "))
    else
        return "?"
    end
end

local function cref(kind,lookupname)
    if lookupname then
        return format("feature %s, lookup %s",kind,lookupname)
    else
        return format("feature %s",kind)
    end
end

local function resolve_ligatures(tfmdata,ligatures,kind)
    kind = kind or "unknown"
    local unicodes = tfmdata.unicodes
    local characters = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local changed = tfmdata.changed
    local done  = { }
    while true do
        local ok = false
        for k,v in next, ligatures do
            local lig = v[1]
            if not done[lig] then
                local ligs = lpegmatch(split_at_space,lig)
                if #ligs == 2 then
                    local uc = v[2]
                    local c, f, s = characters[uc], ligs[1], ligs[2]
                    local uft, ust = unicodes[f] or 0, unicodes[s] or 0
                    if not uft or not ust then
                        report_prepare("%s: unicode problem with base ligature %s = %s + %s",cref(kind),gref(descriptions,uc),gref(descriptions,uft),gref(descriptions,ust))
                        -- some kind of error
                    else
                        if type(uft) == "number" then uft = { uft } end
                        if type(ust) == "number" then ust = { ust } end
                        for ufi=1,#uft do
                            local uf = uft[ufi]
                            for usi=1,#ust do
                                local us = ust[usi]
                                if changed[uf] or changed[us] then
                                    if trace_baseinit and trace_ligatures then
                                        report_prepare("%s: base ligature %s + %s ignored",cref(kind),gref(descriptions,uf),gref(descriptions,us))
                                    end
                                else
                                    local first, second = characters[uf], us
                                    if first and second then
                                        local t = first.ligatures
                                        if not t then
                                            t = { }
                                            first.ligatures = t
                                        end
                                        if type(uc) == "number" then
                                            t[second] = { type = 0, char = uc }
                                        else
                                            t[second] = { type = 0, char = uc[1] } -- can this still happen?
                                        end
                                        if trace_baseinit and trace_ligatures then
                                            report_prepare("%s: base ligature %s + %s => %s",cref(kind),gref(descriptions,uf),gref(descriptions,us),gref(descriptions,uc))
                                        end
                                    end
                                end
                            end
                        end
                    end
                    ok, done[lig] = true, descriptions[uc].name
                end
            end
        end
        if ok then
            -- done has "a b c" = "a_b_c" and ligatures the already set ligatures: "a b" = 123
            -- and here we add extras (f i i = fi + i and alike)
            --
            -- we could use a hash for fnc and pattern
            --
            -- this might be interfering !
            for d,n in next, done do
                local pattern = pcache[d] if not pattern then pattern = "^(" .. d .. ") "              pcache[d] = pattern end
                local fnc     = fcache[n] if not fnc     then fnc     = function() return n .. " " end fcache[n] = fnc     end
                for k,v in next, ligatures do
                    v[1] = gsub(v[1],pattern,fnc)
                end
            end
        else
            break
        end
    end
end

local splitter = lpeg.splitat(" ")

local function prepare_base_substitutions(tfmdata,kind,value) -- we can share some code with the node features
    if value then
        local otfdata = tfmdata.shared.otfdata
        local validlookups, lookuplist = otf.collectlookups(otfdata,kind,tfmdata.script,tfmdata.language)
        if validlookups then
            local ligatures = { }
            local unicodes = tfmdata.unicodes -- names to unicodes
            local indices = tfmdata.indices
            local characters = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local changed = tfmdata.changed
            --
            local actions = {
                substitution = function(p,lookup,k,glyph,unicode)
                    local pv = p[2] -- p.variant
                    if pv then
                        local upv = unicodes[pv]
                        if upv then
                            if type(upv) == "table" then -- zero change that table
                                upv = upv[1]
                            end
                            if characters[upv] then
                                if trace_baseinit and trace_singles then
                                    report_prepare("%s: base substitution %s => %s",cref(kind,lookup),gref(descriptions,k),gref(descriptions,upv))
                                end
                                changed[k] = upv
                            end
                        end
                    end
                end,
                alternate = function(p,lookup,k,glyph,unicode)
                    local pc = p[2] -- p.components
                    if pc then
                        -- a bit optimized ugliness
                        if value == 1 then
                            pc = lpegmatch(splitter,pc)
                        elseif value == 2 then
                            local a, b = lpegmatch(splitter,pc)
                            pc = b or a
                        else
                            pc = { lpegmatch(splitter,pc) }
                            pc = pc[value] or pc[#pc]
                        end
                        if pc then
                            local upc = unicodes[pc]
                            if upc then
                                if type(upc) == "table" then -- zero change that table
                                    upc = upc[1]
                                end
                                if characters[upc] then
                                    if trace_baseinit and trace_alternatives then
                                        report_prepare("%s: base alternate %s %s => %s",cref(kind,lookup),tostring(value),gref(descriptions,k),gref(descriptions,upc))
                                    end
                                    changed[k] = upc
                                end
                            end
                        end
                    end
                end,
                ligature = function(p,lookup,k,glyph,unicode)
                    local pc = p[2]
                    if pc then
                        if trace_baseinit and trace_ligatures then
                            local upc = { lpegmatch(splitter,pc) }
                            for i=1,#upc do upc[i] = unicodes[upc[i]] end
                            -- we assume that it's no table
                            report_prepare("%s: base ligature %s => %s",cref(kind,lookup),gref(descriptions,upc),gref(descriptions,k))
                        end
                        ligatures[#ligatures+1] = { pc, k }
                    end
                end,
            }
            --
            for k,c in next, characters do
                local glyph = descriptions[k]
                local lookups = glyph.slookups
                if lookups then
                    for l=1,#lookuplist do
                        local lookup = lookuplist[l]
                        local p = lookups[lookup]
                        if p then
                            local a = actions[p[1]]
                            if a then
                                a(p,lookup,k,glyph,unicode)
                            end
                        end
                    end
                end
                local lookups = glyph.mlookups
                if lookups then
                    for l=1,#lookuplist do
                        local lookup = lookuplist[l]
                        local ps = lookups[lookup]
                        if ps then
                            for i=1,#ps do
                                local p = ps[i]
                                local a = actions[p[1]]
                                if a then
                                    a(p,lookup,k,glyph,unicode)
                                end
                            end
                        end
                    end
                end
            end
            resolve_ligatures(tfmdata,ligatures,kind)
        end
    else
        tfmdata.ligatures = tfmdata.ligatures or { } -- left over from what ?
    end
end

local function preparebasekerns(tfmdata,kind,value) -- todo what kind of kerns, currently all
    if value then
        local otfdata = tfmdata.shared.otfdata
        local validlookups, lookuplist = otf.collectlookups(otfdata,kind,tfmdata.script,tfmdata.language)
        if validlookups then
            local unicodes = tfmdata.unicodes -- names to unicodes
            local indices = tfmdata.indices
            local characters = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local sharedkerns = { }
            for u, chr in next, characters do
                local d = descriptions[u]
                if d then
                    local dk = d.kerns -- shared
                    if dk then
                        local s = sharedkerns[dk]
                        if s == false then
                            -- skip
                        elseif s then
                            chr.kerns = s
                        else
                            local t, done = chr.kerns or { }, false
                            for l=1,#lookuplist do
                                local lookup = lookuplist[l]
                                local kerns = dk[lookup]
                                if kerns then
                                    for k, v in next, kerns do
                                        if v ~= 0 and not t[k] then -- maybe no 0 test here
                                            t[k], done = v, true
                                            if trace_baseinit and trace_kerns then
                                                report_prepare("%s: base kern %s + %s => %s",cref(kind,lookup),gref(descriptions,u),gref(descriptions,k),v)
                                            end
                                        end
                                    end
                                end
                            end
                            if done then
                                sharedkerns[dk] = t
                                chr.kerns = t -- no empty assignments
                            else
                                sharedkerns[dk] = false
                            end
                        end
                    end
                end
            end
        end
    end
end

-- In principle we could register each feature individually which was
-- what we did in earlier versions. However, after the rewrite it
-- made more sense to collect them in an overall features initializer
-- just as with the node variant. There it was needed because we need
-- to do complete mixed runs and not run featurewise (as we did before).

local supported_gsub = {
    'liga', 'dlig', 'rlig', 'hlig',
    'pnum', 'onum', 'tnum', 'lnum',
    'zero',
    'smcp', 'cpsp', 'c2sc', 'ornm', 'aalt',
    'hwid', 'fwid',
    'ssty', 'rtlm', -- math
--  'tlig', 'trep',
}

local supported_gpos = {
    'kern'
}

function otf.features.registerbasesubstitution(tag)
    supported_gsub[#supported_gsub+1] = tag
end
function otf.features.registerbasekern(tag)
    supported_gsub[#supported_gpos+1] = tag
end

local basehash, basehashes = { }, 1

function fonts.initializers.base.otf.features(tfmdata,value)
    if true then -- value then
        -- not shared
        local t = trace_preparing and os.clock()
        local features = tfmdata.shared.features
        if features then
            local h = { }
            for f=1,#supported_gsub do
                local feature = supported_gsub[f]
                local value = features[feature]
                prepare_base_substitutions(tfmdata,feature,value)
                if value then
                    h[#h+1] = feature  .. "=" .. tostring(value)
                end
            end
            for f=1,#supported_gpos do
                local feature = supported_gpos[f]
                local value = features[feature]
                preparebasekerns(tfmdata,feature,features[feature])
                if value then
                    h[#h+1] = feature  .. "=" .. tostring(value)
                end
            end
            local hash = concat(h," ")
            local base = basehash[hash]
            if not base then
                basehashes = basehashes + 1
                base = basehashes
                basehash[hash] = base
            end
            -- We need to make sure that luatex sees the difference between
            -- base fonts that have different glyphs in the same slots in fonts
            -- that have the same fullname (or filename). LuaTeX will merge fonts
            -- eventually (and subset later on). If needed we can use a more
            -- verbose name as long as we don't use <()<>[]{}/%> and the length
            -- is < 128.
            tfmdata.fullname = tfmdata.fullname .. "-" .. base -- tfmdata.psname is the original
        --~ report_prepare("fullname base hash: '%s', featureset '%s'",tfmdata.fullname,hash)
        end
        if trace_preparing then
            report_prepare("preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.fullname or "?")
        end
    end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is still somewhat preliminary and it will get better in due time;
-- much functionality could only be implemented thanks to the husayni font
-- of Idris Samawi Hamid to who we dedicate this module.

-- I'm in the process of cleaning up the code (which happens in another
-- file) so don't rely on things staying the same.

-- some day when we can jit this, we can use more functions

-- we can use more lpegs when lpeg is extended with function args and so
-- resolving to unicode does not gain much

-- in retrospect it always looks easy but believe it or not, it took a lot
-- of work to get proper open type support done: buggy fonts, fuzzy specs,
-- special made testfonts, many skype sessions between taco, idris and me,
-- torture tests etc etc ... unfortunately the code does not show how much
-- time it took ...

-- todo:
--
-- kerning is probably not yet ok for latin around dics nodes
-- extension infrastructure (for usage out of context)
-- sorting features according to vendors/renderers
-- alternative loop quitters
-- check cursive and r2l
-- find out where ignore-mark-classes went
-- remove unused tables
-- slide tail (always glue at the end so only needed once
-- default features (per language, script)
-- cleanup kern(class) code, remove double info
-- handle positions (we need example fonts)
-- handle gpos_single (we might want an extra width field in glyph nodes because adding kerns might interfere)

--[[ldx--
<p>This module is a bit more split up that I'd like but since we also want to test
with plain <l n='tex'/> it has to be so. This module is part of <l n='context'/>
and discussion about improvements and functionality mostly happens on the
<l n='context'/> mailing list.</p>

<p>The specification of OpenType is kind of vague. Apart from a lack of a proper
free specifications there's also the problem that Microsoft and Adobe
may have their own interpretation of how and in what order to apply features.
In general the Microsoft website has more detailed specifications and is a
better reference. There is also some information in the FontForge help files.</p>

<p>Because there is so much possible, fonts might contain bugs and/or be made to
work with certain rederers. These may evolve over time which may have the side
effect that suddenly fonts behave differently.</p>

<p>After a lot of experiments (mostly by Taco, me and Idris) we're now at yet another
implementation. Of course all errors are mine and of course the code can be
improved. There are quite some optimizations going on here and processing speed
is currently acceptable. Not all functions are implemented yet, often because I
lack the fonts for testing. Many scripts are not yet supported either, but I will
look into them as soon as <l n='context'/> users ask for it.</p>

<p>Because there are different interpretations possible, I will extend the code
with more (configureable) variants. I can also add hooks for users so that they can
write their own extensions.</p>

<p>Glyphs are indexed not by unicode but in their own way. This is because there is no
relationship with unicode at all, apart from the fact that a font might cover certain
ranges of characters. One character can have multiple shapes. However, at the
<l n='tex'/> end we use unicode so and all extra glyphs are mapped into a private
space. This is needed because we need to access them and <l n='tex'/> has to include
then in the output eventually.</p>

<p>The raw table as it coms from <l n='fontforge'/> gets reorganized in to fit out needs.
In <l n='context'/> that table is packed (similar tables are shared) and cached on disk
so that successive runs can use the optimized table (after loading the table is
unpacked). The flattening code used later is a prelude to an even more compact table
format (and as such it keeps evolving).</p>

<p>This module is sparsely documented because it is a moving target. The table format
of the reader changes and we experiment a lot with different methods for supporting
features.</p>

<p>As with the <l n='afm'/> code, we may decide to store more information in the
<l n='otf'/> table.</p>

<p>Incrementing the version number will force a re-cache. We jump the number by one
when there's a fix in the <l n='fontforge'/> library or <l n='lua'/> code that
results in different tables.</p>
--ldx]]--

-- action                    handler     chainproc             chainmore              comment
--
-- gsub_single               ok          ok                    ok
-- gsub_multiple             ok          ok                    not implemented yet
-- gsub_alternate            ok          ok                    not implemented yet
-- gsub_ligature             ok          ok                    ok
-- gsub_context              ok          --
-- gsub_contextchain         ok          --
-- gsub_reversecontextchain  ok          --
-- chainsub                  --          ok
-- reversesub                --          ok
-- gpos_mark2base            ok          ok
-- gpos_mark2ligature        ok          ok
-- gpos_mark2mark            ok          ok
-- gpos_cursive              ok          untested
-- gpos_single               ok          ok
-- gpos_pair                 ok          ok
-- gpos_context              ok          --
-- gpos_contextchain         ok          --
--
-- actions:
--
-- handler   : actions triggered by lookup
-- chainproc : actions triggered by contextual lookup
-- chainmore : multiple substitutions triggered by contextual lookup (e.g. fij -> f + ij)
--
-- remark: the 'not implemented yet' variants will be done when we have fonts that use them
-- remark: we need to check what to do with discretionaries

local concat, insert, remove = table.concat, table.insert, table.remove
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local lpegmatch = lpeg.match
local random = math.random

local logs, trackers, fonts, nodes, attributes = logs, trackers, fonts, nodes, attributes

local otf = fonts.otf
local tfm = fonts.tfm

local trace_lookups      = false  trackers.register("otf.lookups",      function(v) trace_lookups      = v end)
local trace_singles      = false  trackers.register("otf.singles",      function(v) trace_singles      = v end)
local trace_multiples    = false  trackers.register("otf.multiples",    function(v) trace_multiples    = v end)
local trace_alternatives = false  trackers.register("otf.alternatives", function(v) trace_alternatives = v end)
local trace_ligatures    = false  trackers.register("otf.ligatures",    function(v) trace_ligatures    = v end)
local trace_contexts     = false  trackers.register("otf.contexts",     function(v) trace_contexts     = v end)
local trace_marks        = false  trackers.register("otf.marks",        function(v) trace_marks        = v end)
local trace_kerns        = false  trackers.register("otf.kerns",        function(v) trace_kerns        = v end)
local trace_cursive      = false  trackers.register("otf.cursive",      function(v) trace_cursive      = v end)
local trace_preparing    = false  trackers.register("otf.preparing",    function(v) trace_preparing    = v end)
local trace_bugs         = false  trackers.register("otf.bugs",         function(v) trace_bugs         = v end)
local trace_details      = false  trackers.register("otf.details",      function(v) trace_details      = v end)
local trace_applied      = false  trackers.register("otf.applied",      function(v) trace_applied      = v end)
local trace_steps        = false  trackers.register("otf.steps",        function(v) trace_steps        = v end)
local trace_skips        = false  trackers.register("otf.skips",        function(v) trace_skips        = v end)
local trace_directions   = false  trackers.register("otf.directions",   function(v) trace_directions   = v end)

local report_direct   = logs.reporter("fonts","otf direct")
local report_subchain = logs.reporter("fonts","otf subchain")
local report_chain    = logs.reporter("fonts","otf chain")
local report_process  = logs.reporter("fonts","otf process")
local report_prepare  = logs.reporter("fonts","otf prepare")

trackers.register("otf.verbose_chain", function(v) otf.setcontextchain(v and "verbose") end)
trackers.register("otf.normal_chain",  function(v) otf.setcontextchain(v and "normal")  end)

trackers.register("otf.replacements", "otf.singles,otf.multiples,otf.alternatives,otf.ligatures")
trackers.register("otf.positions","otf.marks,otf.kerns,otf.cursive")
trackers.register("otf.actions","otf.replacements,otf.positions")
trackers.register("otf.injections","nodes.injections")

trackers.register("*otf.sample","otf.steps,otf.actions,otf.analyzing")

local insert_node_after = node.insert_after
local delete_node       = nodes.delete
local copy_node         = node.copy
local find_node_tail    = node.tail or node.slide
local set_attribute     = node.set_attribute
local has_attribute     = node.has_attribute

local zwnj     = 0x200C
local zwj      = 0x200D
local wildcard = "*"
local default  = "dflt"

local split_at_space = lpeg.Ct(lpeg.splitat(" ")) -- no trailing or multiple spaces anyway

local nodecodes     = nodes.nodecodes
local whatcodes     = nodes.whatcodes
local glyphcodes    = nodes.glyphcodes

local glyph_code    = nodecodes.glyph
local glue_code     = nodecodes.glue
local disc_code     = nodecodes.disc
local whatsit_code  = nodecodes.whatsit

local dir_code      = whatcodes.dir
local localpar_code = whatcodes.localpar

local ligature_code = glyphcodes.ligature

local state    = attributes.private('state')
local markbase = attributes.private('markbase')
local markmark = attributes.private('markmark')
local markdone = attributes.private('markdone')
local cursbase = attributes.private('cursbase')
local curscurs = attributes.private('curscurs')
local cursdone = attributes.private('cursdone')
local kernpair = attributes.private('kernpair')

local injections  = nodes.injections
local setmark     = injections.setmark
local setcursive  = injections.setcursive
local setkern     = injections.setkern
local setpair     = injections.setpair

local markonce = true
local cursonce = true
local kernonce = true

local fontdata = fonts.identifiers

otf.features.process = { }

-- we share some vars here, after all, we have no nested lookups and
-- less code

local tfmdata       = false
local otfdata       = false
local characters    = false
local descriptions  = false
local marks         = false
local indices       = false
local unicodes      = false
local currentfont   = false
local lookuptable   = false
local anchorlookups = false
local handlers      = { }
local rlmode        = 0
local featurevalue  = false

-- we cheat a bit and assume that a font,attr combination are kind of ranged

local specifiers     = fonts.definers.specifiers
local contextsetups  = specifiers.contextsetups
local contextnumbers = specifiers.contextnumbers
local contextmerged  = specifiers.contextmerged

-- we cannot optimize with "start = first_glyph(head)" because then we don't
-- know which rlmode we're in which messes up cursive handling later on
--
-- head is always a whatsit so we can safely assume that head is not changed

local special_attributes = {
    init = 1,
    medi = 2,
    fina = 3,
    isol = 4
}

-- we use this for special testing and documentation

local checkstep       = (nodes and nodes.tracers and nodes.tracers.steppers.check)    or function() end
local registerstep    = (nodes and nodes.tracers and nodes.tracers.steppers.register) or function() end
local registermessage = (nodes and nodes.tracers and nodes.tracers.steppers.message)  or function() end

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_direct(...)
end
local function logwarning(...)
    report_direct(...)
end

local function gref(n)
    if type(n) == "number" then
        local description = descriptions[n]
        local name = description and description.name
        if name then
            return format("U+%04X (%s)",n,name)
        else
            return format("U+%04X",n)
        end
    elseif not n then
        return "<error in tracing>"
    else
        local num, nam = { }, { }
        for i=1,#n do
            local ni = n[i]
            local di = descriptions[ni]
            num[i] = format("U+%04X",ni)
            nam[i] = di and di.name or "?"
        end
        return format("%s (%s)",concat(num," "), concat(nam," "))
    end
end

local function cref(kind,chainname,chainlookupname,lookupname,index)
    if index then
        return format("feature %s, chain %s, sub %s, lookup %s, index %s",kind,chainname,chainlookupname,lookupname,index)
    elseif lookupname then
        return format("feature %s, chain %s, sub %s, lookup %s",kind,chainname or "?",chainlookupname or "?",lookupname)
    elseif chainlookupname then
        return format("feature %s, chain %s, sub %s",kind,chainname or "?",chainlookupname)
    elseif chainname then
        return format("feature %s, chain %s",kind,chainname)
    else
        return format("feature %s",kind)
    end
end

local function pref(kind,lookupname)
    return format("feature %s, lookup %s",kind,lookupname)
end

-- we can assume that languages that use marks are not hyphenated
-- we can also assume that at most one discretionary is present

local function markstoligature(kind,lookupname,start,stop,char)
    local n = copy_node(start)
    local keep = start
    local current
    current, start = insert_node_after(start,start,n)
    local snext = stop.next
    current.next = snext
    if snext then
        snext.prev = current
    end
    start.prev, stop.next = nil, nil
    current.char, current.subtype, current.components = char, ligature_code, start
    return keep
end

local function toligature(kind,lookupname,start,stop,char,markflag,discfound) -- brr head
    if start ~= stop then
--~         if discfound then
--~             local lignode = copy_node(start)
--~             lignode.font = start.font
--~             lignode.char = char
--~             lignode.subtype = ligature_code
--~             start = node.do_ligature_n(start, stop, lignode)
--~             if start.id == disc_code then
--~                 local prev = start.prev
--~                 start = start.next
--~             end
        if discfound then
         -- print("start->stop",nodes.tosequence(start,stop))
            local lignode = copy_node(start)
            lignode.font, lignode.char, lignode.subtype = start.font, char, ligature_code
            local next, prev = stop.next, start.prev
            stop.next = nil
            lignode = node.do_ligature_n(start, stop, lignode)
            prev.next = lignode
            if next then
                next.prev = lignode
            end
            lignode.next, lignode.prev = next, prev
            start = lignode
         -- print("start->end",nodes.tosequence(start))
        else -- start is the ligature
            local deletemarks = markflag ~= "mark"
            local n = copy_node(start)
            local current
            current, start = insert_node_after(start,start,n)
            local snext = stop.next
            current.next = snext
            if snext then
                snext.prev = current
            end
            start.prev, stop.next = nil, nil
            current.char, current.subtype, current.components = char, ligature_code, start
            local head = current
            if deletemarks then
                if trace_marks then
                    while start do
                        if marks[start.char] then
                            logwarning("%s: remove mark %s",pref(kind,lookupname),gref(start.char))
                        end
                        start = start.next
                    end
                end
            else
                local i = 0
                while start do
                    if marks[start.char] then
                        set_attribute(start,markdone,i)
                        if trace_marks then
                            logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(start.char),i)
                        end
                        head, current = insert_node_after(head,current,copy_node(start))
                    else
                        i = i + 1
                    end
                    start = start.next
                end
                start = current.next
                while start and start.id == glyph_code do
                    if marks[start.char] then
                        set_attribute(start,markdone,i)
                        if trace_marks then
                            logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(start.char),i)
                        end
                    else
                        break
                    end
                    start = start.next
                end
            end
            return head
        end
    else
        start.char = char
    end
    return start
end

function handlers.gsub_single(start,kind,lookupname,replacement)
    if trace_singles then
        logprocess("%s: replacing %s by single %s",pref(kind,lookupname),gref(start.char),gref(replacement))
    end
    start.char = replacement
    return start, true
end

local function alternative_glyph(start,alternatives,kind,chainname,chainlookupname,lookupname) -- chainname and chainlookupname optional
    local value, choice, n = featurevalue or tfmdata.shared.features[kind], nil, #alternatives -- global value, brrr
    if value == "random" then
        local r = random(1,n)
        value, choice = format("random, choice %s",r), alternatives[r]
    elseif value == "first" then
        value, choice = format("first, choice %s",1), alternatives[1]
    elseif value == "last" then
        value, choice = format("last, choice %s",n), alternatives[n]
    else
        value = tonumber(value)
        if type(value) ~= "number" then
            value, choice = "default, choice 1", alternatives[1]
        elseif value > n then
            value, choice = format("no %s variants, taking %s",value,n), alternatives[n]
        elseif value == 0 then
            value, choice = format("choice %s (no change)",value), start.char
        elseif value < 1 then
            value, choice = format("no %s variants, taking %s",value,1), alternatives[1]
        else
            value, choice = format("choice %s",value), alternatives[value]
        end
    end
    if not choice then
        logwarning("%s: no variant %s for %s",cref(kind,chainname,chainlookupname,lookupname),value,gref(start.char))
        choice, value = start.char, format("no replacement instead of %s",value)
    end
    return choice, value
end

function handlers.gsub_alternate(start,kind,lookupname,alternative,sequence)
    local choice, index = alternative_glyph(start,alternative,kind,lookupname)
    if trace_alternatives then
        logprocess("%s: replacing %s by alternative %s (%s)",pref(kind,lookupname),gref(start.char),gref(choice),index)
    end
    start.char = choice
    return start, true
end

function handlers.gsub_multiple(start,kind,lookupname,multiple)
    if trace_multiples then
        logprocess("%s: replacing %s by multiple %s",pref(kind,lookupname),gref(start.char),gref(multiple))
    end
    start.char = multiple[1]
    if #multiple > 1 then
        for k=2,#multiple do
            local n = copy_node(start)
            n.char = multiple[k]
            local sn = start.next
            n.next = sn
            n.prev = start
            if sn then
                sn.prev = n
            end
            start.next = n
            start = n
        end
    end
    return start, true
end

function handlers.gsub_ligature(start,kind,lookupname,ligature,sequence) --or maybe pass lookup ref
    local s, stop, discfound = start.next, nil, false
    local startchar = start.char
    if marks[startchar] then
        while s do
            local id = s.id
            if id == glyph_code and s.subtype<256 then
                if s.font == currentfont then
                    local char = s.char
                    local lg = ligature[1][char]
                    if not lg then
                        break
                    else
                        stop = s
                        ligature = lg
                        s = s.next
                    end
                else
                    break
                end
            else
                break
            end
        end
        if stop and ligature[2] then
            if trace_ligatures then
                local stopchar = stop.char
                start = markstoligature(kind,lookupname,start,stop,ligature[2])
                logprocess("%s: replacing %s upto %s by ligature %s",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
            else
                start = markstoligature(kind,lookupname,start,stop,ligature[2])
            end
            return start, true
        end
    else
        local skipmark = sequence.flags[1]
        while s do
            local id = s.id
            if id == glyph_code and s.subtype<256 then
                if s.font == currentfont then
                    local char = s.char
                    if skipmark and marks[char] then
                        s = s.next
                    else
                        local lg = ligature[1][char]
                        if not lg then
                            break
                        else
                            stop = s
                            ligature = lg
                            s = s.next
                        end
                    end
                else
                    break
                end
            elseif id == disc_code then
                discfound = true
                s = s.next
            else
                break
            end
        end
        if stop and ligature[2] then
            if trace_ligatures then
                local stopchar = stop.char
                start = toligature(kind,lookupname,start,stop,ligature[2],skipmark,discfound)
                logprocess("%s: replacing %s upto %s by ligature %s",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
            else
                start = toligature(kind,lookupname,start,stop,ligature[2],skipmark,discfound)
            end
            return start, true
        end
    end
    return start, false
end

--[[ldx--
<p>We get hits on a mark, but we're not sure if the it has to be applied so
we need to explicitly test for basechar, baselig and basemark entries.</p>
--ldx]]--

function handlers.gpos_mark2base(start,kind,lookupname,markanchors,sequence)
    local markchar = start.char
    if marks[markchar] then
        local base = start.prev -- [glyph] [start=mark]
        if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
            local basechar = base.char
            if marks[basechar] then
                while true do
                    base = base.prev
                    if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                        basechar = base.char
                        if not marks[basechar] then
                            break
                        end
                    else
                        if trace_bugs then
                            logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                        end
                        return start, false
                    end
                end
            end
            local baseanchors = descriptions[basechar]
            if baseanchors then
                baseanchors = baseanchors.anchors
            end
            if baseanchors then
                local baseanchors = baseanchors['basechar']
                if baseanchors then
                    local al = anchorlookups[lookupname]
                    for anchor,ba in next, baseanchors do
                        if al[anchor] then
                            local ma = markanchors[anchor]
                            if ma then
                                local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma)
                                if trace_marks then
                                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%s,%s)",
                                        pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                end
                                return start, true
                            end
                        end
                    end
                    if trace_bugs then
                        logwarning("%s, no matching anchors for mark %s and base %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                    end
                end
            else -- if trace_bugs then
            --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                fonts.registermessage(currentfont,basechar,"no base anchors")
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no char",pref(kind,lookupname))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return start, false
end

function handlers.gpos_mark2ligature(start,kind,lookupname,markanchors,sequence)
    -- check chainpos variant
    local markchar = start.char
    if marks[markchar] then
        local base = start.prev -- [glyph] [optional marks] [start=mark]
        local index = 1
        if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
            local basechar = base.char
            if marks[basechar] then
                index = index + 1
                while true do
                    base = base.prev
                    if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                        basechar = base.char
                        if marks[basechar] then
                            index = index + 1
                        else
                            break
                        end
                    else
                        if trace_bugs then
                            logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                        end
                        return start, false
                    end
                end
            end
            local i = has_attribute(start,markdone)
            if i then index = i end
            local baseanchors = descriptions[basechar]
            if baseanchors then
                baseanchors = baseanchors.anchors
                if baseanchors then
                   local baseanchors = baseanchors['baselig']
                   if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    ba = ba[index]
                                    if ba then
                                        local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma,index)
                                        if trace_marks then
                                            logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%s,%s)",
                                                pref(kind,lookupname),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
                                        end
                                        return start, true
                                    end
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and baselig %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            else -- if trace_bugs then
            --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                fonts.registermessage(currentfont,basechar,"no base anchors")
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no char",pref(kind,lookupname))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return start, false
end

function handlers.gpos_mark2mark(start,kind,lookupname,markanchors,sequence)
    local markchar = start.char
    if marks[markchar] then
--~         local alreadydone = markonce and has_attribute(start,markmark)
--~         if not alreadydone then
            local base = start.prev -- [glyph] [basemark] [start=mark]
            if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then -- subtype test can go
                local basechar = base.char
                local baseanchors = descriptions[basechar]
                if baseanchors then
                    baseanchors = baseanchors.anchors
                    if baseanchors then
                        baseanchors = baseanchors['basemark']
                        if baseanchors then
                            local al = anchorlookups[lookupname]
                            for anchor,ba in next, baseanchors do
                                if al[anchor] then
                                    local ma = markanchors[anchor]
                                    if ma then
                                        local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma)
                                        if trace_marks then
                                            logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%s,%s)",
                                                pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                        end
                                        return start,true
                                    end
                                end
                            end
                            if trace_bugs then
                                logwarning("%s: no matching anchors for mark %s and basemark %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                            end
                        end
                    end
                else -- if trace_bugs then
                --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                    fonts.registermessage(currentfont,basechar,"no base anchors")
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no mark",pref(kind,lookupname))
            end
--~         elseif trace_marks and trace_details then
--~             logprocess("%s, mark %s is already bound (n=%s), ignoring mark2mark",pref(kind,lookupname),gref(markchar),alreadydone)
--~         end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return start,false
end

function handlers.gpos_cursive(start,kind,lookupname,exitanchors,sequence) -- to be checked
    local alreadydone = cursonce and has_attribute(start,cursbase)
    if not alreadydone then
        local done = false
        local startchar = start.char
        if marks[startchar] then
            if trace_cursive then
                logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
            end
        else
            local nxt = start.next
            while not done and nxt and nxt.id == glyph_code and nxt.subtype<256 and nxt.font == currentfont do
                local nextchar = nxt.char
                if marks[nextchar] then
                    -- should not happen (maybe warning)
                    nxt = nxt.next
                else
                    local entryanchors = descriptions[nextchar]
                    if entryanchors then
                        entryanchors = entryanchors.anchors
                        if entryanchors then
                            entryanchors = entryanchors['centry']
                            if entryanchors then
                                local al = anchorlookups[lookupname]
                                for anchor, entry in next, entryanchors do
                                    if al[anchor] then
                                        local exit = exitanchors[anchor]
                                        if exit then
                                            local dx, dy, bound = setcursive(start,nxt,tfmdata.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                                            if trace_cursive then
                                                logprocess("%s: moving %s to %s cursive (%s,%s) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                                            end
                                            done = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else -- if trace_bugs then
                    --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(startchar))
                        fonts.registermessage(currentfont,startchar,"no entry anchors")
                    end
                    break
                end
            end
        end
        return start, done
    else
        if trace_cursive and trace_details then
            logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
        end
        return start, false
    end
end

function handlers.gpos_single(start,kind,lookupname,kerns,sequence)
    local startchar = start.char
    local dx, dy, w, h = setpair(start,tfmdata.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
    if trace_kerns then
        logprocess("%s: shifting single %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),dx,dy,w,h)
    end
    return start, false
end

function handlers.gpos_pair(start,kind,lookupname,kerns,sequence)
    -- todo: kerns in disc nodes: pre, post, replace -> loop over disc too
    -- todo: kerns in components of ligatures
    local snext = start.next
    if not snext then
        return start, false
    else
        local prev, done = start, false
        local factor = tfmdata.factor
        while snext and snext.id == glyph_code and snext.subtype<256 and snext.font == currentfont do
            local nextchar = snext.char
            local krn = kerns[nextchar]
            if not krn and marks[nextchar] then
                prev = snext
                snext = snext.next
            else
                local krn = kerns[nextchar]
                if not krn then
                    -- skip
                elseif type(krn) == "table" then
                    if krn[1] == "pair" then
                        local a, b = krn[3], krn[4]
                        if a and #a > 0 then
                            local startchar = start.char
                            local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
                            if trace_kerns then
                                logprocess("%s: shifting first of pair %s and %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
                            end
                        end
                        if b and #b > 0 then
                            local startchar = start.char
                            local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
                            if trace_kerns then
                                logprocess("%s: shifting second of pair %s and %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
                            end
                        end
                    else
                        report_process("%s: check this out (old kern stuff)",pref(kind,lookupname))
                        local a, b = krn[3], krn[7]
                        if a and a ~= 0 then
                            local k = setkern(snext,factor,rlmode,a)
                            if trace_kerns then
                                logprocess("%s: inserting first kern %s between %s and %s",pref(kind,lookupname),k,gref(prev.char),gref(nextchar))
                            end
                        end
                        if b and b ~= 0 then
                            logwarning("%s: ignoring second kern xoff %s",pref(kind,lookupname),b*factor)
                        end
                    end
                    done = true
                elseif krn ~= 0 then
                    local k = setkern(snext,factor,rlmode,krn)
                    if trace_kerns then
                        logprocess("%s: inserting kern %s between %s and %s",pref(kind,lookupname),k,gref(prev.char),gref(nextchar))
                    end
                    done = true
                end
                break
            end
        end
        return start, done
    end
end

--[[ldx--
<p>I will implement multiple chain replacements once I run into a font that uses
it. It's not that complex to handle.</p>
--ldx]]--

local chainmores = { }
local chainprocs = { }

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_subchain(...)
end

local logwarning = report_subchain

-- ['coverage']={
--     ['after']={ "r" },
--     ['before']={ "q" },
--     ['current']={ "a", "b", "c" },
-- },
-- ['lookups']={ "ls_l_1", "ls_l_1", "ls_l_1" },

function chainmores.chainsub(start,stop,kind,chainname,currentcontext,cache,lookuplist,chainlookupname,n)
    logprocess("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
    return start, false
end

-- handled later:
--
-- function chainmores.gsub_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
--     return chainprocs.gsub_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
-- end

function chainmores.gsub_multiple(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
    logprocess("%s: gsub_multiple not yet supported",cref(kind,chainname,chainlookupname))
    return start, false
end
function chainmores.gsub_alternate(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
    logprocess("%s: gsub_alternate not yet supported",cref(kind,chainname,chainlookupname))
    return start, false
end

-- handled later:
--
-- function chainmores.gsub_ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
--     return chainprocs.gsub_ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
-- end

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_chain(...)
end

local logwarning = report_chain

-- We could share functions but that would lead to extra function calls with many
-- arguments, redundant tests and confusing messages.

function chainprocs.chainsub(start,stop,kind,chainname,currentcontext,cache,lookuplist,chainlookupname)
    logwarning("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
    return start, false
end

-- The reversesub is a special case, which is why we need to store the replacements
-- in a bit weird way. There is no lookup and the replacement comes from the lookup
-- itself. It is meant mostly for dealing with Urdu.

function chainprocs.reversesub(start,stop,kind,chainname,currentcontext,cache,replacements)
    local char = start.char
    local replacement = replacements[char]
    if replacement then
        if trace_singles then
            logprocess("%s: single reverse replacement of %s by %s",cref(kind,chainname),gref(char),gref(replacement))
        end
        start.char = replacement
        return start, true
    else
        return start, false
    end
end

--[[ldx--
<p>This chain stuff is somewhat tricky since we can have a sequence of actions to be
applied: single, alternate, multiple or ligature where ligature can be an invalid
one in the sense that it will replace multiple by one but not neccessary one that
looks like the combination (i.e. it is the counterpart of multiple then). For
example, the following is valid:</p>

<typing>
<line>xxxabcdexxx [single a->A][multiple b->BCD][ligature cde->E] xxxABCDExxx</line>
</typing>

<p>Therefore we we don't really do the replacement here already unless we have the
single lookup case. The efficiency of the replacements can be improved by deleting
as less as needed but that would also mke the code even more messy.</p>
--ldx]]--

local function delete_till_stop(start,stop,ignoremarks)
    if start ~= stop then
        -- todo keep marks
        local done = false
        while not done do
            done = start == stop
            delete_node(start,start.next)
        end
    end
end

--[[ldx--
<p>Here we replace start by a single variant, First we delete the rest of the
match.</p>
--ldx]]--

function chainprocs.gsub_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex)
    -- todo: marks ?
    if not chainindex then
        delete_till_stop(start,stop) -- ,currentlookup.flags[1])
    end
    local current = start
    local subtables = currentlookup.subtables
    while current do
        if current.id == glyph_code then
            local currentchar = current.char
            local lookupname = subtables[1]
            local replacement = cache.gsub_single[lookupname]
            if not replacement then
                if trace_bugs then
                    logwarning("%s: no single hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
                end
            else
                replacement = replacement[currentchar]
                if not replacement then
                    if trace_bugs then
                        logwarning("%s: no single for %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar))
                    end
                else
                    if trace_singles then
                        logprocess("%s: replacing single %s by %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar),gref(replacement))
                    end
                    current.char = replacement
                end
            end
            return start, true
        elseif current == stop then
            break
        else
            current = current.next
        end
    end
    return start, false
end

chainmores.gsub_single = chainprocs.gsub_single

--[[ldx--
<p>Here we replace start by a sequence of new glyphs. First we delete the rest of
the match.</p>
--ldx]]--

function chainprocs.gsub_multiple(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    delete_till_stop(start,stop)
    local startchar = start.char
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local replacements = cache.gsub_multiple[lookupname]
    if not replacements then
        if trace_bugs then
            logwarning("%s: no multiple hits",cref(kind,chainname,chainlookupname,lookupname))
        end
    else
        replacements = replacements[startchar]
        if not replacements then
            if trace_bugs then
                logwarning("%s: no multiple for %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar))
            end
        else
            if trace_multiples then
                logprocess("%s: replacing %s by multiple characters %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar),gref(replacements))
            end
            local sn = start.next
            for k=1,#replacements do
                if k == 1 then
                    start.char = replacements[k]
                else
                    local n = copy_node(start) -- maybe delete the components and such
                    n.char = replacements[k]
                    n.next, n.prev = sn, start
                    if sn then
                        sn.prev = n
                    end
                    start.next, start = n, n
                end
            end
            return start, true
        end
    end
    return start, false
end

--[[ldx--
<p>Here we replace start by new glyph. First we delete the rest of the match.</p>
--ldx]]--

function chainprocs.gsub_alternate(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    -- todo: marks ?
    delete_till_stop(start,stop)
    local current = start
    local subtables = currentlookup.subtables
    while current do
        if current.id == glyph_code then
            local currentchar = current.char
            local lookupname = subtables[1]
            local alternatives = cache.gsub_alternate[lookupname]
            if not alternatives then
                if trace_bugs then
                    logwarning("%s: no alternative hits",cref(kind,chainname,chainlookupname,lookupname))
                end
            else
                alternatives = alternatives[currentchar]
                if not alternatives then
                    if trace_bugs then
                        logwarning("%s: no alternative for %s",cref(kind,chainname,chainlookupname,lookupname),gref(currentchar))
                    end
                else
                    local choice, index = alternative_glyph(current,alternatives,kind,chainname,chainlookupname,lookupname)
                    current.char = choice
                    if trace_alternatives then
                        logprocess("%s: replacing single %s by alternative %s (%s)",cref(kind,chainname,chainlookupname,lookupname),index,gref(currentchar),gref(choice),index)
                    end
                end
            end
            return start, true
        elseif current == stop then
            break
        else
            current = current.next
        end
    end
    return start, false
end

--[[ldx--
<p>When we replace ligatures we use a helper that handles the marks. I might change
this function (move code inline and handle the marks by a separate function). We
assume rather stupid ligatures (no complex disc nodes).</p>
--ldx]]--

function chainprocs.gsub_ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex)
    local startchar = start.char
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local ligatures = cache.gsub_ligature[lookupname]
    if not ligatures then
        if trace_bugs then
            logwarning("%s: no ligature hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
        end
    else
        ligatures = ligatures[startchar]
        if not ligatures then
            if trace_bugs then
                logwarning("%s: no ligatures starting with %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
            end
        else
            local s, discfound, last, nofreplacements = start.next, false, stop, 0
            while s do
                local id = s.id
                if id == disc_code then
                    s = s.next
                    discfound = true
                else
                    local schar = s.char
                    if marks[schar] then -- marks
                        s = s.next
                    else
                        local lg = ligatures[1][schar]
                        if not lg then
                            break
                        else
                            ligatures, last, nofreplacements = lg, s, nofreplacements + 1
                            if s == stop then
                                break
                            else
                                s = s.next
                            end
                        end
                    end
                end
            end
            local l2 = ligatures[2]
            if l2 then
                if chainindex then
                    stop = last
                end
                if trace_ligatures then
                    if start == stop then
                        logprocess("%s: replacing character %s by ligature %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(l2))
                    else
                        logprocess("%s: replacing character %s upto %s by ligature %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char),gref(l2))
                    end
                end
                start = toligature(kind,lookupname,start,stop,l2,currentlookup.flags[1],discfound)
                return start, true, nofreplacements
            elseif trace_bugs then
                if start == stop then
                    logwarning("%s: replacing character %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
                else
                    logwarning("%s: replacing character %s upto %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char))
                end
            end
        end
    end
    return start, false, 0
end

chainmores.gsub_ligature = chainprocs.gsub_ligature

function chainprocs.gpos_mark2base(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    local markchar = start.char
    if marks[markchar] then
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local markanchors = cache.gpos_mark2base[lookupname]
        if markanchors then
            markanchors = markanchors[markchar]
        end
        if markanchors then
            local base = start.prev -- [glyph] [start=mark]
            if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                local basechar = base.char
                if marks[basechar] then
                    while true do
                        base = base.prev
                        if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                            basechar = base.char
                            if not marks[basechar] then
                                break
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                            end
                            return start, false
                        end
                    end
                end
                local baseanchors = descriptions[basechar].anchors
                if baseanchors then
                    local baseanchors = baseanchors['basechar']
                    if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma)
                                    if trace_marks then
                                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%s,%s)",
                                            cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                    end
                                    return start, true
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s, no matching anchors for mark %s and base %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no char",cref(kind,chainname,chainlookupname,lookupname))
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return start, false
end

function chainprocs.gpos_mark2ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    local markchar = start.char
    if marks[markchar] then
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local markanchors = cache.gpos_mark2ligature[lookupname]
        if markanchors then
            markanchors = markanchors[markchar]
        end
        if markanchors then
            local base = start.prev -- [glyph] [optional marks] [start=mark]
            local index = 1
            if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                local basechar = base.char
                if marks[basechar] then
                    index = index + 1
                    while true do
                        base = base.prev
                        if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then
                            basechar = base.char
                            if marks[basechar] then
                                index = index + 1
                            else
                                break
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s",cref(kind,chainname,chainlookupname,lookupname),markchar)
                            end
                            return start, false
                        end
                    end
                end
                -- todo: like marks a ligatures hash
                local i = has_attribute(start,markdone)
                if i then index = i end
                local baseanchors = descriptions[basechar].anchors
                if baseanchors then
                   local baseanchors = baseanchors['baselig']
                   if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    ba = ba[index]
                                    if ba then
                                        local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma,index)
                                        if trace_marks then
                                            logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%s,%s)",
                                                cref(kind,chainname,chainlookupname,lookupname),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                                        end
                                        return start, true
                                    end
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and baselig %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
                logwarning("feature %s, lookup %s: prev node is no char",kind,lookupname)
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return start, false
end

function chainprocs.gpos_mark2mark(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    local markchar = start.char
    if marks[markchar] then
--~         local alreadydone = markonce and has_attribute(start,markmark)
--~         if not alreadydone then
        --  local markanchors = descriptions[markchar].anchors markanchors = markanchors and markanchors.mark
            local subtables = currentlookup.subtables
            local lookupname = subtables[1]
            local markanchors = cache.gpos_mark2mark[lookupname]
            if markanchors then
                markanchors = markanchors[markchar]
            end
            if markanchors then
                local base = start.prev -- [glyph] [basemark] [start=mark]
                if base and base.id == glyph_code and base.subtype<256 and base.font == currentfont then -- subtype test can go
                    local basechar = base.char
                    local baseanchors = descriptions[basechar].anchors
                    if baseanchors then
                        baseanchors = baseanchors['basemark']
                        if baseanchors then
                            local al = anchorlookups[lookupname]
                            for anchor,ba in next, baseanchors do
                                if al[anchor] then
                                    local ma = markanchors[anchor]
                                    if ma then
                                        local dx, dy, bound = setmark(start,base,tfmdata.factor,rlmode,ba,ma)
                                        if trace_marks then
                                            logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%s,%s)",
                                                cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                        end
                                        return start, true
                                    end
                                end
                            end
                            if trace_bugs then
                                logwarning("%s: no matching anchors for mark %s and basemark %s",gref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                            end
                        end
                    end
                elseif trace_bugs then
                    logwarning("%s: prev node is no mark",cref(kind,chainname,chainlookupname,lookupname))
                end
            elseif trace_bugs then
                logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
            end
--~         elseif trace_marks and trace_details then
--~             logprocess("%s, mark %s is already bound (n=%s), ignoring mark2mark",pref(kind,lookupname),gref(markchar),alreadydone)
--~         end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return start, false
end

-- ! ! ! untested ! ! !

function chainprocs.gpos_cursive(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
    local alreadydone = cursonce and has_attribute(start,cursbase)
    if not alreadydone then
        local startchar = start.char
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local exitanchors = cache.gpos_cursive[lookupname]
        if exitanchors then
            exitanchors = exitanchors[startchar]
        end
        if exitanchors then
            local done = false
            if marks[startchar] then
                if trace_cursive then
                    logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
                end
            else
                local nxt = start.next
                while not done and nxt and nxt.id == glyph_code and nxt.subtype<256 and nxt.font == currentfont do
                    local nextchar = nxt.char
                    if marks[nextchar] then
                        -- should not happen (maybe warning)
                        nxt = nxt.next
                    else
                        local entryanchors = descriptions[nextchar]
                        if entryanchors then
                            entryanchors = entryanchors.anchors
                            if entryanchors then
                                entryanchors = entryanchors['centry']
                                if entryanchors then
                                    local al = anchorlookups[lookupname]
                                    for anchor, entry in next, entryanchors do
                                        if al[anchor] then
                                            local exit = exitanchors[anchor]
                                            if exit then
                                                local dx, dy, bound = setcursive(start,nxt,tfmdata.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                                                if trace_cursive then
                                                    logprocess("%s: moving %s to %s cursive (%s,%s) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                                                end
                                                done = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        else -- if trace_bugs then
                        --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(startchar))
                            fonts.registermessage(currentfont,startchar,"no entry anchors")
                        end
                        break
                    end
                end
            end
            return start, done
        else
            if trace_cursive and trace_details then
                logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
            end
            return start, false
        end
    end
    return start, false
end

function chainprocs.gpos_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex,sequence)
    -- untested
    local startchar = start.char
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local kerns = cache.gpos_single[lookupname]
    if kerns then
        kerns = kerns[startchar]
        if kerns then
            local dx, dy, w, h = setpair(start,tfmdata.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
            if trace_kerns then
                logprocess("%s: shifting single %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),dx,dy,w,h)
            end
        end
    end
    return start, false
end

-- when machines become faster i will make a shared function

function chainprocs.gpos_pair(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex,sequence)
--    logwarning("%s: gpos_pair not yet supported",cref(kind,chainname,chainlookupname))
    local snext = start.next
    if snext then
        local startchar = start.char
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local kerns = cache.gpos_pair[lookupname]
        if kerns then
            kerns = kerns[startchar]
            if kerns then
                local prev, done = start, false
                local factor = tfmdata.factor
                while snext and snext.id == glyph_code and snext.subtype<256 and snext.font == currentfont do
                    local nextchar = snext.char
                    local krn = kerns[nextchar]
                    if not krn and marks[nextchar] then
                        prev = snext
                        snext = snext.next
                    else
                        if not krn then
                            -- skip
                        elseif type(krn) == "table" then
                            if krn[1] == "pair" then
                                local a, b = krn[3], krn[4]
                                if a and #a > 0 then
                                    local startchar = start.char
                                    local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
                                    if trace_kerns then
                                        logprocess("%s: shifting first of pair %s and %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                                    end
                                end
                                if b and #b > 0 then
                                    local startchar = start.char
                                    local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
                                    if trace_kerns then
                                        logprocess("%s: shifting second of pair %s and %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                                    end
                                end
                            else
                                report_process("%s: check this out (old kern stuff)",cref(kind,chainname,chainlookupname))
                                local a, b = krn[3], krn[7]
                                if a and a ~= 0 then
                                    local k = setkern(snext,factor,rlmode,a)
                                    if trace_kerns then
                                        logprocess("%s: inserting first kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(prev.char),gref(nextchar))
                                    end
                                end
                                if b and b ~= 0 then
                                    logwarning("%s: ignoring second kern xoff %s",cref(kind,chainname,chainlookupname),b*factor)
                                end
                            end
                            done = true
                        elseif krn ~= 0 then
                            local k = setkern(snext,factor,rlmode,krn)
                            if trace_kerns then
                                logprocess("%s: inserting kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(prev.char),gref(nextchar))
                            end
                            done = true
                        end
                        break
                    end
                end
                return start, done
            end
        end
    end
    return start, false
end

-- what pointer to return, spec says stop
-- to be discussed ... is bidi changer a space?
-- elseif char == zwnj and sequence[n][32] then -- brrr

-- somehow l or f is global
-- we don't need to pass the currentcontext, saves a bit
-- make a slow variant then can be activated but with more tracing

local function show_skip(kind,chainname,char,ck,class)
    if ck[9] then
        logwarning("%s: skipping char %s (%s) in rule %s, lookuptype %s (%s=>%s)",cref(kind,chainname),gref(char),class,ck[1],ck[2],ck[9],ck[10])
    else
        logwarning("%s: skipping char %s (%s) in rule %s, lookuptype %s",cref(kind,chainname),gref(char),class,ck[1],ck[2])
    end
end

local function normal_handle_contextchain(start,kind,chainname,contexts,sequence,cache)
    --  local rule, lookuptype, sequence, f, l, lookups = ck[1], ck[2] ,ck[3], ck[4], ck[5], ck[6]
    local flags, done = sequence.flags, false
    local skipmark, skipligature, skipbase = flags[1], flags[2], flags[3]
    local someskip = skipmark or skipligature or skipbase -- could be stored in flags for a fast test (hm, flags could be false !)
    local markclass = sequence.markclass -- todo, first we need a proper test
    local skipped = false
    for k=1,#contexts do
        local match, current, last = true, start, start
        local ck = contexts[k]
        local seq = ck[3]
        local s = #seq
        -- f..l = mid string
        if s == 1 then
            -- never happens
            match = current.id == glyph_code and current.subtype<256 and current.font == currentfont and seq[1][current.char]
        else
            -- todo: better space check (maybe check for glue)
            local f, l = ck[4], ck[5]
            if f == l then
                -- already a hit
                match = true
            else
                -- no need to test first hit (to be optimized)
                local n = f + 1
                last = last.next
                -- we cannot optimize for n=2 because there can be disc nodes
                -- if not someskip and n == l then
                --    -- n=2 and no skips then faster loop
                --    match = last and last.id == glyph_code and last.subtype<256 and last.font == currentfont and seq[n][last.char]
                -- else
                    while n <= l do
                        if last then
                            local id = last.id
                            if id == glyph_code then
                                if last.subtype<256 and last.font == currentfont then
                                    local char = last.char
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(kind,chainname,char,ck,class)
                                            end
                                            last = last.next
                                        elseif seq[n][char] then
                                            if n < l then
                                                last = last.next
                                            end
                                            n = n + 1
                                        else
                                            match = false break
                                        end
                                    else
                                        match = false break
                                    end
                                else
                                    match = false break
                                end
                            elseif id == disc_code then -- what to do with kerns?
                                last = last.next
                            else
                                match = false break
                            end
                        else
                            match = false break
                        end
                    end
                -- end
            end
            if match and f > 1 then
                -- before
                local prev = start.prev
                if prev then
                    local n = f-1
                    while n >= 1 do
                        if prev then
                            local id = prev.id
                            if id == glyph_code then
                                if prev.subtype<256 and prev.font == currentfont then -- normal char
                                    local char = prev.char
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(kind,chainname,char,ck,class)
                                            end
                                        elseif seq[n][char] then
                                            n = n -1
                                        else
                                            match = false break
                                        end
                                    else
                                        match = false break
                                    end
                                else
                                    match = false break
                                end
                            elseif id == disc_code then
                                -- skip 'm
                            elseif seq[n][32] then
                                n = n -1
                            else
                                match = false break
                            end
                            prev = prev.prev
                        elseif seq[n][32] then
                            n = n -1
                        else
                            match = false break
                        end
                    end
                elseif f == 2 then
                    match = seq[1][32]
                else
                    for n=f-1,1 do
                        if not seq[n][32] then
                            match = false break
                        end
                    end
                end
            end
            if match and s > l then
                -- after
                local current = last.next
                if current then
                    -- removed optimization for s-l == 1, we have to deal with marks anyway
                    local n = l + 1
                    while n <= s do
                        if current then
                            local id = current.id
                            if id == glyph_code then
                                if current.subtype<256 and current.font == currentfont then -- normal char
                                    local char = current.char
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(kind,chainname,char,ck,class)
                                            end
                                        elseif seq[n][char] then
                                            n = n + 1
                                        else
                                            match = false break
                                        end
                                    else
                                        match = false break
                                    end
                                else
                                    match = false break
                                end
                            elseif id == disc_code then
                                -- skip 'm
                            elseif seq[n][32] then -- brrr
                                n = n + 1
                            else
                                match = false break
                            end
                            current = current.next
                        elseif seq[n][32] then
                            n = n + 1
                        else
                            match = false break
                        end
                    end
                elseif s-l == 1 then
                    match = seq[s][32]
                else
                    for n=l+1,s do
                        if not seq[n][32] then
                            match = false break
                        end
                    end
                end
            end
        end
        if match then
            -- ck == currentcontext
            if trace_contexts then
                local rule, lookuptype, f, l = ck[1], ck[2], ck[4], ck[5]
                local char = start.char
                if ck[9] then
                    logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %s (%s=>%s)",cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype,ck[9],ck[10])
                else
                    logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %s",cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype)
                end
            end
            local chainlookups = ck[6]
            if chainlookups then
                local nofchainlookups = #chainlookups
                -- we can speed this up if needed
                if nofchainlookups == 1 then
                    local chainlookupname = chainlookups[1]
                    local chainlookup = lookuptable[chainlookupname]
                    local cp = chainprocs[chainlookup.type]
                    if cp then
                        start, done = cp(start,last,kind,chainname,ck,cache,chainlookup,chainlookupname,nil,sequence)
                    else
                        logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
                    end
                 else
                    -- actually this needs a more complex treatment for which we will use chainmores
--~                     local i = 1
--~                     repeat
--~                         local chainlookupname = chainlookups[i]
--~                         local chainlookup = lookuptable[chainlookupname]
--~                         local cp = chainmores[chainlookup.type]
--~                         if cp then
--~                             local ok, n
--~                             start, ok, n = cp(start,last,kind,chainname,ck,cache,chainlookup,chainlookupname,i,sequence)
--~                             -- messy since last can be changed !
--~                             if ok then
--~                                 done = true
--~                                 start = start.next
--~                                 if n then
--~                                     -- skip next one(s) if ligature
--~                                     i = i + n - 1
--~                                 end
--~                             end
--~                         else
--~                             logprocess("%s: multiple subchains for %s are not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
--~                         end
--~                         i = i + 1
--~                     until i > nofchainlookups

                    local i = 1
                    repeat
                        if skipped then
                            while true do
                                local char = start.char
                                local ccd = descriptions[char]
                                if ccd then
                                    local class = ccd.class
                                    if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                        start = start.next
                                    else
                                        break
                                    end
                                else
                                    break
                                end
                            end
                        end
                        local chainlookupname = chainlookups[i]
                        local chainlookup = lookuptable[chainlookupname]
                        local cp = chainmores[chainlookup.type]
                        if cp then
                            local ok, n
                            start, ok, n = cp(start,last,kind,chainname,ck,cache,chainlookup,chainlookupname,i,sequence)
                            -- messy since last can be changed !
                            if ok then
                                done = true
                                -- skip next one(s) if ligature
                                i = i + (n or 1)
                            else
                                i = i + 1
                            end
                        else
                            logprocess("%s: multiple subchains for %s are not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
                            i = i + 1
                        end
                        start = start.next
                    until i > nofchainlookups

                end
            else
                local replacements = ck[7]
                if replacements then
                    start, done = chainprocs.reversesub(start,last,kind,chainname,ck,cache,replacements) -- sequence
                else
                    done = true -- can be meant to be skipped
                    if trace_contexts then
                        logprocess("%s: skipping match",cref(kind,chainname))
                    end
                end
            end
        end
    end
    return start, done
end

-- Because we want to keep this elsewhere (an because speed is less an issue) we
-- pass the font id so that the verbose variant can access the relevant helper tables.

local verbose_handle_contextchain = function(font,...)
    logwarning("no verbose handler installed, reverting to 'normal'")
    otf.setcontextchain()
    return normal_handle_contextchain(...)
end

otf.chainhandlers = {
    normal = normal_handle_contextchain,
    verbose = verbose_handle_contextchain,
}

function otf.setcontextchain(method)
    if not method or method == "normal" or not otf.chainhandlers[method] then
        if handlers.contextchain then -- no need for a message while making the format
            logwarning("installing normal contextchain handler")
        end
        handlers.contextchain = normal_handle_contextchain
    else
        logwarning("installing contextchain handler '%s'",method)
        local handler = otf.chainhandlers[method]
        handlers.contextchain = function(...)
            return handler(currentfont,...) -- hm, get rid of ...
        end
    end
    handlers.gsub_context             = handlers.contextchain
    handlers.gsub_contextchain        = handlers.contextchain
    handlers.gsub_reversecontextchain = handlers.contextchain
    handlers.gpos_contextchain        = handlers.contextchain
    handlers.gpos_context             = handlers.contextchain
end

otf.setcontextchain()

local missing = { } -- we only report once

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_process(...)
end

local logwarning = report_process

local function report_missing_cache(typ,lookup)
    local f = missing[currentfont] if not f then f = { } missing[currentfont] = f end
    local t = f[typ]               if not t then t = { } f[typ]               = t end
    if not t[lookup] then
        t[lookup] = true
        logwarning("missing cache for lookup %s of type %s in font %s (%s)",lookup,typ,currentfont,tfmdata.fullname)
    end
end

local resolved = { } -- we only resolve a font,script,language pair once

-- todo: pass all these 'locals' in a table
--
-- dynamics will be isolated some day ... for the moment we catch attribute zero
-- not being set

function fonts.methods.node.otf.features(head,font,attr)
    if trace_steps then
        checkstep(head)
    end
    tfmdata = fontdata[font]
    local shared = tfmdata.shared
    otfdata = shared.otfdata
    local luatex = otfdata.luatex
    descriptions = tfmdata.descriptions
    characters = tfmdata.characters
    indices = tfmdata.indices
    unicodes = tfmdata.unicodes
    marks = tfmdata.marks
    anchorlookups = luatex.lookup_to_anchor
    currentfont = font
    rlmode = 0
    local featuredata = otfdata.shared.featuredata -- can be made local to closure
    local sequences = luatex.sequences
    lookuptable = luatex.lookups
    local done = false
    local script, language, s_enabled, a_enabled, dyn
    local attribute_driven = attr and attr ~= 0
    if attribute_driven then
        local features = contextsetups[contextnumbers[attr]] -- could be a direct list
        dyn = contextmerged[attr] or 0
        language, script = features.language or "dflt", features.script or "dflt"
        a_enabled = features -- shared.features -- can be made local to the resolver
        if dyn == 2 or dyn == -2 then
            -- font based
            s_enabled = shared.features
        end
    else
        language, script = tfmdata.language or "dflt", tfmdata.script or "dflt"
        s_enabled = shared.features -- can be made local to the resolver
        dyn = 0
    end
    -- we can save some runtime by caching feature tests
    local res = resolved[font]     if not res   then res = { } resolved[font]     = res end
    local rs  = res     [script]   if not rs    then rs  = { } res     [script]   = rs  end
    local rl  = rs      [language] if not rl    then rl  = { } rs      [language] = rl  end
    local ra  = rl      [attr]     if ra == nil then ra  = { } rl      [attr]     = ra  end -- attr can be false
    -- sequences always > 1 so no need for optimization
    for s=1,#sequences do
        local pardir, txtdir, success = 0, { }, false
        local sequence = sequences[s]
        local r = ra[s] -- cache
        if r == nil then
            --
            -- this bit will move to font-ctx and become a function
            ---
            local chain = sequence.chain or 0
            local features = sequence.features
            if not features then
                -- indirect lookup, part of chain (todo: make this a separate table)
                r = false -- { false, false, chain }
            else
                local valid, attribute, kind, what = false, false
                for k,v in next, features do
                    -- we can quit earlier but for the moment we want the tracing
                    local s_e = s_enabled and s_enabled[k]
                    local a_e = a_enabled and a_enabled[k]
                    if s_e or a_e then
                        local l = v[script] or v[wildcard]
                        if l then
                            -- not l[language] or l[default] or l[wildcard] because we want tracing
                            -- only first attribute match check, so we assume simple fina's
                            -- default can become a font feature itself
                            if l[language] then
                                valid, what = s_e or a_e, language
                        --  elseif l[default] then
                        --      valid, what = true, default
                            elseif l[wildcard] then
                                valid, what = s_e or a_e, wildcard
                            end
                            if valid then
                                kind, attribute = k, special_attributes[k] or false
                                if a_e and dyn < 0 then
                                    valid = false
                                end
                                if trace_applied then
                                    local typ, action = match(sequence.type,"(.*)_(.*)")
                                    report_process(
                                        "%s font: %03i, dynamic: %03i, kind: %s, lookup: %3i, script: %-4s, language: %-4s (%-4s), type: %s, action: %s, name: %s",
                                        (valid and "+") or "-",font,attr or 0,kind,s,script,language,what,typ,action,sequence.name)
                                end
                                break
                            end
                        end
                    end
                end
                if valid then
                    r = { valid, attribute, chain, kind }
                else
                    r = false -- { valid, attribute, chain, "generic" } -- false anyway, could be flag instead of table
                end
            end
            ra[s] = r
        end
        featurevalue = r and r[1] -- todo: pass to function instead of using a global
        if featurevalue then
            local attribute, chain, typ, subtables = r[2], r[3], sequence.type, sequence.subtables
            if chain < 0 then
                -- this is a limited case, no special treatments like 'init' etc
                local handler = handlers[typ]
                local thecache = featuredata[typ] or { }
                -- we need to get rid of this slide !
                local start = find_node_tail(head) -- slow (we can store tail because there's always a skip at the end): todo
                while start do
                    local id = start.id
                    if id == glyph_code then
                        if start.subtype<256 and start.font == font then
                            local a = has_attribute(start,0)
                            if a then
                                a = a == attr
                            else
                                a = true
                            end
                            if a then
                                for i=1,#subtables do
                                    local lookupname = subtables[i]
                                    local lookupcache = thecache[lookupname]
                                    if lookupcache then
                                        local lookupmatch = lookupcache[start.char]
                                        if lookupmatch then
                                            start, success = handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,i)
                                            if success then
                                                break
                                            end
                                        end
                                    else
                                        report_missing_cache(typ,lookupname)
                                    end
                                end
                                if start then start = start.prev end
                            else
                                start = start.prev
                            end
                        else
                            start = start.prev
                        end
                    else
                        start = start.prev
                    end
                end
            else
                local handler = handlers[typ]
                local ns = #subtables
                local thecache = featuredata[typ] or { }
                local start = head -- local ?
                rlmode = 0 -- to be checked ?
                if ns == 1 then
                    local lookupname = subtables[1]
                    local lookupcache = thecache[lookupname]
                    if not lookupcache then
                        report_missing_cache(typ,lookupname)
                    else
                        while start do
                            local id = start.id
                            if id == glyph_code then
                                if start.subtype<256 and start.font == font then
                                    local a = has_attribute(start,0)
                                    if a then
                                        a = (a == attr) and (not attribute or has_attribute(start,state,attribute))
                                    else
                                        a = not attribute or has_attribute(start,state,attribute)
                                    end
                                    if a then
                                        local lookupmatch = lookupcache[start.char]
                                        if lookupmatch then
                                            -- sequence kan weg
                                            local ok
                                            start, ok = handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,1)
                                            if ok then
                                                success = true
                                            end
                                        end
                                        if start then start = start.next end
                                    else
                                        start = start.next
                                    end
                                else
                                    start = start.next
                                end
                            -- elseif id == glue_code then
                            --     if p[5] then -- chain
                            --         local pc = pp[32]
                            --         if pc then
                            --             start, ok = start, false -- p[1](start,kind,p[2],pc,p[3],p[4])
                            --             if ok then
                            --                 done = true
                            --             end
                            --             if start then start = start.next end
                            --         else
                            --             start = start.next
                            --         end
                            --     else
                            --         start = start.next
                            --     end
                            elseif id == whatsit_code then
                                local subtype = start.subtype
                                if subtype == dir_code then
                                    local dir = start.dir
                                    if     dir == "+TRT" or dir == "+TLT" then
                                        insert(txtdir,dir)
                                    elseif dir == "-TRT" or dir == "-TLT" then
                                        remove(txtdir)
                                    end
                                    local d = txtdir[#txtdir]
                                    if d == "+TRT" then
                                        rlmode = -1
                                    elseif d == "+TLT" then
                                        rlmode = 1
                                    else
                                        rlmode = pardir
                                    end
                                    if trace_directions then
                                        report_process("directions after textdir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                                    end
                                elseif subtype == localpar_code then
                                    local dir = start.dir
                                    if dir == "TRT" then
                                        pardir = -1
                                    elseif dir == "TLT" then
                                        pardir = 1
                                    else
                                        pardir = 0
                                    end
                                    rlmode = pardir
                                --~ txtdir = { }
                                    if trace_directions then
                                        report_process("directions after pardir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                                    end
                                end
                                start = start.next
                            else
                                start = start.next
                            end
                        end
                    end
                else
                    while start do
                        local id = start.id
                        if id == glyph_code then
                            if start.subtype<256 and start.font == font then
                                local a = has_attribute(start,0)
                                if a then
                                    a = (a == attr) and (not attribute or has_attribute(start,state,attribute))
                                else
                                    a = not attribute or has_attribute(start,state,attribute)
                                end
                                if a then
                                    for i=1,ns do
                                        local lookupname = subtables[i]
                                        local lookupcache = thecache[lookupname]
                                        if lookupcache then
                                            local lookupmatch = lookupcache[start.char]
                                            if lookupmatch then
                                                -- we could move all code inline but that makes things even more unreadable
                                                local ok
                                                start, ok = handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,i)
                                                if ok then
                                                    success = true
                                                    break
                                                end
                                            end
                                        else
                                            report_missing_cache(typ,lookupname)
                                        end
                                    end
                                    if start then start = start.next end
                                else
                                    start = start.next
                                end
                            else
                                start = start.next
                            end
                        -- elseif id == glue_code then
                        --     if p[5] then -- chain
                        --         local pc = pp[32]
                        --         if pc then
                        --             start, ok = start, false -- p[1](start,kind,p[2],pc,p[3],p[4])
                        --             if ok then
                        --                 done = true
                        --             end
                        --             if start then start = start.next end
                        --         else
                        --             start = start.next
                        --         end
                        --     else
                        --         start = start.next
                        --     end
                        elseif id == whatsit_code then
                            local subtype = start.subtype
                            if subtype == dir_code then
                                local dir = start.dir
                                if     dir == "+TRT" or dir == "+TLT" then
                                    insert(txtdir,dir)
                                elseif dir == "-TRT" or dir == "-TLT" then
                                    remove(txtdir)
                                end
                                local d = txtdir[#txtdir]
                                if d == "+TRT" then
                                    rlmode = -1
                                elseif d == "+TLT" then
                                    rlmode = 1
                                else
                                    rlmode = pardir
                                end
                                if trace_directions then
                                    report_process("directions after textdir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                                end
                            elseif subtype == localpar_code then
                                local dir = start.dir
                                if dir == "TRT" then
                                    pardir = -1
                                elseif dir == "TLT" then
                                    pardir = 1
                                else
                                    pardir = 0
                                end
                                rlmode = pardir
                            --~ txtdir = { }
                                if trace_directions then
                                    report_process("directions after pardir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                                end
                            end
                            start = start.next
                        else
                            start = start.next
                        end
                    end
                end
            end
            if success then
                done = true
            end
            if trace_steps then -- ?
                registerstep(head)
            end
        end
    end
    return head, done
end

otf.features.prepare = { }

-- we used to share code in the following functions but that costs a lot of
-- memory due to extensive calls to functions (easily hundreds of thousands per
-- document)

local function split(replacement,original,cache,unicodes)
    -- we can cache this too, but not the same (although unicode is a unique enough hash)
    local o, t, n, no = { }, { }, 0, 0
    for s in gmatch(original,"[^ ]+") do
        local us = unicodes[s]
        no = no + 1
        if type(us) == "number" then -- tonumber(us)
            o[no] = us
        else
            o[no] = us[1]
        end
    end
    for s in gmatch(replacement,"[^ ]+") do
        n = n + 1
        local us = unicodes[s]
        if type(us) == "number" then -- tonumber(us)
            t[o[n]] = us
        else
            t[o[n]] = us[1]
        end
    end
    return t
end

local function uncover(covers,result,cache,unicodes)
    -- lpeg hardly faster (.005 sec on mk)
    local nofresults = #result
    for n=1,#covers do
        local c = covers[n]
        local cc = cache[c]
        nofresults = nofresults + 1
        if not cc then
            local t = { }
            for s in gmatch(c,"[^ ]+") do
                local us = unicodes[s]
                if type(us) == "number" then
                    t[us] = true
                else
                    for i=1,#us do
                        t[us[i]] = true
                    end
                end
            end
            cache[c] = t
            result[nofresults] = t
        else
            result[nofresults] = cc
        end
    end
end

local function prepare_lookups(tfmdata)
    local otfdata = tfmdata.shared.otfdata
    local featuredata = otfdata.shared.featuredata
    local anchor_to_lookup = otfdata.luatex.anchor_to_lookup
    local lookup_to_anchor = otfdata.luatex.lookup_to_anchor
    --
    local multiple = featuredata.gsub_multiple
    local alternate = featuredata.gsub_alternate
    local single = featuredata.gsub_single
    local ligature = featuredata.gsub_ligature
    local pair = featuredata.gpos_pair
    local position = featuredata.gpos_single
    local kerns = featuredata.gpos_pair
    local mark = featuredata.gpos_mark2mark
    local cursive = featuredata.gpos_cursive
    --
    local unicodes = tfmdata.unicodes -- names to unicodes
    local indices = tfmdata.indices
    local descriptions = tfmdata.descriptions
    --
    -- we can change the otf table after loading but then we need to adapt base mode
    -- as well (no big deal)
    --
    local action = {
        substitution = function(p,lookup,glyph,unicode)
            local old, new = unicode, unicodes[p[2]]
            if type(new) == "table" then
                new = new[1]
            end
            local s = single[lookup]
            if not s then s = { } single[lookup] = s end
            s[old] = new
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: substitution %s => %s",lookup,old,new)
        --~ end
        end,
        multiple = function (p,lookup,glyph,unicode)
            local old, new, nnew = unicode, { }, 0
            local m = multiple[lookup]
            if not m then m = { } multiple[lookup] = m end
            m[old] = new
            for pc in gmatch(p[2],"[^ ]+") do
                local upc = unicodes[pc]
                nnew = nnew + 1
                if type(upc) == "number" then
                    new[nnew] = upc
                else
                    new[nnew] = upc[1]
                end
            end
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: multiple %s => %s",lookup,old,concat(new," "))
        --~ end
        end,
        alternate = function(p,lookup,glyph,unicode)
            local old, new, nnew = unicode, { }, 0
            local a = alternate[lookup]
            if not a then a = { } alternate[lookup] = a end
            a[old] = new
            for pc in gmatch(p[2],"[^ ]+") do
                local upc = unicodes[pc]
                nnew = nnew + 1
                if type(upc) == "number" then
                    new[nnew] = upc
                else
                    new[nnew] = upc[1]
                end
            end
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: alternate %s => %s",lookup,old,concat(new,"|"))
        --~ end
        end,
        ligature = function (p,lookup,glyph,unicode)
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: ligature %s => %s",lookup,p[2],glyph.name)
        --~ end
            local first = true
            local t = ligature[lookup]
            if not t then t = { } ligature[lookup] = t end
            for s in gmatch(p[2],"[^ ]+") do
                if first then
                    local u = unicodes[s]
                    if not u then
                        report_prepare("lookup %s: ligature %s => %s ignored due to invalid unicode",lookup,p[2],glyph.name)
                        break
                    elseif type(u) == "number" then
                        if not t[u] then
                            t[u] = { { } }
                        end
                        t = t[u]
                    else
                        local tt = t
                        local tu
                        for i=1,#u do
                            local u = u[i]
                            if i==1 then
                                if not t[u] then
                                    t[u] = { { } }
                                end
                                tu = t[u]
                                t = tu
                            else
                                if not t[u] then
                                    tt[u] = tu
                                end
                            end
                        end
                    end
                    first = false
                else
                    s = unicodes[s]
                    local t1 = t[1]
                    if not t1[s] then
                        t1[s] = { { } }
                    end
                    t = t1[s]
                end
            end
            t[2] = unicode
        end,
        position = function(p,lookup,glyph,unicode)
            -- not used
            local s = position[lookup]
            if not s then s = { } position[lookup] = s end
            s[unicode] = p[2] -- direct pointer to kern spec
        end,
        pair = function(p,lookup,glyph,unicode)
            local s = pair[lookup]
            if not s then s = { } pair[lookup] = s end
            local others = s[unicode]
            if not others then others = { } s[unicode] = others end
            -- todo: fast check for space
            local two = p[2]
            local upc = unicodes[two]
            if not upc then
                for pc in gmatch(two,"[^ ]+") do
                    local upc = unicodes[pc]
                    if type(upc) == "number" then
                        others[upc] = p -- direct pointer to main table
                    else
                        for i=1,#upc do
                            others[upc[i]] = p -- direct pointer to main table
                        end
                    end
                end
            elseif type(upc) == "number" then
                others[upc] = p -- direct pointer to main table
            else
                for i=1,#upc do
                    others[upc[i]] = p -- direct pointer to main table
                end
            end
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: pair for U+%04X",lookup,unicode)
        --~ end
        end,
    }
    --
    for unicode, glyph in next, descriptions do
        local lookups = glyph.slookups
        if lookups then
            for lookup, p in next, lookups do
                action[p[1]](p,lookup,glyph,unicode)
            end
        end
        local lookups = glyph.mlookups
        if lookups then
            for lookup, whatever in next, lookups do
                for i=1,#whatever do -- normaly one
                    local p = whatever[i]
                    action[p[1]](p,lookup,glyph,unicode)
                end
            end
        end
        local list = glyph.kerns
        if list then
            for lookup, krn in next, list do
                local k = kerns[lookup]
                if not k then k = { } kerns[lookup] = k end
                k[unicode] = krn -- ref to glyph, saves lookup
            --~ if trace_lookups then
            --~     report_prepare("lookup %s: kern for U+%04X",lookup,unicode)
            --~ end
            end
        end
        local oanchor = glyph.anchors
        if oanchor then
            for typ, anchors in next, oanchor do -- types
                if typ == "mark" then
                    for name, anchor in next, anchors do
                        local lookups = anchor_to_lookup[name]
                        if lookups then
                            for lookup, _ in next, lookups do
                                local f = mark[lookup]
                                if not f then f = { } mark[lookup]  = f end
                                f[unicode] = anchors -- ref to glyph, saves lookup
                            --~ if trace_lookups then
                            --~     report_prepare("lookup %s: mark anchor %s for U+%04X",lookup,name,unicode)
                            --~ end
                            end
                        end
                    end
                elseif typ == "cexit" then -- or entry?
                    for name, anchor in next, anchors do
                        local lookups = anchor_to_lookup[name]
                        if lookups then
                            for lookup, _ in next, lookups do
                                local f = cursive[lookup]
                                if not f then f = { } cursive[lookup]  = f end
                                f[unicode] = anchors -- ref to glyph, saves lookup
                            --~ if trace_lookups then
                            --~     report_prepare("lookup %s: exit anchor %s for U+%04X",lookup,name,unicode)
                            --~ end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- local cache = { }
luatex = luatex or {} -- this has to change ... we need a better one

local function prepare_contextchains(tfmdata)
    local otfdata = tfmdata.shared.otfdata
    local lookups = otfdata.lookups
    if lookups then
        local featuredata = otfdata.shared.featuredata
        local contextchain = featuredata.gsub_contextchain -- shared with gpos
        local reversecontextchain = featuredata.gsub_reversecontextchain -- shared with gpos
        local characters = tfmdata.characters
        local unicodes = tfmdata.unicodes
        local indices = tfmdata.indices
        local cache = luatex.covers
        if not cache then
            cache = { }
            luatex.covers = cache
        end
        --
        for lookupname, lookupdata in next, otfdata.lookups do
            local lookuptype = lookupdata.type
            if not lookuptype then
                report_prepare("missing lookuptype for %s",lookupname)
            else
                local rules = lookupdata.rules
                if rules then
                    local fmt = lookupdata.format
                    -- contextchain[lookupname][unicode]
                    if fmt == "coverage" then
                        if lookuptype ~= "chainsub" and lookuptype ~= "chainpos" then
                            report_prepare("unsupported coverage %s for %s",lookuptype,lookupname)
                        else
                            local contexts = contextchain[lookupname]
                            if not contexts then
                                contexts = { }
                                contextchain[lookupname] = contexts
                            end
                            local t, nt = { }, 0
                            for nofrules=1,#rules do -- does #rules>1 happen often?
                                local rule = rules[nofrules]
                                local coverage = rule.coverage
                                if coverage and coverage.current then
                                    local current, before, after, sequence = coverage.current, coverage.before, coverage.after, { }
                                    if before then
                                        uncover(before,sequence,cache,unicodes)
                                    end
                                    local start = #sequence + 1
                                    uncover(current,sequence,cache,unicodes)
                                    local stop = #sequence
                                    if after then
                                        uncover(after,sequence,cache,unicodes)
                                    end
                                    if sequence[1] then
                                        nt = nt + 1
                                        t[nt] = { nofrules, lookuptype, sequence, start, stop, rule.lookups }
                                        for unic, _ in next, sequence[start] do
                                            local cu = contexts[unic]
                                            if not cu then
                                                contexts[unic] = t
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif fmt == "reversecoverage" then
                        if lookuptype ~= "reversesub" then
                            report_prepare("unsupported reverse coverage %s for %s",lookuptype,lookupname)
                        else
                            local contexts = reversecontextchain[lookupname]
                            if not contexts then
                                contexts = { }
                                reversecontextchain[lookupname] = contexts
                            end
                            local t, nt = { }, 0
                            for nofrules=1,#rules do
                                local rule = rules[nofrules]
                                local reversecoverage = rule.reversecoverage
                                if reversecoverage and reversecoverage.current then
                                    local current, before, after, replacements, sequence = reversecoverage.current, reversecoverage.before, reversecoverage.after, reversecoverage.replacements, { }
                                    if before then
                                        uncover(before,sequence,cache,unicodes)
                                    end
                                    local start = #sequence + 1
                                    uncover(current,sequence,cache,unicodes)
                                    local stop = #sequence
                                    if after then
                                        uncover(after,sequence,cache,unicodes)
                                    end
                                    if replacements then
                                        replacements = split(replacements,current[1],cache,unicodes)
                                    end
                                    if sequence[1] then
                                        -- this is different from normal coverage, we assume only replacements
                                        nt = nt + 1
                                        t[nt] = { nofrules, lookuptype, sequence, start, stop, rule.lookups, replacements }
                                        for unic, _ in next, sequence[start] do
                                            local cu = contexts[unic]
                                            if not cu then
                                                contexts[unic] = t
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif fmt == "glyphs" then
                        if lookuptype ~= "chainsub" and lookuptype ~= "chainpos" then
                            report_prepare("unsupported coverage %s for %s",lookuptype,lookupname)
                        else
                            local contexts = contextchain[lookupname]
                            if not contexts then
                                contexts = { }
                                contextchain[lookupname] = contexts
                            end
                            local t, nt = { }, 0
                            for nofrules=1,#rules do
                                -- nearly the same as coverage so we could as well rename it
                                local rule = rules[nofrules]
                                local glyphs = rule.glyphs
                                if glyphs and glyphs.names then
                                    local fore, back, names, sequence = glyphs.fore, glyphs.back, glyphs.names, { }
                                    if fore and fore ~= "" then
                                        fore = lpegmatch(split_at_space,fore)
                                        uncover(fore,sequence,cache,unicodes)
                                    end
                                    local start = #sequence + 1
                                    names = lpegmatch(split_at_space,names)
                                    uncover(names,sequence,cache,unicodes)
                                    local stop = #sequence
                                    if back and back ~= "" then
                                        back = lpegmatch(split_at_space,back)
                                        uncover(back,sequence,cache,unicodes)
                                    end
                                    if sequence[1] then
                                        nt = nt + 1
                                        t[nt] = { nofrules, lookuptype, sequence, start, stop, rule.lookups }
                                        for unic, _ in next, sequence[start] do
                                            local cu = contexts[unic]
                                            if not cu then
                                                contexts[unic] = t
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function fonts.initializers.node.otf.features(tfmdata,value)
    if true then -- value then
        if not tfmdata.shared.otfdata.shared.initialized then
            local t = trace_preparing and os.clock()
            local otfdata = tfmdata.shared.otfdata
            local featuredata = otfdata.shared.featuredata
            -- caches
            featuredata.gsub_multiple            = { }
            featuredata.gsub_alternate           = { }
            featuredata.gsub_single              = { }
            featuredata.gsub_ligature            = { }
            featuredata.gsub_contextchain        = { }
            featuredata.gsub_reversecontextchain = { }
            featuredata.gpos_pair                = { }
            featuredata.gpos_single              = { }
            featuredata.gpos_mark2base           = { }
            featuredata.gpos_mark2ligature       = featuredata.gpos_mark2base
            featuredata.gpos_mark2mark           = featuredata.gpos_mark2base
            featuredata.gpos_cursive             = { }
            featuredata.gpos_contextchain        = featuredata.gsub_contextchain
            featuredata.gpos_reversecontextchain = featuredata.gsub_reversecontextchain
            --
            prepare_contextchains(tfmdata)
            prepare_lookups(tfmdata)
            otfdata.shared.initialized = true
            if trace_preparing then
                report_prepare("preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.fullname or "?")
            end
        end
    end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-ota'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (analysing)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this might become scrp-*.lua

local type, tostring, match, format, concat = type, tostring, string.match, string.format, table.concat

if not trackers then trackers = { register = function() end } end

local trace_analyzing = false  trackers.register("otf.analyzing",  function(v) trace_analyzing = v end)
local trace_cjk       = false  trackers.register("cjk.injections", function(v) trace_cjk       = v end)

trackers.register("cjk.analyzing","otf.analyzing")

local fonts, nodes = fonts, nodes
local node = node

local otf = fonts.otf
local tfm = fonts.tfm

fonts.analyzers          = fonts.analyzers or { }
local analyzers          = fonts.analyzers

analyzers.initializers   = analyzers.initializers or { node = { otf = { } } }
analyzers.methods        = analyzers.methods      or { node = { otf = { } } }

local initializers       = analyzers.initializers
local methods            = analyzers.methods

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local set_attribute      = node.set_attribute
local has_attribute      = node.has_attribute
local traverse_id        = node.traverse_id
local traverse_node_list = node.traverse

local fontdata           = fonts.identifiers
local state              = attributes.private('state')
local categories         = characters and characters.categories or { } -- sorry, only in context

local fontscolors        = fonts.colors
local fcs                = (fontscolors and fontscolors.set)   or function() end
local fcr                = (fontscolors and fontscolors.reset) or function() end


-- in the future we will use language/script attributes instead of the
-- font related value, but then we also need dynamic features which is
-- somewhat slower; and .. we need a chain of them

local scriptandlanguage = otf.scriptandlanguage

function fonts.initializers.node.otf.analyze(tfmdata,value,attr)
    local script, language = otf.scriptandlanguage(tfmdata,attr)
    local action = initializers[script]
    if action then
        if type(action) == "function" then
            return action(tfmdata,value)
        else
            local action = action[language]
            if action then
                return action(tfmdata,value)
            end
        end
    end
    return nil
end

function fonts.methods.node.otf.analyze(head,font,attr)
    local tfmdata = fontdata[font]
    local script, language = otf.scriptandlanguage(tfmdata,attr)
    local action = methods[script]
    if action then
        if type(action) == "function" then
            return action(head,font,attr)
        else
            action = action[language]
            if action then
                return action(head,font,attr)
            end
        end
    end
    return head, false
end

otf.features.register("analyze",true)   -- we always analyze
table.insert(fonts.triggers,"analyze")  -- we need a proper function for doing this

-- latin

analyzers.methods.latn = analyzers.aux.setstate

-- this info eventually will go into char-def

local zwnj = 0x200C
local zwj  = 0x200D

local isol = {
    [0x0600] = true, [0x0601] = true, [0x0602] = true, [0x0603] = true,
    [0x0608] = true, [0x060B] = true, [0x0621] = true, [0x0674] = true,
    [0x06DD] = true, [zwnj] = true,
}

local isol_fina = {
    [0x0622] = true, [0x0623] = true, [0x0624] = true, [0x0625] = true,
    [0x0627] = true, [0x0629] = true, [0x062F] = true, [0x0630] = true,
    [0x0631] = true, [0x0632] = true, [0x0648] = true, [0x0671] = true,
    [0x0672] = true, [0x0673] = true, [0x0675] = true, [0x0676] = true,
    [0x0677] = true, [0x0688] = true, [0x0689] = true, [0x068A] = true,
    [0x068B] = true, [0x068C] = true, [0x068D] = true, [0x068E] = true,
    [0x068F] = true, [0x0690] = true, [0x0691] = true, [0x0692] = true,
    [0x0693] = true, [0x0694] = true, [0x0695] = true, [0x0696] = true,
    [0x0697] = true, [0x0698] = true, [0x0699] = true, [0x06C0] = true,
    [0x06C3] = true, [0x06C4] = true, [0x06C5] = true, [0x06C6] = true,
    [0x06C7] = true, [0x06C8] = true, [0x06C9] = true, [0x06CA] = true,
    [0x06CB] = true, [0x06CD] = true, [0x06CF] = true, [0x06D2] = true,
    [0x06D3] = true, [0x06D5] = true, [0x06EE] = true, [0x06EF] = true,
    [0x0759] = true, [0x075A] = true, [0x075B] = true, [0x076B] = true,
    [0x076C] = true, [0x0771] = true, [0x0773] = true, [0x0774] = true,
	[0x0778] = true, [0x0779] = true, [0xFEF5] = true, [0xFEF7] = true,
	[0xFEF9] = true, [0xFEFB] = true,
}

local isol_fina_medi_init = {
    [0x0626] = true, [0x0628] = true, [0x062A] = true, [0x062B] = true,
    [0x062C] = true, [0x062D] = true, [0x062E] = true, [0x0633] = true,
    [0x0634] = true, [0x0635] = true, [0x0636] = true, [0x0637] = true,
    [0x0638] = true, [0x0639] = true, [0x063A] = true, [0x063B] = true,
    [0x063C] = true, [0x063D] = true, [0x063E] = true, [0x063F] = true,
    [0x0640] = true, [0x0641] = true, [0x0642] = true, [0x0643] = true,
    [0x0644] = true, [0x0645] = true, [0x0646] = true, [0x0647] = true,
    [0x0649] = true, [0x064A] = true, [0x066E] = true, [0x066F] = true,
    [0x0678] = true, [0x0679] = true, [0x067A] = true, [0x067B] = true,
    [0x067C] = true, [0x067D] = true, [0x067E] = true, [0x067F] = true,
    [0x0680] = true, [0x0681] = true, [0x0682] = true, [0x0683] = true,
    [0x0684] = true, [0x0685] = true, [0x0686] = true, [0x0687] = true,
    [0x069A] = true, [0x069B] = true, [0x069C] = true, [0x069D] = true,
    [0x069E] = true, [0x069F] = true, [0x06A0] = true, [0x06A1] = true,
    [0x06A2] = true, [0x06A3] = true, [0x06A4] = true, [0x06A5] = true,
    [0x06A6] = true, [0x06A7] = true, [0x06A8] = true, [0x06A9] = true,
    [0x06AA] = true, [0x06AB] = true, [0x06AC] = true, [0x06AD] = true,
    [0x06AE] = true, [0x06AF] = true, [0x06B0] = true, [0x06B1] = true,
    [0x06B2] = true, [0x06B3] = true, [0x06B4] = true, [0x06B5] = true,
    [0x06B6] = true, [0x06B7] = true, [0x06B8] = true, [0x06B9] = true,
    [0x06BA] = true, [0x06BB] = true, [0x06BC] = true, [0x06BD] = true,
    [0x06BE] = true, [0x06BF] = true, [0x06C1] = true, [0x06C2] = true,
    [0x06CC] = true, [0x06CE] = true, [0x06D0] = true, [0x06D1] = true,
    [0x06FA] = true, [0x06FB] = true, [0x06FC] = true, [0x06FF] = true,
    [0x0750] = true, [0x0751] = true, [0x0752] = true, [0x0753] = true,
    [0x0754] = true, [0x0755] = true, [0x0756] = true, [0x0757] = true,
    [0x0758] = true, [0x075C] = true, [0x075D] = true, [0x075E] = true,
    [0x075F] = true, [0x0760] = true, [0x0761] = true, [0x0762] = true,
    [0x0763] = true, [0x0764] = true, [0x0765] = true, [0x0766] = true,
    [0x0767] = true, [0x0768] = true, [0x0769] = true, [0x076A] = true,
    [0x076D] = true, [0x076E] = true, [0x076F] = true, [0x0770] = true,
    [0x0772] = true, [0x0775] = true, [0x0776] = true, [0x0777] = true,
    [0x077A] = true, [0x077B] = true, [0x077C] = true, [0x077D] = true,
    [0x077E] = true, [0x077F] = true, [zwj] = true,
}

local arab_warned = { }

-- todo: gref

local function warning(current,what)
    local char = current.char
    if not arab_warned[char] then
        log.report("analyze","arab: character %s (U+%04X) has no %s class", char, char, what)
        arab_warned[char] = true
    end
end

function analyzers.methods.nocolor(head,font,attr)
    for n in traverse_id(glyph_code,head) do
        if not font or n.font == font then
            fcr(n)
        end
    end
    return head, true
end

local function finish(first,last)
    if last then
        if first == last then
            local fc = first.char
            if isol_fina_medi_init[fc] or isol_fina[fc] then
                set_attribute(first,state,4) -- isol
                if trace_analyzing then fcs(first,"font:isol") end
            else
                warning(first,"isol")
                set_attribute(first,state,0) -- error
                if trace_analyzing then fcr(first) end
            end
        else
            local lc = last.char
            if isol_fina_medi_init[lc] or isol_fina[lc] then -- why isol here ?
            -- if laststate == 1 or laststate == 2 or laststate == 4 then
                set_attribute(last,state,3) -- fina
                if trace_analyzing then fcs(last,"font:fina") end
            else
                warning(last,"fina")
                set_attribute(last,state,0) -- error
                if trace_analyzing then fcr(last) end
            end
        end
        first, last = nil, nil
    elseif first then
        -- first and last are either both set so we never com here
        local fc = first.char
        if isol_fina_medi_init[fc] or isol_fina[fc] then
            set_attribute(first,state,4) -- isol
            if trace_analyzing then fcs(first,"font:isol") end
        else
            warning(first,"isol")
            set_attribute(first,state,0) -- error
            if trace_analyzing then fcr(first) end
        end
        first = nil
    end
    return first, last
end

function analyzers.methods.arab(head,font,attr) -- maybe make a special version with no trace
    local useunicodemarks = analyzers.useunicodemarks
    local tfmdata = fontdata[font]
    local marks = tfmdata.marks
    local first, last, current, done = nil, nil, head, false
    while current do
        if current.id == glyph_code and current.subtype<256 and current.font == font and not has_attribute(current,state) then
            done = true
            local char = current.char
            if marks[char] or (useunicodemarks and categories[char] == "mn") then
                set_attribute(current,state,5) -- mark
                if trace_analyzing then fcs(current,"font:mark") end
            elseif isol[char] then -- can be zwj or zwnj too
                first, last = finish(first,last)
                set_attribute(current,state,4) -- isol
                if trace_analyzing then fcs(current,"font:isol") end
                first, last = nil, nil
            elseif not first then
                if isol_fina_medi_init[char] then
                    set_attribute(current,state,1) -- init
                    if trace_analyzing then fcs(current,"font:init") end
                    first, last = first or current, current
                elseif isol_fina[char] then
                    set_attribute(current,state,4) -- isol
                    if trace_analyzing then fcs(current,"font:isol") end
                    first, last = nil, nil
                else -- no arab
                    first, last = finish(first,last)
                end
            elseif isol_fina_medi_init[char] then
                first, last = first or current, current
                set_attribute(current,state,2) -- medi
                if trace_analyzing then fcs(current,"font:medi") end
            elseif isol_fina[char] then
                if not has_attribute(last,state,1) then
                    -- tricky, we need to check what last may be !
                    set_attribute(last,state,2) -- medi
                    if trace_analyzing then fcs(last,"font:medi") end
                end
                set_attribute(current,state,3) -- fina
                if trace_analyzing then fcs(current,"font:fina") end
                first, last = nil, nil
            elseif char >= 0x0600 and char <= 0x06FF then
                if trace_analyzing then fcs(current,"font:rest") end
                first, last = finish(first,last)
            else --no
                first, last = finish(first,last)
            end
        else
            first, last = finish(first,last)
        end
        current = current.next
    end
    first, last = finish(first,last)
    return head, done
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next

-- we assume that the other otf stuff is loaded already

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local fonts = fonts
local otf   = fonts.otf

local report_otf = logs.reporter("fonts","otf loading")

-- instead of "script = "DFLT", langs = { 'dflt' }" we now use wildcards (we used to
-- have always); some day we can write a "force always when true" trick for other
-- features as well
--
-- we could have a tnum variant as well

-- In the userdata interface we can not longer tweak the loaded font as
-- conveniently as before. For instance, instead of pushing extra data in
-- in the table using the original structure, we now have to operate on
-- the mkiv representation. And as the fontloader interface is modelled
-- after fontforge we cannot change that one too much either.

local extra_lists = {
    tlig = {
        {
            endash        = "hyphen hyphen",
            emdash        = "hyphen hyphen hyphen",
         -- quotedblleft  = "quoteleft quoteleft",
         -- quotedblright = "quoteright quoteright",
         -- quotedblleft  = "grave grave",
         -- quotedblright = "quotesingle quotesingle",
         -- quotedblbase  = "comma comma",
        },
    },
    trep = {
        {
         -- [0x0022] = 0x201D,
            [0x0027] = 0x2019,
         -- [0x0060] = 0x2018,
        },
    },
    anum = {
        { -- arabic
            [0x0030] = 0x0660,
            [0x0031] = 0x0661,
            [0x0032] = 0x0662,
            [0x0033] = 0x0663,
            [0x0034] = 0x0664,
            [0x0035] = 0x0665,
            [0x0036] = 0x0666,
            [0x0037] = 0x0667,
            [0x0038] = 0x0668,
            [0x0039] = 0x0669,
        },
        { -- persian
            [0x0030] = 0x06F0,
            [0x0031] = 0x06F1,
            [0x0032] = 0x06F2,
            [0x0033] = 0x06F3,
            [0x0034] = 0x06F4,
            [0x0035] = 0x06F5,
            [0x0036] = 0x06F6,
            [0x0037] = 0x06F7,
            [0x0038] = 0x06F8,
            [0x0039] = 0x06F9,
        },
    },
}

local extra_features = { -- maybe just 1..n so that we prescribe order
    tlig = {
        {
            features  = { ["*"] = { ["*"] = true } },
            name      = "ctx_tlig_1",
            subtables = { "ctx_tlig_1_s" },
            type      = "gsub_ligature",
            flags     = { },
        },
    },
    trep = {
        {
            features  = { ["*"] = { ["*"] = true } },
            name      = "ctx_trep_1",
            subtables = { "ctx_trep_1_s" },
            type      = "gsub_single",
            flags     = { },
        },
    },
    anum = {
        {
            features  = { arab = { URD = true, dflt = true } },
            name      = "ctx_anum_1",
            subtables = { "ctx_anum_1_s" },
            type      = "gsub_single",
            flags     = { },
        },
        {
            features  = { arab = { URD = true } },
            name      = "ctx_anum_2",
            subtables = { "ctx_anum_2_s" },
            type      = "gsub_single",
            flags     = { },
        },
    },
}

local function enhancedata(data,filename,raw)
    local luatex = data.luatex
    local lookups = luatex.lookups
    local sequences = luatex.sequences
    local glyphs = data.glyphs
    local indices = luatex.indices
    local gsubfeatures = luatex.features.gsub
    for kind, specifications in next, extra_features do
        if gsub and gsub[kind] then
            -- already present
        else
            local done = 0
            for s=1,#specifications do
                local added = false
                local specification = specifications[s]
                local features, subtables = specification.features, specification.subtables
                local name, type, flags = specification.name, specification.type, specification.flags
                local full = subtables[1]
                local list = extra_lists[kind][s]
                if type == "gsub_ligature" then
                    -- inefficient loop
                    for unicode, index in next, indices do
                        local glyph = glyphs[index]
                        local ligature = list[glyph.name]
                        if ligature then
                            if glyph.slookups then
                                glyph.slookups     [full] = { "ligature", ligature, glyph.name }
                            else
                                glyph.slookups = { [full] = { "ligature", ligature, glyph.name } }
                            end
                            done, added = done+1, true
                        end
                    end
                elseif type == "gsub_single" then
                    -- inefficient loop
                    for unicode, index in next, indices do
                        local glyph = glyphs[index]
                        local r = list[unicode]
                        if r then
                            local replacement = indices[r]
                            if replacement and glyphs[replacement] then
                                if glyph.slookups then
                                    glyph.slookups     [full] = { "substitution", glyphs[replacement].name }
                                else
                                    glyph.slookups = { [full] = { "substitution", glyphs[replacement].name } }
                                end
                                done, added = done+1, true
                            end
                        end
                    end
                end
                if added then
                    sequences[#sequences+1] = {
                        chain     = 0,
                        features  = { [kind] = features },
                        flags     = flags,
                        name      = name,
                        subtables = subtables,
                        type      = type,
                    }
                    -- register in metadata (merge as there can be a few)
                    if not gsubfeatures then
                        gsubfeatures = { }
                        luatex.features.gsub = gsubfeatures
                    end
                    local k = gsubfeatures[kind]
                    if not k then
                        k = { }
                        gsubfeatures[kind] = k
                    end
                    for script, languages in next, features do
                        local kk = k[script]
                        if not kk then
                            kk = { }
                            k[script] = kk
                        end
                        for language, value in next, languages do
                            kk[language] = value
                        end
                    end
                end
            end
            if done > 0 then
                if trace_loading then
                    report_otf("enhance: registering %s feature (%s glyphs affected)",kind,done)
                end
            end
        end
    end
end

otf.enhancers.register("check extra features",enhancedata)

local features = otf.tables.features

features['tlig'] = 'TeX Ligatures'
features['trep'] = 'TeX Replacements'
features['anum'] = 'Arabic Digits'

local registerbasesubstitution = otf.features.registerbasesubstitution

registerbasesubstitution('tlig')
registerbasesubstitution('trep')
registerbasesubstitution('anum')

-- the functionality is defined elsewhere

local initializers        = fonts.initializers
local common_initializers = initializers.common
local base_initializers   = initializers.base.otf
local node_initializers   = initializers.node.otf

base_initializers.equaldigits = common_initializers.equaldigits
node_initializers.equaldigits = common_initializers.equaldigits

base_initializers.lineheight  = common_initializers.lineheight
node_initializers.lineheight  = common_initializers.lineheight

base_initializers.compose     = common_initializers.compose
node_initializers.compose     = common_initializers.compose

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "derived from http://www.adobe.com/devnet/opentype/archives/glyphlist.txt",
    original  = "Adobe Glyph List, version 2.0, September 20, 2002",
}

fonts         = fonts or { }
fonts.enc     = fonts.enc or { }
fonts.enc.agl = fonts.enc.agl or { }

fonts.enc.agl.unicodes = { -- generated
    ["A"]=65,
    ["AE"]=198,
    ["AEacute"]=508,
    ["AEmacron"]=482,
    ["Aacute"]=193,
    ["Abreve"]=258,
    ["Abreveacute"]=7854,
    ["Abrevecyrillic"]=1232,
    ["Abrevedotbelow"]=7862,
    ["Abrevegrave"]=7856,
    ["Abrevehookabove"]=7858,
    ["Abrevetilde"]=7860,
    ["Acaron"]=461,
    ["Acircle"]=9398,
    ["Acircumflex"]=194,
    ["Acircumflexacute"]=7844,
    ["Acircumflexdotbelow"]=7852,
    ["Acircumflexgrave"]=7846,
    ["Acircumflexhookabove"]=7848,
    ["Acircumflextilde"]=7850,
    ["Adblgrave"]=512,
    ["Adieresis"]=196,
    ["Adieresiscyrillic"]=1234,
    ["Adieresismacron"]=478,
    ["Adotbelow"]=7840,
    ["Adotmacron"]=480,
    ["Agrave"]=192,
    ["Ahookabove"]=7842,
    ["Aiecyrillic"]=1236,
    ["Ainvertedbreve"]=514,
    ["Alpha"]=913,
    ["Alphatonos"]=902,
    ["Amacron"]=256,
    ["Amonospace"]=65313,
    ["Aogonek"]=260,
    ["Aring"]=197,
    ["Aringacute"]=506,
    ["Aringbelow"]=7680,
    ["Atilde"]=195,
    ["Aybarmenian"]=1329,
    ["B"]=66,
    ["Bcircle"]=9399,
    ["Bdotaccent"]=7682,
    ["Bdotbelow"]=7684,
    ["Benarmenian"]=1330,
    ["Beta"]=914,
    ["Bhook"]=385,
    ["Blinebelow"]=7686,
    ["Bmonospace"]=65314,
    ["Btopbar"]=386,
    ["C"]=67,
    ["Caarmenian"]=1342,
    ["Cacute"]=262,
    ["Ccaron"]=268,
    ["Ccedilla"]=199,
    ["Ccedillaacute"]=7688,
    ["Ccircle"]=9400,
    ["Ccircumflex"]=264,
    ["Cdotaccent"]=266,
    ["Chaarmenian"]=1353,
    ["Cheabkhasiancyrillic"]=1212,
    ["Chedescenderabkhasiancyrillic"]=1214,
    ["Chedescendercyrillic"]=1206,
    ["Chedieresiscyrillic"]=1268,
    ["Cheharmenian"]=1347,
    ["Chekhakassiancyrillic"]=1227,
    ["Cheverticalstrokecyrillic"]=1208,
    ["Chi"]=935,
    ["Chook"]=391,
    ["Cmonospace"]=65315,
    ["Coarmenian"]=1361,
    ["D"]=68,
    ["DZ"]=497,
    ["DZcaron"]=452,
    ["Daarmenian"]=1332,
    ["Dafrican"]=393,
    ["Dcaron"]=270,
    ["Dcedilla"]=7696,
    ["Dcircle"]=9401,
    ["Dcircumflexbelow"]=7698,
    ["Ddotaccent"]=7690,
    ["Ddotbelow"]=7692,
    ["Deicoptic"]=1006,
    ["Deltagreek"]=916,
    ["Dhook"]=394,
    ["Digammagreek"]=988,
    ["Dlinebelow"]=7694,
    ["Dmonospace"]=65316,
    ["Dslash"]=272,
    ["Dtopbar"]=395,
    ["Dz"]=498,
    ["Dzcaron"]=453,
    ["Dzeabkhasiancyrillic"]=1248,
    ["E"]=69,
    ["Eacute"]=201,
    ["Ebreve"]=276,
    ["Ecaron"]=282,
    ["Ecedillabreve"]=7708,
    ["Echarmenian"]=1333,
    ["Ecircle"]=9402,
    ["Ecircumflex"]=202,
    ["Ecircumflexacute"]=7870,
    ["Ecircumflexbelow"]=7704,
    ["Ecircumflexdotbelow"]=7878,
    ["Ecircumflexgrave"]=7872,
    ["Ecircumflexhookabove"]=7874,
    ["Ecircumflextilde"]=7876,
    ["Edblgrave"]=516,
    ["Edieresis"]=203,
    ["Edotaccent"]=278,
    ["Edotbelow"]=7864,
    ["Egrave"]=200,
    ["Eharmenian"]=1335,
    ["Ehookabove"]=7866,
    ["Eightroman"]=8551,
    ["Einvertedbreve"]=518,
    ["Eiotifiedcyrillic"]=1124,
    ["Elevenroman"]=8554,
    ["Emacron"]=274,
    ["Emacronacute"]=7702,
    ["Emacrongrave"]=7700,
    ["Emonospace"]=65317,
    ["Endescendercyrillic"]=1186,
    ["Eng"]=330,
    ["Enghecyrillic"]=1188,
    ["Enhookcyrillic"]=1223,
    ["Eogonek"]=280,
    ["Eopen"]=400,
    ["Epsilon"]=917,
    ["Epsilontonos"]=904,
    ["Ereversed"]=398,
    ["Esdescendercyrillic"]=1194,
    ["Esh"]=425,
    ["Eta"]=919,
    ["Etarmenian"]=1336,
    ["Etatonos"]=905,
    ["Eth"]=208,
    ["Etilde"]=7868,
    ["Etildebelow"]=7706,
    ["Ezh"]=439,
    ["Ezhcaron"]=494,
    ["Ezhreversed"]=440,
    ["F"]=70,
    ["Fcircle"]=9403,
    ["Fdotaccent"]=7710,
    ["Feharmenian"]=1366,
    ["Feicoptic"]=996,
    ["Fhook"]=401,
    ["Fiveroman"]=8548,
    ["Fmonospace"]=65318,
    ["Fourroman"]=8547,
    ["G"]=71,
    ["GBsquare"]=13191,
    ["Gacute"]=500,
    ["Gamma"]=915,
    ["Gammaafrican"]=404,
    ["Gangiacoptic"]=1002,
    ["Gbreve"]=286,
    ["Gcaron"]=486,
    ["Gcircle"]=9404,
    ["Gcircumflex"]=284,
    ["Gcommaaccent"]=290,
    ["Gdotaccent"]=288,
    ["Ghadarmenian"]=1346,
    ["Ghemiddlehookcyrillic"]=1172,
    ["Ghestrokecyrillic"]=1170,
    ["Ghook"]=403,
    ["Gimarmenian"]=1331,
    ["Gmacron"]=7712,
    ["Gmonospace"]=65319,
    ["Gsmallhook"]=667,
    ["Gstroke"]=484,
    ["H"]=72,
    ["HPsquare"]=13259,
    ["Haabkhasiancyrillic"]=1192,
    ["Hadescendercyrillic"]=1202,
    ["Hbar"]=294,
    ["Hbrevebelow"]=7722,
    ["Hcedilla"]=7720,
    ["Hcircle"]=9405,
    ["Hcircumflex"]=292,
    ["Hdieresis"]=7718,
    ["Hdotaccent"]=7714,
    ["Hdotbelow"]=7716,
    ["Hmonospace"]=65320,
    ["Hoarmenian"]=1344,
    ["Horicoptic"]=1000,
    ["Hzsquare"]=13200,
    ["I"]=73,
    ["IJ"]=306,
    ["Iacute"]=205,
    ["Ibreve"]=300,
    ["Icaron"]=463,
    ["Icircle"]=9406,
    ["Icircumflex"]=206,
    ["Idblgrave"]=520,
    ["Idieresis"]=207,
    ["Idieresisacute"]=7726,
    ["Idieresiscyrillic"]=1252,
    ["Idotaccent"]=304,
    ["Idotbelow"]=7882,
    ["Iebrevecyrillic"]=1238,
    ["Ifraktur"]=8465,
    ["Igrave"]=204,
    ["Ihookabove"]=7880,
    ["Iinvertedbreve"]=522,
    ["Imacron"]=298,
    ["Imacroncyrillic"]=1250,
    ["Imonospace"]=65321,
    ["Iniarmenian"]=1339,
    ["Iogonek"]=302,
    ["Iota"]=921,
    ["Iotaafrican"]=406,
    ["Iotadieresis"]=938,
    ["Iotatonos"]=906,
    ["Istroke"]=407,
    ["Itilde"]=296,
    ["Itildebelow"]=7724,
    ["Izhitsadblgravecyrillic"]=1142,
    ["J"]=74,
    ["Jaarmenian"]=1345,
    ["Jcircle"]=9407,
    ["Jcircumflex"]=308,
    ["Jheharmenian"]=1355,
    ["Jmonospace"]=65322,
    ["K"]=75,
    ["KBsquare"]=13189,
    ["KKsquare"]=13261,
    ["Kabashkircyrillic"]=1184,
    ["Kacute"]=7728,
    ["Kadescendercyrillic"]=1178,
    ["Kahookcyrillic"]=1219,
    ["Kappa"]=922,
    ["Kastrokecyrillic"]=1182,
    ["Kaverticalstrokecyrillic"]=1180,
    ["Kcaron"]=488,
    ["Kcircle"]=9408,
    ["Kcommaaccent"]=310,
    ["Kdotbelow"]=7730,
    ["Keharmenian"]=1364,
    ["Kenarmenian"]=1343,
    ["Kheicoptic"]=998,
    ["Khook"]=408,
    ["Klinebelow"]=7732,
    ["Kmonospace"]=65323,
    ["Koppacyrillic"]=1152,
    ["Koppagreek"]=990,
    ["Ksicyrillic"]=1134,
    ["L"]=76,
    ["LJ"]=455,
    ["Lacute"]=313,
    ["Lambda"]=923,
    ["Lcaron"]=317,
    ["Lcircle"]=9409,
    ["Lcircumflexbelow"]=7740,
    ["Lcommaaccent"]=315,
    ["Ldotaccent"]=319,
    ["Ldotbelow"]=7734,
    ["Ldotbelowmacron"]=7736,
    ["Liwnarmenian"]=1340,
    ["Lj"]=456,
    ["Llinebelow"]=7738,
    ["Lmonospace"]=65324,
    ["Lslash"]=321,
    ["M"]=77,
    ["MBsquare"]=13190,
    ["Macute"]=7742,
    ["Mcircle"]=9410,
    ["Mdotaccent"]=7744,
    ["Mdotbelow"]=7746,
    ["Menarmenian"]=1348,
    ["Mmonospace"]=65325,
    ["Mturned"]=412,
    ["Mu"]=924,
    ["N"]=78,
    ["NJ"]=458,
    ["Nacute"]=323,
    ["Ncaron"]=327,
    ["Ncircle"]=9411,
    ["Ncircumflexbelow"]=7754,
    ["Ncommaaccent"]=325,
    ["Ndotaccent"]=7748,
    ["Ndotbelow"]=7750,
    ["Nhookleft"]=413,
    ["Nineroman"]=8552,
    ["Nj"]=459,
    ["Nlinebelow"]=7752,
    ["Nmonospace"]=65326,
    ["Nowarmenian"]=1350,
    ["Ntilde"]=209,
    ["Nu"]=925,
    ["O"]=79,
    ["OE"]=338,
    ["Oacute"]=211,
    ["Obarredcyrillic"]=1256,
    ["Obarreddieresiscyrillic"]=1258,
    ["Obreve"]=334,
    ["Ocaron"]=465,
    ["Ocenteredtilde"]=415,
    ["Ocircle"]=9412,
    ["Ocircumflex"]=212,
    ["Ocircumflexacute"]=7888,
    ["Ocircumflexdotbelow"]=7896,
    ["Ocircumflexgrave"]=7890,
    ["Ocircumflexhookabove"]=7892,
    ["Ocircumflextilde"]=7894,
    ["Odblgrave"]=524,
    ["Odieresis"]=214,
    ["Odieresiscyrillic"]=1254,
    ["Odotbelow"]=7884,
    ["Ograve"]=210,
    ["Oharmenian"]=1365,
    ["Ohookabove"]=7886,
    ["Ohorn"]=416,
    ["Ohornacute"]=7898,
    ["Ohorndotbelow"]=7906,
    ["Ohorngrave"]=7900,
    ["Ohornhookabove"]=7902,
    ["Ohorntilde"]=7904,
    ["Ohungarumlaut"]=336,
    ["Oi"]=418,
    ["Oinvertedbreve"]=526,
    ["Omacron"]=332,
    ["Omacronacute"]=7762,
    ["Omacrongrave"]=7760,
    ["Omega"]=8486,
    ["Omegacyrillic"]=1120,
    ["Omegagreek"]=937,
    ["Omegaroundcyrillic"]=1146,
    ["Omegatitlocyrillic"]=1148,
    ["Omegatonos"]=911,
    ["Omicron"]=927,
    ["Omicrontonos"]=908,
    ["Omonospace"]=65327,
    ["Oneroman"]=8544,
    ["Oogonek"]=490,
    ["Oogonekmacron"]=492,
    ["Oopen"]=390,
    ["Oslash"]=216,
    ["Ostrokeacute"]=510,
    ["Otcyrillic"]=1150,
    ["Otilde"]=213,
    ["Otildeacute"]=7756,
    ["Otildedieresis"]=7758,
    ["P"]=80,
    ["Pacute"]=7764,
    ["Pcircle"]=9413,
    ["Pdotaccent"]=7766,
    ["Peharmenian"]=1354,
    ["Pemiddlehookcyrillic"]=1190,
    ["Phi"]=934,
    ["Phook"]=420,
    ["Pi"]=928,
    ["Piwrarmenian"]=1363,
    ["Pmonospace"]=65328,
    ["Psi"]=936,
    ["Psicyrillic"]=1136,
    ["Q"]=81,
    ["Qcircle"]=9414,
    ["Qmonospace"]=65329,
    ["R"]=82,
    ["Raarmenian"]=1356,
    ["Racute"]=340,
    ["Rcaron"]=344,
    ["Rcircle"]=9415,
    ["Rcommaaccent"]=342,
    ["Rdblgrave"]=528,
    ["Rdotaccent"]=7768,
    ["Rdotbelow"]=7770,
    ["Rdotbelowmacron"]=7772,
    ["Reharmenian"]=1360,
    ["Rfraktur"]=8476,
    ["Rho"]=929,
    ["Rinvertedbreve"]=530,
    ["Rlinebelow"]=7774,
    ["Rmonospace"]=65330,
    ["Rsmallinverted"]=641,
    ["Rsmallinvertedsuperior"]=694,
    ["S"]=83,
    ["SF010000"]=9484,
    ["SF020000"]=9492,
    ["SF030000"]=9488,
    ["SF040000"]=9496,
    ["SF050000"]=9532,
    ["SF060000"]=9516,
    ["SF070000"]=9524,
    ["SF080000"]=9500,
    ["SF090000"]=9508,
    ["SF100000"]=9472,
    ["SF110000"]=9474,
    ["SF190000"]=9569,
    ["SF200000"]=9570,
    ["SF210000"]=9558,
    ["SF220000"]=9557,
    ["SF230000"]=9571,
    ["SF240000"]=9553,
    ["SF250000"]=9559,
    ["SF260000"]=9565,
    ["SF270000"]=9564,
    ["SF280000"]=9563,
    ["SF360000"]=9566,
    ["SF370000"]=9567,
    ["SF380000"]=9562,
    ["SF390000"]=9556,
    ["SF400000"]=9577,
    ["SF410000"]=9574,
    ["SF420000"]=9568,
    ["SF430000"]=9552,
    ["SF440000"]=9580,
    ["SF450000"]=9575,
    ["SF460000"]=9576,
    ["SF470000"]=9572,
    ["SF480000"]=9573,
    ["SF490000"]=9561,
    ["SF500000"]=9560,
    ["SF510000"]=9554,
    ["SF520000"]=9555,
    ["SF530000"]=9579,
    ["SF540000"]=9578,
    ["Sacute"]=346,
    ["Sacutedotaccent"]=7780,
    ["Sampigreek"]=992,
    ["Scaron"]=352,
    ["Scarondotaccent"]=7782,
    ["Scedilla"]=350,
    ["Schwa"]=399,
    ["Schwacyrillic"]=1240,
    ["Schwadieresiscyrillic"]=1242,
    ["Scircle"]=9416,
    ["Scircumflex"]=348,
    ["Scommaaccent"]=536,
    ["Sdotaccent"]=7776,
    ["Sdotbelow"]=7778,
    ["Sdotbelowdotaccent"]=7784,
    ["Seharmenian"]=1357,
    ["Sevenroman"]=8550,
    ["Shaarmenian"]=1351,
    ["Sheicoptic"]=994,
    ["Shhacyrillic"]=1210,
    ["Shimacoptic"]=1004,
    ["Sigma"]=931,
    ["Sixroman"]=8549,
    ["Smonospace"]=65331,
    ["Stigmagreek"]=986,
    ["T"]=84,
    ["Tau"]=932,
    ["Tbar"]=358,
    ["Tcaron"]=356,
    ["Tcircle"]=9417,
    ["Tcircumflexbelow"]=7792,
    ["Tcommaaccent"]=354,
    ["Tdotaccent"]=7786,
    ["Tdotbelow"]=7788,
    ["Tedescendercyrillic"]=1196,
    ["Tenroman"]=8553,
    ["Tetsecyrillic"]=1204,
    ["Theta"]=920,
    ["Thook"]=428,
    ["Thorn"]=222,
    ["Threeroman"]=8546,
    ["Tiwnarmenian"]=1359,
    ["Tlinebelow"]=7790,
    ["Tmonospace"]=65332,
    ["Toarmenian"]=1337,
    ["Tonefive"]=444,
    ["Tonesix"]=388,
    ["Tonetwo"]=423,
    ["Tretroflexhook"]=430,
    ["Twelveroman"]=8555,
    ["Tworoman"]=8545,
    ["U"]=85,
    ["Uacute"]=218,
    ["Ubreve"]=364,
    ["Ucaron"]=467,
    ["Ucircle"]=9418,
    ["Ucircumflex"]=219,
    ["Ucircumflexbelow"]=7798,
    ["Udblgrave"]=532,
    ["Udieresis"]=220,
    ["Udieresisacute"]=471,
    ["Udieresisbelow"]=7794,
    ["Udieresiscaron"]=473,
    ["Udieresiscyrillic"]=1264,
    ["Udieresisgrave"]=475,
    ["Udieresismacron"]=469,
    ["Udotbelow"]=7908,
    ["Ugrave"]=217,
    ["Uhookabove"]=7910,
    ["Uhorn"]=431,
    ["Uhornacute"]=7912,
    ["Uhorndotbelow"]=7920,
    ["Uhorngrave"]=7914,
    ["Uhornhookabove"]=7916,
    ["Uhorntilde"]=7918,
    ["Uhungarumlaut"]=368,
    ["Uhungarumlautcyrillic"]=1266,
    ["Uinvertedbreve"]=534,
    ["Ukcyrillic"]=1144,
    ["Umacron"]=362,
    ["Umacroncyrillic"]=1262,
    ["Umacrondieresis"]=7802,
    ["Umonospace"]=65333,
    ["Uogonek"]=370,
    ["Upsilon"]=933,
    ["Upsilonacutehooksymbolgreek"]=979,
    ["Upsilonafrican"]=433,
    ["Upsilondieresis"]=939,
    ["Upsilondieresishooksymbolgreek"]=980,
    ["Upsilonhooksymbol"]=978,
    ["Upsilontonos"]=910,
    ["Uring"]=366,
    ["Ustraightcyrillic"]=1198,
    ["Ustraightstrokecyrillic"]=1200,
    ["Utilde"]=360,
    ["Utildeacute"]=7800,
    ["Utildebelow"]=7796,
    ["V"]=86,
    ["Vcircle"]=9419,
    ["Vdotbelow"]=7806,
    ["Vewarmenian"]=1358,
    ["Vhook"]=434,
    ["Vmonospace"]=65334,
    ["Voarmenian"]=1352,
    ["Vtilde"]=7804,
    ["W"]=87,
    ["Wacute"]=7810,
    ["Wcircle"]=9420,
    ["Wcircumflex"]=372,
    ["Wdieresis"]=7812,
    ["Wdotaccent"]=7814,
    ["Wdotbelow"]=7816,
    ["Wgrave"]=7808,
    ["Wmonospace"]=65335,
    ["X"]=88,
    ["Xcircle"]=9421,
    ["Xdieresis"]=7820,
    ["Xdotaccent"]=7818,
    ["Xeharmenian"]=1341,
    ["Xi"]=926,
    ["Xmonospace"]=65336,
    ["Y"]=89,
    ["Yacute"]=221,
    ["Ycircle"]=9422,
    ["Ycircumflex"]=374,
    ["Ydieresis"]=376,
    ["Ydotaccent"]=7822,
    ["Ydotbelow"]=7924,
    ["Yerudieresiscyrillic"]=1272,
    ["Ygrave"]=7922,
    ["Yhook"]=435,
    ["Yhookabove"]=7926,
    ["Yiarmenian"]=1349,
    ["Yiwnarmenian"]=1362,
    ["Ymonospace"]=65337,
    ["Ytilde"]=7928,
    ["Yusbigcyrillic"]=1130,
    ["Yusbigiotifiedcyrillic"]=1132,
    ["Yuslittlecyrillic"]=1126,
    ["Yuslittleiotifiedcyrillic"]=1128,
    ["Z"]=90,
    ["Zaarmenian"]=1334,
    ["Zacute"]=377,
    ["Zcaron"]=381,
    ["Zcircle"]=9423,
    ["Zcircumflex"]=7824,
    ["Zdotaccent"]=379,
    ["Zdotbelow"]=7826,
    ["Zedescendercyrillic"]=1176,
    ["Zedieresiscyrillic"]=1246,
    ["Zeta"]=918,
    ["Zhearmenian"]=1338,
    ["Zhebrevecyrillic"]=1217,
    ["Zhedescendercyrillic"]=1174,
    ["Zhedieresiscyrillic"]=1244,
    ["Zlinebelow"]=7828,
    ["Zmonospace"]=65338,
    ["Zstroke"]=437,
    ["a"]=97,
    ["aabengali"]=2438,
    ["aacute"]=225,
    ["aadeva"]=2310,
    ["aagujarati"]=2694,
    ["aagurmukhi"]=2566,
    ["aamatragurmukhi"]=2622,
    ["aarusquare"]=13059,
    ["aavowelsignbengali"]=2494,
    ["aavowelsigndeva"]=2366,
    ["aavowelsigngujarati"]=2750,
    ["abbreviationmarkarmenian"]=1375,
    ["abbreviationsigndeva"]=2416,
    ["abengali"]=2437,
    ["abopomofo"]=12570,
    ["abreve"]=259,
    ["abreveacute"]=7855,
    ["abrevecyrillic"]=1233,
    ["abrevedotbelow"]=7863,
    ["abrevegrave"]=7857,
    ["abrevehookabove"]=7859,
    ["abrevetilde"]=7861,
    ["acaron"]=462,
    ["acircle"]=9424,
    ["acircumflex"]=226,
    ["acircumflexacute"]=7845,
    ["acircumflexdotbelow"]=7853,
    ["acircumflexgrave"]=7847,
    ["acircumflexhookabove"]=7849,
    ["acircumflextilde"]=7851,
    ["acute"]=180,
    ["acutebelowcmb"]=791,
    ["acutecomb"]=769,
    ["acutedeva"]=2388,
    ["acutelowmod"]=719,
    ["acutetonecmb"]=833,
    ["adblgrave"]=513,
    ["addakgurmukhi"]=2673,
    ["adeva"]=2309,
    ["adieresis"]=228,
    ["adieresiscyrillic"]=1235,
    ["adieresismacron"]=479,
    ["adotbelow"]=7841,
    ["adotmacron"]=481,
    ["ae"]=230,
    ["aeacute"]=509,
    ["aekorean"]=12624,
    ["aemacron"]=483,
    ["afii10017"]=1040,
    ["afii10018"]=1041,
    ["afii10019"]=1042,
    ["afii10020"]=1043,
    ["afii10021"]=1044,
    ["afii10022"]=1045,
    ["afii10023"]=1025,
    ["afii10024"]=1046,
    ["afii10025"]=1047,
    ["afii10026"]=1048,
    ["afii10027"]=1049,
    ["afii10028"]=1050,
    ["afii10029"]=1051,
    ["afii10030"]=1052,
    ["afii10031"]=1053,
    ["afii10032"]=1054,
    ["afii10033"]=1055,
    ["afii10034"]=1056,
    ["afii10035"]=1057,
    ["afii10036"]=1058,
    ["afii10037"]=1059,
    ["afii10038"]=1060,
    ["afii10039"]=1061,
    ["afii10040"]=1062,
    ["afii10041"]=1063,
    ["afii10042"]=1064,
    ["afii10043"]=1065,
    ["afii10044"]=1066,
    ["afii10045"]=1067,
    ["afii10046"]=1068,
    ["afii10047"]=1069,
    ["afii10048"]=1070,
    ["afii10049"]=1071,
    ["afii10050"]=1168,
    ["afii10051"]=1026,
    ["afii10052"]=1027,
    ["afii10053"]=1028,
    ["afii10054"]=1029,
    ["afii10055"]=1030,
    ["afii10056"]=1031,
    ["afii10057"]=1032,
    ["afii10058"]=1033,
    ["afii10059"]=1034,
    ["afii10060"]=1035,
    ["afii10061"]=1036,
    ["afii10062"]=1038,
    ["afii10065"]=1072,
    ["afii10145"]=1039,
    ["afii10146"]=1122,
    ["afii10147"]=1138,
    ["afii10148"]=1140,
    ["afii299"]=8206,
    ["afii300"]=8207,
    ["afii301"]=8205,
    ["afii57534"]=1749,
    ["afii61573"]=8236,
    ["afii61574"]=8237,
    ["afii61575"]=8238,
    ["agrave"]=224,
    ["agujarati"]=2693,
    ["agurmukhi"]=2565,
    ["ahiragana"]=12354,
    ["ahookabove"]=7843,
    ["aibengali"]=2448,
    ["aibopomofo"]=12574,
    ["aideva"]=2320,
    ["aiecyrillic"]=1237,
    ["aigujarati"]=2704,
    ["aigurmukhi"]=2576,
    ["aimatragurmukhi"]=2632,
    ["ainarabic"]=1593,
    ["ainfinalarabic"]=65226,
    ["aininitialarabic"]=65227,
    ["ainmedialarabic"]=65228,
    ["ainvertedbreve"]=515,
    ["aivowelsignbengali"]=2504,
    ["aivowelsigndeva"]=2376,
    ["aivowelsigngujarati"]=2760,
    ["akatakana"]=12450,
    ["akatakanahalfwidth"]=65393,
    ["akorean"]=12623,
    ["alefarabic"]=1575,
    ["alefdageshhebrew"]=64304,
    ["aleffinalarabic"]=65166,
    ["alefhamzaabovearabic"]=1571,
    ["alefhamzaabovefinalarabic"]=65156,
    ["alefhamzabelowarabic"]=1573,
    ["alefhamzabelowfinalarabic"]=65160,
    ["alefhebrew"]=1488,
    ["aleflamedhebrew"]=64335,
    ["alefmaddaabovearabic"]=1570,
    ["alefmaddaabovefinalarabic"]=65154,
    ["alefmaksuraarabic"]=1609,
    ["alefmaksurafinalarabic"]=65264,
    ["alefpatahhebrew"]=64302,
    ["alefqamatshebrew"]=64303,
    ["aleph"]=8501,
    ["allequal"]=8780,
    ["alpha"]=945,
    ["alphatonos"]=940,
    ["amacron"]=257,
    ["amonospace"]=65345,
    ["ampersand"]=38,
    ["ampersandmonospace"]=65286,
    ["amsquare"]=13250,
    ["anbopomofo"]=12578,
    ["angbopomofo"]=12580,
    ["angkhankhuthai"]=3674,
    ["angle"]=8736,
    ["anglebracketleft"]=12296,
    ["anglebracketleftvertical"]=65087,
    ["anglebracketright"]=12297,
    ["anglebracketrightvertical"]=65088,
    ["angleleft"]=9001,
    ["angleright"]=9002,
    ["angstrom"]=8491,
    ["anoteleia"]=903,
    ["anudattadeva"]=2386,
    ["anusvarabengali"]=2434,
    ["anusvaradeva"]=2306,
    ["anusvaragujarati"]=2690,
    ["aogonek"]=261,
    ["apaatosquare"]=13056,
    ["aparen"]=9372,
    ["apostrophearmenian"]=1370,
    ["apostrophemod"]=700,
    ["apple"]=63743,
    ["approaches"]=8784,
    ["approxequal"]=8776,
    ["approxequalorimage"]=8786,
    ["araeaekorean"]=12686,
    ["araeakorean"]=12685,
    ["arc"]=8978,
    ["arighthalfring"]=7834,
    ["aring"]=229,
    ["aringacute"]=507,
    ["aringbelow"]=7681,
    ["arrowboth"]=8596,
    ["arrowdashdown"]=8675,
    ["arrowdashleft"]=8672,
    ["arrowdashright"]=8674,
    ["arrowdashup"]=8673,
    ["arrowdbldown"]=8659,
    ["arrowdblup"]=8657,
    ["arrowdown"]=8595,
    ["arrowdownleft"]=8601,
    ["arrowdownright"]=8600,
    ["arrowdownwhite"]=8681,
    ["arrowheaddownmod"]=709,
    ["arrowheadleftmod"]=706,
    ["arrowheadrightmod"]=707,
    ["arrowheadupmod"]=708,
    ["arrowleft"]=8592,
    ["arrowleftdbl"]=8656,
    ["arrowleftdblstroke"]=8653,
    ["arrowleftoverright"]=8646,
    ["arrowleftwhite"]=8678,
    ["arrowright"]=8594,
    ["arrowrightdblstroke"]=8655,
    ["arrowrightheavy"]=10142,
    ["arrowrightoverleft"]=8644,
    ["arrowrightwhite"]=8680,
    ["arrowtableft"]=8676,
    ["arrowtabright"]=8677,
    ["arrowup"]=8593,
    ["arrowupdn"]=8597,
    ["arrowupdownbase"]=8616,
    ["arrowupleft"]=8598,
    ["arrowupleftofdown"]=8645,
    ["arrowupright"]=8599,
    ["arrowupwhite"]=8679,
    ["asciicircum"]=94,
    ["asciicircummonospace"]=65342,
    ["asciitilde"]=126,
    ["asciitildemonospace"]=65374,
    ["ascript"]=593,
    ["ascriptturned"]=594,
    ["asmallhiragana"]=12353,
    ["asmallkatakana"]=12449,
    ["asmallkatakanahalfwidth"]=65383,
    ["asterisk"]=42,
    ["asteriskarabic"]=1645,
    ["asteriskmath"]=8727,
    ["asteriskmonospace"]=65290,
    ["asterisksmall"]=65121,
    ["asterism"]=8258,
    ["asymptoticallyequal"]=8771,
    ["at"]=64,
    ["atilde"]=227,
    ["atmonospace"]=65312,
    ["atsmall"]=65131,
    ["aturned"]=592,
    ["aubengali"]=2452,
    ["aubopomofo"]=12576,
    ["audeva"]=2324,
    ["augujarati"]=2708,
    ["augurmukhi"]=2580,
    ["aulengthmarkbengali"]=2519,
    ["aumatragurmukhi"]=2636,
    ["auvowelsignbengali"]=2508,
    ["auvowelsigndeva"]=2380,
    ["auvowelsigngujarati"]=2764,
    ["avagrahadeva"]=2365,
    ["aybarmenian"]=1377,
    ["ayinaltonehebrew"]=64288,
    ["ayinhebrew"]=1506,
    ["b"]=98,
    ["babengali"]=2476,
    ["backslash"]=92,
    ["backslashmonospace"]=65340,
    ["badeva"]=2348,
    ["bagujarati"]=2732,
    ["bagurmukhi"]=2604,
    ["bahiragana"]=12400,
    ["bahtthai"]=3647,
    ["bakatakana"]=12496,
    ["barmonospace"]=65372,
    ["bbopomofo"]=12549,
    ["bcircle"]=9425,
    ["bdotaccent"]=7683,
    ["bdotbelow"]=7685,
    ["beamedsixteenthnotes"]=9836,
    ["because"]=8757,
    ["becyrillic"]=1073,
    ["beharabic"]=1576,
    ["behfinalarabic"]=65168,
    ["behinitialarabic"]=65169,
    ["behiragana"]=12409,
    ["behmedialarabic"]=65170,
    ["behmeeminitialarabic"]=64671,
    ["behmeemisolatedarabic"]=64520,
    ["behnoonfinalarabic"]=64621,
    ["bekatakana"]=12505,
    ["benarmenian"]=1378,
    ["beta"]=946,
    ["betasymbolgreek"]=976,
    ["betdageshhebrew"]=64305,
    ["bethebrew"]=1489,
    ["betrafehebrew"]=64332,
    ["bhabengali"]=2477,
    ["bhadeva"]=2349,
    ["bhagujarati"]=2733,
    ["bhagurmukhi"]=2605,
    ["bhook"]=595,
    ["bihiragana"]=12403,
    ["bikatakana"]=12499,
    ["bilabialclick"]=664,
    ["bindigurmukhi"]=2562,
    ["birusquare"]=13105,
    ["blackcircle"]=9679,
    ["blackdiamond"]=9670,
    ["blackleftpointingtriangle"]=9664,
    ["blacklenticularbracketleft"]=12304,
    ["blacklenticularbracketleftvertical"]=65083,
    ["blacklenticularbracketright"]=12305,
    ["blacklenticularbracketrightvertical"]=65084,
    ["blacklowerlefttriangle"]=9699,
    ["blacklowerrighttriangle"]=9698,
    ["blackrightpointingtriangle"]=9654,
    ["blacksmallsquare"]=9642,
    ["blackstar"]=9733,
    ["blackupperlefttriangle"]=9700,
    ["blackupperrighttriangle"]=9701,
    ["blackuppointingsmalltriangle"]=9652,
    ["blank"]=9251,
    ["blinebelow"]=7687,
    ["block"]=9608,
    ["bmonospace"]=65346,
    ["bobaimaithai"]=3610,
    ["bohiragana"]=12412,
    ["bokatakana"]=12508,
    ["bparen"]=9373,
    ["bqsquare"]=13251,
    ["braceleft"]=123,
    ["braceleftmonospace"]=65371,
    ["braceleftsmall"]=65115,
    ["braceleftvertical"]=65079,
    ["braceright"]=125,
    ["bracerightmonospace"]=65373,
    ["bracerightsmall"]=65116,
    ["bracerightvertical"]=65080,
    ["bracketleft"]=91,
    ["bracketleftmonospace"]=65339,
    ["bracketright"]=93,
    ["bracketrightmonospace"]=65341,
    ["breve"]=728,
    ["brevebelowcmb"]=814,
    ["brevecmb"]=774,
    ["breveinvertedbelowcmb"]=815,
    ["breveinvertedcmb"]=785,
    ["breveinverteddoublecmb"]=865,
    ["bridgebelowcmb"]=810,
    ["bridgeinvertedbelowcmb"]=826,
    ["brokenbar"]=166,
    ["bstroke"]=384,
    ["btopbar"]=387,
    ["buhiragana"]=12406,
    ["bukatakana"]=12502,
    ["bullet"]=8226,
    ["bulletoperator"]=8729,
    ["bullseye"]=9678,
    ["c"]=99,
    ["caarmenian"]=1390,
    ["cabengali"]=2458,
    ["cacute"]=263,
    ["cadeva"]=2330,
    ["cagujarati"]=2714,
    ["cagurmukhi"]=2586,
    ["calsquare"]=13192,
    ["candrabindubengali"]=2433,
    ["candrabinducmb"]=784,
    ["candrabindudeva"]=2305,
    ["candrabindugujarati"]=2689,
    ["capslock"]=8682,
    ["careof"]=8453,
    ["caron"]=711,
    ["caronbelowcmb"]=812,
    ["caroncmb"]=780,
    ["carriagereturn"]=8629,
    ["cbopomofo"]=12568,
    ["ccaron"]=269,
    ["ccedilla"]=231,
    ["ccedillaacute"]=7689,
    ["ccircle"]=9426,
    ["ccircumflex"]=265,
    ["ccurl"]=597,
    ["cdotaccent"]=267,
    ["cdsquare"]=13253,
    ["cedilla"]=184,
    ["cedillacmb"]=807,
    ["cent"]=162,
    ["centigrade"]=8451,
    ["centmonospace"]=65504,
    ["chaarmenian"]=1401,
    ["chabengali"]=2459,
    ["chadeva"]=2331,
    ["chagujarati"]=2715,
    ["chagurmukhi"]=2587,
    ["chbopomofo"]=12564,
    ["cheabkhasiancyrillic"]=1213,
    ["checkmark"]=10003,
    ["checyrillic"]=1095,
    ["chedescenderabkhasiancyrillic"]=1215,
    ["chedescendercyrillic"]=1207,
    ["chedieresiscyrillic"]=1269,
    ["cheharmenian"]=1395,
    ["chekhakassiancyrillic"]=1228,
    ["cheverticalstrokecyrillic"]=1209,
    ["chi"]=967,
    ["chieuchacirclekorean"]=12919,
    ["chieuchaparenkorean"]=12823,
    ["chieuchcirclekorean"]=12905,
    ["chieuchkorean"]=12618,
    ["chieuchparenkorean"]=12809,
    ["chochangthai"]=3594,
    ["chochanthai"]=3592,
    ["chochingthai"]=3593,
    ["chochoethai"]=3596,
    ["chook"]=392,
    ["cieucacirclekorean"]=12918,
    ["cieucaparenkorean"]=12822,
    ["cieuccirclekorean"]=12904,
    ["cieuckorean"]=12616,
    ["cieucparenkorean"]=12808,
    ["cieucuparenkorean"]=12828,
    ["circleot"]=8857,
    ["circlepostalmark"]=12342,
    ["circlewithlefthalfblack"]=9680,
    ["circlewithrighthalfblack"]=9681,
    ["circumflex"]=710,
    ["circumflexbelowcmb"]=813,
    ["circumflexcmb"]=770,
    ["clear"]=8999,
    ["clickalveolar"]=450,
    ["clickdental"]=448,
    ["clicklateral"]=449,
    ["clickretroflex"]=451,
    ["clubsuitblack"]=9827,
    ["clubsuitwhite"]=9831,
    ["cmcubedsquare"]=13220,
    ["cmonospace"]=65347,
    ["cmsquaredsquare"]=13216,
    ["coarmenian"]=1409,
    ["colon"]=58,
    ["colonmonospace"]=65306,
    ["colonsign"]=8353,
    ["colonsmall"]=65109,
    ["colontriangularhalfmod"]=721,
    ["colontriangularmod"]=720,
    ["comma"]=44,
    ["commaabovecmb"]=787,
    ["commaaboverightcmb"]=789,
    ["commaarabic"]=1548,
    ["commaarmenian"]=1373,
    ["commamonospace"]=65292,
    ["commareversedabovecmb"]=788,
    ["commareversedmod"]=701,
    ["commasmall"]=65104,
    ["commaturnedabovecmb"]=786,
    ["commaturnedmod"]=699,
    ["congruent"]=8773,
    ["contourintegral"]=8750,
    ["control"]=8963,
    ["controlACK"]=6,
    ["controlBEL"]=7,
    ["controlBS"]=8,
    ["controlCAN"]=24,
    ["controlCR"]=13,
    ["controlDC1"]=17,
    ["controlDC2"]=18,
    ["controlDC3"]=19,
    ["controlDC4"]=20,
    ["controlDEL"]=127,
    ["controlDLE"]=16,
    ["controlEM"]=25,
    ["controlENQ"]=5,
    ["controlEOT"]=4,
    ["controlESC"]=27,
    ["controlETB"]=23,
    ["controlETX"]=3,
    ["controlFF"]=12,
    ["controlFS"]=28,
    ["controlGS"]=29,
    ["controlHT"]=9,
    ["controlLF"]=10,
    ["controlNAK"]=21,
    ["controlRS"]=30,
    ["controlSI"]=15,
    ["controlSO"]=14,
    ["controlSOT"]=2,
    ["controlSTX"]=1,
    ["controlSUB"]=26,
    ["controlSYN"]=22,
    ["controlUS"]=31,
    ["controlVT"]=11,
    ["copyright"]=169,
    ["cornerbracketleft"]=12300,
    ["cornerbracketlefthalfwidth"]=65378,
    ["cornerbracketleftvertical"]=65089,
    ["cornerbracketright"]=12301,
    ["cornerbracketrighthalfwidth"]=65379,
    ["cornerbracketrightvertical"]=65090,
    ["corporationsquare"]=13183,
    ["cosquare"]=13255,
    ["coverkgsquare"]=13254,
    ["cparen"]=9374,
    ["cruzeiro"]=8354,
    ["cstretched"]=663,
    ["curlyand"]=8911,
    ["curlyor"]=8910,
    ["currency"]=164,
    ["d"]=100,
    ["daarmenian"]=1380,
    ["dabengali"]=2470,
    ["dadarabic"]=1590,
    ["dadeva"]=2342,
    ["dadfinalarabic"]=65214,
    ["dadinitialarabic"]=65215,
    ["dadmedialarabic"]=65216,
    ["dageshhebrew"]=1468,
    ["dagger"]=8224,
    ["daggerdbl"]=8225,
    ["dagujarati"]=2726,
    ["dagurmukhi"]=2598,
    ["dahiragana"]=12384,
    ["dakatakana"]=12480,
    ["dalarabic"]=1583,
    ["daletdageshhebrew"]=64307,
    ["dalettserehebrew"]=1491,
    ["dalfinalarabic"]=65194,
    ["dammalowarabic"]=1615,
    ["dammatanarabic"]=1612,
    ["danda"]=2404,
    ["dargalefthebrew"]=1447,
    ["dasiapneumatacyrilliccmb"]=1157,
    ["dblanglebracketleft"]=12298,
    ["dblanglebracketleftvertical"]=65085,
    ["dblanglebracketright"]=12299,
    ["dblanglebracketrightvertical"]=65086,
    ["dblarchinvertedbelowcmb"]=811,
    ["dblarrowleft"]=8660,
    ["dblarrowright"]=8658,
    ["dbldanda"]=2405,
    ["dblgravecmb"]=783,
    ["dblintegral"]=8748,
    ["dbllowlinecmb"]=819,
    ["dbloverlinecmb"]=831,
    ["dblprimemod"]=698,
    ["dblverticalbar"]=8214,
    ["dblverticallineabovecmb"]=782,
    ["dbopomofo"]=12553,
    ["dbsquare"]=13256,
    ["dcaron"]=271,
    ["dcedilla"]=7697,
    ["dcircle"]=9427,
    ["dcircumflexbelow"]=7699,
    ["ddabengali"]=2465,
    ["ddadeva"]=2337,
    ["ddagujarati"]=2721,
    ["ddagurmukhi"]=2593,
    ["ddalarabic"]=1672,
    ["ddalfinalarabic"]=64393,
    ["dddhadeva"]=2396,
    ["ddhabengali"]=2466,
    ["ddhadeva"]=2338,
    ["ddhagujarati"]=2722,
    ["ddhagurmukhi"]=2594,
    ["ddotaccent"]=7691,
    ["ddotbelow"]=7693,
    ["decimalseparatorpersian"]=1643,
    ["decyrillic"]=1076,
    ["degree"]=176,
    ["dehihebrew"]=1453,
    ["dehiragana"]=12391,
    ["deicoptic"]=1007,
    ["dekatakana"]=12487,
    ["deleteleft"]=9003,
    ["deleteright"]=8998,
    ["delta"]=948,
    ["deltaturned"]=397,
    ["denominatorminusonenumeratorbengali"]=2552,
    ["dezh"]=676,
    ["dhabengali"]=2471,
    ["dhadeva"]=2343,
    ["dhagujarati"]=2727,
    ["dhagurmukhi"]=2599,
    ["dhook"]=599,
    ["dialytikatonoscmb"]=836,
    ["diamond"]=9830,
    ["diamondsuitwhite"]=9826,
    ["dieresis"]=168,
    ["dieresisbelowcmb"]=804,
    ["dieresiscmb"]=776,
    ["dieresistonos"]=901,
    ["dihiragana"]=12386,
    ["dikatakana"]=12482,
    ["dittomark"]=12291,
    ["divide"]=247,
    ["divides"]=8739,
    ["divisionslash"]=8725,
    ["djecyrillic"]=1106,
    ["dlinebelow"]=7695,
    ["dlsquare"]=13207,
    ["dmacron"]=273,
    ["dmonospace"]=65348,
    ["dnblock"]=9604,
    ["dochadathai"]=3598,
    ["dodekthai"]=3604,
    ["dohiragana"]=12393,
    ["dokatakana"]=12489,
    ["dollar"]=36,
    ["dollarmonospace"]=65284,
    ["dollarsmall"]=65129,
    ["dong"]=8363,
    ["dorusquare"]=13094,
    ["dotaccent"]=729,
    ["dotaccentcmb"]=775,
    ["dotbelowcomb"]=803,
    ["dotkatakana"]=12539,
    ["dotlessi"]=305,
    ["dotlessjstrokehook"]=644,
    ["dotmath"]=8901,
    ["dottedcircle"]=9676,
    ["downtackbelowcmb"]=798,
    ["downtackmod"]=725,
    ["dparen"]=9375,
    ["dtail"]=598,
    ["dtopbar"]=396,
    ["duhiragana"]=12389,
    ["dukatakana"]=12485,
    ["dz"]=499,
    ["dzaltone"]=675,
    ["dzcaron"]=454,
    ["dzcurl"]=677,
    ["dzeabkhasiancyrillic"]=1249,
    ["dzecyrillic"]=1109,
    ["dzhecyrillic"]=1119,
    ["e"]=101,
    ["eacute"]=233,
    ["earth"]=9793,
    ["ebengali"]=2447,
    ["ebopomofo"]=12572,
    ["ebreve"]=277,
    ["ecandradeva"]=2317,
    ["ecandragujarati"]=2701,
    ["ecandravowelsigndeva"]=2373,
    ["ecandravowelsigngujarati"]=2757,
    ["ecaron"]=283,
    ["ecedillabreve"]=7709,
    ["echarmenian"]=1381,
    ["echyiwnarmenian"]=1415,
    ["ecircle"]=9428,
    ["ecircumflex"]=234,
    ["ecircumflexacute"]=7871,
    ["ecircumflexbelow"]=7705,
    ["ecircumflexdotbelow"]=7879,
    ["ecircumflexgrave"]=7873,
    ["ecircumflexhookabove"]=7875,
    ["ecircumflextilde"]=7877,
    ["ecyrillic"]=1108,
    ["edblgrave"]=517,
    ["edeva"]=2319,
    ["edieresis"]=235,
    ["edotaccent"]=279,
    ["edotbelow"]=7865,
    ["eegurmukhi"]=2575,
    ["eematragurmukhi"]=2631,
    ["efcyrillic"]=1092,
    ["egrave"]=232,
    ["egujarati"]=2703,
    ["eharmenian"]=1383,
    ["ehbopomofo"]=12573,
    ["ehiragana"]=12360,
    ["ehookabove"]=7867,
    ["eibopomofo"]=12575,
    ["eight"]=56,
    ["eightbengali"]=2542,
    ["eightcircle"]=9319,
    ["eightcircleinversesansserif"]=10129,
    ["eightdeva"]=2414,
    ["eighteencircle"]=9329,
    ["eighteenparen"]=9349,
    ["eighteenperiod"]=9369,
    ["eightgujarati"]=2798,
    ["eightgurmukhi"]=2670,
    ["eighthackarabic"]=1640,
    ["eighthangzhou"]=12328,
    ["eightideographicparen"]=12839,
    ["eightinferior"]=8328,
    ["eightmonospace"]=65304,
    ["eightparen"]=9339,
    ["eightperiod"]=9359,
    ["eightpersian"]=1784,
    ["eightroman"]=8567,
    ["eightsuperior"]=8312,
    ["eightthai"]=3672,
    ["einvertedbreve"]=519,
    ["eiotifiedcyrillic"]=1125,
    ["ekatakana"]=12456,
    ["ekatakanahalfwidth"]=65396,
    ["ekonkargurmukhi"]=2676,
    ["ekorean"]=12628,
    ["elcyrillic"]=1083,
    ["element"]=8712,
    ["elevencircle"]=9322,
    ["elevenparen"]=9342,
    ["elevenperiod"]=9362,
    ["elevenroman"]=8570,
    ["ellipsis"]=8230,
    ["ellipsisvertical"]=8942,
    ["emacron"]=275,
    ["emacronacute"]=7703,
    ["emacrongrave"]=7701,
    ["emcyrillic"]=1084,
    ["emdash"]=8212,
    ["emdashvertical"]=65073,
    ["emonospace"]=65349,
    ["emphasismarkarmenian"]=1371,
    ["emptyset"]=8709,
    ["enbopomofo"]=12579,
    ["encyrillic"]=1085,
    ["endash"]=8211,
    ["endashvertical"]=65074,
    ["endescendercyrillic"]=1187,
    ["eng"]=331,
    ["engbopomofo"]=12581,
    ["enghecyrillic"]=1189,
    ["enhookcyrillic"]=1224,
    ["enspace"]=8194,
    ["eogonek"]=281,
    ["eokorean"]=12627,
    ["eopen"]=603,
    ["eopenclosed"]=666,
    ["eopenreversed"]=604,
    ["eopenreversedclosed"]=606,
    ["eopenreversedhook"]=605,
    ["eparen"]=9376,
    ["epsilon"]=949,
    ["epsilontonos"]=941,
    ["equal"]=61,
    ["equalmonospace"]=65309,
    ["equalsmall"]=65126,
    ["equalsuperior"]=8316,
    ["equivalence"]=8801,
    ["erbopomofo"]=12582,
    ["ercyrillic"]=1088,
    ["ereversed"]=600,
    ["ereversedcyrillic"]=1101,
    ["escyrillic"]=1089,
    ["esdescendercyrillic"]=1195,
    ["esh"]=643,
    ["eshcurl"]=646,
    ["eshortdeva"]=2318,
    ["eshortvowelsigndeva"]=2374,
    ["eshreversedloop"]=426,
    ["eshsquatreversed"]=645,
    ["esmallhiragana"]=12359,
    ["esmallkatakana"]=12455,
    ["esmallkatakanahalfwidth"]=65386,
    ["estimated"]=8494,
    ["eta"]=951,
    ["etarmenian"]=1384,
    ["etatonos"]=942,
    ["eth"]=240,
    ["etilde"]=7869,
    ["etildebelow"]=7707,
    ["etnahtalefthebrew"]=1425,
    ["eturned"]=477,
    ["eukorean"]=12641,
    ["euro"]=8364,
    ["evowelsignbengali"]=2503,
    ["evowelsigndeva"]=2375,
    ["evowelsigngujarati"]=2759,
    ["exclam"]=33,
    ["exclamarmenian"]=1372,
    ["exclamdbl"]=8252,
    ["exclamdown"]=161,
    ["exclammonospace"]=65281,
    ["ezh"]=658,
    ["ezhcaron"]=495,
    ["ezhcurl"]=659,
    ["ezhreversed"]=441,
    ["ezhtail"]=442,
    ["f"]=102,
    ["fadeva"]=2398,
    ["fagurmukhi"]=2654,
    ["fahrenheit"]=8457,
    ["fathalowarabic"]=1614,
    ["fathatanarabic"]=1611,
    ["fbopomofo"]=12552,
    ["fcircle"]=9429,
    ["fdotaccent"]=7711,
    ["feharabic"]=1601,
    ["feharmenian"]=1414,
    ["fehfinalarabic"]=65234,
    ["fehinitialarabic"]=65235,
    ["fehmedialarabic"]=65236,
    ["feicoptic"]=997,
    ["ff"]=64256,
    ["ffi"]=64259,
    ["ffl"]=64260,
    ["fi"]=64257,
    ["fifteencircle"]=9326,
    ["fifteenparen"]=9346,
    ["fifteenperiod"]=9366,
    ["figuredash"]=8210,
    ["filledbox"]=9632,
    ["filledrect"]=9644,
    ["finalkafdageshhebrew"]=64314,
    ["finalkafshevahebrew"]=1498,
    ["finalmemhebrew"]=1501,
    ["finalnunhebrew"]=1503,
    ["finalpehebrew"]=1507,
    ["finaltsadihebrew"]=1509,
    ["firsttonechinese"]=713,
    ["fisheye"]=9673,
    ["fitacyrillic"]=1139,
    ["five"]=53,
    ["fivebengali"]=2539,
    ["fivecircle"]=9316,
    ["fivecircleinversesansserif"]=10126,
    ["fivedeva"]=2411,
    ["fiveeighths"]=8541,
    ["fivegujarati"]=2795,
    ["fivegurmukhi"]=2667,
    ["fivehackarabic"]=1637,
    ["fivehangzhou"]=12325,
    ["fiveideographicparen"]=12836,
    ["fiveinferior"]=8325,
    ["fivemonospace"]=65301,
    ["fiveparen"]=9336,
    ["fiveperiod"]=9356,
    ["fivepersian"]=1781,
    ["fiveroman"]=8564,
    ["fivesuperior"]=8309,
    ["fivethai"]=3669,
    ["fl"]=64258,
    ["florin"]=402,
    ["fmonospace"]=65350,
    ["fmsquare"]=13209,
    ["fofanthai"]=3615,
    ["fofathai"]=3613,
    ["fongmanthai"]=3663,
    ["four"]=52,
    ["fourbengali"]=2538,
    ["fourcircle"]=9315,
    ["fourcircleinversesansserif"]=10125,
    ["fourdeva"]=2410,
    ["fourgujarati"]=2794,
    ["fourgurmukhi"]=2666,
    ["fourhackarabic"]=1636,
    ["fourhangzhou"]=12324,
    ["fourideographicparen"]=12835,
    ["fourinferior"]=8324,
    ["fourmonospace"]=65300,
    ["fournumeratorbengali"]=2551,
    ["fourparen"]=9335,
    ["fourperiod"]=9355,
    ["fourpersian"]=1780,
    ["fourroman"]=8563,
    ["foursuperior"]=8308,
    ["fourteencircle"]=9325,
    ["fourteenparen"]=9345,
    ["fourteenperiod"]=9365,
    ["fourthai"]=3668,
    ["fourthtonechinese"]=715,
    ["fparen"]=9377,
    ["fraction"]=8260,
    ["franc"]=8355,
    ["g"]=103,
    ["gabengali"]=2455,
    ["gacute"]=501,
    ["gadeva"]=2327,
    ["gafarabic"]=1711,
    ["gaffinalarabic"]=64403,
    ["gafinitialarabic"]=64404,
    ["gafmedialarabic"]=64405,
    ["gagujarati"]=2711,
    ["gagurmukhi"]=2583,
    ["gahiragana"]=12364,
    ["gakatakana"]=12460,
    ["gamma"]=947,
    ["gammalatinsmall"]=611,
    ["gammasuperior"]=736,
    ["gangiacoptic"]=1003,
    ["gbopomofo"]=12557,
    ["gbreve"]=287,
    ["gcaron"]=487,
    ["gcircle"]=9430,
    ["gcircumflex"]=285,
    ["gcommaaccent"]=291,
    ["gdotaccent"]=289,
    ["gecyrillic"]=1075,
    ["gehiragana"]=12370,
    ["gekatakana"]=12466,
    ["geometricallyequal"]=8785,
    ["gereshaccenthebrew"]=1436,
    ["gereshhebrew"]=1523,
    ["gereshmuqdamhebrew"]=1437,
    ["germandbls"]=223,
    ["gershayimaccenthebrew"]=1438,
    ["gershayimhebrew"]=1524,
    ["getamark"]=12307,
    ["ghabengali"]=2456,
    ["ghadarmenian"]=1394,
    ["ghadeva"]=2328,
    ["ghagujarati"]=2712,
    ["ghagurmukhi"]=2584,
    ["ghainarabic"]=1594,
    ["ghainfinalarabic"]=65230,
    ["ghaininitialarabic"]=65231,
    ["ghainmedialarabic"]=65232,
    ["ghemiddlehookcyrillic"]=1173,
    ["ghestrokecyrillic"]=1171,
    ["gheupturncyrillic"]=1169,
    ["ghhadeva"]=2394,
    ["ghhagurmukhi"]=2650,
    ["ghook"]=608,
    ["ghzsquare"]=13203,
    ["gihiragana"]=12366,
    ["gikatakana"]=12462,
    ["gimarmenian"]=1379,
    ["gimeldageshhebrew"]=64306,
    ["gimelhebrew"]=1490,
    ["gjecyrillic"]=1107,
    ["glottalinvertedstroke"]=446,
    ["glottalstop"]=660,
    ["glottalstopinverted"]=662,
    ["glottalstopmod"]=704,
    ["glottalstopreversed"]=661,
    ["glottalstopreversedmod"]=705,
    ["glottalstopreversedsuperior"]=740,
    ["glottalstopstroke"]=673,
    ["glottalstopstrokereversed"]=674,
    ["gmacron"]=7713,
    ["gmonospace"]=65351,
    ["gohiragana"]=12372,
    ["gokatakana"]=12468,
    ["gparen"]=9378,
    ["gpasquare"]=13228,
    ["grave"]=96,
    ["gravebelowcmb"]=790,
    ["gravecomb"]=768,
    ["gravedeva"]=2387,
    ["gravelowmod"]=718,
    ["gravemonospace"]=65344,
    ["gravetonecmb"]=832,
    ["greater"]=62,
    ["greaterequal"]=8805,
    ["greaterequalorless"]=8923,
    ["greatermonospace"]=65310,
    ["greaterorequivalent"]=8819,
    ["greaterorless"]=8823,
    ["greateroverequal"]=8807,
    ["greatersmall"]=65125,
    ["gscript"]=609,
    ["gstroke"]=485,
    ["guhiragana"]=12368,
    ["guillemotleft"]=171,
    ["guillemotright"]=187,
    ["guilsinglleft"]=8249,
    ["guilsinglright"]=8250,
    ["gukatakana"]=12464,
    ["guramusquare"]=13080,
    ["gysquare"]=13257,
    ["h"]=104,
    ["haabkhasiancyrillic"]=1193,
    ["habengali"]=2489,
    ["hadescendercyrillic"]=1203,
    ["hadeva"]=2361,
    ["hagujarati"]=2745,
    ["hagurmukhi"]=2617,
    ["haharabic"]=1581,
    ["hahfinalarabic"]=65186,
    ["hahinitialarabic"]=65187,
    ["hahiragana"]=12399,
    ["hahmedialarabic"]=65188,
    ["haitusquare"]=13098,
    ["hakatakana"]=12495,
    ["hakatakanahalfwidth"]=65418,
    ["halantgurmukhi"]=2637,
    ["hamzasukunarabic"]=1569,
    ["hangulfiller"]=12644,
    ["hardsigncyrillic"]=1098,
    ["harpoonleftbarbup"]=8636,
    ["harpoonrightbarbup"]=8640,
    ["hasquare"]=13258,
    ["hatafpatahwidehebrew"]=1458,
    ["hatafqamatswidehebrew"]=1459,
    ["hatafsegolwidehebrew"]=1457,
    ["hbar"]=295,
    ["hbopomofo"]=12559,
    ["hbrevebelow"]=7723,
    ["hcedilla"]=7721,
    ["hcircle"]=9431,
    ["hcircumflex"]=293,
    ["hdieresis"]=7719,
    ["hdotaccent"]=7715,
    ["hdotbelow"]=7717,
    ["heartsuitblack"]=9829,
    ["heartsuitwhite"]=9825,
    ["hedageshhebrew"]=64308,
    ["hehaltonearabic"]=1729,
    ["heharabic"]=1607,
    ["hehebrew"]=1492,
    ["hehfinalaltonearabic"]=64423,
    ["hehfinalarabic"]=65258,
    ["hehhamzaabovefinalarabic"]=64421,
    ["hehhamzaaboveisolatedarabic"]=64420,
    ["hehinitialaltonearabic"]=64424,
    ["hehinitialarabic"]=65259,
    ["hehiragana"]=12408,
    ["hehmedialaltonearabic"]=64425,
    ["hehmedialarabic"]=65260,
    ["heiseierasquare"]=13179,
    ["hekatakana"]=12504,
    ["hekatakanahalfwidth"]=65421,
    ["hekutaarusquare"]=13110,
    ["henghook"]=615,
    ["herutusquare"]=13113,
    ["hethebrew"]=1495,
    ["hhook"]=614,
    ["hhooksuperior"]=689,
    ["hieuhacirclekorean"]=12923,
    ["hieuhaparenkorean"]=12827,
    ["hieuhcirclekorean"]=12909,
    ["hieuhkorean"]=12622,
    ["hieuhparenkorean"]=12813,
    ["hihiragana"]=12402,
    ["hikatakana"]=12498,
    ["hikatakanahalfwidth"]=65419,
    ["hiriqwidehebrew"]=1460,
    ["hlinebelow"]=7830,
    ["hmonospace"]=65352,
    ["hoarmenian"]=1392,
    ["hohipthai"]=3627,
    ["hohiragana"]=12411,
    ["hokatakana"]=12507,
    ["hokatakanahalfwidth"]=65422,
    ["holamwidehebrew"]=1465,
    ["honokhukthai"]=3630,
    ["hookcmb"]=777,
    ["hookpalatalizedbelowcmb"]=801,
    ["hookretroflexbelowcmb"]=802,
    ["hoonsquare"]=13122,
    ["horicoptic"]=1001,
    ["horizontalbar"]=8213,
    ["horncmb"]=795,
    ["hotsprings"]=9832,
    ["house"]=8962,
    ["hparen"]=9379,
    ["hsuperior"]=688,
    ["hturned"]=613,
    ["huhiragana"]=12405,
    ["huiitosquare"]=13107,
    ["hukatakana"]=12501,
    ["hukatakanahalfwidth"]=65420,
    ["hungarumlaut"]=733,
    ["hungarumlautcmb"]=779,
    ["hv"]=405,
    ["hyphen"]=45,
    ["hyphenmonospace"]=65293,
    ["hyphensmall"]=65123,
    ["hyphentwo"]=8208,
    ["i"]=105,
    ["iacute"]=237,
    ["iacyrillic"]=1103,
    ["ibengali"]=2439,
    ["ibopomofo"]=12583,
    ["ibreve"]=301,
    ["icaron"]=464,
    ["icircle"]=9432,
    ["icircumflex"]=238,
    ["icyrillic"]=1110,
    ["idblgrave"]=521,
    ["ideographearthcircle"]=12943,
    ["ideographfirecircle"]=12939,
    ["ideographicallianceparen"]=12863,
    ["ideographiccallparen"]=12858,
    ["ideographiccentrecircle"]=12965,
    ["ideographicclose"]=12294,
    ["ideographiccomma"]=12289,
    ["ideographiccommaleft"]=65380,
    ["ideographiccongratulationparen"]=12855,
    ["ideographiccorrectcircle"]=12963,
    ["ideographicearthparen"]=12847,
    ["ideographicenterpriseparen"]=12861,
    ["ideographicexcellentcircle"]=12957,
    ["ideographicfestivalparen"]=12864,
    ["ideographicfinancialcircle"]=12950,
    ["ideographicfinancialparen"]=12854,
    ["ideographicfireparen"]=12843,
    ["ideographichaveparen"]=12850,
    ["ideographichighcircle"]=12964,
    ["ideographiciterationmark"]=12293,
    ["ideographiclaborcircle"]=12952,
    ["ideographiclaborparen"]=12856,
    ["ideographicleftcircle"]=12967,
    ["ideographiclowcircle"]=12966,
    ["ideographicmedicinecircle"]=12969,
    ["ideographicmetalparen"]=12846,
    ["ideographicmoonparen"]=12842,
    ["ideographicnameparen"]=12852,
    ["ideographicperiod"]=12290,
    ["ideographicprintcircle"]=12958,
    ["ideographicreachparen"]=12867,
    ["ideographicrepresentparen"]=12857,
    ["ideographicresourceparen"]=12862,
    ["ideographicrightcircle"]=12968,
    ["ideographicsecretcircle"]=12953,
    ["ideographicselfparen"]=12866,
    ["ideographicsocietyparen"]=12851,
    ["ideographicspace"]=12288,
    ["ideographicspecialparen"]=12853,
    ["ideographicstockparen"]=12849,
    ["ideographicstudyparen"]=12859,
    ["ideographicsunparen"]=12848,
    ["ideographicsuperviseparen"]=12860,
    ["ideographicwaterparen"]=12844,
    ["ideographicwoodparen"]=12845,
    ["ideographiczero"]=12295,
    ["ideographmetalcircle"]=12942,
    ["ideographmooncircle"]=12938,
    ["ideographnamecircle"]=12948,
    ["ideographsuncircle"]=12944,
    ["ideographwatercircle"]=12940,
    ["ideographwoodcircle"]=12941,
    ["ideva"]=2311,
    ["idieresis"]=239,
    ["idieresisacute"]=7727,
    ["idieresiscyrillic"]=1253,
    ["idotbelow"]=7883,
    ["iebrevecyrillic"]=1239,
    ["iecyrillic"]=1077,
    ["ieungacirclekorean"]=12917,
    ["ieungaparenkorean"]=12821,
    ["ieungcirclekorean"]=12903,
    ["ieungkorean"]=12615,
    ["ieungparenkorean"]=12807,
    ["igrave"]=236,
    ["igujarati"]=2695,
    ["igurmukhi"]=2567,
    ["ihiragana"]=12356,
    ["ihookabove"]=7881,
    ["iibengali"]=2440,
    ["iicyrillic"]=1080,
    ["iideva"]=2312,
    ["iigujarati"]=2696,
    ["iigurmukhi"]=2568,
    ["iimatragurmukhi"]=2624,
    ["iinvertedbreve"]=523,
    ["iishortcyrillic"]=1081,
    ["iivowelsignbengali"]=2496,
    ["iivowelsigndeva"]=2368,
    ["iivowelsigngujarati"]=2752,
    ["ij"]=307,
    ["ikatakana"]=12452,
    ["ikatakanahalfwidth"]=65394,
    ["ikorean"]=12643,
    ["iluyhebrew"]=1452,
    ["imacron"]=299,
    ["imacroncyrillic"]=1251,
    ["imageorapproximatelyequal"]=8787,
    ["imatragurmukhi"]=2623,
    ["imonospace"]=65353,
    ["increment"]=8710,
    ["infinity"]=8734,
    ["iniarmenian"]=1387,
    ["integral"]=8747,
    ["integralbt"]=8993,
    ["integraltp"]=8992,
    ["intersection"]=8745,
    ["intisquare"]=13061,
    ["invbullet"]=9688,
    ["invsmileface"]=9787,
    ["iocyrillic"]=1105,
    ["iogonek"]=303,
    ["iota"]=953,
    ["iotadieresis"]=970,
    ["iotadieresistonos"]=912,
    ["iotalatin"]=617,
    ["iotatonos"]=943,
    ["iparen"]=9380,
    ["irigurmukhi"]=2674,
    ["ismallhiragana"]=12355,
    ["ismallkatakana"]=12451,
    ["ismallkatakanahalfwidth"]=65384,
    ["issharbengali"]=2554,
    ["istroke"]=616,
    ["iterationhiragana"]=12445,
    ["iterationkatakana"]=12541,
    ["itilde"]=297,
    ["itildebelow"]=7725,
    ["iubopomofo"]=12585,
    ["iucyrillic"]=1102,
    ["ivowelsignbengali"]=2495,
    ["ivowelsigndeva"]=2367,
    ["ivowelsigngujarati"]=2751,
    ["izhitsacyrillic"]=1141,
    ["izhitsadblgravecyrillic"]=1143,
    ["j"]=106,
    ["jaarmenian"]=1393,
    ["jabengali"]=2460,
    ["jadeva"]=2332,
    ["jagujarati"]=2716,
    ["jagurmukhi"]=2588,
    ["jbopomofo"]=12560,
    ["jcaron"]=496,
    ["jcircle"]=9433,
    ["jcircumflex"]=309,
    ["jcrossedtail"]=669,
    ["jdotlessstroke"]=607,
    ["jecyrillic"]=1112,
    ["jeemarabic"]=1580,
    ["jeemfinalarabic"]=65182,
    ["jeeminitialarabic"]=65183,
    ["jeemmedialarabic"]=65184,
    ["jeharabic"]=1688,
    ["jehfinalarabic"]=64395,
    ["jhabengali"]=2461,
    ["jhadeva"]=2333,
    ["jhagujarati"]=2717,
    ["jhagurmukhi"]=2589,
    ["jheharmenian"]=1403,
    ["jis"]=12292,
    ["jmonospace"]=65354,
    ["jparen"]=9381,
    ["jsuperior"]=690,
    ["k"]=107,
    ["kabashkircyrillic"]=1185,
    ["kabengali"]=2453,
    ["kacute"]=7729,
    ["kacyrillic"]=1082,
    ["kadescendercyrillic"]=1179,
    ["kadeva"]=2325,
    ["kafarabic"]=1603,
    ["kafdageshhebrew"]=64315,
    ["kaffinalarabic"]=65242,
    ["kafhebrew"]=1499,
    ["kafinitialarabic"]=65243,
    ["kafmedialarabic"]=65244,
    ["kafrafehebrew"]=64333,
    ["kagujarati"]=2709,
    ["kagurmukhi"]=2581,
    ["kahiragana"]=12363,
    ["kahookcyrillic"]=1220,
    ["kakatakana"]=12459,
    ["kakatakanahalfwidth"]=65398,
    ["kappa"]=954,
    ["kappasymbolgreek"]=1008,
    ["kapyeounmieumkorean"]=12657,
    ["kapyeounphieuphkorean"]=12676,
    ["kapyeounpieupkorean"]=12664,
    ["kapyeounssangpieupkorean"]=12665,
    ["karoriisquare"]=13069,
    ["kasmallkatakana"]=12533,
    ["kasquare"]=13188,
    ["kasraarabic"]=1616,
    ["kasratanarabic"]=1613,
    ["kastrokecyrillic"]=1183,
    ["katahiraprolongmarkhalfwidth"]=65392,
    ["kaverticalstrokecyrillic"]=1181,
    ["kbopomofo"]=12558,
    ["kcalsquare"]=13193,
    ["kcaron"]=489,
    ["kcircle"]=9434,
    ["kcommaaccent"]=311,
    ["kdotbelow"]=7731,
    ["keharmenian"]=1412,
    ["kehiragana"]=12369,
    ["kekatakana"]=12465,
    ["kekatakanahalfwidth"]=65401,
    ["kenarmenian"]=1391,
    ["kesmallkatakana"]=12534,
    ["kgreenlandic"]=312,
    ["khabengali"]=2454,
    ["khacyrillic"]=1093,
    ["khadeva"]=2326,
    ["khagujarati"]=2710,
    ["khagurmukhi"]=2582,
    ["khaharabic"]=1582,
    ["khahfinalarabic"]=65190,
    ["khahinitialarabic"]=65191,
    ["khahmedialarabic"]=65192,
    ["kheicoptic"]=999,
    ["khhadeva"]=2393,
    ["khhagurmukhi"]=2649,
    ["khieukhacirclekorean"]=12920,
    ["khieukhaparenkorean"]=12824,
    ["khieukhcirclekorean"]=12906,
    ["khieukhkorean"]=12619,
    ["khieukhparenkorean"]=12810,
    ["khokhaithai"]=3586,
    ["khokhonthai"]=3589,
    ["khokhuatthai"]=3587,
    ["khokhwaithai"]=3588,
    ["khomutthai"]=3675,
    ["khook"]=409,
    ["khorakhangthai"]=3590,
    ["khzsquare"]=13201,
    ["kihiragana"]=12365,
    ["kikatakana"]=12461,
    ["kikatakanahalfwidth"]=65399,
    ["kiroguramusquare"]=13077,
    ["kiromeetorusquare"]=13078,
    ["kirosquare"]=13076,
    ["kiyeokacirclekorean"]=12910,
    ["kiyeokaparenkorean"]=12814,
    ["kiyeokcirclekorean"]=12896,
    ["kiyeokkorean"]=12593,
    ["kiyeokparenkorean"]=12800,
    ["kiyeoksioskorean"]=12595,
    ["kjecyrillic"]=1116,
    ["klinebelow"]=7733,
    ["klsquare"]=13208,
    ["kmcubedsquare"]=13222,
    ["kmonospace"]=65355,
    ["kmsquaredsquare"]=13218,
    ["kohiragana"]=12371,
    ["kohmsquare"]=13248,
    ["kokaithai"]=3585,
    ["kokatakana"]=12467,
    ["kokatakanahalfwidth"]=65402,
    ["kooposquare"]=13086,
    ["koppacyrillic"]=1153,
    ["koreanstandardsymbol"]=12927,
    ["koroniscmb"]=835,
    ["kparen"]=9382,
    ["kpasquare"]=13226,
    ["ksicyrillic"]=1135,
    ["ktsquare"]=13263,
    ["kturned"]=670,
    ["kuhiragana"]=12367,
    ["kukatakana"]=12463,
    ["kukatakanahalfwidth"]=65400,
    ["kvsquare"]=13240,
    ["kwsquare"]=13246,
    ["l"]=108,
    ["labengali"]=2482,
    ["lacute"]=314,
    ["ladeva"]=2354,
    ["lagujarati"]=2738,
    ["lagurmukhi"]=2610,
    ["lakkhangyaothai"]=3653,
    ["lamaleffinalarabic"]=65276,
    ["lamalefhamzaabovefinalarabic"]=65272,
    ["lamalefhamzaaboveisolatedarabic"]=65271,
    ["lamalefhamzabelowfinalarabic"]=65274,
    ["lamalefhamzabelowisolatedarabic"]=65273,
    ["lamalefisolatedarabic"]=65275,
    ["lamalefmaddaabovefinalarabic"]=65270,
    ["lamalefmaddaaboveisolatedarabic"]=65269,
    ["lamarabic"]=1604,
    ["lambda"]=955,
    ["lambdastroke"]=411,
    ["lameddageshhebrew"]=64316,
    ["lamedholamhebrew"]=1500,
    ["lamfinalarabic"]=65246,
    ["lamhahinitialarabic"]=64714,
    ["lamjeeminitialarabic"]=64713,
    ["lamkhahinitialarabic"]=64715,
    ["lamlamhehisolatedarabic"]=65010,
    ["lammedialarabic"]=65248,
    ["lammeemhahinitialarabic"]=64904,
    ["lammeeminitialarabic"]=64716,
    ["lammeemkhahinitialarabic"]=65247,
    ["largecircle"]=9711,
    ["lbar"]=410,
    ["lbelt"]=620,
    ["lbopomofo"]=12556,
    ["lcaron"]=318,
    ["lcircle"]=9435,
    ["lcircumflexbelow"]=7741,
    ["lcommaaccent"]=316,
    ["ldotaccent"]=320,
    ["ldotbelow"]=7735,
    ["ldotbelowmacron"]=7737,
    ["leftangleabovecmb"]=794,
    ["lefttackbelowcmb"]=792,
    ["less"]=60,
    ["lessequal"]=8804,
    ["lessequalorgreater"]=8922,
    ["lessmonospace"]=65308,
    ["lessorequivalent"]=8818,
    ["lessorgreater"]=8822,
    ["lessoverequal"]=8806,
    ["lesssmall"]=65124,
    ["lezh"]=622,
    ["lfblock"]=9612,
    ["lhookretroflex"]=621,
    ["lira"]=8356,
    ["liwnarmenian"]=1388,
    ["lj"]=457,
    ["ljecyrillic"]=1113,
    ["lladeva"]=2355,
    ["llagujarati"]=2739,
    ["llinebelow"]=7739,
    ["llladeva"]=2356,
    ["llvocalicbengali"]=2529,
    ["llvocalicdeva"]=2401,
    ["llvocalicvowelsignbengali"]=2531,
    ["llvocalicvowelsigndeva"]=2403,
    ["lmiddletilde"]=619,
    ["lmonospace"]=65356,
    ["lmsquare"]=13264,
    ["lochulathai"]=3628,
    ["logicaland"]=8743,
    ["logicalnot"]=172,
    ["logicalor"]=8744,
    ["lolingthai"]=3621,
    ["lowlinecenterline"]=65102,
    ["lowlinecmb"]=818,
    ["lowlinedashed"]=65101,
    ["lozenge"]=9674,
    ["lparen"]=9383,
    ["lslash"]=322,
    ["lsquare"]=8467,
    ["luthai"]=3622,
    ["lvocalicbengali"]=2444,
    ["lvocalicdeva"]=2316,
    ["lvocalicvowelsignbengali"]=2530,
    ["lvocalicvowelsigndeva"]=2402,
    ["lxsquare"]=13267,
    ["m"]=109,
    ["mabengali"]=2478,
    ["macron"]=175,
    ["macronbelowcmb"]=817,
    ["macroncmb"]=772,
    ["macronlowmod"]=717,
    ["macronmonospace"]=65507,
    ["macute"]=7743,
    ["madeva"]=2350,
    ["magujarati"]=2734,
    ["magurmukhi"]=2606,
    ["mahapakhlefthebrew"]=1444,
    ["mahiragana"]=12414,
    ["maichattawathai"]=3659,
    ["maiekthai"]=3656,
    ["maihanakatthai"]=3633,
    ["maitaikhuthai"]=3655,
    ["maithothai"]=3657,
    ["maitrithai"]=3658,
    ["maiyamokthai"]=3654,
    ["makatakana"]=12510,
    ["makatakanahalfwidth"]=65423,
    ["mansyonsquare"]=13127,
    ["maqafhebrew"]=1470,
    ["mars"]=9794,
    ["masoracirclehebrew"]=1455,
    ["masquare"]=13187,
    ["mbopomofo"]=12551,
    ["mbsquare"]=13268,
    ["mcircle"]=9436,
    ["mcubedsquare"]=13221,
    ["mdotaccent"]=7745,
    ["mdotbelow"]=7747,
    ["meemarabic"]=1605,
    ["meemfinalarabic"]=65250,
    ["meeminitialarabic"]=65251,
    ["meemmedialarabic"]=65252,
    ["meemmeeminitialarabic"]=64721,
    ["meemmeemisolatedarabic"]=64584,
    ["meetorusquare"]=13133,
    ["mehiragana"]=12417,
    ["meizierasquare"]=13182,
    ["mekatakana"]=12513,
    ["mekatakanahalfwidth"]=65426,
    ["memdageshhebrew"]=64318,
    ["memhebrew"]=1502,
    ["menarmenian"]=1396,
    ["merkhakefulalefthebrew"]=1446,
    ["merkhalefthebrew"]=1445,
    ["mhook"]=625,
    ["mhzsquare"]=13202,
    ["middledotkatakanahalfwidth"]=65381,
    ["mieumacirclekorean"]=12914,
    ["mieumaparenkorean"]=12818,
    ["mieumcirclekorean"]=12900,
    ["mieumkorean"]=12609,
    ["mieumpansioskorean"]=12656,
    ["mieumparenkorean"]=12804,
    ["mieumpieupkorean"]=12654,
    ["mieumsioskorean"]=12655,
    ["mihiragana"]=12415,
    ["mikatakana"]=12511,
    ["mikatakanahalfwidth"]=65424,
    ["minus"]=8722,
    ["minusbelowcmb"]=800,
    ["minuscircle"]=8854,
    ["minusmod"]=727,
    ["minusplus"]=8723,
    ["minute"]=8242,
    ["miribaarusquare"]=13130,
    ["mirisquare"]=13129,
    ["mlonglegturned"]=624,
    ["mlsquare"]=13206,
    ["mmcubedsquare"]=13219,
    ["mmonospace"]=65357,
    ["mmsquaredsquare"]=13215,
    ["mohiragana"]=12418,
    ["mohmsquare"]=13249,
    ["mokatakana"]=12514,
    ["mokatakanahalfwidth"]=65427,
    ["molsquare"]=13270,
    ["momathai"]=3617,
    ["moverssquare"]=13223,
    ["moverssquaredsquare"]=13224,
    ["mparen"]=9384,
    ["mpasquare"]=13227,
    ["mssquare"]=13235,
    ["mturned"]=623,
    ["mu1"]=181,
    ["muasquare"]=13186,
    ["muchgreater"]=8811,
    ["muchless"]=8810,
    ["mufsquare"]=13196,
    ["mugreek"]=956,
    ["mugsquare"]=13197,
    ["muhiragana"]=12416,
    ["mukatakana"]=12512,
    ["mukatakanahalfwidth"]=65425,
    ["mulsquare"]=13205,
    ["multiply"]=215,
    ["mumsquare"]=13211,
    ["munahlefthebrew"]=1443,
    ["musicalnote"]=9834,
    ["musicalnotedbl"]=9835,
    ["musicflatsign"]=9837,
    ["musicsharpsign"]=9839,
    ["mussquare"]=13234,
    ["muvsquare"]=13238,
    ["muwsquare"]=13244,
    ["mvmegasquare"]=13241,
    ["mvsquare"]=13239,
    ["mwmegasquare"]=13247,
    ["mwsquare"]=13245,
    ["n"]=110,
    ["nabengali"]=2472,
    ["nabla"]=8711,
    ["nacute"]=324,
    ["nadeva"]=2344,
    ["nagujarati"]=2728,
    ["nagurmukhi"]=2600,
    ["nahiragana"]=12394,
    ["nakatakana"]=12490,
    ["nakatakanahalfwidth"]=65413,
    ["nasquare"]=13185,
    ["nbopomofo"]=12555,
    ["ncaron"]=328,
    ["ncircle"]=9437,
    ["ncircumflexbelow"]=7755,
    ["ncommaaccent"]=326,
    ["ndotaccent"]=7749,
    ["ndotbelow"]=7751,
    ["nehiragana"]=12397,
    ["nekatakana"]=12493,
    ["nekatakanahalfwidth"]=65416,
    ["nfsquare"]=13195,
    ["ngabengali"]=2457,
    ["ngadeva"]=2329,
    ["ngagujarati"]=2713,
    ["ngagurmukhi"]=2585,
    ["ngonguthai"]=3591,
    ["nhiragana"]=12435,
    ["nhookleft"]=626,
    ["nhookretroflex"]=627,
    ["nieunacirclekorean"]=12911,
    ["nieunaparenkorean"]=12815,
    ["nieuncieuckorean"]=12597,
    ["nieuncirclekorean"]=12897,
    ["nieunhieuhkorean"]=12598,
    ["nieunkorean"]=12596,
    ["nieunpansioskorean"]=12648,
    ["nieunparenkorean"]=12801,
    ["nieunsioskorean"]=12647,
    ["nieuntikeutkorean"]=12646,
    ["nihiragana"]=12395,
    ["nikatakana"]=12491,
    ["nikatakanahalfwidth"]=65414,
    ["nikhahitthai"]=3661,
    ["nine"]=57,
    ["ninebengali"]=2543,
    ["ninecircle"]=9320,
    ["ninecircleinversesansserif"]=10130,
    ["ninedeva"]=2415,
    ["ninegujarati"]=2799,
    ["ninegurmukhi"]=2671,
    ["ninehackarabic"]=1641,
    ["ninehangzhou"]=12329,
    ["nineideographicparen"]=12840,
    ["nineinferior"]=8329,
    ["ninemonospace"]=65305,
    ["nineparen"]=9340,
    ["nineperiod"]=9360,
    ["ninepersian"]=1785,
    ["nineroman"]=8568,
    ["ninesuperior"]=8313,
    ["nineteencircle"]=9330,
    ["nineteenparen"]=9350,
    ["nineteenperiod"]=9370,
    ["ninethai"]=3673,
    ["nj"]=460,
    ["njecyrillic"]=1114,
    ["nkatakana"]=12531,
    ["nkatakanahalfwidth"]=65437,
    ["nlegrightlong"]=414,
    ["nlinebelow"]=7753,
    ["nmonospace"]=65358,
    ["nmsquare"]=13210,
    ["nnabengali"]=2467,
    ["nnadeva"]=2339,
    ["nnagujarati"]=2723,
    ["nnagurmukhi"]=2595,
    ["nnnadeva"]=2345,
    ["nohiragana"]=12398,
    ["nokatakana"]=12494,
    ["nokatakanahalfwidth"]=65417,
    ["nonbreakingspace"]=160,
    ["nonenthai"]=3603,
    ["nonuthai"]=3609,
    ["noonarabic"]=1606,
    ["noonfinalarabic"]=65254,
    ["noonghunnaarabic"]=1722,
    ["noonghunnafinalarabic"]=64415,
    ["nooninitialarabic"]=65255,
    ["noonjeeminitialarabic"]=64722,
    ["noonjeemisolatedarabic"]=64587,
    ["noonmedialarabic"]=65256,
    ["noonmeeminitialarabic"]=64725,
    ["noonmeemisolatedarabic"]=64590,
    ["noonnoonfinalarabic"]=64653,
    ["notcontains"]=8716,
    ["notelementof"]=8713,
    ["notequal"]=8800,
    ["notgreater"]=8815,
    ["notgreaternorequal"]=8817,
    ["notgreaternorless"]=8825,
    ["notidentical"]=8802,
    ["notless"]=8814,
    ["notlessnorequal"]=8816,
    ["notparallel"]=8742,
    ["notprecedes"]=8832,
    ["notsubset"]=8836,
    ["notsucceeds"]=8833,
    ["notsuperset"]=8837,
    ["nowarmenian"]=1398,
    ["nparen"]=9385,
    ["nssquare"]=13233,
    ["nsuperior"]=8319,
    ["ntilde"]=241,
    ["nu"]=957,
    ["nuhiragana"]=12396,
    ["nukatakana"]=12492,
    ["nukatakanahalfwidth"]=65415,
    ["nuktabengali"]=2492,
    ["nuktadeva"]=2364,
    ["nuktagujarati"]=2748,
    ["nuktagurmukhi"]=2620,
    ["numbersign"]=35,
    ["numbersignmonospace"]=65283,
    ["numbersignsmall"]=65119,
    ["numeralsigngreek"]=884,
    ["numeralsignlowergreek"]=885,
    ["numero"]=8470,
    ["nundageshhebrew"]=64320,
    ["nunhebrew"]=1504,
    ["nvsquare"]=13237,
    ["nwsquare"]=13243,
    ["nyabengali"]=2462,
    ["nyadeva"]=2334,
    ["nyagujarati"]=2718,
    ["nyagurmukhi"]=2590,
    ["o"]=111,
    ["oacute"]=243,
    ["oangthai"]=3629,
    ["obarred"]=629,
    ["obarredcyrillic"]=1257,
    ["obarreddieresiscyrillic"]=1259,
    ["obengali"]=2451,
    ["obopomofo"]=12571,
    ["obreve"]=335,
    ["ocandradeva"]=2321,
    ["ocandragujarati"]=2705,
    ["ocandravowelsigndeva"]=2377,
    ["ocandravowelsigngujarati"]=2761,
    ["ocaron"]=466,
    ["ocircle"]=9438,
    ["ocircumflex"]=244,
    ["ocircumflexacute"]=7889,
    ["ocircumflexdotbelow"]=7897,
    ["ocircumflexgrave"]=7891,
    ["ocircumflexhookabove"]=7893,
    ["ocircumflextilde"]=7895,
    ["ocyrillic"]=1086,
    ["odblgrave"]=525,
    ["odeva"]=2323,
    ["odieresis"]=246,
    ["odieresiscyrillic"]=1255,
    ["odotbelow"]=7885,
    ["oe"]=339,
    ["oekorean"]=12634,
    ["ogonek"]=731,
    ["ogonekcmb"]=808,
    ["ograve"]=242,
    ["ogujarati"]=2707,
    ["oharmenian"]=1413,
    ["ohiragana"]=12362,
    ["ohookabove"]=7887,
    ["ohorn"]=417,
    ["ohornacute"]=7899,
    ["ohorndotbelow"]=7907,
    ["ohorngrave"]=7901,
    ["ohornhookabove"]=7903,
    ["ohorntilde"]=7905,
    ["ohungarumlaut"]=337,
    ["oi"]=419,
    ["oinvertedbreve"]=527,
    ["okatakana"]=12458,
    ["okatakanahalfwidth"]=65397,
    ["okorean"]=12631,
    ["olehebrew"]=1451,
    ["omacron"]=333,
    ["omacronacute"]=7763,
    ["omacrongrave"]=7761,
    ["omdeva"]=2384,
    ["omega"]=969,
    ["omegacyrillic"]=1121,
    ["omegalatinclosed"]=631,
    ["omegaroundcyrillic"]=1147,
    ["omegatitlocyrillic"]=1149,
    ["omegatonos"]=974,
    ["omgujarati"]=2768,
    ["omicron"]=959,
    ["omicrontonos"]=972,
    ["omonospace"]=65359,
    ["one"]=49,
    ["onebengali"]=2535,
    ["onecircle"]=9312,
    ["onecircleinversesansserif"]=10122,
    ["onedeva"]=2407,
    ["onedotenleader"]=8228,
    ["oneeighth"]=8539,
    ["onegujarati"]=2791,
    ["onegurmukhi"]=2663,
    ["onehackarabic"]=1633,
    ["onehalf"]=189,
    ["onehangzhou"]=12321,
    ["oneideographicparen"]=12832,
    ["oneinferior"]=8321,
    ["onemonospace"]=65297,
    ["onenumeratorbengali"]=2548,
    ["oneparen"]=9332,
    ["oneperiod"]=9352,
    ["onepersian"]=1777,
    ["onequarter"]=188,
    ["oneroman"]=8560,
    ["onesuperior"]=185,
    ["onethai"]=3665,
    ["onethird"]=8531,
    ["oogonek"]=491,
    ["oogonekmacron"]=493,
    ["oogurmukhi"]=2579,
    ["oomatragurmukhi"]=2635,
    ["oopen"]=596,
    ["oparen"]=9386,
    ["option"]=8997,
    ["ordfeminine"]=170,
    ["ordmasculine"]=186,
    ["oshortdeva"]=2322,
    ["oshortvowelsigndeva"]=2378,
    ["oslash"]=248,
    ["osmallhiragana"]=12361,
    ["osmallkatakana"]=12457,
    ["osmallkatakanahalfwidth"]=65387,
    ["ostrokeacute"]=511,
    ["otcyrillic"]=1151,
    ["otilde"]=245,
    ["otildeacute"]=7757,
    ["otildedieresis"]=7759,
    ["oubopomofo"]=12577,
    ["overline"]=8254,
    ["overlinecenterline"]=65098,
    ["overlinecmb"]=773,
    ["overlinedashed"]=65097,
    ["overlinedblwavy"]=65100,
    ["overlinewavy"]=65099,
    ["ovowelsignbengali"]=2507,
    ["ovowelsigndeva"]=2379,
    ["ovowelsigngujarati"]=2763,
    ["p"]=112,
    ["paampssquare"]=13184,
    ["paasentosquare"]=13099,
    ["pabengali"]=2474,
    ["pacute"]=7765,
    ["padeva"]=2346,
    ["pagedown"]=8671,
    ["pageup"]=8670,
    ["pagujarati"]=2730,
    ["pagurmukhi"]=2602,
    ["pahiragana"]=12401,
    ["paiyannoithai"]=3631,
    ["pakatakana"]=12497,
    ["palatalizationcyrilliccmb"]=1156,
    ["palochkacyrillic"]=1216,
    ["pansioskorean"]=12671,
    ["paragraph"]=182,
    ["parallel"]=8741,
    ["parenleft"]=40,
    ["parenleftaltonearabic"]=64830,
    ["parenleftinferior"]=8333,
    ["parenleftmonospace"]=65288,
    ["parenleftsmall"]=65113,
    ["parenleftsuperior"]=8317,
    ["parenleftvertical"]=65077,
    ["parenright"]=41,
    ["parenrightaltonearabic"]=64831,
    ["parenrightinferior"]=8334,
    ["parenrightmonospace"]=65289,
    ["parenrightsmall"]=65114,
    ["parenrightsuperior"]=8318,
    ["parenrightvertical"]=65078,
    ["partialdiff"]=8706,
    ["paseqhebrew"]=1472,
    ["pashtahebrew"]=1433,
    ["pasquare"]=13225,
    ["patahwidehebrew"]=1463,
    ["pazerhebrew"]=1441,
    ["pbopomofo"]=12550,
    ["pcircle"]=9439,
    ["pdotaccent"]=7767,
    ["pecyrillic"]=1087,
    ["pedageshhebrew"]=64324,
    ["peezisquare"]=13115,
    ["pefinaldageshhebrew"]=64323,
    ["peharabic"]=1662,
    ["peharmenian"]=1402,
    ["pehebrew"]=1508,
    ["pehfinalarabic"]=64343,
    ["pehinitialarabic"]=64344,
    ["pehiragana"]=12410,
    ["pehmedialarabic"]=64345,
    ["pekatakana"]=12506,
    ["pemiddlehookcyrillic"]=1191,
    ["perafehebrew"]=64334,
    ["percent"]=37,
    ["percentarabic"]=1642,
    ["percentmonospace"]=65285,
    ["percentsmall"]=65130,
    ["period"]=46,
    ["periodarmenian"]=1417,
    ["periodcentered"]=183,
    ["periodhalfwidth"]=65377,
    ["periodmonospace"]=65294,
    ["periodsmall"]=65106,
    ["perispomenigreekcmb"]=834,
    ["perpendicular"]=8869,
    ["perthousand"]=8240,
    ["peseta"]=8359,
    ["pfsquare"]=13194,
    ["phabengali"]=2475,
    ["phadeva"]=2347,
    ["phagujarati"]=2731,
    ["phagurmukhi"]=2603,
    ["phi"]=966,
    ["phieuphacirclekorean"]=12922,
    ["phieuphaparenkorean"]=12826,
    ["phieuphcirclekorean"]=12908,
    ["phieuphkorean"]=12621,
    ["phieuphparenkorean"]=12812,
    ["philatin"]=632,
    ["phinthuthai"]=3642,
    ["phisymbolgreek"]=981,
    ["phook"]=421,
    ["phophanthai"]=3614,
    ["phophungthai"]=3612,
    ["phosamphaothai"]=3616,
    ["pi"]=960,
    ["pieupacirclekorean"]=12915,
    ["pieupaparenkorean"]=12819,
    ["pieupcieuckorean"]=12662,
    ["pieupcirclekorean"]=12901,
    ["pieupkiyeokkorean"]=12658,
    ["pieupkorean"]=12610,
    ["pieupparenkorean"]=12805,
    ["pieupsioskiyeokkorean"]=12660,
    ["pieupsioskorean"]=12612,
    ["pieupsiostikeutkorean"]=12661,
    ["pieupthieuthkorean"]=12663,
    ["pieuptikeutkorean"]=12659,
    ["pihiragana"]=12404,
    ["pikatakana"]=12500,
    ["pisymbolgreek"]=982,
    ["piwrarmenian"]=1411,
    ["plus"]=43,
    ["plusbelowcmb"]=799,
    ["pluscircle"]=8853,
    ["plusminus"]=177,
    ["plusmod"]=726,
    ["plusmonospace"]=65291,
    ["plussmall"]=65122,
    ["plussuperior"]=8314,
    ["pmonospace"]=65360,
    ["pmsquare"]=13272,
    ["pohiragana"]=12413,
    ["pointingindexdownwhite"]=9759,
    ["pointingindexleftwhite"]=9756,
    ["pointingindexrightwhite"]=9758,
    ["pointingindexupwhite"]=9757,
    ["pokatakana"]=12509,
    ["poplathai"]=3611,
    ["postalmark"]=12306,
    ["postalmarkface"]=12320,
    ["pparen"]=9387,
    ["precedes"]=8826,
    ["prescription"]=8478,
    ["primemod"]=697,
    ["primereversed"]=8245,
    ["product"]=8719,
    ["projective"]=8965,
    ["prolongedkana"]=12540,
    ["propellor"]=8984,
    ["proportion"]=8759,
    ["proportional"]=8733,
    ["psi"]=968,
    ["psicyrillic"]=1137,
    ["psilipneumatacyrilliccmb"]=1158,
    ["pssquare"]=13232,
    ["puhiragana"]=12407,
    ["pukatakana"]=12503,
    ["pvsquare"]=13236,
    ["pwsquare"]=13242,
    ["q"]=113,
    ["qadeva"]=2392,
    ["qadmahebrew"]=1448,
    ["qafarabic"]=1602,
    ["qaffinalarabic"]=65238,
    ["qafinitialarabic"]=65239,
    ["qafmedialarabic"]=65240,
    ["qamatswidehebrew"]=1464,
    ["qarneyparahebrew"]=1439,
    ["qbopomofo"]=12561,
    ["qcircle"]=9440,
    ["qhook"]=672,
    ["qmonospace"]=65361,
    ["qofdageshhebrew"]=64327,
    ["qoftserehebrew"]=1511,
    ["qparen"]=9388,
    ["quarternote"]=9833,
    ["qubutswidehebrew"]=1467,
    ["question"]=63,
    ["questionarabic"]=1567,
    ["questionarmenian"]=1374,
    ["questiondown"]=191,
    ["questiongreek"]=894,
    ["questionmonospace"]=65311,
    ["quotedbl"]=34,
    ["quotedblbase"]=8222,
    ["quotedblleft"]=8220,
    ["quotedblmonospace"]=65282,
    ["quotedblprime"]=12318,
    ["quotedblprimereversed"]=12317,
    ["quotedblright"]=8221,
    ["quoteleft"]=8216,
    ["quotereversed"]=8219,
    ["quoteright"]=8217,
    ["quoterightn"]=329,
    ["quotesinglbase"]=8218,
    ["quotesingle"]=39,
    ["quotesinglemonospace"]=65287,
    ["r"]=114,
    ["raarmenian"]=1404,
    ["rabengali"]=2480,
    ["racute"]=341,
    ["radeva"]=2352,
    ["radical"]=8730,
    ["radoverssquare"]=13230,
    ["radoverssquaredsquare"]=13231,
    ["radsquare"]=13229,
    ["rafehebrew"]=1471,
    ["ragujarati"]=2736,
    ["ragurmukhi"]=2608,
    ["rahiragana"]=12425,
    ["rakatakana"]=12521,
    ["rakatakanahalfwidth"]=65431,
    ["ralowerdiagonalbengali"]=2545,
    ["ramiddlediagonalbengali"]=2544,
    ["ramshorn"]=612,
    ["ratio"]=8758,
    ["rbopomofo"]=12566,
    ["rcaron"]=345,
    ["rcircle"]=9441,
    ["rcommaaccent"]=343,
    ["rdblgrave"]=529,
    ["rdotaccent"]=7769,
    ["rdotbelow"]=7771,
    ["rdotbelowmacron"]=7773,
    ["referencemark"]=8251,
    ["registered"]=174,
    ["reharmenian"]=1408,
    ["rehfinalarabic"]=65198,
    ["rehiragana"]=12428,
    ["rehyehaleflamarabic"]=1585,
    ["rekatakana"]=12524,
    ["rekatakanahalfwidth"]=65434,
    ["reshdageshhebrew"]=64328,
    ["reshtserehebrew"]=1512,
    ["reversedtilde"]=8765,
    ["reviamugrashhebrew"]=1431,
    ["revlogicalnot"]=8976,
    ["rfishhook"]=638,
    ["rfishhookreversed"]=639,
    ["rhabengali"]=2525,
    ["rhadeva"]=2397,
    ["rho"]=961,
    ["rhook"]=637,
    ["rhookturned"]=635,
    ["rhookturnedsuperior"]=693,
    ["rhosymbolgreek"]=1009,
    ["rhotichookmod"]=734,
    ["rieulacirclekorean"]=12913,
    ["rieulaparenkorean"]=12817,
    ["rieulcirclekorean"]=12899,
    ["rieulhieuhkorean"]=12608,
    ["rieulkiyeokkorean"]=12602,
    ["rieulkiyeoksioskorean"]=12649,
    ["rieulkorean"]=12601,
    ["rieulmieumkorean"]=12603,
    ["rieulpansioskorean"]=12652,
    ["rieulparenkorean"]=12803,
    ["rieulphieuphkorean"]=12607,
    ["rieulpieupkorean"]=12604,
    ["rieulpieupsioskorean"]=12651,
    ["rieulsioskorean"]=12605,
    ["rieulthieuthkorean"]=12606,
    ["rieultikeutkorean"]=12650,
    ["rieulyeorinhieuhkorean"]=12653,
    ["rightangle"]=8735,
    ["righttackbelowcmb"]=793,
    ["righttriangle"]=8895,
    ["rihiragana"]=12426,
    ["rikatakana"]=12522,
    ["rikatakanahalfwidth"]=65432,
    ["ring"]=730,
    ["ringbelowcmb"]=805,
    ["ringcmb"]=778,
    ["ringhalfleft"]=703,
    ["ringhalfleftarmenian"]=1369,
    ["ringhalfleftbelowcmb"]=796,
    ["ringhalfleftcentered"]=723,
    ["ringhalfright"]=702,
    ["ringhalfrightbelowcmb"]=825,
    ["ringhalfrightcentered"]=722,
    ["rinvertedbreve"]=531,
    ["rittorusquare"]=13137,
    ["rlinebelow"]=7775,
    ["rlongleg"]=636,
    ["rlonglegturned"]=634,
    ["rmonospace"]=65362,
    ["rohiragana"]=12429,
    ["rokatakana"]=12525,
    ["rokatakanahalfwidth"]=65435,
    ["roruathai"]=3619,
    ["rparen"]=9389,
    ["rrabengali"]=2524,
    ["rradeva"]=2353,
    ["rragurmukhi"]=2652,
    ["rreharabic"]=1681,
    ["rrehfinalarabic"]=64397,
    ["rrvocalicbengali"]=2528,
    ["rrvocalicdeva"]=2400,
    ["rrvocalicgujarati"]=2784,
    ["rrvocalicvowelsignbengali"]=2500,
    ["rrvocalicvowelsigndeva"]=2372,
    ["rrvocalicvowelsigngujarati"]=2756,
    ["rtblock"]=9616,
    ["rturned"]=633,
    ["rturnedsuperior"]=692,
    ["ruhiragana"]=12427,
    ["rukatakana"]=12523,
    ["rukatakanahalfwidth"]=65433,
    ["rupeemarkbengali"]=2546,
    ["rupeesignbengali"]=2547,
    ["ruthai"]=3620,
    ["rvocalicbengali"]=2443,
    ["rvocalicdeva"]=2315,
    ["rvocalicgujarati"]=2699,
    ["rvocalicvowelsignbengali"]=2499,
    ["rvocalicvowelsigndeva"]=2371,
    ["rvocalicvowelsigngujarati"]=2755,
    ["s"]=115,
    ["sabengali"]=2488,
    ["sacute"]=347,
    ["sacutedotaccent"]=7781,
    ["sadarabic"]=1589,
    ["sadeva"]=2360,
    ["sadfinalarabic"]=65210,
    ["sadinitialarabic"]=65211,
    ["sadmedialarabic"]=65212,
    ["sagujarati"]=2744,
    ["sagurmukhi"]=2616,
    ["sahiragana"]=12373,
    ["sakatakana"]=12469,
    ["sakatakanahalfwidth"]=65403,
    ["sallallahoualayhewasallamarabic"]=65018,
    ["samekhdageshhebrew"]=64321,
    ["samekhhebrew"]=1505,
    ["saraaathai"]=3634,
    ["saraaethai"]=3649,
    ["saraaimaimalaithai"]=3652,
    ["saraaimaimuanthai"]=3651,
    ["saraamthai"]=3635,
    ["saraathai"]=3632,
    ["saraethai"]=3648,
    ["saraiithai"]=3637,
    ["saraithai"]=3636,
    ["saraothai"]=3650,
    ["saraueethai"]=3639,
    ["sarauethai"]=3638,
    ["sarauthai"]=3640,
    ["sarauuthai"]=3641,
    ["sbopomofo"]=12569,
    ["scaron"]=353,
    ["scarondotaccent"]=7783,
    ["scedilla"]=351,
    ["schwa"]=601,
    ["schwacyrillic"]=1241,
    ["schwadieresiscyrillic"]=1243,
    ["schwahook"]=602,
    ["scircle"]=9442,
    ["scircumflex"]=349,
    ["scommaaccent"]=537,
    ["sdotaccent"]=7777,
    ["sdotbelow"]=7779,
    ["sdotbelowdotaccent"]=7785,
    ["seagullbelowcmb"]=828,
    ["second"]=8243,
    ["secondtonechinese"]=714,
    ["section"]=167,
    ["seenarabic"]=1587,
    ["seenfinalarabic"]=65202,
    ["seeninitialarabic"]=65203,
    ["seenmedialarabic"]=65204,
    ["segoltahebrew"]=1426,
    ["segolwidehebrew"]=1462,
    ["seharmenian"]=1405,
    ["sehiragana"]=12379,
    ["sekatakana"]=12475,
    ["sekatakanahalfwidth"]=65406,
    ["semicolon"]=59,
    ["semicolonarabic"]=1563,
    ["semicolonmonospace"]=65307,
    ["semicolonsmall"]=65108,
    ["semivoicedmarkkana"]=12444,
    ["semivoicedmarkkanahalfwidth"]=65439,
    ["sentisquare"]=13090,
    ["sentosquare"]=13091,
    ["seven"]=55,
    ["sevenbengali"]=2541,
    ["sevencircle"]=9318,
    ["sevencircleinversesansserif"]=10128,
    ["sevendeva"]=2413,
    ["seveneighths"]=8542,
    ["sevengujarati"]=2797,
    ["sevengurmukhi"]=2669,
    ["sevenhackarabic"]=1639,
    ["sevenhangzhou"]=12327,
    ["sevenideographicparen"]=12838,
    ["seveninferior"]=8327,
    ["sevenmonospace"]=65303,
    ["sevenparen"]=9338,
    ["sevenperiod"]=9358,
    ["sevenpersian"]=1783,
    ["sevenroman"]=8566,
    ["sevensuperior"]=8311,
    ["seventeencircle"]=9328,
    ["seventeenparen"]=9348,
    ["seventeenperiod"]=9368,
    ["seventhai"]=3671,
    ["shaarmenian"]=1399,
    ["shabengali"]=2486,
    ["shacyrillic"]=1096,
    ["shaddadammaarabic"]=64609,
    ["shaddadammatanarabic"]=64606,
    ["shaddafathaarabic"]=64608,
    ["shaddafathatanarabic"]=1617,
    ["shaddakasraarabic"]=64610,
    ["shaddakasratanarabic"]=64607,
    ["shadedark"]=9619,
    ["shadelight"]=9617,
    ["shademedium"]=9618,
    ["shadeva"]=2358,
    ["shagujarati"]=2742,
    ["shagurmukhi"]=2614,
    ["shalshelethebrew"]=1427,
    ["shbopomofo"]=12565,
    ["shchacyrillic"]=1097,
    ["sheenarabic"]=1588,
    ["sheenfinalarabic"]=65206,
    ["sheeninitialarabic"]=65207,
    ["sheenmedialarabic"]=65208,
    ["sheicoptic"]=995,
    ["sheqelhebrew"]=8362,
    ["shevawidehebrew"]=1456,
    ["shhacyrillic"]=1211,
    ["shimacoptic"]=1005,
    ["shindageshhebrew"]=64329,
    ["shindageshshindothebrew"]=64300,
    ["shindageshsindothebrew"]=64301,
    ["shindothebrew"]=1473,
    ["shinhebrew"]=1513,
    ["shinshindothebrew"]=64298,
    ["shinsindothebrew"]=64299,
    ["shook"]=642,
    ["sigma"]=963,
    ["sigmafinal"]=962,
    ["sigmalunatesymbolgreek"]=1010,
    ["sihiragana"]=12375,
    ["sikatakana"]=12471,
    ["sikatakanahalfwidth"]=65404,
    ["siluqlefthebrew"]=1469,
    ["sindothebrew"]=1474,
    ["siosacirclekorean"]=12916,
    ["siosaparenkorean"]=12820,
    ["sioscieuckorean"]=12670,
    ["sioscirclekorean"]=12902,
    ["sioskiyeokkorean"]=12666,
    ["sioskorean"]=12613,
    ["siosnieunkorean"]=12667,
    ["siosparenkorean"]=12806,
    ["siospieupkorean"]=12669,
    ["siostikeutkorean"]=12668,
    ["six"]=54,
    ["sixbengali"]=2540,
    ["sixcircle"]=9317,
    ["sixcircleinversesansserif"]=10127,
    ["sixdeva"]=2412,
    ["sixgujarati"]=2796,
    ["sixgurmukhi"]=2668,
    ["sixhackarabic"]=1638,
    ["sixhangzhou"]=12326,
    ["sixideographicparen"]=12837,
    ["sixinferior"]=8326,
    ["sixmonospace"]=65302,
    ["sixparen"]=9337,
    ["sixperiod"]=9357,
    ["sixpersian"]=1782,
    ["sixroman"]=8565,
    ["sixsuperior"]=8310,
    ["sixteencircle"]=9327,
    ["sixteencurrencydenominatorbengali"]=2553,
    ["sixteenparen"]=9347,
    ["sixteenperiod"]=9367,
    ["sixthai"]=3670,
    ["slash"]=47,
    ["slashmonospace"]=65295,
    ["slong"]=383,
    ["slongdotaccent"]=7835,
    ["smonospace"]=65363,
    ["sofpasuqhebrew"]=1475,
    ["softhyphen"]=173,
    ["softsigncyrillic"]=1100,
    ["sohiragana"]=12381,
    ["sokatakana"]=12477,
    ["sokatakanahalfwidth"]=65407,
    ["soliduslongoverlaycmb"]=824,
    ["solidusshortoverlaycmb"]=823,
    ["sorusithai"]=3625,
    ["sosalathai"]=3624,
    ["sosothai"]=3595,
    ["sosuathai"]=3626,
    ["space"]=32,
    ["spadesuitblack"]=9824,
    ["spadesuitwhite"]=9828,
    ["sparen"]=9390,
    ["squarebelowcmb"]=827,
    ["squarecc"]=13252,
    ["squarecm"]=13213,
    ["squarediagonalcrosshatchfill"]=9641,
    ["squarehorizontalfill"]=9636,
    ["squarekg"]=13199,
    ["squarekm"]=13214,
    ["squarekmcapital"]=13262,
    ["squareln"]=13265,
    ["squarelog"]=13266,
    ["squaremg"]=13198,
    ["squaremil"]=13269,
    ["squaremm"]=13212,
    ["squaremsquared"]=13217,
    ["squareorthogonalcrosshatchfill"]=9638,
    ["squareupperlefttolowerrightfill"]=9639,
    ["squareupperrighttolowerleftfill"]=9640,
    ["squareverticalfill"]=9637,
    ["squarewhitewithsmallblack"]=9635,
    ["srsquare"]=13275,
    ["ssabengali"]=2487,
    ["ssadeva"]=2359,
    ["ssagujarati"]=2743,
    ["ssangcieuckorean"]=12617,
    ["ssanghieuhkorean"]=12677,
    ["ssangieungkorean"]=12672,
    ["ssangkiyeokkorean"]=12594,
    ["ssangnieunkorean"]=12645,
    ["ssangpieupkorean"]=12611,
    ["ssangsioskorean"]=12614,
    ["ssangtikeutkorean"]=12600,
    ["sterling"]=163,
    ["sterlingmonospace"]=65505,
    ["strokelongoverlaycmb"]=822,
    ["strokeshortoverlaycmb"]=821,
    ["subset"]=8834,
    ["subsetnotequal"]=8842,
    ["subsetorequal"]=8838,
    ["succeeds"]=8827,
    ["suchthat"]=8715,
    ["suhiragana"]=12377,
    ["sukatakana"]=12473,
    ["sukatakanahalfwidth"]=65405,
    ["sukunarabic"]=1618,
    ["summation"]=8721,
    ["sun"]=9788,
    ["superset"]=8835,
    ["supersetnotequal"]=8843,
    ["supersetorequal"]=8839,
    ["svsquare"]=13276,
    ["syouwaerasquare"]=13180,
    ["t"]=116,
    ["tabengali"]=2468,
    ["tackdown"]=8868,
    ["tackleft"]=8867,
    ["tadeva"]=2340,
    ["tagujarati"]=2724,
    ["tagurmukhi"]=2596,
    ["taharabic"]=1591,
    ["tahfinalarabic"]=65218,
    ["tahinitialarabic"]=65219,
    ["tahiragana"]=12383,
    ["tahmedialarabic"]=65220,
    ["taisyouerasquare"]=13181,
    ["takatakana"]=12479,
    ["takatakanahalfwidth"]=65408,
    ["tatweelarabic"]=1600,
    ["tau"]=964,
    ["tavdageshhebrew"]=64330,
    ["tavhebrew"]=1514,
    ["tbar"]=359,
    ["tbopomofo"]=12554,
    ["tcaron"]=357,
    ["tccurl"]=680,
    ["tcheharabic"]=1670,
    ["tchehfinalarabic"]=64379,
    ["tchehmedialarabic"]=64381,
    ["tchehmeeminitialarabic"]=64380,
    ["tcircle"]=9443,
    ["tcircumflexbelow"]=7793,
    ["tcommaaccent"]=355,
    ["tdieresis"]=7831,
    ["tdotaccent"]=7787,
    ["tdotbelow"]=7789,
    ["tecyrillic"]=1090,
    ["tedescendercyrillic"]=1197,
    ["teharabic"]=1578,
    ["tehfinalarabic"]=65174,
    ["tehhahinitialarabic"]=64674,
    ["tehhahisolatedarabic"]=64524,
    ["tehinitialarabic"]=65175,
    ["tehiragana"]=12390,
    ["tehjeeminitialarabic"]=64673,
    ["tehjeemisolatedarabic"]=64523,
    ["tehmarbutaarabic"]=1577,
    ["tehmarbutafinalarabic"]=65172,
    ["tehmedialarabic"]=65176,
    ["tehmeeminitialarabic"]=64676,
    ["tehmeemisolatedarabic"]=64526,
    ["tehnoonfinalarabic"]=64627,
    ["tekatakana"]=12486,
    ["tekatakanahalfwidth"]=65411,
    ["telephone"]=8481,
    ["telephoneblack"]=9742,
    ["telishagedolahebrew"]=1440,
    ["telishaqetanahebrew"]=1449,
    ["tencircle"]=9321,
    ["tenideographicparen"]=12841,
    ["tenparen"]=9341,
    ["tenperiod"]=9361,
    ["tenroman"]=8569,
    ["tesh"]=679,
    ["tetdageshhebrew"]=64312,
    ["tethebrew"]=1496,
    ["tetsecyrillic"]=1205,
    ["tevirlefthebrew"]=1435,
    ["thabengali"]=2469,
    ["thadeva"]=2341,
    ["thagujarati"]=2725,
    ["thagurmukhi"]=2597,
    ["thalarabic"]=1584,
    ["thalfinalarabic"]=65196,
    ["thanthakhatthai"]=3660,
    ["theharabic"]=1579,
    ["thehfinalarabic"]=65178,
    ["thehinitialarabic"]=65179,
    ["thehmedialarabic"]=65180,
    ["thereexists"]=8707,
    ["therefore"]=8756,
    ["theta"]=952,
    ["thetasymbolgreek"]=977,
    ["thieuthacirclekorean"]=12921,
    ["thieuthaparenkorean"]=12825,
    ["thieuthcirclekorean"]=12907,
    ["thieuthkorean"]=12620,
    ["thieuthparenkorean"]=12811,
    ["thirteencircle"]=9324,
    ["thirteenparen"]=9344,
    ["thirteenperiod"]=9364,
    ["thonangmonthothai"]=3601,
    ["thook"]=429,
    ["thophuthaothai"]=3602,
    ["thorn"]=254,
    ["thothahanthai"]=3607,
    ["thothanthai"]=3600,
    ["thothongthai"]=3608,
    ["thothungthai"]=3606,
    ["thousandcyrillic"]=1154,
    ["thousandsseparatorpersian"]=1644,
    ["three"]=51,
    ["threebengali"]=2537,
    ["threecircle"]=9314,
    ["threecircleinversesansserif"]=10124,
    ["threedeva"]=2409,
    ["threeeighths"]=8540,
    ["threegujarati"]=2793,
    ["threegurmukhi"]=2665,
    ["threehackarabic"]=1635,
    ["threehangzhou"]=12323,
    ["threeideographicparen"]=12834,
    ["threeinferior"]=8323,
    ["threemonospace"]=65299,
    ["threenumeratorbengali"]=2550,
    ["threeparen"]=9334,
    ["threeperiod"]=9354,
    ["threepersian"]=1779,
    ["threequarters"]=190,
    ["threeroman"]=8562,
    ["threesuperior"]=179,
    ["threethai"]=3667,
    ["thzsquare"]=13204,
    ["tihiragana"]=12385,
    ["tikatakana"]=12481,
    ["tikatakanahalfwidth"]=65409,
    ["tikeutacirclekorean"]=12912,
    ["tikeutaparenkorean"]=12816,
    ["tikeutcirclekorean"]=12898,
    ["tikeutkorean"]=12599,
    ["tikeutparenkorean"]=12802,
    ["tilde"]=732,
    ["tildebelowcmb"]=816,
    ["tildecomb"]=771,
    ["tildedoublecmb"]=864,
    ["tildeoperator"]=8764,
    ["tildeoverlaycmb"]=820,
    ["tildeverticalcmb"]=830,
    ["timescircle"]=8855,
    ["tipehalefthebrew"]=1430,
    ["tippigurmukhi"]=2672,
    ["titlocyrilliccmb"]=1155,
    ["tiwnarmenian"]=1407,
    ["tlinebelow"]=7791,
    ["tmonospace"]=65364,
    ["toarmenian"]=1385,
    ["tohiragana"]=12392,
    ["tokatakana"]=12488,
    ["tokatakanahalfwidth"]=65412,
    ["tonebarextrahighmod"]=741,
    ["tonebarextralowmod"]=745,
    ["tonebarhighmod"]=742,
    ["tonebarlowmod"]=744,
    ["tonebarmidmod"]=743,
    ["tonefive"]=445,
    ["tonesix"]=389,
    ["tonetwo"]=424,
    ["tonos"]=900,
    ["tonsquare"]=13095,
    ["topatakthai"]=3599,
    ["tortoiseshellbracketleft"]=12308,
    ["tortoiseshellbracketleftsmall"]=65117,
    ["tortoiseshellbracketleftvertical"]=65081,
    ["tortoiseshellbracketright"]=12309,
    ["tortoiseshellbracketrightsmall"]=65118,
    ["tortoiseshellbracketrightvertical"]=65082,
    ["totaothai"]=3605,
    ["tpalatalhook"]=427,
    ["tparen"]=9391,
    ["trademark"]=8482,
    ["tretroflexhook"]=648,
    ["triagdn"]=9660,
    ["triaglf"]=9668,
    ["triagrt"]=9658,
    ["triagup"]=9650,
    ["ts"]=678,
    ["tsadidageshhebrew"]=64326,
    ["tsadihebrew"]=1510,
    ["tsecyrillic"]=1094,
    ["tserewidehebrew"]=1461,
    ["tshecyrillic"]=1115,
    ["ttabengali"]=2463,
    ["ttadeva"]=2335,
    ["ttagujarati"]=2719,
    ["ttagurmukhi"]=2591,
    ["tteharabic"]=1657,
    ["ttehfinalarabic"]=64359,
    ["ttehinitialarabic"]=64360,
    ["ttehmedialarabic"]=64361,
    ["tthabengali"]=2464,
    ["tthadeva"]=2336,
    ["tthagujarati"]=2720,
    ["tthagurmukhi"]=2592,
    ["tturned"]=647,
    ["tuhiragana"]=12388,
    ["tukatakana"]=12484,
    ["tukatakanahalfwidth"]=65410,
    ["tusmallhiragana"]=12387,
    ["tusmallkatakana"]=12483,
    ["tusmallkatakanahalfwidth"]=65391,
    ["twelvecircle"]=9323,
    ["twelveparen"]=9343,
    ["twelveperiod"]=9363,
    ["twelveroman"]=8571,
    ["twentycircle"]=9331,
    ["twentyparen"]=9351,
    ["twentyperiod"]=9371,
    ["two"]=50,
    ["twobengali"]=2536,
    ["twocircle"]=9313,
    ["twocircleinversesansserif"]=10123,
    ["twodeva"]=2408,
    ["twodotleader"]=8229,
    ["twodotleadervertical"]=65072,
    ["twogujarati"]=2792,
    ["twogurmukhi"]=2664,
    ["twohackarabic"]=1634,
    ["twohangzhou"]=12322,
    ["twoideographicparen"]=12833,
    ["twoinferior"]=8322,
    ["twomonospace"]=65298,
    ["twonumeratorbengali"]=2549,
    ["twoparen"]=9333,
    ["twoperiod"]=9353,
    ["twopersian"]=1778,
    ["tworoman"]=8561,
    ["twostroke"]=443,
    ["twosuperior"]=178,
    ["twothai"]=3666,
    ["twothirds"]=8532,
    ["u"]=117,
    ["uacute"]=250,
    ["ubar"]=649,
    ["ubengali"]=2441,
    ["ubopomofo"]=12584,
    ["ubreve"]=365,
    ["ucaron"]=468,
    ["ucircle"]=9444,
    ["ucircumflex"]=251,
    ["ucircumflexbelow"]=7799,
    ["ucyrillic"]=1091,
    ["udattadeva"]=2385,
    ["udblgrave"]=533,
    ["udeva"]=2313,
    ["udieresis"]=252,
    ["udieresisacute"]=472,
    ["udieresisbelow"]=7795,
    ["udieresiscaron"]=474,
    ["udieresiscyrillic"]=1265,
    ["udieresisgrave"]=476,
    ["udieresismacron"]=470,
    ["udotbelow"]=7909,
    ["ugrave"]=249,
    ["ugujarati"]=2697,
    ["ugurmukhi"]=2569,
    ["uhiragana"]=12358,
    ["uhookabove"]=7911,
    ["uhorn"]=432,
    ["uhornacute"]=7913,
    ["uhorndotbelow"]=7921,
    ["uhorngrave"]=7915,
    ["uhornhookabove"]=7917,
    ["uhorntilde"]=7919,
    ["uhungarumlaut"]=369,
    ["uhungarumlautcyrillic"]=1267,
    ["uinvertedbreve"]=535,
    ["ukatakana"]=12454,
    ["ukatakanahalfwidth"]=65395,
    ["ukcyrillic"]=1145,
    ["ukorean"]=12636,
    ["umacron"]=363,
    ["umacroncyrillic"]=1263,
    ["umacrondieresis"]=7803,
    ["umatragurmukhi"]=2625,
    ["umonospace"]=65365,
    ["underscore"]=95,
    ["underscoredbl"]=8215,
    ["underscoremonospace"]=65343,
    ["underscorevertical"]=65075,
    ["underscorewavy"]=65103,
    ["union"]=8746,
    ["universal"]=8704,
    ["uogonek"]=371,
    ["uparen"]=9392,
    ["upblock"]=9600,
    ["upperdothebrew"]=1476,
    ["upsilon"]=965,
    ["upsilondieresis"]=971,
    ["upsilondieresistonos"]=944,
    ["upsilonlatin"]=650,
    ["upsilontonos"]=973,
    ["uptackbelowcmb"]=797,
    ["uptackmod"]=724,
    ["uragurmukhi"]=2675,
    ["uring"]=367,
    ["ushortcyrillic"]=1118,
    ["usmallhiragana"]=12357,
    ["usmallkatakana"]=12453,
    ["usmallkatakanahalfwidth"]=65385,
    ["ustraightcyrillic"]=1199,
    ["ustraightstrokecyrillic"]=1201,
    ["utilde"]=361,
    ["utildeacute"]=7801,
    ["utildebelow"]=7797,
    ["uubengali"]=2442,
    ["uudeva"]=2314,
    ["uugujarati"]=2698,
    ["uugurmukhi"]=2570,
    ["uumatragurmukhi"]=2626,
    ["uuvowelsignbengali"]=2498,
    ["uuvowelsigndeva"]=2370,
    ["uuvowelsigngujarati"]=2754,
    ["uvowelsignbengali"]=2497,
    ["uvowelsigndeva"]=2369,
    ["uvowelsigngujarati"]=2753,
    ["v"]=118,
    ["vadeva"]=2357,
    ["vagujarati"]=2741,
    ["vagurmukhi"]=2613,
    ["vakatakana"]=12535,
    ["vavdageshhebrew"]=64309,
    ["vavhebrew"]=1493,
    ["vavholamhebrew"]=64331,
    ["vavvavhebrew"]=1520,
    ["vavyodhebrew"]=1521,
    ["vcircle"]=9445,
    ["vdotbelow"]=7807,
    ["vecyrillic"]=1074,
    ["veharabic"]=1700,
    ["vehfinalarabic"]=64363,
    ["vehinitialarabic"]=64364,
    ["vehmedialarabic"]=64365,
    ["vekatakana"]=12537,
    ["venus"]=9792,
    ["verticalbar"]=124,
    ["verticallineabovecmb"]=781,
    ["verticallinebelowcmb"]=809,
    ["verticallinelowmod"]=716,
    ["verticallinemod"]=712,
    ["vewarmenian"]=1406,
    ["vhook"]=651,
    ["vikatakana"]=12536,
    ["viramabengali"]=2509,
    ["viramadeva"]=2381,
    ["viramagujarati"]=2765,
    ["visargabengali"]=2435,
    ["visargadeva"]=2307,
    ["visargagujarati"]=2691,
    ["vmonospace"]=65366,
    ["voarmenian"]=1400,
    ["voicediterationhiragana"]=12446,
    ["voicediterationkatakana"]=12542,
    ["voicedmarkkana"]=12443,
    ["voicedmarkkanahalfwidth"]=65438,
    ["vokatakana"]=12538,
    ["vparen"]=9393,
    ["vtilde"]=7805,
    ["vturned"]=652,
    ["vuhiragana"]=12436,
    ["vukatakana"]=12532,
    ["w"]=119,
    ["wacute"]=7811,
    ["waekorean"]=12633,
    ["wahiragana"]=12431,
    ["wakatakana"]=12527,
    ["wakatakanahalfwidth"]=65436,
    ["wakorean"]=12632,
    ["wasmallhiragana"]=12430,
    ["wasmallkatakana"]=12526,
    ["wattosquare"]=13143,
    ["wavedash"]=12316,
    ["wavyunderscorevertical"]=65076,
    ["wawarabic"]=1608,
    ["wawfinalarabic"]=65262,
    ["wawhamzaabovearabic"]=1572,
    ["wawhamzaabovefinalarabic"]=65158,
    ["wbsquare"]=13277,
    ["wcircle"]=9446,
    ["wcircumflex"]=373,
    ["wdieresis"]=7813,
    ["wdotaccent"]=7815,
    ["wdotbelow"]=7817,
    ["wehiragana"]=12433,
    ["weierstrass"]=8472,
    ["wekatakana"]=12529,
    ["wekorean"]=12638,
    ["weokorean"]=12637,
    ["wgrave"]=7809,
    ["whitebullet"]=9702,
    ["whitecircle"]=9675,
    ["whitecircleinverse"]=9689,
    ["whitecornerbracketleft"]=12302,
    ["whitecornerbracketleftvertical"]=65091,
    ["whitecornerbracketright"]=12303,
    ["whitecornerbracketrightvertical"]=65092,
    ["whitediamond"]=9671,
    ["whitediamondcontainingblacksmalldiamond"]=9672,
    ["whitedownpointingsmalltriangle"]=9663,
    ["whitedownpointingtriangle"]=9661,
    ["whiteleftpointingsmalltriangle"]=9667,
    ["whiteleftpointingtriangle"]=9665,
    ["whitelenticularbracketleft"]=12310,
    ["whitelenticularbracketright"]=12311,
    ["whiterightpointingsmalltriangle"]=9657,
    ["whiterightpointingtriangle"]=9655,
    ["whitesmallsquare"]=9643,
    ["whitesmilingface"]=9786,
    ["whitesquare"]=9633,
    ["whitestar"]=9734,
    ["whitetelephone"]=9743,
    ["whitetortoiseshellbracketleft"]=12312,
    ["whitetortoiseshellbracketright"]=12313,
    ["whiteuppointingsmalltriangle"]=9653,
    ["whiteuppointingtriangle"]=9651,
    ["wihiragana"]=12432,
    ["wikatakana"]=12528,
    ["wikorean"]=12639,
    ["wmonospace"]=65367,
    ["wohiragana"]=12434,
    ["wokatakana"]=12530,
    ["wokatakanahalfwidth"]=65382,
    ["won"]=8361,
    ["wonmonospace"]=65510,
    ["wowaenthai"]=3623,
    ["wparen"]=9394,
    ["wring"]=7832,
    ["wsuperior"]=695,
    ["wturned"]=653,
    ["wynn"]=447,
    ["x"]=120,
    ["xabovecmb"]=829,
    ["xbopomofo"]=12562,
    ["xcircle"]=9447,
    ["xdieresis"]=7821,
    ["xdotaccent"]=7819,
    ["xeharmenian"]=1389,
    ["xi"]=958,
    ["xmonospace"]=65368,
    ["xparen"]=9395,
    ["xsuperior"]=739,
    ["y"]=121,
    ["yaadosquare"]=13134,
    ["yabengali"]=2479,
    ["yacute"]=253,
    ["yadeva"]=2351,
    ["yaekorean"]=12626,
    ["yagujarati"]=2735,
    ["yagurmukhi"]=2607,
    ["yahiragana"]=12420,
    ["yakatakana"]=12516,
    ["yakatakanahalfwidth"]=65428,
    ["yakorean"]=12625,
    ["yamakkanthai"]=3662,
    ["yasmallhiragana"]=12419,
    ["yasmallkatakana"]=12515,
    ["yasmallkatakanahalfwidth"]=65388,
    ["yatcyrillic"]=1123,
    ["ycircle"]=9448,
    ["ycircumflex"]=375,
    ["ydieresis"]=255,
    ["ydotaccent"]=7823,
    ["ydotbelow"]=7925,
    ["yeharabic"]=1610,
    ["yehbarreearabic"]=1746,
    ["yehbarreefinalarabic"]=64431,
    ["yehfinalarabic"]=65266,
    ["yehhamzaabovearabic"]=1574,
    ["yehhamzaabovefinalarabic"]=65162,
    ["yehhamzaaboveinitialarabic"]=65163,
    ["yehhamzaabovemedialarabic"]=65164,
    ["yehinitialarabic"]=65267,
    ["yehmedialarabic"]=65268,
    ["yehmeeminitialarabic"]=64733,
    ["yehmeemisolatedarabic"]=64600,
    ["yehnoonfinalarabic"]=64660,
    ["yehthreedotsbelowarabic"]=1745,
    ["yekorean"]=12630,
    ["yen"]=165,
    ["yenmonospace"]=65509,
    ["yeokorean"]=12629,
    ["yeorinhieuhkorean"]=12678,
    ["yerahbenyomolefthebrew"]=1450,
    ["yericyrillic"]=1099,
    ["yerudieresiscyrillic"]=1273,
    ["yesieungkorean"]=12673,
    ["yesieungpansioskorean"]=12675,
    ["yesieungsioskorean"]=12674,
    ["yetivhebrew"]=1434,
    ["ygrave"]=7923,
    ["yhook"]=436,
    ["yhookabove"]=7927,
    ["yiarmenian"]=1397,
    ["yicyrillic"]=1111,
    ["yikorean"]=12642,
    ["yinyang"]=9775,
    ["yiwnarmenian"]=1410,
    ["ymonospace"]=65369,
    ["yoddageshhebrew"]=64313,
    ["yodhebrew"]=1497,
    ["yodyodhebrew"]=1522,
    ["yodyodpatahhebrew"]=64287,
    ["yohiragana"]=12424,
    ["yoikorean"]=12681,
    ["yokatakana"]=12520,
    ["yokatakanahalfwidth"]=65430,
    ["yokorean"]=12635,
    ["yosmallhiragana"]=12423,
    ["yosmallkatakana"]=12519,
    ["yosmallkatakanahalfwidth"]=65390,
    ["yotgreek"]=1011,
    ["yoyaekorean"]=12680,
    ["yoyakorean"]=12679,
    ["yoyakthai"]=3618,
    ["yoyingthai"]=3597,
    ["yparen"]=9396,
    ["ypogegrammeni"]=890,
    ["ypogegrammenigreekcmb"]=837,
    ["yr"]=422,
    ["yring"]=7833,
    ["ysuperior"]=696,
    ["ytilde"]=7929,
    ["yturned"]=654,
    ["yuhiragana"]=12422,
    ["yuikorean"]=12684,
    ["yukatakana"]=12518,
    ["yukatakanahalfwidth"]=65429,
    ["yukorean"]=12640,
    ["yusbigcyrillic"]=1131,
    ["yusbigiotifiedcyrillic"]=1133,
    ["yuslittlecyrillic"]=1127,
    ["yuslittleiotifiedcyrillic"]=1129,
    ["yusmallhiragana"]=12421,
    ["yusmallkatakana"]=12517,
    ["yusmallkatakanahalfwidth"]=65389,
    ["yuyekorean"]=12683,
    ["yuyeokorean"]=12682,
    ["yyabengali"]=2527,
    ["yyadeva"]=2399,
    ["z"]=122,
    ["zaarmenian"]=1382,
    ["zacute"]=378,
    ["zadeva"]=2395,
    ["zagurmukhi"]=2651,
    ["zaharabic"]=1592,
    ["zahfinalarabic"]=65222,
    ["zahinitialarabic"]=65223,
    ["zahiragana"]=12374,
    ["zahmedialarabic"]=65224,
    ["zainarabic"]=1586,
    ["zainfinalarabic"]=65200,
    ["zakatakana"]=12470,
    ["zaqefgadolhebrew"]=1429,
    ["zaqefqatanhebrew"]=1428,
    ["zarqahebrew"]=1432,
    ["zayindageshhebrew"]=64310,
    ["zayinhebrew"]=1494,
    ["zbopomofo"]=12567,
    ["zcaron"]=382,
    ["zcircle"]=9449,
    ["zcircumflex"]=7825,
    ["zcurl"]=657,
    ["zdotaccent"]=380,
    ["zdotbelow"]=7827,
    ["zecyrillic"]=1079,
    ["zedescendercyrillic"]=1177,
    ["zedieresiscyrillic"]=1247,
    ["zehiragana"]=12380,
    ["zekatakana"]=12476,
    ["zero"]=48,
    ["zerobengali"]=2534,
    ["zerodeva"]=2406,
    ["zerogujarati"]=2790,
    ["zerogurmukhi"]=2662,
    ["zerohackarabic"]=1632,
    ["zeroinferior"]=8320,
    ["zeromonospace"]=65296,
    ["zeropersian"]=1776,
    ["zerosuperior"]=8304,
    ["zerothai"]=3664,
    ["zerowidthjoiner"]=65279,
    ["zerowidthnonjoiner"]=8204,
    ["zerowidthspace"]=8203,
    ["zeta"]=950,
    ["zhbopomofo"]=12563,
    ["zhearmenian"]=1386,
    ["zhebrevecyrillic"]=1218,
    ["zhecyrillic"]=1078,
    ["zhedescendercyrillic"]=1175,
    ["zhedieresiscyrillic"]=1245,
    ["zihiragana"]=12376,
    ["zikatakana"]=12472,
    ["zinorhebrew"]=1454,
    ["zlinebelow"]=7829,
    ["zmonospace"]=65370,
    ["zohiragana"]=12382,
    ["zokatakana"]=12478,
    ["zparen"]=9397,
    ["zretroflexhook"]=656,
    ["zstroke"]=438,
    ["zuhiragana"]=12378,
    ["zukatakana"]=12474,

    -- extras

    ["Dcroat"]=272,
    ["Delta"]=8710,
    ["Euro"]=8364,
    ["H18533"]=9679,
    ["H18543"]=9642,
    ["H18551"]=9643,
    ["H22073"]=9633,
    ["Ldot"]=319,
    ["Oslashacute"]=510,
    ["SF10000"]=9484,
    ["SF20000"]=9492,
    ["SF30000"]=9488,
    ["SF40000"]=9496,
    ["SF50000"]=9532,
    ["SF60000"]=9516,
    ["SF70000"]=9524,
    ["SF80000"]=9500,
    ["SF90000"]=9508,
    ["Upsilon1"]=978,
    ["afii10066"]=1073,
    ["afii10067"]=1074,
    ["afii10068"]=1075,
    ["afii10069"]=1076,
    ["afii10070"]=1077,
    ["afii10071"]=1105,
    ["afii10072"]=1078,
    ["afii10073"]=1079,
    ["afii10074"]=1080,
    ["afii10075"]=1081,
    ["afii10076"]=1082,
    ["afii10077"]=1083,
    ["afii10078"]=1084,
    ["afii10079"]=1085,
    ["afii10080"]=1086,
    ["afii10081"]=1087,
    ["afii10082"]=1088,
    ["afii10083"]=1089,
    ["afii10084"]=1090,
    ["afii10085"]=1091,
    ["afii10086"]=1092,
    ["afii10087"]=1093,
    ["afii10088"]=1094,
    ["afii10089"]=1095,
    ["afii10090"]=1096,
    ["afii10091"]=1097,
    ["afii10092"]=1098,
    ["afii10093"]=1099,
    ["afii10094"]=1100,
    ["afii10095"]=1101,
    ["afii10096"]=1102,
    ["afii10097"]=1103,
    ["afii10098"]=1169,
    ["afii10099"]=1106,
    ["afii10100"]=1107,
    ["afii10101"]=1108,
    ["afii10102"]=1109,
    ["afii10103"]=1110,
    ["afii10104"]=1111,
    ["afii10105"]=1112,
    ["afii10106"]=1113,
    ["afii10107"]=1114,
    ["afii10108"]=1115,
    ["afii10109"]=1116,
    ["afii10110"]=1118,
    ["afii10193"]=1119,
    ["afii10194"]=1123,
    ["afii10195"]=1139,
    ["afii10196"]=1141,
    ["afii10846"]=1241,
    ["afii208"]=8213,
    ["afii57381"]=1642,
    ["afii57388"]=1548,
    ["afii57392"]=1632,
    ["afii57393"]=1633,
    ["afii57394"]=1634,
    ["afii57395"]=1635,
    ["afii57396"]=1636,
    ["afii57397"]=1637,
    ["afii57398"]=1638,
    ["afii57399"]=1639,
    ["afii57400"]=1640,
    ["afii57401"]=1641,
    ["afii57403"]=1563,
    ["afii57407"]=1567,
    ["afii57409"]=1569,
    ["afii57410"]=1570,
    ["afii57411"]=1571,
    ["afii57412"]=1572,
    ["afii57413"]=1573,
    ["afii57414"]=1574,
    ["afii57415"]=1575,
    ["afii57416"]=1576,
    ["afii57417"]=1577,
    ["afii57418"]=1578,
    ["afii57419"]=1579,
    ["afii57420"]=1580,
    ["afii57421"]=1581,
    ["afii57422"]=1582,
    ["afii57423"]=1583,
    ["afii57424"]=1584,
    ["afii57425"]=1585,
    ["afii57426"]=1586,
    ["afii57427"]=1587,
    ["afii57428"]=1588,
    ["afii57429"]=1589,
    ["afii57430"]=1590,
    ["afii57431"]=1591,
    ["afii57432"]=1592,
    ["afii57433"]=1593,
    ["afii57434"]=1594,
    ["afii57440"]=1600,
    ["afii57441"]=1601,
    ["afii57442"]=1602,
    ["afii57443"]=1603,
    ["afii57444"]=1604,
    ["afii57445"]=1605,
    ["afii57446"]=1606,
    ["afii57448"]=1608,
    ["afii57449"]=1609,
    ["afii57450"]=1610,
    ["afii57451"]=1611,
    ["afii57452"]=1612,
    ["afii57453"]=1613,
    ["afii57454"]=1614,
    ["afii57455"]=1615,
    ["afii57456"]=1616,
    ["afii57457"]=1617,
    ["afii57458"]=1618,
    ["afii57470"]=1607,
    ["afii57505"]=1700,
    ["afii57506"]=1662,
    ["afii57507"]=1670,
    ["afii57508"]=1688,
    ["afii57509"]=1711,
    ["afii57511"]=1657,
    ["afii57512"]=1672,
    ["afii57513"]=1681,
    ["afii57514"]=1722,
    ["afii57519"]=1746,
    ["afii57636"]=8362,
    ["afii57645"]=1470,
    ["afii57658"]=1475,
    ["afii57664"]=1488,
    ["afii57665"]=1489,
    ["afii57666"]=1490,
    ["afii57667"]=1491,
    ["afii57668"]=1492,
    ["afii57669"]=1493,
    ["afii57670"]=1494,
    ["afii57671"]=1495,
    ["afii57672"]=1496,
    ["afii57673"]=1497,
    ["afii57674"]=1498,
    ["afii57675"]=1499,
    ["afii57676"]=1500,
    ["afii57677"]=1501,
    ["afii57678"]=1502,
    ["afii57679"]=1503,
    ["afii57680"]=1504,
    ["afii57681"]=1505,
    ["afii57682"]=1506,
    ["afii57683"]=1507,
    ["afii57684"]=1508,
    ["afii57685"]=1509,
    ["afii57686"]=1510,
    ["afii57687"]=1511,
    ["afii57688"]=1512,
    ["afii57689"]=1513,
    ["afii57690"]=1514,
    ["afii57716"]=1520,
    ["afii57717"]=1521,
    ["afii57718"]=1522,
    ["afii57793"]=1460,
    ["afii57794"]=1461,
    ["afii57795"]=1462,
    ["afii57796"]=1467,
    ["afii57797"]=1464,
    ["afii57798"]=1463,
    ["afii57799"]=1456,
    ["afii57800"]=1458,
    ["afii57801"]=1457,
    ["afii57802"]=1459,
    ["afii57803"]=1474,
    ["afii57804"]=1473,
    ["afii57806"]=1465,
    ["afii57807"]=1468,
    ["afii57839"]=1469,
    ["afii57841"]=1471,
    ["afii57842"]=1472,
    ["afii57929"]=700,
    ["afii61248"]=8453,
    ["afii61289"]=8467,
    ["afii61352"]=8470,
    ["afii61664"]=8204,
    ["afii63167"]=1645,
    ["afii64937"]=701,
    ["arrowdblboth"]=8660,
    ["arrowdblleft"]=8656,
    ["arrowdblright"]=8658,
    ["arrowupdnbse"]=8616,
    ["bar"]=124,
    ["circle"]=9675,
    ["circlemultiply"]=8855,
    ["circleplus"]=8853,
    ["club"]=9827,
    ["colonmonetary"]=8353,
    ["dcroat"]=273,
    ["dkshade"]=9619,
    ["existential"]=8707,
    ["female"]=9792,
    ["gradient"]=8711,
    ["heart"]=9829,
    ["hookabovecomb"]=777,
    ["invcircle"]=9689,
    ["ldot"]=320,
    ["longs"]=383,
    ["ltshade"]=9617,
    ["male"]=9794,
    ["mu"]=181,
    ["napostrophe"]=329,
    ["notelement"]=8713,
    ["omega1"]=982,
    ["openbullet"]=9702,
    ["orthogonal"]=8735,
    ["oslashacute"]=511,
    ["phi1"]=981,
    ["propersubset"]=8834,
    ["propersuperset"]=8835,
    ["reflexsubset"]=8838,
    ["reflexsuperset"]=8839,
    ["shade"]=9618,
    ["sigma1"]=962,
    ["similar"]=8764,
    ["smileface"]=9786,
    ["spacehackarabic"]=32,
    ["spade"]=9824,
    ["theta1"]=977,
    ["twodotenleader"]=8229,
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-def'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local format, gmatch, match, find, lower, gsub = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub
local tostring, next = tostring, next
local lpegmatch = lpeg.match

local allocate = utilities.storage.allocate

local trace_defining     = false  trackers  .register("fonts.defining", function(v) trace_defining     = v end)
local directive_embedall = false  directives.register("fonts.embedall", function(v) directive_embedall = v end)

trackers.register("fonts.loading", "fonts.defining", "otf.loading", "afm.loading", "tfm.loading")
trackers.register("fonts.all", "fonts.*", "otf.*", "afm.*", "tfm.*")

local report_defining = logs.reporter("fonts","defining")

--[[ldx--
<p>Here we deal with defining fonts. We do so by intercepting the
default loader that only handles <l n='tfm'/>.</p>
--ldx]]--

local fonts         = fonts
local tfm           = fonts.tfm
local vf            = fonts.vf

fonts.used          = allocate()

tfm.readers         = tfm.readers or { }
tfm.fonts           = allocate()

local readers       = tfm.readers
local sequence      = allocate { 'otf', 'ttf', 'afm', 'tfm', 'lua' }
readers.sequence    = sequence

tfm.version         = 1.01
tfm.cache           = containers.define("fonts", "tfm", tfm.version, false) -- better in font-tfm
tfm.autoprefixedafm = true -- this will become false some day (catches texnansi-blabla.*)

fonts.definers      = fonts.definers or { }
local definers      = fonts.definers

definers.specifiers = definers.specifiers or { }
local specifiers    = definers.specifiers

specifiers.variants = allocate()
local variants      = specifiers.variants

definers.method     = "afm or tfm" -- afm, tfm, afm or tfm, tfm or afm
definers.methods    = definers.methods or { }

local findbinfile   = resolvers.findbinfile

--[[ldx--
<p>We hardly gain anything when we cache the final (pre scaled)
<l n='tfm'/> table. But it can be handy for debugging.</p>
--ldx]]--

fonts.version = 1.05
fonts.cache   = containers.define("fonts", "def", fonts.version, false)

--[[ldx--
<p>We can prefix a font specification by <type>name:</type> or
<type>file:</type>. The first case will result in a lookup in the
synonym table.</p>

<typing>
[ name: | file: ] identifier [ separator [ specification ] ]
</typing>

<p>The following function split the font specification into components
and prepares a table that will move along as we proceed.</p>
--ldx]]--

-- beware, we discard additional specs
--
-- method:name method:name(sub) method:name(sub)*spec method:name*spec
-- name name(sub) name(sub)*spec name*spec
-- name@spec*oeps

local splitter, splitspecifiers = nil, ""

local P, C, S, Cc = lpeg.P, lpeg.C, lpeg.S, lpeg.Cc

local left  = P("(")
local right = P(")")
local colon = P(":")
local space = P(" ")

definers.defaultlookup = "file"

local prefixpattern  = P(false)

local function addspecifier(symbol)
    splitspecifiers     = splitspecifiers .. symbol
    local method        = S(splitspecifiers)
    local lookup        = C(prefixpattern) * colon
    local sub           = left * C(P(1-left-right-method)^1) * right
    local specification = C(method) * C(P(1)^1)
    local name          = C((1-sub-specification)^1)
    splitter = P((lookup + Cc("")) * name * (sub + Cc("")) * (specification + Cc("")))
end

local function addlookup(str,default)
    prefixpattern = prefixpattern + P(str)
end

definers.addlookup = addlookup

addlookup("file")
addlookup("name")
addlookup("spec")

local function getspecification(str)
    return lpegmatch(splitter,str)
end

definers.getspecification = getspecification

function definers.registersplit(symbol,action,verbosename)
    addspecifier(symbol)
    variants[symbol] = action
    if verbosename then
        variants[verbosename] = action
    end
end

function definers.makespecification(specification, lookup, name, sub, method, detail, size)
    size = size or 655360
    if trace_defining then
        report_defining("%s -> lookup: %s, name: %s, sub: %s, method: %s, detail: %s",
            specification, (lookup ~= "" and lookup) or "[file]", (name ~= "" and name) or "-",
            (sub ~= "" and sub) or "-", (method ~= "" and method) or "-", (detail ~= "" and detail) or "-")
    end
    if not lookup or lookup == "" then
        lookup = definers.defaultlookup
    end
    local t = {
        lookup        = lookup,        -- forced type
        specification = specification, -- full specification
        size          = size,          -- size in scaled points or -1000*n
        name          = name,          -- font or filename
        sub           = sub,           -- subfont (eg in ttc)
        method        = method,        -- specification method
        detail        = detail,        -- specification
        resolved      = "",            -- resolved font name
        forced        = "",            -- forced loader
        features      = { },           -- preprocessed features
    }
    return t
end

function definers.analyze(specification, size)
    -- can be optimized with locals
    local lookup, name, sub, method, detail = getspecification(specification or "")
    return definers.makespecification(specification, lookup, name, sub, method, detail, size)
end

--[[ldx--
<p>A unique hash value is generated by:</p>
--ldx]]--

local sortedhashkeys = table.sortedhashkeys

function tfm.hashfeatures(specification)
    local features = specification.features
    if features then
        local t, tn = { }, 0
        local normal = features.normal
        if normal and next(normal) then
            local f = sortedhashkeys(normal)
            for i=1,#f do
                local v = f[i]
                if v ~= "number" and v ~= "features" then -- i need to figure this out, features
                    tn = tn + 1
                    t[tn] = v .. '=' .. tostring(normal[v])
                end
            end
        end
        local vtf = features.vtf
        if vtf and next(vtf) then
            local f = sortedhashkeys(vtf)
            for i=1,#f do
                local v = f[i]
                tn = tn + 1
                t[tn] = v .. '=' .. tostring(vtf[v])
            end
        end
     -- if specification.mathsize then
     --     tn = tn + 1
     --     t[tn] = "mathsize=" .. specification.mathsize
     -- end
        if tn > 0 then
            return concat(t,"+")
        end
    end
    return "unknown"
end

fonts.designsizes = allocate()

--[[ldx--
<p>In principle we can share tfm tables when we are in node for a font, but then
we need to define a font switch as an id/attr switch which is no fun, so in that
case users can best use dynamic features ... so, we will not use that speedup. Okay,
when we get rid of base mode we can optimize even further by sharing, but then we
loose our testcases for <l n='luatex'/>.</p>
--ldx]]--

function tfm.hashinstance(specification,force)
    local hash, size, fallbacks = specification.hash, specification.size, specification.fallbacks
    if force or not hash then
        hash = tfm.hashfeatures(specification)
        specification.hash = hash
    end
    if size < 1000 and fonts.designsizes[hash] then
        size = math.round(tfm.scaled(size,fonts.designsizes[hash]))
        specification.size = size
    end
 -- local mathsize = specification.mathsize or 0
 -- if mathsize > 0 then
 --     local textsize = specification.textsize
 --     if fallbacks then
 --         return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ] @ ' .. fallbacks
 --     else
 --         return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ]'
 --     end
 -- else
        if fallbacks then
            return hash .. ' @ ' .. tostring(size) .. ' @ ' .. fallbacks
        else
            return hash .. ' @ ' .. tostring(size)
        end
 -- end
end

--[[ldx--
<p>We can resolve the filename using the next function:</p>
--ldx]]--

definers.resolvers = definers.resolvers or { }
local resolvers    = definers.resolvers

-- todo: reporter

function resolvers.file(specification)
    local suffix = file.suffix(specification.name)
    if fonts.formats[suffix] then
        specification.forced = suffix
        specification.name = file.removesuffix(specification.name)
    end
end

function resolvers.name(specification)
    local resolve = fonts.names.resolve
    if resolve then
        local resolved, sub = fonts.names.resolve(specification.name,specification.sub)
        specification.resolved, specification.sub = resolved, sub
        if resolved then
            local suffix = file.suffix(resolved)
            if fonts.formats[suffix] then
                specification.forced = suffix
                specification.name = file.removesuffix(resolved)
            else
                specification.name = resolved
            end
        end
    else
        resolvers.file(specification)
    end
end

function resolvers.spec(specification)
    local resolvespec = fonts.names.resolvespec
    if resolvespec then
        specification.resolved, specification.sub = fonts.names.resolvespec(specification.name,specification.sub)
        if specification.resolved then
            specification.forced = file.extname(specification.resolved)
            specification.name = file.removesuffix(specification.resolved)
        end
    else
        resolvers.name(specification)
    end
end

function definers.resolve(specification)
    if not specification.resolved or specification.resolved == "" then -- resolved itself not per se in mapping hash
        local r = resolvers[specification.lookup]
        if r then
            r(specification)
        end
    end
    if specification.forced == "" then
        specification.forced = nil
    else
        specification.forced = specification.forced
    end
    -- for the moment here (goodies set outside features)
    local goodies = specification.goodies
    if goodies and goodies ~= "" then
        local normalgoodies = specification.features.normal.goodies
        if not normalgoodies or normalgoodies == "" then
            specification.features.normal.goodies = goodies
        end
    end
    --
    specification.hash = lower(specification.name .. ' @ ' .. tfm.hashfeatures(specification))
    if specification.sub and specification.sub ~= "" then
        specification.hash = specification.sub .. ' @ ' .. specification.hash
    end
    return specification
end

--[[ldx--
<p>The main read function either uses a forced reader (as determined by
a lookup) or tries to resolve the name using the list of readers.</p>

<p>We need to cache when possible. We do cache raw tfm data (from <l
n='tfm'/>, <l n='afm'/> or <l n='otf'/>). After that we can cache based
on specificstion (name) and size, that is, <l n='tex'/> only needs a number
for an already loaded fonts. However, it may make sense to cache fonts
before they're scaled as well (store <l n='tfm'/>'s with applied methods
and features). However, there may be a relation between the size and
features (esp in virtual fonts) so let's not do that now.</p>

<p>Watch out, here we do load a font, but we don't prepare the
specification yet.</p>
--ldx]]--

function tfm.read(specification)
    local hash = tfm.hashinstance(specification)
    local tfmtable = tfm.fonts[hash] -- hashes by size !
    if not tfmtable then
        local forced = specification.forced or ""
        if forced ~= "" then
            local reader = readers[lower(forced)]
            tfmtable = reader and reader(specification)
            if not tfmtable then
                report_defining("forced type %s of %s not found",forced,specification.name)
            end
        else
            for s=1,#sequence do -- reader sequence
                local reader = sequence[s]
                if readers[reader] then -- not really needed
                    if trace_defining then
                        report_defining("trying (reader sequence driven) type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
                    end
                    tfmtable = readers[reader](specification)
                    if tfmtable then
                        break
                    else
                        specification.filename = nil
                    end
                end
            end
        end
        if tfmtable then
            if directive_embedall then
                tfmtable.embedding = "full"
            elseif tfmtable.filename and fonts.dontembed[tfmtable.filename] then
                tfmtable.embedding = "no"
            else
                tfmtable.embedding = "subset"
            end
            -- fonts.goodies.postprocessors.apply(tfmdata) -- only here
            local postprocessors = tfmtable.postprocessors
            if postprocessors then
                for i=1,#postprocessors do
                    local extrahash = postprocessors[i](tfmtable) -- after scaling etc
                    if type(extrahash) == "string" and extrahash ~= "" then
                        -- e.g. a reencoding needs this
                        extrahash = gsub(lower(extrahash),"[^a-z]","-")
                        tfmtable.fullname = format("%s-%s",tfmtable.fullname,extrahash)
                    end
                end
            end
            --
            tfm.fonts[hash] = tfmtable
            fonts.designsizes[specification.hash] = tfmtable.designsize -- we only know this for sure after loading once
        --~ tfmtable.mode = specification.features.normal.mode or "base"
        end
    end
    if not tfmtable then
        report_defining("font with asked name '%s' is not found using lookup '%s'",specification.name,specification.lookup)
    end
    return tfmtable
end

--[[ldx--
<p>For virtual fonts we need a slightly different approach:</p>
--ldx]]--

function tfm.readanddefine(name,size) -- no id
    local specification = definers.analyze(name,size)
    local method = specification.method
    if method and variants[method] then
        specification = variants[method](specification)
    end
    specification = definers.resolve(specification)
    local hash = tfm.hashinstance(specification)
    local id = definers.registered(hash)
    if not id then
        local tfmdata = tfm.read(specification)
        if tfmdata then
            tfmdata.hash = hash
            id = font.define(tfmdata)
            definers.register(tfmdata,id)
            tfm.cleanuptable(tfmdata)
        else
            id = 0  -- signal
        end
    end
    return fonts.identifiers[id], id
end

--[[ldx--
<p>We need to check for default features. For this we provide
a helper function.</p>
--ldx]]--

function definers.check(features,defaults) -- nb adapts features !
    local done = false
    if features and next(features) then
        for k,v in next, defaults do
            if features[k] == nil then
                features[k], done = v, true
            end
        end
    else
        features, done = table.fastcopy(defaults), true
    end
    return features, done -- done signals a change
end

--[[ldx--
<p>So far the specifiers. Now comes the real definer. Here we cache
based on id's. Here we also intercept the virtual font handler. Since
it evolved stepwise I may rewrite this bit (combine code).</p>

In the previously defined reader (the one resulting in a <l n='tfm'/>
table) we cached the (scaled) instances. Here we cache them again, but
this time based on id. We could combine this in one cache but this does
not gain much. By the way, passing id's back to in the callback was
introduced later in the development.</p>
--ldx]]--

local lastdefined  = nil -- we don't want this one to end up in s-tra-02
local internalized = { }

function definers.current() -- or maybe current
    return lastdefined
end

function definers.register(tfmdata,id) -- will be overloaded
    if tfmdata and id then
        local hash = tfmdata.hash
        if not internalized[hash] then
            if trace_defining then
                report_defining("registering font, id: %s, hash: %s",id or "?",hash or "?")
            end
            fonts.identifiers[id] = tfmdata
            internalized[hash] = id
        end
    end
end

function definers.registered(hash) -- will be overloaded
    local id = internalized[hash]
    return id, id and fonts.identifiers[id]
end

local cache_them = false

function tfm.make(specification)
    -- currently fonts are scaled while constructing the font, so we
    -- have to do scaling of commands in the vf at that point using
    -- e.g. "local scale = g.factor or 1" after all, we need to work
    -- with copies anyway and scaling needs to be done at some point;
    -- however, when virtual tricks are used as feature (makes more
    -- sense) we scale the commands in fonts.tfm.scale (and set the
    -- factor there)
    local fvm = definers.methods.variants[specification.features.vtf.preset]
    if fvm then
        return fvm(specification)
    else
        return nil
    end
end

function definers.read(specification,size,id) -- id can be optional, name can already be table
    statistics.starttiming(fonts)
    if type(specification) == "string" then
        specification = definers.analyze(specification,size)
    end
    local method = specification.method
    if method and variants[method] then
        specification = variants[method](specification)
    end
    specification = definers.resolve(specification)
    local hash = tfm.hashinstance(specification)
    if cache_them then
        local tfmdata = containers.read(fonts.cache,hash) -- for tracing purposes
    end
    local tfmdata = definers.registered(hash) -- id
    if not tfmdata then
        if specification.features.vtf and specification.features.vtf.preset then
            tfmdata = tfm.make(specification)
        else
            tfmdata = tfm.read(specification)
            if tfmdata then
                tfm.checkvirtualid(tfmdata)
            end
        end
        if cache_them then
            tfmdata = containers.write(fonts.cache,hash,tfmdata) -- for tracing purposes
        end
        if tfmdata then
            tfmdata.hash = hash
            tfmdata.cache = "no"
            if id then
                definers.register(tfmdata,id)
            end
        end
    end
    lastdefined = tfmdata or id -- todo ! ! ! ! !
    if not tfmdata then -- or id?
        report_defining( "unknown font %s, loading aborted",specification.name)
    elseif trace_defining and type(tfmdata) == "table" then
        report_defining("using %s font with id %s, name:%s size:%s bytes:%s encoding:%s fullname:%s filename:%s",
            tfmdata.type          or "unknown",
            id                    or "?",
            tfmdata.name          or "?",
            tfmdata.size          or "default",
            tfmdata.encodingbytes or "?",
            tfmdata.encodingname  or "unicode",
            tfmdata.fullname      or "?",
            file.basename(tfmdata.filename or "?"))
    end
    statistics.stoptiming(fonts)
    return tfmdata
end

function vf.find(name)
    name = file.removesuffix(file.basename(name))
    if tfm.resolvevirtualtoo then
        local format = fonts.logger.format(name)
        if format == 'tfm' or format == 'ofm' then
            if trace_defining then
                report_defining("locating vf for %s",name)
            end
            return findbinfile(name,"ovf")
        else
            if trace_defining then
                report_defining("vf for %s is already taken care of",name)
            end
            return nil -- ""
        end
    else
        if trace_defining then
            report_defining("locating vf for %s",name)
        end
        return findbinfile(name,"ovf")
    end
end

--[[ldx--
<p>We overload both the <l n='tfm'/> and <l n='vf'/> readers.</p>
--ldx]]--

callbacks.register('define_font' , definers.read, "definition of fonts (tfmtable preparation)")
callbacks.register('find_vf_file', vf.find,       "locating virtual fonts, insofar needed") -- not that relevant any more

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-xtx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, count = tex.sprint, tex.count
local format, concat, gmatch, match, find, lower = string.format, table.concat, string.gmatch, string.match, string.find, string.lower
local tostring, next = tostring, next
local lpegmatch = lpeg.match

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

--[[ldx--
<p>Choosing a font by name and specififying its size is only part of the
game. In order to prevent complex commands, <l n='xetex'/> introduced
a method to pass feature information as part of the font name. At the
risk of introducing nasty parsing and compatinility problems, this
syntax was expanded over time.</p>

<p>For the sake of users who have defined fonts using that syntax, we
will support it, but we will provide additional methods as well.
Normally users will not use this direct way, but use a more abstract
interface.</p>

<p>The next one is the official one. However, in the plain
variant we need to support the crappy [] specification as
well and that does not work too well with the general design
of the specifier.</p>
--ldx]]--

local fonts              = fonts
local definers           = fonts.definers
local specifiers         = definers.specifiers
local normalize_meanings = fonts.otf.meanings.normalize

local list = { }

specifiers.colonizedpreference = "file"

local function issome ()    list.lookup = specifiers.colonizedpreference end
local function isfile ()    list.lookup = 'file' end
local function isname ()    list.lookup = 'name' end
local function thename(s)   list.name   = s end
local function issub  (v)   list.sub    = v end
local function iscrap (s)   list.crap   = string.lower(s) end
local function istrue (s)   list[s]     = 'yes' end
local function isfalse(s)   list[s]     = 'no' end
local function iskey  (k,v) list[k]     = v end

local function istrue (s)   list[s]     = true end
local function isfalse(s)   list[s]     = false end

local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C

local spaces     = P(" ")^0
local namespec   = (1-S("/:("))^0 -- was: (1-S("/: ("))^0
local crapspec   = spaces * P("/") * (((1-P(":"))^0)/iscrap) * spaces
local filename   = (P("file:")/isfile * (namespec/thename)) + (P("[") * P(true)/isname * (((1-P("]"))^0)/thename) * P("]"))
local fontname   = (P("name:")/isname * (namespec/thename)) + P(true)/issome * (namespec/thename)
local sometext   = (R("az","AZ","09") + S("+-."))^1
local truevalue  = P("+") * spaces * (sometext/istrue)
local falsevalue = P("-") * spaces * (sometext/isfalse)
local keyvalue   = (C(sometext) * spaces * P("=") * spaces * C(sometext))/iskey
local somevalue  = sometext/istrue
local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
local option     = spaces * (keyvalue + falsevalue + truevalue + somevalue) * spaces
local options    = P(":") * spaces * (P(";")^0  * option)^0
local pattern    = (filename + fontname) * subvalue^0 * crapspec^0 * options^0

local function colonized(specification) -- xetex mode
    list = { }
    lpegmatch(pattern,specification.specification)
 -- for k, v in next, list do
 --     list[k] = is_boolean(v)
 --     if type(list[a]) == "nil" then
 --         list[k] = v
 --     end
 -- end
    list.crap = nil -- style not supported, maybe some day
    if list.name then
        specification.name = list.name
        list.name = nil
    end
    if list.lookup then
        specification.lookup = list.lookup
        list.lookup = nil
    end
    if list.sub then
        specification.sub = list.sub
        list.sub = nil
    end
 -- specification.features.normal = list
    specification.features.normal = normalize_meanings(list)
    return specification
end

definers.registersplit(":",colonized,"cryptic")

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts = fonts or { }

-- general

fonts.otf.pack              = false -- only makes sense in context
fonts.tfm.resolvevirtualtoo = false -- context specific (due to resolver)
fonts.tfm.fontnamemode      = "specification" -- somehow latex needs this (changed name!)

-- readers

fonts.tfm.readers          = fonts.tfm.readers or { }
fonts.tfm.readers.sequence = { 'otf', 'ttf', 'tfm', 'lua' }
fonts.tfm.readers.afm      = nil

-- define

fonts.definers            = fonts.definers or { }
fonts.definers.specifiers = fonts.definers.specifiers or { }

fonts.definers.specifiers.colonizedpreference = "name" -- is "file" in context

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

fonts.definers.registersplit("",fonts.definers.specifiers.variants[":"]) -- we add another one for catching lone [names]

-- logger

fonts.logger = fonts.logger or { }

function fonts.logger.save()
end

-- names
--
-- Watch out, the version number is the same as the one used in
-- the mtx-fonts.lua function scripts.fonts.names as we use a
-- simplified font database in the plain solution and by using
-- a different number we're less dependent on context.

fonts.names = fonts.names or { }

fonts.names.version    = 1.001 -- not the same as in context
fonts.names.basename   = "luatex-fonts-names.lua"
fonts.names.new_to_old = { }
fonts.names.old_to_new = { }

local data, loaded = nil, false

local fileformats = { "lua", "tex", "other text files" }

function fonts.names.resolve(name,sub)
    if not loaded then
        local basename = fonts.names.basename
        if basename and basename ~= "" then
            for i=1,#fileformats do
                local format = fileformats[i]
                local foundname = resolvers.findfile(basename,format) or ""
                if foundname ~= "" then
                    data = dofile(foundname)
                    break
                end
            end
        end
        loaded = true
    end
    if type(data) == "table" and data.version == fonts.names.version then
        local condensed = string.gsub(string.lower(name),"[^%a%d]","")
        local found = data.mappings and data.mappings[condensed]
        if found then
            local fontname, filename, subfont = found[1], found[2], found[3]
            if subfont then
                return filename, fontname
            else
                return filename, false
            end
        else
            return name, false -- fallback to filename
        end
    end
end

fonts.names.resolvespec = fonts.names.resolve -- only supported in mkiv

function fonts.names.getfilename(askedname,suffix)  -- only supported in mkiv
    return ""
end

-- For the moment we put this (adapted) pseudo feature here.

table.insert(fonts.triggers,"itlc")

local function itlc(tfmdata,value)
    if value then
        -- the magic 40 and it formula come from Dohyun Kim
        local metadata = tfmdata.shared.otfdata.metadata
        if metadata then
            local italicangle = metadata.italicangle
            if italicangle and italicangle ~= 0 then
                local uwidth = (metadata.uwidth or 40)/2
                for unicode, d in next, tfmdata.descriptions do
                    local it = d.boundingbox[3] - d.width + uwidth
                    if it ~= 0 then
                        d.italic = it
                    end
                end
                tfmdata.has_italic = true
            end
        end
    end
end

fonts.initializers.base.otf.itlc = itlc
fonts.initializers.node.otf.itlc = itlc

-- slant and extend

function fonts.initializers.common.slant(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  1 then
        value =  1
    elseif value < -1 then
        value = -1
    end
    tfmdata.slant_factor = value
end

function fonts.initializers.common.extend(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  10 then
        value =  10
    elseif value < -10 then
        value = -10
    end
    tfmdata.extend_factor = value
end

table.insert(fonts.triggers,"slant")
table.insert(fonts.triggers,"extend")

fonts.initializers.base.otf.slant  = fonts.initializers.common.slant
fonts.initializers.node.otf.slant  = fonts.initializers.common.slant
fonts.initializers.base.otf.extend = fonts.initializers.common.extend
fonts.initializers.node.otf.extend = fonts.initializers.common.extend

-- expansion and protrusion

fonts.protrusions        = fonts.protrusions        or { }
fonts.protrusions.setups = fonts.protrusions.setups or { }

local setups  = fonts.protrusions.setups

function fonts.initializers.common.protrusion(tfmdata,value)
    if value then
        local setup = setups[value]
        if setup then
            local factor, left, right = setup.factor or 1, setup.left or 1, setup.right or 1
            local emwidth = tfmdata.parameters.quad
            tfmdata.auto_protrude = true
            for i, chr in next, tfmdata.characters do
                local v, pl, pr = setup[i], nil, nil
                if v then
                    pl, pr = v[1], v[2]
                end
                if pl and pl ~= 0 then chr.left_protruding  = left *pl*factor end
                if pr and pr ~= 0 then chr.right_protruding = right*pr*factor end
            end
        end
    end
end

fonts.expansions         = fonts.expansions        or { }
fonts.expansions.setups  = fonts.expansions.setups or { }

local setups = fonts.expansions.setups

function fonts.initializers.common.expansion(tfmdata,value)
    if value then
        local setup = setups[value]
        if setup then
            local stretch, shrink, step, factor = setup.stretch or 0, setup.shrink or 0, setup.step or 0, setup.factor or 1
            tfmdata.stretch, tfmdata.shrink, tfmdata.step, tfmdata.auto_expand = stretch * 10, shrink * 10, step * 10, true
            for i, chr in next, tfmdata.characters do
                local v = setup[i]
                if v and v ~= 0 then
                    chr.expansion_factor = v*factor
                else -- can be option
                    chr.expansion_factor = factor
                end
            end
        end
    end
end

table.insert(fonts.manipulators,"protrusion")
table.insert(fonts.manipulators,"expansion")

fonts.initializers.base.otf.protrusion = fonts.initializers.common.protrusion
fonts.initializers.node.otf.protrusion = fonts.initializers.common.protrusion
fonts.initializers.base.otf.expansion  = fonts.initializers.common.expansion
fonts.initializers.node.otf.expansion  = fonts.initializers.common.expansion

-- left over

function fonts.registermessage()
end

-- example vectors

local byte = string.byte

fonts.expansions.setups['default'] = {

    stretch = 2, shrink = 2, step = .5, factor = 1,

    [byte('A')] = 0.5, [byte('B')] = 0.7, [byte('C')] = 0.7, [byte('D')] = 0.5, [byte('E')] = 0.7,
    [byte('F')] = 0.7, [byte('G')] = 0.5, [byte('H')] = 0.7, [byte('K')] = 0.7, [byte('M')] = 0.7,
    [byte('N')] = 0.7, [byte('O')] = 0.5, [byte('P')] = 0.7, [byte('Q')] = 0.5, [byte('R')] = 0.7,
    [byte('S')] = 0.7, [byte('U')] = 0.7, [byte('W')] = 0.7, [byte('Z')] = 0.7,
    [byte('a')] = 0.7, [byte('b')] = 0.7, [byte('c')] = 0.7, [byte('d')] = 0.7, [byte('e')] = 0.7,
    [byte('g')] = 0.7, [byte('h')] = 0.7, [byte('k')] = 0.7, [byte('m')] = 0.7, [byte('n')] = 0.7,
    [byte('o')] = 0.7, [byte('p')] = 0.7, [byte('q')] = 0.7, [byte('s')] = 0.7, [byte('u')] = 0.7,
    [byte('w')] = 0.7, [byte('z')] = 0.7,
    [byte('2')] = 0.7, [byte('3')] = 0.7, [byte('6')] = 0.7, [byte('8')] = 0.7, [byte('9')] = 0.7,
}

fonts.protrusions.setups['default'] = {

    factor = 1, left = 1, right = 1,

    [0x002C] = { 0, 1    }, -- comma
    [0x002E] = { 0, 1    }, -- period
    [0x003A] = { 0, 1    }, -- colon
    [0x003B] = { 0, 1    }, -- semicolon
    [0x002D] = { 0, 1    }, -- hyphen
    [0x2013] = { 0, 0.50 }, -- endash
    [0x2014] = { 0, 0.33 }, -- emdash
    [0x3001] = { 0, 1    }, -- ideographic comma      、
    [0x3002] = { 0, 1    }, -- ideographic full stop  。
    [0x060C] = { 0, 1    }, -- arabic comma           ،
    [0x061B] = { 0, 1    }, -- arabic semicolon       ؛
    [0x06D4] = { 0, 1    }, -- arabic full stop       ۔

}

-- normalizer

fonts.otf.meanings = fonts.otf.meanings or { }

fonts.otf.meanings.normalize = fonts.otf.meanings.normalize or function(t)
    if t.rand then
        t.rand = "random"
    end
end

-- needed (different in context)

function fonts.otf.scriptandlanguage(tfmdata)
    return tfmdata.script, tfmdata.language
end

-- bonus

function fonts.otf.nametoslot(name)
    local tfmdata = fonts.identifiers[font.current()]
    if tfmdata and tfmdata.shared then
        local otfdata = tfmdata.shared.otfdata
        local unicode = otfdata.luatex.unicodes[name]
        return unicode and (type(unicode) == "number" and unicode or unicode[1])
    end
end

function fonts.otf.char(n)
    if type(n) == "string" then
        n = fonts.otf.nametoslot(n)
    end
    if type(n) == "number" then
        tex.sprint("\\char" .. n)
    end
end

-- another one:

fonts.strippables = table.tohash {
    0x000AD, 0x017B4, 0x017B5, 0x0200B, 0x0200C, 0x0200D, 0x0200E, 0x0200F, 0x0202A, 0x0202B,
    0x0202C, 0x0202D, 0x0202E, 0x02060, 0x02061, 0x02062, 0x02063, 0x0206A, 0x0206B, 0x0206C,
    0x0206D, 0x0206E, 0x0206F, 0x0FEFF, 0x1D173, 0x1D174, 0x1D175, 0x1D176, 0x1D177, 0x1D178,
    0x1D179, 0x1D17A, 0xE0001, 0xE0020, 0xE0021, 0xE0022, 0xE0023, 0xE0024, 0xE0025, 0xE0026,
    0xE0027, 0xE0028, 0xE0029, 0xE002A, 0xE002B, 0xE002C, 0xE002D, 0xE002E, 0xE002F, 0xE0030,
    0xE0031, 0xE0032, 0xE0033, 0xE0034, 0xE0035, 0xE0036, 0xE0037, 0xE0038, 0xE0039, 0xE003A,
    0xE003B, 0xE003C, 0xE003D, 0xE003E, 0xE003F, 0xE0040, 0xE0041, 0xE0042, 0xE0043, 0xE0044,
    0xE0045, 0xE0046, 0xE0047, 0xE0048, 0xE0049, 0xE004A, 0xE004B, 0xE004C, 0xE004D, 0xE004E,
    0xE004F, 0xE0050, 0xE0051, 0xE0052, 0xE0053, 0xE0054, 0xE0055, 0xE0056, 0xE0057, 0xE0058,
    0xE0059, 0xE005A, 0xE005B, 0xE005C, 0xE005D, 0xE005E, 0xE005F, 0xE0060, 0xE0061, 0xE0062,
    0xE0063, 0xE0064, 0xE0065, 0xE0066, 0xE0067, 0xE0068, 0xE0069, 0xE006A, 0xE006B, 0xE006C,
    0xE006D, 0xE006E, 0xE006F, 0xE0070, 0xE0071, 0xE0072, 0xE0073, 0xE0074, 0xE0075, 0xE0076,
    0xE0077, 0xE0078, 0xE0079, 0xE007A, 0xE007B, 0xE007C, 0xE007D, 0xE007E, 0xE007F,
}

-- \font\test=file:somefont:reencode=mymessup
--
--  fonts.enc.reencodings.mymessup = {
--      [109] = 110, -- m
--      [110] = 109, -- n
--  }

fonts.enc             = fonts.enc or {}
local reencodings     = { }
fonts.enc.reencodings = reencodings

local function specialreencode(tfmdata,value)
    -- we forget about kerns as we assume symbols and we
    -- could issue a message if ther are kerns but it's
    -- a hack anyway so we odn't care too much here
    local encoding = value and reencodings[value]
    if encoding then
        local temp = { }
        local char = tfmdata.characters
        for k, v in next, encoding do
            temp[k] = char[v]
        end
        for k, v in next, temp do
            char[k] = temp[k]
        end
        -- if we use the font otherwise luatex gets confused so
        -- we return an additional hash component for fullname
        return string.format("reencoded:%s",value)
    end
end

local function reencode(tfmdata,value)
    tfmdata.postprocessors = tfmdata.postprocessors or { }
    table.insert(tfmdata.postprocessors,
        function(tfmdata)
            return specialreencode(tfmdata,value)
        end
    )
end

table.insert(fonts.manipulators,"reencode")
fonts.initializers.base.otf.reencode = reencode

end -- closure
