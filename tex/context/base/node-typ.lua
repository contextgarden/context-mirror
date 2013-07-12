if not modules then modules = { } end modules ['node-typ'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- code has been moved to blob-ini.lua

local typesetters = nodes.typesetters or { }
nodes.typesetters = typesetters

local hpack_node_list = nodes.hpack
local vpack_node_list = nodes.vpack
local fast_hpack_list = nodes.fasthpack

local nodepool        = nodes.pool
local new_glyph       = nodepool.glyph
local new_glue        = nodepool.glue

local utfvalues       = utf.values

local currentfont    = font.current
local fontparameters = fonts.hashes.parameters

local function tonodes(str,fontid,spacing) -- quick and dirty
    local head, prev = nil, nil
    if not fontid then
        fontid = currentfont()
    end
    local fp = fontparameters[fontid]
    local s, p, m
    if spacing then
        s, p, m = spacing, 0, 0
    else
        s, p, m = fp.space, fp.space_stretch, fp,space_shrink
    end
    local spacedone = false
    for c in utfvalues(str) do
        local next
        if c == 32 then
            if not spacedone then
                next = new_glue(s,p,m)
                spacedone = true
            end
        else
            next = new_glyph(fontid or 1,c)
            spacedone = false
        end
        if not next then
            -- nothing
        elseif not head then
            head = next
        else
            prev.next = next
            next.prev = prev
        end
        prev = next
    end
    return head
end

local function tohpack(str,fontid,spacing)
    return hpack_node_list(tonodes(str,fontid,spacing),"exactly")
end

local function tohpackfast(str,fontid,spacing)
    return fast_hpack_list(tonodes(str,fontid,spacing),"exactly")
end

local function tovpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implentation is on the agenda
    -- as it needs more info etc than currently available
    return vpack_node_list(tonodes(str,fontid,spacing))
end

local tovpackfast = tovpack

typesetters.tonodes     = tonodes
typesetters.tohpack     = tohpack
typesetters.tohpackfast = tohpackfast
typesetters.tovpack     = tovpack
typesetters.tovpackfast = tovpackfast

typesetters.hpack       = tohpack
typesetters.fast_hpack  = tohpackfast
typesetters.vpack       = tovpack

-- node.write(nodes.typestters.hpack("Hello World!"))
-- node.write(nodes.typestters.hpack("Hello World!",1,100*1024*10))

string.tonodes = tonodes -- quite convenient
