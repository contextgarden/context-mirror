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
        -- This is not okay yet ... we have no proper way to refer to 'self'
        -- otherwise I will make my own id allocator).
local self = #usedfonts == 0 and font.nextid() or nil -- will be true
        local textid, scriptid, scriptscriptid
        local textindex, scriptindex, scriptscriptindex
        local textdata, scriptdata, scriptscriptdata
        if mathsize == 3 then
            -- scriptscriptsize
         -- textid         = nil -- self
         -- scriptid       = nil -- no smaller
         -- scriptscriptid = nil -- no smaller
textid = self
scriptid = self
scriptscriptid = self
        elseif mathsize == 2 then
            -- scriptsize
         -- textid         = nil -- self
textid = self
            scriptid       = lastmathids[3]
            scriptscriptid = lastmathids[3]
        else
            -- textsize
         -- textid         = nil -- self
textid = self
            scriptid       = lastmathids[2]
            scriptscriptid = lastmathids[3]
        end
        if textid then
            textindex = #usedfonts + 1
            usedfonts[textindex] = { id = textid }
            textdata = identifiers[textid]
        else
            textdata = target
        end
        if scriptid then
            scriptindex = #usedfonts  + 1
            usedfonts[scriptindex] = { id = scriptid }
            scriptdata = identifiers[scriptid]
        else
            scriptindex = textindex
            scriptdata  = textdata
        end
        if scriptscriptid then
            scriptscriptindex = #usedfonts  + 1
            usedfonts[scriptscriptindex] = { id = scriptscriptid }
            scriptscriptdata = identifiers[scriptscriptid]
        else
            scriptscriptindex = scriptindex
            scriptscriptdata  = scriptdata
        end
-- report_fallbacks("used textid: %s, used script id: %s, used scriptscript id: %s",
--     tostring(textid),tostring(scriptid),tostring(scriptscriptid))
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
            mathsize          = mathsize,
        }
-- inspect(usedfonts)
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
                { "down", down and data.size/4 or -data.size/2 }, -- maybe exheight
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

local addextra = mathematics.extras.add

addextra(0xFE350, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW LEFT END",
    mathclass="relation",
    mathname="ctxdoublearrowfillleftend",
    unicodeslot=0xFE350,
} )

addextra(0xFE351, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW MIDDLE PART",
    mathclass="relation",
    mathname="ctxdoublearrowfillmiddlepart",
    unicodeslot=0xFE351,
} )

addextra(0xFE352, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW RIGHT END",
    mathclass="relation",
    mathname="ctxdoublearrowfillrightend",
    unicodeslot=0xFE352,
} )

local push       = { "push" }
local pop        = { "pop" }
local leftarrow  = { "char", 0x2190 }
local relbar     = { "char", 0x2212 }
local rightarrow = { "char", 0x2192 }

virtualcharacters[0xFE350] = function(data)
 -- return combined(data,0x2190,0x2212) -- leftarrow relbar
    local charone = data.characters[0x2190]
    local chartwo = data.characters[0x2212]
    if charone and chartwo then
        local size = data.size/2
        return {
            width    = chartwo.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                leftarrow,
                pop,
                { "down", -size/2 },
                relbar,
            }
        }
    end
end

virtualcharacters[0xFE351] = function(data)
 -- return combined(data,0x2212,0x2212) -- relbar, relbar
    local char = data.characters[0x2212]
    if char then
        local size = data.size/2
        return {
            width    = char.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                relbar,
                pop,
                { "down", -size/2 },
                relbar,
            }
        }
    end
end

virtualcharacters[0xFE352] = function(data)
 -- return combined(data,0x2192,0x2212) -- rightarrow relbar
    local charone = data.characters[0x2192]
    local chartwo = data.characters[0x2212]
    if charone and chartwo then
        local size = data.size/2
        return {
            width    = chartwo.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                relbar,
                pop,
                { "right", chartwo.width - charone.width },
                { "down", -size/2 },
                rightarrow,
            }
        }
    end
end

