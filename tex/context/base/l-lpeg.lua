-- filename : l-lpeg.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-lpeg'] = 1.001

--~ l-lpeg.lua :

--~ lpeg.digit         = lpeg.R('09')^1
--~ lpeg.sign          = lpeg.S('+-')^1
--~ lpeg.cardinal      = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.integer       = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.float         = lpeg.P(lpeg.sign^0 * lpeg.digit^0 * lpeg.P('.') * lpeg.digit^1)
--~ lpeg.number        = lpeg.float + lpeg.integer
--~ lpeg.oct           = lpeg.P("0") * lpeg.R('07')^1
--~ lpeg.hex           = lpeg.P("0x") * (lpeg.R('09') + lpeg.R('AF'))^1
--~ lpeg.uppercase     = lpeg.P("AZ")
--~ lpeg.lowercase     = lpeg.P("az")

--~ lpeg.eol           = lpeg.S('\r\n\f')^1 -- includes formfeed
--~ lpeg.space         = lpeg.S(' ')^1
--~ lpeg.nonspace      = lpeg.P(1-lpeg.space)^1
--~ lpeg.whitespace    = lpeg.S(' \r\n\f\t')^1
--~ lpeg.nonwhitespace = lpeg.P(1-lpeg.whitespace)^1

local hash = { }

function lpeg.anywhere(pattern) --slightly adapted from website
    return lpeg.P { lpeg.P(pattern) + 1 * lpeg.V(1) }
end

function lpeg.startswith(pattern) --slightly adapted
    return lpeg.P(pattern)
end

--~ g = lpeg.splitter(" ",function(s) ... end) -- gmatch:lpeg = 3:2

function lpeg.splitter(pattern, action)
    return (((1-lpeg.P(pattern))^1)/action+1)^0
end


local crlf    = lpeg.P("\r\n")
local cr      = lpeg.P("\r")
local lf      = lpeg.P("\n")
local space   = lpeg.S(" \t\f\v")
local newline = crlf + cr + lf
local spacing = space^0 * newline
local content = lpeg.Cs((1-spacing)^1) * spacing^-1 * (spacing * lpeg.Cc(""))^0

local capture = lpeg.Ct(content^0)

function string:splitlines()
    return capture:match(self)
end
