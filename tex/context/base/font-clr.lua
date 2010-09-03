if not modules then modules = { } end modules ['font-clr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from ini:

fonts.colors = fonts.colors or { } -- dummy in ini
local colors = fonts.colors

local set_attribute   = node.set_attribute
local unset_attribute = node.unset_attribute

local attribute = attributes.private('color')
local mapping   = attributes and attributes.list[attribute] or { }

function colors.set(n,c)
    local mc = mapping[c]
    if not mc then
        unset_attribute(n,attribute)
    else
        set_attribute(n,attribute,mc)
    end
end

function colors.reset(n)
    unset_attribute(n,attribute)
end
