if not modules then modules = { } end modules ['lpdf-swf'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code is based on tests by Luigi Scarso. His prototype
-- was using tex code. This is the official implementation.

local format = string.format

local pdfconstant        = lpdf.constant
local pdfboolean         = lpdf.boolean
local pdfstring          = lpdf.string
local pdfunicode         = lpdf.unicode
local pdfdictionary      = lpdf.dictionary
local pdfarray           = lpdf.array
local pdfnull            = lpdf.null
local pdfreference       = lpdf.reference
local pdfimmediateobject = lpdf.immediateobject

function backends.pdf.helpers.insertswf(spec)

    local width, height, filename = spec.width, spec.height, spec.foundname

    local eref = backends.codeinjections.embedfile(filename)

    local flash = pdfdictionary {
        Subtype   = pdfconstant("Flash"),
        Instances = pdfarray {
            pdfdictionary {
                Asset  = eref,
                Params = pdfdictionary {
                    Binding = pdfconstant("Foreground")
                }
            },
        },
    }

    local fref = pdfreference(pdfimmediateobject(tostring(flash)))

    local configuration = pdfdictionary {
        Configurations = pdfarray { fref },
        Assets         = pdfdictionary {
            Names = pdfarray {
                pdfstring(filename),
                eref,
            }
        },
    }

    local cref = pdfreference(pdfimmediateobject(tostring(configuration)))

    local activation = pdfdictionary {
        Activation = pdfdictionary {
            Type          = pdfconstant("RichMediaActivation"),
            Condition     = pdfconstant("PO"),
            Configuration = fref,
            Animation     = pdfdictionary {
                Subtype   = pdfconstant("Linear"),
                Speed     = 1,
                Playcount = 1,
            },
            Deactivation  = pdfdictionary {
                Type      = pdfconstant("RichMediaDeactivation"),
                Condition = pdfconstant("XD"),
            },
            Presentation  = pdfdictionary {
                PassContextClick = false,
                Style            = pdfconstant("Embedded"),
                Toolbar          = false,
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
            }
        }
    }

    local aref = pdfreference(pdfimmediateobject(tostring(activation)))

    local annotation = pdfdictionary {
       Subtype           = pdfconstant("RichMedia"),
       RichMediaContent  = cref,
       RichMediaSettings = aref,
    }

    return annotation, nil, nil

end
