if not modules then modules = { } end modules ['spac-ver'] = {
    version   = 1.001,
    comment   = "companion to spac-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon

local next, type = next, type
local format, gmatch, concat = string.format, string.gmatch, table.concat
local texsprint, texlists = tex.sprint, tex.lists

local ctxcatcodes = tex.ctxcatcodes
local variables = interfaces.variables

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

-- vertical space handler

local trace_vbox_vspacing    = false  trackers.register("nodes.vbox_vspacing",    function(v) trace_vbox_vspacing    = v end)
local trace_page_vspacing    = false  trackers.register("nodes.page_vspacing",    function(v) trace_page_vspacing    = v end)
local trace_collect_vspacing = false  trackers.register("nodes.collect_vspacing", function(v) trace_collect_vspacing = v end)
local trace_vspacing         = false  trackers.register("nodes.vspacing",         function(v) trace_vspacing         = v end)

local skip_category = attributes.private('skip-category')
local skip_penalty  = attributes.private('skip-penalty')
local skip_order    = attributes.private('skip-order')
local snap_category = attributes.private('snap-category')
local display_math  = attributes.private('display-math')

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local find_node_tail     = node.tail
local free_node          = node.free
local copy_node          = node.copy
local traverse_nodes     = node.traverse
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove
local make_penalty_node  = nodes.penalty
local count_nodes        = nodes.count
local node_ids_to_string = nodes.ids_to_string
local hpack_node         = node.hpack

local glyph   = node.id("glyph")
local penalty = node.id("penalty")
local kern    = node.id("kern")
local glue    = node.id('glue')
local hlist   = node.id('hlist')
local vlist   = node.id('vlist')
local adjust  = node.id('adjust')

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

local categories = vspacing.categories

function vspacing.tocategories(str)
    local t = { }
    for s in gmatch(str,"[^, ]") do
        local n = tonumber(s)
        if n then
            t[categories[n]] = true
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
        return set.tonumber({ [categories[str]] = true })
    end
end

vspacing.data      = vspacing.data      or { }
vspacing.data.map  = vspacing.data.map  or { }
vspacing.data.skip = vspacing.data.skip or { }

storage.register("vspacing/data/map", vspacing.data.map, "vspacing.data.map")
storage.register("vspacing/data/skip", vspacing.data.skip, "vspacing.data.skip")

do -- todo: interface.variables

    local function logger(c,s)
        logs.report("vspacing",s)
        texsprint(c,s)
    end

    vspacing.fixed = false

    local map  = vspacing.data.map
    local skip = vspacing.data.skip

    local multiplier = lpeg.C(lpeg.S("+-")^0 * lpeg.R("09")^1) * lpeg.P("*")
    local category   = lpeg.P(":") * lpeg.C(lpeg.P(1)^1)
    local keyword    = lpeg.C((1-category)^1)
    local splitter   = (multiplier + lpeg.Cc(1)) * keyword * (category + lpeg.Cc(false))

    local k_fixed, k_flexible, k_category, k_penalty, k_order = variables.fixed, variables.flexible, "category", "penalty", "order"

    local function analyse(str,oldcategory,texsprint)
--~ print(table.serialize(map))
--~ print(table.serialize(skip))
        for s in gmatch(str,"([^ ,]+)") do
            local amount, keyword, detail = splitter:match(s)
            if not keyword then
                logs.report("vspacing","unknown directive: %s",s)
            else
                local mk = map[keyword]
                if mk then
                    category = analyse(mk,category,texsprint)
                elseif keyword == k_fixed then
                    texsprint(ctxcatcodes,"\\fixedblankskip")
                elseif keyword == k_flexible then
                    texsprint(ctxcatcodes,"\\flexibleblankskip")
                elseif keyword == k_category then
                    local category = tonumber(detail)
                    if category then
                        texsprint(ctxcatcodes,format("\\setblankcategory{%s}",category))
                        if category ~= oldcategory then
                            texsprint(ctxcatcodes,"\\flushblankhandling")
                            oldcategory = category
                        end
                    end
                elseif keyword == k_order and detail then
                    local order = tonumber(detail)
                    if order then
                        texsprint(ctxcatcodes,format("\\setblankorder{%s}",order))
                    end
                elseif keyword == k_penalty and detail then
                    local penalty = tonumber(detail)
                    if penalty then
                        texsprint(ctxcatcodes,format("\\setblankpenalty{%s}",penalty))
                        texsprint(ctxcatcodes,"\\flushblankhandling")
                    end
                else
                    amount = tonumber(amount) or 1
                    local sk = skip[keyword]
                    if sk then
                        texsprint(ctxcatcodes,format("\\addblankskip{%s}{%s}{%s}",amount,sk[1],sk[2] or sk[1]))
                    else -- no check
                        texsprint(ctxcatcodes,format("\\addblankskip{%s}{%s}{%s}",amount,keyword,keyword))
                    end
                end
            end
        end
        return category
    end

    function vspacing.analyse(str)
        local texsprint = (trace_vspacing and logger) or texsprint
        texsprint(ctxcatcodes,"\\startblankhandling")
        analyse(str,1,texsprint)
        texsprint(ctxcatcodes,"\\stopblankhandling")
    end

    --

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
        return concat(t," ")
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
    return concat(t," + ")
end

local function reset_tracing(head)
    trace_list, tracing_info, before, after = { }, false, nodes_to_string(head), ""
end

local function trace_skip(str,sc,so,sp,data)
    trace_list[#trace_list+1] = { "skip", format("%s | %s | category %s | order %s | penalty %s", str, glue_to_string(data), sc or "-", so or "-", sp or "-") }
    tracing_info = true
end

local function trace_natural(str,data)
    trace_list[#trace_list+1] = { "skip", format("%s | %s", str, glue_to_string(data)) }
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
        trace_list[#trace_list+1] = { "penalty", format("%s | %s", str, data.penalty) }
    else
        trace_list[#trace_list+1] = { "glue", format("%s | %s", str, glue_to_string(data)) }
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

local free_glue_node = free_node
local free_glue_spec = free_node
local discard, largest, force, penalty, add, disable, nowhite, goback = 0, 1, 2, 3, 4, 5, 6, 7

local function collapser(head,where,what,trace) -- maybe also pass tail
    if trace then
        reset_tracing(head)
        trace_info("start analyzing",where,what)
    end
    local current = head
    local glue_order, glue_data = 0, nil
    local penalty_order, penalty_data, natural_penalty = 0, nil, nil
    local parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
    while current do
        local id = current.id -- has each node a subtype ?
        if id == glue and current.subtype == 0 then -- todo, other subtypes, like math
            local sc = has_attribute(current,skip_category)      -- has no default, no unset (yet)
            local so = has_attribute(current,skip_order   ) or 1 -- has  1 default, no unset (yet)
            local sp = has_attribute(current,skip_penalty )      -- has no degault, no unset (yet)
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
                                head, current = remove_node(head, current, true)
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
                if sc == disable then
                    ignore_following = true
                    if trace then trace_skip("disable",sc,so,sp,current) end
                    head, current = remove_node(head, current, true)
                elseif sc == nowhite then
                    ignore_whitespace = true
                    head, current = remove_node(head, current, true)
                elseif sc == discard then
                    if trace then trace_skip("discard",sc,so,sp,current) end
                    head, current = remove_node(head, current, true)
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
                        head, current = remove_node(head, current, true)
                    elseif not glue_data then
                        if trace then trace_skip("assign",sc,so,sp,current) end
                        glue_order = so
                        head, current, glue_data = remove_node(head, current)
                    elseif glue_order < so then
                        if trace then trace_skip("force",sc,so,sp,current) end
                        glue_order = so
                        free_glue_node(glue_data)
                        head, current, glue_data = remove_node(head, current)
                    elseif glue_order == so then
                        -- is now exclusive, maybe support goback as combi, else why a set
                        if sc == largest then
                            local cs, gs = current.spec, glue_data.spec
                            local cw = (cs and cs.width) or 0
                            local gw = (gs and gs.width) or 0
                            if cw > gw then
                                if trace then trace_skip('largest',sc,so,sp,current) end
                                free_glue_node(glue_data) -- also free spec
                                head, current, glue_data = remove_node(head, current)
                            else
                                if trace then trace_skip('remove smallest',sc,so,sp,current) end
                                head, current = remove_node(head, current, true)
                            end
                        elseif sc == goback then
                            if trace then trace_skip('goback',sc,so,sp,current) end
                            free_glue_node(glue_data) -- also free spec
                            head, current, glue_data = remove_node(head, current)
                        elseif sc == force then
                            -- todo: inject kern
                            if trace then trace_skip('force',sc,so,sp,current) end
                            free_glue_node(glue_data) -- also free spec
                            head, current, glue_data = remove_node(head, current)
                        elseif sc == penalty then
                            if trace then trace_skip('penalty',sc,so,sp,current) end
                            free_glue_node(glue_data) -- also free spec
                            glue_data = nil
                            head, current = remove_node(head, current, true)
                        elseif sc == add then
                            if trace then trace_skip('add',sc,so,sp,current) end
                            local old, new = glue_data.spec, current.spec
                            old.width   = old.width   + new.width
                            old.stretch = old.stretch + new.stretch
                            old.shrink  = old.shrink  + new.shrink
                            -- toto: order
                            head, current = remove_node(head, current, true)
                        else
                            if trace then trace_skip("unknown",sc,so,sp,current) end
                            head, current = remove_node(head, current, true)
                        end
                    else
                        if trace then trace_skip("unknown",sc,so,sp,current) end
                        head, current = remove_node(head, current, true)
                    end
                end
            end
        elseif id == penalty then
            --~ natural_penalty = current.penalty
            --~ if trace then trace_done("removed penalty",current) end
            --~ head, current = remove_node(head, current, true)
            current = current.next
        elseif id == glue and current.subtype == 2 then
            local sn = has_attribute(current,snap_category)
            if sn then
            --  local sv = nodes.snapvalues[sn]
            --  if sv then
                    if trace then trace_natural("removed baselineskip",current) end
                    head, current = remove_node(head, current, true)
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
                head, current = remove_node(head,current,true)
            elseif glue_data then
                local ps, gs = current.spec, glue_data.spec
                if ps and gs and ps.width > gs.width then
                --  free_glue_spec(glue_data.spec) -- result in double free
                    glue_data.spec = copy_node(ps)
                    if trace then trace_natural("taking parskip",current) end
                else
                    if trace then trace_natural("removed parskip",current) end
                end
                head, current = remove_node(head, current,true)
            else
                if trace then trace_natural("honored parskip",current) end
                head, current, glue_data = remove_node(head, current)
            end
        --~ if trace then trace_natural("removed parskip",current) end
        --~ current.spec = nil
        --~ current = current.next
        else
-- reversed
            if penalty_data then
                local p = make_penalty_node(penalty_data)
                if trace then trace_done("flushed",p) end
                head, current = insert_node_before(head,current,p)
            --  penalty_data = nil
            end
            if glue_data then
                if trace then trace_done("flushed",glue_data) end
                head, current = insert_node_before(head,current,glue_data)
            --  glue_order, glue_data = 0, nil
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
                            -- is math.ceil really needed?
                            current.height = math.ceil((current.height-height)/lineheight)*lineheight + height
                            current.depth  = math.ceil((current.depth -depth )/lineheight)*lineheight + depth
                        end
                    end
                end
            end
            glue_order, glue_data = 0, nil
            penalty_order, penalty_data, natural_penalty = 0, nil, nil
            parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
            current = current.next
        end
    end
    if trace then trace_info("stop analyzing",where,what) end
    --~ if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
    --~     penalty_data = natural_penalty
    --~ end
    if trace and (glue_data or penalty_data) then
        trace_info("start flushing",where,what)
    end
    local tail
    if penalty_data then
        tail = find_node_tail(head)
        local p = make_penalty_node(penalty_data)
        if trace then trace_done("result",p) end
        head, tail = insert_node_after(head,tail,p)
    end
    if glue_data then
        if not tail then tail = find_node_tail(head) end
        if trace then trace_done("result",glue_data) end
        head, tail = insert_node_after(head,tail,glue_data)
    end
    if trace then
        if glue_data or penalty_data then
            trace_info("stop flushing",where,what)
        end
        show_tracing(head)
    end
    return head, true
end

-- alignment after_output end box new_graf vmode_par hmode_par insert penalty before_display after_display
-- \par -> vmode_par
--
-- status.best_page_break
-- tex.lists.best_page_break
-- tex.lists.best_size (natural size to best_page_break)
-- tex.lists.least_page_cost (badness of best_page_break)
-- tex.lists.page_head
-- tex.lists.contrib_head

local stackhead, stacktail, stackhack = nil, nil, false

local function report(message,lst)
    logs.report("vspacing",message,count_nodes(lst,true),node_ids_to_string(lst))
end

function nodes.handle_page_spacing(where)
    local newhead = texlists.contrib_head
    if newhead then
        starttiming(vspacing)
        local newtail = find_node_tail(newhead)
        local flush = false
        for n in traverse_nodes(newhead) do -- we could just look for glue nodes
            local id = n.id
            if id == glue then
                if n.subtype == 0 then
                    if has_attribute(n,skip_category) then
                        stackhack = true
                    else
                        flush = true
                    end
                else
                    -- tricky
                end
            else
                flush = true
            end
        end
        if flush then
            if stackhead then
                if trace_collect_vspacing then report("appending %s nodes to stack (final): %s",newhead) end
                stacktail.next = newhead
                newhead.prev = stacktail
                newhead = stackhead
                stackhead, stacktail = nil, nil
            end
            if stackhack then
                stackhack = false
                if trace_collect_vspacing then report("processing %s nodes: %s",newhead) end
                texlists.contrib_head = collapser(newhead,"page",where,trace_page_vspacing)
            else
                if trace_collect_vspacing then report("flushing %s nodes: %s",newhead) end
                texlists.contrib_head = newhead
            end
        else
            if stackhead then
                if trace_collect_vspacing then report("appending %s nodes to stack (intermediate): %s",newhead) end
                stacktail.next = newhead
                newhead.prev = stacktail
            else
                if trace_collect_vspacing then report("storing %s nodes in stack (initial): %s",newhead) end
                stackhead = newhead
            end
            stacktail = newtail
            texlists.contrib_head = nil
        end
        stoptiming(vspacing)
    end
end

local ignore = table.tohash {
    "split_keep",
    "split_off",
 -- "vbox",
}

function nodes.handle_vbox_spacing(head,where)
    if head and not ignore[where] and head.next then
        starttiming(vspacing)
        head = collapser(head,"vbox",where,trace_vbox_vspacing)
        stoptiming(vspacing)
    end
    return head
end

statistics.register("v-node processing time", function()
    if statistics.elapsedindeed(vspacing) then
        return format("%s seconds", statistics.elapsedtime(vspacing))
    end
end)

-- these are experimental callback definitions that definitely will
-- be moved elsewhere as part of a chain of vnode handling

function vspacing.enable()
    callback.register('vpack_filter', nodes.handle_vbox_spacing) -- enabled per 2009/10/16
    callback.register('buildpage_filter', nodes.handle_page_spacing)
end

function vspacing.disable()
    callback.register('vpack_filter', nil)
    callback.register('buildpage_filter', nil)
end

vspacing.enable()

-- we will split this module hence the locals

local attribute = attributes.private('graphicvadjust')

local hlist = node.id('hlist')
local vlist = node.id('vlist')

local remove_node   = nodes.remove
local hpack_node    = node.hpack
local has_attribute = node.has_attribute

function nodes.repackage_graphicvadjust(head,groupcode) -- we can make an actionchain for mvl only
    if groupcode == "" then -- mvl only
        local h, p, done = head, nil, false
        while h do
            local id = h.id
            if id == hlist or id == vlist then
                local a = has_attribute(h,attribute)
                if a then
                    if p then
                        local n
                        head, h, n = remove_node(head,h)
                        local pl = p.list
                        if n.width ~= 0 then
                            n = hpack_node(n,0,'exactly')
                        end
                        if pl then
                            pl.prev = n
                            n.next = pl
                        end
                        p.list = n
                        done = true
                    else
                        -- can't happen
                    end
                else
                    p = h
                    h = h.next
                end
            else
                h = h.next
            end
        end
        return head, done
    else
        return head, false
    end
end

--~ tasks.appendaction("finalizers", "lists", "nodes.repackage_graphicvadjust")
