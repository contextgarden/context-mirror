if not modules then modules = { } end modules ['lpdf-xmp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "with help from Peter Rolf",
}

local tostring, type = tostring, type
local format, random, char, gsub, concat = string.format, math.random, string.char, string.gsub, table.concat
local xmlfillin = xml.fillin

local trace_xmp  = false  trackers.register("backend.xmp",  function(v) trace_xmp  = v end)
local trace_info = false  trackers.register("backend.info", function(v) trace_info = v end)

local report_xmp  = logs.reporter("backend","xmp")
local report_info = logs.reporter("backend","info")

local backends, lpdf = backends, lpdf

local codeinjections       = backends.pdf.codeinjections -- normally it is registered

local pdfdictionary        = lpdf.dictionary
local pdfconstant          = lpdf.constant
local pdfreference         = lpdf.reference
local pdfflushstreamobject = lpdf.flushstreamobject

-- I wonder why this begin end is empty / w (no time now to look into it) / begin can also be "?"

local xpacket = [[
<?xpacket begin="﻿" id="%s"?>

%s

<?xpacket end="w"?>]]

local mapping = {
    -- user defined keys (pdfx:)
    ["ConTeXt.Jobname"] = { "context", "rdf:Description/pdfx:ConTeXt.Jobname" },
    ["ConTeXt.Time"]    = { "date",    "rdf:Description/pdfx:ConTeXt.Time" },
    ["ConTeXt.Url"]     = { "context", "rdf:Description/pdfx:ConTeXt.Url" },
    ["ConTeXt.Version"] = { "context", "rdf:Description/pdfx:ConTeXt.Version" },
    ["ID"]              = { "id",      "rdf:Description/pdfx:ID" },                         -- has date
    ["PTEX.Fullbanner"] = { "metadata","rdf:Description/pdfx:PTEX.Fullbanner" },
    -- Adobe PDF schema
    ["Keywords"]        = { "metadata","rdf:Description/pdf:Keywords" },
    ["Producer"]        = { "metadata","rdf:Description/pdf:Producer" },
 -- ["Trapped"]         = { "pdf",     "rdf:Description/pdf:Trapped" },                     -- '/False' in /Info, but 'False' in XMP
    -- Dublin Core schema
    ["Author"]          = { "metadata","rdf:Description/dc:creator/rdf:Seq/rdf:li" },
    ["Format"]          = { "metadata","rdf:Description/dc:format" },                       -- optional, but nice to have
    ["Subject"]         = { "metadata","rdf:Description/dc:description/rdf:Alt/rdf:li" },
    ["Title"]           = { "metadata","rdf:Description/dc:title/rdf:Alt/rdf:li" },
    -- XMP Basic schema
    ["CreateDate"]      = { "date",    "rdf:Description/xmp:CreateDate" },
    ["CreationDate"]    = { "date",    "rdf:Description/xmp:CreationDate" },                -- dummy
    ["Creator"]         = { "metadata","rdf:Description/xmp:CreatorTool" },
    ["MetadataDate"]    = { "date",    "rdf:Description/xmp:MetadataDate" },
    ["ModDate"]         = { "date",    "rdf:Description/xmp:ModDate" },                     -- dummy
    ["ModifyDate"]      = { "date",    "rdf:Description/xmp:ModifyDate" },
    -- XMP Media Management schema
    ["DocumentID"]      = { "id",      "rdf:Description/xmpMM:DocumentID" },                -- uuid
    ["InstanceID"]      = { "id",      "rdf:Description/xmpMM:InstanceID" },                -- uuid
    ["RenditionClass"]  = { "pdf",     "rdf:Description/xmpMM:RenditionClass" },            -- PDF/X-4
    ["VersionID"]       = { "pdf",     "rdf:Description/xmpMM:VersionID" },                 -- PDF/X-4
    -- additional entries
    -- PDF/X
    ["GTS_PDFXVersion"] = { "pdf",     "rdf:Description/pdfxid:GTS_PDFXVersion" },
    -- optional entries
    -- all what is visible in the 'document properties --> additional metadata' window
    -- XMP Rights Management schema (optional)
    ["Marked"]          = { "pdf",      "rdf:Description/xmpRights:Marked" },
 -- ["Owner"]           = { "metadata", "rdf:Description/xmpRights:Owner/rdf:Bag/rdf:li" }, -- maybe useful (not visible)
 -- ["UsageTerms"]      = { "metadata", "rdf:Description/xmpRights:UsageTerms" },           -- maybe useful (not visible)
    ["WebStatement"]    = { "metadata", "rdf:Description/xmpRights:WebStatement" },
    -- Photoshop PDF schema (optional)
    ["AuthorsPosition"] = { "metadata", "rdf:Description/photoshop:AuthorsPosition" },
    ["Copyright"]       = { "metadata", "rdf:Description/photoshop:Copyright" },
    ["CaptionWriter"]   = { "metadata", "rdf:Description/photoshop:CaptionWriter" },
}

pdf.setsuppressoptionalinfo(
        0 --
    +   1 -- pdfnofullbanner
    +   2 -- pdfnofilename
    +   4 -- pdfnopagenumber
    +   8 -- pdfnoinfodict
    +  16 -- pdfnocreator
    +  32 -- pdfnocreationdate
    +  64 -- pdfnomoddate
    + 128 -- pdfnoproducer
    + 256 -- pdfnotrapped
 -- + 512 -- pdfnoid
)

local included = backends.included

function lpdf.settrailerid(v)
    if v then
        local b = toboolean(v) or v == ""
        if b then
            v = "This file is processed by ConTeXt and LuaTeX."
        else
            v = tostring(v)
        end
        local h = md5.HEX(v)
        if b then
            report_info("using frozen trailer id")
        else
            report_info("using hashed trailer id %a (%a)",v,h)
        end
        pdf.settrailerid(format("[<%s> <%s>]",h,h))
    end
end

function lpdf.setdates(v)
    local t = type(v)
    if t == "number" or t == "string" then
        t = converters.totime(v)
        if t then
            included.date = true
            included.id   = "fake"
            report_info("forced date/time information %a will be used",lpdf.settime(t))
            lpdf.settrailerid(false)
            return
        end
    end
    v = toboolean(v)
    included.date = v
    if v then
        included.id = true
    else
        report_info("no date/time but fake id information will be added")
        lpdf.settrailerid(true)
        included.id = "fake"
     -- maybe: lpdf.settime(231631200) -- 1975-05-05 % first entry of knuth about tex mentioned in DT
    end
end

function lpdf.id() -- overload of ini
    local banner = tex.jobname
    if included.date then
        return format("%s.%s",banner,lpdf.timestamp())
    else
        return banner
    end
end

directives.register("backend.trailerid", lpdf.settrailerid)
directives.register("backend.date",      lpdf.setdates)

local function permitdetail(what)
    local m = mapping[what]
    if m then
        return included[m[1]] and m[2]
    else
        return included[what] and true or false
    end
end

lpdf.permitdetail = permitdetail

-- maybe some day we will load the xmp file at runtime

local xmp, xmpfile, xmpname = nil, nil, "lpdf-pdx.xml"

local function setxmpfile(name)
    if xmp then
        report_xmp("discarding loaded file %a",xmpfile)
        xmp = nil
    end
    xmpfile = name ~= "" and name
end

codeinjections.setxmpfile = setxmpfile

interfaces.implement {
    name      = "setxmpfile",
    arguments = "string",
    actions   = setxmpfile
}

local function valid_xmp()
    if not xmp then
     -- local xmpfile = xmpfile or resolvers.findfile(xmpname) or ""
        if xmpfile and xmpfile ~= "" then
            xmpfile = resolvers.findfile(xmpfile) or ""
        end
        if not xmpfile or xmpfile == "" then
            xmpfile = resolvers.findfile(xmpname) or ""
        end
        if xmpfile ~= "" then
            report_xmp("using file %a",xmpfile)
        end
        local xmpdata = xmpfile ~= "" and io.loaddata(xmpfile) or ""
        xmp = xml.convert(xmpdata)
    end
    return xmp
end

function lpdf.addxmpinfo(tag,value,check)
    local pattern = permitdetail(tag)
    if type(pattern) == "string" then
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

-- redefined

local pdfaddtoinfo  = lpdf.addtoinfo
local pdfaddxmpinfo = lpdf.addxmpinfo

function lpdf.addtoinfo(tag,pdfvalue,strvalue)
    local pattern = permitdetail(tag)
    if pattern then
        pdfaddtoinfo(tag,pdfvalue)
    end
    if type(pattern) == "string" then
        local value = strvalue or gsub(tostring(pdfvalue),"^%((.*)%)$","%1") -- hack
        if trace_info then
            report_info("set %a to %a",tag,value)
        end
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

local pdfaddtoinfo = lpdf.addtoinfo -- used later

-- for the do-it-yourselvers

function lpdf.insertxmpinfo(pattern,whatever,prepend)
    xml.insert(xmp or valid_xmp(),pattern,whatever,prepend)
end

function lpdf.injectxmpinfo(pattern,whatever,prepend)
    xml.inject(xmp or valid_xmp(),pattern,whatever,prepend)
end

-- flushing

local function randomstring(n)
    local t = { }
    for i=1,n do
        t[i] = char(96 + random(26))
    end
    return concat(t)
end

randomstring(26) -- kind of initializes and kicks off random

local function flushxmpinfo()
    commands.pushrandomseed()
    commands.setrandomseed(os.time())

    local packetid   = "no unique packet id here" -- 24 chars
    local documentid = "no unique document id here"
    local instanceid = "no unique instance id here"
    local producer   = format("LuaTeX-%0.2f.%s",status.luatex_version/100,status.luatex_revision)
    local creator    = "LuaTeX + ConTeXt MkIV"
    local time       = lpdf.timestamp()
    local fullbanner = status.banner

    if included.id ~= "fake" then
        packetid   = randomstring(24)
        documentid = "uuid:%s" .. os.uuid()
        instanceid = "uuid:%s" .. os.uuid()
    end

    pdfaddxmpinfo("DocumentID",      documentid)
    pdfaddxmpinfo("InstanceID",      instanceid)
    pdfaddxmpinfo("Producer",        producer)
    pdfaddxmpinfo("CreatorTool",     creator)
    pdfaddxmpinfo("CreateDate",      time)
    pdfaddxmpinfo("ModifyDate",      time)
    pdfaddxmpinfo("MetadataDate",    time)
    pdfaddxmpinfo("PTEX.Fullbanner", fullbanner)

    pdfaddtoinfo("Producer",         producer)
    pdfaddtoinfo("Creator",          creator)
    pdfaddtoinfo("CreationDate",     time)
    pdfaddtoinfo("ModDate",          time)
 -- pdfaddtoinfo("PTEX.Fullbanner",  fullbanner) -- no checking done on existence

    local blob = xml.tostring(xml.first(xmp or valid_xmp(),"/x:xmpmeta"))
    local md = pdfdictionary {
        Subtype = pdfconstant("XML"),
        Type    = pdfconstant("Metadata"),
    }
    if trace_xmp then
        report_xmp("data flushed, see log file")
        logs.pushtarget("logfile")
        report_xmp("start xmp blob")
        logs.newline()
        logs.writer(blob)
        logs.newline()
        report_xmp("stop xmp blob")
        logs.poptarget()
    end
    blob = format(xpacket,packetid,blob)
    if not verbose and pdf.getcompresslevel() > 0 then
        blob = gsub(blob,">%s+<","><")
    end
    local r = pdfflushstreamobject(blob,md,false) -- uncompressed
    lpdf.addtocatalog("Metadata",pdfreference(r))

    commands.poprandomseed() -- hack
end

--  his will be enabled when we can inhibit compression for a stream at the lua end

lpdf.registerdocumentfinalizer(flushxmpinfo,1,"metadata")

directives.register("backend.verbosexmp", function(v)
    verbose = v
end)
