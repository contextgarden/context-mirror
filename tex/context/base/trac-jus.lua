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

local tracers             = nodes.tracers
local tracedrule          = tracers.rule

local new_rule            = nodes.pool.rule
local new_hlist           = nodes.pool.hlist
local new_glue            = nodes.pool.glue
local new_kern            = nodes.pool.kern
local get_list_dimensions = node.dimensions
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

function commands.showjustification(n)
    set(n)
end

trackers.register("visualizers.justification", function(v)
    if v then
        set(1)
    else
        reset()
    end
end)

function checkers.handler(head)
    for current in node.traverse_id(hlist_code,head) do
        if current[a_justification] == 1 then
            current[a_justification] = 0
            local width = current.width
            if width > 0 then
                local list = current.list
                if list then
                    local naturalwidth, naturalheight, naturaldepth = get_list_dimensions(list)
                    local delta = naturalwidth - width
                    if naturalwidth == 0 or delta == 0 then
                        -- special box
                    elseif delta >= max_threshold then
                        local rule = tracedrule(delta,naturalheight,naturaldepth,list.glue_set == 1 and "trace:dr"or "trace:db")
                        current.list = list .. new_hlist(rule)
                    elseif delta <= min_threshold then
                        local alignstate = list[a_alignstate]
                        if alignstate == 1 then
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dc")
                            current.list = new_hlist(rule) .. list
                        elseif alignstate == 2 then
                            local rule = tracedrule(-delta/2,naturalheight,naturaldepth,"trace:dy")
                            current.list = new_hlist(rule^1) .. list .. new_kern(delta/2) .. new_hlist(rule)
                        elseif alignstate == 3 then
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dm")
                            current.list = list .. new_kern(delta) .. new_hlist(rule)
                        else
                            local rule = tracedrule(-delta,naturalheight,naturaldepth,"trace:dg")
                            current.list = list .. new_kern(delta) .. new_hlist(rule)
                        end
                    end
                end
            end
        end
    end
    return head
end
