if not modules then modules = { } end modules ['node-ini'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Most of the code that had accumulated here is now separated in
modules.</p>
--ldx]]--

-- this module is being reconstructed

local utf = unicode.utf8
local next, type = next, type
local format, concat, match, utfchar = string.format, table.concat, string.match, utf.char

--[[ldx--
<p>Access to nodes is what gives <l n='luatex'/> its power. Here we
implement a few helper functions. These functions are rather optimized.</p>
--ldx]]--

--[[ldx--
<p>When manipulating node lists in <l n='context'/>, we will remove
nodes and insert new ones. While node access was implemented, we did
quite some experiments in order to find out if manipulating nodes
in <l n='lua'/> was feasible from the perspective of performance.</p>

<p>First of all, we noticed that the bottleneck is more with excessive
callbacks (some gets called very often) and the conversion from and to
<l n='tex'/>'s datastructures. However, at the <l n='lua'/> end, we
found that inserting and deleting nodes in a table could become a
bottleneck.</p>

<p>This resulted in two special situations in passing nodes back to
<l n='tex'/>: a table entry with value <type>false</type> is ignored,
and when instead of a table <type>true</type> is returned, the
original table is used.</p>

<p>Insertion is handled (at least in <l n='context'/> as follows. When
we need to insert a node at a certain position, we change the node at
that position by a dummy node, tagged <type>inline</type> which itself
has_attribute the original node and one or more new nodes. Before we pass
back the list we collapse the list. Of course collapsing could be built
into the <l n='tex'/> engine, but this is a not so natural extension.</p>

<p>When we collapse (something that we only do when really needed), we
also ignore the empty nodes. [This is obsolete!]</p>
--ldx]]--

nodes = nodes or { }

local hlist   = node.id('hlist')
local vlist   = node.id('vlist')
local glyph   = node.id('glyph')
local glue    = node.id('glue')
local penalty = node.id('penalty')
local kern    = node.id('kern')
local whatsit = node.id('whatsit')

local traverse_id        = node.traverse_id
local traverse           = node.traverse
local free_node          = node.free
local remove_node        = node.remove
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

function nodes.remove(head, current, free_too)
   local t = current
   head, current = remove_node(head,current)
   if t then
        if free_too then
            free_node(t)
            t = nil
        else
            t.next, t.prev = nil, nil
        end
   end
   return head, current, t
end

function nodes.delete(head,current)
    return nodes.remove(head,current,true)
end

nodes.before = insert_node_before
nodes.after  = insert_node_after

-- we need to test this, as it might be fixed now

function nodes.before(h,c,n)
    if c then
        if c == h then
            n.next = h
            n.prev = nil
            h.prev = n
        else
            local cp = c.prev
            n.next = c
            n.prev = cp
            if cp then
                cp.next = n
            end
            c.prev = n
            return h, n
        end
    end
    return n, n
end

function nodes.after(h,c,n)
    if c then
        local cn = c.next
        if cn then
            n.next = cn
            cn.prev = n
        else
            n.next = nil
        end
        c.next = n
        n.prev = c
        return h, n
    end
    return n, n
end

-- local h, c = nodes.replace(head,current,new)
-- local c = nodes.replace(false,current,new)
-- local c = nodes.replace(current,new)

function nodes.replace(head,current,new) -- no head returned if false
    if not new then
        head, current, new = false, head, current
    end
    local prev, next = current.prev, current.next
    if next then
        new.next, next.prev = next, new
    end
    if prev then
        new.prev, prev.next = prev, new
    end
    if head then
        if head == current then
            head = new
        end
        free_node(current)
        return head, new
    else
        free_node(current)
        return new
    end
end

-- will move

local function count(stack,flat)
    local n = 0
    while stack do
        local id = stack.id
        if not flat and id == hlist or id == vlist then
            local list = stack.list
            if list then
                n = n + 1 + count(list) -- self counts too
            else
                n = n + 1
            end
        else
            n = n + 1
        end
        stack  = stack.next
    end
    return n
end

nodes.count = count

local left, space = lpeg.P("<"), lpeg.P(" ")

nodes.filterkey = left * (1-left)^0 * left * space^0 * lpeg.C((1-space)^0)
