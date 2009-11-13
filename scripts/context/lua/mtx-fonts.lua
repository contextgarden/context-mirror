if not modules then modules = { } end modules ['mtx-fonts'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not fontloader then fontloader = fontforge end

dofile(resolvers.find_file("font-otp.lua","tex"))
dofile(resolvers.find_file("font-syn.lua","tex"))
dofile(resolvers.find_file("font-mis.lua","tex"))

scripts       = scripts       or { }
scripts.fonts = scripts.fonts or { }

function scripts.fonts.reload(verbose)
    fonts.names.load(true,verbose)
end

function scripts.fonts.names(name)
    name = name or "luatex-fonts-names.lua"
    fonts.names.identify(true)
    local data = fonts.names.data
    if data then
        data.fallback_mapping = nil
        logs.report("fontnames","saving names in '%s'",name)
        io.savedata(name,table.serialize(data,true))
    elseif lfs.isfile(name) then
        os.remove(name)
    end
end

local function showfeatures(v,n,f,s,t)
    logs.simple("fontname: %s",v)
    logs.simple("fullname: %s",n)
    logs.simple("filename: %s",f)
    local features = fonts.get_features(f,t)
    if features then
        for what, v in table.sortedpairs(features) do
            local data = features[what]
            if data and next(data) then
                logs.simple()
                logs.simple("%s features:",what)
                logs.simple()
                logs.simple("feature  script   languages")
                logs.simple()
                for f,ff in table.sortedpairs(data) do
                    local done = false
                    for s, ss in table.sortedpairs(ff) do
                        if s == "*"  then s       = "all" end
                        if ss  ["*"] then ss["*"] = nil ss.all = true end
                        if done then
                            f = ""
                        else
                            done = true
                        end
                        logs.simple("% -8s % -8s % -8s",f,s,table.concat(table.sortedkeys(ss), " "))
                    end
                end
            end
        end
    end
    logs.reportline()
end

local function make_pattern(pattern) -- will become helper in string
    pattern = pattern:lower()
    pattern = pattern:gsub("%-","%%-")
    pattern = pattern:gsub("%.","%%.")
    pattern = pattern:gsub("%*",".*")
    pattern = pattern:gsub("%?",".?")
    if pattern == "" then
        pattern = ".*"
    else
        pattern = "^" .. pattern .. "$"
    end
    return pattern
end

local function reloadbase(reload)
    if reload then
        logs.simple("fontnames, reloading font database")
        names.load(true)
        logs.simple("fontnames, done\n\n")
    end
end

function scripts.fonts.list_by_pattern(pattern,reload,all,info)
    reloadbase(reload)
    local t = fonts.names.list(make_pattern(pattern))
    if t then
        local s, w = table.sortedkeys(t), { 0, 0, 0 }
        for k,v in ipairs(s) do
            local entry = t[v]
            local n = #v        if n > w[1] then w[1] = n end
            local n = #entry[2] if n > w[2] then w[2] = n end
            local n = #entry[3] if n > w[3] then w[3] = n end
        end
        local template = "%-" .. w[1] .. "s  %-" .. w[2] .. "s  %-" .. w[3] .. "s %s"
        for k,v in ipairs(s) do
            local entry = t[v]
            local tag, fontname, filename, sub = v, entry[2], entry[3], entry[4]
            if sub then sub = "(sub)" else sub = "" end
            if info then
                showfeatures(tag,fontname,filename,sub,t)
            else
                print(string.format(template,tag,fontname,filename,sub))
            end
        end
    end
end

function scripts.fonts.list_by_specification(specification,reload,all,info)
    reloadbase(reload)
    local t = fonts.names.collectspec(specification)
    if t then
        local w, tags = { 0, 0, 0 }, { }
        for k,entry in ipairs(t) do
            local s = entry[5] .. "-" .. (entry[6] or "noweight") .. "-" .. (entry[7] or "nostyle") .. "-" .. (entry[8] or "nowidth")
            local n = #s        if n > w[1] then w[1] = n end
            local n = #entry[2] if n > w[2] then w[2] = n end
            local n = #entry[3] if n > w[3] then w[3] = n end
            tags[k] = s
        end
        local template = "%-" .. w[1] .."s  %-" .. w[2] .. "s  %-" .. w[3] .. "s  %s"
        for k,entry in ipairs(t) do
            local tag, fontname, filename, sub, name, weight, style = tags[k], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]
            if sub then sub = "(sub)" else sub = "" end
            print(string.format(template,tag,fontname,filename,sub))
        end
    end
end

function scripts.fonts.save(name,sub)
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
            local suffix = file.extname(filename)
            if suffix == 'ttf' or suffix == 'otf' or suffix == 'ttc' or suffix == "dfont" then
                local fontinfo = fontloader.info(filename)
                if fontinfo then
                    logs.simple("font: %s located as %s",name,filename)
                    if fontinfo[1] then
                        for _, v in ipairs(fontinfo) do
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

logs.extendbanner("Font Tools 0.20",true)

messages.help = [[
--reload              generate new font database
--list [--info]       list installed fonts (show info)
--save                save open type font in raw table
--names               generate 'luatex-fonts-names.lua' (not for context!)

--pattern=str         filter files using pattern
--all                 provide alternatives
]]

if environment.argument("reload") then
    scripts.fonts.reload(true)
elseif environment.argument("names") then
    scripts.fonts.names()
elseif environment.argument("list") then
    local all     = environment.argument("all")
    local info    = environment.argument("info")
    local reload  = environment.argument("reload")
    if environment.argument("pattern") then
        scripts.fonts.list_by_pattern(environment.argument("pattern"),reload,all,info)
    elseif environment.files[1] then
        scripts.fonts.list_by_specification(environment.files[1],reload,all,info)
    else
        scripts.fonts.list_by_pattern("",reload,all,info) -- wildcard
    end
elseif environment.argument("save") then
    local name = environment.files[1] or ""
    local sub  = environment.files[2] or ""
    scripts.fonts.save(name,sub)
else
    logs.help(messages.help)
end
