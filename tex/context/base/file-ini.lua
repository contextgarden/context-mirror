if not modules then modules = { } end modules ['file-ini'] = {
    version   = 1.001,
    comment   = "companion to file-ini.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in
<l n='lua'/> than in <l n='tex'/>. These methods have counterparts
at the <l n='tex'/> side.</p>
--ldx]]--

resolvers.jobs = resolvers.jobs or { }

local texcount = tex.count
local setvalue = context.setvalue

function commands.splitfilename(fullname)
    local t = file.nametotable(fullname)
    local path = t.path
    texcount.splitoffkind = (path == "" and 0) or (path == '.' and 1) or 2
    setvalue("splitofffull",fullname)
    setvalue("splitoffpath",path)
    setvalue("splitoffname",t.name)
    setvalue("splitoffbase",t.base)
    setvalue("splitofftype",t.suffix)
end

function commands.doifparentfileelse(n)
    commands.doifelse(n == environment.jobname or n == environment.jobname .. '.tex' or n == environment.outputfilename)
end

function commands.doiffileexistelse(name)
    local foundname = resolvers.findtexfile(name)
    commands.doifelse(foundname and foundname ~= "")
end
