if not modules then modules = { } end modules ['strc-mar'] = {
    version   = 1.001,
    comment   = "companion to strc-mar.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

structure.marks = structure.marks or { }

function structure.marks.title(tag,n)
    structure.lists.savedtitle(tag,n,"marking")
end

function structure.marks.number(tag,n) -- no spec
    -- no prefix (as it is the prefix)
    structure.lists.savednumber(tag,n)
end
