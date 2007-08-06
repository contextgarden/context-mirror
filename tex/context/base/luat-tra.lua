-- filename : luat-tra.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-tra'] = 1.001

debugger = { }

debugger.counters = { }
debugger.names    = { }

function debugger.hook()
    local f = debug.getinfo(2,"f").func
    if debugger.counters[f] == nil then
        debugger.counters[f] = 1
        debugger.names[f] = debug.getinfo(2,"Sn")
    else
        debugger.counters[f] = debugger.counters[f] + 1
    end
end

function debugger.getname(func)
    local n = debugger.names[func]
    if n.what == "C" then
        return n.name
    end
    local lc = string.format("[%s]:%s", n.short_src, n.linedefined)
    if n.namewhat ~= "" then
        return string.format("%s (%s)", lc, n.name)
    else
        return lc
    end
end

function debugger.showstats(printer,threshold)
    if not printer   then printer   = print end
    if not threshold then threshold = 0     end
    for func, count in pairs(debugger.counters) do
        if count > threshold then
            printer(string.format("%8i  %s\n", count, debugger.getname(func)))
        end
    end
end

function debugger.savestats(filename,threshold)
    local f = io.open(filename,'w')
    if f then
        debugger.showstats(function(str) f:write(str) end,threshold)
        f:close()
    end
end

function debugger.enable()
    debug.sethook(debugger.hook,"c")
end

function debugger.disable()
    debug.sethook()
--~     debugger.counters[debug.getinfo(2,"f").func] = nil
end

function debugger.tracing()
    return tonumber((os.env['MTX.TRACE.CALLS'] or os.env['MTX_TRACE_CALLS'] or 0)) > 0
end

--~ debugger.enable()

--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))

--~ debugger.disable()

--~ print("")
--~ debugger.showstats()
--~ print("")
--~ debugger.showstats(print,3)

