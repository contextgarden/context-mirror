if not modules then modules = { } end modules ['trac-tra'] = {
    version   = 1.001,
    comment   = "companion to trac-tra.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- the <anonymous> tag is kind of generic and used for functions that are not
-- bound to a variable, like node.new, node.copy etc (contrary to for instance
-- node.has_attribute which is bound to a has_attribute local variable in mkiv)

local getinfo = debug.getinfo
local type, next = type, next
local concat = table.concat
local format, find, lower, gmatch, gsub = string.format, string.find, string.lower, string.gmatch, string.gsub

debugger = debugger or { }

local counters = { }
local names = { }

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
    for func, count in pairs(counters) do
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
--~     for func, count in pairs(counters) do
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

setters      = setters      or { }
setters.data = setters.data or { }

--~ local function set(t,what,value)
--~     local data, done = t.data, t.done
--~     if type(what) == "string" then
--~         what = aux.settings_to_array(what) -- inefficient but ok
--~     end
--~     for i=1,#what do
--~         local w = what[i]
--~         for d, f in next, data do
--~             if done[d] then
--~                 -- prevent recursion due to wildcards
--~             elseif find(d,w) then
--~                 done[d] = true
--~                 for i=1,#f do
--~                     f[i](value)
--~                 end
--~             end
--~         end
--~     end
--~ end

local function set(t,what,value)
    local data, done = t.data, t.done
    if type(what) == "string" then
        what = aux.settings_to_hash(what) -- inefficient but ok
    end
    for w, v in next, what do
        if v == "" then
            v = value
        else
            v = toboolean(v)
        end
        for d, f in next, data do
            if done[d] then
                -- prevent recursion due to wildcards
            elseif find(d,w) then
                done[d] = true
                for i=1,#f do
                    f[i](v)
                end
            end
        end
    end
end

local function reset(t)
    for d, f in next, t.data do
        for i=1,#f do
            f[i](false)
        end
    end
end

local function enable(t,what)
    set(t,what,true)
end

local function disable(t,what)
    local data = t.data
    if not what or what == "" then
        t.done = { }
        reset(t)
    else
        set(t,what,false)
    end
end

function setters.register(t,what,...)
    local data = t.data
    what = lower(what)
    local w = data[what]
    if not w then
        w = { }
        data[what] = w
    end
    for _, fnc in next, { ... } do
        local typ = type(fnc)
        if typ == "function" then
            w[#w+1] = fnc
        elseif typ == "string" then
            w[#w+1] = function(value) set(t,fnc,value,nesting) end
        end
    end
end

function setters.enable(t,what)
    local e = t.enable
    t.enable, t.done = enable, { }
    enable(t,string.simpleesc(what))
    t.enable, t.done = e, { }
end

function setters.disable(t,what)
    local e = t.disable
    t.disable, t.done = disable, { }
    disable(t,string.simpleesc(what))
    t.disable, t.done = e, { }
end

function setters.reset(t)
    t.done = { }
    reset(t)
end

function setters.list(t) -- pattern
    local list = table.sortedkeys(t.data)
    local user, system = { }, { }
    for l=1,#list do
        local what = list[l]
        if find(what,"^%*") then
            system[#system+1] = what
        else
            user[#user+1] = what
        end
    end
    return user, system
end

function setters.show(t)
    commands.writestatus("","")
    for k,v in ipairs(setters.list(t)) do
        commands.writestatus(t.name,v)
    end
    commands.writestatus("","")
end

-- we could have used a bit of oo and the trackers:enable syntax but
-- there is already a lot of code around using the singular tracker

-- we could make this into a module

function setters.new(name)
    local t
    t = {
        data     = { },
        name     = name,
        enable   = function(...) setters.enable  (t,...) end,
        disable  = function(...) setters.disable (t,...) end,
        register = function(...) setters.register(t,...) end,
        list     = function(...) setters.list    (t,...) end,
        show     = function(...) setters.show    (t,...) end,
    }
    setters.data[name] = t
    return t
end

trackers   = setters.new("trackers")
directives = setters.new("directives")

-- nice trick: we overload two of the directives related functions with variants that
-- do tracing (itself using a tracker) .. proof of concept

local trace_directives = false local trace_directives = false  trackers.register("system.directives", function(v) trace_directives = v end)

local e = directives.enable
local d = directives.disable

function directives.enable(...)
    commands.writestatus("directives","enabling: %s",concat({...}," "))
    e(...)
end

function directives.disable(...)
    commands.writestatus("directives","disabling: %s",concat({...}," "))
    d(...)
end
