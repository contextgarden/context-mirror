if not modules then modules = { } end modules ['mult-chk'] = {
    version   = 1.001,
    comment   = "companion to mult-chk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local lpegmatch = lpeg.match
local type = type
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local make_settings_to_hash_pattern, settings_to_set = utilities.parsers.make_settings_to_hash_pattern, utilities.parsers.settings_to_set

local allocate = utilities.storage.allocate

local report_interface = logs.reporter("interface","checking")

interfaces = interfaces or { }

interfaces.syntax = allocate {
    test = { keys = table.tohash { "a","b","c","d","e","f","g" } }
}

function interfaces.invalidkey(category,key)
    report_interface("invalid key '%s' for '%s' in line %s",key,category,tex.inputlineno)
end

function interfaces.setvalidkeys(category,list)
    local s = interfaces.syntax[category]
    if not s then
        interfaces.syntax[category] = {
            keys = settings_to_set(list)
        }
    else
        s.keys = settings_to_set(list)
    end
end

function interfaces.addvalidkeys(category,list)
    local s = interfaces.syntax[category]
    if not s then
        interfaces.syntax[category] = {
            keys = settings_to_set(list)
        }
    else
        settings_to_set(list,s.keys)
    end
end

-- weird code, looks incomplete ... probbably an experiment

local prefix, category, keys

local function set(key,value)
    if keys and not keys[key] then
        interfaces.invalidkey(category,key)
    else
        context.setsomevalue(prefix,key,value)
    end
end

local pattern = make_settings_to_hash_pattern(set,"tolerant")

function interfaces.getcheckedparameters(k,p,s)
    if s and s ~= "" then
        prefix, category = p, k
        keys = k and k ~= "" and interfaces.syntax[k].keys
        lpegmatch(pattern,s)
    end
end

-- _igcp_ = interfaces.getcheckedparameters
