if not modules then modules = { } end modules ['strc-num'] = {
    version   = 1.001,
    comment   = "companion to strc-num.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local next, type = next, type
local min, max = math.min, math.max
local texsprint, texcount = tex.sprint, tex.count

structure              = structure           or { }
structure.helpers      = structure.helpers   or { }
structure.sections     = structure.sections  or { }
structure.counters     = structure.counters  or { }
structure.documents    = structure.documents or { }

structure.counters      = structure.counters      or { }
structure.counters.data = structure.counters.data or { }

local helpers   = structure.helpers
local sections  = structure.sections
local counters  = structure.counters
local documents = structure.documents

local variables = interfaces.variables

-- state: start stop none reset

local counterdata = counters.data
local counterranges, tbs = { }, 0

counters.collected = counters.collected or { }
counters.tobesaved = counters.tobesaved or { }

storage.register("structure/counters/data", structure.counters.data, "structure.counters.data")
storage.register("structure/counters/tobesaved", structure.counters.tobesaved, "structure.counters.tobesaved")

local collected, tobesaved = counters.collected, counters.tobesaved

local function finalizer()
    local ct = counters.tobesaved
    for name, cd in next, counterdata do
        local cs = tobesaved[name]
        local data = cd.data
        for i=1,#data do
            local d = data[i]
            local r = d.range
            cs[i][r] = d.number
            d.range = r + 1
        end
    end
end

local function initializer()
    collected, tobesaved = counters.collected, counters.tobesaved
end

if job then
    job.register('structure.counters.collected', structure.counters.tobesaved, initializer, finalizer)
end

local function constructor(t,s,name,i)
    if s == "last" then
        local cc = collected[name]
        t.stop = (cc and cc[i] and cc[i][t.range]) or 0 -- stop is available for diagnostics purposes only
        if t.offset then
            return t.stop - t.step
        else
            return t.stop
        end
    elseif s == "first" then
        if t.start > 0 then
            return t.start -- brrr
        elseif t.offset then
            return t.start + t.step + 1
        else
            return t.start + 1
        end
    elseif s == "prev" or s == "previous" then
        return max(t.first,t.number-1) -- todo: step
    elseif s == "next" then
        return min(t.last,t.number+1) -- todo: step
    elseif s == "backward" then
        if t.number - 1 < t.first then
            return t.last
        else
            return t.previous
        end
    elseif s == "forward" then
        if t.number + 1 > t.last then
            return t.first
        else
            return t.next
        end
    elseif s == "subs" then
        local cc = collected[name]
        t.subs = (cc and cc[i+1] and cc[i+1][t.range]) or 0
        return t.subs
    else
        return nil -- was 0, but that is fuzzy in testing for e.g. own
    end
end

local enhance = function()
    for name, cd in next, counterdata do
        local data = cd.data
        for i=1,#data do
            local ci = data[i]
            setmetatable(ci, { __index = function(t,s) return constructor(t,s,name,i) end })
        end
    end
    enhance = nil
end

local function allocate(name,i)
    local cd = counterdata[name]
    if not cd then
        cd = {
            level = 1,
            numbers = nil,
            state = variables.start, -- true
            data = { }
        }
        tobesaved[name] = { }
        counterdata[name] = cd
    end
    cd = cd.data
    local ci = cd[i]
    if not ci then
        ci = {
            number = 0,
            start = 0,
            saved = 0,
            step = 1,
            range = 1,
            offset = false,
        --  via metatable: last, first, and for tracing:
            stop = 0,
        }
        setmetatable(ci, { __index = function(t,s) return constructor(t,s,name,i) end })
        cd[i] = ci
        tobesaved[name][i] = { }
    else
        if enhance then enhance() end -- not stored in bytecode
    end
    return ci
end

function counters.record(name,i)
    return allocate(name,i or 1)
end

local function savevalue(name,i)
    local cd = counterdata[name].data[i]
    local cs = tobesaved[name][i]
    local cc = collected[name]
    local cr = cd.range
    local old = (cc and cc[i] and cc[i][cr]) or 0
    cs[cr] = cd.number
    cd.range = cr + 1
    return old
end

function counters.define(name, start, counter) -- todo: step
    local d = allocate(name,1)
    d.start = start
    if counter ~= "" then
        d.counter = counter -- only for special purposes, cannot be false
    end
end

function counters.trace(name)
    local cd = counterdata[name]
    if cd then
        texsprint(format("[%s:",name))
        local data = cd.data
        for i=1,#data do
            local d = data[i]
            texsprint(format(" (%s: %s,%s,%s s:%s r:%s)",i,(d.start or 0),d.number or 0,d.last,d.step or 0,d.range or 0))
        end
        texsprint("]")
    end
end

function counters.raw(name)
    return counterdata[name]
end

function counters.compact(name,level,onlynumbers)
    local cd = counterdata[name]
--~ print(name,cd)
    if cd then
        local data = cd.data
        local compact = { }
        for i=1,level or #data do
            local d = data[i]
            if d.number ~= 0 then
                compact[i] = (onlynumbers and d.number) or d
            end
        end
        return compact
    end
end

-- depends on when incremented, before or after (driven by d.offset)

function counters.doifelse(name)
    commands.doifelse(counterdata[name])
end

function counters.previous(name,n)
    texsprint(allocate(name,n).previous)
end

function counters.next(name,n)
    texsprint(allocate(name,n).next)
end

counters.prev = counters.previous

function counters.current(name,n)
    texsprint(allocate(name,n).number)
end

function counters.first(name,n)
    texsprint(allocate(name,n).first)
end

function counters.last(name,n)
    texsprint(allocate(name,n).last)
end

function counters.subs(name,n)
    texsprint(counterdata[name].data[n].subs or 0)
end

function counters.setvalue(name,tag,value)
    local cd = counterdata[name]
    if cd then
        cd[tag] = value
    end
end

function counters.setstate(name,value) -- true/false
    value = variables[value]
    if value then
        counters.setvalue(name,"state",value)
    end
end

function counters.setlevel(name,value)
    counters.setvalue(name,"level",value)
end

function counters.setoffset(name,value)
    counters.setvalue(name,"offset",value)
end

function counters.reset(name,n)
    local cd = counterdata[name]
    if cd then
        for i=n or 1,#cd.data do
            local d = cd.data[i]
            savevalue(name,i)
            d.number = d.start or 0
            d.own = nil
            if d.counter then texcount[d.counter] = d.number end
        end
        cd.numbers = nil
    end
end

function counters.set(name,n,value)
    local cd = counterdata[name]
    if cd then
        local d = allocate(name,n)
        d.number = value or 0
        d.own = nil
        if d.counter then texcount[d.counter] = d.number end
    end
end

local function check(name,data,start,stop)
    for i=start or 1,stop or #data do
        local d = data[i]
        savevalue(name,i)
        d.number = d.start or 0
        d.own = nil
        if d.counter then texcount[d.counter] = d.number end
    end
end

function counters.setown(name,n,value)
    local cd = counterdata[name]
    if cd then
        local d = allocate(name,n)
        d.own = value
        d.number = (d.number or d.start or 0) + (d.step or 0)
        if cd.level and cd.level > 0 then -- 0 is signal that we reset manually
            check(name,data,n+1) -- where is check defined
        end
        if d.counter then texcount[d.counter] = d.number end
    end
end

function counters.restart(name,n,newstart)
    local cd = counterdata[name]
    if cd then
        newstart = tonumber(newstart)
        if newstart then
            local d = allocate(name,n)
            d.start = newstart
            counters.reset(name,n)
        end
    end
end

function counters.save(name) -- or just number
    local cd = counterdata[name]
    if cd then
        cd.saved = table.copy(cd.data)
    end
end

function counters.restore(name)
    local cd = counterdata[name]
    if cd and cd.saved then
        cd.data = cd.saved
        cd.saved = nil
    end
end

function counters.add(name,n,delta)
    local cd = counterdata[name]
    if cd and cd.state == variables.start then
        local data = cd.data
        local d = allocate(name,n)
        d.number = (d.number or d.start or 0) + delta*(d.step or 0)
        if cd.level and cd.level > 0 then -- 0 is signal that we reset manually
            check(name,data,n+1)
        end
        if d.counter then texcount[d.counter] = d.number end
        return d.number
    end
    return 0
end

function counters.check(level)
    for _, v in next, counterdata do
        if v.level == level then -- is level for whole counter!
            local data = v.data
            check(name,data)
        end
    end
end

function counters.get(name,n,key)
    local d = allocate(name,n)
    d = d and d[key]
    if not d then
        return 0
    elseif type(d) == "function" then
        return d()
    else
        return d
    end
end

function counters.value(name,n) -- what to do with own
    tex.write(counters.get(name,n or 1,'number') or 0)
end

function counters.converted(name,spec) -- name can be number and reference to storage
    local cd
    if type(name) == "number" then
        cd = specials.retrieve("counter",name)
        cd = cd and cd.counter
    else
        cd = counterdata[name]
    end
    if cd then
        local spec = spec or { }
        local numbers, ownnumbers = { }, { }
        local reverse = spec.order == variables["reverse"]
        local kind = spec.type or "number"
        local v_first, v_next, v_previous, v_last = variables.first, variables.next, variables.previous, variables.last
        local data = cd.data
        for k=1,#data do
            local v = data[k]
            -- somewhat messy, what if subnr? only last must honour kind?
            local vn
            if v.own then
                numbers[k], ownnumbers[k] = v.number, v.own
            else
                if kind == v_first then
                    vn = v.first
                elseif kind == v_next then
                    vn = v.next
                elseif kind == v_previous then
                    vn = v.prev
                elseif kind == v_last then
                    vn = v.last
                else
                    vn = v.number
                    if reverse then
                        local vf = v.first
                        local vl = v.last
                        if vl > 0 then
                            vn = vl - vn + 1 + vf
                        end
                    end
                end
                numbers[k], ownnumbers[k] = vn or v.number, nil
            end
        end
        cd.numbers = numbers
        cd.ownnumbers = ownnumbers
        sections.typesetnumber(cd,'number',spec)
        cd.numbers = nil
        cd.ownnumbers = nil
    end
end

-- move to strc-pag.lua

function counters.analyse(name,counterspecification)
    local cd = counterdata[name]
    -- safeguard
    if not cd then
        return false, false, "no counter data"
    end
    -- section data
    local sectiondata = sections.current()
    if not sectiondata then
        return cd, false, "not in section"
    end
    local references = sectiondata.references
    if not references then
        return cd, false, "no references"
    end
    local section = references.section
    if not section then
        return cd, false, "no section"
    end
    sectiondata = jobsections.collected[references.section]
    if not sectiondata then
        return cd, false, "no section data"
    end
    -- local preferences
    local no = variables.no
    if counterspecification and counterspecification.prefix == no then
        return cd, false, "current spec blocks prefix"
    end
    -- stored preferences (not used)
    if cd.prefix == no then
        return cd, false, "entry blocks prefix"
    end
    -- sectioning
    -- if sectiondata.prefix == no then
    --     return false, false, "sectiondata blocks prefix"
    -- end
    -- final verdict
    return cd, sectiondata, "okay"
end

function counters.prefixedconverted(name,prefixspec,numberspec)
    local cd, prefixdata, result = counters.analyse(name,prefixspec)
    if cd then
        if prefixdata then
            sections.typesetnumber(prefixdata,"prefix",prefixspec or false,cd or false)
        end
        counters.converted(name,numberspec)
    end
end
