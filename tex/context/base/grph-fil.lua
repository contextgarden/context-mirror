if not modules then modules = { } end modules ['grph-fil'] = {
    version   = 1.001,
    comment   = "companion to grph-fig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat = string.format, table.concat

local trace_run = false  trackers.register("graphic.runfile",function(v) trace_run = v end)

local report_run = logs.reporter("graphics","run")

local allocate = utilities.storage.allocate

local collected = allocate()
local tobesaved = allocate()

local jobfiles = {
    collected = collected,
    tobesaved = tobesaved,
}

job.files = jobfiles

local function initializer()
    tobesaved = jobfiles.tobesaved
    collected = jobfiles.collected
end

job.register('job.files.collected', tobesaved, initializer)

jobfiles.forcerun = false

function jobfiles.run(name,command)
    local oldchecksum = collected[name]
    local newchecksum = file.checksum(name)
    if jobfiles.forcerun or not oldchecksum or oldchecksum ~= newchecksum then
        if trace_run then
            report_run("processing file, changes in '%s', processing forced",name)
        end
        if command and command ~= "" then
            os.execute(command)
        else
            report_run("processing file, no command given for processing '%s'",name)
        end
    elseif trace_run then
        report_run("processing file, no changes in '%s', not processed",name)
    end
    tobesaved[name] = newchecksum
end

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
