if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate = utilities.storage.allocate

local resolvers = resolvers

resolvers.finders = allocate { notfound  = { nil } }
resolvers.openers = allocate { notfound  = { nil } }
resolvers.loaders = allocate { notfound  = { false, nil, 0 } }
