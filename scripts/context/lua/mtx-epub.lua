if not modules then modules = { } end modules ['mtx-epub'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The epub specification is far from beautiful. Especially the id related
-- part is messy and devices/programs react differently on them (so an id is not
-- really an id but has some special property). Then there is this ncx suffix
-- thing. Somehow it give the impression of a reversed engineered application
-- format so it will probably take a few cycles to let it become a real
-- clean standard. Thanks to Adam Reviczky for helping to figure out all these
-- puzzling details.

-- This is preliminary code. At some point we will deal with images as well but
-- first we need a decent strategy to export them. More information will be
-- available on the wiki.

local format, gsub = string.format, string.gsub
local concat = table.concat

local helpinfo = [[
--make                create epub zip file

example:

mtxrun --script epub --make mydocument
]]

local application = logs.application {
    name     = "mtx-epub",
    banner   = "ConTeXt EPUB Helpers 0.11",
    helpinfo = helpinfo,
}

-- script code

scripts      = scripts      or { }
scripts.epub = scripts.epub or { }

local mimetype = "application/epub+zip"

local container = [[
<?xml version="1.0" encoding="UTF-8" ?>

<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="OPS/%s" media-type="application/oebps-package+xml"/>
    </rootfiles>
</container>
]]

local package = [[
<?xml version="1.0"?>

<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="%s">

    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>My Title</dc:title>
        <dc:language>en</dc:language>
        <dc:identifier id="%s" >urn:uuid:%s</dc:identifier>
        <dc:creator opf:file-as="Self, My" opf:role="aut">MySelf</dc:creator>
        <dc:date>%s</dc:date>
    </metadata>

    <manifest>
%s
    </manifest>

    <spine toc="ncx">
        <itemref idref="%s" />
    </spine>

</package>
]]

local item = [[        <item id='%s' href='%s' media-type='%s'/>]]

local toc = [[
<?xml version="1.0"?>

<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">

<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">

    <head>
        <meta name="dtb:uid"           content="%s" />
        <meta name="dtb:depth"         content="2" />
        <meta name="dtb:totalPgeCount" content="0" />
        <meta name="dtb:maxPageNumber" content="0" />
    </head>

    <docTitle>
        <text>%s</text>
    </docTitle>

    <navMap>
        <navPoint id="np-1" playOrder="1">
            <navLabel>
                <text>start</text>
            </navLabel>
            <content src="%s"/>
        </navPoint>
    </navMap>

</ncx>
]]

-- We need to figure out what is permitted. Numbers only seem to give
-- problems is some applications as do names with dashes. Also the
-- optional toc is supposed to be there and although id's are by
-- concept neutral, there are sometimes hard requirements with respect
-- to their name like ncx and toc.ncx). Maybe we should stick to 3.0
-- only.

local function dumbid(filename)
 -- return (string.gsub(os.uuid(),"%-%","")) -- to be tested
    return file.nameonly(filename) .. "-" .. file.extname(filename)
end

local mimetypes = {
    xhtml   = "application/xhtml+xml",
    xml     = "application/xhtml+xml",
    css     = "text/css",
    svg     = "image/svg+xml",
    png     = "image/png",
    jpg     = "image/jpeg",
    ncx     = "application/x-dtbncx+xml",
 -- default = "text/plain",
}

local idmakers = {
    ncx     = function(filename) return "ncx"            end,
 -- css     = function(filename) return "stylesheet"     end,
    default = function(filename) return dumbid(filename) end,
}

-- specification = {
--     name = "document",
--     identifier = "123",
--     root = "a.xhtml",
--     files = {
--         "a.xhtml",
--         "b.css",
--         "c.png",
--     }
-- }

local function locateimages(oldname,newname,subpath)
    local data = io.loaddata(oldname)
    local images = { }
    local done = gsub(data,"(background%-image *: * url%()(.-)(%))", function(before,name,after)
        if subpath then
            name = file.join(subpath,name)
        end
        images[#images+1] = name
        return before .. name .. after
    end)
    if newname then
        io.savedata(done,newname)
    end
    return images
end

local zippers = {
    {
        name         = "zip",
        uncompressed = "zip %s -X -0 %s",
        compressed   = "zip %s -X -9 -r %s",
    },
    {
        name         = "7zip (7z)",
        uncompressed = "7z a -tzip -mx0 %s %s",
        compressed   = "7z a -tzip %s %s",
    },
}

function scripts.epub.make()

    local filename = environment.files[1]

    if filename and filename ~= "" and type(filename) == "string" then

        filename = file.basename(filename)
        local specfile = file.replacesuffix(filename,"specification")
        local specification = lfs.isfile(specfile) and dofile(specfile) or { }

--         inspect(specification)

        local name       = specification.name       or file.removesuffix(filename)
        local identifier = specification.identifier or os.uuid(true)
        local files      = specification.files      or { file.addsuffix(filename,"xhtml") }
        local images     = specification.images     or { }
        local root       = specification.root       or files[1]

     -- identifier = gsub(identifier,"[^a-zA-z0-9]","")

        identifier = "BookId" -- weird requirement

        local epubname   = name
        local epubpath   = file.replacesuffix(name,"tree")
        local epubfile   = file.replacesuffix(name,"epub")
        local epubroot   = file.replacesuffix(name,"opf")
        local epubtoc    = "toc.ncx"

        application.report("creating paths in tree %s",epubpath)
        lfs.mkdir(epubpath)
        lfs.mkdir(file.join(epubpath,"META-INF"))
        lfs.mkdir(file.join(epubpath,"OPS"))

        local used = { }

        local function copyone(filename)
            local suffix = file.suffix(filename)
            local mime = mimetypes[suffix]
            if mime then
                local idmaker = idmakers[suffix] or idmakers.default
                local target = file.join(epubpath,"OPS",filename)
                file.copy(filename,target)
                application.report("copying %s to %s",filename,target)
                used[#used+1] = format(item,idmaker(filename),filename,mime)
            end
        end

        copyone("toc.ncx")

        local function copythem(files)
            for i=1,#files do
                local filename = files[i]
                if type(filename) == "string" then
                    copyone(filename)
                end
            end
        end

        copythem(files)

        local theimages = { }

        for k, v in table.sortedpairs(images) do
            theimages[#theimages+1] = k
            if not lfs.isfile(k) and file.extname(k) == "svg" and file.extname(v) == "pdf" then
                local command = format("inkscape --export-plain-svg=%s %s",k,v)
                application.report("running command '%s'\n\n",command)
                os.execute(command)
            end
        end

        copythem(theimages)

        local idmaker = idmakers[file.extname(root)] or idmakers.default

        container = format(container,epubroot)
        package   = format(package,identifier,identifier,os.uuid(),os.date("!%Y-%m-%dT%H:%M:%SZ"),concat(used,"\n"),idmaker(root))
        toc       = format(toc,identifier,"title",root)

        io.savedata(file.join(epubpath,"mimetype"),mimetype)
        io.savedata(file.join(epubpath,"META-INF","container.xml"),container)
        io.savedata(file.join(epubpath,"OPS",epubroot),package)
        io.savedata(file.join(epubpath,"OPS",epubtoc),toc)

        application.report("creating archive\n\n")

        local done = false
        local list = { }

        lfs.chdir(epubpath)
        os.remove(epubfile)

        for i=1,#zippers do
            local zipper = zippers[i]
            if os.execute(format(zipper.uncompressed,epubfile,"mimetype")) then
                os.execute(format(zipper.compressed,epubfile,"META-INF"))
                os.execute(format(zipper.compressed,epubfile,"OPS"))
                done = zipper.name
            else
                list[#list+1] = zipper.name
            end
        end

        lfs.chdir("..")

        if done then
            application.report("epub archive made using %s: %s",done,file.join(epubpath,epubfile))
        else
            application.report("no epub archive made, install one of: %s",concat(list," "))
        end

    end

end

--

if environment.argument("make") then
    scripts.epub.make()
else
    application.help()
end
