if not modules then modules = { } end modules ['node-tra'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is rather experimental. We need more control and some of this
might become a runtime module instead. This module will be cleaned up!</p>
--ldx]]--

local utfchar = utf.char
local format, match, gmatch, concat, rep = string.format, string.match, string.gmatch, table.concat, string.rep
local lpegmatch = lpeg.match
local clock = os.gettimeofday or os.clock -- should go in environment

local report_nodes = logs.reporter("nodes","tracing")

nodes = nodes or { }

local nodes, node, context = nodes, node, context

local tracers          = nodes.tracers or { }
nodes.tracers          = tracers

local tasks            = nodes.tasks or { }
nodes.tasks            = tasks

local handlers         = nodes.handlers or {}
nodes.handlers         = handlers

local injections       = nodes.injections or { }
nodes.injections       = injections

local traverse_nodes   = node.traverse
local traverse_by_id   = node.traverse_id
local count_nodes      = nodes.count

local nodecodes        = nodes.nodecodes
local whatcodes        = nodes.whatcodes
local skipcodes        = nodes.skipcodes
local fillcodes        = nodes.fillcodes

local glyph_code       = nodecodes.glyph
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local disc_code        = nodecodes.disc
local glue_code        = nodecodes.glue
local kern_code        = nodecodes.kern
local rule_code        = nodecodes.rule
local whatsit_code     = nodecodes.whatsit
local spec_code        = nodecodes.glue_spec

local localpar_code    = whatcodes.localpar
local dir_code         = whatcodes.dir

local nodepool         = nodes.pool

local dimenfactors     = number.dimenfactors
local formatters       = string.formatters

-- this will be reorganized:

function nodes.showlist(head, message)
    if message then
        report_nodes(message)
    end
    for n in traverse_nodes(head) do
        report_nodes(tostring(n))
    end
end

function nodes.handlers.checkglyphs(head,message)
    local t = { }
    for g in traverse_by_id(glyph_code,head) do
        t[#t+1] = formatters["%U:%s"](g.char,g.subtype)
    end
    if #t > 0 then
        if message and message ~= "" then
            report_nodes("%s, %s glyphs: % t",message,#t,t)
        else
            report_nodes("%s glyphs: % t",#t,t)
        end
    end
    return false
end

function nodes.handlers.checkforleaks(sparse)
    local l = { }
    local q = node.usedlist()
    for p in traverse(q) do
        local s = table.serialize(nodes.astable(p,sparse),nodecodes[p.id])
        l[s] = (l[s] or 0) + 1
    end
    node.flush_list(q)
    for k, v in next, l do
        write_nl(formatters["%s * %s"](v,k))
    end
end

local f_sequence = formatters["U+%04X:%s"]

local function tosequence(start,stop,compact)
    if start then
        local t = { }
        while start do
            local id = start.id
            if id == glyph_code then
                local c = start.char
                if compact then
                    if start.components then
                        t[#t+1] = tosequence(start.components,nil,compact)
                    else
                        t[#t+1] = utfchar(c)
                    end
                else
                    t[#t+1] = f_sequence(c,utfchar(c))
                end
            elseif id == whatsit_code and start.subtype == localpar_code or start.subtype == dir_code then
                t[#t+1] = "[" .. start.dir .. "]"
            elseif id == rule_code then
                if compact then
                    t[#t+1] = "|"
                else
                    t[#t+1] = nodecodes[id]
                end
            else
                if compact then
                    t[#t+1] = "[]"
                else
                    t[#t+1] = nodecodes[id]
                end
            end
            if start == stop then
                break
            else
                start = start.next
            end
        end
        if compact then
            return concat(t)
        else
            return concat(t," ")
        end
    else
        return "[empty]"
    end
end

nodes.tosequence = tosequence

function nodes.report(t,done)
    report_nodes("output %a, %changed %a, %s nodes",status.output_active,done,count_nodes(t))
end

function nodes.packlist(head)
    local t = { }
    for n in traverse(head) do
        t[#t+1] = tostring(n)
    end
    return t
end

function nodes.idstostring(head,tail)
    local t, last_id, last_n = { }, nil, 0
    for n in traverse_nodes(head,tail) do -- hm, does not stop at tail
        local id = n.id
        if not last_id then
            last_id, last_n = id, 1
        elseif last_id == id then
            last_n = last_n + 1
        else
            if last_n > 1 then
                t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
            else
                t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
            end
            last_id, last_n = id, 1
        end
        if n == tail then
            break
        end
    end
    if not last_id then
        t[#t+1] = "no nodes"
    elseif last_n > 1 then
        t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
    else
        t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
    end
    return concat(t," ")
end

-- function nodes.xidstostring(head,tail) -- only for special tracing of backlinks
--     local n = head
--     while n.next do
--         n = n.next
--     end
--     local t, last_id, last_n = { }, nil, 0
--     while n do
--         local id = n.id
--         if not last_id then
--             last_id, last_n = id, 1
--         elseif last_id == id then
--             last_n = last_n + 1
--         else
--             if last_n > 1 then
--                 t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
--             else
--                 t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
--             end
--             last_id, last_n = id, 1
--         end
--         if n == head then
--             break
--         end
--         n = n.prev
--     end
--     if not last_id then
--         t[#t+1] = "no nodes"
--     elseif last_n > 1 then
--         t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
--     else
--         t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
--     end
--     return table.concat(table.reversed(t)," ")
-- end

local function showsimplelist(h,depth,n)
    while h do
        write_nl(rep(" ",n) .. tostring(h))
        if not depth or n < depth then
            local id = h.id
            if id == hlist_code or id == vlist_code then
                showsimplelist(h.list,depth,n+1)
            end
        end
        h = h.next
    end
end

--~ \startluacode
--~ callback.register('buildpage_filter',function() nodes.show_simple_list(tex.lists.contrib_head) end)
--~ \stopluacode
--~ \vbox{b\footnote{n}a}
--~ \startluacode
--~ callback.register('buildpage_filter',nil)
--~ \stopluacode

nodes.showsimplelist = function(h,depth) showsimplelist(h,depth,0) end

local function listtoutf(h,joiner,textonly,last)
    local joiner = (joiner == true and utfchar(0x200C)) or joiner -- zwnj
    local w = { }
    while h do
        local id = h.id
        if id == glyph_code then -- always true
            w[#w+1] = utfchar(h.char)
            if joiner then
                w[#w+1] = joiner
            end
        elseif id == disc_code then
            local pre, rep, pos = h.pre, h.replace, h.post
            w[#w+1] = formatters["[%s|%s|%s]"] (
                pre and listtoutf(pre,joiner,textonly) or "",
                rep and listtoutf(rep,joiner,textonly) or "",
                mid and listtoutf(mid,joiner,textonly) or ""
            )
        elseif textonly then
            if id == glue_code and h.spec and h.spec.width > 0 then
                w[#w+1] = " "
            end
        else
            w[#w+1] = "[-]"
        end
        if h == last then
            break
        else
            h = h.next
        end
    end
    return concat(w)
end

nodes.listtoutf = listtoutf

local what = { [0] = "unknown", "line", "box", "indent", "row", "cell" }

local function showboxes(n,symbol,depth)
    depth, symbol = depth or 0, symbol or "."
    for n in traverse_nodes(n) do
        local id = n.id
        if id == hlist_code or id == vlist_code then
            local s = n.subtype
            report_nodes(rep(symbol,depth) .. what[s] or s)
            showboxes(n.list,symbol,depth+1)
        end
    end
end

nodes.showboxes = showboxes

local ptfactor = dimenfactors.pt
local bpfactor = dimenfactors.bp
local stripper = lpeg.patterns.stripzeros

-- start redefinition
--
-- -- if fmt then
-- --     return formatters[fmt](n*dimenfactors[unit],unit)
-- -- else
-- --     return match(formatters["%.20f"](n*dimenfactors[unit]),"(.-0?)0*$") .. unit
-- -- end
--
-- redefined:

local dimenfactors = number.dimenfactors

local function numbertodimen(d,unit,fmt,strip)
    if not d then
        local str = formatters[fmt](0,unit)
        return strip and lpegmatch(stripper,str) or str
    end
    local t = type(d)
    if t == 'string' then
        return d
    end
    if unit == true then
        unit = "pt"
        fmt  = "%0.5f%s"
    else
        unit = unit or 'pt'
        if not fmt then
            fmt = "%s%s"
        elseif fmt == true then
            fmt = "%0.5f%s"
        end
    end
    if t == "number" then
        local str = formatters[fmt](d*dimenfactors[unit],unit)
        return strip and lpegmatch(stripper,str) or str
    end
    local id = node.id
    if id == kern_code then
        local str = formatters[fmt](d.width*dimenfactors[unit],unit)
        return strip and lpegmatch(stripper,str) or str
    end
    if id == glue_code then
        d = d.spec
    end
    if not d or not d.id == spec_code then
        local str = formatters[fmt](0,unit)
        return strip and lpegmatch(stripper,str) or str
    end
    local width   = d.width
    local plus    = d.stretch_order
    local minus   = d.shrink_order
    local stretch = d.stretch
    local shrink  = d.shrink
    if plus ~= 0 then
        plus = " plus " .. stretch/65536 .. fillcodes[plus]
    elseif stretch ~= 0 then
        plus = formatters[fmt](stretch*dimenfactors[unit],unit)
        plus = " plus " .. (strip and lpegmatch(stripper,plus) or plus)
    else
        plus = ""
    end
    if minus ~= 0 then
        minus = " minus " .. shrink/65536 .. fillcodes[minus]
    elseif shrink ~= 0 then
        minus = formatters[fmt](shrink*dimenfactors[unit],unit)
        minus = " minus " .. (strip and lpegmatch(stripper,minus) or minus)
    else
        minus = ""
    end
    local str = formatters[fmt](d.width*dimenfactors[unit],unit)
    return (strip and lpegmatch(stripper,str) or str) .. plus .. minus
end

number.todimen = numbertodimen

function number.topoints      (n,fmt) return numbertodimen(n,"pt",fmt) end
function number.toinches      (n,fmt) return numbertodimen(n,"in",fmt) end
function number.tocentimeters (n,fmt) return numbertodimen(n,"cm",fmt) end
function number.tomillimeters (n,fmt) return numbertodimen(n,"mm",fmt) end
function number.toscaledpoints(n,fmt) return numbertodimen(n,"sp",fmt) end
function number.toscaledpoints(n)     return            n .. "sp"      end
function number.tobasepoints  (n,fmt) return numbertodimen(n,"bp",fmt) end
function number.topicas       (n,fmt) return numbertodimen(n "pc",fmt) end
function number.todidots      (n,fmt) return numbertodimen(n,"dd",fmt) end
function number.tociceros     (n,fmt) return numbertodimen(n,"cc",fmt) end
function number.tonewdidots   (n,fmt) return numbertodimen(n,"nd",fmt) end
function number.tonewciceros  (n,fmt) return numbertodimen(n,"nc",fmt) end

-- stop redefinition

local points = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fpt",n*ptfactor)) -- faster than formatter
    else
        return numbertodimen(n,"pt",true,true) -- also deals with nodes
    end
end

local basepoints = function(n)
    if not n or n == 0 then
        return "0bp"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fbp",n*bpfactor)) -- faster than formatter
    else
        return numbertodimen(n,"bp",true,true) -- also deals with nodes
    end
end

local pts = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return format("%.5fpt",n*ptfactor) -- faster than formatter
    else
        return numbertodimen(n,"pt",true) -- also deals with nodes
    end
end

local nopts = function(n)
    if not n or n == 0 then
        return "0"
    else
        return format("%.5f",n*ptfactor) -- faster than formatter
    end
end

number.points     = points
number.basepoints = basepoints
number.pts        = pts
number.nopts      = nopts

local colors   = { }
tracers.colors = colors

local unsetvalue      = attributes.unsetvalue

local a_color         = attributes.private('color')
local a_colormodel    = attributes.private('colormodel')
local m_color         = attributes.list[a_color] or { }

function colors.set(n,c,s)
    local mc = m_color[c]
    if not mc then
        n[a_color] = unsetvalue
    else
        if not n[a_colormodel] then
            n[a_colormodel] = s or 1
        end
        n[a_color] = mc
    end
    return n
end

function colors.setlist(n,c,s)
    local f = n
    while n do
        local mc = m_color[c]
        if not mc then
            n[a_color] = unsetvalue
        else
            if not n[a_colormodel] then
                n[a_colormodel] = s or 1
            end
            n[a_color] = mc
        end
        n = n.next
    end
    return f
end

function colors.reset(n)
    n[a_color] = unsetvalue
    return n
end

-- maybe

local transparencies   = { }
tracers.transparencies = transparencies

local a_transparency   = attributes.private('transparency')
local m_transparency   = attributes.list[a_transparency] or { }

function transparencies.set(n,t)
    local mt = m_transparency[t]
    if not mt then
        n[a_transparency] = unsetvalue
    else
        n[a_transparency] = mt
    end
    return n
end

function transparencies.setlist(n,c,s)
    local f = n
    while n do
        local mt = m_transparency[c]
        if not mt then
            n[a_transparency] = unsetvalue
        else
            n[a_transparency] = mt
        end
        n = n.next
    end
    return f
end

function transparencies.reset(n)
    n[a_transparency] = unsetvalue
    return n
end

-- for the moment here

nodes.visualizers = { }

function nodes.visualizers.handler(head)
    return head, false
end

-- also moved here

local snapshots  = { }
nodes.snapshots  = snapshots

local nodeusage  = nodepool.usage

local lasttime   = clock()
local samples    = { }
local parameters = {
    "cs_count",
    "dyn_used",
    "elapsed_time",
    "luabytecode_bytes",
    "luastate_bytes",
    "max_buf_stack",
    "obj_ptr",
    "pdf_mem_ptr",
    "pdf_mem_size",
    "pdf_os_cntr",
--  "pool_ptr", -- obsolete
    "str_ptr",
}

function snapshots.takesample(comment)
    local c = clock()
    local t = {
        elapsed_time = c - lasttime,
        node_memory  = nodeusage(),
        comment      = comment,
    }
    for i=1,#parameters do
        local parameter = parameters[i]
        local ps = status[parameter]
        if ps then
            t[parameter] = ps
        end
    end
    samples[#samples+1] = t
    lasttime = c
end

function snapshots.getsamples()
    return samples -- one return value !
end

function snapshots.resetsamples()
    samples = { }
end

function snapshots.getparameters()
    return parameters
end
