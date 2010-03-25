if not modules then modules = { } end modules ['node-tst'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local glue    = node.id("glue")
local penalty = node.id("penalty")
local kern    = node.id("kern")
local glyph   = node.id("glyph")
local whatsit = node.id("whatsit")
local hlist   = node.id("hlist")

local find_node_tail = node.tail or node.slide

local chardata = characters.data

function nodes.the_left_margin(n) -- todo: three values
    while n do
        local id = n.id
        if id == glue then
            if n.subtype == 8 then -- 7 in c/web source
                return n.spec.width
            else
                return 0
            end
        elseif id == whatsit then
            n = n.next
        elseif id == hlist then
            return n.width
        else
            break
        end
    end
    return 0
end

function nodes.the_right_margin(n)
    if n then
        n = find_node_tail(n)
        while n do
            local id = n.id
            if id == glue then
                if n.subtype == 9 then -- 8 in the c/web source
                    return n.spec.width
                else
                    return 0
                end
            elseif id == whatsit then
                n = n.prev
            else
                break
            end
        end
    end
    return false
end

function nodes.somespace(n,all)
    if n then
        local id = n.id
        if id == glue then
            return (all or (n.spec.width ~= 0)) and glue
        elseif id == kern then
            return (all or (n.kern ~= 0)) and kern
        elseif id == glyph then
            local category = chardata[n.char].category
         -- maybe more category checks are needed
            return (category == "zs") and glyph
        end
    end
    return false
end

function nodes.somepenalty(n,value)
    if n then
        local id = n.id
        if id == penalty then
            if value then
                return n.penalty == value
            else
                return true
            end
        end
    end
    return false
end

function nodes.is_display_math(head)
    local n = head.prev
    while n do
        local id = n.id
        if id == penalty then
        elseif id == glue then
            if n.subtype == 6 then -- above_display_short_skip
                return true
            end
        else
            break
        end
        n = n.prev
    end
    n = head.next
    while n do
        local id = n.id
        if id == penalty then
        elseif id == glue then
            if n.subtype == 7 then -- below_display_short_skip
                return true
            end
        else
            break
        end
        n = n.next
    end
    return false
end
