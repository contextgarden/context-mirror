if not modules then modules = { } end modules ['core-obj'] = {
    version   = 1.001,
    comment   = "companion to core-obj.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save object references in the main utility table. Objects are
reusable components.</p>
--ldx]]--

local texsprint = tex.sprint

if not jobs        then jobs         = { } end
if not job         then jobs['main'] = { } end job = jobs['main']
if not job.objects then job.objects  = { } end

function job.getobjectreference(tag,default)
    if job.objects[tag] then
        texsprint(job.objects[tag][1] or default)
    else
        texsprint(default)
    end
end

function job.getobjectreferencepage(tag,default)
    if job.objects[tag] then
        texsprint(job.objects[tag][2] or default)
    else
        texsprint(default)
    end
end

function job.doifobjectreference(tag)
    cs.testcase(job.objects[tag])
end
