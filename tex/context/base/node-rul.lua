if not modules then modules = { } end modules ['node-rul'] = {
    version   = 1.001,
    comment   = "companion to node-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will go to an auxiliary module
-- beware: rules now have a dir field
--
-- todo: make robust for layers ... order matters

local glyph = node.id("glyph")
local disc  = node.id("disc")
local rule  = node.id("rule")

function nodes.strip_range(first,last) -- todo: dir
    if first and last then -- just to be sure
        if first == last then
            return first, last
        end
        while first and first ~= last do
            local id = first.id
            if id == glyph or id == disc then -- or id == rule
                break
            else
                first = first.next
            end
        end
        if not first then
            return nil, nil
        elseif first == last then
            return first, last
        end
        while last and last ~= first do
            local id = last.id
            if id == glyph or id == disc then -- or id == rule
                break
            else
                last = last.prev
            end
        end
        if not last then
            return nil, nil
        end
    end
    return first, last
end

-- todo: order and maybe other dimensions

local trace_ruled = false  trackers.register("nodes.ruled", function(v) trace_ruled = v end)

local report_ruled   = logs.new("ruled")

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
--
-- this one needs to take layers into account (i.e. we need a list of
-- critical attributes)

-- omkeren class en level -> scheelt functie call in analyse

local function process_words(attribute,data,flush,head,parent) -- we have hlistdir and local dir
    local n = head
    if n then
        local f, l, a, d, i, class
        local continue, done, strip, level = false, false, true, -1
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
                        local newlevel, newclass = floor(aa/1000), aa%1000
--~                         strip = not continue or level == 1 -- 0
                        if f then
                            if class == newclass then -- and newlevel > level then
                                head, done = flush(head,f,l,d,level,parent,false), true
                            else
                                head, done = flush(head,f,l,d,level,parent,strip), true
                            end
                        end
                        f, l, a = n, n, aa
                        level, class = newlevel, newclass
                        d = data[class]
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
                    if id == penalty then
                        l = n
                    elseif id == kern then
                        l = n
                    elseif id == glue then
                        -- catch \underbar{a} \underbar{a} (subtype test is needed)
                        if continue and has_attribute(n,attribute) and n.subtype == 0 then
                            l = n
                        else
                            head, done = flush(head,f,l,d,level,parent,strip), true
                            f, l, a = nil, nil, nil
                        end
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

local a_viewerlayer = attributes.private("viewerlayer")

local function flush_ruled(head,f,l,d,level,parent,strip) -- not that fast but acceptable for this purpose
-- check for f and l
    if f.id ~= glyph then
        -- saveguard ... we need to deal with rules and so (math)
        return head
    end
    local r, m
    if strip then
        if trace_ruled then
            local before = n_tosequence(f,l,true)
            f, l = strip_range(f,l)
            local after = n_tosequence(f,l,true)
            report_ruled("range stripper: %s -> %s",before,after)
        else
            f, l = strip_range(f,l)
        end
    end
    if not f then
        return head
    end
    local w = list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,f,l.next)
    local method, offset, continue, dy, rulethickness, unit, order, max, ma, ca, ta =
        d.method, d.offset, d.continue, d.dy, d.rulethickness, d.unit, d.order, d.max, d.ma, d.ca, d.ta
    local e = dimenfactor(unit,fontdata[f.font]) -- what if no glyph node
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
        local v = has_attribute(f,a_viewerlayer)
        -- quick hack
        if v then
            set_attribute(r,a_viewerlayer,v)
        end
        --
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
            head = insert_before(head,f,r)
            insert_after(head,r,k)
        end
        if trace_ruled then
            report_ruled("level: %s, width: %i, height: %i, depth: %i, nodes: %s, text: %s",
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

local report_shifted = logs.new("shifted")

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
        report_shifted("width: %s, nodes: %s, text: %s",width,n_tostring(first,last),n_tosequence(first,last,true))
    end
    return head
end

local process = nodes.process_words

nodes.shifts.process = function(head) return process(a_shifted,data,flush_shifted,head) end

function nodes.shifts.enable()
    tasks.enableaction("shipouts","nodes.shifts.process")
end
