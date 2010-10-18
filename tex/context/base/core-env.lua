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

local csname_id, texcount, create = token.csname_id, tex.count, token.create

local undefined = csname_id("*undefined*crap*")
local iftrue    = create("iftrue")[2] -- inefficient hack

tex.modes        = { } local modes        = { }
tex.systemmodes  = { } local systemmodes  = { }
tex.constants    = { }
tex.conditionals = { }
tex.ifs          = { }

setmetatable(tex.modes, { __index = function(t,k)
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
end })

setmetatable(tex.systemmodes, { __index = function(t,k)
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
end })

setmetatable(tex.constants, { __index = function(t,k)
    return csname_id(k) ~= undefined and texcount[k] or 0
end })

setmetatable(tex.conditionals, { __index = function(t,k) -- 0 == true
    return csname_id(k) ~= undefined and texcount[k] == 0
end })

setmetatable(tex.ifs, { __index = function(t,k)
    return csname_id(k) ~= undefined and create(k)[2] == iftrue -- inefficient, this create, we need a helper
end })
