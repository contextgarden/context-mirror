if not modules then modules = { } end modules ['grph-fil'] = {
    version   = 1.001,
    comment   = "companion to grph-fig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

local trace_run  = false  trackers.register("graphic.runfile",function(v) trace_run = v end)
local report_run = logs.reporter("graphics","run")

-- Historically running files is part of graphics processing, so this is why it
-- sits here but is part of the job namespace.

local allocate = utilities.storage.allocate

local collected = allocate()
local tobesaved = allocate()

local jobfiles = {
    collected = collected,
    tobesaved = tobesaved,
    forcerun  = false, -- maybe a directive some day
}

job.files = jobfiles

local function initializer()
    tobesaved = jobfiles.tobesaved
    collected = jobfiles.collected
end

job.register('job.files.collected', tobesaved, initializer)

function jobfiles.run(name,action)
    local oldchecksum = collected[name]
    local newchecksum = file.checksum(name)
    if jobfiles.forcerun or not oldchecksum or oldchecksum ~= newchecksum then
        if trace_run then
            report_run("processing file, changes in %a, processing forced",name)
        end
        local ta = type(action)
        if ta == "function" then
            action(name)
        elseif ta == "string" and action ~= "" then
            os.execute(action)
        else
            report_run("processing file, no action given for processing %a",name)
        end
    elseif trace_run then
        report_run("processing file, no changes in %a, not processed",name)
    end
    tobesaved[name] = newchecksum
end

--

function jobfiles.context(name,options)
    if type(name) == "table" then
        local result = { }
        for i=1,#name do
            result[#result+1] = jobfiles.context(name[i],options)
        end
        return result
    else
        jobfiles.run(name,"context ".. (options or "") .. " " .. name)
        return file.replacesuffix(name,"pdf")
    end
end
