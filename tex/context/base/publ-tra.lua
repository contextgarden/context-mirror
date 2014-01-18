if not modules then modules = { } end modules ['publ-tra'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sortedhash = table.sortedhash

local tracers        = { }
publications.tracers = tracers

local context = context
local NC, NR, bold = context.NC, context.NR, context.bold

publications.tracers.fields = table.sorted {
    "abstract",
    "address",
    "annotate",
    "author",
    "booktitle",
    "chapter",
    "comment",
    "country",
    "doi",
    "edition",
    "editor",
    "eprint",
    "howpublished",
    "institution",
    "isbn",
    "issn",
    "journal",
    "key",
    "keyword",
    "keywords",
    "language",
    "lastchecked",
    "month",
    "names",
    "note",
    "notes",
    "number",
    "organization",
    "pages",
    "publisher",
    "school",
    "series",
    "size",
    "title",
    "type",
    "url",
    "volume",
    "year",
    "nationality",
    "assignee",
    "bibnumber",
    "day",
    "dayfiled",
    "monthfiled",
    "yearfiled",
    "revision",
}

publications.tracers.citevariants = table.sorted {
    "author",
    "authoryear",
    "authoryears",
    "authornum",
    "year",
    "short",
    "serial",
    "key",
    "doi",
    "url",
    "type",
    "page",
    "none",
    "num",
}

publications.tracers.listvariants = table.sorted {
    "author",
    "editor",
    "artauthor",
}

publications.tracers.categories = table.sorted {
    "article",
    "book",
    "booklet",
    "conference",
    "inbook",
    "incollection",
    "inproceedings",
    "manual",
    "mastersthesis",
    "misc",
    "phdthesis",
    "proceedings",
    "techreport",
    "unpublished",
}

function tracers.showdatasetfields(name)
    if name and name ~= "" then
        local luadata = publications.datasets[name].luadata
        if next(luadata) then
            context.starttabulate { "|lT|lT|pT|" }
                NC() bold("tag")
                NC() bold("category")
                NC() bold("fields")
                NC() NR() context.FL() -- HL()
                for k, v in sortedhash(luadata) do
                    NC() context(k)
                    NC() context(v.category)
                    NC()
                    for k, v in sortedhash(v) do
                        if k ~= "details" and k ~= "tag" and k ~= "category" then
                            context("%s ",k)
                        end
                    end
                    NC() NR()
                end
            context.stoptabulate()
        end
    end
end

commands.showbtxdatasetfields = tracers.showdatasetfields
