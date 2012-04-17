if not modules then modules = { } end modules ['core-dat'] = {
    version   = 1.001,
    comment   = "companion to core-dat.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module provides a (multipass) container for arbitrary data. It
replaces the twopass data mechanism.</p>
--ldx]]--

local tonumber = tonumber

local context, commands = context, commands

local allocate = utilities.storage.allocate
local settings_to_hash = utilities.parsers.settings_to_hash
local format = string.format
local texcount = tex.count

local v_yes = interfaces.variables.yes

local new_latelua = nodes.pool.latelua

local collected = allocate()
local tobesaved = allocate()

local datasets = {
    collected = collected,
    tobesaved = tobesaved,
}

job.datasets = datasets

local function initializer()
    collected = datasets.collected
    tobesaved = datasets.tobesaved
end

job.register('job.datasets.collected', tobesaved, initializer, nil)

local sets = { }

table.setmetatableindex(tobesaved, function(t,k)
    local v = { }
    t[k] = v
    return v
end)

table.setmetatableindex(sets, function(t,k)
    local v = {
        index = 0,
        order = 0,
    }
    t[k] = v
    return v
end)

local function setdata(settings)
    local name = settings.name
    local tag  = settings.tag
    local data = settings.data
    local list = tobesaved[name]
    data = settings_to_hash(data) or { }
    if not tag then
        tag = #list + 1
    else
        tag = tonumber(tag) or tag -- autonumber saves keys
    end
    list[tag] = data
    if settings.delay == v_yes then
        local set = sets[name]
        local index = set.index + 1
        set.index = index
        data.index = index
        data.order = index
        data.realpage = texcount.realpageno
    end
    return name, tag, data
end

datasets.setdata = setdata

function datasets.extend(name,tag)
    local set = sets[name]
    local order = set.order + 1
    set.order = order
    local t = tobesaved[name][tag]
    t.realpage = texcount.realpageno
    t.order = order
end

function datasets.getdata(name,tag,key,default)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    if not t then
        -- back luck
    elseif key then
        return t[key] or default
    else
        return t
    end
end

function commands.setdataset(settings)
    local name, tag, data = setdata(settings)
    if settings.delay ~= v_yes then
        --
    elseif type(tag) == "number" then
        context(new_latelua(format("job.datasets.extend(%q,%i)",name,tag)))
    else
        context(new_latelua(format("job.datasets.extend(%q,%q)",name,tag)))
    end
end

function commands.datasetvariable(name,tag,key)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    if t then
        local s = t[key]
        if s then
            context(s)
        end
    end
end

--[[ldx--
<p>We also provide an efficient variant for page states.</p>
--ldx]]--

local collected = allocate()
local tobesaved = allocate()

local pagestates = {
    collected = collected,
    tobesaved = tobesaved,
}

job.pagestates = pagestates

local function initializer()
    collected = pagestates.collected
    tobesaved = pagestates.tobesaved
end

job.register('job.pagestates.collected', tobesaved, initializer, nil)

table.setmetatableindex(tobesaved, function(t,k)
    local v = { }
    t[k] = v
    return v
end)

local function setstate(settings)
    local name = settings.name
    local tag  = settings.tag
    local list = tobesaved[name]
    if not tag then
        tag = #list + 1
    else
        tag = tonumber(tag) or tag -- autonumber saves keys
    end
    local data = texcount.realpageno
    list[tag] = data
    return name, tag, data
end

pagestates.setstate = setstate

function pagestates.extend(name,tag)
    tobesaved[name][tag] = texcount.realpageno
end

function pagestates.realpage(name,tag,default)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    return tonumber(t or default)
end

function commands.setpagestate(settings)
    local name, tag, data = setstate(settings)
    if type(tag) == "number" then
        context(new_latelua(format("job.pagestates.extend(%q,%i)",name,tag)))
    else
        context(new_latelua(format("job.pagestates.extend(%q,%q)",name,tag)))
    end
end

function commands.pagestaterealpage(name,tag)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    if t then
        context(t)
    end
end
