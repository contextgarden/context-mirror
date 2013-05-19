if not modules then modules = { } end modules ['mtx-mtxworks'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a shortcut to "mtxrun --script texworks --start"

environment.setargument("start",true)

require "mtx-texworks"

