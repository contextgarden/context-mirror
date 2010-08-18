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

local nodecodes      = nodes.nodecodes

local hlist_code     = nodecodes.hlist
local vlist_code     = nodecodes.vlist

local has_attribute  = node.has_attribute
local set_attribute  = node.set_attribute
local traverse       = node.traverse

local nodepool       = nodes.pool
local tasks          = nodes.tasks

local new_rule       = nodepool.rule
local new_glue       = nodepool.glue

local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')
local a_background   = attributes.private('background')

local function add_backgrounds(head) -- boxes, inline will be done too
    local id = head.id
    if id == vlist_code or id == hlist_code then
        local current = head.list
        while current do
            local id = current.id
            if id == hlist_code then -- and current.list
                local background = has_attribute(current,a_background)
                if background then
                    -- direct to hbox
                    -- colorspace is already set so we can omit that and stick to color
                    local mode = has_attribute(current,a_colorspace)
                    if mode then
                        local glue = new_glue(-current.width)
                        local rule = new_rule(current.width,current.height,current.depth)
                        local color = has_attribute(current,a_color)
                        local transparency = has_attribute(current,a_transparency)
                        set_attribute(rule,a_colorspace, mode)
                        if color then
                            set_attribute(rule,a_color, color)
                        end
                        if transparency then
                            set_attribute(rule,a_transparency,transparency)
                        end
                        rule.next = glue
                        glue.next = current.list
                        current.list = rule
                    end
                else
                    -- temporary hack for aligments
                    local list, background, found = current.list, nil, nil
                    for l in traverse(list) do
                        background = has_attribute(l,a_background)
                        if background then
                            found = l
                            break
                        end
                    end
                    if background then
                        local mode = has_attribute(found,a_colorspace)
                        if mode then
                            local glue = new_glue(-current.width)
                            local rule = new_rule(current.width,current.height,current.depth)
                            local color = has_attribute(found,a_color)
                            local transparency = has_attribute(found,a_transparency)
                            set_attribute(rule,a_colorspace, mode)
                            if color then
                                set_attribute(rule,a_color, color)
                            end
                            if transparency then
                                set_attribute(rule,a_transparency,transparency)
                            end
                            rule.next = glue
                            glue.next = list
                            current.list = rule
                        end
                    else
                        add_backgrounds(current)
                    end
                end
            elseif id == vlist_code then -- and current.list
                    -- direct to vbox
                local background = has_attribute(current,a_background)
                if background then
                    local mode = has_attribute(current,a_colorspace)
                    if mode then
                        local glue = new_glue(-current.height-current.depth)
                        local rule = new_rule(current.width,current.height,current.depth)
                        local color = has_attribute(current,a_color)
                        local transparency = has_attribute(current,a_transparency)
                        set_attribute(rule,a_colorspace, mode)
                        if color then
                            set_attribute(rule,a_color, color)
                        end
                        if transparency then
                            set_attribute(rule,a_transparency,transparency)
                        end
                        rule.next = glue
                        glue.next = current.list
                        current.list = rule
                    end
                end
                add_backgrounds(current)
            end
            current = current.next
        end
    end
    return head, true
end

nodes.handlers.backgrounds = add_backgrounds

tasks.appendaction("shipouts","normalizers","nodes.handlers.backgrounds")
