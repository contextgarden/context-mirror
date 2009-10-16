if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next =  type, next
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local utfupper = utf.upper

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>

<p>We do things different now but it's still somewhat experimental</p>
--ldx]]--

xml.entities = xml.entities or { } -- xml.entity_handler == function

-- experimental, this will be done differently

function xml.merge_entities(root)
    local documententities = root.entities
    local allentities = xml.entities
    if documententities then
        for k, v in next, documententities do
            allentities[k] = v
        end
    end
end

function xml.resolved_entity(str)
    local e = xml.entities[str]
    if e then
        local te = type(e)
        if te == "function" then
            e(str)
        else
            texsprint(ctxcatcodes,e)
        end
    else
        texsprint(ctxcatcodes,"\\xmle{",str,"}{",utfupper(str),"}") -- we need to use our own upper
    end
end

xml.entities.amp = function() tex.write("&") end
xml.entities.lt  = function() tex.write("<") end
xml.entities.gt  = function() tex.write(">") end
