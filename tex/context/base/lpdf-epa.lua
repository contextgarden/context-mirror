if not modules then modules = { } end modules ['lpdf-epa'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a rather experimental feature and the code will probably
-- change.

local type, tonumber = type, tonumber
local format = string.format

local trace_links = false  trackers.register("figures.links", function(v) trace_links = v end)

local report_link = logs.new("backend","merging")

local backends, lpdf = backends, lpdf

local variables      = interfaces.variables
local codeinjections = backends.pdf.codeinjections

local layerspec = { -- predefining saves time
    "epdflinks"
}

local function add_link(x,y,w,h,destination,what)
    if trace_links then
        report_link("dx: % 4i, dy: % 4i, wd: % 4i, ht: % 4i, destination: %s, type: %s",x,y,w,h,destination,what)
    end
    local locationspec = { -- predefining saves time
        x      = x .. "bp",
        y      = y .. "bp",
        preset = "leftbottom",
    }
    local buttonspec = {
        width  = w .. "bp",
        height = h .. "bp",
        offset = variables.overlay,
        frame  = trace_links and variables.on or variables.off,
    }
    context.setlayer (
        layerspec,
        locationspec,
        function() context.button ( buttonspec, "", { destination } ) end
     -- context.nested.button(buttonspec, "", { destination }) -- time this
    )
end

local function link_goto(x,y,w,h,document,annotation,pagesdata,pagedata,namespace)
 -- print("border",table.unpack(annotation.Border.all))
 -- print("flags",annotation.F)
 -- print("pagenumbers",pagedata.reference.num,destination[1].num)
 -- print("pagerefs",pagedata.number,pagesdata.references[destination[1].num])
    local destination = annotation.A.D -- [ 18 0 R /Fit ]
    local what = "page"
    if type(destination) == "string" then
        local destinations = document.Catalog.Destinations
        local wanted = destinations[destination]
        destination = wanted and wanted.D
        if destination then what = "named" end
    end
    local whereto = destination and destination[1] -- array
    if whereto and whereto.num then
        local currentpage = pagedata.number
        local destinationpage = pagesdata.references[whereto.num]
        add_link(x,y,w,h,namespace .. destinationpage,what)
        return
    end
end

local function link_uri(x,y,w,h,document,annotation)
    local url = annotation.A.URI
    if url then
        add_link(x,y,w,h,format("url(%s)",url),"url")
    end
end

local function link_file(x,y,w,h,document,annotation)
    local filename = annotation.A.F
    if filename then
        local destination = annotation.A.D
        if not destination then
            add_link(x,y,w,h,format("file(%s)",filename),"file")
        elseif type(destination) == "string" then
            add_link(x,y,w,h,format("%s::%s",filename,destination),"file (named)")
        else
            destination = destination[1] -- array
            if tonumber(destination) then
                add_link(x,y,w,h,format("%s::page(%s)",filename,destination),"file (page)")
            else
                add_link(x,y,w,h,format("file(%s)",filename),"file")
            end
        end
    end
end

function codeinjections.mergereferences(specification)
    if figures and not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local document = lpdf.load(fullname)
        if document then
            local pagenumber  = specification.page    or 1
            local xscale      = specification.yscale  or 1
            local yscale      = specification.yscale  or 1
            local size        = specification.size    or "crop" -- todo
            local pagesdata   = document.Catalog.Pages
            local pagedata    = pagesdata[pagenumber]
            local annotations = pagedata.Annots
            local namespace   = format("lpdf-epa-%s-",file.removesuffix(file.basename(fullname)))
            local reference   = namespace .. pagenumber
            if annotations.size > 0 then
                local llx, lly, urx, ury = table.unpack(pagedata.MediaBox.all)
                local width, height = xscale * (urx - llx), yscale * (ury - lly) -- \\overlaywidth, \\overlayheight
                context.definelayer( { "epdflinks" }, { height = height.."bp" , width = width.."bp" })
                for i=1,annotations.size do
                    local annotation = annotations[i]
                    local subtype = annotation.Subtype
                    local a_llx, a_lly, a_urx, a_ury = table.unpack(annotation.Rect.all)
                    local x, y = xscale * (a_llx -   llx), yscale * (a_lly -   lly)
                    local w, h = xscale * (a_urx - a_llx), yscale * (a_ury - a_lly)
                    if subtype  == "Link" then
                        local linktype = annotation.A.S
                        if linktype == "GoTo" then
                            link_goto(x,y,w,h,document,annotation,pagesdata,pagedata,namespace)
                        elseif linktype == "GoToR" then
                            link_file(x,y,w,h,document,annotation)
                        elseif linktype == "URI" then
                            link_uri(x,y,w,h,document,annotation)
                        elseif trace_links then
                            report_link("unsupported link annotation '%s'",linktype)
                        end
                    elseif trace_links then
                        report_link("unsupported annotation '%s'",subtype)
                    end
                end
                context.flushlayer { "epdflinks" }
             -- context("\\gdef\\figurereference{%s}",reference) -- global
                context.setgvalue("figurereference",reference) -- global
                if trace_links then
                    report_link("setting figure reference to '%s'",reference)
                end
                specification.reference = reference
                return namespace
            end
        end
    end
    return ""-- no namespace, empty, not nil
end

function codeinjections.mergeviewerlayers(specification)
    if not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local document = lpdf.load(fullname)
        if document then
            local pagenumber = specification.page or 1
            local pagesdata  = document.Catalog.Pages
            local pagedata   = pagesdata[pagenumber]
            local resources  = pagedata.Resources
--~             table.print(resources)
--~             local properties = resources.Properties
        end
    end
end
