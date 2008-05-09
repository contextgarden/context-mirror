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

local texprint  = tex.print
local positions = job.positions
local concat    = table.concat
local format    = string.format

function job.MPp(id) local jpi = positions[id] texprint((jpi and jpi[1]) or '0'  ) end
function job.MPx(id) local jpi = positions[id] texprint((jpi and jpi[2]) or '0pt') end
function job.MPy(id) local jpi = positions[id] texprint((jpi and jpi[3]) or '0pt') end
function job.MPw(id) local jpi = positions[id] texprint((jpi and jpi[4]) or '0pt') end
function job.MPh(id) local jpi = positions[id] texprint((jpi and jpi[5]) or '0pt') end
function job.MPd(id) local jpi = positions[id] texprint((jpi and jpi[6]) or '0pt') end

-- the following are only for MP so there we can leave out the pt

function job.MPxy(id)
    local jpi = positions[id]
    if jpi then
        texprint(format('(%s,%s)',jpi[2],jpi[3]))
    else
        texprint('(0,0)')
    end
end

function job.MPll(id)
    local jpi = positions[id]
    if jpi then
        texprint(format('(%s,%s-%s)',jpi[2],jpi[3],jpi[6]))
    else
        texprint('(0,0)')
    end
end
function job.MPlr(id)
    local jpi = positions[id]
    if jpi then
        texprint(format('(%s+%s,%s-%s)',jpi[2],jpi[4],jpi[3],jpi[6]))
    else
        texprint('(0,0)')
    end
end
function job.MPur(id)
    local jpi = positions[id]
    if jpi then
        texprint(format('(%s+%s,%s+%s)',jpi[2],jpi[4],jpi[3],jpi[5]))
    else
        texprint('(0,0)')
    end
end
function job.MPul(id)
    local jpi = positions[id]
    if jpi then
        texprint(format('(%s,%s+%s)',jpi[2],jpi[3],jpi[5]))
    else
        texprint('(0,0)')
    end
end

-- todo

function job.MPpos(id)
    local jpi = positions[id]
    if jpi then
        texprint(concat(jpi,',',1,6))
    else
        texprint('0,0,0,0,0,0')
    end
end

function job.MPplus(id,n,default)
    local jpi = positions[id]
    texprint((jpi and jpi[n]) or default)
end

function job.MPrest(id,default)
    local jpi = positions[id]
    texprint((jpi and jpi[8]) or default) -- was 7, bugged
end
