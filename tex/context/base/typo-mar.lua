if not modules then modules = { } end modules ['typo-mar'] = {
    version   = 1.001,
    comment   = "companion to typo-mar.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo:
--
-- * autoleft/right depending on available space (or distance to margin)
-- * stack across paragraphs, but that is messy and one should reconsider
--   using margin data then as also vertical spacing kicks in
-- * floating margin data, with close-to-call anchoring

-- -- experiment (does not work, too much interference)
--
-- local pdfprint = pdf.print
-- local format = string.format
--
-- anchors = anchors or { }
--
-- local whatever = { }
-- local factor   = (7200/7227)/65536
--
-- function anchors.set(tag)
--     whatever[tag] = { pdf.h, pdf.v }
-- end
--
-- function anchors.reset(tag)
--     whatever[tag] = nil
-- end
--
-- function anchors.startmove(tag,how) -- save/restore nodes but they don't support moves
--     local w = whatever[tag]
--     if not w then
--         -- error
--     elseif how == "horizontal" or how == "h" then
--         pdfprint("page",format(" q 1 0 0 1 %s 0 cm ", (w[1] - pdf.h) * factor))
--     elseif how == "vertical" or how == "v" then
--         pdfprint("page",format(" q 1 0 0 1 0 %s cm ", (w[2] - pdf.v) * factor))
--     else
--         pdfprint("page",format(" q 1 0 0 1 %s %s cm ", (w[1] - pdf.h) * factor, (w[2] - pdf.v) * factor))
--     end
-- end
--
-- function anchors.stopmove(tag)
--     local w = whatever[tag]
--     if not w then
--         -- error
--     else
--         pdfprint("page"," Q ")
--     end
-- end
--
-- local latelua = nodes.pool.latelua
--
-- function anchors.node_set(tag)
--     return latelua(format("anchors.set(%q)",tag))
-- end
--
-- function anchors.node_reset(tag)
--     return latelua(format("anchors.reset(%q)",tag))
-- end
--
-- function anchors.node_start_move(tag,how)
--     return latelua(format("anchors.startmove(%q,%q)",tag,how))
-- end
--
-- function anchors.node_stop_move(tag)
--     return latelua(format("anchors.stopmove(%q)",tag))
-- end

-- so far

local format = string.format
local insert, remove = table.insert, table.remove
local setmetatable, next = setmetatable, next

local attributes, nodes, node, variables = attributes, nodes, node, variables

local trace_margindata  = false  trackers.register("typesetters.margindata",       function(v) trace_margindata  = v end)
local trace_marginstack = false  trackers.register("typesetters.margindata.stack", function(v) trace_marginstack = v end)

local report_margindata = logs.reporter("typesetters","margindata")

local tasks              = nodes.tasks
local prependaction      = tasks.prependaction
local disableaction      = tasks.disableaction
local enableaction       = tasks.enableaction

local variables          = interfaces.variables

local conditionals       = tex.conditionals

local v_top              = variables.top
local v_depth            = variables.depth
local v_local            = variables["local"]
local v_global           = variables["global"]
local v_left             = variables.left
local v_right            = variables.right
local v_flushleft        = variables.flushleft
local v_flushright       = variables.flushright
local v_inner            = variables.inner
local v_outer            = variables.outer
local v_margin           = variables.margin
local v_edge             = variables.edge
local v_default          = variables.default
local v_normal           = variables.normal
local v_yes              = variables.yes
local v_continue         = variables.continue
local v_first            = variables.first
local v_text             = variables.text
local v_column           = variables.column

local has_attribute      = node.has_attribute
local set_attribute      = node.set_attribute
local unset_attribute    = node.unset_attribute
local copy_node_list     = node.copy_list
local slide_nodes        = node.slide
local hpack_nodes        = node.hpack -- nodes.fasthpack not really faster here
local traverse_id        = node.traverse_id
local free_node_list     = node.flush_list
local insert_node_after  = node.insert_after
local insert_node_before = node.insert_before

local link_nodes         = nodes.link

local nodecodes          = nodes.nodecodes
local listcodes          = nodes.listcodes
local gluecodes          = nodes.gluecodes
local whatsitcodes       = nodes.whatsitcodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local glue_code          = nodecodes.glue
local kern_code          = nodecodes.kern
local penalty_code       = nodecodes.penalty
local whatsit_code       = nodecodes.whatsit
local line_code          = listcodes.line
local leftskip_code      = gluecodes.leftskip
local rightskip_code     = gluecodes.rightskip
local userdefined_code   = whatsitcodes.userdefined

local dir_code           = whatsitcodes.dir
local localpar_code      = whatsitcodes.localpar

local nodepool           = nodes.pool

local new_kern           = nodepool.kern
local new_glue           = nodepool.glue
local new_penalty        = nodepool.penalty
local new_stretch        = nodepool.stretch
local new_usernumber     = nodepool.usernumber
local new_latelua        = nodepool.latelua

local texcount           = tex.count
local texdimen           = tex.dimen
local texbox             = tex.box

local points             = number.points

local isleftpage         = layouts.status.isleftpage
local registertogether   = builders.paragraphs.registertogether

local jobpositions       = job.positions
local getposition        = jobpositions.position

local a_margindata       = attributes.private("margindata")

local inline_mark        = nodepool.userids["margins.inline"]

local margins            =  { }
typesetters.margins      = margins

local locations          = { v_left, v_right, v_inner, v_outer } -- order might change
local categories         = { }
local displaystore       = { } -- [category][location][scope]
local inlinestore        = { } -- [number]
local nofsaved           = 0
local nofstored          = 0
local nofinlined         = 0
local nofdelayed         = 0
local h_anchors          = 0
local v_anchors          = 0

local mt1 = {
    __index = function(t,location)
        local v = { [v_local] = { }, [v_global] = { } }
        t[location] = v
        return v
    end
}

local mt2 = {
    __index = function(stores,category)
        categories[#categories+1] = category
        local v = { }
        setmetatable(v,mt1)
        stores[category] = v
        return v
    end
}

setmetatable(displaystore,mt2)

local defaults = {
    __index  = {
        location  = v_left,
        align     = v_normal,
        method    = "",
        name      = "",
        threshold = 0, -- .25ex
        margin    = v_normal,
        scope     = v_global,
        distance  = 0,
        hoffset   = 0,
        voffset   = 0,
        category  = v_default,
        line      = 0,
        vstack    = 0,
        dy        = 0,
        baseline  = false,
        inline    = false,
        leftskip  = 0,
        rightskip = 0,
    }
}

local enablelocal, enableglobal -- forward reference (delayed initialization)

local function showstore(store,banner)
    if next(store) then
        for i, si in table.sortedpairs(store) do
            local si =store[i]
            report_margindata("%s: stored at %s: %s => %s",banner,i,si.name or "no name",nodes.toutf(si.box.list))
        end
    else
        report_margindata("%s: nothing stored",banner)
    end
end

function margins.save(t)
    setmetatable(t,defaults)
    local inline   = t.inline
    local location = t.location
    local category = t.category
    local scope    = t.scope
    local store
    if inline then
        store = inlinestore
    else
        store = displaystore[category][location]
        if not store then
            report_margindata("invalid location: %s",location)
            return
        end
        store = store[scope]
    end
    if not store then
        report_margindata("invalid scope: %s",scope)
        return
    end
    if enablelocal and scope == v_local then
        enablelocal()
    end
    if enableglobal and scope == v_global then
        enableglobal()
    end
    nofsaved = nofsaved + 1
    nofstored = nofstored + 1
    local name = t.name
    if trace_marginstack then
        showstore(store,"before ")
    end
    if name and name ~= "" then
        if inlinestore then -- todo: inline store has to be done differently (not sparse)
            local t = table.sortedkeys(store) for j=#t,1,-1 do local i = t[j]
                local si = store[i]
                if si.name == name then
                    local s = remove(store,i)
                    free_node_list(s.box)
                end
            end
        else
            for i=#store,1,-1 do
                local si = store[i]
                if si.name == name then
                    local s = remove(store,i)
                    free_node_list(s.box)
                end
            end
        end
        if trace_marginstack then
            showstore(store,"between")
        end
    end
    if t.number then
        -- better make a new table and make t entry in t
        t.box                 = copy_node_list(texbox[t.number])
        t.n                   = nofsaved
        -- used later (we will clean up this natural mess later)
        -- nice is to make a special status table mechanism
        local leftmargindistance  = texdimen.naturalleftmargindistance
        local rightmargindistance = texdimen.naturalrightmargindistance
        t.strutdepth          = texbox.strutbox.depth
        t.strutheight         = texbox.strutbox.height
        t.leftskip            = tex.leftskip.width  -- we're not in forgetall
        t.rightskip           = tex.rightskip.width -- we're not in forgetall
        t.leftmargindistance  = leftmargindistance -- todo:layoutstatus table
        t.rightmargindistance = rightmargindistance
        t.leftedgedistance    = texdimen.naturalleftedgedistance
                              + texdimen.leftmarginwidth
                              + leftmargindistance
        t.rightedgedistance   = texdimen.naturalrightedgedistance
                              + texdimen.rightmarginwidth
                              + rightmargindistance
        t.lineheight          = texdimen.lineheight
        --
     -- t.realpageno          = texcount.realpageno
        if inline then
            context(new_usernumber(inline_mark,nofsaved))
            store[nofsaved] = t -- no insert
            nofinlined = nofinlined + 1
        else
            insert(store,t)
        end
    end
    if trace_marginstack then
        showstore(store,"after  ")
    end
    if trace_margindata then
        report_margindata("saved: %s, location: %s, scope: %s, inline: %s",nofsaved,location,scope,tostring(inline))
    end
end

-- Actually it's an advantage to have them all anchored left (tags and such)
-- we could keep them in store and flush in stage two but we might want to
-- do more before that so we need the content to be there unless we can be
-- sure that we flush this first which might not be the case in the future.
--
-- When the prototype inner/outer code that was part of this proved to be
-- okay it was moved elsewhere.

local status, nofstatus = { }, 0

local function realign(current,candidate)
    local location      = candidate.location
    local margin        = candidate.margin
    local hoffset       = candidate.hoffset
    local distance      = candidate.distance
    local hsize         = candidate.hsize
    local width         = candidate.width
    local align         = candidate.align
 -- local realpageno    = candidate.realpageno
    local leftpage      = isleftpage(false,true)
    local delta         = 0
    local leftdelta     = 0
    local rightdelta    = 0
    local leftdistance  = distance
    local rightdistance = distance
    if margin == v_normal then
        --
    elseif margin == v_local then
        leftdelta  = - candidate.leftskip
        rightdelta =   candidate.rightskip
    elseif margin == v_margin then
        leftdistance  = candidate.leftmargindistance
        rightdistance = candidate.rightmargindistance
    elseif margin == v_edge then
        leftdistance  = candidate.leftedgedistance
        rightdistance = candidate.rightedgedistance
    end
    if leftpage then
        leftdistance, rightdistance = rightdistance, leftdistance
    end

    if location == v_left then
        delta =  hoffset + width + leftdistance  + leftdelta
    elseif location == v_right then
        delta = -hoffset - hsize - rightdistance + rightdelta
    elseif location == v_inner then
        if leftpage then
            delta = -hoffset - hsize - rightdistance + rightdelta
        else
            delta =  hoffset + width + leftdistance  + leftdelta
        end
    elseif location == v_outer then
        if leftpage then
            delta =  hoffset + width + leftdistance  + leftdelta
        else
            delta = -hoffset - hsize - rightdistance + rightdelta
        end
    end

    -- we assume that list is a hbox, otherwise we had to take the whole current
    -- in order to get it right

    current.width = 0
    local anchornode, move_x

    -- this mess is needed for alignments (combinations) so we use that
    -- oportunity to add arbitrary anchoring

    -- always increment anchor is nicer for multipass when we add new ..

    local inline = candidate.inline
    local anchor = candidate.anchor
    if not anchor or anchor == "" then
        anchor = v_text
    end
    if inline or anchor ~= v_text then
        h_anchors = h_anchors + 1
        anchornode = new_latelua(format("_plib_.set('md:h',%i,{x=true,c=true})",h_anchors))
        local blob = jobpositions.get('md:h', h_anchors)
        if blob then
            local reference = jobpositions.getreserved(anchor,blob.c)
            if reference then
                if location == v_left then
                    move_x = (reference.x or 0) - (blob.x or 0)
                elseif location == v_right then
                    move_x = (reference.x or 0) - (blob.x or 0) + (reference.w or 0) - hsize
                else
                    -- not yet done
                end
            end
        end
    end

    if move_x then
        delta = delta - move_x
        if trace_margindata then
            report_margindata("realigned: %s, location: %s, margin: %s, move: %s",candidate.n,location,margin,points(move_x))
        end
    else
        if trace_margindata then
            report_margindata("realigned: %s, location: %s, margin: %s",candidate.n,location,margin)
        end
    end

    current.list = hpack_nodes(link_nodes(anchornode,new_kern(-delta),current.list,new_kern(delta))) -- anchor == nil is ok in link_nodes
    current.width = 0
end

local function realigned(current,a)
    local candidate = status[a]
    realign(current,candidate)
    nofdelayed = nofdelayed - 1
    status[a] = nil
    return true
end

-- Stacking is done in two ways: the v_yes option stacks per paragraph (or line,
-- depending on what gets by) and mostly concerns margin data dat got set at more or
-- less the same time. The v_continue option uses position tracking and works on
-- larger range. However, crossing pages is not part of it. Anyway, when you have
-- such messed up margin data you'd better think twice.
--
-- The stacked table keeps track (per location) of the offsets (the v_yes case). This
-- table gets saved when the v_continue case is active. We use a special variant
-- of position tracking, after all we only need the page number and vertical position.

local stacked = { } -- left/right keys depending on location
local cache   = { }

local function resetstacked()
    stacked = { }
end

-- resetstacked()

function margins.ha(tag) -- maybe l/r keys ipv left/right keys
    local p = cache[tag]
    p.p = true
    p.y = true
    jobpositions.set('md:v',tag,p)
    cache[tag] = nil
end

local function markovershoot(current)
    v_anchors = v_anchors + 1
    cache[v_anchors] = stacked
    local anchor = new_latelua(format("typesetters.margins.ha(%s)",v_anchors)) -- todo: alleen als offset > line
    current.list = hpack_nodes(link_nodes(anchor,current.list))
end

local function getovershoot(location)
    local p = jobpositions.get("md:v",v_anchors)
    local c = jobpositions.get("md:v",v_anchors+1)
    if p and c and p.p and p.p == c.p then
        local distance = p.y - c.y
        local offset = p[location] or 0
        local overshoot = offset - distance
        if trace_marginstack then
            report_margindata("location: %s, distance: %s, offset: %s, overshoot: %s",
                location,points(distance),points(offset),points(overshoot))
        end
        if overshoot > 0 then
            return overshoot
        end
    end
    return 0
end

local function inject(parent,head,candidate)
    local box          = candidate.box
    local width        = box.width
    local height       = box.height
    local depth        = box.depth
    local shift        = box.shift
    local stack        = candidate.stack
    local location     = candidate.location
    local method       = candidate.method
    local voffset      = candidate.voffset
    local line         = candidate.line
    local baseline     = candidate.baseline
    local strutheight  = candidate.strutheight
    local strutdepth   = candidate.strutdepth
    local offset       = stacked[location]
    local firstonstack = offset == false or offset == nil
    nofstatus          = nofstatus  + 1
    nofdelayed         = nofdelayed + 1
    status[nofstatus]  = candidate
    -- yet untested
    if baseline == true then
        baseline = false
        -- hbox vtop
--~         for h in traverse_id(hlist_code,box.list.list) do
--~             baseline = h.height
--~             break
--~         end
    else
        baseline = tonumber(baseline)
        if not baseline or baseline <= 0 then
            -- in case we have a box of width 0 that is not analyzed
            baseline = false -- strutheight -- actually a hack
        end
    end
    candidate.width = width
    candidate.hsize = parent.width -- we can also pass textwidth
    if trace_margindata then
        report_margindata("processing, index %s, height: %s, depth: %s",candidate.n,height,depth)
    end
    if firstonstack then
        offset = 0
    else
--         offset = offset + height
    end
    if stack == v_yes then
        offset = offset + candidate.dy
        shift = shift + offset
    elseif stack == v_continue then
        offset = offset + candidate.dy
        if firstonstack then
            offset = offset + getovershoot(location)
        end
        shift = shift + offset
    end
    -- -- --
    -- Maybe we also need to patch offset when we apply methods, but how ...
    -- This needs a bit of playing as it depends on the stack setting of the
    -- following which we don't know yet ... so, consider stacking partially
    -- experimental.
    -- -- --
    if method == v_top then
        local delta = height - parent.height
        if trace_margindata then
            report_margindata("top aligned, amount: %s",delta)
        end
        if delta < candidate.threshold then
            shift = shift + voffset + delta
        end
    elseif method == v_first then
        if baseline then
            shift = shift + voffset + height - baseline -- option
        else
            shift = shift + voffset -- normal
        end
        if trace_margindata then
            report_margindata("first aligned")
        end
    elseif method == v_depth then
        local delta = strutdepth
        if trace_margindata then
            report_margindata("depth aligned, amount: %s",delta)
        end
        shift = shift + voffset + delta
    elseif method == v_height then
        local delta = - strutheight
        if trace_margindata then
            report_margindata("height aligned, amount: %s",delta)
        end
        shift = shift + voffset + delta
    elseif voffset ~= 0 then
        if trace_margindata then
            report_margindata("voffset applied: %s",voffset)
        end
        shift = shift + voffset
    end
    -- -- --
    if line ~= 0 then
        local delta = line * candidate.lineheight
        if trace_margindata then
            report_margindata("line offset applied: %s (%s)",line,delta)
        end
        shift = shift + delta
        offset = offset + delta
    end
    box.shift = shift
    box.width = 0
    if not head then
        head = box
    elseif head.id == whatsit_code and head.subtype == localpar_code then
        -- experimental
        if head.dir == "TRT" then
            box.list = hpack_nodes(link_nodes(new_kern(candidate.hsize),box.list,new_kern(-candidate.hsize)))
        end
        insert_node_after(head,head,box)
    else
        head.prev = box
        box.next = head
        head = box
    end
    set_attribute(box,a_margindata,nofstatus)
    if trace_margindata then
        report_margindata("injected, location: %s, shift: %s",location,shift)
    end
    -- we need to add line etc to offset as well
    offset = offset + depth
    local room = {
        height     = height,
        depth      = offset,
        slack      = candidate.bottomspace, -- todo: 'depth' => strutdepth
        lineheight = candidate.lineheight,  -- only for tracing
    }
    offset = offset + height
    stacked[location] = offset -- weird, no table ?
    -- todo: if no real depth then zero
    if trace_margindata then
        report_margindata("status, offset: %s",offset)
    end
    return head, room, stack == v_continue
end

local function flushinline(parent,head)
    local current = head
    local done = false
    local continue = false
    local room, don, con
    while current and nofinlined > 0 do
        local id = current.id
        if id == whatsit_code then
            if current.subtype == userdefined_code and current.user_id == inline_mark then
                local n = current.value
                local candidate = inlinestore[n]
                if candidate then -- no vpack, as we want to realign
                    inlinestore[n] = nil
                    nofinlined = nofinlined - 1
                    head, room, con = inject(parent,head,candidate) -- maybe return applied offset
                    continue = continue or con
                    done = true
                    nofstored = nofstored - 1
                end
            end
        elseif id == hlist_code or id == vlist_code then
            -- optional (but sometimes needed)
            current.list, don, con = flushinline(current,current.list)
            continue = continue or con
            done = done or don
        end
        current = current.next
    end
    return head, done, continue
end

local a_linenumber = attributes.private('linenumber')

local function flushed(scope,parent) -- current is hlist
    local head = parent.list
    local done = false
    local continue = false
    local room, con, don
    for c=1,#categories do
        local category = categories[c]
        for l=1,#locations do
            local location = locations[l]
            local store = displaystore[category][location][scope]
            while true do
                local candidate = remove(store,1) -- brr, local stores are sparse
                if candidate then -- no vpack, as we want to realign
                    head, room, con = inject(parent,head,candidate)
                    done = true
                    continue = continue or con
                    nofstored = nofstored - 1
                    registertogether(parent,room)
                else
                    break
                end
            end
        end
    end
    if nofinlined > 0 then
        if done then
            parent.list = head
        end
        head, don, con = flushinline(parent,head)
        continue = continue or con
        done = done or don
    end
    if done then
local a = has_attribute(head,a_linenumber) -- hack .. we need a more decent critical attribute inheritance mechanism
        parent.list = hpack_nodes(head,parent.width,"exactly")
if a then
    set_attribute(parent.list,a_linenumber,a)
end
     -- resetstacked()
    end
    return done, continue
end

-- only when group   : vbox|vmode_par
-- only when subtype : line, box (no indent alignment cell)

local function handler(scope,head,group)
   if nofstored > 0 then
        if trace_margindata then
            report_margindata("flushing stage one, stored: %s, scope: %s, delayed: %s, group: %s",nofstored,scope,nofdelayed,group)
        end
        local current = head
        local done = false
        while current do
            local id = current.id
            if (id == vlist_code or id == hlist_code) and not has_attribute(current,a_margindata) then
                local don, continue = flushed(scope,current)
                if don then
                    set_attribute(current,a_margindata,0) -- signal to prevent duplicate processing
                    if continue then
                        markovershoot(current)
                    end
                    if nofstored <= 0 then
                        break
                    end
                    done = true
                end
            end
            current = current.next
        end
     -- if done then
        resetstacked() -- why doesn't done work ok here?
     -- end
        return head, done
    else
        return head, false
    end
end

function margins.localhandler(head,group)
    if conditionals.inhibitmargindata then
        return head, false
    elseif nofstored > 0 then
        return handler(v_local,head,group)
    else
        return head, false
    end
end

function margins.globalhandler(head,group) -- check group
--    print(group)
    if conditionals.inhibitmargindata or nofstored == 0 then
        return head, false
    elseif group == "hmode_par" then
        return handler("global",head,group)
    elseif group == "vmode_par" then              -- experiment (for alignments)
        return handler("global",head,group)
    -- this needs checking as we then get quite some one liners to process and
    -- we cannot look ahead then:
    elseif group == "box" then                    -- experiment (for alignments)
        return handler("global",head,group)
    else
        return head, false
    end
end

local function finalhandler(head)
    if nofdelayed > 0 then
        local current = head
        local done = false
        while current do
            local id = current.id
            if id == hlist_code then
                local a = has_attribute(current,a_margindata)
                if not a or a == 0 then
                    finalhandler(current.list)
                elseif realigned(current,a) then
                    done = true
                    if nofdelayed == 0 then
                        return head, true
                    end
                end
            elseif id == vlist_code then
                finalhandler(current.list)
            end
            current = current.next
        end
        return head, done
    else
        return head, false
    end
end

function margins.finalhandler(head)
    if nofdelayed > 0 then
     -- if trace_margindata then
     --     report_margindata("flushing stage two, instore: %s, delayed: %s",nofstored,nofdelayed)
     -- end
        return finalhandler(head)
    else
        return head, false
    end
end

-- Somehow the vbox builder (in combinations) gets pretty confused and decides to
-- go horizontal. So this needs more testing.

prependaction("finalizers",   "lists",       "typesetters.margins.localhandler")
-- prependaction("vboxbuilders", "normalizers", "typesetters.margins.localhandler")
prependaction("mvlbuilders",  "normalizers", "typesetters.margins.globalhandler")
prependaction("shipouts",     "normalizers", "typesetters.margins.finalhandler")

disableaction("finalizers",   "typesetters.margins.localhandler")
-- disableaction("vboxbuilders", "typesetters.margins.localhandler")
disableaction("mvlbuilders",  "typesetters.margins.globalhandler")
disableaction("shipouts",     "typesetters.margins.finalhandler")

enablelocal = function()
    enableaction("finalizers",   "typesetters.margins.localhandler")
 -- enableaction("vboxbuilders", "typesetters.margins.localhandler")
    enableaction("shipouts",     "typesetters.margins.finalhandler")
    enablelocal = nil
end

enableglobal = function()
    enableaction("mvlbuilders",  "typesetters.margins.globalhandler")
    enableaction("shipouts",     "typesetters.margins.finalhandler")
    enableglobal = nil
end

statistics.register("margin data", function()
    if nofsaved > 0 then
        return format("%s entries, %s pending",nofsaved,nofdelayed)
    else
        return nil
    end
end)
