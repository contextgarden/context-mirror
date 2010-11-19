if not modules then modules = { } end modules ['util.deb'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- the <anonymous> tag is kind of generic and used for functions that are not
-- bound to a variable, like node.new, node.copy etc (contrary to for instance
-- node.has_attribute which is bound to a has_attribute local variable in mkiv)

local debug = require "debug"

local getinfo = debug.getinfo
local type, next, tostring = type, next, tostring
local format, find = string.format, string.find
local is_boolean = string.is_boolean

utilities          = utilities or { }
utilities.debugger = utilities.debugger or { }
local debugger     = utilities.debugger

local counters = { }
local names    = { }

-- one

local function hook()
    local f = getinfo(2,"f").func
    local n = getinfo(2,"Sn")
--  if n.what == "C" and n.name then print (n.namewhat .. ': ' .. n.name) end
    if f then
        local cf = counters[f]
        if cf == nil then
            counters[f] = 1
            names[f] = n
        else
            counters[f] = cf + 1
        end
    end
end

local function getname(func)
    local n = names[func]
    if n then
        if n.what == "C" then
            return n.name or '<anonymous>'
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
    for func, count in next, counters do
        if count > threshold then
            local name = getname(func)
            if not find(name,"for generator") then
                printer(format("%8i  %s", count, name))
                total = total + count
            end
        end
        grandtotal = grandtotal + count
        functions = functions + 1
    end
    printer(format("functions: %s, total: %s, grand total: %s, threshold: %s\n", functions, total, grandtotal, threshold))
end

-- two

--~ local function hook()
--~     local n = getinfo(2)
--~     if n.what=="C" and not n.name then
--~         local f = tostring(debug.traceback())
--~         local cf = counters[f]
--~         if cf == nil then
--~             counters[f] = 1
--~             names[f] = n
--~         else
--~             counters[f] = cf + 1
--~         end
--~     end
--~ end
--~ function debugger.showstats(printer,threshold)
--~     printer   = printer or texio.write or print
--~     threshold = threshold or 0
--~     local total, grandtotal, functions = 0, 0, 0
--~     printer("\n") -- ugly but ok
--~  -- table.sort(counters)
--~     for func, count in next, counters do
--~         if count > threshold then
--~             printer(format("%8i  %s", count, func))
--~             total = total + count
--~         end
--~         grandtotal = grandtotal + count
--~         functions = functions + 1
--~     end
--~     printer(format("functions: %s, total: %s, grand total: %s, threshold: %s\n", functions, total, grandtotal, threshold))
--~ end

-- rest

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

local is_node = node and node.is_node

function inspect(i)
    local ti = type(i)
    if ti == "table" then
        table.print(i,"table")
    elseif is_node and is_node(i) then
        print(node.sequenced(i))
    else
        print(tostring(i))
    end
end
