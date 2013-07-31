if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local codeinjections = backends.pdf.codeinjections

local outputfilename

function codeinjections.getoutputfilename()
    if not outputfilename then
        outputfilename = file.addsuffix(tex.jobname,"pdf")
    end
    return outputfilename
end

backends.install("pdf")

-- experimental code (somewhat weird here) .. todo: nodeinjections

local context = context

local sind, cosd = math.sind, math.cosd
local insert, remove = table.insert, table.remove

-- function commands.pdfrotation(a) -- somewhat weird here
--     local s, c = sind(a), cosd(a)
--     context("%0.6f %0.6f %0.6f %0.6f",c,s,-s,c)
-- end

local stack       = { }
local f_rotation  = string.formatters["%0.8f %0.8f %0.8f %0.8f"]
local f_scaling   = string.formatters["%0.8f 0 0 %0.8f"]
local s_mirroring = "-1 0 0 1"
local f_matrix    = string.formatters["%0.8f %0.8f %0.8f %0.8f"]

local pdfsetmatrix = nodes.pool.pdfsetmatrix

local function pop()
    local top = remove(stack)
    if top then
        context(pdfsetmatrix(top))
    end
end

function commands.pdfstartrotation(a)
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        context(pdfsetmatrix(f_rotation(c,s,-s,c)))
        insert(stack,f_rotation(-c,-s,s,-c))
    end
end

function commands.pdfstartscaling(sx,sy)
    if sx == 1 and sy == 1 then
        insert(stack,false)
    else
        if sx == 0 then sx = 0.0001 end -- prevent acrobat crash
        if sy == 0 then sy = 0.0001 end -- prevent acrobat crash
        context(pdfsetmatrix(f_scaling(sx,sy)))
        insert(stack,f_scaling(1/sx,1/sy))
    end
end

function commands.pdfstartmirroring(sx,sy)
    context(pdfsetmatrix(s_mirroring))
    insert(stack,s_mirroring)
end

function commands.pdfstartmatrix(sx,rx,ry,sy)
    if sx ==1 and rx == 0 and ry == 0 and sy == 1 then
        insert(stack,false)
    else
        if sx == 0 then sx = 0.0001 end -- prevent acrobat crash
        if sy == 0 then sy = 0.0001 end -- prevent acrobat crash
        context(pdfsetmatrix(f_matrix(rx,sx,sy,ry)))
        insert(stack,f_matrix(-rx,-sx,-sy,-ry))
    end
end

commands.pdfstoprotation  = pop
commands.pdfstopscaling   = pop
commands.pdfstopmirroring = pop
commands.pdfstopmatrix    = pop
