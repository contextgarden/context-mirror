if not modules then modules = { } end modules ['lpdf-swf'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code is based on tests by Luigi Scarso. His prototype
-- was using tex code. This is the official implementation.

local format, gsub = string.format, string.gsub

local backends, lpdf = backends, lpdf

local pdfconstant        = lpdf.constant
local pdfboolean         = lpdf.boolean
local pdfstring          = lpdf.string
local pdfunicode         = lpdf.unicode
local pdfdictionary      = lpdf.dictionary
local pdfarray           = lpdf.array
local pdfnull            = lpdf.null
local pdfreference       = lpdf.reference
local pdfflushobject     = lpdf.flushobject

local checkedkey         = lpdf.checkedkey

local codeinjections     = backends.pdf.codeinjections
local nodeinjections     = backends.pdf.nodeinjections

local pdfannotation_node = nodes.pool.pdfannotation

local trace_swf = false  trackers.register("backend.swf", function(v) trace_swf = v end)

local report_swf = logs.reporter("backend","swf")

local activations = {
    click = "XA",
    page  = "PO",
    focus = "PV",
}

local deactivations = {
    click = "XD",
    page  = "PI",
    focus = "PC",
}

table.setmetatableindex(activations,  function() return activations  .click end)
table.setmetatableindex(deactivations,function() return deactivations.focus end)

local function insertswf(spec)

    local width     = spec.width
    local height    = spec.height
    local filename  = spec.foundname
    local resources = spec.resources
    local display   = spec.display
    local controls  = spec.controls

    local resources = resources and parametersets[resources]
    local display   = display   and parametersets[display]
    local controls  = controls  and parametersets[controls] -- not yet used

    local preview   = checkedkey(display,"preview","string")
    local toolbar   = checkedkey(display,"toolbar","boolean")

    local embeddedreference = codeinjections.embedfile { file = filename }

    local flash = pdfdictionary {
        Subtype   = pdfconstant("Flash"),
        Instances = pdfarray {
            pdfdictionary {
                Asset  = embeddedreference,
                Params = pdfdictionary {
                    Binding = pdfconstant("Background") -- Foreground makes swf behave erratic
                }
            },
        },
    }

    local flashreference = pdfreference(pdfflushobject(flash))

    local configuration = pdfdictionary {
        Configurations = pdfarray { flashreference },
        Assets         = pdfdictionary {
            Names = pdfarray {
                pdfstring(filename),
                embeddedreference,
            }
        },
    }

    -- todo: check op subpath figuur (relatief)

    if resources then
        local names = configuration.Assets.Names
        local root = file.dirname(filename)
        local prefix = format("^%s/",root)
        local function add(filename,strip)
            local filename = gsub(filename,"%./","")
            local usedname = strip and gsub(filename,prefix,"") -- always when relative
            local embeddedreference = codeinjections.embedfile {
                file     = filename,
                usedname = usedname,
                keepdir  = true,
            }
            names[#names+1] = pdfstring(filename)
            names[#names+1] = embeddedreference
            if trace_swf then
                if usedname == filename then
                    report_swf("embedding file '%s'",filename)
                else
                    report_swf("embedding file '%s' as '%s'",filename,usedname)
                end
            end
        end
        local relativepaths = resources.relativepaths
        if relativepaths then
            if trace_swf then
                report_swf("checking %s relative paths",#relativepaths)
            end
            for i=1,#relativepaths do
                local relativepath = relativepaths[i]
                if trace_swf then
                    report_swf("checking path '%s' relative to '%s'",relativepath,root)
                end
                local path = file.join(root,relativepath)
                local files = dir.glob(path .. "/**")
                for i=1,#files do
                    add(files[i],true)
                end
            end
        end
        local paths = resources.paths
        if paths then
            if trace_swf then
                report_swf("checking %s paths",#paths)
            end
            for i=1,#paths do
                local path = paths[i]
                if trace_swf then
                    report_swf("checking path '%s'",path)
                end
                local files = dir.glob(path .. "/**")
                for i=1,#files do
                    add(files[i],false)
                end
            end
        end
        local relativefiles = resources.relativefiles
        if relativefiles then
            if trace_swf then
                report_swf("checking %s relative files",#relativefiles)
            end
            for i=1,#relativefiles do
                add(relativefiles[i],true)
            end
        end
        local files = resources.files
        if files then
            if trace_swf then
                report_swf("checking %s files",#files)
            end
            for i=1,#files do
                add(files[i],false)
            end
        end
    end

    local opendisplay  = display and display.open  or false
    local closedisplay = display and display.close or false

    local configurationreference = pdfreference(pdfflushobject(configuration))

    local activation = pdfdictionary {
        Type          = pdfconstant("RichMediaActivation"),
        Condition     = pdfconstant(activations[opendisplay]),
        Configuration = flashreference,
        Animation     = pdfdictionary {
            Subtype   = pdfconstant("Linear"),
            Speed     = 1,
            Playcount = 1,
        },
        Presentation  = pdfdictionary {
            PassContextClick = false,
            Style            = pdfconstant("Embedded"),
            Toolbar          = toolbar,
            NavigationPane   = false,
            Transparent      = true,
            Window           = pdfdictionary {
                Type     = pdfconstant("RichMediaWindow"),
                Width    = pdfdictionary {
                    Default = 100,
                    Min     = 100,
                    Max     = 100,
                },
                Height   = pdfdictionary {
                    Default = 100,
                    Min     = 100,
                    Max     = 100,
                },
                Position = pdfdictionary {
                    Type    = pdfconstant("RichMediaPosition"),
                    HAlign  = pdfconstant("Near"),
                    VAlign  = pdfconstant("Near"),
                    HOffset = 0,
                    VOffset = 0,
                }
            }
        },
     -- View
     -- Scripts
    }

    local deactivation = pdfdictionary {
        Type      = pdfconstant("RichMediaDeactivation"),
        Condition = pdfconstant(deactivations[closedisplay]),
    }

    local richmediasettings = pdfdictionary {
        Type         = pdfconstant("RichMediaSettings"),
        Activation   = activation,
        Deactivation = deactivation,
    }

    local settingsreference = pdfreference(pdfflushobject(richmediasettings))

    local appearance

    if preview then
        local figure = codeinjections.getpreviewfigure { name = preview, width = width, height = height }
        if figure then
            local image = img.package(figure.status.private)
            appearance = pdfdictionary { N = pdfreference(image.objnum) }
        end
    end

    local annotation = pdfdictionary {
        Subtype           = pdfconstant("RichMedia"),
        RichMediaContent  = configurationreference,
        RichMediaSettings = settingsreference,
        AP                = appearance,
    }

    return annotation, nil, nil

end

function backends.pdf.nodeinjections.insertswf(spec)
    local annotation, preview, ref = insertswf {
        foundname = spec.foundname,
        width     = spec.width,
        height    = spec.height,
        display   = spec.display,
        controls  = spec.controls,
        resources = spec.resources,
     -- factor    = spec.factor,
     -- label     = spec.label,
    }
    context(pdfannotation_node(spec.width,spec.height,0,annotation())) -- the context wrap is probably also needed elsewhere
end
