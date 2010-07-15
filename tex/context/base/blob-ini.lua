if not modules then modules = { } end modules ['blob-ini'] = {
    version   = 1.001,
    comment   = "companion to blob-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- later we will consider an OO variant.

-- This module is just a playground. Occasionally we need to typeset
-- at the lua and and this is one method. In principle we can construct
-- pages this way too which sometimes makes sense in dumb cases. Actually,
-- if one only needs this, one does not really need tex, okay maybe the
-- parbuilder but that one can be simplified as well then.

-- set fonts, attributes
-- rest already done in packers etc
-- add local par whatsit (or wait till cleaned up)
-- collapse or new pars
-- interline spacing etc

-- DON'T USE THESE FUNCTIONS AS THEY WILL CHANGE!

local type = type

local report_blobs = logs.new("blobs")

local utfvalues = string.utfvalues
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local fontdata = fonts.identifiers

local new_glyph_node    = nodes.glyph
local new_glue_node     = nodes.glyph

local copy_node         = node.copy
local copy_node_list    = node.copy_list
local insert_node_after = node.insert_after
local flush_node_list   = node.flush_list
local hpack_node_list   = node.hpack
local vpack_node_list   = node.vpack
local write_node        = node.write

local current_font      = font.current

blobs = blobs or  { }

local newline = lpegpatterns.newline
local space   = lpegpatterns.spacer
local spacing = newline * space^0
local content = (space^1)/" " + (1-spacing)

local ctxtextcapture = lpeg.Ct ( (
    space^0 * (
        newline^2 * space^0 * lpeg.Cc("")
      + newline   * space^0 * lpeg.Cc(" ")
      + lpeg.Cs(content^1)
    )
)^0)

local function tonodes(str,fnt,attr) -- (str,template_glyph)
    if not str or str == "" then
        return
    end
    local head, tail, space, fnt, template = nil, nil, nil, nil, nil
    if not fnt then
        fnt = current_font()
    elseif type(fnt) ~= "number" and fnt.id == "glyph" then
        fnt, template = nil, fnt
 -- else
     -- already a number
    end
    for s in utfvalues(str) do
        local n
        if s == 32 then
            if not space then
                local parameters = fontdata[fnt].parameters
                space = new_glue_node(parameters.space,parameters.space_stretch,parameters.space_shrink)
                n = space
            else
                n = copy_node(space)
            end
        elseif template then
            n = copy_node(template)
            n.char = s
        else
            n = new_glyph_node(fnt,s)
        end
        if attr then -- normally false when template
            n.attr = copy_node_list(attr)
        end
        if head then
            insert_node_after(head,tail,n)
        else
            head = n
        end
        tail = n
    end
    return head, tail
end

blobs.tonodes = tonodes

function blobs.new()
    return {
        list = { },
    }
end

function blobs.append(t,str)
    local kind = type(str)
    local dummy = nil
    if kind == "number" then
        str = tostring(str)
        kind = "string"
    end
    local list = t.list
    if kind == "string" then
        local pars = lpegmatch(ctxtextcapture,str)
        for p=1,#pars do
            local str = pars[p]
            if #str == 0 then
                list[#list+1 ] = { head = nil, tail = nil }
            else
                local l = list[#list]
                if not l then
                    l = { head = nil, tail = nil }
                    list[#list+1 ] = l
                end
                local head, tail = tonodes(str,nil,nil)
                if head then
                    if l.head then
                        l.tail.next = head
                        head.prev = l.tail
                        l.tail = tail
                    else
                        l.head, l.tail = head, tail
                    end
                end
            end
        end
    end
end

function blobs.pack(t,how)
    local list = t.list
    for i=1,#list do
        local pack = list[i].pack
        if pack then
            flush_node_list(node.pack)
        end
        if how == "vertical" then
            -- we need to prepend a local par node
            -- list[i].pack = node.vpack(list[i].head,"exactly")
            report_blobs("vpack not yet supported")
        else
            list[i].pack = hpack_node_list(list[i].head,"exactly")
        end
    end
end

function blobs.write(t)
    local list = t.list
    for i=1,#list do
        local pack = list[i].pack
        if pack then
            write_node(pack)
        end
    end
end
