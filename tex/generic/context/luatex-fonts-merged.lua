-- merged file : luatex-fonts-merged.lua
-- parent file : luatex-fonts.lua
-- merge date  : 10/20/10 21:33:36

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
local lpegmatch = lpeg.match

-- some functions may disappear as they are not used anywhere

if not string.split then

    -- this will be overloaded by a faster lpeg variant

    function string:split(pattern)
        if #self > 0 then
            local t = { }
            for s in gmatch(self..pattern,"(.-)"..pattern) do
                t[#t+1] = s
            end
            return t
        else
            return { }
        end
    end

end

string.patterns = { }

local escapes = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["^"] = "%^", ["$"] = "%$",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
    ["{"] = "%{", ["}"] = "%}"
}

string.patterns.escapes = escapes

function string:esc() -- variant 2
    return (gsub(self,"(.)",escapes))
end

function string:unquote()
    return (gsub(self,"^([\"\'])(.*)%1$","%2"))
end

--~ function string:unquote()
--~     if find(self,"^[\'\"]") then
--~         return sub(self,2,-2)
--~     else
--~         return self
--~     end
--~ end

function string:quote() -- we could use format("%q")
    return format("%q",self)
end

function string:count(pattern) -- variant 3
    local n = 0
    for _ in gmatch(self,pattern) do
        n = n + 1
    end
    return n
end

function string:limit(n,sentinel)
    if #self > n then
        sentinel = sentinel or " ..."
        return sub(self,1,(n-#sentinel)) .. sentinel
    else
        return self
    end
end

--~ function string:strip() -- the .- is quite efficient
--~  -- return match(self,"^%s*(.-)%s*$") or ""
--~  -- return match(self,'^%s*(.*%S)') or '' -- posted on lua list
--~     return find(s,'^%s*$') and '' or match(s,'^%s*(.*%S)')
--~ end

do -- roberto's variant:
    local space    = lpeg.S(" \t\v\n")
    local nospace  = 1 - space
    local stripper = space^0 * lpeg.C((space^0 * nospace^1)^0)
    function string.strip(str)
        return lpegmatch(stripper,str) or ""
    end
end

function string:is_empty()
    return not find(self,"%S")
end

function string:enhance(pattern,action)
    local ok, n = true, 0
    while ok do
        ok = false
        self = gsub(self,pattern, function(...)
            ok, n = true, n + 1
            return action(...)
        end)
    end
    return self, n
end

if not string.characters then

    local function nextchar(str, index)
        index = index + 1
        return (index <= #str) and index or nil, sub(str,index,index)
    end
    function string:characters()
        return nextchar, self, 0
    end
    local function nextbyte(str, index)
        index = index + 1
        return (index <= #str) and index or nil, byte(sub(str,index,index))
    end
    function string:bytes()
        return nextbyte, self, 0
    end

end

function string:rpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return self .. rep(chr or " ",m)
    else
        return self
    end
end

function string:lpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return rep(chr or " ",m) .. self
    else
        return self
    end
end

string.padd = string.rpadd

local patterns_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["+"] = "%+",
    ["*"] = "%*",
    ["%"] = "%%",
    ["("] = "%)",
    [")"] = "%)",
    ["["] = "%[",
    ["]"] = "%]",
}

function string:escapedpattern()
    return (gsub(self,".",patterns_escapes))
end

local simple_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

function string:partialescapedpattern()
    return (gsub(self,".",simple_escapes))
end

function string:tohash()
    local t = { }
    for s in gmatch(self,"([^, ]+)") do -- lpeg
        t[s] = true
    end
    return t
end

local pattern = lpeg.Ct(lpeg.C(1)^0)

function string:totable()
    return lpegmatch(pattern,self)
end

--~ local t = {
--~     "1234567123456712345671234567",
--~     "a\tb\tc",
--~     "aa\tbb\tcc",
--~     "aaa\tbbb\tccc",
--~     "aaaa\tbbbb\tcccc",
--~     "aaaaa\tbbbbb\tccccc",
--~     "aaaaaa\tbbbbbb\tcccccc",
--~ }
--~ for k,v do
--~     print(string.tabtospace(t[k]))
--~ end

function string.tabtospace(str,tab)
    -- we don't handle embedded newlines
    while true do
        local s = find(str,"\t")
        if s then
            if not tab then tab = 7 end -- only when found
            local d = tab-(s-1) % tab
            if d > 0 then
                str = gsub(str,"\t",rep(" ",d),1)
            else
                str = gsub(str,"\t","",1)
            end
        else
            break
        end
    end
    return str
end

function string:compactlong() -- strips newlines and leading spaces
    self = gsub(self,"[\n\r]+ *","")
    self = gsub(self,"^ *","")
    return self
end

function string:striplong() -- strips newlines and leading spaces
    self = gsub(self,"^%s*","")
    self = gsub(self,"[\n\r]+ *","\n")
    return self
end

function string:topattern(lowercase,strict)
    if lowercase then
        self = lower(self)
    end
    self = gsub(self,".",simple_escapes)
    if self == "" then
        self = ".*"
    elseif strict then
        self = "^" .. self .. "$"
    end
    return self
end

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

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local P, R, S, Ct, C, Cs, Cc, V = lpeg.P, lpeg.R, lpeg.S, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.V
local match = lpeg.match

local digit, sign      = R('09'), S('+-')
local cr, lf, crlf     = P("\r"), P("\n"), P("\r\n")
local utf8byte         = R("\128\191")

patterns.utf8byte      = utf8byte
patterns.utf8one       = R("\000\127")
patterns.utf8two       = R("\194\223") * utf8byte
patterns.utf8three     = R("\224\239") * utf8byte * utf8byte
patterns.utf8four      = R("\240\244") * utf8byte * utf8byte * utf8byte

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
patterns.utf8          = patterns.utf8one + patterns.utf8two + patterns.utf8three + patterns.utf8four
patterns.utfbom        = P('\000\000\254\255') + P('\255\254\000\000') + P('\255\254') + P('\254\255') + P('\239\187\191')
patterns.validutf8     = patterns.utf8^0 * P(-1) * Cc(true) + Cc(false)
patterns.comma         = P(",")
patterns.commaspacer   = P(",") * patterns.spacer^0
patterns.period        = P(".")

patterns.undouble      = P('"')/"" * (1-P('"'))^0 * P('"')/""
patterns.unsingle      = P("'")/"" * (1-P("'"))^0 * P("'")/""
patterns.unspacer      = ((patterns.spacer^1)/"")^0

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

function string:splitlines()
    return match(capture,self)
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

function lpeg.split(separator,str)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return match(c,str)
end

function string:split(separator)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return match(c,self)
end

lpeg.splitters = cache

local cache = { }

function lpeg.checkedsplit(separator,str)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^0)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,str)
end

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

patterns.utf8byte = patterns.utf8one/f1 + patterns.utf8two/f2 + patterns.utf8three/f3 + patterns.utf8four/f4

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

function lpeg.replacer(t)
    if #t > 0 then
        local p
        for i=1,#t do
            local ti= t[i]
            local pp = P(ti[1]) / ti[2]
            p = (p and p + pp ) or pp
        end
        return Cs((p + 1)^0)
    end
end

--~ print(utf.check(""))
--~ print(utf.check("abcde"))
--~ print(utf.check("abcde\255\123"))

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

function boolean.tonumber(b)
    if b then return 1 else return 0 end
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

function boolean.alwaystrue()
    return true
end

function boolean.falsetrue()
    return false
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
    function math.round(x)
        return floor(x + 0.5)
    end
end

if not math.div then
    function math.div(n,m)
        return floor(n/m)
    end
end

if not math.mod then
    function math.mod(n,m)
        return n % m
    end
end

local pipi = 2*math.pi/360

function math.sind(d)
    return sin(d*pipi)
end

function math.cosd(d)
    return cos(d*pipi)
end

function math.tand(d)
    return tan(d*pipi)
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
    local lst = { }
    for i=1,#tab do
        local s = gsub(tab[i],"^%s*(.-)%s*$","%1")
        if s == "" then
            -- skip this one
        else
            lst[#lst+1] = s
        end
    end
    return lst
end

function table.keys(t)
    local k = { }
    for key, _ in next, t do
        k[#k+1] = key
    end
    return k
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
    local srt, kind = { }, 0 -- 0=unknown 1=string, 2=number 3=mixed
    for key,_ in next, tab do
        srt[#srt+1] = key
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
    local srt = { }
    for key,_ in next, tab do
        if key then
            srt[#srt+1] = key
        end
    end
    sort(srt)
    return srt
end

table.sortedkeys     = sortedkeys
table.sortedhashkeys = sortedhashkeys

local function sortedhash(t)
    local s = sortedhashkeys(t) -- maybe just sortedkeys
    local n = 0
    local function kv(s)
        n = n + 1
        local k = s[n]
        return k, t[k]
    end
    return kv, s
end

table.sortedhash  = sortedhash
table.sortedpairs = sortedhash

function table.append(t, list)
    for _,v in next, list do
        insert(t,v)
    end
end

function table.prepend(t, list)
    for k,v in next, list do
        insert(t,k,v)
    end
end

function table.merge(t, ...) -- first one is target
    t = t or { }
    local lst = {...}
    for i=1,#lst do
        for k, v in next, lst[i] do
            t[k] = v
        end
    end
    return t
end

function table.merged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        for k, v in next, lst[i] do
            tmp[k] = v
        end
    end
    return tmp
end

function table.imerge(t, ...)
    local lst = {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            t[#t+1] = nst[j]
        end
    end
    return t
end

function table.imerged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            tmp[#tmp+1] = nst[j]
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
    local h = { }
    for k, v in next, t do -- no ipairs here
        if v then h[#h+1] = k end
    end
    return h
end

table.serialize_functions = true
table.serialize_compact   = true
table.serialize_inline    = true

local noquotes, hexify, handle, reduce, compact, inline, functions

local reserved = table.tohash { -- intercept a language flaw, no reserved words as key
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
            local tt = { }
            for i=1,#t do
                local v = t[i]
                local tv = type(v)
                if tv == "number" then
                    if hexify then
                        tt[#tt+1] = format("0x%04X",v)
                    else
                        tt[#tt+1] = tostring(v) -- tostring not needed
                    end
                elseif tv == "boolean" then
                    tt[#tt+1] = tostring(v)
                elseif tv == "string" then
                    tt[#tt+1] = format("%q",v)
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
    if root and next(root) then
        do_serialize(root,name,"",0)
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

function table.serialize(root,name,reduce,noquotes,hexify)
    local t = { }
    local function flush(s)
        t[#t+1] = s
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
            local t = { }
            local function flush(s)
                t[#t+1] = s
                if #t > maxtab then
                    f:write(concat(t,"\n"),"\n") -- hm, write(sometable) should be nice
                    t = { }
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

local function flatten(t,f,complete) -- is this used? meybe a variant with next, ...
    for i=1,#t do
        local v = t[i]
        if type(v) == "table" then
            if complete or type(v[1]) == "table" then
                flatten(v,f,complete)
            else
                f[#f+1] = v
            end
        else
            f[#f+1] = v
        end
    end
end

function table.flatten(t)
    local f = { }
    flatten(t,f,true)
    return f
end

function table.unnest(t) -- bad name
    local f = { }
    flatten(t,f,false)
    return f
end

table.flattenonelevel = table.unnest

-- a better one:

local function flattened(t,f)
    if not f then
        f = { }
    end
    for k, v in next, t do
        if type(v) == "table" then
            flattened(v,f)
        else
            f[k] = v
        end
    end
    return f
end

table.flattened = flattened

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
        local vb = b[k]
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

table.are_equal = are_equal
table.identical = identical

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
    local n, e = 0, next(t)
    while e do
        n, e = n + 1, next(t,e)
    end
    return n
end

function table.swapped(t,s)
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

--~ function table.are_equal(a,b)
--~     return table.serialize(a) == table.serialize(b)
--~ end

function table.clone(t,p) -- t is optional or nil or table
    if not p then
        t, p = { }, t or { }
    elseif not t then
        t = { }
    end
    setmetatable(t, { __index = function(_,key) return p[key] end }) -- why not __index = p ?
    return t
end

function table.hexed(t,seperator)
    local tt = { }
    for i=1,#t do tt[i] = format("0x%04X",t[i]) end
    return concat(tt,seperator or " ")
end

function table.swaphash(h) -- needs another name
    local r = { }
    for k,v in next, h do
        r[v] = lower(gsub(k," ",""))
    end
    return r
end

function table.reverse(t)
    local tt = { }
    if #t > 0 then
        for i=#t,1,-1 do
            tt[#tt+1] = t[i]
        end
    end
    return tt
end

function table.sequenced(t,sep,simple) -- hash only
    local s = { }
    for k, v in sortedhash(t) do
        if simple then
            if v == true then
                s[#s+1] = k
            elseif v and v~= "" then
                s[#s+1] = k .. "=" .. tostring(v)
            end
        else
            s[#s+1] = k .. "=" .. tostring(v)
        end
    end
    return concat(s, sep or " | ")
end

function table.print(...)
    table.tohandle(print,...)
end

-- -- -- obsolete but we keep them for a while and will comment them later -- -- --

-- roughly: copy-loop : unpack : sub == 0.9 : 0.4 : 0.45 (so in critical apps, use unpack)

function table.sub(t,i,j)
    return { unpack(t,i,j) }
end

-- slower than #t on indexed tables (#t only returns the size of the numerically indexed slice)

function table.is_empty(t)
    return not t or not next(t)
end

function table.has_one_entry(t)
    local n = next(t)
    return n and not next(t,n)
end

function table.replace(a,b)
    for k,v in next, b do
        a[k] = v
    end
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
local find, gmatch, match, gsub, sub, char = string.find, string.gmatch, string.match, string.gsub, string.sub, string.char
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

-- todo: lpeg

local checkedsplit = string.checkedsplit

function file.splitpath(str,separator) -- string
    str = gsub(str,"\\","/")
    return checkedsplit(str,separator or io.pathseparator)
end

function file.joinpath(tab) -- table
    return concat(tab,io.pathseparator) -- can have trailing //
end

-- we can hash them weakly

--~ function file.old_collapse_path(str) -- fails on b.c/..
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

function file.collapse_path(str,anchor)
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

--~ local function test(str)
--~    print(string.format("%-20s %-15s %-15s",str,file.collapse_path(str),file.collapse_path(str,true)))
--~ end
--~ test("a/b.c/d") test("b.c/d") test("b.c/..")
--~ test("/") test("c:/..") test("sys://..")
--~ test("") test("./") test(".") test("..") test("./..") test("../..")
--~ test("a") test("./a") test("/a") test("a/../..")
--~ test("a/./b/..") test("a/aa/../b/bb") test("a/.././././b/..") test("a/./././b/..")
--~ test("a/b/c/../..") test("./a/b/c/../..") test("a/b/c/../..")

function file.robustname(str)
    return (gsub(str,"[^%a%d%/%-%.\\]+","-"))
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
    local n = 0
    for _ in f:lines() do
        n = n + 1
    end
    f:seek('set',0)
    return n
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
    new           = function() return dummyfunction end,
    report        = dummyfunction,
    simple        = dummyfunction,
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

-- we need to cheat a bit here

texconfig.kpse_init = true

resolvers = resolvers or { } -- no fancy file helpers used

local remapper = {
    otf   = "opentype fonts",
    ttf   = "truetype fonts",
    ttc   = "truetype fonts",
    dfont = "truetype dictionary",
    cid   = "cid maps",
    fea   = "font feature files",
}

function resolvers.findfile(name,kind)
    name = string.gsub(name,"\\","\/")
    kind = string.lower(kind)
    return kpse.find_file(name,(kind and kind ~= "" and (remapper[kind] or kind)) or file.extname(name,"tex"))
end

function resolvers.findbinfile(name,kind)
    if not kind or kind == "" then
        kind = file.extname(name) -- string.match(name,"%.([^%.]-)$")
    end
    return resolvers.findfile(name,(kind and remapper[kind]) or kind)
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

local report_cache = logs.new("cache")

local function report(container,tag,name)
    if trace_cache or trace_containers then
        report_cache("container: %s, tag: %s, name: %s",container.subcategory,tag,name or 'invalid')
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

-- fonts

local fontdata = fonts.ids or { }

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
    texio.write_nl("log","! purposed so setting them at the TeX end might break the font handler.")
    texio.write_nl("log","!")

    tex.attribute[0] = 0 -- else no features

end

nodes.handlers.protectglyphs   = node.protect_glyphs
nodes.handlers.unprotectglyphs = node.unprotect_glyphs

function nodes.handlers.characters(head)
    local usedfonts, done, prevfont = { }, false, nil
    for n in traverse_id(glyph_code,head) do
        local font = n.font
        if font ~= prevfont then
            prevfont = font
            local used = usedfonts[font]
            if not used then
                local tfmdata = fontdata[font]
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

-- tricky ... fonts.ids is not yet defined .. to be solved (maybe general tex ini)

-- This is very experimental (this will change when we have luatex > .50 and
-- a few pending thingies are available. Also, Idris needs to make a few more
-- test fonts. Btw, future versions of luatex will have extended glyph properties
-- that can be of help.

local next = next

local trace_injections = false  trackers.register("nodes.injections", function(v) trace_injections = v end)

local report_injections = logs.new("injections")

local attributes, nodes, node = attributes, nodes, node

fonts     = fonts      or { }
fonts.tfm = fonts.tfm  or { }
fonts.ids = fonts.ids  or { }

nodes.injections = nodes.injections or { }
local injections = nodes.injections

local fontdata   = fonts.ids
local nodecodes  = nodes.nodecodes
local glyph_code = nodecodes.glyph
local nodepool   = nodes.pool
local newkern    = nodepool.kern

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
        local done, ky, rl, valid, cx, wx, mk = false, { }, { }, { }, { }, { }, { }
        if has_kerns then -- move outside loop
            local nf, tm = nil, nil
            for n in traverse_id(glyph_code,head) do
                if n.subtype < 256 then
                    valid[#valid+1] = n
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
                    valid[#valid+1] = n
                    if n.font ~= nf then
                        nf = n.font
                        tm = fontdata[nf].marks
                    end
                    mk[n] = tm[n.char]
                end
            end
        end
        if #valid > 0 then
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
                for i=1,#valid do -- valid == glyphs
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
                for i=1,#valid do
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

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local utf = unicode.utf8
local format, serialize = string.format, table.serialize
local write_nl = texio.write_nl
local lower = string.lower
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local report_define = logs.new("define fonts")

fontloader.totable = fontloader.to_table

-- vtf comes first
-- fix comes last

fonts = fonts or { }

-- we will also have des and fam hashes

-- beware, soem alreadyu defined

fonts.ids = mark(fonts.ids or { })  fonts.identifiers = fonts.ids -- aka fontdata
fonts.chr = mark(fonts.chr or { })  fonts.characters  = fonts.chr -- aka chardata
fonts.qua = mark(fonts.qua or { })  fonts.quads       = fonts.qua -- aka quaddata
fonts.css = mark(fonts.css or { })  fonts.csnames     = fonts.css -- aka namedata

fonts.tfm = fonts.tfm or { }
fonts.vf  = fonts.vf  or { }
fonts.afm = fonts.afm or { }
fonts.pfb = fonts.pfb or { }
fonts.otf = fonts.otf or { }

fonts.privateoffset = 0xF0000 -- 0x10FFFF
fonts.verbose = false -- more verbose cache tables

fonts.ids[0] = { -- nullfont
    characters   = { },
    descriptions = { },
    name         = "nullfont",
}

fonts.chr[0] = { }

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
        report_define("unable to determine font format for '%s'",filename)
        return default
    end
end

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

local report_define = logs.new("define fonts")

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

local fontdata   = fonts.ids
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

fonts.formats.tfm = "type1" -- we need to have at least a value here

function tfm.read_from_tfm(specification)
    local fname, tfmdata = specification.filename or "", nil
    if fname ~= "" then
        if trace_defining then
            report_define("loading tfm file %s at size %s",fname,specification.size)
        end
        tfmdata = font.read_tfm(fname,specification.size) -- not cached, fast enough
        if tfmdata then
            tfmdata.descriptions = tfmdata.descriptions or { }
            if tfm.resolvevirtualtoo then
                fonts.logger.save(tfmdata,file.extname(fname),specification) -- strange, why here
                fname = resolvers.findbinfile(specification.name, 'ovf')
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
        report_define("loading tfm with name %s fails",specification.name)
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

function tfm.getvirtualid(tfmdata)
    --  since we don't know the id yet, we use 0 as signal
    if not tfmdata.fonts then
        tfmdata.type = "virtual"
        tfmdata.fonts = { { id = 0 } }
        return 1
    else
        tfmdata.fonts[#tfmdata.fonts+1] = { id = 0 }
        return #tfmdata.fonts
    end
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
    t.units_per_em = units or 1000
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
    local hasmath = (tfmtable.math_parameters ~= nil and next(tfmtable.math_parameters) ~= nil) or (tfmtable.MathConstants ~= nil and next(tfmtable.MathConstants) ~= nil)
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
    t.goodies = tfmtable.goodies
    t.colorscheme = tfmtable.colorscheme
 -- t.embedding = tfmtable.embedding
    t.descriptions = descriptions
    if tfmtable.fonts then
        t.fonts = table.fastcopy(tfmtable.fonts) -- hm  also at the end
    end
    local tp = t.parameters
    local mp = t.math_parameters
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
    --      report_define("t=%s, u=%s, i=%s, n=%s c=%s",k,chr.tounicode or k,description.index,description.name or '-',description.class or '-')
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
            --~     report_define("glyph 0x%05X has combination of next, vert_variants and horiz_variants",index)
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
                            tt[#tt+1] = { key, ivc[2]*hdelta }
                        elseif key == "down" then
                            tt[#tt+1] = { key, ivc[2]*vdelta }
                        elseif key == "rule" then
                            tt[#tt+1] = { key, ivc[2]*vdelta, ivc[3]*hdelta }
                        else -- not comment
                            tt[#tt+1] = ivc -- shared since in cache and untouched
                        end
                    end
                    chr.commands = tt
                else
                    chr.commands = vc
                end
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
            report_define("math enabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
        end
    else
        if trace_defining then
            report_define("math disabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
        end
        t.nomath, t.MathConstants = true, nil
    end
    if not t.psname then
     -- name used in pdf file as well as for selecting subfont in ttc/dfont
        t.psname = t.fontname or (t.fullname and fonts.names.cleanname(t.fullname))
    end
    if trace_defining then
        report_define("used for accessing (sub)font: '%s'",t.psname or "nopsname")
        report_define("used for subsetting: '%s'",t.fontname or "nofontname")
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
            foundfilename = resolvers.findbinfile(askedfilename,"") or ""
            if foundfilename == "" then
                report_define("source file '%s' is not found",askedfilename)
                foundfilename = resolvers.findbinfile(file.basename(askedfilename),"") or ""
                if foundfilename ~= "" then
                    report_define("using source file '%s' (cache mismatch)",foundfilename)
                end
            end
        elseif whatever then
            report_define("no source file for '%s'",whatever)
            foundfilename = ""
        end
        metadata.foundfilename = foundfilename
    --  report_define("using source file '%s'",foundfilename)
    end
    return foundfilename
end

-- status info

statistics.register("fonts load time", function()
    return statistics.elapsedseconds(fonts)
end)

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

local report_otf = logs.new("load otf")

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

local verbosescripts    = allocate(table.swaphash(scripts  ))
local verboselanguages  = allocate(table.swaphash(languages))
local verbosefeatures   = allocate(table.swaphash(features ))

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

-- can be sped up by local tables

function tables.totag(id) -- not used
    return format("%4s",lower(id))
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

local report_otf = logs.new("load otf")

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
    local aglmap = fonts.enc and fonts.enc.agl -- to name
    for index, glyph in next, data.glyphs do
        local name, unic = glyph.name, glyph.unicode or -1 -- play safe
        if unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
            local unicode = (lumunic and lumunic[name]) or (aglmap and aglmap[name])
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
                    unicode = unicodes[base] or (aglmap and aglmap[base])
                    if unicode then
                        if type(unicode) == "table" then
                            unicode = unicode[1]
                        end
                        originals[index], tounicode[index], ns = unicode, tounicode16(unicode), ns + 1
                    end
                else
                    local t = { }
                    for l=1,nplit do
                        local base = split[l]
                        local u = unicodes[base] or (aglmap and aglmap[base])
                        if not u then
                            break
                        elseif type(u) == "table" then
                            t[#t+1] = u[1]
                        else
                            t[#t+1] = u
                        end
                    end
                    if #t == 0 then -- done then
                        -- nothing
                    elseif #t == 1 then
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

-- the following is sort of obsolete
--
-- fonts.map.data      = fonts.map.data      or { }
-- fonts.map.encodings = fonts.map.encodings or { }
-- fonts.map.loaded    = fonts.map.loaded    or { }
-- fonts.map.line      = fonts.map.line      or { }
--
-- function fonts.map.line.pdftex(e)
--     if e.name and e.fontfile then
--         local fullname = e.fullname or ""
--         if e.slant and e.slant ~= 0 then
--             if e.encoding then
--                 pdf.mapline(format('= %s %s "%g SlantFont" <%s <%s',e.name,fullname,e.slant,e.encoding,e.fontfile)))
--             else
--                 pdf.mapline(format('= %s %s "%g SlantFont" <%s',e.name,fullname,e.slant,e.fontfile)))
--             end
--         elseif e.extend and e.extend ~= 1 and e.extend ~= 0 then
--             if e.encoding then
--                 pdf.mapline(format('= %s %s "%g ExtendFont" <%s <%s',e.name,fullname,e.extend,e.encoding,e.fontfile)))
--             else
--                 pdf.mapline(format('= %s %s "%g ExtendFont" <%s',e.name,fullname,e.extend,e.fontfile)))
--             end
--         else
--             if e.encoding then
--                 pdf.mapline(format('= %s %s <%s <%s',e.name,fullname,e.encoding,e.fontfile)))
--             else
--                 pdf.mapline(format('= %s %s <%s',e.name,fullname,e.fontfile)))
--             end
--         end
--     else
--         return nil
--     end
-- end
--
-- function fonts.map.flush(backend) -- will also erase the accumulated data
--     local flushline = fonts.map.line[backend or "pdftex"] or fonts.map.line.pdftex
--     for _, e in next, fonts.map.data do
--         flushline(e)
--     end
--     fonts.map.data = { }
-- end
--
-- fonts.map.line.dvips     = fonts.map.line.pdftex
-- fonts.map.line.dvipdfmx  = function() end
--
-- function fonts.map.convert_entries(filename)
--     if not fonts.map.loaded[filename] then
--         fonts.map.data, fonts.map.encodings = fonts.map.load_file(filename,fonts.map.data, fonts.map.encodings)
--         fonts.map.loaded[filename] = true
--     end
-- end
--
-- function fonts.map.load_file(filename, entries, encodings)
--     entries   = entries   or { }
--     encodings = encodings or { }
--     local f = io.open(filename)
--     if f then
--         local data = f:read("*a")
--         if data then
--             for line in gmatch(data,"(.-)[\n\t]") do
--                 if find(line,"^[%#%%%s]") then
--                     -- print(line)
--                 else
--                     local extend, slant, name, fullname, fontfile, encoding
--                     line = gsub(line,'"(.+)"', function(s)
--                         extend = find(s,'"([^"]+) ExtendFont"')
--                         slant = find(s,'"([^"]+) SlantFont"')
--                         return ""
--                     end)
--                     if not name then
--                         -- name fullname encoding fontfile
--                         name, fullname, encoding, fontfile = match(line,"^(%S+)%s+(%S*)[%s<]+(%S*)[%s<]+(%S*)%s*$")
--                     end
--                     if not name then
--                         -- name fullname (flag) fontfile encoding
--                         name, fullname, fontfile, encoding = match(line,"^(%S+)%s+(%S*)[%d%s<]+(%S*)[%s<]+(%S*)%s*$")
--                     end
--                     if not name then
--                         -- name fontfile
--                         name, fontfile = match(line,"^(%S+)%s+[%d%s<]+(%S*)%s*$")
--                     end
--                     if name then
--                         if encoding == "" then encoding = nil end
--                         entries[name] = {
--                             name     = name, -- handy
--                             fullname = fullname,
--                             encoding = encoding,
--                             fontfile = fontfile,
--                             slant    = tonumber(slant),
--                             extend   = tonumber(extend)
--                         }
--                         encodings[name] = encoding
--                     elseif line ~= "" then
--                     --  print(line)
--                     end
--                 end
--             end
--         end
--         f:close()
--     end
--     return entries, encodings
-- end

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

local concat, utfbyte = table.concat, utf.byte
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local abs = math.abs
local getn = table.getn
local lpegmatch = lpeg.match
local reverse = table.reverse
local ioflush = io.flush

local allocate = utilities.storage.allocate

local trace_private    = false  trackers.register("otf.private",    function(v) trace_private      = v end)
local trace_loading    = false  trackers.register("otf.loading",    function(v) trace_loading      = v end)
local trace_features   = false  trackers.register("otf.features",   function(v) trace_features     = v end)
local trace_dynamics   = false  trackers.register("otf.dynamics",   function(v) trace_dynamics     = v end)
local trace_sequences  = false  trackers.register("otf.sequences",  function(v) trace_sequences    = v end)
local trace_math       = false  trackers.register("otf.math",       function(v) trace_math         = v end)
local trace_defining   = false  trackers.register("fonts.defining", function(v) trace_defining     = v end)

local report_otf = logs.new("load otf")

local starttiming, stoptiming, elapsedtime = statistics.starttiming, statistics.stoptiming, statistics.elapsedtime

local fonts          = fonts

fonts.otf            = fonts.otf or { }
local otf            = fonts.otf
local tfm            = fonts.tfm

local fontdata       = fonts.ids
local chardata       = characters.data

otf.features         = otf.features         or { }
otf.features.list    = otf.features.list    or { }
otf.features.default = otf.features.default or { }

otf.enhancers        = allocate()
local enhancers      = otf.enhancers
enhancers.patches    = { }

local definers       = fonts.definers

otf.glists           = { "gsub", "gpos" }

otf.version          = 2.705 -- beware: also sync font-mis.lua
otf.cache            = containers.define("fonts", "otf", otf.version, true)

local loadmethod     = "table" -- table, mixed, sparse
local forceload      = false
local cleanup        = 0
local usemetatables  = false -- .4 slower on mk but 30 M less mem so we might change the default -- will be directive
local packdata       = true
local syncspace      = true
local forcenotdef    = false

local wildcard       = "*"
local default        = "dflt"

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

enhancers.patches.before = allocate()
enhancers.patches.after  = allocate()

local before = enhancers.patches.before
local after  = enhancers.patches.after

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

-- enhancers.patches.register("before","migrate metadata","cambria",function() end)

function enhancers.patches.register(what,where,pattern,action)
    local ww = what[where]
    if ww then
        ww[pattern] = action
    else
        ww = { [pattern] = action}
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
        filename = filename,
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

actions["prepare unicodes"] = function(data,filename,raw)
    local luatex = data.luatex
    local indices, unicodes, multiples, internals = { }, { }, { }, { }
    local mapmap = data.map or raw.map
    if not mapmap then
        report_otf("no map in %s",filename)
        mapmap = { }
        data.map = { map = mapmap }
    elseif not mapmap.map then
        report_otf("no unicode map in %s",filename)
        mapmap = { }
        data.map.map = mapmap
    else
        mapmap = mapmap.map
    end
    local criterium = fonts.privateoffset
    local private = criterium
    local glyphs = data.glyphs
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
            else
                -- message that something is wrong
            end
        end
    end
    -- beware: the indices table is used to initialize the tfm table
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
                        c.before = reverse(c.before)
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

local private_math_parameters = {
    "FractionDelimiterSize",
    "FractionDelimiterDisplayStyleSize",
}

actions["check math parameters"] = function(data,filename,raw)
    local mathdata = data.metadata.math
    if mathdata then
        for m=1,#private_math_parameters do
            local pmp = private_math_parameters[m]
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

function otf.features.register(name,default)
    otf.features.list[#otf.features.list+1] = name
    otf.features.default[name] = default
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

fonts.formats.dfont = "truetype"
fonts.formats.ttc   = "truetype"
fonts.formats.ttf   = "truetype"
fonts.formats.otf   = "opentype"

local function copytotfm(data,cache_id) -- we can save a copy when we reorder the tma to unicode (nasty due to one->many)
    if data then
        local glyphs, pfminfo, metadata = data.glyphs or { }, data.pfminfo or { }, data.metadata or { }
        local luatex = data.luatex
        local unicodes = luatex.unicodes -- names to unicodes
        local indices = luatex.indices        local mode = data.mode or "base"

        local characters, parameters, math_parameters, descriptions = { }, { }, { }, { }
        local designsize = metadata.designsize or metadata.design_size or 100
        if designsize == 0 then
            designsize = 100
        end
        local spaceunits, spacer = 500, "space"
        -- indices maps from unicodes to indices
        for u, i in next, indices do
            characters[u] = { } -- we need this because for instance we add protruding info and loop over characters
            descriptions[u] = glyphs[i]
        end
        -- math
        if metadata.math then
            -- parameters
            for name, value in next, metadata.math do
                math_parameters[name] = value
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
        local endash, emdash, space = 0x20, 0x2014, "space" -- unicodes['space'], unicodes['emdash']
        if metadata.isfixedpitch then
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        else
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width/2, "emdash/2"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits) or tfm.units/2 -- 500 -- brrr
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
        return {
            characters         = characters,
            parameters         = parameters,
            math_parameters    = math_parameters,
            descriptions       = descriptions,
            indices            = indices,
            unicodes           = unicodes,
            type               = "real",
            direction          = 0,
            boundarychar_label = 0,
            boundarychar       = 65536,
            designsize         = (designsize/10)*65536,
            spacer             = "500 units",
            encodingbytes      = 2,
            mode               = mode,
            filename           = filename,
            fontname           = fontname,
            fullname           = fullname,
            psname             = fontname or fullname,
            name               = filename or fullname,
            units              = units,
            format             = fonts.fontformat(filename,"opentype"),
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
                shared.processes, shared.features = otf.setfeatures(tfmdata,definers.check(features,otf.features.default))
            end
        end
        containers.write(tfm.cache,cache_id,tfmdata)
    end
    return tfmdata
end

otf.features.register('mathsize')

function tfm.read_from_otf(specification) -- wrong namespace
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

local report_otf = logs.new("load otf")

local fonts          = fonts
local otf            = fonts.otf
local fontdata       = fonts.ids

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

local report_prepare = logs.new("otf prepare")

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

local report_direct   = logs.new("otf direct")
local report_subchain = logs.new("otf subchain")
local report_chain    = logs.new("otf chain")
local report_process  = logs.new("otf process")
local report_prepare  = logs.new("otf prepare")

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

local split_at_space = lpeg.splitters[" "] or lpeg.Ct(lpeg.splitat(" ")) -- no trailing or multiple spaces anyway

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

local fontdata = fonts.ids

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

-- we cannot optimize with "start = first_character(head)" because then we don't
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
            num[#num+1] = format("U+%04X",ni)
            local dni = descriptions[ni]
            nam[#num] = (dni and dni.name) or "?"
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
        local r = math.random(1,n)
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
    local o, t, n = { }, { }, 0
    for s in gmatch(original,"[^ ]+") do
        local us = unicodes[s]
        if type(us) == "number" then -- tonumber(us)
            o[#o+1] = us
        else
            o[#o+1] = us[1]
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
    for n=1,#covers do
        local c = covers[n]
        local cc = cache[c]
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
            result[#result+1] = t
        else
            result[#result+1] = cc
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
            local old, new = unicode, { }
            local m = multiple[lookup]
            if not m then m = { } multiple[lookup] = m end
            m[old] = new
            for pc in gmatch(p[2],"[^ ]+") do
                local upc = unicodes[pc]
                if type(upc) == "number" then
                    new[#new+1] = upc
                else
                    new[#new+1] = upc[1]
                end
            end
        --~ if trace_lookups then
        --~     report_prepare("lookup %s: multiple %s => %s",lookup,old,concat(new," "))
        --~ end
        end,
        alternate = function(p,lookup,glyph,unicode)
            local old, new = unicode, { }
            local a = alternate[lookup]
            if not a then a = { } alternate[lookup] = a end
            a[old] = new
            for pc in gmatch(p[2],"[^ ]+") do
                local upc = unicodes[pc]
                if type(upc) == "number" then
                    new[#new+1] = upc
                else
                    new[#new+1] = upc[1]
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
                            local t = { }
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
                                        t[#t+1] = { nofrules, lookuptype, sequence, start, stop, rule.lookups }
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
                            local t = { }
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
                                        t[#t+1] = { nofrules, lookuptype, sequence, start, stop, rule.lookups, replacements }
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
                            local t = { }
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
                                        t[#t+1] = { nofrules, lookuptype, sequence, start, stop, rule.lookups }
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

local fontdata           = fonts.ids
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

local report_otf = logs.new("load otf")

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
    comment   = "Adobe Glyph List, version 2.0, September 20, 2002",
}

local allocate = utilities.storage.allocate

fonts.enc = fonts.enc or { }
local enc = fonts.enc
local agl = { }
enc.agl   = agl

agl.names = allocate { -- to name
    "controlSTX",
    "controlSOT",
    "controlETX",
    "controlEOT",
    "controlENQ",
    "controlACK",
    "controlBEL",
    "controlBS",
    "controlHT",
    "controlLF",
    "controlVT",
    "controlFF",
    "controlCR",
    "controlSO",
    "controlSI",
    "controlDLE",
    "controlDC1",
    "controlDC2",
    "controlDC3",
    "controlDC4",
    "controlNAK",
    "controlSYN",
    "controlETB",
    "controlCAN",
    "controlEM",
    "controlSUB",
    "controlESC",
    "controlFS",
    "controlGS",
    "controlRS",
    "controlUS",
    "spacehackarabic",
    "exclam",
    "quotedbl",
    "numbersign",
    "dollar",
    "percent",
    "ampersand",
    "quotesingle",
    "parenleft",
    "parenright",
    "asterisk",
    "plus",
    "comma",
    "hyphen",
    "period",
    "slash",
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "colon",
    "semicolon",
    "less",
    "equal",
    "greater",
    "question",
    "at",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "bracketleft",
    "backslash",
    "bracketright",
    "asciicircum",
    "underscore",
    "grave",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "braceleft",
    "verticalbar",
    "braceright",
    "asciitilde",
    "controlDEL",
    [0x00A0] = "nonbreakingspace",
    [0x00A1] = "exclamdown",
    [0x00A2] = "cent",
    [0x00A3] = "sterling",
    [0x00A4] = "currency",
    [0x00A5] = "yen",
    [0x00A6] = "brokenbar",
    [0x00A7] = "section",
    [0x00A8] = "dieresis",
    [0x00A9] = "copyright",
    [0x00AA] = "ordfeminine",
    [0x00AB] = "guillemotleft",
    [0x00AC] = "logicalnot",
    [0x00AD] = "softhyphen",
    [0x00AE] = "registered",
    [0x00AF] = "overscore",
    [0x00B0] = "degree",
    [0x00B1] = "plusminus",
    [0x00B2] = "twosuperior",
    [0x00B3] = "threesuperior",
    [0x00B4] = "acute",
    [0x00B5] = "mu1",
    [0x00B6] = "paragraph",
    [0x00B7] = "periodcentered",
    [0x00B8] = "cedilla",
    [0x00B9] = "onesuperior",
    [0x00BA] = "ordmasculine",
    [0x00BB] = "guillemotright",
    [0x00BC] = "onequarter",
    [0x00BD] = "onehalf",
    [0x00BE] = "threequarters",
    [0x00BF] = "questiondown",
    [0x00C0] = "Agrave",
    [0x00C1] = "Aacute",
    [0x00C2] = "Acircumflex",
    [0x00C3] = "Atilde",
    [0x00C4] = "Adieresis",
    [0x00C5] = "Aring",
    [0x00C6] = "AE",
    [0x00C7] = "Ccedilla",
    [0x00C8] = "Egrave",
    [0x00C9] = "Eacute",
    [0x00CA] = "Ecircumflex",
    [0x00CB] = "Edieresis",
    [0x00CC] = "Igrave",
    [0x00CD] = "Iacute",
    [0x00CE] = "Icircumflex",
    [0x00CF] = "Idieresis",
    [0x00D0] = "Eth",
    [0x00D1] = "Ntilde",
    [0x00D2] = "Ograve",
    [0x00D3] = "Oacute",
    [0x00D4] = "Ocircumflex",
    [0x00D5] = "Otilde",
    [0x00D6] = "Odieresis",
    [0x00D7] = "multiply",
    [0x00D8] = "Oslash",
    [0x00D9] = "Ugrave",
    [0x00DA] = "Uacute",
    [0x00DB] = "Ucircumflex",
    [0x00DC] = "Udieresis",
    [0x00DD] = "Yacute",
    [0x00DE] = "Thorn",
    [0x00DF] = "germandbls",
    [0x00E0] = "agrave",
    [0x00E1] = "aacute",
    [0x00E2] = "acircumflex",
    [0x00E3] = "atilde",
    [0x00E4] = "adieresis",
    [0x00E5] = "aring",
    [0x00E6] = "ae",
    [0x00E7] = "ccedilla",
    [0x00E8] = "egrave",
    [0x00E9] = "eacute",
    [0x00EA] = "ecircumflex",
    [0x00EB] = "edieresis",
    [0x00EC] = "igrave",
    [0x00ED] = "iacute",
    [0x00EE] = "icircumflex",
    [0x00EF] = "idieresis",
    [0x00F0] = "eth",
    [0x00F1] = "ntilde",
    [0x00F2] = "ograve",
    [0x00F3] = "oacute",
    [0x00F4] = "ocircumflex",
    [0x00F5] = "otilde",
    [0x00F6] = "odieresis",
    [0x00F7] = "divide",
    [0x00F8] = "oslash",
    [0x00F9] = "ugrave",
    [0x00FA] = "uacute",
    [0x00FB] = "ucircumflex",
    [0x00FC] = "udieresis",
    [0x00FD] = "yacute",
    [0x00FE] = "thorn",
    [0x00FF] = "ydieresis",
    [0x0100] = "Amacron",
    [0x0101] = "amacron",
    [0x0102] = "Abreve",
    [0x0103] = "abreve",
    [0x0104] = "Aogonek",
    [0x0105] = "aogonek",
    [0x0106] = "Cacute",
    [0x0107] = "cacute",
    [0x0108] = "Ccircumflex",
    [0x0109] = "ccircumflex",
    [0x010A] = "Cdotaccent",
    [0x010B] = "cdotaccent",
    [0x010C] = "Ccaron",
    [0x010D] = "ccaron",
    [0x010E] = "Dcaron",
    [0x010F] = "dcaron",
    [0x0110] = "Dslash",
    [0x0111] = "dmacron",
    [0x0112] = "Emacron",
    [0x0113] = "emacron",
    [0x0114] = "Ebreve",
    [0x0115] = "ebreve",
    [0x0116] = "Edotaccent",
    [0x0117] = "edotaccent",
    [0x0118] = "Eogonek",
    [0x0119] = "eogonek",
    [0x011A] = "Ecaron",
    [0x011B] = "ecaron",
    [0x011C] = "Gcircumflex",
    [0x011D] = "gcircumflex",
    [0x011E] = "Gbreve",
    [0x011F] = "gbreve",
    [0x0120] = "Gdotaccent",
    [0x0121] = "gdotaccent",
    [0x0122] = "Gcommaaccent",
    [0x0123] = "gcommaaccent",
    [0x0124] = "Hcircumflex",
    [0x0125] = "hcircumflex",
    [0x0126] = "Hbar",
    [0x0127] = "hbar",
    [0x0128] = "Itilde",
    [0x0129] = "itilde",
    [0x012A] = "Imacron",
    [0x012B] = "imacron",
    [0x012C] = "Ibreve",
    [0x012D] = "ibreve",
    [0x012E] = "Iogonek",
    [0x012F] = "iogonek",
    [0x0130] = "Idotaccent",
    [0x0131] = "dotlessi",
    [0x0132] = "IJ",
    [0x0133] = "ij",
    [0x0134] = "Jcircumflex",
    [0x0135] = "jcircumflex",
    [0x0136] = "Kcommaaccent",
    [0x0137] = "kcommaaccent",
    [0x0138] = "kgreenlandic",
    [0x0139] = "Lacute",
    [0x013A] = "lacute",
    [0x013B] = "Lcommaaccent",
    [0x013C] = "lcommaaccent",
    [0x013D] = "Lcaron",
    [0x013E] = "lcaron",
    [0x013F] = "Ldotaccent",
    [0x0140] = "ldotaccent",
    [0x0141] = "Lslash",
    [0x0142] = "lslash",
    [0x0143] = "Nacute",
    [0x0144] = "nacute",
    [0x0145] = "Ncommaaccent",
    [0x0146] = "ncommaaccent",
    [0x0147] = "Ncaron",
    [0x0148] = "ncaron",
    [0x0149] = "quoterightn",
    [0x014A] = "Eng",
    [0x014B] = "eng",
    [0x014C] = "Omacron",
    [0x014D] = "omacron",
    [0x014E] = "Obreve",
    [0x014F] = "obreve",
    [0x0150] = "Ohungarumlaut",
    [0x0151] = "ohungarumlaut",
    [0x0152] = "OE",
    [0x0153] = "oe",
    [0x0154] = "Racute",
    [0x0155] = "racute",
    [0x0156] = "Rcommaaccent",
    [0x0157] = "rcommaaccent",
    [0x0158] = "Rcaron",
    [0x0159] = "rcaron",
    [0x015A] = "Sacute",
    [0x015B] = "sacute",
    [0x015C] = "Scircumflex",
    [0x015D] = "scircumflex",
    [0x015E] = "Scedilla",
    [0x015F] = "scedilla",
    [0x0160] = "Scaron",
    [0x0161] = "scaron",
    [0x0162] = "Tcommaaccent",
    [0x0163] = "tcommaaccent",
    [0x0164] = "Tcaron",
    [0x0165] = "tcaron",
    [0x0166] = "Tbar",
    [0x0167] = "tbar",
    [0x0168] = "Utilde",
    [0x0169] = "utilde",
    [0x016A] = "Umacron",
    [0x016B] = "umacron",
    [0x016C] = "Ubreve",
    [0x016D] = "ubreve",
    [0x016E] = "Uring",
    [0x016F] = "uring",
    [0x0170] = "Uhungarumlaut",
    [0x0171] = "uhungarumlaut",
    [0x0172] = "Uogonek",
    [0x0173] = "uogonek",
    [0x0174] = "Wcircumflex",
    [0x0175] = "wcircumflex",
    [0x0176] = "Ycircumflex",
    [0x0177] = "ycircumflex",
    [0x0178] = "Ydieresis",
    [0x0179] = "Zacute",
    [0x017A] = "zacute",
    [0x017B] = "Zdotaccent",
    [0x017C] = "zdotaccent",
    [0x017D] = "Zcaron",
    [0x017E] = "zcaron",
    [0x017F] = "slong",
    [0x0180] = "bstroke",
    [0x0181] = "Bhook",
    [0x0182] = "Btopbar",
    [0x0183] = "btopbar",
    [0x0184] = "Tonesix",
    [0x0185] = "tonesix",
    [0x0186] = "Oopen",
    [0x0187] = "Chook",
    [0x0188] = "chook",
    [0x0189] = "Dafrican",
    [0x018A] = "Dhook",
    [0x018B] = "Dtopbar",
    [0x018C] = "dtopbar",
    [0x018D] = "deltaturned",
    [0x018E] = "Ereversed",
    [0x018F] = "Schwa",
    [0x0190] = "Eopen",
    [0x0191] = "Fhook",
    [0x0192] = "florin",
    [0x0193] = "Ghook",
    [0x0194] = "Gammaafrican",
    [0x0195] = "hv",
    [0x0196] = "Iotaafrican",
    [0x0197] = "Istroke",
    [0x0198] = "Khook",
    [0x0199] = "khook",
    [0x019A] = "lbar",
    [0x019B] = "lambdastroke",
    [0x019C] = "Mturned",
    [0x019D] = "Nhookleft",
    [0x019E] = "nlegrightlong",
    [0x019F] = "Ocenteredtilde",
    [0x01A0] = "Ohorn",
    [0x01A1] = "ohorn",
    [0x01A2] = "Oi",
    [0x01A3] = "oi",
    [0x01A4] = "Phook",
    [0x01A5] = "phook",
    [0x01A6] = "yr",
    [0x01A7] = "Tonetwo",
    [0x01A8] = "tonetwo",
    [0x01A9] = "Esh",
    [0x01AA] = "eshreversedloop",
    [0x01AB] = "tpalatalhook",
    [0x01AC] = "Thook",
    [0x01AD] = "thook",
    [0x01AE] = "Tretroflexhook",
    [0x01AF] = "Uhorn",
    [0x01B0] = "uhorn",
    [0x01B1] = "Upsilonafrican",
    [0x01B2] = "Vhook",
    [0x01B3] = "Yhook",
    [0x01B4] = "yhook",
    [0x01B5] = "Zstroke",
    [0x01B6] = "zstroke",
    [0x01B7] = "Ezh",
    [0x01B8] = "Ezhreversed",
    [0x01B9] = "ezhreversed",
    [0x01BA] = "ezhtail",
    [0x01BB] = "twostroke",
    [0x01BC] = "Tonefive",
    [0x01BD] = "tonefive",
    [0x01BE] = "glottalinvertedstroke",
    [0x01BF] = "wynn",
    [0x01C0] = "clickdental",
    [0x01C1] = "clicklateral",
    [0x01C2] = "clickalveolar",
    [0x01C3] = "clickretroflex",
    [0x01C4] = "DZcaron",
    [0x01C5] = "Dzcaron",
    [0x01C6] = "dzcaron",
    [0x01C7] = "LJ",
    [0x01C8] = "Lj",
    [0x01C9] = "lj",
    [0x01CA] = "NJ",
    [0x01CB] = "Nj",
    [0x01CC] = "nj",
    [0x01CD] = "Acaron",
    [0x01CE] = "acaron",
    [0x01CF] = "Icaron",
    [0x01D0] = "icaron",
    [0x01D1] = "Ocaron",
    [0x01D2] = "ocaron",
    [0x01D3] = "Ucaron",
    [0x01D4] = "ucaron",
    [0x01D5] = "Udieresismacron",
    [0x01D6] = "udieresismacron",
    [0x01D7] = "Udieresisacute",
    [0x01D8] = "udieresisacute",
    [0x01D9] = "Udieresiscaron",
    [0x01DA] = "udieresiscaron",
    [0x01DB] = "Udieresisgrave",
    [0x01DC] = "udieresisgrave",
    [0x01DD] = "eturned",
    [0x01DE] = "Adieresismacron",
    [0x01DF] = "adieresismacron",
    [0x01E0] = "Adotmacron",
    [0x01E1] = "adotmacron",
    [0x01E2] = "AEmacron",
    [0x01E3] = "aemacron",
    [0x01E4] = "Gstroke",
    [0x01E5] = "gstroke",
    [0x01E6] = "Gcaron",
    [0x01E7] = "gcaron",
    [0x01E8] = "Kcaron",
    [0x01E9] = "kcaron",
    [0x01EA] = "Oogonek",
    [0x01EB] = "oogonek",
    [0x01EC] = "Oogonekmacron",
    [0x01ED] = "oogonekmacron",
    [0x01EE] = "Ezhcaron",
    [0x01EF] = "ezhcaron",
    [0x01F0] = "jcaron",
    [0x01F1] = "DZ",
    [0x01F2] = "Dz",
    [0x01F3] = "dz",
    [0x01F4] = "Gacute",
    [0x01F5] = "gacute",
    [0x01FA] = "Aringacute",
    [0x01FB] = "aringacute",
    [0x01FC] = "AEacute",
    [0x01FD] = "aeacute",
    [0x01FE] = "Ostrokeacute",
    [0x01FF] = "ostrokeacute",
    [0x0200] = "Adblgrave",
    [0x0201] = "adblgrave",
    [0x0202] = "Ainvertedbreve",
    [0x0203] = "ainvertedbreve",
    [0x0204] = "Edblgrave",
    [0x0205] = "edblgrave",
    [0x0206] = "Einvertedbreve",
    [0x0207] = "einvertedbreve",
    [0x0208] = "Idblgrave",
    [0x0209] = "idblgrave",
    [0x020A] = "Iinvertedbreve",
    [0x020B] = "iinvertedbreve",
    [0x020C] = "Odblgrave",
    [0x020D] = "odblgrave",
    [0x020E] = "Oinvertedbreve",
    [0x020F] = "oinvertedbreve",
    [0x0210] = "Rdblgrave",
    [0x0211] = "rdblgrave",
    [0x0212] = "Rinvertedbreve",
    [0x0213] = "rinvertedbreve",
    [0x0214] = "Udblgrave",
    [0x0215] = "udblgrave",
    [0x0216] = "Uinvertedbreve",
    [0x0217] = "uinvertedbreve",
    [0x0218] = "Scommaaccent",
    [0x0219] = "scommaaccent",
    [0x0250] = "aturned",
    [0x0251] = "ascript",
    [0x0252] = "ascriptturned",
    [0x0253] = "bhook",
    [0x0254] = "oopen",
    [0x0255] = "ccurl",
    [0x0256] = "dtail",
    [0x0257] = "dhook",
    [0x0258] = "ereversed",
    [0x0259] = "schwa",
    [0x025A] = "schwahook",
    [0x025B] = "eopen",
    [0x025C] = "eopenreversed",
    [0x025D] = "eopenreversedhook",
    [0x025E] = "eopenreversedclosed",
    [0x025F] = "jdotlessstroke",
    [0x0260] = "ghook",
    [0x0261] = "gscript",
    [0x0263] = "gammalatinsmall",
    [0x0264] = "ramshorn",
    [0x0265] = "hturned",
    [0x0266] = "hhook",
    [0x0267] = "henghook",
    [0x0268] = "istroke",
    [0x0269] = "iotalatin",
    [0x026B] = "lmiddletilde",
    [0x026C] = "lbelt",
    [0x026D] = "lhookretroflex",
    [0x026E] = "lezh",
    [0x026F] = "mturned",
    [0x0270] = "mlonglegturned",
    [0x0271] = "mhook",
    [0x0272] = "nhookleft",
    [0x0273] = "nhookretroflex",
    [0x0275] = "obarred",
    [0x0277] = "omegalatinclosed",
    [0x0278] = "philatin",
    [0x0279] = "rturned",
    [0x027A] = "rlonglegturned",
    [0x027B] = "rhookturned",
    [0x027C] = "rlongleg",
    [0x027D] = "rhook",
    [0x027E] = "rfishhook",
    [0x027F] = "rfishhookreversed",
    [0x0281] = "Rsmallinverted",
    [0x0282] = "shook",
    [0x0283] = "esh",
    [0x0284] = "dotlessjstrokehook",
    [0x0285] = "eshsquatreversed",
    [0x0286] = "eshcurl",
    [0x0287] = "tturned",
    [0x0288] = "tretroflexhook",
    [0x0289] = "ubar",
    [0x028A] = "upsilonlatin",
    [0x028B] = "vhook",
    [0x028C] = "vturned",
    [0x028D] = "wturned",
    [0x028E] = "yturned",
    [0x0290] = "zretroflexhook",
    [0x0291] = "zcurl",
    [0x0292] = "ezh",
    [0x0293] = "ezhcurl",
    [0x0294] = "glottalstop",
    [0x0295] = "glottalstopreversed",
    [0x0296] = "glottalstopinverted",
    [0x0297] = "cstretched",
    [0x0298] = "bilabialclick",
    [0x029A] = "eopenclosed",
    [0x029B] = "Gsmallhook",
    [0x029D] = "jcrossedtail",
    [0x029E] = "kturned",
    [0x02A0] = "qhook",
    [0x02A1] = "glottalstopstroke",
    [0x02A2] = "glottalstopstrokereversed",
    [0x02A3] = "dzaltone",
    [0x02A4] = "dezh",
    [0x02A5] = "dzcurl",
    [0x02A6] = "ts",
    [0x02A7] = "tesh",
    [0x02A8] = "tccurl",
    [0x02B0] = "hsuperior",
    [0x02B1] = "hhooksuperior",
    [0x02B2] = "jsuperior",
    [0x02B4] = "rturnedsuperior",
    [0x02B5] = "rhookturnedsuperior",
    [0x02B6] = "Rsmallinvertedsuperior",
    [0x02B7] = "wsuperior",
    [0x02B8] = "ysuperior",
    [0x02B9] = "primemod",
    [0x02BA] = "dblprimemod",
    [0x02BB] = "commaturnedmod",
    [0x02BC] = "apostrophemod",
    [0x02BD] = "commareversedmod",
    [0x02BE] = "ringhalfright",
    [0x02BF] = "ringhalfleft",
    [0x02C0] = "glottalstopmod",
    [0x02C1] = "glottalstopreversedmod",
    [0x02C2] = "arrowheadleftmod",
    [0x02C3] = "arrowheadrightmod",
    [0x02C4] = "arrowheadupmod",
    [0x02C5] = "arrowheaddownmod",
    [0x02C6] = "circumflex",
    [0x02C7] = "caron",
    [0x02C8] = "verticallinemod",
    [0x02C9] = "firsttonechinese",
    [0x02CA] = "secondtonechinese",
    [0x02CB] = "fourthtonechinese",
    [0x02CC] = "verticallinelowmod",
    [0x02CD] = "macronlowmod",
    [0x02CE] = "gravelowmod",
    [0x02CF] = "acutelowmod",
    [0x02D0] = "colontriangularmod",
    [0x02D1] = "colontriangularhalfmod",
    [0x02D2] = "ringhalfrightcentered",
    [0x02D3] = "ringhalfleftcentered",
    [0x02D4] = "uptackmod",
    [0x02D5] = "downtackmod",
    [0x02D6] = "plusmod",
    [0x02D7] = "minusmod",
    [0x02D8] = "breve",
    [0x02D9] = "dotaccent",
    [0x02DA] = "ring",
    [0x02DB] = "ogonek",
    [0x02DC] = "tilde",
    [0x02DD] = "hungarumlaut",
    [0x02DE] = "rhotichookmod",
    [0x02E0] = "gammasuperior",
    [0x02E3] = "xsuperior",
    [0x02E4] = "glottalstopreversedsuperior",
    [0x02E5] = "tonebarextrahighmod",
    [0x02E6] = "tonebarhighmod",
    [0x02E7] = "tonebarmidmod",
    [0x02E8] = "tonebarlowmod",
    [0x02E9] = "tonebarextralowmod",
    [0x0300] = "gravecomb",
    [0x0301] = "acutecomb",
    [0x0302] = "circumflexcmb",
    [0x0303] = "tildecomb",
    [0x0304] = "macroncmb",
    [0x0305] = "overlinecmb",
    [0x0306] = "brevecmb",
    [0x0307] = "dotaccentcmb",
    [0x0308] = "dieresiscmb",
    [0x0309] = "hookcmb",
    [0x030A] = "ringcmb",
    [0x030B] = "hungarumlautcmb",
    [0x030C] = "caroncmb",
    [0x030D] = "verticallineabovecmb",
    [0x030E] = "dblverticallineabovecmb",
    [0x030F] = "dblgravecmb",
    [0x0310] = "candrabinducmb",
    [0x0311] = "breveinvertedcmb",
    [0x0312] = "commaturnedabovecmb",
    [0x0313] = "commaabovecmb",
    [0x0314] = "commareversedabovecmb",
    [0x0315] = "commaaboverightcmb",
    [0x0316] = "gravebelowcmb",
    [0x0317] = "acutebelowcmb",
    [0x0318] = "lefttackbelowcmb",
    [0x0319] = "righttackbelowcmb",
    [0x031A] = "leftangleabovecmb",
    [0x031B] = "horncmb",
    [0x031C] = "ringhalfleftbelowcmb",
    [0x031D] = "uptackbelowcmb",
    [0x031E] = "downtackbelowcmb",
    [0x031F] = "plusbelowcmb",
    [0x0320] = "minusbelowcmb",
    [0x0321] = "hookpalatalizedbelowcmb",
    [0x0322] = "hookretroflexbelowcmb",
    [0x0323] = "dotbelowcomb",
    [0x0324] = "dieresisbelowcmb",
    [0x0325] = "ringbelowcmb",
    [0x0327] = "cedillacmb",
    [0x0328] = "ogonekcmb",
    [0x0329] = "verticallinebelowcmb",
    [0x032A] = "bridgebelowcmb",
    [0x032B] = "dblarchinvertedbelowcmb",
    [0x032C] = "caronbelowcmb",
    [0x032D] = "circumflexbelowcmb",
    [0x032E] = "brevebelowcmb",
    [0x032F] = "breveinvertedbelowcmb",
    [0x0330] = "tildebelowcmb",
    [0x0331] = "macronbelowcmb",
    [0x0332] = "lowlinecmb",
    [0x0333] = "dbllowlinecmb",
    [0x0334] = "tildeoverlaycmb",
    [0x0335] = "strokeshortoverlaycmb",
    [0x0336] = "strokelongoverlaycmb",
    [0x0337] = "solidusshortoverlaycmb",
    [0x0338] = "soliduslongoverlaycmb",
    [0x0339] = "ringhalfrightbelowcmb",
    [0x033A] = "bridgeinvertedbelowcmb",
    [0x033B] = "squarebelowcmb",
    [0x033C] = "seagullbelowcmb",
    [0x033D] = "xabovecmb",
    [0x033E] = "tildeverticalcmb",
    [0x033F] = "dbloverlinecmb",
    [0x0340] = "gravetonecmb",
    [0x0341] = "acutetonecmb",
    [0x0342] = "perispomenigreekcmb",
    [0x0343] = "koroniscmb",
    [0x0344] = "dialytikatonoscmb",
    [0x0345] = "ypogegrammenigreekcmb",
    [0x0360] = "tildedoublecmb",
    [0x0361] = "breveinverteddoublecmb",
    [0x0374] = "numeralsigngreek",
    [0x0375] = "numeralsignlowergreek",
    [0x037A] = "ypogegrammeni",
    [0x037E] = "questiongreek",
    [0x0384] = "tonos",
    [0x0385] = "dieresistonos",
    [0x0386] = "Alphatonos",
    [0x0387] = "anoteleia",
    [0x0388] = "Epsilontonos",
    [0x0389] = "Etatonos",
    [0x038A] = "Iotatonos",
    [0x038C] = "Omicrontonos",
    [0x038E] = "Upsilontonos",
    [0x038F] = "Omegatonos",
    [0x0390] = "iotadieresistonos",
    [0x0391] = "Alpha",
    [0x0392] = "Beta",
    [0x0393] = "Gamma",
    [0x0394] = "Deltagreek",
    [0x0395] = "Epsilon",
    [0x0396] = "Zeta",
    [0x0397] = "Eta",
    [0x0398] = "Theta",
    [0x0399] = "Iota",
    [0x039A] = "Kappa",
    [0x039B] = "Lambda",
    [0x039C] = "Mu",
    [0x039D] = "Nu",
    [0x039E] = "Xi",
    [0x039F] = "Omicron",
    [0x03A0] = "Pi",
    [0x03A1] = "Rho",
    [0x03A3] = "Sigma",
    [0x03A4] = "Tau",
    [0x03A5] = "Upsilon",
    [0x03A6] = "Phi",
    [0x03A7] = "Chi",
    [0x03A8] = "Psi",
    [0x03A9] = "Omegagreek",
    [0x03AA] = "Iotadieresis",
    [0x03AB] = "Upsilondieresis",
    [0x03AC] = "alphatonos",
    [0x03AD] = "epsilontonos",
    [0x03AE] = "etatonos",
    [0x03AF] = "iotatonos",
    [0x03B0] = "upsilondieresistonos",
    [0x03B1] = "alpha",
    [0x03B2] = "beta",
    [0x03B3] = "gamma",
    [0x03B4] = "delta",
    [0x03B5] = "epsilon",
    [0x03B6] = "zeta",
    [0x03B7] = "eta",
    [0x03B8] = "theta",
    [0x03B9] = "iota",
    [0x03BA] = "kappa",
    [0x03BB] = "lambda",
    [0x03BC] = "mugreek",
    [0x03BD] = "nu",
    [0x03BE] = "xi",
    [0x03BF] = "omicron",
    [0x03C0] = "pi",
    [0x03C1] = "rho",
    [0x03C2] = "sigmafinal",
    [0x03C3] = "sigma",
    [0x03C4] = "tau",
    [0x03C5] = "upsilon",
    [0x03C6] = "phi",
    [0x03C7] = "chi",
    [0x03C8] = "psi",
    [0x03C9] = "omega",
    [0x03CA] = "iotadieresis",
    [0x03CB] = "upsilondieresis",
    [0x03CC] = "omicrontonos",
    [0x03CD] = "upsilontonos",
    [0x03CE] = "omegatonos",
    [0x03D0] = "betasymbolgreek",
    [0x03D1] = "thetasymbolgreek",
    [0x03D2] = "Upsilonhooksymbol",
    [0x03D3] = "Upsilonacutehooksymbolgreek",
    [0x03D4] = "Upsilondieresishooksymbolgreek",
    [0x03D5] = "phisymbolgreek",
    [0x03D6] = "pisymbolgreek",
    [0x03DA] = "Stigmagreek",
    [0x03DC] = "Digammagreek",
    [0x03DE] = "Koppagreek",
    [0x03E0] = "Sampigreek",
    [0x03E2] = "Sheicoptic",
    [0x03E3] = "sheicoptic",
    [0x03E4] = "Feicoptic",
    [0x03E5] = "feicoptic",
    [0x03E6] = "Kheicoptic",
    [0x03E7] = "kheicoptic",
    [0x03E8] = "Horicoptic",
    [0x03E9] = "horicoptic",
    [0x03EA] = "Gangiacoptic",
    [0x03EB] = "gangiacoptic",
    [0x03EC] = "Shimacoptic",
    [0x03ED] = "shimacoptic",
    [0x03EE] = "Deicoptic",
    [0x03EF] = "deicoptic",
    [0x03F0] = "kappasymbolgreek",
    [0x03F1] = "rhosymbolgreek",
    [0x03F2] = "sigmalunatesymbolgreek",
    [0x03F3] = "yotgreek",
    [0x0401] = "afii10023",
    [0x0402] = "afii10051",
    [0x0403] = "afii10052",
    [0x0404] = "afii10053",
    [0x0405] = "afii10054",
    [0x0406] = "afii10055",
    [0x0407] = "afii10056",
    [0x0408] = "afii10057",
    [0x0409] = "afii10058",
    [0x040A] = "afii10059",
    [0x040B] = "afii10060",
    [0x040C] = "afii10061",
    [0x040E] = "afii10062",
    [0x040F] = "afii10145",
    [0x0410] = "afii10017",
    [0x0411] = "afii10018",
    [0x0412] = "afii10019",
    [0x0413] = "afii10020",
    [0x0414] = "afii10021",
    [0x0415] = "afii10022",
    [0x0416] = "afii10024",
    [0x0417] = "afii10025",
    [0x0418] = "afii10026",
    [0x0419] = "afii10027",
    [0x041A] = "afii10028",
    [0x041B] = "afii10029",
    [0x041C] = "afii10030",
    [0x041D] = "afii10031",
    [0x041E] = "afii10032",
    [0x041F] = "afii10033",
    [0x0420] = "afii10034",
    [0x0421] = "afii10035",
    [0x0422] = "afii10036",
    [0x0423] = "afii10037",
    [0x0424] = "afii10038",
    [0x0425] = "afii10039",
    [0x0426] = "afii10040",
    [0x0427] = "afii10041",
    [0x0428] = "afii10042",
    [0x0429] = "afii10043",
    [0x042A] = "afii10044",
    [0x042B] = "afii10045",
    [0x042C] = "afii10046",
    [0x042D] = "afii10047",
    [0x042E] = "afii10048",
    [0x042F] = "afii10049",
    [0x0430] = "afii10065",
    [0x0431] = "becyrillic",
    [0x0432] = "vecyrillic",
    [0x0433] = "gecyrillic",
    [0x0434] = "decyrillic",
    [0x0435] = "iecyrillic",
    [0x0436] = "zhecyrillic",
    [0x0437] = "zecyrillic",
    [0x0438] = "iicyrillic",
    [0x0439] = "iishortcyrillic",
    [0x043A] = "kacyrillic",
    [0x043B] = "elcyrillic",
    [0x043C] = "emcyrillic",
    [0x043D] = "encyrillic",
    [0x043E] = "ocyrillic",
    [0x043F] = "pecyrillic",
    [0x0440] = "ercyrillic",
    [0x0441] = "escyrillic",
    [0x0442] = "tecyrillic",
    [0x0443] = "ucyrillic",
    [0x0444] = "efcyrillic",
    [0x0445] = "khacyrillic",
    [0x0446] = "tsecyrillic",
    [0x0447] = "checyrillic",
    [0x0448] = "shacyrillic",
    [0x0449] = "shchacyrillic",
    [0x044A] = "hardsigncyrillic",
    [0x044B] = "yericyrillic",
    [0x044C] = "softsigncyrillic",
    [0x044D] = "ereversedcyrillic",
    [0x044E] = "iucyrillic",
    [0x044F] = "iacyrillic",
    [0x0451] = "iocyrillic",
    [0x0452] = "djecyrillic",
    [0x0453] = "gjecyrillic",
    [0x0454] = "ecyrillic",
    [0x0455] = "dzecyrillic",
    [0x0456] = "icyrillic",
    [0x0457] = "yicyrillic",
    [0x0458] = "jecyrillic",
    [0x0459] = "ljecyrillic",
    [0x045A] = "njecyrillic",
    [0x045B] = "tshecyrillic",
    [0x045C] = "kjecyrillic",
    [0x045E] = "ushortcyrillic",
    [0x045F] = "dzhecyrillic",
    [0x0460] = "Omegacyrillic",
    [0x0461] = "omegacyrillic",
    [0x0462] = "afii10146",
    [0x0463] = "yatcyrillic",
    [0x0464] = "Eiotifiedcyrillic",
    [0x0465] = "eiotifiedcyrillic",
    [0x0466] = "Yuslittlecyrillic",
    [0x0467] = "yuslittlecyrillic",
    [0x0468] = "Yuslittleiotifiedcyrillic",
    [0x0469] = "yuslittleiotifiedcyrillic",
    [0x046A] = "Yusbigcyrillic",
    [0x046B] = "yusbigcyrillic",
    [0x046C] = "Yusbigiotifiedcyrillic",
    [0x046D] = "yusbigiotifiedcyrillic",
    [0x046E] = "Ksicyrillic",
    [0x046F] = "ksicyrillic",
    [0x0470] = "Psicyrillic",
    [0x0471] = "psicyrillic",
    [0x0472] = "afii10147",
    [0x0473] = "fitacyrillic",
    [0x0474] = "afii10148",
    [0x0475] = "izhitsacyrillic",
    [0x0476] = "Izhitsadblgravecyrillic",
    [0x0477] = "izhitsadblgravecyrillic",
    [0x0478] = "Ukcyrillic",
    [0x0479] = "ukcyrillic",
    [0x047A] = "Omegaroundcyrillic",
    [0x047B] = "omegaroundcyrillic",
    [0x047C] = "Omegatitlocyrillic",
    [0x047D] = "omegatitlocyrillic",
    [0x047E] = "Otcyrillic",
    [0x047F] = "otcyrillic",
    [0x0480] = "Koppacyrillic",
    [0x0481] = "koppacyrillic",
    [0x0482] = "thousandcyrillic",
    [0x0483] = "titlocyrilliccmb",
    [0x0484] = "palatalizationcyrilliccmb",
    [0x0485] = "dasiapneumatacyrilliccmb",
    [0x0486] = "psilipneumatacyrilliccmb",
    [0x0490] = "afii10050",
    [0x0491] = "gheupturncyrillic",
    [0x0492] = "Ghestrokecyrillic",
    [0x0493] = "ghestrokecyrillic",
    [0x0494] = "Ghemiddlehookcyrillic",
    [0x0495] = "ghemiddlehookcyrillic",
    [0x0496] = "Zhedescendercyrillic",
    [0x0497] = "zhedescendercyrillic",
    [0x0498] = "Zedescendercyrillic",
    [0x0499] = "zedescendercyrillic",
    [0x049A] = "Kadescendercyrillic",
    [0x049B] = "kadescendercyrillic",
    [0x049C] = "Kaverticalstrokecyrillic",
    [0x049D] = "kaverticalstrokecyrillic",
    [0x049E] = "Kastrokecyrillic",
    [0x049F] = "kastrokecyrillic",
    [0x04A0] = "Kabashkircyrillic",
    [0x04A1] = "kabashkircyrillic",
    [0x04A2] = "Endescendercyrillic",
    [0x04A3] = "endescendercyrillic",
    [0x04A4] = "Enghecyrillic",
    [0x04A5] = "enghecyrillic",
    [0x04A6] = "Pemiddlehookcyrillic",
    [0x04A7] = "pemiddlehookcyrillic",
    [0x04A8] = "Haabkhasiancyrillic",
    [0x04A9] = "haabkhasiancyrillic",
    [0x04AA] = "Esdescendercyrillic",
    [0x04AB] = "esdescendercyrillic",
    [0x04AC] = "Tedescendercyrillic",
    [0x04AD] = "tedescendercyrillic",
    [0x04AE] = "Ustraightcyrillic",
    [0x04AF] = "ustraightcyrillic",
    [0x04B0] = "Ustraightstrokecyrillic",
    [0x04B1] = "ustraightstrokecyrillic",
    [0x04B2] = "Hadescendercyrillic",
    [0x04B3] = "hadescendercyrillic",
    [0x04B4] = "Tetsecyrillic",
    [0x04B5] = "tetsecyrillic",
    [0x04B6] = "Chedescendercyrillic",
    [0x04B7] = "chedescendercyrillic",
    [0x04B8] = "Cheverticalstrokecyrillic",
    [0x04B9] = "cheverticalstrokecyrillic",
    [0x04BA] = "Shhacyrillic",
    [0x04BB] = "shhacyrillic",
    [0x04BC] = "Cheabkhasiancyrillic",
    [0x04BD] = "cheabkhasiancyrillic",
    [0x04BE] = "Chedescenderabkhasiancyrillic",
    [0x04BF] = "chedescenderabkhasiancyrillic",
    [0x04C0] = "palochkacyrillic",
    [0x04C1] = "Zhebrevecyrillic",
    [0x04C2] = "zhebrevecyrillic",
    [0x04C3] = "Kahookcyrillic",
    [0x04C4] = "kahookcyrillic",
    [0x04C7] = "Enhookcyrillic",
    [0x04C8] = "enhookcyrillic",
    [0x04CB] = "Chekhakassiancyrillic",
    [0x04CC] = "chekhakassiancyrillic",
    [0x04D0] = "Abrevecyrillic",
    [0x04D1] = "abrevecyrillic",
    [0x04D2] = "Adieresiscyrillic",
    [0x04D3] = "adieresiscyrillic",
    [0x04D4] = "Aiecyrillic",
    [0x04D5] = "aiecyrillic",
    [0x04D6] = "Iebrevecyrillic",
    [0x04D7] = "iebrevecyrillic",
    [0x04D8] = "Schwacyrillic",
    [0x04D9] = "schwacyrillic",
    [0x04DA] = "Schwadieresiscyrillic",
    [0x04DB] = "schwadieresiscyrillic",
    [0x04DC] = "Zhedieresiscyrillic",
    [0x04DD] = "zhedieresiscyrillic",
    [0x04DE] = "Zedieresiscyrillic",
    [0x04DF] = "zedieresiscyrillic",
    [0x04E0] = "Dzeabkhasiancyrillic",
    [0x04E1] = "dzeabkhasiancyrillic",
    [0x04E2] = "Imacroncyrillic",
    [0x04E3] = "imacroncyrillic",
    [0x04E4] = "Idieresiscyrillic",
    [0x04E5] = "idieresiscyrillic",
    [0x04E6] = "Odieresiscyrillic",
    [0x04E7] = "odieresiscyrillic",
    [0x04E8] = "Obarredcyrillic",
    [0x04E9] = "obarredcyrillic",
    [0x04EA] = "Obarreddieresiscyrillic",
    [0x04EB] = "obarreddieresiscyrillic",
    [0x04EE] = "Umacroncyrillic",
    [0x04EF] = "umacroncyrillic",
    [0x04F0] = "Udieresiscyrillic",
    [0x04F1] = "udieresiscyrillic",
    [0x04F2] = "Uhungarumlautcyrillic",
    [0x04F3] = "uhungarumlautcyrillic",
    [0x04F4] = "Chedieresiscyrillic",
    [0x04F5] = "chedieresiscyrillic",
    [0x04F8] = "Yerudieresiscyrillic",
    [0x04F9] = "yerudieresiscyrillic",
    [0x0531] = "Aybarmenian",
    [0x0532] = "Benarmenian",
    [0x0533] = "Gimarmenian",
    [0x0534] = "Daarmenian",
    [0x0535] = "Echarmenian",
    [0x0536] = "Zaarmenian",
    [0x0537] = "Eharmenian",
    [0x0538] = "Etarmenian",
    [0x0539] = "Toarmenian",
    [0x053A] = "Zhearmenian",
    [0x053B] = "Iniarmenian",
    [0x053C] = "Liwnarmenian",
    [0x053D] = "Xeharmenian",
    [0x053E] = "Caarmenian",
    [0x053F] = "Kenarmenian",
    [0x0540] = "Hoarmenian",
    [0x0541] = "Jaarmenian",
    [0x0542] = "Ghadarmenian",
    [0x0543] = "Cheharmenian",
    [0x0544] = "Menarmenian",
    [0x0545] = "Yiarmenian",
    [0x0546] = "Nowarmenian",
    [0x0547] = "Shaarmenian",
    [0x0548] = "Voarmenian",
    [0x0549] = "Chaarmenian",
    [0x054A] = "Peharmenian",
    [0x054B] = "Jheharmenian",
    [0x054C] = "Raarmenian",
    [0x054D] = "Seharmenian",
    [0x054E] = "Vewarmenian",
    [0x054F] = "Tiwnarmenian",
    [0x0550] = "Reharmenian",
    [0x0551] = "Coarmenian",
    [0x0552] = "Yiwnarmenian",
    [0x0553] = "Piwrarmenian",
    [0x0554] = "Keharmenian",
    [0x0555] = "Oharmenian",
    [0x0556] = "Feharmenian",
    [0x0559] = "ringhalfleftarmenian",
    [0x055A] = "apostrophearmenian",
    [0x055B] = "emphasismarkarmenian",
    [0x055C] = "exclamarmenian",
    [0x055D] = "commaarmenian",
    [0x055E] = "questionarmenian",
    [0x055F] = "abbreviationmarkarmenian",
    [0x0561] = "aybarmenian",
    [0x0562] = "benarmenian",
    [0x0563] = "gimarmenian",
    [0x0564] = "daarmenian",
    [0x0565] = "echarmenian",
    [0x0566] = "zaarmenian",
    [0x0567] = "eharmenian",
    [0x0568] = "etarmenian",
    [0x0569] = "toarmenian",
    [0x056A] = "zhearmenian",
    [0x056B] = "iniarmenian",
    [0x056C] = "liwnarmenian",
    [0x056D] = "xeharmenian",
    [0x056E] = "caarmenian",
    [0x056F] = "kenarmenian",
    [0x0570] = "hoarmenian",
    [0x0571] = "jaarmenian",
    [0x0572] = "ghadarmenian",
    [0x0573] = "cheharmenian",
    [0x0574] = "menarmenian",
    [0x0575] = "yiarmenian",
    [0x0576] = "nowarmenian",
    [0x0577] = "shaarmenian",
    [0x0578] = "voarmenian",
    [0x0579] = "chaarmenian",
    [0x057A] = "peharmenian",
    [0x057B] = "jheharmenian",
    [0x057C] = "raarmenian",
    [0x057D] = "seharmenian",
    [0x057E] = "vewarmenian",
    [0x057F] = "tiwnarmenian",
    [0x0580] = "reharmenian",
    [0x0581] = "coarmenian",
    [0x0582] = "yiwnarmenian",
    [0x0583] = "piwrarmenian",
    [0x0584] = "keharmenian",
    [0x0585] = "oharmenian",
    [0x0586] = "feharmenian",
    [0x0587] = "echyiwnarmenian",
    [0x0589] = "periodarmenian",
    [0x0591] = "etnahtalefthebrew",
    [0x0592] = "segoltahebrew",
    [0x0593] = "shalshelethebrew",
    [0x0594] = "zaqefqatanhebrew",
    [0x0595] = "zaqefgadolhebrew",
    [0x0596] = "tipehalefthebrew",
    [0x0597] = "reviamugrashhebrew",
    [0x0598] = "zarqahebrew",
    [0x0599] = "pashtahebrew",
    [0x059A] = "yetivhebrew",
    [0x059B] = "tevirlefthebrew",
    [0x059C] = "gereshaccenthebrew",
    [0x059D] = "gereshmuqdamhebrew",
    [0x059E] = "gershayimaccenthebrew",
    [0x059F] = "qarneyparahebrew",
    [0x05A0] = "telishagedolahebrew",
    [0x05A1] = "pazerhebrew",
    [0x05A3] = "munahlefthebrew",
    [0x05A4] = "mahapakhlefthebrew",
    [0x05A5] = "merkhalefthebrew",
    [0x05A6] = "merkhakefulalefthebrew",
    [0x05A7] = "dargalefthebrew",
    [0x05A8] = "qadmahebrew",
    [0x05A9] = "telishaqetanahebrew",
    [0x05AA] = "yerahbenyomolefthebrew",
    [0x05AB] = "olehebrew",
    [0x05AC] = "iluyhebrew",
    [0x05AD] = "dehihebrew",
    [0x05AE] = "zinorhebrew",
    [0x05AF] = "masoracirclehebrew",
    [0x05B0] = "shevawidehebrew",
    [0x05B1] = "hatafsegolwidehebrew",
    [0x05B2] = "hatafpatahwidehebrew",
    [0x05B3] = "hatafqamatswidehebrew",
    [0x05B4] = "hiriqwidehebrew",
    [0x05B5] = "tserewidehebrew",
    [0x05B6] = "segolwidehebrew",
    [0x05B7] = "patahwidehebrew",
    [0x05B8] = "qamatswidehebrew",
    [0x05B9] = "holamwidehebrew",
    [0x05BB] = "qubutswidehebrew",
    [0x05BC] = "dageshhebrew",
    [0x05BD] = "siluqlefthebrew",
    [0x05BE] = "maqafhebrew",
    [0x05BF] = "rafehebrew",
    [0x05C0] = "paseqhebrew",
    [0x05C1] = "shindothebrew",
    [0x05C2] = "sindothebrew",
    [0x05C3] = "sofpasuqhebrew",
    [0x05C4] = "upperdothebrew",
    [0x05D0] = "alefhebrew",
    [0x05D1] = "bethebrew",
    [0x05D2] = "gimelhebrew",
    [0x05D3] = "dalettserehebrew",
    [0x05D4] = "hehebrew",
    [0x05D5] = "vavhebrew",
    [0x05D6] = "zayinhebrew",
    [0x05D7] = "hethebrew",
    [0x05D8] = "tethebrew",
    [0x05D9] = "yodhebrew",
    [0x05DA] = "finalkafshevahebrew",
    [0x05DB] = "kafhebrew",
    [0x05DC] = "lamedholamhebrew",
    [0x05DD] = "finalmemhebrew",
    [0x05DE] = "memhebrew",
    [0x05DF] = "finalnunhebrew",
    [0x05E0] = "nunhebrew",
    [0x05E1] = "samekhhebrew",
    [0x05E2] = "ayinhebrew",
    [0x05E3] = "finalpehebrew",
    [0x05E4] = "pehebrew",
    [0x05E5] = "finaltsadihebrew",
    [0x05E6] = "tsadihebrew",
    [0x05E7] = "qoftserehebrew",
    [0x05E8] = "reshtserehebrew",
    [0x05E9] = "shinhebrew",
    [0x05EA] = "tavhebrew",
    [0x05F0] = "vavvavhebrew",
    [0x05F1] = "vavyodhebrew",
    [0x05F2] = "yodyodhebrew",
    [0x05F3] = "gereshhebrew",
    [0x05F4] = "gershayimhebrew",
    [0x060C] = "commaarabic",
    [0x061B] = "semicolonarabic",
    [0x061F] = "questionarabic",
    [0x0621] = "hamzasukunarabic",
    [0x0622] = "alefmaddaabovearabic",
    [0x0623] = "alefhamzaabovearabic",
    [0x0624] = "wawhamzaabovearabic",
    [0x0625] = "alefhamzabelowarabic",
    [0x0626] = "yehhamzaabovearabic",
    [0x0627] = "alefarabic",
    [0x0628] = "beharabic",
    [0x0629] = "tehmarbutaarabic",
    [0x062A] = "teharabic",
    [0x062B] = "theharabic",
    [0x062C] = "jeemarabic",
    [0x062D] = "haharabic",
    [0x062E] = "khaharabic",
    [0x062F] = "dalarabic",
    [0x0630] = "thalarabic",
    [0x0631] = "rehyehaleflamarabic",
    [0x0632] = "zainarabic",
    [0x0633] = "seenarabic",
    [0x0634] = "sheenarabic",
    [0x0635] = "sadarabic",
    [0x0636] = "dadarabic",
    [0x0637] = "taharabic",
    [0x0638] = "zaharabic",
    [0x0639] = "ainarabic",
    [0x063A] = "ghainarabic",
    [0x0640] = "tatweelarabic",
    [0x0641] = "feharabic",
    [0x0642] = "qafarabic",
    [0x0643] = "kafarabic",
    [0x0644] = "lamarabic",
    [0x0645] = "meemarabic",
    [0x0646] = "noonarabic",
    [0x0647] = "heharabic",
    [0x0648] = "wawarabic",
    [0x0649] = "alefmaksuraarabic",
    [0x064A] = "yeharabic",
    [0x064B] = "fathatanarabic",
    [0x064C] = "dammatanarabic",
    [0x064D] = "kasratanarabic",
    [0x064E] = "fathalowarabic",
    [0x064F] = "dammalowarabic",
    [0x0650] = "kasraarabic",
    [0x0651] = "shaddafathatanarabic",
    [0x0652] = "sukunarabic",
    [0x0660] = "zerohackarabic",
    [0x0661] = "onehackarabic",
    [0x0662] = "twohackarabic",
    [0x0663] = "threehackarabic",
    [0x0664] = "fourhackarabic",
    [0x0665] = "fivehackarabic",
    [0x0666] = "sixhackarabic",
    [0x0667] = "sevenhackarabic",
    [0x0668] = "eighthackarabic",
    [0x0669] = "ninehackarabic",
    [0x066A] = "percentarabic",
    [0x066B] = "decimalseparatorpersian",
    [0x066C] = "thousandsseparatorpersian",
    [0x066D] = "asteriskarabic",
    [0x0679] = "tteharabic",
    [0x067E] = "peharabic",
    [0x0686] = "tcheharabic",
    [0x0688] = "ddalarabic",
    [0x0691] = "rreharabic",
    [0x0698] = "jeharabic",
    [0x06A4] = "veharabic",
    [0x06AF] = "gafarabic",
    [0x06BA] = "noonghunnaarabic",
    [0x06C1] = "hehaltonearabic",
    [0x06D1] = "yehthreedotsbelowarabic",
    [0x06D2] = "yehbarreearabic",
    [0x06D5] = "afii57534",
    [0x06F0] = "zeropersian",
    [0x06F1] = "onepersian",
    [0x06F2] = "twopersian",
    [0x06F3] = "threepersian",
    [0x06F4] = "fourpersian",
    [0x06F5] = "fivepersian",
    [0x06F6] = "sixpersian",
    [0x06F7] = "sevenpersian",
    [0x06F8] = "eightpersian",
    [0x06F9] = "ninepersian",
    [0x0901] = "candrabindudeva",
    [0x0902] = "anusvaradeva",
    [0x0903] = "visargadeva",
    [0x0905] = "adeva",
    [0x0906] = "aadeva",
    [0x0907] = "ideva",
    [0x0908] = "iideva",
    [0x0909] = "udeva",
    [0x090A] = "uudeva",
    [0x090B] = "rvocalicdeva",
    [0x090C] = "lvocalicdeva",
    [0x090D] = "ecandradeva",
    [0x090E] = "eshortdeva",
    [0x090F] = "edeva",
    [0x0910] = "aideva",
    [0x0911] = "ocandradeva",
    [0x0912] = "oshortdeva",
    [0x0913] = "odeva",
    [0x0914] = "audeva",
    [0x0915] = "kadeva",
    [0x0916] = "khadeva",
    [0x0917] = "gadeva",
    [0x0918] = "ghadeva",
    [0x0919] = "ngadeva",
    [0x091A] = "cadeva",
    [0x091B] = "chadeva",
    [0x091C] = "jadeva",
    [0x091D] = "jhadeva",
    [0x091E] = "nyadeva",
    [0x091F] = "ttadeva",
    [0x0920] = "tthadeva",
    [0x0921] = "ddadeva",
    [0x0922] = "ddhadeva",
    [0x0923] = "nnadeva",
    [0x0924] = "tadeva",
    [0x0925] = "thadeva",
    [0x0926] = "dadeva",
    [0x0927] = "dhadeva",
    [0x0928] = "nadeva",
    [0x0929] = "nnnadeva",
    [0x092A] = "padeva",
    [0x092B] = "phadeva",
    [0x092C] = "badeva",
    [0x092D] = "bhadeva",
    [0x092E] = "madeva",
    [0x092F] = "yadeva",
    [0x0930] = "radeva",
    [0x0931] = "rradeva",
    [0x0932] = "ladeva",
    [0x0933] = "lladeva",
    [0x0934] = "llladeva",
    [0x0935] = "vadeva",
    [0x0936] = "shadeva",
    [0x0937] = "ssadeva",
    [0x0938] = "sadeva",
    [0x0939] = "hadeva",
    [0x093C] = "nuktadeva",
    [0x093D] = "avagrahadeva",
    [0x093E] = "aavowelsigndeva",
    [0x093F] = "ivowelsigndeva",
    [0x0940] = "iivowelsigndeva",
    [0x0941] = "uvowelsigndeva",
    [0x0942] = "uuvowelsigndeva",
    [0x0943] = "rvocalicvowelsigndeva",
    [0x0944] = "rrvocalicvowelsigndeva",
    [0x0945] = "ecandravowelsigndeva",
    [0x0946] = "eshortvowelsigndeva",
    [0x0947] = "evowelsigndeva",
    [0x0948] = "aivowelsigndeva",
    [0x0949] = "ocandravowelsigndeva",
    [0x094A] = "oshortvowelsigndeva",
    [0x094B] = "ovowelsigndeva",
    [0x094C] = "auvowelsigndeva",
    [0x094D] = "viramadeva",
    [0x0950] = "omdeva",
    [0x0951] = "udattadeva",
    [0x0952] = "anudattadeva",
    [0x0953] = "gravedeva",
    [0x0954] = "acutedeva",
    [0x0958] = "qadeva",
    [0x0959] = "khhadeva",
    [0x095A] = "ghhadeva",
    [0x095B] = "zadeva",
    [0x095C] = "dddhadeva",
    [0x095D] = "rhadeva",
    [0x095E] = "fadeva",
    [0x095F] = "yyadeva",
    [0x0960] = "rrvocalicdeva",
    [0x0961] = "llvocalicdeva",
    [0x0962] = "lvocalicvowelsigndeva",
    [0x0963] = "llvocalicvowelsigndeva",
    [0x0964] = "danda",
    [0x0965] = "dbldanda",
    [0x0966] = "zerodeva",
    [0x0967] = "onedeva",
    [0x0968] = "twodeva",
    [0x0969] = "threedeva",
    [0x096A] = "fourdeva",
    [0x096B] = "fivedeva",
    [0x096C] = "sixdeva",
    [0x096D] = "sevendeva",
    [0x096E] = "eightdeva",
    [0x096F] = "ninedeva",
    [0x0970] = "abbreviationsigndeva",
    [0x0981] = "candrabindubengali",
    [0x0982] = "anusvarabengali",
    [0x0983] = "visargabengali",
    [0x0985] = "abengali",
    [0x0986] = "aabengali",
    [0x0987] = "ibengali",
    [0x0988] = "iibengali",
    [0x0989] = "ubengali",
    [0x098A] = "uubengali",
    [0x098B] = "rvocalicbengali",
    [0x098C] = "lvocalicbengali",
    [0x098F] = "ebengali",
    [0x0990] = "aibengali",
    [0x0993] = "obengali",
    [0x0994] = "aubengali",
    [0x0995] = "kabengali",
    [0x0996] = "khabengali",
    [0x0997] = "gabengali",
    [0x0998] = "ghabengali",
    [0x0999] = "ngabengali",
    [0x099A] = "cabengali",
    [0x099B] = "chabengali",
    [0x099C] = "jabengali",
    [0x099D] = "jhabengali",
    [0x099E] = "nyabengali",
    [0x099F] = "ttabengali",
    [0x09A0] = "tthabengali",
    [0x09A1] = "ddabengali",
    [0x09A2] = "ddhabengali",
    [0x09A3] = "nnabengali",
    [0x09A4] = "tabengali",
    [0x09A5] = "thabengali",
    [0x09A6] = "dabengali",
    [0x09A7] = "dhabengali",
    [0x09A8] = "nabengali",
    [0x09AA] = "pabengali",
    [0x09AB] = "phabengali",
    [0x09AC] = "babengali",
    [0x09AD] = "bhabengali",
    [0x09AE] = "mabengali",
    [0x09AF] = "yabengali",
    [0x09B0] = "rabengali",
    [0x09B2] = "labengali",
    [0x09B6] = "shabengali",
    [0x09B7] = "ssabengali",
    [0x09B8] = "sabengali",
    [0x09B9] = "habengali",
    [0x09BC] = "nuktabengali",
    [0x09BE] = "aavowelsignbengali",
    [0x09BF] = "ivowelsignbengali",
    [0x09C0] = "iivowelsignbengali",
    [0x09C1] = "uvowelsignbengali",
    [0x09C2] = "uuvowelsignbengali",
    [0x09C3] = "rvocalicvowelsignbengali",
    [0x09C4] = "rrvocalicvowelsignbengali",
    [0x09C7] = "evowelsignbengali",
    [0x09C8] = "aivowelsignbengali",
    [0x09CB] = "ovowelsignbengali",
    [0x09CC] = "auvowelsignbengali",
    [0x09CD] = "viramabengali",
    [0x09D7] = "aulengthmarkbengali",
    [0x09DC] = "rrabengali",
    [0x09DD] = "rhabengali",
    [0x09DF] = "yyabengali",
    [0x09E0] = "rrvocalicbengali",
    [0x09E1] = "llvocalicbengali",
    [0x09E2] = "lvocalicvowelsignbengali",
    [0x09E3] = "llvocalicvowelsignbengali",
    [0x09E6] = "zerobengali",
    [0x09E7] = "onebengali",
    [0x09E8] = "twobengali",
    [0x09E9] = "threebengali",
    [0x09EA] = "fourbengali",
    [0x09EB] = "fivebengali",
    [0x09EC] = "sixbengali",
    [0x09ED] = "sevenbengali",
    [0x09EE] = "eightbengali",
    [0x09EF] = "ninebengali",
    [0x09F0] = "ramiddlediagonalbengali",
    [0x09F1] = "ralowerdiagonalbengali",
    [0x09F2] = "rupeemarkbengali",
    [0x09F3] = "rupeesignbengali",
    [0x09F4] = "onenumeratorbengali",
    [0x09F5] = "twonumeratorbengali",
    [0x09F6] = "threenumeratorbengali",
    [0x09F7] = "fournumeratorbengali",
    [0x09F8] = "denominatorminusonenumeratorbengali",
    [0x09F9] = "sixteencurrencydenominatorbengali",
    [0x09FA] = "issharbengali",
    [0x0A02] = "bindigurmukhi",
    [0x0A05] = "agurmukhi",
    [0x0A06] = "aagurmukhi",
    [0x0A07] = "igurmukhi",
    [0x0A08] = "iigurmukhi",
    [0x0A09] = "ugurmukhi",
    [0x0A0A] = "uugurmukhi",
    [0x0A0F] = "eegurmukhi",
    [0x0A10] = "aigurmukhi",
    [0x0A13] = "oogurmukhi",
    [0x0A14] = "augurmukhi",
    [0x0A15] = "kagurmukhi",
    [0x0A16] = "khagurmukhi",
    [0x0A17] = "gagurmukhi",
    [0x0A18] = "ghagurmukhi",
    [0x0A19] = "ngagurmukhi",
    [0x0A1A] = "cagurmukhi",
    [0x0A1B] = "chagurmukhi",
    [0x0A1C] = "jagurmukhi",
    [0x0A1D] = "jhagurmukhi",
    [0x0A1E] = "nyagurmukhi",
    [0x0A1F] = "ttagurmukhi",
    [0x0A20] = "tthagurmukhi",
    [0x0A21] = "ddagurmukhi",
    [0x0A22] = "ddhagurmukhi",
    [0x0A23] = "nnagurmukhi",
    [0x0A24] = "tagurmukhi",
    [0x0A25] = "thagurmukhi",
    [0x0A26] = "dagurmukhi",
    [0x0A27] = "dhagurmukhi",
    [0x0A28] = "nagurmukhi",
    [0x0A2A] = "pagurmukhi",
    [0x0A2B] = "phagurmukhi",
    [0x0A2C] = "bagurmukhi",
    [0x0A2D] = "bhagurmukhi",
    [0x0A2E] = "magurmukhi",
    [0x0A2F] = "yagurmukhi",
    [0x0A30] = "ragurmukhi",
    [0x0A32] = "lagurmukhi",
    [0x0A35] = "vagurmukhi",
    [0x0A36] = "shagurmukhi",
    [0x0A38] = "sagurmukhi",
    [0x0A39] = "hagurmukhi",
    [0x0A3C] = "nuktagurmukhi",
    [0x0A3E] = "aamatragurmukhi",
    [0x0A3F] = "imatragurmukhi",
    [0x0A40] = "iimatragurmukhi",
    [0x0A41] = "umatragurmukhi",
    [0x0A42] = "uumatragurmukhi",
    [0x0A47] = "eematragurmukhi",
    [0x0A48] = "aimatragurmukhi",
    [0x0A4B] = "oomatragurmukhi",
    [0x0A4C] = "aumatragurmukhi",
    [0x0A4D] = "halantgurmukhi",
    [0x0A59] = "khhagurmukhi",
    [0x0A5A] = "ghhagurmukhi",
    [0x0A5B] = "zagurmukhi",
    [0x0A5C] = "rragurmukhi",
    [0x0A5E] = "fagurmukhi",
    [0x0A66] = "zerogurmukhi",
    [0x0A67] = "onegurmukhi",
    [0x0A68] = "twogurmukhi",
    [0x0A69] = "threegurmukhi",
    [0x0A6A] = "fourgurmukhi",
    [0x0A6B] = "fivegurmukhi",
    [0x0A6C] = "sixgurmukhi",
    [0x0A6D] = "sevengurmukhi",
    [0x0A6E] = "eightgurmukhi",
    [0x0A6F] = "ninegurmukhi",
    [0x0A70] = "tippigurmukhi",
    [0x0A71] = "addakgurmukhi",
    [0x0A72] = "irigurmukhi",
    [0x0A73] = "uragurmukhi",
    [0x0A74] = "ekonkargurmukhi",
    [0x0A81] = "candrabindugujarati",
    [0x0A82] = "anusvaragujarati",
    [0x0A83] = "visargagujarati",
    [0x0A85] = "agujarati",
    [0x0A86] = "aagujarati",
    [0x0A87] = "igujarati",
    [0x0A88] = "iigujarati",
    [0x0A89] = "ugujarati",
    [0x0A8A] = "uugujarati",
    [0x0A8B] = "rvocalicgujarati",
    [0x0A8D] = "ecandragujarati",
    [0x0A8F] = "egujarati",
    [0x0A90] = "aigujarati",
    [0x0A91] = "ocandragujarati",
    [0x0A93] = "ogujarati",
    [0x0A94] = "augujarati",
    [0x0A95] = "kagujarati",
    [0x0A96] = "khagujarati",
    [0x0A97] = "gagujarati",
    [0x0A98] = "ghagujarati",
    [0x0A99] = "ngagujarati",
    [0x0A9A] = "cagujarati",
    [0x0A9B] = "chagujarati",
    [0x0A9C] = "jagujarati",
    [0x0A9D] = "jhagujarati",
    [0x0A9E] = "nyagujarati",
    [0x0A9F] = "ttagujarati",
    [0x0AA0] = "tthagujarati",
    [0x0AA1] = "ddagujarati",
    [0x0AA2] = "ddhagujarati",
    [0x0AA3] = "nnagujarati",
    [0x0AA4] = "tagujarati",
    [0x0AA5] = "thagujarati",
    [0x0AA6] = "dagujarati",
    [0x0AA7] = "dhagujarati",
    [0x0AA8] = "nagujarati",
    [0x0AAA] = "pagujarati",
    [0x0AAB] = "phagujarati",
    [0x0AAC] = "bagujarati",
    [0x0AAD] = "bhagujarati",
    [0x0AAE] = "magujarati",
    [0x0AAF] = "yagujarati",
    [0x0AB0] = "ragujarati",
    [0x0AB2] = "lagujarati",
    [0x0AB3] = "llagujarati",
    [0x0AB5] = "vagujarati",
    [0x0AB6] = "shagujarati",
    [0x0AB7] = "ssagujarati",
    [0x0AB8] = "sagujarati",
    [0x0AB9] = "hagujarati",
    [0x0ABC] = "nuktagujarati",
    [0x0ABE] = "aavowelsigngujarati",
    [0x0ABF] = "ivowelsigngujarati",
    [0x0AC0] = "iivowelsigngujarati",
    [0x0AC1] = "uvowelsigngujarati",
    [0x0AC2] = "uuvowelsigngujarati",
    [0x0AC3] = "rvocalicvowelsigngujarati",
    [0x0AC4] = "rrvocalicvowelsigngujarati",
    [0x0AC5] = "ecandravowelsigngujarati",
    [0x0AC7] = "evowelsigngujarati",
    [0x0AC8] = "aivowelsigngujarati",
    [0x0AC9] = "ocandravowelsigngujarati",
    [0x0ACB] = "ovowelsigngujarati",
    [0x0ACC] = "auvowelsigngujarati",
    [0x0ACD] = "viramagujarati",
    [0x0AD0] = "omgujarati",
    [0x0AE0] = "rrvocalicgujarati",
    [0x0AE6] = "zerogujarati",
    [0x0AE7] = "onegujarati",
    [0x0AE8] = "twogujarati",
    [0x0AE9] = "threegujarati",
    [0x0AEA] = "fourgujarati",
    [0x0AEB] = "fivegujarati",
    [0x0AEC] = "sixgujarati",
    [0x0AED] = "sevengujarati",
    [0x0AEE] = "eightgujarati",
    [0x0AEF] = "ninegujarati",
    [0x0E01] = "kokaithai",
    [0x0E02] = "khokhaithai",
    [0x0E03] = "khokhuatthai",
    [0x0E04] = "khokhwaithai",
    [0x0E05] = "khokhonthai",
    [0x0E06] = "khorakhangthai",
    [0x0E07] = "ngonguthai",
    [0x0E08] = "chochanthai",
    [0x0E09] = "chochingthai",
    [0x0E0A] = "chochangthai",
    [0x0E0B] = "sosothai",
    [0x0E0C] = "chochoethai",
    [0x0E0D] = "yoyingthai",
    [0x0E0E] = "dochadathai",
    [0x0E0F] = "topatakthai",
    [0x0E10] = "thothanthai",
    [0x0E11] = "thonangmonthothai",
    [0x0E12] = "thophuthaothai",
    [0x0E13] = "nonenthai",
    [0x0E14] = "dodekthai",
    [0x0E15] = "totaothai",
    [0x0E16] = "thothungthai",
    [0x0E17] = "thothahanthai",
    [0x0E18] = "thothongthai",
    [0x0E19] = "nonuthai",
    [0x0E1A] = "bobaimaithai",
    [0x0E1B] = "poplathai",
    [0x0E1C] = "phophungthai",
    [0x0E1D] = "fofathai",
    [0x0E1E] = "phophanthai",
    [0x0E1F] = "fofanthai",
    [0x0E20] = "phosamphaothai",
    [0x0E21] = "momathai",
    [0x0E22] = "yoyakthai",
    [0x0E23] = "roruathai",
    [0x0E24] = "ruthai",
    [0x0E25] = "lolingthai",
    [0x0E26] = "luthai",
    [0x0E27] = "wowaenthai",
    [0x0E28] = "sosalathai",
    [0x0E29] = "sorusithai",
    [0x0E2A] = "sosuathai",
    [0x0E2B] = "hohipthai",
    [0x0E2C] = "lochulathai",
    [0x0E2D] = "oangthai",
    [0x0E2E] = "honokhukthai",
    [0x0E2F] = "paiyannoithai",
    [0x0E30] = "saraathai",
    [0x0E31] = "maihanakatthai",
    [0x0E32] = "saraaathai",
    [0x0E33] = "saraamthai",
    [0x0E34] = "saraithai",
    [0x0E35] = "saraiithai",
    [0x0E36] = "sarauethai",
    [0x0E37] = "saraueethai",
    [0x0E38] = "sarauthai",
    [0x0E39] = "sarauuthai",
    [0x0E3A] = "phinthuthai",
    [0x0E3F] = "bahtthai",
    [0x0E40] = "saraethai",
    [0x0E41] = "saraaethai",
    [0x0E42] = "saraothai",
    [0x0E43] = "saraaimaimuanthai",
    [0x0E44] = "saraaimaimalaithai",
    [0x0E45] = "lakkhangyaothai",
    [0x0E46] = "maiyamokthai",
    [0x0E47] = "maitaikhuthai",
    [0x0E48] = "maiekthai",
    [0x0E49] = "maithothai",
    [0x0E4A] = "maitrithai",
    [0x0E4B] = "maichattawathai",
    [0x0E4C] = "thanthakhatthai",
    [0x0E4D] = "nikhahitthai",
    [0x0E4E] = "yamakkanthai",
    [0x0E4F] = "fongmanthai",
    [0x0E50] = "zerothai",
    [0x0E51] = "onethai",
    [0x0E52] = "twothai",
    [0x0E53] = "threethai",
    [0x0E54] = "fourthai",
    [0x0E55] = "fivethai",
    [0x0E56] = "sixthai",
    [0x0E57] = "seventhai",
    [0x0E58] = "eightthai",
    [0x0E59] = "ninethai",
    [0x0E5A] = "angkhankhuthai",
    [0x0E5B] = "khomutthai",
    [0x1E00] = "Aringbelow",
    [0x1E01] = "aringbelow",
    [0x1E02] = "Bdotaccent",
    [0x1E03] = "bdotaccent",
    [0x1E04] = "Bdotbelow",
    [0x1E05] = "bdotbelow",
    [0x1E06] = "Blinebelow",
    [0x1E07] = "blinebelow",
    [0x1E08] = "Ccedillaacute",
    [0x1E09] = "ccedillaacute",
    [0x1E0A] = "Ddotaccent",
    [0x1E0B] = "ddotaccent",
    [0x1E0C] = "Ddotbelow",
    [0x1E0D] = "ddotbelow",
    [0x1E0E] = "Dlinebelow",
    [0x1E0F] = "dlinebelow",
    [0x1E10] = "Dcedilla",
    [0x1E11] = "dcedilla",
    [0x1E12] = "Dcircumflexbelow",
    [0x1E13] = "dcircumflexbelow",
    [0x1E14] = "Emacrongrave",
    [0x1E15] = "emacrongrave",
    [0x1E16] = "Emacronacute",
    [0x1E17] = "emacronacute",
    [0x1E18] = "Ecircumflexbelow",
    [0x1E19] = "ecircumflexbelow",
    [0x1E1A] = "Etildebelow",
    [0x1E1B] = "etildebelow",
    [0x1E1C] = "Ecedillabreve",
    [0x1E1D] = "ecedillabreve",
    [0x1E1E] = "Fdotaccent",
    [0x1E1F] = "fdotaccent",
    [0x1E20] = "Gmacron",
    [0x1E21] = "gmacron",
    [0x1E22] = "Hdotaccent",
    [0x1E23] = "hdotaccent",
    [0x1E24] = "Hdotbelow",
    [0x1E25] = "hdotbelow",
    [0x1E26] = "Hdieresis",
    [0x1E27] = "hdieresis",
    [0x1E28] = "Hcedilla",
    [0x1E29] = "hcedilla",
    [0x1E2A] = "Hbrevebelow",
    [0x1E2B] = "hbrevebelow",
    [0x1E2C] = "Itildebelow",
    [0x1E2D] = "itildebelow",
    [0x1E2E] = "Idieresisacute",
    [0x1E2F] = "idieresisacute",
    [0x1E30] = "Kacute",
    [0x1E31] = "kacute",
    [0x1E32] = "Kdotbelow",
    [0x1E33] = "kdotbelow",
    [0x1E34] = "Klinebelow",
    [0x1E35] = "klinebelow",
    [0x1E36] = "Ldotbelow",
    [0x1E37] = "ldotbelow",
    [0x1E38] = "Ldotbelowmacron",
    [0x1E39] = "ldotbelowmacron",
    [0x1E3A] = "Llinebelow",
    [0x1E3B] = "llinebelow",
    [0x1E3C] = "Lcircumflexbelow",
    [0x1E3D] = "lcircumflexbelow",
    [0x1E3E] = "Macute",
    [0x1E3F] = "macute",
    [0x1E40] = "Mdotaccent",
    [0x1E41] = "mdotaccent",
    [0x1E42] = "Mdotbelow",
    [0x1E43] = "mdotbelow",
    [0x1E44] = "Ndotaccent",
    [0x1E45] = "ndotaccent",
    [0x1E46] = "Ndotbelow",
    [0x1E47] = "ndotbelow",
    [0x1E48] = "Nlinebelow",
    [0x1E49] = "nlinebelow",
    [0x1E4A] = "Ncircumflexbelow",
    [0x1E4B] = "ncircumflexbelow",
    [0x1E4C] = "Otildeacute",
    [0x1E4D] = "otildeacute",
    [0x1E4E] = "Otildedieresis",
    [0x1E4F] = "otildedieresis",
    [0x1E50] = "Omacrongrave",
    [0x1E51] = "omacrongrave",
    [0x1E52] = "Omacronacute",
    [0x1E53] = "omacronacute",
    [0x1E54] = "Pacute",
    [0x1E55] = "pacute",
    [0x1E56] = "Pdotaccent",
    [0x1E57] = "pdotaccent",
    [0x1E58] = "Rdotaccent",
    [0x1E59] = "rdotaccent",
    [0x1E5A] = "Rdotbelow",
    [0x1E5B] = "rdotbelow",
    [0x1E5C] = "Rdotbelowmacron",
    [0x1E5D] = "rdotbelowmacron",
    [0x1E5E] = "Rlinebelow",
    [0x1E5F] = "rlinebelow",
    [0x1E60] = "Sdotaccent",
    [0x1E61] = "sdotaccent",
    [0x1E62] = "Sdotbelow",
    [0x1E63] = "sdotbelow",
    [0x1E64] = "Sacutedotaccent",
    [0x1E65] = "sacutedotaccent",
    [0x1E66] = "Scarondotaccent",
    [0x1E67] = "scarondotaccent",
    [0x1E68] = "Sdotbelowdotaccent",
    [0x1E69] = "sdotbelowdotaccent",
    [0x1E6A] = "Tdotaccent",
    [0x1E6B] = "tdotaccent",
    [0x1E6C] = "Tdotbelow",
    [0x1E6D] = "tdotbelow",
    [0x1E6E] = "Tlinebelow",
    [0x1E6F] = "tlinebelow",
    [0x1E70] = "Tcircumflexbelow",
    [0x1E71] = "tcircumflexbelow",
    [0x1E72] = "Udieresisbelow",
    [0x1E73] = "udieresisbelow",
    [0x1E74] = "Utildebelow",
    [0x1E75] = "utildebelow",
    [0x1E76] = "Ucircumflexbelow",
    [0x1E77] = "ucircumflexbelow",
    [0x1E78] = "Utildeacute",
    [0x1E79] = "utildeacute",
    [0x1E7A] = "Umacrondieresis",
    [0x1E7B] = "umacrondieresis",
    [0x1E7C] = "Vtilde",
    [0x1E7D] = "vtilde",
    [0x1E7E] = "Vdotbelow",
    [0x1E7F] = "vdotbelow",
    [0x1E80] = "Wgrave",
    [0x1E81] = "wgrave",
    [0x1E82] = "Wacute",
    [0x1E83] = "wacute",
    [0x1E84] = "Wdieresis",
    [0x1E85] = "wdieresis",
    [0x1E86] = "Wdotaccent",
    [0x1E87] = "wdotaccent",
    [0x1E88] = "Wdotbelow",
    [0x1E89] = "wdotbelow",
    [0x1E8A] = "Xdotaccent",
    [0x1E8B] = "xdotaccent",
    [0x1E8C] = "Xdieresis",
    [0x1E8D] = "xdieresis",
    [0x1E8E] = "Ydotaccent",
    [0x1E8F] = "ydotaccent",
    [0x1E90] = "Zcircumflex",
    [0x1E91] = "zcircumflex",
    [0x1E92] = "Zdotbelow",
    [0x1E93] = "zdotbelow",
    [0x1E94] = "Zlinebelow",
    [0x1E95] = "zlinebelow",
    [0x1E96] = "hlinebelow",
    [0x1E97] = "tdieresis",
    [0x1E98] = "wring",
    [0x1E99] = "yring",
    [0x1E9A] = "arighthalfring",
    [0x1E9B] = "slongdotaccent",
    [0x1EA0] = "Adotbelow",
    [0x1EA1] = "adotbelow",
    [0x1EA2] = "Ahookabove",
    [0x1EA3] = "ahookabove",
    [0x1EA4] = "Acircumflexacute",
    [0x1EA5] = "acircumflexacute",
    [0x1EA6] = "Acircumflexgrave",
    [0x1EA7] = "acircumflexgrave",
    [0x1EA8] = "Acircumflexhookabove",
    [0x1EA9] = "acircumflexhookabove",
    [0x1EAA] = "Acircumflextilde",
    [0x1EAB] = "acircumflextilde",
    [0x1EAC] = "Acircumflexdotbelow",
    [0x1EAD] = "acircumflexdotbelow",
    [0x1EAE] = "Abreveacute",
    [0x1EAF] = "abreveacute",
    [0x1EB0] = "Abrevegrave",
    [0x1EB1] = "abrevegrave",
    [0x1EB2] = "Abrevehookabove",
    [0x1EB3] = "abrevehookabove",
    [0x1EB4] = "Abrevetilde",
    [0x1EB5] = "abrevetilde",
    [0x1EB6] = "Abrevedotbelow",
    [0x1EB7] = "abrevedotbelow",
    [0x1EB8] = "Edotbelow",
    [0x1EB9] = "edotbelow",
    [0x1EBA] = "Ehookabove",
    [0x1EBB] = "ehookabove",
    [0x1EBC] = "Etilde",
    [0x1EBD] = "etilde",
    [0x1EBE] = "Ecircumflexacute",
    [0x1EBF] = "ecircumflexacute",
    [0x1EC0] = "Ecircumflexgrave",
    [0x1EC1] = "ecircumflexgrave",
    [0x1EC2] = "Ecircumflexhookabove",
    [0x1EC3] = "ecircumflexhookabove",
    [0x1EC4] = "Ecircumflextilde",
    [0x1EC5] = "ecircumflextilde",
    [0x1EC6] = "Ecircumflexdotbelow",
    [0x1EC7] = "ecircumflexdotbelow",
    [0x1EC8] = "Ihookabove",
    [0x1EC9] = "ihookabove",
    [0x1ECA] = "Idotbelow",
    [0x1ECB] = "idotbelow",
    [0x1ECC] = "Odotbelow",
    [0x1ECD] = "odotbelow",
    [0x1ECE] = "Ohookabove",
    [0x1ECF] = "ohookabove",
    [0x1ED0] = "Ocircumflexacute",
    [0x1ED1] = "ocircumflexacute",
    [0x1ED2] = "Ocircumflexgrave",
    [0x1ED3] = "ocircumflexgrave",
    [0x1ED4] = "Ocircumflexhookabove",
    [0x1ED5] = "ocircumflexhookabove",
    [0x1ED6] = "Ocircumflextilde",
    [0x1ED7] = "ocircumflextilde",
    [0x1ED8] = "Ocircumflexdotbelow",
    [0x1ED9] = "ocircumflexdotbelow",
    [0x1EDA] = "Ohornacute",
    [0x1EDB] = "ohornacute",
    [0x1EDC] = "Ohorngrave",
    [0x1EDD] = "ohorngrave",
    [0x1EDE] = "Ohornhookabove",
    [0x1EDF] = "ohornhookabove",
    [0x1EE0] = "Ohorntilde",
    [0x1EE1] = "ohorntilde",
    [0x1EE2] = "Ohorndotbelow",
    [0x1EE3] = "ohorndotbelow",
    [0x1EE4] = "Udotbelow",
    [0x1EE5] = "udotbelow",
    [0x1EE6] = "Uhookabove",
    [0x1EE7] = "uhookabove",
    [0x1EE8] = "Uhornacute",
    [0x1EE9] = "uhornacute",
    [0x1EEA] = "Uhorngrave",
    [0x1EEB] = "uhorngrave",
    [0x1EEC] = "Uhornhookabove",
    [0x1EED] = "uhornhookabove",
    [0x1EEE] = "Uhorntilde",
    [0x1EEF] = "uhorntilde",
    [0x1EF0] = "Uhorndotbelow",
    [0x1EF1] = "uhorndotbelow",
    [0x1EF2] = "Ygrave",
    [0x1EF3] = "ygrave",
    [0x1EF4] = "Ydotbelow",
    [0x1EF5] = "ydotbelow",
    [0x1EF6] = "Yhookabove",
    [0x1EF7] = "yhookabove",
    [0x1EF8] = "Ytilde",
    [0x1EF9] = "ytilde",
    [0x2002] = "enspace",
    [0x200B] = "zerowidthspace",
    [0x200C] = "zerowidthnonjoiner",
    [0x200D] = "afii301",
    [0x200E] = "afii299",
    [0x200F] = "afii300",
    [0x2010] = "hyphentwo",
    [0x2012] = "figuredash",
    [0x2013] = "endash",
    [0x2014] = "emdash",
    [0x2015] = "horizontalbar",
    [0x2016] = "dblverticalbar",
    [0x2017] = "underscoredbl",
    [0x2018] = "quoteleft",
    [0x2019] = "quoteright",
    [0x201A] = "quotesinglbase",
    [0x201B] = "quotereversed",
    [0x201C] = "quotedblleft",
    [0x201D] = "quotedblright",
    [0x201E] = "quotedblbase",
    [0x2020] = "dagger",
    [0x2021] = "daggerdbl",
    [0x2022] = "bullet",
    [0x2024] = "onedotenleader",
    [0x2025] = "twodotleader",
    [0x2026] = "ellipsis",
    [0x202C] = "afii61573",
    [0x202D] = "afii61574",
    [0x202E] = "afii61575",
    [0x2030] = "perthousand",
    [0x2032] = "minute",
    [0x2033] = "second",
    [0x2035] = "primereversed",
    [0x2039] = "guilsinglleft",
    [0x203A] = "guilsinglright",
    [0x203B] = "referencemark",
    [0x203C] = "exclamdbl",
    [0x203E] = "overline",
    [0x2042] = "asterism",
    [0x2044] = "fraction",
    [0x2070] = "zerosuperior",
    [0x2074] = "foursuperior",
    [0x2075] = "fivesuperior",
    [0x2076] = "sixsuperior",
    [0x2077] = "sevensuperior",
    [0x2078] = "eightsuperior",
    [0x2079] = "ninesuperior",
    [0x207A] = "plussuperior",
    [0x207C] = "equalsuperior",
    [0x207D] = "parenleftsuperior",
    [0x207E] = "parenrightsuperior",
    [0x207F] = "nsuperior",
    [0x2080] = "zeroinferior",
    [0x2081] = "oneinferior",
    [0x2082] = "twoinferior",
    [0x2083] = "threeinferior",
    [0x2084] = "fourinferior",
    [0x2085] = "fiveinferior",
    [0x2086] = "sixinferior",
    [0x2087] = "seveninferior",
    [0x2088] = "eightinferior",
    [0x2089] = "nineinferior",
    [0x208D] = "parenleftinferior",
    [0x208E] = "parenrightinferior",
    [0x20A1] = "colonsign",
    [0x20A2] = "cruzeiro",
    [0x20A3] = "franc",
    [0x20A4] = "lira",
    [0x20A7] = "peseta",
    [0x20A9] = "won",
    [0x20AA] = "sheqelhebrew",
    [0x20AB] = "dong",
    [0x20AC] = "euro",
    [0x2103] = "centigrade",
    [0x2105] = "careof",
    [0x2109] = "fahrenheit",
    [0x2111] = "Ifraktur",
    [0x2113] = "lsquare",
    [0x2116] = "numero",
    [0x2118] = "weierstrass",
    [0x211C] = "Rfraktur",
    [0x211E] = "prescription",
    [0x2121] = "telephone",
    [0x2122] = "trademark",
    [0x2126] = "Omega",
    [0x212B] = "angstrom",
    [0x212E] = "estimated",
    [0x2135] = "aleph",
    [0x2153] = "onethird",
    [0x2154] = "twothirds",
    [0x215B] = "oneeighth",
    [0x215C] = "threeeighths",
    [0x215D] = "fiveeighths",
    [0x215E] = "seveneighths",
    [0x2160] = "Oneroman",
    [0x2161] = "Tworoman",
    [0x2162] = "Threeroman",
    [0x2163] = "Fourroman",
    [0x2164] = "Fiveroman",
    [0x2165] = "Sixroman",
    [0x2166] = "Sevenroman",
    [0x2167] = "Eightroman",
    [0x2168] = "Nineroman",
    [0x2169] = "Tenroman",
    [0x216A] = "Elevenroman",
    [0x216B] = "Twelveroman",
    [0x2170] = "oneroman",
    [0x2171] = "tworoman",
    [0x2172] = "threeroman",
    [0x2173] = "fourroman",
    [0x2174] = "fiveroman",
    [0x2175] = "sixroman",
    [0x2176] = "sevenroman",
    [0x2177] = "eightroman",
    [0x2178] = "nineroman",
    [0x2179] = "tenroman",
    [0x217A] = "elevenroman",
    [0x217B] = "twelveroman",
    [0x2190] = "arrowleft",
    [0x2191] = "arrowup",
    [0x2192] = "arrowright",
    [0x2193] = "arrowdown",
    [0x2194] = "arrowboth",
    [0x2195] = "arrowupdn",
    [0x2196] = "arrowupleft",
    [0x2197] = "arrowupright",
    [0x2198] = "arrowdownright",
    [0x2199] = "arrowdownleft",
    [0x21A8] = "arrowupdownbase",
    [0x21B5] = "carriagereturn",
    [0x21BC] = "harpoonleftbarbup",
    [0x21C0] = "harpoonrightbarbup",
    [0x21C4] = "arrowrightoverleft",
    [0x21C5] = "arrowupleftofdown",
    [0x21C6] = "arrowleftoverright",
    [0x21CD] = "arrowleftdblstroke",
    [0x21CF] = "arrowrightdblstroke",
    [0x21D0] = "arrowleftdbl",
    [0x21D1] = "arrowdblup",
    [0x21D2] = "dblarrowright",
    [0x21D3] = "arrowdbldown",
    [0x21D4] = "dblarrowleft",
    [0x21DE] = "pageup",
    [0x21DF] = "pagedown",
    [0x21E0] = "arrowdashleft",
    [0x21E1] = "arrowdashup",
    [0x21E2] = "arrowdashright",
    [0x21E3] = "arrowdashdown",
    [0x21E4] = "arrowtableft",
    [0x21E5] = "arrowtabright",
    [0x21E6] = "arrowleftwhite",
    [0x21E7] = "arrowupwhite",
    [0x21E8] = "arrowrightwhite",
    [0x21E9] = "arrowdownwhite",
    [0x21EA] = "capslock",
    [0x2200] = "universal",
    [0x2202] = "partialdiff",
    [0x2203] = "thereexists",
    [0x2205] = "emptyset",
    [0x2206] = "increment",
    [0x2207] = "nabla",
    [0x2208] = "element",
    [0x2209] = "notelementof",
    [0x220B] = "suchthat",
    [0x220C] = "notcontains",
    [0x220F] = "product",
    [0x2211] = "summation",
    [0x2212] = "minus",
    [0x2213] = "minusplus",
    [0x2215] = "divisionslash",
    [0x2217] = "asteriskmath",
    [0x2219] = "bulletoperator",
    [0x221A] = "radical",
    [0x221D] = "proportional",
    [0x221E] = "infinity",
    [0x221F] = "rightangle",
    [0x2220] = "angle",
    [0x2223] = "divides",
    [0x2225] = "parallel",
    [0x2226] = "notparallel",
    [0x2227] = "logicaland",
    [0x2228] = "logicalor",
    [0x2229] = "intersection",
    [0x222A] = "union",
    [0x222B] = "integral",
    [0x222C] = "dblintegral",
    [0x222E] = "contourintegral",
    [0x2234] = "therefore",
    [0x2235] = "because",
    [0x2236] = "ratio",
    [0x2237] = "proportion",
    [0x223C] = "tildeoperator",
    [0x223D] = "reversedtilde",
    [0x2243] = "asymptoticallyequal",
    [0x2245] = "congruent",
    [0x2248] = "approxequal",
    [0x224C] = "allequal",
    [0x2250] = "approaches",
    [0x2251] = "geometricallyequal",
    [0x2252] = "approxequalorimage",
    [0x2253] = "imageorapproximatelyequal",
    [0x2260] = "notequal",
    [0x2261] = "equivalence",
    [0x2262] = "notidentical",
    [0x2264] = "lessequal",
    [0x2265] = "greaterequal",
    [0x2266] = "lessoverequal",
    [0x2267] = "greateroverequal",
    [0x226A] = "muchless",
    [0x226B] = "muchgreater",
    [0x226E] = "notless",
    [0x226F] = "notgreater",
    [0x2270] = "notlessnorequal",
    [0x2271] = "notgreaternorequal",
    [0x2272] = "lessorequivalent",
    [0x2273] = "greaterorequivalent",
    [0x2276] = "lessorgreater",
    [0x2277] = "greaterorless",
    [0x2279] = "notgreaternorless",
    [0x227A] = "precedes",
    [0x227B] = "succeeds",
    [0x2280] = "notprecedes",
    [0x2281] = "notsucceeds",
    [0x2282] = "subset",
    [0x2283] = "superset",
    [0x2284] = "notsubset",
    [0x2285] = "notsuperset",
    [0x2286] = "subsetorequal",
    [0x2287] = "supersetorequal",
    [0x228A] = "subsetnotequal",
    [0x228B] = "supersetnotequal",
    [0x2295] = "pluscircle",
    [0x2296] = "minuscircle",
    [0x2297] = "timescircle",
    [0x2299] = "circleot",
    [0x22A3] = "tackleft",
    [0x22A4] = "tackdown",
    [0x22A5] = "perpendicular",
    [0x22BF] = "righttriangle",
    [0x22C5] = "dotmath",
    [0x22CE] = "curlyor",
    [0x22CF] = "curlyand",
    [0x22DA] = "lessequalorgreater",
    [0x22DB] = "greaterequalorless",
    [0x22EE] = "ellipsisvertical",
    [0x2302] = "house",
    [0x2303] = "control",
    [0x2305] = "projective",
    [0x2310] = "revlogicalnot",
    [0x2312] = "arc",
    [0x2318] = "propellor",
    [0x2320] = "integraltp",
    [0x2321] = "integralbt",
    [0x2325] = "option",
    [0x2326] = "deleteright",
    [0x2327] = "clear",
    [0x2329] = "angleleft",
    [0x232A] = "angleright",
    [0x232B] = "deleteleft",
    [0x2423] = "blank",
    [0x2460] = "onecircle",
    [0x2461] = "twocircle",
    [0x2462] = "threecircle",
    [0x2463] = "fourcircle",
    [0x2464] = "fivecircle",
    [0x2465] = "sixcircle",
    [0x2466] = "sevencircle",
    [0x2467] = "eightcircle",
    [0x2468] = "ninecircle",
    [0x2469] = "tencircle",
    [0x246A] = "elevencircle",
    [0x246B] = "twelvecircle",
    [0x246C] = "thirteencircle",
    [0x246D] = "fourteencircle",
    [0x246E] = "fifteencircle",
    [0x246F] = "sixteencircle",
    [0x2470] = "seventeencircle",
    [0x2471] = "eighteencircle",
    [0x2472] = "nineteencircle",
    [0x2473] = "twentycircle",
    [0x2474] = "oneparen",
    [0x2475] = "twoparen",
    [0x2476] = "threeparen",
    [0x2477] = "fourparen",
    [0x2478] = "fiveparen",
    [0x2479] = "sixparen",
    [0x247A] = "sevenparen",
    [0x247B] = "eightparen",
    [0x247C] = "nineparen",
    [0x247D] = "tenparen",
    [0x247E] = "elevenparen",
    [0x247F] = "twelveparen",
    [0x2480] = "thirteenparen",
    [0x2481] = "fourteenparen",
    [0x2482] = "fifteenparen",
    [0x2483] = "sixteenparen",
    [0x2484] = "seventeenparen",
    [0x2485] = "eighteenparen",
    [0x2486] = "nineteenparen",
    [0x2487] = "twentyparen",
    [0x2488] = "oneperiod",
    [0x2489] = "twoperiod",
    [0x248A] = "threeperiod",
    [0x248B] = "fourperiod",
    [0x248C] = "fiveperiod",
    [0x248D] = "sixperiod",
    [0x248E] = "sevenperiod",
    [0x248F] = "eightperiod",
    [0x2490] = "nineperiod",
    [0x2491] = "tenperiod",
    [0x2492] = "elevenperiod",
    [0x2493] = "twelveperiod",
    [0x2494] = "thirteenperiod",
    [0x2495] = "fourteenperiod",
    [0x2496] = "fifteenperiod",
    [0x2497] = "sixteenperiod",
    [0x2498] = "seventeenperiod",
    [0x2499] = "eighteenperiod",
    [0x249A] = "nineteenperiod",
    [0x249B] = "twentyperiod",
    [0x249C] = "aparen",
    [0x249D] = "bparen",
    [0x249E] = "cparen",
    [0x249F] = "dparen",
    [0x24A0] = "eparen",
    [0x24A1] = "fparen",
    [0x24A2] = "gparen",
    [0x24A3] = "hparen",
    [0x24A4] = "iparen",
    [0x24A5] = "jparen",
    [0x24A6] = "kparen",
    [0x24A7] = "lparen",
    [0x24A8] = "mparen",
    [0x24A9] = "nparen",
    [0x24AA] = "oparen",
    [0x24AB] = "pparen",
    [0x24AC] = "qparen",
    [0x24AD] = "rparen",
    [0x24AE] = "sparen",
    [0x24AF] = "tparen",
    [0x24B0] = "uparen",
    [0x24B1] = "vparen",
    [0x24B2] = "wparen",
    [0x24B3] = "xparen",
    [0x24B4] = "yparen",
    [0x24B5] = "zparen",
    [0x24B6] = "Acircle",
    [0x24B7] = "Bcircle",
    [0x24B8] = "Ccircle",
    [0x24B9] = "Dcircle",
    [0x24BA] = "Ecircle",
    [0x24BB] = "Fcircle",
    [0x24BC] = "Gcircle",
    [0x24BD] = "Hcircle",
    [0x24BE] = "Icircle",
    [0x24BF] = "Jcircle",
    [0x24C0] = "Kcircle",
    [0x24C1] = "Lcircle",
    [0x24C2] = "Mcircle",
    [0x24C3] = "Ncircle",
    [0x24C4] = "Ocircle",
    [0x24C5] = "Pcircle",
    [0x24C6] = "Qcircle",
    [0x24C7] = "Rcircle",
    [0x24C8] = "Scircle",
    [0x24C9] = "Tcircle",
    [0x24CA] = "Ucircle",
    [0x24CB] = "Vcircle",
    [0x24CC] = "Wcircle",
    [0x24CD] = "Xcircle",
    [0x24CE] = "Ycircle",
    [0x24CF] = "Zcircle",
    [0x24D0] = "acircle",
    [0x24D1] = "bcircle",
    [0x24D2] = "ccircle",
    [0x24D3] = "dcircle",
    [0x24D4] = "ecircle",
    [0x24D5] = "fcircle",
    [0x24D6] = "gcircle",
    [0x24D7] = "hcircle",
    [0x24D8] = "icircle",
    [0x24D9] = "jcircle",
    [0x24DA] = "kcircle",
    [0x24DB] = "lcircle",
    [0x24DC] = "mcircle",
    [0x24DD] = "ncircle",
    [0x24DE] = "ocircle",
    [0x24DF] = "pcircle",
    [0x24E0] = "qcircle",
    [0x24E1] = "rcircle",
    [0x24E2] = "scircle",
    [0x24E3] = "tcircle",
    [0x24E4] = "ucircle",
    [0x24E5] = "vcircle",
    [0x24E6] = "wcircle",
    [0x24E7] = "xcircle",
    [0x24E8] = "ycircle",
    [0x24E9] = "zcircle",
    [0x2500] = "SF100000",
    [0x2502] = "SF110000",
    [0x250C] = "SF010000",
    [0x2510] = "SF030000",
    [0x2514] = "SF020000",
    [0x2518] = "SF040000",
    [0x251C] = "SF080000",
    [0x2524] = "SF090000",
    [0x252C] = "SF060000",
    [0x2534] = "SF070000",
    [0x253C] = "SF050000",
    [0x2550] = "SF430000",
    [0x2551] = "SF240000",
    [0x2552] = "SF510000",
    [0x2553] = "SF520000",
    [0x2554] = "SF390000",
    [0x2555] = "SF220000",
    [0x2556] = "SF210000",
    [0x2557] = "SF250000",
    [0x2558] = "SF500000",
    [0x2559] = "SF490000",
    [0x255A] = "SF380000",
    [0x255B] = "SF280000",
    [0x255C] = "SF270000",
    [0x255D] = "SF260000",
    [0x255E] = "SF360000",
    [0x255F] = "SF370000",
    [0x2560] = "SF420000",
    [0x2561] = "SF190000",
    [0x2562] = "SF200000",
    [0x2563] = "SF230000",
    [0x2564] = "SF470000",
    [0x2565] = "SF480000",
    [0x2566] = "SF410000",
    [0x2567] = "SF450000",
    [0x2568] = "SF460000",
    [0x2569] = "SF400000",
    [0x256A] = "SF540000",
    [0x256B] = "SF530000",
    [0x256C] = "SF440000",
    [0x2580] = "upblock",
    [0x2584] = "dnblock",
    [0x2588] = "block",
    [0x258C] = "lfblock",
    [0x2590] = "rtblock",
    [0x2591] = "shadelight",
    [0x2592] = "shademedium",
    [0x2593] = "shadedark",
    [0x25A0] = "filledbox",
    [0x25A1] = "whitesquare",
    [0x25A3] = "squarewhitewithsmallblack",
    [0x25A4] = "squarehorizontalfill",
    [0x25A5] = "squareverticalfill",
    [0x25A6] = "squareorthogonalcrosshatchfill",
    [0x25A7] = "squareupperlefttolowerrightfill",
    [0x25A8] = "squareupperrighttolowerleftfill",
    [0x25A9] = "squarediagonalcrosshatchfill",
    [0x25AA] = "blacksmallsquare",
    [0x25AB] = "whitesmallsquare",
    [0x25AC] = "filledrect",
    [0x25B2] = "triagup",
    [0x25B3] = "whiteuppointingtriangle",
    [0x25B4] = "blackuppointingsmalltriangle",
    [0x25B5] = "whiteuppointingsmalltriangle",
    [0x25B6] = "blackrightpointingtriangle",
    [0x25B7] = "whiterightpointingtriangle",
    [0x25B9] = "whiterightpointingsmalltriangle",
    [0x25BA] = "triagrt",
    [0x25BC] = "triagdn",
    [0x25BD] = "whitedownpointingtriangle",
    [0x25BF] = "whitedownpointingsmalltriangle",
    [0x25C0] = "blackleftpointingtriangle",
    [0x25C1] = "whiteleftpointingtriangle",
    [0x25C3] = "whiteleftpointingsmalltriangle",
    [0x25C4] = "triaglf",
    [0x25C6] = "blackdiamond",
    [0x25C7] = "whitediamond",
    [0x25C8] = "whitediamondcontainingblacksmalldiamond",
    [0x25C9] = "fisheye",
    [0x25CA] = "lozenge",
    [0x25CB] = "whitecircle",
    [0x25CC] = "dottedcircle",
    [0x25CE] = "bullseye",
    [0x25CF] = "blackcircle",
    [0x25D0] = "circlewithlefthalfblack",
    [0x25D1] = "circlewithrighthalfblack",
    [0x25D8] = "invbullet",
    [0x25D9] = "whitecircleinverse",
    [0x25E2] = "blacklowerrighttriangle",
    [0x25E3] = "blacklowerlefttriangle",
    [0x25E4] = "blackupperlefttriangle",
    [0x25E5] = "blackupperrighttriangle",
    [0x25E6] = "whitebullet",
    [0x25EF] = "largecircle",
    [0x2605] = "blackstar",
    [0x2606] = "whitestar",
    [0x260E] = "telephoneblack",
    [0x260F] = "whitetelephone",
    [0x261C] = "pointingindexleftwhite",
    [0x261D] = "pointingindexupwhite",
    [0x261E] = "pointingindexrightwhite",
    [0x261F] = "pointingindexdownwhite",
    [0x262F] = "yinyang",
    [0x263A] = "whitesmilingface",
    [0x263B] = "invsmileface",
    [0x263C] = "sun",
    [0x2640] = "venus",
    [0x2641] = "earth",
    [0x2642] = "mars",
    [0x2660] = "spadesuitblack",
    [0x2661] = "heartsuitwhite",
    [0x2662] = "diamondsuitwhite",
    [0x2663] = "clubsuitblack",
    [0x2664] = "spadesuitwhite",
    [0x2665] = "heartsuitblack",
    [0x2666] = "diamond",
    [0x2667] = "clubsuitwhite",
    [0x2668] = "hotsprings",
    [0x2669] = "quarternote",
    [0x266A] = "musicalnote",
    [0x266B] = "musicalnotedbl",
    [0x266C] = "beamedsixteenthnotes",
    [0x266D] = "musicflatsign",
    [0x266F] = "musicsharpsign",
    [0x2713] = "checkmark",
    [0x278A] = "onecircleinversesansserif",
    [0x278B] = "twocircleinversesansserif",
    [0x278C] = "threecircleinversesansserif",
    [0x278D] = "fourcircleinversesansserif",
    [0x278E] = "fivecircleinversesansserif",
    [0x278F] = "sixcircleinversesansserif",
    [0x2790] = "sevencircleinversesansserif",
    [0x2791] = "eightcircleinversesansserif",
    [0x2792] = "ninecircleinversesansserif",
    [0x279E] = "arrowrightheavy",
    [0x3000] = "ideographicspace",
    [0x3001] = "ideographiccomma",
    [0x3002] = "ideographicperiod",
    [0x3003] = "dittomark",
    [0x3004] = "jis",
    [0x3005] = "ideographiciterationmark",
    [0x3006] = "ideographicclose",
    [0x3007] = "ideographiczero",
    [0x3008] = "anglebracketleft",
    [0x3009] = "anglebracketright",
    [0x300A] = "dblanglebracketleft",
    [0x300B] = "dblanglebracketright",
    [0x300C] = "cornerbracketleft",
    [0x300D] = "cornerbracketright",
    [0x300E] = "whitecornerbracketleft",
    [0x300F] = "whitecornerbracketright",
    [0x3010] = "blacklenticularbracketleft",
    [0x3011] = "blacklenticularbracketright",
    [0x3012] = "postalmark",
    [0x3013] = "getamark",
    [0x3014] = "tortoiseshellbracketleft",
    [0x3015] = "tortoiseshellbracketright",
    [0x3016] = "whitelenticularbracketleft",
    [0x3017] = "whitelenticularbracketright",
    [0x3018] = "whitetortoiseshellbracketleft",
    [0x3019] = "whitetortoiseshellbracketright",
    [0x301C] = "wavedash",
    [0x301D] = "quotedblprimereversed",
    [0x301E] = "quotedblprime",
    [0x3020] = "postalmarkface",
    [0x3021] = "onehangzhou",
    [0x3022] = "twohangzhou",
    [0x3023] = "threehangzhou",
    [0x3024] = "fourhangzhou",
    [0x3025] = "fivehangzhou",
    [0x3026] = "sixhangzhou",
    [0x3027] = "sevenhangzhou",
    [0x3028] = "eighthangzhou",
    [0x3029] = "ninehangzhou",
    [0x3036] = "circlepostalmark",
    [0x3041] = "asmallhiragana",
    [0x3042] = "ahiragana",
    [0x3043] = "ismallhiragana",
    [0x3044] = "ihiragana",
    [0x3045] = "usmallhiragana",
    [0x3046] = "uhiragana",
    [0x3047] = "esmallhiragana",
    [0x3048] = "ehiragana",
    [0x3049] = "osmallhiragana",
    [0x304A] = "ohiragana",
    [0x304B] = "kahiragana",
    [0x304C] = "gahiragana",
    [0x304D] = "kihiragana",
    [0x304E] = "gihiragana",
    [0x304F] = "kuhiragana",
    [0x3050] = "guhiragana",
    [0x3051] = "kehiragana",
    [0x3052] = "gehiragana",
    [0x3053] = "kohiragana",
    [0x3054] = "gohiragana",
    [0x3055] = "sahiragana",
    [0x3056] = "zahiragana",
    [0x3057] = "sihiragana",
    [0x3058] = "zihiragana",
    [0x3059] = "suhiragana",
    [0x305A] = "zuhiragana",
    [0x305B] = "sehiragana",
    [0x305C] = "zehiragana",
    [0x305D] = "sohiragana",
    [0x305E] = "zohiragana",
    [0x305F] = "tahiragana",
    [0x3060] = "dahiragana",
    [0x3061] = "tihiragana",
    [0x3062] = "dihiragana",
    [0x3063] = "tusmallhiragana",
    [0x3064] = "tuhiragana",
    [0x3065] = "duhiragana",
    [0x3066] = "tehiragana",
    [0x3067] = "dehiragana",
    [0x3068] = "tohiragana",
    [0x3069] = "dohiragana",
    [0x306A] = "nahiragana",
    [0x306B] = "nihiragana",
    [0x306C] = "nuhiragana",
    [0x306D] = "nehiragana",
    [0x306E] = "nohiragana",
    [0x306F] = "hahiragana",
    [0x3070] = "bahiragana",
    [0x3071] = "pahiragana",
    [0x3072] = "hihiragana",
    [0x3073] = "bihiragana",
    [0x3074] = "pihiragana",
    [0x3075] = "huhiragana",
    [0x3076] = "buhiragana",
    [0x3077] = "puhiragana",
    [0x3078] = "hehiragana",
    [0x3079] = "behiragana",
    [0x307A] = "pehiragana",
    [0x307B] = "hohiragana",
    [0x307C] = "bohiragana",
    [0x307D] = "pohiragana",
    [0x307E] = "mahiragana",
    [0x307F] = "mihiragana",
    [0x3080] = "muhiragana",
    [0x3081] = "mehiragana",
    [0x3082] = "mohiragana",
    [0x3083] = "yasmallhiragana",
    [0x3084] = "yahiragana",
    [0x3085] = "yusmallhiragana",
    [0x3086] = "yuhiragana",
    [0x3087] = "yosmallhiragana",
    [0x3088] = "yohiragana",
    [0x3089] = "rahiragana",
    [0x308A] = "rihiragana",
    [0x308B] = "ruhiragana",
    [0x308C] = "rehiragana",
    [0x308D] = "rohiragana",
    [0x308E] = "wasmallhiragana",
    [0x308F] = "wahiragana",
    [0x3090] = "wihiragana",
    [0x3091] = "wehiragana",
    [0x3092] = "wohiragana",
    [0x3093] = "nhiragana",
    [0x3094] = "vuhiragana",
    [0x309B] = "voicedmarkkana",
    [0x309C] = "semivoicedmarkkana",
    [0x309D] = "iterationhiragana",
    [0x309E] = "voicediterationhiragana",
    [0x30A1] = "asmallkatakana",
    [0x30A2] = "akatakana",
    [0x30A3] = "ismallkatakana",
    [0x30A4] = "ikatakana",
    [0x30A5] = "usmallkatakana",
    [0x30A6] = "ukatakana",
    [0x30A7] = "esmallkatakana",
    [0x30A8] = "ekatakana",
    [0x30A9] = "osmallkatakana",
    [0x30AA] = "okatakana",
    [0x30AB] = "kakatakana",
    [0x30AC] = "gakatakana",
    [0x30AD] = "kikatakana",
    [0x30AE] = "gikatakana",
    [0x30AF] = "kukatakana",
    [0x30B0] = "gukatakana",
    [0x30B1] = "kekatakana",
    [0x30B2] = "gekatakana",
    [0x30B3] = "kokatakana",
    [0x30B4] = "gokatakana",
    [0x30B5] = "sakatakana",
    [0x30B6] = "zakatakana",
    [0x30B7] = "sikatakana",
    [0x30B8] = "zikatakana",
    [0x30B9] = "sukatakana",
    [0x30BA] = "zukatakana",
    [0x30BB] = "sekatakana",
    [0x30BC] = "zekatakana",
    [0x30BD] = "sokatakana",
    [0x30BE] = "zokatakana",
    [0x30BF] = "takatakana",
    [0x30C0] = "dakatakana",
    [0x30C1] = "tikatakana",
    [0x30C2] = "dikatakana",
    [0x30C3] = "tusmallkatakana",
    [0x30C4] = "tukatakana",
    [0x30C5] = "dukatakana",
    [0x30C6] = "tekatakana",
    [0x30C7] = "dekatakana",
    [0x30C8] = "tokatakana",
    [0x30C9] = "dokatakana",
    [0x30CA] = "nakatakana",
    [0x30CB] = "nikatakana",
    [0x30CC] = "nukatakana",
    [0x30CD] = "nekatakana",
    [0x30CE] = "nokatakana",
    [0x30CF] = "hakatakana",
    [0x30D0] = "bakatakana",
    [0x30D1] = "pakatakana",
    [0x30D2] = "hikatakana",
    [0x30D3] = "bikatakana",
    [0x30D4] = "pikatakana",
    [0x30D5] = "hukatakana",
    [0x30D6] = "bukatakana",
    [0x30D7] = "pukatakana",
    [0x30D8] = "hekatakana",
    [0x30D9] = "bekatakana",
    [0x30DA] = "pekatakana",
    [0x30DB] = "hokatakana",
    [0x30DC] = "bokatakana",
    [0x30DD] = "pokatakana",
    [0x30DE] = "makatakana",
    [0x30DF] = "mikatakana",
    [0x30E0] = "mukatakana",
    [0x30E1] = "mekatakana",
    [0x30E2] = "mokatakana",
    [0x30E3] = "yasmallkatakana",
    [0x30E4] = "yakatakana",
    [0x30E5] = "yusmallkatakana",
    [0x30E6] = "yukatakana",
    [0x30E7] = "yosmallkatakana",
    [0x30E8] = "yokatakana",
    [0x30E9] = "rakatakana",
    [0x30EA] = "rikatakana",
    [0x30EB] = "rukatakana",
    [0x30EC] = "rekatakana",
    [0x30ED] = "rokatakana",
    [0x30EE] = "wasmallkatakana",
    [0x30EF] = "wakatakana",
    [0x30F0] = "wikatakana",
    [0x30F1] = "wekatakana",
    [0x30F2] = "wokatakana",
    [0x30F3] = "nkatakana",
    [0x30F4] = "vukatakana",
    [0x30F5] = "kasmallkatakana",
    [0x30F6] = "kesmallkatakana",
    [0x30F7] = "vakatakana",
    [0x30F8] = "vikatakana",
    [0x30F9] = "vekatakana",
    [0x30FA] = "vokatakana",
    [0x30FB] = "dotkatakana",
    [0x30FC] = "prolongedkana",
    [0x30FD] = "iterationkatakana",
    [0x30FE] = "voicediterationkatakana",
    [0x3105] = "bbopomofo",
    [0x3106] = "pbopomofo",
    [0x3107] = "mbopomofo",
    [0x3108] = "fbopomofo",
    [0x3109] = "dbopomofo",
    [0x310A] = "tbopomofo",
    [0x310B] = "nbopomofo",
    [0x310C] = "lbopomofo",
    [0x310D] = "gbopomofo",
    [0x310E] = "kbopomofo",
    [0x310F] = "hbopomofo",
    [0x3110] = "jbopomofo",
    [0x3111] = "qbopomofo",
    [0x3112] = "xbopomofo",
    [0x3113] = "zhbopomofo",
    [0x3114] = "chbopomofo",
    [0x3115] = "shbopomofo",
    [0x3116] = "rbopomofo",
    [0x3117] = "zbopomofo",
    [0x3118] = "cbopomofo",
    [0x3119] = "sbopomofo",
    [0x311A] = "abopomofo",
    [0x311B] = "obopomofo",
    [0x311C] = "ebopomofo",
    [0x311D] = "ehbopomofo",
    [0x311E] = "aibopomofo",
    [0x311F] = "eibopomofo",
    [0x3120] = "aubopomofo",
    [0x3121] = "oubopomofo",
    [0x3122] = "anbopomofo",
    [0x3123] = "enbopomofo",
    [0x3124] = "angbopomofo",
    [0x3125] = "engbopomofo",
    [0x3126] = "erbopomofo",
    [0x3127] = "ibopomofo",
    [0x3128] = "ubopomofo",
    [0x3129] = "iubopomofo",
    [0x3131] = "kiyeokkorean",
    [0x3132] = "ssangkiyeokkorean",
    [0x3133] = "kiyeoksioskorean",
    [0x3134] = "nieunkorean",
    [0x3135] = "nieuncieuckorean",
    [0x3136] = "nieunhieuhkorean",
    [0x3137] = "tikeutkorean",
    [0x3138] = "ssangtikeutkorean",
    [0x3139] = "rieulkorean",
    [0x313A] = "rieulkiyeokkorean",
    [0x313B] = "rieulmieumkorean",
    [0x313C] = "rieulpieupkorean",
    [0x313D] = "rieulsioskorean",
    [0x313E] = "rieulthieuthkorean",
    [0x313F] = "rieulphieuphkorean",
    [0x3140] = "rieulhieuhkorean",
    [0x3141] = "mieumkorean",
    [0x3142] = "pieupkorean",
    [0x3143] = "ssangpieupkorean",
    [0x3144] = "pieupsioskorean",
    [0x3145] = "sioskorean",
    [0x3146] = "ssangsioskorean",
    [0x3147] = "ieungkorean",
    [0x3148] = "cieuckorean",
    [0x3149] = "ssangcieuckorean",
    [0x314A] = "chieuchkorean",
    [0x314B] = "khieukhkorean",
    [0x314C] = "thieuthkorean",
    [0x314D] = "phieuphkorean",
    [0x314E] = "hieuhkorean",
    [0x314F] = "akorean",
    [0x3150] = "aekorean",
    [0x3151] = "yakorean",
    [0x3152] = "yaekorean",
    [0x3153] = "eokorean",
    [0x3154] = "ekorean",
    [0x3155] = "yeokorean",
    [0x3156] = "yekorean",
    [0x3157] = "okorean",
    [0x3158] = "wakorean",
    [0x3159] = "waekorean",
    [0x315A] = "oekorean",
    [0x315B] = "yokorean",
    [0x315C] = "ukorean",
    [0x315D] = "weokorean",
    [0x315E] = "wekorean",
    [0x315F] = "wikorean",
    [0x3160] = "yukorean",
    [0x3161] = "eukorean",
    [0x3162] = "yikorean",
    [0x3163] = "ikorean",
    [0x3164] = "hangulfiller",
    [0x3165] = "ssangnieunkorean",
    [0x3166] = "nieuntikeutkorean",
    [0x3167] = "nieunsioskorean",
    [0x3168] = "nieunpansioskorean",
    [0x3169] = "rieulkiyeoksioskorean",
    [0x316A] = "rieultikeutkorean",
    [0x316B] = "rieulpieupsioskorean",
    [0x316C] = "rieulpansioskorean",
    [0x316D] = "rieulyeorinhieuhkorean",
    [0x316E] = "mieumpieupkorean",
    [0x316F] = "mieumsioskorean",
    [0x3170] = "mieumpansioskorean",
    [0x3171] = "kapyeounmieumkorean",
    [0x3172] = "pieupkiyeokkorean",
    [0x3173] = "pieuptikeutkorean",
    [0x3174] = "pieupsioskiyeokkorean",
    [0x3175] = "pieupsiostikeutkorean",
    [0x3176] = "pieupcieuckorean",
    [0x3177] = "pieupthieuthkorean",
    [0x3178] = "kapyeounpieupkorean",
    [0x3179] = "kapyeounssangpieupkorean",
    [0x317A] = "sioskiyeokkorean",
    [0x317B] = "siosnieunkorean",
    [0x317C] = "siostikeutkorean",
    [0x317D] = "siospieupkorean",
    [0x317E] = "sioscieuckorean",
    [0x317F] = "pansioskorean",
    [0x3180] = "ssangieungkorean",
    [0x3181] = "yesieungkorean",
    [0x3182] = "yesieungsioskorean",
    [0x3183] = "yesieungpansioskorean",
    [0x3184] = "kapyeounphieuphkorean",
    [0x3185] = "ssanghieuhkorean",
    [0x3186] = "yeorinhieuhkorean",
    [0x3187] = "yoyakorean",
    [0x3188] = "yoyaekorean",
    [0x3189] = "yoikorean",
    [0x318A] = "yuyeokorean",
    [0x318B] = "yuyekorean",
    [0x318C] = "yuikorean",
    [0x318D] = "araeakorean",
    [0x318E] = "araeaekorean",
    [0x3200] = "kiyeokparenkorean",
    [0x3201] = "nieunparenkorean",
    [0x3202] = "tikeutparenkorean",
    [0x3203] = "rieulparenkorean",
    [0x3204] = "mieumparenkorean",
    [0x3205] = "pieupparenkorean",
    [0x3206] = "siosparenkorean",
    [0x3207] = "ieungparenkorean",
    [0x3208] = "cieucparenkorean",
    [0x3209] = "chieuchparenkorean",
    [0x320A] = "khieukhparenkorean",
    [0x320B] = "thieuthparenkorean",
    [0x320C] = "phieuphparenkorean",
    [0x320D] = "hieuhparenkorean",
    [0x320E] = "kiyeokaparenkorean",
    [0x320F] = "nieunaparenkorean",
    [0x3210] = "tikeutaparenkorean",
    [0x3211] = "rieulaparenkorean",
    [0x3212] = "mieumaparenkorean",
    [0x3213] = "pieupaparenkorean",
    [0x3214] = "siosaparenkorean",
    [0x3215] = "ieungaparenkorean",
    [0x3216] = "cieucaparenkorean",
    [0x3217] = "chieuchaparenkorean",
    [0x3218] = "khieukhaparenkorean",
    [0x3219] = "thieuthaparenkorean",
    [0x321A] = "phieuphaparenkorean",
    [0x321B] = "hieuhaparenkorean",
    [0x321C] = "cieucuparenkorean",
    [0x3220] = "oneideographicparen",
    [0x3221] = "twoideographicparen",
    [0x3222] = "threeideographicparen",
    [0x3223] = "fourideographicparen",
    [0x3224] = "fiveideographicparen",
    [0x3225] = "sixideographicparen",
    [0x3226] = "sevenideographicparen",
    [0x3227] = "eightideographicparen",
    [0x3228] = "nineideographicparen",
    [0x3229] = "tenideographicparen",
    [0x322A] = "ideographicmoonparen",
    [0x322B] = "ideographicfireparen",
    [0x322C] = "ideographicwaterparen",
    [0x322D] = "ideographicwoodparen",
    [0x322E] = "ideographicmetalparen",
    [0x322F] = "ideographicearthparen",
    [0x3230] = "ideographicsunparen",
    [0x3231] = "ideographicstockparen",
    [0x3232] = "ideographichaveparen",
    [0x3233] = "ideographicsocietyparen",
    [0x3234] = "ideographicnameparen",
    [0x3235] = "ideographicspecialparen",
    [0x3236] = "ideographicfinancialparen",
    [0x3237] = "ideographiccongratulationparen",
    [0x3238] = "ideographiclaborparen",
    [0x3239] = "ideographicrepresentparen",
    [0x323A] = "ideographiccallparen",
    [0x323B] = "ideographicstudyparen",
    [0x323C] = "ideographicsuperviseparen",
    [0x323D] = "ideographicenterpriseparen",
    [0x323E] = "ideographicresourceparen",
    [0x323F] = "ideographicallianceparen",
    [0x3240] = "ideographicfestivalparen",
    [0x3242] = "ideographicselfparen",
    [0x3243] = "ideographicreachparen",
    [0x3260] = "kiyeokcirclekorean",
    [0x3261] = "nieuncirclekorean",
    [0x3262] = "tikeutcirclekorean",
    [0x3263] = "rieulcirclekorean",
    [0x3264] = "mieumcirclekorean",
    [0x3265] = "pieupcirclekorean",
    [0x3266] = "sioscirclekorean",
    [0x3267] = "ieungcirclekorean",
    [0x3268] = "cieuccirclekorean",
    [0x3269] = "chieuchcirclekorean",
    [0x326A] = "khieukhcirclekorean",
    [0x326B] = "thieuthcirclekorean",
    [0x326C] = "phieuphcirclekorean",
    [0x326D] = "hieuhcirclekorean",
    [0x326E] = "kiyeokacirclekorean",
    [0x326F] = "nieunacirclekorean",
    [0x3270] = "tikeutacirclekorean",
    [0x3271] = "rieulacirclekorean",
    [0x3272] = "mieumacirclekorean",
    [0x3273] = "pieupacirclekorean",
    [0x3274] = "siosacirclekorean",
    [0x3275] = "ieungacirclekorean",
    [0x3276] = "cieucacirclekorean",
    [0x3277] = "chieuchacirclekorean",
    [0x3278] = "khieukhacirclekorean",
    [0x3279] = "thieuthacirclekorean",
    [0x327A] = "phieuphacirclekorean",
    [0x327B] = "hieuhacirclekorean",
    [0x327F] = "koreanstandardsymbol",
    [0x328A] = "ideographmooncircle",
    [0x328B] = "ideographfirecircle",
    [0x328C] = "ideographwatercircle",
    [0x328D] = "ideographwoodcircle",
    [0x328E] = "ideographmetalcircle",
    [0x328F] = "ideographearthcircle",
    [0x3290] = "ideographsuncircle",
    [0x3294] = "ideographnamecircle",
    [0x3296] = "ideographicfinancialcircle",
    [0x3298] = "ideographiclaborcircle",
    [0x3299] = "ideographicsecretcircle",
    [0x329D] = "ideographicexcellentcircle",
    [0x329E] = "ideographicprintcircle",
    [0x32A3] = "ideographiccorrectcircle",
    [0x32A4] = "ideographichighcircle",
    [0x32A5] = "ideographiccentrecircle",
    [0x32A6] = "ideographiclowcircle",
    [0x32A7] = "ideographicleftcircle",
    [0x32A8] = "ideographicrightcircle",
    [0x32A9] = "ideographicmedicinecircle",
    [0x3300] = "apaatosquare",
    [0x3303] = "aarusquare",
    [0x3305] = "intisquare",
    [0x330D] = "karoriisquare",
    [0x3314] = "kirosquare",
    [0x3315] = "kiroguramusquare",
    [0x3316] = "kiromeetorusquare",
    [0x3318] = "guramusquare",
    [0x331E] = "kooposquare",
    [0x3322] = "sentisquare",
    [0x3323] = "sentosquare",
    [0x3326] = "dorusquare",
    [0x3327] = "tonsquare",
    [0x332A] = "haitusquare",
    [0x332B] = "paasentosquare",
    [0x3331] = "birusquare",
    [0x3333] = "huiitosquare",
    [0x3336] = "hekutaarusquare",
    [0x3339] = "herutusquare",
    [0x333B] = "peezisquare",
    [0x3342] = "hoonsquare",
    [0x3347] = "mansyonsquare",
    [0x3349] = "mirisquare",
    [0x334A] = "miribaarusquare",
    [0x334D] = "meetorusquare",
    [0x334E] = "yaadosquare",
    [0x3351] = "rittorusquare",
    [0x3357] = "wattosquare",
    [0x337B] = "heiseierasquare",
    [0x337C] = "syouwaerasquare",
    [0x337D] = "taisyouerasquare",
    [0x337E] = "meizierasquare",
    [0x337F] = "corporationsquare",
    [0x3380] = "paampssquare",
    [0x3381] = "nasquare",
    [0x3382] = "muasquare",
    [0x3383] = "masquare",
    [0x3384] = "kasquare",
    [0x3385] = "KBsquare",
    [0x3386] = "MBsquare",
    [0x3387] = "GBsquare",
    [0x3388] = "calsquare",
    [0x3389] = "kcalsquare",
    [0x338A] = "pfsquare",
    [0x338B] = "nfsquare",
    [0x338C] = "mufsquare",
    [0x338D] = "mugsquare",
    [0x338E] = "squaremg",
    [0x338F] = "squarekg",
    [0x3390] = "Hzsquare",
    [0x3391] = "khzsquare",
    [0x3392] = "mhzsquare",
    [0x3393] = "ghzsquare",
    [0x3394] = "thzsquare",
    [0x3395] = "mulsquare",
    [0x3396] = "mlsquare",
    [0x3397] = "dlsquare",
    [0x3398] = "klsquare",
    [0x3399] = "fmsquare",
    [0x339A] = "nmsquare",
    [0x339B] = "mumsquare",
    [0x339C] = "squaremm",
    [0x339D] = "squarecm",
    [0x339E] = "squarekm",
    [0x339F] = "mmsquaredsquare",
    [0x33A0] = "cmsquaredsquare",
    [0x33A1] = "squaremsquared",
    [0x33A2] = "kmsquaredsquare",
    [0x33A3] = "mmcubedsquare",
    [0x33A4] = "cmcubedsquare",
    [0x33A5] = "mcubedsquare",
    [0x33A6] = "kmcubedsquare",
    [0x33A7] = "moverssquare",
    [0x33A8] = "moverssquaredsquare",
    [0x33A9] = "pasquare",
    [0x33AA] = "kpasquare",
    [0x33AB] = "mpasquare",
    [0x33AC] = "gpasquare",
    [0x33AD] = "radsquare",
    [0x33AE] = "radoverssquare",
    [0x33AF] = "radoverssquaredsquare",
    [0x33B0] = "pssquare",
    [0x33B1] = "nssquare",
    [0x33B2] = "mussquare",
    [0x33B3] = "mssquare",
    [0x33B4] = "pvsquare",
    [0x33B5] = "nvsquare",
    [0x33B6] = "muvsquare",
    [0x33B7] = "mvsquare",
    [0x33B8] = "kvsquare",
    [0x33B9] = "mvmegasquare",
    [0x33BA] = "pwsquare",
    [0x33BB] = "nwsquare",
    [0x33BC] = "muwsquare",
    [0x33BD] = "mwsquare",
    [0x33BE] = "kwsquare",
    [0x33BF] = "mwmegasquare",
    [0x33C0] = "kohmsquare",
    [0x33C1] = "mohmsquare",
    [0x33C2] = "amsquare",
    [0x33C3] = "bqsquare",
    [0x33C4] = "squarecc",
    [0x33C5] = "cdsquare",
    [0x33C6] = "coverkgsquare",
    [0x33C7] = "cosquare",
    [0x33C8] = "dbsquare",
    [0x33C9] = "gysquare",
    [0x33CA] = "hasquare",
    [0x33CB] = "HPsquare",
    [0x33CD] = "KKsquare",
    [0x33CE] = "squarekmcapital",
    [0x33CF] = "ktsquare",
    [0x33D0] = "lmsquare",
    [0x33D1] = "squareln",
    [0x33D2] = "squarelog",
    [0x33D3] = "lxsquare",
    [0x33D4] = "mbsquare",
    [0x33D5] = "squaremil",
    [0x33D6] = "molsquare",
    [0x33D8] = "pmsquare",
    [0x33DB] = "srsquare",
    [0x33DC] = "svsquare",
    [0x33DD] = "wbsquare",
    [0x5344] = "twentyhangzhou",
    [0xF6BE] = "dotlessj",
    [0xF6BF] = "LL",
    [0xF6C0] = "ll",
    [0xF6C3] = "commaaccent",
    [0xF6C4] = "afii10063",
    [0xF6C5] = "afii10064",
    [0xF6C6] = "afii10192",
    [0xF6C7] = "afii10831",
    [0xF6C8] = "afii10832",
    [0xF6C9] = "Acute",
    [0xF6CA] = "Caron",
    [0xF6CB] = "Dieresis",
    [0xF6CC] = "DieresisAcute",
    [0xF6CD] = "DieresisGrave",
    [0xF6CE] = "Grave",
    [0xF6CF] = "Hungarumlaut",
    [0xF6D0] = "Macron",
    [0xF6D1] = "cyrBreve",
    [0xF6D2] = "cyrFlex",
    [0xF6D3] = "dblGrave",
    [0xF6D4] = "cyrbreve",
    [0xF6D5] = "cyrflex",
    [0xF6D6] = "dblgrave",
    [0xF6D7] = "dieresisacute",
    [0xF6D8] = "dieresisgrave",
    [0xF6D9] = "copyrightserif",
    [0xF6DA] = "registerserif",
    [0xF6DB] = "trademarkserif",
    [0xF6DC] = "onefitted",
    [0xF6DD] = "rupiah",
    [0xF6DE] = "threequartersemdash",
    [0xF6DF] = "centinferior",
    [0xF6E0] = "centsuperior",
    [0xF6E1] = "commainferior",
    [0xF6E2] = "commasuperior",
    [0xF6E3] = "dollarinferior",
    [0xF6E4] = "dollarsuperior",
    [0xF6E5] = "hypheninferior",
    [0xF6E6] = "hyphensuperior",
    [0xF6E7] = "periodinferior",
    [0xF6E8] = "periodsuperior",
    [0xF6E9] = "asuperior",
    [0xF6EA] = "bsuperior",
    [0xF6EB] = "dsuperior",
    [0xF6EC] = "esuperior",
    [0xF6ED] = "isuperior",
    [0xF6EE] = "lsuperior",
    [0xF6EF] = "msuperior",
    [0xF6F0] = "osuperior",
    [0xF6F1] = "rsuperior",
    [0xF6F2] = "ssuperior",
    [0xF6F3] = "tsuperior",
    [0xF6F4] = "Brevesmall",
    [0xF6F5] = "Caronsmall",
    [0xF6F6] = "Circumflexsmall",
    [0xF6F7] = "Dotaccentsmall",
    [0xF6F8] = "Hungarumlautsmall",
    [0xF6F9] = "Lslashsmall",
    [0xF6FA] = "OEsmall",
    [0xF6FB] = "Ogoneksmall",
    [0xF6FC] = "Ringsmall",
    [0xF6FD] = "Scaronsmall",
    [0xF6FE] = "Tildesmall",
    [0xF6FF] = "Zcaronsmall",
    [0xF721] = "exclamsmall",
    [0xF724] = "dollaroldstyle",
    [0xF726] = "ampersandsmall",
    [0xF730] = "zerooldstyle",
    [0xF731] = "oneoldstyle",
    [0xF732] = "twooldstyle",
    [0xF733] = "threeoldstyle",
    [0xF734] = "fouroldstyle",
    [0xF735] = "fiveoldstyle",
    [0xF736] = "sixoldstyle",
    [0xF737] = "sevenoldstyle",
    [0xF738] = "eightoldstyle",
    [0xF739] = "nineoldstyle",
    [0xF73F] = "questionsmall",
    [0xF760] = "Gravesmall",
    [0xF761] = "Asmall",
    [0xF762] = "Bsmall",
    [0xF763] = "Csmall",
    [0xF764] = "Dsmall",
    [0xF765] = "Esmall",
    [0xF766] = "Fsmall",
    [0xF767] = "Gsmall",
    [0xF768] = "Hsmall",
    [0xF769] = "Ismall",
    [0xF76A] = "Jsmall",
    [0xF76B] = "Ksmall",
    [0xF76C] = "Lsmall",
    [0xF76D] = "Msmall",
    [0xF76E] = "Nsmall",
    [0xF76F] = "Osmall",
    [0xF770] = "Psmall",
    [0xF771] = "Qsmall",
    [0xF772] = "Rsmall",
    [0xF773] = "Ssmall",
    [0xF774] = "Tsmall",
    [0xF775] = "Usmall",
    [0xF776] = "Vsmall",
    [0xF777] = "Wsmall",
    [0xF778] = "Xsmall",
    [0xF779] = "Ysmall",
    [0xF77A] = "Zsmall",
    [0xF7A1] = "exclamdownsmall",
    [0xF7A2] = "centoldstyle",
    [0xF7A8] = "Dieresissmall",
    [0xF7AF] = "Macronsmall",
    [0xF7B4] = "Acutesmall",
    [0xF7B8] = "Cedillasmall",
    [0xF7BF] = "questiondownsmall",
    [0xF7E0] = "Agravesmall",
    [0xF7E1] = "Aacutesmall",
    [0xF7E2] = "Acircumflexsmall",
    [0xF7E3] = "Atildesmall",
    [0xF7E4] = "Adieresissmall",
    [0xF7E5] = "Aringsmall",
    [0xF7E6] = "AEsmall",
    [0xF7E7] = "Ccedillasmall",
    [0xF7E8] = "Egravesmall",
    [0xF7E9] = "Eacutesmall",
    [0xF7EA] = "Ecircumflexsmall",
    [0xF7EB] = "Edieresissmall",
    [0xF7EC] = "Igravesmall",
    [0xF7ED] = "Iacutesmall",
    [0xF7EE] = "Icircumflexsmall",
    [0xF7EF] = "Idieresissmall",
    [0xF7F0] = "Ethsmall",
    [0xF7F1] = "Ntildesmall",
    [0xF7F2] = "Ogravesmall",
    [0xF7F3] = "Oacutesmall",
    [0xF7F4] = "Ocircumflexsmall",
    [0xF7F5] = "Otildesmall",
    [0xF7F6] = "Odieresissmall",
    [0xF7F8] = "Oslashsmall",
    [0xF7F9] = "Ugravesmall",
    [0xF7FA] = "Uacutesmall",
    [0xF7FB] = "Ucircumflexsmall",
    [0xF7FC] = "Udieresissmall",
    [0xF7FD] = "Yacutesmall",
    [0xF7FE] = "Thornsmall",
    [0xF7FF] = "Ydieresissmall",
    [0xF884] = "maihanakatleftthai",
    [0xF885] = "saraileftthai",
    [0xF886] = "saraiileftthai",
    [0xF887] = "saraueleftthai",
    [0xF888] = "saraueeleftthai",
    [0xF889] = "maitaikhuleftthai",
    [0xF88A] = "maiekupperleftthai",
    [0xF88B] = "maieklowrightthai",
    [0xF88C] = "maieklowleftthai",
    [0xF88D] = "maithoupperleftthai",
    [0xF88E] = "maitholowrightthai",
    [0xF88F] = "maitholowleftthai",
    [0xF890] = "maitriupperleftthai",
    [0xF891] = "maitrilowrightthai",
    [0xF892] = "maitrilowleftthai",
    [0xF893] = "maichattawaupperleftthai",
    [0xF894] = "maichattawalowrightthai",
    [0xF895] = "maichattawalowleftthai",
    [0xF896] = "thanthakhatupperleftthai",
    [0xF897] = "thanthakhatlowrightthai",
    [0xF898] = "thanthakhatlowleftthai",
    [0xF899] = "nikhahitleftthai",
    [0xF8E5] = "radicalex",
    [0xF8E6] = "arrowvertex",
    [0xF8E7] = "arrowhorizex",
    [0xF8E8] = "registersans",
    [0xF8E9] = "copyrightsans",
    [0xF8EA] = "trademarksans",
    [0xF8EB] = "parenlefttp",
    [0xF8EC] = "parenleftex",
    [0xF8ED] = "parenleftbt",
    [0xF8EE] = "bracketlefttp",
    [0xF8EF] = "bracketleftex",
    [0xF8F0] = "bracketleftbt",
    [0xF8F1] = "bracelefttp",
    [0xF8F2] = "braceleftmid",
    [0xF8F3] = "braceleftbt",
    [0xF8F4] = "braceex",
    [0xF8F5] = "integralex",
    [0xF8F6] = "parenrighttp",
    [0xF8F7] = "parenrightex",
    [0xF8F8] = "parenrightbt",
    [0xF8F9] = "bracketrighttp",
    [0xF8FA] = "bracketrightex",
    [0xF8FB] = "bracketrightbt",
    [0xF8FC] = "bracerighttp",
    [0xF8FD] = "bracerightmid",
    [0xF8FE] = "bracerightbt",
    [0xF8FF] = "apple",
    [0xFB00] = "ff",
    [0xFB01] = "fi",
    [0xFB02] = "fl",
    [0xFB03] = "ffi",
    [0xFB04] = "ffl",
    [0xFB1F] = "yodyodpatahhebrew",
    [0xFB20] = "ayinaltonehebrew",
    [0xFB2A] = "shinshindothebrew",
    [0xFB2B] = "shinsindothebrew",
    [0xFB2C] = "shindageshshindothebrew",
    [0xFB2D] = "shindageshsindothebrew",
    [0xFB2E] = "alefpatahhebrew",
    [0xFB2F] = "alefqamatshebrew",
    [0xFB30] = "alefdageshhebrew",
    [0xFB31] = "betdageshhebrew",
    [0xFB32] = "gimeldageshhebrew",
    [0xFB33] = "daletdageshhebrew",
    [0xFB34] = "hedageshhebrew",
    [0xFB35] = "vavdageshhebrew",
    [0xFB36] = "zayindageshhebrew",
    [0xFB38] = "tetdageshhebrew",
    [0xFB39] = "yoddageshhebrew",
    [0xFB3A] = "finalkafdageshhebrew",
    [0xFB3B] = "kafdageshhebrew",
    [0xFB3C] = "lameddageshhebrew",
    [0xFB3E] = "memdageshhebrew",
    [0xFB40] = "nundageshhebrew",
    [0xFB41] = "samekhdageshhebrew",
    [0xFB43] = "pefinaldageshhebrew",
    [0xFB44] = "pedageshhebrew",
    [0xFB46] = "tsadidageshhebrew",
    [0xFB47] = "qofdageshhebrew",
    [0xFB48] = "reshdageshhebrew",
    [0xFB49] = "shindageshhebrew",
    [0xFB4A] = "tavdageshhebrew",
    [0xFB4B] = "vavholamhebrew",
    [0xFB4C] = "betrafehebrew",
    [0xFB4D] = "kafrafehebrew",
    [0xFB4E] = "perafehebrew",
    [0xFB4F] = "aleflamedhebrew",
    [0xFB57] = "pehfinalarabic",
    [0xFB58] = "pehinitialarabic",
    [0xFB59] = "pehmedialarabic",
    [0xFB67] = "ttehfinalarabic",
    [0xFB68] = "ttehinitialarabic",
    [0xFB69] = "ttehmedialarabic",
    [0xFB6B] = "vehfinalarabic",
    [0xFB6C] = "vehinitialarabic",
    [0xFB6D] = "vehmedialarabic",
    [0xFB7B] = "tchehfinalarabic",
    [0xFB7C] = "tchehmeeminitialarabic",
    [0xFB7D] = "tchehmedialarabic",
    [0xFB89] = "ddalfinalarabic",
    [0xFB8B] = "jehfinalarabic",
    [0xFB8D] = "rrehfinalarabic",
    [0xFB93] = "gaffinalarabic",
    [0xFB94] = "gafinitialarabic",
    [0xFB95] = "gafmedialarabic",
    [0xFB9F] = "noonghunnafinalarabic",
    [0xFBA4] = "hehhamzaaboveisolatedarabic",
    [0xFBA5] = "hehhamzaabovefinalarabic",
    [0xFBA7] = "hehfinalaltonearabic",
    [0xFBA8] = "hehinitialaltonearabic",
    [0xFBA9] = "hehmedialaltonearabic",
    [0xFBAF] = "yehbarreefinalarabic",
    [0xFC08] = "behmeemisolatedarabic",
    [0xFC0B] = "tehjeemisolatedarabic",
    [0xFC0C] = "tehhahisolatedarabic",
    [0xFC0E] = "tehmeemisolatedarabic",
    [0xFC48] = "meemmeemisolatedarabic",
    [0xFC4B] = "noonjeemisolatedarabic",
    [0xFC4E] = "noonmeemisolatedarabic",
    [0xFC58] = "yehmeemisolatedarabic",
    [0xFC5E] = "shaddadammatanarabic",
    [0xFC5F] = "shaddakasratanarabic",
    [0xFC60] = "shaddafathaarabic",
    [0xFC61] = "shaddadammaarabic",
    [0xFC62] = "shaddakasraarabic",
    [0xFC6D] = "behnoonfinalarabic",
    [0xFC73] = "tehnoonfinalarabic",
    [0xFC8D] = "noonnoonfinalarabic",
    [0xFC94] = "yehnoonfinalarabic",
    [0xFC9F] = "behmeeminitialarabic",
    [0xFCA1] = "tehjeeminitialarabic",
    [0xFCA2] = "tehhahinitialarabic",
    [0xFCA4] = "tehmeeminitialarabic",
    [0xFCC9] = "lamjeeminitialarabic",
    [0xFCCA] = "lamhahinitialarabic",
    [0xFCCB] = "lamkhahinitialarabic",
    [0xFCCC] = "lammeeminitialarabic",
    [0xFCD1] = "meemmeeminitialarabic",
    [0xFCD2] = "noonjeeminitialarabic",
    [0xFCD5] = "noonmeeminitialarabic",
    [0xFCDD] = "yehmeeminitialarabic",
    [0xFD3E] = "parenleftaltonearabic",
    [0xFD3F] = "parenrightaltonearabic",
    [0xFD88] = "lammeemhahinitialarabic",
    [0xFDF2] = "lamlamhehisolatedarabic",
    [0xFDFA] = "sallallahoualayhewasallamarabic",
    [0xFE30] = "twodotleadervertical",
    [0xFE31] = "emdashvertical",
    [0xFE32] = "endashvertical",
    [0xFE33] = "underscorevertical",
    [0xFE34] = "wavyunderscorevertical",
    [0xFE35] = "parenleftvertical",
    [0xFE36] = "parenrightvertical",
    [0xFE37] = "braceleftvertical",
    [0xFE38] = "bracerightvertical",
    [0xFE39] = "tortoiseshellbracketleftvertical",
    [0xFE3A] = "tortoiseshellbracketrightvertical",
    [0xFE3B] = "blacklenticularbracketleftvertical",
    [0xFE3C] = "blacklenticularbracketrightvertical",
    [0xFE3D] = "dblanglebracketleftvertical",
    [0xFE3E] = "dblanglebracketrightvertical",
    [0xFE3F] = "anglebracketleftvertical",
    [0xFE40] = "anglebracketrightvertical",
    [0xFE41] = "cornerbracketleftvertical",
    [0xFE42] = "cornerbracketrightvertical",
    [0xFE43] = "whitecornerbracketleftvertical",
    [0xFE44] = "whitecornerbracketrightvertical",
    [0xFE49] = "overlinedashed",
    [0xFE4A] = "overlinecenterline",
    [0xFE4B] = "overlinewavy",
    [0xFE4C] = "overlinedblwavy",
    [0xFE4D] = "lowlinedashed",
    [0xFE4E] = "lowlinecenterline",
    [0xFE4F] = "underscorewavy",
    [0xFE50] = "commasmall",
    [0xFE52] = "periodsmall",
    [0xFE54] = "semicolonsmall",
    [0xFE55] = "colonsmall",
    [0xFE59] = "parenleftsmall",
    [0xFE5A] = "parenrightsmall",
    [0xFE5B] = "braceleftsmall",
    [0xFE5C] = "bracerightsmall",
    [0xFE5D] = "tortoiseshellbracketleftsmall",
    [0xFE5E] = "tortoiseshellbracketrightsmall",
    [0xFE5F] = "numbersignsmall",
    [0xFE61] = "asterisksmall",
    [0xFE62] = "plussmall",
    [0xFE63] = "hyphensmall",
    [0xFE64] = "lesssmall",
    [0xFE65] = "greatersmall",
    [0xFE66] = "equalsmall",
    [0xFE69] = "dollarsmall",
    [0xFE6A] = "percentsmall",
    [0xFE6B] = "atsmall",
    [0xFE82] = "alefmaddaabovefinalarabic",
    [0xFE84] = "alefhamzaabovefinalarabic",
    [0xFE86] = "wawhamzaabovefinalarabic",
    [0xFE88] = "alefhamzabelowfinalarabic",
    [0xFE8A] = "yehhamzaabovefinalarabic",
    [0xFE8B] = "yehhamzaaboveinitialarabic",
    [0xFE8C] = "yehhamzaabovemedialarabic",
    [0xFE8E] = "aleffinalarabic",
    [0xFE90] = "behfinalarabic",
    [0xFE91] = "behinitialarabic",
    [0xFE92] = "behmedialarabic",
    [0xFE94] = "tehmarbutafinalarabic",
    [0xFE96] = "tehfinalarabic",
    [0xFE97] = "tehinitialarabic",
    [0xFE98] = "tehmedialarabic",
    [0xFE9A] = "thehfinalarabic",
    [0xFE9B] = "thehinitialarabic",
    [0xFE9C] = "thehmedialarabic",
    [0xFE9E] = "jeemfinalarabic",
    [0xFE9F] = "jeeminitialarabic",
    [0xFEA0] = "jeemmedialarabic",
    [0xFEA2] = "hahfinalarabic",
    [0xFEA3] = "hahinitialarabic",
    [0xFEA4] = "hahmedialarabic",
    [0xFEA6] = "khahfinalarabic",
    [0xFEA7] = "khahinitialarabic",
    [0xFEA8] = "khahmedialarabic",
    [0xFEAA] = "dalfinalarabic",
    [0xFEAC] = "thalfinalarabic",
    [0xFEAE] = "rehfinalarabic",
    [0xFEB0] = "zainfinalarabic",
    [0xFEB2] = "seenfinalarabic",
    [0xFEB3] = "seeninitialarabic",
    [0xFEB4] = "seenmedialarabic",
    [0xFEB6] = "sheenfinalarabic",
    [0xFEB7] = "sheeninitialarabic",
    [0xFEB8] = "sheenmedialarabic",
    [0xFEBA] = "sadfinalarabic",
    [0xFEBB] = "sadinitialarabic",
    [0xFEBC] = "sadmedialarabic",
    [0xFEBE] = "dadfinalarabic",
    [0xFEBF] = "dadinitialarabic",
    [0xFEC0] = "dadmedialarabic",
    [0xFEC2] = "tahfinalarabic",
    [0xFEC3] = "tahinitialarabic",
    [0xFEC4] = "tahmedialarabic",
    [0xFEC6] = "zahfinalarabic",
    [0xFEC7] = "zahinitialarabic",
    [0xFEC8] = "zahmedialarabic",
    [0xFECA] = "ainfinalarabic",
    [0xFECB] = "aininitialarabic",
    [0xFECC] = "ainmedialarabic",
    [0xFECE] = "ghainfinalarabic",
    [0xFECF] = "ghaininitialarabic",
    [0xFED0] = "ghainmedialarabic",
    [0xFED2] = "fehfinalarabic",
    [0xFED3] = "fehinitialarabic",
    [0xFED4] = "fehmedialarabic",
    [0xFED6] = "qaffinalarabic",
    [0xFED7] = "qafinitialarabic",
    [0xFED8] = "qafmedialarabic",
    [0xFEDA] = "kaffinalarabic",
    [0xFEDB] = "kafinitialarabic",
    [0xFEDC] = "kafmedialarabic",
    [0xFEDE] = "lamfinalarabic",
    [0xFEDF] = "lammeemkhahinitialarabic",
    [0xFEE0] = "lammedialarabic",
    [0xFEE2] = "meemfinalarabic",
    [0xFEE3] = "meeminitialarabic",
    [0xFEE4] = "meemmedialarabic",
    [0xFEE6] = "noonfinalarabic",
    [0xFEE7] = "nooninitialarabic",
    [0xFEE8] = "noonmedialarabic",
    [0xFEEA] = "hehfinalarabic",
    [0xFEEB] = "hehinitialarabic",
    [0xFEEC] = "hehmedialarabic",
    [0xFEEE] = "wawfinalarabic",
    [0xFEF0] = "alefmaksurafinalarabic",
    [0xFEF2] = "yehfinalarabic",
    [0xFEF3] = "yehinitialarabic",
    [0xFEF4] = "yehmedialarabic",
    [0xFEF5] = "lamalefmaddaaboveisolatedarabic",
    [0xFEF6] = "lamalefmaddaabovefinalarabic",
    [0xFEF7] = "lamalefhamzaaboveisolatedarabic",
    [0xFEF8] = "lamalefhamzaabovefinalarabic",
    [0xFEF9] = "lamalefhamzabelowisolatedarabic",
    [0xFEFA] = "lamalefhamzabelowfinalarabic",
    [0xFEFB] = "lamalefisolatedarabic",
    [0xFEFC] = "lamaleffinalarabic",
    [0xFEFF] = "zerowidthjoiner",
    [0xFF01] = "exclammonospace",
    [0xFF02] = "quotedblmonospace",
    [0xFF03] = "numbersignmonospace",
    [0xFF04] = "dollarmonospace",
    [0xFF05] = "percentmonospace",
    [0xFF06] = "ampersandmonospace",
    [0xFF07] = "quotesinglemonospace",
    [0xFF08] = "parenleftmonospace",
    [0xFF09] = "parenrightmonospace",
    [0xFF0A] = "asteriskmonospace",
    [0xFF0B] = "plusmonospace",
    [0xFF0C] = "commamonospace",
    [0xFF0D] = "hyphenmonospace",
    [0xFF0E] = "periodmonospace",
    [0xFF0F] = "slashmonospace",
    [0xFF10] = "zeromonospace",
    [0xFF11] = "onemonospace",
    [0xFF12] = "twomonospace",
    [0xFF13] = "threemonospace",
    [0xFF14] = "fourmonospace",
    [0xFF15] = "fivemonospace",
    [0xFF16] = "sixmonospace",
    [0xFF17] = "sevenmonospace",
    [0xFF18] = "eightmonospace",
    [0xFF19] = "ninemonospace",
    [0xFF1A] = "colonmonospace",
    [0xFF1B] = "semicolonmonospace",
    [0xFF1C] = "lessmonospace",
    [0xFF1D] = "equalmonospace",
    [0xFF1E] = "greatermonospace",
    [0xFF1F] = "questionmonospace",
    [0xFF20] = "atmonospace",
    [0xFF21] = "Amonospace",
    [0xFF22] = "Bmonospace",
    [0xFF23] = "Cmonospace",
    [0xFF24] = "Dmonospace",
    [0xFF25] = "Emonospace",
    [0xFF26] = "Fmonospace",
    [0xFF27] = "Gmonospace",
    [0xFF28] = "Hmonospace",
    [0xFF29] = "Imonospace",
    [0xFF2A] = "Jmonospace",
    [0xFF2B] = "Kmonospace",
    [0xFF2C] = "Lmonospace",
    [0xFF2D] = "Mmonospace",
    [0xFF2E] = "Nmonospace",
    [0xFF2F] = "Omonospace",
    [0xFF30] = "Pmonospace",
    [0xFF31] = "Qmonospace",
    [0xFF32] = "Rmonospace",
    [0xFF33] = "Smonospace",
    [0xFF34] = "Tmonospace",
    [0xFF35] = "Umonospace",
    [0xFF36] = "Vmonospace",
    [0xFF37] = "Wmonospace",
    [0xFF38] = "Xmonospace",
    [0xFF39] = "Ymonospace",
    [0xFF3A] = "Zmonospace",
    [0xFF3B] = "bracketleftmonospace",
    [0xFF3C] = "backslashmonospace",
    [0xFF3D] = "bracketrightmonospace",
    [0xFF3E] = "asciicircummonospace",
    [0xFF3F] = "underscoremonospace",
    [0xFF40] = "gravemonospace",
    [0xFF41] = "amonospace",
    [0xFF42] = "bmonospace",
    [0xFF43] = "cmonospace",
    [0xFF44] = "dmonospace",
    [0xFF45] = "emonospace",
    [0xFF46] = "fmonospace",
    [0xFF47] = "gmonospace",
    [0xFF48] = "hmonospace",
    [0xFF49] = "imonospace",
    [0xFF4A] = "jmonospace",
    [0xFF4B] = "kmonospace",
    [0xFF4C] = "lmonospace",
    [0xFF4D] = "mmonospace",
    [0xFF4E] = "nmonospace",
    [0xFF4F] = "omonospace",
    [0xFF50] = "pmonospace",
    [0xFF51] = "qmonospace",
    [0xFF52] = "rmonospace",
    [0xFF53] = "smonospace",
    [0xFF54] = "tmonospace",
    [0xFF55] = "umonospace",
    [0xFF56] = "vmonospace",
    [0xFF57] = "wmonospace",
    [0xFF58] = "xmonospace",
    [0xFF59] = "ymonospace",
    [0xFF5A] = "zmonospace",
    [0xFF5B] = "braceleftmonospace",
    [0xFF5C] = "barmonospace",
    [0xFF5D] = "bracerightmonospace",
    [0xFF5E] = "asciitildemonospace",
    [0xFF61] = "periodhalfwidth",
    [0xFF62] = "cornerbracketlefthalfwidth",
    [0xFF63] = "cornerbracketrighthalfwidth",
    [0xFF64] = "ideographiccommaleft",
    [0xFF65] = "middledotkatakanahalfwidth",
    [0xFF66] = "wokatakanahalfwidth",
    [0xFF67] = "asmallkatakanahalfwidth",
    [0xFF68] = "ismallkatakanahalfwidth",
    [0xFF69] = "usmallkatakanahalfwidth",
    [0xFF6A] = "esmallkatakanahalfwidth",
    [0xFF6B] = "osmallkatakanahalfwidth",
    [0xFF6C] = "yasmallkatakanahalfwidth",
    [0xFF6D] = "yusmallkatakanahalfwidth",
    [0xFF6E] = "yosmallkatakanahalfwidth",
    [0xFF6F] = "tusmallkatakanahalfwidth",
    [0xFF70] = "katahiraprolongmarkhalfwidth",
    [0xFF71] = "akatakanahalfwidth",
    [0xFF72] = "ikatakanahalfwidth",
    [0xFF73] = "ukatakanahalfwidth",
    [0xFF74] = "ekatakanahalfwidth",
    [0xFF75] = "okatakanahalfwidth",
    [0xFF76] = "kakatakanahalfwidth",
    [0xFF77] = "kikatakanahalfwidth",
    [0xFF78] = "kukatakanahalfwidth",
    [0xFF79] = "kekatakanahalfwidth",
    [0xFF7A] = "kokatakanahalfwidth",
    [0xFF7B] = "sakatakanahalfwidth",
    [0xFF7C] = "sikatakanahalfwidth",
    [0xFF7D] = "sukatakanahalfwidth",
    [0xFF7E] = "sekatakanahalfwidth",
    [0xFF7F] = "sokatakanahalfwidth",
    [0xFF80] = "takatakanahalfwidth",
    [0xFF81] = "tikatakanahalfwidth",
    [0xFF82] = "tukatakanahalfwidth",
    [0xFF83] = "tekatakanahalfwidth",
    [0xFF84] = "tokatakanahalfwidth",
    [0xFF85] = "nakatakanahalfwidth",
    [0xFF86] = "nikatakanahalfwidth",
    [0xFF87] = "nukatakanahalfwidth",
    [0xFF88] = "nekatakanahalfwidth",
    [0xFF89] = "nokatakanahalfwidth",
    [0xFF8A] = "hakatakanahalfwidth",
    [0xFF8B] = "hikatakanahalfwidth",
    [0xFF8C] = "hukatakanahalfwidth",
    [0xFF8D] = "hekatakanahalfwidth",
    [0xFF8E] = "hokatakanahalfwidth",
    [0xFF8F] = "makatakanahalfwidth",
    [0xFF90] = "mikatakanahalfwidth",
    [0xFF91] = "mukatakanahalfwidth",
    [0xFF92] = "mekatakanahalfwidth",
    [0xFF93] = "mokatakanahalfwidth",
    [0xFF94] = "yakatakanahalfwidth",
    [0xFF95] = "yukatakanahalfwidth",
    [0xFF96] = "yokatakanahalfwidth",
    [0xFF97] = "rakatakanahalfwidth",
    [0xFF98] = "rikatakanahalfwidth",
    [0xFF99] = "rukatakanahalfwidth",
    [0xFF9A] = "rekatakanahalfwidth",
    [0xFF9B] = "rokatakanahalfwidth",
    [0xFF9C] = "wakatakanahalfwidth",
    [0xFF9D] = "nkatakanahalfwidth",
    [0xFF9E] = "voicedmarkkanahalfwidth",
    [0xFF9F] = "semivoicedmarkkanahalfwidth",
    [0xFFE0] = "centmonospace",
    [0xFFE1] = "sterlingmonospace",
    [0xFFE3] = "macronmonospace",
    [0xFFE5] = "yenmonospace",
    [0xFFE6] = "wonmonospace",
}

agl.unicodes = allocate(table.swapped(agl.names)) -- to unicode

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules = { } end modules ['font-def'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat, gmatch, match, find, lower = string.format, table.concat, string.gmatch, string.match, string.find, string.lower
local tostring, next = tostring, next
local lpegmatch = lpeg.match

local allocate = utilities.storage.allocate

local trace_defining     = false  trackers  .register("fonts.defining", function(v) trace_defining     = v end)
local directive_embedall = false  directives.register("fonts.embedall", function(v) directive_embedall = v end)

trackers.register("fonts.loading", "fonts.defining", "otf.loading", "afm.loading", "tfm.loading")
trackers.register("fonts.all", "fonts.*", "otf.*", "afm.*", "tfm.*")

local report_define = logs.new("define fonts")
local report_afm    = logs.new("load afm")

--[[ldx--
<p>Here we deal with defining fonts. We do so by intercepting the
default loader that only handles <l n='tfm'/>.</p>
--ldx]]--

local fonts         = fonts
local tfm           = fonts.tfm
local vf            = fonts.vf
local fontcsnames   = fonts.csnames

fonts.used          = allocate()

tfm.readers         = tfm.readers or { }
tfm.fonts           = allocate()
tfm.internalized    = allocate() -- internal tex numbers

local readers       = tfm.readers
local sequence      = allocate { 'otf', 'ttf', 'afm', 'tfm' }
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

function definers.registersplit(symbol,action)
    addspecifier(symbol)
    variants[symbol] = action
end

function definers.makespecification(specification, lookup, name, sub, method, detail, size)
    size = size or 655360
    if trace_defining then
        report_define("%s -> lookup: %s, name: %s, sub: %s, method: %s, detail: %s",
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
        local t = { }
        local normal = features.normal
        if normal and next(normal) then
            local f = sortedhashkeys(normal)
            for i=1,#f do
                local v = f[i]
                if v ~= "number" and v ~= "features" then -- i need to figure this out, features
                    t[#t+1] = v .. '=' .. tostring(normal[v])
                end
            end
        end
        local vtf = features.vtf
        if vtf and next(vtf) then
            local f = sortedhashkeys(vtf)
            for i=1,#f do
                local v = f[i]
                t[#t+1] = v .. '=' .. tostring(vtf[v])
            end
        end
--~ if specification.mathsize then
--~     t[#t+1] = "mathsize=" .. specification.mathsize
--~ end
        if #t > 0 then
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
--~     local mathsize = specification.mathsize or 0
--~     if mathsize > 0 then
--~         local textsize = specification.textsize
--~         if fallbacks then
--~             return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ] @ ' .. fallbacks
--~         else
--~             return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ]'
--~         end
--~     else
        if fallbacks then
            return hash .. ' @ ' .. tostring(size) .. ' @ ' .. fallbacks
        else
            return hash .. ' @ ' .. tostring(size)
        end
--~     end
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
            tfmtable = readers[lower(forced)](specification)
            if not tfmtable then
                report_define("forced type %s of %s not found",forced,specification.name)
            end
        else
            for s=1,#sequence do -- reader sequence
                local reader = sequence[s]
                if readers[reader] then -- not really needed
                    if trace_defining then
                        report_define("trying (reader sequence driven) type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
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
            tfm.fonts[hash] = tfmtable
            fonts.designsizes[specification.hash] = tfmtable.designsize -- we only know this for sure after loading once
        --~ tfmtable.mode = specification.features.normal.mode or "base"
        end
    end
    if not tfmtable then
        report_define("font with name %s is not found",specification.name)
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
        local fontdata = tfm.read(specification)
        if fontdata then
            fontdata.hash = hash
            id = font.define(fontdata)
            definers.register(fontdata,id)
            tfm.cleanuptable(fontdata)
        else
            id = 0  -- signal
        end
    end
    return fonts.ids[id], id
end

--[[ldx--
<p>Next follow the readers. This code was written while <l n='luatex'/>
evolved. Each one has its own way of dealing with its format.</p>
--ldx]]--

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
        return tfm.read_from_tfm(specification)
    end
end

local function check_afm(specification,fullname)
    local foundname = findbinfile(fullname, 'afm') or "" -- just to be sure
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"afm")
    end
    if foundname == "" and tfm.autoprefixedafm then
        local encoding, shortname = match(fullname,"^(.-)%-(.*)$") -- context: encoding-name.*
        if encoding and shortname and fonts.enc.known[encoding] then
            shortname = findbinfile(shortname,'afm') or "" -- just to be sure
            if shortname ~= "" then
                foundname = shortname
                if trace_loading then
                    report_afm("stripping encoding prefix from filename %s",afmname)
                end
            end
        end
    end
    if foundname ~= "" then
        specification.filename, specification.format = foundname, "afm"
        return tfm.read_from_afm(specification)
    end
end

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

function readers.afm(specification,method)
    local fullname, tfmtable = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmtable = check_afm(specification,specification.name .. "." .. forced)
        end
        if not tfmtable then
            method = method or definers.method or "afm or tfm"
            if method == "tfm" then
                tfmtable = check_tfm(specification,specification.name)
            elseif method == "afm" then
                tfmtable = check_afm(specification,specification.name)
            elseif method == "tfm or afm" then
                tfmtable = check_tfm(specification,specification.name) or check_afm(specification,specification.name)
            else -- method == "afm or tfm" or method == "" then
                tfmtable = check_afm(specification,specification.name) or check_tfm(specification,specification.name)
            end
        end
    else
        tfmtable = check_afm(specification,fullname)
    end
    return tfmtable
end

-- maybe some day a set of names

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
        tfmtable = tfm.read_from_otf(specification)             -- we need to do it for all matches / todo
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

local lastdefined = nil -- we don't want this one to end up in s-tra-02

function definers.current() -- or maybe current
    return lastdefined
end

function definers.register(fontdata,id)
    if fontdata and id then
        local hash = fontdata.hash
        if not tfm.internalized[hash] then
            if trace_defining then
                report_define("loading at 2 id %s, hash: %s",id or "?",hash or "?")
            end
            fonts.identifiers[id] = fontdata
            fonts.characters [id] = fontdata.characters
            fonts.quads      [id] = fontdata.parameters and fontdata.parameters.quad
            -- todo: extra functions, e.g. setdigitwidth etc in list
            tfm.internalized[hash] = id
        end
    end
end

function definers.registered(hash)
    local id = tfm.internalized[hash]
    return id, id and fonts.ids[id]
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
        local fontdata = containers.read(fonts.cache,hash) -- for tracing purposes
    end
    local fontdata = definers.registered(hash) -- id
    if not fontdata then
        if specification.features.vtf and specification.features.vtf.preset then
            fontdata = tfm.make(specification)
        else
            fontdata = tfm.read(specification)
            if fontdata then
                tfm.checkvirtualid(fontdata)
            end
        end
        if cache_them then
            fontdata = containers.write(fonts.cache,hash,fontdata) -- for tracing purposes
        end
        if fontdata then
            fontdata.hash = hash
            fontdata.cache = "no"
            if id then
                definers.register(fontdata,id)
            end
        end
    end
    lastdefined = fontdata or id -- todo ! ! ! ! !
    if not fontdata then -- or id?
        report_define( "unknown font %s, loading aborted",specification.name)
    elseif trace_defining and type(fontdata) == "table" then
        report_define("using %s font with id %s, name:%s size:%s bytes:%s encoding:%s fullname:%s filename:%s",
            fontdata.type          or "unknown",
            id                     or "?",
            fontdata.name          or "?",
            fontdata.size          or "default",
            fontdata.encodingbytes or "?",
            fontdata.encodingname  or "unicode",
            fontdata.fullname      or "?",
            file.basename(fontdata.filename or "?"))
    end
    local cs = specification.cs
    if cs then
        fontcsnames[cs] = fontdata -- new (beware: locals can be forgotten)
    end
    statistics.stoptiming(fonts)
    return fontdata
end

function vf.find(name)
    name = file.removesuffix(file.basename(name))
    if tfm.resolvevirtualtoo then
        local format = fonts.logger.format(name)
        if format == 'tfm' or format == 'ofm' then
            if trace_defining then
                report_define("locating vf for %s",name)
            end
            return findbinfile(name,"ovf")
        else
            if trace_defining then
                report_define("vf for %s is already taken care of",name)
            end
            return nil -- ""
        end
    else
        if trace_defining then
            report_define("locating vf for %s",name)
        end
        return findbinfile(name,"ovf")
    end
end

--[[ldx--
<p>We overload both the <l n='tfm'/> and <l n='vf'/> readers.</p>
--ldx]]--

callbacks.register('define_font' , definers.read, "definition of fonts (tfmtable preparation)")
callbacks.register('find_vf_file', vf.find    , "locating virtual fonts, insofar needed") -- not that relevant any more

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
 --     list[k] = v:is_boolean()
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

definers.registersplit(":",colonized)

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
fonts.tfm.resolvevirtualtoo = false -- context specific (du eto resolver)
fonts.tfm.fontnamemode      = "specification" -- somehow latex needs this (changed name!)

-- readers

fonts.tfm.readers          = fonts.tfm.readers or { }
fonts.tfm.readers.sequence = { 'otf', 'ttf', 'tfm' }
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
    local tfmdata = fonts.ids[font.current()]
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


end -- closure
