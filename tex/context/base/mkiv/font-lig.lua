if not modules then modules = { } end modules ['font-lig'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This module is not loaded but generated a file for plain TeX as a substitute
-- for collapsing the input: "luatex-fonts-lig.lua" with "collapse=yes".

local standalone = not characters

if standalone then
    require("char-def")
    require("char-utf")
    if characters.initialize then
        characters.initialize()
    end
end

local data = { } -- if we ever preload this i'll cache it

for first, seconds in next, characters.graphemes do
    for second, combined in next, seconds do
        data[combined] = { first, second }
    end
end

-- data['c'] = { 'a', 'b' }
-- data['d'] = { 'c', 'c' }

local feature = {
    name    = "collapse",
    type    = "ligature",
    prepend = true,
    dataset = {
        { data = data },
        { data = data },
    }
}

if standalone then
    local filename = "luatex-fonts-lig.lua"
    local filedata = "-- this file is generated by context\n\n"
                  .. "fonts.handlers.otf.addfeature "
                  .. table.serialize(feature,false)
    logs.report("fonts","pseudo ligature file %a saved",filename)
    io.savedata(filename,filedata)
else
    fonts.handlers.otf.addfeature(feature)
end
