if not modules then modules = { } end modules ['tabl-tbl'] = {
    version   = 1.001,
    comment   = "companion to tabl-tbl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A couple of hacks ... easier to do in Lua than in regular
-- TeX. More will follow.

local tonumber = tonumber
local gsub, rep, sub = string.gsub, string.rep, string.sub

local P, C, Cc, Ct, lpegmatch = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.match

local settexcount = tex.setcount

local separator = P("|")
local nested    = lpeg.patterns.nested
local pattern   = Ct((separator * (C(nested) + Cc("")) * C((1-separator)^0))^0)

function commands.presettabulate(preamble)
    -- todo: lpeg
    preamble = string.escapedpattern(preamble)
    preamble = gsub(preamble, "%*(%b{})(%b{})", function(n,p)
        return rep(sub(p,2,-2),tonumber(sub(n,2,-2)) or 1)
    end)
    local t = lpegmatch(pattern,preamble)
    local m = #t - 2
    settexcount("global","noftabulatecolumns", m/2)
    settexcount("global","tabulatehasfirstrulespec", t[1] == "" and 0 or 1)
    settexcount("global","tabulatehaslastrulespec", t[m+1] == "" and 0 or 1)
    for i=1,m,2 do
        context.settabulateentry(t[i],t[i+1])
    end
    context.setlasttabulateentry(t[m+1])
end
