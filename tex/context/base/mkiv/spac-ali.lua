if not modules then modules = { } end modules ['spac-ali'] = {
    version   = 1.001,
    comment   = "companion to spac-ali.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local div = math.div
local format = string.format

local tasks            = nodes.tasks
local enableaction     = tasks.enableaction

local nuts             = nodes.nuts
local nodepool         = nuts.pool

local tonode           = nuts.tonode
local tonut            = nuts.tonut

local getfield         = nuts.getfield
local setfield         = nuts.setfield
local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getlist          = nuts.getlist
local setlist          = nuts.setlist
local getattr          = nuts.getattr
local setattr          = nuts.setattr
local getsubtype       = nuts.getsubtype

local hpack_nodes      = nuts.hpack
local linked_nodes     = nuts.linked

local unsetvalue       = attributes.unsetvalue

local nodecodes        = nodes.nodecodes
local listcodes        = nodes.listcodes

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local line_code        = listcodes.line

local new_stretch      = nodepool.stretch

local a_realign        = attributes.private("realign")

local texsetattribute  = tex.setattribute
local texgetcount      = tex.getcount

local isleftpage       = layouts.status.isleftpage

typesetters            = typesetters or { }
local alignments       = { }
typesetters.alignments = alignments

local report_realign   = logs.reporter("typesetters","margindata")
local trace_realign    = trackers.register("typesetters.margindata", function(v) trace_margindata = v end)

local nofrealigned     = 0

--                leftskip   rightskip parfillskip
-- raggedleft      0 +         0          -
-- raggedright     0           0         fil
-- raggedcenter    0 +         0 +        -

local function handler(head,leftpage,realpageno)
    local current = head
    local done = false
    while current do
        local id = getid(current)
        if id == hlist_code then
            if getsubtype(current) == line_code then
                local a = getattr(current,a_realign)
                if not a or a == 0 then
                    -- skip
                else
                    local align = a % 10
                    local pageno = div(a,10)
                    if pageno == realpageno then
                        -- already ok
                    else
                        local action = 0
                        if align == 1 then -- flushright
                            action = leftpage and 1 or 2
                        elseif align == 2 then -- flushleft
                            action = leftpage and 2 or 1
                        end
                        if action == 1 then
                            setlist(current,hpack_nodes(linked_nodes(getlist(current),new_stretch(3)),getfield(current,"width"),"exactly"))
                            if trace_realign then
                                report_realign("flushing left, align %a, page %a, realpage %a",align,pageno,realpageno)
                            end
                        elseif action == 2 then
                            setlist(current,hpack_nodes(linked_nodes(new_stretch(3),getlist(current)),getfield(current,"width"),"exactly"))
                            if trace_realign then
                                report_realign("flushing right. align %a, page %a, realpage %a",align,pageno,realpageno)
                            end
                        elseif trace_realign then
                            report_realign("invalid flushing, align %a, page %a, realpage %a",align,pageno,realpageno)
                        end
                        done = true
                        nofrealigned = nofrealigned + 1
                    end
                    setattr(current,a_realign,unsetvalue)
                end
            end
            handler(getlist(current),leftpage,realpageno)
        elseif id == vlist_code then
            handler(getlist(current),leftpage,realpageno)
        end
        current = getnext(current)
    end
    return head, done
end

function alignments.handler(head)
    local leftpage = isleftpage()
    local realpageno = texgetcount("realpageno")
    local head, done = handler(tonut(head),leftpage,realpageno)
    return tonode(head), done
end

local enabled = false

function alignments.set(n)
    if not enabled then
        enableaction("shipouts","typesetters.alignments.handler")
        enabled = true
        if trace_realign then
            report_realign("enabled")
        end
    end
    texsetattribute(a_realign,texgetcount("realpageno") * 10 + n)
end

interfaces.implement {
    name      = "setrealign",
    actions   = alignments.set,
    arguments = "integer",
}

statistics.register("realigning", function()
    if nofrealigned > 0 then
        return format("%s processed",nofrealigned)
    else
        return nil
    end
end)
