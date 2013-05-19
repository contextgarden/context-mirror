if not modules then modules = { } end modules ['font-hsh'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatableindex = table.setmetatableindex
local currentfont       = font.current
local allocate          = utilities.storage.allocate

local fonts         = fonts
local hashes        = fonts.hashes or allocate()
fonts.hashes        = hashes

-- todo: autoallocate ... just create on the fly .. use constructors.keys (problem: plurals)

local identifiers   = hashes.identifiers  or allocate()
local characters    = hashes.characters   or allocate() -- chardata
local descriptions  = hashes.descriptions or allocate()
local parameters    = hashes.parameters   or allocate()
local properties    = hashes.properties   or allocate()
local resources     = hashes.resources    or allocate()
local spacings      = hashes.spacings     or allocate()
local spaces        = hashes.spaces       or allocate()
local quads         = hashes.quads        or allocate() -- maybe also spacedata
local xheights      = hashes.xheights     or allocate()
local csnames       = hashes.csnames      or allocate() -- namedata
local marks         = hashes.marks        or allocate()
local italics       = hashes.italics      or allocate()
local lastmathids   = hashes.lastmathids  or allocate()
local dynamics      = hashes.dynamics     or allocate()

hashes.characters   = characters
hashes.descriptions = descriptions
hashes.parameters   = parameters
hashes.properties   = properties
hashes.resources    = resources
hashes.spacings     = spacings
hashes.spaces       = spaces
hashes.quads        = quads                 hashes.emwidths  = quads
hashes.xheights     = xheights              hashes.exheights = xheights
hashes.csnames      = csnames
hashes.marks        = marks
hashes.italics      = italics
hashes.lastmathids  = lastmathids
hashes.dynamics     = dynamics

local nulldata = allocate {
    name         = "nullfont",
    characters   = { },
    descriptions = { },
    properties   = { },
    parameters   = { -- lmromanregular @ 12pt
        slantperpoint =      0,
        spacing       = {
            width   = 256377,
            stretch = 128188,
            shrink  = 85459,
            extra   = 85459,
        },
        quad          = 786432,
        xheight       = 338952,
        -- compatibility:
        slant         =      0, -- 1
        space         = 256377, -- 2
        space_stretch = 128188, -- 3
        space_shrink  =  85459, -- 4
        x_height      = 338952, -- 5
        quad          = 786432, -- 6
        extra_space   =  85459, -- 7
    },
}

fonts.nulldata = nulldata

fonts.constructors.enhanceparameters(nulldata.parameters) -- official copies for us

setmetatableindex(identifiers, function(t,k)
    return k == true and identifiers[currentfont()] or nulldata
end)

setmetatableindex(characters, function(t,k)
    if k == true then
        return characters[currentfont()]
    else
        local characters = identifiers[k].characters
        t[k] = characters
        return characters
    end
end)

setmetatableindex(descriptions, function(t,k)
    if k == true then
        return descriptions[currentfont()]
    else
        local descriptions = identifiers[k].descriptions
        t[k] = descriptions
        return descriptions
    end
end)

setmetatableindex(parameters, function(t,k)
    if k == true then
        return parameters[currentfont()]
    else
        local parameters = identifiers[k].parameters
        t[k] = parameters
        return parameters
    end
end)

setmetatableindex(properties, function(t,k)
    if k == true then
        return properties[currentfont()]
    else
        local properties = identifiers[k].properties
        t[k] = properties
        return properties
    end
end)

setmetatableindex(resources, function(t,k)
    if k == true then
        return resources[currentfont()]
    else
        local shared    = identifiers[k].shared
        local rawdata   = shared and shared.rawdata
        local resources = rawdata and rawdata.resources
        t[k] = resources or false -- better than resolving each time
        return resources
    end
end)

setmetatableindex(quads, function(t,k)
    if k == true then
        return quads[currentfont()]
    else
        local parameters = parameters[k]
        local quad = parameters and parameters.quad or 0
        t[k] = quad
        return quad
    end
end)

local nospacing = {
    width   = 0,
    stretch = 0,
    shrink  = 0,
    extra   = 0,
}

setmetatableindex(spacings, function(t,k)
    if k == true then
        return spacings[currentfont()]
    else
        local parameters = parameters[k]
        local spacing = parameters and parameters.spacing or nospacing
        t[k] = spacing
        return spacing
    end
end)

setmetatableindex(spaces, function(t,k)
    if k == true then
        return spaces[currentfont()]
    else
        local space = spacings[k].width
        t[k] = space
        return space
    end
end)

setmetatableindex(marks, function(t,k)
    if k == true then
        return marks[currentfont()]
    else
        local resources = identifiers[k].resources or { }
        local marks = resources.marks or { }
        t[k] = marks
        return marks
    end
end)

setmetatableindex(xheights, function(t,k)
    if k == true then
        return xheights[currentfont()]
    else
        local parameters = parameters[k]
        local xheight = parameters and parameters.xheight or 0
        t[k] = xheight
        return xheight
    end
end)

setmetatableindex(italics, function(t,k) -- is test !
    if k == true then
        return italics[currentfont()]
    else
        local properties = identifiers[k].properties
        local hasitalics = properties and properties.hasitalics
        if hasitalics then
            hasitalics = characters[k] -- convenient return
        else
            hasitalics = false
        end
        t[k] = hasitalics
        return hasitalics
    end
end)

setmetatableindex(dynamics, function(t,k)
    if k == true then
        return dynamics[currentfont()]
    else
        local shared = identifiers[k].shared
        local dynamics = shared and shared.dynamics or false
        t[k] = dynamics
        return dynamics
    end
end)

function font.getfont(id)
    return identifiers[id]
end
