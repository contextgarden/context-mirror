if not modules then modules = { } end modules ['l-utils'] = {
    version   = 1.001,
    comment   = "this module is replaced by the util-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utils = utils or { }

require("util-mrg") for k, v in next, utilities.merger do utils[k] = v end
require("util-lua") for k, v in next, utilities.lua    do utils[k] = v end
