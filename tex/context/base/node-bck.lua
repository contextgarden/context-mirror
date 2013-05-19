if not modules then modules = { } end modules ['node-bck'] = {
    version   = 1.001,
    comment   = "companion to node-bck.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, this one takes quite some runtime, so we need a status flag
-- maybe some page related state

local attributes, nodes, node = attributes, nodes, node

local nodecodes         = nodes.nodecodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local glyph_code        = nodecodes.glyph
local cell_code         = listcodes.cell

local traverse          = node.traverse
local traverse_id       = node.traverse_id

local nodepool          = nodes.pool
local tasks             = nodes.tasks

local new_rule          = nodepool.rule
local new_glue          = nodepool.glue

local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colorspace      = attributes.private('colormodel')
local a_background      = attributes.private('background')
local a_alignbackground = attributes.private('alignbackground')

local function add_backgrounds(head) -- rather old code .. to be redone
    local current = head
    while current do
        local id = current.id
        if id == hlist_code or id == vlist_code then
            local list = current.list
            if list then
                local head = add_backgrounds(list)
                if head then
                    current.list = head
                    list = head
                end
            end
            local width = current.width
            if width > 0 then
                local background = current[a_background]
                if background then
                    -- direct to hbox
                    -- colorspace is already set so we can omit that and stick to color
                    local mode = current[a_colorspace]
                    if mode then
                        local height = current.height
                        local depth = current.depth
                        local skip = id == hlist_code and width or (height + depth)
                        local glue = new_glue(-skip)
                        local rule = new_rule(width,height,depth)
                        local color = current[a_color]
                        local transparency = current[a_transparency]
                        rule[a_colorspace] = mode
                        if color then
                            rule[a_color] = color
                        end
                        if transparency then
                            rule[a_transparency] = transparency
                        end
                        rule.next = glue
                        glue.prev = rule
                        if list then
                            glue.next = list
                            list.prev = glue
                        end
                        current.list = rule
                    end
                end
            end
        end
        current = current.next
    end
    return head, true
end

local function add_alignbackgrounds(head)
    local current = head
    while current do
        local id = current.id
        if id == hlist_code then
            local list = current.list
            if not list then
                -- no need to look
            elseif current.subtype == cell_code then
                local background = nil
                local found = nil
             -- for l in traverse(list) do
             --     background = l[a_alignbackground]
             --     if background then
             --         found = l
             --         break
             --     end
             -- end
                -- we know that it's a fake hlist (could be user node)
                -- but we cannot store tables in user nodes yet
                for l in traverse_id(hpack_code,list) do
                    background = l[a_alignbackground]
                    if background then
                        found = l
                    end
                    break
                end
                --
                if background then
                    -- current has subtype 5 (cell)
                    local width = current.width
                    if width > 0 then
                        local mode = found[a_colorspace]
                        if mode then
                            local glue = new_glue(-width)
                            local rule = new_rule(width,current.height,current.depth)
                            local color = found[a_color]
                            local transparency = found[a_transparency]
                            rule[a_colorspace] = mode
                            if color then
                                rule[a_color] = color
                            end
                            if transparency then
                                rule[a_transparency] = transparency
                            end
                            rule.next = glue
                            glue.prev = rule
                            if list then
                                glue.next = list
                                list.prev = glue
                            end
                            current.list = rule
                        end
                    end
                end
            else
                add_alignbackgrounds(list)
            end
        elseif id == vlist_code then
            local list = current.list
            if list then
                add_alignbackgrounds(list)
            end
        end
        current = current.next
    end
    return head, true
end

nodes.handlers.backgrounds      = add_backgrounds
nodes.handlers.alignbackgrounds = add_alignbackgrounds

tasks.appendaction("shipouts","normalizers","nodes.handlers.backgrounds")
tasks.appendaction("shipouts","normalizers","nodes.handlers.alignbackgrounds")
