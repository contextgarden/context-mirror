-- filename : l-string.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-string'] = 1.001

--~ function string.split(str, pat) -- taken from the lua wiki
--~     local t = {n = 0} -- so this table has a length field, traverse with ipairs then!
--~     local fpat = "(.-)"..pat
--~     local last_end = 1
--~     local s, e, cap = string.find(str, fpat, 1)
--~     while s ~= nil do
--~         if s~=1 or cap~="" then
--~             table.insert(t,cap)
--~         end
--~         last_end = e+1
--~         s, e, cap = string.find(str, fpat, last_end)
--~     end
--~     if last_end<=string.len(str) then
--~         table.insert(t,(string.sub(str,last_end)))
--~     end
--~     return t
--~ end

--~ function string:split(pat) -- taken from the lua wiki but adapted
--~     local t = { }          -- self and colon usage (faster)
--~     local fpat = "(.-)"..pat
--~     local last_end = 1
--~     local s, e, cap = self:find(fpat, 1)
--~     while s ~= nil do
--~         if s~=1 or cap~="" then
--~             t[#t+1] = cap
--~         end
--~         last_end = e+1
--~         s, e, cap = self:find(fpat, last_end)
--~     end
--~     if last_end <= #self then
--~         t[#t+1] = self:sub(last_end)
--~     end
--~     return t
--~ end

--~ a piece of brilliant code by Rici Lake (posted on lua list) -- only names changed
--~
--~ function string:splitter(pat)
--~    local st, g = 1, self:gmatch("()"..pat.."()")
--~    local function splitter(self)
--~      if st then
--~        local s, f = g()
--~        local rv = self:sub(st, (s or 0)-1)
--~        st = f
--~        return rv
--~      end
--~    end
--~    return splitter, self
--~ end

function string:splitter(pat)
    -- by Rici Lake (posted on lua list) -- only names changed
    -- p 79 ref man: () returns position of match
    local st, g = 1, self:gmatch("()("..pat..")")
    local function strgetter(self, segs, seps, sep, cap1, ...)
        st = sep and seps + #sep
        return self:sub(segs, (seps or 0) - 1), cap1 or sep, ...
    end
    local function strsplitter(self)
        if st then return strgetter(self, st, g()) end
    end
    return strsplitter, self
end

function string:split(separator)
    local t = {}
    for k in self:splitter(separator) do t[#t+1] = k end
    return t
end

-- faster than a string:split:

function string:splitchr(chr)
    if #self > 0 then
        local t = { }
        for s in string.gmatch(self..chr,"(.-)"..chr) do
            t[#t+1] = s
        end
        return t
    else
        return { }
    end
end

--~ function string.piecewise(str, pat, fnc) -- variant of split
--~     local fpat = "(.-)"..pat
--~     local last_end = 1
--~     local s, e, cap = string.find(str, fpat, 1)
--~     while s ~= nil do
--~         if s~=1 or cap~="" then
--~             fnc(cap)
--~         end
--~         last_end = e+1
--~         s, e, cap = string.find(str, fpat, last_end)
--~     end
--~     if last_end <= #str then
--~         fnc((string.sub(str,last_end)))
--~     end
--~ end

function string.piecewise(str, pat, fnc) -- variant of split
    for k in string.splitter(str,pat) do fnc(k) end
end

--~ function string.piecewise(str, pat, fnc) -- variant of split
--~     for k in str:splitter(pat) do fnc(k) end
--~ end

--~ do if lpeg then

--~     -- this alternative is 30% faster esp when we cache them
--~     -- problem: no expressions

--~     splitters = { }

--~     function string:split(separator)
--~         if #self > 0 then
--~             local split = splitters[separator]
--~             if not split then
--~                 -- based on code by Roberto
--~                 local p = lpeg.P(separator)
--~                 local c = lpeg.C((1-p)^0)
--~                 split = lpeg.Ct(c*(p*c)^0)
--~                 splitters[separator] = split
--~             end
--~             return split:match(self)
--~         else
--~             return { }
--~         end
--~     end

--~     string.splitchr = string.split

--~     function string:piecewise(separator,fnc)
--~         for _,v in pairs(self:split(separator)) do
--~             fnc(v)
--~         end
--~     end

--~ end end

string.chr_to_esc = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["^"] = "%^", ["$"] = "%$",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
    ["{"] = "%{", ["}"] = "%}"
}

function string:esc() -- variant 2
    return (self:gsub("(.)",string.chr_to_esc))
end

function string.unquote(str)
    return (str:gsub("^([\"\'])(.*)%1$","%2"))
end

function string.quote(str)
    return '"' .. str:unquote() .. '"'
end

function string:count(pattern) -- variant 3
    local n = 0
    for _ in self:gmatch(pattern) do
        n = n + 1
    end
    return n
end

function string:limit(n,sentinel)
    if #self > n then
        sentinel = sentinel or " ..."
        return self:sub(1,(n-#sentinel)) .. sentinel
    else
        return self
    end
end

function string:strip()
    return (self:gsub("^%s*(.-)%s*$", "%1"))
end

--~ function string.strip(str) -- slightly different
--~     return (string.gsub(string.gsub(str,"^%s*(.-)%s*$","%1"),"%s+"," "))
--~ end

function string:is_empty()
    return not self:find("%S")
end

function string:enhance(pattern,action)
    local ok, n = true, 0
    while ok do
        ok = false
        self = self:gsub(pattern, function(...)
            ok, n = true, n + 1
            return action(...)
        end)
    end
    return self, n
end

--~ function string:enhance(pattern,action)
--~     local ok, n = 0, 0
--~     repeat
--~         self, ok = self:gsub(pattern, function(...)
--~             n = n + 1
--~             return action(...)
--~         end)
--~     until ok == 0
--~     return self, n
--~ end

--~     function string:to_hex()
--~         if self then
--~             return (self:gsub("(.)",function(c)
--~                 return string.format("%02X",c:byte())
--~             end))
--~         else
--~             return ""
--~         end
--~     end

--~     function string:from_hex()
--~         if self then
--~             return (self:gsub("(..)",function(c)
--~                 return string.char(tonumber(c,16))
--~             end))
--~         else
--~             return ""
--~         end
--~     end

string.chr_to_hex = { }
string.hex_to_chr = { }

for i=0,255 do
    local c, h = string.char(i), string.format("%02X",i)
    string.chr_to_hex[c], string.hex_to_chr[h] = h, c
end

--~     function string:to_hex()
--~         if self then return (self:gsub("(.)",string.chr_to_hex)) else return "" end
--~     end

--~     function string:from_hex()
--~         if self then return (self:gsub("(..)",string.hex_to_chr)) else return "" end
--~     end

function string:to_hex()
    return ((self or ""):gsub("(.)",string.chr_to_hex))
end

function string:from_hex()
    return ((self or ""):gsub("(..)",string.hex_to_chr))
end

if not string.characters then

    local function nextchar(str, index)
        index = index + 1
        return (index <= #str) and index or nil, str:sub(index,index)
    end
    function string:characters()
        return nextchar, self, 0
    end
    local function nextbyte(str, index)
        index = index + 1
        return (index <= #str) and index or nil, string.byte(str:sub(index,index))
    end
    function string:bytes()
        return nextbyte, self, 0
    end

end

--~ function string:padd(n,chr)
--~     return self .. self.rep(chr or " ",n-#self)
--~ end

function string:rpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return self .. self.rep(chr or " ",m)
    else
        return self
    end
end

function string:lpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return self.rep(chr or " ",m) .. self
    else
        return self
    end
end

string.padd = string.rpadd

function is_number(str)
    return str:find("^[%-%+]?[%d]-%.?[%d+]$") == 1
end

--~ print(is_number("1"))
--~ print(is_number("1.1"))
--~ print(is_number(".1"))
--~ print(is_number("-0.1"))
--~ print(is_number("+0.1"))
--~ print(is_number("-.1"))
--~ print(is_number("+.1"))

function string:split_settings() -- no {} handling, see l-aux for lpeg variant
    if self:find("=") then
        local t = { }
        for k,v in self:gmatch("(%a+)=([^%,]*)") do
            t[k] = v
        end
        return t
    else
        return nil
    end
end

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


function string:pattesc()
    return (self:gsub(".",patterns_escapes))
end

function string:tohash()
    local t = { }
    for s in self:gmatch("([^, ]+)") do -- lpeg
        t[s] = true
    end
    return t
end
