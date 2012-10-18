if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- rather experimental down here ... will change with lua 5.2 --

local debug = require "debug"
local string, table, lpeg, math, io, system = string, table, lpeg, math, io, system
local next, setfenv = next, setfenv or debug.setfenv

local mark = utilities.storage.mark

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a fewtables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata      = userdata      or { } -- for users (e.g. functions etc)
thirddata     = thirddata     or { } -- only for third party modules
moduledata    = moduledata    or { } -- only for development team
documentdata  = documentdata  or { } -- for users (e.g. raw data)
parametersets = parametersets or { } -- experimental for team

document      = document      or { } -- only for context itself

--[[ldx--
<p>These can be used/set by the caller program; <t>mtx-context.lua</t> does it.</p>
--ldx]]--

document.arguments = mark(document.arguments or { })
document.files     = mark(document.files     or { })

--[[ldx--
<p>Please create a namespace within these tables before using them!</p>

<typing>
userdata ['my.name'] = { }
thirddata['tricks' ] = { }
</typing>
--ldx]]--

--[[ldx--
<p>We could cook up a readonly model for global tables but it
makes more sense to invite users to use one of the predefined
namespaces. One can redefine the protector. After all, it's
just a lightweight suggestive system, not a watertight
one.</p>
--ldx]]--

-- this will change when we move on to lua 5.2+

local global = _G

global.global = global
--~ rawset(global,"global",global)

local dummy = function() end

-- another approach is to freeze tables by using a metatable, this will be
-- implemented stepwise

local protected = {
    -- global table
    global       = global,
    -- user tables
 -- moduledata   = moduledata,
    userdata     = userdata,
    thirddata    = thirddata,
    documentdata = documentdata,
    -- reserved
    protect      = dummy,
    unprotect    = dummy,
    -- luatex
    tex          = tex,
    -- lua
    string       = string,
    table        = table,
    lpeg         = lpeg,
    math         = math,
    io           = io,
    --
    -- maybe other l-*, xml etc
}

-- moduledata  : no need for protection (only for developers)
-- isolatedata : full protection
-- userdata    : protected
-- thirddata   : protected

userdata, thirddata = nil, nil

-- we could have a metatable that automaticaly creates a top level namespace

if not setfenv then
    texio.write_nl("warning: we need to fix setfenv by using 'load in' or '_ENV'")
end

local function protect_full(name)
    local t = { }
    for k, v in next, protected do
        t[k] = v
    end
    return t
end

local function protect_part(name)
--~     local t = global[name]
    local t = rawget(global,name)
    if not t then
        t = { }
        for k, v in next, protected do
            t[k] = v
        end
--~         global[name] = t
        rawset(global,name,t)
    end
    return t
end

function protect(name)
    if name == "isolateddata" then
        setfenv(2,protect_full(name))
    else
        setfenv(2,protect_part(name or "shareddata"))
    end
end

lua.numbers  = { }
lua.messages = { }

function lua.registername(name,message)
    local lnn = lua.numbers[name]
    if not lnn then
        lnn = #lua.messages + 1
        lua.messages[lnn] = message
        lua.numbers[name] = lnn
    end
    lua.name[lnn] = message
    context(lnn)
    -- initialize once
    if name ~= "isolateddata" then
        protect_full(name or "shareddata")
    end
end

--~ function lua.checknames()
--~     lua.name[0] = "ctx"
--~     for k, v in next, lua.messages do
--~         lua.name[k] = v
--~     end
--~ end

storage.register("lua/numbers", lua.numbers, "lua.numbers")
storage.register("lua/messages", lua.messages, "lua.messages")

--~ local arguments, files = document.arguments, document.files -- set later

function document.setargument(key,value)
    document.arguments[key] = value
end

function document.setdefaultargument(key,default)
    local v = document.arguments[key]
    if v == nil or v == "" then
        document.arguments[key] = default
    end
end

function document.getargument(key,default)
    local v = document.arguments[key]
    if type(v) == "boolean" then
        v = (v and "yes") or "no"
        document.arguments[key] = v
    end
    context(v or default or "")
end

function document.setfilename(i,name)
    document.files[tonumber(i)] = name
end

function document.getfilename(i)
    context(document.files[i] or "")
end
