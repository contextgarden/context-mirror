if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tonumber =  type, next, tonumber
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local utf = unicode.utf8
local byte, format = string.byte, string.format
local utfupper, utfchar = utf.upper, utf.char
local lpegmatch = lpeg.match

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>

<p>We do things different now but it's still somewhat experimental</p>
--ldx]]--

local trace_entities = false  trackers.register("xml.entities", function(v) trace_entities = v end)

local report_xml = logs.reporter("xml")

local xml = xml

xml.entities = xml.entities  or { }

storage.register("xml/entities", xml.entities, "xml.entities" )

local entities = xml.entities  -- maybe some day properties

function xml.registerentity(key,value)
    entities[key] = value
    if trace_entities then
        report_xml("registering entity '%s' as: %s",key,value)
    end
end

--~ entities.amp = function() tex.write("&") end
--~ entities.lt  = function() tex.write("<") end
--~ entities.gt  = function() tex.write(">") end

if characters and characters.entities then

    function characters.registerentities(forcecopy)
        if forcecopy then
            for name, value in next, characters.entities do
                if not entities[name] then
                    entities[name] = value
                end
            end
        else
            table.setmetatableindex(xml.entities,characters.entities)
        end
    end

end

local trace_entities = false  trackers.register("xml.entities", function(v) trace_entities = v end)

local report_xml = logs.reporter("xml")
