if not modules then modules = { } end modules ['font-gds'] = {
    version   = 1.000,
    comment   = "companion to font-gds.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next
local gmatch = string.gmatch

local trace_goodies = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)

local report_fonts = logs.new("fonts")

-- goodies=name,colorscheme=,featureset=
--
-- goodies=auto

-- goodies

fonts.goodies      = fonts.goodies      or { }
fonts.goodies.data = fonts.goodies.data or { }
fonts.goodies.list = fonts.goodies.list or { }

local data = fonts.goodies.data
local list = fonts.goodies.list

function fonts.goodies.report(what,trace,goodies)
    if trace_goodies or trace then
        local whatever = goodies[what]
        if whatever then
            report_fonts("goodie '%s' found in '%s'",what,goodies.name)
        end
    end
end

local function getgoodies(filename) -- maybe a merge is better
    local goodies = data[filename] -- we assume no suffix is given
    if goodies ~= nil then
        -- found or tagged unfound
    elseif type(filename) == "string" then
        local fullname = resolvers.find_file(file.addsuffix(filename,"lfg")) or "" -- prefered suffix
        if fullname == "" then
            fullname = resolvers.find_file(file.addsuffix(filename,"lua")) or "" -- fallback suffix
        end
        if fullname == "" then
            report_fonts("goodie file '%s.lfg' is not found",filename)
            data[filename] = false -- signal for not found
        else
            goodies = dofile(fullname) or false
            if not goodies then
                report_fonts("goodie file '%s' is invalid",fullname)
                return nil
            elseif trace_goodies then
                report_fonts("goodie file '%s' is loaded",fullname)
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

function fonts.goodies.register(name,fnc)
    list[name] = fnc
end

fonts.goodies.get = getgoodies

-- register goodies file

local preset_context = fonts.define.specify.preset_context

function fonts.initializers.common.goodies(tfmdata,value)
    local goodies = tfmdata.goodies or { } -- future versions might store goodies in the cached instance
    for filename in gmatch(value,"[^, ]+") do
        -- we need to check for duplicates
        local ok = getgoodies(filename)
        if ok then
            goodies[#goodies+1] = ok
        end
    end
    tfmdata.goodies = goodies -- shared ?
end

-- featuresets

local function flattened_features(t,tt)
    -- first set value dominates
    local tt = tt or { }
    for i=1,#t do
        local ti = t[i]
        if type(ti) == "table" then
            flattened_features(ti,tt)
        elseif tt[ti] == nil then
            tt[ti] = true
        end
    end
    for k, v in next, t do
        if type(k) ~= "number" then -- not tonumber(k)
            if type(v) == "table" then
                flattened_features(v,tt)
            elseif tt[k] == nil then
                tt[k] = v
            end
        end
    end
    return tt
end

fonts.flattened_features = flattened_features

function fonts.goodies.prepare_features(goodies,name,set)
    if set then
        local ff = flattened_features(set)
        local fullname = goodies.name .. "::" .. name
        local n, s = preset_context(fullname,"",ff)
        goodies.featuresets[name] = s -- set
        if trace_goodies then
            report_fonts("feature set '%s' gets number %s and name '%s'",name,n,fullname)
        end
        return n
    end
end

local function initialize(goodies,tfmdata)
    local featuresets = goodies.featuresets
    local goodiesname = goodies.name
    if featuresets then
        if trace_goodies then
            report_fonts("checking featuresets in '%s'",goodies.name)
        end
        for name, set in next, featuresets do
            fonts.goodies.prepare_features(goodies,name,set)
        end
    end
end

fonts.goodies.register("featureset",initialize)

function fonts.initializers.common.featureset(tfmdata,set)
    local goodies = tfmdata.goodies -- shared ?
    if goodies then
        local features = tfmdata.shared.features
        local what
        for i=1,#goodies do
            -- last one counts
            local g = goodies[i]
            what = (g.featuresets and g.featuresets[set]) or what
        end
        if what then
            for feature, value in next, what do
                if features[feature] == nil then
                    features[feature] = value
                end
            end
            tfmdata.mode = features.mode or tfmdata.mode
        end
    end
end

-- colorschemes

fonts.goodies.colorschemes      = fonts.goodies.colorschemes      or { }
fonts.goodies.colorschemes.data = fonts.goodies.colorschemes.data or { }

local colorschemes = fonts.goodies.colorschemes

function fonts.initializers.common.colorscheme(tfmdata,scheme)
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
                local hash, reverse = tfmdata.luatex.unicodes, { }
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
                tfmdata.colorscheme = reverse
                return
            end
        end
    end
    tfmdata.colorscheme = false
end

local fontdata      = fonts.ids
local fcs           = fonts.color.set
local has_attribute = node.has_attribute
local traverse_id   = node.traverse_id
local a_colorscheme = attributes.private('colorscheme')
local glyph         = node.id("glyph")

function fonts.goodies.colorschemes.coloring(head)
    local lastfont, lastscheme
    local done = false
    for n in traverse_id(glyph,head) do
        local a = has_attribute(n,a_colorscheme)
        if a then
            local f = n.font
            if f ~= lastfont then
                lastscheme, lastfont = fontdata[f].colorscheme, f
            end
            if lastscheme then
                local sc = lastscheme[n.char]
                if sc then
                    done = true
                    fcs(n,"colorscheme:"..a..":"..sc) -- slow
                end
            end
        end
    end
    return head, done
end

function fonts.goodies.colorschemes.enable()
    tasks.appendaction("processors","fonts","fonts.goodies.colorschemes.coloring")
    function fonts.goodies.colorschemes.enable() end
end

-- installation (collected to keep the overview)

fonts.otf.tables.features['goodies']     = 'Goodies on top of built in features'
fonts.otf.tables.features['featurset']   = 'Goodie Feature Set'
fonts.otf.tables.features['colorscheme'] = 'Goodie Color Scheme'

fonts.otf.features.register('goodies')
fonts.otf.features.register('featureset')
fonts.otf.features.register('colorscheme')

table.insert(fonts.triggers, 1, "goodies")
table.insert(fonts.triggers, 2, "featureset") -- insert after
table.insert(fonts.triggers,    "colorscheme")

fonts.initializers.base.otf.goodies     = fonts.initializers.common.goodies
fonts.initializers.node.otf.goodies     = fonts.initializers.common.goodies

fonts.initializers.base.otf.featureset  = fonts.initializers.common.featureset
fonts.initializers.node.otf.featureset  = fonts.initializers.common.featureset

fonts.initializers.base.otf.colorscheme = fonts.initializers.common.colorscheme
fonts.initializers.node.otf.colorscheme = fonts.initializers.common.colorscheme

-- experiment, we have to load the definitions immediately as they precede
-- the definition so they need to be initialized in the typescript

local function initialize(goodies)
    local mathgoodies = goodies.mathematics
    local virtuals = mathgoodies and mathgoodies.virtuals
    local mapfiles = mathgoodies and mathgoodies.mapfiles
    local maplines = mathgoodies and mathgoodies.maplines
    if virtuals then
        for name, specification in next, virtuals do
            mathematics.make_font(name,specification)
        end
    end
    if mapfiles then
        for i=1,#mapfiles do
            fonts.map.loadfile(mapfiles[i]) -- todo: backend function
        end
    end
    if maplines then
        for i=1,#maplines do
            fonts.map.loadline(maplines[i]) -- todo: backend function
        end
    end
end

fonts.goodies.register("mathematics", initialize)

-- The following file (husayni.lfg) is the experimental setup that we used
-- for Idris font. For the moment we don't store this in the cache and quite
-- probably these files sit in one of the paths:
--
-- tex/context/fonts/goodies
-- tex/fonts/goodies/context
-- tex/fonts/data/foundry/collection
--
-- see lfg files in distribution

