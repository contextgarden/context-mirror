if not modules then modules = { } end modules ['util-tab'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities        = utilities or {}
utilities.tables = utilities.tables or { }
local tables     = utilities.tables

local format, gmatch = string.format, string.gmatch
local concat, insert, remove = table.concat, table.insert, table.remove
local setmetatable, getmetatable, tonumber, tostring = setmetatable, getmetatable, tonumber, tostring

function tables.definetable(target) -- defines undefined tables
    local composed, t, n = nil, { }, 0
    for name in gmatch(target,"([^%.]+)") do
        n = n + 1
        if composed then
            composed = composed .. "." .. name
        else
            composed = name
        end
        t[n] = format("%s = %s or { }",composed,composed)
    end
    return concat(t,"\n")
end

function tables.accesstable(target)
    local t = _G
    for name in gmatch(target,"([^%.]+)") do
        t = t[name]
    end
    return t
end

function tables.removevalue(t,value) -- todo: n
    if value then
        for i=1,#t do
            if t[i] == value then
                remove(t,i)
                -- remove all, so no: return
            end
        end
    end
end

function tables.insertbeforevalue(t,value,extra)
    for i=1,#t do
        if t[i] == extra then
            remove(t,i)
        end
    end
    for i=1,#t do
        if t[i] == value then
            insert(t,i,extra)
            return
        end
    end
    insert(t,1,extra)
end

function tables.insertaftervalue(t,value,extra)
    for i=1,#t do
        if t[i] == extra then
            remove(t,i)
        end
    end
    for i=1,#t do
        if t[i] == value then
            insert(t,i+1,extra)
            return
        end
    end
    insert(t,#t+1,extra)
end

-- experimental

local function toxml(t,d,result)
    for k, v in table.sortedpairs(t) do
        if type(v) == "table" then
            result[#result+1] = format("%s<%s>",d,k)
            toxml(v,d.." ",result)
            result[#result+1] = format("%s</%s>",d,k)
        elseif tonumber(k) then
            result[#result+1] = format("%s<entry n='%s'>%s</entry>",d,k,v,k)
        else
            result[#result+1] = format("%s<%s>%s</%s>",d,k,tostring(v),k)
        end
    end
end

function table.toxml(t,name,nobanner)
    local noroot = name == false
    local result = (nobanner or noroot) and { } or { "<?xml version='1.0' standalone='yes' ?>" }
    if noroot then
        toxml( t, "", result)
    else
        toxml( { [name or "root"] = t }, "", result)
    end
    return concat(result,"\n")
end
