if not modules then modules = { } end modules ['node-rul'] = {
    version   = 1.001,
    comment   = "companion to node-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will go to an auxiliary module
-- beware: rules now have a dir field

local glyph = node.id("glyph")
local disc  = node.id("disc")
local rule  = node.id("rule")

function nodes.strip_range(first,last) -- todo: dir
    if first and last then -- just to be sure
        local current = first
        while current and current ~= last do
            local id = current.id
            if id == glyph or id == disc then
    --~         if id == glyph or id == rule or id == disc then
                first = current
                break
            else
                current = current.next
            end
        end
        local current = last
        while current and current ~= first do
            local id = current.id
    --~         if id == glyph or id == rule or id == disc then
            if id == glyph or id == disc then
                last = current
                break
            else
                current = current.prev
            end
        end
    end
    return first, last
end

-- todo: order and maybe other dimensions

local trace_ruled = false  trackers.register("nodes.ruled", function(v) trace_ruled = v end)

local floor = math.floor
local n_tostring, n_tosequence = nodes.ids_tostring, nodes.tosequence

local a_ruled        = attributes.private('ruled')
local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')

local glyph   = node.id("glyph")
local disc    = node.id("disc")
local glue    = node.id("glue")
local penalty = node.id("penalty")
local kern    = node.id("kern")
local hlist   = node.id("hlist")
local vlist   = node.id("vlist")
local rule    = node.id("rule")
local whatsit = node.id("whatsit")

local new_rule = nodes.rule
local new_kern = nodes.kern
local new_glue = nodes.glue

local insert_before, insert_after, strip_range = node.insert_before, node.insert_after, nodes.strip_range
local list_dimensions, has_attribute, set_attribute = node.dimensions, node.has_attribute, node.set_attribute
local hpack_nodes = node.hpack
local dimenfactor = fonts.dimenfactor
local texwrite = tex.write

local fontdata  = fonts.ids
local variables = interfaces.variables

-- we can use this one elsewhere too
--
-- todo: functions: word, sentence
--
-- glyph rule unset whatsit glue margin_kern kern math disc

local checkdir = true

-- we assume {glyphruns} and no funny extra kerning, ok, maybe we need
-- a dummy character as start and end; anyway we only collect glyphs

local function process_words(attribute,data,flush,head,parent) -- we have hlistdir and local dir
    local n = head
    if n then
        local f, l, a, d, i, level
        local continue, done, strip = false, false, false
        while n do
            local id = n.id
            if id == glyph or id == rule then
                local aa = has_attribute(n,attribute)
                if aa then
                    if aa == a then
                        if not f then -- ?
                            f = n
                        end
                        l = n
                    else
                        -- possible extensions: when in same class then keep spanning
                        if f then
                            head, done = flush(head,f,l,d,level,parent,strip), true
                        end
                        f, l, a = n, n, aa
                        level, i = floor(a/1000), a%1000
                        d = data[i]
                        continue = d.continue == variables.yes
                    end
                else
                    if f then
                        head, done = flush(head,f,l,d,level,parent,strip), true
                    end
                    f, l, a = nil, nil, nil
                end
            elseif f and (id == disc or (id == kern and n.subtype == 0)) then
                l = n
            elseif id == hlist or id == vlist then
                if f then
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
                local list = n.list
                if list then
                    n.list = process_words(attribute,data,flush,list,n)
                end
            elseif checkdir and id == whatsit and n.subtype == 7 then -- only changes in dir, we assume proper boundaries
                if f and a then
                    l = n
                end
            elseif f then
                if continue then
                    if id == penalty or id == kern then
                        l = n
                    elseif id == glue then
                        l = n
                    end
                else
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
            end
            n = n.next
        end
        if f then
            head, done = flush(head,f,l,d,level,parent,strip), true
        end
        return head, true -- todo: done
    else
        return head, false
    end
end

nodes.process_words = process_words

--

nodes.rules      = nodes.rules      or { }
nodes.rules.data = nodes.rules.data or { }

storage.register("nodes/rules/data", nodes.rules.data, "nodes.rules.data")

local data = nodes.rules.data

function nodes.rules.define(settings)
    data[#data+1] = settings
    texwrite(#data)
end

local function flush_ruled(head,f,l,d,level,parent,strip) -- not that fast but acceptable for this purpose
-- check for f and l
    local r, m
    if true then
        f, l = strip_range(f,l)
    end
    local w = list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,f,l.next)
    local method, offset, continue, dy, rulethickness, unit, order, max, ma, ca, ta =
        d.method, d.offset, d.continue, d.dy, d.rulethickness, d.unit, d.order, d.max, d.ma, d.ca, d.ta
    local e = dimenfactor(unit,fontdata[f.font])
    local colorspace   = (ma > 0 and ma) or has_attribute(f,a_colorspace) or 1
    local color        = (ca > 0 and ca) or has_attribute(f,a_color)
    local transparency = (ta > 0 and ta) or has_attribute(f,a_transparency)
    local foreground = order == variables.foreground
    rulethickness= rulethickness/2
    if level > max then
        level = max
    end
    if method == 0 then -- center
        offset = 2*offset
        m = (offset+(level-1)*dy+rulethickness)*e/2
    else
        m = 0
    end
    for i=1,level do
        local ht =  (offset+(i-1)*dy+rulethickness)*e - m
        local dp = -(offset+(i-1)*dy-rulethickness)*e + m
        local r = new_rule(w,ht,dp)
        if color then
            set_attribute(r,a_colorspace,colorspace)
            set_attribute(r,a_color,color)
        end
        if transparency then
            set_attribute(r,a_transparency,transparency)
        end
        local k = new_kern(-w)
        if foreground then
            insert_after(head,l,k)
            insert_after(head,k,r)
            l = r
        else
            head, _ = insert_before(head,f,r)
            insert_after(head,r,k)
        end
        if trace_ruled then
            logs.report("ruled", "level: %s, width: %i, height: %i, depth: %i, nodes: %s, text: %s",
                level,w,ht,dp,n_tostring(f,l),n_tosequence(f,l,true))
             -- level,r.width,r.height,r.depth,n_tostring(f,l),n_tosequence(f,l,true))
        end
    end
    return head
end

local process = nodes.process_words

nodes.rules.process = function(head) return process(a_ruled,data,flush_ruled,head) end

function nodes.rules.enable()
    tasks.enableaction("shipouts","nodes.rules.process")
end

-- elsewhere:
--
-- tasks.appendaction ("shipouts", "normalizers", "nodes.rules.process")
-- tasks.disableaction("shipouts",                "nodes.rules.process") -- only kick in when used

local trace_shifted = false  trackers.register("nodes.shifted", function(v) trace_shifted = v end)

local a_shifted = attributes.private('shifted')

nodes.shifts      = nodes.shifts      or { }
nodes.shifts.data = nodes.shifts.data or { }

storage.register("nodes/shifts/data", nodes.shifts.data, "nodes.shifts.data")

local data = nodes.shifts.data

function nodes.shifts.define(settings)
    data[#data+1] = settings
    texwrite(#data)
end

local function flush_shifted(head,first,last,data,level,parent,strip) -- not that fast but acceptable for this purpose
    if true then
        first, last = strip_range(first,last)
    end
    local prev, next = first.prev, last.next
    first.prev, last.next = nil, nil
    local width, height, depth = list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,first,next)
    local list = hpack_nodes(first,width,"exactly")
    if first == head then
        head = list
    end
    if prev then
        prev.next, list.prev = list, prev
    end
    if next then
        next.prev, list.next = list, next
    end
    local raise = data.dy * dimenfactor(data.unit,fontdata[first.font])
    list.shift, list.height, list.depth = raise, height, depth
    if trace_shifted then
        logs.report("shifted", "width: %s, nodes: %s, text: %s",width,n_tostring(first,last),n_tosequence(first,last,true))
    end
    return head
end

local process = nodes.process_words

nodes.shifts.process = function(head) return process(a_shifted,data,flush_shifted,head) end

function nodes.shifts.enable()
    tasks.enableaction("shipouts","nodes.shifts.process")
end
