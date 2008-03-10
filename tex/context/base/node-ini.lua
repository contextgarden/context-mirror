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

nodes        = nodes or { }
nodes.trace  = false
nodes.ignore = nodes.ignore or false

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


    local glyph       = node.id('glyph')
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

    --~     function nodes.remove(head, current, free_too)
    --~         if head == current then
    --~             local cn = current.next
    --~             if cn then
    --~                 cn.prev = nil
    --~                 if free_too then
    --~                     node.free(current)
    --~                     return cn, cn, nil
    --~                 else
    --~                     current.prev = nil
    --~                     current.next = nil
    --~                     return cn, cn, current
    --~                 end
    --~             else
    --~                 if free_too then
    --~                     node.free(current)
    --~                     return nil, nil, nil
    --~                 else
    --~                     return head,current,current
    --~                 end
    --~             end
    --~         else
    --~             local cp = current.prev
    --~             local cn = current.next
    --~             if not cp and head.next == current then
    --~                 cp = head
    --~             end
    --~             if cn then
    --~                 cn.prev = cp
    --~                 if cp then
    --~                     cp.next = cn
    --~                 end
    --~             elseif cp then
    --~                 cp.next = nil
    --~             end
    --~             if free_too then
    --~                 node.free(current)
    --~                 return head, cn, nil
    --~             else
    --~                 current.prev = nil
    --~                 current.next = nil
    --~                 return head, cn, current
    --~             end
    --~         end
    --~     end

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
            if c ~= h then
                return h, n
            end
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
                texio.write(string.format("<++ %s>",nodes.count(t)))
            else
                texio.write(string.format("<+ %s>",nodes.count(t)))
            end
        else
            if status.output_active then
                texio.write(string.format("<-- %s>",nodes.count(t)))
            else
                texio.write(string.format("<- %s>",nodes.count(t)))
            end
        end
    end
end

do

    local hlist, vlist = node.id('hlist'), node.id('vlist')

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

if not fonts        then fonts        = { } end
if not fonts.tfm    then fonts.tfm    = { } end
if not fonts.tfm.id then fonts.tfm.id = { } end

do

    local glyph = node.id('glyph')
    local has_attribute = node.has_attribute
    local traverse_id = node.traverse_id

    local pairs = pairs

    local starttiming, stoptiming = input.starttiming, input.stoptiming

    function nodes.process_characters(head)
        if status.output_active then  -- not ok, we need a generic blocker, pagebody ! / attr tex.attibutes
            return head, false -- true
        else
            -- either next or not, but definitely no already processed list
            starttiming(nodes)
            local usedfonts, attrfonts, done = { }, { }, false
            -- todo: should be independent of otf
            local set_dynamics, font_ids = fonts.otf.set_dynamics, fonts.tfm.id -- todo: font-var.lua so that we can global this one
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
                            local d = set_dynamics(font_ids[font],attr) -- todo, script, language -> n.language also axis
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
                        local data = font_ids[font]
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

--~ nodes.processors.actions = nodes.processors.actions or { }

--~ function nodes.processors.action(head)
--~     if head then
--~         node.slide(head)
--~         local done = false
--~         local actions = nodes.processors.actions
--~         for i=1,#actions do
--~             local h, ok = actions[i](head)
--~             if ok then
--~                 head, done = h, true
--~             end
--~         end
--~         if done then
--~             return head
--~         else
--~             return true
--~         end
--~     else
--~         return head
--~     end
--~ end

lists         = lists         or { }
lists.plugins = lists.plugins or { }

chars         = chars         or { }
chars.plugins = chars.plugins or { }

--~ words         = words         or { }
--~ words.plugins = words.plugins or { }

callbacks.trace = false

do

    kernel = kernel or { }

    local starttiming, stoptiming = input.starttiming, input.stoptiming
    local hyphenate, ligaturing, kerning = lang.hyphenate, node.ligaturing, node.kerning

    function kernel.hyphenation(head,tail) -- lang.hyphenate returns done
        starttiming(kernel)
        local done = hyphenate(head,tail)
        stoptiming(kernel)
        return head, tail, done
    end
    function kernel.ligaturing(head,tail) -- node.ligaturing returns head,tail,done
        starttiming(kernel)
        local head, tail, done = ligaturing(head,tail)
        stoptiming(kernel)
        return head, tail, done
    end
    function kernel.kerning(head,tail) -- node.kerning returns head,tail,done
        starttiming(kernel)
        local head, tail, done = kerning(head,tail)
        stoptiming(kernel)
        return head, tail, done
    end

end

callback.register('hyphenate' , function(head,tail) return tail end)
callback.register('ligaturing', function(head,tail) return tail end)
callback.register('kerning'   , function(head,tail) return tail end)

-- used to be loop, this is faster, called often; todo: shift up tail or even better,
-- handle tail everywhere; for the moment we're safe

do

    local charplugins, listplugins = chars.plugins, lists.plugins

    nodes.processors.actions = function(head,tail) -- removed: if head ... end
        local ok, done = false, false
        head,       ok = nodes.process_attributes(head,charplugins) ; done = done or ok -- attribute driven
        head, tail, ok = kernel.hyphenation      (head,tail)        ; done = done or ok -- language driven
        head,       ok = languages.words.check   (head,tail)        ; done = done or ok -- language driven
        head,       ok = nodes.process_characters(head)             ; done = done or ok -- font driven
                    ok = nodes.protect_glyphs    (head)             ; done = done or ok -- turn chars into glyphs
        head, tail, ok = kernel.ligaturing       (head,tail)        ; done = done or ok -- normal ligaturing routine / needed for base mode
        head, tail, ok = kernel.kerning          (head,tail)        ; done = done or ok -- normal kerning routine    / needed for base mode
        head,       ok = nodes.process_attributes(head,listplugins) ; done = done or ok -- attribute driven
        return head, done
    end

end

do

    local actions         = nodes.processors.actions
    local first_character = node.first_character
    local slide           = node.slide

    local function tracer(what,state,head,groupcode,glyphcount)
        texio.write_nl(string.format("%s %s: group: %s, nodes: %s",
            (state and "Y") or "N", what, groupcode or "?", nodes.count(head,true)))
    end

    function nodes.processors.pre_linebreak_filter(head,groupcode) -- todo: tail
        local first, found = first_character(head)
        if found then
            if callbacks.trace then tracer("pre_linebreak",true,head,groupcode) end
            local head, done = actions(head,slide(head))
            return (done and head) or true
        else
            if callbacks.trace then tracer("pre_linebreak",false,head,groupcode) end
            return true
        end
    end

    function nodes.processors.hpack_filter(head,groupcode) -- todo: tail
        local first, found = first_character(head)
        if found then
            if callbacks.trace then tracer("hpack",true,head,groupcode) end
            local head, done = actions(head,slide(head))
            return (done and head) or true
        end
        if callbacks.trace then tracer("hpack",false,head,groupcode) end
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

    -- not ok yet:

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

    function nodes.check_for_leaks(sparse)
        local l = { }
        local q = node.usedlist()
        for p in node.traverse(q) do
            local s = table.serialize(nodes.astable(p,sparse),node.type(p.id))
            l[s] = (l[s] or 0) + 1
        end
        node.flush_list(q)
        for k, v in pairs(l) do
            texio.write_nl(string.format("%s * %s", v, k))
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

    local glue, whatsit, hlist = node.id("glue"), node.id("whatsit"), node.id("hlist")

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

    local glyph, disc = node.id('glyph'), node.id('disc')

    local fontdata = fonts.tfm.id

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
                local d = fontdata[f].characters[c]
                local i = (d and d.description.index) or -1
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
                tt[i] = string.format("%04X",t[i][1])
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
                tt[i] = string.format("%04X",t[i][3])
            end
        end
        return table.concat(tt," ")
    end
    function nodes.tracers.characters.fonts(t)
        local f = t[1] and t[1][2]
        return (f and file.basename(fontdata[f].filename or "unknown")) or "unknown"
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
