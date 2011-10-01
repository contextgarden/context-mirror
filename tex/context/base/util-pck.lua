if not modules then modules = { } end modules ['util-pck'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from core-uti

local next, tostring, type = next, tostring, type
local sort, concat = table.sort, table.concat

utilities         = utilities         or { }
utilities.packers = utilities.packers or { }
local packers     = utilities.packers
packers.version   = 1.00

local function hashed(t)
    local s, ns = { }, 0
    for k, v in next, t do
        ns = ns + 1
        if type(v) == "table" then
            s[ns] = k .. "={" .. hashed(v) .. "}"
        else
            s[ns] = k .. "=" .. tostring(v)
        end
    end
    sort(s)
    return concat(s,",")
end

local function simplehashed(t)
    local s, ns = { }, 0
    for k, v in next, t do
        ns = ns + 1
        s[ns] = k .. "=" .. v
    end
    sort(s)
    return concat(s,",")
end

packers.hashed       = hashed
packers.simplehashed = simplehashed

--~ local function pack(t,keys,hash,index)
--~     for k,v in next, t do
--~         if type(v) == "table" then
--~             pack(v,keys,hash,index)
--~         end
--~         if keys[k] and type(v) == "table" then
--~             local h = hashed(v)
--~             local i = hash[h]
--~             if not i then
--~                 i = #index + 1
--~                 index[i] = v
--~                 hash[h] = i
--~             end
--~             t[k] = i
--~         end
--~     end
--~ end

local function pack(t,keys,hash,index)
    if t then
        for k,v in next, t do
            if type(v) == "table" then
                pack(v,keys,hash,index)
                if keys[k] then
                    local h = hashed(v)
                    local i = hash[h]
                    if not i then
                        i = #index + 1
                        index[i] = v
                        hash[h] = i
                    end
                    t[k] = i
                end
            end
        end
    end
end

local function unpack(t,keys,index)
    if t then
        for k, v in next, t do
            if keys[k] and type(v) == "number" then
                local iv = index[v]
                if iv then
                    v = iv
                    t[k] = v
                end
            end
            if type(v) == "table" then
                unpack(v,keys,index)
            end
        end
    end
end

function packers.new(keys,version)
    return {
        version = version or packers.version,
        keys    = table.tohash(keys),
        hash    = { },
        index   = { },
    }
end

function packers.pack(t,p,shared)
    if shared then
        pack(t,p.keys,p.hash,p.index)
    elseif not t.packer then
        pack(t,p.keys,p.hash,p.index)
        if #p.index > 0 then
            t.packer = {
                version = p.version or packers.version,
                keys = p.keys,
                index = p.index,
            }
        end
        p.hash, p.index = { }, { }
    end
end

function packers.unpack(t,p,shared)
    if shared then
        if p then
            unpack(t,p.keys,p.index)
        end
    else
        local tp = t.packer
        if tp then
            if tp.version == (p and p.version or packers.version) then
                unpack(t,tp.keys,tp.index)
            else
                -- fatal error, wrong version
            end
            t.packer = nil
        end
    end
end

function packers.strip(p)
    p.hash = nil
end
