if not modules then modules = { } end modules ['chem-ini'] = {
    version   = 1.001,
    comment   = "companion to chem-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, texsprint = string.format, tex.sprint
local lpegmatch = lpeg.match

local trace_molecules = false  trackers.register("chemistry.molecules",  function(v) trace_molecules = v end)

local report_chemistry = logs.new("chemistry")

local ctxcatcodes = tex.ctxcatcodes

chemicals = chemicals or { }

--[[
<p>The next code is an adaptation of code from Wolfgang Schuster
as posted on the mailing list. This version supports nested
braces and unbraced integers as scripts. We could consider
spaces as terminals for them but first let collect a bunch
of input then.</p>
]]--

-- some lpeg, maybe i'll make an syst-lpg module

local lowercase   = lpeg.R("az")
local uppercase   = lpeg.R("AZ")
local backslash   = lpeg.P("\\")
local csname      = backslash * lpeg.P(1) * (1-backslash)^0
local plus        = lpeg.P("+") / "\\textplus "
local minus       = lpeg.P("-") / "\\textminus "
local digit       = lpeg.R("09")
local sign        = plus + minus
local cardinal    = digit^1
local integer     = sign^0 * cardinal

local leftbrace   = lpeg.P("{")
local rightbrace  = lpeg.P("}")
local nobrace     = 1 - (leftbrace + rightbrace)
local nested      = lpeg.P { leftbrace * (csname + sign + nobrace + lpeg.V(1))^0 * rightbrace }
local any         = lpeg.P(1)

local subscript   = lpeg.P("_")
local superscript = lpeg.P("^")
local somescript  = subscript + superscript

--~ local content     = lpeg.Cs(nested + integer + sign + any)
local content     = lpeg.Cs(csname + nested + sign + any)

-- could be made more efficient

local lowhigh    = lpeg.Cc("\\lohi{%s}{%s}") * subscript   * content * superscript * content / format
local highlow    = lpeg.Cc("\\hilo{%s}{%s}") * superscript * content * subscript   * content / format
local low        = lpeg.Cc("\\low{%s}")      * subscript   * content                         / format
local high       = lpeg.Cc("\\high{%s}")     * superscript * content                         / format
local justtext   = (1 - somescript)^1
local parser     = lpeg.Cs((csname + lowhigh + highlow + low + high + sign + any)^0)

chemicals.moleculeparser = parser -- can be used to avoid functioncall

function chemicals.molecule(str)
    return lpegmatch(parser,str)
end

function commands.molecule(str)
    if trace_molecules then
        local rep = lpegmatch(parser,str)
        report_chemistry("molecule %s => %s",str,rep)
        texsprint(ctxcatcodes,rep)
    else
        texsprint(ctxcatcodes,lpegmatch(parser,str))
    end
end
