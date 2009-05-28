if not modules then modules = { } end modules ['strc-itm'] = {
    version   = 1.001,
    comment   = "companion to strc-itm.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

structure            = structure            or { }
structure.itemgroups = structure.itemgroups or { }

local itemgroups = structure.itemgroups

function itemgroups.register(name,nofitems,maxwidth)
    jobpasses.savedata("itemgroup", { nofitems, maxwidth })
end

function itemgroups.nofitems(name,index)
    jobpasses.getfield("itemgroup", index, 1, 0)
end

function itemgroups.maxwidth(name,index)
    jobpasses.getfield("itemgroup", index, 2, 0)
end
