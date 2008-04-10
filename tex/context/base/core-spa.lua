if not modules then modules = { } end modules ['core-spa'] = {
    version   = 1.001,
    comment   = "companion to core-spa.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: test without unset

-- vertical space handler

vspacing = vspacing or { }

vspacing.categories = {
     [0] = 'discard',
     [1] = 'largest',
     [2] = 'force'  ,
     [3] = 'penalty',
     [4] = 'add'    ,
     [5] = 'disable',
     [6] = 'nowhite',
     [7] = 'goback',
}

function vspacing.tocategories(str)
    local t = { }
    for s in str:gmatch("[^, ]") do
        local n = tonumber(s)
        if n then
            t[vspacing.categories[n]] = true
        else
            t[b] = true
        end
    end
    return t
end

function vspacing.tocategory(str)
    if type(str) == "string" then
        return set.tonumber(vspacing.tocategories(str))
    else
        return set.tonumber({ [vspacing.categories[str]] = true })
    end
end

function vspacing.tostring(t)
    local str = nil
    for k,v in pairs(vspacing.categories) do
        if t[v] then
            if str then str = str .. " +" .. v else str = "+" .. v end
        else
            if str then str = str .. " -" .. v else str = "-" .. v end
        end
    end
    return str or ""
end

do

    local map  = { }
    local skip = { }

    vspacing.fixed = false

    function vspacing.analyse(str)
        local category, order, penalty, command, fixed = { }, 0, 0, { }, vspacing.fixed
        local function analyse(str)
            for sign,amount,_,keyword in str:gmatch("([+%-]*)([%.%d]*)([%*]*)([^,%* ]+)") do
                if keyword then
                    if map[keyword] then
                        analyse(map[keyword])
                    elseif keyword == "fixed" then
                        fixed = true
                    elseif keyword == "flexible" then
                        fixed = false
                    else
                        local a, b = keyword:match("(.-):(.-)$")
                        if a and b then
                            if a == "category" then
                                -- is a set
                                local n = tonumber(b)
                                if n then
                                    category[vspacing.categories[n]] = true
                                else
                                    category[b] = true
                                end
                            elseif a == "order" then
                                -- last one counts
                                order = tonumber(b) or 0
                            elseif a == "penalty" then
                                -- last one counts
                                penalty = tonumber(b) or 0
                            elseif a == "skip" then
                                -- last one counts
                                command[#command+1] = { 1, tonumber[b] }
                            end
                        else
                            if amount == ""  then amount = 1 end
                            if sign   == "-" then amount = -amount end
                            if skip[keyword] then
                                command[#command+1] = { amount, skip[keyword][1], skip[keyword][2] }
                            end
                        end
                    end
                end
            end
        end
        analyse(str)
        category = set.tonumber(category)
        local p = print
        p("\\startblankhandling")
        if category > 0 then
            p(("\\setblankcategory{%s}"):format(category))
        end
        if order > 0 then
            p(("\\setblankorder{%s}"):format(order))
        end
        if penalty > 0 then
            p(("\\setblankpenalty{%s}"):format(penalty))
        end
        for k,v in ipairs(command) do
            p(("\\addblankskip{%s}{%s}{%s}"):format(v[1],v[2],v[3]))
        end
        if fixed then
            p("\\fixedblankskip")
        else
            p("\\flexibleblankskip")
        end
        p("\\stopblankhandling")
    end

    function vspacing.setmap(from,to)
        map[from] = to
    end

    function vspacing.setskip(key,value,grid)
        if value ~= "" then
            if grid == "" then grid = value end
            skip[key] = { value, grid }
        end
    end

end

-- implementation

nodes.snapvalues = { }

function nodes.setsnapvalue(n,ht,dp)
    nodes.snapvalues[n] = { ht, dp, ht+dp }
end

do

    nodes.trace_collapse = false

    local kern, glue, penalty, hlist = node.id('kern'), node.id('glue'), node.id('penalty'), node.id('hlist')

    local has_attribute = node.has_attribute
    local has_field     = node.has_field

    local trace_list = { }

    local function reset_tracing()
        trace_list = { }
    end
    local function trace_skip(str,sc,so,sp,data)
        trace_list[#trace_list+1] = string.format("%s %10s %10s %10s %10s", str:padd(8), (data.spec and data.spec.width) or "?", sc or "-", so or "-", sp or "-")
    end
    local function trace_info(...)
        trace_list[#trace_list+1] = table.concat({...}," ")
    end
    local function trace_done(str,data)
        if data.id == penalty then
            trace_list[#trace_list+1] = string.format("%s %10s penalty", str:padd(8), data.penalty)
        else
            trace_list[#trace_list+1] = string.format("%s %10s glue", str:padd(8), (data.spec and data.spec.width) or "?")
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

    local user_skip                =  0
    local line_skip                =  1
    local baseline_skip            =  2
    local par_skip                 =  3
    local above_display_skip       =  4
    local below_display_skip       =  5
    local above_display_short_skip =  6
    local below_display_short_skip =  7
    local left_skip_code           =  8
    local right_skip_code          =  9
    local top_skip_code            = 10
    local split_top_skip_code      = 11
    local tab_skip_code            = 12
    local space_skip_code          = 13
    local xspace_skip_code         = 14
    local par_fill_skip_code       = 15
    local thin_mu_skip_code        = 16
    local med_mu_skip_code         = 17
    local thick_mu_skip_code       = 18

    local skips = {
       [ 0] = "user_skip",
       [ 1] = "line_skip",
       [ 2] = "baseline_skip",
       [ 3] = "par_skip",
       [ 4] = "above_display_skip",
       [ 5] = "below_display_skip",
       [ 6] = "above_display_short_skip",
       [ 7] = "below_display_short_skip",
       [ 8] = "left_skip_code",
       [ 9] = "right_skip_code",
       [10] = "top_skip_code",
       [11] = "split_top_skip_code",
       [12] = "tab_skip_code",
       [13] = "space_skip_code",
       [14] = "xspace_skip_code",
       [15] = "par_fill_skip_code",
       [16] = "thin_mu_skip_code",
       [17] = "med_mu_skip_code",
       [18] = "thick_mu_skip_code",
    }

    function nodes.is_display_math(head)
        local n = head.prev
        while n do
            local id = n.id
            if id == penalty then
            elseif id == glue then
                if n.subtype == 6 then -- above_display_short_skip
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
                if n.subtype == 7 then -- below_display_short_skip
                    return true
                end
            else
                break
            end
            n = n.next
        end
        return false
    end

    local function collapser(head,where)
        if head and head.next then
node.slide(head) -- hm, why
            input.starttiming(nodes)
            local trace = nodes.trace_collapse
            local current, tail = head, nil
            local glue_order, glue_data = 0, nil
            local penalty_order, penalty_data, natural_penalty = 0, nil, nil
            if trace then reset_tracing() end
            local parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
            if trace then trace_info("start analyzing") end
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
                    else
                        local sct = set.totable(sc)
                        if trace then trace_info("catset",vspacing.tostring(sct)) end
                        if sct.disable then
                            ignore_following = true
                        end
                        if sct.nowhite then
                            ignore_whitespace = true
                        end
                        if sct.discard then
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
                            if ignore_following then
                                if trace then trace_skip("disabled",sc,so,sp,current) end
                                head, current = nodes.remove(head, current, true)
                            elseif not glue_data then
                                if trace then trace_skip("assign",sc,so,sp,current) end
                                glue_order = so
                                head, current, glue_data = nodes.remove(head, current)
                            elseif glue_order < so then
                                if trace then trace_skip("force",sc,so,sp,current) end
                                glue_order = so
                                node.free(glue_data)
                                head, current, glue_data = nodes.remove(head, current)
                            elseif glue_order == so then
                                if sct.largest then
                                    if current.spec.width > glue_data.spec.width then
                                        if trace then trace_skip("larger",sc,so,sp,current) end
                                        node.free(glue_data)
                                        head, current, glue_data = nodes.remove(head, current)
                                    else
                                        if trace then trace_skip("smaller",sc,so,sp,current) end
                                        head, current = nodes.remove(head, current, true)
                                    end
                                elseif sct.goback then
                                    if trace then trace_skip("force",sc,so,sp,current) end
                                    node.free(glue_data)
                                    head, current, glue_data = nodes.remove(head, current)
                                elseif sct.force then
                                    -- todo: inject kern
                                    if trace then trace_skip("force",sc,so,sp,current) end
                                    node.free(glue_data)
                                    head, current, glue_data = nodes.remove(head, current)
                                elseif sct.penalty then
                                    if trace then trace_skip("penalty",sc,so,sp,current) end
                                    node.free(glue_data)
                                    head, current = nodes.remove(head, current, true)
                                elseif sct.add then
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
                    end
            --  elseif id == penalty then
            --      natural_penalty = current.penalty
            --      head, current = nodes.remove(head, current, true)
                elseif id == glue and current.subtype == 2 then
                    -- baselineskip
                    local sn = has_attribute(current,snap_category)
                    if sn then
                    --  local sv = nodes.snapvalues[sn]
                    --  if sv then
                           head, current = nodes.remove(head, current, true)
                    --  else
                    --      current = current.next
                    --  end
                    elseif ignore_whitespace then
                        head, current = nodes.remove(head, current, true)
                    else
                        current = current.next
                    end
                elseif id == glue and current.subtype == 3 then
                    parskip = current
                    current = current.next
                else
                    if trace then trace_info(node.type(current)) end
                    if glue_data then
                        head, current = nodes.before(head,current,glue_data)
                        if trace then trace_done("before",glue_data) end
                        glue_order, glue_data = 0, nil
                    end
                    if id == hlist and where == 'hmode_par' then
                        local list = current.list
                        if list then
                            local sn = has_attribute(list,snap_category)
                            if sn then
                                local sv = nodes.snapvalues[sn]
                                if sv then
                                    local height, depth, lineheight = sv[1], sv[2], sv[3]
                                    current.height = math.ceil((current.height-height)/lineheight)*lineheight + height
                                    current.depth  = math.ceil((current.depth -depth )/lineheight)*lineheight + depth
                                end
                            end
                        end
                    end
                    current = current.next
                end
                tail = current -- WRONG ! ! ! !
            end
            if trace then trace_info("stop analyzing") end
        --  if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
        --      penalty_data = natural_penalty
        --  end
            if trace then trace_info("start flushing") end
            if parskip and glue_data then
                local ps, gs = parskip.spec, glue_data.spec
                if ps and gs and ps.width > gs.width then
                    gs.width = ps.width
                    head, current = nodes.remove(head, parskip, true)
                end
            end
            if glue_data then
                if trace then trace_done("first",glue_data) end
                head, tail = nodes.after(head,tail,glue_data)
            end
            if penalty_data then
                local p = nodes.penalty(penalty_data)
                if trace then trace_done("second",p) end
                head, head = nodes.before(head,head,p)
            end
            if trace then trace_info("stop flushing") end
            if trace then show_tracing() end
            input.stoptiming(nodes)
        end
        return head, true
    end

    local head, tail = nil, nil

    function nodes.flush_vertical_spacing()
        if head and head.next then
            local t = collapser(head)
            head = nil
        --  tail = nil
            return t
        else
            return head
        end
    end

    function nodes.handle_page_spacing(t, where)
    --  we need to add the latest t too, else we miss skips and such
        if t then
-- node.slide(t) -- redunant
            if t.next then
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
                end
            elseif head then
                t.prev = tail
                tail.next = t
                t = collapser(head,where)
                head = nil
            else
                t = collapser(t,where)
            end
        end
        return t
    end

    function nodes.handle_vbox_spacing(t)
        if t and t.next then
node.slide(t)
            return collapser(t,'whole')
        else
            return t
        end
    end

end

-- experimental callback definitions will be moved elsewhere

-- not yet ... we need to get rid of lastskip stuff first
--
-- callback.register('vpack_filter',     nodes.handle_vbox_spacing)
-- callback.register('buildpage_filter', nodes.handle_page_spacing)

-- horizontal stuff

-- probably a has_glyphs is rather fast too

do

    local has_attribute   = node.has_attribute
    local unset_attribute = node.unset_attribute
    local set_attribute   = node.set_attribute

--~     local function unset_attribute(n,attribute)
--~         set_attribute(n,attribute,0)
--~     end

    local glyph = node.id("glyph")
    local kern  = node.id("kern")
    local disc  = node.id('disc')
    local glue  = node.id('glue')
    local hlist = node.id('hlist')
    local vlist = node.id('vlist')

    spacings         = spacings         or { }
    spacings.mapping = spacings.mapping or { }
    spacings.enabled = false

    input.storage.register(false,"spacings/mapping", spacings.mapping, "spacings.mapping")

    function spacings.setspacing(id,char,left,right)
        local mapping = spacings.mapping[id]
        if not mapping then
            mapping = { }
            spacings.mapping[id] = mapping
        end
        local map = mapping[char]
        if not map then
            map = { }
            mapping[char] = map
        end
        map.left, map.right = left, right
    end

    -- todo: no ligatures

    function spacings.process(namespace,attribute,head)
        local done, mapping, fontids = false, spacings.mapping, fonts.tfm.id
        for start in node.traverse_id(glyph,head) do -- tricky since we inject
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                local map = mapping[attr]
                if map then
                    map = map[start.char]
                    unset_attribute(start,attribute)
                    if map then
                        local kern, prev = map.left, start.prev
                        if kern and kern ~= 0 and prev and prev.id == glyph then
                            node.insert_before(head,start,nodes.kern(tex.scale(fontids[start.font].parameters[6],kern)))
                        --  node.insert_before(head,start,nodes.kern(fontids[start.font].parameters[6]*kern))
                            done = true
                        end
                        local kern, next = map.right, start.next
                        if kern and kern ~= 0 and next and next.id == glyph then
                            node.insert_after(head,start,nodes.kern(tex.scale(fontids[start.font].parameters[6],kern)))
                        --  node.insert_after(head,start,nodes.kern(fontids[start.font].parameters[6]*kern))
                            done = true
                        end
                    end
                end
            end
        end
        return head, done
    end

    lists.plugins.spacing = {
        namespace   = spacings,
        processor   = spacings.process,
    }

    kerns         = kerns or { }
    kerns.mapping = kerns.mapping or { }
    kerns.enabled = false

    input.storage.register(false, "kerns/mapping", kerns.mapping, "kerns.mapping")

    function kerns.setspacing(id,factor)
        kerns.mapping[id] = factor
    end

-- local marks = fti[font].shared.otfdata.luatex.marks
-- if not marks[tchar] then

    function kerns.process(namespace,attribute,head) -- todo interchar kerns / disc nodes / can be made faster
        local fti, scale = fonts.tfm.id, tex.scale
        local start, done, mapping, fontids, lastfont = head, false, kerns.mapping, fonts.tfm.id, nil
        while start do
            -- faster to test for attr first
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                unset_attribute(start,attribute)
                local krn = mapping[attr]
                if krn and krn ~= 0 then
                    local id = start.id
                    if id == glyph then
                        lastfont = start.font
                        local c = start.components
                        if c then
                            local s = start
                            local tail = node.slide(c)
                            if s.prev then
                                s.prev.next = c
                                c.prev = s.prev
                            else
                                head = c
                            end
                            if s.next then
                                s.next.prev = tail
                            end
                            tail.next = s.next
                            start = c
                            start.attr = s.attr
                            s.attr = nil
                            s.components = nil
                            node.free(s)
                            done = true
                        end
                        local prev = start.prev
                        if prev then
                            local pid = prev.id
                            if not pid then
                                -- nothing
                            elseif pid == kern and prev.subtype == 0 then
                                prev.subtype = 1
                                prev.kern = prev.kern + scale(fontids[lastfont].parameters[6],krn)
                            --  prev.kern = prev.kern + fontids[lastfont].parameters[6]*krn
                                done = true
                            elseif pid == glyph then
                                -- fontdata access can be done more efficient
                                if prev.font == lastfont then
                                    local prevchar, lastchar = prev.char, start.char
                                    local tfm = fti[lastfont].characters[prevchar]
                                    local ickern = tfm.kerns
                                    if ickern and ickern[lastchar] then
                                        krn = scale(ickern[lastchar]+fontids[lastfont].parameters[6],krn)
                                    --  krn = krn*(ickern[lastchar]+fontids[lastfont].parameters[6])
                                    else
                                        krn = scale(fontids[lastfont].parameters[6],krn)
                                    --  krn = krn*fontids[lastfont].parameters[6]
                                    end
                                else
                                    krn = scale(fontids[lastfont].parameters[6],krn)
                                --  krn = krn*fontids[lastfont].parameters[6]
                                end
                                node.insert_before(head,start,nodes.kern(krn))
                                done = true
                            elseif pid == disc then
                                local disc = start.prev -- disc
                                local pre, post, replace = disc.pre, disc.post, disc.replace
                                if pre then -- must pair with start.prev
                                    local before = node.copy(disc.prev)
                                    pre.prev = before
                                    before.next = pre
                                    before.prev = nil
                                    pre = kerns.process(namespace,attribute,before)
                                    pre = pre.next
                                    pre.prev = nil
                                    disc.pre = pre
                                    node.free(before)
                                end
                                if post then  -- must pair with start
                                    local after = node.copy(disc.next)
                                    local tail = node.slide(post)
                                    tail.next = after
                                    after.prev = tail
                                    after.next = nil
                                    post = kerns.process(namespace,attribute,post)
                                    tail.next = nil
                                    disc.post = post
                                    node.free(after)
                                end
                                if replace then -- must pair with start and start.prev
                                    local before = node.copy(disc.prev)
                                    local after = node.copy(disc.next)
                                    local tail = node.slide(post)
                                    replace.prev = before
                                    before.next = replace
                                    before.prev = nil
                                    tail.next = after
                                    after.prev = tail
                                    after.next = nil
                                    replace = kerns.process(namespace,attribute,before)
                                    replace = replace.next
                                    replace.prev = nil
                                    tail.next = nil
                                    disc.replace = replace
                                    node.free(after)
                                    node.free(before)
                                end
                            end
                        end
                    elseif id == glue and start.subtype == 0 then
                        local s = start.spec
                        local w = s.width
                        if w > 0 then
                            local width, stretch, shrink = w+2*scale(w,krn), s.stretch, s.shrink
                            start.spec = nodes.glue_spec(width,scale(stretch,width/w),scale(shrink,width/w))
                        --  local width, stretch, shrink = w+2*w*krn, s.stretch, s.shrink
                        --  start.spec = nodes.glue_spec(width,stretch*width/w,shrink*width/w))
                            done = true
                        end
                    elseif false and id == kern and start.subtype == 0 then -- handle with glyphs
                        local sk = start.kern
                        if sk > 0 then
                        --  start.kern = scale(sk,krn)
                            start.kern = sk*krn
                            done = true
                        end
                    elseif lastfont and (id == hlist or id == vlist) then -- todo: lookahead
                        if start.prev then
                            node.insert_before(head,start,nodes.kern(scale(fontids[lastfont].parameters[6],krn)))
                        --  node.insert_before(head,start,nodes.kern(fontids[lastfont].parameters[6]*krn))
                            done = true
                        end
                        if start.next then
                            node.insert_after(head,start,nodes.kern(scale(fontids[lastfont].parameters[6],krn)))
                        --  node.insert_after(head,start,nodes.kern(fontids[lastfont].parameters[6]*krn))
                            done = true
                        end
                    end
                end
            end
            if start then
                start = start.next
            end
        end
        return head, done
    end

    lists.plugins.kern = {
        namespace = kerns,
        processor = kerns.process,
    }

    -- spacing == attributename !! does not belong here but we will
    -- relocate node and attribute stuff once it's more complete !!

    cases         = cases or { }
    cases.enabled = false
    cases.actions = { }

    -- hm needs to be run before glyphs: chars.plugins

    local function upper(start)
        local data, char = characters.data, start.char
        if data[char] then
            local uc = data[char].uccode
            if uc and fonts.tfm.id[start.font].characters[uc] then
                start.char = uc
                return start, true
            end
        end
        return start, false
    end
    local function lower(start)
        local data, char = characters.data, start.char
        if data[char] then
            local lc = data[char].lccode
            if lc and fonts.tfm.id[start.font].characters[lc] then
                start.char = lc
                return start, true
            end
        end
        return start, false
    end

    cases.actions[1], cases.actions[2] = upper, lower

    cases.actions[3] = function(start)
        local prev = start.prev
        if prev and prev.id == kern and prev.subtype == 0 then
            prev = prev.prev
        end
        if not prev or prev.id ~= glyph then
            return upper(start)
        else
            return start, false
        end
    end

    cases.actions[4] = function(start)
        local prev, next = start.prev, start.next
        if prev and prev.id == kern and prev.subtype == 0 then
            prev = prev.prev
        end
        if next and next.id == kern and next.subtype == 0 then
            next = next.next
        end
        if (not prev or prev.id ~= glyph) and next and next.id == glyph then
            return upper(start)
        else
            return start, false
        end
    end

    cases.actions[5] = function(start)
        local data = characters.data
        local ch = start.char
        local mr = math.random
        local tfm = fonts.tfm.id[start.font].characters
        if data[ch].lccode then
            while true do
                local d = data[mr(1,0xFFFF)]
                if d then
                    local uc = d.uccode
                    if uc and tfm[uc] then
                        start.char = uc
                        return start, true
                    end
                end
            end
        elseif data[ch].uccode then
            while true do
                local d = data[mr(1,0xFFFF)]
                if d then
                    local lc = d.lccode
                    if lc and tfm[lc] then
                        start.char = lc
                        return start, true
                    end
                end
            end
        else
            return start, false
        end
    end

    -- node.traverse_id_attr

    function cases.process(namespace,attribute,head) -- not real fast but also not used on much data
        local done, actions = false, cases.actions
        for start in node.traverse_id(glyph,head) do
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                unset_attribute(start,attribute)
                local action = actions[attr]
                if action then
                    local _, ok = action(start)
                    done = done and ok
                end
            end
        end
        return head, done
    end

    chars.plugins.case = {
        namespace = cases,
        processor = cases.process,
    }

    breakpoints         = breakpoints         or { }
    breakpoints.mapping = breakpoints.mapping or { }
    breakpoints.methods = breakpoints.methods or { }
    breakpoints.enabled = false

    input.storage.register(false,"breakpoints/mapping", breakpoints.mapping, "breakpoints.mapping")

    function breakpoints.setreplacement(id,char,kind,before,after)
        local mapping = breakpoints.mapping[id]
        if not mapping then
            mapping = { }
            breakpoints.mapping[id] = mapping
        end
        mapping[char] = { kind or 1, before or 1, after or 1 }
    end

    breakpoints.methods[1] = function(head,start)
        --  no discretionary needed
        --  \def\prewordbreak  {\penalty\plustenthousand\hskip\zeropoint\relax}
        --  \def\postwordbreak {\penalty\zerocount\hskip\zeropoint\relax}
        --  texio.write_nl(string.format("injecting replacement type %s for character %s",map[1],utf.char(start.char)))
        if start.prev and start.next then
            node.insert_before(head,start,nodes.penalty(10000))
            node.insert_before(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.penalty(0))
        end
        return head, start
    end
    breakpoints.methods[2] = function(head,start) -- ( => (-
        if start.prev and start.next then
            local tmp = start
            start = nodes.disc()
            start.prev, start.next = tmp.prev, tmp.next
            tmp.prev.next, tmp.next.prev = start, start
            tmp.prev, tmp.next = nil, nil
            start.replace = tmp
            local tmp, hyphen = node.copy(tmp), node.copy(tmp)
            hyphen.char = languages.prehyphenchar(tmp.lang)
            tmp.next, hyphen.prev = hyphen, tmp
	        start.post = tmp
            node.insert_before(head,start,nodes.penalty(10000))
            node.insert_before(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.penalty(10000))
        end
        return head, start
    end
    breakpoints.methods[3] = function(head,start) -- ) => -)
        if start.prev and start.next then
            local tmp = start
            start = nodes.disc()
            start.prev, start.next = tmp.prev, tmp.next
            tmp.prev.next, tmp.next.prev = start, start
            tmp.prev, tmp.next = nil, nil
            start.replace = tmp
            local tmp, hyphen = node.copy(tmp), node.copy(tmp)
            hyphen.char = languages.prehyphenchar(tmp.lang)
            tmp.prev, hyphen.next = hyphen, tmp
	        start.pre = hyphen
            node.insert_before(head,start,nodes.penalty(10000))
            node.insert_before(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.glue(0))
            node.insert_after(head,start,nodes.penalty(10000))
        end
        return head, start
    end

    function breakpoints.process(namespace,attribute,head)
        local done, mapping, fontids = false, breakpoints.mapping, fonts.tfm.id
        local start, n = head, 0
        while start do
            local id = start.id
            if id == glyph then
                local attr = has_attribute(start,attribute)
                if attr and attr > 0 then
                    unset_attribute(start,attribute) -- maybe test for subtype > 256 (faster)
                    -- look ahead and back n chars
                    local map = mapping[attr]
                    if map then
                        local smap = map[start.char]
                        if smap then
                            if n >= smap[2] then
                                local m = smap[3]
                                local next = start.next
                                while next do -- gamble on same attribute
                                    local id = next.id
                                    if id == glyph then -- gamble on same attribute
                                        if map[next.char] then
                                            break
                                        elseif m == 1 then
                                            local method = breakpoints.methods[smap[1]]
                                            if method then
                                                head, start = method(head,start)
                                                done = true
                                            end
                                            break
                                        else
                                            m = m - 1
                                            next = next.next
                                        end
                                    elseif id == kern and next.subtype == 0 then
                                        next = next.next
                                        -- ignore intercharacter kerning, will go way
                                    else
                                        -- we can do clever and set n and jump ahead but ... not now
                                        break
                                    end
                                end
                            end
                            n = 0
                        else
                            n = n + 1
                        end
                    else
                         n = 0
                    end
                end
            elseif id == kern and start.subtype == 0 then
                -- ignore intercharacter kerning, will go way
            else
                n = 0
            end
            start = start.next
        end
        return head, done
    end

    chars.plugins.breakpoint = {
        namespace   = breakpoints,
        processor   = breakpoints.process,
    }

end

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
