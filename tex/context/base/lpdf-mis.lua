if not modules then modules = { } end modules ['lpdf-mis'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Although we moved most pdf handling to the lua end, we didn't change
-- the overall approach. For instance we share all resources i.e. we
-- don't make subsets for each xform or page. The current approach is
-- quite efficient. A big difference between MkII and MkIV is that we
-- now use forward references. In this respect the MkII code shows that
-- it evolved over a long period, when backends didn't provide forward
-- referencing and references had to be tracked in multiple passes. Of
-- course there are a couple of more changes.

local next, tostring = next, tostring
local format = string.format
local texsprint, texset = tex.sprint, tex.set
local ctxcatcodes = tex.ctxcatcodes

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local copy_node = node.copy

local pdfliteral, register = nodes.pdfliteral, nodes.register

local pdfdictionary = lpdf.dictionary
local pdfarray      = lpdf.array
local pdfboolean    = lpdf.boolean
local pdfconstant   = lpdf.constant
local pdfreference  = lpdf.reference
local pdfunicode    = lpdf.unicode
local pdfstring     = lpdf.string

local pdfreserveobj   = pdf.reserveobj
local pdfimmediateobj = pdf.immediateobj

local tobasepoints = number.tobasepoints

local variables = interfaces.variables

lpdf.addtoinfo   ("Trapped", pdfboolean(false))
lpdf.addtocatalog("Version", pdfconstant(format("1.%s",tex.pdfminorversion)))

--

local positive  = register(pdfliteral("/GSpositive gs"))
local negative  = register(pdfliteral("/GSnegative gs"))
local overprint = register(pdfliteral("/GSoverprint gs"))
local knockout  = register(pdfliteral("/GSknockout gs"))

local function initializenegative()
    local a = pdfarray { 0, 1 }
    local g = pdfconstant("ExtGState")
    local d = pdfdictionary {
        FunctionType = 4,
        Range        = a,
        Domain       = a,
    }
    local negative = pdfdictionary { Type = g, TR = pdfreference(pdf.immediateobj("stream","1 exch sub",d())) }
    local positive = pdfdictionary { Type = g, TR = pdfconstant("Identity") }
    lpdf.adddocumentextgstate("GSnegative", pdfreference(pdfimmediateobj(tostring(negative))))
    lpdf.adddocumentextgstate("GSPositive", pdfreference(pdfimmediateobj(tostring(positive))))
    initializenegative = nil
end

local function initializeoverprint()
    local g = pdfconstant("ExtGState")
    local knockout  = pdfdictionary { Type = g, OP = false, OPM  = 0 }
    local overprint = pdfdictionary { Type = g, OP = true,  OPM  = 1 }
    lpdf.adddocumentextgstate("GSknockout",  pdfreference(pdfimmediateobj(tostring(knockout ))))
    lpdf.adddocumentextgstate("GSoverprint", pdfreference(pdfimmediateobj(tostring(overprint))))
    initializeoverprint = nil
end

function nodeinjections.overprint()
    if initializeoverprint then initializeoverprint() end
    return copy_node(overprint)
end
function nodeinjections.knockout ()
    if initializeoverprint then initializeoverprint() end
    return copy_node(knockout)
end

function nodeinjections.positive()
    if initializenegative then initializenegative() end
    return copy_node(positive)
end
function nodeinjections.negative()
    if initializenegative then initializenegative() end
    return copy_node(negative)
end

--

function codeinjections.addtransparencygroup()
    -- png: /CS /DeviceRGB /I true
    local d = pdfdictionary {
        S = pdfconstant("Transparency"),
        I = true,
        K = true,
    }
    lpdf.registerpagefinalizer(function() lpdf.addtopageattributes("Group",d) end) -- hm
end

-- actions (todo: store and update when changed)

local openpage, closepage, opendocument, closedocument

function codeinjections.flushdocumentactions(open,close)
    opendocument, closedocument = open, close
end

function codeinjections.flushpageactions(open,close)
    openpage, closepage = open, close
end

local function flushdocumentactions()
    if opendocument then
        lpdf.addtocatalog("OpenAction",lpdf.pdfaction(opendocument))
    end
    if closedocument then
        lpdf.addtocatalog("CloseAction",lpdf.pdfaction(closedocument))
    end
end

local function flushpageactions()
    if openpage or closepage then
        local d = pdfdictionary()
        if openpage then
            d.O = lpdf.pdfaction(openpage)
        end
        if closepage then
            d.C = lpdf.pdfaction(closepage)
        end
        lpdf.addtopageattributes("AA",d)
    end
end

lpdf.registerpagefinalizer(flushpageactions)
lpdf.registerdocumentfinalizer(flushdocumentactions)

--- info

function codeinjections.setupidentity(specification)
    local title = specification.title or "" if title ~= "" then
        lpdf.addtoinfo("Title", pdfunicode(title))
    end
    local subject = specification.subject or "" if subject ~= "" then
        lpdf.addtoinfo("Subject", pdfunicode(subject))
    end
    local author = specification.author or "" if author ~= "" then
        lpdf.addtoinfo("Author",  pdfunicode(author))
    end
    local creator = specification.creator or "" if creator ~= "" then
        lpdf.addtoinfo("Creator", pdfunicode(creator))
    end
    local date = specification.date or "" if date ~= "" then
        lpdf.addtoinfo("ModDate", pdfstring(date))
    end
    local keywords = specification.keywords or "" if keywords ~= "" then
        keywords = string.gsub(keywords, "[%s,]+", " ")
        lpdf.addtoinfo("Keywords",pdfunicode(keywords))
    end
    lpdf.addtoinfo("ID", pdfstring(format("%s.%s",tex.jobname,os.date("%Y%m%d.%H%M")))) -- needed for pdf/x
end

local function flushjavascripts()
    local t = javascripts.flushpreambles()
    if #t > 0 then
        local a = pdfarray()
        local pdf_javascript = pdfconstant("JavaScript")
        for i=1,#t do
            local name, script = t[i][1], t[i][2]
            local j = pdfdictionary {
                S  = pdf_javascript,
                JS = pdfreference(pdfimmediateobj("stream",script)),
            }
            a[#a+1] = pdfstring(name)
            a[#a+1] = pdfreference(pdfimmediateobj(tostring(j)))
        end
        lpdf.addtonames("JavaScript",pdfreference(pdfimmediateobj(tostring(pdfdictionary{ Names = a }))))
    end
end

lpdf.registerdocumentfinalizer(flushjavascripts)

-- -- --

local pagespecs = {
    [variables.max]         = { "FullScreen", false, false },
    [variables.bookmark]    = { "UseOutlines", false, false },
    [variables.fit]         = { "UseNone", false, true },
    [variables.doublesided] = { "UseNone", "TwoColumnRight", true },
    [variables.singlesided] = { "UseNone", false, false },
    [variables.default]     = { "UseNone", "auto", false },
    [variables.auto]        = { "UseNone", "auto", false },
    [variables.none]        = { false, false, false },
}

local pagespec, topoffset, leftoffset, height, width, doublesided = "default", 0, 0, 0, 0, false

function codeinjections.setupcanvas(specification)
    local paperheight = specification.paperheight
    local paperwidth  = specification.paperwidth
    local paperdouble = specification.doublesided
    if paperheight then
        texset('global','pdfpageheight',paperheight)
    end
    if paperwidth then
        texset('global','pdfpagewidth',paperwidth)
    end
    pagespec    = specification.mode       or pagespec
    topoffset   = specification.topoffset  or 0
    leftoffset  = specification.leftoffset or 0
    height      = specification.height     or tex.pdfpageheight
    width       = specification.width      or tex.pdfpagewidth
    if paperdouble ~= nil then
        doublesided = paperdouble
    end
end

local function documentspecification()
    local spec = pagespecs[pagespec] or pagespecs[variables.default]
    local mode, layout, fit = spec[1], spec[2], spec[3]
    if layout == variables.auto then
        if doublesided then
            spec = pagespecs.doublesided
            mode, layout, fit = spec[1], spec[2], spec[3]
        else
            layout = false
        end
    end
    mode = mode and pdfconstant(mode)
    layout = layout and pdfconstant(layout)
    fit = fit and pdfdictionary { FitWindow = true }
    if layout then
        lpdf.addtocatalog("PageLayout",layout)
    end
    if mode then
        lpdf.addtocatalog("PageMode",mode)
    end
    if fit then
        lpdf.addtocatalog("ViewerPreferences",fit)
    end
end

local factor = number.dimenfactors.bp

local function pagespecification()
    local pageheight = tex.pdfpageheight
    local box = pdfarray { -- can be cached
        factor * (leftoffset),
        factor * (pageheight-topoffset-height),
        factor * (width-leftoffset),
        factor * (pageheight-topoffset),
    }
    lpdf.addtopageattributes("CropBox",box) -- mandate for rendering
    lpdf.addtopageattributes("TrimBox",box) -- mandate for pdf/x
 -- lpdf.addtopageattributes("BleedBox",box)
 -- lpdf.addtopageattributes("ArtBox",box)
end

lpdf.registerpagefinalizer(pagespecification)
lpdf.registerdocumentfinalizer(documentspecification)
