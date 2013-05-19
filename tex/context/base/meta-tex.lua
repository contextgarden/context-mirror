if not modules then modules = { } end modules ['meta-tex'] = {
    version   = 1.001,
    comment   = "companion to meta-tex.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ local P, C, lpegmatch = lpeg.P, lpeg.C, lpeg.match

-- local left     = P("[")
-- local right    = P("]")
-- local space    = P(" ")
-- local argument = left * C((1-right)^1) * right
-- local pattern  = (argument + space)^0

-- function metapost.sometxt(optional,str)
--     if optional == "" then
--         context.sometxta(str)
--     else
--         local one, two = lpegmatch(pattern,optional)
--         if two then
--             context.sometxtc(one,two,str)
--         elseif one then
--             context.sometxtb(one,str)
--         else
--             context.sometxta(str)
--         end
--     end
-- end

local P, Cs, lpegmatch = lpeg.P, lpeg.Cs, lpeg.match

local pattern = Cs((P([[\"]]) + P([["]])/"\\quotedbl{}" + P(1))^0) -- or \char

function metapost.escaped(str)
    context(lpegmatch(pattern,str))
end
