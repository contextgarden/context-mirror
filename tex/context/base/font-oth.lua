if not modules then modules = { } end modules ['font-oth'] = {
    version   = 1.001,
    comment   = "companion to font-oth.lua (helpers)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fonts = fonts
local otf   = fonts.handlers.otf

-- todo: use nodemode data is available

function otf.getalternate(tfmdata,k,kind,value) -- just initialize nodemode and use that (larger mem print)
    if value then
        local description = tfmdata.descriptions[k]
        if description then
            local slookups = description.slookups -- we assume only slookups (we can always extend)
            if slookups then
                local shared = tfmdata.shared
                local rawdata = shared and shared.rawdata
                if rawdata then
                    local lookuptypes = rawdata.resources.lookuptypes
                    if lookuptypes then
                        local properties = tfmdata.properties
                        -- we could cache these
                        local validlookups, lookuplist = otf.collectlookups(rawdata,kind,properties.script,properties.language)
                        if validlookups then
                            local choice = tonumber(value) or 1 -- no random here (yet)
                            for l=1,#lookuplist do
                                local lookup = lookuplist[l]
                                local found  = slookups[lookup]
                                if found then
                                    local lookuptype = lookuptypes[lookup]
                                    if lookuptype == "substitution" then
                                        return found
                                    elseif lookuptype == "alternate" then
                                        return found[choice] or found[#found]
                                    else
                                        -- ignore
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return k
end
