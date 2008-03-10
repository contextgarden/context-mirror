-- filename : luat-env.lua
-- comment  : companion to luat-env.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- here we don't assume any extra libraries

-- A former version provides functionality for non embeded core
-- scripts i.e. runtime library loading. Given the amount of
-- Lua code we use now, this no longer makes sense. Much of this
-- evolved before bytecode arrays were available.

if not versions then versions = { } end versions['luat-env'] = 1.001

-- environment

if not environment then environment = { } end

--~ environment.useluc  = true -- still testing, so we don't use luc yet

if environment.silent == nil then environment.silent  = false end
if environment.useluc == nil then environment.useluc  = true  end

-- kpse is overloaded by this time

--~ if environment.formatname  == nil then if tex  then environment.formatname = tex.formatname                              end end
--~ if environment.formatpath  == nil then if kpse then environment.formatpath = kpse.find_file(tex.formatname,"fmt") or "." end end
--~ if environment.jobname     == nil then if tex  then environment.jobname    = tex.jobname                                 end end
--~ if environment.progname    == nil then              environment.progname   = os.getenv("progname")    or "luatex"        end
--~ if environment.engine      == nil then              environment.engine     = os.getenv("engine")      or "context"       end
--~ if environment.enginepath  == nil then              environment.enginepath = os.getenv("SELFAUTOLOC") or "."             end
--~ if environment.initex      == nil then if tex  then environment.initex     = tex.formatname == ""                        end end

if not environment.formatname or environment.formatname == "" then if tex then environment.formatname = tex.formatname end end
if not environment.jobname    or environment.jobname    == "" then if tex then environment.jobname    = tex.jobname    end end

if not environment.progname   or environment.progname   == "" then environment.progname   = "luatex"  end
if not environment.engine     or environment.engine     == "" then environment.engine     = "context" end
if not environment.formatname or environment.formatname == "" then environment.formatname = "cont-en" end
if not environment.formatpath or environment.formatpath == "" then environment.formatpath = '.'       end
if not environment.enginepath or environment.enginepath == "" then environment.enginepath = '.'       end
if not environment.version    or environment.version    == "" then environment.version    = "unknown" end

environment.formatpath = string.gsub(environment.formatpath:gsub("\\","/"),"/([^/]-)$","")
environment.enginepath = string.gsub(environment.enginepath:gsub("\\","/"),"/([^/]-)$","")

function environment.texfile(filename)
    return input.find_file(texmf.instance,filename,'tex')
end

function environment.luafile(filename)
    return input.find_file(texmf.instance,filename,'tex') or input.find_file(texmf.instance,filename,'texmfscripts')
end

function environment.showmessage(...) -- todo, cleaner
    if not environment.silent then
        if input and input.report then
            input.report(table.concat({...}," "))
        elseif texio and texio.write_nl then
            texio.write_nl("[[" .. table.concat({...}," ") .. "]]")
        else
            print("[[" .. table.concat({...}," ") .. "]]")
        end
    end
end

if not environment.jobname then environment.jobname  = "unknown" end

function environment.setlucpath()
    if environment.initex then
        environment.lucpath = nil
    else
        environment.lucpath = environment.formatpath .. "/lua/" .. environment.progname
    end
end

environment.setlucpath()

function environment.loadedluacode(fullname)
    return loadfile(fullname)
end

function environment.luafilechunk(filename)
    local filename = filename:gsub("%.%a+$", "") .. ".lua"
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        environment.showmessage("loading file", fullname)
        return environment.loadedluacode(fullname)
    else
        environment.showmessage("unknown file", filename)
        return nil
    end
end

-- the next ones can use the previous ones

function environment.loadluafile(filename)
    filename = filename:gsub("%.%a+$", "") .. ".lua"
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        environment.showmessage("loading", fullname)
        dofile(fullname)
    else
        environment.showmessage("unknown file", filename)
    end
end

function environment.loadlucfile(filename,version)
    local filename = filename:gsub("%.%a+$", "")
    local fullname = nil
    if environment.initex or not environment.useluc then
        environment.loadluafile(filename)
    else
        if environment.lucpath and environment.lucpath ~= "" then
            fullname = environment.lucpath .. "/" .. filename .. ".luc"
            local chunk = loadfile(fullname) -- this way we don't need a file exists check
            if chunk then
                environment.showmessage("loading", fullname)
                assert(chunk)()
                if version then
                    local v = version -- can be nil
                    if modules and modules[filename] then
                        v = modules[filename].version -- new
                    elseif versions and versions[filename] then
                        v = versions[filename]        -- old
                    end
                    if v ~= version then
                        environment.showmessage("version mismatch", filename,"lua=" .. v, "luc=" ..version)
                        environment.loadluafile(filename)
                    end

                end
            else
                environment.loadluafile(filename)
            end
        else
            environment.loadluafile(filename)
        end
    end
end

-- -- -- the next function was posted by Peter Cawley on the lua list -- -- --
-- -- --                                                              -- -- --
-- -- -- stripping makes the compressed format file about 1MB smaller -- -- --
-- -- --                                                              -- -- --
-- -- -- using this trick is at your own risk                         -- -- --

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
