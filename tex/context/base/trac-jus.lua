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
local setcolor            = tracers.colors.set
local settransparency     = tracers.transparencies.set

local new_rule            = nodes.pool.rule
local new_glue            = nodes.pool.glue
local new_kern            = nodes.pool.kern
local concat_nodes        = nodes.concat
local hpack_nodes         = node.hpack
local copy_node           = node.copy
local get_list_dimensions = node.dimensions
local hlist_code          = nodes.nodecodes.hlist

local tex_set_attribute   = tex.setattribute
local unsetvalue          = attributes.unsetvalue

local min_threshold = 0
local max_threshold = 0

local function set(n)
    nodes.tasks.enableaction("mvlbuilders", "typesetters.checkers.handler")
    nodes.tasks.enableaction("vboxbuilders","typesetters.checkers.handler")
    tex_set_attribute(a_justification,n or 1)
    function typesetters.checkers.set(n)
        tex_set_attribute(a_justification,n or 1)
    end
end

local function reset()
    tex_set_attribute(a_justification,unsetvalue)
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
                        local rule = new_rule(delta,naturalheight,naturaldepth)
                        list = hpack_nodes(list,width,"exactly")
                        if list.glue_set == 1 then
                            setcolor(rule,"trace:dr")
                            settransparency(rule,"trace:dr")
                        else
                            setcolor(rule,"trace:db")
                            settransparency(rule,"trace:db")
                        end
                        rule = hpack_nodes(rule)
                        rule.width = 0
                        rule.height = 0
                        rule.depth = 0
                        current.list = concat_nodes { list, rule }
                     -- current.list = concat_nodes { list, new_kern(-naturalwidth+width), rule }
                    elseif delta <= min_threshold then
                        local alignstate = list[a_alignstate]
                        if alignstate == 1 then
                            local rule = new_rule(-delta,naturalheight,naturaldepth)
                            setcolor(rule,"trace:dc")
                            settransparency(rule,"trace:dc")
                            rule = hpack_nodes(rule)
                            rule.height = 0
                            rule.depth = 0
                            rule.width = 0
                            current.list = nodes.concat { rule, list }
                        elseif alignstate == 2 then
                            local rule = new_rule(-delta/2,naturalheight,naturaldepth)
                            setcolor(rule,"trace:dy")
                            settransparency(rule,"trace:dy")
                            rule = hpack_nodes(rule)
                            rule.width = 0
                            rule.height = 0
                            rule.depth = 0
                            current.list = concat_nodes { copy_node(rule), list, new_kern(delta/2), rule }
                        elseif alignstate == 3 then
                            local rule = new_rule(-delta,naturalheight,naturaldepth)
                            setcolor(rule,"trace:dm")
                            settransparency(rule,"trace:dm")
                            rule = hpack_nodes(rule)
                            rule.height = 0
                            rule.depth = 0
                            current.list = concat_nodes { list, new_kern(delta), rule }
                        else
                            local rule = new_rule(-delta,naturalheight,naturaldepth)
                            setcolor(rule,"trace:dg")
                            settransparency(rule,"trace:dg")
                            rule = hpack_nodes(rule)
                            rule.height = 0
                            rule.depth = 0
                            rule.width = 0
                            current.list = concat_nodes { list, new_kern(delta), rule }
                        end
                    end
                end
            end
        end
    end
    return head
end
