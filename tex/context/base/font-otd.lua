if not modules then modules = { } end modules ['font-otd'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match = string.match
local sequenced = table.sequenced

local trace_dynamics     = false  trackers.register("otf.dynamics", function(v) trace_dynamics = v end)
local trace_applied      = false  trackers.register("otf.applied",  function(v) trace_applied      = v end)

local report_otf         = logs.reporter("fonts","otf loading")
local report_process     = logs.reporter("fonts","otf process")

local fonts              = fonts
local otf                = fonts.handlers.otf
local hashes             = fonts.hashes
local definers           = fonts.definers
local constructors       = fonts.constructors
local specifiers         = fonts.specifiers

local fontdata           = hashes.identifiers
----- fontresources      = hashes.resources -- not yet defined

local contextsetups      = specifiers.contextsetups
local contextnumbers     = specifiers.contextnumbers
local contextmerged      = specifiers.contextmerged

local setmetatableindex  = table.setmetatableindex

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local fontdynamics       = { }
hashes.dynamics          = fontdynamics

local a_to_script        = { }
local a_to_language      = { }

setmetatableindex(fontdynamics, function(t,font)
    local d = fontdata[font].shared.dynamics or false
    t[font] = d
    return d
end)

function otf.setdynamics(font,attribute)
    local features = contextsetups[contextnumbers[attribute]] -- can be moved to caller
    if features then
        local dynamics = fontdynamics[font]
        local script   = features.script   or 'dflt'
        local language = features.language or 'dflt'
        if script == "auto" then
            -- checkedscript and resources are defined later so we cannot shortcut them
            script = definers.checkedscript(fontdata[font],hashes.resources[font],features)
        end
        local ds = dynamics[script] -- can be metatable magic (less testing)
        if not ds then
            ds = { }
            dynamics[script] = ds
        end
        local dsl = ds[language]
        if not dsl then
            dsl = { }
            ds[language] = dsl
        end
        local dsla = dsl[attribute]
        if not dsla then
            local tfmdata = fontdata[font]
            a_to_script  [attribute] = script
            a_to_language[attribute] = language
            -- we need to save some values
            local properties = tfmdata.properties
            local shared     = tfmdata.shared
            local s_script   = properties.script
            local s_language = properties.language
            local s_mode     = properties.mode
            local s_features = shared.features
            properties.mode     = "node"
            properties.language = language
            properties.script   = script
            properties.dynamics = true -- handy for tracing
            shared.features     = { }
            -- end of save
            local set = constructors.checkedfeatures("otf",features)
            set.mode = "node" -- really needed
            dsla = otf.setfeatures(tfmdata,set)
            if trace_dynamics then
                report_otf("setting dynamics %s: attribute %s, script %s, language %s, set: %s",contextnumbers[attribute],attribute,script,language,sequenced(set))
            end
            -- we need to restore some values
            properties.script   = s_script
            properties.language = s_language
            properties.mode     = s_mode
            shared.features     = s_features
            -- end of restore
            dynamics[script][language][attribute] = dsla -- cache
        elseif trace_dynamics then
         -- report_otf("using dynamics %s: attribute %s, script %s, language %s",contextnumbers[attribute],attribute,script,language)
        end
        return dsla
    end
end

function otf.scriptandlanguage(tfmdata,attr)
    local properties = tfmdata.properties
    if attr and attr > 0 then
        return a_to_script[attr] or properties.script or "dflt", a_to_language[attr] or properties.language or "dflt"
    else
        return properties.script or "dflt", properties.language or "dflt"
    end
end

-- we reimplement the dataset resolver

local special_attributes = {
    init = 1,
    medi = 2,
    fina = 3,
    isol = 4
}

local resolved = { } -- we only resolve a font,script,language,attribute pair once
local wildcard = "*"
local default  = "dflt"

local function initialize(sequence,script,language,s_enabled,a_enabled,font,attr,dynamic)
    local features = sequence.features
    if features then
        for kind, scripts in next, features do
            local s_e = s_enabled and s_enabled[kind] -- the value
            local a_e = a_enabled and a_enabled[kind] -- the value
            local e_e = s_e or a_e -- todo: when one of them is true and the other is a value
            if e_e then
                local languages = scripts[script] or scripts[wildcard]
                if languages then
                    local valid, what = false
                    -- not languages[language] or languages[default] or languages[wildcard] because we want tracing
                    -- only first attribute match check, so we assume simple fina's
                    -- default can become a font feature itself
                    if languages[language] then
                        valid = e_e -- was true
                        what  = language
                 -- elseif languages[default] then
                 --     valid = true
                 --     what  = default
                    elseif languages[wildcard] then
                        valid = e_e -- was true
                        what  = wildcard
                    end
                    if valid then
                        local attribute = special_attributes[kind] or false
                        if a_e and dynamic < 0 then
                            valid = false
                        end
                        if trace_applied then
                            local typ, action = match(sequence.type,"(.*)_(.*)") -- brrr
                            report_process(
                                "%s font: %03i, dynamic: %03i, kind: %s, script: %-4s, language: %-4s (%-4s), type: %s, action: %s, name: %s",
                                (valid and "+") or "-",font,attr or 0,kind,script,language,what,typ,action,sequence.name)
                        end
                        return { valid, attribute, sequence.chain or 0, kind, sequence }
                    end
                end
            end
        end
        return false -- { valid, attribute, chain, "generic", sequence } -- false anyway, could be flag instead of table
    else
        return false -- { false, false, chain, false, sequence } -- indirect lookup, part of chain (todo: make this a separate table)
    end
end

-- local contextresolved = { }
--
-- setmetatableindex(contextresolved, function(t,k)
--     local v = contextsetups[contextnumbers[k]]
--     t[k] = v
--     return v
-- end)

function otf.dataset(tfmdata,sequences,font,attr) -- attr only when explicit (as in special parbuilder)

    local script, language, s_enabled, a_enabled, dynamic

    if attr and attr ~= 0 then
        local features = contextsetups[contextnumbers[attr]] -- could be a direct list
     -- local features = contextresolved[attr]
        language  = features.language or "dflt"
        script    = features.script   or "dflt"
        a_enabled = features
        dynamic   = contextmerged[attr] or 0
        if dynamic == 2 or dynamic == -2 then
            -- font based
            s_enabled = tfmdata.shared.features
        end
    else
        local properties = tfmdata.properties
        language  = properties.language or "dflt"
        script    = properties.script   or "dflt"
        s_enabled = tfmdata.shared.features -- can be made local to the resolver
        dynamic   = 0
    end

    local res = resolved[font]
    if not res then
        res = { }
        resolved[font] = res
    end
    local rs = res[script]
    if not rs then
        rs = { }
        res[script] = rs
    end
    local rl = rs[language]
    if not rl then
        rl = { }
        rs[language] = rl
    end
    local ra = rl[attr]
    if ra == nil then -- attr can be false
        ra = { }
        rl[attr] = ra
        setmetatableindex(ra, function(t,k)
            local v = initialize(sequences[k],script,language,s_enabled,a_enabled,font,attr,dynamic)
            t[k] = v or false
            return v
        end)
    end

    return ra

end
