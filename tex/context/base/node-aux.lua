if not modules then modules = { } end modules ['node-aux'] = {
    version   = 1.001,
    comment   = "companion to node-spl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, format = string.gsub, string.format

local free_node   = node.free
local hpack_nodes = node.hpack
local node_fields = node.fields

function nodes.repack_hlist(list,...)
    local temp, b = hpack_nodes(list,...)
    list = temp.list
    temp.list = nil
    free_node(temp)
    return list, b
end

function nodes.merge(a,b)
    if a and b then
        local t = node.fields(a.id)
        for i=3,#t do
            local name = t[i]
            a[name] = b[name]
        end
    end
    return a, b
end

local fields, whatsits = { }, { }

for k, v in pairs(node.types()) do
    if v == "whatsit" then
        fields[k], fields[v] = { }, { }
        for kk, vv in pairs(node.whatsits()) do
            local f = node_fields(k,kk)
            whatsits[kk], whatsits[vv] = f, f
        end
    else
        local f = node_fields(k)
        fields[k], fields[v] = f, f
    end
end

nodes.fields, nodes.whatsits = fields, whatsits

function nodes.info(n)
    logs.report(format("%14s","type"),node.type(n.id))
    for k,v in pairs(fields[n.id]) do
        logs.report(format("%14s",v),gsub(gsub(tostring(n[v]),"%s+"," "),"node ",""))
    end
end
