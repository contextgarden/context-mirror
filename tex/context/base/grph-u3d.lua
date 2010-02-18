if not modules then modules = { } end modules ['grph-u3d'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- see lpdf-u3d.lua for comment

local format = string.format

local texsprint     = tex.sprint
local ctxcatcodes   = tex.ctxcatcodes
local pdfannotation = nodes.pdfannotation

function figures.checkers.u3d(data)
    local dr, du, ds = data.request, data.used, data.status
    local width = (dr.width or figures.defaultwidth):todimen()
    local height = (dr.height or figures.defaultheight):todimen()
    local foundname = du.fullname
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    texsprint(ctxcatcodes,format("\\startfoundexternalfigure{%ssp}{%ssp}",width,height))
    local annot, preview, ref = backends.pdf.helpers.insert3d {
        foundname = foundname,
        width     = width,
        height    = height,
        factor    = number.dimenfactors.bp,
        display   = dr.display,
        controls  = dr.controls,
        label     = dr.label,
    }
 -- node.write(pdfannotation(width,-height,0,annot()))
    texsprint(ctxcatcodes,format("\\pdfannot width %ssp height %ssp {%s}",width,height,annot())) -- brrrr
--~     if ref then -- wrong ! a direct ref should work
--~         texsprint(ctxcatcodes,format("\\smash{\\pdfrefximage%s\\relax}",ref)) -- brrrr
--~     end
    texsprint(ctxcatcodes,"\\stopfoundexternalfigure")
    return data
end

figures.includers.u3d = figures.includers.nongeneric

figures.registersuffix("u3d","u3d")
figures.registersuffix("prc","u3d")
