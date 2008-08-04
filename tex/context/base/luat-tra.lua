-- filename : luat-tra.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-tra'] = 1.001

debugger = { }

local counters = { }
local names    = { }
local getinfo  = debug.getinfo
local format   = string.format

local function hook()
    local f = getinfo(2,"f").func
    if f then
        if counters[f] == nil then
            counters[f] = 1
            names[f] = getinfo(2,"Sn")
        else
            counters[f] = counters[f] + 1
        end
    end
end

local function getname(func)
    local n = names[func]
    if n then
        if n.what == "C" then
            return n.name or '<luacall>'
        else
            -- source short_src linedefined what name namewhat nups func
            local name = n.name or n.namewhat or n.what
            if not name or name == "" then name = "?" end
            return format("%s : %s : %s", n.short_src or "unknown source", n.linedefined or "--", name)
        end
    else
        return "unknown"
    end
end

function debugger.showstats(printer,threshold)
    printer   = printer or texio.write or print
    threshold = threshold or 0
    local total, grandtotal, functions = 0, 0, 0
    printer("\n") -- ugly but ok
 -- table.sort(counters)
    for func, count in pairs(counters) do
        if count > threshold then
            local name = getname(func)
            if not name:find("for generator") then
                printer(format("%8i  %s", count, name))
                total = total + count
            end
        end
        grandtotal = grandtotal + count
        functions = functions + 1
    end
    printer(format("functions: %s, total: %s, grand total: %s, threshold: %s\n", functions, total, grandtotal, threshold))
end

function debugger.savestats(filename,threshold)
    local f = io.open(filename,'w')
    if f then
        debugger.showstats(function(str) f:write(str) end,threshold)
        f:close()
    end
end

function debugger.enable()
    debug.sethook(hook,"c")
end

function debugger.disable()
    debug.sethook()
--~ counters[debug.getinfo(2,"f").func] = nil
end

function debugger.tracing()
    local n = tonumber(os.env['MTX.TRACE.CALLS']) or tonumber(os.env['MTX_TRACE_CALLS']) or 0
    if n > 0 then
        function debugger.tracing() return true  end ; return true
    else
        function debugger.tracing() return false end ; return false
    end
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

