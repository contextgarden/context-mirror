if not modules then modules = { } end modules ['pack-obj'] = {
    version   = 1.001,
    comment   = "companion to pack-obj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save object references in the main utility table. jobobjects are
reusable components.</p>
--ldx]]--

local commands, context = commands, context

local texcount = tex.count
local allocate = utilities.storage.allocate

local collected = allocate()
local tobesaved = allocate()

local jobobjects = {
    collected = collected,
    tobesaved = tobesaved,
}

job.objects = jobobjects

local function initializer()
    collected = jobobjects.collected
    tobesaved = jobobjects.tobesaved
end

job.register('job.objects.collected', tobesaved, initializer, nil)

function jobobjects.save(tag,number,page)
    local t = { number, page }
    tobesaved[tag], collected[tag] = t, t
end

function jobobjects.set(tag,number,page)
    collected[tag] = { number, page }
end

function jobobjects.get(tag)
    return collected[tag] or tobesaved[tag]
end

function jobobjects.number(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[1] or default
end

function jobobjects.page(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[2] or default
end

-- interface

commands.saveobject = jobobjects.save
commands.setobject  = jobobjects.set

function commands.objectnumber(tag,default)
    local o = collected[tag] or tobesaved[tag]
    context(o and o[1] or default)
end

function commands.objectpage(tag,default)
    local o = collected[tag] or tobesaved[tag]
    context(o and o[2] or default)
end

function commands.doifobjectreferencefoundelse(tag)
    commands.doifelse(collected[tag] or tobesaved[tag])
end

