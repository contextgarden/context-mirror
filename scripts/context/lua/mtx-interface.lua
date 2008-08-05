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

local flushers = { }

function flushers.scite(interface,collection)
    local result, i = {}, 0
    result[#result+1] = format("keywordclass.macros.context.%s=",interface)
    for _, command in ipairs(collection) do
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
    for _, command in ipairs(collection) do
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
    for _, command in ipairs(collection) do
        result[#result+1]  = format("\t<string>\\%s</string>",command)
    end
    result[#result+1] = "</array>"
    io.savedata(format("context-bbedit-%s.xml",interface), table.concat(result),"\n")
end

function flushers.raw(interface,collection)
    for _, command in ipairs(collection) do
        input.report(command)
    end
end

function scripts.interface.editor(editor)
    local interfaces= environment.files
    if #interfaces == 0 then
        interfaces= { 'en','cs','de','it','nl','ro','fr' }
    end
    local xmlfile = input.find_file("cont-en.xml") or ""
    if xmlfile == "" then
        input.verbose = true
        input.report("unable to locate cont-en.xml")
    end
    for _, interface in ipairs(interfaces) do
        local keyfile = input.find_file(format("keys-%s.xml",interface)) or ""
        if keyfile == "" then
            input.verbose = true
            input.report("unable to locate keys-*.xml")
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
    local xmlfile = input.find_file("cont-en.xml") or ""
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

banner = banner .. " | interface tools "

messages.help = [[
--scite               generate scite interface
--bbedit              generate scite interface
--jedit               generate scite interface
--check               generate check file
]]

if environment.argument("scite") or environment.argument("bbedit") or environment.argument("jedit") then
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
    input.help(banner,messages.help)
end
