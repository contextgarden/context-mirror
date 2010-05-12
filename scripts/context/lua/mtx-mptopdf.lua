if not modules then modules = { } end modules ['mtx-mptopdf'] = {
    version   = 1.303,
    comment   = "companion to mtxrun.lua, patched by HH so errors are his",
    author    = "Taco Hoekwater, Elvenkind BV, Dordrecht NL",
    copyright = "Elvenkind BV / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts             = scripts             or { }
scripts.mptopdf     = scripts.mptopdf     or { }
scripts.mptopdf.aux = scripts.mptopdf.aux or { }

local dosish      = os.type == 'windows'
local miktex      = dosish and environment.TEXSYSTEM and environment.TEXSYSTEM:find("miktex")
local escapeshell = environment.SHELL and environment.SHELL:find("sh") and true

function scripts.mptopdf.aux.find_latex(fname)
    local d = io.loaddata(fname) or ""
    return d:find("\\documentstyle") or d:find("\\documentclass") or d:find("\\begin{document}")
end

function scripts.mptopdf.aux.do_convert (fname)
    local command, done, pdfdest = "", 0, ""
    if fname:find(".%d+$") or fname:find("%.mps$") then
        if miktex then
            command = "pdftex -undump=mptopdf"
        else
            command = "pdftex -fmt=mptopdf -progname=context"
        end
        if dosish then
            command = string.format('%s \\relax "%s"',command,fname)
        else
            command = string.format('%s \\\\relax "%s"',command,fname)
        end
        local result = os.execute(command)
        if result == 0 then
            local name, suffix = file.nameonly(fname), file.extname(fname)
            local pdfsrc =  name .. ".pdf"
            if lfs.isfile(pdfsrc) then
                pdfdest = name .. "-" .. suffix .. ".pdf"
                os.rename(pdfsrc, pdfdest)
                if lfs.isfile(pdfsrc) then -- rename failed
                    file.copy(pdfsrc, pdfdest)
                end
                done = 1
            end
        end
    end
    return done, pdfdest
end

function scripts.mptopdf.aux.make_mps(fn,latex,rawmp,metafun)
    local rest, mpbin = latex and " --tex=latex " or " ", ""
    if rawmp then
        if metafun then
            mpbin = "mpost --progname=mpost --mem=metafun"
        else
            mpbin = "mpost --mem=mpost"
        end
    else
        if latex then
            mpbin = "mpost --mem=mpost"
        else
            mpbin = "texexec --mptex"
        end
    end
    local runner = mpbin .. rest .. fn
    logs.simple("running: %s\n", runner)
    return (os.execute(runner))
end

function scripts.mptopdf.convertall()
    local rawmp   = environment.arguments.rawmp   or false
    local metafun = environment.arguments.metafun or false
    local latex   = environment.arguments.latex   or false
    local files   = dir.glob(environment.files)
    if #files > 0 then
        local fn = files[1]
        if #files == 1 and fn:find("%.mp$") then
            latex = scripts.mptopdf.aux.find_latex(fn) or latex
        end
        if scripts.mptopdf.aux.make_mps(fn,latex,rawmp,metafun) then
            files = dir.glob(file.nameonly(fn) .. ".*") -- reset
        else
            logs.simple("error while processing mp file '%s'", fn)
            exit(1)
        end
        local report = { }
        for _,fn in ipairs(files) do
            local success, name = scripts.mptopdf.aux.do_convert(fn)
            if success > 0 then
                report[#report+1] = { fn, name }
            end
        end
        if #report > 0 then
            logs.simple("number of converted files: %i", #report)
            logs.simple("")
            for _, r in ipairs(report) do
                logs.simple("%s => %s", r[1], r[2])
            end
        else
            logs.simple("no files are converted")
        end
    else
        logs.simple("no files match %s", table.concat(environment.files,' '))
    end
end

logs.extendbanner("MetaPost to PDF Converter 0.51",true)

messages.help = [[
--rawmp               raw metapost run
--metafun             use metafun instead of plain
--latex               force --tex=latex
]]

if environment.files[1] then
    scripts.mptopdf.convertall()
else
    if not environment.arguments.help then
        logs.simple("provide MP output file (or pattern)")
        logs.simple("")
    end
    logs.help(messages.help)
end
