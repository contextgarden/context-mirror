if not modules then modules = { } end modules ['scrn-int'] = {
    version   = 1.001,
    comment   = "companion to scrn-int.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interactions         = { }
interactions.general = interactions.general or { }
local general        = interactions.general

local codeinjections = backends.codeinjections

local function setupidentity(specification)
    codeinjections.setupidentity(specification)
end

general.setupidentity  = setupidentity

commands.setupidentity = setupidentity
