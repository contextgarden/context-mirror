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
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local definetable, accesstable = utilities.tables.definetable, utilities.tables.accesstable
local serialize = table.serialize

local report_jobcontrol = logs.new("jobcontrol")

if not jobs then jobs         = { } end
if not job  then jobs['main'] = { } end job = jobs['main']

local packers = utilities.packers

jobs.version = 1.14

--[[ldx--
<p>Variables are saved using in the previously defined table and passed
onto <l n='tex'/> using the following method. Of course one can also
directly access the variable using a <l n='lua'/> call.</p>
--ldx]]--

local savelist, comment = { }, { }

function job.comment(str)
    comment[#comment+1] = str
end

job.comment(format("version: %1.2f",jobs.version))

function job.initialize(loadname,savename)
    job.load(loadname) -- has to come after  structure is defined !
    luatex.registerstopactions(function()
        if not status.lasterrorstring or status.lasterrorstring == "" then
            job.save(savename)
        end
    end)
end

function job.register(...) -- collected, tobesaved, initializer, finalizer
    savelist[#savelist+1] = { ... }
end

-- as an example we implement variables

local jobvariables = {
    collected = { },
    tobesaved = { },
    checksums = { },
}

job.variables = jobvariables

if not jobvariables.checksums.old then jobvariables.checksums.old = md5.HEX("old") end -- used in experiment
if not jobvariables.checksums.new then jobvariables.checksums.new = md5.HEX("new") end -- used in experiment

job.register('job.variables.checksums', jobvariables.checksums)

local function initializer()
    local r = jobvariables.collected.randomseed
    if not r then
        r = math.random()
        math.setrandomseedi(r,"initialize")
        report_jobcontrol("initializing randomizer with %s",r)
    else
        math.setrandomseedi(r,"previous run")
        report_jobcontrol("resuming randomizer with %s",r)
    end
    jobvariables.tobesaved.randomseed = r
    for cs, value in next, jobvariables.collected do
        texsprint(ctxcatcodes,format("\\xdef\\%s{%s}",cs,value))
    end
end

job.register('job.variables.collected', jobvariables.tobesaved, initializer)

function jobvariables.save(cs,value)
    jobvariables.tobesaved[cs] = value
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

local _save_, _load_ = { }, { } -- registers timing

function job.save(filename)
    statistics.starttiming(_save_)
    local f = io.open(filename,'w')
    if f then
        for c=1,#comment do
            f:write("-- ",comment[c],"\n")
        end
        f:write("\n")
        for l=1,#savelist do
            local list = savelist[l]
            local target, data, finalizer = list[1], list[2], list[4]
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
            f:write(serialize(jobpacker,"job.packed",true,true),"\n")
        end
        f:close()
    end
    statistics.stoptiming(_save_)
end

function job.load(filename)
    statistics.starttiming(_load_)
    local data = io.loaddata(filename)
    if data and data ~= "" then
        local version = tonumber(match(data,"^-- version: ([%d%.]+)"))
        if version ~= jobs.version then
            report_jobcontrol("version mismatch with jobfile: %s <> %s", version or "?", jobs.version)
        else
            local data = loadstring(data)
            if data then
                data()
            end
            for l=1,#savelist do
                local list = savelist[l]
                local target, initializer = list[1], list[3]
                packers.unpack(accesstable(target),job.packed,true)
                if type(initializer) == "function" then
                    initializer(accesstable(target))
                end
            end
            job.packed = nil
        end
    end
    statistics.stoptiming(_load_)
end

-- eventually this will end up in strc-ini

statistics.register("startup time", function()
    return statistics.elapsedseconds(statistics,"including runtime option file processing")
end)

statistics.register("jobdata time",function()
    if statistics.elapsedindeed(_save_) or statistics.elapsedindeed(_load_) then
        return format("%s seconds saving, %s seconds loading", statistics.elapsedtime(_save_), statistics.elapsedtime(_load_))
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
