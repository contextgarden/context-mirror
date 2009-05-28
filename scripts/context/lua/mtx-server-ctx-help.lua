if not modules then modules = { } end modules ['mtx-server-ctx-help'] = {
    version   = 1.001,
    comment   = "Basic Definition Browser",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ dofile(resolvers.find_file("l-xml.lua","tex"))
dofile(resolvers.find_file("l-aux.lua","tex"))
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
    interface = [[<a href='mtx-server-ctx-help.lua?interface=%s'>%s</a>]],
    href = [[<a href='mtx-server-ctx-help.lua?command=%s'>%s</a>]],
    source = [[<a href='mtx-server-ctx-help.lua?source=%s'>%s</a>]],
    optional_single = "[optional string %s]",
    optional_list = "[optional list %s]",
    mandate_single = "[mandate string %s]",
    mandate_list = "[mandate list %s]",
    parameter = [[<tr><td width='15%%'>%s</td><td width='15%%'>%s</td><td width='70%%'>%s</td></tr>]],
    parameters = [[<table width='100%%'>%s</table>]],
    listing = [[<pre><t>%s</t></listing>]],
    special = "<i>%s</i>",
    default = "<u>%s</u>",
}

local function translate(tag,int,noformat)
    local t = document.setups.translations
    local te = t["en"]
    local ti = t[int] or te
    if noformat then
        return ti[tag] or te[tag] or tag
    else
        return document.setups.formats.special:format(ti[tag] or te[tag] or tag)
    end
end

local function translated(e,int)
    local attributes = e.at
    local s = attributes.type or "?"
    local tag = s:match("^cd:(.*)$")
    if attributes.default == "yes" then
        return document.setups.formats.default:format(tag)
    elseif tag then
        return translate(tag,int)
    else
        return s
    end
end

document.setups.loaded = document.setups.loaded or { }

document.setups.current = { }
document.setups.showsources = false

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
    local at = ek.at
    if at.type == 'environment' then
        cs = translate("start",int,true) .. cs
    end
    for r, d, k in xml.elements(ek,'cd:sequence/(cd:string|variable)') do
        local dk = d[k]
        if dk.tg == "string" then
            cs = cs .. dk.at.value
        else
            cs = cs .. dk.at.value -- to be translated
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
        for r, d, k in xml.elements(current.root,'cd:command') do
            local dk = d[k]
            names[#names+1] = { dk.at.name, csname(dk,int) }
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
        xml.each_element(current.root,"cd:command", function(r,d,t)
            local ek = d[t]
            list[document.setups.name(ek)] = ek
        end )
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

function document.setups.collect(name,int)
    local current = document.setups.current
    local formats = document.setups.formats
    local command = xml.filter(current.root,format("cd:command[@name='%s']",name))
    if command then
        local attributes = command.at
        local data = {
            command = command,
            category = attributes.category or "",
        }
        if document.setups.showsources then
            data.source = (attributes.file and formats.source:format(attributes.file,attributes.file)) or ""
        else
            data.source = attributes.file or ""
        end
        local sequence, n = { "\\" .. document.setups.csname(command,int) }, 0
        local arguments = { }
        for r, d, k in xml.elements(command,"(cd:keywords|cd:assignments)") do
            n = n + 1
            local attributes = d[k].at
            if attributes.optional == 'yes' then
                if attributes.list == 'yes' then
                    sequence[#sequence+1] = formats.optional_list:format(n)
                else
                    sequence[#sequence+1] = formats.optional_single:format(n)
                end
            else
                if attributes.list == 'yes' then
                    sequence[#sequence+1] = formats.mandate_list:format(n)
                else
                    sequence[#sequence+1] = formats.mandate_single:format(n)
                end
            end
        end
        data.sequence = concat(sequence, " ")
        local parameters, n = { }, 0
        for r, d, k in xml.elements(command,"(cd:keywords|cd:assignments)") do
            n = n + 1
            if d[k].tg == "keywords" then
                local left = sequence[n+1]
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
                local what = sequence[n+1]
                for r, d, k in xml.elements(d[k],"(cd:parameter|cd:inherit)") do
                    local tag = d[k].tg
                    local left, right = d[k].at.name or "?", { }
                    if tag == "inherit" then
                        local name = d[k].at.name or "?"
                        local goto = document.setups.formats.href:format(name,"\\"..name)
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
        data.parameters = parameters
        return data
    else
        return nil
    end
end

-- -- --

tex = tex or { }

lmx.variables['color-background-green']      = '#4F6F6F'
lmx.variables['color-background-blue']       = '#6F6F8F'
lmx.variables['color-background-yellow']     = '#8F8F6F'
lmx.variables['color-background-purple']     = '#8F6F8F'

lmx.variables['color-background-body']       = '#808080'
lmx.variables['color-background-main']       = '#3F3F3F'
lmx.variables['color-background-main-left']  = '#3F3F3F'
lmx.variables['color-background-main-right'] = '#5F5F5F'
lmx.variables['color-background-one']        = lmx.variables['color-background-green']
lmx.variables['color-background-two']        = lmx.variables['color-background-blue']

lmx.variables['title-default']               = 'ConTeXt Help Information'
lmx.variables['title']                       = lmx.variables['title-default']

function lmx.loadedfile(filename)
    return io.loaddata(resolvers.find_file(filename)) -- return resolvers.texdatablob(filename)
end

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

local lastinterface, lastcommand, lastsource = "en", "", ""

local function doit(configuration,filename,hashed)

    local formats = document.setups.formats

    local start = os.clock()

    local detail = aux.settings_to_hash(hashed.query or "")

    lastinterface, lastcommand, lastsource = detail.interface or lastinterface, detail.command or lastcommand, detail.source or lastsource

    if lastinterface then
        logs.simple("checking interface: %s",lastinterface)
        document.setups.load(format("cont-%s.xml",lastinterface))
    end

    local div = document.setups.div[lastinterface]
    local span = document.setups.span[lastinterface]

    local result = { content = "error" }

    local names, refs, ints = document.setups.names(lastinterface), { }, { }
    for k,v in ipairs(names) do
        refs[k] = document.setups.formats.href:format(v[1],v[2])
    end
    for k,v in ipairs(table.sortedkeys(interfaces)) do
        ints[k] = document.setups.formats.interface:format(interfaces[v],v)
    end

    lmx.restore()
    lmx.set('title', 'ConTeXt Help Information')
    lmx.set('color-background-one', lmx.get('color-background-green'))
    lmx.set('color-background-two', lmx.get('color-background-blue'))

    local n = concat(refs,"<br/>")
    local i = concat(ints,"<br/><br/>")

    if div then
        lmx.set('names',div:format(n))
        lmx.set('interfaces',div:format(i))
    else
        lmx.set('names', n)
        lmx.set('interfaces', i)
    end

    -- first we need to add information about mkii/mkiv

    if document.setups.showsources and lastsource and lastsource ~= "" then
        -- todo: mkii, mkiv, tex (can be different)
        local data = io.loaddata(resolvers.find_file(lastsource))
        lmx.set('maintitle', lastsource)
        lmx.set('maintext', formats.listing:format(data))
        lastsource = ""
    elseif lastcommand and lastcommand ~= "" then
        local data = document.setups.collect(lastcommand,lastinterface)
        if data then
            lmx.set('maintitle', data.sequence)
            local extra = { }
            for k, v in ipairs { "environment", "category", "source" } do
                if data[v] and data[v] ~= "" then
                    lmx.set(v, data[v])
                    extra[#extra+1] = v .. ": " .. data[v]
                end
            end
            lmx.set('extra', concat(extra,", "))
            lmx.set('maintext', formats.parameters:format(concat(data.parameters)))
        else
            lmx.set('maintext', "select command")
        end
    else
        lmx.set('maintext', "no definition")
    end

    local content = lmx.convert('context-help.lmx')

    logs.simple("time spent on page: %0.03f seconds",os.clock()-start)

    return { content = content }
end

return doit, true
