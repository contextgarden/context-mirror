if not modules then modules = { } end modules ['spac-chr'] = {
    version   = 1.001,
    comment   = "companion to spac-chr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, lower = string.byte, string.lower

-- to be redone: characters will become tagged spaces instead as then we keep track of
-- spaceskip etc

trace_characters = false  trackers.register("typesetters.characters", function(v) trace_characters = v end)

report_characters = logs.reporter("typesetting","characters")

local nodes, node = nodes, node

local set_attribute      = node.set_attribute
local has_attribute      = node.has_attribute
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove -- ! nodes

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local skipcodes          = nodes.skipcodes
local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue

local space_skip_code    = skipcodes["spaceskip"]

local chardata           = characters.data

local typesetters        = typesetters

local characters         = { }
typesetters.characters   = characters

local fontparameters     = fonts.hashes.parameters
local fontcharacters     = fonts.hashes.characters

local a_character        = attributes.private("characters")
local a_alignstate       = attributes.private("alignstate")

local c_zero   = byte('0')
local c_period = byte('.')

local function inject_quad_space(unicode,head,current,fraction)
    local attr = current.attr
    if fraction ~= 0 then
        fraction = fraction * fontparameters[current.font].quad
    end
    head, current = insert_node_after(head,current,new_glue(fraction))
    current.attr = attr
    set_attribute(current,a_character,unicode)
    return head, current
end

local function inject_char_space(unicode,head,current,parent)
    local attr = current.attr
    local char = fontcharacters[current.font][parent]
    head, current = insert_node_after(head,current,new_glue(char and char.width or fontparameters[current.font].space))
    current.attr = attr
    set_attribute(current,a_character,unicode)
    return head, current
end

local function inject_nobreak_space(unicode,head,current,space,spacestretch,spaceshrink)
    local attr = current.attr
    local next = current.next
    head, current = insert_node_after(head,current,new_penalty(10000))
    head, current = insert_node_after(head,current,new_glue(space,spacestretch,spaceshrink))
    current.attr = attr
    set_attribute(current,a_character,unicode)
    return head, current
end

local methods = {

    -- The next one uses an attribute assigned to the character but still we
    -- don't have the 'local' value.

    [0x00A0] = function(head,current)
        local para = fontparameters[current.font]
        if has_attribute(current,a_alignstate) == 1 then -- flushright
            head, current = inject_nobreak_space(0x00A0,head,current,para.space,0,0)
            current.subtype = space_skip_code
        else
            head, current = inject_nobreak_space(0x00A0,head,current,para.space,para.spacestretch,para.spaceshrink)
        end
        return head, current
    end,

    [0x2000] = function(head,current) -- enquad
        return inject_quad_space(0x2000,head,current,1/2)
    end,

    [0x2001] = function(head,current) -- emquad
        return inject_quad_space(0x2001,head,current,1)
    end,

    [0x2002] = function(head,current) -- enspace
        return inject_quad_space(0x2002,head,current,1/2)
    end,

    [0x2003] = function(head,current) -- emspace
        return inject_quad_space(0x2003,head,current,1)
    end,

    [0x2004] = function(head,current) -- threeperemspace
        return inject_quad_space(0x2004,head,current,1/3)
    end,

    [0x2005] = function(head,current) -- fourperemspace
        return inject_quad_space(0x2005,head,current,1/4)
    end,

    [0x2006] = function(head,current) -- sixperemspace
        return inject_quad_space(0x2006,head,current,1/6)
    end,

    [0x2007] = function(head,current) -- figurespace
        return inject_char_space(0x2007,head,current,c_zero)
    end,

    [0x2008] = function(head,current) -- punctuationspace
        return inject_char_space(0x2008,head,current,c_period)
    end,

    [0x2009] = function(head,current) -- breakablethinspace
        return inject_quad_space(0x2009,head,current,1/8) -- same as next
    end,

    [0x200A] = function(head,current) -- hairspace
        return inject_quad_space(0x200A,head,current,1/8) -- same as previous (todo)
    end,

    [0x200B] = function(head,current) -- zerowidthspace
        return inject_quad_space(0x200B,head,current,0)
    end,

    [0x202F] = function(head,current) -- narrownobreakspace
        return inject_nobreak_space(0x202F,head,current,fontparameters[current.font].space/8)
    end,

    [0x205F] = function(head,current) -- math thinspace
        return inject_nobreak_space(0x205F,head,current,fontparameters[current.font].space/8)
    end,

 -- [0xFEFF] = function(head,current) -- zerowidthnobreakspace
 --     return head, current
 -- end,

}

function characters.handler(head)
    local current = head
    local done = false
    while current do
        local next = current.next
        local id = current.id
        if id == glyph_code then
            local char = current.char
            local method = methods[char]
            if method then
                if trace_characters then
                    report_characters("replacing character U+%04X (%s)",char,lower(chardata[char].description))
                end
                head = method(head,current)
                head = remove_node(head,current,true)
                done = true
            end
        end
        current = next
    end
    return head, done
end
