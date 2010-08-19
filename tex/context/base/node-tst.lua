if not modules then modules = { } end modules ['node-tst'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local chardata                   = characters.data
local nodecodes                  = nodes.nodecodes
local skipcodes                  = nodes.skipcodes

local glue_code                  = nodecodes.glue
local penalty_code               = nodecodes.penalty
local kern_code                  = nodecodes.kern
local glyph_code                 = nodecodes.glyph
local whatsit_code               = nodecodes.whatsit
local hlist_code                 = nodecodes.hlist

local leftskip_code              = skipcodes.leftskip
local rightskip_code             = skipcodes.rightskip
local abovedisplayshortskip_code = skipcodes.abovedisplayshortskip
local belowdisplayshortskip_code = skipcodes.belowdisplayshortskip

local find_node_tail             = node.tail or node.slide

function nodes.the_left_margin(n) -- todo: three values
    while n do
        local id = n.id
        if id == glue_code then
            return n.subtype == leftskip_code and n.spec.width or 0
        elseif id == whatsit_code then
            n = n.next
        elseif id == hlist_code then
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
            if id == glue_code then
                return n.subtype == rightskip_code and n.spec.width or 0
            elseif id == whatsit_code then
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
        if id == glue_code then
            return (all or (n.spec.width ~= 0)) and glue_code
        elseif id == kern_code then
            return (all or (n.kern ~= 0)) and kern
        elseif id == glyph_code then
            local category = chardata[n.char].category
         -- maybe more category checks are needed
            return (category == "zs") and glyph_code
        end
    end
    return false
end

function nodes.somepenalty(n,value)
    if n then
        local id = n.id
        if id == penalty_code then
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
        if id == penalty_code then
        elseif id == glue_code then
            if n.subtype == abovedisplayshortskip_code then
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
        if id == penalty_code then
        elseif id == glue_code then
            if n.subtype == belowdisplayshortskip_code then
                return true
            end
        else
            break
        end
        n = n.next
    end
    return false
end
