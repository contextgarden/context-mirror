if not modules then modules = { } end modules ['lpdf-xmp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "with help from Peter Rolf",
}

local format, random, char, gsub, concat = string.format, math.random, string.char, string.gsub, table.concat
local xmlfillin = xml.fillin

local trace_xmp = false  trackers.register("backend.xmp", function(v) trace_xmp = v end)

local pdfdictionary = lpdf.dictionary
local pdfconstant   = lpdf.constant

-- i wonder why this begin end is empty / w (no time now to look into it)

local xpacket = [[
<?xpacket begin="﻿" id="%s"?>

%s

<?xpacket end="w"?>]]

local mapping = {
    -- user defined keys (pdfx:)
    ["ConTeXt.Jobname"] = "rdf:Description/pdfx:ConTeXt.Jobname",
    ["ConTeXt.Time"]    = "rdf:Description/pdfx:ConTeXt.Time",
    ["ConTeXt.Url"]     = "rdf:Description/pdfx:ConTeXt.Url",
    ["ConTeXt.Version"] = "rdf:Description/pdfx:ConTeXt.Version",
    ["ID"]              = "rdf:Description/pdfx:ID",
    ["PTEX.Fullbanner"] = "rdf:Description/pdfx:PTEX.Fullbanner",
    -- Adobe PDF schema
    ["Keywords"]        = "rdf:Description/pdf:Keywords",
    ["Producer"]        = "rdf:Description/pdf:Producer",
 -- ["Trapped"]         = "rdf:Description/pdf:Trapped", -- '/False' in /Info, but 'False' in XMP
    -- Dublin Core schema
    ["Author"]          = "rdf:Description/dc:creator/rdf:Seq/rdf:li",
    ["Format"]          = "rdf:Description/dc:format", -- optional, but nice to have
    ["Subject"]         = "rdf:Description/dc:description",
    ["Title"]           = "rdf:Description/dc:title/rdf:Alt/rdf:li",
    -- XMP Basic schema
    ["CreateDate"]      = "rdf:Description/xmp:CreateDate",
    ["Creator"]         = "rdf:Description/xmp:CreatorTool",
    ["MetadataDate"]    = "rdf:Description/xmp:MetadataDate",
    ["ModifyDate"]      = "rdf:Description/xmp:ModifyDate",
    -- XMP Media Management schema
    ["DocumentID"]      = "rdf:Description/xmpMM:DocumentID",
    ["InstanceID"]      = "rdf:Description/xmpMM:InstanceID",
    ["RenditionClass"]  = "rdf:Description/xmpMM:RenditionClass", -- PDF/X-4
    ["VersionID"]       = "rdf:Description/xmpMM:VersionID", -- PDF/X-4
    -- additional entries
    -- PDF/X
    ["GTS_PDFXVersion"] = "rdf:Description/pdfxid:GTS_PDFXVersion",
    -- optional entries
    -- all what is visible in the 'document properties --> additional metadata' window
    -- XMP Rights Management schema (optional)
    ["Marked"]          = "rdf:Description/xmpRights:Marked",
 -- ["Owner"]           = "rdf:Description/xmpRights:Owner/rdf:Bag/rdf:li", -- maybe useful (not visible)
 -- ["UsageTerms"]      = "rdf:Description/xmpRights:UsageTerms", -- maybe useful (not visible)
    ["WebStatement"]    = "rdf:Description/xmpRights:WebStatement",
    -- Photoshop PDF schema (optional)
    ["AuthorsPosition"] = "rdf:Description/photoshop:AuthorsPosition",
    ["Copyright"]       = "rdf:Description/photoshop:Copyright",
    ["CaptionWriter"]   = "rdf:Description/photoshop:CaptionWriter",
}

-- maybe some day we will load the xmp file at runtime

local xmp, xmpfile, xmpname = nil, nil, "lpdf-xmp.xml"

function lpdf.setxmpfile(name)
    xmpfile = resolvers.findctxfile(name) or ""
    if xmpfile == "" then
        xmpfile = nil
    end
end

local function valid_xmp()
    if not xmp then
        local xmpfile = xmpfile or resolvers.find_file(xmpname) or ""
        local xmpdata = (xmpfile ~= "" and io.loaddata(xmpfile)) or ""
        xmp = xml.convert(xmpdata)
    end
    return xmp
end

function lpdf.addxmpinfo(tag,value,check)
    local pattern = mapping[tag]
    if pattern then
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

-- redefined

local addtoinfo  = lpdf.addtoinfo
local addxmpinfo = lpdf.addxmpinfo

function lpdf.addtoinfo(tag,pdfvalue,strvalue)
    addtoinfo(tag,pdfvalue)
    addxmpinfo(tag,strvalue or gsub(tostring(pdfvalue),"^%((.*)%)$","%1")) -- hack
end

-- for the do-it-yourselvers

function lpdf.insertxmpinfo(pattern,whatever,prepend)
    xml.insert(xmp or valid_xmp(),pattern,whatever,prepend)
end

function lpdf.injectxmpinfo(pattern,whatever,prepend)
    xml.inject(xmp or valid_xmp(),pattern,whatever,prepend)
end

-- flushing

local t = { } for i=1,24 do t[i] = random() end

local function flushxmpinfo()

    commands.freezerandomseed(os.clock()) -- hack

    local t = { } for i=1,24 do t[i] = char(96 + random(26)) end
    local packetid = concat(t)
    local time = lpdf.timestamp()
    addxmpinfo("Producer",format("LuaTeX-%0.2f.%s",tex.luatexversion/100,tex.luatexrevision))
    addxmpinfo("DocumentID",format("uuid:%s",os.uuid()))
    addxmpinfo("InstanceID",format("uuid:%s",os.uuid()))
    addxmpinfo("CreatorTool","LuaTeX + ConTeXt MkIV")
    addxmpinfo("CreateDate",time)
    addxmpinfo("ModifyDate",time)
    addxmpinfo("MetadataDate",time)
    addxmpinfo("PTEX.Fullbanner", tex.pdftexbanner)
    local blob = xml.tostring(xml.first(xmp or valid_xmp(),"/x:xmpmeta"))
    local md = pdfdictionary {
        Subtype = pdfconstant("XML"),
        Type    = pdfconstant("Metadata"),
    }
    if trace_xmp then
        commands.writestatus("system","xmp data flushed (see log file)")
        texio.write_nl("log","")
        texio.write("log","\n% ",(gsub(blob,"[\r\n]","\n%% ")),"\n")
    end
    blob = format(xpacket,packetid,blob)
    if tex.pdfcompresslevel > 0 then
        blob = gsub(blob,">%s+<","><")
    end
    local r = pdf.obj {
        immediate = true,
        compresslevel = 0,
        type = "stream",
        string = blob,
        attr = md(),
    }
    lpdf.addtocatalog("Metadata",lpdf.reference(r))

    commands.defrostrandomseed() -- hack

end

--  his will be enabled when we can inhibit compression for a stream at the lua end

lpdf.registerdocumentfinalizer(flushxmpinfo,1)
