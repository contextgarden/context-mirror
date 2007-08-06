-- filename : l-io.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-io'] = 1.001

if string.find(os.getenv("PATH"),";") then
    io.fileseparator, io.pathseparator = "\\", ";"
else
    io.fileseparator, io.pathseparator = "/" , ":"
end

function io.loaddata(filename)
    local f = io.open(filename)
    if f then
        local data = f:read('*all')
        f:close()
        return data
    else
        return nil
    end
end

function io.savedata(filename,data,joiner)
    local f = io.open(filename, "wb")
    if f then
        if type(data) == "table" then
            f:write(table.join(data,joiner or ""))
        elseif type(data) == "function" then
            data(f)
        else
            f:write(data)
        end
        f:close()
    end
end

function io.exists(filename)
    local f = io.open(filename)
    if f == nil then
        return false
    else
        assert(f:close())
        return true
    end
end

function io.size(filename)
    local f = io.open(filename)
    if f == nil then
        return 0
    else
        local s = f:seek("end")
        assert(f:close())
        return s
    end
end

function io.noflines(f)
    local n = 0
    for _ in f:lines() do
        n = n + 1
    end
    f:seek('set',0)
    return n
end

--~ t, f, n = os.clock(), io.open("testbed/sample-utf16-bigendian-big.txt",'rb'), 0
--~ for a in io.characters(f) do n = n + 1 end
--~ print(string.format("characters: %s, time: %s", n, os.clock()-t))

do

    local nextchar = {
        [ 4] = function(f)
            return f:read(1), f:read(1), f:read(1), f:read(1)
        end,
        [ 2] = function(f)
            return f:read(1), f:read(1)
        end,
        [ 1] = function(f)
            return f:read(1)
        end,
        [-2] = function(f)
            local a = f:read(1)
            local b = f:read(1)
            return b, a
        end,
        [-4] = function(f)
            local a = f:read(1)
            local b = f:read(1)
            local c = f:read(1)
            local c = f:read(1)
            return d, c, b, a
        end
    }

    function io.characters(f,n)
        local sb = string.byte
        if f then
            return nextchar[n or 1], f
        else
            return nil, nil
        end
    end

end

do

    local nextbyte = {
        [4] = function(f)
            local a = f:read(1)
            local b = f:read(1)
            local c = f:read(1)
            local d = f:read(1)
            if d then
                return sb(a), sb(b), sb(c), sb(d)
            else
                return nil, nil, nil, nil
            end
        end,
        [2] = function(f)
            local a = f:read(1)
            local b = f:read(1)
            if b then
                return sb(a), sb(b)
            else
                return nil, nil
            end
        end,
        [1] = function (f)
            local a = f:read(1)
            if a then
                return sb(a)
            else
                return nil
            end
        end,
        [-2] = function (f)
            local a = f:read(1)
            local b = f:read(1)
            if b then
                return sb(b), sb(a)
            else
                return nil, nil
            end
        end,
        [-4] = function(f)
            local a = f:read(1)
            local b = f:read(1)
            local c = f:read(1)
            local d = f:read(1)
            if d then
                return sb(d), sb(c), sb(b), sb(a)
            else
                return nil, nil, nil, nil
            end
        end
    }

    function io.bytes(f,n)
        local sb = string.byte
        if f then
            return nextbyte[n or 1], f
        else
            return nil, nil
        end
    end

end
