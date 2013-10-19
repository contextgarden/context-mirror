if not modules then modules = { } end modules ["page-mix"] = {
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
    local size = 0
    while current do
        local id = current.id
        if id == glue_code then
            size = size + current.spec.width
            discarded[#discarded+1] = current
            current = current.next
        elseif id == penalty_code then
            if current.penalty == forcedbreak then
                discarded[#discarded+1] = current
                current = current.next
                while current do
                    local id = current.id
                    if id == glue_code then
                        size = size + current.spec.width
                        discarded[#discarded+1] = current
                        current = current.next
                    else
                        break
                    end
                end
            else
                discarded[#discarded+1] = current
                current = current.next
            end
        else
            break
        end
    end
    return current, size
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
            end
            local id = t.id
            if id == penalty_code then
                if t.penalty == forcedbreak then
                    break
                else
                    discarded[#discarded+1] = t
                    r.tail = prev
                    t = prev
                end
            elseif id == glue_code then
                discarded[#discarded+1] = t
                local width = t.spec.width
                if trace_state then
                    report_state("columns %s, discarded bottom glue %p",i,width)
                end
                r.height = r.height - width
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
    local skipped = 0
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
        report_state("cycle %s, maxheight %p, preheight %p, target %p, overflow %a, extra %p",
            cycle, maxheight, preheight , target, overflow, extra)
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
    local column   = 1
    local line     = 0
    local result   = results[column]
    local lasthead = nil
    local rest     = nil
    local function gotonext()
        if head == lasthead then
            if trace_state then
                report_state("empty column %s, needs more work",column)
            end
            rest = current
            return false, 0
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
        head    = current
        height  = 0
        depth   = 0
        if column == nofcolumns then
            column = 0 -- nicer in trace
            rest = head
         -- lasthead = head
            return false, 0
        else
            local skipped
            column = column + 1
            result = results[column]
            current, skipped = discardtopglue(current,discarded)
            head = current
         -- lasthead = head
            return true, skipped
        end
    end
    local function checked(advance,where)
        local total   = skip + height + depth + advance
        local delta   = total - target
        local state   = "same"
        local okay    = false
        local skipped = 0
        local curcol  = column
        if delta > threshold then
            result.delta = delta
            okay, skipped = gotonext()
            if okay then
                state = "next"
            else
                state = "quit"
            end
        end
        if trace_detail then
            report_state("%-7s > column %s, delta %p, threshold %p, advance %p, total %p, target %p, discarded %p => %a (height %p, depth %p, skip %p)",
                where,curcol,delta,threshold,advance,total,target,state,skipped,height,depth,skip)
        end
        return state, skipped
    end
    current, skipped = discardtopglue(current,discarded)
    if trace_detail and skipped ~= 0 then
        report_state("check > column 1, discarded %p",skipped)
    end
    head = current
    while current do
        local id = current.id
        local nxt = current.next
local lastcolumn = column
        if id == hlist_code or id == vlist_code then
            line = line + 1
            local nxtid = nxt and nxt.id
            local inserts, currentskips, nextskips, inserttotal = nil, 0, 0, 0
            local advance = current.height -- + current.depth
            if nxt and (nxtid == insert_code or nxtid == mark_code) then
                nxt, inserts, localskips, insertskips, inserttotal = collectinserts(result,nxt,nxtid)
            end
            local state, skipped = checked(advance+inserttotal+currentskips,"line")
            if trace_state then
                report_state("%-7s > column %s, state %a, line %s, advance %p, insert %p, height %p","line",column,state,line,advance,inserttotal,height)
                if skipped ~= 0 then
                    report_state("%-7s > column %s, discarded %p","line",column,skipped)
                end
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
                local state, skipped = checked(advance,"glue")
                if trace_state then
                    report_state("%-7s > column %s, state %a, advance %p, height %p","glue",column,state,advance,height)
                    if skipped ~= 0 then
                        report_state("%-7s > column %s, discarded %p","glue",column,skipped)
                    end
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
                local state, skipped = checked(advance,"kern")
                if trace_state then
                    report_state("%-7s > column %s, state %a, advance %p, height %p, state %a","kern",column,state,advance,height)
                    if skipped ~= 0 then
                        report_state("%-7s > column %s, discarded %p","kern",column,skipped)
                    end
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
                local okay, skipped = gotonext()
                if okay then
                    if trace_state then
                        report_state("cycle: %s, forced column break (same page)",cycle)
                        if skipped ~= 0 then
                            report_state("%-7s > column %s, discarded %p","penalty",column,skipped)
                        end
                    end
                else
                    if trace_state then
                        report_state("cycle: %s, forced column break (next page)",cycle)
                        if skipped ~= 0 then
                            report_state("%-7s > column %s, discarded %p","penalty",column,skipped)
                        end
                    end
                    break
                end
            else
                -- todo: nobreak etc ... we might need to backtrack so we need to remember
                -- the last acceptable break
                -- club and widow and such i.e. resulting penalties (if we care)
            end
        end
if lastcolumn == column then
        nxt = current.next -- can have changed
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
    report_state("%s, cycles %s, deltas % | t",str,result.cycle or 1,t)
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
                    report_state("cycle: %s.%s, original height %p, total height %p",
                        splitruns,cycle,result.originalheight,result.nofcolumns*result.targetheight)
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
        report_state("flush, column %s, no result",n)
        return
    end
    local r = result.results[n]
    if not r then
        report_state("flush, column %s, empty",n)
    end
    local h = r.head
    if not h then
        return new_glue(result.originalwidth)
    end

    h.prev = nil -- move up
    local strutht    = result.strutht
    local strutdp    = result.strutdp
    local lineheight = strutht + strutdp

    local v = new_vlist()
    v.head = h

 -- local v = vpack(h,"exactly",height)

    if result.alternative == v_global then -- option
        result.height = result.maxheight
    end

    local ht = 0
    local dp = 0
    local wd = result.originalwidth

    local grid = result.grid

    if grid then
        ht = lineheight * math.ceil(result.height/lineheight) - strutdp
        dp = strutdp
    else
        ht = result.height
        dp = result.depth
    end

    v.width  = wd
    v.height = ht
    v.depth  = dp

    if trace_state then
        local id = h.id
        if id == hlist_code then
            report_state("flush, column %s, grid %a, width %p, height %p, depth %p, %s: %s",n,grid,wd,ht,dp,"top line",nodes.toutf(h.list))
        else
            report_state("flush, column %s, grid %a, width %p, height %p, depth %p, %s: %s",n,grid,wd,ht,dp,"head node",nodecodes[id])
        end
    end

    for c, list in next, r.inserts do
     -- tex.setbox("global",c,vpack(nodes.concat(list)))
     -- tex.setbox(c,vpack(nodes.concat(list)))
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
    result.discarded = { }
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
