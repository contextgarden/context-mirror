if not modules then modules = { } end modules ['mtx-metatex'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- future versions will deal with specific variants of metatex

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-metatex</entry>
  <entry name="detail">MetaTeX Process Management</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="run"><short>process (one or more) files (default action)</short></flag>
    <flag name="make"><short>create metatex format(s)</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-metatex",
    banner   = "MetaTeX Process Management 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.metatex = scripts.metatex or { }

-- metatex

function scripts.metatex.make()
    environment.make_format("metatex")
end

function scripts.metatex.run(ctxdata,filename)
    local filename = environment.files[1] or ""
    if filename ~= "" then
        local formatfile, scriptfile = resolvers.locateformat("metatex")
        if formatfile and scriptfile then
            local command = string.format("luatex --fmt=%s --lua=%s  %s",
                string.quote(formatfile), string.quote(scriptfile), string.quote(filename))
            report("running command: %s",command)
            os.spawn(command)
        elseif formatname then
            report("error, no format found with name: %s",formatname)
        else
            report("error, no format found (provide formatname or interface)")
        end
    end
end

function scripts.metatex.timed(action)
    statistics.timed(action)
end

if environment.argument("run") then
    scripts.metatex.timed(scripts.metatex.run)
elseif environment.argument("make") then
    scripts.metatex.timed(scripts.metatex.make)
elseif environment.argument("help") then
    logs.help(messages.help,false)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
elseif environment.files[1] then
    scripts.metatex.timed(scripts.metatex.run)
else
    application.help()
end
