if not modules then modules = { } end modules ['blob-ini'] = {
    version   = 1.001,
    comment   = "companion to blob-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Experimental ... names and functionality will change ... just a
-- place to collect code, so:
--
-- DON'T USE THESE FUNCTIONS AS THEY WILL CHANGE!
--
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

local type = type

local report_blobs = logs.reporter("blobs")

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local fontdata = fonts.identifiers

local nodepool          = nodes.pool

local new_glyph         = nodepool.glyph
local new_glue          = nodepool.glue

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

function blobs.new()
    return {
        list = { },
    }
end

function blobs.append(t,str) -- will be link nodes.link
    local kind = type(str)
    local dummy = nil
    if kind == "number" then
        str = tostring(str)
        kind = "string"
    end
    local list = t.list
    if kind == "string" then
        local pars = lpegmatch(ctxtextcapture,str)
        local noflist = #list
        for p=1,#pars do
            local str = pars[p]
            if #str == 0 then
                noflist = noflist + 1
                list[noflist] = { head = nil, tail = nil }
            else
                local l = list[noflist]
                if not l then
                    l = { head = nil, tail = nil }
                    noflist = noflist + 1
                    list[noflist] = l
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
