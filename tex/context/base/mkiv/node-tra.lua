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

local nodes, node, context = nodes, node, context

local texgetattribute  = tex.getattribute

local tracers          = nodes.tracers or { }
nodes.tracers          = tracers

local tasks            = nodes.tasks or { }
nodes.tasks            = tasks

local handlers         = nodes.handlers or {}
nodes.handlers         = handlers

local injections       = nodes.injections or { }
nodes.injections       = injections

local nuts             = nodes.nuts
local tonut            = nuts.tonut
local tonode           = nuts.tonode

local getfield         = nuts.getfield
local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getchar          = nuts.getchar
local getsubtype       = nuts.getsubtype
local getlist          = nuts.getlist
local getdisc          = nuts.getdisc
local setattr          = nuts.setattr
local isglyph          = nuts.isglyph

local flush_list       = nuts.flush_list
local count_nodes      = nuts.count
local used_nodes       = nuts.usedlist

local traverse_by_id   = nuts.traverse_id
local traverse_nodes   = nuts.traverse
local d_tostring       = nuts.tostring

local nutpool          = nuts.pool
local new_rule         = nutpool.rule

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
local dir_code         = nodecodes.dir
local localpar_code    = nodecodes.localpar
local whatsit_code     = nodecodes.whatsit

local dimenfactors     = number.dimenfactors
local fillorders       = nodes.fillcodes
local formatters       = string.formatters

-- this will be reorganized:

function nodes.showlist(head, message)
    if message then
        report_nodes(message)
    end
    for n in traverse_nodes(tonut(head)) do
        report_nodes(d_tostring(n))
    end
end

function nodes.handlers.checkglyphs(head,message)
    local h = tonut(head)
    local t = { }
    for g in traverse_by_id(glyph_code,h) do
        t[#t+1] = formatters["%U:%s"](getchar(g),getsubtype(g))
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
    local q = used_nodes()
    for p in traverse_nodes(q) do
        local s = table.serialize(nodes.astable(p,sparse),nodecodes[getid(p)])
        l[s] = (l[s] or 0) + 1
    end
    flush_list(q)
    for k, v in next, l do
        report_nodes("%s * %s",v,k)
    end
end

local f_sequence = formatters["U+%04X:%s"]

local function tosequence(start,stop,compact)
    if start then
        start = tonut(start)
        stop = stop and tonut(stop)
        local t = { }
        while start do
            local c, id = isglyph(start)
            if c then
                if compact then
                    local components = getfield(start,"components")
                    if components then
                        t[#t+1] = tosequence(components,nil,compact)
                    else
                        t[#t+1] = utfchar(c)
                    end
                else
                    t[#t+1] = f_sequence(c,utfchar(c))
                end
            elseif id == rule_code then
                if compact then
                    t[#t+1] = "|"
                else
                    t[#t+1] = nodecodes[id]
                end
            elseif id == dir_code or id == localpar_code then
                t[#t+1] = "[" .. getfield(start,"dir") .. "]"
            elseif compact then
                t[#t+1] = "[]"
            else
                t[#t+1] = nodecodes[id]
            end
            if start == stop then
                break
            else
                start = getnext(start)
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
nuts .tosequence = tosequence

function nodes.report(t,done)
    report_nodes("output %a, changed %a, %s nodes",status.output_active,done,count_nodes(tonut(t)))
end

function nodes.packlist(head)
    local t = { }
    for n in traverse_nodes(tonut(head)) do
        t[#t+1] = d_tostring(n)
    end
    return t
end

function nodes.idstostring(head,tail)
    head = tonut(head)
    tail = tail and tonut(tail)
    local t       = { }
    local last_id = nil
    local last_n  = 0
    for n in traverse_nodes(head,tail) do -- hm, does not stop at tail
        local id = getid(n)
        if id == whatsit_code then
            id = whatcodes[getsubtype(n)]
        else
            id = nodecodes[id]
        end
        if not last_id then
            last_id = id
            last_n  = 1
        elseif last_id == id then
            last_n = last_n + 1
        else
            if last_n > 1 then
                t[#t+1] = formatters["[%s*%s]"](last_n,last_id)
            else
                t[#t+1] = formatters["[%s]"](last_id)
            end
            last_id = id
            last_n  = 1
        end
        if n == tail then
            break
        end
    end
    if not last_id then
        t[#t+1] = "no nodes"
    else
        if last_n > 1 then
            t[#t+1] = formatters["[%s*%s]"](last_n,last_id)
        else
            t[#t+1] = formatters["[%s]"](last_id)
        end
    end
    return concat(t," ")
end

-- function nodes.xidstostring(head,tail) -- only for special tracing of backlinks
--     head = tonut(head)
--     tail = tonut(tail)
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
--         n = getprev(n)
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
    h = h and tonut(h)
    while h do
        report_nodes("% w%s",n,d_tostring(h))
        if not depth or n < depth then
            local id = getid(h)
            if id == hlist_code or id == vlist_code then
                showsimplelist(getlist(h),depth,n+1)
            end
        end
        h = getnext(h)
    end
end

-- \startluacode
-- callbacks.register('buildpage_filter',function() nodes.show_simple_list(tex.lists.contrib_head) end)
-- \stopluacode
-- \vbox{b\footnote{n}a}
-- \startluacode
-- callbacks.register('buildpage_filter',nil)
-- \stopluacode

nodes.showsimplelist = function(h,depth) showsimplelist(h,depth,0) end

local function listtoutf(h,joiner,textonly,last,nodisc)
    local w = { }
    while h do
        local c, id = isglyph(h)
        if c then
            w[#w+1] = c >= 0 and utfchar(c) or formatters["<%i>"](c)
            if joiner then
                w[#w+1] = joiner
            end
        elseif id == disc_code then
            local pre, pos, rep = getdisc(h)
            if not nodisc then
                w[#w+1] = formatters["[%s|%s|%s]"] (
                    pre and listtoutf(pre,joiner,textonly) or "",
                    pos and listtoutf(pos,joiner,textonly) or "",
                    rep and listtoutf(rep,joiner,textonly) or ""
                )
            elseif rep then
                w[#w+1] = listtoutf(rep,joiner,textonly) or ""
            end
        elseif textonly then
            if id == glue_code then
                if getfield(h,"width") > 0 then
                    w[#w+1] = " "
                end
            elseif id == hlist_code or id == vlist_code then
                w[#w+1] = "[]"
            end
        else
            w[#w+1] = "[-]"
        end
        if h == last then
            break
        else
            h = getnext(h)
        end
    end
    return concat(w)
end

function nodes.listtoutf(h,joiner,textonly,last,nodisc)
    if h then
        local joiner = joiner == true and utfchar(0x200C) or joiner -- zwnj
        return listtoutf(tonut(h),joiner,textonly,last and tonut(last),nodisc)
    else
        return ""
    end
end

local what = { [0] = "unknown", "line", "box", "indent", "row", "cell" }

local function showboxes(n,symbol,depth)
    depth  = depth  or 0
    symbol = symbol or "."
    for n in traverse_nodes(tonut(n)) do
        local id = getid(n)
        if id == hlist_code or id == vlist_code then
            local s = getsubtype(n)
            report_nodes(rep(symbol,depth) .. what[s] or s)
            showboxes(getlist(n),symbol,depth+1)
        end
    end
end

nodes.showboxes = showboxes

local ptfactor = dimenfactors.pt
local bpfactor = dimenfactors.bp
local stripper = lpeg.patterns.stripzeros

local f_f_f = formatters["%0.5Fpt plus %0.5F%s minus %0.5F%s"]
local f_f_m = formatters["%0.5Fpt plus %0.5F%s minus %0.5Fpt"]
local f_p_f = formatters["%0.5Fpt plus %0.5Fpt minus %0.5F%s"]
local f_p_m = formatters["%0.5Fpt plus %0.5Fpt minus %0.5Fpt"]
local f_f_z = formatters["%0.5Fpt plus %0.5F%s"]
local f_p_z = formatters["%0.5Fpt plus %0.5Fpt"]
local f_z_f = formatters["%0.5Fpt minus %0.5F%s"]
local f_z_m = formatters["%0.5Fpt minus %0.5Fpt"]
local f_z_z = formatters["%0.5Fpt"]

local tonut    = nodes.tonut
local getfield = nodes.nuts.getfield

local function nodetodimen(n)
    n = tonut(n)
    local id = getid(n)
    if id == kern_code then
        local width = getfield(n,"width")
        if width == 0 then
            return "0pt"
        else
            return f_z_z(width)
        end
    elseif id ~= glue_code then
        return "0pt"
    end
    local stretch_order = getfield(n,"stretch_order")
    local shrink_order  = getfield(n,"shrink_order")
    local stretch       = getfield(n,"stretch") / 65536
    local shrink        = getfield(n,"shrink")  / 65536
    local width         = getfield(n,"width")   / 65536
    if stretch_order ~= 0 then
        if shrink_order ~= 0 then
            return f_f_f(width,stretch,fillorders[stretch_order],shrink,fillorders[shrink_order])
        elseif shrink ~= 0 then
            return f_f_m(width,stretch,fillorders[stretch_order],shrink)
        else
            return f_f_z(width,stretch,fillorders[stretch_order])
        end
    elseif shrink_order ~= 0 then
        if stretch ~= 0 then
            return f_p_f(width,stretch,shrink,fillorders[shrink_order])
        else
            return f_z_f(width,shrink,fillorders[shrink_order])
        end
    elseif stretch ~= 0 then
        if shrink ~= 0 then
            return f_p_m(width,stretch,shrink)
        else
            return f_p_z(width,stretch)
        end
    elseif shrink ~= 0 then
        return f_z_m(width,shrink)
    elseif width == 0 then
        return "0pt"
    else
        return f_z_z(width)
    end
end


-- number.todimen(123)
-- number.todimen(123,"cm")
-- number.todimen(123,false,"%F))

local f_pt = formatters["%p"]
local f_un = formatters["%F%s"]

dimenfactors[""] = dimenfactors.pt

local function numbertodimen(d,unit,fmt)
    if not d or d == 0 then
        if not unit or unit == "pt" then
            return "0pt"
        elseif fmt then
            return formatters[fmt](0,unit)
        else
            return 0 .. unit
        end
    elseif fmt then
        if not unit then
            unit = "pt"
        end
        return formatters[fmt](d*dimenfactors[unit],unit)
    elseif not unit or unit == "pt" then
        return f_pt(d)
    else
        return f_un(d*dimenfactors[unit],unit)
    end
end

number.todimen = numbertodimen
nodes .todimen = nodetodimen

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

function nodes.topoints      (n,fmt) return nodetodimen(n,"pt",fmt) end
function nodes.toinches      (n,fmt) return nodetodimen(n,"in",fmt) end
function nodes.tocentimeters (n,fmt) return nodetodimen(n,"cm",fmt) end
function nodes.tomillimeters (n,fmt) return nodetodimen(n,"mm",fmt) end
function nodes.toscaledpoints(n,fmt) return nodetodimen(n,"sp",fmt) end
function nodes.toscaledpoints(n)     return          n .. "sp"      end
function nodes.tobasepoints  (n,fmt) return nodetodimen(n,"bp",fmt) end
function nodes.topicas       (n,fmt) return nodetodimen(n "pc",fmt) end
function nodes.todidots      (n,fmt) return nodetodimen(n,"dd",fmt) end
function nodes.tociceros     (n,fmt) return nodetodimen(n,"cc",fmt) end
function nodes.tonewdidots   (n,fmt) return nodetodimen(n,"nd",fmt) end
function nodes.tonewciceros  (n,fmt) return nodetodimen(n,"nc",fmt) end

-- stop redefinition

local points = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fpt",n*ptfactor)) -- faster than formatter
    else
        return numbertodimen(n,"pt") -- also deals with nodes
    end
end

local basepoints = function(n)
    if not n or n == 0 then
        return "0bp"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fbp",n*bpfactor)) -- faster than formatter
    else
        return numbertodimen(n,"bp") -- also deals with nodes
    end
end

local pts = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return format("%.5fpt",n*ptfactor) -- faster than formatter
    else
        return numbertodimen(n,"pt") -- also deals with nodes
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

nodes.points     = function(n) return numbertodimen(n,"pt")     end
nodes.basepoints = function(n) return numbertodimen(n,"bp")     end
nodes.pts        = function(n) return numbertodimen(n,"pt")     end
nodes.nopts      = function(n) return format("%.5f",n*ptfactor) end

local colors          = { }
tracers.colors        = colors

local unsetvalue      = attributes.unsetvalue

local a_color         = attributes.private('color')
local a_colormodel    = attributes.private('colormodel')
local m_color         = attributes.list[a_color] or { }

function colors.set(n,c,s)
    local mc = m_color[c]
    local nn = tonut(n)
    if mc then
        local mm = s or texgetattribute(a_colormodel)
        setattr(nn,a_colormodel,mm <= 0 and mm or 1)
        setattr(nn,a_color,mc)
    else
        setattr(nn,a_color,unsetvalue)
    end
    return n
end

function colors.setlist(n,c,s)
    local nn = tonut(n)
    local mc = m_color[c] or unsetvalue
    local mm = s or texgetattribute(a_colormodel)
    if mm <= 0 then
        mm = 1
    end
    while nn do
        setattr(nn,a_colormodel,mm)
        setattr(nn,a_color,mc)
        nn = getnext(nn)
    end
    return n
end

function colors.reset(n)
    setattr(tonut(n),a_color,unsetvalue)
    return n
end

-- maybe

local transparencies   = { }
tracers.transparencies = transparencies

local a_transparency   = attributes.private('transparency')
local m_transparency   = attributes.list[a_transparency] or { }

function transparencies.set(n,t)
    setattr(tonut(n),a_transparency,m_transparency[t] or unsetvalue)
    return n
end

function transparencies.setlist(n,c,s)
    local nn = tonut(n)
    local mt = m_transparency[c] or unsetvalue
    while nn do
        setattr(nn,a_transparency,mt)
        nn = getnext(nn)
    end
    return n
end

function transparencies.reset(n)
    setattr(n,a_transparency,unsetvalue)
    return n
end

-- for the moment here

local visualizers = nodes.visualizers or { }
nodes.visualizers = visualizers

function visualizers.handler(head)
    return head, false
end

-- we could cache attribute lists and set attr (copy will increment count) .. todo ..
-- although tracers are used seldom

local function setproperties(n,c,s)
    local nn = tonut(n)
    local mm = texgetattribute(a_colormodel)
    setattr(nn,a_colormodel,mm > 0 and mm or 1)
    setattr(nn,a_color,m_color[c])
    setattr(nn,a_transparency,m_transparency[c])
    return n
end

tracers.setproperties = setproperties

function tracers.setlist(n,c,s)
    local nn = tonut(n)
    local mc = m_color[c]
    local mt = m_transparency[c]
    local mm = texgetattribute(a_colormodel)
    if mm <= 0 then
        mm = 1
    end
    while nn do
        setattr(nn,a_colormodel,mm)
        setattr(nn,a_color,mc)
        setattr(nn,a_transparency,mt)
        nn = getnext(nn)
    end
    return n
end

function tracers.resetproperties(n)
    local nn = tonut(n)
    setattr(nn,a_color,unsetvalue)
    setattr(nn,a_transparency,unsetvalue)
    return n
end

-- this one returns a nut

local nodestracerpool = { }
local nutstracerpool  = { }

tracers.pool = {
    nodes = nodestracerpool,
    nuts  = nutstracerpool,
}

table.setmetatableindex(nodestracerpool,function(t,k,v)
    local f = nutstracerpool[k]
    local v = function(...)
        return tonode(f(...))
    end
    t[k] = v
    return v
end)

function nutstracerpool.rule(w,h,d,c,s) -- so some day we can consider using literals (speedup)
    return setproperties(new_rule(w,h,d),c,s)
end

tracers.rule = nodestracerpool.rule -- for a while

-- local function show(head,n,message)
--     print("START",message or "")
--     local i = 0
--     for current in traverse(head) do
--         local prev = getprev(current)
--         local next = getnext(current)
--         i = i + 1
--         print(i, prev and nodecodes[getid(prev)],nodecodes[getid(current)],next and nodecodes[getid(next)])
--         if i == n then
--             break
--         end
--     end
--     print("STOP", message or "")
-- end
