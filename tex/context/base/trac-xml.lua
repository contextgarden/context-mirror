if not modules then modules = { } end modules ['trac-xml'] = {
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

-- there is no need for a newhandlers { name = "help", parent = "string" }

local function showhelp(specification,...)
    local root = xml.convert(specification.helpinfo or "")
    if not root then
        return
    end
    local xs = xml.gethandlers("string")
    xml.sethandlersfunction(xs,"short",function(e,handler) xmlserialize(e.dt,handler) end)
    xml.sethandlersfunction(xs,"ref",  function(e,handler) handler.handle("--"..e.at.name) end)
    local wantedcategories = select("#",...) == 0 and true or table.tohash { ... }
    local nofcategories = xml.count(root,"/application/flags/category")
    local report = specification.report
    for category in xmlcollected(root,"/application/flags/category") do
        local categoryname = category.at.name or ""
        if wantedcategories == true or wantedcategories[categoryname] then
            if nofcategories > 1 then
                report("%s options:",categoryname)
                report()
            end
            for subcategory in xmlcollected(category,"/subcategory") do
                for flag in xmlcollected(subcategory,"/flag") do
                    local name  = flag.at.name
                    local value = flag.at.value
                 -- local short = xmlfirst(s,"/short")
                 -- local short = xmlserialize(short,xs)
                    local short = xmltext(xmlfirst(flag,"/short"))
                    if value then
                        report("--%-24s %s",formatters["%s=%s"](name,value),short)
                    else
                        report("--%-24s %s",name,short)
                    end
                end
                report()
            end
        end
    end
    for category in xmlcollected(root,"/application/examples/category") do
        local title = xmltext(xmlfirst(category,"/title"))
        if title and title ~= "" then
            report()
            report(title)
            report()
        end
        for subcategory in xmlcollected(category,"/subcategory") do
            for example in xmlcollected(subcategory,"/example") do
                local command = xmltext(xmlfirst(example,"/command"))
                local comment = xmltext(xmlfirst(example,"/comment"))
                report(command)
            end
            report()
        end
    end
end

local reporthelp = reporters.help
local exporthelp = reporters.export

function reporters.help(t,...)
    local helpinfo = t.helpinfo
    if type(helpinfo) == "string" and string.find(helpinfo,"^<%?xml") then
        showhelp(t,...)
    else
        reporthelp(t,...)
    end
end

function reporters.export(t,method,filename)
    dofile(resolvers.findfile("trac-exp.lua","tex"))
    local exporters = logs.exporters
    local result = method and exporters and exporters[method] and exporters[method](t,method) or exporthelp(t)
    if type(filename) == "string" and filename ~= "" then
        io.savedata(filename,result)
    else
        reporters.lines(t,result)
    end
end
