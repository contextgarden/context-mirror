if not modules then modules = { } end modules ['node-shp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local next, type = next, type
local format = string.format
local concat, sortedpairs = table.concat, table.sortedpairs
local setmetatableindex = table.setmetatableindex

local nodecodes      = nodes.nodecodes
local whatsitcodes   = nodes.whatsitcodes
local disccodes      = nodes.disccodes

local tasks          = nodes.tasks
local handlers       = nodes.handlers

local hlist_code     = nodecodes.hlist
local vlist_code     = nodecodes.vlist
local disc_code      = nodecodes.disc
local whatsit_code   = nodecodes.whatsit

local fulldisc_code  = disccodes.discretionary

local texgetbox      = tex.getbox

local implement      = interfaces.implement

local nuts           = nodes.nuts
local tonut          = nuts.tonut
local tonode         = nuts.tonode
local remove_node    = nuts.remove
local traverse_nodes = nuts.traverse

local getfield       = nuts.getfield
local setfield       = nuts.setfield
local setlink        = nuts.setlink
local setprev        = nuts.setprev
local setnext        = nuts.setnext
local getid          = nuts.getid
local getdisc        = nuts.getdisc
local getboth        = nuts.getboth
local getnext        = nuts.getnext
local getlist        = nuts.getlist
local getsubtype     = nuts.getsubtype

local setlist        = nuts.setlist

local removables     = {
    [whatsitcodes.open]    = true,
    [whatsitcodes.close]   = true,
    [whatsitcodes.write]   = true,
    [whatsitcodes.savepos] = true,
    [whatsitcodes.latelua] = true,
    [whatsitcodes.pdfdest] = true,
}

-- About 10% of the nodes make no sense for the backend. By (at least)
-- removing the replace disc nodes, we can omit extensive checking in
-- the finalizer code (e.g. colors in disc nodes). Removing more nodes
-- (like marks) is not saving much and removing empty boxes is even
-- dangerous because we can rely on dimensions (e.g. in references).

local wipedisc = false -- we can use them in the export ... can be option

local function cleanup_redundant(head) -- better name is: flatten_page
    local start = head
    while start do
        local id = getid(start)
        if id == disc_code then
            if getsubtype(start) == fulldisc_code then
                local _, _, replace, _, _ tail = getdisc(start,true)
                if replace then
                    local prev, next = getboth(start)
                    setfield(start,"replace",nil)
                    if start == head then
                        remove_node(head,start,true)
                        head = replace
                    else
                        remove_node(head,start,true)
                    end
                    if next then
                        setlink(tail,next)
                    end
                    if prev then
                        setlink(prev,replace)
                    else
                        setprev(replace) -- to be sure
                    end
                    start = next
                elseif wipedisc then
                    -- pre and post can have values
                    head, start = remove_node(head,start,true)
                else
                    start = getnext(start)
                end
            else
                start = getnext(start)
            end
        elseif id == hlist_code or id == vlist_code then
            local sl = getlist(start)
            if sl then
                local rl = cleanup_redundant(sl)
                if rl ~= sl then
                    setlist(start,rl)
                end
            end
            start = getnext(start)
        else
            start = getnext(start)
        end
    end
    return head
end

local function cleanup_flushed(head) -- rough
    local start = head
    while start do
        local id = getid(start)
        if id == whatsit_code then
            if removables[getsubtype(start)] then
                head, start = remove_node(head,start,true)
            else
                start = getnext(start)
            end
        elseif id == hlist_code or id == vlist_code then
            local sl = getlist(start)
            if sl then
                local rl = cleanup_flushed(sl)
                if rl ~= sl then
                    setlist(start,rl)
                end
            end
            start = getnext(start)
        else
            start = getnext(start)
        end
    end
    return head
end

function handlers.cleanuppage(head)
    return tonode(cleanup_redundant(tonut(head))), true
end

function handlers.cleanupbox(head)
    return tonode(cleanup_flushed(tonut(head))), true
end

local actions = tasks.actions("shipouts")  -- no extra arguments

function handlers.finalize(head) -- problem, attr loaded before node, todo ...
    return actions(head)
end

-- handlers.finalize = actions

-- interface

implement { name = "cleanupbox",  actions = { texgetbox, cleanup_flushed }, arguments = "integer" }
implement { name = "finalizebox", actions = { texgetbox, actions },         arguments = "integer" }

-- just in case we want to optimize lookups:

local frequencies = { }

nodes.tracers.frequencies = frequencies

local data = { }
local done = false

setmetatableindex(data,function(t,k)
    local v = { }
    setmetatableindex(v,function(t,k)
        local v = { }
        t[k] = v
        setmetatableindex(v,function(t,k)
            t[k] = 0
            return 0
        end)
        return v
    end)
    t[k] = v
    return v
end)

local function count(head,data,subcategory)
    -- no components, pre, post, replace .. can maybe an option .. but
    -- we use this for optimization so it makes sense to look the the
    -- main node only
    for n in traverse_nodes(tonut(head)) do
        local id = getid(n)
        local dn = data[nodecodes[id]] -- we could use id and then later convert to nodecodes
        dn[subcategory] = dn[subcategory] + 1
        if id == hlist_code or id == vlist_code then
            count(getlist(n),data,subcategory)
        end
    end
end

local function register(category,subcategory)
    return function(head)
        done = true
        count(head,data[category],subcategory)
        return head, false
    end
end

frequencies.register = register
frequencies.filename = nil

trackers.register("nodes.frequencies",function(v)
    if type(v) == "string" then
        frequencies.filename = v
    end
    handlers.frequencies_shipouts_before   = register("shipouts",   "begin")
    handlers.frequencies_shipouts_after    = register("shipouts",   "end")
    handlers.frequencies_processors_before = register("processors", "begin")
    handlers.frequencies_processors_after  = register("processors", "end")
    tasks.prependaction("shipouts",   "before", "nodes.handlers.frequencies_shipouts_before")
    tasks.appendaction ("shipouts",   "after",  "nodes.handlers.frequencies_shipouts_after")
    tasks.prependaction("processors", "before", "nodes.handlers.frequencies_processors_before")
    tasks.appendaction ("processors", "after",  "nodes.handlers.frequencies_processors_after")
end)

statistics.register("node frequencies", function()
    if done then
        local filename = frequencies.filename or (tex.jobname .. "-frequencies.lua")
        io.savedata(filename,table.serialize(data,true))
        return format("saved in %q",filename)
    end
end)
