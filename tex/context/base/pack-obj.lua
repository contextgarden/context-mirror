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

local texsprint, texcount = tex.sprint, tex.count

local jobobjects = {
    collected = { },
    tobesaved = { },
}

job.objects = jobobjects

local collected, tobesaved = jobobjects.collected, jobobjects.tobesaved

local function initializer()
    collected, tobesaved = jobobjects.collected, jobobjects.tobesaved
end

job.register('job.objects.collected', jobobjects.tobesaved, initializer, nil)

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
    texsprint((o and o[1]) or default)
end

function jobobjects.page(tag,default)
    local o = collected[tag] or tobesaved[tag]
    texsprint((o and o[2]) or default)
end

function jobobjects.doifelse(tag)
    commands.testcase(collected[tag] or tobesaved[tag])
end

