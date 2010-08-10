if not modules then modules = { } end modules ['luat-bwc'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- backward compatibility

local box = tex.box

tex.wd = { } setmetatable(tex.wd, {
    __index    = function(t,k)   local bk = box[k] return bk and bk.width or 0 end,
    __newindex = function(t,k,v) local bk = box[k] if bk then bk.width = v end end,
}

tex.ht = { } setmetatable(tex.ht, {
    __index    = function(t,k)   local bk = box[k] return bk and bk.height or 0 end,
    __newindex = function(t,k,v) local bk = box[k] if bk then bk.height = v end end,
}

tex.dp = { } setmetatable(tex.dp, {
    __index    = function(t,k)   local bk = box[k] return bk and bk.depth or 0 end,
    __newindex = function(t,k,v) local bk = box[k] if bk then bk.depth = v end end,
}

