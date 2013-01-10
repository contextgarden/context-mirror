if not modules then modules = { } end modules ['attr-mkr'] = {
    version   = 1.001,
    comment   = "companion to attr-mkr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local has_attribute = node.has_attribute

local markers = nodes.markers or { }
nodes.markers = markers

local cache   = { }
local numbers = attributes.numbers
local unknown = attributes.private("marker:unknown")

table.setmetatableindex(cache,function(t,k)
    local k = "marker:" .. k
    local v = numbers[k] or unknown
    t[k] = v
    return v
end)

function markers.get(n,name)
    local a = cache[name]
    return a and has_attribute(n,a) or nil
end
