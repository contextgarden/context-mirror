if not modules then modules = { } end modules ['strc-tag'] = {
    version   = 1.001,
    comment   = "companion to strc-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is rather experimental code.

local insert, remove, unpack, concat = table.insert, table.remove, table.unpack, table.concat
local gsub, find, topattern, format = string.gsub, string.find, string.topattern, string.format
local lpegmatch = lpeg.match
local texattribute = tex.attribute
local unsetvalue = attributes.unsetvalue

structure.tags = structure.tags or { }

local report_tags = logs.new("tags")

local trace_tags = false  trackers.register("structure.tags", function(v) trace_tags = v end)

local a_tagged = attributes.private('tagged')
local a_image  = attributes.private('image')

local tags, labels, stack, chain, ids, enabled = { }, { }, { }, { }, { }, false -- no grouping assumed

structure.tags.taglist = tags -- can best be hidden

function structure.tags.start(tag,label,detail)
--~     labels[label or tag] = tag
    labels[tag] = label ~= "" and label or tag
    if detail and detail ~= "" then
        tag = tag .. ":" .. detail
    end
    if not enabled then
        backends.codeinjections.enabletags(tags,labels)
        enabled = true
    end
    local n = (ids[tag] or 0) + 1
    ids[tag] = n
    chain[#chain+1] = tag .. "-" .. n -- insert(chain,tag .. ":" .. n)
    local t = #tags + 1
    stack[#stack+1] = t -- insert(stack,t)
    tags[t] = { unpack(chain) } -- we can add key values for alt and actualtext if needed
    texattribute[a_tagged] = t
    return t
end

function structure.tags.stop()
    local t = stack[#stack] stack[#stack] = nil -- local t = remove(stack)
    if not t then
        if trace_tags then
            report_tags("ignoring end tag, previous chain: %s",#chain > 0 and concat(chain[#chain]) or "none")
        end
        t = unsetvalue
    else
        chain[#chain] = nil -- remove(chain)
    end
    texattribute[a_tagged] = t
    return t
end

function structure.atlocation(str)
    local location = gsub(concat(tags[texattribute[a_tagged]],"-"),"%-%d+","")
    return find(location,topattern(str)) ~= nil
end

function structure.tags.handler(head)  -- we need a dummy
    return head, false
end

statistics.register("structure elements", function()
    if enabled then
        return format("%s element chains identified",#tags)
    else
        return nil
    end
end)

directives.register("backend.addtags", function(v)
    if not enabled then
        backends.codeinjections.enabletags(tags,labels)
        enabled = true
    end
end)
