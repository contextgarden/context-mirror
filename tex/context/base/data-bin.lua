if not modules then modules = { } end modules ['data-bin'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders
local unpack = unpack or table.unpack

function resolvers.findbinfile(filename, filetype)
    return resolvers.methodhandler('finders',file.collapse_path(filename), filetype)
end

function resolvers.openbinfile(filename)
    return resolvers.methodhandler('loaders',file.collapse_path(filename))
end

function resolvers.loadbinfile(filename, filetype)
    local fname = resolvers.findbinfile(file.collapse_path(filename), filetype)
    if fname and fname ~= "" then
        return resolvers.openbinfile(fname)
    else
        return unpack(loaders.notfound)
    end
end
