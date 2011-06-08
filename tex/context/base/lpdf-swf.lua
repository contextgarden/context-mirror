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
    local controls  = controls  and parametersets[controls]     -- not yet used

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

    if resources then
        local names = configuration.Assets.Names
        local function add(filename)
            local filename = gsub(filename,"%./","")
            local embeddedreference = codeinjections.embedfile { file = filename, keepdir = true }
            names[#names+1] = pdfstring(filename)
            names[#names+1] = embeddedreference
        end
        local paths = resources.paths
        if paths then
            for i=1,#paths do
                local files = dir.glob(paths[i] .. "/**")
                for i=1,#files do
                    add(files[i])
                end
            end
        end
        local files = resources.files
        if files then
            for i=1,#files do
                add(files[i])
            end
        end
    end

    local configurationreference = pdfreference(pdfflushobject(configuration))

    local activation = pdfdictionary {
        Type          = pdfconstant("RichMediaActivation"),
        Condition     = pdfconstant(activations[display.open]),
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
        Condition = pdfconstant(deactivations[display.close]),
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
    node.write(pdfannotation_node(spec.width,spec.height,0,annotation()))
end
