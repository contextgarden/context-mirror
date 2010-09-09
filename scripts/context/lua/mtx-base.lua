if not modules then modules = { } end modules ['mtx-base'] = {
    version   = 1.001,
    comment   = "formerly known as luatools",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

logs.extendbanner("ConTeXt TDS Management Tool 1.35 (aka luatools)")

-- private option --noluc for testing errors in the stub

local instance = resolvers.instance

instance.engine     =     environment.arguments["engine"]   or instance.engine   or 'luatex'
instance.progname   =     environment.arguments["progname"] or instance.progname or 'context'
instance.luaname    =     environment.arguments["luafile"]  or ""
instance.lualibs    =     environment.arguments["lualibs"]  or nil
instance.allresults =     environment.arguments["all"]      or false
instance.pattern    =     environment.arguments["pattern"]  or nil
instance.sortdata   =     environment.arguments["sort"]     or false
instance.my_format  =     environment.arguments["format"]   or instance.format

if type(instance.pattern) == 'boolean' then
    logs.simple("invalid pattern specification")
    instance.pattern = nil
end

if environment.arguments["trace"] then
    resolvers.settrace(environment.arguments["trace"])  -- move to mtxrun ?
end

runners  = runners  or { }
messages = messages or { }

messages.no_ini_file = [[
There is no lua initialization file found. This file can be forced by the
"--progname" directive, or specified with "--luaname", or it is derived
automatically from the formatname (aka jobname). It may be that you have
to regenerate the file database using "mtxrun --generate".
]]

messages.help = [[
--generate        generate file database
--variables       show configuration variables
--expansions      show expanded variables
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
--luafile=str     lua inifile (default is <progname>.lua)
--lualibs=list    libraries to assemble (optional when --compile)
--compile         assemble and compile lua inifile
--verbose         give a bit more info
--all             show all found files
--sort            sort cached data
--format=str      filter cf format specification (default 'tex', use 'any' for any match)
--engine=str      target engine
--progname=str    format or backend
--pattern=str     filter variables
--trackers=list   enable given trackers
]]

if environment.arguments["find-file"] then
    resolvers.load()
    instance.format  = environment.arguments["format"] or instance.format
    if instance.pattern then
        instance.allresults = true
        resolvers.dowithfilesandreport(resolvers.findfiles, { instance.pattern }, instance.my_format)
    else
        resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, instance.my_format)
    end
elseif environment.arguments["find-path"] then
    resolvers.load()
    local path = resolvers.findpath(environment.files[1], instance.my_format)
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
    resolvers.dowithfilesandreport(resolvers.expandvar, environment.files)
elseif environment.arguments["show-path"] or environment.arguments["path-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.showpath, environment.files)
elseif environment.arguments["var-value"] or environment.arguments["show-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.var_value, environment.files)
elseif environment.arguments["format-path"] then
    resolvers.load()
    logs.simple(caches.getwritablepath("format"))
elseif instance.pattern then -- brrr
    resolvers.load()
    instance.format = environment.arguments["format"] or instance.format
    instance.allresults = true
    resolvers.dowithfilesandreport(resolvers.findfiles, { instance.pattern }, instance.my_format)
elseif environment.arguments["generate"] then
    instance.renewcache = true
    trackers.enable("resolvers.locating")
    resolvers.load()
elseif environment.arguments["make"] or environment.arguments["ini"] or environment.arguments["compile"] then
    resolvers.load()
    trackers.enable("resolvers.locating")
    environment.make_format(environment.files[1] or "")
elseif environment.arguments["variables"] or environment.arguments["show-variables"] then
    resolvers.load("nofiles")
    resolvers.listers.variables(false,instance.pattern)
elseif environment.arguments["expansions"] or environment.arguments["show-expansions"] then
    resolvers.load("nofiles")
    resolvers.listers.expansions(false,instance.pattern)
elseif environment.arguments["configurations"] or environment.arguments["show-configurations"] then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
elseif environment.arguments["help"] or (environment.files[1]=='help') or (#environment.files==0) then
    logs.help(messages.help)
elseif environment.files[1] == 'texmfcnf.lua' then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
else
    resolvers.load()
    resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, instance.my_format)
end
