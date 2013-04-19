if not modules then modules = { } end modules ['font-ctx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- At some point I will clean up the code here so that at the tex end
-- the table interface is used.
--
-- Todo: make a proper 'next id' mechanism (register etc) or wait till 'true'
-- in virtual fonts indices is implemented.

local context, commands = context, commands

local texcount, texsetcount = tex.count, tex.setcount
local format, gmatch, match, find, lower, gsub, byte = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub, string.byte
local concat, serialize, sort, fastcopy, mergedtable = table.concat, table.serialize, table.sort, table.fastcopy, table.merged
local sortedhash, sortedkeys, sequenced = table.sortedhash, table.sortedkeys, table.sequenced
local settings_to_hash, hash_to_string = utilities.parsers.settings_to_hash, utilities.parsers.hash_to_string
local formatcolumns = utilities.formatters.formatcolumns
local mergehashes = utilities.parsers.mergehashes

local tostring, next, type, rawget = tostring, next, type, rawget
local utfchar, utfbyte = utf.char, utf.byte
local round = math.round

local P, S, C, Cc, Cf, Cg, Ct, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.match

local trace_features      = false  trackers.register("fonts.features",   function(v) trace_features   = v end)
local trace_defining      = false  trackers.register("fonts.defining",   function(v) trace_defining   = v end)
local trace_designsize    = false  trackers.register("fonts.designsize", function(v) trace_designsize = v end)
local trace_usage         = false  trackers.register("fonts.usage",      function(v) trace_usage      = v end)
local trace_mapfiles      = false  trackers.register("fonts.mapfiles",   function(v) trace_mapfiles   = v end)
local trace_automode      = false  trackers.register("fonts.automode",   function(v) trace_automode   = v end)

local report_features     = logs.reporter("fonts","features")
local report_cummulative  = logs.reporter("fonts","cummulative")
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
local fontgoodies         = fonts.goodies
local helpers             = fonts.helpers
local hashes              = fonts.hashes
local currentfont         = font.current
local texattribute        = tex.attribute

local fontdata            = hashes.identifiers
local characters          = hashes.chardata
local descriptions        = hashes.descriptions
local properties          = hashes.properties
local resources           = hashes.resources
local csnames             = hashes.csnames
local marks               = hashes.markdata
local lastmathids         = hashes.lastmathids

local designsizefilename  = fontgoodies.designsizes.filename

local otffeatures         = handlers.otf.features
local registerotffeature  = otffeatures.register
local baseprocessors      = otffeatures.processors.base
local baseinitializers    = otffeatures.initializers.base

local sequencers          = utilities.sequencers
local appendgroup         = sequencers.appendgroup
local appendaction        = sequencers.appendaction

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

-- inspect(setups)

if environment.initex then
    setmetatableindex(setups,function(t,k)
        return type(k) == "number" and rawget(t,numbers[k]) or nil
    end)
else
    setmetatableindex(setups,function(t,k)
        local v = type(k) == "number" and rawget(t,numbers[k])
        if v then
            t[k] = v
            return v
        end
    end)
end

-- this will move elsewhere ...

utilities.strings.formatters.add(string.formatters,"font:name",    [["'"..file.basename(%s.properties.name).."'"]])
utilities.strings.formatters.add(string.formatters,"font:features",[["'"..table.sequenced(%s," ",true).."'"]])

-- ... like font-sfm or so

constructors.resolvevirtualtoo = true -- context specific (due to resolver)

local limited = false

directives.register("system.inputmode", function(v)
    if not limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            fontloader.open = i_limiter.protect(fontloader.open)
            fontloader.info = i_limiter.protect(fontloader.info)
            limited = true
        end
    end
end)

function definers.resetnullfont()
    -- resetting is needed because tikz misuses nullfont
    local parameters = fonts.nulldata.parameters
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

local function checkedscript(tfmdata,resources,features)
    local latn = false
    local script = false
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
    if not script then
        script = latn and "latn" or "dflt"
    end
    if trace_automode then
        report_defining("auto script mode, using script %a in font %!font:name!",script,tfmdata)
    end
    features.script = script
    return script
end

local function checkedmode(tfmdata,resources,features)
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
                                        report_defining("forcing mode %a, font %!font:name!, feature %a, script %a, language %a, %s",
                                            "node",tfmdata,feature,script,language,"multiple lookups")
                                    end
                                    features.mode = "node"
                                    return "node"
                                elseif needsnodemode[sequence.type] then
                                    if trace_automode then
                                        report_defining("forcing mode %a, font %!font:name!, feature %a, script %a, language %a, %s",
                                            "node",tfmdata,feature,script,language,"no base support")
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
    features.mode = "base" -- new, or is this wrong?
    return "base"
end

definers.checkedscript = checkedscript
definers.checkedmode   = checkedmode

local function modechecker(tfmdata,features,mode) -- we cannot adapt features as they are shared!
    if trace_features then
        report_features("fontname %!font:name!, features %!font:features!",tfmdata,features)
    end
    local rawdata   = tfmdata.shared.rawdata
    local resources = rawdata and rawdata.resources
    local script    = features.script
    if resources then
        if script == "auto" then
            script = checkedscript(tfmdata,resources,features)
        end
        if mode == "auto" then
            mode = checkedmode(tfmdata,resources,features)
        end
    else
        report_features("missing resources for font %!font:name!",tfmdata)
    end
    return mode
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

local beforecopyingcharacters = sequencers.new {
    name      = "beforecopyingcharacters",
    arguments = "target,original",
}

appendgroup(beforecopyingcharacters,"before") -- user
appendgroup(beforecopyingcharacters,"system") -- private
appendgroup(beforecopyingcharacters,"after" ) -- user

function constructors.beforecopyingcharacters(original,target)
    local runner = beforecopyingcharacters.runner
    if runner then
        runner(original,target)
    end
end

local aftercopyingcharacters = sequencers.new {
    name      = "aftercopyingcharacters",
    arguments = "target,original",
}

appendgroup(aftercopyingcharacters,"before") -- user
appendgroup(aftercopyingcharacters,"system") -- private
appendgroup(aftercopyingcharacters,"after" ) -- user

function constructors.aftercopyingcharacters(original,target)
    local runner = aftercopyingcharacters.runner
    if runner then
        runner(original,target)
    end
end

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

local function definecontext(name,t) -- can be shared
    local number = setups[name] and setups[name].number or 0 -- hm, numbers[name]
    if number == 0 then
        number = #numbers + 1
        numbers[number] = name
    end
    t.number = number
    setups[name] = t
    return number, t
end

local function presetcontext(name,parent,features) -- will go to con and shared
    if features == "" and find(parent,"=") then
        features = parent
        parent = ""
    end
    if not features or features == "" then
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
            else
                -- just ignore an undefined one .. i.e. we can refer to not yet defined
            end
        end
    end
    -- these are auto set so in order to prevent redundant definitions
    -- we need to preset them (we hash the features and adding a default
    -- setting during initialization may result in a different hash)
    --
    -- for k,v in next, triggers do
    --     if features[v] == nil then -- not false !
    --         local vv = default_features[v]
    --         if vv then features[v] = vv end
    --     end
    -- end
    --
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
--         if v then t[k] = v end
        t[k] = v
    end
    -- needed for dynamic features
    -- maybe number should always be renewed as we can redefine features
    local number = setups[name] and setups[name].number or 0 -- hm, numbers[name]
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

local function mergecontext(currentnumber,extraname,option) -- number string number (used in scrp-ini
    local extra = setups[extraname]
    if extra then
        local current = setups[numbers[currentnumber]]
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

local extrasets = { }

setmetatableindex(extrasets,function(t,k)
    local v = mergehashes(setups,k)
    t[k] = v
    return v
end)

local function mergecontextfeatures(currentname,extraname,how,mergedname) -- string string
    local extra = setups[extraname] or extrasets[extraname]
    if extra then
        local current = setups[currentname]
        local mergedfeatures = { }
        if how == "+" then
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
        elseif how == "-" then
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                -- only boolean features
                if v == true then
                    mergedfeatures[k] = false
                end
            end
        else -- =
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number
    else
        return numbers[currentname] or 0
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

local function registercontextfeature(mergedname,extraname,how)
    local extra = setups[extraname]
    if extra then
        local mergedfeatures = { }
        for k, v in next, extra do
            mergedfeatures[k] = v
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = how == "=" and 1 or 2 -- 1=replace, 2=combine
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
specifiers.definecontext   = definecontext

-- we extend the hasher:

constructors.hashmethods.virtual = function(list)
    local s = { }
    local n = 0
    for k, v in next, list do
        n = n + 1
        s[n] = k -- no checking on k
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

-- local withcache = { } -- concat might be less efficient than nested tables
--
-- local function withset(name,what)
--     local zero = texattribute[0]
--     local hash = zero .. "+" .. name .. "*" .. what
--     local done = withcache[hash]
--     if not done then
--         done = mergecontext(zero,name,what)
--         withcache[hash] = done
--     end
--     texattribute[0] = done
-- end
--
-- local function withfnt(name,what,font)
--     local font = font or currentfont()
--     local hash = font .. "*" .. name .. "*" .. what
--     local done = withcache[hash]
--     if not done then
--         done = registercontext(font,name,what)
--         withcache[hash] = done
--     end
--     texattribute[0] = done
-- end

function specifiers.showcontext(name)
    return setups[name] or setups[numbers[name]] or setups[numbers[tonumber(name)]] or { }
end

-- we need a copy as we will add (fontclass) goodies to the features and
-- that is bad for a shared table

-- local function splitcontext(features) -- presetcontext creates dummy here
--     return fastcopy(setups[features] or (presetcontext(features,"","") and setups[features]))
-- end

local function splitcontext(features) -- presetcontext creates dummy here
    local sf = setups[features]
    if not sf then
        local n -- number
        if find(features,",") then
            -- let's assume a combination which is not yet defined but just specified (as in math)
            n, sf = presetcontext(features,features,"")
        else
            -- we've run into an unknown feature and or a direct spec so we create a dummy
            n, sf = presetcontext(features,"","")
        end
    end
    return fastcopy(sf)
end

-- local splitter = lpeg.splitat("=")
--
-- local function splitcontext(features)
--     local setup = setups[features]
--     if setup then
--         return setup
--     elseif find(features,",") then
--         -- This is not that efficient but handy anyway for quick and dirty tests
--         -- beware, due to the way of caching setups you can get the wrong results
--         -- when components change. A safeguard is to nil the cache.
--         local merge = nil
--         for feature in gmatch(features,"[^, ]+") do
--             if find(feature,"=") then
--                 local k, v = lpegmatch(splitter,feature)
--                 if k and v then
--                     if not merge then
--                         merge = { k = v }
--                     else
--                         merge[k] = v
--                     end
--                 end
--             else
--                 local s = setups[feature]
--                 if not s then
--                     -- skip
--                 elseif not merge then
--                     merge = s
--                 else
--                     for k, v in next, s do
--                         merge[k] = v
--                     end
--                 end
--             end
--         end
--         setup = merge and presetcontext(features,"",merge) and setups[features]
--         -- actually we have to nil setups[features] in order to permit redefinitions
--         setups[features] = nil
--     end
--     return setup or (presetcontext(features,"","") and setups[features]) -- creates dummy
-- end

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

function helpers.splitfontpattern(str)
    local name, size = lpegmatch(splitpattern,str)
    local kind, size = lpegmatch(sizepattern,size)
    return name, kind, size
end

function helpers.fontpatternhassize(str)
    local name, size = lpegmatch(splitpattern,str)
    local kind, size = lpegmatch(sizepattern,size)
    return size or false
end

local specification -- still needed as local ?

local getspecification = definers.getspecification

-- we can make helper macros which saves parsing (but normaly not
-- that many calls, e.g. in mk a couple of 100 and in metafun 3500)

local setdefaultfontname = context.fntsetdefname
local setsomefontname    = context.fntsetsomename
local setemptyfontsize   = context.fntsetnopsize
local setsomefontsize    = context.fntsetsomesize
local letvaluerelax      = context.letvaluerelax

function commands.definefont_one(str)
    statistics.starttiming(fonts)
    if trace_defining then
        report_defining("memory usage before: %s",statistics.memused())
        report_defining("start stage one: %s",str)
    end
    local fullname, size = lpegmatch(splitpattern,str)
    local lookup, name, sub, method, detail = getspecification(fullname)
    if not name then
        report_defining("strange definition %a",str)
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

local function nice_cs(cs)
    return (gsub(cs,".->", ""))
end

function commands.definefont_two(global,cs,str,size,inheritancemode,classfeatures,fontfeatures,classfallbacks,fontfallbacks,
        mathsize,textsize,relativeid,classgoodies,goodies,classdesignsize,fontdesignsize)
    if trace_defining then
        report_defining("start stage two: %s (size %s)",str,size)
    end
    -- name is now resolved and size is scaled cf sa/mo
    local lookup, name, sub, method, detail = getspecification(str or "")
    -- new (todo: inheritancemode)
    local designsize = fontdesignsize ~= "" and fontdesignsize or classdesignsize or ""
    local designname = designsizefilename(name,designsize,size)
    if designname and designname ~= "" then
        if trace_defining or trace_designsize then
            report_defining("remapping name %a, specification %a, size %a, designsize %a",name,designsize,size,designname)
        end
        -- we don't catch detail here
        local o_lookup, o_name, o_sub, o_method, o_detail = getspecification(designname)
        if o_lookup and o_lookup ~= "" then lookup = o_lookup end
        if o_method and o_method ~= "" then method = o_method end
        if o_detail and o_detail ~= "" then detail = o_detail end
        name = o_name
        sub = o_sub
    end
    -- so far
    -- some settings can have been overloaded
    if lookup and lookup ~= "" then
        specification.lookup = lookup
    end
    if relativeid and relativeid ~= "" then -- experimental hook
        local id = tonumber(relativeid) or 0
        specification.relativeid = id > 0 and id
    end
    specification.name      = name
    specification.size      = size
    specification.sub       = (sub and sub ~= "" and sub) or specification.sub
    specification.mathsize  = mathsize
    specification.textsize  = textsize
    specification.goodies   = goodies
    specification.cs        = cs
    specification.global    = global
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
    local tfmdata = definers.read(specification,size) -- id not yet known (size in spec?)
    --
    local lastfontid = 0
    if not tfmdata then
        report_defining("unable to define %a as %a",name,nice_cs(cs))
        lastfontid = -1
        letvaluerelax(cs) -- otherwise the current definition takes the previous one
    elseif type(tfmdata) == "number" then
        if trace_defining then
            report_defining("reusing %s, id %a, target %a, features %a / %a, fallbacks %a / %a, goodies %a / %a, designsize %a / %a",
                name,tfmdata,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,classgoodies,goodies,classdesignsize,fontdesignsize)
        end
        csnames[tfmdata] = specification.cs
        tex.definefont(global,cs,tfmdata)
        -- resolved (when designsize is used):
        setsomefontsize((fontdata[tfmdata].parameters.size or 0) .. "sp")
        lastfontid = tfmdata
    else
        -- setting the extra characters will move elsewhere
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        -- we use char0 as signal; cf the spec pdf can handle this (no char in slot)
        characters[0] = nil
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
            report_defining("defining %a, id %a, target %a, features %a / %a, fallbacks %a / %a",
                name,id,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        -- resolved (when designsize is used):
        setsomefontsize((tfmdata.parameters.size or 655360) .. "sp")
        lastfontid = id
    end
    if trace_defining then
        report_defining("memory usage after: %s",statistics.memused())
        report_defining("stop stage two")
    end
    --
    texsetcount("global","lastfontid",lastfontid)
    if not mathsize then
        -- forget about it
    elseif mathsize == 0 then
        lastmathids[1] = lastfontid
    else
        lastmathids[mathsize] = lastfontid
    end
    --
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
 -- if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific
 --     local relativedata = fontdata[relativeid]
 --     local rfmdata = relativedata and relativedata.unscaled and relativedata.unscaled
 --     local id_x_height = rfmdata and rfmdata.parameters and rfmdata.parameters.x_height
 --     local tf_x_height = tfmdata and tfmdata.parameters and tfmdata.parameters.x_height
 --     if id_x_height and tf_x_height then
 --         local rscale = id_x_height/tf_x_height
 --         delta = rscale * delta
 --         scaledpoints = rscale * scaledpoints
 --     end
 -- end
    return scaledpoints, delta
end

-- We overload the (generic) resolver:

local resolvers    = definers.resolvers
local hashfeatures = constructors.hashfeatures

function definers.resolve(specification) -- overload function in font-con.lua
    if not specification.resolved or specification.resolved == "" then -- resolved itself not per se in mapping hash
        local r = resolvers[specification.lookup]
        if r then
            r(specification)
        end
    end
    if specification.forced == "" then
        specification.forced = nil
    else
        specification.forced = specification.forced
    end
    -- goodies are a context specific thing and not always defined
    -- as feature, so we need to make sure we add them here before
    -- hashing because otherwise we get funny goodies applied
    local goodies = specification.goodies
    if goodies and goodies ~= "" then
        -- this adapts the features table so it has best be a copy
        local normal = specification.features.normal
        if not normal then
            specification.features.normal = { goodies = goodies }
        elseif not normal.goodies then
            local g = normal.goodies
            if g and g ~= "" then
                normal.goodies = format("%s,%s",g,goodies)
            else
                normal.goodies = goodies
            end
        end
    end
    -- so far for goodie hacks
    specification.hash = lower(specification.name .. ' @ ' .. hashfeatures(specification))
    if specification.sub and specification.sub ~= "" then
        specification.hash = specification.sub .. ' @ ' .. specification.hash
    end
    return specification
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
            report_mapfiles("loading map file %a",name)
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
            report_mapfiles("processing map line %a",line)
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
        return resources[true].unicodes[name]
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
  format("%03i",id                  or 0),
  format("%09i",parameters.size     or 0),
                properties.type     or "real",
                properties.format   or "unknown",
                properties.name     or "",
                properties.psname   or "",
                properties.fullname or "",
            }
            report_status("%s: % t",properties.name,sortedkeys(data))
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

-- function commands.addfs(tag) withset(tag, 1) end
-- function commands.subfs(tag) withset(tag,-1) end
-- function commands.addff(tag) withfnt(tag, 2) end -- on top of font features
-- function commands.subff(tag) withfnt(tag,-2) end -- on top of font features

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
            report_status("%s @ %s => %U => %c => %s",tfmdata.properties.fullname,tfmdata.parameters.size,n,n,serialize(chr,false))
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
        local du = dimenfactors[unit]
        return du and 1/du or tonumber(unit) or 1
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

function constructors.checkvirtualids(tfmdata)
    -- begin of experiment: we can use { "slot", 0, number } in virtual fonts
    local fonts = tfmdata.fonts
    local selfid = font.nextid()
    if fonts and #fonts > 0 then
        for i=1,#fonts do
            if fonts[i][2] == 0 then
                fonts[i][2] = selfid
            end
        end
    else
     -- tfmdata.fonts = { "id", selfid } -- conflicts with other next id's (vf math), too late anyway
    end
    -- end of experiment
end

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

-- more interfacing:

commands.definefontfeature = presetcontext

local cache = { }

local hows = {
    ["+"] = "add",
    ["-"] = "subtract",
    ["="] = "replace",
}

function commands.feature(how,parent,name,font)
    if not how then
        if trace_features and texattribute[0] ~= 0 then
            report_cummulative("font %!font:name!, reset",fontdata[font or true])
        end
        texattribute[0] = 0
    elseif how == true then
        local hash = "feature > " .. parent
        local done = cache[hash]
        if trace_features and done then
            report_cummulative("font %!font:name!, revive %a : %!font:features!",fontdata[font or true],parent,setups[numbers[done]])
        end
        texattribute[0] = done or 0
    else
        local full = parent .. how .. name
        local hash = "feature > " .. full
        local done = cache[hash]
        if not done then
            local n = setups[full]
            if n then
                -- already defined
            else
                n = mergecontextfeatures(parent,name,how,full)
            end
            done = registercontextfeature(hash,full,how)
            cache[hash] = done
            if trace_features then
                report_cummulative("font %!font:name!, %s %a : %!font:features!",fontdata[font or true],hows[how],full,setups[numbers[done]])
            end
        end
        texattribute[0] = done
    end
end

function commands.featurelist(...)
    context(fonts.specifiers.contexttostring(...))
end

function commands.registerlanguagefeatures()
    local specifications = languages.data.specifications
    for i=1,#specifications do
        local specification = specifications[i]
        local language = specification.opentype
        if language then
            local script = specification.opentypescript or specification.script
            if script then
                local context = specification.context
                if type(context) == "table" then
                    for i=1,#context do
                        definecontext(context[i], { language = language, script = script})
                    end
                elseif type(context) == "string" then
                   definecontext(context, { language = language, script = script})
                end
            end
        end
    end
end

-- a fontkern plug:

local copy_node = node.copy
local kern      = nodes.pool.register(nodes.pool.kern())

node.set_attribute(kern,attributes.private('fontkern'),1) -- we can have several, attributes are shared

nodes.injections.installnewkern(function(k)
    local c = copy_node(kern)
    c.kern = k
    return c
end)

directives.register("nodes.injections.fontkern", function(v) kern.subtype = v and 0 or 1 end)

-- here

local trace_analyzing    = false  trackers.register("otf.analyzing", function(v) trace_analyzing = v end)

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local analyzers          = fonts.analyzers
local methods            = analyzers.methods

local unsetvalue         = attributes.unsetvalue

local traverse_by_id     = node.traverse_id

local a_color            = attributes.private('color')
local a_colormodel       = attributes.private('colormodel')
local a_state            = attributes.private('state')
local m_color            = attributes.list[a_color] or { }

local glyph_code         = nodes.nodecodes.glyph

local states             = analyzers.states

local names = {
    [states.init] = "font:1",
    [states.medi] = "font:2",
    [states.fina] = "font:3",
    [states.isol] = "font:4",
    [states.mark] = "font:5",
    [states.rest] = "font:6",
    [states.rphf] = "font:1",
    [states.half] = "font:2",
    [states.pref] = "font:3",
    [states.blwf] = "font:4",
    [states.pstf] = "font:5",
}

local function markstates(head)
    if head then
        local model = head[a_colormodel] or 1
        for glyph in traverse_by_id(glyph_code,head) do
            local a = glyph[a_state]
            if a then
                local name = names[a]
                if name then
                    local color = m_color[name]
                    if color then
                        glyph[a_colormodel] = model
                        glyph[a_color] = color
                    end
                end
            end
        end
    end
end

local function analyzeprocessor(head,font,attr)
    local tfmdata = fontdata[font]
    local script, language = otf.scriptandlanguage(tfmdata,attr)
    local action = methods[script]
    if not action then
        return head, false
    end
    if type(action) == "function" then
        local head, done = action(head,font,attr)
        if done and trace_analyzing then
            markstates(head)
        end
        return head, done
    end
    action = action[language]
    if action then
        local head, done = action(head,font,attr)
        if done and trace_analyzing then
            markstates(head)
        end
        return head, done
    else
        return head, false
    end
end

registerotffeature { -- adapts
    name         = "analyze",
    processors = {
        node     = analyzeprocessor,
    }
}

function methods.nocolor(head,font,attr)
    for n in traverse_by_id(glyph_code,head) do
        if not font or n.font == font then
            n[a_color] = unsetvalue
        end
    end
    return head, true
end
