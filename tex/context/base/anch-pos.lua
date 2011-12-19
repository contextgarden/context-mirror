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

-- to be considered: store as numbers instead of string
-- maybe replace texsp by our own converter (stay at the lua end)
-- eventually mp will have large numbers so we can use sp there too

local tostring = tostring
local concat, format, gmatch = table.concat, string.format, string.gmatch
local lpegmatch = lpeg.match
local allocate, mark = utilities.storage.allocate, utilities.storage.mark
local texsp, texcount = tex.sp, tex.count
----- texsp = string.todimen -- because we cache this is much faster but no rounding

local pt  = number.dimenfactors.pt
local pts = number.pts

local collected = allocate()
local tobesaved = allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

_plib_ = jobpositions

local function initializer()
    tobesaved = jobpositions.tobesaved
    collected = jobpositions.collected
end

job.register('job.positions.collected', tobesaved, initializer)

function jobpositions.setraw(name,val)
    tobesaved[name] = val
end

function jobpositions.setdim(name,wd,ht,dp,plus) -- will be used when we move to sp allover
    if plus then
        tobesaved[name] = { texcount.realpageno, pdf.h, pdf.v, wd, ht, dp, plus }
    elseif wd then
        tobesaved[name] = { texcount.realpageno, pdf.h, pdf.v, wd, ht, dp }
    else
        tobesaved[name] = { texcount.realpageno, pdf.h, pdf.v }
    end
end

function jobpositions.setall(name,p,x,y,wd,ht,dp,plus) -- will be used when we move to sp allover
    if plus then
        tobesaved[name] = { p, x, y, wd, ht, dp, plus }
    elseif wd then
        tobesaved[name] = { p, x, y, wd, ht, dp }
    else
        tobesaved[name] = { p, x, y }
    end
end

-- _praw_ = jobpositions.setraw
-- _pdim_ = jobpositions.setdim
-- _pall_ = jobpositions.setall

function jobpositions.copy(target,source)
    collected[target] = collected[source] or tobesaved[source]
end

function jobpositions.replace(name,...)
    collected[name] = {...}
end

function jobpositions.v(id,default)
    return collected[id] or tobesaved[id] or default
end

function jobpositions.page(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[1] or 0
end

function jobpositions.x(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[2] or 0
end

function jobpositions.y(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[3] or 0
end

function jobpositions.width(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[4] or 0
end

function jobpositions.height(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[5] or 0
end

function jobpositions.depth(id)
    local jpi = collected[id] or tobesaved[id]
    return jpi and jpi[6] or 0
end

function jobpositions.xy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[2], jpi[3]
    else
        return 0, 0
    end
end

function jobpositions.lowerleft(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[2], jpi[3] - jpi[6]
    else
        return 0, 0
    end
end

function jobpositions.lowerright(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[2] + jpi[4], jpi[3] - jpi[6]
    else
        return 0, 0
    end
end

function jobpositions.upperright(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[2] + jpi[4], jpi[3] + jpi[5]
    else
        return 0, 0
    end
end

function jobpositions.upperleft(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[2], jpi[3] + jpi[5]
    else
        return 0, 0
    end
end

function jobpositions.position(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return jpi[1], jpi[2], jpi[3], jpi[4], jpi[5], jpi[6]
    else
        return 0, 0, 0, 0, 0, 0
    end
end

function jobpositions.extra(id,n,default) -- assume numbers
    local jpi = collected[id] or tobesaved[id]
    if not jpi then
        return default
    else
        local split = jpi[0]
        if not split then
            split = lpegmatch(splitter,jpi[7])
            jpi[0] = split
        end
        return texsp(split[n]) or default -- watch the texsp here
    end
end

local function overlapping(one,two,overlappingmargin) -- hm, strings so this is wrong .. texsp
    one = collected[one] or tobesaved[one]
    two = collected[two] or tobesaved[two]
    if one and two and one[1] == two[1] then
        if not overlappingmargin then
            overlappingmargin = 2
        end
        local x_one = one[2]
        local x_two = two[2]
        local w_two = two[4]
        local llx_one = x_one         - overlappingmargin
        local urx_two = x_two + w_two + overlappingmargin
        if llx_one > urx_two then
            return false
        end
        local w_one = one[4]
        local urx_one = x_one + w_one + overlappingmargin
        local llx_two = x_two         - overlappingmargin
        if urx_one < llx_two then
            return false
        end
        local y_one = one[3]
        local y_two = two[3]
        local d_one = one[6]
        local h_two = two[5]
        local lly_one = y_one - d_one - overlappingmargin
        local ury_two = y_two + h_two + overlappingmargin
        if lly_one > ury_two then
            return false
        end
        local h_one = one[5]
        local d_two = two[6]
        local ury_one = y_one + h_one + overlappingmargin
        local lly_two = y_two - d_two - overlappingmargin
        if ury_one < lly_two then
            return false
        end
        return true
    end
end

local function onsamepage(list,page)
    for id in gmatch(list,"(, )") do
        local jpi = collected[id] or tobesaved[id]
        if jpi then
            local p = jpi[1]
            if not page then
                page = p
            elseif page ~= p then
                return false
            end
        end
    end
    return page
end

jobpositions.overlapping = overlapping
jobpositions.onsamepage  = onsamepage

-- interface

commands.replacepospxywhd = jobpositions.replace
commands.copyposition     = jobpositions.copy

function commands.MPp(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context(jpi[1])
    else
        context('0')
    end
end

function commands.MPx(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%spt",jpi[2]*pt)
    else
        context('0pt')
    end
end

function commands.MPy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%spt",jpi[3]*pt)
    else
        context('0pt')
    end
end

function commands.MPw(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%spt",jpi[4]*pt)
    else
        context('0pt')
    end
end

function commands.MPh(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%spt",jpi[5]*pt)
    else
        context('0pt')
    end
end

function commands.MPd(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%spt",jpi[6]*pt)
    else
        context('0pt')
    end
end

function commands.MPxy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%spt,%spt)',jpi[2]*pt,jpi[3]*pt)
    else
        context('(0,0)')
    end
end

function commands.MPll(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%spt,%spt)',jpi[2]*pt,(jpi[3]-jpi[6])*pt)
    else
        context('(0,0)')
    end
end

function commands.MPlr(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%spt,%spt)',(jpi[2]+jpi[4])*pt,(jpi[3]-jpi[6])*pt)
    else
        context('(0,0)')
    end
end

function commands.MPur(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%spt,%spt)',(jpi[2]+jpi[4])*pt,(jpi[3]+jpi[5])*pt)
    else
        context('(0,0)')
    end
end

function commands.MPul(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%spt,%spt)',jpi[2]*pt,(jpi[3]+jpi[5])*pt)
    else
        context('(0,0)')
    end
end

function commands.MPpos(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context("%s,%spt,%spt,%spt,%spt,%spt",jpi[1],jpi[2]*pt,jpi[3]*pt,jpi[4]*pt,jpi[5]*pt,jpi[6]*pt)
    else
        context('0,0,0,0,0,0')
    end
end

local splitter = lpeg.tsplitat(",")

function commands.MPplus(id,n,default)
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

function commands.MPrest(id,default)
    local jpi = collected[id] or tobesaved[id]
    context(jpi and jpi[7] or default)
end

-- is testcase already defined? if so, then local

function commands.doifpositionelse(name)
    commands.testcase(collected[name] or tobesaved[name])
end

function commands.doifoverlappingelse(one,two,overlappingmargin)
    commands.testcase(overlapping(one,two,overlappingmargin))
end

function commands.doifpositionsonsamepageelse(list,page)
    commands.testcase(onsamepage(list))
end

function commands.doifpositionsonthispageelse(list)
    commands.testcase(onsamepage(list,tostring(tex.count.realpageno)))
end
