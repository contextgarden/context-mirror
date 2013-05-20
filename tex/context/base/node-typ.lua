if not modules then modules = { } end modules ['node-typ'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfvalues      = utf.values

local currentfont    = font.current
local fontparameters = fonts.hashes.parameters

local hpack          = node.hpack
local vpack          = node.vpack
local fast_hpack     = nodes.fasthpack

local nodepool       = nodes.pool

local newglyph       = nodepool.glyph
local newglue        = nodepool.glue

typesetters = typesetters or { }

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
                next = newglue(s,p,m)
                spacedone = true
            end
        else
            next = newglyph(fontid or 1,c)
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

typesetters.tonodes = tonodes

function typesetters.hpack(str,fontid,spacing)
    return hpack(tonodes(str,fontid,spacing),"exactly")
end

function typesetters.fast_hpack(str,fontid,spacing)
    return fast_hpack(tonodes(str,fontid,spacing),"exactly")
end

function typesetters.vpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implentation is on the agenda
    -- as it needs more info etc than currently available
    return vpack(tonodes(str,fontid,spacing))
end

--~ node.write(typesetters.hpack("Hello World!"))
--~ node.write(typesetters.hpack("Hello World!",1,100*1024*10))
