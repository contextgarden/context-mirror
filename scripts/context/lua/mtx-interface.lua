if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, sort, insert = table.concat, table.sort, table.insert
local gsub, format, gmatch = string.gsub, string.format, string.gmatch

scripts           = scripts           or { }
scripts.interface = scripts.interface or { }

local flushers          = { }
local userinterfaces    = { 'en','cs','de','it','nl','ro','fr','pe' }
local messageinterfaces = { 'en','cs','de','it','nl','ro','fr','pe','no' }

function flushers.scite(interface,commands)
    local result, i = {}, 0
    result[#result+1] = format("keywordclass.macros.context.%s=",interface)
    for i=1,#commands do
        local command = commands[i]
        if i==0 then
            result[#result+1] = "\\\n"
            i = 5
        else
            i = i - 1
        end
        result[#result+1] = format("%s ",command)
    end
    io.savedata(format("cont-%s-scite.properties",interface), concat(result),"\n")
    io.savedata(format("cont-%s-scite.lua",interface), table.serialize(commands,true))
end

function flushers.jedit(interface,commands)
    local result = {}
    result[#result+1] = "<?xml version='1.0'?>"
    result[#result+1] = "<!DOCTYPE MODE SYSTEM 'xmode.dtd'>\n"
    result[#result+1] = "<MODE>"
    result[#result+1] = "\t<RULES>"
    result[#result+1] = "\t\t<KEYWORDS>"
    for i=1,#commands do
        result[#result+1] = format("\t\t\t<KEYWORD2>%s</KEYWORD2>",commands[i])
    end
    result[#result+1] = "\t\t</KEYWORDS>"
    result[#result+1] = "\t</RULES>"
    result[#result+1] = "</MODE>"
    io.savedata(format("context-jedit-%s.xml",interface), concat(result),"\n")
end

function flushers.bbedit(interface,commands)
    local result = {}
    result[#result+1] = "<?xml version='1.0'?>"
    result[#result+1] = "<key>BBLMKeywordList</key>"
    result[#result+1] = "<array>"
    for i=1,#commands do
        result[#result+1]  = format("\t<string>\\%s</string>",commands[i])
    end
    result[#result+1] = "</array>"
    io.savedata(format("context-bbedit-%s.xml",interface), concat(result),"\n")
end

function flushers.raw(interface,commands)
    for i=1,#commands do
        logs.simple(commands[i])
    end
end

local textpadcreator = "mtx-interface-textpad.lua"

function flushers.text(interface,commands,environments)
    local c, cname = { }, format("context-commands-%s.txt",interface)
    local e, ename = { }, format("context-environments-%s.txt",interface)
    logs.simple("saving '%s'",cname)
    for i=1,#commands do
        c[#c+1] = format("\\%s",commands[i])
    end
    io.savedata(cname,concat(c,"\n"))
    logs.simple("saving '%s'",ename)
    for i=1,#environments do
        e[#e+1] = format("\\start%s",environments[i])
        e[#e+1] = format("\\stop%s", environments[i])
    end
    io.savedata(format("context-environments-%s.txt",interface),concat(e,"\n"))
end

function flushers.textpad(interface,commands,environments)
    flushers.text(interface,commands,environments)
    --
    -- plugin, this is a rewrite of a file provided by Lukas Prochazka
    --
    local function merge(templatedata,destinationdata,categories)
        logs.simple("loading '%s'",templatedata)
        local data = io.loaddata(templatedata)
        local done = 0
        for i=1,#categories do
            local category = categories[i]
            local cpattern = ";%s*category:%s*(" .. category .. ")%s*[\n\r]+"
            local fpattern = ";%s*filename:%s*(" .. "%S+"     .. ")%s*[\n\r]+"
            data = gsub(data,cpattern..fpattern,function(category,filename)
                local found = resolvers.findfile(filename) or ""
                local blob = found ~= "" and io.loaddata(found) or ""
                if blob == ""  then
                    logs.simple("category: %s, filename: %s, not found",category,filename)
                else
                    done = done + 1
                    logs.simple("category: %s, filename: %s, merged",category,filename)
                end
                return format("; category: %s\n; filename: %s\n%s\n\n",category,filename,blob)
            end)
        end
        if done > 0 then
            logs.simple("saving '%s' (%s files merged)",destinationdata,done)
            io.savedata(destinationdata,data)
        else
            logs.simple("skipping '%s' (no files merged)",destinationdata)
        end
    end
    local templatename = "textpad-context-template.txt"
    local templatedata = resolvers.findfile(templatename) or ""
    if templatedata == "" then
        logs.simple("unable to locate template '%s'",templatename)
    else
        merge(templatedata, "context.syn",       { "tex commands","context commands" })
        if environment.argument("textpad") == "latex" then
            merge(templatedata, "context-latex.syn", { "tex commands","context commands", "latex commands" })
        end
    end
    local r = { }
    local c = io.loaddata("context-commands-en.txt")     or "" -- sits on the same path
    local e = io.loaddata("context-environments-en.txt") or "" -- sits on the same path
    for s in gmatch(c,"\\(.-)%s") do
        r[#r+1] = format("\n!TEXT=%s\n\\%s\n!",s,s)
    end
    for s in gmatch(e,"\\start(.-)%s+\\stop(.-)") do
        r[#r+1] = format("\n!TEXT=%s (start/stop)\n\\start%s \\^\\stop%s\n!",s,s,s)
    end
    sort(r)
    insert(r,1,"!TCL=597,\n!TITLE=ConTeXt\n!SORT=N\n!CHARSET=DEFAULT")
    io.savedata("context.tcl",concat(r,"\n"))
    -- cleanup
    os.remove("context-commands-en.txt")
    os.remove("context-environments-en.txt")
end

function scripts.interface.editor(editor,split,forcedinterfaces)
    local interfaces= forcedinterfaces or environment.files
    if #interfaces == 0 then
        interfaces= userinterfaces
    end
    local xmlfile = resolvers.findfile("cont-en.xml") or ""
    if xmlfile == "" then
        logs.simple("unable to locate cont-en.xml")
    end
    for i=1,#interfaces do
        local interface = interfaces[i]
        local keyfile = resolvers.findfile(format("keys-%s.xml",interface)) or ""
        if keyfile == "" then
            logs.simple("unable to locate keys-*.xml")
        else
            local commands     = { }
            local mappings     = { }
            local environments = { }
            local x = xml.load(keyfile)
            for e, d, k in xml.elements(x,"cd:command") do
                local at = d[k].at
                local name, value = at.name, at.value
                if name and value then
                    mappings[name] = value
                end
            end
            local x = xml.load(xmlfile)
            for e, d, k in xml.elements(x,"cd:command") do
                local at = d[k].at
                local name, type = at.name, at["type"]
                if name and name ~= "" then
                    local remapped = mappings[name] or name
                    if type == "environment" then
                        if split then
                            environments[#environments+1] = remapped
                        else
                            commands[#commands+1] = "start" .. remapped
                            commands[#commands+1] = "stop"  .. remapped
                        end
                    else
                        commands[#commands+1] = remapped
                    end
                end
            end
            if #commands > 0 then
                sort(commands)
                sort(environments)
                flushers[editor](interface,commands,environments)
            end
        end
    end
end

function scripts.interface.check()
    local xmlfile = resolvers.findfile("cont-en.xml") or ""
    if xmlfile ~= "" then
        local f = io.open("cont-en-check.tex","w")
        if f then
            f:write("\\starttext\n")
            local x = xml.load(xmlfile)
            for e, d, k in xml.elements(x,"cd:command") do
                local dk = d[k]
                local at = dk.at
                if at then
                    local name = xml.filter(dk,"cd:sequence/cd:string/attribute(value)")
                    if name and name ~= "" then
                        if at.type == "environment" then
                            name = "start" .. name
                        end
                        f:write(format("\\doifundefined{%s}{\\writestatus{check}{command '%s' is undefined}}\n",name,name))
                    end
                end
            end
            f:write("\\stoptext\n")
            f:close()
        end
    end
end

function scripts.interface.context()
    local filename = resolvers.findfile(environment.files[1] or "mult-def.lua") or ""
    if filename ~= "" then
        local interface = dofile(filename)
        if interface and next(interface) then
            local variables, constants, commands, elements = interface.variables, interface.constants, interface.commands, interface.elements
            local filename = resolvers.findfile("cont-en.xml") or ""
            local xmldata = filename ~= "" and (io.loaddata(filename) or "")
            local function flush(texresult,xmlresult,language,what,tag)
                local t = interface[what]
                texresult[#texresult+1] = format("%% definitions for interface %s for language %s\n%%",what,language)
                xmlresult[#xmlresult+1] = format("\t<!-- definitions for interface %s for language %s -->\n",what,language)
                xmlresult[#xmlresult+1] = format("\t<cd:%s>",what)
                local sorted = table.sortedkeys(t)
                for i=1,#sorted do
                    local key = sorted[i]
                    local v = t[key]
                    local value = v[language] or v["en"]
                    if not value then
                        logs.simple("warning, no value for key '%s' for language '%s'",key,language)
                    else
                        local value = t[key][language] or t[key].en
                        texresult[#texresult+1] = format("\\setinterface%s{%s}{%s}",tag,key,value)
                        xmlresult[#xmlresult+1] = format("\t\t<cd:%s name='%s' value='%s'/>",tag,key,value)
                    end
                end
                xmlresult[#xmlresult+1] = format("\t</cd:%s>\n",tag)
            end
            local function replace(str, element, attribute, category, othercategory, language)
                return str:gsub(format("(<%s[^>]-%s=)([\"\'])([^\"\']-)([\"\'])",element,attribute), function(a,b,c)
                    local cc = category[c]
                    if not cc and othercategory then
                        cc = othercategory[c]
                    end
                    if cc then
                        ccl = cc[language]
                        if ccl then
                            return a .. b .. ccl .. b
                        end
                    end
                    return a .. b .. c .. b
                end)
            end
            for language, _ in next, commands.setuplayout do
                local texresult, xmlresult = { }, { }
                texresult[#texresult+1] = format("%% this file is auto-generated, don't edit this file\n%%")
                xmlresult[#xmlresult+1] = format("<?xml version='1.0'?>\n",tag)
                xmlresult[#xmlresult+1] = format("<cd:interface xmlns:cd='http://www.pragma-ade.com/commands' name='context' language='%s' version='2008.10.21 19:42'>\n",language)
                flush(texresult,xmlresult,language,"variables","variable")
                flush(texresult,xmlresult,language,"constants","constant")
                flush(texresult,xmlresult,language,"elements", "element")
                flush(texresult,xmlresult,language,"commands", "command")
                texresult[#texresult+1] = format("%%\n\\endinput")
                xmlresult[#xmlresult+1] = format("</cd:interface>")
                local texfilename = format("mult-%s.tex",language)
                local xmlfilename = format("keys-%s.xml",language)
                io.savedata(texfilename,concat(texresult,"\n"))
                logs.simple("saving interface definitions '%s'",texfilename)
                io.savedata(xmlfilename,concat(xmlresult,"\n"))
                logs.simple("saving interface translations '%s'",xmlfilename)
                if language ~= "en" and xmldata ~= "" then
                    local newdata = xmldata:gsub("(<cd:interface.*language=.)en(.)","%1"..language.."%2",1)
                    newdata = replace(newdata, 'cd:string', 'value', interface.commands, interface.elements, language)
                    newdata = replace(newdata, 'cd:variable' , 'value', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:parameter', 'name', interface.constants, nil, language)
                    newdata = replace(newdata, 'cd:constant', 'type', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:variable', 'type', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:inherit', 'name', interface.commands, interface.elements, language)
                    local xmlfilename = format("cont-%s.xml",language)
                    io.savedata(xmlfilename,newdata)
                    logs.simple("saving interface specification '%s'",xmlfilename)
                end
            end
        end
    end
end

function scripts.interface.messages()
    local filename = resolvers.findfile(environment.files[1] or "mult-mes.lua") or ""
    if filename ~= "" then
        local messages = dofile(filename)
        logs.simple("messages for * loaded from '%s'",filename)
        logs.simple()
        for i=1,#messageinterfaces do
            local interface = messageinterfaces[i]
            local texresult = { }
            for category, data in next, messages do
                for tag, message in next, data do
                    if tag ~= "files" then
                        local msg = message[interface] or message["all"] or message["en"]
                        if msg then
                            texresult[#texresult+1] = format("\\setinterfacemessage{%s}{%s}{%s}",category,tag,msg)
                        end
                    end
                end
            end
            texresult[#texresult+1] = format("%%\n\\endinput")
            local interfacefile = format("mult-m%s.tex",interface)
            io.savedata(interfacefile,concat(texresult,"\n"))
            logs.simple("messages for '%s' saved in '%s'",interface,interfacefile)
        end
    end
end

logs.extendbanner("ConTeXt Interface Related Goodies 0.12")

messages.help = [[
--scite               generate scite interface
--bbedit              generate bbedit interface files
--jedit               generate jedit interface files
--textpad             generate textpad interface files
--text                create text files for commands and environments
--raw                 report commands to the console
--check               generate check file
--context             generate context definition files
--messages            generate context message files
]]

local ea = environment.argument

if ea("context") then
    scripts.interface.context()
elseif ea("messages") then
    scripts.interface.messages()
elseif ea("scite") or ea("bbedit") or ea("jedit") or ea("textpad") or ea("text") or ea("raw") then
    if ea("scite") then
        scripts.interface.editor("scite")
    end
    if ea("bbedit") then
        scripts.interface.editor("bbedit")
    end
    if ea("jedit") then
        scripts.interface.editor("jedit")
    end
    if ea("textpad") then
        scripts.interface.editor("textpad",true, { "en" })
    end
    if ea("text") then
        scripts.interface.editor("text")
    end
    if ea("raw") then
        scripts.interface.editor("raw")
    end
elseif ea("check") then
    scripts.interface.check()
else
    logs.help(messages.help)
end
