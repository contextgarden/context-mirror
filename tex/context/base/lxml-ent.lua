if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, gsub, find = string.format, string.gsub, string.find
local utfchar = unicode.utf8.char

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>
--ldx]]--

xml.entities = xml.entities or { } -- xml.entity_handler == function

function xml.entity_handler(e)
    return format("[%s]",e)
end

local function toutf(s)
    return utfchar(tonumber(s,16))
end

local function utfize(root)
    local d = root.dt
    for k=1,#d do
        local dk = d[k]
        if type(dk) == "string" then
        --  test prevents copying if no match
            if find(dk,"&#x.-;") then
                d[k] = gsub(dk,"&#x(.-);",toutf)
            end
        else
            utfize(dk)
        end
    end
end

xml.utfize = utfize

local function resolve(e) -- hex encoded always first, just to avoid mkii fallbacks
    if find(e,"^#x") then
        return utfchar(tonumber(e:sub(3),16))
    elseif find(e,"^#") then
        return utfchar(tonumber(e:sub(2)))
    else
        local ee = xml.entities[e] -- we cannot shortcut this one (is reloaded)
        if ee then
            return ee
        else
            local h = xml.entity_handler
            return (h and h(e)) or "&" .. e .. ";"
        end
    end
end

local function resolve_entities(root)
    if not root.special or root.tg == "@rt@" then
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
                if find(dk,"&.-;") then
                    d[k] = gsub(dk,"&(.-);",resolve)
                end
            else
                resolve_entities(dk)
            end
        end
    end
end

xml.resolve_entities = resolve_entities

function xml.utfize_text(str)
    if find(str,"&#") then
        return (gsub(str,"&#x(.-);",toutf))
    else
        return str
    end
end

function xml.resolve_text_entities(str) -- maybe an lpeg. maybe resolve inline
    if find(str,"&") then
        return (gsub(str,"&(.-);",resolve))
    else
        return str
    end
end

function xml.show_text_entities(str)
    if find(str,"&") then
        return (gsub(str,"&(.-);","[%1]"))
    else
        return str
    end
end

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
