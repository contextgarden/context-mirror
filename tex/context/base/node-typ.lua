if not modules then modules = { } end modules ['node-typ'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will be replaced by blob-ini cum suis so typesetters will go away

local utfvalues = string.utfvalues

local hpack     = node.hpack
local vpack     = node.vpack

local nodepool  = nodes.pool

local new_glyph = nodepool.glyph
local new_glue  = nodepool.glue

typesetters = typesetters or { }

local function tonodes(str,fontid,spacing) -- don't use this
    local head, prev = nil, nil
    for s in utfvalues(str) do
        local next
        if spacing and s == 32 then
            next = newglue(spacing or 64*1024*10)
        else
            next = newglyph(fontid or 1,s)
        end
        if not head then
            head = next
        else
            prev.next = next
            next.prev = prev
        end
        prev = next
    end
    return head
end

typesetters.tonodes = tonodes

function typesetters.hpack(str,fontid,spacing)
    return hpack(tonodes(str,fontid,spacing))
end

function typesetters.vpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implentation is on the agenda
    -- as it needs more info etc than currently available
    return vpack(tonodes(str,fontid,spacing))
end

--~ node.write(typesetters.hpack("Hello World!"))
--~ node.write(typesetters.hpack("Hello World!",1,100*1024*10))
