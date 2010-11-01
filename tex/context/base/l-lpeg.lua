if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg = require("lpeg")

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local P, R, S, V, match = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.match
local Ct, C, Cs, Cc, Cf, Cg = lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Cf, lpeg.Cg

local utfcharacters    = string.utfcharacters
local utfgmatch        = unicode and unicode.utf8.gmatch

local digit, sign      = R('09'), S('+-')
local cr, lf, crlf     = P("\r"), P("\n"), P("\r\n")
local utf8next         = R("\128\191")
local escaped          = P("\\") * P(1)
local squote           = P("'")
local dquote           = P('"')

patterns.utf8one       = R("\000\127")
patterns.utf8two       = R("\194\223") * utf8next
patterns.utf8three     = R("\224\239") * utf8next * utf8next
patterns.utf8four      = R("\240\244") * utf8next * utf8next * utf8next
patterns.utfbom        = P('\000\000\254\255') + P('\255\254\000\000') + P('\255\254') + P('\254\255') + P('\239\187\191')

local utf8char         = patterns.utf8one + patterns.utf8two + patterns.utf8three + patterns.utf8four
local validutf8char    = utf8char^0 * P(-1) * Cc(true) + Cc(false)

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
patterns.space         = P(" ")
patterns.tab           = P("\t")
patterns.eol           = S("\n\r")
patterns.spacer        = S(" \t\f\v")  -- + string.char(0xc2, 0xa0) if we want utf (cf mail roberto)
patterns.newline       = crlf + cr + lf
patterns.nonspace      = 1 - patterns.space
patterns.nonspacer     = 1 - patterns.spacer
patterns.whitespace    = patterns.eol + patterns.spacer
patterns.nonwhitespace = 1 - patterns.whitespace
patterns.comma         = P(",")
patterns.commaspacer   = P(",") * patterns.spacer^0
patterns.period        = P(".")
patterns.escaped       = escaped
patterns.squote        = squote
patterns.dquote        = dquote
patterns.undouble      = (dquote/"") * ((escaped + (1-dquote))^0) * (dquote/"")
patterns.unsingle      = (squote/"") * ((escaped + (1-squote))^0) * (squote/"")
patterns.unquoted      = patterns.undouble + patterns.unsingle -- more often undouble
patterns.unspacer      = ((patterns.spacer^1)/"")^0

local unquoted = Cs(patterns.unquoted * P(-1)) -- not C

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

local spacing  = patterns.spacer^0 * patterns.newline -- sort of strip
local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

local capture = Ct(content^0)

function string.splitlines(str)
    return match(capture,str)
end

patterns.textline = content

--~ local p = lpeg.splitat("->",false)  print(match(p,"oeps->what->more"))  -- oeps what more
--~ local p = lpeg.splitat("->",true)   print(match(p,"oeps->what->more"))  -- oeps what->more
--~ local p = lpeg.splitat("->",false)  print(match(p,"oeps"))              -- oeps
--~ local p = lpeg.splitat("->",true)   print(match(p,"oeps"))              -- oeps

local splitters_s, splitters_m = { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        local other = C((1 - separator)^0)
        if single then
            local any = P(1)
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

--~ function lpeg.append(list,pp)
--~     local p = pp
--~     for l=1,#list do
--~         if p then
--~             p = p + P(list[l])
--~         else
--~             p = P(list[l])
--~         end
--~     end
--~     return p
--~ end

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

-- Just for fun I looked at the used bytecode and
-- p = (p and p + pp) or pp gets one more (testset).

function lpeg.replacer(t)
    if #t > 0 then
        local p
        for i=1,#t do
            local ti= t[i]
            local pp = P(ti[1]) / ti[2]
            if p then
                p = p + pp
            else
                p = pp
            end
        end
        return Cs((p + 1)^0)
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
        splitter = (1 - separator)^0 * separator * C(P(1)^0)
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
--~     local n, pattern = 0, (lpeg.P(pattern)/function() n = n + 1 end  + lpeg.P(1))^0
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

local p = Cs((S("-.+*%()[]") / patterns_escapes + P(1))^0)
local s = Cs((S("-.+*%()[]") / simple_escapes   + P(1))^0)

function string.escapedpattern(str,simple)
    if simple then
        return match(s,str)
    else
        return match(p,str)
    end
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
