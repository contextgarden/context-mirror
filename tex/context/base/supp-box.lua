if not modules then modules = { } end modules ['supp-box'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is preliminary code

local report_hyphenation = logs.reporter("languages","hyphenation")

local tex, node = tex, node
local context, commands, nodes = context, commands, nodes

local nodecodes    = nodes.nodecodes

local disc_code    = nodecodes.disc
local hlist_code   = nodecodes.hlist
local vlist_code   = nodecodes.vlist
local glue_code    = nodecodes.glue
local glyph_code   = nodecodes.glyph

local new_penalty  = nodes.pool.penalty

local free_node    = node.free
local copynodelist = node.copy_list
local copynode     = node.copy
local texbox       = tex.box

local function hyphenatedlist(list)
    while list do
        local id, next, prev = list.id, list.next, list.prev
        if id == disc_code then
            local hyphen = list.pre
            if hyphen then
                local penalty = new_penalty(-500)
                hyphen.next, penalty.prev = penalty, hyphen
                prev.next, next.prev = hyphen, penalty
                penalty.next, hyphen.prev = next, prev
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
    report_hyphenation("show: %s",nodes.listtoutf(list,false,true))
end

local function checkedlist(list)
    if type(list) == "number" then
        return texbox[list].list
    else
        return list
    end
end

local function applytochars(list,what,nested)
    local doaction = context[what or "ruledhbox"]
    local noaction = context
    local current  = checkedlist(list)
    while current do
        local id = current.id
        if nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytochars(current.list,what,nested)
            context.endhbox()
        elseif id ~= glyph_code then
            noaction(copynode(current))
        else
            doaction(copynode(current))
        end
        current = current.next
    end
end

local function applytowords(list,what,nested)
    local doaction = context[what or "ruledhbox"]
    local noaction = context
    local current  = checkedlist(list)
    local start
    while current do
        local id = current.id
        if id == glue_code then
            if start then
                doaction(copynodelist(start,current))
                start = nil
            end
            noaction(copynode(current))
        elseif nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytowords(current.list,what,nested)
            context.egroup()
        elseif not start then
            start = current
        end
        current = current.next
    end
    if start then
        doaction(copynodelist(start))
    end
end

commands.applytochars = applytochars
commands.applytowords = applytowords
