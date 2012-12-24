if not modules then modules = { } end modules ['luat-fmt'] = {
    version   = 1.001,
    comment   = "companion to mtxrun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


local format = string.format
local quoted      = string.quoted
local luasuffixes = utilities.lua.suffixes

local report_format = logs.reporter("resolvers","formats")

local function primaryflags() -- not yet ok
    local trackers   = environment.argument("trackers")
    local directives = environment.argument("directives")
    local flags = ""
    if trackers and trackers ~= "" then
        flags = flags .. "--trackers=" .. quoted(trackers)
    end
    if directives and directives ~= "" then
        flags = flags .. "--directives=" .. quoted(directives)
    end
    return flags
end

function environment.make_format(name)
    local engine = environment.ownmain or "luatex"
    -- change to format path (early as we need expanded paths)
    local olddir = dir.current()
    local path = caches.getwritablepath("formats",engine) or "" -- maybe platform
    if path ~= "" then
        lfs.chdir(path)
    end
    report_format("format path: %s",dir.current())
    -- check source file
    local texsourcename = file.addsuffix(name,"mkiv")
    local fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    if fulltexsourcename == "" then
        texsourcename = file.addsuffix(name,"tex")
        fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    end
    if fulltexsourcename == "" then
        report_format("no tex source file with name: %s (mkiv or tex)",name)
        lfs.chdir(olddir)
        return
    else
        report_format("using tex source file: %s",fulltexsourcename)
    end
    local texsourcepath = dir.expandname(file.dirname(fulltexsourcename)) -- really needed
    -- check specification
    local specificationname = file.replacesuffix(fulltexsourcename,"lus")
    local fullspecificationname = resolvers.findfile(specificationname,"tex") or ""
    if fullspecificationname == "" then
        specificationname = file.join(texsourcepath,"context.lus")
        fullspecificationname = resolvers.findfile(specificationname,"tex") or ""
    end
    if fullspecificationname == "" then
        report_format("unknown stub specification: %s",specificationname)
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
        report_format("using stub specification: %s",fullspecificationname)
        local texbasename = file.basename(name)
        local luastubname = file.addsuffix(texbasename,luasuffixes.lua)
        local lucstubname = file.addsuffix(texbasename,luasuffixes.luc)
        -- pack libraries in stub
        report_format("creating initialization file: %s",luastubname)
        utilities.merger.selfcreate(usedlualibs,specificationpath,luastubname)
        -- compile stub file (does not save that much as we don't use this stub at startup any more)
        if utilities.lua.compile(luastubname,lucstubname) and lfs.isfile(lucstubname) then
            report_format("using compiled initialization file: %s",lucstubname)
            usedluastub = lucstubname
        else
            report_format("using uncompiled initialization file: %s",luastubname)
            usedluastub = luastubname
        end
    else
        report_format("invalid stub specification: %s",fullspecificationname)
        lfs.chdir(olddir)
        return
    end
    -- generate format
    local command = format("%s --ini %s --lua=%s %s %sdump",engine,primaryflags(),quoted(usedluastub),quoted(fulltexsourcename),os.platform == "unix" and "\\\\" or "\\")
    report_format("running command: %s\n",command)
    os.spawn(command)
    -- remove related mem files
    local pattern = file.removesuffix(file.basename(usedluastub)).."-*.mem"
 -- report_format("removing related mplib format with pattern '%s'", pattern)
    local mp = dir.glob(pattern)
    if mp then
        for i=1,#mp do
            local name = mp[i]
            report_format("removing related mplib format %s", file.basename(name))
            os.remove(name)
        end
    end
    lfs.chdir(olddir)
end

function environment.run_format(name,data,more)
    if name and name ~= "" then
        local engine = environment.ownmain or "luatex"
        local barename = file.removesuffix(name)
        local fmtname = caches.getfirstreadablefile(file.addsuffix(barename,"fmt"),"formats",engine)
        if fmtname == "" then
            fmtname = resolvers.findfile(file.addsuffix(barename,"fmt")) or ""
        end
        fmtname = resolvers.cleanpath(fmtname)
        if fmtname == "" then
            report_format("no format with name: %s",name)
        else
            local barename = file.removesuffix(name) -- expanded name
            local luaname = file.addsuffix(barename,"luc")
            if not lfs.isfile(luaname) then
                luaname = file.addsuffix(barename,"lua")
            end
            if not lfs.isfile(luaname) then
                report_format("using format name: %s",fmtname)
                report_format("no luc/lua with name: %s",barename)
            else
                local command = format("%s %s --fmt=%s --lua=%s %s %s",engine,primaryflags(),quoted(barename),quoted(luaname),quoted(data),more ~= "" and quoted(more) or "")
                report_format("running command: %s",command)
                os.spawn(command)
            end
        end
    end
end
