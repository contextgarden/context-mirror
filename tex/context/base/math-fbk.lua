if not modules then modules = { } end modules ['math-fbk'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_fallbacks = false  trackers.register("math.fallbacks", function(v) trace_fallbacks = v end)

local report_fallbacks = logs.reporter("math","fallbacks")

local formatters = string.formatters
local fastcopy = table.fastcopy

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
            textid         = self
            scriptid       = self
            scriptscriptid = self
        elseif mathsize == 2 then
            -- scriptsize
         -- textid         = nil -- self
            textid         = self
            scriptid       = lastmathids[3]
            scriptscriptid = lastmathids[3]
        else
            -- textsize
         -- textid         = nil -- self
            textid         = self
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
     -- report_fallbacks("used textid: %S, used script id: %S, used scriptscript id: %S",textid,scriptid,scriptscriptid)
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
                        report_fallbacks("extending font %a with %U",target.properties.fullname,k)
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

-- local function repeated(data,char,n,fraction)
--     local character = data.characters[char]
--     if character then
--         local width = character.width
--         local delta = width - character.italic -- width * fraction
--         local c = { "char", char }
--         local r = { "right", right }
--         local commands = { }
--         for i=1,n-1 do
--             width = width + delta
--             commands[#commands+1] = c
--             commands[#commands+1] = -delta
--         end
--         commands[#commands+1] = c
--         return {
--             width    = width,
--             height   = character.height,
--             depth    = character.depth,
--             commands = commands,
--         }
--     end
-- end

-- virtualcharacters[0x222C] = function(data)
--     return repeated(data,0x222B,2,1/8)
-- end

-- virtualcharacters[0x222D] = function(data)
--     return repeated(data,0x222B,3,1/8)
-- end

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
 -- return combined(data,0x2212,0x2212) -- relbar, relbar  (isn't that just equal)
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

-- we could move the defs from math-act here

addextra(0xFE3DE, { description="EXTENSIBLE OF 0x03DE", unicodeslot=0xFE3DE, mathextensible = "r", mathstretch = "h" } )
addextra(0xFE3DF, { description="EXTENSIBLE OF 0x03DF", unicodeslot=0xFE3DF, mathextensible = "r", mathstretch = "h" } )
addextra(0xFE3DC, { description="EXTENSIBLE OF 0x03DC", unicodeslot=0xFE3DC, mathextensible = "r", mathstretch = "h" } )
addextra(0xFE3DD, { description="EXTENSIBLE OF 0x03DD", unicodeslot=0xFE3DD, mathextensible = "r", mathstretch = "h" } )
addextra(0xFE3B4, { description="EXTENSIBLE OF 0x03B4", unicodeslot=0xFE3B4, mathextensible = "r", mathstretch = "h" } )
addextra(0xFE3B5, { description="EXTENSIBLE OF 0x03B5", unicodeslot=0xFE3B5, mathextensible = "r", mathstretch = "h" } )

local function accent_to_extensible(target,newchr,original,oldchr,height,depth,swap)
    local characters = target.characters
    local addprivate = fonts.helpers.addprivate
    local olddata = characters[oldchr]
    if olddata then
        if swap then
            swap = characters[swap]
            height = swap.depth
            depth  = 0
        else
            height = height or 0
            depth  = depth  or 0
        end
        local correction = swap and { "down", (olddata.height or 0) - height } or { "down", olddata.height }
        local newdata = {
            commands = { correction, { "slot", 1, oldchr } },
            width    = olddata.width,
            height   = height,
            depth    = depth,
        }
        local glyphdata = newdata
        local nextglyph = olddata.next
        while nextglyph do
            local oldnextdata = characters[nextglyph]
            local newnextdata = {
                commands = { correction, { "slot", 1, nextglyph } },
                width    = oldnextdata.width,
                height   = height,
                depth    = depth,
            }
            local newnextglyph = addprivate(target,formatters["original-%H"](nextglyph),newnextdata)
            newdata.next = newnextglyph
            local nextnextglyph = oldnextdata.next
            if nextnextglyph == nextglyph then
                break
            else
                olddata   = oldnextdata
                newdata   = newnextdata
                nextglyph = nextnextglyph
            end
        end
        local hv = olddata.horiz_variants
        if hv then
            hv = fastcopy(hv)
            newdata.horiz_variants = hv
            for i=1,#hv do
                local hvi = hv[i]
                local oldglyph = hvi.glyph
                local olddata = characters[oldglyph]
                local newdata = {
                    commands = { correction, { "slot", 1, oldglyph } },
                    width    = olddata.width,
                    height   = height,
                    depth    = depth,
                }
                hvi.glyph = addprivate(target,formatters["original-%H"](oldglyph),newdata)
            end
        end
        return glyphdata
    end
end

virtualcharacters[0x203E] = function(data) -- could be FE33E instead
    local target = data.target
    local height, depth = 0, 0
    local mathparameters = target.mathparameters
    if mathparameters then
        height = mathparameters.OverbarVerticalGap
        depth  = mathparameters.UnderbarVerticalGap
    else
        height = target.parameters.xheight/4
        depth  = height
    end
    return accent_to_extensible(target,0x203E,data.original,0x0305,height,depth)
end

virtualcharacters[0xFE33E] = virtualcharacters[0x203E] -- convenient
virtualcharacters[0xFE33F] = virtualcharacters[0x203E] -- convenient

virtualcharacters[0xFE3DE] = function(data)
    local target, original = data.target, data.original
    local chardata = target.characters[0x23DE]
    if chardata and chardata.height > target.parameters.xheight then
        return accent_to_extensible(target,0xFE3DE,original,0x23DE,0,0,0x23DF)
    else
        return original.characters[0x23DE]
    end
end

virtualcharacters[0xFE3DC] = function(data)
    local target, original = data.target, data.original
    local chardata = target.characters[0x23DC]
    if chardata and chardata.height > target.parameters.xheight then
        return accent_to_extensible(target,0xFE3DC,original,0x23DC,0,0,0x23DD)
    else
        return original.characters[0x23DC]
    end
end

virtualcharacters[0xFE3B4] = function(data)
    local target, original = data.target, data.original
    local chardata = target.characters[0x23B4]
    if chardata and chardata.height > target.parameters.xheight then
        return accent_to_extensible(target,0xFE3B4,original,0x23B4,0,0,0x23B5)
    else
        return original.characters[0x23B4]
    end
end

virtualcharacters[0xFE3DF] = function(data)
    return data.original.characters[0x23DF]
end

virtualcharacters[0xFE3DD] = function(data)
    return data.original.characters[0x23DD]
end

virtualcharacters[0xFE3B5] = function(data)
    return data.original.characters[0x23B5]
end
