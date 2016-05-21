if not modules then modules = { } end modules ['trac-jus'] = {
    version   = 1.001,
    comment   = "companion to trac-jus.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local checkers            = typesetters.checkers or { }
typesetters.checkers      = checkers

----- report_justification = logs.reporter("visualize","justification")

local a_alignstate        = attributes.private("alignstate")
local a_justification     = attributes.private("justification")

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local setfield            = nuts.setfield
local getlist             = nuts.getlist
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local setlist             = nuts.setlist

local traverse_id         = nuts.traverse_id
local get_list_dimensions = nuts.dimensions
local linked_nodes        = nuts.linked
local copy_node           = nuts.copy

local tracedrule          = nodes.tracers.pool.nuts.rule

local nodepool            = nuts.pool

local new_hlist           = nodepool.hlist
local new_kern            = nodepool.kern

local hlist_code          = nodes.nodecodes.hlist

local texsetattribute     = tex.setattribute
local unsetvalue          = attributes.unsetvalue

local min_threshold = 0
local max_threshold = 0

local function set(n)
    nodes.tasks.enableaction("mvlbuilders", "typesetters.checkers.handler")
    nodes.tasks.enableaction("vboxbuilders","typesetters.checkers.handler")
    texsetattribute(a_justification,n or 1)
    function typesetters.checkers.set(n)
        texsetattribute(a_justification,n or 1)
    end
end

local function reset()
    texsetattribute(a_justification,unsetvalue)
end

checkers.set   = set
checkers.reset = reset

interfaces.implement {
    name    = "showjustification",
    actions = set
}

trackers.register("visualizers.justification", function(v)
    if v then
        set(1)
    else
        reset()
    end
end)

function checkers.handler(head)
    for current in traverse_id(hlist_code,tonut(head)) do
        if getattr(current,a_justification) == 1 then
            setattr(current,a_justification,0) -- kind of reset
            local width = getfield(current,"width")
            if width > 0 then
                local list = getlist(current)
                if list then
                    local naturalwidth, naturalheight, naturaldepth = get_list_dimensions(list)
                    local delta = naturalwidth - width
                    if naturalwidth == 0 or delta == 0 then
                        -- special box
                    elseif delta >= max_threshold then
                        local rule = tracedrule(delta,naturalheight,naturaldepth,getfield(list,"glue_set") == 1 and "trace:dr" or "trace:db")
                        setlist(current,linked_nodes(list,new_hlist(rule)))
                    elseif delta <= min_threshold then
                        local alignstate = getattr(list,a_alignstate)
                        if alignstate == 1 then
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dc")
                            setlist(current,linked_nodes(new_hlist(rule),list))
                        elseif alignstate == 2 then
                            local lrule = tracedrule(-delta/2,naturalheight,naturaldepth,"trace:dy")
                            local rrule = copy_node(lrule)
                            setlist(current,linked_nodes(new_hlist(lrule),list,new_kern(delta/2),new_hlist(rrule)))
                        elseif alignstate == 3 then
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dm")
                            setlist(current,linked_nodes(list,new_kern(delta),new_hlist(rule)))
                        else
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dg")
                            setlist(current,linked_nodes(list,new_kern(delta),new_hlist(rule)))
                        end
                    end
                end
            end
        end
    end
    return head
end
