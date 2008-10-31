if not modules then modules = { } end modules ['core-uti'] = {
    version   = 1.001,
    comment   = "companion to core-uti.tex",
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

local format = string.format

if not jobs then jobs         = { } end
if not job  then jobs['main'] = { } end job = jobs['main']

jobs.version = 1.01

--[[ldx--
<p>Variables are saved using in the previously defined table and passed
onto <l n='tex'/> using the following method. Of course one can also
directly access the variable using a <l n='lua'/> call.</p>
--ldx]]--

local savelist, comment = { }, { }

function job.comment(...)
    for _, str in ipairs({...}) do
        comment[#comment+1] = str
    end
end

job.comment(format("version: %1.2f",jobs.version))

job._save_, job._load_ = { }, { }

function job.save(filename)
    input.starttiming(job._save_)
    local f = io.open(filename,'w')
    if f then
        for _, str in ipairs(comment) do
            f:write("-- ",str,"\n")
        end
        f:write("\n")
        for _, list in ipairs(savelist) do
            local target, data, finalizer = list[1], list[2], list[4]
            if type(finalizer) == "function" then
                finalizer()
            end
            f:write(aux.definetable(target),"\n")
            f:write(table.serialize(data,target,true,true),"\n")
        end
        f:close()
    end
    input.stoptiming(job._save_)
end

function job.load(filename)
    input.starttiming(job._load_)
    local data = io.loaddata(filename)
    if data and data ~= "" then
        local version = tonumber(data:match("^-- version: ([%d%.]+)"))
        if version ~= jobs.version then
            logs.report("job","version mismatch with jobfile: %s <> %s", version or "?", jobs.version)
        else
            loadstring(data)()
            for _, list in ipairs(savelist) do
                local target, initializer = list[1], list[3]
                if type(initializer) == "function" then
                    initializer(aux.accesstable(target))
                end
            end
        end
    end
    input.stoptiming(job._load_)
end

function job.initialize(loadname,savename)
    job.load(loadname)
    table.insert(input.stop_actions, function()
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

local function initializer()
    for cs, value in pairs(jobvariables.collected) do
        tex.sprint(string.format("\\xdef\\%s{%s}",cs,value))
    end
end

job.register('jobvariables.collected', jobvariables.tobesaved, initializer)

function jobvariables.save(cs,value)
    jobvariables.tobesaved[cs] = value
end


