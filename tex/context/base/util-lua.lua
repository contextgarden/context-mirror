if not modules then modules = { } end modules ['util-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    comment   = "the strip code is written by Peter Cawley",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rep, sub, byte, dump, format = string.rep, string.sub, string.byte, string.dump, string.format
local load, loadfile, type = load, loadfile, type

utilities          = utilities or {}
utilities.lua      = utilities.lua or { }
local luautilities = utilities.lua

utilities.report   = logs and logs.reporter("system") or print -- can be overloaded later

local tracestripping           = false
local forcestupidcompile       = true  -- use internal bytecode compiler
luautilities.stripcode         = true  -- support stripping when asked for
luautilities.alwaysstripcode   = false -- saves 1 meg on 7 meg compressed format file (2012.08.12)
luautilities.nofstrippedchunks = 0
luautilities.nofstrippedbytes  = 0
local strippedchunks           = { } -- allocate()
luautilities.strippedchunks    = strippedchunks

luautilities.suffixes = {
    tma = "tma",
    tmc = jit and "tmb" or "tmc",
    lua = "lua",
    luc = jit and "lub" or "luc",
    lui = "lui",
    luv = "luv",
    luj = "luj",
    tua = "tua",
    tuc = "tuc",
}

local function fatalerror(name)
    utilities.report(format("fatal error in %q",name or "unknown"))
end

if jit or status.luatex_version >= 74 then

    local function register(name)
        if tracestripping then
            utilities.report("stripped bytecode: %s",name or "unknown")
        end
        strippedchunks[#strippedchunks+1] = name
        luautilities.nofstrippedchunks = luautilities.nofstrippedchunks + 1
    end

    local function stupidcompile(luafile,lucfile,strip)
        local code = io.loaddata(luafile)
        if code and code ~= "" then
            code = load(code)
            if code then
                code = dump(code,strip and luautilities.stripcode or luautilities.alwaysstripcode)
                if code and code ~= "" then
                    register(name)
                    io.savedata(lucfile,code)
                    return true, 0
                end
            else
                fatalerror()
            end
        else
            fatalerror()
        end
        return false, 0
    end

    -- quite subtle ... doing this wrong incidentally can give more bytes

    function luautilities.loadedluacode(fullname,forcestrip,name)
        -- quite subtle ... doing this wrong incidentally can give more bytes
        name = name or fullname
        local code = loadfile(fullname)
        if code then
            code()
        end
        if forcestrip and luautilities.stripcode then
            if type(forcestrip) == "function" then
                forcestrip = forcestrip(fullname)
            end
            if forcestrip or luautilities.alwaysstripcode then
                register(name)
                return load(dump(code,true)), 0
            else
                return code, 0
            end
        elseif luautilities.alwaysstripcode then
            register(name)
            return load(dump(code,true)), 0
        else
            return code, 0
        end
    end

    function luautilities.strippedloadstring(code,forcestrip,name) -- not executed
        if forcestrip and luautilities.stripcode or luautilities.alwaysstripcode then
            code = load(code)
            if not code then
                fatalerror(name)
            end
            register(name)
            code = dump(code,true)
        end
        return load(code), 0
    end

    function luautilities.compile(luafile,lucfile,cleanup,strip,fallback) -- defaults: cleanup=false strip=true
        utilities.report("lua: compiling %s into %s",luafile,lucfile)
        os.remove(lucfile)
        local done = stupidcompile(luafile,lucfile,strip ~= false)
        if done then
            utilities.report("lua: %s dumped into %s (stripped)",luafile,lucfile)
            if cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
                utilities.report("lua: removing %s",luafile)
                os.remove(luafile)
            end
        end
        return done
    end

else

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

    local function register(name,before,after)
        local delta = before - after
        if tracestripping then
            utilities.report("stripped bytecode: %s, before %s, after %s, delta %s",name or "unknown",before,after,delta)
        end
        strippedchunks[#strippedchunks+1] = name
        luautilities.nofstrippedchunks = luautilities.nofstrippedchunks + 1
        luautilities.nofstrippedbytes  = luautilities.nofstrippedbytes  + delta
        return delta
    end

    local strip_code_pc

    if _MAJORVERSION == 5 and _MINORVERSION == 1 then

        strip_code_pc = function(dump,name)
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
            local delta = register(name,before,after)
            return dump, delta
        end

    else

        strip_code_pc = function(dump,name)
            return dump, 0
        end

    end

    -- ... end of borrowed code.

    -- quite subtle ... doing this wrong incidentally can give more bytes

    function luautilities.loadedluacode(fullname,forcestrip,name)
        -- quite subtle ... doing this wrong incidentally can give more bytes
        name = name or fullname
        local code = loadfile(fullname)
        if code then
            code()
        end
        if forcestrip and luautilities.stripcode then
            if type(forcestrip) == "function" then
                forcestrip = forcestrip(fullname)
            end
            if forcestrip then
                local code, n = strip_code_pc(dump(code),name)
                return load(code), n
            elseif luautilities.alwaysstripcode then
                return load(strip_code_pc(dump(code),name))
            else
                return code, 0
            end
        elseif luautilities.alwaysstripcode then
            return load(strip_code_pc(dump(code),name))
        else
            return code, 0
        end
    end

    function luautilities.strippedloadstring(code,forcestrip,name) -- not executed
        local n = 0
        if (forcestrip and luautilities.stripcode) or luautilities.alwaysstripcode then
            code = load(code)
            if not code then
                fatalerror(name)
            end
            code, n = strip_code_pc(dump(code),name)
        end
        return load(code), n
    end

    local function stupidcompile(luafile,lucfile,strip)
        local code = io.loaddata(luafile)
        local n = 0
        if code and code ~= "" then
            code = load(code)
            if not code then
                fatalerror()
            end
            code = dump(code)
            if strip then
                code, n = strip_code_pc(code,luautilities.stripcode or luautilities.alwaysstripcode,luafile) -- last one is reported
            end
            if code and code ~= "" then
                io.savedata(lucfile,code)
            end
        end
        return n
    end

    local luac_normal = "texluac -o %q %q"
    local luac_strip  = "texluac -s -o %q %q"

    function luautilities.compile(luafile,lucfile,cleanup,strip,fallback) -- defaults: cleanup=false strip=true
        utilities.report("lua: compiling %s into %s",luafile,lucfile)
        os.remove(lucfile)
        local done = false
        if strip ~= false then
            strip = true
        end
        if forcestupidcompile then
            fallback = true
        elseif strip then
            done = os.spawn(format(luac_strip, lucfile,luafile)) == 0
        else
            done = os.spawn(format(luac_normal,lucfile,luafile)) == 0
        end
        if not done and fallback then
            local n = stupidcompile(luafile,lucfile,strip)
            if n > 0 then
                utilities.report("lua: %s dumped into %s (%i bytes stripped)",luafile,lucfile,n)
            else
                utilities.report("lua: %s dumped into %s (unstripped)",luafile,lucfile)
            end
            cleanup = false -- better see how bad it is
            done = true -- hm
        end
        if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
            utilities.report("lua: removing %s",luafile)
            os.remove(luafile)
        end
        return done
    end

end

-- local getmetatable, type = getmetatable, type
--
-- local types = { }
--
-- function luautilities.registerdatatype(d,name)
--     types[getmetatable(d)] = name
-- end
--
-- function luautilities.datatype(d)
--     local t = type(d)
--     if t == "userdata" then
--         local m = getmetatable(d)
--         return m and types[m] or "userdata"
--     else
--         return t
--     end
-- end
--
-- luautilities.registerdatatype(lpeg.P("!"),"lpeg")
--
-- print(luautilities.datatype(lpeg.P("oeps")))
