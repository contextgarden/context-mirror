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

local trace_datasets   = false  trackers.register("job.datasets" ,  function(v) trace_datasets   = v end)
local trace_pagestates = false  trackers.register("job.pagestates", function(v) trace_pagestates = v end)

local report_dataset   = logs.reporter("dataset")
local report_pagestate = logs.reporter("pagestate")

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
        if trace_datasets then
            report_dataset("delayed: name %s, tag %s, index %s",name,tag,index)
        end
    elseif trace_datasets then
        report_dataset("immediate: name %s, tag %s",name,tag)
    end
    return name, tag, data
end

datasets.setdata = setdata

function datasets.extend(name,tag)
    local set = sets[name]
    local order = set.order + 1
    local realpage = texcount.realpageno
    set.order = order
    local t = tobesaved[name][tag]
    t.realpage = realpage
    t.order = order
    if trace_datasets then
        report_dataset("flushed: name %s, tag %s, page %s, index %s, order",name,tag,t.index or 0,order,realpage)
    end
end

function datasets.getdata(name,tag,key,default)
    local t = collected[name]
    if t then
        t = t[tag] or t[tonumber(tag)]
        if t then
            if key then
                return t[key] or default
            else
                return t
            end
        elseif trace_datasets then
            report_dataset("unknown: name %s, tag %s",name,tag)
        end
    elseif trace_datasets then
        report_dataset("unknown: name %s",name)
    end
    return default
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
    local realpage = texcount.realpageno
    local data = realpage
    list[tag] = data
    if trace_pagestates then
        report_pagestate("setting: name %s, tag %s, preset %s",name,tag,realpage)
    end
    return name, tag, data
end

pagestates.setstate = setstate

function pagestates.extend(name,tag)
    local realpage = texcount.realpageno
    if trace_pagestates then
        report_pagestate("synchronizing: name %s, tag %s, preset %s",name,tag,realpage)
    end
    tobesaved[name][tag] = realpage
end

function pagestates.realpage(name,tag,default)
    local t = collected[name]
    if t then
        t = t[tag] or t[tonumber(tag)]
        if t then
            return tonumber(t or default)
        elseif trace_pagestates then
            report_pagestate("unknown: name %s, tag %s",name,tag)
        end
    elseif trace_pagestates then
        report_pagestate("unknown: name %s",name)
    end
    return default
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

function commands.setpagestaterealpageno(name,tag)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    if t then
        texcount.realpagestateno = t
    else
        texcount.realpagestateno = texcount.realpageno
    end
end
