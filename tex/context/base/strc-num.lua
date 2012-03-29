if not modules then modules = { } end modules ['strc-num'] = {
    version   = 1.001,
    comment   = "companion to strc-num.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will be reimplemented and some more will move to the commands namespace

local format = string.format
local next, type = next, type
local min, max = math.min, math.max
local texcount = tex.count

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local trace_counters    = false  trackers.register("structures.counters", function(v) trace_counters = v end)
local report_counters   = logs.reporter("structure","counters")

local structures        = structures
local helpers           = structures.helpers
local sections          = structures.sections
local counters          = structures.counters
local documents         = structures.documents

local variables         = interfaces.variables

-- state: start stop none reset

counters.specials       = counters.specials or { }
local counterspecials   = counters.specials

local counterranges, tbs = { }, 0

counters.collected = allocate()
counters.tobesaved = counters.tobesaved or { }
counters.data      = counters.data or { }

storage.register("structures/counters/data",      counters.data,      "structures.counters.data")
storage.register("structures/counters/tobesaved", counters.tobesaved, "structures.counters.tobesaved")

local collected   = counters.collected
local tobesaved   = counters.tobesaved
local counterdata = counters.data

local function initializer() -- not really needed
    collected   = counters.collected
    tobesaved   = counters.tobesaved
    counterdata = counters.data
end

local function finalizer()
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

job.register('structures.counters.collected', tobesaved, initializer, finalizer)

local function constructor(t,s,name,i) -- variables ?
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

local function enhance()
    for name, cd in next, counterdata do
        local data = cd.data
        for i=1,#data do
            local ci = data[i]
            setmetatableindex(ci, function(t,s) return constructor(t,s,name,i) end)
        end
    end
    enhance = nil
end

local function allocate(name,i) -- can be metatable
    local cd = counterdata[name]
    if not cd then
        cd = {
            level   = 1,
         -- block   = "", -- todo
            numbers = nil,
            state   = variables.start, -- true
            data    = { },
            saved   = { },
        }
        tobesaved[name]   = { }
        counterdata[name] = cd
    end
    cd = cd.data
    local ci = cd[i]
    if not ci then
        ci = {
            number = 0,
            start  = 0,
            saved  = 0,
            step   = 1,
            range  = 1,
            offset = false,
            stop   = 0, -- via metatable: last, first, stop only for tracing
        }
        setmetatableindex(ci, function(t,s) return constructor(t,s,name,i) end)
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
    if name then
        local cd = counterdata[name].data[i]
        local cs = tobesaved[name][i]
        local cc = collected[name]
        if trace_counters then
            report_counters("saving value %s of counter named %s",cd.number,name)
        end
        local cr = cd.range
        local old = (cc and cc[i] and cc[i][cr]) or 0
        local number = cd.number
        if cd.method == variables.page then
            -- we can be one page ahead
            number = number - 1
        end
        cs[cr] = (number >= 0) and number or 0
        cd.range = cr + 1
        return old
    else
        return 0
    end
end

function counters.define(specification)
    local name = specification.name
    if name and name ~= "" then
        -- todo: step
        local d = allocate(name,1)
        d.start = specification.start
        d.state = variables.start or ""
        local counter = specification.counter
        if counter and counter ~= "" then
            d.counter = counter -- only for special purposes, cannot be false
            d.method  = specification.method -- frozen at define time
        end
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
--~ print(name,i,d.number)
            if d.number ~= 0 then
                compact[i] = (onlynumbers and d.number) or d
            end
        end
--~ print(table.serialize(compact))
        return compact
    end
end

-- depends on when incremented, before or after (driven by d.offset)

function counters.previous(name,n)
    return allocate(name,n).previous
end

function counters.next(name,n)
    return allocate(name,n).next
end

counters.prev = counters.previous

function counters.currentvalue(name,n)
    return allocate(name,n).number
end

function counters.first(name,n)
    return allocate(name,n).first
end

function counters.last(name,n)
    return allocate(name,n).last
end

function counters.subs(name,n)
    return counterdata[name].data[n].subs or 0
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

local function synchronize(name,d)
    local dc = d.counter
    if dc then
        if trace_counters then
            report_counters("setting counter %s with name %s to %s",dc,name,d.number)
        end
        tex.setcount("global",dc,d.number)
    end
    local cs = counterspecials[name]
    if cs then
        if trace_counters then
            report_counters("invoking special for name %s",name)
        end
        cs()
    end
end

function counters.reset(name,n)
    local cd = counterdata[name]
    if cd then
        for i=n or 1,#cd.data do
            local d = cd.data[i]
            savevalue(name,i)
            d.number = d.start or 0
            d.own = nil
            synchronize(name,d)
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
        synchronize(name,d)
    end
end

local function check(name,data,start,stop)
    for i=start or 1,stop or #data do
        local d = data[i]
        savevalue(name,i)
        d.number = d.start or 0
        d.own = nil
        synchronize(name,d)
    end
end

function counters.setown(name,n,value)
    local cd = counterdata[name]
    if cd then
        local d = allocate(name,n)
        d.own = value
        d.number = (d.number or d.start or 0) + (d.step or 0)
        local level = cd.level
        if not level or level == -1 then
            -- -1 is signal that we reset manually
        elseif level > 0 then
            check(name,d,n+1)
        elseif level == 0 then
            -- happens elsewhere, check this for block
        end
        synchronize(name,d)
    end
end

function counters.restart(name,n,newstart)
    local cd = counterdata[name]
    if cd then
        newstart = tonumber(newstart)
        if newstart then
            local d = allocate(name,n)
if d.start == newstart then
    -- nothing, else we do it too often in a synchronize
else
            d.start = newstart
            counters.reset(name,n)
end
        end
    end
end

function counters.save(name) -- or just number
    local cd = counterdata[name]
    if cd then
        table.insert(cd.saved,table.copy(cd.data))
    end
end

function counters.restore(name)
    local cd = counterdata[name]
    if cd and cd.saved then
        cd.data = table.remove(cd.saved)
    end
end

function counters.add(name,n,delta)
    local cd = counterdata[name]
-- inspect(cd)
    if cd and (cd.state == variables.start or cd.state == "") then
        local data = cd.data
        local d = allocate(name,n)
        d.number = (d.number or d.start or 0) + delta*(d.step or 0)
     -- d.own = nil
        local level = cd.level
-- print(name,n,delta,level)
        if not level or level == -1 then
            -- -1 is signal that we reset manually
        elseif level == -2 then
            -- -2 is signal that we work per text
            check(name,data,n+1)
        elseif level > 0 then
            -- within countergroup
            check(name,data,n+1)
        elseif level == 0 then
            -- happens elsewhere
        end
        synchronize(name,d)
        return d.number -- not needed
    end
    return 0
end

function counters.check(level) -- not used (yet)
    for name, cd in next, counterdata do
        -- report_counters("%s %s %s",name,cd.level,level)
        if cd.level == level then
            if trace_counters then
                report_counters("resetting %s at level %s",name,level)
            end
            counters.reset(name)
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
    return counters.get(name,n or 1,'number') or 0
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
        local reverse = spec.order == variables.reverse
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
                        --  vn = vl - vn + 1 + vf
                            vn = vl - vn + vf -- see testbed for test
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

-- interfacing

commands.definecounter  = counters.define
commands.setcounter     = counters.set
commands.setowncounter  = counters.setown
commands.resetcounter   = counters.reset
commands.restartcounter = counters.restart
commands.savecounter    = counters.save
commands.restorecounter = counters.restore
commands.addcounter     = counters.add

commands.rawcountervalue   = function(...) context(counters.raw     (...)) end
commands.countervalue      = function(...) context(counters.value   (...)) end
commands.lastcountervalue  = function(...) context(counters.last    (...)) end
commands.firstcountervalue = function(...) context(counters.first   (...)) end
commands.nextcountervalue  = function(...) context(counters.next    (...)) end
commands.prevcountervalue  = function(...) context(counters.previous(...)) end
commands.subcountervalues  = function(...) context(counters.subs    (...)) end

function commands.showcounter(name)
    local cd = counterdata[name]
    if cd then
        context("[%s:",name)
        local data = cd.data
        for i=1,#data do
            local d = data[i]
            context(" (%s: %s,%s,%s s:%s r:%s)",i,(d.start or 0),d.number or 0,d.last,d.step or 0,d.range or 0)
        end
        context("]")
    end
end

function commands.doifelsecounter(name) commands.doifelse(counterdata[name]) end
function commands.doifcounter    (name) commands.doif    (counterdata[name]) end
function commands.doifnotcounter (name) commands.doifnot (counterdata[name]) end

function commands.incrementedcounter(...) context(counters.add(...)) end

function commands.checkcountersetup(name,level,start,state)
    counters.restart(name,1,start)
    counters.setstate(name,state)
    counters.setlevel(name,level)
    sections.setchecker(name,level,counters.reset)
end

--~ -- move to strc-pag.lua

--~ function counters.analyze(name,counterspecification)
--~     local cd = counterdata[name]
--~     -- safeguard
--~     if not cd then
--~         return false, false, "no counter data"
--~     end
--~     -- section data
--~     local sectiondata = sections.current()
--~     if not sectiondata then
--~         return cd, false, "not in section"
--~     end
--~     local references = sectiondata.references
--~     if not references then
--~         return cd, false, "no references"
--~     end
--~     local section = references.section
--~     if not section then
--~         return cd, false, "no section"
--~     end
--~     sectiondata = sections.collected[references.section]
--~     if not sectiondata then
--~         return cd, false, "no section data"
--~     end
--~     -- local preferences
--~     local no = variables.no
--~     if counterspecification and counterspecification.prefix == no then
--~         return cd, false, "current spec blocks prefix"
--~     end
--~     -- stored preferences (not used)
--~     if cd.prefix == no then
--~         return cd, false, "entry blocks prefix"
--~     end
--~     -- sectioning
--~     -- if sectiondata.prefix == no then
--~     --     return false, false, "sectiondata blocks prefix"
--~     -- end
--~     -- final verdict
--~     return cd, sectiondata, "okay"
--~ end

--~ function counters.prefixedconverted(name,prefixspec,numberspec)
--~     local cd, prefixdata, result = counters.analyze(name,prefixspec)
--~     if cd then
--~         if prefixdata then
--~             sections.typesetnumber(prefixdata,"prefix",prefixspec or false,cd or false)
--~         end
--~         counters.converted(name,numberspec)
--~     end
--~ end
