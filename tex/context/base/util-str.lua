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

local gsub, rep = string.gsub, string.rep
local Cs, C, Cp, P, Carg = lpeg.Cs, lpeg.C, lpeg.Cp, lpeg.P, lpeg.Carg
local patterns, lpegmatch = lpeg.patterns, lpeg.match

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
    setmetatable(t, {
        __index = function(t,k)
            if not k then
                return ""
            end
            local n = k + offset
            local s = n > 0 and rep(str,n) or ""
            t[k] = s
            return s
        end
    } )
    s[offset] = t
    return t
end

--~ local dashes = strings.newrepeater("--",-1)

--~ print(dashes[2])
--~ print(dashes[3])
--~ print(dashes[1])

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

--~ local t = {
--~     "1234567123456712345671234567",
--~     "\tb\tc",
--~     "a\tb\tc",
--~     "aa\tbb\tcc",
--~     "aaa\tbbb\tccc",
--~     "aaaa\tbbbb\tcccc",
--~     "aaaaa\tbbbbb\tccccc",
--~     "aaaaaa\tbbbbbb\tcccccc\n       aaaaaa\tbbbbbb\tcccccc",
--~     "one\n	two\nxxx	three\nxx	four\nx	five\nsix",
--~ }
--~ for k=1,#t do
--~     print(strings.tabtospace(t[k]))
--~ end

function strings.striplong(str) -- strips all leading spaces
    str = gsub(str,"^%s*","")
    str = gsub(str,"[\n\r]+ *","\n")
    return str
end

--~ local template = string.striplong([[
--~   aaaa
--~   bb
--~   cccccc
--~ ]])
