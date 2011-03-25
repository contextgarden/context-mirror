if not modules then modules = { } end modules ['font-enh'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next

local trace_defining     = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local report_defining    = logs.reporter("fonts","defining")

local fonts              = fonts
local constructors       = fonts.constructors

local tfmfeatures        = constructors.newfeatures("tfm")
local registertfmfeature = tfmfeatures.register

local fontencodings      = fonts.encodings
fontencodings.remappings = fontencodings.remappings or { }

local function reencode(tfmdata,encoding)
    if encoding and fontencodings.known[encoding] then
        local data = fontencodings.load(encoding)
        if data then
            tfmdata.properties.encoding = encoding
            local characters = tfmdata.characters
            local original   = { }
            local vector     = data.vector
            for unicode, character in next, characters do
                character.name    = vector[unicode]
                character.index   = unicode, character
                original[unicode] = character
            end
            for newcode, oldcode in next, data.unicodes do
                if newcode ~= oldcode then
                    if trace_defining then
                        report_defining("reencoding U+%04X to U+%04X",newcode,oldcode)
                    end
                    characters[newcode] = original[oldcode]
                end
            end
        end
    end
end

registertfmfeature {
    name         = "reencode",
    description  = "reencode",
    manipulators = {
        base = reencode,
        node = reencode,
    }
}

local function remap(tfmdata,remapping)
    local vector = remapping and fontencodings.remappings[remapping]
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
        local properties = tfmdata.properties
        if not properties then
            properties = { }
            tfmdata.properties = properties
        else
            properties.encodingbytes = 2
            properties.format        = properties.format or 'type1'
        end
    end
end

registertfmfeature {
    name         = "remap",
    description  = "remap",
    manipulators = {
        base = remap,
        node = remap,
    }
}
