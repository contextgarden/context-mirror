-- category = {
--     sets     = {
--         authors = { "author", "editor" },
--     },
--     required = { "authors", "title" },
--     optional = { "year", "journal", "editor", "volume", "number", "pages" },
--     virtual  = { "authoryear", "authoryears", "authornum", "num", "suffix" },
-- }

-- category = {
--     sets     = {
--         author = { "author", "editor" },
--     },
--     required = { "author", "title" },
--     optional = { "year", "journal", "editor", "volume", "number", "pages" },
--     virtual  = { "authoryear", "authoryears", "authornum", "num", "suffix" },
-- }

local article = {
    required = { "authors" },
    optional = { "year", "subtitle", "type", "journal", "volume", "number", "pages", "note", "links", "file" },
    sets     = {
        authors = { "author", "editor", "title" },
        links   = { "doi", "url" },
    },
}

local magazine = {
    required = { "authors", "journal", "year" },
    optional = { "subtitle", "volume", "number", "pages", "month", "day", "note", "links", "file" },
    sets     = article.sets,
}

local book = {
    required = { "authors" },
    optional = { "subtitle", "year", "month", "day", "type", "edition", "series", "volume", "number", "pages", "address", "url", "note", "ISBN", "file" },
    sets     = {
        authors = { "author", "editor", "publisher", "title" },
    },
}

local inbook = {
    required = { "authors", "title", "chapter", "pages", "year" },
    optional = { "subtitle", "volume", "number", "series", "type", "address", "edition", "month", "note", "ISBN", "file" },
    sets     = book.sets,
}

local booklet = {
    required = { "authors" },
    optional = { "subtitle", "howpublished", "address", "month", "year", "note", "file" },
    sets     = {
        authors = { "author", "title" },
    },
}

local incollection = {
    required = { "authors", "title", "booktitle", "year" },
    optional = { "subtitle", "volume", "number", "series", "type", "chapter", "pages", "address", "edition", "month", "note", "ISBN", "file" },
    sets     = {
        authors = { "author", "editor", "publisher" },
    },
}

local inproceedings = {
    optional = { "subtitle", "volume", "number", "series", "pages", "address", "month", "organization", "note", "ISBN", "file" },
    required = incollection.required,
    sets     = incollection.sets,
}

local manual = {
    required = { "title" },
    optional = { "subtitle", "author", "organization", "address", "edition", "month", "year", "note", "file" },
}

local thesis = {
    required = { "author", "title", "school", "year", "type" },
    optional = { "subtitle", "address", "month", "note", "file" },
}

local misc = {
    required = { },
    optional = { "author", "title", "subtitle", "howpublished", "month", "year", "note", "file" },
}

local periodical = {
    required = { "title", "year" },
    optional = { "subtitle", "authors", "month", "note", "number", "organization", "series", "volume", "file" },
    sets     = {
        authors = { "editor", "publisher" },
    },
}

local proceedings = {
    required = { "title", "year" },
    optional = { "subtitle", "editor", "volume", "number", "series", "address", "month", "organization", "publisher", "note", "pages", "ISBN", "file" },
}

local techreport = {
    required = { "author", "title", "institution", "year" },
    optional = { "subtitle", "type", "number", "address", "month", "note", "file" },
}

local other = {
    required = { "author", "title", "year" },
    optional = { "subtitle", "note", "doi", "file" },
}

local patent = {
    required = { "nationality", "number", "year", "yearfiled" },
    optional = { "author", "title", "subtitle", "language", "assignee", "address", "type", "day", "dayfiled", "month", "monthfiled", "note", "file" },
}

local electronic = {
    required = { "title" },
    optional = { "subtitle", "address", "author", "howpublished", "month", "note", "organization", "year", "url", "doi", "type", "file" },
}

local standard = {
    required = { "authors", "title", "subtitle", "year", "note", "url" },
    optional = { "doi", "file" },
    sets     = {
        authors = { "author", "institution", "organization" },
    },
}

local unpublished = {
    required = { "author", "title", "note" },
    optional = { "subtitle", "month", "year", "file" },
}

local literal = {
    required = { "key", "text" },
    optional = { },
    virtual  = false,
}

return {
    name = "apa",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    virtual = {
        -- all share the same default set
        "authoryear", "authoryears", "authornum", "num", "suffix",
    },
    types = {
        --
        -- list of fields that are interpreted as names: "NAME [and NAME]" where
        -- NAME is one of the following:
        --
        -- First vons Last
        -- vons Last, First
        -- vons Last, Jrs, First
        -- Vons, Last, Jrs, First
        --
        author      = "author",
        editor      = "author",
        artist      = "author",
        interpreter = "author",
        composer    = "author",
        producer    = "author",
    },
    categories = {
        article       = article,
        magazine      = magazine,
        newspaper     = magazine,
        book          = book,
        inbook        = inbook,
        booklet       = booklet,
        incollection  = incollection,
        inproceedings = inproceedings,
        conference    = inproceedings,
        manual        = manual,
        thesis        = thesis,
        mastersthesis = thesis,
        phdthesis     = thesis,
        misc          = misc,
        periodical    = periodical,
        proceedings   = proceedings,
        techreport    = techreport,
        other         = other,
        patent        = patent,
        electronic    = electronic,
        standard      = standard,
        unpublished   = unpublished,
        literal       = literal,
        --
        -- the following fields are for documentation and testing purposes
        --
        ["demo-a"] = {
            required = { "author", "title", "year", "note", "url" },
            optional = { "subtitle", "doi", "file" },
            sets     = {
                author  = { "author", "institution", "organization" },
            },
        },
        ["demo-b"] = {
            required = { "authors", "title", "year", "note", "url" },
            optional = { "subtitle", "doi", "file" },
            sets     = {
                authors = { "author", "institution", "organization" },
            },
        },
    },
}

