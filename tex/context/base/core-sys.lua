if not modules then modules = { } end modules ['core-sys'] = {
    version   = 1.001,
    comment   = "companion to core-sys.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower, extname, basename, removesuffix = string.lower, file.extname, file.basename, file.removesuffix

function commands.updatefilenames(inputfilename,outputfilename)
    environment.inputfilename     = inputfilename or ""
    environment.outputfilename    = outputfilename or ""
    environment.jobfilename       = inputfilename or tex.jobname or ""
    environment.jobfilesuffix     = lower(extname(environment.jobfilename))
    environment.inputfilebarename = removesuffix(basename(inputfilename))
    environment.inputfilesuffix   = lower(extname(inputfilename))
end
