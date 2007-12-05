if not modules then modules = { } end modules ['mtx-fonts'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

dofile(input.find_file(instance,"font-syn.lua"))

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts       = scripts       or { }
scripts.fonts = scripts.fonts or { }

function scripts.fonts.reload()
    fonts.names.load(true)
end

function scripts.fonts.list(pattern,reload,all)
    if reload then
        logs.report("fontnames","reloading font database")
    end
    local t = fonts.names.list(pattern,reload)
    if reload then
        logs.report("fontnames","done\n\n")
    end
    if t then
        local s, w = table.sortedkeys(t), { 0, 0, 0 }
        local function action(f)
            for k,v in pairs(s) do
                if all or v == t[v][2]:lower() then
                    local type, name, file, sub = unpack(t[v])
                    f(v,name,file,sub)
                end
            end
        end
        action(function(v,n,f,s)
            if #v > w[1] then w[1] = #v end
            if #n > w[2] then w[2] = #n end
            if #f > w[3] then w[3] = #f end
        end)
        action(function(v,n,f,s)
            if s then s = "(sub)" else s = "" end
            print(string.format("%s  %s  %s %s",v:padd(w[1]," "),n:padd(w[2]," "),f:padd(w[3]," "), s))
        end)
    end
end

function scripts.fonts.save(name,sub)
    local function save(savename,fontblob)
        if fontblob then
            savename = savename:lower() .. ".lua"
            logs.report("fontsave","saving data in " .. savename)
            table.tofile(savename,fontforge.to_table(fontblob),"return")
            fontforge.close(fontblob)
        end
    end
    if name and name ~= "" then
        local filename = input.find_file(texmf.instance,name) -- maybe also search for opentype
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
--list                list installed fonts
--save                save open type font in raw table

--pattern=str         filter files
--all                 provide alternatives
]]

if environment.argument("reload") then
    scripts.fonts.reload()
elseif environment.argument("list") then
    local pattern = environment.argument("pattern") or environment.files[1] or ""
    local all     = environment.argument("all")
    local reload  = environment.argument("reload")
    scripts.fonts.list(pattern,reload,all)
elseif environment.argument("save") then
    local name = environment.files[1] or ""
    local sub  = environment.files[2] or ""
    scripts.fonts.save(name,sub)
else
    input.help(banner,messages.help)
end
