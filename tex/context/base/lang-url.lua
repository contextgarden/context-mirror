if not modules then modules = { } end modules ['lang-url'] = {
    version   = 1.001,
    comment   = "companion to lang-url.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utfgsub = utf.byte, utf.gsub

local ctxcatcodes, texsprint = tex.ctxcatcodes, tex.sprint

commands       = commands or { }
local commands = commands

--[[
<p>Hyphenating <l n='url'/>'s is somewhat tricky and a matter of taste. I did
consider using a dedicated hyphenation pattern or dealing with it by node
parsing, but the following solution suits as well. After all, we're mostly
dealing with <l n='ascii'/> characters.</p>
]]--

commands.hyphenatedurl = commands.hyphenatedurl or { }
local hyphenatedurl    = commands.hyphenatedurl

hyphenatedurl.characters = utilities.storage.allocate {
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

hyphenatedurl.lefthyphenmin  = 2
hyphenatedurl.righthyphenmin = 3
hyphenatedurl.discretionary  = nil

local chars = hyphenatedurl.characters

function hyphenatedurl.action(str, left, right, disc)
    local n = 0
    local b = math.max(      left  or hyphenatedurl.lefthyphenmin,    2)
    local e = math.min(#str-(right or hyphenatedurl.righthyphenmin)+2,#str)
    local d = disc or hyphenatedurl.discretionary
    for s in utfcharacters(str) do
        n = n + 1
        if s == d then
            texsprint(ctxcatcodes,"\\d{",utfbyte(s),"}")
        else
            local c = chars[s]
            if not c or n<=b or n>=e then
                texsprint(ctxcatcodes,"\\n{",utfbyte(s),"}")
            elseif c == 1 then
                texsprint(ctxcatcodes,"\\b{",utfbyte(s),"}")
            elseif c == 2 then
                texsprint(ctxcatcodes,"\\a{",utfbyte(s),"}")
            end
        end
    end
end

-- todo, no interface in mkiv yet

function hyphenatedurl.setcharacters(str,value) -- 1, 2 == before, after
    for s in utfcharacters(str) do
        chars[s] = value or 1
    end
end

-- .hyphenatedurl.setcharacters("')]}",2)
