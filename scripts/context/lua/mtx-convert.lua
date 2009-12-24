if not modules then modules = { } end modules ['mtx-convert'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: eps and svg

graphics            = graphics            or { }
graphics.converters = graphics.converters or { }

local gsprogram = (os.type == "windows" and "gswin32c") or "gs"
local gstemplate = "%s -q -sDEVICE=pdfwrite -dEPSCrop -dNOPAUSE -dNOCACHE -dBATCH -dAutoRotatePages=/None -dProcessColorModel=/DeviceCMYK -sOutputFile=%s %s -c quit"

function graphics.converters.eps(oldname,newname)
    return gstemplate:format(gsprogram,newname,oldname)
end

local improgram  = "convert"
local imtemplate = {
    low    = "%s -quality   0 -compress zip %s pdf:%s",
    medium = "%s -quality  75 -compress zip %s pdf:%s",
    high   = "%s -quality 100 -compress zip %s pdf:%s",
}

function graphics.converters.jpg(oldname,newname)
    local ea = environment.arguments
    local quality = (ea.high and 'high') or (ea.medium and 'medium') or (ea.low and 'low') or 'high'
    return imtemplate[quality]:format(improgram,oldname,newname)
end

graphics.converters.gif  = graphics.converters.jpg
graphics.converters.tif  = graphics.converters.jpg
graphics.converters.tiff = graphics.converters.jpg
graphics.converters.png  = graphics.converters.jpg

local function convert(kind,oldname,newname)
    if graphics.converters[kind] then -- extra test
        local tmpname = file.replacesuffix(newname,"tmp")
        local command = graphics.converters[kind](oldname,tmpname)
        logs.simple("command: %s",command)
        io.flush()
        os.spawn(command)
        os.remove(newname)
        os.rename(tmpname,newname)
        if lfs.attributes(newname,"size") == 0 then
            os.remove(newname)
        end
    end
end

function graphics.converters.convertpath(inputpath,outputpath)
    inputpath  = inputpath  or "."
    outputpath = outputpath or "."
    for name in lfs.dir(inputpath) do
        local suffix = file.extname(name)
        if name:find("%.$") then
            -- skip . and ..
        elseif graphics.converters[suffix] then
            local oldname = file.join(inputpath,name)
            local newname = file.join(outputpath,file.replacesuffix(name,"pdf"))
            local et = lfs.attributes(oldname,"modification")
            local pt = lfs.attributes(newname,"modification")
            if not pt or et > pt then
                dir.mkdirs(outputpath)
                convert(suffix,oldname,newname)
            end
        elseif lfs.isdir(inputpath .. "/".. name) then
            graphics.converters.convertpath(inputpath .. "/".. name,outputpath .. "/".. name)
        end
    end
end

function graphics.converters.convertfile(oldname)
    local suffix = file.extname(oldname)
    if graphics.converters[suffix] then
        local newname = file.replacesuffix(name,"pdf")
        if oldname == newname then
            -- todo: downsample, crop etc
        elseif environment.argument("force") then
            convert(suffix,oldname,newname)
        else
            local et = lfs.attributes(oldname,"modification")
            local pt = lfs.attributes(newname,"modification")
            if not pt or et > pt then
                convert(suffix,oldname,newname)
            end
        end
    end
end

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

function scripts.convert.convertgiven()
    for _, name in ipairs(environment.files) do
        graphics.converters.convertfile(name)
    end
end


logs.extendbanner("ConTeXT Graphic Conversion Helpers 0.10",true)

messages.help = [[
--convertall          convert all graphics on path
--inputpath=string    original graphics path
--outputpath=string   converted graphics path
--watch               watch folders
--force               force conversion (even if older)
--delay               time between sweeps
]]

if environment.argument("convertall") then
    scripts.convert.convertall()
elseif environment.files[1] then
    scripts.convert.convertgiven()
else
    logs.help(messages.help)
end
