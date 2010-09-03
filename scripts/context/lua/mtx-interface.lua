if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

scripts           = scripts           or { }
scripts.interface = scripts.interface or { }

local flushers          = { }
local userinterfaces    = { 'en','cs','de','it','nl','ro','fr','pe' }
local messageinterfaces = { 'en','cs','de','it','nl','ro','fr','pe','no' }

function flushers.scite(interface,collection)
    local result, i = {}, 0
    result[#result+1] = format("keywordclass.macros.context.%s=",interface)
    for i=1,#collection do
        local command = collection[i]
        if i==0 then
            result[#result+1] = "\\\n"
            i = 5
        else
            i = i - 1
        end
        result[#result+1] = format("%s ",command)
    end
    io.savedata(format("cont-%s-scite.properties",interface), table.concat(result),"\n")
    io.savedata(format("cont-%s-scite.lua",interface), table.serialize(collection,true))
end

function flushers.jedit(interface,collection)
    local result = {}
    result[#result+1] = "<?xml version='1.0'?>"
    result[#result+1] = "<!DOCTYPE MODE SYSTEM 'xmode.dtd'>\n"
    result[#result+1] = "<MODE>"
    result[#result+1] = "\t<RULES>"
    result[#result+1] = "\t\t<KEYWORDS>"
    for i=1,#collection do
        local command = collection[i]
        result[#result+1] = format("\t\t\t<KEYWORD2>%s</KEYWORD2>",command)
    end
    result[#result+1] = "\t\t</KEYWORDS>"
    result[#result+1] = "\t</RULES>"
    result[#result+1] = "</MODE>"
    io.savedata(format("context-jedit-%s.xml",interface), table.concat(result),"\n")
end

function flushers.bbedit(interface,collection)
    local result = {}
    result[#result+1] = "<?xml version='1.0'?>"
    result[#result+1] = "<key>BBLMKeywordList</key>"
    result[#result+1] = "<array>"
    for i=1,#collection do
        local command = collection[i]
        result[#result+1]  = format("\t<string>\\%s</string>",command)
    end
    result[#result+1] = "</array>"
    io.savedata(format("context-bbedit-%s.xml",interface), table.concat(result),"\n")
end

function flushers.raw(interface,collection)
    for i=1,#collection do
        local command = collection[i]
        logs.simple(command)
    end
end

function scripts.interface.editor(editor)
    local interfaces= environment.files
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
            local collection = { }
            local mappings   = { }
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
                        collection[#collection+1] = "start" .. remapped
                        collection[#collection+1] = "stop" .. remapped
                    else
                        collection[#collection+1] = remapped
                    end
                end
            end
            if #collection > 0 then
                table.sort(collection)
                flushers[editor](interface,collection)
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
                io.savedata(texfilename,table.concat(texresult,"\n"))
                logs.simple("saving interface definitions '%s'",texfilename)
                io.savedata(xmlfilename,table.concat(xmlresult,"\n"))
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
            io.savedata(interfacefile,table.concat(texresult,"\n"))
            logs.simple("messages for '%s' saved in '%s'",interface,interfacefile)
        end
    end
end

logs.extendbanner("ConTeXt Interface Related Goodies 0.11")

messages.help = [[
--scite               generate scite interface
--bbedit              generate scite interface
--jedit               generate scite interface
--check               generate check file
--context             generate context definition files
--messages            generate context message files
]]

if environment.argument("context") then
    scripts.interface.context()
elseif environment.argument("messages") then
    scripts.interface.messages()
elseif environment.argument("scite") or environment.argument("bbedit") or environment.argument("jedit") then
    if environment.argument("scite") then
        scripts.interface.editor("scite")
    end
    if environment.argument("bbedit") then
        scripts.interface.editor("bbedit")
    end
    if environment.argument("jedit") then
        scripts.interface.editor("jedit")
    end
elseif environment.argument("check") then
    scripts.interface.check()
else
    logs.help(messages.help)
end
