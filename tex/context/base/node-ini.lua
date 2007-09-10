if not modules then modules = { } end modules ['node-ini'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Access to nodes is what gives <l n='luatex'/> its power. Here we
implement a few helper functions.</p>
--ldx]]--

nodes       = nodes or { }
nodes.trace = false

-- handy helpers

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

    function nodes.delete(head,current)
        return nodes.remove(head,current,true)
    end

    nodes.before =  node.insert_before
    nodes.after  =  node.insert_after

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

--~ function nodes.count(stack)
--~     if stack then
--~         local n = 0
--~         for _, node in pairs(stack) do
--~             if node then
--~                 local kind = node[1]
--~                 if kind == 'hlist' or kind == 'vlist' then
--~                     local content = node[8]
--~                     if type(content) == "table" then
--~                         n = n + 1 + nodes.count(content) -- self counts too
--~                     else
--~                         n = n + 1
--~                     end
--~                 elseif kind == 'inline' then
--~                     n = n + nodes.count(node[4]) -- self does not count
--~                 else
--~                     n = n + 1
--~                 end
--~             end
--~         end
--~         return n
--~     else
--~         return 0
--~     end
--~ end

do

    local hlist, vlist = node.id('hlist'), node.id('vlist')

    function nodes.count(stack)
        local n = 0
        while stack do
            local id = stack.id
            if id == hlist or id == vlist then
                local list = stack.list
                if list then
                    n = n + 1 + nodes.count(list) -- self counts too
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
contains the original node and one or more new nodes. Before we pass
back the list we collapse the list. Of course collapsing could be built
into the <l n='tex'/> engine, but this is a not so natural extension.</p>

<p>When we collapse (something that we only do when really needed), we
also ignore the empty nodes.</p>
--ldx]]--

--~ function nodes.inline(...)
--~     return { 'inline', 0, nil, { ... } }
--~ end

--~ do

--~     function collapse(stack,existing_t)
--~         if stack then
--~             local t = existing_t or { }
--~             for _, node in pairs(stack) do
--~                 if node then
--~                  -- if node[3] then node[3][1] = nil end -- remove status bit
--~                     local kind = node[1]
--~                     if kind == 'inline' then
--~                         collapse(node[4],t)
--~                     elseif kind == 'hlist' or kind == 'vlist' then
--~                         local content = node[8]
--~                         if type(content) == "table" then
--~                             node[8] = collapse(content)
--~                         end
--~                         t[#t+1] = node
--~                     else
--~                         t[#t+1] = node
--~                     end
--~                 else
--~                     -- deleted node
--~                 end
--~             end
--~             return t
--~         else
--~             return stack
--~         end
--~     end

--~     nodes.collapse = collapse

--~ end

--[[ldx--
<p>The following function implements a generic node processor. A
generic processer is not that much needed, because we often need
to act differently for horizontal or vertical lists. For instance
counting nodes needs a different method (ok, we could add a second
handle for catching them but it would become messy then).</p>
--ldx]]--

--~ function nodes.each(stack,handle)
--~     if stack then
--~         local i = 1
--~         while true do
--~             local node = stack[i]
--~             if node then
--~                 local kind = node[1]
--~                 if kind == 'hlist' or kind == 'vlist' then
--~                     local content = node[8]
--~                     if type(content) == "table" then
--~                         nodes.each(content,handle)
--~                     end
--~                 elseif kind == 'inline' then
--~                     nodes.each(node[4],handle)
--~                 else
--~                     stack[i] = handle(kind,node)
--~                 end
--~             end
--~             i = i + 1
--~             if i > #stack then
--~                 break
--~             end
--~         end
--~     end
--~ end

--~ function nodes.remove(stack,id,subid) -- "whatsit", 6
--~     nodes.each(stack, function(kind,node)
--~         if kind == id and node[2] == subid then
--~             return false
--~         else
--~             return node
--~         end
--~     end)
--~ end

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

    local glyph, hlist, vlist = node.id('glyph'), node.id('hlist'), node.id('vlist')
    local pushmarks  = false

    function nodes.process_glyphs(head)
        if status.output_active then  -- not ok, we need a generic blocker, pagebody ! / attr tex.attibutes
            -- 25% calls
            return true
        elseif not head then
            -- 25% calls
            return true
        elseif not head.next and (head.id == hlist or head.id == vlist) then
            return head
        else
            -- either next or not, but definitely no already processed list
            input.start_timing(nodes)
            local usedfonts, found, fontdata, done = { }, false, fonts.tfm.id, false
            for n in node.traverse_id(glyph,head) do
                local font = n.font
                if not usedfonts[font] then
                    local shared = fontdata[font].shared
                    if shared and shared.processors then
                        usedfonts[font], found = shared.processors, true
                    end
                end
            end
            if found then
                local tail = head
                if head.next then
                    tail = node.slide(head)
                else
                    head.prev = nil
                end
                for font, processors in pairs(usedfonts) do
                    if pushmarks then
                        local h, d = fonts.pushmarks(head,font)
                        head, done = head or h, done or d
                    end
                    for _, processor in ipairs(processors) do
                        local h, d = processor(head,font)
                        head, done = head or h, done or d
                    end
                    if pushmarks then
                        local h, d = fonts.popmarks(head,font)
                        head, done = head or h, done or d
                    end
                end
            end
            input.stop_timing(nodes)
            if nodes.trace then
                nodes.report(head,done)
            end
            if done then
                return head  -- something changed
            elseif head then
                return true  -- nothing changed
            else
                return false -- delete list
            end
        end
    end

end

-- vbox: grouptype: vbox vtop output split_off split_keep  | box_type: exactly|aditional
-- hbox: grouptype: hbox adjusted_hbox(=hbox_in_vmode)     | box_type: exactly|aditional

do

    local contains, set, attribute = node.has_attribute, node.set_attribute, tex.attribute

    function nodes.inherit_attributes(n)
        if n then
            local i = 1
            while true do
                local a = attribute[i]
                if a < 0 then
                    break
                else
                    local ai = contains(n,i)
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

nodes.processors.actions = nodes.processors.actions or { }

function nodes.processors.action(head)
    if head then
        node.slide(head)
        local actions, done = nodes.processors.actions, false
        for i=1,#actions do
            local action = actions[i]
            if action then
                local h, ok = action(head)
                if ok then
                    head = h
                end
                done = done or ok
            end
        end
        if done then
            return head
        else
            return true
        end
    else
        return head
    end
end

lists         = lists         or { }
lists.plugins = lists.plugins or { }

function nodes.process_lists(head)
    return nodes.process_attributes(head,lists.plugins)
end

chars         = chars         or { }
chars.plugins = chars.plugins or { }

function nodes.process_chars(head)
    return nodes.process_attributes(head,chars.plugins)
end

nodes.processors.actions = { -- for the moment here, will change
    nodes.process_chars,  -- attribute driven
    nodes.process_glyphs, -- font driven
    nodes.process_lists,  -- attribute driven
}

callback.register('pre_linebreak_filter', nodes.processors.action)
callback.register('hpack_filter',         nodes.processors.action)

do

    local expand = {
        list = true,
        pre = true,
        post = true,
        spec = true,
        attr = true,
        components = true,
    }

    -- flat: don't use next, but indexes
    -- verbose: also add type

    function nodes.totable(n,flat,verbose)
        local function totable(n,verbose)
            local f = node.fields(n.id,n.subtype)
            local tt = { }
            for _,v in ipairs(f) do
                if n[v] then
                    if v == "ref_count" then
                        -- skip
                    elseif expand[v] then -- or: type(n[v]) ~= "string" or type(n[v]) ~= "number"
                        tt[v] = nodes.totable(n[v],flat,verbose)
                    else
                        tt[v] = n[v]
                    end
                end
            end
            if verbose then
                tt.type = node.type(tt.id)
            end
            return tt
        end
        if n then
            if flat then
                local t = { }
                while n do
                    t[#t+1] = totable(n,verbose)
                    n = n.next
                end
                return t
            else
                local t = totable(n,verbose)
                if n.next then
                    t.next = nodes.totable(n.next,flat,verbose)
                end
                return t
            end
        else
            return { }
        end
    end

    local function key(k)
        if type(k) == "number" then
            return "["..k.."]"
        else
            return k
        end
    end

    local function serialize(root,name,handle,depth,m)
        handle = handle or print
        if depth then
            depth = depth .. " "
            handle(("%s%s={"):format(depth,key(name)))
        else
            depth = ""
            if type(name) == "string" then
                if name == "return" then
                    handle("return {")
                else
                    handle(name .. "={")
                end
            elseif type(name) == "number" then
                handle("[" .. name .. "]={")
            else
                handle("t={")
            end
        end
        if root then
            local fld
            if root.id then
                fld = node.fields(root.id,root.subtype)
            else
                fld = table.sortedkeys(root)
            end
            if type(root) == 'table' and root['type'] then -- userdata or table
                handle(("%s %s=%q,"):format(depth,'type',root['type']))
            end
            for _,k in ipairs(fld) do
                if k then
                    local v = root[k]
                    local t = type(v)
                    if t == "number" then
                        handle(("%s %s=%s,"):format(depth,key(k),v))
                    elseif t == "string" then
                        handle(("%s %s=%q,"):format(depth,key(k),v))
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

end

if not node.list_has_attribute then

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

-- helpers

do

    local kern_node      = node.new("kern",1)
    local penalty_node   = node.new("penalty")
    local glue_node      = node.new("glue")
    local glue_spec_node = node.new("glue_spec")

    function nodes.penalty(p)
        local n = node.copy(penalty_node)
        n.penalty = p
        return n
    end
    function nodes.kern(k)
        local n = node.copy(kern_node)
        n.kern = k
        return n
    end
    function nodes.glue(width,stretch,shrink)
        local n = node.copy(glue_node)
        local s = node.copy(glue_spec_node)
        s.width, s.stretch, s.shrink = width, stretch, shrink
        n.spec = s
        return n
    end
    function nodes.glue_spec(width,stretch,shrink)
        local s = node.copy(glue_spec_node)
        s.width, s.stretch, s.shrink = width, stretch, shrink
        return s
    end

end

-- old code

--~ function nodes.do_process_glyphs(stack)
--~     if not stack or #stack == 0 then
--~         return false
--~     elseif #stack == 1 then
--~         local node = stack[1]
--~         if node then
--~             local kind = node[1]
--~             if kind == 'glyph' then
--~                 local tfmdata = fonts.tfm.id[node[5]] -- we can use fonts.tfm.processor_id
--~                 if tfmdata and tfmdata.shared and tfmdata.shared.processors then
--~                     for _, func in pairs(tfmdata.shared.processors) do -- per font
--~                         func(stack,1,node)
--~                     end
--~                 end
--~             elseif kind == 'hlist' or kind == "vlist" then
--~                 local done = nodes.do_process_glyphs(node[8])
--~             end
--~             return true
--~         else
--~             return false
--~         end
--~     else
--~         local font_ids = { }
--~         local done = false
--~         for _, v in pairs(stack) do
--~             if v then
--~                 if v[1] == 'glyph' then
--~                     local font_id = v[5]
--~                     local tfmdata = fonts.tfm.id[font_id] -- we can use fonts.tfm.processor_id
--~                     if tfmdata and tfmdata.shared and tfmdata.shared.processors then
--~                         font_ids[font_id] = tfmdata.shared.processors
--~                     end
--~                 end
--~             end
--~         end
--~         if done then
--~             return false
--~         else
--~             -- todo: generic loop before
--~             for font_id, _ in pairs(font_ids) do
--~                 for _, func in pairs(font_ids[font_id]) do -- per font
--~                     local i = 1
--~                     while true do
--~                         local node = stack[i]
--~                         if node and node[1] == 'glyph' and node[5] == font_id then
--~                             i = func(stack,i,node)
--~                         end
--~                         if i < #stack then
--~                             i = i + 1
--~                         else
--~                             break
--~                         end
--~                     end
--~                 end
--~             end
--~             for i=1, #stack do
--~                 local node = stack[i]
--~                 if node then
--~                     if node[1] == 'hlist' or node[1] == "vlist" then
--~                         nodes.do_process_glyphs(node[8])
--~                     end
--~                 end
--~             end
--~             return true
--~         end
--~     end
--~ end

--~ function nodes.do_process_glyphs(stack)
--~     local function process_list(node)
--~         local done = false
--~         if node and node[1] == 'hlist' or node[1] == "vlist" then
--~             local attributes = node[3]
--~             if attributes then
--~                 if not attributes[1] then
--~                     nodes.do_process_glyphs(node[8])
--~                     attributes[1] = 1
--~                     done = true
--~                 end
--~             else
--~                 nodes.do_process_glyphs(node[8])
--~                 node[3] = { 1 }
--~                 done = true
--~             end
--~         end
--~         return done
--~     end
--~     if not stack or #stack == 0 then
--~         return false
--~     elseif #stack == 1 then
--~         return process_list(stack[1])
--~     else
--~         local font_ids, found = { }, false
--~         for _, node in ipairs(stack) do
--~             if node and node[1] == 'glyph' then
--~                 local font_id = node[5]
--~                 local tfmdata = fonts.tfm.id[font_id] -- we can use fonts.tfm.processor_id
--~                 if tfmdata and tfmdata.shared and tfmdata.shared.processors then
--~                     font_ids[font_id], found = tfmdata.shared.processors, true
--~                 end
--~             end
--~         end
--~         if not found then
--~             return false
--~         else
--~             -- we need func to report a 'done'
--~             local done = false
--~             for font_id, font_func in pairs(font_ids) do
--~                 for _, func in pairs(font_func) do -- per font
--~                     local i = 1
--~                     while true do
--~                         local node = stack[i]
--~                         if node and node[1] == 'glyph' and node[5] == font_id then
--~                             i = func(stack,i,node)
--~                             done = true
--~                         end
--~                         if i < #stack then
--~                             i = i + 1
--~                         else
--~                             break
--~                         end
--~                     end
--~                 end
--~             end
--~             for _, node in ipairs(stack) do
--~                 if node then
--~                     done = done or process_list(node)
--~                 end
--~             end
--~             return done
--~         end
--~     end
--~ end

--~ function nodes.process_glyphs(t,...)
--~     input.start_timing(nodes)
--~     local done = nodes.do_process_glyphs(t)
--~     if done then
--~         t = nodes.collapse(t)
--~     end
--~     input.stop_timing(nodes)
--~     nodes.report(t,done)
--~     if done then
--~         return t
--~     else
--~         return true
--~     end
--~ end

--~ function nodes.do_process_glyphs(stack)
--~     local function process_list(node)
--~         local done = false
--~         if node and node[1] == 'hist' or node[1] == "vlist" then
--~             local attributes = node[3]
--~             if attributes then
--~                 if attributes[1] then
--~                 else
--~                     local content = node[8]
--~                     if type(content) == "table" then
--~                         nodes.do_process_glyphs(content)
--~                     end
--~                     attributes[1] = 1
--~                     done = true
--~                 end
--~             else
--~                 nodes.do_process_glyphs(node[8])
--~                 node[3] = { 1 }
--~                 done = true
--~             end
--~         end
--~         return done
--~     end
--~     if not stack or #stack == 0 then
--~         return false
--~     elseif #stack == 1 then
--~         return process_list(stack[1])
--~     else
--~         local font_ids, found = { }, false
--~         for _, node in ipairs(stack) do
--~             if node and node[1] == 'glyph' then
--~                 local font_id = node[5]
--~                 local tfmdata = fonts.tfm.id[font_id] -- we can use fonts.tfm.processor_id
--~                 if tfmdata and tfmdata.shared and tfmdata.shared.processors then
--~                     font_ids[font_id], found = tfmdata.shared.processors, true
--~                 end
--~             end
--~         end
--~         if not found then
--~             return false
--~         else
--~             -- we need func to report a 'done'
--~             local done = false
--~             for font_id, font_func in pairs(font_ids) do
--~                 for _, func in pairs(font_func) do -- per font
--~                     local i = 1
--~                     while true do
--~                         local node = stack[i]
--~                         if node and node[1] == 'glyph' and node[5] == font_id then
--~                             i = func(stack,i,node)
--~                             done = true
--~                         end
--~                         if i < #stack then
--~                             i = i + 1
--~                         else
--~                             break
--~                         end
--~                     end
--~                 end
--~             end
--~             for _, node in ipairs(stack) do
--~                 if node then
--~                     done = done or process_list(node)
--~                 end
--~             end
--~             return done
--~         end
--~     end
--~ end

--~ function nodes.process_glyphs(t,...)
--~     if status.output_active then
--~         return true
--~     else
--~         input.start_timing(nodes)
--~         local done = nodes.do_process_glyphs(t)
--~         if done then
--~             t = nodes.collapse(t)
--~         end
--~         input.stop_timing(nodes)
--~         nodes.report(t,done)
--~         if done then
--~             return t
--~         else
--~             return true
--~         end
--~     end
--~ end

--~ do

--~     local function do_process_glyphs(stack)
--~         if not stack or #stack == 0 then
--~             return false
--~         elseif #stack == 1 and stack[1][1] ~= 'glyph' then
--~             return false
--~         else
--~             local font_ids, found = { }, false
--~             local fti = fonts.tfm.id
--~             for _, node in ipairs(stack) do
--~                 if node and node[1] == 'glyph' then
--~                     local font_id = node[5]
--~                     local tfmdata = fti[font_id] -- we can use fonts.tfm.processor_id
--~                     if tfmdata and tfmdata.shared and tfmdata.shared.processors then
--~                         font_ids[font_id], found = tfmdata.shared.processors, true
--~                     end
--~                 end
--~             end
--~             if not found then
--~                 return false
--~             else
--~                 -- we need func to report a 'done'
--~                 local done = false
--~                 for font_id, font_func in pairs(font_ids) do
--~                     for _, func in pairs(font_func) do -- per font
--~                         local i = 1
--~                         while true do
--~                             local node = stack[i]
--~                             if node and node[1] == 'glyph' and node[5] == font_id then
--~                                 i = func(stack,i,node)
--~                                 done = true
--~                             end
--~                             if i < #stack then
--~                                 i = i + 1
--~                             else
--~                                 break
--~                             end
--~                         end
--~                     end
--~                 end
--~                 for _, node in ipairs(stack) do
--~                     if node then
--~                         done = done or process_list(node)
--~                     end
--~                 end
--~                 return done
--~             end
--~         end
--~     end

--~     local function do_collapse_glyphs(stack,existing_t)
--~         if stack then
--~             local t = existing_t or { }
--~             for _, node in pairs(stack) do
--~                 if node then
--~                     if node[3] then node[3][1] = nil end -- remove status bit / 1 sec faster on 15 sec
--~                     if node[1] == 'inline' then
--~                         local nodes = node[4]
--~                         if #nodes == 1 then
--~                             t[#t+1] = nodes[1]
--~                         else
--~                             do_collapse_glyphs(nodes,t)
--~                         end
--~                     else
--~                         t[#t+1] = node
--~                     end
--~                 else
--~                     -- deleted node
--~                 end
--~             end
--~             return t
--~         else
--~             return stack
--~         end
--~     end

--~     function nodes.process_glyphs(t,...)
--~     --~ print(...)
--~         if status.output_active then  -- not ok, we need a generic blocker, pagebody ! / attr tex.attibutes
--~             return true
--~         else
--~             input.start_timing(nodes)
--~             local done = do_process_glyphs(t)
--~             if done then
--~                 t = do_collapse_glyphs(t)
--~             end
--~             input.stop_timing(nodes)
--~             nodes.report(t,done)
--~             if done then
--~     --~ texio.write_nl("RETURNING PROCESSED LIST")
--~                 return t
--~             else
--~     --~ texio.write_nl("RETURNING SIGNAL")
--~                 return true
--~             end
--~         end
--~     end

--~ end
