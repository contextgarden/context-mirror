if not modules then modules = { } end modules ['spac-ver'] = {
    version   = 1.001,
    comment   = "companion to spac-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we also need to call the spacer for inserts!

-- somehow lists still don't always have proper prev nodes so i need to
-- check all of the luatex code some day .. maybe i should replece the
-- whole mvl handler by lua code .. why not

-- todo: use lua nodes with lua data (>0.79)
-- see ** can go when 0.79

-- needs to be redone, too many calls and tests now ... still within some
-- luatex limitations

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon .. it's way too complex now but
-- dates from less possibilities
--
-- the collapser will be redone with user nodes; also, we might get make
-- parskip into an attribute and appy it explicitly thereby getting rid
-- of automated injections; eventually i want to get rid of the currently
-- still needed tex -> lua -> tex > lua chain (needed because we can have
-- expandable settings at the tex end

-- todo: strip baselineskip around display math

local next, type, tonumber = next, type, tonumber
local gmatch, concat = string.gmatch, table.concat
local ceil, floor = math.ceil, math.floor
local lpegmatch = lpeg.match
local unpack = unpack or table.unpack
local allocate = utilities.storage.allocate
local todimen = string.todimen
local formatters = string.formatters

local P, C, R, S, Cc, Carg = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc, lpeg.Carg

local nodes        =  nodes
local node         =  node
local trackers     =  trackers
local attributes   =  attributes
local context      =  context
local tex          =  tex

local texlists     = tex.lists
local texgetdimen  = tex.getdimen
local texsetdimen  = tex.setdimen
local texnest      = tex.nest

local variables    = interfaces.variables
local implement    = interfaces.implement

-- vertical space handler

local trace_vbox_vspacing    = false  trackers.register("vspacing.vbox",     function(v) trace_vbox_vspacing    = v end)
local trace_page_vspacing    = false  trackers.register("vspacing.page",     function(v) trace_page_vspacing    = v end)
local trace_page_builder     = false  trackers.register("builders.page",     function(v) trace_page_builder     = v end)
local trace_collect_vspacing = false  trackers.register("vspacing.collect",  function(v) trace_collect_vspacing = v end)
local trace_vspacing         = false  trackers.register("vspacing.spacing",  function(v) trace_vspacing         = v end)
local trace_vsnapping        = false  trackers.register("vspacing.snapping", function(v) trace_vsnapping        = v end)
local trace_specials         = false  trackers.register("vspacing.specials", function(v) trace_specials         = v end)

local remove_math_skips   = true  directives.register("vspacing.removemathskips", function(v) remnove_math_skips = v end)

local report_vspacing     = logs.reporter("vspacing","spacing")
local report_collapser    = logs.reporter("vspacing","collapsing")
local report_snapper      = logs.reporter("vspacing","snapping")
local report_specials     = logs.reporter("vspacing","specials")

local a_skipcategory      = attributes.private('skipcategory')
local a_skippenalty       = attributes.private('skippenalty')
local a_skiporder         = attributes.private('skiporder')
local a_snapmethod        = attributes.private('snapmethod')
local a_snapvbox          = attributes.private('snapvbox')

local nuts                = nodes.nuts
local tonode              = nuts.tonode
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local setfield            = nuts.setfield
local getnext             = nuts.getnext
local setlink             = nuts.setlink
local getprev             = nuts.getprev
local getid               = nuts.getid
local getlist             = nuts.getlist
local setlist             = nuts.setlist
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getsubtype          = nuts.getsubtype
local getbox              = nuts.getbox

local find_node_tail      = nuts.tail
local flush_node          = nuts.flush_node
local traverse_nodes      = nuts.traverse
local traverse_nodes_id   = nuts.traverse_id
local insert_node_before  = nuts.insert_before
local insert_node_after   = nuts.insert_after
local remove_node         = nuts.remove
local count_nodes         = nuts.count
local hpack_node          = nuts.hpack
local vpack_node          = nuts.vpack
----- writable_spec       = nuts.writable_spec
local nodereference       = nuts.reference

local theprop             = nuts.theprop

local listtoutf           = nodes.listtoutf
local nodeidstostring     = nodes.idstostring

local nodepool            = nuts.pool

local new_penalty         = nodepool.penalty
local new_kern            = nodepool.kern
local new_rule            = nodepool.rule

local nodecodes           = nodes.nodecodes
local skipcodes           = nodes.skipcodes

local penalty_code        = nodecodes.penalty
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local insert_code         = nodecodes.ins
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local localpar_code       = nodecodes.localpar

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

local vspacing            = builders.vspacing or { }
builders.vspacing         = vspacing

local vspacingdata        = vspacing.data or { }
vspacing.data             = vspacingdata

local snapmethods         = vspacingdata.snapmethods or { }
vspacingdata.snapmethods  = snapmethods

storage.register("builders/vspacing/data/snapmethods", snapmethods, "builders.vspacing.data.snapmethods")

local default = {
    maxheight = true,
    maxdepth  = true,
    strut     = true,
    hfraction = 1,
    dfraction = 1,
    bfraction = 0.25,
}

local fractions = {
    minheight = "hfraction", maxheight = "hfraction",
    mindepth  = "dfraction", maxdepth  = "dfraction",
    box       = "bfraction",
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
--     if getid(n) == vlist_id then
--         local list = getlist(n)
--         local height = (list and getid(list) <= rule_id and getfield(list,"height")) or 0
--         setfield(n,"depth",getfield(n,"depth") - height + getfield(n,"height")
--         setfield(n,"height",height
--     end
-- end

local function validvbox(parentid,list)
    if parentid == hlist_code then
        local id = getid(list)
        if id == localpar_code then -- check for initial par subtype
            list = getnext(list)
            if not next then
                return nil
            end
        end
        local done = nil
        for n in traverse_nodes(list) do
            local id = getid(n)
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
            local id = getid(done)
            if id == hlist_code then
                return validvbox(id,getlist(done))
            end
        end
        return done -- only one vbox
    end
end

local function already_done(parentid,list,a_snapmethod) -- todo: done when only boxes and all snapped
    -- problem: any snapped vbox ends up in a line
    if list and parentid == hlist_code then
        local id = getid(list)
        if id == localpar_code then -- check for initial par subtype
            list = getnext(list)
            if not next then
                return false
            end
        end
--~ local i = 0
        for n in traverse_nodes(list) do
            local id = getid(n)
--~ i = i + 1 print(i,nodecodes[id],getattr(n,a_snapmethod))
            if id == hlist_code or id == vlist_code then
                local a = getattr(n,a_snapmethod)
                if not a then
                 -- return true -- not snapped at all
                elseif a == 0 then
                    return true -- already snapped
                end
            elseif id == glue_code or id == penalty_code then
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

local function fixedprofile(current)
    local profiling = builders.profiling
    return profiling and profiling.fixedprofile(current)
end

local function snap_hlist(where,current,method,height,depth) -- method.strut is default
    if fixedprofile(current) then
        return
    end
    local list = getlist(current)
    local t = trace_vsnapping and { }
    if t then
        t[#t+1] = formatters["list content: %s"](listtoutf(list))
        t[#t+1] = formatters["parent id: %s"](nodereference(current))
        t[#t+1] = formatters["snap method: %s"](method.name)
        t[#t+1] = formatters["specification: %s"](method.specification)
    end
    local snapht, snapdp
    if method["local"] then
        -- snapping is done immediately here
        snapht = texgetdimen("bodyfontstrutheight")
        snapdp = texgetdimen("bodyfontstrutdepth")
        if t then
            t[#t+1] = formatters["local: snapht %p snapdp %p"](snapht,snapdp)
        end
    elseif method["global"] then
        snapht = texgetdimen("globalbodyfontstrutheight")
        snapdp = texgetdimen("globalbodyfontstrutdepth")
        if t then
            t[#t+1] = formatters["global: snapht %p snapdp %p"](snapht,snapdp)
        end
    else
        -- maybe autolocal
        -- snapping might happen later in the otr
        snapht = texgetdimen("globalbodyfontstrutheight")
        snapdp = texgetdimen("globalbodyfontstrutdepth")
        local lsnapht = texgetdimen("bodyfontstrutheight")
        local lsnapdp = texgetdimen("bodyfontstrutdepth")
        if snapht ~= lsnapht and snapdp ~= lsnapdp then
            snapht, snapdp = lsnapht, lsnapdp
        end
        if t then
            t[#t+1] = formatters["auto: snapht %p snapdp %p"](snapht,snapdp)
        end
    end

    local h        = (method.noheight and 0) or height or getfield(current,"height")
    local d        = (method.nodepth  and 0) or depth  or getfield(current,"depth")
    local hr       = method.hfraction or 1
    local dr       = method.dfraction or 1
    local br       = method.bfraction or 0
    local ch       = h
    local cd       = d
    local tlines   = method.tlines or 1
    local blines   = method.blines or 1
    local done     = false
    local plusht   = snapht
    local plusdp   = snapdp
    local snaphtdp = snapht + snapdp

-- local properties = theprop(current)
-- local unsnapped  = properties.unsnapped
-- if not unsnapped then -- experiment
--     properties.unsnapped = {
--         height = h,
--         depth  = d,
--         snapht = snapht,
--         snapdp = snapdp,
--     }
-- end

    if method.box then
        local br = 1 - br
        if br < 0 then
            br = 0
        elseif br > 1 then
            br = 1
        end
        local n = ceiled((h+d-br*snapht-br*snapdp)/snaphtdp)
        local x = n * snaphtdp - h - d
        plusht = h + x / 2
        plusdp = d + x / 2
    elseif method.max then
        local n = ceiled((h+d)/snaphtdp)
        local x = n * snaphtdp - h - d
        plusht = h + x / 2
        plusdp = d + x / 2
    elseif method.min then
        local n = floored((h+d)/snaphtdp)
        local x = n * snaphtdp - h - d
        plusht = h + x / 2
        plusdp = d + x / 2
    elseif method.none then
        plusht, plusdp = 0, 0
        if t then
            t[#t+1] = "none: plusht 0pt plusdp 0pt"
        end
    end
    if method.halfline then -- extra halfline
        plusht = plusht + snaphtdp/2
        plusdp = plusdp + snaphtdp/2
        if t then
            t[#t+1] = formatters["halfline: plusht %p plusdp %p"](plusht,plusdp)
        end
    end
    if method.line then -- extra line
        plusht = plusht + snaphtdp
        plusdp = plusdp + snaphtdp
        if t then
            t[#t+1] = formatters["line: plusht %p plusdp %p"](plusht,plusdp)
        end
    end

    if method.first then
        local thebox = current
        local id = getid(thebox)
        if id == hlist_code then
            thebox = validvbox(id,getlist(thebox))
            id = thebox and getid(thebox)
        end
        if thebox and id == vlist_code then
            local list = getlist(thebox)
            local lh, ld
            for n in traverse_nodes_id(hlist_code,list) do
                lh = getfield(n,"height")
                ld = getfield(n,"depth")
                break
            end
            if lh then
                local ht = getfield(thebox,"height")
                local dp = getfield(thebox,"depth")
                if t then
                    t[#t+1] = formatters["first line: height %p depth %p"](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = h - lh
                ch, cd = lh, delta + d
                h, d = ch, cd
                local shifted = hpack_node(getlist(current))
                setfield(shifted,"shift",delta)
                setlist(current,shifted)
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
        local id = getid(thebox)
        if id == hlist_code then
            thebox = validvbox(id,getlist(thebox))
            id = thebox and getid(thebox)
        end
        if thebox and id == vlist_code then
            local list = getlist(thebox)
            local lh, ld
            for n in traverse_nodes_id(hlist_code,list) do
                lh = getfield(n,"height")
                ld = getfield(n,"depth")
            end
            if lh then
                local ht = getfield(thebox,"height")
                local dp = getfield(thebox,"depth")
                if t then
                    t[#t+1] = formatters["last line: height %p depth %p" ](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = d - ld
                cd, ch = ld, delta + h
                h, d = ch, cd
                local shifted = hpack_node(getlist(current))
                setfield(shifted,"shift",delta)
                setlist(current,shifted)
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
            t[#t+1] = formatters["before offset: %p (width %p height %p depth %p)"](offset,getfield(current,"width") or 0,getfield(current,"height"),getfield(current,"depth"))
        end
        local shifted = hpack_node(getlist(current))
        setfield(shifted,"shift",offset)
        setlist(current,shifted)
        if t then
            t[#t+1] = formatters["after offset: %p (width %p height %p depth %p)"](offset,getfield(current,"width") or 0,getfield(current,"height"),getfield(current,"depth"))
        end
        setattr(shifted,a_snapmethod,0)
        setattr(current,a_snapmethod,0)
    end
    if not height then
        setfield(current,"height",ch)
        if t then
            t[#t+1] = formatters["forced height: %p"](ch)
        end
    end
    if not depth then
        setfield(current,"depth",cd)
        if t then
            t[#t+1] = formatters["forced depth: %p"](cd)
        end
    end
    local lines = (ch+cd)/snaphtdp
    if t then
        local original = (h+d)/snaphtdp
        local whatever = (ch+cd)/(texgetdimen("globalbodyfontstrutheight") + texgetdimen("globalbodyfontstrutdepth"))
        t[#t+1] = formatters["final lines: %s -> %s (%s)"](original,lines,whatever)
        t[#t+1] = formatters["final height: %p -> %p"](h,ch)
        t[#t+1] = formatters["final depth: %p -> %p"](d,cd)
    end
-- todo:
--
--     if h < 0 or d < 0 then
--         h = 0
--         d = 0
--     end
    if t then
        report_snapper("trace: %s type %s\n\t%\n\tt",where,nodecodes[getid(current)],t)
    end
    return h, d, ch, cd, lines
end

local function snap_topskip(current,method)
    local w = getfield(current,"width") or 0
    setfield(current,"width",0)
    return w, 0
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
     [8] = 'together', -- not used (?)
     [9] = 'overlay',
    [10] = 'notopskip',
}

vspacing.categories = categories

function vspacing.tocategories(str)
    local t = { }
    for s in gmatch(str,"[^, ]") do -- use lpeg instead
        local n = tonumber(s)
        if n then
            t[categories[n]] = true
        else
            t[b] = true
        end
    end
    return t
end

function vspacing.tocategory(str) -- can be optimized
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

do -- todo: interface.variables and properties

    vspacing.fixed   = false

    local map        = vspacingdata.map
    local skip       = vspacingdata.skip

    local multiplier = C(S("+-")^0 * R("09")^1) * P("*")
    local separator  = S(", ")
    local category   = P(":") * C((1-separator)^1)
    local keyword    = C((1-category-separator)^1)
    local splitter   = (multiplier + Cc(1)) * keyword * (category + Cc(false))

    local k_fixed    = variables.fixed
    local k_flexible = variables.flexible
    local k_category = "category"
    local k_penalty  = "penalty"
    local k_order    = "order"

    -- This will change: just node.write and we can store the values in skips which
    -- then obeys grouping .. but .. we miss the amounts then as they live at the tex
    -- end so we then also need to change that bit ... it would be interesting if we
    -- could store in properties

    local ctx_fixedblankskip         = context.fixedblankskip
    local ctx_flexibleblankskip      = context.flexibleblankskip
    local ctx_setblankcategory       = context.setblankcategory
    local ctx_setblankorder          = context.setblankorder
    local ctx_setblankpenalty        = context.setblankpenalty
    ----- ctx_setblankhandling       = context.setblankhandling
    local ctx_flushblankhandling     = context.flushblankhandling
    local ctx_addpredefinedblankskip = context.addpredefinedblankskip
    local ctx_addaskedblankskip      = context.addaskedblankskip

    local ctx_pushlogger             = context.pushlogger
    local ctx_startblankhandling     = context.startblankhandling
    local ctx_stopblankhandling      = context.stopblankhandling
    local ctx_poplogger              = context.poplogger

    --

 -- local function analyze(str,oldcategory) -- we could use shorter names
 --     for s in gmatch(str,"([^ ,]+)") do
 --         local amount, keyword, detail = lpegmatch(splitter,s) -- the comma splitter can be merged
 --         if not keyword then
 --             report_vspacing("unknown directive %a",s)
 --         else
 --             local mk = map[keyword]
 --             if mk then
 --                 category = analyze(mk,category) -- category not used .. and we pass crap anyway
 --             elseif keyword == k_fixed then
 --                 ctx_fixedblankskip()
 --             elseif keyword == k_flexible then
 --                 ctx_flexibleblankskip()
 --             elseif keyword == k_category then
 --                 local category = tonumber(detail)
 --                 if category then
 --                     ctx_setblankcategory(category)
 --                     if category ~= oldcategory then
 --                         ctx_flushblankhandling()
 --                         oldcategory = category
 --                     end
 --                 end
 --             elseif keyword == k_order and detail then
 --                 local order = tonumber(detail)
 --                 if order then
 --                     ctx_setblankorder(order)
 --                 end
 --             elseif keyword == k_penalty and detail then
 --                 local penalty = tonumber(detail)
 --                 if penalty then
 --                     ctx_setblankpenalty(penalty)
 --                 end
 --             else
 --                 amount = tonumber(amount) or 1
 --                 local sk = skip[keyword]
 --                 if sk then
 --                     ctx_addpredefinedblankskip(amount,keyword)
 --                 else -- no check
 --                     ctx_addaskedblankskip(amount,keyword)
 --                 end
 --             end
 --         end
 --     end
 --     return category
 -- end

 -- local function analyze(str) -- we could use shorter names
 --     for s in gmatch(str,"([^ ,]+)") do
 --         local amount, keyword, detail = lpegmatch(splitter,s) -- the comma splitter can be merged
 --         if not keyword then
 --             report_vspacing("unknown directive %a",s)
 --         else
 --             local mk = map[keyword]
 --             if mk then
 --                 analyze(mk) -- category not used .. and we pass crap anyway
 --             elseif keyword == k_fixed then
 --                 ctx_fixedblankskip()
 --             elseif keyword == k_flexible then
 --                 ctx_flexibleblankskip()
 --             elseif keyword == k_category then
 --                 local category = tonumber(detail)
 --                 if category then
 --                     ctx_setblankcategory(category)
 --                     ctx_flushblankhandling()
 --                 end
 --             elseif keyword == k_order and detail then
 --                 local order = tonumber(detail)
 --                 if order then
 --                     ctx_setblankorder(order)
 --                 end
 --             elseif keyword == k_penalty and detail then
 --                 local penalty = tonumber(detail)
 --                 if penalty then
 --                     ctx_setblankpenalty(penalty)
 --                 end
 --             else
 --                 amount = tonumber(amount) or 1
 --                 local sk = skip[keyword]
 --                 if sk then
 --                     ctx_addpredefinedblankskip(amount,keyword)
 --                 else -- no check
 --                     ctx_addaskedblankskip(amount,keyword)
 --                 end
 --             end
 --         end
 --     end
 -- end

 -- function vspacing.analyze(str)
 --     if trace_vspacing then
 --         ctx_pushlogger(report_vspacing)
 --         ctx_startblankhandling()
 --         analyze(str,1)
 --         ctx_stopblankhandling()
 --         ctx_poplogger()
 --     else
 --         ctx_startblankhandling()
 --         analyze(str,1)
 --         ctx_stopblankhandling()
 --     end
 -- end

    -- alternative

    local pattern = nil

    local function handler(amount, keyword, detail)
        if not keyword then
            report_vspacing("unknown directive %a",s)
        else
            local mk = map[keyword]
            if mk then
                lpegmatch(pattern,mk)
            elseif keyword == k_fixed then
                ctx_fixedblankskip()
            elseif keyword == k_flexible then
                ctx_flexibleblankskip()
            elseif keyword == k_category then
                local category = tonumber(detail)
                if category then
                    ctx_setblankcategory(category)
                    ctx_flushblankhandling()
                end
            elseif keyword == k_order and detail then
                local order = tonumber(detail)
                if order then
                    ctx_setblankorder(order)
                end
            elseif keyword == k_penalty and detail then
                local penalty = tonumber(detail)
                if penalty then
                    ctx_setblankpenalty(penalty)
                end
            else
                amount = tonumber(amount) or 1
                local sk = skip[keyword]
                if sk then
                    ctx_addpredefinedblankskip(amount,keyword)
                else -- no check
                    ctx_addaskedblankskip(amount,keyword)
                end
            end
        end
    end

    local splitter = ((multiplier + Cc(1)) * keyword * (category + Cc(false))) / handler
          pattern  = (splitter + separator^1)^0

    function vspacing.analyze(str)
        if trace_vspacing then
            ctx_pushlogger(report_vspacing)
            ctx_startblankhandling()
            lpegmatch(pattern,str)
            ctx_stopblankhandling()
            ctx_poplogger()
        else
            ctx_startblankhandling()
            lpegmatch(pattern,str)
            ctx_stopblankhandling()
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
        local id = getid(current)
        local ty = nodecodes[id]
        if id == penalty_code then
            t[#t+1] = formatters["%s:%s"](ty,getfield(current,"penalty"))
        elseif id == glue_code then
            t[#t+1] = formatters["%s:%s:%p"](ty,skipcodes[getsubtype(current)],getfield(current,"width"))
        elseif id == kern_code then
            t[#t+1] = formatters["%s:%p"](ty,getfield(current,"kern"))
        else
            t[#t+1] = ty
        end
        current = getnext(current)
    end
    return concat(t," + ")
end

local function reset_tracing(head)
    trace_list, tracing_info, before, after = { }, false, nodes_to_string(head), ""
end

local function trace_skip(str,sc,so,sp,data)
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p | category %s | order %s | penalty %s"](str, getfield(data,"width"), sc or "-", so or "-", sp or "-") }
    tracing_info = true
end

local function trace_natural(str,data)
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p"](str, getfield(data,"width")) }
    tracing_info = true
end

local function trace_info(message, where, what)
    trace_list[#trace_list+1] = { "info", formatters["%s: %s/%s"](message,where,what) }
end

local function trace_node(what)
    local nt = nodecodes[getid(what)]
    local tl = trace_list[#trace_list]
    if tl and tl[1] == "node" then
        trace_list[#trace_list] = { "node", formatters["%s + %s"](tl[2],nt) }
    else
        trace_list[#trace_list+1] = { "node", nt }
    end
end

local function trace_done(str,data)
    if getid(data) == penalty_code then
        trace_list[#trace_list+1] = { "penalty", formatters["%s | %s"](str,getfield(data,"penalty")) }
    else
        trace_list[#trace_list+1] = { "glue", formatters["%s | %p"](str,getfield(data,"width")) }
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

function vspacing.snapbox(n,how)
    local sv = snapmethods[how]
    if sv then
        local box = getbox(n)
        local list = getlist(box)
        if list then
            local s = getattr(list,a_snapmethod)
            if s == 0 then
                if trace_vsnapping then
                --  report_snapper("box list not snapped, already done")
                end
            else
                local ht = getfield(box,"height")
                local dp = getfield(box,"depth")
                if false then -- todo: already_done
                    -- assume that the box is already snapped
                    if trace_vsnapping then
                        report_snapper("box list already snapped at (%p,%p): %s",
                            ht,dp,listtoutf(list))
                    end
                else
                    local h, d, ch, cd, lines = snap_hlist("box",box,sv,ht,dp)
                    setfield(box,"height",ch)
                    setfield(box,"depth",cd)
                    if trace_vsnapping then
                        report_snapper("box list snapped from (%p,%p) to (%p,%p) using method %a (%s) for %a (%s lines): %s",
                            h,d,ch,cd,sv.name,sv.specification,"direct",lines,listtoutf(list))
                    end
                    setattr(box,a_snapmethod,0)  --
                    setattr(list,a_snapmethod,0) -- yes or no
                end
            end
        end
    end
end

-- I need to figure out how to deal with the prevdepth that crosses pages. In fact,
-- prevdepth is often quite interfering (even over a next paragraph) so I need to
-- figure out a trick. Maybe use something other than a rule. If we visualize we'll
-- see the baselineskip in action:
--
-- \blank[force,5*big] { \baselineskip1cm xxxxxxxxx \par } \page
-- \blank[force,5*big] { \baselineskip1cm xxxxxxxxx \par } \page
-- \blank[force,5*big] { \baselineskip5cm xxxxxxxxx \par } \page

-- We can register and copy the rule instead.

local w, h, d = 0, 0, 0
----- w, h, d = 100*65536, 65536, 65536

local function forced_skip(head,current,width,where,trace)
    if head == current then
        if getsubtype(head) == baselineskip_code then
            width = width - (getfield(head,"width") or 0)
        end
    end
    if width == 0 then
        -- do nothing
    elseif where == "after" then
        head, current = insert_node_after(head,current,new_rule(w,h,d))
        head, current = insert_node_after(head,current,new_kern(width))
        head, current = insert_node_after(head,current,new_rule(w,h,d))
    else
        local c = current
        head, current = insert_node_before(head,current,new_rule(w,h,d))
        head, current = insert_node_before(head,current,new_kern(width))
        head, current = insert_node_before(head,current,new_rule(w,h,d))
        current = c
    end
    if trace then
        report_vspacing("inserting forced skip of %p",width)
    end
    return head, current
end

-- penalty only works well when before skip

local discard  =  0
local largest  =  1
local force    =  2
local penalty  =  3
local add      =  4
local disable  =  5
local nowhite  =  6
local goback   =  7
local together =  8 -- not used (?)
local overlay  =  9
local enable   = 10

-- [whatsits][hlist][glue][glue][penalty]

local special_penalty_min = 32250
local special_penalty_max = 35000
local special_penalty_xxx =     0

-- this is rather messy and complex: we want to make sure that successive
-- header don't break but also make sure that we have at least a decent
-- break when we have succesive ones (often when testing)

-- todo: mark headers as such so that we can recognize them

local specialmethods = { }
local specialmethod  = 1

local properties = nodes.properties.data

specialmethods[1] = function(pagehead,pagetail,start,penalty)
    --
    if not pagehead or penalty < special_penalty_min or penalty > special_penalty_max then
        return
    end
    local current  = pagetail
    --
    -- nodes.showsimplelist(pagehead,0)
    --
    if trace_specials then
        report_specials("checking penalty %a",penalty)
    end
    while current do
        local id = getid(current)
        if id == penalty_code then
            local p = properties[current]
            if p then
                local p = p.special_penalty
                if not p then
                    if trace_specials then
                        report_specials("  regular penalty, continue")
                    end
                elseif p == penalty then
                    if trace_specials then
                        report_specials("  context penalty %a, same level, overloading",p)
                    end
                    return special_penalty_xxx
                elseif p > special_penalty_min and p < special_penalty_max then
                    if penalty < p then
                        if trace_specials then
                            report_specials("  context penalty %a, lower level, overloading",p)
                        end
                        return special_penalty_xxx
                    else
                        if trace_specials then
                            report_specials("  context penalty %a, higher level, quitting",p)
                        end
                        return
                    end
                elseif trace_specials then
                    report_specials("  context penalty %a, higher level, continue",p)
                end
            else
                local p = getfield(current,"penalty")
                if p < 10000 then
                    -- assume some other mechanism kicks in so we seem to have content
                    if trace_specials then
                        report_specials("  regular penalty %a, quitting",p)
                    end
                    break
                else
                    if trace_specials then
                        report_specials("  regular penalty %a, continue",p)
                    end
                end
            end
        end
        current = getprev(current)
    end
    -- none found, so no reson to be special
    if trace_specials then
        if pagetail then
            report_specials("  context penalty, discarding, nothing special")
        else
            report_specials("  context penalty, discarding, nothing preceding")
        end
    end
    return special_penalty_xxx
end

-- specialmethods[2] : always put something before and use that as to-be-changed
--
-- we could inject a vadjust to force a recalculation .. a mess
--
-- So, the next is far from robust and okay but for the moment this overlaying
-- has to do. Always test this with the examples in spec-ver.mkvi!

local function check_experimental_overlay(head,current)
    local p = nil
    local c = current
    local n = nil
    local function overlay(p,n,mvl)
        local p_ht  = getfield(p,"height")
        local p_dp  = getfield(p,"depth")
        local n_ht  = getfield(n,"height")
        local skips = 0
        --
        -- We deal with this at the tex end .. we don't see spacing .. enabling this code
        -- is probably harmless btu then we need to test it.
        --
        local c = getnext(p)
        while c and c ~= n do
            local id = getid(c)
            if id == glue_code then
                skips = skips + (getfield(c,"width") or 0)
            elseif id == kern_code then
                skips = skips + getfield(c,"kern")
            end
            c = getnext(c)
        end
        --
        local delta = n_ht + skips + p_dp
        texsetdimen("global","d_spac_overlay",-delta) -- for tracing
        local k = new_kern(-delta)
        if n_ht > p_ht then
            -- we should adapt pagetotal ! (need a hook for that) .. now we have the wrong pagebreak
            setfield(p,"height",n_ht)
        end
        insert_node_before(head,n,k)
        if p == head then
            head = k
        end
        if trace_vspacing then
            report_vspacing("overlaying, prev height: %p, prev depth: %p, next height: %p, skips: %p, move up: %p",p_ht,p_dp,n_ht,skips,delta)
        end
        return remove_node(head,current,true)
    end

    -- goto next line
    while c do
        local id = getid(c)
        if id == glue_code or id == penalty_code or id == kern_code then
            -- skip (actually, remove)
            c = getnext(c)
        elseif id == hlist_code then
            n = c
            break
        else
            break
        end
    end
    if n then
        -- we have a next line, goto prev line
        c = current
        while c do
            local id = getid(c)
            if id == glue_code or id == penalty_code then
                c = getprev(c)
            elseif id == hlist_code then
                p = c
                break
            else
                break
            end
        end
        if not p then
            if a_snapmethod == a_snapvbox then
                -- quit, we're not on the mvl
            else
                local c = tonut(texlists.page_head)
                while c and c ~= n do
                    local id = getid(c)
                    if id == hlist_code then
                        p = c
                    end
                    c = getnext(c)
                end
                if p and p ~= n then
                    return overlay(p,n,true)
                end
            end
        elseif p ~= n then
            return overlay(p,n,false)
        end
    end
    -- in fact, we could try again later ... so then no remove (a few tries)
    return remove_node(head, current, true)
end

-- This will be replaced after 0.80+ when we have a more robust look-back and
-- can look at the bigger picture.

-- todo: look back and when a special is there before a list is seen penalty keep ut

-- we now look back a lot, way too often

-- userskip
-- lineskip
-- baselineskip
-- parskip
-- abovedisplayskip
-- belowdisplayskip
-- abovedisplayshortskip
-- belowdisplayshortskip
-- topskip
-- splittopskip

local experiment = true directives.register("vspacing.experiment",function(v) experiment = v end)

local function collapser(head,where,what,trace,snap,a_snapmethod) -- maybe also pass tail
    if trace then
        reset_tracing(head)
    end
    local current, oldhead = head, head
    local glue_order, glue_data, force_glue = 0, nil, false
    local penalty_order, penalty_data, natural_penalty, special_penalty = 0, nil, nil, nil
    local parskip, ignore_parskip, ignore_following, ignore_whitespace, keep_together = nil, false, false, false, false
    --
    -- todo: keep_together: between headers
    --
    local pagehead = nil
    local pagetail = nil

    local function getpagelist()
        if not pagehead then
            pagehead = texlists.page_head
            if pagehead then
                pagehead = tonut(texlists.page_head)
                pagetail = find_node_tail(pagehead) -- no texlists.page_tail yet-- no texlists.page_tail yet
            end
        end
    end
    --
    local function flush(why)
        if penalty_data then
            local p = new_penalty(penalty_data)
            if trace then
                trace_done("flushed due to " .. why,p)
            end
            if penalty_data >= 10000 then -- or whatever threshold?
                local prev = getprev(current)
                if getid(prev) == glue_code then -- maybe go back more, or maybe even push back before any glue
                        -- tricky case: spacing/grid-007.tex: glue penalty glue
                    head = insert_node_before(head,prev,p)
                else
                    head = insert_node_before(head,current,p)
                end
            else
                head = insert_node_before(head,current,p)
            end
         -- if penalty_data > special_penalty_min and penalty_data < special_penalty_max then
            local props = properties[p]
            if props then
                props.special_penalty = special_penalty or penalty_data
            else
                properties[p] = {
                    special_penalty = special_penalty or penalty_data
                }
            end
         -- end
        end
        if glue_data then
            if force_glue then
                if trace then
                    trace_done("flushed due to forced " .. why,glue_data)
                end
                head = forced_skip(head,current,getfield(glue_data,"width") or 0,"before",trace)
                flush_node(glue_data)
            else
                local w = getfield(glue_data,"width")
                if w ~= 0 then
                    if trace then
                        trace_done("flushed due to non zero " .. why,glue_data)
                    end
                    head = insert_node_before(head,current,glue_data)
                elseif getfield(glue_data,"stretch") ~= 0 or getfield(glue_data,"shrink") ~= 0 then
                    if trace then
                        trace_done("flushed due to stretch/shrink in" .. why,glue_data)
                    end
                    head = insert_node_before(head,current,glue_data)
                else
                 -- report_vspacing("needs checking (%s): %p",skipcodes[getsubtype(glue_data)],w)
                    flush_node(glue_data)
                end
            end
        end

        if trace then
            trace_node(current)
        end
        glue_order, glue_data, force_glue = 0, nil, false
        penalty_order, penalty_data, natural_penalty = 0, nil, nil
        parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
    end
    --

-- quick hack, can be done nicer
-- local nobreakfound = nil
-- local function checknobreak()
--     local pagehead, pagetail = getpagelist()
--     local current = pagetail
--     while current do
--         local id = getid(current)
--         if id == hlist_code or id == vlist_code then
--             return false
--         elseif id == penalty_code then
--             return getfield(current,"penalty") >= 10000
--         end
--         current = getprev(current)
--     end
--     return false
-- end

    --
    if trace_vsnapping then
        report_snapper("global ht/dp = %p/%p, local ht/dp = %p/%p",
            texgetdimen("globalbodyfontstrutheight"), texgetdimen("globalbodyfontstrutdepth"),
            texgetdimen("bodyfontstrutheight"), texgetdimen("bodyfontstrutdepth")
        )
    end
    if trace then
        trace_info("start analyzing",where,what)
    end

-- local headprev = getprev(head)

    while current do
        local id = getid(current)
        if id == hlist_code or id == vlist_code then
-- if nobreakfound == nil then
--     nobreakfound = false
-- end
            -- needs checking, why so many calls
            if snap then
                local list = getlist(current)
                local s = getattr(current,a_snapmethod)
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
                            -- assume that the box is already snapped
                            if trace_vsnapping then
                                local h = getfield(current,"height")
                                local d = getfield(current,"depth")
                                report_snapper("mvl list already snapped at (%p,%p): %s",h,d,listtoutf(list))
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
                    setattr(current,a_snapmethod,0)
                end
            else
                --
            end
        --  tex.prevdepth = 0
            flush("list")
            current = getnext(current)
        elseif id == penalty_code then
         -- natural_penalty = getfield(current,"penalty")
         -- if trace then
         --     trace_done("removed penalty",current)
         -- end
         -- head, current = remove_node(head, current, true)

-- if nobreakfound == nil then
--     nobreakfound = checknobreak()
-- end
-- if nobreakfound and getfield(current,"penalty") <= 10000 then
--  -- if trace then
--         trace_done("removed penalty",current)
--  -- end
--     head, current = remove_node(head, current, true)
-- end

            current = getnext(current)
        elseif id == kern_code then
            if snap and trace_vsnapping and getfield(current,"kern") ~= 0 then
                report_snapper("kern of %p kept",getfield(current,"kern"))
            end
            flush("kern")
            current = getnext(current)
        elseif id == glue_code then
            local subtype = getsubtype(current)
            if subtype == userskip_code then
                local sc = getattr(current,a_skipcategory)   -- has no default, no unset (yet)
                local so = getattr(current,a_skiporder) or 1 -- has  1 default, no unset (yet)
                local sp = getattr(current,a_skippenalty)    -- has no default, no unset (yet)
                if sp and sc == penalty then
                    if where == "page" then
                        getpagelist()
                        local p = specialmethods[specialmethod](pagehead,pagetail,current,sp)
                        if p then
                         -- todo: other tracer
                         --
                         -- if trace then
                         --     trace_skip("previous special penalty %a is changed to %a using method %a",sp,p,specialmethod)
                         -- end
                            special_penalty = sp
                            sp = p
                        end

-- else
--     if nobreakfound == nil then
--         nobreakfound = checknobreak()
--     end

                    end
                    if not penalty_data then
                        penalty_data = sp
                    elseif penalty_order < so then
                        penalty_order, penalty_data = so, sp
                    elseif penalty_order == so and sp > penalty_data then
                        penalty_data = sp
                    end
                    if trace then
                        trace_skip("penalty in skip",sc,so,sp,current)
                    end

-- if nobreakfound then
--     penalty_data = 10000
--     if trace then
--         trace_skip("nobreak found before penalty in skip",sc,so,sp,current)
--     end
-- end

                    head, current = remove_node(head, current, true)
                elseif not sc then  -- if not sc then
                    if glue_data then
                        if trace then
                            trace_done("flush",glue_data)
                        end
                        head = insert_node_before(head,current,glue_data)
                        if trace then
                            trace_natural("natural",current)
                        end
                        current = getnext(current)
                    else
                        -- not look back across head
                        -- todo: prev can be whatsit (latelua)
                        local previous = getprev(current)
                        if previous and getid(previous) == glue_code and getsubtype(previous) == userskip_code then
                            if getfield(previous,"stretch_order") == 0 and getfield(previous,"shrink_order") == 0 and
                               getfield(current, "stretch_order") == 0 and getfield(current, "shrink_order") == 0 then
                                setfield(previous,"width",  (getfield(previous,"width")   or 0) + (getfield(current,"width")   or 0))
                                setfield(previous,"stretch",(getfield(previous,"stretch") or 0) + (getfield(current,"stretch") or 0))
                                setfield(previous,"shrink", (getfield(previous,"shrink")  or 0) + (getfield(current,"shrink")  or 0))
                                if trace then
                                    trace_natural("removed",current)
                                end
                                head, current = remove_node(head, current, true)
                                if trace then
                                    trace_natural("collapsed",previous)
                                end
                            else
                                if trace then
                                    trace_natural("filler",current)
                                end
                                current = getnext(current)
                            end
                        else
                            if trace then
                                trace_natural("natural (no prev)",current)
                            end
                            current = getnext(current)
                        end
                    end
                    glue_order, glue_data = 0, nil
                elseif sc == disable or sc == enable then
                    local next = getnext(current)
                    if not experiment or next then
                        ignore_following = sc == disable
                        if trace then
                            trace_skip(sc == disable and "disable" or "enable",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    else
                        current = next
                    end
                elseif sc == together then
                    local next = getnext(current)
                    if not experiment or next then
                        keep_together = true
                        if trace then
                            trace_skip("together",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    else
                        current = next
                    end
                elseif sc == nowhite then
                    local next = getnext(current)
                    if not experiment or next then
                        ignore_whitespace = true
                        head, current = remove_node(head, current, true)
                    else
                        current = next
                    end
                elseif sc == discard then
                    if trace then
                        trace_skip("discard",sc,so,sp,current)
                    end
                    head, current = remove_node(head, current, true)
                elseif sc == overlay then
                    -- todo (overlay following line over previous
                    if trace then
                        trace_skip("overlay",sc,so,sp,current)
                    end
                        -- beware: head can actually be after the affected nodes as
                        -- we look back ... some day head will the real head
                    head, current = check_experimental_overlay(head,current,a_snapmethod)
                elseif ignore_following then
                    if trace then
                        trace_skip("disabled",sc,so,sp,current)
                    end
                    head, current = remove_node(head, current, true)
                elseif not glue_data then
                    if trace then
                        trace_skip("assign",sc,so,sp,current)
                    end
                    glue_order = so
                    head, current, glue_data = remove_node(head, current)
                elseif glue_order < so then
                    if trace then
                        trace_skip("force",sc,so,sp,current)
                    end
                    glue_order = so
                    flush_node(glue_data)
                    head, current, glue_data = remove_node(head, current)
                elseif glue_order == so then
                    -- is now exclusive, maybe support goback as combi, else why a set
                    if sc == largest then
                        local cw = getfield(current,"width")   or 0
                        local gw = getfield(glue_data,"width") or 0
                        if cw > gw then
                            if trace then
                                trace_skip("largest",sc,so,sp,current)
                            end
                            flush_node(glue_data)
                            head, current, glue_data = remove_node(head,current)
                        else
                            if trace then
                                trace_skip("remove smallest",sc,so,sp,current)
                            end
                            head, current = remove_node(head, current, true)
                        end
                    elseif sc == goback then
                        if trace then
                            trace_skip("goback",sc,so,sp,current)
                        end
                        flush_node(glue_data)
                        head, current, glue_data = remove_node(head,current)
                    elseif sc == force then
                        -- last one counts, some day we can provide an accumulator and largest etc
                        -- but not now
                        if trace then
                            trace_skip("force",sc,so,sp,current)
                        end
                        flush_node(glue_data)
                        head, current, glue_data = remove_node(head, current)
                    elseif sc == penalty then
                        if trace then
                            trace_skip("penalty",sc,so,sp,current)
                        end
                        flush_node(glue_data)
                        glue_data = nil
                        head, current = remove_node(head, current, true)
                    elseif sc == add then
                        if trace then
                            trace_skip("add",sc,so,sp,current)
                        end
                        setfield(old,"width",  (getfield(glue_data,"width")   or 0) + (getfield(current,"width")   or 0))
                        setfield(old,"stretch",(getfield(glue_data,"stretch") or 0) + (getfield(current,"stretch") or 0))
                        setfield(old,"shrink", (getfield(glue_data,"shrink")  or 0) + (getfield(current,"shrink")  or 0))
                        -- toto: order
                        head, current = remove_node(head, current, true)
                    else
                        if trace then
                            trace_skip("unknown",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    end
                else
                    if trace then
                        trace_skip("unknown",sc,so,sp,current)
                    end
                    head, current = remove_node(head, current, true)
                end
                if sc == force then
                    force_glue = true
                end
            elseif subtype == lineskip_code then
                if snap then
                    local s = getattr(current,a_snapmethod)
                    if s and s ~= 0 then
                        setattr(current,a_snapmethod,0)
                        setfield(current,"width",0)
                        if trace_vsnapping then
                            report_snapper("lineskip set to zero")
                        end
                    else
                        if trace then
                            trace_skip("lineskip",sc,so,sp,current)
                        end
                        flush("lineskip")
                    end
                else
                    if trace then
                        trace_skip("lineskip",sc,so,sp,current)
                    end
                    flush("lineskip")
                end
                current = getnext(current)
            elseif subtype == baselineskip_code then
                if snap then
                    local s = getattr(current,a_snapmethod)
                    if s and s ~= 0 then
                        setattr(current,a_snapmethod,0)
                        setfield(current,"width",0)
                        if trace_vsnapping then
                            report_snapper("baselineskip set to zero")
                        end
                    else
                        if trace then
                            trace_skip("baselineskip",sc,so,sp,current)
                        end
                        flush("baselineskip")
                    end
                else
                    if trace then
                        trace_skip("baselineskip",sc,so,sp,current)
                    end
                    flush("baselineskip")
                end
                current = getnext(current)
            elseif subtype == parskip_code then
                -- parskip always comes later
                if ignore_whitespace then
                    if trace then
                        trace_natural("ignored parskip",current)
                    end
                    head, current = remove_node(head, current, true)
                elseif glue_data then
                    local w = getfield(current,"width") or 0
                    if ((w ~= 0) and (w > (getfield(glue_data,"width") or 0))) then
                        glue_data = current
                        if trace then
                            trace_natural("taking parskip",current)
                        end
                        head, current = remove_node(head, current)
                    else
                        if trace then
                            trace_natural("removed parskip",current)
                        end
                        head, current = remove_node(head, current, true)
                    end
                else
                    if trace then
                        trace_natural("honored parskip",current)
                    end
                    head, current, glue_data = remove_node(head, current)
                end
            elseif subtype == topskip_code or subtype == splittopskip_code then
                local next = getnext(current)
                if next and getattr(next,a_skipcategory) == 10 then -- no top skip
                    nuts.setglue(current) -- zero
                end
                if snap then
                    local s = getattr(current,a_snapmethod)
                    if s and s ~= 0 then
                        setattr(current,a_snapmethod,0)
                        local sv = snapmethods[s]
                        local w, cw = snap_topskip(current,sv)
                        if trace_vsnapping then
                            report_snapper("topskip snapped from %p to %p for %a",w,cw,where)
                        end
                    else
                        if trace then
                            trace_skip("topskip",sc,so,sp,current)
                        end
                        flush("topskip")
                    end
                else
                    if trace then
                        trace_skip("topskip",sc,so,sp,current)
                    end
                    flush("topskip")
                end
                current = getnext(current)
            elseif subtype == abovedisplayskip_code and remove_math_skips then
                --
                if trace then
                    trace_skip("above display skip (normal)",sc,so,sp,current)
                end
                flush("above display skip (normal)")
                current = getnext(current)
                --
            elseif subtype == belowdisplayskip_code and remove_math_skips then
                --
                if trace then
                    trace_skip("below display skip (normal)",sc,so,sp,current)
                end
                flush("below display skip (normal)")
                current = getnext(current)
               --
            elseif subtype == abovedisplayshortskip_code and remove_math_skips then
                --
                if trace then
                    trace_skip("above display skip (short)",sc,so,sp,current)
                end
                flush("above display skip (short)")
                current = getnext(current)
                --
            elseif subtype == belowdisplayshortskip_code and remove_math_skips then
                --
                if trace then
                    trace_skip("below display skip (short)",sc,so,sp,current)
                end
                flush("below display skip (short)")
                current = getnext(current)
                --
            else -- other glue
                if snap and trace_vsnapping then
                    local w = getfield(current,"width") or 0
                    if w ~= 0 then
                        report_snapper("glue %p of type %a kept",w,skipcodes[subtype])
                    end
                end
                if trace then
                    trace_skip(formatters["glue of type %a"](subtype),sc,so,sp,current)
                end
                flush("some glue")
                current = getnext(current)
            end
        else
            flush(formatters["node with id %a"](id))
            current = getnext(current)
        end
    end
    if trace then
        trace_info("stop analyzing",where,what)
    end
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
        if trace then
            trace_done("result",p)
        end
        head, tail = insert_node_after(head,tail,p)
     -- if penalty_data > special_penalty_min and penalty_data < special_penalty_max then
            local props = properties[p]
            if props then
                props.special_penalty = special_penalty or penalty_data
            else
                properties[p] = {
                    special_penalty = special_penalty or penalty_data
                }
            end
     -- end
    end
    if glue_data then
        if not tail then tail = find_node_tail(head) end
        if trace then
            trace_done("result",glue_data)
        end
        if force_glue then
            head, tail = forced_skip(head,tail,getfield(glue_data,"width") or 0,"after",trace)
            flush_node(glue_data)
            glue_data = nil
        else
            head, tail = insert_node_after(head,tail,glue_data)
        end
        texnest[texnest.ptr].prevdepth = 0 -- appending to the list bypasses tex's prevdepth handler
    end
    if trace then
        if glue_data or penalty_data then
            trace_info("stop flushing",where,what)
        end
        show_tracing(head)
        if oldhead ~= head then
            trace_info("head has been changed from %a to %a",nodecodes[getid(oldhead)],nodecodes[getid(head)])
        end
    end

-- if headprev then
--     setprev(head,headprev)
--     setnext(headprev,head)
-- end
-- print("C HEAD",tonode(head))

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

local function report(message,where,lst)
    if lst and where then
        report_vspacing(message,where,count_nodes(lst,true),nodeidstostring(lst))
    else
        report_vspacing(message,count_nodes(lst,true),nodeidstostring(lst))
    end
end

-- ugly code: we get partial lists (check if this stack is still okay) ... and we run
-- into temp nodes (sigh)

function vspacing.pagehandler(newhead,where)
    -- local newhead = texlists.contrib_head
    if newhead then
        newhead = tonut(newhead)
        local newtail = find_node_tail(newhead) -- best pass that tail, known anyway
        local flush = false
        stackhack = true -- todo: only when grid snapping once enabled
        -- todo: fast check if head = tail
        for n in traverse_nodes(newhead) do -- we could just look for glue nodes
            local id = getid(n)
            if id ~= glue_code then
                flush = true
            elseif getsubtype(n) == userskip_code then
                if getattr(n,a_skipcategory) then
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
                if trace_collect_vspacing then report("%s > appending %s nodes to stack (final): %s",where,newhead) end
                setlink(stacktail,newhead)
                newhead = stackhead
                stackhead, stacktail = nil, nil
            end
            if stackhack then
                stackhack = false
                if trace_collect_vspacing then report("%s > processing %s nodes: %s",where,newhead) end
             -- texlists.contrib_head = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
                newhead = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
            else
                if trace_collect_vspacing then report("%s > flushing %s nodes: %s",where,newhead) end
             -- texlists.contrib_head = newhead
            end
            return tonode(newhead)
        else
            if stackhead then
                if trace_collect_vspacing then report("%s > appending %s nodes to stack (intermediate): %s",where,newhead) end
                setlink(stacktail,newhead)
            else
                if trace_collect_vspacing then report("%s > storing %s nodes in stack (initial): %s",where,newhead) end
                stackhead = newhead
            end
            stacktail = newtail
         -- texlists.contrib_head = nil
         -- newhead = nil
        end
    end
    return nil
end

local ignore = table.tohash {
    "split_keep",
    "split_off",
 -- "vbox",
}

function vspacing.vboxhandler(head,where)
    if head and not ignore[where] then
        local h = tonut(head)
        if getnext(h) then -- what if a one liner and snapping?
            h = collapser(h,"vbox",where,trace_vbox_vspacing,true,a_snapvbox) -- todo: local snapper
            return tonode(h)
        end
    end
    return head
end

function vspacing.collapsevbox(n,aslist) -- for boxes but using global a_snapmethod
    local box = getbox(n)
    if box then
        local list = getlist(box)
        if list then
            list = collapser(list,"snapper","vbox",trace_vbox_vspacing,true,a_snapmethod)
            if aslist then
                setlist(box,list) -- beware, dimensions of box are wrong now
            else
                setlist(box,vpack_node(list))
            end
        end
    end
end

-- This one is needed to prevent bleeding of prevdepth to the next page
-- which doesn't work well with forced skips. I'm not that sure if the
-- following is a good way out.

do

    local outer  = texnest[0]
    local reset  = true
    local trace  = false
    local report = logs.reporter("vspacing")

    directives.register("vspacing.resetprevdepth",function(v) reset = v end)
    trackers.register  ("vspacing.resetprevdepth",function(v) trace = v end)

    function vspacing.resetprevdepth()
        if reset then
            local head = texlists.hold_head
            local skip = 0
            while head and head.id == insert_code do
                head = head.next
                skip = skip + 1
            end
            if head then
                outer.prevdepth = 0
            end
            if trace then
                report("prevdepth %s at page %i, skipped %i, value %p",
                    head and "reset" or "kept",tex.getcount("realpageno"),skip,outer.prevdepth)
            end
        end
    end

end

-- interface

implement {
    name      = "vspacing",
    actions   = vspacing.analyze,
    scope     = "private",
    arguments = "string"
}

implement {
    name      = "resetprevdepth",
    actions   = vspacing.resetprevdepth,
    scope     = "private"
}

implement {
    name      = "vspacingsetamount",
    actions   = vspacing.setskip,
    scope     = "private",
    arguments = "string",
}

implement {
    name      = "vspacingdefine",
    actions   = vspacing.setmap,
    scope     = "private",
    arguments = { "string", "string" }
}

implement {
    name      = "vspacingcollapse",
    actions   = vspacing.collapsevbox,
    scope     = "private",
    arguments = "integer"
}

implement {
    name      = "vspacingcollapseonly",
    actions   = vspacing.collapsevbox,
    scope     = "private",
    arguments = { "integer", true }
}

implement {
    name      = "vspacingsnap",
    actions   = vspacing.snapbox,
    scope     = "private",
    arguments = { "integer", "integer" }
}

implement {
    name      = "definesnapmethod",
    actions   = vspacing.definesnapmethod,
    scope     = "private",
    arguments = { "string", "string" }
}

