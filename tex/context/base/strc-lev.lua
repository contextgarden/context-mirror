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

local level, levels, categories = 0, { }, { }

function sections.defineautolevels(category,list)
    levels[category] = utilities.parsers.settings_to_array(list)
end

function sections.startautolevel(category)
    level = level + 1
    local lc = levels[category]
    if not lc or level > #lc then
        context.nostartstructurehead { format("%s:%s",category,level) }
    else
        context.dostartstructurehead { lc[level] }
    end
    insert(categories,category)
end

function sections.stopautolevel()
    local category = remove(categories)
    local lc = levels[category]
    if not lc or level > #lc then
        context.nostopstructurehead { format("%s:%s",category,level) }
    else
        context.dostopstructurehead { lc[level] }
    end
    level = level - 1
end
