if not modules then modules = { } end modules ['font-mis'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local lower, strip = string.lower, string.strip

fonts.otf = fonts.otf or { }

fonts.otf.version = fonts.otf.version or 2.650
fonts.otf.pack    = true
fonts.otf.cache   = containers.define("fonts", "otf", fonts.otf.version, true)

function fonts.otf.loadcached(filename,format,sub)
    -- no recache when version mismatch
    local name = file.basename(file.removesuffix(filename))
    if sub == "" then sub = false end
    local hash = name
    if sub then
        hash = hash .. "-" .. sub
    end
    hash = containers.cleanname(hash)
    local data = containers.read(fonts.otf.cache(), hash)
    if data and not data.verbose then
        fonts.otf.enhancers.unpack(data)
        return data
    else
        return nil
    end
end

local featuregroups = { "gsub", "gpos" }

function fonts.get_features(name,t,script,language)
    local t = lower(t or (name and file.extname(name)) or "")
    if t == "otf" or t == "ttf" or t == "ttc" or t == "dfont" then
        local filename = resolvers.find_file(name,t) or ""
        if filename ~= "" then
            local data = fonts.otf.loadcached(filename)
            if data and data.luatex and data.luatex.features then
                return  data.luatex.features
            else
                local ff = fontloader.open(filename)
                if ff then
                    local data = fontloader.to_table(ff)
                    fontloader.close(ff)
                    local features = { }
                    for k=1,#featuregroups do
                        local what = featuregroups[k]
                        local dw = data[what]
                        if dw then
                            local f = { }
                            features[what] = f
                            for i=1,#dw do
                                local d = dw[i]
                                local dfeatures = d.features
                                if dfeatures then
                                    for i=1,#dfeatures do
                                        local df = dfeatures[i]
                                        local tag = strip(lower(df.tag))
                                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                                        local dfscripts = df.scripts
                                        for i=1,#dfscripts do
                                            local ds = dfscripts[i]
                                            local scri = strip(lower(ds.script))
                                            local fts = ft[scri] if not fts then fts = {} ft[scri] = fts end
                                            local dslangs = ds.langs
                                            for i=1,#dslangs do
                                                local lang = dslangs[i]
                                                lang = strip(lower(lang))
                                                if scri == script then
                                                    if lang == language then
                                                        fts[lang] = 'sl'
                                                    else
                                                        fts[lang] = 's'
                                                    end
                                                else
                                                    if lang == language then
                                                        fts[lang] = 'l'
                                                    else
                                                        fts[lang] = true
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return features
                end
            end
        end
    end
    return nil, nil
end
