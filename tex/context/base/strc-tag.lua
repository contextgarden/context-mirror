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

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.new("tags")

local attributes, structures = attributes, structures

local a_tagged       = attributes.private('tagged')
local a_image        = attributes.private('image')

local unsetvalue     = attributes.unsetvalue
local codeinjections = backends.codeinjections

local taglist, labels, stack, chain, ids, enabled = { }, { }, { }, { }, { }, false -- no grouping assumed

structures.tags = structures.tags or { }
local tags      = structures.tags
tags.taglist    = taglist -- can best be hidden

function tags.start(tag,label,detail)
    labels[tag] = label ~= "" and label or tag
    if detail and detail ~= "" then
        tag = tag .. ":" .. detail
    end
    if not enabled then
        codeinjections.enabletags(taglist,labels)
        enabled = true
    end
    local n = (ids[tag] or 0) + 1
    ids[tag] = n
    chain[#chain+1] = tag .. "-" .. n -- insert(chain,tag .. ":" .. n)
    local t = #taglist + 1
    stack[#stack+1] = t -- insert(stack,t)
    taglist[t] = { unpack(chain) } -- we can add key values for alt and actualtext if needed
    texattribute[a_tagged] = t
    return t
end

function tags.stop()
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

function structures.atlocation(str)
    local location = gsub(concat(taglist[texattribute[a_tagged]],"-"),"%-%d+","")
    return find(location,topattern(str)) ~= nil
end

function tags.handler(head)  -- we need a dummy
    return head, false
end

statistics.register("structure elements", function()
    if enabled then
        return format("%s element chains identified",#taglist)
    else
        return nil
    end
end)

directives.register("backend.addtags", function(v)
    if not enabled then
        codeinjections.enabletags(taglist,labels)
        enabled = true
    end
end)
