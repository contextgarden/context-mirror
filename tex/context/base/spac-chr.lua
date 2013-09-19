if not modules then modules = { } end modules ['spac-chr'] = {
    version   = 1.001,
    comment   = "companion to spac-chr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, lower = string.byte, string.lower

-- beware: attribute copying is bugged ... there will be a proper luatex helper
-- for this

-- to be redone: characters will become tagged spaces instead as then we keep track of
-- spaceskip etc

local next = next

trace_characters = false  trackers.register("typesetters.characters", function(v) trace_characters = v end)

report_characters = logs.reporter("typesetting","characters")

local nodes, node = nodes, node

local insert_node_after  = nodes.insert_after
local remove_node        = nodes.remove
local copy_node_list     = nodes.copy_list
local traverse_id        = nodes.traverse_id

local tasks              = nodes.tasks

local nodepool           = nodes.pool
local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local skipcodes          = nodes.skipcodes
local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue

local space_skip_code    = skipcodes["spaceskip"]

local chardata           = characters.data

local typesetters        = typesetters

local unicodeblocks      = characters.blocks

local characters         = typesetters.characters or { } -- can be predefined
typesetters.characters   = characters

local fonthashes         = fonts.hashes
local fontparameters     = fonthashes.parameters
local fontcharacters     = fonthashes.characters
local fontquads          = fonthashes.quads

local setmetatableindex  = table.setmetatableindex

local a_character        = attributes.private("characters")
local a_alignstate       = attributes.private("alignstate")

local c_zero   = byte('0')
local c_period = byte('.')

local function inject_quad_space(unicode,head,current,fraction)
    local attr = current.attr
    if fraction ~= 0 then
        fraction = fraction * fontquads[current.font]
    end
    local glue = new_glue(fraction)
--     glue.attr = copy_node_list(attr)
    glue.attr = attr
    current.attr = nil
    glue[a_character] = unicode
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function inject_char_space(unicode,head,current,parent)
    local attr = current.attr
    local font = current.font
    local char = fontcharacters[font][parent]
    local glue = new_glue(char and char.width or fontparameters[font].space)
    glue.attr = current.attr
    current.attr = nil
    glue[a_character] = unicode
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function inject_nobreak_space(unicode,head,current,space,spacestretch,spaceshrink)
    local attr = current.attr
    local glue = new_glue(space,spacestretch,spaceshrink)
    local penalty = new_penalty(10000)
    glue.attr = attr
    current.attr = nil
    glue[a_character] = unicode
    head, current = insert_node_after(head,current,penalty)
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function nbsp(head,current)
    local para = fontparameters[current.font]
    if current[a_alignstate] == 1 then -- flushright
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,0,0)
        current.subtype = space_skip_code
    else
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,para.spacestretch,para.spaceshrink)
    end
    return head, current
end

-- assumes nuts or nodes, depending on callers .. so no tonuts here

function characters.replacenbsp(head,original)
    local head, current = nbsp(head,original)
    head = remove_node(head,original,true)
    return head, current
end

function characters.replacenbspaces(head)
    for current in traverse_id(glyph_code,head) do
        if current.char == 0x00A0 then
            local h = nbsp(head,current)
            if h then
                head = remove_node(h,current,true)
            end
        end
    end
    return head
end

-- This initialization might move someplace else if we need more of it. The problem is that
-- this module depends on fonts so we have an order problem.

local nbsphash = { } setmetatableindex(nbsphash,function(t,k)
    for i=unicodeblocks.devanagari.first,unicodeblocks.devanagari.last do nbsphash[i] = true end
    for i=unicodeblocks.kannada   .first,unicodeblocks.kannada   .last do nbsphash[i] = true end
    setmetatableindex(nbsphash,nil)
    return nbsphash[k]
end)

local methods = {

    -- The next one uses an attribute assigned to the character but still we
    -- don't have the 'local' value.

    [0x00A0] = function(head,current) -- nbsp
        local next = current.next
        if next and next.id == glyph_code then
            local char = next.char
            if char == 0x200C or char == 0x200D then -- nzwj zwj
                next = next.next
				if next and nbsphash[next.char] then
                    return false
                end
            elseif nbsphash[char] then
                return false
            end
        end
        local prev = current.prev
        if prev and prev.id == glyph_code and nbsphash[prev.char] then
            return false -- kannada
        end
        return nbsp(head,current)
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
        return inject_nobreak_space(0x202F,head,current,fontquads[current.font]/8)
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
        local id = current.id
        if id == glyph_code then
            local next = current.next
            local char = current.char
            local method = methods[char]
            if method then
                if trace_characters then
                    report_characters("replacing character %C, description %a",char,lower(chardata[char].description))
                end
                local h = method(head,current)
                if h then
                    head = remove_node(h,current,true)
                end
                done = true
            end
            current = next
        else
            current = current.next
        end
    end
    return head, done
end
