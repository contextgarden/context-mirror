if not modules then modules = { } end modules ['grph-epd'] = {
    version   = 1.001,
    comment   = "companion to grph-epd.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local variables = interfaces.variables

-- todo: page, name, file, url

function figures.mergegoodies(optionlist)
    local options = aux.settings_to_hash(optionlist)
    local all = options[variables.all] or options[variables.yes]
    if all or options[variables.reference] then
        backends.codeinjections.mergereferences()
    end
    if all or options[variables.layer] then
        backends.codeinjections.mergelayers()
    end

end
