if not modules then modules = { } end modules ['node-aux'] = {
    version   = 1.001,
    comment   = "companion to node-spl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, format = string.gsub, string.format

local free_node, hpack_nodes, node_fields, traverse_nodes = node.free, node.hpack, node.fields, node.traverse
local has_attribute, set_attribute, unset_attribute, has_attribute = node.has_attribute, node.set_attribute, node.unset_attribute,node.has_attribute

local nodecodes = nodes.nodecodes

local hlist = nodecodes.hlist
local vlist = nodecodes.vlist

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

local fields, whatsitfields = { }, { }

for k, v in next, node.types() do
    if v == "whatsit" then
        fields[k], fields[v] = { }, { }
        for kk, vv in next, node.whatsits() do
            local f = node_fields(k,kk)
            whatsitfields[kk], whatsitfields[vv] = f, f
        end
    else
        local f = node_fields(k)
        fields[k], fields[v] = f, f
    end
end

nodes.fields, nodes.whatsitfields = fields, whatsitfields

function nodes.info(n)
    local id = n.id
    local tp = node.type(id)
    local list = (tp == "whatsit" and whatsitfields[n.subtype]) or fields[id]
    logs.report(format("%14s","type"),tp)
    for k,v in next, list do
        logs.report(format("%14s",v),gsub(gsub(tostring(n[v]),"%s+"," "),"node ",""))
    end
end

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
--         logs.error("parbuilder",'arith_error')
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


local function set_attributes(head,attr,value)
    for n in traverse_nodes(head) do
        set_attribute(n,attr,value)
        local id = n.id
        if id == hlist or id == vlist then
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
        if id == hlist or id == vlist then
            set_unset_attributes(n.list,attr,value)
        end
    end
end

local function unset_attributes(head,attr)
    for n in traverse_nodes(head) do
        unset_attribute(n,attr)
        local id = n.id
        if id == hlist or id == vlist then
            unset_attributes(n.list,attr)
        end
    end
end

nodes.set_attribute        = set_attribute
nodes.unset_attribute      = unset_attribute
nodes.has_attribute        = has_attribute
nodes.set_attributes       = set_attributes
nodes.set_unset_attributes = set_unset_attributes
nodes.unset_attributes     = unset_attributes
