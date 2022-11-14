if not modules then modules = { } end modules ['spac-chr'] = {
    version   = 1.001,
    optimize  = true,
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

-- todo: only setattr when export / use properties

local next = next

local trace_characters = false  trackers.register("typesetters.characters", function(v) trace_characters = v end)
local trace_nbsp       = false  trackers.register("typesetters.nbsp",       function(v) trace_nbsp       = v end)

local report_characters = logs.reporter("typesetting","characters")

local nodes, node = nodes, node

local nuts               = nodes.nuts

local getid              = nuts.getid
local getboth            = nuts.getboth
local getsubtype         = nuts.getsubtype
local setsubtype         = nuts.setsubtype
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getlanguage        = nuts.getlanguage
local setchar            = nuts.setchar
local setattrlist        = nuts.setattrlist
local getfont            = nuts.getfont
local isglyph            = nuts.isglyph

local setcolor           = nodes.tracers.colors.set

local insertnodebefore   = nuts.insertbefore
local insertnodeafter    = nuts.insertafter
local remove_node        = nuts.remove
local nextchar           = nuts.traversers.char
local nextglyph          = nuts.traversers.glyph

local copy_node          = nuts.copy

local nodepool           = nuts.pool
local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue
local new_kern           = nodepool.kern
local new_rule           = nodepool.rule

local nodecodes          = nodes.nodecodes
local gluecodes          = nodes.gluecodes

local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue
local spaceskip_code     = gluecodes.spaceskip

local chardata           = characters.data
local ispunctuation      = characters.is_punctuation
local canhavespace       = characters.can_have_space

local typesetters        = typesetters

local unicodeblocks      = characters.blocks

local characters         = typesetters.characters or { } -- can be predefined
typesetters.characters   = characters

local fonthashes         = fonts.hashes
local fontparameters     = fonthashes.parameters
local fontcharacters     = fonthashes.characters
local fontquads          = fonthashes.quads

local setmetatableindex  = table.setmetatableindex

local a_character        = attributes.private("characters") -- this will become a property (or maybe even a field)
local a_alignstate       = attributes.private("alignstate")

local c_zero   = byte('0')
local c_period = byte('.')

local function inject_quad_space(unicode,head,current,fraction)
    if fraction ~= 0 then
        fraction = fraction * fontquads[getfont(current)]
    end
    local glue = new_glue(fraction)
    setattrlist(glue,current)
    setattrlist(current) -- why reset all
    setattr(glue,a_character,unicode)
    return insertnodeafter(head,current,glue)
end

local function inject_char_space(unicode,head,current,parent)
    local font = getfont(current)
    local char = fontcharacters[font][parent]
    local glue = new_glue(char and char.width or fontparameters[font].space)
    setattrlist(glue,current)
    setattrlist(current) -- why reset all
    setattr(glue,a_character,unicode)
    return insertnodeafter(head,current,glue)
end

local function inject_nobreak_space(unicode,head,current,space,spacestretch,spaceshrink)
    local glue    = new_glue(space,spacestretch,spaceshrink)
    local penalty = new_penalty(10000)
    setattrlist(glue,current)
    setattrlist(current) -- why reset all
    setattr(glue,a_character,unicode) -- bombs
    head, current = insertnodeafter(head,current,penalty)
    if trace_nbsp then
        local rule    = new_rule(space)
        local kern    = new_kern(-space)
        local penalty = new_penalty(10000)
        setcolor(rule,"orange")
        head, current = insertnodeafter(head,current,rule)
        head, current = insertnodeafter(head,current,kern)
        head, current = insertnodeafter(head,current,penalty)
    end
    return insertnodeafter(head,current,glue)
end

local function nbsp(head,current)
    local para = fontparameters[getfont(current)]
    local attr = getattr(current,a_alignstate) or 0
    if attr >= 1 and attr <= 3 then -- flushright
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,0,0)
    else
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,para.spacestretch,para.spaceshrink)
    end
    setsubtype(current,spaceskip_code)
    return head, current
end

-- assumes nuts or nodes, depending on callers .. so no tonuts here

function characters.replacenbsp(head,original)
    local head, current = nbsp(head,original)
    return remove_node(head,original,true)
end

function characters.replacenbspaces(head)
    local wipe = false
    for current, char, font in nextglyph, head do -- can be anytime so no traversechar
        if char == 0x00A0 then
            if wipe then
                head = remove_node(h,current,true)
                wipe = false
            end
            local h = nbsp(head,current)
            if h then
                wipe = current
            end
        end
    end
    if wipe then
        head = remove_node(head,current,true)
    end
    return head
end

-- This initialization might move someplace else if we need more of it. The problem is that
-- this module depends on fonts so we have an order problem.

local nbsphash = { } setmetatableindex(nbsphash,function(t,k)
    -- this needs checking !
    for i=unicodeblocks.devanagari.first,unicodeblocks.devanagari.last do nbsphash[i] = true end
    for i=unicodeblocks.kannada   .first,unicodeblocks.kannada   .last do nbsphash[i] = true end
    setmetatableindex(nbsphash,nil)
    return nbsphash[k]
end)

local methods = {

    -- The next one uses an attribute assigned to the character but still we
    -- don't have the 'local' value.

    -- maybe also 0x0008 : backspace

    [0x001E] = function(head,current) -- kind of special
        local next = getnext(current)
        head, current = remove_node(head,current,true)
        if next and getid(next) == glue_code and getsubtype(next) == spaceskip_code then
            local nextnext = getnext(next)
            if nextnext then
                local char, font = isglyph(nextnext)
                if char and not canhavespace[char] then
                    remove_node(head,next,true)
                end
            end
        end
    end,

    [0x001F] = function(head,current) -- kind of special
        local next = getnext(current)
        if next then
            local char, font = isglyph(next)
            if char then
                head, current = remove_node(head,current,true)
                if not ispunctuation[char] then
                    local p = fontparameters[font]
                    head, current = insertnodebefore(head,current,new_glue(p.space,p.space_stretch,p.space_shrink))
                end
            end
        end
    end,

    [0x00A0] = function(head,current) -- nbsp
        local prev, next = getboth(current)
        if next then
            local char = isglyph(current)
            if not char then
                -- move on
            elseif char == 0x200C or char == 0x200D then -- nzwj zwj
                next = getnext(next)
				if next then
                    char = isglyph(next)
                    if char and nbsphash[char] then
                        return false
                    end
                end
            elseif nbsphash[char] then
                return false
            end
        end
        if prev then
            local char = isglyph(prev)
            if char and nbsphash[char] then
                return false
            end
        end
        return nbsp(head,current)
    end,

    [0x00AD] = function(head,current) -- softhyphen
        return insertnodeafter(head,current,languages.explicithyphen(current))
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
        return inject_nobreak_space(0x202F,head,current,fontquads[getfont(current)]/8)
    end,

    [0x205F] = function(head,current) -- math thinspace
        return inject_nobreak_space(0x205F,head,current,4*fontquads[getfont(current)]/18)
    end,

    -- The next one is also a bom so maybe only when we have glyphs around it

 -- [0xFEFF] = function(head,current) -- zerowidthnobreakspace
 --     return head, current
 -- end,

}

characters.methods = methods

-- this also works ok in math as we run over glyphs and these stay glyphs ... not sure
-- about scripts and such but that is not important anyway ... some day we can consider
-- special definitions in math

function characters.handler(head)
    local wipe = false
    for current, char in nextchar, head do
        local method = methods[char]
        if method then
            if wipe then
                head = remove_node(head,wipe,true)
                wipe = false
            end
            if trace_characters then
                report_characters("replacing character %C, description %a",char,lower(chardata[char].description))
            end
            local h = method(head,current)
            if h then
                wipe = current
            end
        end
    end
    if wipe then
        head = remove_node(head,wipe,true)
    end
    return head
end
