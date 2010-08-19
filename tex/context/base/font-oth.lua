if not modules then modules = { } end modules ['font-oth'] = {
    version   = 1.001,
    comment   = "companion to font-oth.lua (helpers)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpegmatch = lpeg.match
local splitter  = lpeg.Ct(lpeg.splitat(" "))

local collect_lookups = fonts.otf.collect_lookups

-- For the moment there is no need to cache this but this might
-- happen when I get the feeling that there is a performance
-- penalty involved.

function fonts.otf.getalternate(tfmdata,k,kind,value)
    if value then
        local shared = tfmdata.shared
        local otfdata = shared and shared.otfdata
        if otfdata then
            local validlookups, lookuplist = collect_lookups(otfdata,kind,tfmdata.script,tfmdata.language)
            if validlookups then
                local lookups = tfmdata.descriptions[k].slookups -- we assume only slookups (we can always extend)
                if lookups then
                    local unicodes = tfmdata.unicodes -- names to unicodes
                    local choice = tonumber(value)
                    for l=1,#lookuplist do
                        local lookup = lookuplist[l]
                        local p = lookups[lookup]
                        if p then
                            local pc = p[2] -- p.components
                            if pc then
                                pc = lpegmatch(splitter,pc)
                                return unicodes[pc[choice] or pc[#pc]]
                            end
                        end
                    end
                end
            end
        end
    end
    return k
end
