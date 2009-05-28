if not modules then modules = { } end modules ['supp-fil'] = {
    version   = 1.001,
    comment   = "companion to supp-fil.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in
<l n='lua'/> than in <l n='tex'/>. These methods have counterparts
at the <l n='tex'/> side.</p>
--ldx]]--

local find, gsub, match = string.find, string.gsub, string.match

local ctxcatcodes = tex.ctxcatcodes

support     = support     or { }
environment = environment or { }

environment.outputfilename = environment.outputfilename or environment.jobname

function support.checkfilename(str) -- "/whatever..." "c:..." "http://..."
    commands.chardef("kindoffile",boolean.tonumber(find(str,"^/") or find(str,"[%a]:")))
end

function support.thesanitizedfilename(str)
    tex.write((gsub(str,"\\","/")))
end

function support.splitfilename(fullname)
    local path, name, base, suffix, kind = '', fullname, fullname, '', 0
    local p, n = match(fullname,"^(.+)/(.-)$")
    if p and n then
        path, name, base = p, n, n
    end
    local b, s = match(base,"^(.+)%.(.-)$")
    if b and s then
        name, suffix = b, s
    end
    if path == "" then
        kind = 0
    elseif path == '.' then
        kind = 1
    else
        kind = 2
    end
    commands.def("splitofffull", fullname)
    commands.def("splitoffpath", path)
    commands.def("splitoffbase", base)
    commands.def("splitoffname", name)
    commands.def("splitofftype", suffix)
    commands.chardef("splitoffkind", kind)
end

function support.splitfiletype(fullname)
    local name, suffix = fullname, ''
    local n, s = match(fullname,"^(.+)%.(.-)$")
    if n and s then
        name, suffix = n, s
    end
    commands.def("splitofffull", fullname)
    commands.def("splitoffpath", "")
    commands.def("splitoffname", name)
    commands.def("splitofftype", suffix)
end

function support.doifparentfileelse(n)
    commands.testcase(n==environment.jobname or n==environment.jobname..'.tex' or n==environment.outputfilename)
end

-- saves some .15 sec on 12 sec format generation

local lastexistingfile = ""

function support.doiffileexistelse(name)
    if not name or name == "" then
        lastexistingfile = ""
    else
        lastexistingfile = resolvers.findtexfile(name) or ""
    end
    return commands.testcase(lastexistingfile ~= "")
end

function support.lastexistingfile()
    tex.sprint(ctxcatcodes,lastexistingfile)
end
