if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


-- a new lpeg fails on a #(1-P(":")) test and really needs a + P(-1)

local lpeg = require("lpeg")

-- tracing (only used when we encounter a problem in integration of lpeg in luatex)

-- some code will move to unicode and string

local report = texio and texio.write_nl or print

-- local lpmatch = lpeg.match
-- local lpprint = lpeg.print
-- local lpp     = lpeg.P
-- local lpr     = lpeg.R
-- local lps     = lpeg.S
-- local lpc     = lpeg.C
-- local lpb     = lpeg.B
-- local lpv     = lpeg.V
-- local lpcf    = lpeg.Cf
-- local lpcb    = lpeg.Cb
-- local lpcg    = lpeg.Cg
-- local lpct    = lpeg.Ct
-- local lpcs    = lpeg.Cs
-- local lpcc    = lpeg.Cc
-- local lpcmt   = lpeg.Cmt
-- local lpcarg  = lpeg.Carg

-- function lpeg.match(l,...) report("LPEG MATCH") lpprint(l) return lpmatch(l,...) end

-- function lpeg.P    (l) local p = lpp   (l) report("LPEG P =")    lpprint(l) return p end
-- function lpeg.R    (l) local p = lpr   (l) report("LPEG R =")    lpprint(l) return p end
-- function lpeg.S    (l) local p = lps   (l) report("LPEG S =")    lpprint(l) return p end
-- function lpeg.C    (l) local p = lpc   (l) report("LPEG C =")    lpprint(l) return p end
-- function lpeg.B    (l) local p = lpb   (l) report("LPEG B =")    lpprint(l) return p end
-- function lpeg.V    (l) local p = lpv   (l) report("LPEG V =")    lpprint(l) return p end
-- function lpeg.Cf   (l) local p = lpcf  (l) report("LPEG Cf =")   lpprint(l) return p end
-- function lpeg.Cb   (l) local p = lpcb  (l) report("LPEG Cb =")   lpprint(l) return p end
-- function lpeg.Cg   (l) local p = lpcg  (l) report("LPEG Cg =")   lpprint(l) return p end
-- function lpeg.Ct   (l) local p = lpct  (l) report("LPEG Ct =")   lpprint(l) return p end
-- function lpeg.Cs   (l) local p = lpcs  (l) report("LPEG Cs =")   lpprint(l) return p end
-- function lpeg.Cc   (l) local p = lpcc  (l) report("LPEG Cc =")   lpprint(l) return p end
-- function lpeg.Cmt  (l) local p = lpcmt (l) report("LPEG Cmt =")  lpprint(l) return p end
-- function lpeg.Carg (l) local p = lpcarg(l) report("LPEG Carg =") lpprint(l) return p end

local type, next = type, next
local byte, char, gmatch, format = string.byte, string.char, string.gmatch, string.format

-- Beware, we predefine a bunch of patterns here and one reason for doing so
-- is that we get consistent behaviour in some of the visualizers.

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local P, R, S, V, Ct, C, Cs, Cc, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Cp
local lpegtype, lpegmatch = lpeg.type, lpeg.match

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
local newline          = crlf + S("\r\n") -- cr + lf
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

local eol              = S("\n\r")
local spacer           = S(" \t\f\v")  -- + char(0xc2, 0xa0) if we want utf (cf mail roberto)
local whitespace       = eol + spacer

patterns.digit         = digit
patterns.sign          = sign
patterns.cardinal      = sign^0 * digit^1
patterns.integer       = sign^0 * digit^1
patterns.unsigned      = digit^0 * P('.') * digit^1
patterns.float         = sign^0 * patterns.unsigned
patterns.cunsigned     = digit^0 * P(',') * digit^1
patterns.cfloat        = sign^0 * patterns.cunsigned
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
patterns.eol           = eol
patterns.spacer        = spacer
patterns.whitespace    = whitespace
patterns.newline       = newline
patterns.emptyline     = newline^1
patterns.nonspacer     = 1 - spacer
patterns.nonwhitespace = 1 - whitespace
patterns.equal         = P("=")
patterns.comma         = P(",")
patterns.commaspacer   = P(",") * spacer^0
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

patterns.singlequoted  = squote * patterns.nosquote * squote
patterns.doublequoted  = dquote * patterns.nodquote * dquote
patterns.quoted        = patterns.doublequoted + patterns.singlequoted

patterns.somecontent   = (anything - newline - space)^1 -- (utf8char - newline - space)^1
patterns.beginline     = #(1-newline)

-- print(string.unquoted("test"))
-- print(string.unquoted([["t\"est"]]))
-- print(string.unquoted([["t\"est"x]]))
-- print(string.unquoted("\'test\'"))
-- print(string.unquoted('"test"'))
-- print(string.unquoted('"test"'))

local function anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * V(1) }
end

lpeg.anywhere = anywhere

function lpeg.instringchecker(p)
    p = anywhere(p)
    return function(str)
        return lpegmatch(p,str) and true or false
    end
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

function lpeg.tsplitter(pattern, action)
    return Ct((((1-P(pattern))^1)/action+1)^0)
end

-- probleem: separator can be lpeg and that does not hash too well, but
-- it's quite okay as the key is then not garbage collected

local splitters_s, splitters_m, splitters_t = { }, { }, { }

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

local function tsplitat(separator)
    local splitter = splitters_t[separator]
    if not splitter then
        splitter = Ct(splitat(separator))
        splitters_t[separator] = splitter
    end
    return splitter
end

lpeg.splitat  = splitat
lpeg.tsplitat = tsplitat

function string.splitup(str,separator)
    if not separator then
        separator = ","
    end
    return lpegmatch(splitters_m[separator] or splitat(separator),str)
end

--~ local p = splitat("->",false)  print(lpegmatch(p,"oeps->what->more"))  -- oeps what more
--~ local p = splitat("->",true)   print(lpegmatch(p,"oeps->what->more"))  -- oeps what->more
--~ local p = splitat("->",false)  print(lpegmatch(p,"oeps"))              -- oeps
--~ local p = splitat("->",true)   print(lpegmatch(p,"oeps"))              -- oeps

local cache = { }

function lpeg.split(separator,str)
    local c = cache[separator]
    if not c then
        c = tsplitat(separator)
        cache[separator] = c
    end
    return lpegmatch(c,str)
end

function string.split(str,separator)
    if separator then
        local c = cache[separator]
        if not c then
            c = tsplitat(separator)
            cache[separator] = c
        end
        return lpegmatch(c,str)
    else
        return { str }
    end
end

local spacing  = patterns.spacer^0 * newline -- sort of strip
local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

patterns.textline = content

--~ local linesplitter = Ct(content^0)
--~
--~ function string.splitlines(str)
--~     return lpegmatch(linesplitter,str)
--~ end

local linesplitter = tsplitat(newline)

patterns.linesplitter = linesplitter

function string.splitlines(str)
    return lpegmatch(linesplitter,str)
end

local utflinesplitter = utfbom^-1 * tsplitat(newline)

patterns.utflinesplitter = utflinesplitter

function string.utfsplitlines(str)
    return lpegmatch(utflinesplitter,str or "")
end

local utfcharsplitter_ows = utfbom^-1 * Ct(C(utf8char)^0)
local utfcharsplitter_iws = utfbom^-1 * Ct((whitespace^1 + C(utf8char))^0)

function string.utfsplit(str,ignorewhitespace) -- new
    if ignorewhitespace then
        return lpegmatch(utfcharsplitter_iws,str or "")
    else
        return lpegmatch(utfcharsplitter_ows,str or "")
    end
end

-- inspect(string.utfsplit("a b c d"))
-- inspect(string.utfsplit("a b c d",true))

-- -- alternative 1: 0.77
--
-- local utfcharcounter = utfbom^-1 * Cs((utf8char/'!')^0)
--
-- function string.utflength(str)
--     return #lpegmatch(utfcharcounter,str or "")
-- end
--
-- -- alternative 2: 1.70
--
-- local n = 0
--
-- local utfcharcounter = utfbom^-1 * (utf8char/function() n = n + 1 end)^0 -- slow
--
-- function string.utflength(str)
--     n = 0
--     lpegmatch(utfcharcounter,str or "")
--     return n
-- end
--
-- -- alternative 3: 0.24 (native unicode.utf8.len: 0.047)

local n = 0

local utfcharcounter = utfbom^-1 * Cs ( (
    Cp() * (lpeg.patterns.utf8one  )^1 * Cp() / function(f,t) n = n +  t - f    end
  + Cp() * (lpeg.patterns.utf8two  )^1 * Cp() / function(f,t) n = n + (t - f)/2 end
  + Cp() * (lpeg.patterns.utf8three)^1 * Cp() / function(f,t) n = n + (t - f)/3 end
  + Cp() * (lpeg.patterns.utf8four )^1 * Cp() / function(f,t) n = n + (t - f)/4 end
)^0 )

function string.utflength(str)
    n = 0
    lpegmatch(utfcharcounter,str or "")
    return n
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
    return lpegmatch(c,str)
end

function string.checkedsplit(str,separator)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return lpegmatch(c,str)
end

--~ from roberto's site:

local function f2(s) local c1, c2         = byte(s,1,2) return   c1 * 64 + c2                       -    12416 end
local function f3(s) local c1, c2, c3     = byte(s,1,3) return  (c1 * 64 + c2) * 64 + c3            -   925824 end
local function f4(s) local c1, c2, c3, c4 = byte(s,1,4) return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168 end

local utf8byte = patterns.utf8one/byte + patterns.utf8two/f2 + patterns.utf8three/f3 + patterns.utf8four/f4

patterns.utf8byte = utf8byte

--~ local str = " a b c d "

--~ local s = lpeg.stripper(lpeg.R("az"))   print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.keeper(lpeg.R("az"))     print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.stripper("ab")           print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.keeper("ab")             print("["..lpegmatch(s,str).."]")

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
    return (P(str) + P(true)) * Cs(anything^0)
end

function lpeg.endstripper(str) -- or pattern (yet undocumented)
    return Cs((1 - P(str) * endofstring)^0)
end

-- Just for fun I looked at the used bytecode and
-- p = (p and p + pp) or pp gets one more (testset).

function lpeg.replacer(one,two,makefunction)
    local pattern
    if type(one) == "table" then
        local no = #one
        local p = P(false)
        if no == 0 then
            for k, v in next, one do
                p = p + P(k) / v
            end
            pattern = Cs((p + 1)^0)
        elseif no == 1 then
            local o = one[1]
            one, two = P(o[1]), o[2]
         -- pattern = Cs(((1-one)^1 + one/two)^0)
            pattern = Cs((one/two + 1)^0)
        else
            for i=1,no do
                local o = one[i]
                p = p + P(o[1]) / o[2]
            end
            pattern = Cs((p + 1)^0)
        end
    else
        one = P(one)
        two = two or ""
     -- pattern = Cs(((1-one)^1 + one/two)^0)
        pattern = Cs((one/two +1)^0)
    end
    if makefunction then
        return function(str)
            return lpegmatch(pattern,str)
        end
    else
        return pattern
    end
end

function lpeg.finder(lst,makefunction)
    local pattern
    if type(lst) == "table" then
        local p = P(false)
        for i=1,#lst do
            p = p + P(lst[i])
        end
        pattern = (p + 1)^0
    else
        pattern = (P(lst) + 1)^0
    end
    if makefunction then
        return function(str)
            return lpegmatch(pattern,str)
        end
    else
        return pattern
    end
end

-- print(lpeg.match(lpeg.replacer("e","a"),"test test"))
-- print(lpeg.match(lpeg.replacer{{"e","a"}},"test test"))
-- print(lpeg.match(lpeg.replacer({ e = "a", t = "x" }),"test test"))

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

--~ print(1,lpegmatch(lpeg.firstofsplit(":"),"bc:de"))
--~ print(2,lpegmatch(lpeg.firstofsplit(":"),":de")) -- empty
--~ print(3,lpegmatch(lpeg.firstofsplit(":"),"bc"))
--~ print(4,lpegmatch(lpeg.secondofsplit(":"),"bc:de"))
--~ print(5,lpegmatch(lpeg.secondofsplit(":"),"bc:")) -- empty
--~ print(6,lpegmatch(lpeg.secondofsplit(":",""),"bc"))
--~ print(7,lpegmatch(lpeg.secondofsplit(":"),"bc"))
--~ print(9,lpegmatch(lpeg.secondofsplit(":","123"),"bc"))

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
        return #lpegmatch(pattern,str)
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
            return #lpegmatch(Cs((P(what)/" " + nany)^0),str)
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
            return #lpegmatch(p,str)
        else -- 4 times slower but still faster than / function
            return #lpegmatch(Cs((P(what)/" " + nany)^0),str)
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
    return lpegmatch(simple and s or p,str)
end

-- utf extensies

lpeg.UP = lpeg.P

if utfcharacters then

    function lpeg.US(str)
        local p = P(false)
        for uc in utfcharacters(str) do
            p = p + P(uc)
        end
        return p
    end


elseif utfgmatch then

    function lpeg.US(str)
        local p = P(false)
        for uc in utfgmatch(str,".") do
            p = p + P(uc)
        end
        return p
    end

else

    function lpeg.US(str)
        local p = P(false)
        local f = function(uc)
            p = p + P(uc)
        end
        lpegmatch((utf8char/f)^0,str)
        return p
    end

end

local range = utf8byte * utf8byte + Cc(false) -- utf8byte is already a capture

local utfchar = unicode and unicode.utf8 and unicode.utf8.char

function lpeg.UR(str,more)
    local first, last
    if type(str) == "number" then
        first = str
        last = more or first
    else
        first, last = lpegmatch(range,str)
        if not last then
            return P(str)
        end
    end
    if first == last then
        return P(str)
    elseif utfchar and (last - first < 8) then -- a somewhat arbitrary criterium
        local p = P(false)
        for i=first,last do
            p = p + P(utfchar(i))
        end
        return p -- nil when invalid range
    else
        local f = function(b)
            return b >= first and b <= last
        end
        -- tricky, these nested captures
        return utf8byte / f -- nil when invalid range
    end
end

-- print(lpeg.match(lpeg.Cs((C(lpeg.UR("αω"))/{ ["χ"] = "OEPS" })^0),"αωχαω"))

--~ lpeg.print(lpeg.R("ab","cd","gh"))
--~ lpeg.print(lpeg.P("a","b","c"))
--~ lpeg.print(lpeg.S("a","b","c"))

--~ print(lpeg.count("äáàa",lpeg.P("á") + lpeg.P("à")))
--~ print(lpeg.count("äáàa",lpeg.UP("áà")))
--~ print(lpeg.count("äáàa",lpeg.US("àá")))
--~ print(lpeg.count("äáàa",lpeg.UR("aá")))
--~ print(lpeg.count("äáàa",lpeg.UR("àá")))
--~ print(lpeg.count("äáàa",lpeg.UR(0x0000,0xFFFF)))

function lpeg.is_lpeg(p)
    return p and lpegtype(p) == "pattern"
end

function lpeg.oneof(list,...) -- lpeg.oneof("elseif","else","if","then") -- assume proper order
    if type(list) ~= "table" then
        list = { list, ... }
    end
 -- table.sort(list) -- longest match first
    local p = P(list[1])
    for l=2,#list do
        p = p + P(list[l])
    end
    return p
end

-- For the moment here, but it might move to utilities. Beware, we need to
-- have the longest keyword first, so 'aaa' comes beforte 'aa' which is why we
-- loop back from the end cq. prepend.

local sort, fastcopy, sortedkeys = table.sort, table.fastcopy, table.sortedkeys -- dependency!

function lpeg.append(list,pp,delayed,checked)
    local p = pp
    if #list > 0 then
        local keys = fastcopy(list)
        sort(keys)
        for i=#keys,1,-1 do
            local k = keys[i]
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
    elseif delayed then -- hm, it looks like the lpeg parser resolves anyway
        local keys = sortedkeys(list)
        if p then
            for i=1,#keys,1 do
                local k = keys[i]
                local v = list[k]
                p = P(k)/list + p
            end
        else
            for i=1,#keys do
                local k = keys[i]
                local v = list[k]
                if p then
                    p = P(k) + p
                else
                    p = P(k)
                end
            end
            if p then
                p = p / list
            end
        end
    elseif checked then
        -- problem: substitution gives a capture
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                if k == v then
                    p = P(k) + p
                else
                    p = P(k)/v + p
                end
            else
                if k == v then
                    p = P(k)
                else
                    p = P(k)/v
                end
            end
        end
    else
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                p = P(k)/v + p
            else
                p = P(k)/v
            end
        end
    end
    return p
end

-- inspect(lpeg.append({ a = "1", aa = "1", aaa = "1" } ,nil,true))
-- inspect(lpeg.append({ ["degree celsius"] = "1", celsius = "1", degree = "1" } ,nil,true))

-- function lpeg.exact_match(words,case_insensitive)
--     local pattern = concat(words)
--     if case_insensitive then
--         local pattern = S(upper(characters)) + S(lower(characters))
--         local list = { }
--         for i=1,#words do
--             list[lower(words[i])] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[lower(s)] and i
--         end)
--     else
--         local pattern = S(concat(words))
--         local list = { }
--         for i=1,#words do
--             list[words[i]] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[s] and i
--         end)
--     end
-- end

-- experiment:

local function make(t)
    local p
--     for k, v in next, t do
    for k, v in table.sortedhash(t) do
        if not p then
            if next(v) then
                p = P(k) * make(v)
            else
                p = P(k)
            end
        else
            if next(v) then
                p = p + P(k) * make(v)
            else
                p = p + P(k)
            end
        end
    end
    return p
end

function lpeg.utfchartabletopattern(list)
    local tree = { }
    for i=1,#list do
        local t = tree
        for c in gmatch(list[i],".") do
            if not t[c] then
                t[c] = { }
            end
            t = t[c]
        end
    end
    return make(tree)
end

-- inspect ( lpeg.utfchartabletopattern {
--     utfchar(0x00A0), -- nbsp
--     utfchar(0x2000), -- enquad
--     utfchar(0x2001), -- emquad
--     utfchar(0x2002), -- enspace
--     utfchar(0x2003), -- emspace
--     utfchar(0x2004), -- threeperemspace
--     utfchar(0x2005), -- fourperemspace
--     utfchar(0x2006), -- sixperemspace
--     utfchar(0x2007), -- figurespace
--     utfchar(0x2008), -- punctuationspace
--     utfchar(0x2009), -- breakablethinspace
--     utfchar(0x200A), -- hairspace
--     utfchar(0x200B), -- zerowidthspace
--     utfchar(0x202F), -- narrownobreakspace
--     utfchar(0x205F), -- math thinspace
-- } )

-- handy from within tex:

local lpegmatch = lpeg.match

local replacer = lpeg.replacer("@","%%") -- Watch the escaped % in lpeg!

function string.tformat(fmt,...)
    return format(lpegmatch(replacer,fmt),...)
end

-- strips leading and trailing spaces and collapsed all other spaces

local pattern = Cs(whitespace^0/"" * ((whitespace^1 * P(-1) / "") + (whitespace^1/" ") + P(1))^0)

function string.collapsespaces(str)
    return lpegmatch(pattern,str)
end
