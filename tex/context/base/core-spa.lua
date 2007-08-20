if not modules then modules = { } end modules ['core-spa'] = {
    version   = 1.001,
    comment   = "companion to core-spa.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

do

    local glyph, disc, kern, glue, hlist, vlist = node.id('glyph'), node.id('disc'), node.id('kern'), node.id('glue'), node.id('hlist'), node.id('vlist')

    local kernnode = node.new('kern')
    local stretch  = attributes.numbers['kern-chars'] or 141

    function nodes.kern_chars(head)
        local fti, scale, has_attribute = fonts.tfm.id, tex.scale, node.has_attribute
        local fnt, pchar, pfont, p, n = nil, nil, nil, nil, head
-- local marks = fti[font].shared.otfdata.luatex.marks
        while n do
            local id = n.id
            local extra = has_attribute(n,stretch)
            if id == glyph then
                if pfont == n.font then
                    -- check for mark
                    local tchar = n.char
-- if not marks[tchar] then
                    local pdata = fti[pfont].characters[pchar]
                    local pkern = pdata.kerns
                    if pkern and pkern[tchar] then
                        local k = node.copy(kernnode)
                        if extra then
                            k.kern = pkern[tchar] + extra
                            if p.id == disc then
                                p.replace = p.replace + 1
                            end
                        else
                            k.kern = pkern[tchar]
                        end
                        k.attr = n.attr
                        k.next = p.next
                        p.next = k
                    elseif extra then
                        local k = node.copy(kernnode)
                        k.kern = extra
                        k.attr = n.attr
                        k.next = p.next
                        p.next = k
                        if p.id == disc then
                            p.replace = p.replace + 1
                        end
-- end
                    end
                else
                    pfont, pchar = n.font, n.char
                end
            elseif id == disc then
                local pre, post = n.pre, n.post
                if pre then
                    local nn, pp = p.prev, p.next
                    p.prev, p.next = nil, pre -- hijack node
                    pre = nodes.kern_chars(p)
                    pre = pre.next
                    pre.prev = nil
                    p.prev, p.next = nn, pp
                    n.pre = pre
                end
                if post and n.next then
                    local tail = node.slide(post)
                    local nn, pp = n.next.prev, n.next.next
                    n.next.next, n.next.prev = nil, tail
                    tail.next = n.next -- hijack node
                    post = nodes.kern_chars(post)
                    tail.next = nil
                    n.next.prev, n.next.next = nn, pp
                    n.post = post
                end
                if n.next and n.next.id == glyph then
                    local tchar = n.next.char
                    local pdata = fti[pfont].characters[pchar]
                    local pkern = pdata.kerns
                    if pkern and pkern[tchar] then
                        local k = node.copy(kernnode)
                        if extra then
                            k.kern = pkern[tchar] + extra
                        else
                            k.kern = pkern[tchar]
                        end
                        k.attr = n.attr
                        k.next = n.next
                        n.next = k
                        n.replace = n.replace + 1
                        n = n.next
                    end
                end
            else
                pfont = nil
                if extra then
                    if id == glue and n.subtype == 0 then
                        local g = n.spec
                        if g.width > 0 then
                            g = node.copy(g)
                            n.spec = g
                            local w = g.width
                            g.width = w + 2*extra
                            local f = g.width/w
                            g.stretch = scale(g.stretch,f)
                            g.shrink = scale(g.shrink, f)
                        end
                    elseif id == kern and n.subtype == 0 then
                        if n.width > 0 then
                            n.width = n.width + extra
                        end
                    elseif id == hlist or id == vlist then
                        if n.width > 0 then -- else parindent etc
                            if p then
                                local k = node.copy(kernnode)
                                k.kern = extra
                                k.attr = n.attr
                                k.next = n
                                k.prev = p
                                p.next = k
                                n.prev = k
                            end
                            if n.next then
                                local k = node.copy(kernnode)
                                k.kern = extra
                                k.attr = n.attr
                                k.next = n.next
                                k.prev = n
                                n.prev = k
                                n.next = k
                                p = k
                                n = n.next
                            end
                        end
                    end
                end
            end
            n.prev = p
            p = n
            n = n.next
        end
        return head, p
    end

end

-- vertical space handler

nodes.snapvalues = { }

function nodes.setsnapvalue(n,ht,dp)
    nodes.snapvalues[n] = { ht, dp, ht+dp }
end

do

    nodes.trace_collapse = false

    local kern, glue, penalty, hlist = node.id('kern'), node.id('glue'), node.id('penalty'), node.id('hlist')

    local penalty_node = node.new('penalty')

    local has_attribute = node.has_attribute
    local has_field     = node.has_field

    local trace_list = { }

    local function reset_tracing()
        trace_list = { }
    end
    local function trace_skip(str,sc,so,sp,data)
        trace_list[#trace_list+1] = string.format("%s %8s %8s %8s %8s", str:padd(8), data.spec.width, sc or "-", so or "-", sp or "-")
    end
    local function trace_done(str,data)
        if data.id == penalty then
            trace_list[#trace_list+1] = string.format("%s %8s penalty", str:padd(8), data.penalty)
        else
            trace_list[#trace_list+1] = string.format("%s %8s glue", str:padd(8), data.spec.width)
        end
    end
    local function show_tracing()
        texio.write_nl(table.concat(trace_list,"\n"))
    end

    -- we assume that these are defined

    local skip_category = attributes.numbers['skip-category']  or 101
    local skip_penalty  = attributes.numbers['skip-penalty']   or 102
    local skip_order    = attributes.numbers['skip-order']     or 103
    local snap_category = attributes.numbers['snap-category']  or 111
    local display_math  = attributes.numbers['display-math']   or 121

    -- alignment box begin_of_par vmode_par hmode_par insert penalty before_display after_display

    function nodes.is_display_math(head)
        n = head.prev
        while n do
            local id = n.id
            if id == penalty then
            elseif id == glue then
                if n.subtype == 6 then
                    return true
                end
            else
                break
            end
            n = n.prev
        end
        n = head.next
        while n do
            local id = n.id
            if id == penalty then
            elseif id == glue then
                if n.subtype == 7 then
                    return true
                end
            else
                break
            end
            n = n.next
        end
        return false
    end

    -- helpers

    function nodes.snapline(current,where)
        local sn = has_attribute(current.list,snap_category)
        if sn then
            local sv = nodes.snapvalues[sn]
            if sv then
                local height, depth, lineheight = sv[1], sv[2], sv[3]
                current.height = math.ceil((current.height-height)/lineheight)*lineheight + height
                current.depth  = math.ceil((current.depth -depth )/lineheight)*lineheight + depth
            end
        end
    end

    -- local free = node.free

    local function collapser(head,where)
        if head and head.next then
            local trace = nodes.trace_collapse
            local current, tail = head, nil
            local glue_order, glue_data = 0, nil
            local penalty_order, penalty_data, natural_penalty = 0, nil, nil
            if trace then reset_tracing() end
            while current do
                local id = current.id
                if id == glue and current.subtype == 0 then -- todo, other subtypes, like math
                    local sc = has_attribute(current,skip_category)
                    local so = has_attribute(current,skip_order   ) or 1
                    local sp = has_attribute(current,skip_penalty )
                    if not sc then
                        if glue_data then
                            if trace then trace_done("before",glue_data) end
                            head, current = nodes.before(head,current,glue_data)
                        end
                        if trace then trace_skip("natural",sc,so,sp,current) end
                        glue_order, glue_data = 0, nil
                        current = current.next
                    elseif sc < 1 or sc > 4 then -- 0 = discard, > 3 = unsupported
                        if trace then trace_skip("ignore",sc,so,sp,current) end
                        head, current = nodes.remove(head, current, true)
                    else
                        if sp then
                            if not penalty_data then
                                penalty_data = sp
                            elseif penalty_order < so then
                                penalty_order, penalty_data = so, sp
                            elseif penalty_order == so and sp > penalty_data then
                                penalty_data = sp
                            end
                        end
                        if not glue_data then
                            if trace then trace_skip("assign",sc,so,sp,current) end
                            glue_order = so
                            head, current, glue_data = nodes.remove(head, current)
                        elseif glue_order < so then
                            if trace then trace_skip("force",sc,so,sp,current) end
                            glue_order = so
                            node.free(glue_data)
                            head, current, glue_data = nodes.remove(head, current)
                        elseif glue_order == so then
                            if sc == 1 then
                                if current.spec.width > glue_data.spec.width then
                                    if trace then trace_skip("larger",sc,so,sp,current) end
                                    node.free(glue_data)
                                    head, current, glue_data = nodes.remove(head, current)
                                else
                                    if trace then trace_skip("smaller",sc,so,sp,current) end
                                    head, current = nodes.remove(head, current, true)
                                end
                            elseif sc == 2 then
                                if trace then trace_skip("force",sc,so,sp,current) end
                                node.free(glue_data)
                                head, current, glue_data = nodes.remove(head, current)
                            elseif sc == 3 then
                                if trace then trace_skip("penalty",sc,so,sp,current) end
                                node.free(glue_data)
                                head, current = nodes.remove(head, current, true)
                            elseif sc == 4 then
                                if trace then trace_skip("add",sc,so,sp,current) end
                                local old, new = glue_data.spec, current.spec
                                old.width   = old.width   + new.width
                                old.stretch = old.stretch + new.stretch
                                old.shrink  = old.shrink  + new.shrink
                                head, current = nodes.remove(head, current, true)
                            else
                                if trace then trace_skip("unknown",sc,so,sp,current) end
                                head, current = nodes.remove(head, current, true)
                            end
                        else
                            if trace then trace_skip("unknown",sc,so,sp,current) end
                            head, current = nodes.remove(head, current, true)
                        end
                    end
            --  elseif id == penalty then
            --      natural_penalty = current.penalty
            --      head, current = nodes.remove(head, current, true)
                elseif id == glue and current.subtype == 2 then
                    local sn = has_attribute(current,snap_category)
                    if sn then
                    --  local sv = nodes.snapvalues[sn]
                    --  if sv then
                           head, current = nodes.remove(head, current, true)
                    --  else
                    --      current = current.next
                    --  end
                    else
                        current = current.next
                    end
                else
                    if glue_data then
                        head, current = nodes.before(head,current,glue_data)
                        if trace then trace_done("before",glue_data) end
                        glue_order, glue_data = 0, nil
                    end
                    if id == hlist and where == 'hmode_par' and current.list then
                        nodes.snapline(current,where) -- will be inline later
                    end
                    current = current.next
                end
                tail = current
            end
        --  if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
        --      penalty_data = natural_penalty
        --  end
            if penalty_data then
                local p = node.copy(penalty_node)
                p.penalty = penalty_data
                if trace then trace_done("before",p) end
                head, head = nodes.before(head,head,p)
            end
            if glue_data then
                if trace then trace_done("after",glue_data) end
                head, tail = nodes.after(head,tail,glue_data)
            end
            if trace then show_tracing() end
        end
        return head
    end

    local head, tail = nil, nil

    function nodes.flush_vertical_spacing()
        if head then
            input.start_timing(nodes)
            local t = collapser(head)
            head = nil
        --  tail = nil
            input.stop_timing(nodes)
            return t
        else
            return nil
        end
    end

    function nodes.handle_page_spacing(t, where)
    --  we need to add the latest t too, else we miss skips and such
        if t and t.next then
            local tt = node.slide(t)
            local id = tt.id
            if id == glue then -- or id == penalty then -- or maybe: if not hlist or vlist
                if head then
                    t.prev = tail
                    tail.next = t
                else
                    head = t
                end
                tail = tt
                t = nil
            else
                input.start_timing(nodes)
                if head then
                    t.prev = tail
                    tail.next = t
                --  tail = tt
                    t = collapser(head,where)
                    head = nil
                --  tail = nil
                else
                    t = collapser(t,where)
                end
                input.stop_timing(nodes,where)
            end
        end
        return t
    end

    function nodes.handle_vbox_spacing(t)
        if t and t.next then
            local tail = node.slide(t)
            return collapser(t,'whole')
        else
            return t
        end
    end

end

-- experimental!

callback.register('vpack_filter',     nodes.handle_vbox_spacing)
callback.register('buildpage_filter', nodes.handle_page_spacing)

-- educational: snapper

--~ function demo_snapper(head,where) -- snap_category 105 / nodes.snapvalue = { [1] = { 8*65536, 4*65536, 12*65536 } }
--~     if head then
--~         local current, tail, dummy = head, nil, nil
--~         while current do
--~             local id = current.id
--~             if id == glue and current.subtype == 2 then
--~                 local sn = has_attribute(current,snap_category)
--~                 if sn then
--~                     local sv = nodes.snapvalues[sn]
--~                     if sv then
--~                         head, current, dummy = node.delete(head, current)
--~                         node.free(dummy)
--~                     else
--~                         current = current.next
--~                     end
--~                 else
--~                     current = current.next
--~                 end
--~             else
--~                 if id == hlist and where == 'hmode_par' and current.list then
--~                     local sn = has_attribute(current.list,snap_category)
--~                     if sn then
--~                         local sv = nodes.snapvalues[sn]
--~                         if sv then
--~                             local height, depth, lineheight = sv[1], sv[2], sv[3]
--~                             current.height = math.ceil((current.height-height)/lineheight)*lineheight + height
--~                             current.depth  = math.ceil((current.depth -depth )/lineheight)*lineheight + depth
--~                         end
--~                     end
--~                 end
--~                 current = current.next
--~             end
--~             tail = current
--~         end
--~     end
--~     return head
--~ end

--~ callback.register('buildpage_filter', demo_snapper)

    --~ function nodes.kern_chars(head)
    --~     local fti = fonts.tfm.id
    --~     local fnt, pchar, pfont, p, n = nil, nil, nil, nil, head
    --~     while n do
    --~         local id = n.id
    --~         if id == glyph then
    --~             if pfont == n.font then
    --~                 local tchar = n.char
    --~                 local pdata = fti[pfont].characters[pchar]
    --~                 local pkern = pdata.kerns
    --~                 if pkern and pkern[tchar] then
    --~                     local k = node.copy(kernnode)
    --~                     k.kern = pkern[tchar]
    --~                     k.attr = n.attr
    --~                     k.next = p.next
    --~                     p.next = k
    --~                 --  texio.write_nl(string.format("KERN = %s %s %s",utf.char(pchar), utf.char(tchar), pkern[tchar]))
    --~                 end
    --~             else
    --~                 pfont, pchar = n.font, n.char
    --~             end
    --~         elseif id == disc then
    --~             if pre then
    --~                 local nn, pp = p.prev, p.next
    --~                 p.prev, p.next = nil, pre -- hijack node
    --~                 pre = nodes.kern_chars(p)
    --~                 pre = pre.next
    --~                 pre.prev = nil
    --~                 p.prev, p.next = nn, pp
    --~                 n.pre = pre
    --~             end
    --~             if post then
    --~                 local tail = node.slide(post)
    --~                 local nn, pp = n.next.prev, n.next.next
    --~                 n.next.next, n.next.prev = nil, tail
    --~                 tail.next = n.next -- hijack node
    --~                 post = nodes.kern_chars(post)
    --~                 tail.next = nil
    --~                 n.next.prev, n.next.next = nn, pp
    --~                 n.post = post
    --~             end
    --~             local tchar = n.next.char
    --~             local pdata = fti[pfont].characters[pchar]
    --~             local pkern = pdata.kerns
    --~             if pkern and pkern[tchar] then
    --~                 local k = node.copy(kernnode)
    --~                 k.kern = pkern[tchar]
    --~                 k.attr = n.attr
    --~                 k.next = n.next
    --~                 n.next = k
    --~                 n.replace = n.replace + 1
    --~                 n = n.next
    --~             end
    --~         else
    --~             pfont = nil
    --~         end
    --~         n.prev = p
    --~         p = n
    --~         n = n.next
    --~     end
    --~     return head, p
    --~ end
