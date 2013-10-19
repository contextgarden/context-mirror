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

-- blob.char
-- blob.line
-- blob.paragraph
-- blob.page

local type, tostring = type, tostring
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local report_blobs = logs.reporter("blobs")

local t_tonodes         = typesetters.tonodes
local t_hpack           = typesetters.hpack

local flush_node_list   = node.flush_list
local hpack_node_list   = node.hpack
local vpack_node_list   = node.vpack
local write_node        = node.write

blobs = blobs or  { }

local newline = lpegpatterns.newline
local space   = lpegpatterns.spacer
local spacing = newline * space^0
local content = (space^1)/" " + (1-spacing)

local ctxtextcapture = lpeg.Ct ( ( -- needs checking (see elsewhere)
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

function blobs.dispose(t)
    local list = t.list
    for i=1,#list do
        local li = list[i]
        local pack = li.pack
        if pack then
            flush_node_list(pack)
            li.pack = nil
        end
    end
end

function blobs.append(t,str) -- compare concat and link
    local typ = type(str)
    local dummy = nil
    if typ == "number" then
        str = tostring(str)
        typ = "string"
    end
    local list = t.list
    if typ == "string" then
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
                local head, tail = t_tonodes(str,nil,nil)
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
        local li = list[i]
        local pack = li.pack
        if pack then
            write_node(pack)
            flush_node_list(pack)
            li.pack = nil
        end
    end
end

function blobs.dimensions(t)
    local list = t.list
    local first = list and list[1]
    if first then
        local pack = first.pack
        return pack.width, pack.height, pack.depth
    else
        return 0, 0, 0
    end
end

-- blob.char
-- blob.line: head, tail
-- blob.paragraph
-- blob.page

--~ local lineblob = {
--~     type = "line",
--~     head = false,
--~     tail = false,
--~     pack = false,
--~     properties = { },
--~ end

--~ local parblob = {
--~     type = "line",
--~     head = false,
--~     tail = false,
--~     pack = false,
--~     properties = { },
--~ end

-- for the moment here:

function commands.widthofstring(str)
    local l = t_hpack(str)
    context(number.todimen(l.width))
    flush_node_list(l)
end

-- less efficient:
--
-- function commands.widthof(str)
--     local b = blobs.new()
--     blobs.append(b,str)
--     blobs.pack(b)
--     local w = blobs.dimensions(b)
--     context(number.todimen(w))
--     blobs.dispose(b)
-- end
