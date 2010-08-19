if not modules then modules = { } end modules ['l-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

aux = aux or { }

require("util-int")  for k, v in next, utilities.interfaces do aux[k] = v end
require("util-tab")  for k, v in next, utilities.tables     do aux[k] = v end
require("util-fmt")  for k, v in next, utilities.formatters do aux[k] = v end
