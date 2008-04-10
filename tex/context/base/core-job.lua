if not modules then modules = { } end modules ['core-job'] = {
    version   = 1.001,
    comment   = "companion to core-job.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- will move

commands.writestatus = ctx.writestatus

function commands.doifelse(b)
    tex.sprint(tex.texcatcodes,(b and "\\firstoftwoarguments") or "\\secondoftwoarguments")
end
function commands.doif(b)
    tex.sprint(tex.texcatcodes,(b and "\\firstofoneargument") or "\\gobbleoneargument")
end
function commands.doifnot(b)
    tex.sprint(tex.texcatcodes,(b and "\\gobbleoneargument") or "\\firstofoneargument")
end
cs.testcase = commands.doifelse

local format = string.format

function commands. def(cs,value) tex.sprint(tex.ctxcatcodes,format( "\\def\\%s{%s}",cs,value)) end
function commands.edef(cs,value) tex.sprint(tex.ctxcatcodes,format("\\edef\\%s{%s}",cs,value)) end
function commands.gdef(cs,value) tex.sprint(tex.ctxcatcodes,format("\\gdef\\%s{%s}",cs,value)) end
function commands.xdef(cs,value) tex.sprint(tex.ctxcatcodes,format("\\xdef\\%s{%s}",cs,value)) end

function commands.cs(cs,args) tex.sprint(tex.ctxcatcodes,format("\\csname %s\\endcsname %s",cs,args or"")) end

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
        return input.find_file(texmf.instance,name) or ""
    end
end

function commands.processfile(name,maxreadlevel)
    name = find_file(name,maxreadlevel)
    if name ~= "" then
    --  tex.sprint(tex.ctxcatcodes,string.format("\\input %s\\relax",name))
        tex.print(tex.ctxcatcodes,string.format("\\input %s",name))
    end
end

function commands.doifinputfileelse(name,maxreadlevel)
    commands.doifelse(find_file(name,maxreadlevel) ~= "")
end

function commands.locatefilepath(name,maxreadlevel)
    tex.sprint(tex.texcatcodes,file.dirname(find_file(name,maxreadlevel)))
end

function commands.usepath(paths,maxreadlevel)
    input.register_extra_path(texmf.instance,paths)
    tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
end

function commands.usesubpath(subpaths,maxreadlevel)
    input.register_extra_path(texmf.instance,nil,subpaths)
    tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
end

function commands.usezipfile(name,tree)
    if tree and tree ~= "" then
        input.usezipfile(texmf.instance,string.format("zip:///%s?tree=%s",name,tree))
    else
        input.usezipfile(texmf.instance,string.format("zip:///%s",name))
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
                tex.sprint(tex.ctxcatcodes,string.format("\\enablemode[%s:%s]",mode,data))
            end
            if data:find("{}") then
                t[#t+1] = string.format("%s={%s}",mode,data)
            else
                t[#t+1] = string.format("%s=%s",mode,data)
            end
        end
    end
    if #t > 0 then
        tex.sprint(tex.ctxcatcodes,string.format("\\setvariables[exa:variables][%s]",table.concat(t,",")))
    end
end

-- we need a system file option: ,. .. etc + paths but no tex lookup so input.find_file is wrong here

function commands.loadexamodes(filename)
    if not filename or filename == "" then
        filename = file.stripsuffix(tex.jobname)
    end
    filename = input.find_file(texmf.instance,file.addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        commands.writestatus("examodes","loading " .. filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        commands.writestatus("examodes","no mode file " .. filename) -- todo: message system
    end
end
