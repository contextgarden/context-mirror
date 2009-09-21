if not modules then modules = { } end modules ['node-typ'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfvalues = string.utfvalues

local newglyph = nodes.glyph
local newglue  = nodes.glue

local hpack, vpack = node.hpack, node.vpack

typesetting = typesetting or { }

local function tonodes(str,fontid,spacing)
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

typesetting.tonodes = tonodes

function typesetting.hpack(str,fontid,spacing)
    return hpack(tonodes(str,fontid,spacing))
end

function typesetting.vpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implentation is on the agenda
    -- as it needs more info etc than currently available
    return vpack(tonodes(str,fontid,spacing))
end

--~ node.write(typesetting.hpack("Hello World!"))
--~ node.write(typesetting.hpack("Hello World!",1,100*1024*10))
