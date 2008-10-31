if not modules then modules = { } end modules ['node-ini'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Access to nodes is what gives <l n='luatex'/> its power. Here we
implement a few helper functions. These functions are rather optimized.</p>
--ldx]]--

local format = string.format

nodes        = nodes or { }
nodes.trace  = false
nodes.ignore = nodes.ignore or false

local hlist   = node.id('vlist')
local vlist   = node.id('hlist')
local glyph   = node.id('glyph')
local disc    = node.id('disc')
local mark    = node.id('mark')
local glue    = node.id('glue')
local whatsit = node.id('whatsit')

-- handy helpers

if node.protect_glyphs then

    nodes.protect_glyphs   = node.protect_glyphs
    nodes.unprotect_glyphs = node.unprotect_glyphs

else do

    -- initial value subtype     : X000 0001 =  1 = 0x01 = char
    --
    -- expected before linebreak : X000 0000 =  0 = 0x00 = glyph
    --                             X000 0010 =  2 = 0x02 = ligature
    --                             X000 0100 =  4 = 0x04 = ghost
    --                             X000 1010 = 10 = 0x0A = leftboundary lig
    --                             X001 0010 = 18 = 0x12 = rightboundary lig
    --                             X001 1010 = 26 = 0x1A = both boundaries lig
    --                             X000 1100 = 12 = 0x1C = leftghost
    --                             X001 0100 = 20 = 0x14 = rightghost


    local traverse_id = node.traverse_id

    function nodes.protect_glyphs(head)
        local done = false
        for g in traverse_id(glyph,head) do
            local s = g.subtype
            if s == 1 then
                done, g.subtype = true, 256
            elseif s <= 256 then
                done, g.subtype = true, 256 + s
            end
        end
        return done
    end

    function nodes.unprotect_glyphs(head)
        local done = false
        for g in traverse_id(glyph,head) do
            local s = g.subtype
            if s > 256 then
                done, g.subtype = true, s - 256
            end
        end
        return done
    end

end end

do

    local remove, free = node.remove, node.free

    function nodes.remove(head, current, free_too)
       local t = current
       head, current = remove(head,current)
       if t then
            if free_too then
                free(t)
                t = nil
            else
                t.next, t.prev = nil, nil
            end
       end
       return head, current, t
    end

--~ function nodes.remove(head, current, delete)
--~     local t = current
--~     if current == head then
--~         current = current.next
--~         if current then
--~             current.prev = nil
--~         end
--~         head = current
--~     else
--~         local prev, next = current.prev, current.next
--~         if prev then
--~             prev.next = next
--~         end
--~         if next then
--~             next.prev = prev
--~         end
--~         current = next -- not: or next
--~     end
--~     if t then
--~         if free_too then
--~             free(t)
--~             t = nil
--~         else
--~             t.next, t.prev = nil, nil
--~         end
--~     end
--~     return head, current, t
--~ end


    function nodes.delete(head,current)
        return nodes.remove(head,current,true)
    end

    nodes.before =  node.insert_before -- broken
    nodes.after  =  node.insert_after

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
--~             if c ~= h then
                return h, n
--~             end
        end
        return n, n
    end

    function nodes.show_list(head, message)
        if message then
            texio.write_nl(message)
        end
        for n in node.traverse(head) do
            texio.write_nl(tostring(n))
        end
    end

end

-- will move

nodes.processors = { }
nodes.processors.char = { }
nodes.processors.char.proc = { }

function nodes.report(t,done)
    if nodes.trace then -- best also test this before calling
        if done then
            if status.output_active then
                texio.write(format("<++ %s>",nodes.count(t)))
            else
                texio.write(format("<+ %s>",nodes.count(t)))
            end
        else
            if status.output_active then
                texio.write(format("<-- %s>",nodes.count(t)))
            else
                texio.write(format("<- %s>",nodes.count(t)))
            end
        end
    end
end

do

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

end

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


--[[ldx--
<p>Serializing nodes can be handy for tracing. Also, saving and
loading node lists can come in handy as soon we are going to
use external applications to process node lists.</p>
--ldx]]--

function nodes.show(stack)
--~     texio.write_nl(table.serialize(stack))
end

function nodes.save(stack,name) -- *.ltn : luatex node file
--~     if name then
--~         file.savedata(name,table.serialize(stack))
--~     else
--~         texio.write_nl('log',table.serialize(stack))
--~     end
end

function nodes.load(name)
--~     return file.loaddata(name)
end

-- node-cap.lua

--~ nodes.capture = { } -- somehow fails

--~ function nodes.capture.start(cbk)
--~     local head, tail = nil, nil
--~     callbacks.push(cbk, function(t)
--~         if tail then
--~             tail.next = t
--~         else
--~             head, tail = t, t
--~         end
--~         while tail.next do
--~             tail = tail.next
--~         end
--~         return false
--~     end)
--~     function nodes.capture.stop()
--~         function nodes.capture.stop() end
--~         function nodes.capture.get()
--~             function nodes.capture.get() end
--~             return head
--~         end
--~         callbacks.pop(cbk)
--~     end
--~     function nodes.capture.get() end -- error
--~ end

--~ nodes.capture.stop = function() end
--~ nodes.capture.get  = function() end

-- node-gly.lua

fonts        = fonts        or { }
fonts.otf    = fonts.otf    or { }
fonts.tfm    = fonts.tfm    or { }
fonts.tfm.id = fonts.tfm.id or { }

local tfm   = fonts.tfm
local otf   = fonts.otf
local tfmid = fonts.tfm.id

do

    local has_attribute = node.has_attribute
    local traverse_id = node.traverse_id

    local pairs = pairs

    local starttiming, stoptiming = input.starttiming, input.stoptiming

    function nodes.process_characters(head)
     -- not ok yet; we need a generic blocker
     -- if status.output_active then
        if false then -- status.output_active then
            return head, false -- true
        else
            -- either next or not, but definitely no already processed list
            starttiming(nodes)
            local usedfonts, attrfonts, done = { }, { }, false
            -- todo: should be independent of otf
            local set_dynamics = otf.set_dynamics -- todo: font-var.lua so that we can global this one
            local a, u, prevfont, prevattr = 0, 0, nil, 0
            for n in traverse_id(glyph,head) do
                local font, attr = n.font, has_attribute(n,0) -- zero attribute is reserved for fonts, preset to 0 is faster (first match)
                if attr and attr > 0 then
                    if font ~= prevfont or attr ~= prevattr then
                        local used = attrfonts[font]
                        if not used then
                            used = { }
                            attrfonts[font] = used
                        end
                        if not used[attr] then
                            local d = set_dynamics(tfmid[font],attr) -- todo, script, language -> n.language also axis
                            if d then
                                used[attr] = d
                                a = a + 1
                            end
                        end
                        prevfont, prevattr = font, attr
                    end
                elseif font ~= prevfont then
                    prevfont, prevattr = font, 0
                    local used = usedfonts[font]
                    if not used then
                        local data = tfmid[font]
                        if data then
                            local shared = data.shared -- we need to check shared, only when same features
                            if shared then
                                local processors = shared.processors
                                if processors and #processors > 0 then
                                    usedfonts[font] = processors
                                    u = u + 1
                                end
                            end
                        else
                            -- probably nullfont
                        end
                    end
                else
                    prevattr = attr
                end
            end
            -- we could combine these and just make the attribute nil
            if u > 0 then
                for font, processors in pairs(usedfonts) do
                    local n = #processors
                    if n == 1 then
                        local h, d = processors[1](head,font,false)
                        head, done = h or head, done or d
                    else
                        for i=1,#processors do
                            local h, d = processors[i](head,font,false)
                            head, done = h or head, done or d
                        end
                    end
                end
            end
            if a > 0 then -- we need to get rid of a loop here
                for font, dynamics in pairs(attrfonts) do
                    for attribute, processors in pairs(dynamics) do -- attr can switch in between
                        local n = #processors
                        if n == 1 then
                            local h, d = processors[1](head,font,attribute)
                            head, done = h or head, done or d
                        else
                            for i=1,n do
                                local h, d = processors[i](head,font,attribute)
                                head, done = h or head, done or d
                            end
                        end
                    end
                end
            end
            stoptiming(nodes)
            if nodes.trace then
                nodes.report(head,done)
            end
            return head, true
        end
    end

end

-- vbox: grouptype: vbox vtop output split_off split_keep  | box_type: exactly|aditional
-- hbox: grouptype: hbox adjusted_hbox(=hbox_in_vmode)     | box_type: exactly|aditional

do

    local has_attribute, set, attribute = node.has_attribute, node.set_attribute, tex.attribute

    function nodes.inherit_attributes(n) -- still ok ?
        if n then
            local i = 1
            while true do
                local a = attribute[i]
                if a < 0 then
                    break
                else
                    local ai = has_attribute(n,i)
                    if not ai then
                        set(n,i,a)
                    end
                    i = i + 1
                end
            end
        end
    end

end

function nodes.length(head)
    if head then
        local m = 0
        for n in node.traverse(head) do
            m = m + 1
        end
        return m
    else
        return 0
    end
end

lists = lists or { }
chars = chars or { }
words = words or { } -- not used yet

callbacks.trace = false

do

    kernel = kernel or { }

    local starttiming, stoptiming = input.starttiming, input.stoptiming
    local hyphenate, ligaturing, kerning = lang.hyphenate, node.ligaturing, node.kerning

    function kernel.hyphenation(head,tail) -- lang.hyphenate returns done
        if head == tail then
            return head, tail, false
        else
            starttiming(kernel)
            local done = head ~= tail and hyphenate(head,tail)
            stoptiming(kernel)
            return head, tail, done
        end
    end
    function kernel.ligaturing(head,tail) -- node.ligaturing returns head,tail,done
        if head == tail then
            return head, tail, false
        else
            starttiming(kernel)
            local head, tail, done = ligaturing(head,tail)
            stoptiming(kernel)
            return head, tail, done
        end
    end
    function kernel.kerning(head,tail) -- node.kerning returns head,tail,done
        if head == tail then
            return head, tail, false
        else
            starttiming(kernel)
            local head, tail, done = kerning(head,tail)
            stoptiming(kernel)
            return head, tail, done
        end
    end

end

callback.register('hyphenate' , function(head,tail) return tail end)
callback.register('ligaturing', function(head,tail) return tail end)
callback.register('kerning'   , function(head,tail) return tail end)

nodes.tasks      = nodes.tasks      or { }
nodes.tasks.data = nodes.tasks.data or { }

function nodes.tasks.new(name,list)
    local tasklist = sequencer.reset()
    nodes.tasks.data[name] = { list = tasklist, runner = false }
    for _, task in ipairs(list) do
        sequencer.appendgroup(tasklist,task)
    end
end

function nodes.tasks.appendaction(name,group,action,where,kind)
    local data = nodes.tasks.data[name]
    sequencer.appendaction(data.list,group,action,where,kind)
    data.runner = false
end

function nodes.tasks.prependaction(name,group,action,where,kind)
    local data = nodes.tasks.data[name]
    sequencer.prependaction(data.list,group,action,where,kind)
    data.runner = false
end

function nodes.tasks.removeaction(name,group,action)
    local data = nodes.tasks.data[name]
    sequencer.removeaction(data.list,group,action)
    data.runner = false
end

function nodes.tasks.showactions(name,group,action,where,kind)
    local data = nodes.tasks.data[name]
    logs.report("nodes","task %s, list:\n%s",name,sequencer.nodeprocessor(data.list))
end

function nodes.tasks.actions(name)
    local data = nodes.tasks.data[name]
    return function(head,tail)
        local runner = data.runner
        if not runner then
            if nodes.trace_tasks then
                logs.report("nodes","creating task runner '%s'",name)
            end
            runner = sequencer.compile(data.list,sequencer.nodeprocessor)
            data.runner = runner
        end
        return runner(head,tail)
    end
end

nodes.tasks.new (
    "processors",
    {
        "before",      -- for users
        "normalizers",
        "characters",
        "words",
        "fonts",
        "lists",
        "after",       -- for users
    }
)

-- these definitions will move

nodes.tasks.appendaction("processors", "normalizers", "nodes.normalize_fonts", nil)
nodes.tasks.appendaction("processors", "characters", "chars.handle_mirroring", nil, "notail")
nodes.tasks.appendaction("processors", "characters", "chars.handle_casing", nil, "notail")
nodes.tasks.appendaction("processors", "characters", "chars.handle_breakpoints", nil, "notail")
nodes.tasks.appendaction("processors", "words", "kernel.hyphenation", nil)
nodes.tasks.appendaction("processors", "words", "languages.words.check", nil, "notail")
nodes.tasks.appendaction("processors", "fonts", "nodes.process_characters", nil, "notail")
nodes.tasks.appendaction("processors", "fonts", "nodes.protect_glyphs", nil, "nohead")
nodes.tasks.appendaction("processors", "fonts", "kernel.ligaturing", nil)
nodes.tasks.appendaction("processors", "fonts", "kernel.kerning", nil)
nodes.tasks.appendaction("processors", "lists", "lists.handle_spacing", nil, "notail")
nodes.tasks.appendaction("processors", "lists", "lists.handle_kerning", nil, "notail")


local free = node.free

local function cleanup_page(head) -- rough
    local prev, start = nil, head
    while start do
        local id, nx = start.id, start.next
        if id == disc or id == mark then
            if prev then
                prev.next = nx
            end
            if start == head then
                head = nx
            end
            local tmp = start
            start = nx
            free(tmp)
        elseif id == hlist or id == vlist then
            local sl = start.list
            if sl then
                start.list = cleanup_page(sl)
            end
            prev, start = start, nx
        else
            prev, start = start, nx
        end
    end
    return head
end

nodes.cleanup_page_first = false

function nodes.cleanup_page(head)
    if nodes.cleanup_page_first then
        head = cleanup_page(head)
    end
    return head, false
end

nodes.tasks.new (
    "shipouts",
    {
        "before",      -- for users
        "normalizers",
        "finishers",
        "after",       -- for users
    }
)

nodes.tasks.appendaction("shipouts", "normalizers", "nodes.cleanup_page", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_color", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_transparency", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_overprint", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_negative", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_effect", nil, "notail")
nodes.tasks.appendaction("shipouts", "finishers", "shipouts.handle_viewerlayer", nil, "notail")

local actions = nodes.tasks.actions("shipouts")

function nodes.process_page(head) -- problem, attr loaded before node, todo ...
    return actions(head) -- no tail
end

-- or just: nodes.process_page = nodes.tasks.actions("shipouts")


do -- remove these

    local actions         = nodes.tasks.actions("processors")
    local first_character = node.first_character
    local slide           = node.slide

    local n = 0

    local function reconstruct(head)
        local t = { }
        local h = head
        while h do
            local id = h.id
            if id == glyph then
                t[#t+1] = utf.char(h.char)
            else
                t[#t+1] = "[]"
            end
            h = h.next
        end
        return table.concat(t)
    end

    local function tracer(what,state,head,groupcode,before,after,show)
        if not groupcode then
            groupcode = "unknown"
        elseif groupcode == "" then
            groupcode = "mvl"
        end
        n = n + 1
        if show then
            texio.write_nl(format("%s %s: %s, group: %s, nodes: %s -> %s, string: %s",what,n,state,groupcode,before,after,reconstruct(head)))
        else
            texio.write_nl(format("%s %s: %s, group: %s, nodes: %s -> %s",what,n,state,groupcode,before,after))
        end
    end

    function nodes.processors.pre_linebreak_filter(head,groupcode) -- todo: tail
        local first, found = first_character(head)
        if found then
            if callbacks.trace then
                local before = nodes.count(head,true)
                local head, tail, done = actions(head,slide(head))
                local after = nodes.count(head,true)
                if done then
                    tracer("pre_linebreak","changed",head,groupcode,before,after,true)
                else
                    tracer("pre_linebreak","unchanged",head,groupcode,before,after,true)
                end
                return (done and head) or true
            else
                local head, tail, done = actions(head,slide(head))
                return (done and head) or true
            end
        else
            if callbacks.trace then
                local n = nodes.count(head,false)
                tracer("pre_linebreak","no chars",head,groupcode,n,n)
            end
            return true
        end
    end

    function nodes.processors.hpack_filter(head,groupcode) -- todo: tail
        local first, found = first_character(head)
        if found then
            if callbacks.trace then
                local before = nodes.count(head,true)
                local head, tail, done = actions(head,slide(head))
                local after = nodes.count(head,true)
                if done then
                    tracer("hpack","changed",head,groupcode,before,after,true)
                else
                    tracer("hpack","unchanged",head,groupcode,before,after,true)
                end
                return (done and head) or true
            else
                local head, tail, done = actions(head,slide(head))
                return (done and head) or true
            end
        end
        if callbacks.trace then
            local n = nodes.count(head,false)
            tracer("hpack","no chars",head,groupcode,n,n)
        end
        return true
    end

end

callback.register('pre_linebreak_filter', nodes.processors.pre_linebreak_filter)
callback.register('hpack_filter'        , nodes.processors.hpack_filter)

do

    -- beware, some field names will change in a next release of luatex

    local expand = table.tohash {
        "list",         -- list_ptr & ins_ptr & adjust_ptr
        "pre",          --
        "post",         --
        "spec",         -- glue_ptr
        "top_skip",     --
        "attr",         --
        "replace",      -- nobreak
        "components",   -- lig_ptr
        "box_left",     --
        "box_right",    --
        "glyph",        -- margin_char
        "leader",       -- leader_ptr
        "action",       -- action_ptr
        "value",        -- user_defined nodes with subtype 'a' en 'n'
    }

    -- page_insert: "height", "last_ins_ptr", "best_ins_ptr"
    -- split_insert:  "height", "last_ins_ptr", "best_ins_ptr", "broken_ptr", "broken_ins"

    local ignore = table.tohash {
        "page_insert",
        "split_insert",
        "ref_count",
    }

    local dimension = table.tohash {
        "width", "height", "depth", "shift",
        "stretch", "shrink",
        "xoffset", "yoffset",
        "surround",
        "kern",
        "box_left_width", "box_right_width"
    }

    -- flat: don't use next, but indexes
    -- verbose: also add type
    -- can be sped up

    nodes.dimensionfields = dimension
    nodes.listablefields  = expand
    nodes.ignorablefields = ignore

    -- not ok yet:

    function nodes.astable(n,sparse) -- not yet ok
        local f, t = node.fields(n.id,n.subtype), { }
        for i=1,#f do
            local v = f[i]
            local d = n[v]
            if d then
                if ignore[v] or v == "id" then
                    -- skip
                elseif expand[v] then -- or: type(n[v]) ~= "string" or type(n[v]) ~= "number" or type(n[v]) ~= "table"
                    t[v] = "pointer to list"
                elseif sparse then
                    if (type(d) == "number" and d ~= 0) or (type(d) == "string" and d ~= "") then
                        t[v] = d
                    end
                else
                    t[v] = d
                end
            end
        end
        t.type = node.type(n.id)
        return t
    end

    local nodefields = node.fields
    local nodetype   = node.type

    -- under construction:

    local function totable(n,flat,verbose)
        local function to_table(n)
            local f = nodefields(n.id,n.subtype)
            local tt = { }
            for k=1,#f do
                local v = f[k]
                local nv = n[v]
                if nv then
                    if ignore[v] then
                        -- skip
                    elseif expand[v] then
                        if type(nv) == "number" or type(nv) == "string" then
                            tt[v] = nv
                        else
                            tt[v] = totable(nv,flat,verbose)
                        end
                    elseif type(nv) == "table" then
                        tt[v] = nv -- totable(nv,flat,verbose) -- data
                    else
                        tt[v] = nv
                    end
                end
            end
            if verbose then
                tt.type = nodetype(tt.id)
            end
            return tt
        end
        if n then
            if flat then
                local t = { }
                while n do
                    t[#t+1] = to_table(n)
                    n = n.next
                end
                return t
            else
                local t = to_table(n)
                if n.next then
                    t.next = totable(n.next,flat,verbose)
                end
                return t
            end
        else
            return { }
        end
    end

    nodes.totable = totable

    local function key(k)
        return ((type(k) == "number") and "["..k.."]") or k
    end

    -- not ok yet; this will become a module

    local function serialize(root,name,handle,depth,m)
        handle = handle or print
        if depth then
            depth = depth .. " "
            handle(("%s%s={"):format(depth,key(name)))
        else
            depth = ""
            local tname = type(name)
            if tname == "string" then
                if name == "return" then
                    handle("return {")
                else
                    handle(name .. "={")
                end
            elseif tname == "number"then
                handle("[" .. name .. "]={")
            else
                handle("t={")
            end
        end
        if root then
            local fld
            if root.id then
                fld = nodefields(root.id,root.subtype) -- we can cache these (todo)
            else
                fld = table.sortedkeys(root)
            end
            if type(root) == 'table' and root['type'] then -- userdata or table
                handle(("%s %s=%q,"):format(depth,'type',root['type']))
            end
            for _,k in ipairs(fld) do
                if k == "ref_count" then
                    -- skip
                elseif k then
                    local v = root[k]
                    local t = type(v)
                    if t == "number" then
                        if v == 0 then
                            -- skip
                        else
                            handle(("%s %s=%s,"):format(depth,key(k),v))
                        end
                    elseif t == "string" then
                        if v == "" then
                            -- skip
                        else
                            handle(("%s %s=%q,"):format(depth,key(k),v))
                        end
                    elseif v then -- userdata or table
                        serialize(v,k,handle,depth,m+1)
                    end
                end
            end
            if root['next'] then -- userdata or table
                serialize(root['next'],'next',handle,depth,m+1)
            end
        end
        if m and m > 0 then
            handle(("%s},"):format(depth))
        else
            handle(("%s}"):format(depth))
        end
    end

    function nodes.serialize(root,name)
        local t = { }
        local function flush(s)
            t[#t+1] = s
        end
        serialize(root, name, flush, nil, 0)
        return table.concat(t,"\n")
    end

    function nodes.serializebox(n,flat,verbose)
        return nodes.serialize(nodes.totable(tex.box[n],flat,verbose))
    --  return nodes.serialize(tex.box[n])
    end

    function nodes.visualizebox(...)
    --  tex.sprint(tex.ctxcatcodes,"\\starttyping\n" .. nodes.serializebox(...) .. "\n\\stoptyping\n")
        tex.print(tex.ctxcatcodes,"\\starttyping")
        tex.print(nodes.serializebox(...))
        tex.print("\\stoptyping")
    end

    function nodes.list(head,n) -- name might change to nodes.type
        if not n then
            tex.print(tex.ctxcatcodes,"\\starttyping")
        end
        while head do
            local id = head.id
            tex.print(string.rep(" ",n or 0) .. tostring(head) .. "\n")
            if id == hlist or id == vlist then
                nodes.list(head.list,(n or 0)+1)
            end
            head = head.next
        end
        if not n then
            tex.print("\\stoptyping")
        end
    end

    function nodes.print(head,n)
        while head do
            local id = head.id
            texio.write_nl(string.rep(" ",n or 0) .. tostring(head))
            if id == hlist or id == vlist then
                nodes.print(head.list,(n or 0)+1)
            end
            head = head.next
        end
    end

    function nodes.check_for_leaks(sparse)
        local l = { }
        local q = node.usedlist()
        for p in node.traverse(q) do
            local s = table.serialize(nodes.astable(p,sparse),node.type(p.id))
            l[s] = (l[s] or 0) + 1
        end
        node.flush_list(q)
        for k, v in pairs(l) do
            texio.write_nl(format("%s * %s", v, k))
        end
    end

end

if not node.list_has_attribute then -- no longer needed

    function node.list_has_attribute(list,attribute)
        if list and attribute then
            for n in node.traverse(list) do
                local a = has_attribute(n,attribute)
                if a then return a end
            end
        end
        return false
    end

end

function nodes.pack_list(head)
    local t = { }
    for n in node.traverse(head) do
        t[#t+1] = tostring(n)
    end
    return t
end

do

    function nodes.leftskip(n)
        while n do
            local id = n.id
            if id == glue then
                if n.subtype == 8 then -- 7 in c/web source
                    return (n.spec and n.spec.width) or 0
                else
                    return 0
                end
            elseif id == whatsit then
                n = n.next
            elseif id == hlist then
                return n.width
            else
                break
            end
        end
        return 0
    end
    function nodes.rightskip(n)
        if n then
            n = node.slide(n)
            while n do
                local id = n.id
                if id == glue then
                    if n.subtype == 9 then -- 8 in the c/web source
                        return (n.spec and n.spec.width) or 0
                    else
                        return 0
                    end
                elseif id == whatsit then
                    n = n.prev
                else
                    break
                end
            end
        end
        return false
    end

end

-- goodie
--
-- if node.valid(tex.box[0]) then print("valid node") end

--~ do
--~     local n = node.new(0,0)
--~     local m = getmetatable(n)
--~     m.__metatable = 'node'
--~     node.free(n)

--~     function node.valid(n)
--~         return n and getmetatable(n) == 'node'
--~     end
--~ end

-- for the moment we put this here:

do

    nodes.tracers = { }
    nodes.tracers.characters = { }

    local function collect(head,list,tag,n)
        n = n or 0
        local ok, fn = false, nil
        while head do
            local id = head.id
            if id == glyph then
                local f = head.font
                if f ~= fn then
                    ok, fn = false, f
                end
                local c = head.char
                local d = tfmid[f].descriptions[c]
                local i = (d and d.index) or -1
                if not ok then
                    ok = true
                    n = n + 1
                    list[n] = list[n] or { }
                    list[n][tag] = { }
                end
                local l = list[n][tag]
                l[#l+1] = { c, f, i }
            elseif id == disc then
                -- skip
            else
                ok = false
            end
            head = head.next
        end
    end

    function nodes.tracers.characters.equal(ta, tb)
        if #ta ~= #tb then
            return false
        else
            for i=1,#ta do
                local a, b = ta[i], tb[i]
                if a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3] then
                    return false
                end
            end
        end
        return true
    end
    function nodes.tracers.characters.string(t)
        local tt = { }
        for i=1,#t do
            tt[i] = utf.char(t[i][1])
        end
        return table.concat(tt,"")
    end
    function nodes.tracers.characters.unicodes(t,decimal)
        local tt = { }
        for i=1,#t do
            if decimal then
                tt[i] = t[i][1]
            else
                tt[i] = format("%04X",t[i][1])
            end
        end
        return table.concat(tt," ")
    end
    function nodes.tracers.characters.indices(t,decimal)
        local tt = { }
        for i=1,#t do
            if decimal then
                tt[i] = t[i][3]
            else
                tt[i] = format("%04X",t[i][3])
            end
        end
        return table.concat(tt," ")
    end
    function nodes.tracers.characters.fonts(t)
        local f = t[1] and t[1][2]
        return (f and file.basename(tfmid[f].filename or "unknown")) or "unknown"
    end

    function nodes.tracers.characters.start()
        local npc = nodes.process_characters
        local list = { }
        function nodes.process_characters(head)
            local n = #list
            collect(head,list,'before',n)
            local h, d = npc(head)
            collect(head,list,'after',n)
            if #list > n then
                list[#list+1] = { }
            end
            return h, d
        end
        function nodes.tracers.characters.stop()
            tracers.list['characters'] = list
            lmx.set('title', 'ConTeXt Character Processing Information')
            lmx.set('color-background-one', lmx.get('color-background-yellow'))
            lmx.set('color-background-two', lmx.get('color-background-purple'))
            lmx.show('context-characters.lmx')
            lmx.restore()
            nodes.process_characters = npc
        end
    end

    local stack = { }

    function nodes.tracers.start(tag)
        stack[#stack+1] = tag
        local tracer = nodes.tracers[tag]
        if tracer and tracer.start then
            tracer.start()
        end
    end
    function nodes.tracers.stop()
        local tracer = stack[#stack]
        if tracer and tracer.stop then
            tracer.stop()
        end
        stack[#stack] = nil
    end

end
