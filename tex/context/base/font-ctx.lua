if not modules then modules = { } end modules ['font-ctx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup: merge of replace, lang/script etc

local texsprint, count, texsetcount = tex.sprint, tex.count, tex.setcount
local format, concat, gmatch, match, find, lower, gsub = string.format, table.concat, string.gmatch, string.match, string.find, string.lower, string.gsub
local tostring, next, type = tostring, next, type
local lpegmatch = lpeg.match

local ctxcatcodes = tex.ctxcatcodes

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local tfm      = fonts.tfm
local define   = fonts.define
local fontdata = fonts.ids
local specify  = define.specify

specify.context_setups  = specify.context_setups  or { }
specify.context_numbers = specify.context_numbers or { }
specify.context_merged  = specify.context_merged  or { }
specify.synonyms        = specify.synonyms        or { }

local setups   = specify.context_setups
local numbers  = specify.context_numbers
local merged   = specify.context_merged
local synonyms = specify.synonyms
local triggers = fonts.triggers

--[[ldx--
<p>So far we haven't really dealt with features (or whatever we want
to pass along with the font definition. We distinguish the following
situations:</p>
situations:</p>

<code>
name:xetex like specs
name@virtual font spec
name*context specification
</code>
--ldx]]--

function specify.predefined(specification)
    local detail = specification.detail
    if detail ~= "" then
    --  detail = gsub(detail,"["..define.splitsymbols.."].*$","") -- get rid of *whatever specs and such
        if define.methods[detail] then                            -- since these may be appended at the
            specification.features.vtf = { preset = detail }      -- tex end by default
        end
    end
    return specification
end

define.register_split("@", specify.predefined)

storage.register("fonts/setups" ,  define.specify.context_setups , "fonts.define.specify.context_setups" )
storage.register("fonts/numbers",  define.specify.context_numbers, "fonts.define.specify.context_numbers")
storage.register("fonts/merged",   define.specify.context_merged,  "fonts.define.specify.context_merged")
storage.register("fonts/synonyms", define.specify.synonyms,        "fonts.define.specify.synonyms")

local normalize_meanings = fonts.otf.meanings.normalize
local settings_to_hash   = aux.settings_to_hash
local default_features   = fonts.otf.features.default

local function preset_context(name,parent,features) -- currently otf only
    if features == "" and find(parent,"=") then
        features = parent
        parent = ""
    end
    if features == "" then
        features = { }
    elseif type(features) == "string" then
        features = normalize_meanings(settings_to_hash(features))
    else
        features = normalize_meanings(features)
    end
    -- todo: synonyms, and not otf bound
    if parent ~= "" then
        for p in gmatch(parent,"[^, ]+") do
            local s = setups[p]
            if s then
                for k,v in next, s do
                    if features[k] == nil then
                        features[k] = v
                    end
                end
            end
        end
    end
    -- these are auto set so in order to prevent redundant definitions
    -- we need to preset them (we hash the features and adding a default
    -- setting during initialization may result in a different hash)
    for k,v in next, triggers do
        if features[v] == nil then -- not false !
            local vv = default_features[v]
            if vv then features[v] = vv end
        end
    end
    -- sparse 'm so that we get a better hash and less test (experimental
    -- optimization)
    local t = { } -- can we avoid t ?
    for k,v in next, features do
        if v then t[k] = v end
    end
    -- needed for dynamic features
    local number = (setups[name] and setups[name].number) or 0
    if number == 0 then
        number = #numbers + 1
        numbers[number] = name
    end
    t.number = number
    setups[name] = t
    return number, t
end

local function context_number(name) -- will be replaced
    local t = setups[name]
    if not t then
        return 0
    elseif t.auto then
        local lng = tonumber(tex.language)
        local tag = name .. ":" .. lng
        local s = setups[tag]
        if s then
            return s.number or 0
        else
            local script, language = languages.association(lng)
            if t.script ~= script or t.language ~= language then
                local s = table.fastcopy(t)
                local n = #numbers + 1
                setups[tag] = s
                numbers[n] = tag
                s.number = n
                s.script = script
                s.language = language
                return n
            else
                setups[tag] = t
                return t.number or 0
            end
        end
    else
        return t.number or 0
    end
end

local function merge_context(currentnumber,extraname,option)
    local current = setups[numbers[currentnumber]]
    local extra = setups[extraname]
    if extra then
        local mergedfeatures, mergedname = { }, nil
        if option < 0 then
            if current then
                for k, v in next, current do
                    if not extra[k] then
                        mergedfeatures[k] = v
                    end
                end
            end
            mergedname = currentnumber .. "-" .. extraname
        else
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
            mergedname = currentnumber .. "+" .. extraname
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number -- context_number(mergedname)
    else
        return currentnumber
    end
end

local function register_context(fontnumber,extraname,option)
    local extra = setups[extraname]
    if extra then
        local mergedfeatures, mergedname = { }, nil
        if option < 0 then
            mergedname = fontnumber .. "-" .. extraname
        else
            mergedname = fontnumber .. "+" .. extraname
        end
        for k, v in next, extra do
            mergedfeatures[k] = v
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number -- context_number(mergedname)
    else
        return 0
    end
end

specify.preset_context   = preset_context
specify.context_number   = context_number
specify.merge_context    = merge_context
specify.register_context = register_context

local current_font  = font.current
local tex_attribute = tex.attribute

local cache = { } -- concat might be less efficient than nested tables

function fonts.withset(name,what)
    local zero = tex_attribute[0]
    local hash = zero .. "+" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = merge_context(zero,name,what)
        cache[hash] = done
    end
    tex_attribute[0] = done
end
function fonts.withfnt(name,what)
    local font = current_font()
    local hash = font .. "*" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = register_context(font,name,what)
        cache[hash] = done
    end
    tex_attribute[0] = done
end

function specify.show_context(name)
    return setups[name] or setups[numbers[name]] or setups[numbers[tonumber(name)]] or { }
end

local function split_context(features)
    return setups[features] or (preset_context(features,"","") and setups[features])
end

specify.split_context = split_context

function specify.context_tostring(name,kind,separator,yes,no,strict,omit) -- not used
    return aux.hash_to_string(table.merged(fonts[kind].features.default or {},setups[name] or {}),separator,yes,no,strict,omit)
end

local splitter = lpeg.splitat(",")

function specify.starred(features) -- no longer fallbacks here
    local detail = features.detail
    if detail and detail ~= "" then
        features.features.normal = split_context(detail)
    else
        features.features.normal = { }
    end
    return features
end

define.register_split('*',specify.starred)

-- define (two steps)

local P, C, Cc = lpeg.P, lpeg.C, lpeg.Cc

local space        = P(" ")
local spaces       = space^0
local leftparent   = (P"(")
local rightparent  = (P")")
local value        = C((leftparent * (1-rightparent)^0 * rightparent + (1-space))^1)
local dimension    = C((space/"" + P(1))^1)
local rest         = C(P(1)^0)
local scale_none   =               Cc(0)
local scale_at     = P("at")     * Cc(1) * spaces * dimension -- value
local scale_sa     = P("sa")     * Cc(2) * spaces * dimension -- value
local scale_mo     = P("mo")     * Cc(3) * spaces * dimension -- value
local scale_scaled = P("scaled") * Cc(4) * spaces * dimension -- value

local sizepattern  = spaces * (scale_at + scale_sa + scale_mo + scale_scaled + scale_none)
local splitpattern = spaces * value * spaces * rest

local specification --

local get_specification = define.get_specification

-- we can make helper macros which saves parsing (but normaly not
-- that many calls, e.g. in mk a couple of 100 and in metafun 3500)

function define.command_1(str)
    statistics.starttiming(fonts)
    local fullname, size = lpegmatch(splitpattern,str)
    local lookup, name, sub, method, detail = get_specification(fullname)
    if not name then
        logs.report("define font","strange definition '%s'",str)
        texsprint(ctxcatcodes,"\\fcglet\\somefontname\\defaultfontfile")
    elseif name == "unknown" then
        texsprint(ctxcatcodes,"\\fcglet\\somefontname\\defaultfontfile")
    else
        texsprint(ctxcatcodes,"\\fcxdef\\somefontname{",name,"}")
    end
    -- we can also use a count for the size
    if size and size ~= "" then
        local mode, size = lpegmatch(sizepattern,size)
        if size and mode then
            count.scaledfontmode = mode
            texsprint(ctxcatcodes,"\\def\\somefontsize{",size,"}")
        else
            count.scaledfontmode = 0
            texsprint(ctxcatcodes,"\\let\\somefontsize\\empty")
        end
    elseif true then
        -- so we don't need to check in tex
        count.scaledfontmode = 2
        texsprint(ctxcatcodes,"\\let\\somefontsize\\empty")
    else
        count.scaledfontmode = 0
        texsprint(ctxcatcodes,"\\let\\somefontsize\\empty")
    end
    specification = define.makespecification(str,lookup,name,sub,method,detail,size)
end

local n = 0

-- we can also move rscale to here (more consistent)

function define.command_2(global,cs,str,size,classfeatures,fontfeatures,classfallbacks,fontfallbacks,mathsize,textsize,relativeid)
    if trace_defining then
        logs.report("define font","memory usage before: %s",statistics.memused())
    end
    -- name is now resolved and size is scaled cf sa/mo
    local lookup, name, sub, method, detail = get_specification(str or "")
    -- asome settings can be overloaded
    if lookup and lookup ~= "" then
        specification.lookup = lookup
    end
    if relativeid and relativeid ~= "" then -- experimental hook
        local id = tonumber(relativeid) or 0
        specification.relativeid = id > 0 and id
    end
    specification.name = name
    specification.size = size
    specification.sub = (sub and sub ~= "" and sub) or specification.sub
    specification.mathsize = mathsize
    specification.textsize = textsize
    if detail and detail ~= "" then
        specification.method, specification.detail = method or "*", detail
    elseif specification.detail and specification.detail ~= "" then
        -- already set
    elseif fontfeatures and fontfeatures ~= "" then
        specification.method, specification.detail = "*", fontfeatures
    elseif classfeatures and classfeatures ~= "" then
        specification.method, specification.detail = "*", classfeatures
    end
    if fontfallbacks and fontfallbacks ~= "" then
        specification.fallbacks = fontfallbacks
    elseif classfallbacks and classfallbacks ~= "" then
        specification.fallbacks = classfallbacks
    end
    local tfmdata = define.read(specification,size) -- id not yet known
    if not tfmdata then
        logs.report("define font","unable to define %s as \\%s",name,cs)
        texsetcount("global","lastfontid",-1)
    elseif type(tfmdata) == "number" then
        if trace_defining then
            logs.report("define font","reusing %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,tfmdata,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        tex.definefont(global,cs,tfmdata)
        -- resolved (when designsize is used):
        texsprint(ctxcatcodes,format("\\def\\somefontsize{%isp}",fontdata[tfmdata].size))
        texsetcount("global","lastfontid",tfmdata)
    else
    --  local t = os.clock(t)
        local id = font.define(tfmdata)
    --  print(name,os.clock()-t)
        tfmdata.id = id
        define.register(tfmdata,id)
        tex.definefont(global,cs,id)
        tfm.cleanup_table(tfmdata)
        if trace_defining then
            logs.report("define font","defining %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,id,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        -- resolved (when designsize is used):
        texsprint(ctxcatcodes,format("\\def\\somefontsize{%isp}",tfmdata.size))
    --~ if specification.fallbacks then
    --~     fonts.collections.prepare(specification.fallbacks)
    --~ end
        texsetcount("global","lastfontid",id)
    end
    if trace_defining then
        logs.report("define font","memory usage after: %s",statistics.memused())
    end
    statistics.stoptiming(fonts)
end

local enable_auto_r_scale = false

experiments.register("fonts.autorscale", function(v)
    enable_auto_r_scale = v
end)

local calculate_scale = fonts.tfm.calculate_scale

function fonts.tfm.calculate_scale(tfmtable, scaledpoints, relativeid)
    local scaledpoints, delta = calculate_scale(tfmtable, scaledpoints, relativeid)
    if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific
        local relativedata = fontdata[relativeid]
        local id_x_height = relativedata and relativedata.parameters and relativedata.parameters.x_height
        local tf_x_height = id_x_height and tfmtable.parameters and tfmtable.parameters.x_height * delta
        if tf_x_height then
            scaledpoints = (id_x_height/tf_x_height) * scaledpoints
            delta = scaledpoints/(tfmtable.units or 1000)
        end
    end
    return scaledpoints, delta
end

--~ table.insert(readers.sequence,1,'vtf')

--~ function readers.vtf(specification)
--~     if specification.features.vtf and specification.features.vtf.preset then
--~         return tfm.make(specification)
--~     else
--~         return nil
--~     end
--~ end

-- we need a place for this .. outside the generic scope

local dimenfactors = number.dimenfactors

function fonts.dimenfactor(unit,tfmdata)
    if unit == "ex" then
        return (tfmdata and tfmdata.parameters.x_height) or 655360
    elseif unit == "em" then
        return (tfmdata and tfmdata.parameters.em_height) or 655360
    else
        return dimenfactors[unit] or unit
    end
end

function fonts.cleanname(name)
    texsprint(ctxcatcodes,fonts.names.cleanname(name))
end

local p, f = 1, "%0.01fpt" -- normally this value is changed only once

function fonts.nbfs(amount,precision)
    if precision ~= p then
        p = precision
        f = "%0.0" .. p .. "fpt"
    end
    texsprint(ctxcatcodes,format(f,amount/65536))
end
