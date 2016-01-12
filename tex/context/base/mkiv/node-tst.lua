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

local nuts                       = nodes.nuts

local getfield                   = nuts.getfield
local getnext                    = nuts.getnext
local getprev                    = nuts.getprev
local getid                      = nuts.getid
local getchar                    = nuts.getchar
local getsubtype                 = nuts.getsubtype

local find_node_tail             = nuts.tail

function nuts.leftmarginwidth(n) -- todo: three values
    while n do
        local id = getid(n)
        if id == glue_code then
            return getsubtype(n) == leftskip_code and getfield(n,"width") or 0
        elseif id == whatsit_code then
            n = getnext(n)
        elseif id == hlist_code then
            return getfield(n,"width")
        else
            break
        end
    end
    return 0
end

function nuts.rightmarginwidth(n)
    if n then
        n = find_node_tail(n)
        while n do
            local id = getid(n)
            if id == glue_code then
                return getsubtype(n) == rightskip_code and getfield(n,"width") or 0
            elseif id == whatsit_code then
                n = getprev(n)
            else
                break
            end
        end
    end
    return false
end

function nuts.somespace(n,all)
    if n then
        local id = getid(n)
        if id == glue_code then
            return (all or ((getfield(n,"width") or 0) ~= 0)) and glue_code -- temp: or 0
         -- return (all or (getfield(n,"width") ~= 0)) and glue_code
        elseif id == kern_code then
            return (all or (getfield(n,"kern") ~= 0)) and kern
        elseif id == glyph_code then
            local category = chardata[getchar(n)].category
         -- maybe more category checks are needed
            return (category == "zs") and glyph_code
        end
    end
    return false
end

function nuts.somepenalty(n,value)
    if n then
        local id = getid(n)
        if id == penalty_code then
            if value then
                return getfield(n,"penalty") == value
            else
                return true
            end
        end
    end
    return false
end

function nuts.is_display_math(head)
    local n = getprev(head)
    while n do
        local id = getid(n)
        if id == penalty_code then
        elseif id == glue_code then
            if getsubtype(n) == abovedisplayshortskip_code then
                return true
            end
        else
            break
        end
        n = getprev(n)
    end
    n = getnext(head)
    while n do
        local id = getid(n)
        if id == penalty_code then
        elseif id == glue_code then
            if getsubtype(n) == belowdisplayshortskip_code then
                return true
            end
        else
            break
        end
        n = getnext(n)
    end
    return false
end

nodes.leftmarginwidth  = nodes.vianuts(nuts.leftmarginwidth)
nodes.rightmarginwidth = nodes.vianuts(nuts.rightmarginwidth)
nodes.somespace        = nodes.vianuts(nuts.somespace)
nodes.somepenalty      = nodes.vianuts(nuts.somepenalty)
nodes.is_display_math  = nodes.vianuts(nuts.is_display_math)
