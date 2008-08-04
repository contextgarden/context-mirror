if not modules then modules = { } end modules ['core-job'] = {
    version   = 1.001,
    comment   = "companion to core-job.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- will move

local texsprint, texprint, format = tex.sprint, tex.print, string.format

commands.writestatus = ctx.writestatus

function commands.doifelse(b)
    if b then -- faster with if than with expression
        texsprint(tex.texcatcodes,"\\firstoftwoarguments")
    else
        texsprint(tex.texcatcodes,"\\secondoftwoarguments")
    end
end
function commands.doif(b)
    if b then
        texsprint(tex.texcatcodes,"\\firstofoneargument")
    else
        texsprint(tex.texcatcodes,"\\gobbleoneargument")
    end
end
function commands.doifnot(b)
    if b then
        texsprint(tex.texcatcodes,"\\gobbleoneargument")
    else
        texsprint(tex.texcatcodes,"\\firstofoneargument")
    end
end
cs.testcase = commands.doifelse

function commands.doifelsespaces(str)
    return commands.doifelse(str:find("^ +$"))
end

function commands. def(cs,value) texsprint(tex.ctxcatcodes,format( "\\def\\%s{%s}",cs,value)) end
function commands.edef(cs,value) texsprint(tex.ctxcatcodes,format("\\edef\\%s{%s}",cs,value)) end
function commands.gdef(cs,value) texsprint(tex.ctxcatcodes,format("\\gdef\\%s{%s}",cs,value)) end
function commands.xdef(cs,value) texsprint(tex.ctxcatcodes,format("\\xdef\\%s{%s}",cs,value)) end

function commands.cs(cs,args) texsprint(tex.ctxcatcodes,format("\\csname %s\\endcsname %s",cs,args or"")) end

-- main code

local function find_file(name,maxreadlevel)
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
    if input.aux.qualified_path(name) then
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
        return input.find_file(name) or ""
    end
end

function commands.processfile(name,maxreadlevel)
    name = find_file(name,maxreadlevel)
    if name ~= "" then
--~         texsprint(tex.ctxcatcodes,format('\\input {%s}',name)) -- future version
        texsprint(tex.ctxcatcodes,format("\\input %s\\relax",name)) -- we need \input {name}
    end
end

function commands.doifinputfileelse(name,maxreadlevel)
    commands.doifelse(find_file(name,maxreadlevel) ~= "")
end

function commands.locatefilepath(name,maxreadlevel)
    texsprint(tex.texcatcodes,file.dirname(find_file(name,maxreadlevel)))
end

function commands.usepath(paths,maxreadlevel)
    input.register_extra_path(paths)
    texsprint(tex.texcatcodes,table.concat(input.instance.extra_paths or {}, ""))
end

function commands.usesubpath(subpaths,maxreadlevel)
    input.register_extra_path(nil,subpaths)
    texsprint(tex.texcatcodes,table.concat(input.instance.extra_paths or {}, ""))
end

function commands.usezipfile(name,tree)
    if tree and tree ~= "" then
        input.usezipfile(format("zip:///%s?tree=%s",name,tree))
    else
        input.usezipfile(format("zip:///%s",name))
    end
end

-- for the moment here, maybe a module

--~ <?xml version='1.0' standalone='yes'?>
--~ <exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>
--~ 	<exa:variable label='mode:pragma'>nee</exa:variable>
--~ 	<exa:variable label='mode:variant'>standaard</exa:variable>
--~ </exa:variables>

local function convertexamodes(str)
    local x, t = xml.convert(str), { }
    for e, d, k in xml.elements(x,"exa:variable") do
        local dk = d[k]
        local label = dk.at and dk.at.label
        if label and label ~= "" then
            local data = xml.content(dk)
            local mode = label:match("^mode:(.+)$")
            if mode then
                texsprint(tex.ctxcatcodes,format("\\enablemode[%s:%s]",mode,data))
            end
            if data:find("{}") then
                t[#t+1] = format("%s={%s}",mode,data)
            else
                t[#t+1] = format("%s=%s",mode,data)
            end
        end
    end
    if #t > 0 then
        texsprint(tex.ctxcatcodes,format("\\setvariables[exa:variables][%s]",table.concat(t,",")))
    end
end

-- we need a system file option: ,. .. etc + paths but no tex lookup so input.find_file is wrong here

function commands.loadexamodes(filename)
    if not filename or filename == "" then
        filename = file.stripsuffix(tex.jobname)
    end
    filename = input.find_file(file.addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        commands.writestatus("examodes","loading %s",filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        commands.writestatus("examodes","no mode file %s",filename) -- todo: message system
    end
end

--~ set functions not ok and not faster on mk runs either
--~
--~ local function doifcommonelse(a,b)
--~     local ba = a:find(",")
--~     local bb = b:find(",")
--~     if ba and bb then
--~         for sa in a:gmatch("[^ ,]+") do
--~             for sb in b:gmatch("[^ ,]+") do
--~                 if sa == sb then
--~                     texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..sa.."}")
--~                     return true
--~                 end
--~             end
--~         end
--~     elseif ba then
--~         for sa in a:gmatch("[^ ,]+") do
--~             if sa == b then
--~                 texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..b.."}")
--~                 return true
--~             end
--~         end
--~     elseif bb then
--~         for sb in b:gmatch("[^ ,]+") do
--~             if a == sb then
--~                 texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..a.."}")
--~                 return true
--~             end
--~         end
--~     else
--~         if a == b then
--~             texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..a.."}")
--~             return true
--~         end
--~     end
--~     texsprint(tex.ctxcatcodes,"\\let\\commalistelement\\empty")
--~     return false
--~ end
--~ local function doifinsetelse(a,b)
--~     local bb = b:find(",")
--~     if bb then
--~         for sb in b:gmatch("[^ ,]+") do
--~             if a == sb then
--~                 texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..a.."}")
--~                 return true
--~             end
--~         end
--~     else
--~         if a == b then
--~             texsprint(tex.ctxcatcodes,"\\def\\commalistelement{"..a.."}")
--~             return true
--~         end
--~     end
--~     texsprint(tex.ctxcatcodes,"\\let\\commalistelement\\empty")
--~     return false
--~ end
--~ function commands.doifcommon    (a,b) commands.doif    (doifcommonelse(a,b)) end
--~ function commands.doifnotcommon (a,b) commands.doifnot (doifcommonelse(a,b)) end
--~ function commands.doifcommonelse(a,b) commands.doifelse(doifcommonelse(a,b)) end
--~ function commands.doifinset     (a,b) commands.doif    (doifinsetelse(a,b)) end
--~ function commands.doifnotinset  (a,b) commands.doifnot (doifinsetelse(a,b)) end
--~ function commands.doifinsetelse (a,b) commands.doifelse(doifinsetelse(a,b)) end

