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

local format, gmatch, match, find, lower, gsub, byte, topattern = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub, string.byte, string.topattern
local concat, serialize, sort, fastcopy, mergedtable = table.concat, table.serialize, table.sort, table.fastcopy, table.merged
local sortedhash, sortedkeys, sequenced = table.sortedhash, table.sortedkeys, table.sequenced
local settings_to_hash, hash_to_string = utilities.parsers.settings_to_hash, utilities.parsers.hash_to_string
local formatcolumns = utilities.formatters.formatcolumns
local mergehashes = utilities.parsers.mergehashes
local formatters = string.formatters
local basename = file.basename

local tostring, next, type, rawget, tonumber = tostring, next, type, rawget, tonumber
local utfchar, utfbyte = utf.char, utf.byte
local round = math.round

local P, S, C, Cc, Cf, Cg, Ct, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.match

local trace_features      = false  trackers.register("fonts.features",   function(v) trace_features   = v end)
local trace_defining      = false  trackers.register("fonts.defining",   function(v) trace_defining   = v end)
local trace_designsize    = false  trackers.register("fonts.designsize", function(v) trace_designsize = v end)
local trace_usage         = false  trackers.register("fonts.usage",      function(v) trace_usage      = v end)
local trace_mapfiles      = false  trackers.register("fonts.mapfiles",   function(v) trace_mapfiles   = v end)
local trace_automode      = false  trackers.register("fonts.automode",   function(v) trace_automode   = v end)
local trace_merge         = false  trackers.register("fonts.merge",      function(v) trace_merge      = v end)

local report_features     = logs.reporter("fonts","features")
local report_cummulative  = logs.reporter("fonts","cummulative")
local report_defining     = logs.reporter("fonts","defining")
local report_status       = logs.reporter("fonts","status")
local report_mapfiles     = logs.reporter("fonts","mapfiles")
local report_newline      = logs.newline

local setmetatableindex   = table.setmetatableindex

local implement           = interfaces.implement

local fonts               = fonts
local handlers            = fonts.handlers
local otf                 = handlers.otf -- brrr
local afm                 = handlers.afm -- brrr
local tfm                 = handlers.tfm -- brrr
local names               = fonts.names
local definers            = fonts.definers
local specifiers          = fonts.specifiers
local constructors        = fonts.constructors
local loggers             = fonts.loggers
local fontgoodies         = fonts.goodies
local helpers             = fonts.helpers
local hashes              = fonts.hashes
local currentfont         = font.current
local definefont          = font.define

local encodings           = fonts.encodings
----- aglunicodes         = encodings.agl.unicodes
local aglunicodes         = nil -- delayed loading

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local setfield            = nuts.setfield
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getprop             = nuts.getprop
local setprop             = nuts.setprop
local getfont             = nuts.getfont
local setsubtype          = nuts.setsubtype

local texgetattribute     = tex.getattribute
local texsetattribute     = tex.setattribute
local texgetdimen         = tex.getdimen
local texsetcount         = tex.setcount
local texget              = tex.get

local texdefinefont       = tex.definefont
local texsp               = tex.sp

local fontdata            = hashes.identifiers
local characters          = hashes.characters
local descriptions        = hashes.descriptions
local properties          = hashes.properties
local resources           = hashes.resources
local unicodes            = hashes.unicodes
local csnames             = hashes.csnames
local lastmathids         = hashes.lastmathids
local exheights           = hashes.exheights
local emwidths            = hashes.emwidths
local parameters          = hashes.parameters

local designsizefilename  = fontgoodies.designsizes.filename

local ctx_char            = context.char
local ctx_getvalue        = context.getvalue

local otffeatures         = otf.features
local otftables           = otf.tables

local registerotffeature  = otffeatures.register

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

local function getfontname(tfmdata)
    return basename(type(tfmdata) == "number" and properties[tfmdata].name or tfmdata.properties.name)
end

helpers.name = getfontname

if _LUAVERSION < 5.2  then

    formatters.add(formatters,"font:name",    [["'"..fontname(%s).."'"]],          "local fontname  = fonts.helpers.name")
    formatters.add(formatters,"font:features",[["'"..sequenced(%s," ",true).."'"]],"local sequenced = table.sequenced")

else

    formatters.add(formatters,"font:name",    [["'"..fontname(%s).."'"]],          { fontname  = helpers.name })
    formatters.add(formatters,"font:features",[["'"..sequenced(%s," ",true).."'"]],{ sequenced = table.sequenced    })

end

-- ... like font-sfm or so

constructors.resolvevirtualtoo = true -- context specific (due to resolver)

constructors.sharefonts        = true -- experimental
constructors.nofsharedhashes   = 0
constructors.nofsharedvectors  = 0
constructors.noffontsloaded    = 0

do

    local shares = { }
    local hashes = { }

    function constructors.trytosharefont(target,tfmdata)
        constructors.noffontsloaded = constructors.noffontsloaded + 1
        if constructors.sharefonts then
            local fonthash   = target.specification.hash
            if fonthash then
                local properties = target.properties
                local fullname   = target.fullname
                local sharedname = hashes[fonthash]
                if sharedname then
                    -- this is ok for context as we know that only features can mess with font definitions
                    -- so a similar hash means that the fonts are similar too
                    if trace_defining then
                        report_defining("font %a uses backend resources of font %a (%s)",target.fullname,sharedname,"common hash")
                    end
                    target.fullname = sharedname
                    properties.sharedwith = sharedname
                    constructors.nofsharedfonts = constructors.nofsharedfonts + 1
                    constructors.nofsharedhashes = constructors.nofsharedhashes + 1
                else
                    -- the one takes more time (in the worst case of many cjk fonts) but it also saves
                    -- embedding time
                    local characters = target.characters
                    local n = 1
                    local t = { target.psname }
                    local u = sortedkeys(characters)
                    for i=1,#u do
                        local k = u[i]
                        n = n + 1 ; t[n] = k
                        n = n + 1 ; t[n] = characters[k].index or k
                    end
                    local checksum   = md5.HEX(concat(t," "))
                    local sharedname = shares[checksum]
                    local fullname   = target.fullname
                    if sharedname then
                        if trace_defining then
                            report_defining("font %a uses backend resources of font %a (%s)",fullname,sharedname,"common vector")
                        end
                        fullname = sharedname
                        properties.sharedwith= sharedname
                        constructors.nofsharedfonts = constructors.nofsharedfonts + 1
                        constructors.nofsharedvectors = constructors.nofsharedvectors + 1
                    else
                        shares[checksum] = fullname
                    end
                    target.fullname  = fullname
                    hashes[fonthash] = fullname
                end
            end
        end
    end

end

directives.register("fonts.checksharing",function(v)
    if not v then
        report_defining("font sharing in backend is disabled")
    end
    constructors.sharefonts = v
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

implement {
    name     = "resetnullfont",
    onlyonce = true,
    actions  = function()
        for i=1,7 do
            -- we have no direct method yet
            context([[\fontdimen%s\nullfont\zeropoint]],i)
        end
        definers.resetnullfont()
    end
}

-- this cannot be a feature initializer as there is no auto namespace
-- so we never enter the loop then; we can store the defaults in the tma
-- file (features.gpos.mkmk = 1 etc)

local needsnodemode = { -- we will have node mode by default anyway
 -- gsub_single              = true,
    gsub_multiple            = true,
 -- gsub_alternate           = true,
 -- gsub_ligature            = true,
    gsub_context             = true,
    gsub_contextchain        = true,
    gsub_reversecontextchain = true,
 -- chainsub                 = true,
 -- reversesub               = true,
    gpos_mark2base           = true,
    gpos_mark2ligature       = true,
    gpos_mark2mark           = true,
    gpos_cursive             = true,
 -- gpos_single              = true,
 -- gpos_pair                = true,
    gpos_context             = true,
    gpos_contextchain        = true,
}

otftables.scripts.auto = "automatic fallback to latn when no dflt present"

-- setmetatableindex(otffeatures.descriptions,otftables.features)

local privatefeatures = { -- this can go away
    tlig = true,
    trep = true,
    anum = true,
}

local function checkedscript(tfmdata,resources,features)
    local latn   = false
    local script = false
    if resources.features then
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

-- basemode combined with dynamics is somewhat tricky

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
    if trace_automode then
        report_defining("forcing mode base, font %!font:name!",tfmdata)
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
    if features == "" and find(parent,"=",1,true) then
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
     -- if v then t[k] = v end
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

local function adaptcontext(pattern,features)
    local pattern = topattern(pattern,false,true)
    for name in next, setups do
        if find(name,pattern) then
            presetcontext(name,name,features)
        end
    end
end

-- local function contextnumber(name) -- will be replaced
--     local t = setups[name]
--     if not t then
--         return 0
--     elseif t.auto then -- check where used, autolanguage / autoscript?
--         local lng = tonumber(tex.language)
--         local tag = name .. ":" .. lng
--         local s = setups[tag]
--         if s then
--             return s.number or 0
--         else
--             local script, language = languages.association(lng)
--             if t.script ~= script or t.language ~= language then
--                 local s = fastcopy(t)
--                 local n = #numbers + 1
--                 setups[tag] = s
--                 numbers[n] = tag
--                 s.number = n
--                 s.script = script
--                 s.language = language
--                 return n
--             else
--                 setups[tag] = t
--                 return t.number or 0
--             end
--         end
--     else
--         return t.number or 0
--     end
-- end

local function contextnumber(name) -- will be replaced
    local t = setups[name]
    return t and t.number or 0
end

local function mergecontext(currentnumber,extraname,option) -- number string number (used in scrp-ini
    local extra = setups[extraname]
    if extra then
        local current = setups[numbers[currentnumber]]
        local mergedfeatures = { }
        local mergedname = nil
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
            if trace_merge then
                report_features("merge %a, method %a, current %|T, extra %|T, result %|T",mergedname,"add",current or { },extra,mergedfeatures)
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
            if trace_merge then
                report_features("merge %a, method %a, current %|T, extra %|T, result %|T",mergedname,"subtract",current or { },extra,mergedfeatures)
            end
        else -- =
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
            if trace_merge then
                report_features("merge %a, method %a, result %|T",mergedname,"replace",mergedfeatures)
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
        local number = #numbers + 1 -- we somehow end up with steps of 2
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = how == "=" and 1 or 2 -- 1=replace, 2=combine
        setups[mergedname] = mergedfeatures
        return number -- contextnumber(mergedname)
    else
        report_features("unknown feature %a cannot be merged into %a using method %a",extraname,mergedname,how)
        return 0
    end
end

specifiers.presetcontext   = presetcontext
specifiers.contextnumber   = contextnumber
specifiers.mergecontext    = mergecontext
specifiers.registercontext = registercontext
specifiers.definecontext   = definecontext

-- we extend the hasher:

-- constructors.hashmethods.virtual = function(list)
--     local s = { }
--     local n = 0
--     for k, v in next, list do
--         n = n + 1
--         s[n] = k -- no checking on k
--     end
--     if n > 0 then
--         sort(s)
--         for i=1,n do
--             local k = s[i]
--             s[i] = k .. '=' .. tostring(list[k])
--         end
--         return concat(s,"+")
--     end
-- end

constructors.hashmethods.virtual = function(list)
    local s = { }
    local n = 0
    for k, v in next, list do
        n = n + 1
     -- if v == true then
     --     s[n] = k .. '=true'
     -- elseif v == false then
     --     s[n] = k .. '=false'
     -- else
     --     s[n] = k .. "=" .. v
     -- end
        s[n] = k .. "=" .. tostring(v)
    end
    if n > 0 then
        sort(s)
        return concat(s,"+")
    end
end

-- end of redefine

-- local withcache = { } -- concat might be less efficient than nested tables
--
-- local function withset(name,what)
--     local zero = texgetattribute(0)
--     local hash = zero .. "+" .. name .. "*" .. what
--     local done = withcache[hash]
--     if not done then
--         done = mergecontext(zero,name,what)
--         withcache[hash] = done
--     end
--     texsetattribute(0,done)
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
--     texsetattribute(0,done)
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
        if find(features,",",a,true) then
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
--     elseif find(features,",",1,true) then
--         -- This is not that efficient but handy anyway for quick and dirty tests
--         -- beware, due to the way of caching setups you can get the wrong results
--         -- when components change. A safeguard is to nil the cache.
--         local merge = nil
--         for feature in gmatch(features,"[^, ]+") do
--             if find(feature,"=",1,true) then
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
    return hash_to_string(
        mergedtable(handlers[kind].features.defaults or {},setups[name] or {}),
        separator, yes, no, strict, omit or { "number" }
    )
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
local spaces     = space^0
local separator  = S(";,")
local equal      = P("=")
local sometext   = C((1-equal-space-separator)^1)
local truevalue  = P("+") * spaces * sometext                           * Cc(true)
local falsevalue = P("-") * spaces * sometext                           * Cc(false)
local somevalue  =                   sometext * spaces                  * Cc(true)
local keyvalue   =                   sometext * spaces * equal * spaces * sometext
local pattern    = Cf(Ct("") * (space + separator + Cg(falsevalue + truevalue + keyvalue + somevalue))^0, rawset)

local function colonized(specification)
    specification.features.normal = normalize_features(lpegmatch(pattern,specification.detail))
    return specification
end

definers.registersplit(":",colonized,"direct")

-- define (two steps)

----- space        = P(" ")
----- spaces       = space^0
local leftparent   = (P"(")
local rightparent  = (P")")
local value        = C((leftparent * (1-rightparent)^0 * rightparent + (1-space))^1)
local dimension    = C((space/"" + P(1))^1)
local rest         = C(P(1)^0)
local scale_none   =               Cc(0)
local scale_at     = P("at")     * Cc(1) * spaces * dimension -- dimension
local scale_sa     = P("sa")     * Cc(2) * spaces * dimension -- number
local scale_mo     = P("mo")     * Cc(3) * spaces * dimension -- number
local scale_scaled = P("scaled") * Cc(4) * spaces * dimension -- number
local scale_ht     = P("ht")     * Cc(5) * spaces * dimension -- dimension
local scale_cp     = P("cp")     * Cc(6) * spaces * dimension -- dimension

local specialscale = { [5] = "ht", [6] = "cp" }

local sizepattern  = spaces * (scale_at + scale_sa + scale_mo + scale_ht + scale_cp + scale_scaled + scale_none)
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

local specifiers = { }

do  -- else too many locals

    ----- ctx_setdefaultfontname = context.fntsetdefname
    ----- ctx_setsomefontname    = context.fntsetsomename
    ----- ctx_setemptyfontsize   = context.fntsetnopsize
    ----- ctx_setsomefontsize    = context.fntsetsomesize
    ----- ctx_letvaluerelax      = context.letvaluerelax

    local starttiming            = statistics.starttiming
    local stoptiming             = statistics.stoptiming

    local scanners               = tokens.scanners
    local scanstring             = scanners.string
    local scaninteger            = scanners.integer
    local scannumber             = scanners.number
    local scanboolean            = scanners.boolean

    local setmacro               = tokens.setters.macro

    local scanners               = interfaces.scanners

 -- function commands.definefont_one(str)

    scanners.definefont_one = function()
        local str = scanstring()

        starttiming(fonts)
        if trace_defining then
            report_defining("memory usage before: %s",statistics.memused())
            report_defining("start stage one: %s",str)
        end
        local fullname, size = lpegmatch(splitpattern,str)
        local lookup, name, sub, method, detail = getspecification(fullname)
        if not name then
            report_defining("strange definition %a",str)
         -- ctx_setdefaultfontname()
        elseif name == "unknown" then
         -- ctx_setdefaultfontname()
        else
         -- ctx_setsomefontname(name)
            setmacro("somefontname",name,"global")
        end
        -- we can also use a count for the size
        if size and size ~= "" then
            local mode, size = lpegmatch(sizepattern,size)
            if size and mode then
                texsetcount("scaledfontmode",mode)
             -- ctx_setsomefontsize(size)
                setmacro("somefontsize",size)
            else
                texsetcount("scaledfontmode",0)
             -- ctx_setemptyfontsize()
            end
        elseif true then
            -- so we don't need to check in tex
            texsetcount("scaledfontmode",2)
         -- ctx_setemptyfontsize()
        else
            texsetcount("scaledfontmode",0)
         -- ctx_setemptyfontsize()
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

 -- function commands.definefont_two(global,cs,str,size,inheritancemode,classfeatures,fontfeatures,classfallbacks,fontfallbacks,
 --     mathsize,textsize,relativeid,classgoodies,goodies,classdesignsize,fontdesignsize,scaledfontmode)

    scanners.definefont_two = function()

        local global          = scanboolean() -- \ifx\fontclass\empty\s!false\else\s!true\fi
        local cs              = scanstring () -- {#csname}%
        local str             = scanstring () -- \somefontfile
        local size            = scaninteger() -- \d_font_scaled_font_size
        local inheritancemode = scaninteger() -- \c_font_feature_inheritance_mode
        local classfeatures   = scanstring () -- \m_font_class_features
        local fontfeatures    = scanstring () -- \m_font_features
        local classfallbacks  = scanstring () -- \m_font_class_fallbacks
        local fontfallbacks   = scanstring () -- \m_font_fallbacks
        local mathsize        = scaninteger() -- \fontface
        local textsize        = scaninteger() -- \d_font_scaled_text_face
        local relativeid      = scaninteger() -- \relativefontid
        local classgoodies    = scanstring () -- \m_font_class_goodies
        local goodies         = scanstring () -- \m_font_goodies
        local classdesignsize = scanstring () -- \m_font_class_designsize
        local fontdesignsize  = scanstring () -- \m_font_designsize
        local scaledfontmode  = scaninteger() -- \scaledfontmode

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
        --
        specification.name      = name
        specification.size      = size
        specification.sub       = (sub and sub ~= "" and sub) or specification.sub
        specification.mathsize  = mathsize
        specification.textsize  = textsize
        specification.goodies   = goodies
        specification.cs        = cs
        specification.global    = global
        specification.scalemode = scaledfontmode -- context specific
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
            texsetcount("scaledfontsize",0)
         -- ctx_letvaluerelax(cs) -- otherwise the current definition takes the previous one
        elseif type(tfmdata) == "number" then
            if trace_defining then
                report_defining("reusing %s, id %a, target %a, features %a / %a, fallbacks %a / %a, goodies %a / %a, designsize %a / %a",
                    name,tfmdata,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,classgoodies,goodies,classdesignsize,fontdesignsize)
            end
            csnames[tfmdata] = specification.cs
            texdefinefont(global,cs,tfmdata)
            -- resolved (when designsize is used):
            local size = fontdata[tfmdata].parameters.size or 0
         -- ctx_setsomefontsize(size .. "sp")
            setmacro("somefontsize",size.."sp")
            texsetcount("scaledfontsize",size)
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
            constructors.checkvirtualids(tfmdata) -- experiment, will become obsolete when slots can selfreference
            local id = definefont(tfmdata)
            csnames[id] = specification.cs
            tfmdata.properties.id = id
            definers.register(tfmdata,id) -- to be sure, normally already done
            texdefinefont(global,cs,id)
            constructors.cleanuptable(tfmdata)
            constructors.finalize(tfmdata)
            if trace_defining then
                report_defining("defining %a, id %a, target %a, features %a / %a, fallbacks %a / %a",
                    name,id,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks)
            end
            -- resolved (when designsize is used):
            local size = tfmdata.parameters.size or 655360
            setmacro("somefontsize",size.."sp")
         -- ctx_setsomefontsize(size .. "sp")
            texsetcount("scaledfontsize",size)
            lastfontid = id
        end
        if trace_defining then
            report_defining("memory usage after: %s",statistics.memused())
            report_defining("stop stage two")
        end
        --
        texsetcount("global","lastfontid",lastfontid)
        specifiers[lastfontid] = { str, size }
        if not mathsize then
            -- forget about it
        elseif mathsize == 0 then
            lastmathids[1] = lastfontid
        else
            lastmathids[mathsize] = lastfontid
        end
        --
        stoptiming(fonts)
    end

    function scanners.specifiedfontspec()
        local f = specifiers[scaninteger()]
        if f then
            context(f[1])
        end
    end
    function scanners.specifiedfontsize()
        local f = specifiers[scaninteger()]
        if f then
            context(f[2])
        end
    end
    function scanners.specifiedfont()
        local f = specifiers[scaninteger()]
        local s = scannumber()
        if f and s then
            context("%s at %0.2p",f[1],s * f[2]) -- we round to 2 decimals (as at the tex end)
        end
    end

    --

    function definers.define(specification)
        --
        local name = specification.name
        if not name or name == "" then
            return -1
        else
            starttiming(fonts)
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
                specification.size = texsp(specification.size) or 655260
            end
            --
            specification.specification = "" -- not used
            specification.resolved      = ""
            specification.forced        = ""
            specification.features      = { } -- via detail, maybe some day
            --
            -- we don't care about mathsize textsize goodies fallbacks
            --
            local cs = specification.cs
            if cs == "" then
                cs = nil
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
                if cs then
                    texdefinefont(specification.global,cs,tfmdata)
                    csnames[tfmdata] = cs
                end
                return tfmdata, fontdata[tfmdata]
            else
                constructors.checkvirtualids(tfmdata) -- experiment, will become obsolete when slots can selfreference
                local id = definefont(tfmdata)
                tfmdata.properties.id = id
                definers.register(tfmdata,id)
                if cs then
                    texdefinefont(specification.global,cs,id)
                    csnames[id] = cs
                end
                constructors.cleanuptable(tfmdata)
                constructors.finalize(tfmdata)
                return id, tfmdata
            end
            stoptiming(fonts)
        end
    end

    -- local id, cs = fonts.definers.internal { }
    -- local id, cs = fonts.definers.internal { number = 2 }
    -- local id, cs = fonts.definers.internal { name = "dejavusans" }

    local n = 0

    function definers.internal(specification,cs)
        specification = specification or { }
        local name    = specification.name
        local size    = tonumber(specification.size)
        local number  = tonumber(specification.number)
        local id      = nil
        if not size then
            size = texgetdimen("bodyfontsize")
        end
        if number then
            id = number
        elseif name and name ~= "" then
            local cs = cs or specification.cs
            if not cs then
                n  = n + 1 -- beware ... there can be many and they are often used once
             -- cs = formatters["internal font %s"](n)
                cs = "internal font " .. n
            else
                specification.cs = cs
            end
            id = definers.define {
                name = name,
                size = size,
                cs   = cs,
            }
        end
        if not id then
            id = currentfont()
        end
        return id, csnames[id]
    end

    -- here

    local infofont = 0

    function fonts.infofont()
        if infofont == 0 then
            infofont = definers.define { name = "dejavusansmono", size = tex.sp("6pt") }
        end
        return infofont
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

function constructors.calculatescale(tfmdata,scaledpoints,relativeid,specification)
    if specification then
        local scalemode = specification.scalemode
        local special   = scalemode and specialscale[scalemode]
        if special then
            -- we also have available specification.textsize
            local parameters = tfmdata.parameters
         -- local designsize = parameters.designsize
            if     special == "ht" then
                local height = parameters.ascender / parameters.units
                scaledpoints = scaledpoints / height
            elseif special == "cp" then
                local glyph  = tfmdata.descriptions[utfbyte("X")]
                local height = (glyph and glyph.height or parameters.ascender) / parameters.units
                scaledpoints = scaledpoints / height
            end
        end
    end
    local scaledpoints, delta = calculatescale(tfmdata,scaledpoints)
 -- if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific (we need to hash rscale then)
 --     local relativedata = fontdata[relativeid]
 --     local rfmdata = relativedata and relativedata.unscaled and relativedata.unscaled -- just use metadata instead
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

local designsizes = constructors.designsizes

function constructors.hashinstance(specification,force)
    local hash, size, fallbacks = specification.hash, specification.size, specification.fallbacks
    if force or not hash then
        hash = constructors.hashfeatures(specification)
        specification.hash = hash
    end
    if size < 1000 and designsizes[hash] then
        size = math.round(constructors.scaled(size,designsizes[hash]))
        specification.size = size
    end
    if fallbacks then
        return hash .. ' @ ' .. tostring(size) .. ' @ ' .. fallbacks
    else
        local scalemode = specification.scalemode
        local special   = scalemode and specialscale[scalemode]
        if special then
            return hash .. ' @ ' .. tostring(size) .. ' @ ' .. special
        else
            return hash .. ' @ ' .. tostring(size)
        end
    end
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
    -- goodies are a context specific thing and are not always defined
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
                normal.goodies = formatters["%s,%s"](g,goodies)
            else
                normal.goodies = goodies
            end
        end
    end
    -- so far for goodie hacks
    local hash = hashfeatures(specification)
    local name = specification.name
    local sub  = specification.sub
    if sub and sub ~= "" then
        specification.hash = lower(name .. " @ " .. sub .. ' @ ' .. hash)
    else
        specification.hash = lower(name .. " @ "        .. ' @ ' .. hash)
    end
    --
    return specification
end




-- soon to be obsolete:

local mappings = fonts.mappings

local loaded = { -- prevent loading (happens in cont-sys files)
 -- ["original-base.map"     ] = true,
 -- ["original-ams-base.map" ] = true,
 -- ["original-ams-euler.map"] = true,
 -- ["original-public-lm.map"] = true,
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

implement {
    name      = "loadmapfile",
    actions   = mappings.loadfile,
    arguments = "string"
}

implement {
    name      = "loadmapline",
    actions   = mappings.loadline,
    arguments = "string"
}

implement {
    name      = "resetmapfiles",
    actions   = mappings.reset,
    arguments = "string"
}

-- we need an 'do after the banner hook'

-- => commands

local function nametoslot(name)
    local t = type(name)
    local s = nil
    if t == "string" then
        local slot = unicodes[true][name]
        if slot then
            return slot
        end
        if not aglunicodes then
            aglunicodes = encodings.agl.unicodes
        end
        slot = aglunicodes[name]
        if characters[true][slot] then
            return slot
        else
            -- not in font
        end
    elseif t == "number" then
        if characters[true][name] then
            return slot
        else
            -- not in font
        end
    end
end

local function indextoslot(index)
    local r = resources[true]
    if r then
        local indices = r.indices
        if not indices then
            indices = { }
            local c = characters[true]
            for unicode, data in next, c do
                local di = data.index
                if di then
                    indices[di] = unicode
                end
            end
            r.indices = indices
        end
        return indices[tonumber(index)]
    end
end

do -- else too many locals

    local entities = characters.entities
    local lowered  = { } -- delayed initialization

    setmetatableindex(lowered,function(t,k)
        for k, v in next, entities do
            local l = lower(k)
            if not entities[l] then
                lowered[l] = v
            end
        end
        setmetatableindex(lowered,nil)
        return lowered[k]
    end)

    local methods = {
        -- entity
        e = function(name)
                return entities[name] or lowered[name] or name
            end,
        -- hexadecimal unicode
        x = function(name)
                local n = tonumber(name,16)
                return n and utfchar(n) or name
            end,
        -- decimal unicode
        d = function(name)
                local n = tonumber(name)
                return n and utfchar(n) or name
            end,
        -- hexadecimal index (slot)
        s = function(name)
                local n = tonumber(name,16)
                local n = n and indextoslot(n)
                return n and utfchar(n) or name
            end,
        -- decimal index
        i = function(name)
                local n = tonumber(name)
                local n = n and indextoslot(n)
                return n and utfchar(n) or name
            end,
        -- name
        n = function(name)
                local n = nametoslot(name)
                return n and utfchar(n) or name
            end,
        -- char
        c = function(name)
                return name
            end,
    }

    -- -- nicer:
    --
    -- setmetatableindex(methods,function(t,k) return methods.c end)
    --
    -- local splitter = (C(1) * P(":") + Cc("c")) * C(P(1)^1) / function(method,name)
    --     return methods[method](name)
    -- end
    --
    -- -- more efficient:

    local splitter = C(1) * P(":") * C(P(1)^1) / function(method,name)
        local action = methods[method]
        return action and action(name) or name
    end

    local function tochar(str)
        local t = type(str)
        if t == "number" then
            return utfchar(str)
        elseif t == "string" then
            return lpegmatch(splitter,str) or str
        else
            return str
        end
    end

    helpers.nametoslot  = nametoslot
    helpers.indextoslot = indextoslot
    helpers.tochar      = tochar

    -- interfaces:

    implement {
        name      = "fontchar",
        actions   = { nametoslot, ctx_char },
        arguments = "string",
    }

    implement {
        name      = "fontcharbyindex",
        actions   = { indextoslot, ctx_char },
        arguments = "integer",
    }

    implement {
        name      = "tochar",
        actions   = { tochar, context },
        arguments = "string",
    }

end

-- this will change ...

function loggers.reportdefinedfonts()
    if trace_usage then
        local t, tn = { }, 0
        for id, data in sortedhash(fontdata) do
            local properties = data.properties or { }
            local parameters = data.parameters or { }
            tn = tn + 1
            t[tn] = {
  format("%03i",id                    or 0),
  format("%09i",parameters.size       or 0),
                properties.type       or "real",
                properties.format     or "unknown",
                properties.name       or "",
                properties.psname     or "",
                properties.fullname   or "",
                properties.sharedwith or "",
            }
        end
        formatcolumns(t,"  ")
        logs.pushtarget("logfile")
        report_newline()
        report_status("defined fonts:")
        report_newline()
        for k=1,tn do
            report_status(t[k])
        end
        logs.poptarget()
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
        logs.pushtarget("logfile")
        report_newline()
        report_status("defined featuresets:")
        report_newline()
        for k=1,n do
            report_status(t[k])
        end
        logs.poptarget()
    end
end

luatex.registerstopactions(loggers.reportusedfeatures)

-- maybe move this to font-log.lua:

statistics.register("font engine", function()
    local elapsed   = statistics.elapsedseconds(fonts)
    local nofshared = constructors.nofsharedfonts or 0
    local nofloaded = constructors.noffontsloaded or 0
    if nofshared > 0 then
        return format("otf %0.3f, afm %0.3f, tfm %0.3f, %s instances, %s shared in backend, %s common vectors, %s common hashes, load time %s",
            otf.version,afm.version,tfm.version,nofloaded,
            nofshared,constructors.nofsharedvectors,constructors.nofsharedhashes,
            elapsed)
    elseif nofloaded > 0 and elapsed then
        return format("otf %0.3f, afm %0.3f, tfm %0.3f, %s instances, load time %s",
            otf.version,afm.version,tfm.version,nofloaded,
            elapsed)
    else
        return format("otf %0.3f, afm %0.3f, tfm %0.3f",
            otf.version,afm.version,tfm.version)
    end
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

local ctx_startfontclass       = context.startfontclass
local ctx_stopfontclass        = context.stopfontclass
local ctx_definefontsynonym    = context.definefontsynonym
local ctx_dofastdefinetypeface = context.dofastdefinetypeface

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
    ctx_startfontclass { name }
        ctx_definefontsynonym( { formatters["%s"]          (Shape) }, { formatters["spec:%s-%s-regular-%s"] (fontname, normalweight, normalwidth) } )
        ctx_definefontsynonym( { formatters["%sBold"]      (Shape) }, { formatters["spec:%s-%s-regular-%s"] (fontname, boldweight,   boldwidth  ) } )
        ctx_definefontsynonym( { formatters["%sBoldItalic"](Shape) }, { formatters["spec:%s-%s-italic-%s"]  (fontname, boldweight,   boldwidth  ) } )
        ctx_definefontsynonym( { formatters["%sItalic"]    (Shape) }, { formatters["spec:%s-%s-italic-%s"]  (fontname, normalweight, normalwidth) } )
    ctx_stopfontclass()
    local settings = sequenced({ features= t.features },",")
    ctx_dofastdefinetypeface(name, shortcut, shape, size, settings)
end

implement {
    name      = "definetypeface",
    actions   = fonts.definetypeface,
    arguments = { "string", "string" }
}

function fonts.current() -- todo: also handle name
    return fontdata[currentfont()] or fontdata[0]
end

function fonts.currentid()
    return currentfont() or 0
end

-- for the moment here, this will become a chain of extras that is
-- hooked into the ctx registration (or scaler or ...)

local dimenfactors = number.dimenfactors

function helpers.dimenfactor(unit,id)
    if unit == "ex" then
        return id and exheights[id] or 282460 -- lm 10pt
    elseif unit == "em" then
        return id and emwidths [id] or 655360 -- lm 10pt
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

-- local hashes      = fonts.hashes
-- local emwidths    = hashes.emwidths
-- local exheights   = hashes.exheights

setmetatableindex(dimenfactors, function(t,k)
    if k == "ex" then
        return 1/exheights[currentfont()]
    elseif k == "em" then
        return 1/emwidths[currentfont()]
    elseif k == "pct" or k == "%" then
        return 1/(texget("hsize")/100)
    else
     -- error("wrong dimension: " .. (s or "?")) -- better a message
        return false
    end
end)

dimenfactors.ex   = nil
dimenfactors.em   = nil
dimenfactors["%"] = nil
dimenfactors.pct  = nil

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

-- in versions > 0.82 0 is supported as equivalent of self

function constructors.checkvirtualids(tfmdata)
    -- begin of experiment: we can use { "slot", 0, number } in virtual fonts
    local fonts  = tfmdata.fonts
    local selfid = font.nextid()
    if fonts and #fonts > 0 then
        for i=1,#fonts do
            local fi = fonts[i]
            if fi[2] == 0 then
                fi[2] = selfid
            elseif fi.id == 0 then
                fi.id = selfid
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

do

    local setmacro = tokens.setters.macro

    function constructors.currentfonthasfeature(n)
        local f = fontdata[currentfont()]
        if not f then return end f = f.shared
        if not f then return end f = f.rawdata
        if not f then return end f = f.resources
        if not f then return end f = f.features
        return f and (f.gpos[n] or f.gsub[n])
    end

    implement {
        name      = "doifelsecurrentfonthasfeature",
        actions   = { constructors.currentfonthasfeature, commands.doifelse },
        arguments = "string"
    }

    local f_strip  = formatters["%0.2fpt"] -- normally this value is changed only once
    local stripper = lpeg.patterns.stripzeros

    implement {
        name      = "nbfs",
        arguments = "dimen",
        actions   = function(d)
            context(lpegmatch(stripper,f_strip(d/65536)))
        end
    }

    implement {
        name      = "featureattribute",
        arguments = "string",
        actions   = { contextnumber, context }
    }

    implement {
        name      = "setfontfeature",
        arguments = "string",
        actions   = function(tag) texsetattribute(0,contextnumber(tag)) end
    }

    implement {
        name      = "resetfontfeature",
        arguments = { 0, 0 },
        actions   = texsetattribute,
    }

    implement {
        name      = "setfontofid",
        arguments = "integer",
        actions   = function(id)
            ctx_getvalue(csnames[id])
        end
    }

    implement {
        name      = "definefontfeature",
        arguments = { "string", "string", "string" },
        actions   = presetcontext
    }

    implement {
        name      = "adaptfontfeature",
        arguments = { "string", "string" },
        actions   = adaptcontext
    }

    local cache = { }

    local hows = {
        ["+"] = "add",
        ["-"] = "subtract",
        ["="] = "replace",
    }

    local function setfeature(how,parent,name,font) -- 0/1 test temporary for testing
        if not how or how == 0 then
            if trace_features and texgetattribute(0) ~= 0 then
                report_cummulative("font %!font:name!, reset",fontdata[font or true])
            end
            texsetattribute(0,0)
        elseif how == true or how == 1 then
            local hash = "feature > " .. parent
            local done = cache[hash]
            if trace_features and done then
                report_cummulative("font %!font:name!, revive %a : %!font:features!",fontdata[font or true],parent,setups[numbers[done]])
            end
            texsetattribute(0,done or 0)
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
            texsetattribute(0,done)
        end
    end

    local function resetfeature()
        if trace_features and texgetattribute(0) ~= 0 then
            report_cummulative("font %!font:name!, reset",fontdata[true])
        end
        texsetattribute(0,0)
    end

    local function registerlanguagefeatures()
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

    constructors.setfeature   = setfeature
    constructors.resetfeature = resetfeature

    implement { name = "resetfeature",    actions = resetfeature }
    implement { name = "addfeature",      actions = setfeature, arguments = { "'+'",  "string", "string" } }
    implement { name = "subtractfeature", actions = setfeature, arguments = { "'-'",  "string", "string" } }
    implement { name = "replacefeature",  actions = setfeature, arguments = { "'='",  "string", "string" } }
    implement { name = "revivefeature",   actions = setfeature, arguments = { true, "string" } }

    implement {
        name      = "featurelist",
        actions   = { fonts.specifiers.contexttostring, context },
        arguments = { "string", "'otf'", "string", "'yes'", "'no'", true }
    }

    implement {
        name    = "registerlanguagefeatures",
        actions = registerlanguagefeatures,
    }

end

-- a fontkern plug:

do

    local kerncodes = nodes.kerncodes
    local copy_node = nuts.copy
    local kern      = nuts.pool.register(nuts.pool.kern())

    setattr(kern,attributes.private('fontkern'),1)

    nodes.injections.installnewkern(function(k)
        local c = copy_node(kern)
        setfield(c,"kern",k)
        return c
    end)

    directives.register("fonts.injections.fontkern", function(v)
        setsubtype(kern,v and kerncodes.fontkern or kerncodes.userkern)
    end)

end

do

    local report = logs.reporter("otf","variants")

    local function replace(tfmdata,feature,value)
        local characters = tfmdata.characters
        local variants   = tfmdata.resources.variants
        if variants then
            local t = { }
            for k, v in sortedhash(variants) do
                t[#t+1] = formatters["0x%X (%i)"](k,k)
            end
            value = tonumber(value) or 0xFE00 -- 917762
            report("fontname : %s",tfmdata.properties.fontname)
            report("available: % t",t)
            local v = variants[value]
            if v then
                report("using    : %X (%i)",value,value)
                for k, v in next, v do
                    local c = characters[v]
                    if c then
                        characters[k] = c
                    end
                end
            else
                report("unknown  : %X (%i)",value,value)
            end
        end
    end

    registerotffeature {
        name         = 'variant',
        description  = 'unicode variant',
        manipulators = {
            base = replace,
            node = replace,
        }
    }

end

-- here (todo: closure)

-- make a closure (200 limit):

local trace_analyzing    = false  trackers.register("otf.analyzing", function(v) trace_analyzing = v end)

local analyzers          = fonts.analyzers
local methods            = analyzers.methods

local unsetvalue         = attributes.unsetvalue

local traverse_id        = nuts.traverse_id

local a_color            = attributes.private('color')
local a_colormodel       = attributes.private('colormodel')
local a_state            = attributes.private('state')
local m_color            = attributes.list[a_color] or { }

local glyph_code         = nodes.nodecodes.glyph

local states             = analyzers.states

local colornames = {
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
        head = tonut(head)
        local model = getattr(head,a_colormodel) or 1
        for glyph in traverse_id(glyph_code,head) do
            local a = getprop(glyph,a_state)
            if a then
                local name = colornames[a]
                if name then
                    local color = m_color[name]
                    if color then
                        setattr(glyph,a_colormodel,model)
                        setattr(glyph,a_color,color)
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
    name       = "analyze",
    processors = {
        node     = analyzeprocessor,
    }
}

function methods.nocolor(head,font,attr)
    for n in traverse_id(glyph_code,head) do
        if not font or getfont(n) == font then
            setattr(n,a_color,unsetvalue)
        end
    end
    return head, true
end

local function purefontname(name)
    if type(name) == "number" then
        name = getfontname(name)
    end
    if type(name) == "string" then
       return basename(name)
    end
end

implement {
    name      = "purefontname",
    actions   = { purefontname, context },
    arguments = "string",
}

local list = storage.shared.bodyfontsizes or { }
storage.shared.bodyfontsizes = list

implement {
    name      = "registerbodyfontsize",
    arguments = "string",
    actions   = function(size)
        list[size] = true
    end
}

implement {
    name      = "getbodyfontsizes",
    arguments = "string",
    actions   = function(separator)
        context(concat(sortedkeys(list),separator))
    end
}

implement {
    name      = "processbodyfontsizes",
    arguments = "string",
    actions   = function(command)
        local keys = sortedkeys(list)
        if command then
            local action = context[command]
            for i=1,#keys do
                action(keys[i])
            end
        else
            context(concat(keys,","))
        end
    end
}

implement {
    name      = "cleanfontname",
    actions   = { names.cleanname, context },
    arguments = "string"
}

implement {
    name      = "fontlookupinitialize",
    actions   = names.lookup,
    arguments = "string",
}

implement {
    name      = "fontlookupnoffound",
    actions   = { names.noflookups, context },
}

implement {
    name      = "fontlookupgetkeyofindex",
    actions   = { names.getlookupkey, context },
    arguments = { "string", "integer"}
}

implement {
    name      = "fontlookupgetkey",
    actions   = { names.getlookupkey, context },
    arguments = "string"
}

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

implement {
    name    = "currentdesignsize",
    actions = function()
        context(parameters[currentfont()].designsize)
    end
}

implement {
    name      = "doifelsefontpresent",
    actions   = { names.exists, commands.doifelse },
    arguments = "string"
}

-- we use 0xFE000+ and 0xFF000+ in math and for runtime (text) extensions we
-- use 0xFD000+

constructors.privateslots = constructors.privateslots or { }

storage.register("fonts/constructors/privateslots", constructors.privateslots, "fonts.constructors.privateslots")

do

    local privateslots    = constructors.privateslots
    local lastprivateslot = 0xFD000

    constructors.privateslots = setmetatableindex(privateslots,function(t,k)
        local v = lastprivateslot
        lastprivateslot = lastprivateslot + 1
        t[k] = v
        return v
    end)

    implement {
        name      = "getprivateglyphslot",
        actions   = function(name) context(privateslots[name]) end,
        arguments = "string",
    }

end

-- an extra helper

function helpers.getcoloredglyphs(tfmdata)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    if not tfmdata then
        tfmdata = fontdata[true]
    end
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local collected    = { }
    for unicode, character in next, characters do
        local description = descriptions[unicode]
        if description and (description.colors or character.svg) then
            collected[#collected+1] = unicode
        end
    end
    table.sort(collected)
    return collected
end

-- for the font manual

statistics.register("used fonts",function()
    if trace_usage then
        local filename = file.nameonly(environment.jobname) .. "-fonts-usage.lua"
        if next(fontdata) then
            local files = { }
            local list  = { }
            for id, tfmdata in sortedhash(fontdata) do
                local filename = tfmdata.properties.filename
                if filename then
                    local filedata = files[filename]
                    if filedata then
                        filedata.instances = filedata.instances + 1
                    else
                        local rawdata  = tfmdata.shared and tfmdata.shared.rawdata
                        local metadata = rawdata and rawdata.metadata
                        files[filename] = {
                            instances = 1,
                            filename  = filename,
                            version   = metadata and metadata.version,
                            size      = rawdata and rawdata.size,
                        }
                    end
                else
                    -- what to do
                end
            end
            for k, v in sortedhash(files) do
                list[#list+1] = v
            end
            table.save(filename,list)
        else
            os.remove(filename)
        end
    end
end)

-- new

do

    local settings_to_array    = utilities.parsers.settings_to_array
    local namedcolorattributes = attributes.colors.namedcolorattributes
    local colorvalues          = attributes.colors.values

    implement {
        name      = "definefontcolorpalette",
        arguments = { "string", "string" },
        actions   = function(name,set)
            set = settings_to_array(set)
            for i=1,#set do
                local name = set[i]
                local space, color = namedcolorattributes(name)
                local values = colorvalues[color]
                if values then
                    set[i] = { r = values[3], g = values[4],  b = values[5] }
                else
                    set[i] = { r = 0, g = 0, b = 0 }
                end
            end
            otf.registerpalette(name,set)
        end
    }

end

do

    local pattern = C((1-S("* "))^1)

    implement {
        name      = "truefontname",
        arguments = "string",
        actions   = function(s)
         -- context(match(s,"[^* ]+") or s)
            context(lpegmatch(pattern,s) or s)
        end
    }

end
