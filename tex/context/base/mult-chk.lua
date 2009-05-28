if not modules then modules = { } end modules ['mult-chk'] = {
    version   = 1.001,
    comment   = "companion to mult-chk.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local type = type
local texsprint = tex.sprint
local ctxcatcodes = tex.ctxcatcodes

interfaces = interfaces or { }

interfaces.syntax = {
    test = { keys = table.tohash { "a","b","c","d","e","f","g" } }
}

function interfaces.invalidkey(kind,key)
    commands.writestatus("syntax","invalid key '%s' for '%s' in line %s",key,kind,tex.inputlineno)
end

function interfaces.setvalidkeys(kind,list)
    local s = interfaces.syntax[kind]
    if not s then
        interfaces.syntax[kind] = {
            keys = aux.settings_to_set(list)
        }
    else
        s.keys = aux.settings_to_set(list)
    end
end

function interfaces.addvalidkeys(kind,list)
    local s = interfaces.syntax[kind]
    if not s then
        interfaces.syntax[kind] = {
            keys = aux.settings_to_set(list)
        }
    else
        aux.settings_to_set(list,s.keys)
    end
end

local prefix, kind, keys

local function set(key,value)
    if keys and not keys[key] then
        interfaces.invalidkey(kind,key)
    else
        texsprint(ctxcatcodes,format("\\setsomevalue{%s}{%s}{%s}",prefix,key,value))
    end
end

local pattern = aux.make_settings_to_hash_pattern(set,true)

function commands.getcheckedparameters(k,p,s)
    if s and s ~= "" then
        prefix, kind = p, k
        keys = k and k ~= "" and interfaces.syntax[k].keys
        pattern:match(s)
    end
end

_gcp_ = commands.getcheckedparameters
