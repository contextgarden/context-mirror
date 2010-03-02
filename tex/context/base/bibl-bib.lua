if not modules then modules = { } end modules ['bibl-bib'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is a prelude to integrated bibliography support. This file just loads
bibtex files and converts them to xml so that the we access the content
in a convenient way. Actually handling the data takes place elsewhere.</p>
--ldx]]--

local lower, format, gsub = string.lower, string.format, string.gsub
local next = next
local lpegmatch = lpeg.match
local textoutf = characters.tex.toutf
local variables = interfaces.variables

local trace_bibxml = false  trackers.register("publications.bibxml", function(v) trace_bibtex = v end)

bibtex = bibtex or { }

bibtex.size        = 0
bibtex.definitions = 0
bibtex.shortcuts   = 0

local shortcuts = { }
local data      = { }
local entries

-- Currently we expand shortcuts and for large ones (like the acknowledgements
-- in tugboat.bib this is not that efficient. However, eventually stings get
-- hashed again.

local function do_shortcut(tag,key,value)
    bibtex.shortcuts = bibtex.shortcuts + 1
    if lower(tag) == "@string" then
        shortcuts[key] = value
    end
end

local function do_definition(tag,key,tab) -- maybe check entries here (saves memory)
    if not entries or entries[key] then
        bibtex.definitions = bibtex.definitions + 1
        local t = { }
        for i=1,#tab,2 do
            t[tab[i]] = tab[i+1]
        end
        local p = data[tag]
        if not p then
            data[tag] = { [key] = t }
        else
            p[key] = t
        end
    end
end

local function resolve(s)
    return shortcuts[s] or ""
end

local percent    = lpeg.P("%")
local start      = lpeg.P("@")
local comma      = lpeg.P(",")
local hash       = lpeg.P("#")
local escape     = lpeg.P("\\")
local single     = lpeg.P("'")
local double     = lpeg.P('"')
local left       = lpeg.P('{')
local right      = lpeg.P('}')
local both       = left + right
local lineending = lpeg.S("\n\r")
local space      = lpeg.S(" \t\n\r\f")
local spacing    = space^0
local equal      = lpeg.P("=")
local collapsed  = (space^1)/ " "

local function add(a,b) if b then return a..b else return a end end

local keyword    = lpeg.C((lpeg.R("az","AZ","09") + lpeg.S("@_:-"))^1)  -- lpeg.C((1-space)^1)
local s_quoted   = ((escape*single) + collapsed + (1-single))^0
local d_quoted   = ((escape*double) + collapsed + (1-double))^0
local balanced   = lpeg.P {
    [1] = ((escape * (left+right)) + (1 - (left+right)) + lpeg.V(2))^0,
    [2] = left * lpeg.V(1) * right
}

local s_value    = (single/"") * s_quoted * (single/"")
local d_value    = (double/"") * d_quoted * (double/"")
local b_value    = (left  /"") * balanced * (right /"")
local r_value    = keyword/resolve

local somevalue  = s_value + d_value + b_value + r_value
local value      = lpeg.Cs((somevalue * ((spacing * hash * spacing)/"" * somevalue)^0))

local assignment = spacing * keyword * spacing * equal * spacing * value * spacing
local shortcut   = keyword * spacing * left * spacing * (assignment * comma^0)^0 * spacing * right
local definition = keyword * spacing * left * spacing * keyword * comma * lpeg.Ct((assignment * comma^0)^0) * spacing * right
local comment    = keyword * spacing * left * (1-right)^0 * spacing * right
local forget     = percent^1 * (1-lineending)^0

-- todo \%

local grammar = (space + forget + shortcut/do_shortcut + definition/do_definition + comment + 1)^0

function bibtex.convert(session,content)
    statistics.starttiming(bibtex)
    data, shortcuts, entries = session.data, session.shortcuts, session.entries
 -- session.size = session.size + #content
    bibtex.size = bibtex.size + #content
    lpegmatch(grammar,content or "")
    statistics.stoptiming(bibtex)
end

function bibtex.load(session,filename)
    local filename = resolvers.find_file(filename,"bib")
    if filename ~= "" then
        local data = io.loaddata(filename) or ""
        if data == "" then
            logs.report("publications","empty file '%s', no conversion to xml",filename)
        elseif trace_bibxml then
            logs.report("publications","converting file '%s' to xml",filename)
        end
        bibtex.convert(session,data)
    end
end

function bibtex.new()
    return {
        data = { },
        shortcuts = { },
        xml = xml.convert("<?xml version='1.0' standalone='yes'?>\n<bibtex></bibtex>"),
        size = 0,
        entries = nil,
    }
end

local escaped_pattern = xml.escaped_pattern

local ihatethis = {
    f = "\\f",
    n = "\\n",
    r = "\\r",
    s = "\\s",
    t = "\\t",
    v = "\\v",
    z = "\\z",
}

function bibtex.toxml(session,options)
    -- we can always speed this up if needed
    -- format slows down things a bit but who cares
    statistics.starttiming(bibtex)
    local result = { }
    local options = aux.settings_to_array(options)
    local convert = options.convert -- todo: interface
    local entries = session.entries
    result[#result+1] = format("<?xml version='1.0' standalone='yes'?>")
    result[#result+1] = format("<bibtex>")
    for id, categories in next, session.data do
        id = lower(gsub(id,"^@",""))
        for name, entry in next, categories do
            if not entries or entries[name] then
                result[#result+1] = format("<entry tag='%s' category='%s'>",lower(name),id)
                for key, value in next, entry do
                    value = gsub(value,"\\(.)",ihatethis)
                    value = lpegmatch(escaped_pattern,value)
                    if value ~= "" then
                        if convert then
                            value = textoutf(value)
                        end
                        result[#result+1] = format(" <field name='%s'>%s</field>",key,value)
                    end
                end
                result[#result+1] = format("</eentry>")
            end
        end
    end
    result[#result+1] = format("</bibtex>")
    session.xml = xml.convert(table.concat(result,"\n"))
    statistics.stoptiming(bibtex)
end

statistics.register("bibtex load time", function()
    local size = bibtex.size
    if size > 0 then
        return format("%s seconds (%s bytes, %s definitions, %s shortcuts)",
            statistics.elapsedtime(bibtex),size,bibtex.definitions,bibtex.shortcuts)
    else
        return nil
    end
end)

--~ str = [[
--~     @COMMENT { CRAP }
--~     @STRING{ hans = "h a n s" }
--~     @STRING{ taco = "t a c o" }
--~     @SOMETHING{ key1, abc = "t a c o" , def = "h a n s" }
--~     @SOMETHING{ key2, abc = hans # taco }
--~     @SOMETHING{ key3, abc = "hans" # taco }
--~     @SOMETHING{ key4, abc = hans # "taco" }
--~     @SOMETHING{ key5, abc = hans # taco # "hans" # "taco"}
--~     @SOMETHING{ key6, abc =  {oeps {oeps} oeps} }
--~ ]]

--~ local session = bibtex.new()
--~ bibtex.convert(session,str)
--~ bibtex.toxml(session)
--~ print(session.size,statistics.elapsedtime(bibtex))

--~ local session = bibtex.new()
--~ bibtex.load(session,"IEEEabrv.bib")
--~ bibtex.load(session,"IEEEfull.bib")
--~ bibtex.load(session,"IEEEexample.bib")
--~ bibtex.toxml(session)
--~ print(session.size,statistics.elapsedtime(bibtex))

--~ local session = bibtex.new()
--~ bibtex.load(session,"gut.bib")
--~ bibtex.load(session,"komoedie.bib")
--~ bibtex.load(session,"texbook1.bib")
--~ bibtex.load(session,"texbook2.bib")
--~ bibtex.load(session,"texbook3.bib")
--~ bibtex.load(session,"texgraph.bib")
--~ bibtex.load(session,"texjourn.bib")
--~ bibtex.load(session,"texnique.bib")
--~ bibtex.load(session,"tugboat.bib")
--~ bibtex.toxml(session)
--~ print(session.size,statistics.elapsedtime(bibtex))

--~ print(table.serialize(session.data))
--~ print(table.serialize(session.shortcuts))
--~ print(xml.serialize(session.xml))

-- this will move:

if commands then

    local sessions = { }

    function commands.definebibtexsession(name)
        sessions[name] = bibtex.new()
    end
    function commands.preparebibtexsession(name,options)
        bibtex.toxml(sessions[name],options)
        lxml.register("bibtex:"..name,sessions[name].xml)
    end
    function commands.registerbibtexfile(name,filename)
        bibtex.load(sessions[name],filename)
    end
    function commands.registerbibtexentry(name,entry)
        local session = sessions[name]
        local entries = session.entries
        if not entries then
            session.entries = { [entry] = true }
        else
            entries[entry] = true
        end
    end

end
