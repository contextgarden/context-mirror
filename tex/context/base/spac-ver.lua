if not modules then modules = { } end modules ['spac-ver'] = {
    version   = 1.001,
    comment   = "companion to spac-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we also need to call the spacer for inserts!

-- todo: directly set skips

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon
--
-- the collapser will be redone with user nodes; also, we might get make
-- parskip into an attribute and appy it explicitly thereby getting rid
-- of automated injections; eventually i want to get rid of the currently
-- still needed tex -> lua -> tex > lua chain (needed because we can have
-- expandable settings at the tex end

-- todo: strip baselineskip around display math

local next, type, tonumber = next, type, tonumber
local gmatch, concat = string.gmatch, table.concat
local ceil, floor, max, min, round, abs = math.ceil, math.floor, math.max, math.min, math.round, math.abs
local texlists, texdimen, texbox = tex.lists, tex.dimen, tex.box
local lpegmatch = lpeg.match
local unpack = unpack or table.unpack
local allocate = utilities.storage.allocate
local todimen = string.todimen
local formatters = string.formatters

local P, C, R, S, Cc = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc

local nodes, node, trackers, attributes, context =  nodes, node, trackers, attributes, context

local variables   = interfaces.variables

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming

-- vertical space handler

local trace_vbox_vspacing    = false  trackers.register("vspacing.vbox",     function(v) trace_vbox_vspacing    = v end)
local trace_page_vspacing    = false  trackers.register("vspacing.page",     function(v) trace_page_vspacing    = v end)
local trace_page_builder     = false  trackers.register("builders.page",     function(v) trace_page_builder     = v end)
local trace_collect_vspacing = false  trackers.register("vspacing.collect",  function(v) trace_collect_vspacing = v end)
local trace_vspacing         = false  trackers.register("vspacing.spacing",  function(v) trace_vspacing         = v end)
local trace_vsnapping        = false  trackers.register("vspacing.snapping", function(v) trace_vsnapping        = v end)
local trace_vpacking         = false  trackers.register("vspacing.packing",  function(v) trace_vpacking         = v end)

local report_vspacing     = logs.reporter("vspacing","spacing")
local report_collapser    = logs.reporter("vspacing","collapsing")
local report_snapper      = logs.reporter("vspacing","snapping")
local report_page_builder = logs.reporter("builders","page")

local a_skipcategory      = attributes.private('skipcategory')
local a_skippenalty       = attributes.private('skippenalty')
local a_skiporder         = attributes.private('skiporder')
----- snap_category       = attributes.private('snapcategory')
local a_snapmethod        = attributes.private('snapmethod')
local a_snapvbox          = attributes.private('snapvbox')

local find_node_tail      = node.tail
local free_node           = node.free
local free_node_list      = node.flush_list
local copy_node           = node.copy
local traverse_nodes      = node.traverse
local traverse_nodes_id   = node.traverse_id
local insert_node_before  = node.insert_before
local insert_node_after   = node.insert_after
local remove_node         = nodes.remove
local count_nodes         = nodes.count
local nodeidstostring     = nodes.idstostring
local hpack_node          = node.hpack
local vpack_node          = node.vpack
local writable_spec       = nodes.writable_spec
local listtoutf           = nodes.listtoutf

local nodepool            = nodes.pool

local new_penalty         = nodepool.penalty
local new_kern            = nodepool.kern
local new_rule            = nodepool.rule
local new_gluespec        = nodepool.gluespec

local nodecodes           = nodes.nodecodes
local skipcodes           = nodes.skipcodes
local fillcodes           = nodes.fillcodes

local penalty_code        = nodecodes.penalty
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local whatsit_code        = nodecodes.whatsit

local userskip_code       = skipcodes.userskip

local vspacing            = builders.vspacing or { }
builders.vspacing         = vspacing

local vspacingdata        = vspacing.data or { }
vspacing.data             = vspacingdata

vspacingdata.snapmethods  = vspacingdata.snapmethods or { }
local snapmethods         = vspacingdata.snapmethods --maybe some older code can go

storage.register("builders/vspacing/data/snapmethods", snapmethods, "builders.vspacing.data.snapmethods")

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
    top       = "tlines",    bottom    = "blines",
}

local values = {
    offset = "offset"
}

local colonsplitter = lpeg.splitat(":")

local function listtohash(str)
    local t = { }
    for s in gmatch(str,"[^, ]+") do
        local key, detail = lpegmatch(colonsplitter,s)
        local v = variables[key]
        if v then
            t[v] = true
            if detail then
                local k = fractions[key]
                if k then
                    detail = tonumber("0" .. detail)
                    if detail then
                        t[k] = detail
                    end
                else
                    k = values[key]
                    if k then
                        detail = todimen(detail)
                        if detail then
                            t[k] = detail
                        end
                    end
                end
            end
        else
            detail = tonumber("0" .. key)
            if detail then
                t.hfraction, t.dfraction = detail, detail
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

function vspacing.definesnapmethod(name,method)
    local n = #snapmethods + 1
    local t = listtohash(method)
    snapmethods[n] = t
    t.name, t.specification = name, method
    context(n)
end

-- local rule_id  = nodecodes.rule
-- local vlist_id = nodecodes.vlist
-- function nodes.makevtop(n)
--     if n.id == vlist_id then
--         local list = n.list
--         local height = (list and list.id <= rule_id and list.height) or 0
--         n.depth = n.depth - height + n.height
--         n.height = height
--     end
-- end

local reference = nodes.reference

local function validvbox(parentid,list)
    if parentid == hlist_code then
        local id = list.id
        if id == whatsit_code then -- check for initial par subtype
            list = list.next
            if not next then
                return nil
            end
        end
        local done = nil
        for n in traverse_nodes(list) do
            local id = n.id
            if id == vlist_code or id == hlist_code then
                if done then
                    return nil
                else
                    done = n
                end
            elseif id == glue_code or id == penalty_code then
                -- go on
            else
                return nil -- whatever
            end
        end
        if done then
            local id = done.id
            if id == hlist_code then
                return validvbox(id,done.list)
            end
        end
        return done -- only one vbox
    end
end

local function already_done(parentid,list,a_snapmethod) -- todo: done when only boxes and all snapped
    -- problem: any snapped vbox ends up in a line
    if list and parentid == hlist_code then
        local id = list.id
        if id == whatsit_code then -- check for initial par subtype
            list = list.next
            if not next then
                return false
            end
        end
--~ local i = 0
        for n in traverse_nodes(list) do
            local id = n.id
--~ i = i + 1 print(i,nodecodes[id],n[a_snapmethod])
            if id == hlist_code or id == vlist_code then
                local a = n[a_snapmethod]
                if not a then
                 -- return true -- not snapped at all
                elseif a == 0 then
                    return true -- already snapped
                end
            elseif id == glue_code or id == penalty_code then -- whatsit is weak spot
                -- go on
            else
                return false -- whatever
            end
        end
    end
    return false
end


-- quite tricky: ceil(-something) => -0

local function ceiled(n)
    if n < 0 or n < 0.01 then
        return 0
    else
        return ceil(n)
    end
end

local function floored(n)
    if n < 0 or n < 0.01 then
        return 0
    else
        return floor(n)
    end
end

-- check variables.none etc

local function snap_hlist(where,current,method,height,depth) -- method.strut is default
    local list = current.list
    local t = trace_vsnapping and { }
    if t then
        t[#t+1] = formatters["list content: %s"](nodes.toutf(list))
        t[#t+1] = formatters["parent id: %s"](reference(current))
        t[#t+1] = formatters["snap method: %s"](method.name)
        t[#t+1] = formatters["specification: %s"](method.specification)
    end
    local snapht, snapdp
    if method["local"] then
        -- snapping is done immediately here
        snapht, snapdp = texdimen.bodyfontstrutheight, texdimen.bodyfontstrutdepth
        if t then
            t[#t+1] = formatters["local: snapht %p snapdp %p"](snapht,snapdp)
        end
    elseif method["global"] then
        snapht, snapdp = texdimen.globalbodyfontstrutheight, texdimen.globalbodyfontstrutdepth
        if t then
            t[#t+1] = formatters["global: snapht %p snapdp %p"](snapht,snapdp)
        end
    else
        -- maybe autolocal
        -- snapping might happen later in the otr
        snapht, snapdp = texdimen.globalbodyfontstrutheight, texdimen.globalbodyfontstrutdepth
        local lsnapht, lsnapdp = texdimen.bodyfontstrutheight, texdimen.bodyfontstrutdepth
        if snapht ~= lsnapht and snapdp ~= lsnapdp then
            snapht, snapdp = lsnapht, lsnapdp
        end
        if t then
            t[#t+1] = formatters["auto: snapht %p snapdp %p"](snapht,snapdp)
        end
    end
    local h, d = height or current.height, depth or current.depth
    local hr, dr, ch, cd = method.hfraction or 1, method.dfraction or 1, h, d
    local tlines, blines = method.tlines or 1, method.blines or 1
    local done, plusht, plusdp = false, snapht, snapdp
    local snaphtdp = snapht + snapdp

    if method.none then
        plusht, plusdp = 0, 0
        if t then
            t[#t+1] = "none: plusht 0pt plusdp 0pt"
        end
    end
    if method.halfline then -- extra halfline
        plusht, plusdp = plusht + snaphtdp/2, plusdp + snaphtdp/2
        if t then
            t[#t+1] = formatters["halfline: plusht %p plusdp %p"](plusht,plusdp)
        end
    end
    if method.line then -- extra line
        plusht, plusdp = plusht + snaphtdp, plusdp + snaphtdp
        if t then
            t[#t+1] = formatters["line: plusht %p plusdp %p"](plusht,plusdp)
        end
    end

    if method.first then
        local thebox = current
        local id = thebox.id
        if id == hlist_code then
            thebox = validvbox(id,thebox.list)
            id = thebox and thebox.id
        end
        if thebox and id == vlist_code then
            local list, lh, ld = thebox.list
            for n in traverse_nodes_id(hlist_code,list) do
                lh, ld = n.height, n.depth
                break
            end
            if lh then
                local ht, dp = thebox.height, thebox.depth
                if t then
                    t[#t+1] = formatters["first line: height %p depth %p"](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = h - lh
                ch, cd = lh, delta + d
                h, d = ch, cd
                local shifted = hpack_node(current.list)
                shifted.shift = delta
                current.list = shifted
                done = true
                if t then
                    t[#t+1] = formatters["first: height %p depth %p shift %p"](ch,cd,delta)
                end
            elseif t then
                t[#t+1] = "first: not done, no content"
            end
        elseif t then
            t[#t+1] = "first: not done, no vbox"
        end
    elseif method.last then
        local thebox = current
        local id = thebox.id
        if id == hlist_code then
            thebox = validvbox(id,thebox.list)
            id = thebox and thebox.id
        end
        if thebox and id == vlist_code then
            local list, lh, ld = thebox.list
            for n in traverse_nodes_id(hlist_code,list) do
                lh, ld = n.height, n.depth
            end
            if lh then
                local ht, dp = thebox.height, thebox.depth
                if t then
                    t[#t+1] = formatters["last line: height %p depth %p" ](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = d - ld
                cd, ch = ld, delta + h
                h, d = ch, cd
                local shifted = hpack_node(current.list)
                shifted.shift = delta
                current.list = shifted
                done = true
                if t then
                    t[#t+1] = formatters["last: height %p depth %p shift %p"](ch,cd,delta)
                end
            elseif t then
                t[#t+1] = "last: not done, no content"
            end
        elseif t then
            t[#t+1] = "last: not done, no vbox"
        end
    end
    if method.minheight then
        ch = floored((h-hr*snapht)/snaphtdp)*snaphtdp + plusht
        if t then
            t[#t+1] = formatters["minheight: %p"](ch)
        end
    elseif method.maxheight then
        ch = ceiled((h-hr*snapht)/snaphtdp)*snaphtdp + plusht
        if t then
            t[#t+1] = formatters["maxheight: %p"](ch)
        end
    else
        ch = plusht
        if t then
            t[#t+1] = formatters["set height: %p"](ch)
        end
    end
    if method.mindepth then
        cd = floored((d-dr*snapdp)/snaphtdp)*snaphtdp + plusdp
        if t then
            t[#t+1] = formatters["mindepth: %p"](cd)
        end
    elseif method.maxdepth then
        cd = ceiled((d-dr*snapdp)/snaphtdp)*snaphtdp + plusdp
        if t then
            t[#t+1] = formatters["maxdepth: %p"](cd)
        end
    else
        cd = plusdp
        if t then
            t[#t+1] = formatters["set depth: %p"](cd)
        end
    end
    if method.top then
        ch = ch + tlines * snaphtdp
        if t then
            t[#t+1] = formatters["top height: %p"](ch)
        end
    end
    if method.bottom then
        cd = cd + blines * snaphtdp
        if t then
            t[#t+1] = formatters["bottom depth: %p"](cd)
        end
    end

    local offset = method.offset
    if offset then
        -- we need to set the attr
        if t then
            t[#t+1] = formatters["before offset: %p (width %p height %p depth %p)"](offset,current.width,current.height,current.depth)
        end
        local shifted = hpack_node(current.list)
        shifted.shift = offset
        current.list = shifted
        if t then
            t[#t+1] = formatters["after offset: %p (width %p height %p depth %p)"](offset,current.width,current.height,current.depth)
        end
        shifted[a_snapmethod] = 0
        current[a_snapmethod] = 0
    end
    if not height then
        current.height = ch
        if t then
            t[#t+1] = formatters["forced height: %p"](ch)
        end
    end
    if not depth then
        current.depth = cd
        if t then
            t[#t+1] = formatters["forced depth: %p"](cd)
        end
    end
    local lines = (ch+cd)/snaphtdp
    if t then
        local original = (h+d)/snaphtdp
        local whatever = (ch+cd)/(texdimen.globalbodyfontstrutheight + texdimen.globalbodyfontstrutdepth)
        t[#t+1] = formatters["final lines: %s -> %s (%s)"](original,lines,whatever)
        t[#t+1] = formatters["final height: %p -> %p"](h,ch)
        t[#t+1] = formatters["final depth: %p -> %p"](d,cd)
    end
    if t then
        report_snapper("trace: %s type %s\n\t%\n\tt",where,nodecodes[current.id],t)
    end
    return h, d, ch, cd, lines
end

local function snap_topskip(current,method)
    local spec = current.spec
    local w = spec.width
    local wd = w
    if spec.writable then
        spec.width, wd = 0, 0
    end
    return w, wd
end

local categories = allocate {
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

vspacing.categories = categories

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

vspacingdata.map  = vspacingdata.map  or { } -- allocate ?
vspacingdata.skip = vspacingdata.skip or { } -- allocate ?

storage.register("builders/vspacing/data/map",  vspacingdata.map,  "builders.vspacing.data.map")
storage.register("builders/vspacing/data/skip", vspacingdata.skip, "builders.vspacing.data.skip")

do -- todo: interface.variables

    vspacing.fixed = false

    local map  = vspacingdata.map
    local skip = vspacingdata.skip

    local multiplier = C(S("+-")^0 * R("09")^1) * P("*")
    local category   = P(":") * C(P(1)^1)
    local keyword    = C((1-category)^1)
    local splitter   = (multiplier + Cc(1)) * keyword * (category + Cc(false))

    local k_fixed, k_flexible, k_category, k_penalty, k_order = variables.fixed, variables.flexible, "category", "penalty", "order"

    -- This will change: just node.write and we can store the values in skips which
    -- then obeys grouping

    local fixedblankskip         = context.fixedblankskip
    local flexibleblankskip      = context.flexibleblankskip
    local setblankcategory       = context.setblankcategory
    local setblankorder          = context.setblankorder
    local setblankpenalty        = context.setblankpenalty
    local setblankhandling       = context.setblankhandling
    local flushblankhandling     = context.flushblankhandling
    local addpredefinedblankskip = context.addpredefinedblankskip
    local addaskedblankskip      = context.addaskedblankskip

    local function analyze(str,oldcategory) -- we could use shorter names
        for s in gmatch(str,"([^ ,]+)") do
            local amount, keyword, detail = lpegmatch(splitter,s) -- the comma splitter can be merged
            if not keyword then
                report_vspacing("unknown directive %a",s)
            else
                local mk = map[keyword]
                if mk then
                    category = analyze(mk,category)
                elseif keyword == k_fixed then
                    fixedblankskip()
                elseif keyword == k_flexible then
                    flexibleblankskip()
                elseif keyword == k_category then
                    local category = tonumber(detail)
                    if category then
                        setblankcategory(category)
                        if category ~= oldcategory then
                            flushblankhandling()
                            oldcategory = category
                        end
                    end
                elseif keyword == k_order and detail then
                    local order = tonumber(detail)
                    if order then
                        setblankorder(order)
                    end
                elseif keyword == k_penalty and detail then
                    local penalty = tonumber(detail)
                    if penalty then
                        setblankpenalty(penalty)
                    end
                else
                    amount = tonumber(amount) or 1
                    local sk = skip[keyword]
                    if sk then
                        addpredefinedblankskip(amount,keyword)
                    else -- no check
                        addaskedblankskip(amount,keyword)
                    end
                end
            end
        end
        return category
    end

    local pushlogger         = context.pushlogger
    local startblankhandling = context.startblankhandling
    local stopblankhandling  = context.stopblankhandling
    local poplogger          = context.poplogger

    function vspacing.analyze(str)
        if trace_vspacing then
            pushlogger(report_vspacing)
            startblankhandling()
            analyze(str,1)
            stopblankhandling()
            poplogger()
        else
            startblankhandling()
            analyze(str,1)
            stopblankhandling()
        end
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

local trace_list, tracing_info, before, after = { }, false, "", ""

local function nodes_to_string(head)
    local current, t = head, { }
    while current do
        local id = current.id
        local ty = nodecodes[id]
        if id == penalty_code then
            t[#t+1] = formatters["%s:%s"](ty,current.penalty)
        elseif id == glue_code then -- or id == kern_code then -- to be tested
            t[#t+1] = formatters["%s:%p"](ty,current)
        elseif id == kern_code then
            t[#t+1] = formatters["%s:%p"](ty,current.kern)
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
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p | category %s | order %s | penalty %s"](str, data, sc or "-", so or "-", sp or "-") }
    tracing_info = true
end

local function trace_natural(str,data)
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p"](str, data) }
    tracing_info = true
end

local function trace_info(message, where, what)
    trace_list[#trace_list+1] = { "info", formatters["%s: %s/%s"](message,where,what) }
end

local function trace_node(what)
    local nt = nodecodes[what.id]
    local tl = trace_list[#trace_list]
    if tl and tl[1] == "node" then
        trace_list[#trace_list] = { "node", formatters["%s + %s"](tl[2],nt) }
    else
        trace_list[#trace_list+1] = { "node", nt }
    end
end

local function trace_done(str,data)
    if data.id == penalty_code then
        trace_list[#trace_list+1] = { "penalty", formatters["%s | %s"](str,data.penalty) }
    else
        trace_list[#trace_list+1] = { "glue", formatters["%s | %p"](str,data) }
    end
    tracing_info = true
end

local function show_tracing(head)
    if tracing_info then
        after = nodes_to_string(head)
        for i=1,#trace_list do
            local tag, text = unpack(trace_list[i])
            if tag == "info" then
                report_collapser(text)
            else
                report_collapser("  %s: %s",tag,text)
            end
        end
        report_collapser("before: %s",before)
        report_collapser("after : %s",after)
    end
end

-- alignment box begin_of_par vmode_par hmode_par insert penalty before_display after_display

local skipcodes = nodes.skipcodes

local userskip_code              = skipcodes.userskip
local lineskip_code              = skipcodes.lineskip
local baselineskip_code          = skipcodes.baselineskip
local parskip_code               = skipcodes.parskip
local abovedisplayskip_code      = skipcodes.abovedisplayskip
local belowdisplayskip_code      = skipcodes.belowdisplayskip
local abovedisplayshortskip_code = skipcodes.abovedisplayshortskip
local belowdisplayshortskip_code = skipcodes.belowdisplayshortskip
local topskip_code               = skipcodes.topskip
local splittopskip_code          = skipcodes.splittopskip

local free_glue_node = free_node
local discard, largest, force, penalty, add, disable, nowhite, goback, together = 0, 1, 2, 3, 4, 5, 6, 7, 8

-- local function free_glue_node(n)
--  -- free_node(n.spec)
--     print("before",n)
--     logs.flush()
--     free_node(n)
--     print("after")
--     logs.flush()
-- end

function vspacing.snapbox(n,how)
    local sv = snapmethods[how]
    if sv then
        local box = texbox[n]
        local list = box.list
        if list then
            local s = list[a_snapmethod]
            if s == 0 then
                if trace_vsnapping then
                --  report_snapper("box list not snapped, already done")
                end
            else
                local ht, dp = box.height, box.depth
                if false then -- todo: already_done
                    -- assume that the box is already snapped
                    if trace_vsnapping then
                        report_snapper("box list already snapped at (%p,%p): %s",
                            ht,dp,listtoutf(list))
                    end
                else
                    local h, d, ch, cd, lines = snap_hlist("box",box,sv,ht,dp)
                    box.height, box.depth = ch, cd
                    if trace_vsnapping then
                        report_snapper("box list snapped from (%p,%p) to (%p,%p) using method %a (%s) for %a (%s lines): %s",
                            h,d,ch,cd,sv.name,sv.specification,"direct",lines,listtoutf(list))
                    end
                    box[a_snapmethod] = 0 --
                    list[a_snapmethod] = 0 -- yes or no
                end
            end
        end
    end
end

local function forced_skip(head,current,width,where,trace)
    if where == "after" then
        head, current = insert_node_after(head,current,new_rule(0,0,0))
        head, current = insert_node_after(head,current,new_kern(width))
        head, current = insert_node_after(head,current,new_rule(0,0,0))
    else
        local c = current
        head, current = insert_node_before(head,current,new_rule(0,0,0))
        head, current = insert_node_before(head,current,new_kern(width))
        head, current = insert_node_before(head,current,new_rule(0,0,0))
        current = c
    end
    if trace then
        report_vspacing("inserting forced skip of %p",width)
    end
    return head, current
end

-- penalty only works well when before skip

local function collapser(head,where,what,trace,snap,a_snapmethod) -- maybe also pass tail
    if trace then
        reset_tracing(head)
    end
    local current, oldhead = head, head
    local glue_order, glue_data, force_glue = 0, nil, false
    local penalty_order, penalty_data, natural_penalty = 0, nil, nil
    local parskip, ignore_parskip, ignore_following, ignore_whitespace, keep_together = nil, false, false, false, false
    --
    -- todo: keep_together: between headers
    --
    local function flush(why)
        if penalty_data then
            local p = new_penalty(penalty_data)
            if trace then trace_done("flushed due to " .. why,p) end
            head = insert_node_before(head,current,p)
        end
        if glue_data then
            if force_glue then
                if trace then trace_done("flushed due to " .. why,glue_data) end
                head = forced_skip(head,current,glue_data.spec.width,"before",trace)
                free_glue_node(glue_data)
            elseif glue_data.spec.writable then
                if trace then trace_done("flushed due to " .. why,glue_data) end
                head = insert_node_before(head,current,glue_data)
            else
                free_glue_node(glue_data)
            end
        end
        if trace then trace_node(current) end
        glue_order, glue_data, force_glue = 0, nil, false
        penalty_order, penalty_data, natural_penalty = 0, nil, nil
        parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
    end
    if trace_vsnapping then
        report_snapper("global ht/dp = %p/%p, local ht/dp = %p/%p",
            texdimen.globalbodyfontstrutheight, texdimen.globalbodyfontstrutdepth,
            texdimen.bodyfontstrutheight, texdimen.bodyfontstrutdepth)
    end
    if trace then trace_info("start analyzing",where,what) end
    while current do
        local id = current.id
        if id == hlist_code or id == vlist_code then
            -- needs checking, why so many calls
            if snap then
                local list = current.list
                local s = current[a_snapmethod]
                if not s then
                --  if trace_vsnapping then
                --      report_snapper("mvl list not snapped")
                --  end
                elseif s == 0 then
                    if trace_vsnapping then
                        report_snapper("mvl %a not snapped, already done: %s",nodecodes[id],listtoutf(list))
                    end
                else
                    local sv = snapmethods[s]
                    if sv then
                        -- check if already snapped
                        if list and already_done(id,list,a_snapmethod) then
                            local ht, dp = current.height, current.depth
                            -- assume that the box is already snapped
                            if trace_vsnapping then
                                report_snapper("mvl list already snapped at (%p,%p): %s",ht,dp,listtoutf(list))
                            end
                        else
                            local h, d, ch, cd, lines = snap_hlist("mvl",current,sv)
                            if trace_vsnapping then
                                report_snapper("mvl %a snapped from (%p,%p) to (%p,%p) using method %a (%s) for %a (%s lines): %s",
                                    nodecodes[id],h,d,ch,cd,sv.name,sv.specification,where,lines,listtoutf(list))
                            end
                        end
                    elseif trace_vsnapping then
                        report_snapper("mvl %a not snapped due to unknown snap specification: %s",nodecodes[id],listtoutf(list))
                    end
                    current[a_snapmethod] = 0
                end
            else
                --
            end
        --  tex.prevdepth = 0
            flush("list")
            current = current.next
        elseif id == penalty_code then
         -- natural_penalty = current.penalty
         -- if trace then trace_done("removed penalty",current) end
         -- head, current = remove_node(head, current, true)
            current = current.next
        elseif id == kern_code then
            if snap and trace_vsnapping and current.kern ~= 0 then
                report_snapper("kern of %p kept",current.kern)
            end
            flush("kern")
            current = current.next
        elseif id == glue_code then
            local subtype = current.subtype
            if subtype == userskip_code then
                local sc = current[a_skipcategory]   -- has no default, no unset (yet)
                local so = current[a_skiporder] or 1 -- has  1 default, no unset (yet)
                local sp = current[a_skippenalty]    -- has no default, no unset (yet)
                if sp and sc == penalty then
                    if not penalty_data then
                        penalty_data = sp
                    elseif penalty_order < so then
                        penalty_order, penalty_data = so, sp
                    elseif penalty_order == so and sp > penalty_data then
                        penalty_data = sp
                    end
                    if trace then trace_skip("penalty in skip",sc,so,sp,current) end
                    head, current = remove_node(head, current, true)
                elseif not sc then  -- if not sc then
                    if glue_data then
                        if trace then trace_done("flush",glue_data) end
                        head = insert_node_before(head,current,glue_data)
                        if trace then trace_natural("natural",current) end
                        current = current.next
                    else
                        -- not look back across head
                        local previous = current.prev
                        if previous and previous.id == glue_code and previous.subtype == userskip_code then
                            local ps = previous.spec
                            if ps.writable then
                                local cs = current.spec
                                if cs.writable and ps.stretch_order == 0 and ps.shrink_order == 0 and cs.stretch_order == 0 and cs.shrink_order == 0 then
                                    local pw, pp, pm = ps.width, ps.stretch, ps.shrink
                                    local cw, cp, cm = cs.width, cs.stretch, cs.shrink
                                 -- ps = writable_spec(previous) -- no writable needed here
                                 -- ps.width, ps.stretch, ps.shrink = pw + cw, pp + cp, pm + cm
                                    previous.spec = new_gluespec(pw + cw, pp + cp, pm + cm) -- else topskip can disappear
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
                        local cw, gw = cs.width, gs.width
                        if cw > gw then
                            if trace then trace_skip("largest",sc,so,sp,current) end
                            free_glue_node(glue_data) -- also free spec
                            head, current, glue_data = remove_node(head, current)
                        else
                            if trace then trace_skip("remove smallest",sc,so,sp,current) end
                            head, current = remove_node(head, current, true)
                        end
                    elseif sc == goback then
                        if trace then trace_skip("goback",sc,so,sp,current) end
                        free_glue_node(glue_data) -- also free spec
                        head, current, glue_data = remove_node(head, current)
                    elseif sc == force then
                        -- last one counts, some day we can provide an accumulator and largest etc
                        -- but not now
                        if trace then trace_skip("force",sc,so,sp,current) end
                        free_glue_node(glue_data) -- also free spec
                        head, current, glue_data = remove_node(head, current)
                    elseif sc == penalty then
                        if trace then trace_skip("penalty",sc,so,sp,current) end
                        free_glue_node(glue_data) -- also free spec
                        glue_data = nil
                        head, current = remove_node(head, current, true)
                    elseif sc == add then
                        if trace then trace_skip("add",sc,so,sp,current) end
                     -- local old, new = glue_data.spec, current.spec
                        local old, new = writable_spec(glue_data), current.spec
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
            elseif subtype == lineskip_code then
                if snap then
                    local s = current[a_snapmethod]
                    if s and s ~= 0 then
                        current[a_snapmethod] = 0
                        if current.spec.writable then
                            local spec = writable_spec(current)
                            spec.width = 0
                            if trace_vsnapping then
                                report_snapper("lineskip set to zero")
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
            elseif subtype == baselineskip_code then
                if snap then
                    local s = current[a_snapmethod]
                    if s and s ~= 0 then
                        current[a_snapmethod] = 0
                        if current.spec.writable then
                            local spec = writable_spec(current)
                            spec.width = 0
                            if trace_vsnapping then
                                report_snapper("baselineskip set to zero")
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
            elseif subtype == parskip_code then
                -- parskip always comes later
                if ignore_whitespace then
                    if trace then trace_natural("ignored parskip",current) end
                    head, current = remove_node(head, current, true)
                elseif glue_data then
                    local ps, gs = current.spec, glue_data.spec
                    if ps.writable and gs.writable and ps.width > gs.width then
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
            elseif subtype == topskip_code or subtype == splittopskip_code then
                if snap then
                    local s = current[a_snapmethod]
                    if s and s ~= 0 then
                        current[a_snapmethod] = 0
                        local sv = snapmethods[s]
                        local w, cw = snap_topskip(current,sv)
                        if trace_vsnapping then
                            report_snapper("topskip snapped from %p to %p for %a",w,cw,where)
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
            elseif subtype == abovedisplayskip_code then
                --
                if trace then trace_skip("above display skip (normal)",sc,so,sp,current) end
                flush("above display skip (normal)")
                current = current.next
                --
            elseif subtype == belowdisplayskip_code then
                --
                if trace then trace_skip("below display skip (normal)",sc,so,sp,current) end
                flush("below display skip (normal)")
                current = current.next
                --
            elseif subtype == abovedisplayshortskip_code then
                --
                if trace then trace_skip("above display skip (short)",sc,so,sp,current) end
                flush("above display skip (short)")
                current = current.next
                --
            elseif subtype == belowdisplayshortskip_code then
                --
                if trace then trace_skip("below display skip (short)",sc,so,sp,current) end
                flush("below display skip (short)")
                current = current.next
                --
            else -- other glue
                if snap and trace_vsnapping and current.spec.writable and current.spec.width ~= 0 then
                    report_snapper("glue %p of type %a kept",current.spec.width,skipcodes[subtype])
                --~ current.spec.width = 0
                end
                if trace then trace_skip(formatted["glue of type %a"](subtype),sc,so,sp,current) end
                flush("some glue")
                current = current.next
            end
        else
            flush("something else")
            current = current.next
        end
    end
    if trace then trace_info("stop analyzing",where,what) end
 -- if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
 --     penalty_data = natural_penalty
 -- end
    if trace and (glue_data or penalty_data) then
        trace_info("start flushing",where,what)
    end
    local tail
    if penalty_data then
        tail = find_node_tail(head)
        local p = new_penalty(penalty_data)
        if trace then trace_done("result",p) end
        head, tail = insert_node_after(head,tail,p)
    end
    if glue_data then
        if not tail then tail = find_node_tail(head) end
        if trace then trace_done("result",glue_data) end
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
            trace_info("head has been changed from %a to %a",nodecodes[oldhead.id],nodecodes[head.id])
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
    report_vspacing(message,count_nodes(lst,true),nodeidstostring(lst))
end

function vspacing.pagehandler(newhead,where)
    -- local newhead = texlists.contrib_head
    if newhead then
        local newtail = find_node_tail(newhead) -- best pass that tail, known anyway
        local flush = false
        stackhack = true -- todo: only when grid snapping once enabled
        for n in traverse_nodes(newhead) do -- we could just look for glue nodes
            local id = n.id
            if id ~= glue_code then
                flush = true
            elseif n.subtype == userskip_code then
                if n[a_skipcategory] then
                    stackhack = true
                else
                    flush = true
                end
            else
                -- tricky
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
--~                 texlists.contrib_head = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
                    newhead = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
            else
                if trace_collect_vspacing then report("flushing %s nodes: %s",newhead) end
--~                 texlists.contrib_head = newhead
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
         -- texlists.contrib_head = nil
            newhead = nil
        end
    end
    return newhead
end

local ignore = table.tohash {
    "split_keep",
    "split_off",
 -- "vbox",
}

function vspacing.vboxhandler(head,where)
    if head and not ignore[where] and head.next then
    --  starttiming(vspacing)
        head = collapser(head,"vbox",where,trace_vbox_vspacing,true,a_snapvbox) -- todo: local snapper
    --  stoptiming(vspacing)
    end
    return head
end

function vspacing.collapsevbox(n) -- for boxes but using global a_snapmethod
    local list = texbox[n].list
    if list then
    --  starttiming(vspacing)
        texbox[n].list = vpack_node(collapser(list,"snapper","vbox",trace_vbox_vspacing,true,a_snapmethod))
    --  stoptiming(vspacing)
    end
end

-- We will split this module so a few locals are repeated. Also this will be
-- rewritten.

nodes.builders = nodes.builder or { }
local builders = nodes.builders

local actions = nodes.tasks.actions("vboxbuilders")

function builders.vpack_filter(head,groupcode,size,packtype,maxdepth,direction)
    local done = false
    if head then
        starttiming(builders)
        if trace_vpacking then
            local before = nodes.count(head)
            head, done = actions(head,groupcode,size,packtype,maxdepth,direction)
            local after = nodes.count(head)
            if done then
                nodes.processors.tracer("vpack","changed",head,groupcode,before,after,true)
            else
                nodes.processors.tracer("vpack","unchanged",head,groupcode,before,after,true)
            end
        else
            head, done = actions(head,groupcode)
        end
        stoptiming(builders)
    end
    return head, done
end

-- This one is special in the sense that it has no head and we operate on the mlv. Also,
-- we need to do the vspacing last as it removes items from the mvl.

local actions = nodes.tasks.actions("mvlbuilders")

local function report(groupcode,head)
    report_page_builder("trigger: %s",groupcode)
    report_page_builder("  vsize    : %p",tex.vsize)
    report_page_builder("  pagegoal : %p",tex.pagegoal)
    report_page_builder("  pagetotal: %p",tex.pagetotal)
    report_page_builder("  list     : %s",head and nodeidstostring(head) or "<empty>")
end

function builders.buildpage_filter(groupcode)
    local head, done = texlists.contrib_head, false
 -- if head and head.next and head.next.id == hlist_code and head.next.width == 1 then
 --     report_page_builder("trigger otr calculations")
 --     free_node_list(head)
 --     head = nil
 -- end
    if head then
        starttiming(builders)
        if trace_page_builder then
            report(groupcode,head)
        end
        head, done = actions(head,groupcode)
        stoptiming(builders)
     -- -- doesn't work here (not passed on?)
     -- tex.pagegoal = tex.vsize - tex.dimen.d_page_floats_inserted_top - tex.dimen.d_page_floats_inserted_bottom
        texlists.contrib_head = head
        return done and head or true
    else
        if trace_page_builder then
            report(groupcode)
        end
        return nil, false
    end
end

callbacks.register('vpack_filter',     builders.vpack_filter,     "vertical spacing etc")
callbacks.register('buildpage_filter', builders.buildpage_filter, "vertical spacing etc (mvl)")

statistics.register("v-node processing time", function()
    return statistics.elapsedseconds(builders)
end)

-- interface

commands.vspacing          = vspacing.analyze
commands.vspacingsetamount = vspacing.setskip
commands.vspacingdefine    = vspacing.setmap
commands.vspacingcollapse  = vspacing.collapsevbox
commands.vspacingsnap      = vspacing.snapbox
