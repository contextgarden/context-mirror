if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

resolvers.finders = resolvers.finders or { }
resolvers.openers = resolvers.openers or { }
resolvers.loaders = resolvers.loaders or { }

resolvers.finders.notfound  = { nil }
resolvers.openers.notfound  = { nil }
resolvers.loaders.notfound  = { false, nil, 0 }
