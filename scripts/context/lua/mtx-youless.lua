if not modules then modules = { } end modules ['mtx-youless'] = {
    version   = 1.002,
    comment   = "script tp fetch data from kwk meter polling device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- This script can fetch data from a youless device (http://www.youless.nl/) where data
-- is merged into a file. The data concerns energy consumption (current wattage as well
-- as kwh usage). There is an accompanying module to generate graphics.

require("util-you")

-- the script

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-youless</entry>
  <entry name="detail">youless Fetcher</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="collect"><short>collect data from device</short></flag>
    <flag name="nobackup"><short>don't backup old datafile</short></flag>
    <flag name="nofile"><short>don't write data to file (for checking)</short></flag>
    <flag name="kwh"><short>summative kwk data</short></flag>
    <flag name="watt"><short>collected watt data</short></flag>
    <flag name="host"><short>ip address of device</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script youless --collect --host=192.168.2.50 --kwk</command></example>
    <example><command>mtxrun --script youless --collect --host=192.168.2.50 --watt somefile.lua</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-youless",
    banner   = "youless Fetcher",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.youless = scripts.youless or { }

function scripts.youless.collect()
    local host     = environment.arguments.host
    local variant  = environment.arguments.kwh and "kwh" or environment.arguments.watt and "watt"
    local nobackup = environment.arguments.nobackup
    local nofile   = environment.arguments.nofile
    local filename = environment.files[1]
    if not variant then
        report("provide variant --kwh or --watt")
        return
    else
        report("using variant %a",variant)
    end
    if not host then
        host = "192.168.2.50"
        report("using default host %a",host)
    else
        report("using host %a",host)
    end
    if nobackup then
        report("not backing up data file")
    end
    if not filename and not nofile then
        filename = formatters["youless-%s.lua"](variant)
    end
    if filename ~= "" then
        report("using file %a",filename)
    end
    local data = utilities.youless.collect {
        filename = filename,
        host     = host,
        variant  = variant,
        nobackup = nobackup,
    }
    if type(data) ~= "table" then
        report("no data collected")
    elseif filename == "" then
        report("data collected but not saved")
    end
end

if environment.argument("collect") then
    scripts.youless.collect()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
