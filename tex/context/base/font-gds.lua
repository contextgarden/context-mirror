if not modules then modules = { } end modules ['font-gds'] = {
    version   = 1.000,
    comment   = "companion to font-gds.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depends on ctx

local type, next = type, next
local gmatch, format, lower = string.gmatch, string.format, string.lower
local texsp = tex.sp

local fonts, nodes, attributes, node = fonts, nodes, attributes, node

local trace_goodies      = false

trackers.register("fonts.goodies", function(v) trace_goodies = v end)

local report_goodies     = logs.reporter("fonts","goodies")

local allocate           = utilities.storage.allocate

local otf                = fonts.handlers.otf
local addotffeature      = otf.enhancers.addfeature

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local afmfeatures        = fonts.constructors.newfeatures("afm")
local registerafmfeature = afmfeatures.register

local tfmfeatures        = fonts.constructors.newfeatures("tfm")
local registertfmfeature = tfmfeatures.register

local fontgoodies        = { }
fonts.goodies            = fontgoodies

local typefaces          = allocate()
fonts.typefaces          = typefaces

local data               = allocate()
fontgoodies.data         = fontgoodies.data

local list               = { }
fontgoodies.list         = list -- no allocate as we want to see what is there

function fontgoodies.report(what,trace,goodies)
    if trace_goodies or trace then
        local whatever = goodies[what]
        if whatever then
            report_goodies("goodie '%s' found in '%s'",what,goodies.name)
        end
    end
end

local function loadgoodies(filename) -- maybe a merge is better
    local goodies = data[filename] -- we assume no suffix is given
    if goodies ~= nil then
        -- found or tagged unfound
    elseif type(filename) == "string" then
        local fullname = resolvers.findfile(file.addsuffix(filename,"lfg")) or "" -- prefered suffix
        if fullname == "" then
            fullname = resolvers.findfile(file.addsuffix(filename,"lua")) or "" -- fallback suffix
        end
        if fullname == "" then
            report_goodies("goodie file '%s.lfg' is not found",filename)
            data[filename] = false -- signal for not found
        else
            goodies = dofile(fullname) or false
            if not goodies then
                report_goodies("goodie file '%s' is invalid",fullname)
                return nil
            elseif trace_goodies then
                report_goodies("goodie file '%s' is loaded",fullname)
            end
            goodies.name = goodies.name or "no name"
            for name, fnc in next, list do
                fnc(goodies)
            end
            goodies.initialized = true
            data[filename] = goodies
        end
    end
    return goodies
end

function fontgoodies.register(name,fnc) -- will be a proper sequencer
    list[name] = fnc
end

fontgoodies.load = loadgoodies

-- register goodies file

local function setgoodies(tfmdata,value)
    local goodies = tfmdata.goodies
    if not goodies then -- actually an error
        goodies = { }
        tfmdata.goodies = goodies
    end
    for filename in gmatch(value,"[^, ]+") do
        -- we need to check for duplicates
        local ok = loadgoodies(filename)
        if ok then
            if trace_goodies then
                report_goodies("assigning goodie '%s'",filename)
            end
            goodies[#goodies+1] = ok
        end
    end
end

-- this will be split into good-* files and this file might become good-ini.lua

-- featuresets

local function flattenedfeatures(t,tt)
    -- first set value dominates
    local tt = tt or { }
    for i=1,#t do
        local ti = t[i]
        if type(ti) == "table" then
            flattenedfeatures(ti,tt)
        elseif tt[ti] == nil then
            tt[ti] = true
        end
    end
    for k, v in next, t do
        if type(k) ~= "number" then -- not tonumber(k)
            if type(v) == "table" then
                flattenedfeatures(v,tt)
            elseif tt[k] == nil then
                tt[k] = v
            end
        end
    end
    return tt
end

-- fonts.features.flattened = flattenedfeatures

function fontgoodies.prepare_features(goodies,name,set)
    if set then
        local ff = flattenedfeatures(set)
        local fullname = goodies.name .. "::" .. name
        local n, s = fonts.specifiers.presetcontext(fullname,"",ff)
        goodies.featuresets[name] = s -- set
        if trace_goodies then
            report_goodies("feature set '%s' gets number %s and name '%s'",name,n,fullname)
        end
        return n
    end
end

local function initialize(goodies,tfmdata)
    local featuresets = goodies.featuresets
    local goodiesname = goodies.name
    if featuresets then
        if trace_goodies then
            report_goodies("checking featuresets in '%s'",goodies.name)
        end
        for name, set in next, featuresets do
            fontgoodies.prepare_features(goodies,name,set)
        end
    end
end

fontgoodies.register("featureset",initialize)

local function setfeatureset(tfmdata,set,features)
    local goodies = tfmdata.goodies -- shared ?
    if goodies then
        local properties = tfmdata.properties
        local what
        for i=1,#goodies do
            -- last one wins
            local g = goodies[i]
            what = (g.featuresets and g.featuresets[set]) or what
        end
        if what then
            for feature, value in next, what do
                if features[feature] == nil then
                    features[feature] = value
                end
            end
            properties.mode = what.mode or properties.mode
        end
    end
end

-- postprocessors (we could hash processor and share code)

function fontgoodies.registerpostprocessor(tfmdata,f,prepend)
    if not tfmdata.postprocessors then
        tfmdata.postprocessors = { f }
    elseif prepend then
        table.insert(tfmdata.postprocessors,f,1)
    else
        table.insert(tfmdata.postprocessors,f)
    end
end

local function setpostprocessor(tfmdata,processor)
    local goodies = tfmdata.goodies
    if goodies and type(processor) == "string" then
        local found = { }
        local asked = utilities.parsers.settings_to_array(processor)
        for i=1,#goodies do
            local g = goodies[i]
            local p = g.postprocessors
            if p then
                for i=1,#asked do
                    local a = asked[i]
                    local f = p[a]
                    if type(f) == "function" then
                        found[a] = f
                    end
                end
            end
        end
        local postprocessors = tfmdata.postprocessors or { }
        for i=1,#asked do
            local a = asked[i]
            local f = found[a]
            if f then
                postprocessors[#postprocessors+1] = f
            end
        end
        if #postprocessors > 0 then
            tfmdata.postprocessors = postprocessors
        end
    end
end

-- colorschemes

local colorschemes       = { }
fontgoodies.colorschemes = colorschemes
colorschemes.data        = { }

local function setcolorscheme(tfmdata,scheme)
    if type(scheme) == "string" then
        local goodies = tfmdata.goodies
        -- todo : check for already defined in shared
        if goodies then
            local what
            for i=1,#goodies do
                -- last one counts
                local g = goodies[i]
                what = (g.colorschemes and g.colorschemes[scheme]) or what
            end
            if what then
                -- this is font bound but we can share them if needed
                -- just as we could hash the conversions (per font)
                local hash, reverse = tfmdata.resources.unicodes, { }
                for i=1,#what do
                    local w = what[i]
                    for j=1,#w do
                        local name = w[j]
                        local unicode = hash[name]
                        if unicode then
                            reverse[unicode] = i
                        end
                    end
                end
                tfmdata.properties.colorscheme = reverse
                return
            end
        end
    end
    tfmdata.properties.colorscheme = false
end

local fontdata      = fonts.hashes.identifiers
local setnodecolor  = nodes.tracers.colors.set
local has_attribute = node.has_attribute
local traverse_id   = node.traverse_id
local a_colorscheme = attributes.private('colorscheme')
local glyph         = node.id("glyph")

function colorschemes.coloring(head)
    local lastfont, lastscheme
    local done = false
    for n in traverse_id(glyph,head) do
        local a = has_attribute(n,a_colorscheme)
        if a then
            local f = n.font
            if f ~= lastfont then
                lastscheme, lastfont = fontdata[f].properties.colorscheme, f
            end
            if lastscheme then
                local sc = lastscheme[n.char]
                if sc then
                    done = true
                    setnodecolor(n,"colorscheme:"..a..":"..sc) -- slow
                end
            end
        end
    end
    return head, done
end

function colorschemes.enable()
    nodes.tasks.appendaction("processors","fonts","fonts.goodies.colorschemes.coloring")
    function colorschemes.enable() end
end

local function setextrafeatures(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        for i=1,#goodies do
            local g = goodies[i]
            local f = g.features
            if f then
                for feature, specification in next, f do
                    addotffeature(tfmdata.shared.rawdata,feature,specification)
                    registerotffeature {
                        name        = feature,
                        description = format("extra: %s",feature)
                    }
                end
            end
        end
    end
end

-- installation (collected to keep the overview) -- also for type 1

registerotffeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

registerotffeature {
    name        = "extrafeatures",
    description = "extra features",
    default     = true,
    initializers = {
        position = 2,
        base     = setextrafeatures,
        node     = setextrafeatures,
    }
}

registerotffeature {
    name        = "featureset",
    description = "goodie feature set",
    initializers = {
        position = 3,
        base     = setfeatureset,
        node     = setfeatureset,
    }
}

registerotffeature {
    name        = "colorscheme",
    description = "goodie color scheme",
    initializers = {
        base = setcolorscheme,
        node = setcolorscheme,
    }
}

registerotffeature {
    name        = "postprocessor",
    description = "goodie postprocessor",
    initializers = {
        base = setpostprocessor,
        node = setpostprocessor,
    }
}

-- afm

registerafmfeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

-- tfm

registertfmfeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

-- experiment, we have to load the definitions immediately as they precede
-- the definition so they need to be initialized in the typescript

local function initialize(goodies)
    local mathgoodies = goodies.mathematics
    if mathgoodies then
        local virtuals = mathgoodies.virtuals
        local mapfiles = mathgoodies.mapfiles
        local maplines = mathgoodies.maplines
        if virtuals then
            for name, specification in next, virtuals do
                -- beware, they are all constructed
                mathematics.makefont(name,specification,goodies)
            end
        end
        if mapfiles then
            for i=1,#mapfiles do
                fonts.mappings.loadfile(mapfiles[i]) -- todo: backend function
            end
        end
        if maplines then
            for i=1,#maplines do
                fonts.mappings.loadline(maplines[i]) -- todo: backend function
            end
        end
    end
end

fontgoodies.register("mathematics", initialize)

-- the following takes care of explicit file specifications
--
-- files = {
--     name = "antykwapoltawskiego",
--     list = {
--         ["AntPoltLtCond-Regular.otf"] = {
--          -- name   = "antykwapoltawskiego",
--             style  = "regular",
--             weight = "light",
--             width  = "condensed",
--         },
--     },
-- }

-- math italics

-- it would be nice to have a \noitalics\font option

local function initialize(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        local shared = tfmdata.shared
        for i=1,#goodies do
            local mathgoodies = goodies[i].mathematics
            local mathitalics = mathgoodies and mathgoodies.italics
            if mathitalics then
                local properties = tfmdata.properties
                mathitalics = mathitalics[file.nameonly(properties.name)] or mathitalics
                if mathitalics then
                    if trace_goodies then
                        report_goodies("loading mathitalics for font '%s'",properties.name)
                    end
                    local corrections   = mathitalics.corrections
                    local defaultfactor = mathitalics.defaultfactor
                    local disableengine = mathitalics.disableengine
                    properties.hasitalics = true
                    properties.mathitalic_defaultfactor = defaultfactor -- we inherit outer one anyway (name will change)
                    if properties.mathitalics == nil then
                        properties.mathitalics = disableengine
                    end
                    if corrections then
                        -- As we want to set italic_correction (the context one) we need a
                        -- postprocessor instead of messing with the (unscaled) descriptions.
                        fontgoodies.registerpostprocessor(tfmdata, function(tfmdata) -- this is another tfmdata (a copy)
                            -- better make a helper so that we have less code being defined
                            local properties = tfmdata.properties
                            local parameters = tfmdata.parameters
                            local characters = tfmdata.characters
                            properties.hasitalics = true
                            properties.mathitalic_defaultfactor = defaultfactor
                            properties.mathitalic_defaultvalue  = defaultfactor * parameters.quad
                            if properties.mathitalics == nil then
                                properties.mathitalics = disableengine
                            end
                            if trace_goodies then
                                report_goodies("assigning mathitalics for font '%s'",properties.name)
                            end
                            local mathitalics = properties.mathitalics
                            local quad        = parameters.quad
                            local hfactor     = parameters.hfactor
                            for k, v in next, corrections do
                                local c = characters[k]
                                if v > -1 and v < 1 then
                                    v = v * quad
                                else
                                    v = v * hfactor
                                end
                                c.italic_correction = v -- for context
                                if mathitalics then
                                    c.italic = v -- for tex
                                else
                                    c.italic = nil
                                end
                            end
                        end)
                    end
                    return -- maybe not as these can accumulate
                end
            end
        end
    end
end

registerotffeature {
    name         = "mathitalics",
    description  = "additional math italic corrections",
 -- default      = true,
    initializers = {
        base = initialize,
        node = initialize,
    }
}

-- fontgoodies.register("mathitalics", initialize)

-- files

local function initialize(goodies)
    local files = goodies.files
    if files then
        fonts.names.register(files)
    end
end

fontgoodies.register("files", initialize)

-- some day we will have a define command and then we can also do some
-- proper tracing
--
-- fonts.typefaces["antykwapoltawskiego-condensed"] = {
--     shortcut     = "rm",
--     shape        = "serif",
--     fontname     = "antykwapoltawskiego",
--     normalweight = "light",
--     boldweight   = "medium",
--     width        = "condensed",
--     size         = "default",
--     features     = "default",
-- }

local function initialize(goodies)
    local typefaces = goodies.typefaces
    if typefaces then
        local ft = fonts.typefaces
        for k, v in next, typefaces do
            ft[k] = v
        end
    end
end

fontgoodies.register("typefaces", initialize)

local compositions = { }

function fontgoodies.getcompositions(tfmdata)
    return compositions[file.nameonly(tfmdata.properties.filename or "")]
end

local function initialize(goodies)
    local gc = goodies.compositions
    if gc then
        for k, v in next, gc do
            compositions[k] = v
        end
    end
end

fontgoodies.register("compositions", initialize)

local designsizes       = { }
fontgoodies.designsizes = designsizes
local designdata        = allocate()
designsizes.data        = designdata

local function initialize(goodies) -- design sizes are registered global
    local gd = goodies.designsizes
    if gd then
        for name, data in next, gd do
            local ranges = { }
            for size, file in next, data do
                if size ~= "default" then
                    ranges[#ranges+1] =  { texsp(size), file } -- also lower(file)
                end
            end
            table.sort(ranges,function(a,b) return a[1] < b[1] end)
            designdata[lower(name)] = { -- overloads, doesn't merge!
                default = data.default,
                ranges  = ranges,
            }
        end
    end
end

fontgoodies.register("designsizes", initialize)

function fontgoodies.designsizes.register(name,size,specification)
    local d = designdata[name]
    if not d then
        d = {
            ranges  = { },
            default = nil, -- so we have no default set
        }
        designdata[name] = d
    end
    if size == "default" then
        d.default = specification
    else
        if type(size) == "string" then
            size = texsp(size)
        end
        local ranges = d.ranges
        ranges[#ranges+1] = { size, specification }
    end
end

function fontgoodies.designsizes.filename(name,spec,size) -- returns nil of no match
    if spec and spec ~= "" then
        local data = designdata[lower(name)]
        if data then
            if spec == "default" then
                return data.default
            elseif spec == "auto" then
                local ranges = data.ranges
                if ranges then
                    for i=1,#ranges do
                        local r = ranges[i]
                        if r[1] >= size then -- todo: rounding so maybe size - 100
                            return r[2]
                        end
                    end
                end
                return data.default or (ranges and ranges[#ranges][2])
            end
        end
    end
end

-- The following file (husayni.lfg) is the experimental setup that we used
-- for Idris font. For the moment we don't store this in the cache and quite
-- probably these files sit in one of the paths:
--
-- tex/context/fonts/goodies
-- tex/fonts/goodies/context
-- tex/fonts/data/foundry/collection
--
-- see lfg files in distribution

-- interface

commands.loadfontgoodies        = fontgoodies.load
commands.enablefontcolorschemes = colorschemes.enable
