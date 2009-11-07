if not modules then modules = { } end modules ['node-rul'] = {
    version   = 1.001,
    comment   = "companion to node-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: order and maybe other dimensions

local floor = math.floor

local a_ruled        = attributes.private('ruled')
local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')

local glyph = node.id("glyph")
local disc  = node.id("disc")
local glue  = node.id("glue")
local kern  = node.id("kern")
local hlist = node.id("hlist")
local vlist = node.id("vlist")

local new_rule = nodes.rule
local new_kern = nodes.kern
local new_glue = nodes.glue

local insert_before, insert_after = node.insert_before, node.insert_after
local list_dimensions, has_attribute, set_attribute = node.dimensions, node.has_attribute, node.set_attribute
local dimenfactor = fonts.dimenfactor
local texwrite = tex.write

local fontdata    = fonts.ids
local variables   = interfaces.variables

nodes.rules      = nodes.rules      or { }
nodes.rules.data = nodes.rules.data or { }

storage.register("nodes/rules/data", nodes.rules.data, "nodes.rules.data")

local data = nodes.rules.data

-- method, offset, continue, dy, rulethickness, unit, order, max, colorspace, color, transparency

function nodes.rules.define(...)
    data[#data+1] = { ... }
    texwrite(#data)
end

local function flush(head,f,l,d,level,parent) -- not that fast but acceptable for this purpose
    local r, m
    local w = list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,f,l.next)
    local method, offset, continue, dy, rulethickness, unit, order, max = d[1], d[2], d[3], d[4], d[5]/2, d[6], d[7], d[8]
    local cs, co, tr = d[9], d[10], d[11]
    local e = dimenfactor(unit,fontdata[f.font])
    local colorspace   = (cs > 0 and cs) or has_attribute(f,a_colorspace) or 1
    local color        = (co > 0 and co) or has_attribute(f,a_color)
    local transparency = (tr > 0 and tr) or has_attribute(f,a_transparency)
    local foreground = order == variables.foreground
    if method == 0 then -- center
        offset = 2*offset
        m = (offset+(level-1)*dy+rulethickness)*e/2
    else
        m = 0
    end
    if level > max then
        level = max
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
     -- print(level,w,nodes.ids_to_string(f,l),nodes.tosequence(f,l,true))
    end
    return head
end

-- todo: functions: word, sentence

local function process(head,parent)
    local n = head
    local f, l, a, d, i, level
    local continue = false
    while n do
        local id = n.id
        if id == glyph then
            local aa = has_attribute(n,a_ruled)
            if aa then
                if aa == a then
                    if not f then
                        f = n
                    end
                    l = n
                else
                    -- possible extensions: when in same class then keep spanning
                    if f then
                        head = flush(head,f,l,d,level,parent)
                    end
                    f, l, a = n, n, aa
                    level, i = floor(a/1000), a%1000
                    d = data[i]
                    continue = d[3] == variables.yes
                end
            else
                if f then
                    head = flush(head,f,l,d,level,parent)
                end
                f, l, a = nil, nil, nil
            end
        elseif f and id == disc then
            l = n
        elseif f and id == kern and n.subtype == 0 then
            l = n
        elseif id == hlist or id == vlist then
            if f then
                head = flush(head,f,l,d,level,parent)
                f, l, a = nil, nil, nil
            end
            n.list = process(n.list,n)
        elseif f and not continue then
            head = flush(head,f,l,d,level,parent)
            f, l, a = nil, nil, nil
        end
        n = n.next
    end
    if f then
        head = flush(head,f,l,d,level,parent)
    end
    return head, true -- todo: done
end

nodes.rules.process = function(head) return process(head) end

function nodes.rules.enable()
    tasks.enableaction("shipouts","nodes.rules.process")
end

--~ tasks.appendaction ("shipouts", "normalizers", "nodes.rules.process")
--~ tasks.disableaction("shipouts",                "nodes.rules.process") -- only kick in when used

