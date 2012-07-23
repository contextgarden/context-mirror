if not modules then modules = { } end modules ['util-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    comment   = "the strip code is written by Peter Cawley",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rep, sub, byte, dump = string.rep, string.sub, string.byte, string.dump
local loadstring, loadfile = loadstring, loadfile

utilities          = utilities or {}
utilities.lua      = utilities.lua or { }
local luautilities = utilities.lua

utilities.report   = logs and logs.reporter("system") or print

local tracestripping           = false
local forcestupidcompile       = true
luautilities.stripcode         = true
luautilities.nofstrippedchunks = 0
luautilities.nofstrippedbytes  = 0

-- The next function was posted by Peter Cawley on the lua list and strips line
-- number information etc. from the bytecode data blob. We only apply this trick
-- when we store data tables. Stripping makes the compressed format file about
-- 1MB smaller (and uncompressed we save at least 6MB).
--
-- You can consider this feature an experiment, so it might disappear. There is
-- no noticeable gain in runtime although the memory footprint should be somewhat
-- smaller (and the file system has a bit less to deal with).
--
-- Begin of borrowed code ... works for Lua 5.1 which LuaTeX currently uses ...

local function strip_code_pc(dump,name)
    local before = #dump
    local version, format, endian, int, size, ins, num = byte(dump,5,11)
    local subint
    if endian == 1 then
        subint = function(dump, i, l)
            local val = 0
            for n = l, 1, -1 do
                val = val * 256 + byte(dump,i + n - 1)
            end
            return val, i + l
        end
    else
        subint = function(dump, i, l)
            local val = 0
            for n = 1, l, 1 do
                val = val * 256 + byte(dump,i + n - 1)
            end
            return val, i + l
        end
    end
    local strip_function
    strip_function = function(dump)
        local count, offset = subint(dump, 1, size)
        local stripped, dirty = rep("\0", size), offset + count
        offset = offset + count + int * 2 + 4
        offset = offset + int + subint(dump, offset, int) * ins
        count, offset = subint(dump, offset, int)
        for n = 1, count do
            local t
            t, offset = subint(dump, offset, 1)
            if t == 1 then
                offset = offset + 1
            elseif t == 4 then
                offset = offset + size + subint(dump, offset, size)
            elseif t == 3 then
                offset = offset + num
            end
        end
        count, offset = subint(dump, offset, int)
        stripped = stripped .. sub(dump,dirty, offset - 1)
        for n = 1, count do
            local proto, off = strip_function(sub(dump,offset, -1))
            stripped, offset = stripped .. proto, offset + off - 1
        end
        offset = offset + subint(dump, offset, int) * int + int
        count, offset = subint(dump, offset, int)
        for n = 1, count do
            offset = offset + subint(dump, offset, size) + size + int * 2
        end
        count, offset = subint(dump, offset, int)
        for n = 1, count do
            offset = offset + subint(dump, offset, size) + size
        end
        stripped = stripped .. rep("\0", int * 3)
        return stripped, offset
    end
    dump = sub(dump,1,12) .. strip_function(sub(dump,13,-1))
    local after = #dump
    local delta = before-after
    if tracestripping then
        utilities.report("stripped bytecode: %s, before %s, after %s, delta %s",name or "unknown",before,after,delta)
    end
    luautilities.nofstrippedchunks = luautilities.nofstrippedchunks + 1
    luautilities.nofstrippedbytes  = luautilities.nofstrippedbytes  + delta
    return dump, delta
end

-- ... end of borrowed code.

local function strippedbytecode(code,forcestrip,name)
    if forcestrip and luautilities.stripcode then
        return strip_code_pc(code,name)
    else
        return code, 0
    end
end

luautilities.stripbytecode    = strip_code_pc
luautilities.strippedbytecode = strippedbytecode

function luautilities.loadedluacode(fullname,forcestrip,name)
    -- quite subtle ... doing this wrong incidentally can give more bytes
    local code = loadfile(fullname)
    if code then
        code()
    end
    if forcestrip and luautilities.stripcode then
        if type(forcestrip) == "function" then
            forcestrip = forcestrip(fullname)
        end
        if forcestrip then
            local code, n = strip_code_pc(dump(code,name or fullname))
            return loadstring(code), n
        else
            return code, 0
        end
    else
        return code, 0
    end
end

function luautilities.strippedloadstring(str,forcestrip,name) -- better inline
    if forcestrip and luautilities.stripcode then
        local code, n = strip_code_pc(dump(loadstring(str)),name)
        return loadstring(code), n
    else
        return loadstring(str)
    end
end

local function stupidcompile(luafile,lucfile,strip)
    local data = io.loaddata(luafile)
    if data and data ~= "" then
        data = dump(loadstring(data))
        if strip then
            data = strippedbytecode(data,true,luafile) -- last one is reported
        end
        if data and data ~= "" then
            io.savedata(lucfile,data)
        end
    end
end

function luautilities.compile(luafile,lucfile,cleanup,strip,fallback) -- defaults: cleanup=false strip=true
    utilities.report("lua: compiling %s into %s",luafile,lucfile)
    os.remove(lucfile)
    local done = false
    if forcestupidcompile then
        fallback = true
    else
        local command = "-o " .. string.quoted(lucfile) .. " " .. string.quoted(luafile)
        if strip ~= false then
            command = "-s " .. command
        end
        done = os.spawn("texluac " .. command) == 0 -- or os.spawn("luac " .. command) == 0
    end
    if not done and fallback then
        utilities.report("lua: dumping %s into %s (unstripped)",luafile,lucfile)
        stupidcompile(luafile,lucfile,strip)
        cleanup = false -- better see how bad it is
    end
    if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
        utilities.report("lua: removing %s",luafile)
        os.remove(luafile)
    end
    return done
end

--~ local getmetatable, type = getmetatable, type

--~ local types = { }

--~ function luautilities.registerdatatype(d,name)
--~     types[getmetatable(d)] = name
--~ end

--~ function luautilities.datatype(d)
--~     local t = type(d)
--~     if t == "userdata" then
--~         local m = getmetatable(d)
--~         return m and types[m] or "userdata"
--~     else
--~         return t
--~     end
--~ end

--~ luautilities.registerdatatype(lpeg.P("!"),"lpeg")

--~ print(luautilities.datatype(lpeg.P("oeps")))
