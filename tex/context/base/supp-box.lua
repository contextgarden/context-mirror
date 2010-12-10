if not modules then modules = { } end modules ['supp-box'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is preliminary code

local nodecodes   = nodes.nodecodes

local disc_code   = nodecodes.disc
local hlist_code  = nodecodes.hlist
local vlist_code  = nodecodes.vlist

local new_penalty = nodes.pool.penalty
local free_node   = node.free

function hyphenatedlist(list)
    while list do
        local id = list.id
        local next = list.next
        local prev = list.prev
        if id == disc_code then
            local hyphen = list.pre
            if hyphen then
                local penalty = new_penalty(-500)
                hyphen.next = penalty
                penalty.prev = hyphen
                prev.next = hyphen
                next.prev = penalty
                penalty.next = next
                hyphen.prev = prev
                list.pre = nil
                free_node(list)
            end
        elseif id == vlist_code or id == hlist_code then
            hyphenatedlist(list.list)
        end
        list = next
    end
end

commands.hyphenatedlist = hyphenatedlist

function commands.showhyphenatedinlist(list)
    commands.writestatus("show hyphens",nodes.listtoutf(list))
end

-- processisolatedwords
