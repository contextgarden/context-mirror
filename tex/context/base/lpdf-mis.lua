if not modules then modules = { } end modules ['lpdf-mis'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
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

local pdfdictionary      = lpdf.dictionary
local pdfarray           = lpdf.array
local pdfboolean         = lpdf.boolean
local pdfconstant        = lpdf.constant
local pdfreference       = lpdf.reference
local pdfunicode         = lpdf.unicode
local pdfverbose         = lpdf.verbose
local pdfstring          = lpdf.string
local pdfflushobject     = lpdf.flushobject
local pdfimmediateobject = lpdf.immediateobject

local tobasepoints = number.tobasepoints
local variables    = interfaces.variables

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
    local negative = pdfdictionary { Type = g, TR = pdfreference(pdfimmediateobject("stream","1 exch sub",d())) }
    local positive = pdfdictionary { Type = g, TR = pdfconstant("Identity") }
    lpdf.adddocumentextgstate("GSnegative", pdfreference(pdfflushobject(negative)))
    lpdf.adddocumentextgstate("GSPositive", pdfreference(pdfflushobject(positive)))
    initializenegative = nil
end

local function initializeoverprint()
    local g = pdfconstant("ExtGState")
    local knockout  = pdfdictionary { Type = g, OP = false, OPM  = 0 }
    local overprint = pdfdictionary { Type = g, OP = true,  OPM  = 1 }
    lpdf.adddocumentextgstate("GSknockout",  pdfreference(pdfflushobject(knockout)))
    lpdf.adddocumentextgstate("GSoverprint", pdfreference(pdfflushobject(overprint)))
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
        lpdf.addtocatalog("OpenAction",lpdf.action(opendocument))
    end
    if closedocument then
        lpdf.addtocatalog("CloseAction",lpdf.action(closedocument))
    end
end

local function flushpageactions()
    if openpage or closepage then
        local d = pdfdictionary()
        if openpage then
            d.O = lpdf.action(openpage)
        end
        if closepage then
            d.C = lpdf.action(closepage)
        end
        lpdf.addtopageattributes("AA",d)
    end
end

lpdf.registerpagefinalizer(flushpageactions,"page actions")
lpdf.registerdocumentfinalizer(flushdocumentactions,"document actions")

--- info

function codeinjections.setupidentity(specification)
    local title = specification.title or ""
    if title ~= "" then
        lpdf.addtoinfo("Title", pdfunicode(title), title)
    end
    local subject = specification.subject or ""
    if subject ~= "" then
        lpdf.addtoinfo("Subject", pdfunicode(subject), subject)
    end
    local author = specification.author or ""
    if author ~= "" then
        lpdf.addtoinfo("Author",  pdfunicode(author), author) -- '/Author' in /Info, 'Creator' in XMP
    end
    local creator = specification.creator or ""
    if creator ~= "" then
        lpdf.addtoinfo("Creator", pdfunicode(creator), creator) -- '/Creator' in /Info, 'CreatorTool' in XMP
    end
    lpdf.addtoinfo("CreationDate", pdfstring(lpdf.pdftimestamp(lpdf.timestamp())))
    local date = specification.date or ""
    local pdfdate = lpdf.pdftimestamp(date)
    if pdfdate then
        lpdf.addtoinfo("ModDate", pdfstring(pdfdate), date)
    else
        -- users should enter the date in 2010-01-19T23:27:50+01:00 format
        -- and if not provided that way we use the creation time instead
        date = lpdf.timestamp()
        lpdf.addtoinfo("ModDate", pdfstring(lpdf.pdftimestamp(date)), date)
    end
    local keywords = specification.keywords or ""
    if keywords ~= "" then
        keywords = string.gsub(keywords, "[%s,]+", " ")
        lpdf.addtoinfo("Keywords",pdfunicode(keywords), keywords)
    end
    local id = lpdf.id()
    lpdf.addtoinfo("ID", pdfstring(id), id) -- needed for pdf/x
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
                JS = pdfreference(pdfimmediateobject("stream",script)),
            }
            a[#a+1] = pdfstring(name)
            a[#a+1] = pdfreference(pdfflushobject(j))
        end
        lpdf.addtonames("JavaScript",pdfreference(pdfflushobject(pdfdictionary{ Names = a })))
    end
end

lpdf.registerdocumentfinalizer(flushjavascripts,"javascripts")

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
    if spec then
        local mode, layout, fit = spec[1], spec[2], spec[3]
        if layout == variables.auto then
            if doublesided then
                spec = pagespecs[variables.doublesided] -- to be checked voor interfaces
                if spec then
                    mode, layout, fit = spec[1], spec[2], spec[3]
                end
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
        lpdf.addtoinfo   ("Trapped", pdfconstant("False")) -- '/Trapped' in /Info, 'Trapped' in XMP
        lpdf.addtocatalog("Version", pdfconstant(format("1.%s",tex.pdfminorversion)))
    end
end

-- temp hack: the mediabox is not under our control and has a precision of 4 digits

local factor = number.dimenfactors.bp

local function boxvalue(n) -- we could share them
    return pdfverbose(format("%0.4f",factor * n))
end

local function pagespecification()
    local pageheight = tex.pdfpageheight
    local box = pdfarray { -- can be cached
        boxvalue(leftoffset),
        boxvalue(pageheight-topoffset-height),
        boxvalue(width-leftoffset),
        boxvalue(pageheight-topoffset),
    }
    lpdf.addtopageattributes("CropBox",box) -- mandate for rendering
    lpdf.addtopageattributes("TrimBox",box) -- mandate for pdf/x
 -- lpdf.addtopageattributes("BleedBox",box)
 -- lpdf.addtopageattributes("ArtBox",box)
end

lpdf.registerpagefinalizer(pagespecification,"page specification")
lpdf.registerdocumentfinalizer(documentspecification,"document specification")

-- Page Label support ...
--
-- In principle we can also support /P (prefix) as we can just use the verbose form
-- and we can then forget about the /St (start) as we don't care about those few
-- extra bytes due to lack of collapsing. Anyhow, for that we need a stupid prefix
-- variant and that's not on the agenda now.

local map = {
    numbers       = "D",
    Romannumerals = "R",
    romannumerals = "r",
    Characters    = "A",
    characters    = "a",
}

local function featurecreep()
    local pages, lastconversion, list = jobpages.tobesaved, nil, pdfarray()
    local getstructureset = structure.sets.get
    for i=1,#pages do
        local p = pages[i]
        local numberdata = p.numberdata
        if numberdata then
            local conversionset = numberdata.conversionset
            if conversionset then
                local conversion = getstructureset("structure:conversions",p.block,conversionset,1,"numbers")
                if conversion ~= lastconversion then
                    lastconversion = conversion
                    list[#list+1] = i - 1 -- pdf starts numbering at 0
                    list[#list+1] = pdfdictionary { S = pdfconstant(map[conversion] or map.numbers) }
                end
            end
        end
        if not lastconversion then
            lastconversion = "numbers"
            list[#list+1] = i - 1 -- pdf starts numbering at 0
            list[#list+1] = pdfdictionary { S = pdfconstant(map.numbers) }
        end
    end
    lpdf.addtocatalog("PageLabels", pdfdictionary { Nums = list })
end

lpdf.registerdocumentfinalizer(featurecreep,"featurecreep")
