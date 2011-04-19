if not modules then modules = { } end modules ['grph-swf'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local todimen = number.todimen

local nodeinjections = backends.nodeinjections

local figures = figures
local context = context

function figures.checkers.swf(data)
    local dr, du, ds = data.request, data.used, data.status
    local width = (dr.width or figures.defaultwidth):todimen()
    local height = (dr.height or figures.defaultheight):todimen()
    local foundname = du.fullname
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    context.startfoundexternalfigure(todimen(width),todimen(height))
    nodeinjections.insertswf {
        foundname = foundname,
        width     = width,
        height    = height,
    --  factor    = number.dimenfactors.bp,
    --  display   = dr.display,
    --  controls  = dr.controls,
    --  label     = dr.label,
        resources = dr.resources,
    }
    context.stopfoundexternalfigure()
    return data
end

figures.includers.swf = figures.includers.nongeneric

figures.registersuffix("swf","swf")
