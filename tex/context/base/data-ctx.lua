if not modules then modules = { } end modules ['data-ctx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

function resolvers.save_used_files_in_trees(filename,jobname)
    if not filename then filename = 'luatex.jlg' end
    local found = instance.foundintrees
    local f = io.open(filename,'w')
    if f then
        f:write("<?xml version='1.0' standalone='yes'?>\n")
        f:write("<rl:job>\n")
        if jobname then
            f:write(format("\t<rl:name>%s</rl:name>\n",jobname))
        end
        f:write("\t<rl:files>\n")
        for _,v in ipairs(table.sortedkeys(found)) do
            f:write(format("\t\t<rl:file n='%s'>%s</rl:file>\n",found[v],v))
        end
        f:write("\t</rl:files>\n")
        f:write("</rl:usedfiles>\n")
        f:close()
    end
end
