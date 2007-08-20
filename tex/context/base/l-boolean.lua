-- filename : l-boolean.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-boolean'] = 1.001
if not boolean  then boolean  = { } end

function boolean.tonumber(b)
    if b then return 1 else return 0 end
end

function toboolean(str)
    if type(str) == "string" then
        return str == "true" or str == "yes" or str == "on" or str == "1"
    elseif type(str) == "number" then
        return tonumber(str) ~= 0
    elseif type(str) == "nil" then
        return false
    else
        return str
    end
end

function string.is_boolean(str)
    if type(str) == "string" then
        if str == "true" or str == "yes" or str == "on" then
            return true
        elseif str == "false" or str == "no" or str == "off" then
            return false
        end
    end
    return nil
end

function boolean.alwaystrue()
    return true
end

function boolean.falsetrue()
    return false
end
