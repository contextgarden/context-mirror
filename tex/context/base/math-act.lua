if not modules then modules = { } end modules ['math-act'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we tweak some font properties (if needed).

local type, next = type, next
local fastcopy = table.fastcopy

local trace_defining = false  trackers.register("math.defining", function(v) trace_defining = v end)
local report_math    = logs.reporter("mathematics","initializing")

local context        = context
local commands       = commands
local mathematics    = mathematics
local texdimen       = tex.dimen
local abs            = math.abs

local sequencers     = utilities.sequencers
local appendgroup    = sequencers.appendgroup
local appendaction   = sequencers.appendaction

local mathfontparameteractions = sequencers.new {
    name      = "mathparameters",
    arguments = "target,original",
}

appendgroup("mathparameters","before") -- user
appendgroup("mathparameters","system") -- private
appendgroup("mathparameters","after" ) -- user

function fonts.constructors.assignmathparameters(original,target)
    local runner = mathfontparameteractions.runner
    if runner then
        runner(original,target)
    end
end

function mathematics.initializeparameters(target,original)
    local mathparameters = original.mathparameters
    if mathparameters and next(mathparameters) then
        target.mathparameters = mathematics.dimensions(mathparameters)
    end
end

sequencers.appendaction("mathparameters","system","mathematics.initializeparameters")

local how = {
 -- RadicalKernBeforeDegree         = "horizontal",
 -- RadicalKernAfterDegree          = "horizontal",
    ScriptPercentScaleDown          = "unscaled",
    ScriptScriptPercentScaleDown    = "unscaled",
    RadicalDegreeBottomRaisePercent = "unscaled"
}

function mathematics.scaleparameters(target,original)
    if not target.properties.math_is_scaled then
        local mathparameters = target.mathparameters
        if mathparameters and next(mathparameters) then
            local parameters = target.parameters
            local factor  = parameters.factor
            local hfactor = parameters.hfactor
            local vfactor = parameters.vfactor
            for name, value in next, mathparameters do
                local h = how[name]
                if h == "unscaled" then
                    -- kept
                elseif h == "horizontal" then
                    value = value * hfactor
                elseif h == "vertical"then
                    value = value * vfactor
                else
                    value = value * factor
                end
               mathparameters[name] = value
            end
        end
        target.properties.math_is_scaled = true
    end
end

sequencers.appendaction("mathparameters","system","mathematics.scaleparameters")

function mathematics.checkaccentbaseheight(target,original)
    local mathparameters = target.mathparameters
    if mathparameters and mathparameters.AccentBaseHeight == 0 then
        mathparameters.AccentBaseHeight = target.parameters.x_height -- needs checking
    end
end

sequencers.appendaction("mathparameters","system","mathematics.checkaccentbaseheight") -- should go in lfg instead

function mathematics.checkprivateparameters(target,original)
    local mathparameters = target.mathparameters
    if mathparameters then
        local parameters = target.parameters
        if parameters then
            if not mathparameters.FractionDelimiterSize then
                mathparameters.FractionDelimiterSize = 1.01 * parameters.size
            end
            if not mathparameters.FractionDelimiterDisplayStyleSize then
                mathparameters.FractionDelimiterDisplayStyleSize = 2.40 * parameters.size
            end
        elseif target.properties then
            report_math("no parameters in font %a",target.properties.fullname or "?")
        else
            report_math("no parameters and properties in font")
        end
    end
end

sequencers.appendaction("mathparameters","system","mathematics.checkprivateparameters")

function mathematics.overloadparameters(target,original)
    local mathparameters = target.mathparameters
    if mathparameters and next(mathparameters) then
        local goodies = target.goodies
        if goodies then
            for i=1,#goodies do
                local goodie = goodies[i]
                local mathematics = goodie.mathematics
                local parameters  = mathematics and mathematics.parameters
                if parameters then
                    if trace_defining then
                        report_math("overloading math parameters in %a @ %p",target.properties.fullname,target.parameters.size)
                    end
                    for name, value in next, parameters do
                        local tvalue = type(value)
                        if tvalue == "string" then
                            report_math("comment for math parameter %a: %s",name,value)
                        else
                            local oldvalue = mathparameters[name]
                            local newvalue = oldvalue
                            if oldvalue then
                                if tvalue == "number" then
                                    newvalue = value
                                elseif tvalue == "function" then
                                    newvalue = value(oldvalue,target,original)
                                elseif not tvalue then
                                    newvalue = nil
                                end
                                if trace_defining and oldvalue ~= newvalue then
                                    report_math("overloading math parameter %a: %S => %S",name,oldvalue,newvalue)
                                end
                            else
                                report_math("invalid math parameter %a",name)
                            end
                            mathparameters[name] = newvalue
                        end
                    end
                end
            end
        end
    end
end

sequencers.appendaction("mathparameters","system","mathematics.overloadparameters")

local function applytweaks(when,target,original)
    local goodies = original.goodies
    if goodies then
        for i=1,#goodies do
            local goodie = goodies[i]
            local mathematics = goodie.mathematics
            local tweaks = mathematics and mathematics.tweaks
            if tweaks then
                tweaks = tweaks[when]
                if tweaks then
                    if trace_defining then
                        report_math("tweaking math of %a @ %p (%s)",target.properties.fullname,target.parameters.size,when)
                    end
                    for i=1,#tweaks do
                        local tweak= tweaks[i]
                        local tvalue = type(tweak)
                        if tvalue == "function" then
                            tweak(target,original)
                        end
                    end
                end
            end
        end
    end
end

function mathematics.tweakbeforecopyingfont(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        applytweaks("beforecopying",target,original)
    end
end

function mathematics.tweakaftercopyingfont(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        applytweaks("aftercopying",target,original)
    end
end

sequencers.appendaction("beforecopyingcharacters","system","mathematics.tweakbeforecopyingfont")
sequencers.appendaction("aftercopyingcharacters", "system","mathematics.tweakaftercopyingfont")

function mathematics.overloaddimensions(target,original,set)
    local goodies = target.goodies
    if goodies then
        for i=1,#goodies do
            local goodie = goodies[i]
            local mathematics = goodie.mathematics
            local dimensions  = mathematics and mathematics.dimensions
            if dimensions then
                if trace_defining then
                    report_math("overloading dimensions in %a @ %p",target.properties.fullname,target.parameters.size)
                end
                local characters = target.characters
                local parameters = target.parameters
                local factor     = parameters.factor
                local hfactor    = parameters.hfactor
                local vfactor    = parameters.vfactor
                local addprivate = fonts.helpers.addprivate
                local function overload(dimensions)
                    for unicode, data in next, dimensions do
                        local character = characters[unicode]
                        if character then
                            --
                            local width  = data.width
                            local height = data.height
                            local depth  = data.depth
                            if trace_defining and (width or height or depth) then
                                report_math("overloading dimensions of %C, width %a, height %a, depth %a",unicode,width,height,depth)
                            end
                            if width   then character.width  = width  * hfactor end
                            if height  then character.height = height * vfactor end
                            if depth   then character.depth  = depth  * vfactor end
                            --
                            local xoffset = data.xoffset
                            local yoffset = data.yoffset
                            if xoffset then
                                xoffset = { "right", xoffset * hfactor }
                            end
                            if yoffset then
                                yoffset = { "down", -yoffset * vfactor }
                            end
                            if xoffset or yoffset then
                                local slot = { "slot", 1, addprivate(target,nil,fastcopy(character)) }
                                if xoffset and yoffset then
                                    character.commands = { xoffset, yoffset, slot }
                                elseif xoffset then
                                    character.commands = { xoffset, slot }
                                else
                                    character.commands = { yoffset, slot }
                                end
                                character.index = nil
                            end
                        elseif trace_defining then
                            report_math("no overloading dimensions of %C, not in font",unicode)
                        end
                    end
                end
                if set == nil then
                    set = { "default" }
                end
                if set == "all" or set == true then
                    for name, set in next, dimensions do
                        overload(set)
                    end
                else
                    if type(set) == "string" then
                        set = utilities.parsers.settings_to_array(set)
                    end
                    if type(set) == "table" then
                        for i=1,#set do
                            local d = dimensions[set[i]]
                            if d then
                                overload(d)
                            end
                        end
                    end
                end
            end
        end
    end
end

sequencers.appendaction("aftercopyingcharacters", "system","mathematics.overloaddimensions")

-- a couple of predefined tewaks:

local tweaks       = { }
mathematics.tweaks = tweaks

function tweaks.fixbadprime(target,original)
    target.characters[0xFE325] = target.characters[0x2032]
end

-- helpers

local setmetatableindex  = table.setmetatableindex
local family_font        = node.family_font

local fontcharacters     = fonts.hashes.characters
local extensibles        = utilities.storage.allocate()
fonts.hashes.extensibles = extensibles

local chardata           = characters.data
local extensibles        = mathematics.extensibles

-- we use numbers at the tex end (otherwise we could stick to chars)

local e_left       = extensibles.left
local e_right      = extensibles.right
local e_horizontal = extensibles.horizontal
local e_vertical   = extensibles.vertical
local e_mixed      = extensibles.mixed
local e_unknown    = extensibles.unknown

local unknown      = { e_unknown, false, false }

local function extensiblecode(font,unicode)
    local characters = fontcharacters[font]
    local character = characters[unicode]
    if not character then
        return unknown
    end
    local code = unicode
    local next = character.next
    while next do
        code = next
        character = characters[next]
        next = character.next
    end
    local char = chardata[unicode]
    local mathextensible = char and char.mathextensible
    if character.horiz_variants then
        if character.vert_variants then
            return { e_mixed, code, character }
        else
            local e = mathextensible and extensibles[mathextensible]
            return e and { e, code, character } or unknown
        end
    elseif character.vert_variants then
        local e =  mathextensible and extensibles[mathextensible]
        return e and { e, code, character } or unknown
    else
        return unknown
    end
end

setmetatableindex(extensibles,function(extensibles,font)
    local codes = { }
    setmetatableindex(codes, function(codes,unicode)
        local status = extensiblecode(font,unicode)
        codes[unicode] = status
        return status
    end)
    extensibles[font] = codes
    return codes
end)

function mathematics.extensiblecode(family,unicode)
    return extensibles[family_font(family or 0)][unicode][1]
end

function commands.extensiblecode(family,unicode)
    context(extensibles[family_font(family or 0)][unicode][1])
end

-- left       : [head] ...
-- right      : ... [head]
-- horizontal : [head] ... [head]
--
-- abs(right["start"] - right["end"]) | right.advance | characters[right.glyph].width

function commands.horizontalcode(family,unicode)
    local font = family_font(family or 0)
    local data = extensibles[font][unicode]
    local kind = data[1]
    if kind == e_left then
        local charlist = data[3].horiz_variants
        local characters = fontcharacters[font]
        local left = charlist[1]
        texdimen.scratchleftoffset  = abs((left["start"] or 0) - (left["end"] or 0))
        texdimen.scratchrightoffset = 0
    elseif kind == e_right then
        local charlist = data[3].horiz_variants
        local characters = fontcharacters[font]
        local right = charlist[#charlist]
        texdimen.scratchleftoffset  = 0
        texdimen.scratchrightoffset = abs((right["start"] or 0) - (right["end"] or 0))
     elseif kind == e_horizontal then
        local charlist = data[3].horiz_variants
        local characters = fontcharacters[font]
        local left = charlist[1]
        local right = charlist[#charlist]
        texdimen.scratchleftoffset  = abs((left["start"] or 0) - (left["end"] or 0))
        texdimen.scratchrightoffset = abs((right["start"] or 0) - (right["end"] or 0))
    else
        texdimen.scratchleftoffset  = 0
        texdimen.scratchrightoffset = 0
    end
    context(kind)
end
