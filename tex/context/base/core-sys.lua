if not modules then modules = { } end modules ['core-sys'] = {
    version   = 1.001,
    comment   = "companion to core-sys.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower, format = string.lower, string.format
local suffix, basename, removesuffix = file.suffix, file.basename, file.removesuffix

local environment = environment

-- function commands.updatefilenames(inputfilename,outputfilename)
--     --
--     environment.jobfilename       = inputfilename or tex.jobname or ""
--     environment.jobfilesuffix     = lower(suffix(environment.jobfilename))
--     --
--     environment.inputfilename     = inputfilename or ""
--     environment.inputfilebarename = removesuffix(basename(inputfilename))
--     environment.inputfilesuffix   = lower(suffix(inputfilename))
--     --
--     environment.outputfilename    = outputfilename or ""
-- end

function commands.updatefilenames(jobname,inputfilename,outputfilename)
    --
    environment.jobfilename       = jobname or inputfilename or tex.jobname or ""
    environment.jobfilesuffix     = lower(suffix(environment.jobfilename))
    --
    environment.inputfilename     = inputfilename or ""
    environment.inputfilebarename = removesuffix(basename(inputfilename))
    environment.inputfilesuffix   = lower(suffix(inputfilename))
    --
    environment.outputfilename    = outputfilename or environment.inputfilebarename or ""
end

statistics.register("result saved in file", function()
    -- suffix will be fetched from backend
    if tex.pdfoutput > 0 then
        return format( "%s.%s, compresslevel %s, objectcompreslevel %s", environment.outputfilename, "pdf", tex.pdfcompresslevel, tex.pdfobjcompresslevel)
    else
        return format( "%s.%s", environment.outputfilename, "dvi") -- hard to imagine
    end
end)
