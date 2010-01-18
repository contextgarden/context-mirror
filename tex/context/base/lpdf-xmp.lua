if not modules then modules = { } end modules ['lpdf-xmp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, random, char, gsub = string.format, math.random, string.char, string.gsub
local xmlfillin = xml.fillin

local trace_xmp = false  trackers.register("backend.xmp", function(v) trace_xmp = v end)

local xmpmetadata = [[
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 4.2.1-c043 52.372728, 2009/01/18-15:08:04">
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:format>application/pdf</dc:format>
            <dc:creator>
                <rdf:Seq>
                    <rdf:li/>
                </rdf:Seq>
            </dc:creator>
            <dc:title>
                <rdf:Alt>
                    <rdf:li xml:lang="x-default"/>
                </rdf:Alt>
            </dc:title>
        </rdf:Description>
        <rdf:Description rdf:about="" xmlns:pdfx="http://ns.adobe.com/pdfx/1.3/">
            <pdfx:ConTeXt.Jobname/>
            <pdfx:ConTeXt.Time/>
            <pdfx:ConTeXt.Url/>
            <pdfx:ConTeXt.Version/>
            <pdfx:ID/>
            <pdfx:PTEX.Fullbanner/>
        </rdf:Description>
        <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
            <xmp:CreateDate/>
            <xmp:CreatorTool/>
            <xmp:ModifyDate/>
            <xmp:MetadataDate/>
        </rdf:Description>
        <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
            <pdf:Keywords/>
            <pdf:Producer/>
            <pdf:Trapped/>
        </rdf:Description>
        <rdf:Description rdf:about="" xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/">
            <xmpMM:DocumentID/>
            <xmpMM:InstanceID/>
        </rdf:Description>
    </rdf:RDF>
</x:xmpmeta>
]]

-- i wonder why this begin end is empty / w (no time now to look into it)

local xpacket = [[
<?xpacket begin="﻿" id="%s"?>

%s

<?xpacket end="w"?>]]

local mapping = {
    ["Creator"]         = "rdf:Description/dc:creator/rdf:Seq/rdf:li",
    ["Title"]           = "rdf:Description/dc:title/rdf:Alt/rdf:li",
    ["ConTeXt.Jobname"] = "rdf:Description/pdfx:ConTeXt.Jobname",
    ["ConTeXt.Time"]    = "rdf:Description/pdfx:ConTeXt.Time",
    ["ConTeXt.Url"]     = "rdf:Description/pdfx:ConTeXt.Url",
    ["ConTeXt.Version"] = "rdf:Description/pdfx:ConTeXt.Version",
    ["ID"]              = "rdf:Description/pdfx:ID",
    ["PTEX.Fullbanner"] = "rdf:Description/pdfx:PTEX.Fullbanner",
    ["CreateDate"]      = "rdf:Description/xmp:CreateDate",
    ["CreatorTool"]     = "rdf:Description/xmp:CreatorTool",
    ["ModifyDate"]      = "rdf:Description/xmp:ModifyDate",
    ["MetadataDate"]    = "rdf:Description/xmp:MetadataDate",
    ["Keywords"]        = "rdf:Description/pdf:Keywords",
    ["Producer"]        = "rdf:Description/pdf:Producer",
    ["Trapped"]         = "rdf:Description/pdf:Trapped",
    ["DocumentID"]      = "rdf:Description/xmpMM:DocumentID",
    ["InstanceID"]      = "rdf:Description/xmpMM:InstanceID",
}

local xmp = xml.convert(xmpmetadata)

local addtoinfo = lpdf.addtoinfo

local function addxmpinfo(tag,value,check)
    local pattern = mapping[tag]
    if pattern then
        xmlfillin(xmp,pattern,value,check)
    end
end

function lpdf.addtoinfo(tag,pdfvalue,strvalue)
    addtoinfo(tag,pdfvalue)
    addxmpinfo(tag,strvalue or gsub(tostring(pdfvalue),"^%((.*)%)$","%1")) -- hack
end

lpdf.addxmpinfo = addxmpinfo

local t = { } for i=1,24 do t[i] = random() end

local function flushxmpinfo()

    commands.freezerandomseed(os.clock()) -- hack

    local t = { } for i=1,24 do t[i] = char(96 + random(26)) end
    local packetid = table.concat(t)
    local time = os.date("!%Y-%m-%dT%X") -- ! -> universaltime
    addxmpinfo("Producer",format("LuaTeX-%0.2f.%s",tex.luatexversion/100,tex.luatexrevision))
    addxmpinfo("DocumentID",format("uuid:%s",os.uuid()))
    addxmpinfo("InstanceID",format("uuid:%s",os.uuid()))
    addxmpinfo("CreatorTool","LuaTeX + ConTeXt MkIV")
    addxmpinfo("CreateDate",time)
    addxmpinfo("ModifyDate",time)
    addxmpinfo("MetadataDate",time)
    local blob = xml.tostring(xmp)
    local md = lpdf.dictionary {
        Subtype = lpdf.constant("XML"),
        Type    = lpdf.constant("Metadata"),
    }
    if trace_xmp then
        commands.writestatus("system","xmp data flushed (see log file)")
        texio.write_nl("log","")
        texio.write("log","\n% ",(gsub(blob,"[\r\n]","\n%% ")),"\n")
    end
    local r = pdf.obj {
        immediate = true,
        compresslevel = 0,
        type = "stream",
        string = format(xpacket,packetid,blob),
        attr = md(),
    }
    lpdf.addtocatalog("Metadata",lpdf.reference(r))

    commands.defrostrandomseed() -- hack

end

--  his will be enabled when we can inhibit compression for a stream at the lua end

lpdf.registerdocumentfinalizer(flushxmpinfo,1)

--~ lpdf.addxmpinfo("creator",         "PRAGMA ADE: Hans Hagen and/or Ton Otten")
--~ lpdf.addxmpinfo("title",           "oeps")
--~ lpdf.addxmpinfo("ConTeXt.Jobname", "oeps")
--~ lpdf.addxmpinfo("ConTeXt.Time",    "2009.10.30 17:53")
--~ lpdf.addxmpinfo("ConTeXt.Url",     "www.pragma-ade.com")
--~ lpdf.addxmpinfo("ConTeXt.Version", "2009.10.30 16:59")
--~ lpdf.addxmpinfo("ID",              "oeps.20091030.1753")
--~ lpdf.addxmpinfo("PTEX.Fullbanner", "This is LuaTeX, Version beta-0.44.0-2009103014 (Web2C 2009) kpathsea version 5.0.0")
--~ lpdf.addxmpinfo("CreateDate",      "2009-10-30T17:53:39+01:00")
--~ lpdf.addxmpinfo("CreatorTool",     "ConTeXt - 2009.10.30 16:59")
--~ lpdf.addxmpinfo("ModifyDate",      "2009-10-30T19:38:18+01:00")
--~ lpdf.addxmpinfo("MetadataDate",    "2009-10-30T19:38:18+01:00")
--~ lpdf.addxmpinfo("Producer",        "LuaTeX-0.44.0")
--~ lpdf.addxmpinfo("Trapped",         "False")
--~ lpdf.addxmpinfo("DocumentID",      "uuid:d9f1383c-e069-4619-bee0-c978d9495d7d")
--~ lpdf.addxmpinfo("InstanceID",      "uuid:67eda265-8146-4cce-a1a2-1ec91819ad73")

--~ print(lpdf.flushxmpinfo())
