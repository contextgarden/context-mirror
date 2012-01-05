if not modules then modules = { } end modules ['font-ctx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- At some point I will clean up the code here so that at the tex end
-- the table interface is used.

local texcount, texsetcount = tex.count, tex.setcount
local format, gmatch, match, find, lower, gsub, byte = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub, string.byte
local concat, serialize, sort, fastcopy, mergedtable = table.concat, table.serialize, table.sort, table.fastcopy, table.merged
local sortedhash, sortedkeys, sequenced = table.sortedhash, table.sortedkeys, table.sequenced
local settings_to_hash, hash_to_string = utilities.parsers.settings_to_hash, utilities.parsers.hash_to_string
local formatcolumns = utilities.formatters.formatcolumns

local tostring, next, type = tostring, next, type
local utfchar, utfbyte = utf.char, utf.byte
local round = math.round

local P, S, C, Cc, Cf, Cg, Ct, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.match

local trace_features      = false  trackers.register("fonts.features", function(v) trace_features = v end)
local trace_defining      = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local trace_usage         = false  trackers.register("fonts.usage",    function(v) trace_usage    = v end)
local trace_mapfiles      = false  trackers.register("fonts.mapfiles", function(v) trace_mapfiles = v end)
local trace_automode      = false  trackers.register("fonts.automode", function(v) trace_automode = v end)

local report_features     = logs.reporter("fonts","features")
local report_defining     = logs.reporter("fonts","defining")
local report_status       = logs.reporter("fonts","status")
local report_mapfiles     = logs.reporter("fonts","mapfiles")

local setmetatableindex   = table.setmetatableindex

local fonts               = fonts
local handlers            = fonts.handlers
local otf                 = handlers.otf -- brrr
local names               = fonts.names
local definers            = fonts.definers
local specifiers          = fonts.specifiers
local constructors        = fonts.constructors
local loggers             = fonts.loggers
local helpers             = fonts.helpers
local hashes              = fonts.hashes
local fontdata            = hashes.identifiers
local currentfont         = font.current
local texattribute        = tex.attribute

local otffeatures         = fonts.constructors.newfeatures("otf")
local registerotffeature  = otffeatures.register
local baseprocessors      = otffeatures.processors.base
local baseinitializers    = otffeatures.initializers.base

specifiers.contextsetups  = specifiers.contextsetups  or { }
specifiers.contextnumbers = specifiers.contextnumbers or { }
specifiers.contextmerged  = specifiers.contextmerged  or { }
specifiers.synonyms       = specifiers.synonyms       or { }

local setups   = specifiers.contextsetups
local numbers  = specifiers.contextnumbers
local merged   = specifiers.contextmerged
local synonyms = specifiers.synonyms

storage.register("fonts/setups" ,  setups ,  "fonts.specifiers.contextsetups" )
storage.register("fonts/numbers",  numbers,  "fonts.specifiers.contextnumbers")
storage.register("fonts/merged",   merged,   "fonts.specifiers.contextmerged")
storage.register("fonts/synonyms", synonyms, "fonts.specifiers.synonyms")

constructors.resolvevirtualtoo = true -- context specific (due to resolver)

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local nulldata = {
    name         = "nullfont",
    characters   = { },
    descriptions = { },
    properties   = { },
    parameters   = { -- lmromanregular @ 12pt
        slant         =      0, -- 1
        space         = 256377, -- 2
        space_stretch = 128188, -- 3
        space_shrink  =  85459, -- 4
        x_height      = 338952, -- 5
        quad          = 786432, -- 6
        extra_space   =  85459, -- 7
    },
}

constructors.enhanceparameters(nulldata.parameters) -- official copies for us

function definers.resetnullfont()
    -- resetting is needed because tikz misuses nullfont
    local parameters = nulldata.parameters
    --
    parameters.slant         = 0 -- 1
    parameters.space         = 0 -- 2
    parameters.space_stretch = 0 -- 3
    parameters.space_shrink  = 0 -- 4
    parameters.x_height      = 0 -- 5
    parameters.quad          = 0 -- 6
    parameters.extra_space   = 0 -- 7
    --
    constructors.enhanceparameters(parameters) -- official copies for us
    --
    definers.resetnullfont = function() end
end

commands.resetnullfont = definers.resetnullfont

setmetatableindex(fontdata, function(t,k) return nulldata end)

local chardata      = allocate() -- chardata
local descriptions  = allocate()
local parameters    = allocate()
local properties    = allocate()
local quaddata      = allocate()
local markdata      = allocate()
local xheightdata   = allocate()
local csnames       = allocate() -- namedata
local italicsdata   = allocate()

hashes.characters   = chardata
hashes.descriptions = descriptions
hashes.parameters   = parameters
hashes.properties   = properties
hashes.quads        = quaddata
hashes.marks        = markdata
hashes.xheights     = xheightdata
hashes.csnames      = csnames
hashes.italics      = italicsdata

setmetatableindex(chardata,  function(t,k)
    local characters = fontdata[k].characters
    t[k] = characters
    return characters
end)

setmetatableindex(descriptions,  function(t,k)
    local descriptions = fontdata[k].descriptions
    t[k] = descriptions
    return descriptions
end)

setmetatableindex(parameters, function(t,k)
    local parameters = fontdata[k].parameters
    t[k] = parameters
    return parameters
end)

setmetatableindex(properties, function(t,k)
    local properties = fontdata[k].properties
    t[k] = properties
    return properties
end)

setmetatableindex(quaddata, function(t,k)
    local parameters = parameters[k]
    local quad = parameters and parameters.quad or 0
    t[k] = quad
    return quad
end)

setmetatableindex(markdata, function(t,k)
    local resources = fontdata[k].resources or { }
    local marks = resources.marks or { }
    t[k] = marks
    return marks
end)

setmetatableindex(xheightdata, function(t,k)
    local parameters = parameters[k]
    local xheight = parameters and parameters.xheight or 0
    t[k] = xheight
    return quad
end)

setmetatableindex(italicsdata, function(t,k) -- is test !
    local properties = fontdata[k].properties
    local hasitalics = properties and properties.hasitalics
    if hasitalics then
        hasitalics = chardata[k] -- convenient return
    else
        hasitalics = false
    end
    t[k] = hasitalics
    return hasitalics
end)

-- this cannot be a feature initializer as there is no auto namespace
-- so we never enter the loop then; we can store the defaults in the tma
-- file (features.gpos.mkmk = 1 etc)

local needsnodemode = {
    gpos_mark2mark     = true,
    gpos_mark2base     = true,
    gpos_mark2ligature = true,
}

fonts.handlers.otf.tables.scripts.auto = "automatic fallback to latn when no dflt present"

local privatefeatures = {
    tlig = true,
    trep = true,
    anum = true,
}

local function modechecker(tfmdata,features,mode) -- we cannot adapt features as they are shared!
    if trace_features then
        report_features(serialize(features,"used"))
    end
    local rawdata   = tfmdata.shared.rawdata
    local resources = rawdata and rawdata.resources
    local script    = features.script
    if script == "auto" then
        local latn = false
        for g, list in next, resources.features do
            for f, scripts in next, list do
                if privatefeatures[f] then
                    -- skip
                elseif scripts.dflt then
                    script = "dflt"
                    break
                elseif scripts.latn then
                    latn = true
                end
            end
        end
        if script == "auto" then
            script = latn and "latn" or "dflt"
        end
        features.script = script
        if trace_automode then
            report_defining("auto script mode: using script '%s' in font '%s'",script,file.basename(tfmdata.properties.name))
        end
    end
    if mode == "auto" then
        local sequences = resources.sequences
        if sequences and #sequences > 0 then
            local script    = features.script   or "dflt"
            local language  = features.language or "dflt"
            for feature, value in next, features do
                if value then
                    local found = false
                    for i=1,#sequences do
                        local sequence = sequences[i]
                        local features = sequence.features
                        if features then
                            local scripts = features[feature]
                            if scripts then
                                local languages = scripts[script]
                                if languages and languages[language] then
                                    if found then
                                        -- more than one lookup
                                        if trace_automode then
                                            report_defining("forcing node mode in font %s for feature %s, script %s, language %s (multiple lookups)",file.basename(tfmdata.properties.name),feature,script,language)
                                        end
                                        features.mode = "node"
                                        return "node"
                                    elseif needsnodemode[sequence.type] then
                                        if trace_automode then
                                            report_defining("forcing node mode in font %s for feature %s, script %s, language %s (no base support)",file.basename(tfmdata.properties.name),feature,script,language)
                                        end
                                        features.mode = "node"
                                        return "node"
                                    else
                                        -- at least one lookup
                                        found = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return "base"
    else
        return mode
    end
end

registerotffeature {
    -- we only set the checker and leave other settings of the mode
    -- feature as they are
    name        = "mode",
    modechecker = modechecker,
}

-- -- default = true anyway
--
-- local normalinitializer = constructors.getfeatureaction("otf","initializers","node","analyze")
--
-- local function analyzeinitializer(tfmdata,value,features) -- attr
--     if value == "auto" and features then
--         value = features.init or features.medi or features.fina or features.isol or false
--     end
--     return normalinitializer(tfmdata,value,features)
-- end
--
-- registerotffeature {
--     name         = "analyze",
--     initializers = {
--         node = analyzeinitializer,
--     },
-- }

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

-- currently fonts are scaled while constructing the font, so we
-- have to do scaling of commands in the vf at that point using e.g.
-- "local scale = g.parameters.factor or 1" after all, we need to
-- work with copies anyway and scaling needs to be done at some point;
-- however, when virtual tricks are used as feature (makes more
-- sense) we scale the commands in fonts.constructors.scale (and set the
-- factor there)

local loadfont = definers.loadfont

function definers.loadfont(specification,size,id) -- overloads the one in font-def
    local variants = definers.methods.variants
    local virtualfeatures = specification.features.virtual
    if virtualfeatures and virtualfeatures.preset then
        local variant = variants[virtualfeatures.preset]
        if variant then
            return variant(specification,size,id)
        end
    else
        local tfmdata = loadfont(specification,size,id)
     -- constructors.checkvirtualid(tfmdata,id)
        return tfmdata
    end
end

local function predefined(specification)
    local variants = definers.methods.variants
    local detail = specification.detail
    if detail ~= "" and variants[detail] then
        specification.features.virtual = { preset = detail }
    end
    return specification
end

definers.registersplit("@", predefined,"virtual")

local normalize_features = otffeatures.normalize     -- should be general

local function presetcontext(name,parent,features) -- will go to con and shared
    if features == "" and find(parent,"=") then
        features = parent
        parent = ""
    end
    if features == "" then
        features = { }
    elseif type(features) == "string" then
        features = normalize_features(settings_to_hash(features))
    else
        features = normalize_features(features)
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
--~     for k,v in next, triggers do
--~         if features[v] == nil then -- not false !
--~             local vv = default_features[v]
--~             if vv then features[v] = vv end
--~         end
--~     end
    for feature,value in next, features do
        if value == nil then -- not false !
            local default = default_features[feature]
            if default ~= nil then
                features[feature] = default
            end
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
                local s = fastcopy(t)
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

-- we extend the hasher:

constructors.hashmethods.virtual = function(list)
    local s = { }
    local n = 0
    for k, v in next, list do
        n = n + 1
        s[n] = k
    end
    if n > 0 then
        sort(s)
        for i=1,n do
            local k = s[i]
            s[i] = k .. '=' .. tostring(list[k])
        end
        return concat(s,"+")
    end
end

-- end of redefine

local cache = { } -- concat might be less efficient than nested tables

local function withset(name,what)
    local zero = texattribute[0]
    local hash = zero .. "+" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = mergecontext(zero,name,what)
        cache[hash] = done
    end
    texattribute[0] = done
end

local function withfnt(name,what)
    local font = currentfont()
    local hash = font .. "*" .. name .. "*" .. what
    local done = cache[hash]
    if not done then
        done = registercontext(font,name,what)
        cache[hash] = done
    end
    texattribute[0] = done
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
    return hash_to_string(mergedtable(handlers[kind].features.defaults or {},setups[name] or {}),separator,yes,no,strict,omit)
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

definers.registersplit('*',starred,"featureset")

-- sort of xetex mode, but without [] and / as we have file: and name: etc

local space      = P(" ")
local separator  = S(";,")
local equal      = P("=")
local spaces     = space^0
local sometext   = C((1-equal-space-separator)^1)
local truevalue  = P("+") * spaces * sometext                           * Cc(true)  -- "yes"
local falsevalue = P("-") * spaces * sometext                           * Cc(false) -- "no"
local keyvalue   =                   sometext * spaces * equal * spaces * sometext
local somevalue  =                   sometext * spaces                  * Cc(true)  -- "yes"
local pattern    = Cf(Ct("") * (space + separator + Cg(keyvalue + falsevalue + truevalue + somevalue))^0, rawset)

local function colonized(specification)
    specification.features.normal = normalize_features(lpegmatch(pattern,specification.detail))
    return specification
end

definers.registersplit(":",colonized,"direct")

-- define (two steps)

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

local specification -- still needed as local ?

local getspecification = definers.getspecification

-- we can make helper macros which saves parsing (but normaly not
-- that many calls, e.g. in mk a couple of 100 and in metafun 3500)

local setdefaultfontname = context.fntsetdefname
local setsomefontname    = context.fntsetsomename
local setemptyfontsize   = context.fntsetnopsize
local setsomefontsize    = context.fntsetsomesize

function commands.definefont_one(str)
    statistics.starttiming(fonts)
    if trace_defining then
        report_defining("memory usage before: %s",statistics.memused())
        report_defining("start stage one: %s",str)
    end
    local fullname, size = lpegmatch(splitpattern,str)
    local lookup, name, sub, method, detail = getspecification(fullname)
    if not name then
        report_defining("strange definition '%s'",str)
        setdefaultfontname()
    elseif name == "unknown" then
        setdefaultfontname()
    else
        setsomefontname(name)
    end
    -- we can also use a count for the size
    if size and size ~= "" then
        local mode, size = lpegmatch(sizepattern,size)
        if size and mode then
            texcount.scaledfontmode = mode
            setsomefontsize(size)
        else
            texcount.scaledfontmode = 0
            setemptyfontsize()
        end
    elseif true then
        -- so we don't need to check in tex
        texcount.scaledfontmode = 2
        setemptyfontsize()
    else
        texcount.scaledfontmode = 0
        setemptyfontsize()
    end
    specification = definers.makespecification(str,lookup,name,sub,method,detail,size)
    if trace_defining then
        report_defining("stop stage one")
    end
end

local n = 0

-- we can also move rscale to here (more consistent)
-- the argument list will become a table

function commands.definefont_two(global,cs,str,size,inheritancemode,classfeatures,fontfeatures,classfallbacks,fontfallbacks,
        mathsize,textsize,relativeid,classgoodies,goodies)
    if trace_defining then
        report_defining("start stage two: %s (%s)",str,size)
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
    specification.name     = name
    specification.size     = size
    specification.sub      = (sub and sub ~= "" and sub) or specification.sub
    specification.mathsize = mathsize
    specification.textsize = textsize
    specification.goodies  = goodies
    specification.cs       = cs
    specification.global   = global
    if detail and detail ~= "" then
        specification.method = method or "*"
        specification.detail = detail
    elseif specification.detail and specification.detail ~= "" then
        -- already set
    elseif inheritancemode == 0 then
        -- nothing
    elseif inheritancemode == 1 then
        -- fontonly
        if fontfeatures and fontfeatures ~= "" then
            specification.method = "*"
            specification.detail = fontfeatures
        end
        if fontfallbacks and fontfallbacks ~= "" then
            specification.fallbacks = fontfallbacks
        end
    elseif inheritancemode == 2 then
        -- classonly
        if classfeatures and classfeatures ~= "" then
            specification.method = "*"
            specification.detail = classfeatures
        end
        if classfallbacks and classfallbacks ~= "" then
            specification.fallbacks = classfallbacks
        end
    elseif inheritancemode == 3 then
        -- fontfirst
        if fontfeatures and fontfeatures ~= "" then
            specification.method = "*"
            specification.detail = fontfeatures
        elseif classfeatures and classfeatures ~= "" then
            specification.method = "*"
            specification.detail = classfeatures
        end
        if fontfallbacks and fontfallbacks ~= "" then
            specification.fallbacks = fontfallbacks
        elseif classfallbacks and classfallbacks ~= "" then
            specification.fallbacks = classfallbacks
        end
    elseif inheritancemode == 4 then
        -- classfirst
        if classfeatures and classfeatures ~= "" then
            specification.method = "*"
            specification.detail = classfeatures
        elseif fontfeatures and fontfeatures ~= "" then
            specification.method = "*"
            specification.detail = fontfeatures
        end
        if classfallbacks and classfallbacks ~= "" then
            specification.fallbacks = classfallbacks
        elseif fontfallbacks and fontfallbacks ~= "" then
            specification.fallbacks = fontfallbacks
        end
    end
--~ report_defining("SIZE %s %s",size,specification.size)
    local tfmdata = definers.read(specification,size) -- id not yet known (size in spec?)
--~ report_defining("HASH AFTER %s",specification.size)
    if not tfmdata then
        report_defining("unable to define %s as \\%s",name,cs)
        texsetcount("global","lastfontid",-1)
        context.letvaluerelax(cs) -- otherwise the current definition takes the previous one
    elseif type(tfmdata) == "number" then
        if trace_defining then
            report_defining("reusing %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s, goodies: %s/%s)",
                name,tfmdata,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks,classgoodies,goodies)
        end
        csnames[tfmdata] = specification.cs
        tex.definefont(global,cs,tfmdata)
        -- resolved (when designsize is used):
        setsomefontsize(fontdata[tfmdata].parameters.size .. "sp")
        texsetcount("global","lastfontid",tfmdata)
    else
        -- setting the extra characters will move elsewhere
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        -- we use char0 as signal
        characters[0] = nil
        -- cf the spec pdf can handle this (no char in slot)
     -- characters[0x00A0] = { width = parameters.space }
     -- characters[0x2007] = { width = characters[0x0030] and characters[0x0030].width or parameters.space } -- figure
     -- characters[0x2008] = { width = characters[0x002E] and characters[0x002E].width or parameters.space } -- period
        --
        local id = font.define(tfmdata)
        csnames[id] = specification.cs
        tfmdata.properties.id = id
        definers.register(tfmdata,id) -- to be sure, normally already done
        tex.definefont(global,cs,id)
        constructors.cleanuptable(tfmdata)
        constructors.finalize(tfmdata)
        if trace_defining then
            report_defining("defining %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,id,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        -- resolved (when designsize is used):
        setsomefontsize((tfmdata.parameters.size or 655360) .. "sp")
    --~ if specification.fallbacks then
    --~     fonts.collections.prepare(specification.fallbacks)
    --~ end
        texsetcount("global","lastfontid",id)
    end
    if trace_defining then
        report_defining("memory usage after: %s",statistics.memused())
        report_defining("stop stage two")
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
        if type(specification.size) == "string" then
            specification.size = tex.sp(specification.size) or 655260
        end
        --
        specification.specification = "" -- not used
        specification.resolved      = ""
        specification.forced        = ""
        specification.features      = { } -- via detail, maybe some day
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
            tfmdata.properties.id = id
            definers.register(tfmdata,id)
            if specification.cs then
                tex.definefont(specification.global,specification.cs,id)
            end
            constructors.cleanuptable(tfmdata)
            constructors.finalize(tfmdata)
            return id, tfmdata
        end
        statistics.stoptiming(fonts)
    end
end

local enable_auto_r_scale = false

experiments.register("fonts.autorscale", function(v)
    enable_auto_r_scale = v
end)

-- Not ok, we can best use a database for this. The problem is that we
-- have delayed definitions and so we never know what style is taken
-- as start.

local calculatescale  = constructors.calculatescale

function constructors.calculatescale(tfmdata,scaledpoints,relativeid)
    local scaledpoints, delta = calculatescale(tfmdata,scaledpoints)
--~     if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific
--~         local relativedata = fontdata[relativeid]
--~         local rfmdata = relativedata and relativedata.unscaled and relativedata.unscaled
--~         local id_x_height = rfmdata and rfmdata.parameters and rfmdata.parameters.x_height
--~         local tf_x_height = tfmdata and tfmdata.parameters and tfmdata.parameters.x_height
--~         if id_x_height and tf_x_height then
--~             local rscale = id_x_height/tf_x_height
--~             delta = rscale * delta
--~             scaledpoints = rscale * scaledpoints
--~         end
--~     end
    return scaledpoints, delta
end

-- soon to be obsolete:

local mappings = fonts.mappings

local loaded = { -- prevent loading (happens in cont-sys files)
    ["original-base.map"     ] = true,
    ["original-ams-base.map" ] = true,
    ["original-ams-euler.map"] = true,
    ["original-public-lm.map"] = true,
}

function mappings.loadfile(name)
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

function mappings.loadline(how,line)
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

function mappings.reset()
    pdf.mapfile("")
end

mappings.reset() -- resets the default file

-- we need an 'do after the banner hook'

-- => commands

local function nametoslot(name)
    local t = type(name)
    if t == "string" then
        local tfmdata = fonts.hashes.identifiers[currentfont()]
        local shared  = tfmdata and tfmdata.shared
        local fntdata = shared and shared.rawdata
        return fntdata and fntdata.resources.unicodes[name]
    elseif t == "number" then
        return n
    end
end

helpers.nametoslot = nametoslot

-- this will change ...

function loggers.reportdefinedfonts()
    if trace_usage then
        local t, tn = { }, 0
        for id, data in sortedhash(fontdata) do
            local properties = data.properties or { }
            local parameters = data.parameters or { }
            tn = tn + 1
            t[tn] = {
  format("%03i",id                       or 0),
  format("%09i",parameters.size     or 0),
                properties.type     or "real",
                properties.format   or "unknown",
                properties.name     or "",
                properties.psname   or "",
                properties.fullname or "",
            }
report_status("%s: %s",properties.name,concat(sortedkeys(data)," "))
        end
        formatcolumns(t,"  ")
        report_status()
        report_status("defined fonts:")
        report_status()
        for k=1,tn do
            report_status(t[k])
        end
    end
end

luatex.registerstopactions(loggers.reportdefinedfonts)

function loggers.reportusedfeatures()
    -- numbers, setups, merged
    if trace_usage then
        local t, n = { }, #numbers
        for i=1,n do
            local name = numbers[i]
            local setup = setups[name]
            local n = setup.number
            setup.number = nil -- we have no reason to show this
            t[i] = { i, name, sequenced(setup,false,true) } -- simple mode
            setup.number = n -- restore it (normally not needed as we're done anyway)
        end
        formatcolumns(t,"  ")
        report_status()
        report_status("defined featuresets:")
        report_status()
        for k=1,n do
            report_status(t[k])
        end
    end
end

luatex.registerstopactions(loggers.reportusedfeatures)

statistics.register("fonts load time", function()
    return statistics.elapsedseconds(fonts)
end)

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
            t = settings_to_hash(name)
        else
            -- "abc", {k=v,...}
        end
        t.name = t.name or name
    else
        -- "name=abc,k=v,..."
        t = settings_to_hash(name)
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
    local settings = sequenced({ features= t.features },",")
    context.dofastdefinetypeface(name, shortcut, shape, size, settings)
end

function fonts.current() -- todo: also handle name
    return fontdata[currentfont()] or fontdata[0]
end

function fonts.currentid()
    return currentfont() or 0
end

-- interfaces

function commands.fontchar(n)
    n = nametoslot(n)
    if n then
        context.char(n)
    end
end

function commands.doifelsecurrentfonthasfeature(name) -- can be made faster with a supportedfeatures hash
    local f = fontdata[currentfont()]
    f = f and f.shared
    f = f and f.rawdata
    f = f and f.resources
    f = f and f.features
    commands.doifelse(f and (f.gpos[name] or f.gsub[name]))
end

local p, f = 1, "%0.1fpt" -- normally this value is changed only once

local stripper = lpeg.patterns.stripzeros

function commands.nbfs(amount,precision)
    if precision ~= p then
        p = precision
        f = "%0." .. p .. "fpt"
    end
    context(lpegmatch(stripper,format(f,amount/65536)))
end

function commands.featureattribute(tag)
    context(contextnumber(tag))
end

function commands.setfontfeature(tag)
    texattribute[0] = contextnumber(tag)
end

function commands.resetfontfeature()
    texattribute[0] = 0
end

function commands.addfs(tag) withset(tag, 1) end
function commands.subfs(tag) withset(tag,-1) end
function commands.addff(tag) withfnt(tag, 2) end
function commands.subff(tag) withfnt(tag,-2) end

-- function commands.addfontfeaturetoset        (tag) withset(tag, 1) end
-- function commands.subtractfontfeaturefromset (tag) withset(tag,-1) end
-- function commands.addfontfeaturetofont       (tag) withfnt(tag, 2) end
-- function commands.subtractfontfeaturefromfont(tag) withfnt(tag,-2) end

function commands.cleanfontname          (name)      context(names.cleanname(name))         end

function commands.fontlookupinitialize   (name)      names.lookup(name)                     end
function commands.fontlookupnoffound     ()          context(names.noflookups())            end
function commands.fontlookupgetkeyofindex(key,index) context(names.getlookupkey(key,index)) end
function commands.fontlookupgetkey       (key)       context(names.getlookupkey(key))       end

-- this might move to a runtime module:

function commands.showchardata(n)
    local tfmdata = fontdata[currentfont()]
    if tfmdata then
        if type(n) == "string" then
            n = utfbyte(n)
        end
        local chr = tfmdata.characters[n]
        if chr then
            report_status("%s @ %s => U%05X => %s => %s",tfmdata.properties.fullname,tfmdata.parameters.size,n,utfchar(n),serialize(chr,false))
        end
    end
end

function commands.showfontparameters(tfmdata)
    -- this will become more clever
    local tfmdata = tfmdata or fontdata[currentfont()]
    if tfmdata then
        local parameters        = tfmdata.parameters
        local mathparameters    = tfmdata.mathparameters
        local properties        = tfmdata.properties
        local hasparameters     = parameters     and next(parameters)
        local hasmathparameters = mathparameters and next(mathparameters)
        if hasparameters then
            report_status("%s @ %s => text parameters => %s",properties.fullname,parameters.size,serialize(parameters,false))
        end
        if hasmathparameters then
            report_status("%s @ %s => math parameters => %s",properties.fullname,parameters.size,serialize(mathparameters,false))
        end
        if not hasparameters and not hasmathparameters then
            report_status("%s @ %s => no text parameters and/or math parameters",properties.fullname,parameters.size)
        end
    end
end

-- for the moment here, this will become a chain of extras that is
-- hooked into the ctx registration (or scaler or ...)

local dimenfactors = number.dimenfactors

function helpers.dimenfactor(unit,tfmdata) -- could be a method of a font instance
    if unit == "ex" then
        return (tfmdata and tfmdata.parameters.x_height) or 655360
    elseif unit == "em" then
        return (tfmdata and tfmdata.parameters.em_width) or 655360
    else
        return dimenfactors[unit] or unit
    end
end

local function digitwidth(font) -- max(quad/2,wd(0..9))
    local tfmdata = fontdata[font]
    local parameters = tfmdata.parameters
    local width = parameters.digitwidth
    if not width then
        width = round(parameters.quad/2) -- maybe tex.scale
        local characters = tfmdata.characters
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

helpers.getdigitwidth = digitwidth
helpers.setdigitwidth = digitwidth

--

function helpers.getparameters(tfmdata)
    local p = { }
    local m = p
    local parameters = tfmdata.parameters
    while true do
        for k, v in next, parameters do
            m[k] = v
        end
        parameters = getmetatable(parameters)
        parameters = parameters and parameters.__index
        if type(parameters) == "table" then
            m = { }
            p.metatable = m
        else
            break
        end
    end
    return p
end

if environment.initex then

    local function names(t)
        local nt = #t
        if nt > 0 then
            local n = { }
            for i=1,nt do
                n[i] = t[i].name
            end
            return concat(n," ")
        else
            return "-"
        end
    end

    statistics.register("font processing", function()
        local l = { }
        for what, handler in table.sortedpairs(handlers) do
            local features = handler.features
            if features then
                l[#l+1] = format("[%s (base initializers: %s) (base processors: %s) (base manipulators: %s) (node initializers: %s) (node processors: %s) (node manipulators: %s)]",
                    what,
                    names(features.initializers.base),
                    names(features.processors  .base),
                    names(features.manipulators.base),
                    names(features.initializers.node),
                    names(features.processors  .node),
                    names(features.manipulators.node)
                )
            end
        end
        return concat(l, " | ")
    end)

end

-- redefinition

local quads       = hashes.quads
local xheights    = hashes.xheights
local currentfont = font.current
local texdimen    = tex.dimen

setmetatableindex(number.dimenfactors, function(t,k)
    if k == "ex" then
        return xheigths[currentfont()]
    elseif k == "em" then
        return quads[currentfont()]
    elseif k == "%" then
        return dimen.hsize/100
    else
     -- error("wrong dimension: " .. (s or "?")) -- better a message
        return false
    end
end)

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

-- function constructors.getvirtualid(tfmdata)
--     --  since we don't know the id yet, we use 0 as signal
--     local tf = tfmdata.fonts
--     if not tf then
--         local properties = tfmdata.properties
--         if properties then
--             properties.virtualized = true
--         else
--             tfmdata.properties = { virtualized = true }
--         end
--         tf = { }
--         tfmdata.fonts = tf
--     end
--     local ntf = #tf + 1
--     tf[ntf] = { id = 0 }
--     return ntf
-- end
--
-- function constructors.checkvirtualid(tfmdata, id) -- will go
--     local properties = tfmdata.properties
--     if tfmdata and tfmdata.type == "virtual" or (properties and properties.virtualized) then
--         local vfonts = tfmdata.fonts
--         if not vffonts or #vfonts == 0 then
--             if properties then
--                 properties.virtualized = false
--             end
--             tfmdata.fonts = nil
--         else
--             for f=1,#vfonts do
--                 local fnt = vfonts[f]
--                 if fnt.id and fnt.id == 0 then
--                     fnt.id = id
--                 end
--             end
--         end
--     end
-- end

function commands.setfontofid(id)
    context.getvalue(csnames[id])
end
