-- filename : luat-env.lua
-- comment  : companion to luat-env.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- here we don't assume any extra libraries

-- A former version provides functionality for non embeded core
-- scripts i.e. runtime library loading. Given the amount of
-- Lua code we use now, this no longer makes sense. Much of this
-- evolved before bytecode arrays were available. Much code has
-- disappeared already.

if not versions then versions = { } end versions['luat-env'] = 1.001

-- environment

if not environment then environment = { } end

environment.trace = false

-- kpse is overloaded by this time

if not environment.jobname or environment.jobname == "" then if tex then environment.jobname = tex.jobname end end
if not environment.version or environment.version == "" then             environment.version = "unknown"   end

function environment.texfile(filename)
    return input.find_file(filename,'tex')
end

function environment.luafile(filename)
    return input.find_file(filename,'tex') or input.find_file(filename,'texmfscripts')
end

if not environment.jobname then environment.jobname  = "unknown" end

environment.loadedluacode = loadfile -- can be overloaded

function environment.luafilechunk(filename) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        input.report("loading file %s", fullname)
        return environment.loadedluacode(fullname)
    else
        input.report("unknown file %s", filename)
        return nil
    end
end

-- the next ones can use the previous ones / combine

function environment.loadluafile(filename, version)
    local lucname, luaname, chunk
    local basename = file.removesuffix(filename)
    if basename == filename then
        lucname, luaname = basename .. ".luc",  basename .. ".lua"
    else
        lucname, luaname = nil, basename -- forced suffix
    end
    -- when not overloaded by explicit suffix we look for a luc file first
    local fullname = (lucname and environment.luafile(lucname)) or ""
    if fullname ~= "" then
        input.report("loading %s", fullname)
        chunk = loadfile(fullname) -- this way we don't need a file exists check
    end
    if chunk then
        assert(chunk)()
        if version then
            -- we check of the version number of this chunk matches
            local v = version -- can be nil
            if modules and modules[filename] then
                v = modules[filename].version -- new method
            elseif versions and versions[filename] then
                v = versions[filename]        -- old method
            end
            if v == version then
                return true
            else
                input.report("version mismatch for %s: lua=%s, luc=%s", filename, v, version)
                environment.loadluafile(filename)
            end
        else
            return true
        end
    end
    fullname = (luaname and environment.luafile(luaname)) or ""
    if fullname ~= "" then
        input.report("loading %s", fullname)
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            input.report("unknown file %s", filename)
        else
            assert(chunk)()
            return true
        end
    end
    return false
end

-- -- -- the next function was posted by Peter Cawley on the lua list -- -- --
-- -- --                                                              -- -- --
-- -- -- stripping makes the compressed format file about 1MB smaller -- -- --
-- -- --                                                              -- -- --
-- -- -- using this trick is at your own risk                         -- -- --
-- -- --                                                              -- -- --
-- -- -- this is just an experiment, this feature may disappear       -- -- --

local function strip_code(dump)
    local version, format, endian, int, size, ins, num = dump:byte(5, 11)
    local subint
    if endian == 1 then
        subint = function(dump, i, l)
            local val = 0
            for n = l, 1, -1 do
                val = val * 256 + dump:byte(i + n - 1)
            end
            return val, i + l
        end
    else
        subint = function(dump, i, l)
            local val = 0
            for n = 1, l, 1 do
                val = val * 256 + dump:byte(i + n - 1)
            end
            return val, i + l
        end
    end
    local strip_function
    strip_function = function(dump)
        local count, offset = subint(dump, 1, size)
        local stripped, dirty = string.rep("\0", size), offset + count
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
        stripped = stripped .. dump:sub(dirty, offset - 1)
        for n = 1, count do
            local proto, off = strip_function(dump:sub(offset, -1))
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
        stripped = stripped .. string.rep("\0", int * 3)
        return stripped, offset
    end
    return dump:sub(1,12) .. strip_function(dump:sub(13,-1))
end

environment.stripcode = false -- true

function environment.loadedluacode(fullname)
    if environment.stripcode then
        return loadstring(strip_code(string.dump(loadstring(io.loaddata(fullname)))))
    else
        return loadfile(fullname)
    end
end

-- -- end of stripping code -- --
