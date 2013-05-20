if not modules then modules = { } end modules ['mtx-pdf'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, gmatch = string.format, string.gmatch
local utfchar = utf.char
local concat = table.concat
local setmetatableindex, sortedhash, sortedkeys = table.setmetatableindex, table.sortedhash, table.sortedkeys

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-pdf</entry>
  <entry name="detail">ConTeXt PDF Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="info"><short>show some info about the given file</short></flag>
    <flag name="metadata"><short>show metadata xml blob</short></flag>
    <flag name="fonts"><short>show used fonts (<ref name="detail)"/></short></flag>
    <flag name="linearize"><short>linearize given file</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-pdf",
    banner   = "ConTeXt PDF Helpers 0.10",
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

function scripts.pdf.info(filename)
    local pdffile = loadpdffile(filename)
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

function scripts.pdf.metadata(filename)
    local pdffile = loadpdffile(filename)
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

local function getfonts(pdffile)
    local usedfonts = { }
    for i=1,pdffile.pages.n do
        local page = pdffile.pages[i]
        local fontlist = page.Resources.Font
        for k, v in next, lpdf.epdf.expand(fontlist) do
            usedfonts[k] = lpdf.epdf.expand(v)
        end
    end
    return usedfonts
end

local function getunicodes(font)
    local cid = font.ToUnicode
    if cid then
        cid = cid()
        local counts = { }
     -- for s in gmatch(cid,"begincodespacerange%s*(.-)%s*endcodespacerange") do
     --     for a, b in gmatch(s,"<([^>]+)>%s+<([^>]+)>") do
     --         print(a,b)
     --     end
     -- end
        setmetatableindex(counts, function(t,k) t[k] = 0 return 0 end)
        for s in gmatch(cid,"beginbfrange%s*(.-)%s*endbfrange") do
            for first, last, offset in gmatch(s,"<([^>]+)>%s+<([^>]+)>%s+<([^>]+)>") do
                first  = tonumber(first,16)
                last   = tonumber(last,16)
                offset = tonumber(offset,16)
                offset = offset - first
                for i=first,last do
                    local c = i + offset
                    counts[c] = counts[c] + 1
                end
            end
        end
        for s in gmatch(cid,"beginbfchar%s*(.-)%s*endbfchar") do
            for old, new in gmatch(s,"<([^>]+)>%s+<([^>]+)>") do
                for n in gmatch(new,"....") do
                    local c = tonumber(n,16)
                    counts[c] = counts[c] + 1
                end
            end
        end
        return counts
    end
end

function scripts.pdf.fonts(filename)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local usedfonts = getfonts(pdffile)
        local found     = { }
        for k, v in table.sortedhash(usedfonts) do
            local counts = getunicodes(v)
            local codes = { }
            local chars = { }
            local freqs = { }
            if counts then
                codes = sortedkeys(counts)
                for i=1,#codes do
                    local k = codes[i]
                    local c = utfchar(k)
                    chars[i] = c
                    freqs[i] = format("U+%05X  %s  %s",k,counts[k] > 1 and "+" or " ", c)
                end
                for i=1,#codes do
                    codes[i] = format("U+%05X",codes[i])
                end
            end
            found[k] = {
                basefont = v.BaseFont or "no basefont",
                encoding = v.Encoding or "no encoding",
                subtype  = v.Subtype or "no subtype",
                unicode  = v.ToUnicode and "unicode" or "no unicode",
                chars    = chars,
                codes    = codes,
                freqs    = freqs,
            }
        end

        if environment.argument("detail") then
            for k, v in sortedhash(found) do
                report("id         : %s",k)
                report("basefont   : %s",v.basefont)
                report("encoding   : %s",v.encoding)
                report("subtype    : %s",v.subtype)
                report("unicode    : %s",v.unicode)
                report("characters : %s", concat(v.chars," "))
                report("codepoints : %s", concat(v.codes," "))
                report("")
            end
        else
            local results = { { "id", "basefont", "encoding", "subtype", "unicode", "characters" } }
            for k, v in sortedhash(found) do
                results[#results+1] = { k, v.basefont, v.encoding, v.subtype, v.unicode, concat(v.chars," ") }
            end
            utilities.formatters.formatcolumns(results)
            report(results[1])
            report("")
            for i=2,#results do
                report(results[i])
            end
            report("")
        end
    end
end

-- this is a quick hack ... proof of concept .. will change (derived from luigi's example) ...
-- i will make a ctx wrapper

local qpdf

function scripts.pdf.linearize(filename)
    qpdf = qpdf or swiglib("qpdf.core")
    local oldfile = filename or environment.files[1]
    if not oldfile then
        return
    end
    file.addsuffix(oldfile,"pdf")
    if not lfs.isfile(oldfile) then
        return
    end
    local newfile = environment.files[2]
    if not newfile or file.removesuffix(oldfile) == file.removesuffix(newfile)then
        newfile = file.addsuffix(file.removesuffix(oldfile) .. "-linearized","pdf")
    end
    local password = environment.arguments.password
    local instance = qpdf.qpdf_init()
    if bit32.band(qpdf.qpdf_read(instance,oldfile,password),qpdf.QPDF_ERRORS) ~= 0 then
        report("unable to open input file")
    elseif bit32.band(qpdf.qpdf_init_write(instance,newfile),qpdf.QPDF_ERRORS) ~= 0 then
        report("unable to open output file")
    else
        report("linearizing %a into %a",oldfile,newfile)
        qpdf.qpdf_set_static_ID(instance,qpdf.QPDF_TRUE)
        qpdf.qpdf_set_linearization(instance,qpdf.QPDF_TRUE)
        qpdf.qpdf_write(instance)
    end
    while qpdf.qpdf_more_warnings(instance) ~= 0 do
        report("warning: %s",qpdf.qpdf_get_error_full_text(instance,qpdf.qpdf_next_warning(qpdf)))
    end
    if qpdf.qpdf_has_error(instance) ~= 0 then
        report("error: %s",qpdf.qpdf_get_error_full_text(instance,qpdf.qpdf_get_error(qpdf)))
    end
    qpdf.qpdf_cleanup_p(instance)
end

-- scripts.pdf.info("e:/tmp/oeps.pdf")
-- scripts.pdf.metadata("e:/tmp/oeps.pdf")
-- scripts.pdf.fonts("e:/tmp/oeps.pdf")
-- scripts.pdf.linearize("e:/tmp/oeps.pdf")

local filename = environment.files[1] or ""

if filename == "" then
    application.help()
elseif environment.argument("info") then
    scripts.pdf.info(filename)
elseif environment.argument("metadata") then
    scripts.pdf.metadata(filename)
elseif environment.argument("fonts") then
    scripts.pdf.fonts(filename)
elseif environment.argument("linearize") then
    scripts.pdf.linearize(filename)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),filename)
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
