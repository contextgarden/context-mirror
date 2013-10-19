if not modules then modules = { } end modules ['font-otd'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local match = string.match
local sequenced = table.sequenced

local trace_dynamics     = false  trackers.register("otf.dynamics", function(v) trace_dynamics = v end)
local trace_applied      = false  trackers.register("otf.applied",  function(v) trace_applied      = v end)

local report_otf         = logs.reporter("fonts","otf loading")
local report_process     = logs.reporter("fonts","otf process")

local allocate           = utilities.storage.allocate

local fonts              = fonts
local otf                = fonts.handlers.otf
local hashes             = fonts.hashes
local definers           = fonts.definers
local constructors       = fonts.constructors
local specifiers         = fonts.specifiers

local fontidentifiers    = hashes.identifiers
local fontresources      = hashes.resources
local fontproperties     = hashes.properties
local fontdynamics       = hashes.dynamics

local contextsetups      = specifiers.contextsetups
local contextnumbers     = specifiers.contextnumbers
local contextmerged      = specifiers.contextmerged

local setmetatableindex  = table.setmetatableindex

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local a_to_script        = { }
local a_to_language      = { }

-- we can have a scripts hash in fonts.hashes

function otf.setdynamics(font,attribute)
 -- local features = contextsetups[contextnumbers[attribute]] -- can be moved to caller
    local features = contextsetups[attribute]
    if features then
        local dynamics = fontdynamics[font]
        dynamic = contextmerged[attribute] or 0
        local script, language
        if dynamic == 2 then -- merge
            language  = features.language or fontproperties[font].language or "dflt"
            script    = features.script   or fontproperties[font].script   or "dflt"
        else -- if dynamic == 1 then -- replace
            language  = features.language or "dflt"
            script    = features.script   or "dflt"
        end
        if script == "auto" then
            -- checkedscript and resources are defined later so we cannot shortcut them -- todo: make installer
            script = definers.checkedscript(fontidentifiers[font],fontresources[font],features)
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
            local tfmdata = fontidentifiers[font]
            a_to_script  [attribute] = script
            a_to_language[attribute] = language
            -- we need to save some values .. quite messy
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
                report_otf("setting dynamics %s: attribute %a, script %a, language %a, set %a",contextnumbers[attribute],attribute,script,language,set)
            end
            -- we need to restore some values
            properties.script   = s_script
            properties.language = s_language
            properties.mode     = s_mode
            shared.features     = s_features
            -- end of restore
            dynamics[script][language][attribute] = dsla -- cache
        elseif trace_dynamics then
         -- report_otf("using dynamics %s: attribute %a, script %a, language %a",contextnumbers[attribute],attribute,script,language)
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

local autofeatures = fonts.analyzers.features -- was: constants

local resolved  = { } -- we only resolve a font,script,language,attribute pair once
local wildcard  = "*"
local default   = "dflt"

-- what about analyze in local and not in font

local function initialize(sequence,script,language,s_enabled,a_enabled,font,attr,dynamic)
    local features = sequence.features
    if features then
        for kind, scripts in next, features do
            local e_e
            local a_e = a_enabled and a_enabled[kind] -- the value (location)
            if a_e ~= nil then
                e_e = a_e
            else
                e_e = s_enabled and s_enabled[kind] -- the value (font)
            end
            if e_e then
                local languages = scripts[script] or scripts[wildcard]
                if languages then
                 -- local valid, what = false
                    local valid = false
                    -- not languages[language] or languages[default] or languages[wildcard] because we want tracing
                    -- only first attribute match check, so we assume simple fina's
                    -- default can become a font feature itself
                    if languages[language] then
                        valid = e_e -- was true
                     -- what  = language
                 -- elseif languages[default] then
                 --     valid = true
                 --     what  = default
                    elseif languages[wildcard] then
                        valid = e_e -- was true
                     -- what  = wildcard
                    end
                    if valid then
                        local attribute = autofeatures[kind] or false
                     -- if a_e and dynamic < 0 then
                     --     valid = false
                     -- end
                     -- if trace_applied then
                     --     local typ, action = match(sequence.type,"(.*)_(.*)") -- brrr
                     --     report_process(
                     --         "%s font: %03i, dynamic: %03i, kind: %s, script: %-4s, language: %-4s (%-4s), type: %s, action: %s, name: %s",
                     --         (valid and "+") or "-",font,attr or 0,kind,script,language,what,typ,action,sequence.name)
                     -- end
                        if trace_applied then
                            report_process(
                                "font %s, dynamic %a (%a), feature %a, script %a, language %a, lookup %a, value %a",
                                    font,attr or 0,dynamic,kind,script,language,sequence.name,valid)
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

-- there is some fuzzy language/script state stuff in properties (temporary)

function otf.dataset(tfmdata,font,attr) -- attr only when explicit (as in special parbuilder)

    local script, language, s_enabled, a_enabled, dynamic

    if attr and attr ~= 0 then
        dynamic = contextmerged[attr] or 0
     -- local features = contextsetups[contextnumbers[attr]] -- could be a direct list
        local features = contextsetups[attr]
        a_enabled = features -- location based
        if dynamic == 1 then -- or dynamic == -1 then
            -- replace
            language  = features.language or "dflt"
            script    = features.script   or "dflt"
        elseif dynamic == 2 then -- or dynamic == -2 then
            -- merge
            local properties = tfmdata.properties
            s_enabled = tfmdata.shared.features -- font based
            language  = features.language or properties.language or  "dflt"
            script    = features.script   or properties.script   or  "dflt"
        else
            -- error
            local properties = tfmdata.properties
            language  = properties.language or "dflt"
            script    = properties.script   or "dflt"
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
        ra = {
            -- indexed but we can also add specific data by key in:
        }
        rl[attr] = ra
        local sequences = tfmdata.resources.sequences
--         setmetatableindex(ra, function(t,k)
--             if type(k) == "number" then
--                 local v = initialize(sequences[k],script,language,s_enabled,a_enabled,font,attr,dynamic)
--                 t[k] = v or false
--                 return v
--             end
--         end)
for s=1,#sequences do
    local v = initialize(sequences[s],script,language,s_enabled,a_enabled,font,attr,dynamic)
    if v then
        ra[#ra+1] = v
    end
end
    end
    return ra

end
