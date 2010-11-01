if not modules then modules = { } end modules ['cldf-com'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local generics  = context.generics
local variables = interfaces.variables

generics.starttabulate = "start" .. variables.tabulate -- todo: e!start
generics.stoptabulate  = "stop"  .. variables.tabulate -- todo: e!stop
