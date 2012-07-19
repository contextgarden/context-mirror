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
local appendaction     = tasks.appendaction
local prependaction    = tasks.prependaction
local disableaction    = tasks.disableaction
local enableaction     = tasks.enableaction

local has_attribute    = node.has_attribute
local unset_attribute  = node.unset_attribute
local slide_nodes      = node.slide
local hpack_nodes      = node.hpack -- nodes.fasthpack not really faster here

local concat_nodes     = nodes.concat

local nodecodes        = nodes.nodecodes
local listcodes        = nodes.listcodes

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local line_code        = listcodes.line

local nodepool         = nodes.pool

local new_stretch      = nodepool.stretch

local a_realign        = attributes.private("realign")

local texattribute     = tex.attribute
local texcount         = tex.count

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
        local id = current.id
        if id == hlist_code then
            if current.subtype == line_code then
                local a = has_attribute(current,a_realign)
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
                            current.list = hpack_nodes(concat_nodes(current.list,new_stretch(3)),current.width,"exactly")
                            if trace_realign then
                                report_realign("flush left: align %s, page %s, realpage %s",align,pageno,realpageno)
                            end
                        elseif action == 2 then
                            current.list = hpack_nodes(concat_nodes(new_stretch(3),current.list),current.width,"exactly")
                            if trace_realign then
                                report_realign("flush right: align %s, page %s, realpage %s",align,pageno,realpageno)
                            end
                        elseif trace_realign then
                            report_realign("invalid: align %s, page %s, realpage %s",align,pageno,realpageno)
                        end
                        done = true
                        nofrealigned = nofrealigned + 1
                    end
                    unset_attribute(current,a_realign)
                end
            end
            handler(current.list,leftpage,realpageno)
        elseif id == vlist_code then
            handler(current.list,leftpage,realpageno)
        end
        current = current.next
    end
    return head, done
end

function alignments.handler(head)
    local leftpage = isleftpage(true,false)
    local realpageno = texcount.realpageno
    return handler(head,leftpage,realpageno)
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
    texattribute[a_realign] = texcount.realpageno * 10 + n
end

commands.setrealign = alignments.set

statistics.register("realigning", function()
    if nofrealigned > 0 then
        return format("%s processed",nofrealigned)
    else
        return nil
    end
end)
