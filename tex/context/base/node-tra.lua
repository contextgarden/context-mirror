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
local concat = table.concat
local format, match, gmatch, concat, rep = string.format, string.match, string.gmatch, table.concat, string.rep
local lpegmatch = lpeg.match
local write_nl = texio.write_nl

local report_nodes = logs.reporter("nodes","tracing")

fonts = fonts or { }
nodes = nodes or { }

local fonts, nodes, node, context = fonts, nodes, node, context

nodes.tracers         = nodes.tracers or { }
local tracers         = nodes.tracers

nodes.tasks           = nodes.tasks or { }
local tasks           = nodes.tasks

nodes.handlers        = nodes.handlers or { }
local handlers        = nodes.handlers

nodes.injections      = nodes.injections or { }
local injections      = nodes.injections

tracers.characters    = tracers.characters or { }
tracers.steppers      = tracers.steppers   or { }

local char_tracers    = tracers.characters
local step_tracers    = tracers.steppers

local copy_node_list  = node.copy_list
local hpack_node_list = node.hpack
local free_node_list  = node.flush_list
local traverse_nodes  = node.traverse
local traverse_by_id  = node.traverse_id

local nodecodes       = nodes.nodecodes
local whatcodes       = nodes.whatcodes
local skipcodes       = nodes.skipcodes

local glyph_code      = nodecodes.glyph
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist
local disc_code       = nodecodes.disc
local glue_code       = nodecodes.glue
local kern_code       = nodecodes.kern
local rule_code       = nodecodes.rule
local whatsit_code    = nodecodes.whatsit

local localpar_code   = whatcodes.localpar
local dir_code        = whatcodes.dir

local nodepool        = nodes.pool

local new_glyph       = nodepool.glyph

function char_tracers.collect(head,list,tag,n)
    local fontdata = fonts.hashes.identifiers
    n = n or 0
    local ok, fn = false, nil
    while head do
        local id = head.id
        if id == glyph_code then
            local f = head.font
            if f ~= fn then
                ok, fn = false, f
            end
            local c = head.char
            local i = fontdata[f].indices[c] or 0
            if not ok then
                ok = true
                n = n + 1
                list[n] = list[n] or { }
                list[n][tag] = { }
            end
            local l = list[n][tag]
            l[#l+1] = { c, f, i }
        elseif id == disc_code then
            -- skip
        else
            ok = false
        end
        head = head.next
    end
end

function char_tracers.equal(ta, tb)
    if #ta ~= #tb then
        return false
    else
        for i=1,#ta do
            local a, b = ta[i], tb[i]
            if a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3] then
                return false
            end
        end
    end
    return true
end

function char_tracers.string(t)
    local tt = { }
    for i=1,#t do
        tt[i] = utfchar(t[i][1])
    end
    return concat(tt,"")
end

function char_tracers.unicodes(t,decimal)
    local tt = { }
    for i=1,#t do
        local n = t[i][1]
        if n == 0 then
            tt[i] = "-"
        elseif decimal then
            tt[i] = n
        else
            tt[i] = format("U+%04X",n)
        end
    end
    return concat(tt," ")
end

function char_tracers.indices(t,decimal)
    local tt = { }
    for i=1,#t do
        local n = t[i][3]
        if n == 0 then
            tt[i] = "-"
        elseif decimal then
            tt[i] = n
        else
            tt[i] = format("U+%04X",n)
        end
    end
    return concat(tt," ")
end

function char_tracers.start()
    local npc = handlers.characters
    local list = { }
    function handlers.characters(head)
        local n = #list
        char_tracers.collect(head,list,'before',n)
        local h, d = npc(head)
        char_tracers.collect(head,list,'after',n)
        if #list > n then
            list[#list+1] = { }
        end
        return h, d
    end
    function char_tracers.stop()
        tracers.list['characters'] = list
        local variables = {
            ['title']                = 'ConTeXt Character Processing Information',
            ['color-background-one'] = lmx.get('color-background-yellow'),
            ['color-background-two'] = lmx.get('color-background-purple'),
        }
        lmx.show('context-characters.lmx',variables)
        handlers.characters = npc
        tasks.restart("processors", "characters")
    end
    tasks.restart("processors", "characters")
end

local stack = { }

function tracers.start(tag)
    stack[#stack+1] = tag
    local tracer = tracers[tag]
    if tracer and tracer.start then
        tracer.start()
    end
end
function tracers.stop()
    local tracer = stack[#stack]
    if tracer and tracer.stop then
        tracer.stop()
    end
    stack[#stack] = nil
end

-- experimental

local collection, collecting, messages = { }, false, { }

function step_tracers.start()
    collecting = true
end

function step_tracers.stop()
    collecting = false
end

function step_tracers.reset()
    for i=1,#collection do
        local c = collection[i]
        if c then
            free_node_list(c)
        end
    end
    collection, messages = { }, { }
end

function step_tracers.nofsteps()
    return context(#collection)
end

function step_tracers.glyphs(n,i) -- no need for hpack
    local c = collection[i]
    if c then
        tex.box[n] = hpack_node_list(copy_node_list(c))
    end
end

function step_tracers.features()
    -- we cannot use first_glyph here as it only finds characters with subtype < 256
    local fontdata = fonts.hashes.identifiers
    local f = collection[1]
    while f do
        if f.id == glyph_code then
            local tfmdata, t = fontdata[f.font], { }
            for feature, value in table.sortedhash(tfmdata.shared.features) do
                if feature == "number" or feature == "features" then
                    -- private
                elseif type(value) == "boolean" then
                    if value then
                        t[#t+1] = format("%s=yes",feature)
                    else
                        -- skip
                    end
                else
                    t[#t+1] = format("%s=%s",feature,value)
                end
            end
            if #t > 0 then
                context(concat(t,", "))
            else
                context("no features")
            end
            return
        end
        f = f.next
    end
end

function tracers.fontchar(font,char)
    local fontchar = fonts.hashes.characters
    local n = new_glyph()
    n.font, n.char, n.subtype = font, char, 256
    context(n)
end

function step_tracers.codes(i,command)
    local fontdata = fonts.hashes.identifiers
    local c = collection[i]
    while c do
        local id = c.id
        if id == glyph_code then
            if command then
                local f, c = c.font,c.char
                local d = fontdata[f].descriptions
                local d = d and d[c]
                context[command](f,c,d and d.class or "")
            else
                context("[%s:U+%04X]",c.font,c.char)
            end
        elseif id == whatsit_code and (c.subtype == localpar_code or c.subtype == dir_code) then
            context("[%s]",c.dir)
        else
            context("[%s]",nodecodes[id])
        end
        c = c.next
    end
end

function step_tracers.messages(i,command,split)
    local list = messages[i] -- or { "no messages" }
    if list then
        for i=1,#list do
            local l = list[i]
            if not command then
                context("(%s)",l)
            elseif split then
                local a, b = match(l,"^(.-)%s*:%s*(.*)$")
                context[command](a or l or "",b or "")
            else
                context[command](l)
            end
        end
    end
end

-- hooks into the node list processor (see otf)

function step_tracers.check(head)
    if collecting then
        step_tracers.reset()
        local n = copy_node_list(head)
        injections.handler(n,nil,"trace",true)
        handlers.protectglyphs(n) -- can be option
        collection[1] = n
    end
end

function step_tracers.register(head)
    if collecting then
        local nc = #collection+1
        if messages[nc] then
            local n = copy_node_list(head)
            injections.handler(n,nil,"trace",true)
            handlers.protectglyphs(n) -- can be option
            collection[nc] = n
        end
    end
end

function step_tracers.message(str,...)
    str = format(str,...)
    if collecting then
        local n = #collection + 1
        local m = messages[n]
        if not m then m = { } messages[n] = m end
        m[#m+1] = str
    end
    return str -- saves an intermediate var in the caller
end

-- this will be reorganized:

function nodes.showlist(head, message)
    if message then
        write_nl(message)
    end
    for n in traverse_nodes(head) do
        write_nl(tostring(n))
    end
end

function nodes.handlers.checkglyphs(head,message)
    local t = { }
    for g in traverse_by_id(glyph_code,head) do
        t[#t+1] = format("U+%04X:%s",g.char,g.subtype)
    end
    if #t > 0 then
        if message and message ~= "" then
            report_nodes("%s, %s glyphs: %s",message,#t,concat(t," "))
        else
            report_nodes("%s glyphs: %s",#t,concat(t," "))
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
        write_nl(format("%s * %s", v, k))
    end
end

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
                    t[#t+1] = format("U+%04X:%s",c,utfchar(c))
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
    if done then
        if status.output_active then
            report_nodes("output, changed, %s nodes",nodes.count(t))
        else
            write_nl("nodes","normal, changed, %s nodes",nodes.count(t))
        end
    else
        if status.output_active then
            report_nodes("output, unchanged, %s nodes",nodes.count(t))
        else
            write_nl("nodes","normal, unchanged, %s nodes",nodes.count(t))
        end
    end
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
                t[#t+1] = format("[%s*%s]",last_n,nodecodes[last_id] or "?")
            else
                t[#t+1] = format("[%s]",nodecodes[last_id] or "?")
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
        t[#t+1] = format("[%s*%s]",last_n,nodecodes[last_id] or "?")
    else
        t[#t+1] = format("[%s]",nodecodes[last_id] or "?")
    end
    return concat(t," ")
end

--~ function nodes.xidstostring(head,tail) -- only for special tracing of backlinks
--~     local n = head
--~     while n.next do
--~         n = n.next
--~     end
--~     local t, last_id, last_n = { }, nil, 0
--~     while n do
--~         local id = n.id
--~         if not last_id then
--~             last_id, last_n = id, 1
--~         elseif last_id == id then
--~             last_n = last_n + 1
--~         else
--~             if last_n > 1 then
--~                 t[#t+1] = format("[%s*%s]",last_n,nodecodes[last_id] or "?")
--~             else
--~                 t[#t+1] = format("[%s]",nodecodes[last_id] or "?")
--~             end
--~             last_id, last_n = id, 1
--~         end
--~         if n == head then
--~             break
--~         end
--~         n = n.prev
--~     end
--~     if not last_id then
--~         t[#t+1] = "no nodes"
--~     elseif last_n > 1 then
--~         t[#t+1] = format("[%s*%s]",last_n,nodecodes[last_id] or "?")
--~     else
--~         t[#t+1] = format("[%s]",nodecodes[last_id] or "?")
--~     end
--~     return table.concat(table.reversed(t)," ")
--~ end

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
            w[#w+1] = format("[%s|%s|%s]",
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

local threshold = 65536

local function toutf(list,result,nofresult,stopcriterium)
    if list then
        local fontchar = fonts.hashes.characters
        for n in traverse_nodes(list) do
            local id = n.id
            if id == glyph_code then
                local components = n.components
                if components then
                    result, nofresult = toutf(components,result,nofresult)
                else
                    local c = n.char
                    local fc = fontchar[n.font]
                    if fc then
                        local u = fc[c].tounicode
                        if u then
                            for s in gmatch(u,"....") do
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(tonumber(s,16))
                            end
                        else
                            nofresult = nofresult + 1
                            result[nofresult] = utfchar(c)
                        end
                    else
                        nofresult = nofresult + 1
                        result[nofresult] = utfchar(c)
                    end
                end
            elseif id == disc_code then
                result, nofresult = toutf(n.replace,result,nofresult) -- needed?
            elseif id == hlist_code or id == vlist_code then
--~                 if nofresult > 0 and result[nofresult] ~= " " then
--~                     nofresult = nofresult + 1
--~                     result[nofresult] = " "
--~                 end
                result, nofresult = toutf(n.list,result,nofresult)
            elseif id == glue_code then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            elseif id == kern_code and n.kern > threshold then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            end
            if n == stopcriterium then
                break
            end
        end
    end
    if nofresult > 0 and result[nofresult] == " " then
        result[nofresult] = nil
        nofresult = nofresult - 1
    end
    return result, nofresult
end

function nodes.toutf(list,stopcriterium)
    local result, nofresult = toutf(list,{},0,stopcriterium)
    return concat(result)
end

-- this will move elsewhere

local ptfactor = number.dimenfactors.pt
local bpfactor = number.dimenfactors.bp
local stripper = lpeg.patterns.stripzeros

local points = function(n)
    if not n or n == 0 then
        return "0pt"
    else
        return lpegmatch(stripper,format("%.5fpt",n*ptfactor))
    end
end

local basepoints = function(n)
    if not n or n == 0 then
        return "0bp"
    else
        return lpegmatch(stripper,format("%.5fbp",n*bpfactor))
    end
end

local pts = function(n)
    if not n or n == 0 then
        return "0pt"
    else
        return format("%.5fpt",n*ptfactor)
    end
end

local nopts = function(n)
    if not n or n == 0 then
        return "0"
    else
        return format("%.5f",n*ptfactor)
    end
end

number.points     = points
number.basepoints = basepoints
number.pts        = pts
number.nopts      = nopts

--~ function nodes.thespec(s)
--~     local stretch_order = s.stretch_order
--~     local shrink_order = s.shrink_order
--~     local stretch_unit = (stretch_order ~= 0) and ("fi".. string.rep("l",stretch_order)) or "sp"
--~     local shrink_unit = (shrink_order ~= 0) and ("fi".. string.rep("l",shrink_order)) or "sp"
--~     return string.format("%ssp+ %ssp - %ssp",s.width,s.stretch,stretch_unit,s.shrink,shrink_unit)
--~ end

local colors   = { }
tracers.colors = colors

local get_attribute   = node.has_attribute
local set_attribute   = node.set_attribute
local unset_attribute = node.unset_attribute

local a_color         = attributes.private('color')
local a_colormodel    = attributes.private('colormodel')
local a_state         = attributes.private('state')
local m_color         = attributes.list[a_color] or { }

function colors.set(n,c,s)
    local mc = m_color[c]
    if not mc then
        unset_attribute(n,a_color)
    else
        if not get_attribute(n,a_colormodel) then
            set_attribute(n,a_colormodel,s or 1)
        end
        set_attribute(n,a_color,mc)
    end
end

function colors.setlist(n,c,s)
    while n do
        local mc = m_color[c]
        if not mc then
            unset_attribute(n,a_color)
        else
            if not get_attribute(n,a_colormodel) then
                set_attribute(n,a_colormodel,s or 1)
            end
            set_attribute(n,a_color,mc)
        end
        n = n.next
    end
end

function colors.reset(n)
    unset_attribute(n,a_color)
end

-- maybe

local transparencies   = { }
tracers.transparencies = transparencies

local a_transparency   = attributes.private('transparency')
local m_transparency   = attributes.list[a_transparency] or { }

function transparencies.set(n,t)
    local mt = m_transparency[t]
    if not mt then
        unset_attribute(n,a_transparency)
    else
        set_attribute(n,a_transparency,mt)
    end
end

function transparencies.setlist(n,c,s)
    while n do
        local mt = m_transparency[c]
        if not mt then
            unset_attribute(n,a_transparency)
        else
            set_attribute(n,a_transparency,mt)
        end
        n = n.next
    end
end

function transparencies.reset(n)
    unset_attribute(n,a_transparency)
end

-- for the moment here

nodes.visualizers = { }

function nodes.visualizers.handler(head)
    return head, false
end
