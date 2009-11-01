if not modules then modules = { } end modules ['core-job'] = {
    version   = 1.001,
    comment   = "companion to core-job.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, texprint, format, find, gmatch = tex.sprint, tex.print, string.format, string.find, string.gmatch

local ctxcatcodes = tex.ctxcatcodes
local texcatcodes = tex.texcatcodes

-- main code

function resolvers.findctxfile(name,maxreadlevel)
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
    if file.is_qualified_path(name) then
        return name
    else
        -- not that efficient, too many ./ lookups
        local n = "./" .. name
        local found = exists(n)
        if found then
            return found
        else
            for i=1,maxreadlevel or 0 do
                n = "../" .. n
                found = exists(n)
                if found then
                    return found
                end
            end
        end
        return resolvers.find_file(name) or ""
    end
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
    resolvers.register_extra_path(paths)
    texsprint(texcatcodes,table.concat(resolvers.instance.extra_paths or {}, ""))
end

function commands.usesubpath(subpaths,maxreadlevel)
    resolvers.register_extra_path(nil,subpaths)
    texsprint(texcatcodes,table.concat(resolvers.instance.extra_paths or {}, ""))
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
            local mode = label:match("^mode:(.+)$")
            if mode then
                texsprint(ctxcatcodes,format("\\enablemode[%s:%s]",mode,data))
            end
            texsprint(ctxcatcodes,format("\\setvariable{exa:variables}{%s}{%s}",label,data:gsub("([{}])","\\%1")))
        end
    end
end

-- we need a system file option: ,. .. etc + paths but no tex lookup so resolvers.find_file is wrong here

function commands.loadexamodes(filename)
    if not filename or filename == "" then
        filename = file.removesuffix(tex.jobname)
    end
    filename = resolvers.find_file(file.addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        commands.writestatus("examodes","loading %s",filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        commands.writestatus("examodes","no mode file %s",filename) -- todo: message system
    end
end

function commands.logoptionfile(name)
    -- todo: xml if xml logmode
    local f = io.open(name)
    if f then
        texio.write_nl("log","%\n%\tbegin of optionfile\n%\n")
        for line in f:lines() do
            texio.write("log",format("%%\t%s\n",line))
        end
        texio.write("log","%\n%\tend of optionfile\n%\n")
        f:close()
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
--~                     texsprint(ctxcatcodes,"\\def\\commalistelement{",sa,"}")
--~                     return true
--~                 end
--~             end
--~         end
--~     elseif ba then
--~         for sa in gmatch(a,"[^ ,]+") do
--~             if sa == b then
--~                 texsprint(ctxcatcodes,"\\def\\commalistelement{",b,"}")
--~                 return true
--~             end
--~         end
--~     elseif bb then
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
