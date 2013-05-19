if not modules then modules = { } end modules ['layo-ini'] = {
    version   = 1.001,
    comment   = "companion to layo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We need to share information between the TeX and Lua end
-- about the typographical model. This happens here.
--
-- Code might move.

-- conditionals.layoutisdoublesided
-- conditionals.layoutissinglesided
-- texcount.pagenoshift
-- texcount.realpageno

local texcount     = tex.count
local conditionals = tex.conditionals

layouts = {
    status = { },
}

local status = layouts.status

function status.leftorrightpagection(left,right)
    if left == nil then
        left, right = false, true
    end
    if not conditionals.layoutisdoublesided then
        return left, right
    elseif conditionals.layoutissinglesided then
        return left, right
    elseif texcount.pagenoshift % 2 == 0 then
        if texcount.realpageno % 2 == 0 then
            return right, left
        else
            return left, right
        end
    else
        if texcount.realpageno % 2 == 0 then
            return left, right
        else
            return right, left
        end
    end
end

function status.isleftpage()
    if not conditionals.layoutisdoublesided then
        return false
    elseif conditionals.layoutissinglesided then
        return false
    elseif texcount.pagenoshift % 2 == 0 then
        return texcount.realpageno % 2 == 0
    else
        return not texcount.realpageno % 2 == 0
    end
end
