if not modules then modules = { } end modules ['scrn-pag'] = {
    version   = 1.001,
    comment   = "companion to scrn-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interactions         = interactions or { }
interactions.pages   = interactions.pages or { }
local pages          = interactions.pages

local codeinjections = backends.codeinjections

local function setupcanvas(specification)
    codeinjections.setupcanvas(specification)
end

local function setpagetransition(specification)
    codeinjections.setpagetransition(specification)
end

pages.setupcanvas          = setupcanvas
pages.setpagetransition    = setpagetransition

commands.setupcanvas       = setupcanvas
commands.setpagetransition = setpagetransition
