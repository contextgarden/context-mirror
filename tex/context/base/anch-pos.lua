if not modules then modules = { } end modules ['anch-pos'] = {
    version   = 1.001,
    comment   = "companion to anch-pos.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save positional information in the main utility table. Not only
can we store much more information in <l n='lua'/> but it's also
more efficient.</p>
--ldx]]--

local concat, format = table.concat, string.format
local lpegmatch = lpeg.match
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local collected, tobesaved = allocate(), allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

_plib_, _ptbs_, _pcol_ = jobpositions, tobesaved, collected -- global

local dx, dy = "0pt", "0pt"

local function initializer()
    tobesaved = mark(jobpositions.tobesaved)
    collected = mark(jobpositions.collected)
    _ptbs_, _pcol_ = tobesaved, collected -- global
    local p = collected["page:0"] -- page:1
    if p then
-- to be checked !
--~ dx, dy = p[2] or "0pt", p[3] or "0pt"
    end
end

job.register('job.positions.collected', tobesaved, initializer)

function jobpositions.copy(target,source)
    collected[target] = collected[source] or tobesaved[source]
end

function jobpositions.replace(name,...)
    collected[name] = {...}
end

function jobpositions.doifelse(name)
    commands.testcase(collected[name] or tobesaved[name])
end

function jobpositions.MPp(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[1] or '0'  ) end
function jobpositions.MPx(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[2] or '0pt') end
function jobpositions.MPy(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[3] or '0pt') end
function jobpositions.MPw(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[4] or '0pt') end
function jobpositions.MPh(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[5] or '0pt') end
function jobpositions.MPd(id) local jpi = collected[id] or tobesaved[id] context(jpi and jpi[6] or '0pt') end

function jobpositions.MPx(id)
    local jpi = collected[id] or tobesaved[id]
    local x = jpi and jpi[2]
    if x then
        context('\\the\\dimexpr%s-%s\\relax',x,dx)
    else
        context('0pt')
    end
end

function jobpositions.MPy(id)
    local jpi = collected[id] or tobesaved[id]
    local y = jpi and jpi[3]
    if y then
        context('\\the\\dimexpr%s-%s\\relax',y,dy)
    else
        context('0pt')
    end
end

-- the following are only for MP so there we can leave out the pt

-- can be writes and no format needed any more

function jobpositions.MPxy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s-%s)',jpi[2],dx,jpi[3],dy)
    else
        context('(0,0)')
    end
end

function jobpositions.MPll(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s-%s-%s)',jpi[2],dx,jpi[3],jpi[6],dy)
    else
        context('(0,0)')
    end
end

function jobpositions.MPlr(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s+%s-%s,%s-%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[6],dy)
    else
        context('(0,0)')
    end
end

function jobpositions.MPur(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s+%s-%s,%s+%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[5],dy)
    else
        context('(0,0)')
    end
end

function jobpositions.MPul(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s+%s-%s)',jpi[2],dx,jpi[3],jpi[5],dy)
    else
        context('(0,0)')
    end
end

function jobpositions.MPpos(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context(concat(jpi,',',1,6))
    else
        context('0,0,0,0,0,0')
    end
end

local splitter = lpeg.Ct(lpeg.splitat(","))

function jobpositions.MPplus(id,n,default)
    local jpi = collected[id] or tobesaved[id]
    if not jpi then
        context(default)
    else
        local split = jpi[0]
        if not split then
            split = lpegmatch(splitter,jpi[7])
            jpi[0] = split
        end
        context(split[n] or default)
    end
end

function jobpositions.MPrest(id,default)
    local jpi = collected[id] or tobesaved[id]
    context(jpi and jpi[7] or default)
end
