if not modules then modules = { } end modules ['lxml-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local finalizers   = xml.finalizers.xml
local xmlfilter    = xml.filter -- we could inline this one for speed
local xmltostring  = xml.tostring
local xmlserialize = xml.serialize
local xmlcollected = xml.collected

local function first(collected) -- wrong ?
    return collected and collected[1]
end

local function last(collected)
    return collected and collected[#collected]
end

local function all(collected)
    return collected
end

local function reverse(collected)
    if collected then
        local reversed = { }
        for c=#collected,1,-1 do
            reversed[#reversed+1] = collected[c]
        end
        return reversed
    end
end

local function attribute(collected,name)
    if collected and #collected > 0 then
        local at = collected[1].at
        return at and at[name]
    end
end

local function att(id,name)
    local at = id.at
    return at and at[name]
end

local function count(collected)
    return (collected and #collected) or 0
end

local function position(collected,n)
    if collected then
        n = tonumber(n) or 0
        if n < 0 then
            return collected[#collected + n + 1]
        elseif n > 0 then
            return collected[n]
        else
            return collected[1].mi or 0
        end
    end
end

local function match(collected)
    return (collected and collected[1].mi) or 0 -- match
end

local function index(collected)
    if collected then
        return collected[1].ni
    end
end

local function attributes(collected,arguments)
    if collected then
        local at = collected[1].at
        if arguments then
            return at[arguments]
        elseif next(at) then
            return at -- all of them
        end
    end
end

local function chainattribute(collected,arguments) -- todo: optional levels
    if collected then
        local e = collected[1]
        while e do
            local at = e.at
            if at then
                local a = at[arguments]
                if a then
                    return a
                end
            else
                break -- error
            end
            e = e.__p__
        end
    end
    return ""
end

local function raw(collected) -- hybrid
    if collected then
        local e = collected[1] or collected
        return (e and xmlserialize(e)) or "" -- only first as we cannot concat function
    else
        return ""
    end
end

local function text(collected) -- hybrid
    if collected then
        local e = collected[1] or collected
        return (e and xmltostring(e.dt)) or ""
    else
        return ""
    end
end

local function texts(collected)
    if collected then
        local t = { }
        for c=1,#collected do
            local e = collection[c]
            if e and e.dt then
                t[#t+1] = e.dt
            end
        end
        return t
    end
end

local function tag(collected,n)
    if collected then
        local c
        if n == 0 or not n then
            c = collected[1]
        elseif n > 1 then
            c = collected[n]
        else
            c = collected[#collected-n+1]
        end
        return c and c.tg
    end
end

local function name(collected,n)
    if collected then
        local c
        if n == 0 or not n then
            c = collected[1]
        elseif n > 1 then
            c = collected[n]
        else
            c = collected[#collected-n+1]
        end
        if c then
            if c.ns == "" then
                return c.tg
            else
                return c.ns .. ":" .. c.tg
            end
        end
    end
end

local function tags(collected,nonamespace)
    if collected then
        local t = { }
        for c=1,#collected do
            local e = collected[c]
            local ns, tg = e.ns, e.tg
            if nonamespace or ns == "" then
                t[#t+1] = tg
            else
                t[#t+1] = ns .. ":" .. tg
            end
        end
        return t
    end
end

local function empty(collected)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            if e then
                local edt = e.dt
                if edt then
                    local n = #edt
                    if n == 1 then
                        local edk = edt[1]
                        local typ = type(edk)
                        if typ == "table" then
                            return false
                        elseif edk ~= "" then -- maybe an extra tester for spacing only
                            return false
                        end
                    elseif n > 1 then
                        return false
                    end
                end
            end
        end
    end
    return true
end

finalizers.first          = first
finalizers.last           = last
finalizers.all            = all
finalizers.reverse        = reverse
finalizers.elements       = all
finalizers.default        = all
finalizers.attribute      = attribute
finalizers.att            = att
finalizers.count          = count
finalizers.position       = position
finalizers.match          = match
finalizers.index          = index
finalizers.attributes     = attributes
finalizers.chainattribute = chainattribute
finalizers.text           = text
finalizers.texts          = texts
finalizers.tag            = tag
finalizers.name           = name
finalizers.tags           = tags
finalizers.empty          = empty

-- shortcuts -- we could support xmlfilter(id,pattern,first)

function xml.first(id,pattern)
    return first(xmlfilter(id,pattern))
end

function xml.last(id,pattern)
    return last(xmlfilter(id,pattern))
end

function xml.count(id,pattern)
    return count(xmlfilter(id,pattern))
end

function xml.attribute(id,pattern,a,default)
    return attribute(xmlfilter(id,pattern),a,default)
end

function xml.raw(id,pattern)
    if pattern then
        return raw(xmlfilter(id,pattern))
    else
        return raw(id)
    end
end

function xml.text(id,pattern)
    if pattern then
     -- return text(xmlfilter(id,pattern))
        local collected = xmlfilter(id,pattern)
        return (collected and xmltostring(collected[1].dt)) or ""
    elseif id then
     -- return text(id)
        return xmltostring(id.dt) or ""
    else
        return ""
    end
end

xml.content = text

function xml.position(id,pattern,n) -- element
    return position(xmlfilter(id,pattern),n)
end

function xml.match(id,pattern) -- number
    return match(xmlfilter(id,pattern))
end

function xml.empty(id,pattern)
    return empty(xmlfilter(id,pattern))
end

xml.all    = xml.filter
xml.index  = xml.position
xml.found  = xml.filter

-- a nice one:

local function totable(x)
    local t = { }
    for e in xmlcollected(x[1] or x,"/*") do
        t[e.tg] = xmltostring(e.dt) or ""
    end
    return next(t) and t or nil
end

xml.table        = totable
finalizers.table = totable
