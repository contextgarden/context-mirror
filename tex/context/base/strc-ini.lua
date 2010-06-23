if not modules then modules = { } end modules ['strc-ini'] = {
    version   = 1.001,
    comment   = "companion to strc-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[
The restructuring is the (intermediate) result of quite some experiments. I started
with the basic structure, followed by lists, numbers, enumerations, itemgroups
and floats. All these have something in common, like pagenumbers and section
prefixes. I played with some generic datastructure (in order to save space) but
the code at both the lua and tex end then quickly becomes messy due to the fact
that access to variables is too different. So, eventually I ended up with
dedicated structures combined with sharing data. In lua this is quite efficient
because tables are referenced. However, some precautions are to be taken in
order to keep the utility file small. Utility data and process data share much
but it does not make sense to store all processdata.

]]--

local format, concat, match = string.format, table.concat, string.match
local count, texwrite, texprint, texsprint = tex.count, tex.write, tex.print, tex.sprint
local type, next, tonumber, tostring = type, next, tonumber, tostring
local lpegmatch = lpeg.match

local ctxcatcodes, xmlcatcodes, notcatcodes = tex.ctxcatcodes, tex.xmlcatcodes, tex.notcatcodes -- tricky as we're in notcatcodes

local trace_processors = false  trackers.register("structure.processors", function(v) trace_processors = v end)

local report_processors = logs.new("processors")

-- move this

commands = commands or { }

function commands.first_in_list(str)
    local first = match(str,"^([^,]+),")
    texsprint(ctxcatcodes,first or str)
end

-- -- -- namespace -- -- --

structure = structure or { }

-- -- -- cache -- -- --

structure.shares       = structure.shares       or { }
structure.shares.cache = structure.shares.cache or { }

local shares = structure.shares
local cache  = shares.cache

function shares.put(data)
    cache[#cache+1] = data
    return #cache
end

function shares.get(n) -- n can be string
    n = tonumber(n) or -1
    return cache[n]
end

-- -- -- specials -- -- --

-- we can store information and get back a reference; this permits
-- us to store rather raw data in references

local specials = { } structure.specials = specials

specials.collected = specials.collected or { }
specials.tobesaved = specials.collected or { }

local collected, tobesaved = specials.collected, specials.tobesaved

local function initializer()
    collected, tobesaved = specials.collected, specials.tobesaved
end

if job then
    job.register('structure.specials.collected', structure.specials.tobesaved, initializer)
end

function specials.store(class,data)
    if class and data then
        local s = tobesaved[class]
        if not s then
            s = { }
            tobesaved[class] = s
        end
        s[#s+1] = data
        texwrite(#s)
    else
        texwrite(0)
    end
end

function specials.retrieve(class,n)
    if class and n then
        local c = collected[class]
        return c and c[n]
    end
end

-- -- -- helpers -- -- --

structure.helpers = structure.helpers or { }

local helpers = structure.helpers

function helpers.touserdata(str)
    local hash = str and str ~= "" and aux.settings_to_hash(str)
    if hash and next(hash) then
        return hash
    end
end

local function simplify(d,nodefault)
    if d then
        local t = { }
        for k, v in next, d do
            local tv = type(v)
            if tv == "table" then
                if next(v) then t[k] = simplify(v) end
            elseif tv == "string" then
                if v ~= "" and v ~= "default" then t[k] = v end
            elseif tv == "boolean" then
                if v then t[k] = v end
            else
                t[k] = v
            end
        end
--~ print(table.serialize(d,"before"))
--~ print(table.serialize(t,"after"))
        return next(t) and t
    elseif nodefault then
        return nil
    else
        return { }
    end
end

helpers.simplify = simplify

function helpers.merged(...)
    local h, t = { ... }, { }
    for k=1, #h do
        local v = h[k]
        if v and v ~= "" and not t[k] then
            t[k] = v
        end
    end
    return t
end

local tags = {
    generic = "ctx:genericentry",
    section = "ctx:sectionentry",
    entry   = "ctx:registerentry",
}

function helpers.title(title,metadata) -- brrr
    if title and title ~= "" then
        if metadata then
            if metadata.coding == "xml" then
                tag = tags[metadata.kind] or tags.generic
                buffers.set(tag,format("<?xml version='1.0'?><%s>%s</%s>",tag,title,tag))
                texsprint(ctxcatcodes,format("\\xmlprocessbuffer{%s}{%s}{}",metadata.xmlroot or "main",tag))
            elseif metadata.xmlsetup then
                texsprint(ctxcatcodes,format("\\xmlsetup{%s}{%s}",title,metadata.xmlsetup)) -- nasty
            else
                local catcodes = metadata.catcodes
--~ print(tex.ctxcatcodes,tex.xmlcatcodes,catcodes,title)
                if catcodes == notcatcodes or catcodes == xmlcatcodes then
                    texsprint(ctxcatcodes,title) -- nasty
                else
                    texsprint(catcodes,title)
                end
            end
        else
            texsprint(title) -- no catcode switch
        end
    end
end

-- -- -- processors -- -- -- syntax: processor->data

local processors = { }  structure.processors = processors

local registered = { }

function processors.register(p)
    registered[p] = true
end

function processors.reset(p)
    registered[p] = nil
end

local splitter = lpeg.splitat("->",true)

function processors.split(str)
    local p, s = lpegmatch(splitter,str)
    if registered[p] then
        return p, s
    else
        return false, str
    end
end

function processors.sprint(catcodes,str,fnc,...)
    local p, s = lpegmatch(splitter,str)
    local code
    if registered[p] then
        code = format("\\applyprocessor{%s}{%s}",p,(fnc and fnc(s,...)) or s)
    else
        code = (fnc and fnc(str,...)) or str
    end
    if trace_processors then
        report_processors("cct: %s, seq: %s",catcodes,code)
    end
    texsprint(catcodes,code)
end

function processors.apply(str)
    local p, s = lpegmatch(splitter,str)
    if registered[p] then
        return format("\\applyprocessor{%s}{%s}",p,s)
    else
        return str
    end
end

-- -- -- sets -- -- --

structure.sets         = structure.sets         or { }
structure.sets.setlist = structure.sets.setlist or { }

storage.register("structure/sets/setlist", structure.sets.setlist, "structure.sets.setlist")

local sets = structure.sets
local setlist = sets.setlist

function sets.define(namespace,name,values,default,numbers)
    local dn = setlist[namespace]
    if not dn then
        dn = { }
        setlist[namespace] = dn
    end
    if values == "" then
        dn[name] = { { }, default }
    else
        local split = aux.settings_to_array(values)
        if numbers then
            -- convert to numbers (e.g. for reset)
            for i=1,#split do
                split[i] = tonumber(split[i]) or 0
            end
        end
        dn[name] = { split, default }
    end
end

function sets.getall(namespace,block,name)
    local ds = setlist[namespace]
    if not ds then
        return { }
    else
        local dn
        if block and block ~= "" then
            dn = ds[block..":"..name] or ds[name] or ds[block] or ds.default
        else
            dn = ds[name] or ds.default
        end
        return (dn and dn[1]) or { }
    end
end

function sets.get(namespace,block,name,level,default) -- check if name is passed
    local ds = setlist[namespace]
    if not ds then
        return default
    end
    local dn
    if name and name ~= "" then
        if block and block ~= "" then
            dn = ds[block..":"..name] or ds[name] or ds[block] or ds.default
        else
            dn = ds[name] or ds.default
        end
    else
        if block and block ~= "" then
            dn = ds[block] or ds[block..":default"] or ds.default
        else
            dn = ds.default
        end
    end
    if not dn then
        return default
    end
    local dl = dn[1][level]
    return dl or dn[2] or default
end
