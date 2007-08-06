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

support     = support     or { }
environment = environment or { }

environment.outputfilename = environment.outputfilename or environment.jobname

function support.checkfilename(str) -- "/whatever..." "c:..." "http://..."
    cs.chardef("kindoffile",boolean.tonumber(str:find("^/") or str:find("[%a]:")))
end

function support.thesanitizedfilename(str)
    tex.write((str:gsub("\\","/")))
end

function support.splitfilename(fullname)
    local path, name, base, suffix, kind = '', fullname, fullname, '', 0
    local p, n = fullname:match("^(.+)/(.-)$")
    if p and n then
        path, name, base = p, n, n
    end
    local b, s = base:match("^(.+)%.(.-)$")
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
    cs.def("splitofffull", fullname)
    cs.def("splitoffpath", path)
    cs.def("splitoffbase", base)
    cs.def("splitoffname", name)
    cs.def("splitofftype", suffix)
    cs.chardef("splitoffkind", kind)
end

function support.splitfiletype(fullname)
    local name, suffix = fullname, ''
    local n, s = fullname:match("^(.+)%.(.-)$")
    if n and s then
        name, suffix = n, s
    end
    cs.def("splitofffull", fullname)
    cs.def("splitoffpath", "")
    cs.def("splitoffname", name)
    cs.def("splitofftype", suffix)
end

function support.doifparentfileelse(n)
    cs.testcase(n==environment.jobname or n==environment.jobname..'.tex' or n==environment.outputfilename)
end

-- saves some .15 sec on 12 sec format generation

function support.doiffileexistelse(name)
    if not name or name == "" then
        return cs.testcase(false)
    else
        local n = input.findtexfile(texmf.instance,name)
        return cs.testcase(n and n ~= "")
    end
end
