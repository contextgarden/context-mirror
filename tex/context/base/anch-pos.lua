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

local tostring = tostring
local concat, format, gmatch = table.concat, string.format, string.gmatch
local lpegmatch = lpeg.match
local allocate, mark = utilities.storage.allocate, utilities.storage.mark
local texsp = tex.sp
----- texsp = string.todimen -- because we cache this is much faster but no rounding

local collected, tobesaved = allocate(), allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

_ptbs_, _pcol_ = tobesaved, collected -- global

local dx, dy, nx, ny = "0pt", "0pt", 0, 0

local function initializer()
    tobesaved = mark(jobpositions.tobesaved)
    collected = mark(jobpositions.collected)
    _ptbs_, _pcol_ = tobesaved, collected -- global
    local p = collected["page:0"] -- page:1
    if p then
 -- dx, nx = p[2] or "0pt", 0
 -- dy, ny = p[3] or "0pt", 0
    end
end

job.register('job.positions.collected', tobesaved, initializer)

function jobpositions.copy(target,source)
    collected[target] = collected[source] or tobesaved[source]
end

function jobpositions.replace(name,...)
    collected[name] = {...}
end

function jobpositions.page(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[1])
    else
        return 0
    end
end

function jobpositions.x(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) - nx
    else
        return 0
    end
end

function jobpositions.y(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[3]) - ny
    else
        return 0
    end
end

function jobpositions.width(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[4])
    else
        return 0
    end
end

function jobpositions.height(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[5])
    else
        return 0
    end
end

function jobpositions.depth(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[6])
    else
        return 0
    end
end

function jobpositions.xy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) - nx, texsp(jpi[3]) - ny
    else
        return 0, 0
    end
end

function jobpositions.lowerleft(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) - nx, texsp(jpi[3]) - texsp(jpi[6]) - ny
    else
        return 0, 0
    end
end

function jobpositions.lowerright(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) + texsp(jpi[4]) - nx, texsp(jpi[3]) - texsp(jpi[6]) - ny
    else
        return 0, 0
    end
end

function jobpositions.upperright(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) + texsp(jpi[4]) - nx, texsp(jpi[3]) + texsp(jpi[5]) - ny
    else
        return 0, 0
    end
end

function jobpositions.upperleft(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[2]) - nx, texsp(jpi[3]) + texsp(jpi[5]) - ny
    else
        return 0, 0
    end
end

function jobpositions.position(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        return texsp(jpi[1]), texsp(jpi[2]), texsp(jpi[3]), texsp(jpi[4]), texsp(jpi[5]), texsp(jpi[6])
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
        return texsp(split[n]) or default
    end
end

local function overlapping(one,two,overlappingmargin)
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
    context(jpi and jpi[1] or '0')
end

function commands.MPx(id)
    local jpi = collected[id] or tobesaved[id]
    local x = jpi and jpi[2]
    if x then
        if nx == 0 then
            context(x)
        else
            context('\\the\\dimexpr%s-%s\\relax',x,dx)
        end
    else
        context('0pt')
    end
end

function commands.MPy(id)
    local jpi = collected[id] or tobesaved[id]
    local y = jpi and jpi[3]
    if y then
        if ny == 0 then
            context(y)
        else
            context('\\the\\dimexpr%s-%s\\relax',y,dy)
        end
    else
        context('0pt')
    end
end

function commands.MPw(id)
    local jpi = collected[id] or tobesaved[id]
    context(jpi and jpi[4] or '0pt')
end

function commands.MPh(id)
    local jpi = collected[id] or tobesaved[id]
    context(jpi and jpi[5] or '0pt')
end

function commands.MPd(id)
    local jpi = collected[id] or tobesaved[id]
    context(jpi and jpi[6] or '0pt')
end

function commands.MPxy(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s-%s)',jpi[2],dx,jpi[3],dy)
    else
        context('(0,0)')
    end
end

function commands.MPll(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s-%s-%s)',jpi[2],dx,jpi[3],jpi[6],dy)
    else
        context('(0,0)')
    end
end

function commands.MPlr(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s+%s-%s,%s-%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[6],dy)
    else
        context('(0,0)')
    end
end

function commands.MPur(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s+%s-%s,%s+%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[5],dy)
    else
        context('(0,0)')
    end
end

function commands.MPul(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context('(%s-%s,%s+%s-%s)',jpi[2],dx,jpi[3],jpi[5],dy)
    else
        context('(0,0)')
    end
end

function commands.MPpos(id)
    local jpi = collected[id] or tobesaved[id]
    if jpi then
        context(concat(jpi,',',1,6))
    else
        context('0,0,0,0,0,0')
    end
end

local splitter = lpeg.Ct(lpeg.splitat(","))

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
