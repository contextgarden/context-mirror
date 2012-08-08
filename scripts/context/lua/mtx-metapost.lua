if not modules then modules = { } end modules ['mtx-metapost'] = { -- this was mtx-mptopdf
    version   = 0.100,
    comment   = "companion to mtxrun.lua",
    author    = "Taco Hoekwater & Hans Hagen",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
--rawmp               raw metapost run
--metafun             use metafun instead of plain
--latex               force --tex=latex
--texexec             force texexec usage (mkii)
--split               split single result file into pages

intended usage:

mtxrun --script metapost yourfile.mp
mtxrun --script metapost --split yourfile.mp
mtxrun --script metapost yourfile.123 myfile.mps

other usage resembles mptopdf.pl
]]

local application = logs.application {
    name     = "mtx-metapost",
    banner   = "MetaPost to PDF processor 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts             = scripts             or { }
scripts.mptopdf     = scripts.mptopdf     or { }
scripts.mptopdf.aux = scripts.mptopdf.aux or { }

local format, find, gsub = string.format, string.find, string.gsub

local function assumes_latex(filename)
    local d = io.loaddata(filename) or ""
    return find(d,"\\documentstyle") or find(d,"\\documentclass") or find(d,"\\begin{document}")
end

local template = "\\startTEXpage\n\\convertMPtoPDF{%s}{1}{1}\n\\stopTEXpage"
local texified = "\\starttext\n%s\n\\stoptext"
local splitter = "\\startTEXpage\\externalfigure[%s][page=%s]\\stopTEXpage"
local tempname = "mptopdf-temp.tex"

local function do_convert(filename)
    if find(filename,".%d+$") or find(filename,"%.mps$") then
        io.savedata(tempname,format(template,filename))
        local resultname = format("%s-%s.pdf",file.nameonly(filename),file.suffix(filename))
        local result = os.execute(format([[context --once --batch --purge --result=%s "%s"]],resultname,tempname))
        return lfs.isfile(resultname) and resultname
    end
end

local function do_split(filename,numbers)
    local name = file.nameonly(filename)
    for i=1,#numbers do
        io.savedata(tempname,format(splitter,file.addsuffix(name,"pdf"),i))
        local resultname = format("%s-%s.pdf",name,numbers[i])
        local result = os.execute(format([[context --once --batch --purge --result=%s "%s"]],resultname,tempname))
    end
end

local function do_texify(str)
    -- This only works for flat mp files i.e. outer beginfigs. Normally a
    -- context user will directly make a tex file. Of course we can make
    -- this script more clever, but why should we as better methods exist.
    local numbers = { }
    str = "\\startMPinclusions\n".. str .. "\n\\stopMPinclusions"
    str = gsub(str,"beginfig%s*%(%s*(.-)%s*%)%s*;%s*",function(s)
        numbers[#numbers+1] = tonumber(s) or 0
        return "\n\\stopMPinclusions\n\\startMPpage\n"
    end)
    str = gsub(str,"%s*endfig%s*;%s*","\n\\stopMPpage\n\\startMPinclusions\n")
    str = gsub(str,"\\startMPinclusions%s*\\stopMPinclusions","")
    str = gsub(str,"[\n\r]+","\n")
    return format(texified,str), numbers
end

local function do_convert_all(filename)
    local results = dir.glob(file.nameonly(filename) .. ".*") -- reset
    local report = { }
    for i=1,#results do
        local filename = results[i]
        local resultname = do_convert(filename)
        if resultname then
            report[#report+1] = { filename, resultname }
        end
    end
    if #report > 0 then
        report("number of converted files: %i", #report)
        report()
        for i=1,#report do
            local r = report[i]
            report("%s => %s", r[1], r[2])
        end
    else
        report("no files are converted for '%s'",filename)
    end
end

local function do_convert_one(filename)
    local resultname = do_convert(filename)
    if resultname then
        report("%s => %s", filename,resultname)
    else
        report("no result for '%s'",filename)
    end
end

function scripts.mptopdf.convertall()
    local rawmp   = environment.arguments.rawmp   or false
    local metafun = environment.arguments.metafun or false
    local latex   = environment.arguments.latex   or false
    local pattern = environment.arguments.pattern or false
    local split   = environment.arguments.split   or false
    local files
    if pattern then
        files = dir.glob(file.nameonly(filename))
    else
        files   = environment.files
    end
    if #files > 0 then
        for i=1,#files do
            local filename = files[i]
            if file.suffix(filename) == "mp" then
                local command, convert, texdata, numbers
                if rawmp then
                    if metafun then
                        command, convert = format("mpost --progname=mpost --mem=metafun %s",filename), true
                    else
                        command, convert = format("mpost --mem=mpost %s",filename), true
                    end
                else
                    if latex or assumes_latex(filename) then
                        command, convert = format("mpost --mem=mpost --tex=latex %s",filename), true
                    elseif texexec then
                        command, convert = format("texexec --mptex %s",filename), true
                    else
                        texdata, numbers = do_texify(io.loaddata(filename) or "")
                        io.savedata(tempname,texdata)
                        command, convert = format("context --result=%s --purge --once %s",file.nameonly(filename),tempname), false
                    end
                end
                report("running: %s",command)
                local done = os.execute(command)
                if done then
                    if convert then
                        do_convert_all(filename)
                    elseif split then
                        do_split(filename,numbers)
                        -- already pdf, maybe optionally split
                    end
                else
                    report("error while processing mp file '%s'", filename)
                end
            else
                do_convert_one(filename)
            end
        end
    else
        report("no files match to process")
    end
end

if environment.files[1] then
    scripts.mptopdf.convertall()
else
    if not environment.arguments.help then
        report("provide MP output file (or pattern)")
        report()
    end
    application.help()
end
