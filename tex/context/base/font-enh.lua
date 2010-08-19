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

local report_define = logs.new("define fonts")

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

table.insert(fonts.manipulators,"compose")

function fonts.initializers.common.compose(tfmdata,value)
    if value then
        fonts.vf.aux.compose_characters(tfmdata)
    end
end

-- tfm features, experimental

tfm.features         = tfm.features         or { }
tfm.features.list    = tfm.features.list    or { }
tfm.features.default = tfm.features.default or { }

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
        local fi = fonts.initializers[mode]
        if fi and fi.tfm then
            local function initialize(list) -- using tex lig and kerning
                if list then
                    for i=1,#list do
                        local f = list[i]
                        local value = features[f]
                        if value and fi.tfm[f] then -- brr
                            if tfm.trace_features then
                                report_define("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                            end
                            fi.tfm[f](tfmdata,value)
                            mode = tfmdata.mode or features.mode or "base"
                            fi = fonts.initializers[mode]
                        end
                    end
                end
            end
            initialize(fonts.triggers)
            initialize(tfm.features.list)
            initialize(fonts.manipulators)
        end
        local fm = fonts.methods[mode]
        if fm and fm.tfm then
            local function register(list) -- node manipulations
                if list then
                    for i=1,#list do
                        local f = list[i]
                        if features[f] and fm.tfm[f] then -- brr
                            if not shared.processors then -- maybe also predefine
                                shared.processors = { fm.tfm[f] }
                            else
                                shared.processors[#shared.processors+1] = fm.tfm[f]
                            end
                        end
                    end
                end
            end
            register(tfm.features.list)
        end
    end
end

function tfm.features.register(name,default)
    tfm.features.list[#tfm.features.list+1] = name
    tfm.features.default[name] = default
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
                        report_define("reencoding U+%04X to U+%04X",k,v)
                    end
                    characters[k] = original[v]
                end
            end
        end
    end
end

tfm.features.register('reencode')

fonts.initializers.base.tfm.reencode = tfm.reencode
fonts.initializers.node.tfm.reencode = tfm.reencode

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
                    report_define("remapping U+%04X to U+%04X",k,v)
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

fonts.initializers.base.tfm.remap = tfm.remap
fonts.initializers.node.tfm.remap = tfm.remap

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
--~                         report_define("mapping %s onto %s",k,v)
--~                     end
--~                     characters[k] = original[v]
--~                 end
--~             end
--~         end
--~     end
--~ end
