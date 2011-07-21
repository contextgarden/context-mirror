if not modules then modules = { } end modules ['mtx-pdf'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
--info                show some info about the given file
--metadata            show metadata xml blob
]]

local application = logs.application {
    name     = "mtx-pdf",
    banner   = "ConTeXt PDF Helpers 0.01",
    helpinfo = helpinfo,
}

local report = application.report

dofile(resolvers.findfile("lpdf-epd.lua","tex"))

scripts     = scripts     or { }
scripts.pdf = scripts.pdf or { }

local function loadpdffile(filename)
    if not filename or filename == "" then
        report("no filename given")
    elseif not lfs.isfile(filename) then
        report("unknown file '%s'",filename)
    else
        local pdffile  = lpdf.epdf.load(filename)
        if pdffile then
            return pdffile
        else
            report("no valid pdf file '%s'",filename)
        end
    end
end

function scripts.pdf.info()
    local filename = environment.files[1]
    local pdffile  = loadpdffile(filename)
    if pdffile then
        local catalog  = pdffile.Catalog
        local info     = pdffile.Info
        local pages    = pdffile.pages
        local nofpages = pages.n -- no # yet. will be in 5.2

        report("filename > %s",filename)
        report("pdf version > %s",catalog.Version)
        report("number of pages > %s",nofpages)
        report("title > %s",info.Title)
        report("creator > %s",info.Creator)
        report("producer > %s",info.Producer)
        report("creation date > %s",info.CreationDate)
        report("modification date > %s",info.ModDate)

        local width, height, start
        for i=1, nofpages do
            local page = pages[i]
            local bbox = page.CropBox or page.MediaBox
            local w, h = bbox[4]-bbox[2],bbox[3]-bbox[1]
            if w ~= width or h ~= height then
                if start then
                    report("cropbox > pages: %s-%s, width: %s, height: %s",start,i-1,width,height)
                end
                width, height, start = w, h, i
            end
        end
        report("cropbox > pages: %s-%s, width: %s, height: %s",start,nofpages,width,height)
    end
end

function scripts.pdf.metadata()
    local filename = environment.files[1]
    local pdffile  = loadpdffile(filename)
    if pdffile then
        local catalog  = pdffile.Catalog
        local metadata = catalog.Metadata
        if metadata then
            report("metadata > \n\n%s\n",metadata())
        else
            report("no metadata")
        end
    end
end

if environment.argument("info") then
    scripts.pdf.info()
elseif environment.argument("metadata") then
    scripts.pdf.metadata()
else
    application.help()
end

-- a variant on an experiment by hartmut

--~ function downloadlinks(filename)
--~     local document = lpdf.epdf.load(filename)
--~     if document then
--~         local pages = document.pages
--~         for p = 1,#pages do
--~             local annotations = pages[p].Annots
--~             if annotations then
--~                 for a=1,#annotations do
--~                     local annotation = annotations[a]
--~                     local uri = annotation.Subtype == "Link" and annotation.A and annotation.A.URI
--~                     if uri and string.find(uri,"^http") then
--~                         os.execute("wget " .. uri)
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~ end
