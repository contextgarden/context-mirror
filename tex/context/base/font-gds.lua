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
            logs.report("fonts", "goodie '%s' found in '%s'",what,goodies.name)
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
            logs.report("fonts", "goodie file '%s.lfg' is not found",filename)
            data[filename] = false -- signal for not found
        else
            goodies = dofile(fullname) or false
            if not goodies then
                logs.report("fonts", "goodie file '%s' is invalid",fullname)
                return nil
            elseif trace_goodies then
                logs.report("fonts", "goodie file '%s' is loaded",fullname)
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

local function flattened(t,tt)
    -- first set value dominates
    local tt = tt or { }
    for i=1,#t do
        local ti = t[i]
        if type(ti) == "table" then
            flattened(ti,tt)
        elseif tt[ti] == nil then
            tt[ti] = true
        end
    end
    for k, v in next, t do
        if type(k) ~= "number" then
            if type(v) == "table" then
                flattened(v,tt)
            elseif tt[k] == nil then
                tt[k] = v
            end
        end
    end
    return tt
end

fonts.flattened_features = flattened

function fonts.goodies.prepare_features(goodies,name,set)
    if set then
        local ff = fonts.flattened_features(set)
        local fullname = goodies.name .. "::" .. name
        local n, s = preset_context(fullname,"",ff)
        goodies.featuresets[name] = s -- set
        if trace_goodies then
            logs.report("fonts", "feature set '%s' gets number %s and name '%s'",name,n,fullname)
        end
        return n
    end
end

local function initialize(goodies,tfmdata)
    local featuresets = goodies.featuresets
    local goodiesname = goodies.name
    if featuresets then
        if trace_goodies then
            logs.report("fonts", "checking featuresets in '%s'",goodies.name)
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
                    fcs(n,"colorscheme:"..a..":"..sc) -- slow
                end
            end
        end
    end
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

--~ local yes = "yes", "node"

--~ local basics = {
--~     analyze  = yes,
--~     mode     = "node",
--~     language = "dflt",
--~     script   = "arab",
--~ }

--~ local analysis = {
--~     ccmp = yes,
--~     init = yes, medi = yes, fina = yes,
--~ }

--~ local regular = {
--~    rlig = yes, calt = yes, salt = yes, anum = yes,
--~    ss01 = yes, ss03 = yes, ss07 = yes, ss10 = yes, ss12 = yes, ss15 = yes, ss16 = yes,
--~    ss19 = yes, ss24 = yes, ss25 = yes, ss26 = yes, ss27 = yes, ss31 = yes, ss34 = yes,
--~    ss35 = yes, ss36 = yes, ss37 = yes, ss38 = yes, ss41 = yes, ss42 = yes, ss43 = yes,
--~    js16 = yes,
--~ }

--~ local positioning = {
--~    kern = yes, curs = yes, mark = yes, mkmk = yes,
--~ }

--~ return {
--~     name = "husayni",
--~     version = "1.00",
--~     comment = "Goodies that complement the Husayni font by Idris Samawi Hamid.",
--~     author = "Idris Samawi Hamid and Hans Hagen",
--~     featuresets = {
--~         default = {
--~             basics, analysis, regular, positioning, -- xxxx = yes, yyyy = 2,
--~         },
--~     },
--~     stylistics = {
--~         ss01 = "Allah, Muhammad",
--~         ss02 = "ss01 + Allah_final",
--~         ss03 = "level-1 stack over Jiim, initial entry only",
--~         ss04 = "level-1 stack over Jiim, initial/medial entry",
--~         ss05 = "multi-level Jiim stacking, initial/medial entry",
--~         ss06 = "aesthetic Faa/Qaaf for FJ_mm, FJ_mf connection",
--~         ss07 = "initial-entry stacking over Haa",
--~         ss08 = "initial/medial stacking over Haa, minus HM_mf strings",
--~         ss09 = "initial/medial Haa stacking plus HM_mf strings",
--~         ss10 = "basic dipped Miim, initial-entry B_S-stack over Miim",
--~         ss11 = "full dipped Miim, initial-entry B_S-stack over Miim",
--~         ss12 = "XBM_im initial-medial entry B_S-stack over Miim",
--~         ss13 = "full initial-medial entry B_S-stacked Miim",
--~         ss14 = "initial entry, stacked Laam on Miim",
--~         ss15 = "full stacked Laam-on-Miim",
--~         ss16 = "initial entry, stacked Ayn-on-Miim",
--~         ss17 = "full stacked Ayn-on-Miim",
--~         ss18 = "LMJ_im already contained in ss03--05, may remove",
--~         ss19 = "LM_im",
--~         ss20 = "KLM_m, sloped Miim",
--~         ss21 = "KLM_i_mm/LM_mm, sloped Miim",
--~         ss22 = "filled sloped Miim",
--~         ss23 = "LM_mm, non-sloped Miim",
--~         ss24 = "BR_i_mf, BN_i_mf",
--~         ss25 = "basic LH_im might merge with ss24",
--~         ss26 = "full Yaa.final special strings: BY_if, BY_mf, LY_mf",
--~         ss27 = "basic thin Miim.final",
--~         ss28 = "full thin Miim.final to be moved to jsnn",
--~         ss29 = "basic short Miim.final",
--~         ss30 = "full short Miim.final to be moved to jsnn",
--~         ss31 = "basic Raa.final strings: JR and SR",
--~         ss32 = "basic Raa.final strings: JR, SR, and BR",
--~         ss33 = "TtR to be moved to jsnn",
--~         ss34 = "AyR style also available in jsnn",
--~         ss35 = "full Kaaf contexts",
--~         ss36 = "full Laam contexts",
--~         ss37 = "Miim-Miim contexts",
--~         ss38 = "basic dipped Haa, B_SH_mm",
--~         ss39 = "full dipped Haa,  B_S_LH_i_mm_Mf",
--~         ss40 = "aesthetic dipped medial Haa",
--~         ss41 = "high and low Baa strings",
--~         ss42 = "diagonal entry",
--~         ss43 = "initial alternates",
--~         ss44 = "hooked final alif",
--~         ss45 = "BMA_f",
--~         ss46 = "BM_mm_alt, for JBM combinations",
--~         ss47 = "Shaddah-<kasrah> combo",
--~         ss48 = "Auto-sukuun",
--~         ss49 = "No vowels",
--~         ss50 = "Shaddah/MaaddahHamzah only",
--~         ss51 = "No Skuun",
--~         ss52 = "No Waslah",
--~         ss53 = "No Waslah",
--~         ss54 = "chopped finals",
--~         ss55 = "idgham-tanwin",
--~         js01 = "Raawide",
--~         js02 = "Yaawide",
--~         js03 = "Kaafwide",
--~         js04 = "Nuunwide",
--~         js05 = "Kaafwide Nuunwide Siinwide Baawide",
--~         js06 = "final Haa wide",
--~         js07 = "thin Miim",
--~         js08 = "short Miim",
--~         js09 = "wide Siin",
--~         js10 = "thuluth-style initial Haa, final Miim, MRw_mf",
--~         js11 = "level-1 stretching",
--~         js12 = "level-2 stretching",
--~         js13 = "level-3 stretching",
--~         js14 = "final Alif",
--~         js15 = "hooked final Alif",
--~         js16 = "aesthetic medial Faa/Qaaf",
--~         js17 = "fancy isol Haa after Daal, Raa, and Waaw",
--~         js18 = "Laamwide, alternate substitution",
--~         js19 = "level-4 stretching, only siin and Hhaa for basmalah",
--~         js20 = "level-5 stretching, only siin and Hhaa for basmalah",
--~         js21 = "Haa.final_alt2",
--~     },
--~     colorschemes = {
--~         default = {
--~             [1] = {
--~                 "Onedotabove", "Onedotbelow", "Twodotsabove", "Twodotsbelow", "Threedotsabove", "Twodotsabove.vrt", "Twodotsbelow.vrt", "Twodotsabove.KBA", "Threedotsabove.KBA", "Threedotsbelowinv",
--~             },
--~             [2] = {
--~                 "Fathah", "Dammah", "Kasrah", "FathahVertical", "DammahInverted", "KasrahVertical", "FathahVertical.alt1", "KasrahVertical.alt1", "FathahTanwiin", "DammahTanwiin", "KasrahTanwiin", "Shaddah", "Sukuun", "MaaddahHamzah", "Jazm", "Maaddah", "DammahTanwiin_alt2", "DammahTanwiin_alt1", "FathahTanwiin_alt1", "KasrahTanwiin_alt1", "Fathah.mkmk", "Dammah.mkmk", "Kasrah.mkmk", "FathahVertical.mkmk", "DammahInverted.mkmk", "KasrahVertical.mkmk", "FathahTanwiin.mkmk", "DammahTanwiin.mkmk", "KasrahTanwiin.mkmk", "DammahTanwiin_alt1.mkmk",
--~             },
--~             [3] = {
--~                 "Ttaa.waqf", "SsLY.waqf", "QLY.waqf", "Miim.waqf", "LA.waqf", "Jiim.waqf", "Threedotsabove.waqf", "Siin.waqf", "Ssaad.waqf", "Qaaf.waqf", "SsL.waqf", "QF.waqf", "SKTH.waqf", "WQFH.waqf", "Kaaf.waqf", "Ayn.ruku",
--~             },
--~             [4] = {
--~                 "Hamzah","Hamzahabove", "Hamzahbelow", "MaaddahHamzah.identity", "Waslah",
--~             },
--~             [5] = {
--~                 "Waawsmall", "Yaasmall", "FathahVertical.alt2", "Waawsmall.isol", "Yaasmall.isol", "FathahVertical.isol",
--~             },
--~             [6] = {
--~                 "Miim.nuun_high", "Siin.Ssaad", "Nuunsmall", "emptydot_low", "emptydot_high", "Sifr.fill", "Miim.nuun_low", "Nuun.tanwiin",
--~             },
--~             [7] = {
--~                 "Ayah", "Yaasmall", "Ayah.alt1", "Ayah.alt2", "Ayah.alt3", "Ayah2",
--~             }
--~         }
--~     }
--~ }
