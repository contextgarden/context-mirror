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
local format, concat, match, gsub = string.format, table.concat, string.match, string.gsub
local utfchar = utf.char
local swapped = table.swapped
local lpegmatch = lpeg.match
local formatcolumns = utilities.formatters.formatcolumns

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

local traverse, traverse_id = node.traverse, node.traverse_id
local free_node, remove_node = node.free, node.remove
local insert_node_before, insert_node_after = node.insert_before, node.insert_after
local slide_nodes = node.slide

local allocate = utilities.storage.allocate

nodes          = nodes or { }
local nodes    = nodes

nodes.handlers = nodes.handlers or { }

-- there will be more of this:

local skipcodes = allocate {
   [ 0] = "userskip",
   [ 1] = "lineskip",
   [ 2] = "baselineskip",
   [ 3] = "parskip",
   [ 4] = "abovedisplayskip",
   [ 5] = "belowdisplayskip",
   [ 6] = "abovedisplayshortskip",
   [ 7] = "belowdisplayshortskip",
   [ 8] = "leftskip",
   [ 9] = "rightskip",
   [10] = "topskip",
   [11] = "splittopskip",
   [12] = "tabskip",
   [13] = "spaceskip",
   [14] = "xspaceskip",
   [15] = "parfillskip",
   [16] = "thinmuskip",
   [17] = "medmuskip",
   [18] = "thickmuskip",
}

local noadcodes = allocate {
    [ 0] = "ord",
    [ 1] = "opdisplaylimits",
    [ 2] = "oplimits",
    [ 3] = "opnolimits",
    [ 4] = "bin",
    [ 5] = "rel",
    [ 6] = "open",
    [ 7] = "close",
    [ 8] = "punct",
    [ 9] = "inner",
    [10] = "under",
    [11] = "over",
    [12] = "vcenter",
}

local listcodes = allocate {
    [ 0] = "unknown",
    [ 1] = "line",
    [ 2] = "box",
    [ 3] = "indent",
    [ 4] = "alignment", -- row or column
    [ 5] = "cell",
}

local glyphcodes = allocate {
    [0] = "character",
    [1] = "glyph",
    [2] = "ligature",
    [3] = "ghost",
    [4] = "left",
    [5] = "right",
}

local kerncodes = allocate {
    [0] = "fontkern",
    [1] = "userkern",
    [2] = "accentkern",
}

local mathcodes = allocate {
    [0] = "beginmath",
    [1] = "endmath",
}

local fillcodes = allocate {
    [0] = "stretch",
    [1] = "fi",
    [2] = "fil",
    [3] = "fill",
    [4] = "filll",
}

local function simplified(t)
    local r = { }
    for k, v in next, t do
        r[k] = gsub(v,"_","")
    end
    return r
end

local nodecodes = simplified(node.types())
local whatcodes = simplified(node.whatsits())

skipcodes  = allocate(swapped(skipcodes, skipcodes ))
noadcodes  = allocate(swapped(noadcodes, noadcodes ))
nodecodes  = allocate(swapped(nodecodes, nodecodes ))
whatcodes  = allocate(swapped(whatcodes, whatcodes ))
listcodes  = allocate(swapped(listcodes, listcodes ))
glyphcodes = allocate(swapped(glyphcodes,glyphcodes))
kerncodes  = allocate(swapped(kerncodes, kerncodes ))
mathcodes  = allocate(swapped(mathcodes, mathcodes ))
fillcodes  = allocate(swapped(fillcodes, fillcodes ))

nodes.skipcodes  = skipcodes  nodes.gluecodes    = skipcodes -- more official
nodes.noadcodes  = noadcodes
nodes.nodecodes  = nodecodes
nodes.whatcodes  = whatcodes  nodes.whatsitcodes = whatcodes -- more official
nodes.listcodes  = listcodes
nodes.glyphcodes = glyphcodes
nodes.kerncodes  = kerncodes
nodes.mathcodes  = mathcodes
nodes.fillcodes  = fillcodes

listcodes.row              = listcodes.alignment
listcodes.column           = listcodes.alignment

kerncodes.italiccorrection = kerncodes.userkern
kerncodes.kerning          = kerncodes.fontkern

nodes.codes = allocate {
    hlist   = listcodes,
    vlist   = listcodes,
    glyph   = glyphcodes,
    glue    = skipcodes,
    kern    = kerncodes,
    whatsit = whatcodes,
    math    = mathnodes,
    noad    = noadcodes,
}

function nodes.showcodes()
    local t = { }
    for name, codes in table.sortedhash(nodes.codes) do
        local sorted = table.sortedkeys(codes)
        for i=1,#sorted do
            local s = sorted[i]
            if type(s) ~= "number" then
                t[#t+1] = { name, s, codes[s] }
            end
        end
    end
    formatcolumns(t)
    for k=1,#t do
        texio.write_nl(t[k])
    end
end

trackers.register("system.showcodes", nodes.showcodes)

local hlist_code = nodecodes.hlist
local vlist_code = nodecodes.vlist
local glue_code  = nodecodes.glue

--~ if t.id == glue_code then
--~     local s = t.spec
--~ print(t)
--~ print(s,s and s.writable)
--~     if s and s.writable then
--~         free_node(s)
--~     end
--~     t.spec = nil
--~ end

local function remove(head, current, free_too)
   local t = current
--~ print(t)
   head, current = remove_node(head,current)
   if t then
        if free_too then
            free_node(t)
            t = nil
        else
            t.next = nil
            t.prev = nil
        end
   end
   return head, current, t
end

nodes.remove = remove

function nodes.delete(head,current)
    return remove(head,current,true)
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
        new.next = next
        next.prev = new
    end
    if prev then
        new.prev = prev
        prev.next = new
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
        if not flat and id == hlist_code or id == vlist_code then
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

local reference = left * (1-left)^0 * left * space^0 * lpeg.C((1-space)^0)

function nodes.reference(n)
    return lpegmatch(reference,tostring(n))
end

function nodes.link(n,...) -- blobs ?
    if n then
        if type(n) ~= "table" then
            n = { n, ... }
        end
        local head = n[1]
        local tail = slide_nodes(head)
        for i=2,#n do
            local ni = n[i]
            tail.next = ni
            ni.prev = tail
            tail = slide_nodes(ni)
        end
        return head
    else
        -- sort of fatal error
    end
end

--

if not node.next then

    function node.next(n) return n and n.next end
    function node.prev(n) return n and n.prev end

end
