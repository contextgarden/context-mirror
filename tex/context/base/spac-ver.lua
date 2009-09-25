if not modules then modules = { } end modules ['spac-ver'] = {
    version   = 1.001,
    comment   = "companion to spac-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon
--
-- the collapser will be redone with user nodes; also, we might get make
-- parskip into an attribute and appy it explicitly thereby getting rid
-- of automated injections; eventually i want to get rid of the currently
-- still needed tex -> lua -> tex > lua chain (needed because we can have
-- expandable settings at the tex end

local next, type, tonumber = next, type, tonumber
local format, gmatch, concat, match = string.format, string.gmatch, table.concat, string.match
local ceil, floor, max, min, round = math.ceil, math.floor, math.max, math.min, math.round
local texsprint, texlists, texdimen, texbox, texht, texdp = tex.sprint, tex.lists, tex.dimen, tex.box, tex.ht, tex.dp

local ctxcatcodes = tex.ctxcatcodes
local variables = interfaces.variables

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

-- vertical space handler

local trace_vbox_vspacing    = false  trackers.register("nodes.vbox_vspacing",    function(v) trace_vbox_vspacing    = v end)
local trace_page_vspacing    = false  trackers.register("nodes.page_vspacing",    function(v) trace_page_vspacing    = v end)
local trace_collect_vspacing = false  trackers.register("nodes.collect_vspacing", function(v) trace_collect_vspacing = v end)
local trace_vspacing         = false  trackers.register("nodes.vspacing",         function(v) trace_vspacing         = v end)
local trace_vsnapping        = false  trackers.register("nodes.vsnapping",        function(v) trace_vsnapping        = v end)

local skip_category = attributes.private('skip-category')
local skip_penalty  = attributes.private('skip-penalty')
local skip_order    = attributes.private('skip-order')
local snap_category = attributes.private('snap-category')
local display_math  = attributes.private('display-math')
local snap_method   = attributes.private('snap-method')
local snap_done     = attributes.private('snap-done')

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local find_node_tail     = node.tail
local free_node          = node.free
local copy_node          = node.copy
local traverse_nodes     = node.traverse
local traverse_nodes_id  = node.traverse_id
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove
local make_penalty_node  = nodes.penalty
local make_kern_node     = nodes.kern
local make_rule_node     = nodes.rule
local count_nodes        = nodes.count
local node_ids_to_string = nodes.ids_to_string
local hpack_node         = node.hpack
local vpack_node         = node.vpack

local glyph   = node.id("glyph")
local penalty = node.id("penalty")
local kern    = node.id("kern")
local glue    = node.id('glue')
local hlist   = node.id('hlist')
local vlist   = node.id('vlist')
local adjust  = node.id('adjust')

vspacing      = vspacing      or { }
vspacing.data = vspacing.data or { }

vspacing.data.snapmethods = vspacing.data.snapmethods or { }

storage.register("vspacing/data/snapmethods", vspacing.data.snapmethods, "vspacing.data.snapmethods")

local snapmethods = vspacing.data.snapmethods

local default = {
    maxheight = true,
    maxdepth  = true,
    strut     = true,
    hfraction = 1,
    dfraction = 1,
}

local fractions = {
    minheight = "hfraction", maxheight = "hfraction",
    mindepth  = "dfraction", maxdepth  = "dfraction",
}

local colonsplitter = lpeg.splitat(":")

function interfaces.listtohash(str)
    local t = { }
    for s in gmatch(str,"[^, ]+") do
        local key, fraction = colonsplitter:match(s)
        local v = variables[key]
        if v then
            t[v] = true
            if fraction then
                local k = fractions[key]
                if k then
                    fraction = tonumber("0" .. fraction)
                    if fraction then
                        t[k] = fraction
                    end
                end
            end
        else
            fraction = tonumber("0" .. key)
            if fraction then
                t.hfraction, t.dfraction = fraction, fraction
            end
        end
    end
    if next(t) then
        t.hfraction = t.hfraction or 1
        t.dfraction = t.dfraction or 1
        return t
    else
        return default
    end
end

function vspacing.define_snap_method(name,method)
    local n = #snapmethods + 1
    local t = interfaces.listtohash(method)
    snapmethods[n] = t
    t.name, t.specification = name, method
    tex.write(n)
end

local snapht, snapdp, snaphtdp = 0, 0, 0

function vspacing.freeze_snap_method(ht,dp)
    snapht, snapdp = ht or texdimen.bodyfontstrutheight, dp or texdimen.bodyfontstrutdepth
    snaphtdp = snapht + snapdp
end

local function snap_hlist(current,method,height,depth) -- method.strut is default
    local h, d = height or current.height, depth or current.depth
    local hr, dr, ch, cd = method.hfraction or 1, method.dfraction or 1, h, d
    local done, plusht, plusdp = false, snapht, snapdp
    if method.none then
        plusht, plusdp = 0, 0
    end
    if method.halfline then
        plusht, plusdp = plusht + snaphtdp/2, plusdp + snaphtdp/2
    end
    if method.line then
        plusht, plusdp = plusht + snaphtdp, plusdp + snaphtdp
    end
    if method.first then
        if current.id == vlist then
            local list, lh, ld = current.list
            for n in traverse_nodes_id(hlist,list) do
                lh, ld = n.height, n.depth
                break
            end
            if lh then
                local x = max(ceil((lh-hr*snapht)/snaphtdp),0)*snaphtdp + plusht
                local n = make_kern_node(x-lh)
                n.next, list.prev, current.list = list, n, n
                ch = x + snaphtdp
                cd = max(ceil((d+h-lh-dr*snapdp-hr*snapht)/snaphtdp),0)*snaphtdp + plusdp
                done = true
            end
        end
    elseif method.last then
        if current.id == vlist then
            local list, lh, ld = current.list
            for n in traverse_nodes_id(hlist,list) do
                lh, ld = n.height, n.depth
            end
            if lh then
                local baseline_till_top = h + d - ld
                local x = max(ceil((baseline_till_top-hr*snapht)/snaphtdp),0)*snaphtdp + plusht
                local n = make_kern_node(x-baseline_till_top)
                n.next, list.prev, current.list = list, n, n
                ch = x
                cd = max(ceil((ld-dr*snapdp)/snaphtdp),0)*snaphtdp + plusdp
                done = true
            end
        end
    end
    if done then
        -- first or last
    elseif method.minheight then
        ch = max(floor((h-hr*snapht)/snaphtdp),0)*snaphtdp + plusht
    elseif method.maxheight then
        ch = max(ceil((h-hr*snapht)/snaphtdp),0)*snaphtdp + plusht
    else
        ch = plusht
    end
    if done then
        -- first or last
    elseif method.mindepth then
        cd = max(floor((d-dr*snapdp)/snaphtdp),0)*snaphtdp + plusdp
    elseif method.maxdepth then
        cd = max(ceil((d-dr*snapdp)/snaphtdp),0)*snaphtdp + plusdp
    else
        cd = plusdp
    end
    if not height then
        current.height = ch
    end
    if not depth then
        current.depth = cd
    end
    return h, d, ch, cd, (ch+cd)/snaphtdp
end

local function snap_topskip(current,method)
    local spec = current.spec
    local w = spec.width
    local wd = w
    if spec then
        wd = 0 -- snapht - w
        spec.width = wd
    end
    return w, wd
end

local function snapped_spec(current)
    local spec = current.spec
    if spec then
        local w = ceil(spec.width/snaphtdp)*snaphtdp
        spec.width = w
        return w
    else
        return 0
    end
end

vspacing.categories = {
     [0] = 'discard',
     [1] = 'largest',
     [2] = 'force'  ,
     [3] = 'penalty',
     [4] = 'add'    ,
     [5] = 'disable',
     [6] = 'nowhite',
     [7] = 'goback',
     [8] = 'together'
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

    -- This will change: just node.write and we can store the values in skips which
    -- then obeys grouping

    local function analyse(str,oldcategory,texsprint) -- we could use shorter names
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
                    end
                else
                    amount = tonumber(amount) or 1
                    local sk = skip[keyword]
--~                     if sk then
--~                         texsprint(ctxcatcodes,format("\\addblankskip{%s}{%s}{%s}",amount,sk[1],sk[2] or sk[1]))
--~                     else -- no check
--~                         texsprint(ctxcatcodes,format("\\addblankskip{%s}{%s}{%s}",amount,keyword,keyword))
--~                     end
                    if sk then
                        texsprint(ctxcatcodes,format("\\addpredefinedblankskip{%s}{%s}",amount,keyword))
                    else -- no check
                        texsprint(ctxcatcodes,format("\\addaskedblankskip{%s}{%s}",amount,keyword))
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

--~ nodes.snapvalues = { }

--~ function nodes.setsnapvalue(n,ht,dp)
--~     nodes.snapvalues[n] = { ht, dp, ht+dp }
--~ end

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
local discard, largest, force, penalty, add, disable, nowhite, goback, together = 0, 1, 2, 3, 4, 5, 6, 7, 8

function vspacing.snap_box(n,how)
    local sv = snapmethods[how]
    if sv then
        local list = texbox[n].list
--~         if list and (list.id == hlist or list.id == vlist) then
        if list then
            local s = has_attribute(list,snap_method)
            if s == 0 then
                if trace_vsnapping then
                    logs.report("snapper", "hlist not snapped, already done")
                end
            else
                local h, d, ch, cd, lines = snap_hlist(list,sv,texht[n],texdp[n])
                texht[n], texdp[n] = ch, cd
                if trace_vsnapping then
                    logs.report("snapper", "hlist snapped from (%s,%s) to (%s,%s) using method '%s' (%s) for '%s' (%s lines)",h,d,ch,cd,sv.name,sv.specification,"direct",lines)
                end
                set_attribute(list,snap_method,0)
            end
        end
    end
end

local function forced_skip(head,current,width,where,trace)
    if where == "after" then
        head, current = insert_node_after(head,current,make_rule_node(0,0,0))
        head, current = insert_node_after(head,current,make_kern_node(width))
        head, current = insert_node_after(head,current,make_rule_node(0,0,0))
    else
        local c = current
        head, current = insert_node_before(head,current,make_rule_node(0,0,0))
        head, current = insert_node_before(head,current,make_kern_node(width))
        head, current = insert_node_before(head,current,make_rule_node(0,0,0))
        current = c
    end
    if trace then
        logs.report("vspacing", "inserting forced skip of %s",width)
    end
    return head, current
end

local function collapser(head,where,what,trace,snap) -- maybe also pass tail
    if trace then
        reset_tracing(head)
        trace_info("start analyzing",where,what)
    end
    local current, oldhead = head, head
    snapht, snapdp = ht or texdimen.bodyfontstrutheight, dp or texdimen.bodyfontstrutdepth
    snaphtdp = snapht + snapdp
    local glue_order, glue_data, force_glue = 0, nil, false
    local penalty_order, penalty_data, natural_penalty = 0, nil, nil
    local parskip, ignore_parskip, ignore_following, ignore_whitespace, keep_together = nil, false, false, false, false
    --
    -- todo: keep_together: between headers
    --
    local function flush(why)
        if penalty_data then
            local p = make_penalty_node(penalty_data)
            if trace then trace_done("flushed due to " .. why,p) end
            head, _ = insert_node_before(head,current,p)
        end
        if glue_data then
            if force_glue then
                if trace then trace_done("flushed due to " .. why,glue_data) end
                head, _ = forced_skip(head,current,glue_data.spec.width,"before",trace)
                free_glue_node(glue_data)
            elseif glue_data.spec then
                if trace then trace_done("flushed due to " .. why,glue_data) end
                head, _ = insert_node_before(head,current,glue_data)
            else
                free_glue_node(glue_data)
            end
        end
        if trace then trace_node(current) end
        glue_order, glue_data, force_glue = 0, nil, false
        penalty_order, penalty_data, natural_penalty = 0, nil, nil
        parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
    end
    while current do
        local id, subtype = current.id, current.subtype
        if id == hlist or id == vlist then
            if snap then
                local s = has_attribute(current,snap_method)
                if not s then
                --  if trace_vsnapping then
                --      logs.report("snapper", "hlist not snapped")
                --  end
                elseif s == 0 then
                    if trace_vsnapping then
                        logs.report("snapper", "hlist not snapped, already done")
                    end
                else
                    local sv = snapmethods[s]
                    if sv then
                        local h, d, ch, cd, lines = snap_hlist(current,sv)
                        if trace_vsnapping then
                            logs.report("snapper", "hlist snapped from (%s,%s) to (%s,%s) using method '%s' (%s) for '%s' (%s lines)",h,d,ch,cd,sv.name,sv.specification,where,lines)
                        end
                    elseif trace_vsnapping then
                        logs.report("snapper", "hlist not snapped due to unknown snap specification")
                    end
                    set_attribute(current,snap_method,0)
                end
            else
                --
            end
        --  tex.prevdepth = 0
            flush("list")
            current = current.next
        elseif id == penalty then
            --~ natural_penalty = current.penalty
            --~ if trace then trace_done("removed penalty",current) end
            --~ head, current = remove_node(head, current, true)
            current = current.next
        elseif id == kern then
            if snap and trace_vsnapping and current.kern ~= 0 then
            --~ current.kern = 0
                logs.report("snapper", "kern of %s (kept)",current.kern)
            end
            flush("kern")
            current = current.next
        elseif id ~= glue then
            flush("something else")
            current = current.next
        elseif subtype == user_skip then -- todo, other subtypes, like math
            local sc = has_attribute(current,skip_category)      -- has no default, no unset (yet)
            local so = has_attribute(current,skip_order   ) or 1 -- has  1 default, no unset (yet)
            local sp = has_attribute(current,skip_penalty )      -- has no default, no unset (yet)
            if sp and sc == penalty then
                if not penalty_data then
                    penalty_data = sp
                elseif penalty_order < so then
                    penalty_order, penalty_data = so, sp
                elseif penalty_order == so and sp > penalty_data then
                    penalty_data = sp
                end
                if trace then trace_skip('penalty in skip',sc,so,sp,current) end
                head, current = remove_node(head, current, true)
            elseif not sc then  -- if not sc then
                if glue_data then
                    if trace then trace_done("flush",glue_data) end
                    head, current = nodes.before(head,current,glue_data)
                    if trace then trace_natural("natural",current) end
                    current = current.next
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
                            --  current = previous
                                if trace then trace_natural("collapsed",previous) end
                            --  current = current.next
                            else
                                if trace then trace_natural("filler",current) end
                                current = current.next
                            end
                        else
                            if trace then trace_natural("natural (no prev spec)",current) end
                            current = current.next
                        end
                    else
                        if trace then trace_natural("natural (no prev)",current) end
                        current = current.next
                    end
                end
                glue_order, glue_data = 0, nil
            elseif sc == disable then
                ignore_following = true
                if trace then trace_skip("disable",sc,so,sp,current) end
                head, current = remove_node(head, current, true)
            elseif sc == together then
                keep_together = true
                if trace then trace_skip("together",sc,so,sp,current) end
                head, current = remove_node(head, current, true)
            elseif sc == nowhite then
                ignore_whitespace = true
                head, current = remove_node(head, current, true)
            elseif sc == discard then
                if trace then trace_skip("discard",sc,so,sp,current) end
                head, current = remove_node(head, current, true)
            elseif ignore_following then
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
                    -- ? ? ? ?
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
            if sc == force then
                force_glue = true
            end
        elseif subtype == line_skip then
            if snap then
                local s = has_attribute(current,snap_method)
                if s and s ~= 0 then
                    set_attribute(current,snap_method,0)
                    local spec = current.spec
                    if spec then
                        spec.width = 0
                        if trace_vsnapping then
                            logs.report("snapper", "lineskip set to zero")
                        end
                    end
                else
                    if trace then trace_skip("lineskip",sc,so,sp,current) end
                    flush("lineskip")
                end
            else
                if trace then trace_skip("lineskip",sc,so,sp,current) end
                flush("lineskip")
            end
            current = current.next
        elseif subtype == baseline_skip then
            if snap then
                local s = has_attribute(current,snap_method)
                if s and s ~= 0 then
                    set_attribute(current,snap_method,0)
                    local spec = current.spec
                    if spec then
                        spec.width = 0
                        if trace_vsnapping then
                            logs.report("snapper", "baselineskip set to zero")
                        end
                    end
                else
                    if trace then trace_skip("baselineskip",sc,so,sp,current) end
                    flush("baselineskip")
                end
            else
                if trace then trace_skip("baselineskip",sc,so,sp,current) end
                flush("baselineskip")
            end
            current = current.next
        elseif subtype == par_skip then
            -- parskip always comes later
            if ignore_whitespace then
                if trace then trace_natural("ignored parskip",current) end
                head, current = remove_node(head, current, true)
            elseif glue_data then
                local ps, gs = current.spec, glue_data.spec
                if ps and gs and ps.width > gs.width then
                    glue_data.spec = copy_node(ps)
                    if trace then trace_natural("taking parskip",current) end
                else
                    if trace then trace_natural("removed parskip",current) end
                end
                head, current = remove_node(head, current, true)
            else
                if trace then trace_natural("honored parskip",current) end
                head, current, glue_data = remove_node(head, current)
            end
        elseif subtype == top_skip_code or subtype == split_top_skip_code then
            if snap then
                local s = has_attribute(current,snap_method)
                if s and s ~= 0 then
                    set_attribute(current,snap_method,0)
                    local sv = snapmethods[s]
                    local w, cw = snap_topskip(current,sv)
                    if trace_vsnapping then
                        logs.report("snapper", "topskip snapped from %s to %s for '%s'",w,cw,where)
                    end
                else
                    if trace then trace_skip("topskip",sc,so,sp,current) end
                    flush("topskip")
                end
            else
                if trace then trace_skip("topskip",sc,so,sp,current) end
                flush("topskip")
            end
            current = current.next
        elseif subtype == above_display_skip then
            --
if trace then trace_skip("above display skip (normal)",sc,so,sp,current) end
flush("above display skip (normal)")
current = current.next
            --
        elseif subtype == below_display_skip then
            --
if trace then trace_skip("below display skip (normal)",sc,so,sp,current) end
flush("below display skip (normal)")
current = current.next
            --
        elseif subtype == above_display_short_skip then
            --
if trace then trace_skip("above display skip (short)",sc,so,sp,current) end
flush("above display skip (short)")
current = current.next
            --
        elseif subtype == below_display_short_skip then
            --
if trace then trace_skip("below display skip (short)",sc,so,sp,current) end
flush("below display skip (short)")
current = current.next
            --
        else -- other glue
            if snap and trace_vsnapping and current.spec and current.spec.width ~= 0 then
                logs.report("snapper", "%s of %s (kept)",skips[subtype],current.spec.width)
            --~ current.spec.width = 0
            end
            if trace then trace_skip(format("some glue (%s)",subtype),sc,so,sp,current) end
            flush("some glue")
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
--~ snapped_spec(glue_data)
        if force_glue then
            head, tail = forced_skip(head,tail,glue_data.spec.width,"after",trace)
            free_glue_node(glue_data)
        else
            head, tail = insert_node_after(head,tail,glue_data)
        end
    end
    if trace then
        if glue_data or penalty_data then
            trace_info("stop flushing",where,what)
        end
        show_tracing(head)
        if oldhead ~= head then
            trace_info("head has been changed from '%s' to '%s'",node.type(oldhead.id),node.type(head.id))
        end
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
stackhack = true -- todo: only when grid snapping once enabled
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
                texlists.contrib_head = collapser(newhead,"page",where,trace_page_vspacing,true)
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
        head = collapser(head,"vbox",where,trace_vbox_vspacing,false)
        stoptiming(vspacing)
    end
    return head
end

function nodes.collapse_vbox(n) -- for boxes
    local list = texbox[n].list
    if list then
        starttiming(vspacing)
        texbox[n].list = vpack_node(collapser(list,"snapper","vbox",trace_vbox_vspacing,true))
        stoptiming(vspacing)
    end
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
local vpack_node    = node.vpack
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
