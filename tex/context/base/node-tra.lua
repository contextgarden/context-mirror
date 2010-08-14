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

local utf = unicode.utf8
local format, match, concat, rep, utfchar = string.format, string.match, table.concat, string.rep, utf.char

local ctxcatcodes = tex.ctxcatcodes

local report_nodes = logs.new("nodes")

fonts     = fonts     or { }
fonts.tfm = fonts.tfm or { }
fonts.ids = fonts.ids or { }

nodes                    = nodes                    or { }
nodes.tracers            = nodes.tracers            or { }
nodes.tracers.characters = nodes.tracers.characters or { }
nodes.tracers.steppers   = nodes.tracers.steppers   or { }

local glyph   = node.id('glyph')
local hlist   = node.id('hlist')
local vlist   = node.id('vlist')
local disc    = node.id('disc')
local glue    = node.id('glue')
local kern    = node.id('kern')
local rule    = node.id('rule')
local whatsit = node.id('whatsit')

local copy_node_list  = node.copy_list
local hpack_node_list = node.hpack
local free_node_list  = node.flush_list
local first_character = node.first_character
local node_type       = node.type
local traverse_nodes  = node.traverse

local texsprint = tex.sprint
local fontdata  = fonts.ids

function nodes.tracers.characters.collect(head,list,tag,n)
    n = n or 0
    local ok, fn = false, nil
    while head do
        local id = head.id
        if id == glyph then
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
        elseif id == disc then
            -- skip
        else
            ok = false
        end
        head = head.next
    end
end

function nodes.tracers.characters.equal(ta, tb)
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

function nodes.tracers.characters.string(t)
    local tt = { }
    for i=1,#t do
        tt[i] = utfchar(t[i][1])
    end
    return concat(tt,"")
end

function nodes.tracers.characters.unicodes(t,decimal)
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

function nodes.tracers.characters.indices(t,decimal)
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

function nodes.tracers.characters.start()
    local npc = nodes.process_characters
    local list = { }
    function nodes.process_characters(head)
        local n = #list
        nodes.tracers.characters.collect(head,list,'before',n)
        local h, d = npc(head)
        nodes.tracers.characters.collect(head,list,'after',n)
        if #list > n then
            list[#list+1] = { }
        end
        return h, d
    end
    function nodes.tracers.characters.stop()
        tracers.list['characters'] = list
        local variables = {
            ['title']                = 'ConTeXt Character Processing Information',
            ['color-background-one'] = lmx.get('color-background-yellow'),
            ['color-background-two'] = lmx.get('color-background-purple'),
        }
        lmx.show('context-characters.lmx',variables)
        nodes.process_characters = npc
        tasks.restart("processors", "characters")
    end
    tasks.restart("processors", "characters")
end

local stack = { }

function nodes.tracers.start(tag)
    stack[#stack+1] = tag
    local tracer = nodes.tracers[tag]
    if tracer and tracer.start then
        tracer.start()
    end
end
function nodes.tracers.stop()
    local tracer = stack[#stack]
    if tracer and tracer.stop then
        tracer.stop()
    end
    stack[#stack] = nil
end

-- experimental

local collection, collecting, messages = { }, false, { }

function nodes.tracers.steppers.start()
    collecting = true
end

function nodes.tracers.steppers.stop()
    collecting = false
end

function nodes.tracers.steppers.reset()
    for i=1,#collection do
        local c = collection[i]
        if c then
            free_node_list(c)
        end
    end
    collection, messages = { }, { }
end

function nodes.tracers.steppers.nofsteps()
    return tex.write(#collection)
end

function nodes.tracers.steppers.glyphs(n,i)
    local c = collection[i]
    if c then
        tex.box[n] = hpack_node_list(copy_node_list(c))
    end
end

function nodes.tracers.steppers.features()
--  local f = first_character(collection[1])
--  if f then -- something fishy with first_character
    local f = collection[1]
    while f do
        if f.id == glyph then
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
                texsprint(ctxcatcodes,concat(t,", "))
            else
                texsprint(ctxcatcodes,"no features")
            end
            return
        end
        f = f.next
    end
end

function nodes.tracers.fontchar(font,char)
    local n = nodes.glyph()
    n.font, n.char, n.subtype = font, char, 256
    node.write(n)
end

function nodes.tracers.steppers.codes(i,command)
    local c = collection[i]
    while c do
        local id = c.id
        if id == glyph then
            if command then
                texsprint(ctxcatcodes,format("%s{%s}{%s}",command,c.font,c.char))
            else
                texsprint(ctxcatcodes,format("[%s:U+%04X]",c.font,c.char))
            end
        elseif id == whatsit and (c.subtype == 6 or c.subtype == 7) then
            texsprint(ctxcatcodes,format("[%s]",c.dir))
        else
            texsprint(ctxcatcodes,format("[%s]",node_type(id)))
        end
        c = c.next
    end
end

function nodes.tracers.steppers.messages(i,command,split)
    local list = messages[i] -- or { "no messages" }
    if list then
        for i=1,#list do
            local l = list[i]
            if split then
                local a, b = match(l,"^(.-)%s*:%s*(.*)$")
                texsprint(ctxcatcodes,format("%s{%s}{%s}",command,a or l,b or ""))
            else
                texsprint(ctxcatcodes,format("%s{%s}",command,l))
            end
        end
    end
end

-- hooks into the node list processor (see otf)

function nodes.tracers.steppers.check(head)
    if collecting then
        nodes.tracers.steppers.reset()
        local n = copy_node_list(head)
        nodes.inject_kerns(n,nil,"trace",true)
        nodes.protect_glyphs(n) -- can be option
        collection[1] = n
    end
end

function nodes.tracers.steppers.register(head)
    if collecting then
        local nc = #collection+1
        if messages[nc] then
            local n = copy_node_list(head)
            nodes.inject_kerns(n,nil,"trace",true)
            nodes.protect_glyphs(n) -- can be option
            collection[nc] = n
        end
    end
end

function nodes.tracers.steppers.message(str,...)
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

function nodes.show_list(head, message)
    if message then
        texio.write_nl(message)
    end
    for n in traverse_nodes(head) do
        texio.write_nl(tostring(n))
    end
end

function nodes.check_glyphs(head,message)
    local t = { }
    for g in traverse_id(glyph,head) do
        t[#t+1] = format("U+%04X:%s",g.char,g.subtype)
    end
    if #t > 0 then
        logs.report(message or "nodes","%s glyphs: %s",#t,concat(t," "))
    end
    return false
end

function nodes.tosequence(start,stop,compact)
    if start then
        local t = { }
        while start do
            local id = start.id
            if id == glyph then
                local c = start.char
                if compact then
                    if start.components then
                        t[#t+1] = nodes.tosequence(start.components,nil,compact)
                    else
                        t[#t+1] = utfchar(c)
                    end
                else
                    t[#t+1] = format("U+%04X:%s",c,utfchar(c))
                end
            elseif id == whatsit and start.subtype == 6 or start.subtype == 7 then
                t[#t+1] = "[" .. start.dir .. "]"
            elseif id == rule then
                if compact then
                    t[#t+1] = "|"
                else
                    t[#t+1] = node_type(id)
                end
            else
                if compact then
                    t[#t+1] = "[]"
                else
                    t[#t+1] = node_type(id)
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

function nodes.report(t,done)
    if done then
        if status.output_active then
            report_nodes("output, changed, %s nodes",nodes.count(t))
        else
            texio.write("nodes","normal, changed, %s nodes",nodes.count(t))
        end
    else
        if status.output_active then
            report_nodes("output, unchanged, %s nodes",nodes.count(t))
        else
            texio.write("nodes","normal, unchanged, %s nodes",nodes.count(t))
        end
    end
end

function nodes.pack_list(head)
    local t = { }
    for n in traverse(head) do
        t[#t+1] = tostring(n)
    end
    return t
end

function nodes.ids_to_string(head,tail)
    local t, last_id, last_n = { }, nil, 0
    for n in traverse_nodes(head,tail) do -- hm, does not stop at tail
        local id = n.id
        if not last_id then
            last_id, last_n = id, 1
        elseif last_id == id then
            last_n = last_n + 1
        else
            if last_n > 1 then
                t[#t+1] = format("[%s*%s]",last_n,node_type(last_id) or "?")
            else
                t[#t+1] = format("[%s]",node_type(last_id) or "?")
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
        t[#t+1] = format("[%s*%s]",last_n,node_type(last_id) or "?")
    else
        t[#t+1] = format("[%s]",node_type(last_id) or "?")
    end
    return concat(t," ")
end

nodes.ids_tostring = nodes.ids_to_string

local function show_simple_list(h,depth,n)
    while h do
        texio.write_nl(rep(" ",n) .. tostring(h))
        if not depth or n < depth then
            local id = h.id
            if id == hlist or id == vlist then
                show_simple_list(h.list,depth,n+1)
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

nodes.show_simple_list = function(h,depth) show_simple_list(h,depth,0) end

function nodes.list_to_utf(h,joiner)
    local joiner = (joiner ==true and utfchar(0x200C)) or joiner -- zwnj
    local w = { }
    while h do
        if h.id == glyph then -- always true
            w[#w+1] = utfchar(h.char)
            if joiner then
                w[#w+1] = joiner
            end
        else
            w[#w+1] = "[-]"
        end
        h = h.next
    end
    return concat(w)
end
