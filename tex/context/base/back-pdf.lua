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

local pdfsetmatrix = nodes.pool.pdfsetmatrix
local stack        = { }

local function popmatrix()
    local top = remove(stack)
    if top then
        context(pdfsetmatrix(unpack(top)))
    end
end

function commands.pdfstartrotation(a)
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        context(pdfsetmatrix(f_rotation(c,s,-s,c)))
        insert(stack,{ -c, -s, s, -c })
    end
end

function commands.pdfstartscaling(sx,sy)
    if sx == 1 and sy == 1 then
        insert(stack,false)
    else
        if sx == 0 then
            sx = 0.0001
        end
        if sy == 0 then
            sy = 0.0001
        end
        context(pdfsetmatrix(sx,0,0,sy))
        insert(stack,{ 1/sx, 0, 0, 1/sy })
    end
end

function commands.pdfstartmirroring()
    context(pdfsetmatrix(-1,0,0,1))
end

function commands.pdfstartmatrix(sx,rx,ry,sy)
    if sx == 1 and rx == 0 and ry == 0 and sy == 1 then
        insert(stack,false)
    else
        context(pdfsetmatrix(f_matrix(rx,sx,sy,ry)))
        insert(stack,f_matrix(-rx,-sx,-sy,-ry))
    end
end

commands.pdfstoprotation  = popmatrix
commands.pdfstopscaling   = popmatrix
commands.pdfstopmirroring = commands.pdfstartmirroring
commands.pdfstopmatrix    = popmatrix
