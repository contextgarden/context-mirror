if not modules then modules = { } end modules ['mtx-fonts'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: fc-cache -v en check dirs, or better is: fc-cat -v | grep Directory

if not fontloader then fontloader = fontforge end

dofile(resolvers.find_file("font-otp.lua","tex"))
dofile(resolvers.find_file("font-syn.lua","tex"))
dofile(resolvers.find_file("font-mis.lua","tex"))

scripts       = scripts       or { }
scripts.fonts = scripts.fonts or { }

function fonts.names.statistics()
    fonts.names.load()

    local data = fonts.names.data
    local statistics = data.statistics

    local function counted(t)
        local n = { }
        for k, v in next, t do
            n[k] = table.count(v)
        end
        return table.sequenced(n)
    end

    logs.simple("cache uuid      : %s", data.cache_uuid)
    logs.simple("cache version   : %s", data.cache_version)
    logs.simple("number of trees : %s", #data.data_state)
    logs.simpleline()
    logs.simple("number of fonts : %s", statistics.fonts or 0)
    logs.simple("used files      : %s", statistics.readfiles or 0)
    logs.simple("skipped files   : %s", statistics.skippedfiles or 0)
    logs.simple("duplicate files : %s", statistics.duplicatefiles or 0)
    logs.simple("specifications  : %s", #data.specifications)
    logs.simple("families        : %s", table.count(data.families))
    logs.simpleline()
    logs.simple("mappings        : %s", counted(data.mappings))
    logs.simple("fallbacks       : %s", counted(data.fallbacks))
    logs.simpleline()
    logs.simple("used styles     : %s", table.sequenced(statistics.used_styles))
    logs.simple("used variants   : %s", table.sequenced(statistics.used_variants))
    logs.simple("used weights    : %s", table.sequenced(statistics.used_weights))
    logs.simple("used widths     : %s", table.sequenced(statistics.used_widths))
    logs.simpleline()
    logs.simple("found styles    : %s", table.sequenced(statistics.styles))
    logs.simple("found variants  : %s", table.sequenced(statistics.variants))
    logs.simple("found weights   : %s", table.sequenced(statistics.weights))
    logs.simple("found widths    : %s", table.sequenced(statistics.widths))

end

function fonts.names.simple()
    local simpleversion = 1.001
    local simplelist = { "ttf", "otf", "ttc", "dfont" }
    local name = "luatex-fonts-names.lua"
    fonts.names.filters.list = simplelist
    fonts.names.version = simpleversion -- this number is the same as in font-dum.lua
    logs.report("fontnames","generating font database for 'luatex-fonts' version %s",fonts.names.version)
    fonts.names.identify(true)
    local data = fonts.names.data
    if data then
        local simplemappings = { }
        local simplified = {
            mappings = simplemappings,
            version = simpleversion,
        }
        local specifications = data.specifications
        for i=1,#simplelist do
            local format = simplelist[i]
            for tag, index in next, data.mappings[format] do
                local s = specifications[index]
                simplemappings[tag] = { s.rawname, s.filename, s.subfont }
            end
        end
        logs.report("fontnames","saving names in '%s'",name)
        io.savedata(name,table.serialize(simplified,true))
        local data = io.loaddata(resolvers.find_file("font-dum.lua","tex"))
        local dummy = string.match(data,"fonts%.names%.version%s*=%s*([%d%.]+)")
        if tonumber(dummy) ~= simpleversion then
            logs.report("fontnames","warning: version number %s in 'font-dum' does not match database version number %s",dummy or "?",simpleversion)
        end
    elseif lfs.isfile(name) then
        os.remove(name)
    end
end

function scripts.fonts.reload()
    if environment.argument("simple") then
        fonts.names.simple()
    else
        fonts.names.load(true)
    end
end

local function subfont(sf)
    if sf then
        return string.format("index: % 2s", sf)
    else
        return ""
    end
end

local function fontweight(fw)
    if fw then
        return string.format("conflict: %s", fw)
    else
        return ""
    end
end

local function showfeatures(tag,specification)
    logs.simple("mapping : %s",tag)
    logs.simple("fontname: %s",specification.fontname)
    logs.simple("fullname: %s",specification.fullname)
    logs.simple("filename: %s",specification.filename)
    logs.simple("family  : %s",specification.familyname or "<nofamily>")
    logs.simple("weight  : %s",specification.weight or "<noweight>")
    logs.simple("style   : %s",specification.style or "<nostyle>")
    logs.simple("width   : %s",specification.width or "<nowidth>")
    logs.simple("variant : %s",specification.variant or "<novariant>")
    logs.simple("subfont : %s",subfont(specification.subfont))
    logs.simple("fweight : %s",fontweight(specification.fontweight))
    -- maybe more
    local features = fonts.get_features(specification.filename,specification.format)
    if features then
        for what, v in table.sortedhash(features) do
            local data = features[what]
            if data and next(data) then
                logs.simple()
                logs.simple("%s features:",what)
                logs.simple()
                logs.simple("feature  script   languages")
                logs.simple()
                for f,ff in table.sortedhash(data) do
                    local done = false
                    for s, ss in table.sortedhash(ff) do
                        if s == "*"  then s       = "all" end
                        if ss  ["*"] then ss["*"] = nil ss.all = true end
                        if done then
                            f = ""
                        else
                            done = true
                        end
                        logs.simple("% -8s % -8s % -8s",f,s,table.concat(table.sortedkeys(ss), " ")) -- todo: padd 4
                    end
                end
            end
        end
    else
        logs.simple()
        logs.simple("no features")
        logs.simple()
    end
    logs.reportline()
end

local function reloadbase(reload)
    if reload then
        logs.simple("fontnames, reloading font database")
        names.load(true)
        logs.simple("fontnames, done\n\n")
    end
end

local function list_specifications(t,info)
    if t then
        local s = table.sortedkeys(t)
        if info then
            for k=1,#s do
                local v = s[k]
                showfeatures(v,t[v])
            end
        else
            for k=1,#s do
                local v = s[k]
                local entry = t[v]
                s[k] = {
                    entry.familyname  or "<nofamily>",
                    entry.weight      or "<noweight>",
                    entry.style       or "<nostyle>",
                    entry.width       or "<nowidth>",
                    entry.variant     or "<novariant>",
                    entry.fontname,
                    entry.filename,
                    subfont(entry.subfont),
                    fontweight(entry.fontweight),
                }
            end
            aux.formatcolumns(s)
            for k=1,#s do
                texio.write_nl(s[k])
            end
        end
    end
end

local function list_matches(t,info)
    if t then
        local s, w = table.sortedkeys(t), { 0, 0, 0 }
        if info then
            for k=1,#s do
                local v = s[k]
                showfeatures(v,t[v])
            end
        else
            for k=1,#s do
                local v = s[k]
                local entry = t[v]
                s[k] = {
                    v,
                    entry.fontname,
                    entry.filename,
                    subfont(entry.subfont)
                }
            end
            aux.formatcolumns(s)
            for k=1,#s do
                texio.write_nl(s[k])
            end
        end
    end
end

function scripts.fonts.list()

    local all     = environment.argument("all")
    local info    = environment.argument("info")
    local reload  = environment.argument("reload")
    local pattern = environment.argument("pattern")
    local filter  = environment.argument("filter")
    local given   = environment.files[1]

    reloadbase(reload)

    if environment.argument("name") then
        if pattern then
            --~ mtxrun --script font --list --name --pattern=*somename*
            list_matches(fonts.names.list(string.topattern(pattern,true),reload,all),info)
        elseif filter then
            logs.report("fontnames","not supported: --list --name --filter",name)
        elseif given then
            --~ mtxrun --script font --list --name somename
            list_matches(fonts.names.list(given,reload,all),info)
        else
            logs.report("fontnames","not supported: --list --name <no specification>",name)
        end
    elseif environment.argument("spec") then
        if pattern then
            --~ mtxrun --script font --list --spec --pattern=*somename*
            logs.report("fontnames","not supported: --list --spec --pattern",name)
        elseif filter then
            --~ mtxrun --script font --list --spec --filter="fontname=somename"
            list_specifications(fonts.names.getlookups(filter),info)
        elseif given then
            --~ mtxrun --script font --list --spec somename
            list_specifications(fonts.names.collectspec(given,reload,all),info)
        else
            logs.report("fontnames","not supported: --list --spec <no specification>",name)
        end
    elseif environment.argument("file") then
        if pattern then
            --~ mtxrun --script font --list --file --pattern=*somename*
            list_specifications(fonts.names.collectfiles(string.topattern(pattern,true),reload,all),info)
        elseif filter then
            logs.report("fontnames","not supported: --list --spec",name)
        elseif given then
            --~ mtxrun --script font --list --file somename
            list_specifications(fonts.names.collectfiles(given,reload,all),info)
        else
            logs.report("fontnames","not supported: --list --file <no specification>",name)
        end
    elseif pattern then
        --~ mtxrun --script font --list --pattern=*somename*
       list_matches(fonts.names.list(string.topattern(pattern,true),reload,all),info)
    elseif given then
        --~ mtxrun --script font --list somename
        list_matches(fonts.names.list(given,reload,all),info)
    elseif all then
        pattern = "*"
        list_matches(fonts.names.list(string.topattern(pattern,true),reload,all),info)
    else
        logs.report("fontnames","not supported: --list <no specification>",name)
    end

end

function scripts.fonts.save()
    local name = environment.files[1] or ""
    local sub  = environment.files[2] or ""
    local function save(savename,fontblob)
        if fontblob then
            savename = savename:lower() .. ".lua"
            logs.simple("fontsave, saving data in %s",savename)
            table.tofile(savename,fontloader.to_table(fontblob),"return")
            fontloader.close(fontblob)
        end
    end
    if name and name ~= "" then
        local filename = resolvers.find_file(name) -- maybe also search for opentype
        if filename and filename ~= "" then
            local suffix = string.lower(file.extname(filename))
            if suffix == 'ttf' or suffix == 'otf' or suffix == 'ttc' or suffix == "dfont" then
                local fontinfo = fontloader.info(filename)
                if fontinfo then
                    logs.simple("font: %s located as %s",name,filename)
                    if fontinfo[1] then
                        for k=1,#fontinfo do
                            local v = fontinfo[k]
                            save(v.fontname,fontloader.open(filename,v.fullname))
                        end
                    else
                        save(fontinfo.fullname,fontloader.open(filename))
                    end
                else
                    logs.simple("font: %s cannot be read",filename)
                end
            else
                logs.simple("font: %s not saved",filename)
            end
        else
            logs.simple("font: %s not found",name)
        end
    else
        logs.simple("font: no name given")
    end
end

logs.extendbanner("ConTeXt Font Database Management 0.21")

messages.help = [[
--save                save open type font in raw table

--reload              generate new font database
--reload --simple     generate 'luatex-fonts-names.lua' (not for context!)

--list --name         list installed fonts, filter by name [--pattern]
--list --spec         list installed fonts, filter by spec [--filter]
--list --file         list installed fonts, filter by file [--pattern]

--pattern=str         filter files using pattern
--filter=list         key-value pairs
--all                 show all found instances
--info                give more details
--track=list          enable trackers
--statistics          some info about the database

examples of searches:

mtxrun --script font --list somename (== --pattern=*somename*)

mtxrun --script font --list --name somename
mtxrun --script font --list --name --pattern=*somename*

mtxrun --script font --list --spec somename
mtxrun --script font --list --spec somename-bold-italic
mtxrun --script font --list --spec --pattern=*somename*
mtxrun --script font --list --spec --filter="fontname=somename"
mtxrun --script font --list --spec --filter="familyname=somename,weight=bold,style=italic,width=condensed"
mtxrun --script font --list --spec --filter="familyname=crap*,weight=bold,style=italic"

mtxrun --script font --list --file somename
mtxrun --script font --list --file --pattern=*somename*
]]

local track = environment.argument("track")

if track then trackers.enable(track) end

if environment.argument("names") then
    environment.setargument("reload",true)
    environment.setargument("simple",true)
end

if environment.argument("list") then
    scripts.fonts.list()
elseif environment.argument("reload") then
    scripts.fonts.reload()
elseif environment.argument("save") then
    scripts.fonts.save()
elseif environment.argument("statistics") then
    fonts.names.statistics()
else
    logs.help(messages.help)
end
