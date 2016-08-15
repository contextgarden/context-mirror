if not modules then modules = { } end modules ['trac-inf'] = {
    version   = 1.001,
    comment   = "companion to trac-inf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- As we want to protect the global tables, we no longer store the timing
-- in the tables themselves but in a hidden timers table so that we don't
-- get warnings about assignments. This is more efficient than using rawset
-- and rawget.

local type, tonumber, select = type, tonumber, select
local format, lower, find = string.format, string.lower, string.find
local concat = table.concat
local clock  = os.gettimeofday or os.clock -- should go in environment

local setmetatableindex = table.setmetatableindex
local serialize         = table.serialize
local formatters        = string.formatters

statistics              = statistics or { }
local statistics        = statistics

statistics.enable       = true
statistics.threshold    = 0.01

local statusinfo, n, registered, timers = { }, 0, { }, { }

setmetatableindex(timers,function(t,k)
    local v = { timing = 0, loadtime = 0 }
    t[k] = v
    return v
end)

local function hastiming(instance)
    return instance and timers[instance]
end

local function resettiming(instance)
    timers[instance or "notimer"] = { timing = 0, loadtime = 0 }
end

local function starttiming(instance)
    local timer = timers[instance or "notimer"]
    local it = timer.timing or 0
    if it == 0 then
        timer.starttime = clock()
        if not timer.loadtime then
            timer.loadtime = 0
        end
    end
    timer.timing = it + 1
end

local function stoptiming(instance)
    local timer = timers[instance or "notimer"]
    local it = timer.timing
    if it > 1 then
        timer.timing = it - 1
    else
        local starttime = timer.starttime
        if starttime and starttime > 0 then
            local stoptime  = clock()
            local loadtime  = stoptime - starttime
            timer.stoptime  = stoptime
            timer.loadtime  = timer.loadtime + loadtime
            timer.timing    = 0
            timer.starttime = 0
            return loadtime
        end
    end
    return 0
end

local function elapsed(instance)
    if type(instance) == "number" then
        return instance or 0
    else
        local timer = timers[instance or "notimer"]
        return timer and timer.loadtime or 0
    end
end

local function elapsedtime(instance)
    return format("%0.3f",elapsed(instance))
end

local function elapsedindeed(instance)
    return elapsed(instance) > statistics.threshold
end

local function elapsedseconds(instance,rest) -- returns nil if 0 seconds
    if elapsedindeed(instance) then
        return format("%0.3f seconds %s", elapsed(instance),rest or "")
    end
end

statistics.hastiming      = hastiming
statistics.resettiming    = resettiming
statistics.starttiming    = starttiming
statistics.stoptiming     = stoptiming
statistics.elapsed        = elapsed
statistics.elapsedtime    = elapsedtime
statistics.elapsedindeed  = elapsedindeed
statistics.elapsedseconds = elapsedseconds

-- general function .. we might split this module

function statistics.register(tag,fnc)
    if statistics.enable and type(fnc) == "function" then
        local rt = registered[tag] or (#statusinfo + 1)
        statusinfo[rt] = { tag, fnc }
        registered[tag] = rt
        if #tag > n then n = #tag end
    end
end

local report = logs.reporter("mkiv lua stats")

function statistics.show()
    if statistics.enable then
        -- this code will move
        local register = statistics.register
        register("used platform", function()
            return format("%s, type: %s, binary subtree: %s",
                os.platform or "unknown",os.type or "unknown", environment.texos or "unknown")
        end)
        register("luatex banner", function()
            return lower(status.banner)
        end)
        register("control sequences", function()
            return format("%s of %s + %s", status.cs_count, status.hash_size,status.hash_extra)
        end)
        register("callbacks", function()
            local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
            return format("%s direct, %s indirect, %s total", total-indirect, indirect, total)
        end)
        if jit then
            local jitstatus = { jit.status() }
            if jitstatus[1] then
                register("luajit options", concat(jitstatus," ",2))
            end
        end
        -- so far
     -- collectgarbage("collect")
        register("lua properties",function()
            local hashchar = tonumber(status.luatex_hashchars)
            local hashtype = status.luatex_hashtype
            local mask = lua.mask or "ascii"
            return format("engine: %s, used memory: %s, hash type: %s, hash chars: min(%s,40), symbol mask: %s (%s)",
                jit and "luajit" or "lua",
                statistics.memused(),
                hashtype or "default",
                hashchar and 2^hashchar or "unknown",
                mask,
                mask == "utf" and "τεχ" or "tex")
        end)
        register("runtime",statistics.runtime)
        logs.newline() -- initial newline
        for i=1,#statusinfo do
            local s = statusinfo[i]
            local r = s[2]()
            if r then
                report("%s: %s",s[1],r)
            end
        end
     -- logs.newline() -- final newline
        statistics.enable = false
    end
end

function statistics.memused() -- no math.round yet -)
    local round = math.round or math.floor
    return format("%s MB (ctx: %s MB)",round(collectgarbage("count")/1000), round(status.luastate_bytes/1000000))
end

starttiming(statistics)

function statistics.formatruntime(runtime) -- indirect so it can be overloaded and
    return format("%s seconds", runtime)   -- indeed that happens in cure-uti.lua
end

function statistics.runtime()
    stoptiming(statistics)
 --  stoptiming(statistics) -- somehow we can start the timer twice, but where
    return statistics.formatruntime(elapsedtime(statistics))
end

local report = logs.reporter("system")

function statistics.timed(action)
    starttiming("run")
    action()
    stoptiming("run")
    report("total runtime: %s seconds",elapsedtime("run"))
end

-- goodie

function statistics.tracefunction(base,tag,...)
    for i=1,select("#",...) do
        local name = select(i,...)
        local stat = { }
        local func = base[name]
        setmetatableindex(stat,function(t,k) t[k] = 0 return 0 end)
        base[name] = function(n,k,v) stat[k] = stat[k] + 1 return func(n,k,v) end
        statistics.register(formatters["%s.%s"](tag,name),function() return serialize(stat,"calls") end)
    end
end
