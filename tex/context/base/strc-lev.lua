if not modules then modules = { } end modules ['strc-lev'] = {
    version   = 1.001,
    comment   = "companion to strc-lev.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local insert, remove = table.insert, table.remove

local sections = structures.sections
local default  = interfaces.variables.default

sections.levels = sections.levels or { }

local level, levels, categories = 0, sections.levels, { }

storage.register("structures/sections/levels", levels, "structures.sections.levels")

function sections.defineautolevels(category,list)
    levels[category] = utilities.parsers.settings_to_array(list)
end

function sections.startautolevel(category)
    category = category ~= "" and category or default
    level = level + 1
    local lc = levels[category]
    if not lc or level > #lc then
        context.nostarthead { format("%s:%s",category,level) }
    else
        context.dostarthead { lc[level] }
    end
    insert(categories,category)
end

function sections.stopautolevel()
    local category = remove(categories)
    if category then
        local lc = levels[category]
        if not lc or level > #lc then
            context.nostophead { format("%s:%s",category,level) }
        else
            context.dostophead { lc[level] }
        end
        level = level - 1
    else
        -- error
    end
end
