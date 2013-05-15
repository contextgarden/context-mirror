if not modules then modules = { } end modules ['s-fonts-features'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-features.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts          or { }
moduledata.fonts.features = moduledata.fonts.features or { }

-- for the moment only otf

local NC, NR, bold = context.NC, context.NR, context.bold

function moduledata.fonts.features.showused(specification)

    specification = interfaces.checkedspecification(specification)

 -- local list = utilities.parsers.settings_to_set(specification.list or "all")

    context.starttabulate { "|T|T|T|T|T|" }

        context.HL()

            NC() bold("feature")
            NC()
            NC() bold("description")
            NC() bold("value")
            NC() bold("internal")
            NC() NR()

        context.HL()

            local usedfeatures = fonts.handlers.otf.statistics.usedfeatures
            local features     = fonts.handlers.otf.tables.features
            local descriptions = fonts.handlers.otf.features.descriptions

            for feature, keys in table.sortedhash(usedfeatures) do
             -- if list.all or (list.otf and rawget(features,feature)) or (list.extra and rawget(descriptions,feature)) then
                    local done = false
                    for k, v in table.sortedhash(keys) do
                        if done then
                            NC()
                            NC()
                            NC()
                        elseif rawget(descriptions,feature) then
                            NC() context(feature)
                            NC() context("+") -- extra
                            NC() context(descriptions[feature])
                            done = true
                        elseif rawget(features,feature) then
                            NC() context(feature)
                            NC()              -- otf
                            NC() context(features[feature])
                            done = true
                        else
                            NC() context(feature)
                            NC() context("-") -- unknown
                            NC()
                            done = true
                        end
                        NC() context(k)
                        NC() context(tostring(v))
                        NC() NR()
                    end
             -- end
            end

        context.HL()

    context.stoptabulate()

end
