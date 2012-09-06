if not modules then modules = { } end modules ['page-mix'] = {
    version   = 1.001,
    comment   = "companion to page-mix.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- inserts.getname(name)

-- local node, tex = node, tex
-- local nodes, interfaces, utilities = nodes, interfaces, utilities
-- local trackers, logs, storage = trackers, logs, storage
-- local number, table = number, table

local concat = table.concat

local nodecodes        = nodes.nodecodes
local gluecodes        = nodes.gluecodes
local nodepool         = nodes.pool

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local kern_code        = nodecodes.kern
local glue_code        = nodecodes.glue
local penalty_code     = nodecodes.penalty
local insert_code      = nodecodes.ins
local mark_code        = nodecodes.mark

local new_hlist        = nodepool.hlist
local new_vlist        = nodepool.vlist
local new_glue         = nodepool.glue

local hpack            = node.hpack
local vpack            = node.vpack
local freenode         = node.free

local texbox           = tex.box
local texskip          = tex.skip
local texdimen         = tex.dimen
local points           = number.points
local settings_to_hash = utilities.parsers.settings_to_hash

local variables        = interfaces.variables
local v_yes            = variables.yes
local v_global         = variables["global"]
local v_local          = variables["local"]
local v_columns        = variables.columns

local trace_state  = false  trackers.register("mixedcolumns.trace",  function(v) trace_state  = v end)
local trace_detail = false  trackers.register("mixedcolumns.detail", function(v) trace_detail = v end)

local report_state = logs.reporter("mixed columns")

pagebuilders              = pagebuilders or { }
pagebuilders.mixedcolumns = pagebuilders.mixedcolumns or { }
local mixedcolumns        = pagebuilders.mixedcolumns

local forcedbreak = -123

-- initializesplitter(specification)
-- cleanupsplitter()

-- Inserts complicate matters a lot. In order to deal with them well, we need to
-- distinguish several cases.
--
-- (1) full page columns: firstcolumn, columns, lastcolumn, page
-- (2) mid page columns : firstcolumn, columns, lastcolumn, page
--
-- We need to collect them accordingly.

local function collectinserts(result,nxt,nxtid)
    local inserts, currentskips, nextskips, inserttotal = { }, 0, 0, 0
    while nxt do
        if nxtid == insert_code then
            inserttotal = inserttotal + nxt.height + nxt.depth
            local s = nxt.subtype
-- print(">>>",structures.inserts.getlocation(s))
            local c = inserts[s]
            if not c then
                c = { }
                inserts[s] = c
                local width = texskip[s].width
                if not result.inserts[s] then
                    currentskips = currentskips + width
                end
                nextskips = nextskips + width
            end
            c[#c+1] = nxt
            if trace_detail then
                report_state("insert of class %s found",s)
            end
        elseif nxtid == mark_code then
            if trace_detail then
                report_state("mark found")
            end
        else
            break
        end
        nxt = nxt.next
        if nxt then
            nxtid = nxt.id
        else
            break
        end
    end
    return nxt, inserts, currentskips, nextskips, inserttotal
end

local function appendinserts(ri,inserts)
    for class, collected in next, inserts do
        local ric = ri[class]
        if not ric then
            -- assign to collected
            ri[class] = collected
        else
            -- append to collected
            for j=1,#collected do
                ric[#ric+1] = collected[j]
            end
        end
    end
end

local function discardtopglue(current,discarded)
    while current do
        local id = current.id
        if id == glue_code or (id == penalty_code and current.penalty ~= forcedbreak) then
            discarded[#discarded+1] = current
            current = current.next
        else
            break
        end
    end
    return current
end

local function stripbottomglue(results,discarded)
    local height = 0
    for i=1,#results do
        local r = results[i]
        local t = r.tail
        while t and t ~= r.head do
            local prev = t.prev
            if not prev then
                break
            elseif t.id == penalty_code then
                if t.penalty == forcedbreak then
                    break
                else
                    discarded[#discarded+1] = t
                    r.tail = prev
                    t = prev
                end
            elseif t.id == glue_code then
                discarded[#discarded+1] = t
                r.height = r.height - t.spec.width
                r.tail = prev
                t = prev
            else
                break
            end
        end
        if r.height > height then
            height = r.height
        end
    end
    return height
end

local function setsplit(specification) -- a rather large function
    local box = specification.box
    if not box then
        report_state("fatal error, no box")
        return
    end
    local list = texbox[box]
    if not list then
        report_state("fatal error, no list")
        return
    end
    local head = list.head or specification.originalhead
    if not head then
        report_state("fatal error, no head")
        return
    end
    local discarded = { }
    local originalhead = head
    local originalwidth = specification.originalwidth or list.width
    local originalheight = specification.originalheight or list.height
    local current = head
    local height = 0
    local depth = 0
    local skip = 0
    local options = settings_to_hash(specification.option or "")
    local stripbottom = specification.alternative == v_local
    local cycle = specification.cycle or 1
    local nofcolumns = specification.nofcolumns or 1
    if nofcolumns == 0 then
        nofcolumns = 1
    end
    local preheight = specification.preheight or 0
    local extra = specification.extra or 0
    local maxheight = specification.maxheight
    local optimal = originalheight/nofcolumns
    if specification.balance ~= v_yes then
        optimal = maxheight
    end
    local target = optimal + extra
    local overflow = target > maxheight - preheight
    local threshold = specification.threshold or 0
    if overflow then
        target = maxheight - preheight
    end
    if trace_state then
        report_state("cycle: %s, maxheight: %s, preheight: %s, target: %s, overflow: %s, extra: %s",
            cycle, points(maxheight),points(preheight),points(target),tostring(overflow),points(extra))
    end
    local results = { }
    for i=1,nofcolumns do
        results[i] = {
            head    = false,
            tail    = false,
            height  = 0,
            depth   = 0,
            inserts = { },
            delta   = 0,
        }
    end
    local column = 1
    local result = results[column]
    local lasthead = nil
    local rest = nil
    local function gotonext()
        if head == lasthead then
            if trace_state then
                report_state("empty column %s, needs more work",column)
            end
rest = current
return false
        else
            lasthead = head
            result.head = head
            if current == head then
                result.tail = head
            else
                result.tail = current.prev
            end
            result.height = height
            result.depth  = depth
        end
        head   = current
        height = 0
        depth  = 0
        skip   = 0
        if column == nofcolumns then
            column = 0 -- nicer in trace
            rest = head
-- lasthead = head
            return false
        else
            column = column + 1
            result = results[column]
            current = discardtopglue(current,discarded)
            head = current
-- lasthead = head
            return true
        end
    end
    local function checked(advance)
        local total = skip + height + depth + advance
        local delta = total - target
        if trace_detail then
            local currentcolumn = column
            local state
            if delta > threshold then
                result.delta = delta
                if gotonext() then
                    state = "next"
                else
                    state = "quit"
                end
            else
                state = "same"
            end
            if trace_detail then
                report_state("check  > column %s, advance: %s, total: %s, target: %s => %s (height: %s, depth: %s, skip: %s)",
                    currentcolumn,points(advance),points(total),points(target),state,points(height),points(depth),points(skip))
            end
            return state
        else
            if delta > threshold then
                result.delta = delta
                if gotonext() then
                    return "next"
                else
                    return "quit"
                end
            else
                return "same"
            end
        end
    end
    current = discardtopglue(current,discarded)
    head = current
    while current do
        local id = current.id
        local nxt = current.next
        if id == hlist_code or id == vlist_code then
            local nxtid = nxt and nxt.id
            local inserts, currentskips, nextskips, inserttotal = nil, 0, 0, 0
            local advance = current.height -- + current.depth
            if nxt and (nxtid == insert_code or nxtid == mark_code) then
                nxt, inserts, localskips, insertskips, inserttotal = collectinserts(result,nxt,nxtid)
            end
            local state = checked(advance+inserttotal+currentskips)
            if trace_state then
                report_state('line   > column %s, advance: %s, insert: %s, height: %s, state: %s',
                    column,points(advance),points(inserttotal),points(height),state)
            end
            if state == "quit" then
                break
            else
                height = height + depth + skip + advance + inserttotal
                if state == "next" then
                    height = height + nextskips
                else
                    height = height + currentskips
                end
            end
            depth = current.depth
            skip  = 0
            if inserts then
                appendinserts(result.inserts,inserts)
            end
        elseif id == glue_code then
            local advance = current.spec.width
            if advance ~= 0 then
                local state = checked(advance)
                if trace_state then
                    report_state('glue   > column %s, advance: %s, height: %s, state: %s',
                        column,points(advance),points(height),state)
                end
                if state == "quit" then
                    break
                end
                height = height + depth + skip
                depth  = 0
                skip   = height > 0 and advance or 0
            end
        elseif id == kern_code then
            local advance = current.kern
            if advance ~= 0 then
                local state = checked(advance)
                if trace_state then
                    report_state('kern   > column %s, advance: %s, height: %s, state: %s',
                        column,points(advance),points(height),state)
                end
                if state == "quit" then
                    break
                end
                height = height + depth + skip + advance
                depth  = 0
                skip   = 0
            end
        elseif id == penalty_code then
            local penalty = current.penalty
            if penalty == 0 then
                -- don't bother
            elseif penalty == forcedbreak then
                if gotonext() then
                    if trace_state then
                        report_state("cycle: %s, forced column break (same page)",cycle)
                    end
                else
                    if trace_state then
                        report_state("cycle: %s, forced column break (next page)",cycle)
                    end
                    break
                end
            else
                -- todo: nobreak etc ... we might need to backtrack so we need to remember
                -- the last acceptable break
                -- club and widow and such i.e. resulting penalties (if we care)
            end
        end
        if nxt then
            current = nxt
        elseif head == lasthead then
            -- to be checked but break needed as otherwise we have a loop
            if trace_state then
                report_state("quit as head is lasthead")
            end
            break
        else
            local r = results[column]
            r.head   = head
            r.tail   = current
            r.height = height
            r.depth  = depth
            break
        end
    end
    if not current then
        if trace_state then
            report_state("nilling rest")
        end
        rest = nil
     elseif rest == lasthead then
        if trace_state then
            report_state("nilling rest as rest is lasthead")
        end
        rest = nil
    end

    if stripbottom then
        local height = stripbottomglue(results,discarded)
        if height > 0 then
            target = height
        end
    end

    specification.results        = results
    specification.height         = target
    specification.originalheight = originalheight
    specification.originalwidth  = originalwidth
    specification.originalhead   = originalhead
    specification.targetheight   = target or 0
    specification.rest           = rest
    specification.overflow       = overflow
    specification.discarded      = discarded

    texbox[specification.box].head = nil

    return specification
end

function mixedcolumns.finalize(result)
    if result then
        local results = result.results
        for i=1,result.nofcolumns do
            local r = results[i]
            local h = r.head
            if h then
                h.prev = nil
                local t = r.tail
                if t then
                    t.next = nil
                else
                    h.next = nil
                    r.tail = h
                end
                for c, list in next, r.inserts do
                    local t = { }
                    for i=1,#list do
                        local l = list[i]
                        local h = new_hlist()
                        t[i] = h
                        h.head = l.head
                        h.height = l.height
                        h.depth = l.depth
                        l.head = nil
                    end
                    t[1].prev  = nil -- needs checking
                    t[#t].next = nil -- needs checking
                    r.inserts[c] = t
                end
            end
        end
    end
end

local splitruns = 0

local function report_deltas(result,str)
    local t = { }
    for i=1,result.nofcolumns do
        t[#t+1] = points(result.results[i].delta or 0)
    end
    report_state("%s, cycles: %s, deltas: %s",str,result.cycle or 1,concat(t," | "))
end

function mixedcolumns.setsplit(specification)
    splitruns = splitruns + 1
    if trace_state then
        report_state("split run %s",splitruns)
    end
    local result = setsplit(specification)
    if result then
        if result.overflow then
            if trace_state then
                report_deltas(result,"overflow")
            end
            -- we might have some rest
        elseif result.rest and specification.balance == v_yes then
            local step = specification.step or 65536*2
            local cycle = 1
            local cycles = specification.cycles or 100
            while result.rest and cycle <= cycles do
                specification.extra = cycle * step
                result = setsplit(specification) or result
                if trace_state then
                    report_state("cycle: %s.%s, original height: %s, total height: %s",
                        splitruns,cycle,points(result.originalheight),points(result.nofcolumns*result.targetheight))
                end
                cycle = cycle + 1
                specification.cycle = cycle
            end
            if cycle > cycles then
                report_deltas(result,"too many balancing cycles")
            elseif trace_state then
                report_deltas(result,"balanced")
            end
        elseif trace_state then
            report_deltas(result,"done")
        end
        return result
    elseif trace_state then
        report_state("no result")
    end
end

local topskip_code      = gluecodes.topskip
local baselineskip_code = gluecodes.baselineskip

function mixedcolumns.getsplit(result,n)
    if not result then
        report_state("flush, column: %s, no result",n)
        return
    end
    local r = result.results[n]
    if not r then
        report_state("flush, column: %s, empty",n)
    end
    local h = r.head
    if not h then
        return new_glue(result.originalwidth)
    end

    if trace_state then
        local id = h.id
        if id == hlist_code then
            report_state("flush, column: %s, top line: %s",n,nodes.toutf(h.list))
        else
            report_state("flush, column: %s, head node: %s",n,nodecodes[id])
        end
    end

    h.prev = nil -- move up
    local strutht    = result.strutht
    local strutdp    = result.strutdp
    local lineheight = strutht + strutdp

    local v = new_vlist()
    v.head = h

 -- local v = vpack(h,"exactly",height)

    v.width  = result.originalwidth
    if result.alternative == v_global then -- option
        result.height = result.maxheight
    end
    v.height = lineheight * math.ceil(result.height/lineheight) - strutdp
    v.depth  = strutdp

    for c, list in next, r.inserts do
    --     tex.setbox("global",c,vpack(nodes.concat(list)))
    --     tex.setbox(c,vpack(nodes.concat(list)))
        texbox[c] = vpack(nodes.concat(list))
        r.inserts[c] = nil
    end
    return v
end

function mixedcolumns.getrest(result)
    local rest = result and result.rest
    result.rest = nil -- to be sure
    return rest
end

function mixedcolumns.getlist(result)
    local originalhead = result and result.originalhead
    result.originalhead = nil -- to be sure
    return originalhead
end

function mixedcolumns.cleanup(result)
    local discarded = result.discarded
    for i=1,#discarded do
        freenode(discarded[i])
    end
end

-- interface --

local result

function commands.mixsetsplit(specification)
    if result then
        for k, v in next, specification do
            result[k] = v
        end
        result = mixedcolumns.setsplit(result)
    else
        result = mixedcolumns.setsplit(specification)
    end
end

function commands.mixgetsplit(n)
    if result then
        context(mixedcolumns.getsplit(result,n))
    end
end

function commands.mixfinalize()
    if result then
        mixedcolumns.finalize(result)
    end
end

function commands.mixflushrest()
    if result then
        context(mixedcolumns.getrest(result))
    end
end

function commands.mixflushlist()
    if result then
        context(mixedcolumns.getlist(result))
    end
end

function commands.mixstate()
    context(result and result.rest and 1 or 0)
end

function commands.mixcleanup()
    if result then
        mixedcolumns.cleanup(result)
        result = nil
    end
end
