if not modules then modules = { } end modules ['grph-fil'] = {
    version   = 1.001,
    comment   = "companion to grph-fig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat = string.format, table.concat

local trace_run = false  trackers.register("files.run",function(v) trace_run = v end)

local command = "context %s"

local jobfiles = {
    collected = { },
    tobesaved = { },
}

job.files = jobfiles

local tobesaved, collected = jobfiles.tobesaved, jobfiles.collected

local function initializer()
    tobesaved, collected = jobfiles.tobesaved, jobfiles.collected
end

job.register('job.files.collected', jobfiles.tobesaved, initializer)

jobfiles.forcerun = false

function jobfiles.run(name,...)
    local oldchecksum = collected[name]
    local newchecksum = file.checksum(name)
    if jobfiles.forcerun or not oldchecksum or oldchecksum ~= newchecksum then
        if trace_run then
            commands.writestatus("buffers","changes in '%s', processing forced",name)
        end
        os.execute(format(command,concat({ name, ... }," ")))
    elseif trace_run then
        commands.writestatus("buffers","no changes in '%s', not processed",name)
    end
    tobesaved[name] = newchecksum
    return file.replacesuffix(name,"pdf")
end
