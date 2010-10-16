if not modules then modules = { } end modules ['font-ctx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup: merge of replace, lang/script etc

local texsprint, count, texsetcount, write_nl = tex.sprint, tex.count, tex.setcount, texio.write_nl
local format, gmatch, match, find, lower, gsub, byte = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub, string.byte
local concat, serialize = table.concat, table.serialize
local settings_to_hash, hash_to_string = utilities.parsers.settings_to_hash, utilities.parsers.hash_to_string
local formatcolumns = utilities.formatters.formatcolumns

local tostring, next, type = tostring, next, type
local lpegmatch = lpeg.match
local round = math.round

local ctxcatcodes = tex.ctxcatcodes

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local trace_usage    = false  trackers.register("fonts.usage",    function(v) trace_usage    = v end)
local trace_mapfiles = false  trackers.register("fonts.mapfiles", function(v) trace_mapfiles  = v end)

local report_define   = logs.new("define fonts")
local report_usage    = logs.new("fonts usage")
local report_mapfiles = logs.new("mapfiles")

local fonts      = fonts
local tfm        = fonts.tfm
local fontdata   = fonts.identifiers
local definers   = fonts.definers
local specifiers = definers.specifiers

specifiers.contextsetups  = specifiers.contextsetups  or { }
specifiers.contextnumbers = specifiers.contextnumbers or { }
specifiers.contextmerged  = specifiers.contextmerged  or { }
specifiers.synonyms       = specifiers.synonyms       or { }

local setups   = specifiers.contextsetups
local numbers  = specifiers.contextnumbers
local merged   = specifiers.contextmerged
local synonyms = specifiers.synonyms
local triggers = fonts.triggers

-- Beware, number can be shared between redefind features but as it is
-- applied only for special cases it probably doesn't matter.

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

local function predefined(specification)
    local detail = specification.detail
    if detail ~= "" and definers.methods.variants[detail] then
        specification.features.vtf = { preset = detail }
    end
    return specification
end

definers.registersplit("@", predefined)

storage.register("fonts/setups" ,  setups ,  "fonts.definers.specifiers.contextsetups" )
storage.register("fonts/numbers",  numbers,  "fonts.definers.specifiers.contextnumbers")
storage.register("fonts/merged",   merged,   "fonts.definers.specifiers.contextmerged")
storage.register("fonts/synonyms", synonyms, "fonts.definers.specifiers.synonyms")

local normalize_meanings = fonts.otf.meanings.normalize
local default_features   = fonts.otf.features.default

local function presetcontext(name,parent,features) -- currently otf only
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
    -- maybe number should always be renewed as we can redefine features
    local number = (setups[name] and setups[name].number) or 0 -- hm, numbers[name]
    if number == 0 then
        number = #numbers + 1
        numbers[number] = name
    end
    t.number = number
    setups[name] = t
    return number, t
end

local function contextnumber(name) -- will be replaced
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

local function mergecontext(currentnumber,extraname,option)
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
        return number -- contextnumber(mergedname)
    else
        return currentnumber
    end
end

local function registercontext(fontnumber,extraname,option)
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
        return number -- contextnumber(mergedname)
    else
        return 0
    end
end

specifiers.presetcontext   = presetcontext
specifiers.contextnumber   = contextnumber
specifiers.mergecontext    = mergecontext
specifiers.registercontext = registercontext

local current_font  = font.current
local tex_attribute = tex.attribute

local cache = { } -- concat might be less efficient than nested tables

function fonts.withset(name,what)
    local zero = tex_attribute[0]
    local hash = zero .. "+" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = mergecontext(zero,name,what)
        cache[hash] = done
    end
    tex_attribute[0] = done
end

function fonts.withfnt(name,what)
    local font = current_font()
    local hash = font .. "*" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = registercontext(font,name,what)
        cache[hash] = done
    end
    tex_attribute[0] = done
end

function specifiers.showcontext(name)
    return setups[name] or setups[numbers[name]] or setups[numbers[tonumber(name)]] or { }
end

-- todo: support a,b,c

local function splitcontext(features) -- presetcontext creates dummy here
    return setups[features] or (presetcontext(features,"","") and setups[features])
end

--~ local splitter = lpeg.splitat("=")

--~ local function splitcontext(features)
--~     local setup = setups[features]
--~     if setup then
--~         return setup
--~     elseif find(features,",") then
--~         -- This is not that efficient but handy anyway for quick and dirty tests
--~         -- beware, due to the way of caching setups you can get the wrong results
--~         -- when components change. A safeguard is to nil the cache.
--~         local merge = nil
--~         for feature in gmatch(features,"[^, ]+") do
--~             if find(feature,"=") then
--~                 local k, v = lpegmatch(splitter,feature)
--~                 if k and v then
--~                     if not merge then
--~                         merge = { k = v }
--~                     else
--~                         merge[k] = v
--~                     end
--~                 end
--~             else
--~                 local s = setups[feature]
--~                 if not s then
--~                     -- skip
--~                 elseif not merge then
--~                     merge = s
--~                 else
--~                     for k, v in next, s do
--~                         merge[k] = v
--~                     end
--~                 end
--~             end
--~         end
--~         setup = merge and presetcontext(features,"",merge) and setups[features]
--~         -- actually we have to nil setups[features] in order to permit redefinitions
--~         setups[features] = nil
--~     end
--~     return setup or (presetcontext(features,"","") and setups[features]) -- creates dummy
--~ end

specifiers.splitcontext = splitcontext

function specifiers.contexttostring(name,kind,separator,yes,no,strict,omit) -- not used
    return hash_to_string(table.merged(fonts[kind].features.default or {},setups[name] or {}),separator,yes,no,strict,omit)
end

local function starred(features) -- no longer fallbacks here
    local detail = features.detail
    if detail and detail ~= "" then
        features.features.normal = splitcontext(detail)
    else
        features.features.normal = { }
    end
    return features
end

definers.registersplit('*',starred)

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

local getspecification = definers.getspecification

-- we can make helper macros which saves parsing (but normaly not
-- that many calls, e.g. in mk a couple of 100 and in metafun 3500)

function definers.stage_one(str)
    statistics.starttiming(fonts)
    local fullname, size = lpegmatch(splitpattern,str)
    local lookup, name, sub, method, detail = getspecification(fullname)
    if not name then
        report_define("strange definition '%s'",str)
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
    specification = definers.makespecification(str,lookup,name,sub,method,detail,size)
end

local n = 0

-- we can also move rscale to here (more consistent)

function definers.stage_two(global,cs,str,size,classfeatures,fontfeatures,classfallbacks,fontfallbacks,
        mathsize,textsize,relativeid,classgoodies,goodies)
    if trace_defining then
        report_define("memory usage before: %s",statistics.memused())
    end
    -- name is now resolved and size is scaled cf sa/mo
    local lookup, name, sub, method, detail = getspecification(str or "")
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
    specification.goodies = goodies
    specification.cs = cs
    specification.global = global
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
    local tfmdata = definers.read(specification,size) -- id not yet known
    if not tfmdata then
        report_define("unable to define %s as \\%s",name,cs)
        texsetcount("global","lastfontid",-1)
    elseif type(tfmdata) == "number" then
        if trace_defining then
            report_define("reusing %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s, goodies: %s/%s)",
                name,tfmdata,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks,classgoodies,goodies)
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
        definers.register(tfmdata,id)
        tex.definefont(global,cs,id)
        tfm.cleanuptable(tfmdata)
        if trace_defining then
            report_define("defining %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,id,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        -- resolved (when designsize is used):
        texsprint(ctxcatcodes,format("\\def\\somefontsize{%isp}",tfmdata.size or 655360))
    --~ if specification.fallbacks then
    --~     fonts.collections.prepare(specification.fallbacks)
    --~ end
        texsetcount("global","lastfontid",id)
    end
    if trace_defining then
        report_define("memory usage after: %s",statistics.memused())
    end
    statistics.stoptiming(fonts)
end

function definers.define(specification)
    --
    local name = specification.name
    if not name or name == "" then
        return -1
    else
        statistics.starttiming(fonts)
        --
        -- following calls expect a few properties to be set:
        --
        local lookup, name, sub, method, detail = getspecification(name or "")
        --
        specification.name          = (name ~= "" and name) or specification.name
        --
        specification.lookup        = specification.lookup or (lookup ~= "" and lookup) or "file"
        specification.size          = specification.size                                or 655260
        specification.sub           = specification.sub    or (sub    ~= "" and sub)    or ""
        specification.method        = specification.method or (method ~= "" and method) or "*"
        specification.detail        = specification.detail or (detail ~= "" and detail) or ""
        --
        specification.specification = "" -- not used
        specification.resolved      = ""
        specification.forced        = ""
        specification.features      = { } -- via detail
        --
        -- we don't care about mathsize textsize goodies fallbacks
        --
        if specification.cs == "" then
            specification.cs = nil
            specification.global = false
        elseif specification.global == nil then
            specification.global = false
        end
        --
        local tfmdata = definers.read(specification,specification.size)
        if not tfmdata then
            return -1, nil
        elseif type(tfmdata) == "number" then
            if specification.cs then
                tex.definefont(specification.global,specification.cs,tfmdata)
            end
            return tfmdata, fontdata[tfmdata]
        else
            local id = font.define(tfmdata)
            tfmdata.id = id
            definers.register(tfmdata,id)
            if specification.cs then
                tex.definefont(specification.global,specification.cs,id)
            end
            tfm.cleanuptable(tfmdata)
            return id, tfmdata
        end
        statistics.stoptiming(fonts)
    end
end

local enable_auto_r_scale = false

experiments.register("fonts.autorscale", function(v)
    enable_auto_r_scale = v
end)

local calculatescale = fonts.tfm.calculatescale

-- Not ok, we can best use a database for this. The problem is that we
-- have delayed definitions and so we never know what style is taken
-- as start.

function fonts.tfm.calculatescale(tfmtable, scaledpoints, relativeid)
    local scaledpoints, delta, units = calculatescale(tfmtable,scaledpoints)
--~     if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific
--~         local relativedata = fontdata[relativeid]
--~         local rfmtable = relativedata and relativedata.unscaled and relativedata.unscaled
--~         local id_x_height = rfmtable and rfmtable.parameters and rfmtable.parameters.x_height
--~         local tf_x_height = tfmtable and tfmtable.parameters and tfmtable.parameters.x_height
--~         if id_x_height and tf_x_height then
--~             local rscale = id_x_height/tf_x_height
--~             delta = rscale * delta
--~             scaledpoints = rscale * scaledpoints
--~         end
--~     end
    return scaledpoints, delta, units
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

local p, f = 1, "%0.1fpt" -- normally this value is changed only once

local stripper = lpeg.patterns.strip_zeros

function fonts.nbfs(amount,precision)
    if precision ~= p then
        p = precision
        f = "%0." .. p .. "fpt"
    end
    texsprint(ctxcatcodes,lpegmatch(stripper,format(f,amount/65536)))
end

-- for the moment here, this will become a chain of extras that is
-- hooked into the ctx registration (or scaler or ...)

local function digitwidth(font) -- max(quad/2,wd(0..9))
    local tfmtable = fontdata[font]
    local parameters = tfmtable.parameters
    local width = parameters.digitwidth
    if not width then
        width = round(parameters.quad/2) -- maybe tex.scale
        local characters = tfmtable.characters
        for i=48,57 do
            local wd = round(characters[i].width)
            if wd > width then
                width = wd
            end
        end
        parameters.digitwidth = width
    end
    return width
end

fonts.getdigitwidth = digitwidth
fonts.setdigitwidth = digitwidth

-- soon to be obsolete:

local loaded = { -- prevent loading (happens in cont-sys files)
    ["original-base.map"     ] = true,
    ["original-ams-base.map" ] = true,
    ["original-ams-euler.map"] = true,
    ["original-public-lm.map"] = true,
}

function fonts.map.loadfile(name)
    name = file.addsuffix(name,"map")
    if not loaded[name] then
        if trace_mapfiles then
            report_mapfiles("loading map file '%s'",name)
        end
        pdf.mapfile(name)
        loaded[name] = true
    end
end

local loaded = { -- prevent double loading
}

function fonts.map.loadline(how,line)
    if line then
        how = how .. " " .. line
    elseif how == "" then
        how = "= " .. line
    end
    if not loaded[how] then
        if trace_mapfiles then
            report_mapfiles("processing map line '%s'",line)
        end
        pdf.mapline(how)
        loaded[how] = true
    end
end

function fonts.map.reset()
    pdf.mapfile("")
end

fonts.map.reset() -- resets the default file

-- we need an 'do after the banner hook'

-- pdf.mapfile("mkiv-base.map") -- loads the default file

local nounicode = byte("?")

local function nametoslot(name) -- maybe some day rawdata
    local tfmdata = fonts.ids[font.current()]
    local shared = tfmdata and tfmdata.shared
    local fntdata = shared and shared.otfdata or shared.afmdata
    if fntdata then
        local unicode = fntdata.luatex.unicodes[name]
        if not unicode then
            return nounicode
        elseif type(unicode) == "number" then
            return unicode
        else -- multiple unicodes
            return unicode[1]
        end
    end
    return nounicode
end

fonts.nametoslot = nametoslot

function fonts.char(n) -- todo: afm en tfm
    if type(n) == "string" then
        n = nametoslot(n)
    end
    if type(n) == "number" then
        texsprint(ctxcatcodes,format("\\char%s ",n))
    end
end

-- this will become obsolete:

fonts.otf.nametoslot = nametoslot
fonts.afm.nametoslot = nametoslot

fonts.otf.char = fonts.char
fonts.afm.char = fonts.char

-- this will change ...

function fonts.showchardata(n)
    local tfmdata = fonts.ids[font.current()]
    if tfmdata then
        if type(n) == "string" then
            n = utf.byte(n)
        end
        local chr = tfmdata.characters[n]
        if chr then
            write_nl(format("%s @ %s => U%04X => %s => ",tfmdata.fullname,tfmdata.size,n,utf.char(n)) .. serialize(chr,false))
        end
    end
end

function fonts.showfontparameters()
    local tfmdata = fonts.ids[font.current()]
    if tfmdata then
        local parameters, mathconstants = tfmdata.parameters, tfmdata.MathConstants
        local hasparameters, hasmathconstants = parameters and next(parameters), mathconstants and next(mathconstants)
        if hasparameters then
            write_nl(format("%s @ %s => parameters => ",tfmdata.fullname,tfmdata.size) .. serialize(parameters,false))
        end
        if hasmathconstants then
            write_nl(format("%s @ %s => math constants => ",tfmdata.fullname,tfmdata.size) .. serialize(mathconstants,false))
        end
        if not hasparameters and not hasmathconstants then
            write_nl(format("%s @ %s => no parameters and/or mathconstants",tfmdata.fullname,tfmdata.size))
        end
    end
end

function fonts.reportdefinedfonts()
    if trace_usage then
        local t = { }
        for id, data in table.sortedhash(fonts.ids) do
            t[#t+1] = {
                format("%03i",id),
                format("%09i",data.size or 0),
                data.type                           or "real",
               (data.mode                           or "base") .. "mode",
                data.auto_expand    and "expanded"  or "",
                data.auto_protrude  and "protruded" or "",
                data.has_math       and "math"      or "",
                data.extend_factor  and "extended"  or "",
                data.slant_factor   and "slanted"   or "",
                data.name                           or "",
                data.psname                         or "",
                data.fullname                       or "",
                data.hash                           or "",
            }
        end
        formatcolumns(t,"  ")
        report_usage()
        report_usage("defined fonts:")
        report_usage()
        for k=1,#t do
            report_usage(t[k])
        end
    end
end

luatex.registerstopactions(fonts.reportdefinedfonts)

function fonts.reportusedfeatures()
    -- numbers, setups, merged
    if trace_usage then
        local t = { }
        for i=1,#numbers do
            local name = numbers[i]
            local setup = setups[name]
            local n = setup.number
            setup.number = nil -- we have no reason to show this
            t[#t+1] = { i, name, table.sequenced(setup,false,true) } -- simple mode
            setup.number = n -- restore it (normally not needed as we're done anyway)
        end
        formatcolumns(t,"  ")
        report_usage()
        report_usage("defined featuresets:")
        report_usage()
        for k=1,#t do
            report_usage(t[k])
        end
    end
end

luatex.registerstopactions(fonts.reportusedfeatures)

-- experimental mechanism for Mojca:
--
-- fonts.definetypeface {
--     name         = "mainbodyfont-light",
--     preset       = "antykwapoltawskiego-light",
-- }
--
-- fonts.definetypeface {
--     name         = "mojcasfavourite",
--     preset       = "antykwapoltawskiego",
--     normalweight = "light",
--     boldweight   = "bold",
--     width        = "condensed",
-- }

local Shapes = {
    serif = "Serif",
    sans  = "Sans",
    mono  = "Mono",
}

function fonts.definetypeface(name,t)
    if type(name) == "table" then
        -- {name=abc,k=v,...}
        t = name
    elseif t then
        if type(t) == "string" then
            -- "abc", "k=v,..."
            t = utilities.parsers.settings_to_hash(name)
        else
            -- "abc", {k=v,...}
        end
        t.name = t.name or name
    else
        -- "name=abc,k=v,..."
        t = utilities.parsers.settings_to_hash(name)
    end
    local p = t.preset and fonts.typefaces[t.preset] or { }
    local name         = t.name         or "unknowntypeface"
    local shortcut     = t.shortcut     or p.shortcut or "rm"
    local size         = t.size         or p.size     or "default"
    local shape        = t.shape        or p.shape    or "serif"
    local fontname     = t.fontname     or p.fontname or "unknown"
    local normalweight = t.normalweight or t.weight or p.normalweight or p.weight or "normal"
    local boldweight   = t.boldweight   or t.weight or p.boldweight   or p.weight or "normal"
    local normalwidth  = t.normalwidth  or t.width  or p.normalwidth  or p.width  or "normal"
    local boldwidth    = t.boldwidth    or t.width  or p.boldwidth    or p.width  or "normal"
    Shape = Shapes[shape] or "Serif"
    context.startfontclass { name }
        context.definefontsynonym( { format("%s",           Shape) }, { format("spec:%s-%s-regular-%s", fontname, normalweight, normalwidth) } )
        context.definefontsynonym( { format("%sBold",       Shape) }, { format("spec:%s-%s-regular-%s", fontname, boldweight,   boldwidth  ) } )
        context.definefontsynonym( { format("%sBoldItalic", Shape) }, { format("spec:%s-%s-italic-%s",  fontname, boldweight,   boldwidth  ) } )
        context.definefontsynonym( { format("%sItalic",     Shape) }, { format("spec:%s-%s-italic-%s",  fontname, normalweight, normalwidth) } )
    context.stopfontclass()
    local settings = table.sequenced({ features= t.features },",")
    context.dofastdefinetypeface(name, shortcut, shape, size, settings)
end
