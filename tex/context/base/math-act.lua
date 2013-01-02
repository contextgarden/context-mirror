if not modules then modules = { } end modules ['math-act'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we tweak some font properties (if needed).

local trace_defining = false  trackers.register("math.defining", function(v) trace_defining = v end)
local report_math    = logs.reporter("mathematics","initializing")

local context        = context
local commands       = commands
local mathematics    = mathematics

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
     -- print("\n",target.properties.fontname)
     -- print(original.mathparameters.DisplayOperatorMinHeight)
     -- print(target.mathparameters.DisplayOperatorMinHeight)
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
             -- if name == "DisplayOperatorMinHeight" then
             --     report_math("f: %s, p: %s, h: %s, b: %s, a: %s",target.properties.fontname,name,h or "scaled",mathparameters[name],value)
             -- end
                mathparameters[name] = value
            end
        end
     -- print(mathparameters.DisplayOperatorMinHeight)
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

sequencers.appendaction("mathparameters","system","mathematics.checkaccentbaseheight")

function mathematics.checkprivateparameters(target,original)
    local mathparameters = target.mathparameters
    if mathparameters then
        if not mathparameters.FractionDelimiterSize then
            mathparameters.FractionDelimiterSize = 1.01 * target.parameters.size
        end
        if not mathparameters.FractionDelimiterDisplayStyleSize then
            mathparameters.FractionDelimiterDisplayStyleSize = 2.40 * target.parameters.size
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
                        report_math("overloading math parameters in '%s' @ %s",target.properties.fullname,target.parameters.size)
                    end
                    for name, value in next, parameters do
                        local tvalue = type(value)
                        if tvalue == "string" then
                            report_math("comment for math parameter '%s': %s",name,value)
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
                                    report_math("overloading math parameter '%s': %s => %s",name,tostring(oldvalue),tostring(newvalue))
                                end
                            else
                                report_math("invalid math parameter '%s'",name)
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
                        report_math("tweaking math of '%s' @ %s (%s)",target.properties.fullname,target.parameters.size,when)
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

local function extensiblecode(font,unicode)
    local characters = fontcharacters[font]
    local chardata = characters[unicode]
    if not chardata then
        return 0
    end
    local next = chardata.next
    while next do
        chardata = characters[next]
        next = chardata.next
    end
    if chardata.horiz_variants then
        if chardata.vert_variants then
            return 4
        else
            return 1
        end
    elseif chardata.vert_variants then
        return 2
    else
        return 0
    end
end

setmetatableindex(extensibles,function(extensibles,font)
    local codes = { }
    setmetatableindex(codes, function(codes,unicode)
        local code = extensiblecode(font,unicode)
        codes[unicode] = code
        return code
    end)
    extensibles[font] = codes
    return codes
end)

function mathematics.extensiblecode(family,unicode)
    return extensibles[family_font(family or 0)][unicode]
end

function commands.extensiblecode(family,unicode)
    context(extensibles[family_font(family or 0)][unicode])
end
