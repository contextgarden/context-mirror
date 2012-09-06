if not modules then modules = { } end modules ['core-sys'] = {
    version   = 1.001,
    comment   = "companion to core-sys.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower, format, gsub = string.lower, string.format, string.gsub
local suffix, basename, removesuffix = file.suffix, file.basename, file.removesuffix

local environment = environment

function commands.updatefilenames(jobname,fulljobname,inputfilename,outputfilename)
    --
    environment.jobname             = jobname
    --
    local       jobfilename         = gsub(fulljobname or jobname or inputfilename or tex.jobname or "","%./","")
    --
    environment.jobfilename         = jobfilename
    environment.jobfilesuffix       = lower(suffix(environment.jobfilename))
    --
    local       inputfilename       = gsub(inputfilename or "","%./","")
    environment.inputfilename       = inputfilename
    environment.inputfilebarename   = removesuffix(basename(inputfilename))
    --
    local       inputfilerealsuffix = suffix(inputfilename)
    environment.inputfilerealsuffix = inputfilerealsuffix
    --
    local       inputfilesuffix     = inputfilerealsuffix == "" and "tex" or lower(inputfilerealsuffix)
    environment.inputfilesuffix     = inputfilesuffix
    --
    local       outputfilename      = outputfilename or environment.inputfilebarename or ""
    environment.outputfilename      = outputfilename
    --
    commands.writestatus("files",format("jobname: %q, input: %q, result: %q, suffix: %s",
        jobfilename,inputfilename,outputfilename,inputfilesuffix))
end

statistics.register("result saved in file", function()
    -- suffix will be fetched from backend
    if tex.pdfoutput > 0 then
        return format( "%s.%s, compresslevel %s, objectcompreslevel %s", environment.outputfilename, "pdf", tex.pdfcompresslevel, tex.pdfobjcompresslevel)
    else
        return format( "%s.%s", environment.outputfilename, "dvi") -- hard to imagine
    end
end)
