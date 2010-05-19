if not modules then modules = { } end modules ['mtx-scite'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: append to global properties else order of loading problem
-- linux problem ... files are under root protection so we need --install

scripts       = scripts       or { }
scripts.scite = scripts.scite or { }

local scitesignals = { "scite-context.rme", "context.properties" }
local screenfont   = "lmtypewriter10-regular.ttf"

function scripts.scite.start(indeed)
    local usedsignal, datapath, fullname, workname, userpath, fontpath
    if os.type == "windows" then
        workname = "scite.exe"
        userpath = os.getenv("USERPROFILE") or ""
        fontpath = os.getenv("SYSTEMROOT")
        fontpath = (fontpath and file.join(fontpath,"fonts")) or ""
    else
        workname = "scite"
        userpath = os.getenv("HOME") or ""
        fontpath = ""
    end
    local binpaths = file.split_path(os.getenv("PATH")) or file.split_path(os.getenv("path"))
    for i=1,#scitesignals do
        local scitesignal = scitesignals[i]
        local scitepath = resolvers.find_file(scitesignal,"other text files") or ""
        if scitepath ~= "" then
            scitepath  = file.dirname(scitepath) -- data
            if scitepath == "" then
                scitepath = resolvers.clean_path(lfs.currentdir())
            else
                usedsignal, datapath = scitesignal, scitepath
                break
            end
        end
    end
    if not datapath or datapath == "" then
        logs.simple("invalid datapath, maybe you need to regenerate the file database")
        return false
    end
    if not binpaths or #binpaths == 0 then
        logs.simple("invalid binpath")
        return false
    end
    for i=1,#binpaths do
        local p = file.join(binpaths[i],workname)
        if lfs.isfile(p) and lfs.attributes(p,"size") > 10000 then -- avoind stub
            fullname = p
            break
        end
    end
    if not fullname then
        logs.simple("unable to locate %s",workname)
        return false
    end
    local properties  = dir.glob(file.join(datapath,"*.properties"))
    local luafiles    = dir.glob(file.join(datapath,"*.lua"))
    local extrafont   = resolvers.find_file(screenfont,"truetype font") or ""
    local pragmafound = dir.glob(file.join(datapath,"pragma.properties"))
    if userpath == "" then
        logs.simple("unable to figure out userpath")
        return false
    end
    local verbose = environment.argument("verbose")
    local tobecopied, logdata = { }, { }
    local function check_state(fullname,newpath)
        local basename = file.basename(fullname)
        local destination = file.join(newpath,basename)
        local pa, da = lfs.attributes(fullname), lfs.attributes(destination)
        if not da then
            logdata[#logdata+1] = { "new        : %s", basename }
            tobecopied[#tobecopied+1] = { fullname, destination }
        elseif pa.modification > da.modification then
            logdata[#logdata+1] = { "outdated   : %s", basename }
            tobecopied[#tobecopied+1] = { fullname, destination }
        else
            logdata[#logdata+1] = { "up to date : %s", basename }
        end
    end
    for i=1,#properties do
        check_state(properties[i],userpath)
    end
    for i=1,#luafiles do
        check_state(luafiles[i],userpath)
    end
    if fontpath ~= "" then
        check_state(extrafont,fontpath)
    end
    local userpropfile = "SciTEUser.properties"
    if os.name ~= "windows" then
        userpropfile = "."  .. userpropfile
    end
    local fullpropfile = file.join(userpath,userpropfile)
    local userpropdata = io.loaddata(fullpropfile) or ""
    local propfiledone = false
    if pragmafound then
        if userpropdata == "" then
            logdata[#logdata+1] = { "error      : no user properties found on '%s'", fullpropfile }
        elseif string.find(userpropdata,"import *pragma") then
            logdata[#logdata+1] = { "up to date : 'import pragma' in '%s'", userpropfile }
        else
            logdata[#logdata+1] = { "yet unset  : 'import pragma' in '%s'", userpropfile }
            userproperties = userpropdata .. "\n\nimport pragma\n\n"
            propfiledone = true
        end
    else
        if string.find(userpropdata,"import *context") then
            logdata[#logdata+1] = { "up to date : 'import context' in '%s'", userpropfile }
        else
            logdata[#logdata+1] = { "yet unset  : 'import context' in '%s'", userpropfile }
            userproperties = userpropdata .. "\n\nimport context\n\n"
            propfiledone = true
        end
    end
    if not indeed or verbose then
        logs.simple("used signal: %s", usedsignal)
        logs.simple("data path  : %s", datapath)
        logs.simple("full name  : %s", fullname)
        logs.simple("user path  : %s", userpath)
        logs.simple("extra font : %s", extrafont)
    end
    if #logdata > 0 then
        logs.simple("")
        for k=1,#logdata do
            local v = logdata[k]
            logs.simple(v[1],v[2])
        end
    end
    if indeed then
        if #tobecopied > 0 then
            logs.simple("warning    : copying updated files")
            for i=1,#tobecopied do
                local what = tobecopied[i]
                logs.simple("copying    : '%s' => '%s'",what[1],what[2])
                file.copy(what[1],what[2])
            end
        end
        if propfiledone then
            logs.simple("saving     : '%s'",userpropfile)
            io.savedata(fullpropfile,userpropdata)
        end
        os.launch(fullname)
    end
end

logs.extendbanner("Scite Startup Script 1.00",true)

messages.help = [[
--start [--verbose]   start scite
--test                report what will happen
]]

if environment.argument("start") then
    scripts.scite.start(true)
elseif environment.argument("test") then
    scripts.scite.start()
else
    logs.help(messages.help)
end
