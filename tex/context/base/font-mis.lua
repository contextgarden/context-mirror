if not modules then modules = { } end modules ['font-mis'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, pairs, ipairs = next, pairs, ipairs
local lower, strip = string.lower, string.strip

fonts.otf = fonts.otf or { }

fonts.otf.version = fonts.otf.version or 2.635
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

function fonts.get_features(name,t,script,language)
    local t = lower(t or (name and file.extname(name)) or "")
    if t == "otf" or t == "ttf" or t == "ttc" then
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
                    for k, what in pairs { "gsub", "gpos" } do
                        local dw = data[what]
                        if dw then
                            local f = { }
                            features[what] = f
                            for _, d in ipairs(dw) do
                                if d.features then
                                    for _, df in ipairs(d.features) do
                                        local tag = strip(lower(df.tag))
                                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                                        for _, ds in ipairs(df.scripts) do
                                            local scri = strip(lower(ds.script))
                                            local fts = ft[scri] if not fts then fts = {} ft[scri] = fts end
                                            for _, lang in ipairs(ds.langs) do
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
