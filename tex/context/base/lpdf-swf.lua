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
local pdfimmediateobject = lpdf.immediateobject

local variables          = interfaces.variables

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

local factor = number.dimenfactors.bp

function img.package(image)
    local boundingbox = image.bbox
    local imagetag    = "Im" .. image.index
    local resources   = pdfdictionary {
        ProcSet = pdfarray {
            pdfconstant("PDF"),
            pdfconstant("ImageC")
        },
        Resources = pdfdictionary {
            XObject = pdfdictionary {
                [imagetag] = pdfreference(image.objnum)
            }
        }
    }
    local width = boundingbox[3]
    local height = boundingbox[4]
    local xform = img.scan {
        attr   = resources(),
        stream = format("%s 0 0 %s 0 0 cm /%s Do",width,height,imagetag),
        bbox   = { 0, 0, width/factor, height/factor },
    }
    img.immediatewrite(xform)
    return xform
end


local function insertswf(spec)

    local width     = spec.width
    local height    = spec.height
    local filename  = spec.foundname
    local resources = spec.resources
    local display   = spec.display
    local controls  = spec.controls

    local resources = resources and parametersets[resources]

    if display == nil or display == "" then
        display = resources.display
    end
    if controls == nil or controls == "" then
        controls = resources.controls
    end

    controls = toboolean(variables[controls] or controls,true)

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

    local flashreference = pdfreference(pdfimmediateobject(tostring(flash)))

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

    local configurationreference = pdfreference(pdfimmediateobject(tostring(configuration)))

    local activation = pdfdictionary {
        Type          = pdfconstant("RichMediaActivation"),
        Condition     = pdfconstant(activations[resources.open]),
        Configuration = flashreference,
        Animation     = pdfdictionary {
            Subtype   = pdfconstant("Linear"),
            Speed     = 1,
            Playcount = 1,
        },
        Presentation  = pdfdictionary {
            PassContextClick = false,
            Style            = pdfconstant("Embedded"),
            Toolbar          = controls or false,
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
        Condition = pdfconstant(deactivations[resources.close]),
    }

    local richmediasettings = pdfdictionary {
        Type         = pdfconstant("RichMediaSettings"),
        Activation   = activation,
        Deactivation = deactivation,
    }

    local settingsreference = pdfreference(pdfimmediateobject(tostring(richmediasettings)))

    local appearance

    if display and display ~= "" then
        local figure = codeinjections.getdisplayfigure { name = display, width = width, height = height }
        if figure then
            local image = img.package(figure.status.private)
            local reference = image.objnum
            appearance = reference and pdfdictionary { N = pdfreference(reference) } or nil
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
    --  factor    = spec.factor,
        display   = spec.display,
        controls  = spec.controls,
    --  label     = spec.label,
        resources = spec.resources,
    }
    node.write(pdfannotation_node(spec.width,spec.height,0,annotation()))
end
