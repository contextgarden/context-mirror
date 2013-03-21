if not modules then modules = { } end modules ['mtx-texworks'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-texworks</entry>
  <entry name="detail">TeXworks Startup Script</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="start"><short>[<ref name="verbose]"/>   start texworks</short></flag>
    <flag name="test"><short>report what will happen</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-texworks",
    banner   = "TeXworks Startup Script 1.00",
    helpinfo = helpinfo,
}

local report = application.report

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
    local binpaths = file.splitpath(os.getenv("PATH")) or file.splitpath(os.getenv("path"))
    local usedsignal = texworkssignal
    local datapath = resolvers.findfile(usedsignal,"other text files") or ""
    if datapath ~= "" then
        datapath  = file.dirname(datapath) -- data
        if datapath == "" then
            datapath = resolvers.cleanpath(lfs.currentdir())
        end
    else
        usedsignal = texworkininame
        datapath = resolvers.findfile(usedsignal,"other text files") or ""
        if datapath == "" then
            usedsignal = string.lower(usedsignal)
            datapath = resolvers.findfile(usedsignal,"other text files") or ""
        end
        if datapath ~= "" and lfs.isfile(datapath) then
            datapath  = file.dirname(datapath) -- TUG
            datapath  = file.dirname(datapath) -- data
            if datapath == "" then
                datapath = resolvers.cleanpath(lfs.currentdir())
            end
        end
    end
    if datapath == "" then
        report("invalid datapath, maybe you need to regenerate the file database")
        return false
    end
    if not binpaths or #binpaths == 0 then
        report("invalid binpath")
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
        report("unable to locate %s",workname)
        return false
    end
    for i=1,#texworkspaths do
        dir.makedirs(file.join(datapath,texworkspaths[i]))
    end
    os.setenv("TW_INIPATH",datapath)
    os.setenv("TW_LIBPATH",datapath)
    if not indeed or environment.argument("verbose") then
        report("used signal: %s", usedsignal)
        report("data path  : %s", datapath)
        report("full name  : %s", fullname)
        report("set paths  : TW_INIPATH TW_LIBPATH")
    end
    if indeed then
        os.launch(fullname)
    end
end

if environment.argument("start") then
    scripts.texworks.start(true)
elseif environment.argument("test") then
    scripts.texworks.start()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
