if not modules then modules = { } end modules ['strc-mar'] = {
    version   = 1.001,
    comment   = "companion to strc-mar.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local structures = structures

structures.marks = structures.marks or { }
local marks      = structures.marks
local lists      = structures.lists

function marks.title(tag,n)
    lists.savedtitle(tag,n,"marking")
end

function marks.number(tag,n) -- no spec
    -- no prefix (as it is the prefix)
    lists.savednumber(tag,n)
end
