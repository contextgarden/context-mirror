if not modules then modules = { } end modules ['core-spa'] = {
    version   = 1.001,
    comment   = "companion to core-spa.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: test without unset

local format = string.format

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

vspacing.data      = vspacing.data      or { }
vspacing.data.map  = vspacing.data.map  or { }
vspacing.data.skip = vspacing.data.skip or { }

input.storage.register(false, "vspacing/data/map", vspacing.data.map, "vspacing.data.map")
input.storage.register(false, "vspacing/data/skip", vspacing.data.skip, "vspacing.data.skip")

do

    local map  = vspacing.data.map
    local skip = vspacing.data.skip

    vspacing.fixed = false
    vspacing.trace = false

    local multiplier = lpeg.C(lpeg.S("+-")^0 * lpeg.R("09")^1) * lpeg.P("*")
    local category   = lpeg.P(":") * lpeg.C(lpeg.P(1)^1)
    local keyword    = lpeg.C((1-category)^1)

    local splitter   = (multiplier + lpeg.Cc(1)) * keyword * (category + lpeg.Cc(false))

    function vspacing.analyse(str)
        local category, order, penalty, command, fixed = { }, 0, 0, { }, vspacing.fixed
        local function analyse(str)
            for s in str:gmatch("([^ ,]+)") do
                local amount, keyword, detail = splitter:match(s)
                if keyword then
                    local mk = map[keyword]
                    if mk then
                        analyse(mk)
                    elseif keyword == "fixed" then
                        fixed = true
                    elseif keyword == "flexible" then
                        fixed = false
                    elseif keyword == "category" then
                        -- is a set
                        local n = tonumber(detail)
                        if n then
                            category[vspacing.categories[n]] = true
                        else
                            category[detail] = true
                        end
                    elseif keyword == "order" then
                        -- last one counts
                        order = tonumber(detail) or 0
                    elseif keyword == "penalty" then
                        -- last one counts
                        penalty = tonumber(detail) or 0
                    elseif keyword == "skip" then
                        -- last one counts
                        command[#command+1] = { 1, tonumber(detail or 1) or 1}
                    else
                        amount = tonumber(amount) or 1
                        local sk = skip[keyword]
                        if sk then
                            command[#command+1] = { amount, sk[1], sk[2] or sk[1]}
                        else -- no check
                            command[#command+1] = { amount, keyword, keyword, keyword}
                        end
                    end
                else
                    logs.report("vspacing","unknown directive: %s",str)
                end
            end
        end
        analyse(str)
        category = set.tonumber(category)
        local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
        if vspacing.trace then
            -- quick and dirty
            texsprint = function(c,s)
                logs.report("vspacing",s)
                tex.sprint(c,s)
            end
        end
        texsprint(ctxcatcodes,"\\startblankhandling")
        if category > 0 then
            texsprint(ctxcatcodes,("\\setblankcategory{%s}"):format(category))
        end
        if order > 0 then
            texsprint(ctxcatcodes,("\\setblankorder{%s}"):format(order))
        end
        if penalty > 0 then
            texsprint(ctxcatcodes,("\\setblankpenalty{%s}"):format(penalty))
        end
        for i=1,#command do
            local c = command[i]
            texsprint(ctxcatcodes,("\\addblankskip{%s}{%s}{%s}"):format(c[1],c[2],c[3] or c[2]))
        end
        if fixed then
            texsprint(ctxcatcodes,"\\fixedblankskip")
        else
            texsprint(ctxcatcodes,"\\flexibleblankskip")
        end
        texsprint(ctxcatcodes,"\\stopblankhandling")
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

    nodes.trace_vbox_spacing = false
    nodes.trace_page_spacing = false

    local kern, glue, penalty, hlist = node.id('kern'), node.id('glue'), node.id('penalty'), node.id('hlist')

    local has_attribute   = node.has_attribute
    local unset_attribute = node.unset_attribute
    local set_attribute   = node.set_attribute
    local has_field       = node.has_field

    local trace_list, tracing_info, before, after = { }, false, "", ""

    local function glue_to_string(glue)
        local spec = glue.spec
        if spec then
            local t = { }
            t[#t+1] = aux.strip_zeros(number.topoints(spec.width))
            if spec.stretch_order and spec.stretch_order ~= 0 then
                t[#t+1] = format("plus -%sfi%s",spec.stretch/65536,string.rep("l",math.abs(spec.stretch_order)-1))
            elseif spec.stretch and spec.stretch ~= 0 then
                t[#t+1] = format("plus %s",aux.strip_zeros(number.topoints(spec.stretch)))
            end
            if spec.shrink_order and spec.shrink_order ~= 0 then
                t[#t+1] = format("minus -%sfi%s",spec.shrink/65536,string.rep("l",math.abs(spec.shrink_order)-1))
            elseif spec.shrink and spec.shrink ~= 0 then
                t[#t+1] = format("minus %s",aux.strip_zeros(number.topoints(spec.shrink)))
            end
            return table.concat(t," ")
        else
            return "[0pt]"
        end
    end
    local function nodes_to_string(head)
        local current, t = head, { }
        while current do
            local id = current.id
            local ty = node.type(id)
            if id == penalty then
                t[#t+1] = format("%s:%s",ty,current.penalty)
            elseif id == glue then
                if current.spec then
                    t[#t+1] = format("%s:%s",ty,aux.strip_zeros(number.topoints(current.spec.width)))
                else
                    t[#t+1] = format("%s:[0pt]",ty)
                end
            elseif id == kern then
                t[#t+1] = format("%s:%s",ty,aux.strip_zeros(number.topoints(current.kern)))
            else
                t[#t+1] = ty
            end
            current = current.next
        end
        return table.concat(t," + ")
    end
    local function reset_tracing(head)
        trace_list, tracing_info, before, after = { }, false, nodes_to_string(head), ""
    end
    local function trace_skip(str,sc,so,sp,data)
        trace_list[#trace_list+1] = { "skip", ("%s | %s | category %s | order %s | penalty %s"):format(str, glue_to_string(data), sc or "-", so or "-", sp or "-") }
        tracing_info = true
    end
    local function trace_natural(str,data)
        trace_list[#trace_list+1] = { "skip", ("%s | %s"):format(str, glue_to_string(data)) }
        tracing_info = true
    end
    local function trace_info(message, where, what)
        trace_list[#trace_list+1] = { "info", format("%s: %s/%s",message,where,what) }
    end
    local function trace_node(what)
        local nt = node.type(what.id)
        local tl = trace_list[#trace_list]
        if tl[1] == "node" then
            trace_list[#trace_list] = { "node", tl[2] .. " + " .. nt }
        else
            trace_list[#trace_list+1] = { "node", nt }
        end
    end
    local function trace_done(str,data)
        if data.id == penalty then
            trace_list[#trace_list+1] = { "penalty", ("%s | %s"):format(str, data.penalty) }
        else
            trace_list[#trace_list+1] = { "glue", ("%s | %s"):format(str, glue_to_string(data)) }
        end
        tracing_info = true
    end
    local function show_tracing(head)
        if tracing_info then
            after = nodes_to_string(head)
            for i=1,#trace_list do
                local tag, text = unpack(trace_list[i])
                if tag == "info" then
                    logs.report("collapse",text)
                else
                    logs.report("collapse","  %s: %s",tag,text)
                end
            end
            logs.report("collapse","before: %s",before)
            logs.report("collapse","after : %s",after)
        end
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

    local function collapser(head,where,what,trace,preceding)
        if head then
            input.starttiming(nodes)
            if trace then reset_tracing(head) end
            if trace then trace_info("start analyzing",where,what) end
            node.slide(head) -- hm, why
            local current, tail = head, nil
            local glue_order, glue_data = 0, nil
            local penalty_order, penalty_data, natural_penalty = 0, nil, nil
            local parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
            while current do
                local id = current.id
                if id == glue and current.subtype == 0 then -- todo, other subtypes, like math
                    local sc = has_attribute(current,skip_category)
                    local so = has_attribute(current,skip_order)
                    local sp = has_attribute(current,skip_penalty)
--~ if sc then unset_attribute(current,skip_category) end
--~ if so then unset_attribute(current,skip_order) end
--~ if sp then unset_attribute(current,skip_penalty) end
                    so = so or 1
                    if not sc then
                        if glue_data then
                            if trace then trace_done("flush",glue_data) end
                            head, current = nodes.before(head,current,glue_data)
                            if trace then trace_natural("natural",current) end
                        else
                            -- not look back across head
                            local previous = current.prev
                            if previous and previous.id == glue and previous.subtype == 0 then
                                local ps = previous.spec
                                if ps then
                                    local cs = current.spec
                                    if cs and ps.stretch_order == 0 and ps.shrink_order == 0 and cs.stretch_order == 0 and cs.shrink_order == 0 then
                                        local pw, pp, pm = ps.width, ps.stretch, ps.shrink
                                        local cw, cp, cm = cs.width, cs.stretch, cs.shrink
                                        ps.width, ps.stretch, ps.shrink = pw + cw, pp + cp, pm + cm
                                        if trace then trace_natural("removed",current) end
                                        head, current = nodes.remove(head, current, true)
                                        current = previous
                                        if trace then trace_natural("collapsed",current) end
                                    else
                                        if trace then trace_natural("filler",current) end
                                    end
                                else
                                    if trace then trace_natural("natural (no prev spec)",current) end
                                end
                            else
                                if trace then trace_natural("natural (no prev)",current) end
                            end
                        end
                        glue_order, glue_data = 0, nil
                        if current then
                            current = current.next
                        end
                    else
                        local sct = vspacing.categories[sc] -- or 'unknown'
                        if sct == 'disable' then
                            ignore_following = true
                            if trace then trace_skip(sct,sc,so,sp,current) end
                            head, current = nodes.remove(head, current, true)
                        elseif sct == 'nowhite' then
                            ignore_whitespace = true
                            head, current = nodes.remove(head, current, true)
                        elseif sct == 'discard' then
                            if trace then trace_skip(sct,sc,so,sp,current) end
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
                                if trace then trace_skip("assign " .. sct,sc,so,sp,current) end
                                glue_order = so
                                head, current, glue_data = nodes.remove(head, current)
                            elseif glue_order < so then
                                if trace then trace_skip("force",sc,so,sp,current) end
                                glue_order = so
                                node.free(glue_data)
                                head, current, glue_data = nodes.remove(head, current)
                            elseif glue_order == so then
                                if sct == 'largest' then
                                    local cs, gs = current.spec, glue_data.spec
                                    local cw = (cs and cs.width) or 0
                                    local gw = (gs and gs.width) or 0
                                    if cw > gw then
                                        if trace then trace_skip(sct,sc,so,sp,current) end
                                        node.free(glue_data) -- also free spec
                                        head, current, glue_data = nodes.remove(head, current)
                                    else
                                        if trace then trace_skip('remove smallest',sc,so,sp,current) end
                                        head, current = nodes.remove(head, current, true)
                                    end
                                elseif sct == 'goback' then
                                    if trace then trace_skip(sct,sc,so,sp,current) end
                                    node.free(glue_data) -- also free spec
                                    head, current, glue_data = nodes.remove(head, current)
                                elseif sct == 'force' then
                                    -- todo: inject kern
                                    if trace then trace_skip(sct,sc,so,sp,current) end
                                    node.free(glue_data) -- also free spec
                                    head, current, glue_data = nodes.remove(head, current)
                                elseif sct == 'penalty' then
                                    if trace then trace_skip(sct,sc,so,sp,current) end
                                    node.free(glue_data) -- also free spec
                                    head, current = nodes.remove(head, current, true)
                                elseif sct == 'add' then
                                    if trace then trace_skip(sct,sc,so,sp,current) end
                                    local old, new = glue_data.spec, current.spec
                                    old.width   = old.width   + new.width
                                    old.stretch = old.stretch + new.stretch
                                    old.shrink  = old.shrink  + new.shrink
                                    -- toto: order
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
                elseif id == penalty then
--~                     natural_penalty = current.penalty
--~                     if trace then trace_done("removed penalty",current) end
--~                     head, current = nodes.remove(head, current, true)
current = current.next
                elseif id == glue and current.subtype == 2 then
                    local sn = has_attribute(current,snap_category)
                    if sn then
                    --  local sv = nodes.snapvalues[sn]
                    --  if sv then
                            if trace then trace_natural("removed baselineskip",current) end
                            head, current = nodes.remove(head, current, true)
                    --  else
                    --      current = current.next
                    --  end
                    else
                        if trace then trace_natural("keep baselineskip",current) end
                        current = current.next
                    end
                elseif id == glue and current.subtype == 3 then
                    -- parskip always comes later
                    if ignore_whitespace then
                        if trace then trace_natural("ignored parskip",current) end
                        head, current = nodes.remove(head,current,true)
                    elseif glue_data then
                        local ps, gs = current.spec, glue_data.spec
                        if ps and gs and ps.width > gs.width then
                            node.free(glue_data.spec)
                            glue_data.spec = ps
                            if trace then trace_natural("taking parskip",current) end
                        else
                            if trace then trace_natural("removed parskip",current) end
                        end
                        head, current = nodes.remove(head, current,true)
                    else
                        if trace then trace_natural("honored parskip",current) end
                        head, current, glue_data = nodes.remove(head, current)
                    end
--~ if trace then trace_natural("removed parskip",current) end
--~ current.spec = nil
--~ current = current.next
                else
                    if glue_data then
                        if trace then trace_done("flushed",glue_data) end
                        head, current = node.insert_before(head,current,glue_data)
                        glue_order, glue_data = 0, nil
                    end
                    if penalty_data then
                        local p = nodes.penalty(penalty_data)
                        if trace then trace_done("flushed",p) end
                        head, current = node.insert_before(head,current,p)
                        penalty_data = nil
                    end
                    if trace then trace_node(current) end
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
            end
            tail = node.slide(head)
            if trace then trace_info("stop analyzing",where,what) end
--~ if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
--~     penalty_data = natural_penalty
--~ end
            if trace and (glue_data or penalty_data) then trace_info("start flushing",where,what) end
            if penalty_data then
                local p = nodes.penalty(penalty_data)
                if trace then trace_done("result",p) end
                head, tail = node.insert_after(head,tail,p)
            end
            if glue_data then
                if trace then trace_done("result",glue_data) end
                head, tail = node.insert_after(head,tail,glue_data)
            end
            if trace and (glue_data or penalty_data) then trace_info("stop flushing",where,what) end
            input.stoptiming(nodes)
            if trace then show_tracing(head) end
        end
        return head, true
    end

    -- alignment after_output end box new_graf vmode_par hmode_par insert penalty before_display after_display

    function nodes.handle_page_spacing(where) -- no arguments
    --~ status.best_page_break
    --~ tex.lists.best_page_break
    --~ tex.lists.best_size (natural size to best_page_break)
    --~ tex.lists.least_page_cost ( badness van best_page_break)
    --~ tex.lists.page_head
    --~ tex.lists.contrib_head
        local head, done= collapser(tex.lists.contrib_head,"page",where,nodes.trace_page_spacing,tex.lists.page_head)
        tex.lists.contrib_head = head
    end

    -- split_keep, split_off, vbox

    local not_needed = table.tohash {
        "split_keep",
        "split_off",
    }

    function nodes.handle_vbox_spacing(t,where)
        return (t and not not_needed[where] and t.next and collapser(t,"vbox",where,nodes.trace_vbox_spacing)) or t
    end

end

-- experimental callback definitions will be moved elsewhere
--
-- this will become a chain

function vspacing.enable()
--~     callback.register('vpack_filter', nodes.handle_vbox_spacing)
    callback.register('buildpage_filter', nodes.handle_page_spacing)
end
function vspacing.disable()
    callback.register('vpack_filter', nil)
    callback.register('buildpage_filter', nil)
end

-- horizontal stuff

-- probably a has_glyphs is rather fast too

do

    local has_attribute    = node.has_attribute
    local unset_attribute  = node.unset_attribute
    local set_attribute    = node.set_attribute
    local traverse_id      = node.traverse_id

--~     local function unset_attribute(n,attribute)
--~         set_attribute(n,attribute,0)
--~     end

    local glyph   = node.id("glyph")
    local whatsit = node.id("whatsit")
    local kern    = node.id("kern")
    local disc    = node.id('disc')
    local glue    = node.id('glue')
    local hlist   = node.id('hlist')
    local vlist   = node.id('vlist')

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
        for start in traverse_id(glyph,head) do -- tricky since we inject
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                local map = mapping[attr]
                if map then
                    map = map[start.char]
                    unset_attribute(start,attribute)
                    if map then
                        local kern, prev = map.left, start.prev
                        if kern and kern ~= 0 and prev and prev.id == glyph then
                            node.insert_before(head,start,nodes.kern(tex.scale(fontids[start.font].parameters.quad,kern)))
                            done = true
                        end
                        local kern, next = map.right, start.next
                        if kern and kern ~= 0 and next and next.id == glyph then
                            node.insert_after(head,start,nodes.kern(tex.scale(fontids[start.font].parameters.quad,kern)))
                            done = true
                        end
                    end
                end
            end
        end
        return head, done
    end

    lists.plugins[#lists.plugins+1] = {
        name        = "spacing",
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
                                prev.kern = prev.kern + scale(fontids[lastfont].parameters.quad,krn)
                                done = true
                            elseif pid == glyph then
                                -- fontdata access can be done more efficient
                                if prev.font == lastfont then
                                    local prevchar, lastchar = prev.char, start.char
                                    local tfm = fti[lastfont].characters[prevchar]
                                    local ickern = tfm.kerns
                                    if ickern and ickern[lastchar] then
                                        krn = scale(ickern[lastchar]+fontids[lastfont].parameters.quad,krn)
                                    else
                                        krn = scale(fontids[lastfont].parameters.quad,krn)
                                    end
                                else
                                    krn = scale(fontids[lastfont].parameters.quad,krn)
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
                            node.insert_before(head,start,nodes.kern(scale(fontids[lastfont].parameters.quad,krn)))
                            done = true
                        end
                        if start.next then
                            node.insert_after(head,start,nodes.kern(scale(fontids[lastfont].parameters.quad,krn)))
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

    lists.plugins[#lists.plugins+1] = {
        name = "kern",
        namespace = kerns,
        processor = kerns.process,
    }

    -- spacing == attributename !! does not belong here but we will
    -- relocate node and attribute stuff once it's more complete !!

    -- experimental, we may extend or change this

    --~ Analysis by Idris:
    --~
    --~ 1. Assuming the reading- vs word-order distinction (bidi-char types) is governing;
    --~ 2. Assuming that 'ARAB' represents an actual arabic string in raw input order, not word-order;
    --~ 3. Assuming that 'BARA' represent the correct RL word order;
    --~
    --~ Then we have, with input: LATIN ARAB
    --~
    --~ \textdir TLT LATIN ARAB => LATIN BARA
    --~ \textdir TRT LATIN ARAB => LATIN BARA
    --~ \textdir TRT LRO LATIN ARAB => LATIN ARAB
    --~ \textdir TLT LRO LATIN ARAB => LATIN ARAB
    --~ \textdir TLT RLO LATIN ARAB => NITAL ARAB
    --~ \textdir TRT RLO LATIN ARAB => NITAL ARAB

    --  elseif d == "es"  then -- European Number Separator
    --  elseif d == "et"  then -- European Number Terminator
    --  elseif d == "cs"  then -- Common Number Separator
    --  elseif d == "nsm" then -- Non-Spacing Mark
    --  elseif d == "bn"  then -- Boundary Neutral
    --  elseif d == "b"   then -- Paragraph Separator
    --  elseif d == "s"   then -- Segment Separator
    --  elseif d == "ws"  then -- Whitespace
    --  elseif d == "on"  then -- Other Neutrals

    mirror         = mirror or { }
    mirror.enabled = false
    mirror.trace   = false
    mirror.strip   = false

    local state = attributes.numbers['state'] or 100

    function mirror.process(namespace,attribute,head)
        local done, data, directions, trace = false, characters.data, characters.directions, mirror.trace
        local current, inserted, obsolete = head, nil, { }
        local override, embedded, autodir = 0, 0, 0
        local list, glyphs = trace and { }, false
        local stack, top, finished, finidir, finipos = { }, 0, nil, nil, 1
        local finish = nil
        local lro, rlo, prevattr = false, false, 0
        -- todo: delayed inserts here
        local function finish_auto_before()
            head, inserted = node.insert_before(head,current,nodes.textdir("-"..finish))
            finished, finidir = inserted, finish
            if trace then table.insert(list,#list,format("finish %s",finish)) ; finipos = #list-1 end
            finish, autodir, done = nil, 0, true
        end
        local function finish_auto_after()
            head, current = node.insert_after(head,current,nodes.textdir("-"..finish))
            finished, finidir = current, finish
            if trace then list[#list+1] = format("finish %s",finish) ; finipos = #list end
            finish, autodir, done = nil, 0, true
        end
        local function force_auto_left_before()
            if finish then
                finish_auto_before()
            end
            if embedded >= 0 then
                finish, autodir, done = "TLT", 1, true
            else
                finish, autodir, done = "TRT", -1, true
            end
            if finidir == finish then
                nodes.remove(head,finished,true)
                if trace then list[finipos] = list[finipos].." (deleted)" end
                if trace then table.insert(list,#list,format("start %s (deleted)",finish)) end
            else
                head, inserted = node.insert_before(head,current,nodes.textdir("+"..finish))
                if trace then table.insert(list,#list,format("start %s",finish)) end
            end
        end
        local function force_auto_right_before()
            if finish then
                finish_auto_before()
            end
            if embedded <= 0 then
                finish, autodir, done = "TRT", -1, true
            else
                finish, autodir, done = "TLT", 1, true
            end
            if finidir == finish then
                nodes.remove(head,finished,true)
                if trace then list[finipos] = list[finipos].." (deleted)" end
                if trace then table.insert(list,#list,format("start %s (deleted)",finish)) end
            else
                head, inserted = node.insert_before(head,current,nodes.textdir("+"..finish))
                if trace then table.insert(list,#list,format("start %s",finish)) end
            end
        end
        local function is_right(n)
            if n then
                local id = n.id
                if id == glyph then
                    local attr = has_attribute(n,attribute)
                    if attr and attr > 0 then
                        local d = directions[n.char]
                        if d == "r" or d == "al" then -- override
                            return true
                        end
                    end
                end
            end
            return false
        end
        while current do
            local id = current.id
            local attr = has_attribute(current,attribute)
            if attr and attr > 0 then
                unset_attribute(current,attribute)
                if attr == 1 then
                    -- bidi parsing mode
                elseif attr ~= prevattr then
                    -- no pop, grouped driven (2=normal,3=lro,4=rlo)
                    if attr == 3 then
                        if trace then list[#list+1] = format("override right -> left (lro) (bidi=%s)",attr) end
                        lro, rlo = true, false
                    elseif attr == 4 then
                        if trace then list[#list+1] = format("override left -> right (rlo) (bidi=%s)",attr) end
                        lro, rlo = false, true
                    else
                        if trace and current ~= head then list[#list+1] = format("override reset (bidi=%s)",attr) end
                        lro, rlo = false, false
                    end
                    prevattr = attr
                end
            end
            if id == glyph then
                glyphs = true
                if attr and attr > 0 then
                    local char = current.char
                    local d = directions[char]
                    if rlo or override > 0 then
                        if d == "l" then
                            if trace then list[#list+1] = format("char %s of class %s overidden to r (bidi=%s)",utf.char(char),d,attr) end
                            d = "r"
                        elseif trace then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                            else -- todo: rle lre
                                list[#list+1] = format("char %s of class %s (bidi=%s)",utf.char(char),d,attr)
                            end
                        end
                    elseif lro or override < 0 then
                        if d == "r" or d == "al" then
                            set_attribute(current,state,4) -- maybe better have a special bidi attr value -> override (9) -> todo
                            if trace then list[#list+1] = format("char %s of class %s overidden to l (bidi=%s) (state=isol)",utf.char(char),d,attr) end
                            d = "l"
                        elseif trace then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                            else -- todo: rle lre
                                list[#list+1] = format("char %s of class %s (bidi=%s)",utf.char(char),d,attr)
                            end
                        end
                    elseif trace then
                        if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                            list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                        else -- todo: rle lre
                            list[#list+1] = format("char %s of class %s (bidi=%s)",utf.char(char),d,attr)
                        end
                    end
                    if d == "on" then
                        local mirror = data[char].mirror
                        if mirror and fonts.tfm.id[current.font].characters[mirror] then
                            -- todo: set attribute
                            if autodir < 0 then
                                current.char = mirror
                                done = true
                            --~ elseif left or autodir > 0 then
                            --~     if not is_right(current.prev) then
                            --~         current.char = mirror
                            --~         done = true
                            --~     end
                            end
                        end
                    elseif d == "l" or d == "en" then -- european number
                        if autodir <= 0 then
                            force_auto_left_before()
                        end
                    elseif d == "r" or d == "al" or d == "an" then -- arabic left, arabic number
                        if autodir >= 0 then
                            force_auto_right_before()
                        end
                    elseif d == "lro" then -- Left-to-Right Override -> right becomes left
                        if trace then list[#list+1] = "override right -> left" end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = -1
                        obsolete[#obsolete+1] = current
                    elseif d == "rlo" then -- Right-to-Left Override -> left becomes right
                        if trace then list[#list+1] = "override left -> right" end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "lre" then -- Left-to-Right Embedding -> TLT
                        if trace then list[#list+1] = "embedding left -> right" end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "rle" then -- Right-to-Left Embedding -> TRT
                        if trace then list[#list+1] = "embedding right -> left" end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "pdf" then -- Pop Directional Format
                    --  override = 0
                        if top > 0 then
                            local s = stack[top]
                            override, embedded = s[1], s[2]
                            top = top - 1
                            if trace then list[#list+1] = format("state: override: %s, embedded: %s, autodir: %s",override,embedded,autodir) end
                        else
                            if trace then list[#list+1] = "pop (error, too many pops)" end
                        end
                        obsolete[#obsolete+1] = current
                    end
                else
                    if trace then
                        local char = current.char
                        local d = directions[char]
                        list[#list+1] = format("char %s of class %s (no bidi)",utf.char(char),d)
                    end
                end
            elseif id == whatsit then
                if finish then
                    finish_auto_before()
                end
                local subtype = current.subtype
                if subtype == 6 then
                    local dir = current.dir
                    local d = dir:sub(2,2)
                    if dir:find(".R.") then
                        autodir = -1
                    else
                        autodir = 1
                    end
                    embeddded = autodir
                    if trace then list[#list+1] = format("pardir %s",dir) end
                elseif subtype == 7 then
                    local dir = current.dir
                    local sign = dir:sub(1,1)
                    local dire = dir:sub(3,3)
                    if dire == "R" then
                        if sign == "+" then
                            finish, autodir = "TRT", -1
                        else
                            finish, autodir = nil, 0
                        end
                    else
                        if sign == "+" then
                            finish, autodir = "TLT", 1
                        else
                            finish, autodir = nil, 0
                        end
                    end
                    if trace then list[#list+1] = format("textdir %s",dir) end
                end
            else
                if trace then list[#list+1] = format("node %s",node.type(id)) end
                if finish then
                    finish_auto_before()
                end
            end
            local cn = current.next
            if not cn then
                if finish then
                    finish_auto_after()
                end
            end
            current = cn
        end
        if trace and glyphs then
            logs.report("bidi","start log")
            for i=1,#list do
                logs.report("bidi","%02i: %s",i,list[i])
            end
            logs.report("bidi","stop log")
        end
        if done and mirror.strip then
            local n = #obsolete
            if n > 0 then
                for i=1,n do
                    nodes.remove(head,obsolete[i],true)
                end
                logs.report("bidi","%s character nodes removed",n)
            end
        end
        return head, done
    end

    chars.plugins[#chars.plugins+1] = {
        name = "mirror",
        namespace = mirror,
        processor = mirror.process,
    }

    cases         = cases or { }
    cases.enabled = false
    cases.actions = { }

    -- hm needs to be run before glyphs: chars.plugins

    local function helper(start, code, codes)
        local data, char = characters.data, start.char
        local dc = data[char]
        if dc then
            local fnt = start.font
            local ifc = fonts.tfm.id[fnt].characters
            local ucs = dc[codes]
            if ucs then
                local ok = true
                for i=1,#ucs do
                    ok = ok and ifc[ucs[i]]
                end
                if ok then
                    local prev, original, copy = start, start, node.copy
                    for i=1,#ucs do
                        local chr = ucs[i]
                        prev = start
                        if i == 1 then
                            start.char = chr
                        else
                            local g = copy(original)
                            g.char = chr
                            local next = start.next
                            g.prev = start
                            if next then
                                g.next = next
                                start.next = g
                                next.prev = g
                            end
                            start = g
                        end
                    end
                    return prev, true
                end
                return start, false
            end
            local uc = dc[code]
            if uc and ifc[uc] then
                start.char = uc
                return start, true
            end
        end
        return start, false
    end

    local function upper(start)
        return helper(start,'uccode','uccodes')
    end
    local function lower(start)
        return helper(start,'lccode','lccodes')
    end

    cases.actions[1], cases.actions[2] = upper, lower

    cases.actions[3] = function(start,attribute)
        local prev = start.prev
        if prev and prev.id == kern and prev.subtype == 0 then
            prev = prev.prev
        end
        if not prev or prev.id ~= glyph then
            --- only the first character is treated
            for n in traverse_id(glyph,start.next) do
                if has_attribute(n,attribute) then
                    unset_attribute(n,attribute)
                end
            end
            return upper(start)
        else
            return start, false
        end
    end

    cases.actions[4] = function(start,attribute)
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

    --~     cases.actions[5] = function(start)
    --~         local prev, next = start.prev, start.next
    --~         if prev and prev.id == kern and prev.subtype == 0 then
    --~             prev = prev.prev
    --~         end
    --~         if next and next.id == kern and next.subtype == 0 then
    --~             next = next.next
    --~         end
    --~         if (not prev or prev.id ~= glyph) and next and next.id == glyph then
    --~             return upper(start)
    --~         else
    --~             return start, false
    --~         end
    --~     end

    cases.actions[8] = function(start)
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
        for start in traverse_id(glyph,head) do
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                unset_attribute(start,attribute)
                local action = actions[attr]
                if action then
                    local _, ok = action(start,attribute)
                    done = done and ok
                end
            end
        end
        return head, done
    end

    chars.plugins[#chars.plugins+1] = {
        name = "case",
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

    chars.plugins[#chars.plugins+1] = {
        name = "breakpoint",
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

-- obsolete, callback changed

--~ local head, tail = nil, nil

--~ function nodes.flush_vertical_spacing()
--~     if head and head.next then
--~         local t = collapser(head,'flush')
--~         head = nil
--~     --  tail = nil
--~         return t
--~     else
--~         return head
--~     end
--~ end

--~ function nodes.handle_page_spacing(t, where)
--~     where = where or "page"
--~ --  we need to add the latest t too, else we miss skips and such
--~     if t then
--~     --~ node.slide(t) -- redunant
--~         if t.next then
--~             local tt = node.slide(t)
--~             local id = tt.id
--~             if id == glue then -- or id == penalty then -- or maybe: if not hlist or vlist
--~                 if head then
--~                     t.prev = tail
--~                     tail.next = t
--~                 else
--~                     head = t
--~                 end
--~                 tail = tt
--~                 t = nil
--~             elseif head then
--~                 t.prev = tail
--~                 tail.next = t
--~                 t = collapser(head,"page",where)
--~                 head = nil
--~             else
--~                 t = collapser(t,"page",where)
--~             end
--~         elseif head then
--~             t.prev = tail
--~             tail.next = t
--~             t = collapser(head,"page",where)
--~             head = nil
--~         else
--~             t = collapser(t,"page",where)
--~         end
--~     elseif head then
--~         t = collapser(head,"page",where)
--~         head = nil
--~     end
--~     return t
--~ end
