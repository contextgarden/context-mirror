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

local report_xml = logs.new("xml")

local xml = xml

xml.entities = xml.entities or { } -- xml.entity_handler == function

storage.register("xml/entities",xml.entities,"xml.entities") -- this will move to lxml

local entities = xml.entities -- this is a shared hash

xml.unknown_any_entity_format = nil -- has to be per xml

local parsedentity = xml.parsedentitylpeg

function xml.register_entity(key,value)
    entities[key] = value
    if trace_entities then
        report_xml("registering entity '%s' as: %s",key,value)
    end
end

function xml.resolved_entity(str)
    local e = entities[str]
    if e then
        local te = type(e)
        if te == "function" then
            e(str)
        elseif e then
            texsprint(ctxcatcodes,e)
        end
    else
        -- resolve hex and dec, todo: escape # & etc for ctxcatcodes
        -- normally this is already solved while loading the file
        local chr, err = lpegmatch(parsedentity,str)
        if chr then
            texsprint(ctxcatcodes,chr)
        elseif err then
            texsprint(ctxcatcodes,err)
        else
            texsprint(ctxcatcodes,"\\xmle{",str,"}{",utfupper(str),"}") -- we need to use our own upper
        end
    end
end

entities.amp = function() tex.write("&") end
entities.lt  = function() tex.write("<") end
entities.gt  = function() tex.write(">") end
