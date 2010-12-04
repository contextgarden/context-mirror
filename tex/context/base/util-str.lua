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

local find, gsub, rep = string.find, string.gsub, string.rep
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

--~ function strings.tabtospace(str,tab)
--~     -- we don't handle embedded newlines
--~     while true do
--~         local s = find(str,"\t")
--~         if s then
--~             if not tab then tab = 7 end -- only when found
--~             local d = tab-(s-1) % tab
--~             if d > 0 then
--~                 str = gsub(str,"\t",rep(" ",d),1)
--~             else
--~                 str = gsub(str,"\t","",1)
--~             end
--~         else
--~             break
--~         end
--~     end
--~     return str
--~ end

local extra, tab, start = 0, 0, 4, 0

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
              return rep(" ",spaces)
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
