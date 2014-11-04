-- to be checked

local virtual = { "authoryear", "authoryears", "authornum", "num", "suffix" }

return {
    name = "apa",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    categories = {
        article = {
            required = { { "author", "editor" }, "title" },
            optional = { "year", "type", "journal", "volume", "number", "pages", "url", "note", "doi" },
            virtual  = virtual,
            author   = { "author", "editor" },
        },
        magazine = {
            required = { { "author", "editor" }, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
            virtual  = virtual,
            author   = { "author", "editor" },
        },
        newspaper = {
            required = { { "author", "editor" }, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
            virtual  = virtual,
            author   = { "author", "editor" },
        },
        book = {
            virtual  = { "authoryear" },
            required = { { "author", "editor", "publisher" }, "title" },
            optional = { "year", "month", "day", "title", "type", "edition", "series", "volume", "number", "pages", "address", "publisher", "url", "note", "ISBN" },
            virtual  = virtual,
            author   = { "author", "editor", "publisher" },
        },
        booklet = {
            required = { "title" },
            optional = { "author", "howpublished", "address", "month", "year", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        inbook = {
            required = { { "author", "editor", "publisher" }, "title", "chapter", "pages", "year" },
            optional = { "volume", "number", "series", "type", "address", "edition", "month", "note", "ISBN" },
            virtual  = virtual,
            author   = { "author", "editor", "publisher" },
        },
        incollection = {
            required = { "author", "title", "booktitle", "publisher", "year" },
            optional = { "editor", "volume", "number", "series", "type", "chapter", "pages", "address", "edition", "month", "note", "ISBN" },
            virtual  = virtual,
            author   = { "author", "editor", "publisher" },
        },
        inproceedings = {
            required = { "author", "title", "booktitle", "year" },
            optional = { "editor", "volume", "number", "series", "pages", "address", "month", "organization", "publisher", "note", "ISBN" },
            virtual  = virtual,
            author   = { "author", "editor", "publisher" },
        },
        conference =
            "inproceedings", -- Alan: does this work? Hans: I just made it work.
        manual = {
            required = { "title" },
            optional = { "author", "organization", "address", "edition", "month", "year", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        mastersthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        phdthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        thesis = {
            required = { "author", "title", "school", "year", "type" },
            optional = { "address", "month", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        misc = {
            required = { },
            optional = { "author", "title", "howpublished", "month", "year", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        -- Not sure yet how "periodical" is used... but "jabref" includes it as standard.
        -- strangely, "jabref" does not include "author" as required nor optional..
        periodical = {
            required = { "title", "year" },
            optional = { "author", "editor", "month", "note", "number", "organization", "series", "volume" },
            virtual  = virtual,
            author   = { "author", "editor" },
        },
        proceedings = {
            required = { "title", "year" },
            optional = { "editor", "volume", "number", "series", "address", "month", "organization", "publisher", "note", "pages", "ISBN" },
            virtual  = virtual,
            author   = { "editor", "publisher" },
        },
        techreport = {
            required = { "author", "title", "institution", "year" },
            optional = { "type", "number", "address", "month", "note" },
            virtual  = virtual,
            author   = { "author" },
        },
        other = {
            required = { { "author", "title" }, "year" },
            optional = { "note", "doi" },
            virtual  = virtual,
            author   = { "author" },
        },
        patent = {
            required = { "nationality", "number", "year", "yearfiled" },
            optional = { "author", "title", "language", "assignee", "address", "type", "day", "dayfiled", "month", "monthfiled", "note", },
            virtual  = virtual,
            author   = { "author" },
        },
        electronic = {
            required = { "title" },
            optional = { "address", "author", "howpublished", "month", "note", "organization", "year", "url", "doi", "type" },
            virtual  = virtual,
            author   = { "author" },
        },
        -- check this!
        standard = {
            required = { { "author", "institution", "organization" }, "title", "year", "note", "url" },
            optional = { "doi", },
            virtual  = virtual,
            author   = { "author", "institution", "organization" },
        },
        unpublished = {
            required = { "author", "title", "note" },
            optional = { "month", "year" },
            virtual  = virtual,
            author   = { "author" },
        },
        literal = {
            required = { "key", "text", },
            optional = { },
        },
    },
}

