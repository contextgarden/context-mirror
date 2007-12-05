if not modules then modules = { } end modules ['mtx-convert'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

do

    graphics            = graphics            or { }
    graphics.converters = graphics.converters or { }

    local gsprogram = (os.platform == "windows" and "gswin32c") or "gs"
    local gstemplate = "%s -q -sDEVICE=pdfwrite -dEPSCrop -dNOPAUSE -dNOCACHE -dBATCH -dAutoRotatePages=/None -dProcessColorModel=/DeviceCMYK -sOutputFile=%s %s -c quit"

    function graphics.converters.epstopdf(inputpath,outputpath,epsname)
        inputpath  = inputpath  or "."
        outputpath = outputpath or "."
        local oldname = file.join(inputpath,epsname)
        local newname = file.join(outputpath,file.replacesuffix(epsname,"pdf"))
        local et = lfs.attributes(oldname,"modification")
        local pt = lfs.attributes(newname,"modification")
        if not pt or et > pt then
            dir.mkdirs(outputpath)
            local tmpname = file.replacesuffix(newname,"tmp")
            local command = string.format(gstemplate,gsprogram,tmpname,oldname)
            os.execute(command)
            os.remove(newname)
            os.rename(tmpname,newname)
        end
    end

    function graphics.converters.convertpath(inputpath,outputpath)
        for name in lfs.dir(inputpath or ".") do
            if name:find("%.$") then
                -- skip . and ..
            elseif name:find("%.eps$") then
                graphics.converters.epstopdf(inputpath,outputpath, name)
            elseif lfs.attributes(inputpath .. "/".. name,"mode") == "directory" then
                graphics.converters.convertpath(inputpath .. "/".. name,outputpath .. "/".. name)
            end
        end
    end

end

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts         = scripts         or { }
scripts.convert = scripts.convert or { }

scripts.convert.delay = 5 * 60 -- 5 minutes

function scripts.convert.convertall()
    local watch  = environment.arguments.watch      or false
    local delay  = environment.arguments.delay      or scripts.convert.delay
    local input  = environment.arguments.inputpath  or "."
    local output = environment.arguments.outputpath or "."
    while true do
        graphics.converters.convertpath(input, output)
        if watch then
            os.sleep(delay)
        else
            break
        end
    end
end

banner = banner .. " | graphic conversion tools "

messages.help = [[
--convertall          convert all graphics on path
--inputpath=string    original graphics path
--outputpath=string   converted graphics path
--watch               watch folders
--delay               time between sweeps
]]

input.verbose = true

if environment.argument("convertall") then
    scripts.convert.convertall()
else
    input.help(banner,messages.help)
end
