if not modules then modules = { } end modules ['chem-ini'] = {
    version   = 1.001,
    comment   = "companion to chem-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local lpegmatch = lpeg.match

local P, R, V, Cc, Cs = lpeg.P, lpeg.R, lpeg.V, lpeg.Cc, lpeg.Cs

local trace_molecules = false  trackers.register("chemistry.molecules",  function(v) trace_molecules = v end)

local report_chemistry = logs.reporter("chemistry")

local context = context

chemicals       = chemicals or { }
local chemicals = chemicals

--[[
<p>The next code is an adaptation of code from Wolfgang Schuster
as posted on the mailing list. This version supports nested
braces and unbraced integers as scripts. We could consider
spaces as terminals for them but first let collect a bunch
of input then.</p>
]]--

-- some lpeg, maybe i'll make an syst-lpg module

local lowercase   = R("az")
local uppercase   = R("AZ")
local backslash   = P("\\")
local csname      = backslash * P(1) * (1-backslash)^0
local plus        = P("+") / "\\textplus "
local minus       = P("-") / "\\textminus "
local digit       = R("09")
local sign        = plus + minus
local cardinal    = digit^1
local integer     = sign^0 * cardinal

local leftbrace   = P("{")
local rightbrace  = P("}")
local nobrace     = 1 - (leftbrace + rightbrace)
local nested      = P { leftbrace * (csname + sign + nobrace + V(1))^0 * rightbrace }
local any         = P(1)

local subscript   = P("_")
local superscript = P("^")
local somescript  = subscript + superscript

local content     = Cs(csname + nested + sign + any)

-- could be made more efficient

local lowhigh    = Cc("\\lohi{%s}{%s}") * subscript   * content * superscript * content / format
local highlow    = Cc("\\hilo{%s}{%s}") * superscript * content * subscript   * content / format
local low        = Cc("\\low{%s}")      * subscript   * content                         / format
local high       = Cc("\\high{%s}")     * superscript * content                         / format
local justtext   = (1 - somescript)^1
local parser     = Cs((csname + lowhigh + highlow + low + high + sign + any)^0)

chemicals.moleculeparser = parser -- can be used to avoid functioncall

function chemicals.molecule(str)
    return lpegmatch(parser,str)
end

function commands.molecule(str)
    if trace_molecules then
        local rep = lpegmatch(parser,str)
        report_chemistry("molecule %s => %s",str,rep)
        context(rep)
    else
        context(lpegmatch(parser,str))
    end
end
