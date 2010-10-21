if not modules then modules = { } end modules ['util-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable, getmetatable = setmetatable, getmetatable

utilities         = utilities or { }
utilities.storage = utilities.storage or { }
local storage     = utilities.storage

function storage.mark(t)
    if not t then
        texio.write_nl("fatal error: storage '%s' cannot be marked",t)
        os.exit()
    end
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.allocate(t)
    t = t or { }
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.marked(t)
    local m = getmetatable(t)
    return m and m.__storage__
end

function storage.checked(t)
    if not t then
        texio.write_nl("fatal error: storage '%s' has not been allocated",t)
        os.exit()
    end
    return t
end

function setmetatablekey(t,key,value)
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m[key] = value
end

function getmetatablekey(t,key,value)
    local m = getmetatable(t)
    return m and m[key]
end

--~ function utilities.storage.delay(parent,name,filename)
--~     local m = getmetatable(parent)
--~     m.__list[name] = filename
--~ end
--~
--~ function utilities.storage.predefine(parent)
--~     local list = { }
--~     local m = getmetatable(parent) or {
--~         __list = list,
--~         __index = function(t,k)
--~             local l = require(list[k])
--~             t[k] = l
--~             return l
--~         end
--~     }
--~     setmetatable(parent,m)
--~ end
--~
--~ bla = { }
--~ utilities.storage.predefine(bla)
--~ utilities.storage.delay(bla,"test","oepsoeps")
--~ local t = bla.test
--~ table.print(t)
--~ print(t.a)

function storage.setinitializer(data,initialize)
    local m = getmetatable(data) or { }
    m.__index = function(data,k)
        m.__index = nil -- so that we can access the entries during initializing
        initialize()
        return data[k]
    end
    setmetatable(data, m)
end
