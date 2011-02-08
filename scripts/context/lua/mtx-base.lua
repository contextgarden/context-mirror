if not modules then modules = { } end modules ['mtx-base'] = {
    version   = 1.001,
    comment   = "formerly known as luatools",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
--generate        generate file database
--variables       show configuration variables
--configurations  show configuration order
--expand-braces   expand complex variable
--expand-path     expand variable (resolve paths)
--expand-var      expand variable (resolve references)
--show-path       show path expansion of ...
--var-value       report value of variable
--find-file       report file location
--find-path       report path of file
--make or --ini   make luatex format
--run or --fmt=   run luatex format
--compile         assemble and compile lua inifile
--verbose         give a bit more info
--all             show all found files
--format=str      filter cf format specification (default 'tex', use 'any' for any match)
--pattern=str     filter variables
--trackers=list   enable given trackers
]]

local application = logs.application {
    name     = "mtx-base",
    banner   = "ConTeXt TDS Management Tool 1.35 (aka luatools)",
    helpinfo = helpinfo,
}

local report = application.report

-- private option --noluc for testing errors in the stub

local instance   = resolvers.instance

local pattern    = environment.arguments["pattern"]  or nil
local fileformat = environment.arguments["format"]   or "" -- nil ?
local allresults = environment.arguments["all"]      or false
local trace      = environment.arguments["trace"]

if type(pattern) == 'boolean' then
    report("invalid pattern specification")
    pattern = nil
end

if trace then
    resolvers.settrace(trace)  -- move to mtxrun ?
end

if environment.arguments["find-file"] then
    resolvers.load()
    if pattern then
        resolvers.dowithfilesandreport(resolvers.findfiles, { pattern }, fileformat, allresults)
    else
        resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, fileformat, allresults)
    end
elseif environment.arguments["find-path"] then
    resolvers.load()
    local path = resolvers.findpath(environment.files[1], fileformat)
    print(path) -- quite basic, wil become function in logs
elseif environment.arguments["run"] then
    resolvers.load("nofiles") -- ! no need for loading databases
    trackers.enable("resolvers.locating")
    environment.run_format(environment.files[1] or "",environment.files[2] or "",environment.files[3] or "")
elseif environment.arguments["fmt"] then
    resolvers.load("nofiles") -- ! no need for loading databases
    trackers.enable("resolvers.locating")
    environment.run_format(environment.arguments["fmt"], environment.files[1] or "",environment.files[2] or "")
elseif environment.arguments["expand-braces"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expandbraces, environment.files)
elseif environment.arguments["expand-path"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expandpath, environment.files)
elseif environment.arguments["expand-var"] or environment.arguments["expand-variable"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expansion, environment.files)
elseif environment.arguments["show-path"] or environment.arguments["path-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.showpath, environment.files)
elseif environment.arguments["var-value"] or environment.arguments["show-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.variable, environment.files)
elseif environment.arguments["format-path"] then
    resolvers.load()
    report(caches.getwritablepath("format"))
elseif pattern then -- brrr
    resolvers.load()
    resolvers.dowithfilesandreport(resolvers.findfiles, { pattern }, fileformat, allresults)
elseif environment.arguments["generate"] then
    instance.renewcache = true
    trackers.enable("resolvers.locating")
    resolvers.load()
elseif environment.arguments["make"] or environment.arguments["ini"] or environment.arguments["compile"] then
    resolvers.load()
    trackers.enable("resolvers.locating")
    environment.make_format(environment.files[1] or "")
elseif environment.arguments["variables"] or environment.arguments["show-variables"] or environment.arguments["expansions"] or environment.arguments["show-expansions"] then
    resolvers.load("nofiles")
    resolvers.listers.variables(pattern)
elseif environment.arguments["configurations"] or environment.arguments["show-configurations"] then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
elseif environment.arguments["help"] or (environment.files[1]=='help') or (#environment.files==0) then
    application.help()
elseif environment.files[1] == 'texmfcnf.lua' then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
else
    resolvers.load()
    resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, fileformat, allresults)
end
