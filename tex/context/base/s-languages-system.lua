if not modules then modules = { } end modules ['s-languages-system'] = {
    version   = 1.001,
    comment   = "companion to s-languages-system.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages        = moduledata.languages        or { }
moduledata.languages.system = moduledata.languages.system or { }

local NC, NR, HL = context.NC, context.NR, context.HL

function moduledata.languages.system.showinstalled()
    local numbers    = languages.numbers
    local registered = languages.registered
    context.starttabulate { "|r|l|l|l|l|" }
        NC() context("id")
        NC() context("tag")
        NC() context("synonyms")
        NC() context("parent")
        NC() context("loaded")
        NC() NR() HL()
        for i=1,#numbers do
            local tag  = numbers[i]
            local data = registered[tag]
            NC() context(data.number)
            NC() context(tag)
            NC() context("% t",table.sortedkeys(data.synonyms))
            NC() context(data.parent)
            NC() context("%+t",table.sortedkeys(data.used))
            NC() NR()
        end
    context.stoptabulate()
end
