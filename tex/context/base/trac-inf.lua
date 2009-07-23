if not modules then modules = { } end modules ['trac-inf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local statusinfo, n, registered = { }, 0, { }

statistics = statistics or { }

statistics.enable    = true
statistics.threshold = 0.05

-- timing functions

local clock = os.gettimeofday or os.clock

local notimer

function statistics.hastimer(instance)
    return instance and instance.starttime
end

function statistics.starttiming(instance)
    if not instance then
        notimer = { }
        instance = notimer
    end
    local it = instance.timing
    if not it then
        it = 0
    end
    if it == 0 then
        instance.starttime = clock()
        if not instance.loadtime then
            instance.loadtime = 0
        end
    end
    instance.timing = it + 1
end

function statistics.stoptiming(instance, report)
    if not instance then
        instance = notimer
    end
    if instance then
        local it = instance.timing
        if it > 1 then
            instance.timing = it - 1
        else
            local starttime = instance.starttime
            if starttime then
                local stoptime = clock()
                local loadtime = stoptime - starttime
                instance.stoptime = stoptime
                instance.loadtime = instance.loadtime + loadtime
                if report then
                    statistics.report("load time %0.3f",loadtime)
                end
                instance.timing = 0
                return loadtime
            end
        end
    end
    return 0
end

function statistics.elapsedtime(instance)
    if not instance then
        instance = notimer
    end
    return format("%0.3f",(instance and instance.loadtime) or 0)
end

function statistics.elapsedindeed(instance)
    if not instance then
        instance = notimer
    end
    local t = (instance and instance.loadtime) or 0
    return t > statistics.threshold
end

-- general function

function statistics.register(tag,fnc)
    if statistics.enable and type(fnc) == "function" then
        local rt = registered[tag] or (#statusinfo + 1)
        statusinfo[rt] = { tag, fnc }
        registered[tag] = rt
        if #tag > n then n = #tag end
    end
end

function statistics.show(reporter)
    if statistics.enable then
        if not reporter then reporter = function(tag,data,n) texio.write_nl(tag .. " " .. data) end end
        -- this code will move
        local register = statistics.register
        register("luatex banner", function()
            return string.lower(status.banner)
        end)
        register("control sequences", function()
            return format("%s of %s", status.cs_count, status.hash_size+status.hash_extra)
        end)
        register("callbacks", function()
            local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
            return format("direct: %s, indirect: %s, total: %s", total-indirect, indirect, total)
        end)
        register("current memory usage", statistics.memused)
        register("runtime",statistics.runtime)
--         --
        for i=1,#statusinfo do
            local s = statusinfo[i]
            local r = s[2]()
            if r then
                reporter(s[1],r,n)
            end
        end
        texio.write_nl("") -- final newline
        statistics.enable = false
    end
end

function statistics.show_job_stat(tag,data,n)
    texio.write_nl(format("%-15s: %s - %s","mkiv lua stats",tag:rpadd(n," "),data))
end

function statistics.memused() -- no math.round yet -)
    local round = math.round or math.floor
    return format("%s MB (ctx: %s MB)",round(collectgarbage("count")/1000), round(status.luastate_bytes/1000000))
end

if statistics.runtime then
    -- already loaded and set
elseif luatex and luatex.starttime then
    statistics.starttime = luatex.starttime
    statistics.loadtime = 0
    statistics.timing = 0
else
    statistics.starttiming(statistics)
end

function statistics.runtime()
    statistics.stoptiming(statistics)
    return statistics.formatruntime(statistics.elapsedtime(statistics))
end

function statistics.formatruntime(runtime)
    return format("%s seconds", statistics.elapsedtime(statistics))
end

function statistics.timed(action,report)
    local timer = { }
    report = report or logs.simple
    statistics.starttiming(timer)
    action()
    statistics.stoptiming(timer)
    report("total runtime: %s",statistics.elapsedtime(timer))
end
