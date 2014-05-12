if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is very preliminary code!

-- maybe we need mplib.model, but how with instances

local type, tostring, select, loadstring = type, tostring, select, loadstring
local formatters = string.formatters
local find, gsub = string.find, string.gsub
local concat = table.concat
local lpegmatch = lpeg.match

local report_luarun = logs.reporter("metapost","lua")

local trace_luarun  = false  trackers.register("metapost.lua",function(v) trace_luarun = v end)
local trace_enabled = true

mp = mp or { } -- system namespace
MP = MP or { } -- user namespace

local buffer, n, max = { }, 0, 10 -- we reuse upto max

function mp._f_()
    if trace_enabled and trace_luarun then
        local result = concat(buffer," ",1,n)
        if n > max then
            buffer = { }
        end
        n = 0
        report_luarun("data: %s",result)
        return result
    else
        if n == 0 then
            return ""
        end
        local result
        if n == 1 then
            result = buffer[1]
        else
            result = concat(buffer," ",1,n)
        end
        if n > max then
            buffer = { }
        end
        n = 0
        return result
    end
end

local f_numeric   = formatters["%.16f"]
local f_pair      = formatters["(%.16f,%.16f)"]
local f_triplet   = formatters["(%.16f,%.16f,%.16f)"]
local f_quadruple = formatters["(%.16f,%.16f,%.16f,%.16f)"]

function mp.print(...)
    for i=1,select("#",...) do
        local value = select(i,...)
        if value then
            n = n + 1
            local t = type(value)
            if t == "number" then
                buffer[n] = f_numeric(value)
            elseif t == "string" then
                buffer[n] = value
            else
                buffer[n] = tostring(value)
            end
        end
    end
end

function mp.pair(x,y)
    n = n + 1
    if type(x) == "table" then
        buffer[n] = f_pair(x[1],x[2])
    else
        buffer[n] = f_pair(x,y)
    end
end

function mp.triplet(x,y,z)
    n = n + 1
    if type(x) == "table" then
        buffer[n] = f_triplet(x[1],x[2],x[3])
    else
        buffer[n] = f_triplet(x,y,z)
    end
end

function mp.quadruple(w,x,y,z)
    n = n + 1
    if type(w) == "table" then
        buffer[n] = f_quadruple(w[1],w[2],w[3],w[4])
    else
        buffer[n] = f_quadruple(w,x,y,z)
    end
end

local replacer = lpeg.replacer("@","%%")

function mp.format(fmt,...)
    n = n + 1
    if not find(fmt,"%%") then
        fmt = lpegmatch(replacer,fmt)
    end
    buffer[n] = formatters[fmt](...)
end

function mp.quoted(fmt,s,...)
    n = n + 1
    if s then
        if not find(fmt,"%%") then
            fmt = lpegmatch(replacer,fmt)
        end
        buffer[n] = '"' .. formatters[fmt](s,...) .. '"'
    else
        buffer[n] = '"' .. fmt .. '"'
    end
end

local f_code = formatters["%s return mp._f_()"]

-- function metapost.runscript(code)
--     local f = loadstring(f_code(code))
--     if f then
--         local result = f()
--         if result then
--             local t = type(result)
--             if t == "number" then
--                 return f_numeric(result)
--             elseif t == "string" then
--                 return result
--             else
--                 return tostring(result)
--             end
--         end
--     end
--     return ""
-- end

local cache, n = { }, 0 -- todo: when > n then reset cache or make weak

function metapost.runscript(code)
    if trace_enabled and trace_luarun then
        report_luarun("code: %s",code)
    end
    local f
    if n > 100 then
        cache = nil -- forget about caching
        f = loadstring(f_code(code))
    else
        f = cache[code]
        if not f then
            f = loadstring(f_code(code))
            if f then
                n = n + 1
                cache[code] = f
            end
        end
    end
    if f then
        local result = f()
        if result then
            local t = type(result)
            if t == "number" then
                return f_numeric(result)
            elseif t == "string" then
                return result
            else
                return tostring(result)
            end
        end
    end
    return ""
end

-- function metapost.initializescriptrunner(mpx)
--     mp.numeric = function(s) return mpx:get_numeric(s) end
--     mp.string  = function(s) return mpx:get_string (s) end
--     mp.boolean = function(s) return mpx:get_boolean(s) end
--     mp.number  = mp.numeric
-- end

local get_numeric = mplib.get_numeric
local get_string  = mplib.get_string
local get_boolean = mplib.get_boolean
local get_number  = get_numeric

-- function metapost.initializescriptrunner(mpx)
--     mp.numeric = function(s) return get_numeric(mpx,s) end
--     mp.string  = function(s) return get_string (mpx,s) end
--     mp.boolean = function(s) return get_boolean(mpx,s) end
--     mp.number  = mp.numeric
-- end

local currentmpx = nil

mp.numeric = function(s) return get_numeric(currentmpx,s) end
mp.string  = function(s) return get_string (currentmpx,s) end
mp.boolean = function(s) return get_boolean(currentmpx,s) end
mp.number  = mp.numeric

function metapost.initializescriptrunner(mpx,trialrun)
    currentmpx = mpx
    trace_enabled = not trialrun
end
