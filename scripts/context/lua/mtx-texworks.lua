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
local texworkininame = "TeXworks.ini"

function scripts.texworks.start(indeed)
    local is_mswin = os.platform == "windows"
    local workname = (is_mswin and "texworks.exe") or "TeXworks"
    local fullname = nil
    local binpaths = file.split_path(os.getenv("PATH")) or file.split_path(os.getenv("path"))
    local datapath = resolvers.find_file(texworkssignal,"other text files") or ""
    if datapath ~= "" then
        datapath  = file.dirname(datapath) -- data
        if datapath == "" then
            datapath = resolvers.ownpath
        end
    else
        datapath = resolvers.find_file(texworkininame,"other text files") or ""
        if datapath == "" then
            datapath = resolvers.find_file(string.lower(texworkininame),"other text files") or ""
        end
        if datapath ~= "" and lfs.isfile(datapath) then
            datapath  = file.dirname(datapath) -- TUG
            datapath  = file.dirname(datapath) -- data
            if datapath == "" then
                datapath = resolvers.ownpath
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
        if lfs.isfile(p) then
            fullname = p
            break
        end
    end
    if not fullname then
        logs.simple("unable to locate %s",workname)
        return false
    end
    for _, subpath in ipairs(texworkspaths)  do
        dir.makedirs(file.join(datapath,subpath))
    end
    os.setenv("TW_INIPATH",datapath)
    os.setenv("TW_LIBPATH",datapath)
    if not indeed or environment.argument("verbose") then
        logs.simple("data path: %s", datapath)
        logs.simple("full name: %s", fullname)
    end
    if indeed then
        os.launch(fullname)
    end
end


logs.extendbanner("TeXworks startup script 1.0",true)

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
