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

local find, gsub = string.find, string.gsub
local patterns, Cs, lpegmatch = lpeg.patterns, lpeg.Cs, lpeg.match

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

-- The following functions might end up in another namespace.

function strings.tabtospace(str,tab)
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

--~ local template = string.striplong([[
--~   aaaa
--~   bb
--~   cccccc
--~ ]])

function strings.striplong(str) -- strips all leading spaces
    str = gsub(str,"^%s*","")
    str = gsub(str,"[\n\r]+ *","\n")
    return str
end
