if not modules then modules = { } end modules ['mtx-server-ctx-help'] = {
    version   = 1.001,
    comment   = "Basic Definition Browser",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo in lua interface: noargument, oneargument, twoarguments, threearguments

dofile(resolvers.find_file("l-aux.lua","tex"))
dofile(resolvers.find_file("l-url.lua","tex"))
dofile(resolvers.find_file("trac-lmx.lua","tex"))

-- problem ... serialize parent stack

local format = string.format
local concat = table.concat

-- -- -- make this a module: cont-xx.lua

document = document or { }
document.setups = document.setups or { }

document.setups.div = {
    pe = "<div dir='rtl' lang='arabic'>%s</div>"
}

document.setups.span = {
    pe = "<span dir='rtl' lang='arabic'>%s</span>"
}

document.setups.translations =  document.setups.translations or {

    nl = {
        ["title"]       = "setup",
        ["formula"]     = "formule",
        ["number"]      = "getal",
        ["list"]        = "lijst",
        ["dimension"]   = "maat",
        ["mark"]        = "markering",
        ["reference"]   = "verwijzing",
        ["command"]     = "commando",
        ["file"]        = "file",
        ["name"]        = "naam",
        ["identifier"]  = "naam",
        ["text"]        = "tekst",
        ["section"]     = "sectie",
        ["singular"]    = "naam enkelvoud",
        ["plural"]      = "naam meervoud",
        ["matrix"]      = "n*m",
        ["see"]         = "zie",
        ["inherits"]    = "erft van",
        ["optional"]    = "optioneel",
        ["displaymath"] = "formule",
        ["index"]       = "ingang",
        ["math"]        = "formule",
        ["nothing"]     = "leeg",
        ["file"]        = "file",
        ["position"]    = "positie",
        ["reference"]   = "verwijzing",
        ["csname"]      = "naam",
        ["destination"] = "bestemming",
        ["triplet"]     = "triplet",
        ["word"]        = "woord",
        ["content"]     = "tekst",
    },

    en = {
        ["title"]       = "setup",
        ["formula"]     = "formula",
        ["number"]      = "number",
        ["list"]        = "list",
        ["dimension"]   = "dimension",
        ["mark"]        = "mark",
        ["reference"]   = "reference",
        ["command"]     = "command",
        ["file"]        = "file",
        ["name"]        = "name",
        ["identifier"]  = "identifier",
        ["text"]        = "text",
        ["section"]     = "section",
        ["singular"]    = "singular name",
        ["plural"]      = "plural name",
        ["matrix"]      = "n*m",
        ["see"]         = "see",
        ["inherits"]    = "inherits from",
        ["optional"]    = "optional",
        ["displaymath"] = "formula",
        ["index"]       = "entry",
        ["math"]        = "formula",
        ["nothing"]     = "empty",
        ["file"]        = "file",
        ["position"]    = "position",
        ["reference"]   = "reference",
        ["csname"]      = "name",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "word",
        ["content"]     = "text",

        ["noargument"]     = "\\cs",
        ["oneargument"]    = "\\cs#1{..}",
        ["twoarguments"]   = "\\cs#1#2{..}{..}",
        ["threearguments"] = "\\cs#1#2#3{..}{..}{..}",

    },

    de = {
        ["title"]       = "Setup",
        ["formula"]     = "Formel",
        ["number"]      = "Nummer",
        ["list"]        = "Liste",
        ["dimension"]   = "Dimension",
        ["mark"]        = "Beschriftung",
        ["reference"]   = "Referenz",
        ["command"]     = "Befehl",
        ["file"]        = "Datei",
        ["name"]        = "Name",
        ["identifier"]  = "Name",
        ["text"]        = "Text",
        ["section"]     = "Abschnitt",
        ["singular"]    = "singular",
        ["plural"]      = "plural",
        ["matrix"]      = "n*m",
        ["see"]         = "siehe",
        ["inherits"]    = "inherits from",
        ["optional"]    = "optioneel",
        ["displaymath"] = "formula",
        ["index"]       = "entry",
        ["math"]        = "formula",
        ["nothing"]     = "empty",
        ["file"]        = "file",
        ["position"]    = "position",
        ["reference"]   = "reference",
        ["csname"]      = "name",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "word",
        ["content"]     = "text",
    },

    cz = {
        ["title"]       = "setup",
        ["formula"]     = "rovnice",
        ["number"]      = "cislo",
        ["list"]        = "seznam",
        ["dimension"]   = "dimenze",
        ["mark"]        = "znacka",
        ["reference"]   = "reference",
        ["command"]     = "prikaz",
        ["file"]        = "soubor",
        ["name"]        = "jmeno",
        ["identifier"]  = "jmeno",
        ["text"]        = "text",
        ["section"]     = "sekce",
        ["singular"]    = "jmeno v singularu",
        ["plural"]      = "jmeno v pluralu",
        ["matrix"]      = "n*m",
        ["see"]         = "viz",
        ["inherits"]    = "inherits from",
        ["optional"]    = "optioneel",
        ["displaymath"] = "formula",
        ["index"]       = "entry",
        ["math"]        = "formula",
        ["nothing"]     = "empty",
        ["file"]        = "file",
        ["position"]    = "position",
        ["reference"]   = "reference",
        ["csname"]      = "name",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "word",
        ["content"]     = "text",
    },

    it = {
        ["title"]       = "setup",
        ["formula"]     = "formula",
        ["number"]      = "number",
        ["list"]        = "list",
        ["dimension"]   = "dimension",
        ["mark"]        = "mark",
        ["reference"]   = "reference",
        ["command"]     = "command",
        ["file"]        = "file",
        ["name"]        = "name",
        ["identifier"]  = "name",
        ["text"]        = "text",
        ["section"]     = "section",
        ["singular"]    = "singular name",
        ["plural"]      = "plural name",
        ["matrix"]      = "n*m",
        ["see"]         = "see",
        ["inherits"]    = "inherits from",
        ["optional"]    = "optioneel",
        ["displaymath"] = "formula",
        ["index"]       = "entry",
        ["math"]        = "formula",
        ["nothing"]     = "empty",
        ["file"]        = "file",
        ["position"]    = "position",
        ["reference"]   = "reference",
        ["csname"]      = "name",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "word",
        ["content"]     = "text",
    },

    ro = {
        ["title"]       = "setari",
        ["formula"]     = "formula",
        ["number"]      = "numar",
        ["list"]        = "lista",
        ["dimension"]   = "dimensiune",
        ["mark"]        = "marcaj",
        ["reference"]   = "referinta",
        ["command"]     = "comanda",
        ["file"]        = "fisier",
        ["name"]        = "nume",
        ["identifier"]  = "nume",
        ["text"]        = "text",
        ["section"]     = "sectiune",
        ["singular"]    = "nume singular",
        ["plural"]      = "nume pluram",
        ["matrix"]      = "n*m",
        ["see"]         = "vezi",
        ["inherits"]    = "inherits from",
        ["optional"]    = "optioneel",
        ["displaymath"] = "formula",
        ["index"]       = "entry",
        ["math"]        = "formula",
        ["nothing"]     = "empty",
        ["file"]        = "file",
        ["position"]    = "position",
        ["reference"]   = "reference",
        ["csname"]      = "name",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "word",
        ["content"]     = "text",
    },

    fr = {
        ["title"]       = "réglage",
        ["formula"]     = "formule",
        ["number"]      = "numéro",
        ["list"]        = "liste",
        ["dimension"]   = "dimension",
        ["mark"]        = "marquage",
        ["reference"]   = "reference",
        ["command"]     = "commande",
        ["file"]        = "fichier",
        ["name"]        = "nom",
        ["identifier"]  = "identificateur",
        ["text"]        = "texte",
        ["section"]     = "section",
        ["singular"]    = "nom singulier",
        ["plural"]      = "nom pluriel",
        ["matrix"]      = "n*m",
        ["see"]         = "vois",
        ["inherits"]    = "herite de",
        ["optional"]    = "optionel",
        ["displaymath"] = "formule",
        ["index"]       = "entrée",
        ["math"]        = "formule",
        ["nothing"]     = "vide",
        ["file"]        = "fichier",
        ["position"]    = "position",
        ["reference"]   = "réference",
        ["csname"]      = "nom",
        ["destination"] = "destination",
        ["triplet"]     = "triplet",
        ["word"]        = "mot",
        ["content"]     = "texte",
    }

}

document.setups.formats = {
    open_command    = { [[\%s]], [[context.%s (]] },
    close_command   = { [[]], [[ )]] },
    connector       = { [[]], [[, ]] },
    href_in_list    = { [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]], [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]] },
    href_as_command = { [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>\%s</a>]], [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>context.%s</a>]] },
    interface       = [[<a href='mtx-server-ctx-help.lua?interface=%s&mode=%s'>%s</a>]],
    source          = [[<a href='mtx-server-ctx-help.lua?source=%s&mode=%s'>%s</a>]],
    modes           = { [[<a href='mtx-server-ctx-help.lua?mode=2'>lua mode</a>]], [[<a href='mtx-server-ctx-help.lua?mode=1'>tex mode</a>]] },
    optional_single = { "[optional string %s]", "{optional string %s}" },
    optional_list   = { "[optional list %s]", "{optional table %s}" } ,
    mandate_single  = { "[mandate string %s]", "{mandate string %s}" },
    mandate_list    = { "[mandate list %s]", "{mandate list %s}" },
    parameter       = [[<tr><td width='15%%'>%s</td><td width='15%%'>%s</td><td width='70%%'>%s</td></tr>]],
    parameters      = [[<table width='100%%'>%s</table>]],
    listing         = [[<pre><t>%s</t></listing>]],
    special         = [[<i>%s</i>]],
    default         = [[<u>%s</u>]],
}

local function translate(tag,int,noformat)
    local t = document.setups.translations
    local te = t["en"]
    local ti = t[int] or te
    if noformat then
        return ti[tag] or te[tag] or tag
    else
        return format(document.setups.formats.special,ti[tag] or te[tag] or tag)
    end
end

local function translated(e,int)
    local attributes = e.at
    local s = attributes.type or "?"
    local tag = s:match("^cd:(.*)$")
    if attributes.default == "yes" then
        return format(document.setups.formats.default,tag or "?")
    elseif tag then
        return translate(tag,int)
    else
        return s
    end
end

document.setups.loaded = document.setups.loaded or { }

document.setups.current = { }
document.setups.showsources = true
document.setups.mode = 1

function document.setups.load(filename)
    filename = resolvers.find_file(filename) or ""
    if filename ~= "" then
        local current = document.setups.loaded[filename]
        if not current then
            local loaded = xml.load(filename)
            if loaded then
                -- xml.inject(document.setups.root,"/",loaded)
                current = {
                    file = filename,
                    root = loaded,
                    names = { },
                    used = { },
                }
                document.setups.loaded[filename] = current
            end
        end
        document.setups.current = current or { }
    end
end

function document.setups.name(ek)
    local at = ek.at
    local name = at.name
    if at.type == 'environment' then
        name = "start" .. name
    end
    if at.variant then
        name = name .. ":" .. at.variant
    end
    if at.generated == "yes" then
        name = name .. "*"
    end
    return name:lower()
end

function document.setups.csname(ek,int)
    local cs = ""
    local at = ek.at or { }
    if at.type == 'environment' then
        cs = translate("start",int,true) .. cs
    end
    for e in xml.collected(ek,'cd:sequence/(cd:string|variable)') do
        if e.tg == "string" then
            cs = cs .. e.at.value
        else
            cs = cs .. e.at.value -- to be translated
        end
    end
    return cs
end

function document.setups.names()
    local current = document.setups.current
    local names = current.names
    if not names or #names == 0 then
        names = { }
        local name = document.setups.name
        local csname = document.setups.csname
        for e in xml.collected(current.root,'cd:command') do
            names[#names+1] = { e.at.name, csname(e,int) }
        end
        table.sort(names, function(a,b) return a[2]:lower() < b[2]:lower() end)
        current.names = names
    end
    return names
end

function document.setups.show(name)
    local current = document.setups.current
    if current.root then
        local name = name:gsub("[<>]","")
        local setup = xml.first(current.root,"cd:command[@name='" .. name .. "']")
        current.used[#current.used+1] = setup
        xml.sprint(setup)
    end
end

function document.setups.showused()
    local current = document.setups.current
    if current.root and next(current.used) then
        for k,v in ipairs(table.sortedkeys(current.used)) do
            xml.sprint(current.used[v])
        end
    end
end
function document.setups.showall()
    local current = document.setups.current
    if current.root then
        local list = { }
        for e in xml.collected(current.root,"cd:command") do
            list[document.setups.name(e)] = e
        end
        for k,v in ipairs(table.sortedkeys(list)) do
            xml.sprint(list[v])
        end
    end
end
function document.setups.resolve(name)
    local current = document.setups.current
    if current.root then
        local e = xml.filter(current.root,format("cd:define[@name='%s']/text()",name))
        if e then
            xml.sprint(e)
        end
    end
end

function document.setups.collect(name,int,lastmode)
    local current = document.setups.current
    local formats = document.setups.formats
    local command = xml.filter(current.root,format("cd:command[@name='%s']/first()",name))
    if command then
        local attributes = command.at or { }
        local data = {
            command = command,
            category = attributes.category or "",
        }
        if document.setups.showsources then
            data.source = (attributes.file and formats.source:format(attributes.file,lastmode,attributes.file)) or ""
        else
            data.source = attributes.file or ""
        end
        local n, sequence, tags = 0, { }, { }
        sequence[#sequence+1] = formats.open_command[lastmode]:format(document.setups.csname(command,int))
        local arguments, tag = { }, ""
        for r, d, k in xml.elements(command,"(cd:keywords|cd:assignments)") do
            n = n + 1
            local attributes = d[k].at
            if #sequence > 1 then
                local c = formats.connector[lastmode]
                if c ~= "" then
                    sequence[#sequence+1] = c
                end
            end
            if attributes.optional == 'yes' then
                if attributes.list == 'yes' then
                    tag = formats.optional_list[lastmode]:format(n)
                else
                    tag = formats.optional_single[lastmode]:format(n)
                end
            else
                if attributes.list == 'yes' then
                    tag = formats.mandate_list[lastmode]:format(n)
                else
                    tag = formats.mandate_single[lastmode]:format(n)
                end
            end
            sequence[#sequence+1] = tag
            tags[#tags+1] = tag
        end
        sequence[#sequence+1] = formats.close_command[lastmode]
        data.sequence = concat(sequence, " ")
        local parameters, n = { }, 0
        for r, d, k in xml.elements(command,"(cd:keywords|cd:assignments)") do
            n = n + 1
            if d[k].tg == "keywords" then
                local left = tags[n]
                local right = { }
                for r, d, k in xml.elements(d[k],"(cd:constant|cd:resolve)") do
                    local tag = d[k].tg
                    if tag == "resolve" then
                        local name = d[k].at.name or ""
                        if name ~= "" then
                            local resolved = xml.filter(current.root,format("cd:define[@name='%s']",name))
                            for r, d, k in xml.elements(resolved,"cd:constant") do
                                right[#right+1] = translated(d[k],int)
                            end
                        end
                    else
                        right[#right+1] = translated(d[k],int)
                    end
                end
                parameters[#parameters+1] = formats.parameter:format(left,"",concat(right, ", "))
            else
                local what = tags[n]
                for r, d, k in xml.elements(d[k],"(cd:parameter|cd:inherit)") do
                    local tag = d[k].tg
                    local left, right = d[k].at.name or "?", { }
                    if tag == "inherit" then
                        local name = d[k].at.name or "?"
                        local goto = document.setups.formats.href_as_command[lastmode]:format(name,lastmode,name)
                        if #parameters > 0 and not parameters[#parameters]:find("<br/>") then
                            parameters[#parameters+1] = formats.parameter:format("<br/>","","")
                        end
                        parameters[#parameters+1] = formats.parameter:format(what,formats.special:format(translate("inherits",int)),goto)
                    else
                        for r, d, k in xml.elements(d[k],"(cd:constant|cd:resolve)") do
                            local tag = d[k].tg
                            if tag == "resolve" then
                                local name = d[k].at.name or ""
                                if name ~= "" then
                                    local resolved = xml.filter(current.root,format("cd:define[@name='%s']",name))
                                    for r, d, k in xml.elements(resolved,"cd:constant") do
                                        right[#right+1] = translated(d[k],int)
                                    end
                                end
                            else
                                right[#right+1] = translated(d[k],int)
                            end
                        end
                        parameters[#parameters+1] = formats.parameter:format(what,left,concat(right, ", "))
                    end
                    what = ""
                end
            end
            parameters[#parameters+1] = formats.parameter:format("<br/>","","")
        end
        data.parameters = parameters or { }
        data.mode = formats.modes[lastmode or 1]
        return data
    else
        return nil
    end
end

-- -- --

tex = tex or { }

-- -- --

local interfaces = {
    czech    = 'cz',
    dutch    = 'nl',
    english  = 'en',
    french   = 'fr',
    german   = 'de',
    italian  = 'it',
    persian  = 'pe',
    romanian = 'ro',
}

local lastinterface, lastcommand, lastsource, lastmode = "en", "", "", 1

local variables = {
    ['color-background-main-left']  = '#3F3F3F',
    ['color-background-main-right'] = '#5F5F5F',
    ['color-background-one']        = lmx.get('color-background-green'),
    ['color-background-two']        = lmx.get('color-background-blue'),
    ['title']                       = 'ConTeXt Help Information',
}

--~ function lmx.loadedfile(filename)
--~     return io.loaddata(resolvers.find_file(filename)) -- return resolvers.texdatablob(filename)
--~ end

local function doit(configuration,filename,hashed)

    local formats = document.setups.formats

    local start = os.clock()

    local detail = url.query(hashed.query or "")

    lastinterface = detail.interface or lastinterface
    lastcommand   = detail.command or lastcommand
    lastsource    = detail.source or lastsource
    lastmode      = tonumber(detail.mode or lastmode) or 1

    if lastinterface then
        logs.simple("checking interface: %s",lastinterface)
        document.setups.load(format("cont-%s.xml",lastinterface))
    end

    local div = document.setups.div[lastinterface]
    local span = document.setups.span[lastinterface]

    local result = { content = "error" }

    local names, refs, ints = document.setups.names(lastinterface), { }, { }
    for k,v in ipairs(names) do
        refs[k] = formats.href_in_list[lastmode]:format(v[1],lastmode,v[2])
    end
    if lastmode ~= 2 then
        for k,v in ipairs(table.sortedkeys(interfaces)) do
            ints[k] = formats.interface:format(interfaces[v],lastmode,v)
        end
    end

    local n = concat(refs,"<br/>")
    local i = concat(ints,"<br/><br/>")

    if div then
        variables.names      = div:format(n)
        variables.interfaces = div:format(i)
    else
        variables.names      = n
        variables.interfaces = i
    end

    -- first we need to add information about mkii/mkiv

    variables.maintitle = "no definition"
    variables.maintext  = ""
    variables.extra     = ""

    if document.setups.showsources and lastsource and lastsource ~= "" then
        -- todo: mkii, mkiv, tex (can be different)
        local data = io.loaddata(resolvers.find_file(lastsource))
        variables.maintitle = lastsource
        variables.maintext  = formats.listing:format(data)
        lastsource = ""
    elseif lastcommand and lastcommand ~= "" then
        local data = document.setups.collect(lastcommand,lastinterface,lastmode)
        if data then
            local extra = { }
            for k, v in ipairs { "environment", "category", "source", "mode" } do
                if data[v] and data[v] ~= "" then
                    lmx.set(v, data[v])
                    extra[#extra+1] = v .. ": " .. data[v]
                end
            end
            variables.maintitle = data.sequence
            variables.maintext  = formats.parameters:format(concat(data.parameters))
            variables.extra     = concat(extra,"&nbsp;&nbsp;&nbsp;")
        else
            variables.maintext = "select command"
        end
    end

    local content = lmx.convert('context-help.lmx',false,variables)

    logs.simple("time spent on page: %0.03f seconds",os.clock()-start)

    return { content = content }
end

return doit, true
