if not modules then modules = { } end modules ['lpdf-wid'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, gsub, find = string.format, string.gmatch, string.gsub, string.find
local texsprint, ctxcatcodes, texbox, texcount = tex.sprint, tex.ctxcatcodes, tex.box, tex.count
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash = utilities.parsers.settings_to_hash

local report_media = logs.new("media")

local backends, lpdf, nodes = backends, lpdf, nodes

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local executers = structures.references.executers
local variables = interfaces.variables

local pdfconstant          = lpdf.constant
local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfreference         = lpdf.reference
local pdfunicode           = lpdf.unicode
local pdfstring            = lpdf.string
local pdfcolorspec         = lpdf.colorspec
local pdfflushobject       = lpdf.flushobject
local pdfreserveannotation = lpdf.reserveannotation
local pdfreserveobject     = lpdf.reserveobject
local pdfimmediateobject   = lpdf.immediateobject
local pdfpagereference     = lpdf.pagereference

local nodepool             = nodes.pool

local pdfannotation_node   = nodepool.pdfannotation

local hpack_node, write_node = node.hpack, node.write

local pdf_border = pdfarray { 0, 0, 0 } -- can be shared

-- symbols

local presets = { } -- xforms

function codeinjections.registersymbol(name,n)
    presets[name] = pdfreference(n)
end

function codeinjections.registeredsymbol(name)
    return presets[name]
end

function codeinjections.presetsymbol(symbol)
    if not presets[symbol] then
        texsprint(ctxcatcodes,format("\\predefinesymbol[%s]",symbol))
    end
end

function codeinjections.presetsymbollist(list)
    if list then
        for symbol in gmatch(list,"[^, ]+") do
            codeinjections.presetsymbol(symbol)
        end
    end
end

-- comments

local symbols = {
    New          = pdfconstant("Insert"),
    Insert       = pdfconstant("Insert"),
    Balloon      = pdfconstant("Comment"),
    Comment      = pdfconstant("Comment"),
    Text         = pdfconstant("Note"),
    Addition     = pdfconstant("NewParagraph"),
    NewParagraph = pdfconstant("NewParagraph"),
    Help         = pdfconstant("Help"),
    Paragraph    = pdfconstant("Paragraph"),
    Key          = pdfconstant("Key"),
    Graph        = pdfconstant("Graph"),
    Paperclip    = pdfconstant("Paperclip"),
    Attachment   = pdfconstant("Attachment"),
    Tag          = pdfconstant("Tag"),
}

symbols[variables.normal] = pdfconstant("Note")

local nofcomments, usepopupcomments, stripleading = 0, true, true

local function analyzesymbol(symbol)
    if not symbol or symbol == "" then
        return symbols.normal, nil
    elseif symbols[symbol] then
        return symbols[symbol], nil
    else
        local set = settings_to_array(symbol)
        local normal, down = set[1], set[2]
        if normal then
            normal = codeinjections.registeredsymbol(down or normal)
        end
        if down then
            down = codeinjections.registeredsymbol(normal)
        end
        if down or normal then
            return nil, pdfdictionary {
                N = normal,
                D = down,
            }
        end
    end
end

local function analyzelayer(layer)
    -- todo:  (specification.layer ~= "" and pdfreference(specification.layer)) or nil, -- todo: ref to layer
end

function codeinjections.registercomment(specification)
    nofcomments = nofcomments + 1
    local text = buffers.collect(specification.buffer)
    if stripleading then
        text = gsub(text,"[\n\r] *","\n")
    end
    local name, appearance = analyzesymbol(specification.symbol)
    local d = pdfdictionary {
        Subtype   = pdfconstant("Text"),
        Open      = specification.open,
        Contents  = pdfunicode(text),
        T         = (specification.title ~= "" and pdfunicode(specification.title)) or nil,
        C         = pdfcolorspec(specification.colormodel,specification.colorvalue),
        OC        = analyzelayer(specification.layer),
        Name      = name,
        AP        = appearance,
    }
    --
    -- watch the nice feed back to tex hack
    --
    -- we can consider replacing nodes by user nodes that do a latelua
    -- so that we get rid of all annotation whatsits
    if usepopupcomments then
        local nd = pdfreserveannotation()
        local nc = pdfreserveannotation()
        local c = pdfdictionary {
            Subtype = pdfconstant("Popup"),
            Parent  = pdfreference(nd),
        }
        d.Popup = pdfreference(nc)
        texbox["commentboxone"] = hpack_node(pdfannotation_node(0,0,0,d(),nd)) -- current dir
        texbox["commentboxtwo"] = hpack_node(pdfannotation_node(specification.width,specification.height,0,c(),nc)) -- current dir
    else
        texbox["commentboxone"] = hpack_node(pdfannotation_node(0,0,0,d())) -- current dir
        texbox["commentboxtwo"] = nil
    end
end

--

local nofattachments, attachments, filestreams = 0, { }, { }

-- todo: hash and embed once

function codeinjections.embedfile(filename)
    local r = filestreams[filename]
    if r == false then
        return nil
    elseif r then
        return r
    elseif not lfs.isfile(filename) then
        interfaces.showmessage("interactions",5,filename)
        filestreams[filename] = false
        return nil
    else
        local basename = file.basename(filename)
        local a = pdfdictionary { Type = pdfconstant("EmbeddedFile") }
        local f = pdfimmediateobject("streamfile",filename,a())
        local d = pdfdictionary {
            Type = pdfconstant("Filespec"),
            F    = pdfstring(newname or basename),
            UF   = pdfstring(newname or basename),
            EF   = pdfdictionary { F = pdfreference(f) },
        }
        local r = pdfreference(pdfflushobject(d))
        filestreams[filename] = r
        return r
    end
end

function codeinjections.attachfile(specification)
    local attachment = interactions.attachments.attachment(specification.label)
    if not attachment then
        -- todo: message
        return
    end
    local filename = attachment.filename
    if not filename or filename == "" then
        -- todo: message
        return
    end
    nofattachments = nofattachments + 1
    local label   = attachment.label   or ""
    local title   = attachment.title   or ""
    local newname = attachment.newname or ""
    if label   == "" then label   = filename end
    if title   == "" then title   = label    end
    if newname == "" then newname = filename end
    local aref = attachments[label]
    if not aref then
        aref = codeinjections.embedfile(filename,newname)
        attachments[label] = aref
    end
    local name, appearance = analyzesymbol(specification.symbol)
    local d = pdfdictionary {
        Subtype  = pdfconstant("FileAttachment"),
        FS       = aref,
        Contents = pdfunicode(title),
        Name     = name,
        AP       = appearance,
        OC       = analyzelayer(specification.layer),
        C        = pdfcolorspec(specification.colormodel,specification.colorvalue),
    }
    -- as soon as we can ask for the dimensions of an xform we can
    -- use them here
    local width  = specification.width  or 0
    local height = specification.height or 0
    local depth  = specification.depth  or 0
    write_node(pdfannotation_node(width,height,depth,d()))
end

function codeinjections.attachmentid(filename)
    return filestreams[filename]
end

-- rendering stuff
--
-- object_1  -> <</Type /Rendition /S /MR /C << /Type /MediaClip ... >> >>
-- object_2  -> <</Type /Rendition /S /MR /C << /Type /MediaClip ... >> >>
-- rendering -> <</Type /Rendition /S /MS [objref_1 objref_2]>>
--
-- we only work foreward here
-- annotation is to be packed at the tex end

-- aiff audio/aiff
-- au   audio/basic
-- avi  video/avi
-- mid  audio/midi
-- mov  video/quicktime
-- mp3  audio/x-mp3 (mpeg)
-- mp4  audio/mp4
-- mp4  video/mp4
-- mpeg video/mpeg
-- smil application/smil
-- swf  application/x-shockwave-flash

-- P  media play parameters (evt /BE for controls etc
-- A  boolean (audio)
-- C  boolean (captions)
-- O  boolean (overdubs)
-- S  boolean (subtitles)
-- PL pdfconstant("ADBE_MCI"),

-- F        = flags,
-- T        = title,
-- Contents = rubish,
-- AP       = irrelevant,

-- sound is different, no window (or zero) so we need to collect them and
-- force them if not set

local ms, mu, mf = { }, { }, { }

local function delayed(label)
    local a = pdfreserveannotation()
    mu[label] = a
    return pdfreference(a)
end

local function insertrenderingwindow(specification)
    local label = specification.label
--~     local openpage = specification.openpage
--~     local closepage = specification.closepage
    if specification.options == variables.auto then
        if openpageaction then
            -- \handlereferenceactions{\v!StartRendering{#2}}
        end
        if closepageaction then
            -- \handlereferenceactions{\v!StopRendering {#2}}
        end
    end
    local actions = nil
    if openpage or closepage then
        actions = pdfdictionary {
            PO = (openpage  and lpdf.action(openpage )) or nil,
            PC = (closepage and lpdf.action(closepage)) or nil,
        }
    end
    local page = tonumber(specification.page) or texcount.realpageno -- todo
    local r = mu[label] or pdfreserveannotation() -- why the reserve here?
    local a = pdfdictionary {
        S  = pdfconstant("Rendition"),
        R  = mf[label],
        OP = 0,
        AN = pdfreference(r),
    }
    local d = pdfdictionary {
        Subtype = pdfconstant("Screen"),
        P       = pdfreference(pdfpagereference(page)),
        A       = a, -- needed in order to make the annotation clickable (i.e. don't bark)
        Border  = pdf_border,
        AA      = actions,
    }
    write_node(pdfannotation_node(specification.width or 0,specification.height or 0,0,d(),r)) -- save ref
    return pdfreference(r)
end

-- some dictionaries can have a MH (must honor) or BE (best effort) capsule

local function insertrendering(specification)
    local label = specification.label
    local options = utilities.parsers.settings_to_hash(specification.options)
    if not mf[label] then
        local filename = specification.filename
        local isurl = find(filename,"://")
    --~ local start = pdfdictionary {
    --~     Type = pdfconstant("MediaOffset"),
    --~     S = pdfconstant("T"), -- time
    --~     T = pdfdictionary { -- time
    --~         Type = pdfconstant("Timespan"),
    --~         S    = pdfconstant("S"),
    --~         V    = 3, -- time in seconds
    --~     },
    --~ }
    --~ local start = pdfdictionary {
    --~     Type = pdfconstant("MediaOffset"),
    --~     S = pdfconstant("F"), -- frame
    --~     F = 100 -- framenumber
    --~ }
    --~ local start = pdfdictionary {
    --~     Type = pdfconstant("MediaOffset"),
    --~     S = pdfconstant("M"), -- mark
    --~     M = "somemark",
    --~ }
    --~ local parameters = pdfdictionary {
    --~     BE = pdfdictionary {
    --~          B = start,
    --~     }
    --~ }
    --~ local parameters = pdfdictionary {
    --~     Type = pdfconstant(MediaPermissions),
    --~     TF   = pdfstring("TEMPALWAYS") }, -- TEMPNEVER TEMPEXTRACT TEMPACCESS TEMPALWAYS
    --~ }
        local descriptor = pdfdictionary {
            Type = pdfconstant("Filespec"),
            F    = filename,
        }
        if isurl then
            descriptor.FS = pdfconstant("URL")
        elseif options[variables.embed] then
            descriptor.EF = codeinjections.embedfile(filename)
        end
        local clip = pdfdictionary {
            Type = pdfconstant("MediaClip"),
            S    = pdfconstant("MCD"),
            N    = label,
            CT   = specification.mime,
            Alt  = pdfarray { "", "file not found" }, -- language id + message
            D    = pdfreference(pdfflushobject(descriptor)),
         -- P    = pdfreference(pdfflushobject(parameters)),
        }
        local rendition = pdfdictionary {
            Type = pdfconstant("Rendition"),
            S    = pdfconstant("MR"),
            N    = label,
            C    = pdfreference(pdfflushobject(clip)),
        }
        mf[label] = pdfreference(pdfflushobject(rendition))
    end
end

local function insertrenderingobject(specification) -- todo
    local label = specification.label
    if not mf[label] then
        report_media("todo: unknown medium '%s'",label or "?")
        local clip = pdfdictionary { -- does  not work that well one level up
            Type = pdfconstant("MediaClip"),
            S    = pdfconstant("MCD"),
            N    = label,
            D    = pdfreference(unknown), -- not label but objectname, hm .. todo?
        }
        local rendition = pdfdictionary {
            Type = pdfconstant("Rendition"),
            S    = pdfconstant("MR"),
            N    = label,
            C    = pdfreference(pdfflushobject(clip)),
        }
        mf[label] = pdfreference(pdfflushobject(rendition))
    end
end

function codeinjections.processrendering(label)
    local specification = interactions.renderings.rendering(label)
    if not specification then
        -- error
    elseif specification.kind == "external" then
        insertrendering(specification)
    else
        insertrenderingobject(specification)
    end
end

function codeinjections.insertrenderingwindow(specification)
    local label = specification.label
    codeinjections.processrendering(label)
    ms[label] = insertrenderingwindow(specification)
end

local function set(operation,arguments)
    codeinjections.processrendering(arguments)
    return pdfdictionary {
        S  = pdfconstant("Rendition"),
        OP = operation,
        R  = mf[arguments],
        AN = ms[arguments] or delayed(arguments),
    }
end

function executers.startrendering (arguments) return set(0,arguments) end
function executers.stoprendering  (arguments) return set(1,arguments) end
function executers.pauserendering (arguments) return set(2,arguments) end
function executers.resumerendering(arguments) return set(3,arguments) end
