if not modules then modules = { } end modules ['mtx-texworks'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts          = scripts          or { }
scripts.texworks = scripts.texworks or { }

local texworkspaths = {
    "completion",
    "configuration",
    "dictionaries",
    "translations",
    "scripts",
    "templates",
    "TUG"
}

local texworkssignal = "texworks-context.rme"
local texworkininame = "texworks.ini"

function scripts.texworks.start(indeed)
    local workname = (os.type == "windows" and "texworks.exe") or "texworks"
    local fullname = nil
    local binpaths = file.split_path(os.getenv("PATH")) or file.split_path(os.getenv("path"))
    local usedsignal = texworkssignal
    local datapath = resolvers.find_file(usedsignal,"other text files") or ""
    if datapath ~= "" then
        datapath  = file.dirname(datapath) -- data
        if datapath == "" then
            datapath = resolvers.clean_path(lfs.currentdir())
        end
    else
        usedsignal = texworkininame
        datapath = resolvers.find_file(usedsignal,"other text files") or ""
        if datapath == "" then
            usedsignal = string.lower(usedsignal)
            datapath = resolvers.find_file(usedsignal,"other text files") or ""
        end
        if datapath ~= "" and lfs.isfile(datapath) then
            datapath  = file.dirname(datapath) -- TUG
            datapath  = file.dirname(datapath) -- data
            if datapath == "" then
                datapath = resolvers.clean_path(lfs.currentdir())
            end
        end
    end
    if datapath == "" then
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
    for i=1,#texworkspaths do
        dir.makedirs(file.join(datapath,texworkspaths[i]))
    end
    os.setenv("TW_INIPATH",datapath)
    os.setenv("TW_LIBPATH",datapath)
    if not indeed or environment.argument("verbose") then
        logs.simple("used signal: %s", usedsignal)
        logs.simple("data path  : %s", datapath)
        logs.simple("full name  : %s", fullname)
        logs.simple("set paths  : TW_INIPATH TW_LIBPATH")
    end
    if indeed then
        os.launch(fullname)
    end
end

logs.extendbanner("TeXworks Startup Script 1.00",true)

messages.help = [[
--start [--verbose]   start texworks
--test                report what will happen
]]

if environment.argument("start") then
    scripts.texworks.start(true)
elseif environment.argument("test") then
    scripts.texworks.start()
else
    logs.help(messages.help)
end
