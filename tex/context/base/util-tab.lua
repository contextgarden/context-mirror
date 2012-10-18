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

local format, gmatch, rep = string.format, string.gmatch, string.rep
local concat, insert, remove = table.concat, table.insert, table.remove
local setmetatable, getmetatable, tonumber, tostring = setmetatable, getmetatable, tonumber, tostring
local type, next, rawset, tonumber = type, next, rawset, tonumber

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

function tables.accesstable(target,root)
    local t = root or _G
    for name in gmatch(target,"([^%.]+)") do
        t = t[name]
        if not t then
            return
        end
    end
    return t
end

function tables.migratetable(target,v,root)
    local t = root or _G
    local names = string.split(target,".")
    for i=1,#names-1 do
        local name = names[i]
        t[name] = t[name] or { }
        t = t[name]
        if not t then
            return
        end
    end
    t[names[#names]] = v
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

local function toxml(t,d,result,step)
    for k, v in table.sortedpairs(t) do
        if type(v) == "table" then
            if type(k) == "number" then
                result[#result+1] = format("%s<entry n='%s'>",d,k)
                toxml(v,d..step,result,step)
                result[#result+1] = format("%s</entry>",d,k)
            else
                result[#result+1] = format("%s<%s>",d,k)
                toxml(v,d..step,result,step)
                result[#result+1] = format("%s</%s>",d,k)
            end
        elseif type(k) == "number" then
            result[#result+1] = format("%s<entry n='%s'>%s</entry>",d,k,v,k)
        else
            result[#result+1] = format("%s<%s>%s</%s>",d,k,tostring(v),k)
        end
    end
end

function table.toxml(t,name,nobanner,indent,spaces)
    local noroot = name == false
    local result = (nobanner or noroot) and { } or { "<?xml version='1.0' standalone='yes' ?>" }
    local indent = rep(" ",indent or 0)
    local spaces = rep(" ",spaces or 1)
    if noroot then
        toxml( t, inndent, result, spaces)
    else
        toxml( { [name or "root"] = t }, indent, result, spaces)
    end
    return concat(result,"\n")
end

-- also experimental

-- encapsulate(table,utilities.tables)
-- encapsulate(table,utilities.tables,true)
-- encapsulate(table,true)

function tables.encapsulate(core,capsule,protect)
    if type(capsule) ~= "table" then
        protect = true
        capsule = { }
    end
    for key, value in next, core do
        if capsule[key] then
            print(format("\ninvalid inheritance '%s' in '%s': %s",key,tostring(core)))
            os.exit()
        else
            capsule[key] = value
        end
    end
    if protect then
        for key, value in next, core do
            core[key] = nil
        end
        setmetatable(core, {
            __index = capsule,
            __newindex = function(t,key,value)
                if capsule[key] then
                    print(format("\ninvalid overload '%s' in '%s'",key,tostring(core)))
                    os.exit()
                else
                    rawset(t,key,value)
                end
            end
        } )
    end
end
