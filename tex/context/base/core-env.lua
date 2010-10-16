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

local csname_id, texcount = token.csname_id, tex.count

local undefined = csname_id("*undefined*crap*")

tex.modes     = { } local modes     = { }
tex.constants = { } local constants = { }

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

setmetatable(tex.constants, { __index = function(t,k)
    local m = constants[k]
    if m then
        return m()
    elseif csname_id(k) == undefined then
        return false
    else
        constants[k] = function() return texcount[k] >= 1 end
        return texcount[k] >= 1
    end
end })
