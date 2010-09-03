if not modules then modules = { } end modules ['data-ctx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local function saveusedfilesin_trees()
    local jobname = environment.jobname
    if not jobname or jobname == "" then jobname = "luatex" end
    local filename = file.replacesuffix(jobname,'jlg')
    local f = io.open(filename,'w')
    if f then
        f:write("<?xml version='1.0' standalone='yes'?>\n")
        f:write("<rl:job>\n")
        f:write(format("\t<rl:jobname>%s</rl:jobname>\n",jobname))
        f:write(format("\t<rl:contextversion>%s</rl:contextversion>\n",environment.version))
        local found = resolvers.instance.foundintrees
        local sorted = table.sortedkeys(found)
        if #sorted > 0 then
            f:write("\t<rl:files>\n")
            for k=1,#sorted do
                local v = sorted[k]
                f:write(format("\t\t<rl:file n='%s'>%s</rl:file>\n",found[v],v))
            end
            f:write("\t</rl:files>\n")
        else
            f:write("\t<rl:files/>\n")
        end
        f:write("</rl:job>\n")
        f:close()
        report_resolvers("saving used tree files in '%s'",filename)
    end
end

directives.register("system.dumpfiles", function() saveusedfilesintrees() end)
