if not modules then modules = { } end modules ['mtx-fonts'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

dofile(input.find_file("font-syn.lua"))

scripts       = scripts       or { }
scripts.fonts = scripts.fonts or { }

function scripts.fonts.reload(verbose)
    fonts.names.load(true,verbose)
end

local function showfeatures(v,n,f,s,t)
    local iv = input.verbose
    input.verbose = true
    input.report("fontname: %s",v)
    input.report("fullname: %s",n)
    input.report("filename: %s",f)
    if t == "otf" or t == "ttf" then
        local filename = input.find_file(f,t) or ""
        if filename ~= "" then
            local ff = fontforge.open(filename)
            if ff then
                local data = fontforge.to_table(ff)
                fontforge.close(ff)
                local features = { }
                local function collect(what)
                    if data[what] then
                        for _, d in ipairs(data[what]) do
                            if d.features then
                                for _, df in ipairs(d.features) do
                                    features[df.tag] = features[df.tag] or { }
                                    for _, ds in ipairs(df.scripts) do
                                        features[df.tag][ds.script] = features[df.tag][ds.script] or { }
                                        for _, lang in ipairs(ds.langs) do
                                            features[df.tag][ds.script][lang] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                collect('gsub')
                collect('gpos')
                input.report("")
                for _, f in ipairs(table.sortedkeys(features)) do
                    local ff = features[f]
                    for _, s in ipairs(table.sortedkeys(ff)) do
                        local ss = ff[s]
                        input.report("feature: %s, script: %s, language: %s",f:lower(),s:lower(),(table.concat(table.sortedkeys(ss), " ")):lower())
                    end
                end
            end
        end
    end
    input.report("")
    input.verbose = iv
end

function scripts.fonts.list(pattern,reload,all,info)
    if reload then
        input.report("fontnames, reloading font database")
    end
    local t = fonts.names.list(pattern,reload)
    if reload then
        input.report("fontnames, done\n\n")
    end
    if t then
        local s, w = table.sortedkeys(t), { 0, 0, 0 }
        local function action(f)
            for k,v in pairs(s) do
                if all or v == t[v][2]:lower() then
                    local type, name, file, sub = unpack(t[v])
                    f(v,name,file,sub,type)
                end
            end
        end
        action(function(v,n,f,s,t)
            if #v > w[1] then w[1] = #v end
            if #n > w[2] then w[2] = #n end
            if #f > w[3] then w[3] = #f end
        end)
        action(function(v,n,f,s,t)
            if s then s = "(sub)" else s = "" end
            if info then
                showfeatures(v,n,f,s,t)
            else
                local str = string.format("%s  %s  %s %s",v:padd(w[1]," "),n:padd(w[2]," "),f:padd(w[3]," "), s)
                print(str:strip())
            end
        end)
    end
end

function scripts.fonts.save(name,sub)
    local function save(savename,fontblob)
        if fontblob then
            savename = savename:lower() .. ".lua"
            input.report("fontsave, saving data in %s",savename)
            table.tofile(savename,fontforge.to_table(fontblob),"return")
            fontforge.close(fontblob)
        end
    end
    if name and name ~= "" then
        local filename = input.find_file(name) -- maybe also search for opentype
        if filename and filename ~= "" then
            local suffix = file.extname(filename)
            if suffix == 'ttf' or suffix == 'otf' or suffix == 'ttc' then
                local fontinfo = fontforge.info(filename)
                if fontinfo then
                    if fontinfo[1] then
                        for _, v in ipairs(fontinfo) do
                            save(v.fontname,fontforge.open(filename,v.fullname))
                        end
                    else
                        save(fontinfo.fullname,fontforge.open(filename))
                    end
                end
            end
        end
    end
end

banner = banner .. " | font tools "

messages.help = [[
--reload              generate new font database
--list [--info]       list installed fonts (show info)
--save                save open type font in raw table

--pattern=str         filter files
--all                 provide alternatives
]]

if environment.argument("reload") then
    local verbose  = environment.argument("verbose")
    scripts.fonts.reload(verbose)
elseif environment.argument("list") then
    local pattern = environment.argument("pattern") or environment.files[1] or ""
    local all     = environment.argument("all")
    local info    = environment.argument("info")
    local reload  = environment.argument("reload")
    scripts.fonts.list(pattern,reload,all,info)
elseif environment.argument("save") then
    local name = environment.files[1] or ""
    local sub  = environment.files[2] or ""
    scripts.fonts.save(name,sub)
else
    input.help(banner,messages.help)
end
