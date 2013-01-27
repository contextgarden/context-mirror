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

local load = load
local format, gsub, rep, sub = string.format, string.gsub, string.rep, string.sub
local concat = table.concat
local P, V, C, S, R, Ct, Cs, Cp, Carg = lpeg.P, lpeg.V, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct, lpeg.Cs, lpeg.Cp, lpeg.Carg
local patterns, lpegmatch = lpeg.patterns, lpeg.match
local utfchar, utfbyte = utf.char, utf.byte
local setmetatableindex = table.setmetatableindex
--

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
    setmetatableindex(t, function(t,k)
        if not k then
            return ""
        end
        local n = k + offset
        local s = n > 0 and rep(str,n) or ""
        t[k] = s
        return s
    end)
    s[offset] = t
    return t
end

-- local dashes = strings.newrepeater("--",-1)
-- print(dashes[2],dashes[3],dashes[1])

local extra, tab, start = 0, 0, 4, 0

local nspaces = strings.newrepeater(" ")

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

local n = 0

-- we are somewhat sloppy in parsing prefixes as it's not that critical
--
-- this does not work out ok:
--
-- function fnc(...) -- 1,2,3
--     print(...,...,...) -- 1,1,1,2,3
-- end

local prefix_any = C((S("+- .") + R("09"))^0)
local prefix_tab = C((1-R("az","AZ","09","%%"))^0)

-- we've split all cases as then we can optimize them (let's omit the fuzzy u)

local format_s = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("format('%%%ss',(select(%s,...)))",f,n)
    else
        return format("(select(%s,...))",n)
    end
end

local format_q = function()
    n = n + 1
    return format("format('%%q',(select(%s,...)))",n) -- maybe an own lpeg
end

local format_i = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("format('%%%si',(select(%s,...)))",f,n)
    else
        return format("(select(%s,...))",n)
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
        return format("format('%%s%%%si',signed((select(%s,...))))",f,n)
    else
        return format("format('%%s%%i',signed((select(%s,...))))",n)
    end
end

local format_f = function(f)
    n = n + 1
    return format("format('%%%sf',(select(%s,...)))",f,n)
end

local format_g = function(f)
    n = n + 1
    return format("format('%%%sg',(select(%s,...)))",f,n)
end

local format_G = function(f)
    n = n + 1
    return format("format('%%%sG',(select(%s,...)))",f,n)
end

local format_e = function(f)
    n = n + 1
    return format("format('%%%se',(select(%s,...)))",f,n)
end

local format_E = function(f)
    n = n + 1
    return format("format('%%%sE',(select(%s,...)))",f,n)
end

local format_x = function(f)
    n = n + 1
    return format("format('%%%sx',(select(%s,...)))",f,n)
end

local format_X = function(f)
    n = n + 1
    return format("format('%%%sX',(select(%s,...)))",f,n)
end

local format_o = function(f)
    n = n + 1
    return format("format('%%%so',(select(%s,...)))",f,n)
end

local format_c = function()
    n = n + 1
    return format("utfchar((select(%s,...)))",n)
end

local format_r = function(f)
    n = n + 1
    return format("format('%%%s.0f',(select(%s,...)))",f,n)
end

local format_v = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sx',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    else
        return format("format('0x%%%sx',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    end
end

local format_V = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sX',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    else
        return format("format('0x%%%sX',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    end
end

local format_u = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sx',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    else
        return format("format('u+%%%sx',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    end
end

local format_U = function(f)
    n = n + 1
    if f == "-" then
        f = sub(f,2)
        return format("format('%%%sX',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    else
        return format("format('U+%%%sX',utfbyte((select(%s,...))))",f == "" and "05" or f,n)
    end
end

local format_p = function()
    n = n + 1
    return format("points((select(%s,...)))",n)
end

local format_b = function()
    n = n + 1
    return format("basepoints((select(%s,...)))",n)
end

local format_t = function(f)
    n = n + 1
    if f and f ~= "" then
        return format("concat((select(%s,...)),%q)",n,f)
    else
        return format("concat((select(%s,...)))",n)
    end
end

local format_l = function()
    n = n + 1
    return format("(select(%s,...) and 'true' or 'false')",n)
end

local format_a = function(s)
    return format("%q",s)
end

local builder = Ct { "start",
    start = (P("%") * (
        V("s") + V("q")
      + V("i") + V("d")
      + V("f") + V("g") + V("G") + V("e") + V("E")
      + V("x") + V("X") + V("o")
      --
      + V("c")
      --
      + V("r")
      + V("v") + V("V") + V("u") + V("U")
      + V("p") + V("b")
      + V("t")
      + V("l")
      + V("I")
    )
      + V("a")
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
    ["c"] = (prefix_any * P("c")) / format_c, -- %c => utf character (extension to regular)
    --
    ["r"] = (prefix_any * P("r")) / format_r, -- %r => round
    ["v"] = (prefix_any * P("v")) / format_v, -- %v => 0x0a1b2 (when - no 0x)
    ["V"] = (prefix_any * P("V")) / format_V, -- %V => 0x0A1B2 (when - no 0x)
    ["u"] = (prefix_any * P("u")) / format_u, -- %u => u+0a1b2 (when - no u+)
    ["U"] = (prefix_any * P("U")) / format_U, -- %U => U+0A1B2 (when - no U+)
    ["p"] = (prefix_any * P("p")) / format_p, -- %p => 12.345pt / maybe: P (and more units)
    ["b"] = (prefix_any * P("b")) / format_b, -- %b => 12.342bp / maybe: B (and more units)
    ["t"] = (prefix_tab * P("t")) / format_t, -- %t => concat
    ["l"] = (prefix_tab * P("l")) / format_l, -- %l => boolean
    ["I"] = (prefix_any * P("I")) / format_I, -- %I => signed integer
    --
    ["a"] = Cs(((1-P("%"))^1 + P("%%")/"%%")^1) / format_a, -- %a => text (including %%)
}

-- we can be clever and only alias what is needed

local template = [[
local format = string.format
local concat = table.concat
local signed = number.signed
local points = number.points
local basepoints = number.basepoints
local utfchar = utf.char
local utfbyte = utf.byte
return function(...)
    return %s
end
]]

local function make(t,str)
    n = 0
    local p = lpegmatch(builder,str)
-- inspect(p)
    local c = format(template,concat(p,".."))
-- inspect(c)
    formatter = load(c)()
    t[str] = formatter
    return formatter
end

local formatters  = string.formatters or { }
string.formatters = formatters

setmetatableindex(formatters,make)

function string.makeformatter(str)
    return formatters[str]
end

function string.formatter(str,...)
    return formatters[str](...)
end

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
