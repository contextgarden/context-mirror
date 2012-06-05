if not modules then modules = { } end modules ['math-fbk'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_fallbacks = false  trackers.register("math.fallbacks", function(v) trace_fallbacks = v end)

local report_fallbacks = logs.reporter("math","fallbacks")

local fallbacks       = { }
mathematics.fallbacks = fallbacks

local virtualcharacters = { }

local identifiers = fonts.hashes.identifiers
local lastmathids = fonts.hashes.lastmathids

-- we need a trick (todo): if we define scriptscript, script and text in
-- that order we could use their id's .. i.e. we could always add a font
-- table with those id's .. in fact, we could also add a whole lot more
-- as it doesn't hurt
--
-- todo: use index 'true when luatex provides that feature (on the agenda)

function fallbacks.apply(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        local characters = target.characters
        local parameters = target.parameters
        local mathsize   = parameters.mathsize
        local size       = parameters.size
        local usedfonts  = target.fonts
        if not usedfonts then
            usedfonts    = {  }
            target.fonts = usedfonts
        end
        local textid             = true -- font.nextid() -- this will fail when we create more than one virtual set
        local scriptid           = textid
        local scriptscriptid     = textid
        local lastscriptid       = lastmathids[2]
        local lastscriptscriptid = lastmathids[3]
        if mathsize == 3 then
            -- scriptscriptsize
        elseif mathsize == 2 then
            -- scriptsize
            scriptid       = lastscriptscriptid or textid
            scriptscriptid = scriptid
        else
            -- textsize
            scriptid       = lastscriptid or textid
            scriptscriptid = lastscriptscriptid or scriptid
        end
        local textindex, scriptindex, scriptscriptindex
        local textdata, scriptdata, scriptscriptdata
        if textid ~= true then
            textindex = #usedfonts  + 1
            usedfonts[textindex] = { id = textid }
            textdata = identifiers[textid]
        else
            textid = nil
            textdata = target
        end
        if scriptid ~= true then
            scriptindex = #usedfonts  + 1
            usedfonts[scriptindex] = { id = scriptid }
            scriptdata = identifiers[scriptid]
        else
            scriptid = textid
            scriptdata = textdata
        end
        if scriptscriptid ~= true then
            scriptscriptindex = #usedfonts  + 1
            usedfonts[scriptscriptindex] = { id = scriptscriptid }
            scriptscriptdata = identifiers[scriptscriptid]
        else
            scriptscriptid = scriptid
            scriptscriptdata = scriptdata
        end
        local data = {
            textdata          = textdata,
            scriptdata        = scriptdata,
            scriptscriptdata  = scriptscriptdata,
            textindex         = textindex,
            scriptindex       = scriptindex,
            scriptscriptindex = scriptscriptindex,
            characters        = characters,
            unicode           = k,
            target            = target,
            original          = original,
            size              = size,
        }
        for k, v in next, virtualcharacters do
            if not characters[k] then
                local tv = type(v)
                if tv == "table" then
                    characters[k] = v
                elseif tv == "number" then
                    characters[k] = characters[v]
                elseif tv == "function" then
                    characters[k] = v(data)
                end
                if trace_fallbacks then
                    if characters[k] then
                        report_fallbacks("extending font %q with U+%05X",target.properties.fullname,k)
                    end
                end
            end
        end
    end
end

utilities.sequencers.appendaction("aftercopyingcharacters","system","mathematics.fallbacks.apply")

function fallbacks.install(unicode,value)
    virtualcharacters[unicode] = value
end

-- a few examples:

local function reference(index,char)
    if index then
        return { "slot", index, char }
    else
        return { "char", char }
    end
end

local function raised(data,down)
    local replacement = data.replacement
    local character = data.scriptdata.characters[replacement]
    if character then
        return {
            width    = character.width,
            height   = character.height,
            depth    = character.depth,
            commands = {
                { "down", down and data.size/4 or -data.size/2 } , -- maybe exheight
                reference(data.scriptindex,replacement)
            }
        }
    end
end

-- virtualcharacters[0x207A] = 0x2212
-- virtualcharacters[0x207B] = 0x002B
-- virtualcharacters[0x208A] = 0x2212
-- virtualcharacters[0x208B] = 0x002B

virtualcharacters[0x207A] = function(data)
    data.replacement = 0x2212
    return raised(data)
end

virtualcharacters[0x207B] = function(data)
    data.replacement = 0x002B
    return raised(data)
end

virtualcharacters[0x208A] = function(data)
    data.replacement = 0x2212
    return raised(data,true)
end

virtualcharacters[0x208B] = function(data)
    data.replacement = 0x002B
    return raised(data,true)
end
