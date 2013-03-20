if not modules then modules = { } end modules ['trac-exp'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local formatters   = string.formatters
local reporters    = logs.reporters
local xmlserialize = xml.serialize
local xmlcollected = xml.collected
local xmltext      = xml.text
local xmlfirst     = xml.first
local xmlfilter    = xml.filter

-- there is no need for a newhandlers { name = "help", parent = "string" }

local function flagdata(flag)
    local name  = flag.at.name or ""
    local value = flag.at.value or ""
 -- local short = xmlfirst(s,"/short")
 -- local short = xmlserialize(short,xs)
    local short = xmltext(xmlfirst(flag,"/short")) or ""
    return name, value, short
end

local function exampledata(example)
    local command = xmltext(xmlfirst(example,"/command")) or ""
    local comment = xmltext(xmlfirst(example,"/comment")) or ""
    return command, comment
end

local function categorytitle(category)
    return xmltext(xmlfirst(category,"/title")) or ""
end

local exporters = { }

exporters.man = function(specification,...)
    local root = xml.convert(specification.helpinfo or "")
    if not root then
        return
    end
    local xs = xml.gethandlers("string")
    xml.sethandlersfunction(xs,"short",function(e,handler) xmlserialize(e.dt,handler) end)
    xml.sethandlersfunction(xs,"ref",  function(e,handler) handler.handle("--"..e.at.name) end)
    local wantedcategories = select("#",...) == 0 and true or table.tohash { ... }
    local nofcategories = xml.count(root,"/application/flags/category")
    local name    = xmlfilter(root,"/application/metadata/entry[@name='name']/text()")
    local detail  = xmlfilter(root,"/application/metadata/entry[@name='detail']/text()") or name
    local version = xmlfilter(root,"/application/metadata/entry[@name='version']/text()") or "0.00"
    local banner  = specification.banner or detail or name
    --
    local result = { }
    --
    result[#result+1] = formatters['.TH %s\n.SH "NAME"\n%s.SH "SYNOPSIS"\n\\fB%s\\fP [ \\fIOPTIONS\\fP ... ]\n.SH "DESCRIPTION"\n%s\n'](
        banner,name,name,detail
    )
    for category in xmlcollected(root,"/application/flags/category") do
        if nofcategories > 1 then
            result[#result+1] = formatters['.SH "OPTIONS: %s"'](string.upper(category.at.name or "all"))
        else
            result[#result+1] = '.SH "OPTIONS"'
        end
        for subcategory in xmlcollected(category,"/subcategory") do
            for flag in xmlcollected(subcategory,"/flag") do
                local name, value, short = flagdata(flag)
                if value == "" then
                    result[#result+1] = formatters[".TP\n.B --%s\n%s"](name,short)
                else
                    result[#result+1] = formatters[".TP\n.B --%s=%s\n%s"](name,value,short)
                end
            end
        end
    end
    result[#result+1] = formatters['.SH "AUTHOR"\n%s'](specification.moreinfo)
    return table.concat(result,"\n")
end

local craptemplate = [[
<?xml version="1.0"?>
<application>
<metadata>
<entry name="banner">%s</entry>
</metadata>
<verbose>
%s
</verbose>
]]

exporters.xml = function(specification,...)
    local helpinfo = specification.helpinfo
    if type(helpinfo) == "string" then
        if string.find(helpinfo,"^<%?xml") then
            return helpinfo
        end
    elseif type(helpinfo) == "table" then
        helpinfo = table.concat(helpinfo,"\n\n")
    else
        helpinfo = "no help"
    end
    return formatters[craptemplate](specification.banner or "?",helpinfo)
end

local bodytemplate = [[
<h1>Command line options</h1>
<table>
    <tr>
        <th style="width: 10em">flag</th>
        <th style="width: 8em">value</th>
        <th>description</th>
    </tr>
    <?lua
        for category in xml.collected(variables.root,"/application/flags/category") do
            if variables.nofcategories > 1 then
                ?><tr><th colspan="3"><?lua inject(category.at.name) ?></td></tr><?lua
            end
            for subcategory in xml.collected(category,"/subcategory") do
                ?><tr><th/><td/><td/></tr><?lua
                for flag in xml.collected(subcategory,"/flag") do
                    local name, value, short = variables.flagdata(flag)
                    ?>
                        <tr>
                            <th>--<?lua inject(name)  ?></th>
                            <td><?lua inject(value) ?></td>
                            <td><?lua inject(short) ?></td>
                        </tr>
                    <?lua
                end
            end
        end
    ?>
</table>
<?lua
    ?><br/><?lua
    for category in xml.collected(variables.root,"/application/examples/category") do
        local title = variables.categorytitle(category)
        if title ~= "" then
            ?><h1><?lua inject(title)?></h1><?lua
        end
        for subcategory in xml.collected(category,"/subcategory") do
            for example in xml.collected(subcategory,"/example") do
                local command, comment = variables.exampledata(example)
                ?><tt><?lua inject(command) ?></tt><br/><?lua
            end
            ?><br/><?lua
        end
    end
?>
]]

exporters.html = function(specification,...)
    local root = xml.convert(specification.helpinfo or "")
    if not root then
        return
    end
    local xs = xml.gethandlers("string")
    xml.sethandlersfunction(xs,"short",function(e,handler) xmlserialize(e.dt,handler) end)
    xml.sethandlersfunction(xs,"ref",  function(e,handler) handler.handle("--"..e.at.name) end)
    local wantedcategories = select("#",...) == 0 and true or table.tohash { ... }
    local nofcategories = xml.count(root,"/application/flags/category")
    local name    = xmlfilter(root,"/application/metadata/entry[@name='name']/text()")
    local detail  = xmlfilter(root,"/application/metadata/entry[@name='detail']/text()") or name
    local version = xmlfilter(root,"/application/metadata/entry[@name='version']/text()") or "0.00"
    local banner  = specification.banner or detail or name
    --
    dofile(resolvers.findfile("trac-lmx.lua","tex"))
    --
    local htmltemplate = io.loaddata(resolvers.findfile("context-base.lmx","tex")) or "no template"
    --
    local body = lmx.convertstring(bodytemplate, {
        nofcategories    = nofcategories,
        wantedcategories = wantedcategories,
        root             = root,
    --  moreinfo         = specification.moreinfo,
        flagdata         = flagdata,
        exampledata      = exampledata,
        categorytitle    = categorytitle,
    })
    local html = lmx.convertstring(htmltemplate, {
        maintext   = body,
        title      = banner,
        bottomtext = "wiki: http://contextgarden.net | mail: ntg-context@ntg.nl | website: http://www.pragma-ade.nl",
    })
    --
    return html
end

logs.exporters = exporters
