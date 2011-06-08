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

local format = string.format
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
        <dc:identifier id="%s" />
        <dc:creator opf:file-as="Self, My" opf:role="aut">MySelf</dc:creator>
    </metadata>

    <manifest>
        %s
    </manifest>

    <spine toc="ncx">
        <itemref idref="%s" />
    </spine>

</package>
]]

-- We need to figure out what is permitted; numbers only seem to give
-- problems is some applications as do names with dashes.

local function dumbid(filename)
 -- return (string.gsub(os.uuid(),"%-%","")) -- to be tested
    return file.nameonly(filename)
end

local mimetypes = {
    xhtml   = "application/xhtml+xml",
    css     = "text/css",
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

function scripts.epub.make()

    local filename = environment.files[1]

    if filename and filename ~= "" then

        filename = file.basename(filename)
        local specfile = file.replacesuffix(filename,"specification")
        local specification = lfs.isfile(specfile) and dofile(specfile) or { }

     -- inspect(specification)

        local name       = specification.name       or file.removesuffix(filename)
        local identifier = specification.identifier or os.uuid()
        local files      = specification.files      or { file.addsuffix(filename,"xhtml") }
        local root       = specification.root       or files[1]

        local epubname   = name
        local epubpath   = file.replacesuffix(name,"tree")
        local epubfile   = file.replacesuffix(name,"epub")
        local epubroot   = file.replacesuffix(name,"opf")

        lfs.mkdir(epubpath)
        lfs.mkdir(file.join(epubpath,"META-INF"))
        lfs.mkdir(file.join(epubpath,"OPS"))

        local used  = { }

        for i=1,#files do
            local filename = files[i]
            local suffix = file.suffix(filename)
            local mime = mimetypes[suffix]
            if mime then
                local idmaker = idmakers[suffix] or idmakers.default
                file.copy(filename,file.join(epubpath,"OPS",filename))
                used[#used+1] = format("<item id='%s' href='%s' media-type='%s'/>",idmaker(filename),filename,mime)
            end
        end

        container = format(container,epubroot)
        package   = format(package,identifier,identifier,concat(used,"\n"),file.removesuffix(root))

        io.savedata(file.join(epubpath,"mimetype"),mimetype)
        io.savedata(file.join(epubpath,"META-INF","container.xml"),container)
        io.savedata(file.join(epubpath,"OPS",epubroot),package)

        lfs.chdir(epubpath)

        os.remove(epubfile)

        os.execute(format("zip %s -X -0 %s",epubfile,"mimetype"))
        os.execute(format("zip %s -X -r %s",epubfile,"META-INF"))
        os.execute(format("zip %s -X -r %s",epubfile,"OPS"))

        lfs.chdir("..")

        application.report("epub archive: %s",file.join(epubpath,epubfile))

    end

end

--

if environment.argument("make") then
    scripts.epub.make()
else
    application.help()
end
