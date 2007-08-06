if not modules then modules = { } end modules ['core-pos'] = {
    version   = 1.001,
    comment   = "companion to core-pos.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save positional information in the main utility table. Not only
can we store much more information in <l n='lua'/> but it's also
more efficient.</p>
--ldx]]--

if not jobs          then jobs          = { } end
if not job           then jobs['main']  = { } end job = jobs['main']
if not job.positions then job.positions = { } end

function job.MPp(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[1]) else tex.sprint('0'  ) end end
function job.MPx(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[2]) else tex.sprint('0pt') end end
function job.MPy(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[3]) else tex.sprint('0pt') end end
function job.MPw(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[4]) else tex.sprint('0pt') end end
function job.MPh(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[5]) else tex.sprint('0pt') end end
function job.MPd(id) local jpi = job.positions[id] if jpi then tex.sprint(jpi[6]) else tex.sprint('0pt') end end

function job.MPxy(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint('('..jpi[2]..','..jpi[3]..')')
    else
        tex.sprint('(0pt,0pt)')
    end
end

function job.MPll(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint('('..jpi[2]..'-'..-jpi[3]..','..jpi[6]..')')
    else
        tex.sprint('(0pt,0pt)')
    end
end
function job.MPlr(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint('('..jpi[2]..'+'..jpi[4]..','..jpi[3]..'-'..jpi[6]..')')
    else
        tex.sprint('(0pt,0pt)')
    end
end
function job.MPur(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint('('..jpi[2]..'+'..jpi[4]..','..jpi[3]..'+'..jpi[5]..')')
    else
        tex.sprint('(0pt,0pt)')
    end
end
function job.MPul(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint('('..jpi[2]..','..jpi[3]..'+'..jpi[5]..')')
    else
        tex.sprint('(0pt,0pt)')
    end
end

-- todo

function job.MPpos(id)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint(table.concat(jpi,',',1,6))
    else
        tex.sprint('0,0pt,0pt,0pt,0pt,0pt')
    end
end

function job.MPplus(id,n)
    local jpi = job.positions[id]
    if jpi then
        tex.sprint(jpi[n] or '0pt')
    else
        tex.sprint('0pt')
    end
end

function job.MPrest(id,default) -- 7 or 8 ?
    local jpi = job.positions[id]
    if jpi then
        tex.sprint(jpi[7] or default)
    else
        tex.sprint(default)
    end
end
