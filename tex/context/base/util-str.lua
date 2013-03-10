if not modules then modules = { } end modules ['util-str'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities         = utilities or {}
utilities.strings = utilities.strings or { }
local strings     = utilities.strings

local format, gsub, rep, sub = string.format, string.gsub, string.rep, string.sub
local load, dump = load, string.dump
local tonumber, type, tostring = tonumber, type, tostring
local unpack, concat = table.unpack, table.concat
local P, V, C, S, R, Ct, Cs, Cp, Carg, Cc = lpeg.P, lpeg.V, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct, lpeg.Cs, lpeg.Cp, lpeg.Carg, lpeg.Cc
local patterns, lpegmatch = lpeg.patterns, lpeg.match
local utfchar, utfbyte = utf.char, utf.byte
----- loadstripped = utilities.lua.loadstripped
----- setmetatableindex = table.setmetatableindex

local loadstripped = _LUAVERSION < 5.2 and load or function(str)
    return load(dump(load(str),true)) -- it only makes sense in luajit and luatex where we have a stipped load
end

local stripper = patterns.stripzeros

local function points(n)
    return (not n or n == 0) and "0pt" or lpegmatch(stripper,format("%.5fpt",n/65536))
end

local function basepoints(n)
    return (not n or n == 0) and "0bp" or lpegmatch(stripper,format("%.5fbp", n*(7200/7227)/65536))
end

number.points     = points
number.basepoints = basepoints

-- str = " \n \ntest  \n test\ntest "
-- print("["..string.gsub(string.collapsecrlf(str),"\n","+").."]")

local rubish     = patterns.spaceortab^0 * patterns.newline
local anyrubish  = patterns.spaceortab + patterns.newline
local anything   = patterns.anything
local stripped   = (patterns.spaceortab^1 / "") * patterns.newline
local leading    = rubish^0 / ""
local trailing   = (anyrubish^1 * patterns.endofstring) / ""
local redundant  = rubish^3 / "\n"

local pattern = Cs(leading * (trailing + redundant + stripped + anything)^0)

function strings.collapsecrlf(str)
    return lpegmatch(pattern,str)
end

-- The following functions might end up in another namespace.

local repeaters = { } -- watch how we also moved the -1 in depth-1 to the creator

function strings.newrepeater(str,offset)
    offset = offset or 0
    local s = repeaters[str]
    if not s then
        s = { }
        repeaters[str] = s
    end
    local t = s[offset]
    if t then
        return t
    end
    t = { }
    setmetatable(t, { __index = function(t,k)
        if not k then
            return ""
        end
        local n = k + offset
        local s = n > 0 and rep(str,n) or ""
        t[k] = s
        return s
    end })
    s[offset] = t
    return t
end

-- local dashes = strings.newrepeater("--",-1)
-- print(dashes[2],dashes[3],dashes[1])

local extra, tab, start = 0, 0, 4, 0

local nspaces = strings.newrepeater(" ")

string.nspaces = nspaces

local pattern =
    Carg(1) / function(t)
        extra, tab, start = 0, t or 7, 1
    end
  * Cs((
      Cp() * patterns.tab / function(position)
          local current = (position - start + 1) + extra
          local spaces = tab-(current-1) % tab
          if spaces > 0 then
              extra = extra + spaces - 1
              return nspaces[spaces] -- rep(" ",spaces)
          else
              return ""
          end
      end
    + patterns.newline * Cp() / function(position)
          extra, start = 0, position
      end
    + patterns.anything
  )^1)

function strings.tabtospace(str,tab)
    return lpegmatch(pattern,str,1,tab or 7)
end

-- local t = {
--     "1234567123456712345671234567",
--     "\tb\tc",
--     "a\tb\tc",
--     "aa\tbb\tcc",
--     "aaa\tbbb\tccc",
--     "aaaa\tbbbb\tcccc",
--     "aaaaa\tbbbbb\tccccc",
--     "aaaaaa\tbbbbbb\tcccccc\n       aaaaaa\tbbbbbb\tcccccc",
--     "one\n	two\nxxx	three\nxx	four\nx	five\nsix",
-- }
-- for k=1,#t do
--     print(strings.tabtospace(t[k]))
-- end

function strings.striplong(str) -- strips all leading spaces
    str = gsub(str,"^%s*","")
    str = gsub(str,"[\n\r]+ *","\n")
    return str
end

-- local template = string.striplong([[
--   aaaa
--   bb
--   cccccc
-- ]])

function strings.nice(str)
    str = gsub(str,"[:%-+_]+"," ") -- maybe more
    return str
end

-- Work in progress. Interesting is that compared to the built-in this
-- is faster in luatex than in luajittex where we have a comparable speed.
-- It only makes sense to use the formatter when a (somewhat) complex format
-- is used a lot. Each formatter is a function so there is some overhead
-- and not all formatted output is worth that overhead. Keep in mind that
-- there is an extra function call involved. In principle we end up with a
-- string concatination so one could inline such a sequence but often at the
-- cost of less readabinity. So, it's a sort of (visual) compromise. Of course
-- there is the benefit of more variants.

local n = 0

-- we are somewhat sloppy in parsing prefixes as it's not that critical
--
-- this does not work out ok:
--
-- function fnc(...) -- 1,2,3
--     print(...,...,...) -- 1,1,1,2,3
-- end

local preamble = [[
local type = type
local tostring = tostring
local tonumber = tonumber
local format = string.format
local concat = table.concat
local signed = number.signed
local points = number.points
local basepoints = number.basepoints
local utfchar = utf.char
local utfbyte = utf.byte
local lpegmatch = lpeg.match
local xmlescape = lpeg.patterns.xmlescape
local spaces = string.nspaces
]]

local template = [[
%s
%s
return function(%s) return %s end
]]


local arguments = { "a1" } -- faster than previously used (select(n,...))

setmetatable(arguments, { __index =
    function(t,k)
        local v = t[k-1] .. ",a" .. k
        t[k] = v
        return v
    end
})

local prefix_any = C((S("+- .") + R("09"))^0)
local prefix_tab = C((1-R("az","AZ","09","%%"))^0)

-- we've split all cases as then we can optimize them (let's omit the fuzzy u)

local format_s = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("format('%%%ss',a%s)",f,n)
    else
        return format("a%s",n)
    end
end

local format_S = function(f) -- can be optimized
    n = n + 1
    if f and f ~= "" then
        return format("format('%%%ss',tostring(a%s))",f,n)
    else
        return format("tostring(a%s)",n)
    end
end

local format_q = function()
    n = n + 1
    return format("format('%%q',a%s)",n) -- maybe an own lpeg
end

local format_Q = function() -- can be optimized
    n = n + 1
    return format("format('%%q',tostring(a%s))",n)
end

local format_i = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("format('%%%si',a%s)",f,n)
    else
        return format("a%s",n)
    end
end

local format_d = format_i

function number.signed(i)
    if i > 0 then
        return "+",  i
    else
        return "-", -i
    end
end

local format_I = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("format('%%s%%%si',signed(a%s))",f,n)
    else
        return format("format('%%s%%i',signed(a%s))",n)
    end
end

local format_f = function(f)
    n = n + 1
    return format("format('%%%sf',a%s)",f,n)
end

local format_g = function(f)
    n = n + 1
    return format("format('%%%sg',a%s)",f,n)
end

local format_G = function(f)
    n = n + 1
    return format("format('%%%sG',a%s)",f,n)
end

local format_e = function(f)
    n = n + 1
    return format("format('%%%se',a%s)",f,n)
end

local format_E = function(f)
    n = n + 1
    return format("format('%%%sE',a%s)",f,n)
end

local format_x = function(f)
    n = n + 1
    return format("format('%%%sx',a%s)",f,n)
end

local format_X = function(f)
    n = n + 1
    return format("format('%%%sX',a%s)",f,n)
end

local format_o = function(f)
    n = n + 1
    return format("format('%%%so',a%s)",f,n)
end

local format_c = function()
    n = n + 1
    return format("utfchar(a%s)",n)
end

local format_r = function(f)
    n = n + 1
    return format("format('%%%s.0f',a%s)",f,n)
end

local format_h = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    else
        return format("format('0x%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    end
end

local format_H = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    else
        return format("format('0x%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    end
end

local format_u = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    else
        return format("format('u+%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    end
end

local format_U = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    else
        return format("format('U+%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f == "" and "05" or f,n,n,n)
    end
end

local format_p = function()
    n = n + 1
    return format("points(a%s)",n)
end

local format_b = function()
    n = n + 1
    return format("basepoints(a%s)",n)
end

local format_t = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("concat(a%s,%q)",n,f)
    else
        return format("concat(a%s)",n)
    end
end

local format_l = function()
    n = n + 1
    return format("(a%s and 'true' or 'false')",n)
end

local format_L = function()
    n = n + 1
    return format("(a%s and 'TRUE' or 'FALSE')",n)
end

local format_N = function() -- strips leading zeros
    n = n + 1
    return format("tostring(tonumber(a%s) or a%s)",n,n)
end

local format_a = function(s)
    return format("%q",s)
end

local format_w = function(f) -- handy when doing depth related indent
    n = n + 1
    f = tonumber(f)
    if f then
        return format("spaces[%s+tonumber(a%s)]",f,n)
    else
        return format("spaces[tonumber(a%s)]",n)
    end
end

local format_W = function(f) -- handy when doing depth related indent
    return format("spaces[%s]",tonumber(f) or 0)
end

local format_extension = function(extensions,f,name)
    local extension = extensions[name] or "tostring(%s)"
    local f = tonumber(f) or 1
    if f == 0 then
        return extension
    elseif f == 1 then
        n = n + 1
        return format(extension,"a"..n)
    elseif f < 0 then
        return format(extension,"a"..n+f+1)
    else
        local t = { }
        for i=1,f do
            n = n + 1
            t[#t+1] = "a"..n
        end
        return format(extension,unpack(t))
    end
end

local builder = Cs { "start",
    start = (
        (
            P("%") / ""
          * (
                V("!") -- new
              + V("s") + V("q")
              + V("i") + V("d")
              + V("f") + V("g") + V("G") + V("e") + V("E")
              + V("x") + V("X") + V("o")
              --
              + V("c")
              + V("S") -- new
              + V("Q") -- new
              + V("N") -- new
              --
              + V("r")
              + V("h") + V("H") + V("u") + V("U")
              + V("p") + V("b")
              + V("t")
              + V("l") + V("L")
              + V("I")
              + V("h") -- new
              + V("w") -- new
              + V("W") -- new
              --
              + V("a") -- ignores probably messed up %
            )
          + V("a")
        )
--      * (P(-1) + Cc(".."))
     * (P(-1) + Carg(1))
    )^0,
    --
    ["s"] = (prefix_any * P("s")) / format_s, -- %s => regular %s (string)
    ["q"] = (prefix_any * P("q")) / format_q, -- %q => regular %q (quoted string)
    ["i"] = (prefix_any * P("i")) / format_i, -- %i => regular %i (integer)
    ["d"] = (prefix_any * P("d")) / format_d, -- %d => regular %d (integer)
    ["f"] = (prefix_any * P("f")) / format_f, -- %f => regular %f (float)
    ["g"] = (prefix_any * P("g")) / format_g, -- %g => regular %g (float)
    ["G"] = (prefix_any * P("G")) / format_G, -- %G => regular %G (float)
    ["e"] = (prefix_any * P("e")) / format_e, -- %e => regular %e (float)
    ["E"] = (prefix_any * P("E")) / format_E, -- %E => regular %E (float)
    ["x"] = (prefix_any * P("x")) / format_x, -- %x => regular %x (hexadecimal)
    ["X"] = (prefix_any * P("X")) / format_X, -- %X => regular %X (HEXADECIMAL)
    ["o"] = (prefix_any * P("o")) / format_o, -- %o => regular %o (octal)
    --
    ["S"] = (prefix_any * P("S")) / format_S, -- %S => %s (tostring)
    ["Q"] = (prefix_any * P("Q")) / format_S, -- %Q => %q (tostring)
    ["N"] = (prefix_any * P("N")) / format_N, -- %N => tonumber (strips leading zeros)
    ["c"] = (prefix_any * P("c")) / format_c, -- %c => utf character (extension to regular)
    --
    ["r"] = (prefix_any * P("r")) / format_r, -- %r => round
    ["h"] = (prefix_any * P("h")) / format_h, -- %h => 0x0a1b2 (when - no 0x) was v
    ["H"] = (prefix_any * P("H")) / format_H, -- %H => 0x0A1B2 (when - no 0x) was V
    ["u"] = (prefix_any * P("u")) / format_u, -- %u => u+0a1b2 (when - no u+)
    ["U"] = (prefix_any * P("U")) / format_U, -- %U => U+0A1B2 (when - no U+)
    ["p"] = (prefix_any * P("p")) / format_p, -- %p => 12.345pt / maybe: P (and more units)
    ["b"] = (prefix_any * P("b")) / format_b, -- %b => 12.342bp / maybe: B (and more units)
    ["t"] = (prefix_tab * P("t")) / format_t, -- %t => concat
    ["l"] = (prefix_tab * P("l")) / format_l, -- %l => boolean
    ["L"] = (prefix_tab * P("L")) / format_L, -- %L => BOOLEAN
    ["I"] = (prefix_any * P("I")) / format_I, -- %I => signed integer
    --
    ["w"] = (prefix_any * P("w")) / format_w, -- %w => n spaces (optional prefix is added)
    ["W"] = (prefix_any * P("W")) / format_W, -- %w => mandate prefix, no specifier
    --
    ["a"] = Cs(((1-P("%"))^1 + P("%%")/"%%%%")^1) / format_a, -- rest (including %%)
    --
 -- ["!"] = P("!xml!") / format_xml, -- %!xml! => hypertext escaped " < > &
    ["!"] = Carg(2) * prefix_any * P("!") * C((1-P("!"))^1) * P("!") / format_extension,
}

-- we can be clever and only alias what is needed

local direct = Cs (
        P("%")/""
      * Cc([[local format = string.format return function(str) return format("%]])
      * C(S("+- .") + R("09"))^0 * S("sqidfgGeExXo")
      * Cc([[",str) end]])
      * P(-1)
    )

local function make(t,str)
    local f
    local p = lpegmatch(direct,str)
    if p then
        f = loadstripped(p)()
    else
        n = 0
        p = lpegmatch(builder,str,1,"..",t._extensions_) -- after this we know n
        if n > 0 then
            p = format(template,preamble,t._preamble_,arguments[n],p)
         -- print("builder>",p)
            f = loadstripped(p)()
        else
            f = function() return str end
        end
    end
    t[str] = f
    return f
end

local function use(t,fmt,...)
    return t[fmt](...)
end

strings.formatters = { }

function strings.formatters.new()
    local t = { _extensions_ = { }, _preamble_ = "", _type_ = "formatter" }
    setmetatable(t, { __index = make, __call = use })
    return t
end

local formatters   = strings.formatters.new() -- the default instance

string.formatters  = formatters -- in the main string namespace
string.formatter   = function(str,...) return formatters[str](...) end -- sometimes nicer name

local function add(t,name,template,preamble)
    if type(t) == "table" and t._type_ == "formatter" then
        t._extensions_[name] = template or "%s"
        if preamble then
            t._preamble_ = preamble .. "\n" .. t._preamble_ -- so no overload !
        end
    end
end

strings.formatters.add = add

-- registered in the default instance (should we fall back on this one?)

lpeg.patterns.xmlescape = Cs((P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;" + P('"')/"&quot;" + P(1))^0)
lpeg.patterns.texescape = Cs((C(S("#$%\\{}"))/"\\%1" + P(1))^0)

add(formatters,"xml",[[lpegmatch(xmlescape,%s)]],[[local xmlescape = lpeg.patterns.xmlescape]])
add(formatters,"tex",[[lpegmatch(texescape,%s)]],[[local texescape = lpeg.patterns.texescape]])

-- add(formatters,"xy",[[ "(" .. %s .. "," .. %s .. ")" ]])
-- print(formatters["coordinates %2!xy! or (%s,%s)"](1,2,3,4,5,6))

-- local myformatter = utilities.strings.formatters.new()
--
-- utilities.strings.formatters.add(myformatter,"upper", [[string.upper(%s)]]) -- maybe handy
-- utilities.strings.formatters.add(myformatter,"csname",[["\\"..%s]])         -- less usefull
--
-- print("\n>>>",myformatter["Is this %!upper! handy %!csname! or %H not %!xml!?"]("really","weird",1234,"a&b"))

-- -- yes or no:
--
-- local function make(t,str)
--     local f
--     local p = lpegmatch(direct,str)
--     if p then
--         f = loadstripped(p)()
--     else
--         n = 0
--         p = lpegmatch(builder,str,1,",") -- after this we know n
--         if n > 0 then
--             p = format(template,template_shortcuts,arguments[n],p)
--             f = loadstripped(p)()
--         else
--             f = function() return str end
--         end
--     end
--     t[str] = f
--     return f
-- end
--
-- local formatteds  = string.formatteds or { }
-- string.formatteds = formatteds
--
-- setmetatable(formatteds, { __index = make, __call = use })

-- print(formatters["hans %N and %N done"](123,"0123"))
-- local test = formatters["1%%23%4w56%s78 %p %!xml! test and %!tex! more %s"]
-- print(#string.dump(test))
-- print(test(2,123,99999,"abc&def","# and $","okay","!!!"))
-- local test = formatters["%s"]
-- print(#string.dump(test))
-- print(test("okay"))

-- local p1 = "%s test %f done %p and %c and %V or %+t or %%"
-- local p2 = "%s test %f done %s and %s and 0x%05X or %s or %%"
--
-- local t = { 1,2,3,4 }
-- local r = ""
--
-- local format, formatter, formatters  = string.format, string.formatter, string.formatters
-- local utfchar, utfbyte, concat, points = utf.char, utf.byte, table.concat, number.points
--
-- local c = os.clock()
-- local f = formatters[p1]
-- for i=1,500000 do
--  -- r = formatters[p1]("hans",123.45,123.45,123,"a",t)
--     r = formatter(p1,"hans",123.45,123.45,123,"a",t)
--  -- r = f("hans",123.45,123.45,123,"a",t)
-- end
-- print(os.clock()-c,r)
--
-- local c = os.clock()
-- for i=1,500000 do
--     r = format(p2,"hans",123.45,points(123.45),utfchar(123),utfbyte("a"),concat(t,"+"))
-- end
-- print(os.clock()-c,r)

-- local f = format
-- function string.format(fmt,...)
--     print(fmt,...)
--     return f(fmt,...)
-- end
