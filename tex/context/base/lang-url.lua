if not modules then modules = { } end modules ['lang-url'] = {
    version   = 1.001,
    comment   = "companion to lang-url.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utfgsub = utf.byte, utf.gsub

local ctxcatcodes = tex.ctxcatcodes

commands = commands or { }

--[[
<p>Hyphenating <l n='url'/>'s is somewhat tricky and a matter of taste. I did
consider using a dedicated hyphenation pattern or dealing with it by node
parsing, but the following solution suits as well. After all, we're mostly
dealing with <l n='ascii'/> characters.</p>
]]--

do

    commands.hyphenatedurl = commands.hyphenatedurl or { }

    commands.hyphenatedurl.characters = {
      ["!"] = 1,
      ["\""] = 1,
      ["#"] = 1,
      ["$"] = 1,
      ["%"] = 1,
      ["&"] = 1,
      ["("] = 1,
      ["*"] = 1,
      ["+"] = 1,
      [","] = 1,
      ["-"] = 1,
      ["."] = 1,
      ["/"] = 1,
      [":"] = 1,
      [";"] = 1,
      ["<"] = 1,
      ["="] = 1,
      [">"] = 1,
      ["?"] = 1,
      ["@"] = 1,
      ["["] = 1,
      ["\\"] = 1,
      ["^"] = 1,
      ["_"] = 1,
      ["`"] = 1,
      ["{"] = 1,
      ["|"] = 1,
      ["~"] = 1,

      ["'"] = 2,
      [")"] = 2,
      ["]"] = 2,
      ["}"] = 2
    }

    commands.hyphenatedurl.lefthyphenmin  = 2
    commands.hyphenatedurl.righthyphenmin = 3

    local chars = commands.hyphenatedurl.characters

    function commands.hyphenatedurl.convert(str, left, right)
        local n = 0
        local b = math.max(left or commands.hyphenatedurl.lefthyphenmin,2)
        local e = math.min(#str-(right or commands.hyphenatedurl.righthyphenmin)+2,#str)
        str = utfgsub(str,"(.)",function(s)
            n = n + 1
            local c = chars[s]
            if not c or n<=b or n>=e then
                return "\\n{" .. utfbyte(s) .. "}"
            elseif c == 1 then
                return "\\b{" .. utfbyte(s) .. "}"
            elseif c == 2 then
                return "\\a{" .. utfbyte(s) .. "}"
            end
        end )
        return str
    end
    function commands.hyphenatedurl.action(str, left, right)
        tex.sprint(ctxcatcodes,commands.hyphenatedurl.convert(str, left, right))
    end

    -- todo, no interface in mkiv yet

    function commands.hyphenatedurl.setcharacters(str,value) -- 1, 2 == before, after
        for s in utfcharacters(str) do
            chars[s] = value or 1
        end
    end

    -- commands.hyphenatedurl.setcharacters("')]}",2)

end
