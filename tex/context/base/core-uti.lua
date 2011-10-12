if not modules then modules = { } end modules ['core-uti'] = {
    version   = 1.001,
    comment   = "companion to core-uti.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: keep track of changes here (hm, track access, and only true when
-- accessed and changed)

--[[ldx--
<p>A utility file has always been part of <l n='context'/> and with
the move to <l n='luatex'/> we also moved a lot of multi-pass info
to a <l n='lua'/> table. Instead of loading a <l n='tex'/> based
utility file under different setups, we now load a table once. This
saves much runtime but at the cost of more memory usage.</p>
--ldx]]--

local format, match = string.format, string.match
local next, type, tostring = next, type, tostring
local concat = table.concat

local definetable       = utilities.tables.definetable
local accesstable       = utilities.tables.accesstable
local migratetable      = utilities.tables.migratetable
local serialize         = table.serialize
local packers           = utilities.packers
local allocate          = utilities.storage.allocate
local mark              = utilities.storage.mark

local report_jobcontrol = logs.reporter("jobcontrol")

job                     = job or { }
local job               = job

job.version             = 1.17

-- some day we will implement loading of other jobs and then we need
-- job.jobs

--[[ldx--
<p>Variables are saved using in the previously defined table and passed
onto <l n='tex'/> using the following method. Of course one can also
directly access the variable using a <l n='lua'/> call.</p>
--ldx]]--

local savelist, comment = { }, { }

function job.comment(str)
    comment[#comment+1] = str
end

job.comment(format("version: %1.2f",job.version))

function job.initialize(loadname,savename)
    job.load(loadname) -- has to come after  structure is defined !
    luatex.registerstopactions(function()
        if not status.lasterrorstring or status.lasterrorstring == "" then
            job.save(savename)
        end
    end)
end

function job.register(collected, tobesaved, initializer, finalizer)
    savelist[#savelist+1] = { collected, tobesaved, initializer, finalizer }
end

-- as an example we implement variables

local tobesaved, collected, checksums = allocate(), allocate(), allocate()

local jobvariables = {
    collected = collected,
    tobesaved = tobesaved,
    checksums = checksums,
}

job.variables = jobvariables

if not checksums.old then checksums.old = md5.HEX("old") end -- used in experiment
if not checksums.new then checksums.new = md5.HEX("new") end -- used in experiment

job.register('job.variables.checksums', checksums)

local rmethod, rvalue

local function initializer()
    tobesaved = jobvariables.tobesaved
    collected = jobvariables.collected
    checksums = jobvariables.checksums
    rvalue = collected.randomseed
    if not rvalue then
        rvalue = math.random()
        math.setrandomseedi(rvalue,"initialize")
        rmethod = "initialized"
    else
        math.setrandomseedi(rvalue,"previous run")
        rmethod = "resumed"
    end
    tobesaved.randomseed = rvalue
    for cs, value in next, collected do
        context.setxvalue(cs,value)
    end
end

job.register('job.variables.collected', tobesaved, initializer)

function jobvariables.save(cs,value)
    tobesaved[cs] = value
end

local packlist = {
    "numbers",
    "metadata",
    "sectiondata",
    "prefixdata",
    "numberdata",
    "pagedata",
    "directives",
    "specification",
    "processors", -- might become key under directives or metadata
--  "references", -- we need to rename of them as only one packs (not structures.lists.references)
}

local jobpacker = packers.new(packlist,1.01)

job.pack = true

local _save_, _load_, _others_ = { }, { }, { } -- registers timing

function job.save(filename) -- we could return a table but it can get pretty large
    statistics.starttiming(_save_)
    local f = io.open(filename,'w')
    if f then
        for c=1,#comment do
            f:write("-- ",comment[c],"\n")
        end
        f:write("\n")
        f:write("local utilitydata = { }\n")
        f:write("\n")
        for l=1,#savelist do
            local list      = savelist[l]
            local target    = format("utilitydata.%s",list[1])
            local data      = list[2]
            local finalizer = list[4]
            if type(finalizer) == "function" then
                finalizer()
            end
            if job.pack then
                packers.pack(data,jobpacker,true)
            end
            f:write(definetable(target),"\n")
            f:write(serialize(data,target,true,true),"\n")
        end
        if job.pack then
            packers.strip(jobpacker)
            f:write(serialize(jobpacker,"utilitydata.job.packed",true,true),"\n")
        end
        f:write("\n")
        f:write("return utilitydata\n")
        f:write("\n")
        f:close()
    end
    statistics.stoptiming(_save_)
end

local function load(filename)
    local data = io.loaddata(filename)
    if data and data ~= "" then
        local version = tonumber(match(data,"^-- version: ([%d%.]+)"))
        if version ~= job.version then
            report_jobcontrol("version mismatch with jobfile: %s <> %s", version or "?", job.version)
        else
            local data = loadstring(data)
            return data and data()
        end
    end
end

function job.load(filename)
    statistics.starttiming(_load_)
    local utilitydata = load(filename)
    if utilitydata then
        local jobpacker = utilitydata.job.packed
        for l=1,#savelist do
            local list        = savelist[l]
            local target      = list[1]
            local initializer = list[3]
            local result      = accesstable(target,utilitydata)
            packers.unpack(result,jobpacker,true)
            migratetable(target,mark(result))
            if type(initializer) == "function" then
                initializer(result)
            end
        end
    end
    statistics.stoptiming(_load_)
end

function job.loadother(filename)
    statistics.starttiming(_load_)
    _others_[#_others_+1] = file.nameonly(filename)
    local utilitydata = load(filename)
    if utilitydata then
        local jobpacker = utilitydata.job.packed
        local unpacked = { }
        for l=1,#savelist do
            local list   = savelist[l]
            local target = list[1]
            local result = accesstable(target,utilitydata)
            packers.unpack(result,jobpacker,true)
            migratetable(target,result,unpacked)
        end
        unpacked.job.packed = nil -- nicer in inspecting
        return unpacked
    end
    statistics.stoptiming(_load_)
end

-- eventually this will end up in strc-ini

statistics.register("startup time", function()
    return statistics.elapsedseconds(statistics,"including runtime option file processing")
end)

statistics.register("jobdata time",function()
    if statistics.elapsedindeed(_save_) or statistics.elapsedindeed(_load_) or #_others_ > 0 then
        if #_others_ > 0 then
            return format("%s seconds saving, %s seconds loading, other files: %s", statistics.elapsedtime(_save_), statistics.elapsedtime(_load_),concat(_others_," "))
        else
            return format("%s seconds saving, %s seconds loading", statistics.elapsedtime(_save_), statistics.elapsedtime(_load_))
        end
    end
end)

statistics.register("callbacks", function()
    local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
    local pages = tex.count['realpageno'] - 1
    if pages > 1 then
        return format("direct: %s, indirect: %s, total: %s (%i per page)", total-indirect, indirect, total, total/pages)
    else
        return format("direct: %s, indirect: %s, total: %s", total-indirect, indirect, total)
    end
end)

statistics.register("randomizer", function()
    if rmethod and rvalue then
        return format("%s with value %s",rmethod,rvalue)
    end
end)

function statistics.formatruntime(runtime)
    local shipped = tex.count['nofshipouts']
    local pages = tex.count['realpageno'] - 1
    if shipped > 0 or pages > 0 then
        local persecond = shipped / runtime
        if pages == 0 then pages = shipped end
        return format("%s seconds, %i processed pages, %i shipped pages, %.3f pages/second",runtime,pages,shipped,persecond)
    else
        return format("%s seconds",runtime)
    end
end
