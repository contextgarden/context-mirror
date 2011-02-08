if not modules then modules = { } end modules ['font-enh'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: optimize a bit

local next, match = next, string.match

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_defining = logs.new("fonts","defining")

-- tfmdata has also fast access to indices and unicodes
-- to be checked: otf -> tfm -> tfmscaled
--
-- watch out: no negative depths and negative eights permitted in regular fonts

--[[ldx--
<p>Here we only implement a few helper functions.</p>
--ldx]]--

local fonts = fonts
local tfm   = fonts.tfm

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

-- auto complete font with missing composed characters

-- tfm features, experimental

tfm.features         = tfm.features         or { }
tfm.features.list    = tfm.features.list    or { }
tfm.features.default = tfm.features.default or { }

local initializers       = fonts.initializers
local triggers           = fonts.triggers
local manipulators       = fonts.manipulators
local featurelist        = tfm.features.list
local defaultfeaturelist = tfm.features.default

table.insert(manipulators,"compose")

function initializers.common.compose(tfmdata,value)
    if value then
        fonts.vf.aux.compose_characters(tfmdata)
    end
end

function tfm.enhance(tfmdata,specification)
    -- we don't really share tfm data because we always reload
    -- but this is more in sycn with afm and such
    local features = (specification.features and specification.features.normal ) or { }
    tfmdata.shared = tfmdata.shared or { }
    tfmdata.shared.features = features
    --  tfmdata.shared.tfmdata = tfmdata -- circular
    tfmdata.filename = specification.name
    if not features.encoding then
        local name, size = specification.name, specification.size
        local encoding, filename = match(name,"^(.-)%-(.*)$") -- context: encoding-name.*
        if filename and encoding and fonts.enc.known[encoding] then
            features.encoding = encoding
        end
    end
    tfm.setfeatures(tfmdata)
end

function tfm.setfeatures(tfmdata)
    -- todo: no local functions
    local shared = tfmdata.shared
--  local tfmdata = shared.tfmdata
    local features = shared.features
    if features and next(features) then
        local mode = tfmdata.mode or features.mode or "base"
        local fi = initializers[mode]
        if fi and fi.tfm then
            local function initialize(list) -- using tex lig and kerning
                if list then
                    -- fi adapts !
                    for i=1,#list do
                        local f = list[i]
                        local value = features[f]
                        if value then
                            local fitfmf = fi.tfm[f] -- brr
                            if fitfmf then
                                if tfm.trace_features then
                                    report_defining("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                                end
                                fitfmf(tfmdata,value)
                                mode = tfmdata.mode or features.mode or "base"
                                fi = initializers[mode]
                            end
                        end
                    end
                end
            end
            initialize(triggers)
            initialize(featurelist)
            initialize(manipulators)
        end
        local fm = fonts.methods[mode]
        if fm then
            local fmtfm = fm.tfm
            if fmtfm then
                local function register(list) -- node manipulations
                    if list then
                        local sp = shared.processors
                        local ns = sp and #sp
                        for i=1,#list do
                            local f = list[i]
                            if features[f] then
                                local fmtfmf = fmtfm[f]
                                if not fmtfmf then
                                    -- brr
                                elseif not sp then
                                    sp = { fmtfmf }
                                    ns = 1
                                    shared.processors = sp
                                else
                                    ns = ns + 1
                                    sp[ns] = fmtfmf
                                end
                            end
                        end
                    end
                end
                register(featurelist)
            end
        end
    end
end

function tfm.features.register(name,default)
    featurelist[#tfm.features.list+1] = name
    defaultfeaturelist[name] = default
end

function tfm.reencode(tfmdata,encoding)
    if encoding and fonts.enc.known[encoding] then
        local data = fonts.enc.load(encoding)
        if data then
            local characters, original, vector = tfmdata.characters, { }, data.vector
            tfmdata.encoding = encoding -- not needed
            for k, v in next, characters do
                v.name, v.index, original[k] = vector[k], k, v
            end
            for k,v in next, data.unicodes do
                if k ~= v then
                    if trace_defining then
                        report_defining("reencoding U+%04X to U+%04X",k,v)
                    end
                    characters[k] = original[v]
                end
            end
        end
    end
end

tfm.features.register('reencode')

initializers.base.tfm.reencode = tfm.reencode
initializers.node.tfm.reencode = tfm.reencode

fonts.enc            = fonts.enc            or { }
fonts.enc.remappings = fonts.enc.remappings or { }

function tfm.remap(tfmdata,remapping)
    local vector = remapping and fonts.enc.remappings[remapping]
    if vector then
        local characters, original = tfmdata.characters, { }
        for k, v in next, characters do
            original[k], characters[k] = v, nil
        end
        for k,v in next, vector do
            if k ~= v then
                if trace_defining then
                    report_defining("remapping U+%04X to U+%04X",k,v)
                end
                local c = original[k]
                characters[v] = c
                c.index = k
            end
        end
        tfmdata.encodingbytes = 2
        tfmdata.format = 'type1'
    end
end

tfm.features.register('remap')

initializers.base.tfm.remap = tfm.remap
initializers.node.tfm.remap = tfm.remap

--~ obsolete
--~
--~ function tfm.enhance(tfmdata,specification)
--~     local name, size = specification.name, specification.size
--~     local encoding, filename = match(name,"^(.-)%-(.*)$") -- context: encoding-name.*
--~     if filename and encoding and fonts.enc.known[encoding] then
--~         local data = fonts.enc.load(encoding)
--~         if data then
--~             local characters = tfmdata.characters
--~             tfmdata.encoding = encoding
--~             local vector = data.vector
--~             local original = { }
--~             for k, v in next, characters do
--~                 v.name = vector[k]
--~                 v.index = k
--~                 original[k] = v
--~             end
--~             for k,v in next, data.unicodes do
--~                 if k ~= v then
--~                     if trace_defining then
--~                         report_defining("mapping %s onto %s",k,v)
--~                     end
--~                     characters[k] = original[v]
--~                 end
--~             end
--~         end
--~     end
--~ end
