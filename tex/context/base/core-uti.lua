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

local sort, concat, format, match = table.sort, table.concat, string.format, string.match
local next, type, tostring = next, type, tostring
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

if not jobs then jobs         = { } end
if not job  then jobs['main'] = { } end job = jobs['main']

jobs.version = 1.10

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
    job.load(loadname)
    main.register_stop_actions(function()
        if not status.lasterrorstring or status.lasterrorstring == "" then
            job.save(savename)
        end
    end)
end

function job.register(...) -- collected, tobesaved, initializer, finalizer
    savelist[#savelist+1] = { ... }
end

-- as an example we implement variables

jobvariables           = jobvariables or { }
jobvariables.collected = jobvariables.collected or { }
jobvariables.tobesaved = jobvariables.tobesaved or { }
jobvariables.checksums = jobvariables.checksums or { }

if not jobvariables.checksums.old then jobvariables.checksums.old = md5.HEX("old") end -- used in experiment
if not jobvariables.checksums.new then jobvariables.checksums.new = md5.HEX("new") end -- used in experiment

job.register('jobvariables.checksums', jobvariables.checksums)

local function initializer()
    local r = jobvariables.collected.randomseed
    if not r then
        r = math.random()
        math.setrandomseedi(r,"initialize")
    else
        math.setrandomseedi(r,"previous run")
    end
    jobvariables.tobesaved.randomseed = r
    for cs, value in next, jobvariables.collected do
        texsprint(ctxcatcodes,format("\\xdef\\%s{%s}",cs,value))
    end
end

job.register('jobvariables.collected', jobvariables.tobesaved, initializer)

function jobvariables.save(cs,value)
    jobvariables.tobesaved[cs] = value
end

-- experiment (bugged: some loop in running)

-- for the moment here, very experimental stuff

packer = packer or { }
packer.version = 1.00

local function hashed(t)
    local s = { }
    for k, v in next, t do
        if type(v) == "table" then
            s[#s+1] = k.."={"..hashed(v).."}"
        else
            s[#s+1] = k.."="..tostring(v)
        end
    end
    sort(s)
    return concat(s,",")
end

local function pack(t,keys,hash,index)
    for k,v in next, t do
        if type(v) == "table" then
            pack(v,keys,hash,index)
        end
        if keys[k] and type(v) == "table" then
            local h = hashed(v)
            local i = hash[h]
            if not i then
                i = #index+1
                index[i] = v
                hash[h] = i
            end
            t[k] = i
        end
    end
end

local function unpack(t,keys,index)
    for k,v in next, t do
        if keys[k] and type(v) == "number" then
            local iv = index[v]
            if iv then
                v = iv
                t[k] = v
            end
        end
        if type(v) == "table" then
            unpack(v,keys,index)
        end
    end
end

function packer.new(keys,version)
    return {
        version = version or packer.version,
        keys = table.tohash(keys),
        hash = { },
        index = { },
    }
end

function packer.pack(t,p,shared)
    if shared then
        pack(t,p.keys,p.hash,p.index)
    elseif not t.packer then
        pack(t,p.keys,p.hash,p.index)
        if #p.index > 0 then
            t.packer = {
                version = p.version or packer.version,
                keys = p.keys,
                index = p.index,
            }
        end
        p.hash, p.index = { }, { }
    end
end

function packer.unpack(t,p,shared)
    if shared then
        if p then
            unpack(t,p.keys,p.index)
        end
    else
        local tp = t.packer
        if tp then
            if tp.version == (p and p.version or packer.version) then
                unpack(t,tp.keys,tp.index)
            else
                -- fatal error, wrong version
            end
            t.packer = nil
        end
    end
end

function packer.strip(p)
    p.hash = nil
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
--  "references", -- we need to rename of them as only one packs (not structure.lists.references)
}

local jobpacker = packer.new(packlist,1.01)

job.pack = true

job._save_, job._load_ = { }, { } -- registers timing

function job.save(filename)
    statistics.starttiming(job._save_)
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
                packer.pack(data,jobpacker,true)
            end
            f:write(aux.definetable(target),"\n")
            f:write(table.serialize(data,target,true,true),"\n")
        end
        if job.pack then
            packer.strip(jobpacker)
            f:write(table.serialize(jobpacker,"job.packer",true,true),"\n")
        end
        f:close()
    end
    statistics.stoptiming(job._save_)
end

function job.load(filename)
    statistics.starttiming(job._load_)
    local data = io.loaddata(filename)
    if data and data ~= "" then
        local version = tonumber(match(data,"^-- version: ([%d%.]+)"))
        if version ~= jobs.version then
            logs.report("job","version mismatch with jobfile: %s <> %s", version or "?", jobs.version)
        else
            local data = loadstring(data)
            if data then
                data()
            end
            for l=1,#savelist do
                local list = savelist[l]
                local target, initializer = list[1], list[3]
                packer.unpack(aux.accesstable(target),job.packer,true)
                if type(initializer) == "function" then
                    initializer(aux.accesstable(target))
                end
            end
            job.packer = nil
        end
    end
    statistics.stoptiming(job._load_)
end

-- eventually this will end up in strc-ini

statistics.register("startup time", function()
    return statistics.elapsedseconds(ctx,"including runtime option file processing")
end)

statistics.register("jobdata time",function()
    if statistics.elapsedindeed(job._save_) or statistics.elapsedindeed(job._load_) then
        return format("%s seconds saving, %s seconds loading", statistics.elapsedtime(job._save_), statistics.elapsedtime(job._load_))
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
