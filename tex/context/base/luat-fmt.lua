if not modules then modules = { } end modules ['luat-fmt'] = {
    version   = 1.001,
    comment   = "companion to mtxrun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- helper for mtxrun

local quote = string.quote

local function primaryflags()
    local trackers   = environment.argument("trackers")
    local directives = environment.argument("directives")
    local flags = ""
    if trackers and trackers ~= "" then
        flags = flags .. "--trackers=" .. quote(trackers)
    end
    if directives and directives ~= "" then
        flags = flags .. "--directives=" .. quote(directives)
    end
    return flags
end

function environment.make_format(name)
    -- change to format path (early as we need expanded paths)
    local olddir = lfs.currentdir()
    local path = caches.getwritablepath("formats") or "" -- maybe platform
    if path ~= "" then
        lfs.chdir(path)
    end
    logs.simple("format path: %s",lfs.currentdir())
    -- check source file
    local texsourcename = file.addsuffix(name,"tex")
    local fulltexsourcename = resolvers.find_file(texsourcename,"tex") or ""
    if fulltexsourcename == "" then
        logs.simple("no tex source file with name: %s",texsourcename)
        lfs.chdir(olddir)
        return
    else
        logs.simple("using tex source file: %s",fulltexsourcename)
    end
    local texsourcepath = dir.expand_name(file.dirname(fulltexsourcename)) -- really needed
    -- check specification
    local specificationname = file.replacesuffix(fulltexsourcename,"lus")
    local fullspecificationname = resolvers.find_file(specificationname,"tex") or ""
    if fullspecificationname == "" then
        specificationname = file.join(texsourcepath,"context.lus")
        fullspecificationname = resolvers.find_file(specificationname,"tex") or ""
    end
    if fullspecificationname == "" then
        logs.simple("unknown stub specification: %s",specificationname)
        lfs.chdir(olddir)
        return
    end
    local specificationpath = file.dirname(fullspecificationname)
    -- load specification
    local usedluastub = nil
    local usedlualibs = dofile(fullspecificationname)
    if type(usedlualibs) == "string" then
        usedluastub = file.join(file.dirname(fullspecificationname),usedlualibs)
    elseif type(usedlualibs) == "table" then
        logs.simple("using stub specification: %s",fullspecificationname)
        local texbasename = file.basename(name)
        local luastubname = file.addsuffix(texbasename,"lua")
        local lucstubname = file.addsuffix(texbasename,"luc")
        -- pack libraries in stub
        logs.simple("creating initialization file: %s",luastubname)
        utils.merger.selfcreate(usedlualibs,specificationpath,luastubname)
        -- compile stub file (does not save that much as we don't use this stub at startup any more)
        local strip = resolvers.boolean_variable("LUACSTRIP", true)
        if utils.lua.compile(luastubname,lucstubname,false,strip) and lfs.isfile(lucstubname) then
            logs.simple("using compiled initialization file: %s",lucstubname)
            usedluastub = lucstubname
        else
            logs.simple("using uncompiled initialization file: %s",luastubname)
            usedluastub = luastubname
        end
    else
        logs.simple("invalid stub specification: %s",fullspecificationname)
        lfs.chdir(olddir)
        return
    end
    -- generate format
    local command = string.format("luatex --ini %s --lua=%s %s %sdump",primaryflags(),quote(usedluastub),quote(fulltexsourcename),os.platform == "unix" and "\\\\" or "\\")
    logs.simple("running command: %s\n",command)
    os.spawn(command)
    -- remove related mem files
    local pattern = file.removesuffix(file.basename(usedluastub)).."-*.mem"
 -- logs.simple("removing related mplib format with pattern '%s'", pattern)
    local mp = dir.glob(pattern)
    if mp then
        for i=1,#mp do
            local name = mp[i]
            logs.simple("removing related mplib format %s", file.basename(name))
            os.remove(name)
        end
    end
    lfs.chdir(olddir)
end

function environment.run_format(name,data,more)
 -- hm, rather old code here; we can now use the file.whatever functions
    if name and name ~= "" then
        local barename = file.removesuffix(name)
        local fmtname = caches.getfirstreadablefile(file.addsuffix(barename,"fmt"),"formats")
        if fmtname == "" then
            fmtname = resolvers.find_file(file.addsuffix(barename,"fmt")) or ""
        end
        fmtname = resolvers.clean_path(fmtname)
        if fmtname == "" then
            logs.simple("no format with name: %s",name)
        else
            local barename = file.removesuffix(name) -- expanded name
            local luaname = file.addsuffix(barename,"luc")
            if not lfs.isfile(luaname) then
                luaname = file.addsuffix(barename,"lua")
            end
            if not lfs.isfile(luaname) then
                logs.simple("using format name: %s",fmtname)
                logs.simple("no luc/lua with name: %s",barename)
            else
                local q = string.quote
                local command = string.format("luatex %s --fmt=%s --lua=%s %s %s",primaryflags(),quote(barename),quote(luaname),quote(data),more ~= "" and quote(more) or "")
                logs.simple("running command: %s",command)
                os.spawn(command)
            end
        end
    end
end
