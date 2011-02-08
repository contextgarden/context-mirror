if not modules then modules = { } end modules ['node-aux'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local nodecodes       = nodes.nodecodes

local glyph_code      = nodecodes.glyph
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist

local traverse_nodes  = node.traverse
local traverse_id     = node.traverse_id
local free_node       = node.free
local hpack_nodes     = node.hpack
local has_attribute   = node.has_attribute
local set_attribute   = node.set_attribute
local get_attribute   = node.get_attribute
local unset_attribute = node.unset_attribute
local first_glyph     = node.first_glyph or node.first_character

local texbox          = tex.box

function nodes.repack_hlist(list,...)
    local temp, b = hpack_nodes(list,...)
    list = temp.list
    temp.list = nil
    free_node(temp)
    return list, b
end

local function set_attributes(head,attr,value)
    for n in traverse_nodes(head) do
        set_attribute(n,attr,value)
        local id = n.id
        if id == hlist_node or id == vlist_node then
            set_attributes(n.list,attr,value)
        end
    end
end

local function set_unset_attributes(head,attr,value)
    for n in traverse_nodes(head) do
        if not has_attribute(n,attr) then
            set_attribute(n,attr,value)
        end
        local id = n.id
        if id == hlist_code or id == vlist_code then
            set_unset_attributes(n.list,attr,value)
        end
    end
end

local function unset_attributes(head,attr)
    for n in traverse_nodes(head) do
        unset_attribute(n,attr)
        local id = n.id
        if id == hlist_code or id == vlist_code then
            unset_attributes(n.list,attr)
        end
    end
end

nodes.set_attribute        = set_attribute
nodes.unset_attribute      = unset_attribute
nodes.has_attribute        = has_attribute
nodes.first_glyph          = first_glyph

nodes.set_attributes       = set_attributes
nodes.set_unset_attributes = set_unset_attributes
nodes.unset_attributes     = unset_attributes

nodes.setattribute         = set_attribute
nodes.unsetattribute       = unset_attribute
nodes.hasattribute         = has_attribute

nodes.setattributes        = set_attributes
nodes.setunsetattributes   = set_unset_attributes
nodes.unsetattributes      = unset_attributes

-- history:
--
-- local function cp_skipable(a,id)  -- skipable nodes at the margins during character protrusion
--     return (
--             id ~= glyph_node
--         or  id == ins_node
--         or  id == mark_node
--         or  id == adjust_node
--         or  id == penalty_node
--         or (id == glue_node    and a.spec.writable)
--         or (id == disc_node    and a.pre == nil and a.post == nil and a.replace == nil)
--         or (id == math_node    and a.surround == 0)
--         or (id == kern_node    and (a.kern == 0 or a.subtype == NORMAL))
--         or (id == hlist_node   and a.width == 0 and a.height == 0 and a.depth == 0 and a.list == nil)
--         or (id == whatsit_node and a.subtype ~= pdf_refximage_node and a.subtype ~= pdf_refxform_node)
--     )
-- end
--
-- local function glyph_width(a)
--     local ch = chardata[a.font][a.char]
--     return (ch and ch.width) or 0
-- end
--
-- local function glyph_total(a)
--     local ch = chardata[a.font][a.char]
--     return (ch and (ch.height+ch.depth)) or 0
-- end
--
-- local function non_discardable(a) -- inline
--     return a.id < math_node -- brrrr
-- end
--
-- local function calculate_badness(t,s)
--     if t == 0 then
--         return 0
--     elseif s <= 0 then
--         return INF_BAD
--     else
--         local r
--         if t <= 7230584 then
--             r = t * 297 / s
--         elseif s >= 1663497 then
--             r = t / floor(s / 297)
--         else
--             r = t
--         end
--         r = floor(r)
--         if r > 1290 then
--             return INF_BAD
--         else
--             return floor((r * r * r + 0x20000) / 0x40000) -- 0400000 / 01000000
--         end
--     end
-- end
--
-- left-overs
--
-- local function round_xn_over_d(x, n, d)
--     local positive -- was x >= 0
--     if x >= 0 then
--         positive = true
--     else
--         x = -x
--         positive = false
--     end
--     local t = floor(x % 0x8000) * n              -- 0100000
--     local f = floor(t / 0x8000)                  -- 0100000
--     local u = floor(x / 0x8000) * n + f          -- 0100000
--     local v = floor(u % d) * 0x8000 + f          -- 0100000
--     if floor(u / d) >= 0x8000 then               -- 0100000
--         report_parbuilders('arith_error')
--     else
--         u = 0x8000 * floor(u / d) + floor(v / d) -- 0100000
--     end
--     v = floor(v % d)
--     if 2*v >= d then
--         u = u + 1
--     end
--     if positive then
--         return u
--     else
--         return -u
--     end
-- end

function nodes.firstcharacter(n,untagged) -- tagged == subtype > 255
    if untagged then
        return first_glyph(n)
    else
        for g in traverse_id(glyph_code,n) do
            return g
        end
    end
end

function nodes.firstcharinbox(n)
    local l = texbox[n].list
    if l then
        for g in traverse_id(glyph_code,l) do
            return g.char
        end
    end
    return 0
end
