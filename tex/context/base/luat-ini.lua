if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ local ctxcatcodes = tex.ctxcatcodes

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a fewtables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata      = userdata      or { } -- might be used
thirddata     = thirddata     or { } -- might be used
moduledata    = moduledata    or { } -- might be used
document      = document      or { }
parametersets = parametersets or { } -- experimental

--[[ldx--
<p>These can be used/set by the caller program; <t>mtx-context.lua</t> does it.</p>
--ldx]]--

document.arguments = document.arguments or { }
document.files     = document.files     or { }

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

local string, table, lpeg, math, io, system = string, table, lpeg, math, io, system
local next, setfenv = next, setfenv or debug.setfenv
local format = string.format

local global = _G

global.global = global

local dummy = function() end

local protected = {
    -- global table
    global     = global,
    -- user tables
    userdata   = userdata,
    moduledata = moduledata,
    thirddata  = thirddata,
    document   = document,
    -- reserved
    protect    = dummy,
    unprotect  = dummy,
    -- luatex
    tex        = tex,
    -- lua
    string     = string,
    table      = table,
    lpeg       = lpeg,
    math       = math,
    io         = io,
    system     = system,
}

userdata, thirddata, moduledata = nil, nil, nil

if not setfenv then
    texio.write_nl("warning: we need to fix setfenv")
end

function protect(name)
    if name == "isolateddata" then
        local t = { }
        for k, v in next, protected do
            t[k] = v
        end
        setfenv(2,t)
    else
        if not name then
            name = "shareddata"
        end
        local t = global[name]
        if not t then
            t = { }
            for k, v in next, protected do
                t[k] = v
            end
            global[name] = t
        end
        setfenv(2,t)
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
    tex.write(lnn)
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
    tex.sprint(tex.ctxcatcodes,v or default or "")
end

function document.setfilename(i,name)
    document.files[tonumber(i)] = name
end

function document.getfilename(i)
    tex.sprint(tex.ctxcatcodes,document.files[i] or "")
end
