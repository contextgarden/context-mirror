if not modules then modules = { } end modules ['core-env'] = {
    version   = 1.001,
    comment   = "companion to core-env.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe this will move to the context name space although the
-- plurals are unlikely to clash with future tex primitives
--
-- if tex.modes['xxxx'] then .... else .... end

local P, C, S, Cc, lpegmatch, patterns = lpeg.P, lpeg.C, lpeg.S, lpeg.Cc, lpeg.match, lpeg.patterns

local csname_id         = token.csname_id
local texcount          = tex.count
local create            = token.create

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local undefined         = csname_id("*undefined*crap*")
local iftrue            = create("iftrue")[2] -- inefficient hack

tex.modes               = allocate { }
tex.systemmodes         = allocate { }
tex.constants           = allocate { }
tex.conditionals        = allocate { }
tex.ifs                 = allocate { }

local modes             = { }
local systemmodes       = { }

setmetatableindex(tex.modes, function(t,k)
    local m = modes[k]
    if m then
        return m()
    else
        local n = "mode" .. k
        if csname_id(n) == undefined then
            return false
        else
            modes[k] = function() return texcount[n] >= 1 end
            return texcount[n] >= 1
        end
    end
end)

setmetatableindex(tex.systemmodes, function(t,k)
    local m = systemmodes[k]
    if m then
        return m()
    else
        local n = "mode*" .. k
        if csname_id(n) == undefined then
            return false
        else
            systemmodes[k] = function() return texcount[n] >= 1 end
            return texcount[n] >= 1
        end
    end
end)

setmetatableindex(tex.constants, function(t,k)
    return csname_id(k) ~= undefined and texcount[k] or 0
end)

setmetatableindex(tex.conditionals, function(t,k) -- 0 == true
    return csname_id(k) ~= undefined and texcount[k] == 0
end)

setmetatableindex(tex.ifs, function(t,k)
    return csname_id(k) ~= undefined and create(k)[2] == iftrue -- inefficient, this create, we need a helper
end)

function tex.settrue(name)
    texcount[name] = 0
end

function tex.setfalse(name)
    texcount[name] = 1
end

----  arg = P("{") * C(patterns.nested) * P("}") + Cc("")

local sep = S("), ")
local str = C((1-sep)^1)
local tag = P("(") * C((1-S(")" ))^1) * P(")")
local arg = P("(") * C((1-S("){"))^1) * P("{") * C((1-P("}"))^0) * P("}") * P(")")

local pattern = (
     P("lua") * tag        / context.luasetup
  +  P("xml") * arg        / context.setupwithargument -- or xmlw as xmlsetup has swapped arguments
  + (P("tex") * tag + str) / context.texsetup
  +             sep^1
)^1

function commands.autosetups(str)
    lpegmatch(pattern,str)
end
