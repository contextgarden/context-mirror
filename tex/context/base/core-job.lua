if not modules then modules = { } end modules ['core-job'] = {
    version   = 1.001,
    comment   = "companion to core-job.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, texprint, texwrite = tex.sprint, tex.print, tex.write
local ctxcatcodes, texcatcodes = tex.ctxcatcodes, tex.texcatcodes
local lower, format, find, gmatch, gsub, match = string.lower, string.format, string.find, string.gmatch, string.gsub, string.match
local concat = table.concat

local commands, resolvers, context = commands, resolvers, context

-- main code

resolvers.maxreadlevel = 3

directives.register("resolvers.maxreadlevel", function(v) resolvers.maxreadlevel = tonumber(v) or resolvers.maxreadlevel end)

local report_examodes = logs.reporter("system","examodes") -- maybe another category

local function exists(n)
    if io.exists(n) then
        return n
    else
        n = file.addsuffix(n,'tex')
        if io.exists(n) then
            return n
        end
    end
    return nil
end

function resolvers.findctxfile(name,maxreadlevel)
    if file.is_qualified_path(name) then
        return name
    else
        -- not that efficient, too many ./ lookups
        local n = "./" .. name
        local found = exists(n)
        if found then
            return found
        else
            for i=1,maxreadlevel or resolvers.maxreadlevel or 0 do
                n = "../" .. n
                found = exists(n)
                if found then
                    return found
                end
            end
        end
        return resolvers.findfile(name) or ""
    end
end

function commands.maxreadlevel()
    texwrite(resolvers.maxreadlevel)
end

function commands.processfile(name,maxreadlevel)
    name = resolvers.findctxfile(name,maxreadlevel)
    if name ~= "" then
        texsprint(ctxcatcodes,format("\\input %s\\relax",name)) -- we need \input {name}
    end
end

function commands.doifinputfileelse(name,maxreadlevel)
    commands.doifelse(resolvers.findctxfile(name,maxreadlevel) ~= "")
end

function commands.locatefilepath(name,maxreadlevel)
    texsprint(texcatcodes,file.dirname(resolvers.findctxfile(name,maxreadlevel)))
end

function commands.usepath(paths,maxreadlevel)
    resolvers.registerextrapath(paths)
    texsprint(texcatcodes,concat(resolvers.instance.extra_paths or {}, ""))
end

function commands.usesubpath(subpaths,maxreadlevel)
    resolvers.registerextrapath(nil,subpaths)
    texsprint(texcatcodes,concat(resolvers.instance.extra_paths or {}, ""))
end

function commands.usezipfile(name,tree)
    if tree and tree ~= "" then
        resolvers.usezipfile(format("zip:///%s?tree=%s",name,tree))
    else
        resolvers.usezipfile(format("zip:///%s",name))
    end
end

-- for the moment here, maybe a module

--~ <?xml version='1.0' standalone='yes'?>
--~ <exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>
--~ 	<exa:variable label='mode:pragma'>nee</exa:variable>
--~ 	<exa:variable label='mode:variant'>standaard</exa:variable>
--~ </exa:variables>

local function convertexamodes(str)
    local x = xml.convert(str)
    for e in xml.collected(x,"exa:variable") do
        local label = e.at and e.at.label
        if label and label ~= "" then
            local data = xml.text(e)
            local mode = match(label,"^mode:(.+)$")
            if mode then
                context.enablemode { format("%s:%s",mode,data) }
            end
            context.setvariable("exa:variables",label,(gsub(data,"([{}])","\\%1")))
        end
    end
end

-- we need a system file option: ,. .. etc + paths but no tex lookup so resolvers.findfile is wrong here

function commands.loadexamodes(filename)
    if not filename or filename == "" then
        filename = file.removesuffix(tex.jobname)
    end
    filename = resolvers.findfile(file.addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        report_examodes("loading %s",filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        report_examodes("no mode file %s",filename) -- todo: message system
    end
end

local report_options = logs.reporter("system","options")

function commands.logoptionfile(name)
    -- todo: xml if xml logmode
    local f = io.open(name)
    if f then
        logs.pushtarget("logfile")
        report_options("begin of optionfile")
        report_options()
        for line in f:lines() do
            report_options(line)
        end
        report_options()
        report_options("end of optionfile")
        f:close()
        logs.poptarget()
    end
end

--~ set functions not ok and not faster on mk runs either
--~
--~ local function doifcommonelse(a,b)
--~     local ba = find(a,",")
--~     local bb = find(b,",")
--~     if ba and bb then
--~         for sa in gmatch(a,"[^ ,]+") do
--~             for sb in gmatch(b,"[^ ,]+") do
--~                 if sa == sb then
--~                     context.setvalue("commalistelement",sa)
--~                     return true
--~                 end
--~             end
--~         end
--~     elseif ba then
--~         for sa in gmatch(a,"[^ ,]+") do
--~             if sa == b then
--~                 context.setvalue("commalistelement",b)
--~                 return true
--~             end
--~         end
--~     elseif bb then
--~         for sb in gmatch(b,"[^ ,]+") do
--~             if a == sb then
--~                 context.setvalue("commalistelement",sb)
--~                 return true
--~             end
--~         end
--~     else
--~         if a == b then
--~             context.setvalue("commalistelement",a)
--~             return true
--~         end
--~     end
--~     context.letvalueempty("commalistelement")
--~     return false
--~ end
--~ local function doifinsetelse(a,b)
--~     local bb = find(b,",")
--~     if bb then
--~         for sb in gmatch(b,"[^ ,]+") do
--~             if a == sb then
--~                 texsprint(ctxcatcodes,"\\def\\commalistelement{",a,"}")
--~                 return true
--~             end
--~         end
--~     else
--~         if a == b then
--~             texsprint(ctxcatcodes,"\\def\\commalistelement{",a,"}")
--~             return true
--~         end
--~     end
--~     texsprint(ctxcatcodes,"\\let\\commalistelement\\empty")
--~     return false
--~ end
--~ function commands.doifcommon    (a,b) commands.doif    (doifcommonelse(a,b)) end
--~ function commands.doifnotcommon (a,b) commands.doifnot (doifcommonelse(a,b)) end
--~ function commands.doifcommonelse(a,b) commands.doifelse(doifcommonelse(a,b)) end
--~ function commands.doifinset     (a,b) commands.doif    (doifinsetelse(a,b)) end
--~ function commands.doifnotinset  (a,b) commands.doifnot (doifinsetelse(a,b)) end
--~ function commands.doifinsetelse (a,b) commands.doifelse(doifinsetelse(a,b)) end
