if not modules then modules = { } end modules ['strc-itm'] = {
    version   = 1.001,
    comment   = "companion to strc-itm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local structures = structures
local itemgroups = structures.itemgroups
local jobpasses  = job.passes

local setvariable   = jobpasses.save
local getvariable   = jobpasses.getfield

function itemgroups.register(name,nofitems,maxwidth)
    setvariable("itemgroup", { nofitems, maxwidth })
end

function itemgroups.nofitems(name,index)
    return getvariable("itemgroup", index, 1, 0)
end

function itemgroups.maxwidth(name,index)
    return getvariable("itemgroup", index, 2, 0)
end

-- interface (might become counter/dimension)

commands.registeritemgroup = itemgroups.register

function commands.nofitems(name,index)
    context(getvariable("itemgroup", index, 1, 0))
end

function commands.maxitemwidth(name,index)
    context(getvariable("itemgroup", index, 2, 0))
end
