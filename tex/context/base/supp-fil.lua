if not modules then modules = { } end modules ['supp-fil'] = {
    version   = 1.001,
    comment   = "companion to supp-fil.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in
<l n='lua'/> than in <l n='tex'/>. These methods have counterparts
at the <l n='tex'/> side.</p>
--ldx]]--

local find, gsub, match, format = string.find, string.gsub, string.match, string.format
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

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

-- more, we can cache matches

local finders, loaders, openers = resolvers.finders, resolvers.loaders, resolvers.openers

local found = { } -- can best be done in the resolver itself

-- todo: tracing

local function readfile(specification,backtrack,treetoo)
    local fnd = found[specification]
    if not fnd then
        local splitspec = resolvers.splitmethod(specification)
        local filename = splitspec.path or ""
        if lfs.isfile(filename) then
            fnd = filename
        end
        if not fnd and backtrack then
            local fname = filename
            for i=1,backtrack,1 do
                fname = "../" .. fname
                if lfs.isfile(fname) then
                    fnd = fname
                    break
                end
            end
        end
        if not fnd and treetoo then
            fnd = resolvers.find_file(filename)
        end
        found[specification] = fnd
    end
    return fnd or ""
end

function finders.job(filename) return readfile(filename,nil,false) end -- current path, no backtracking
function finders.loc(filename) return readfile(filename,2,  false) end -- current path, backtracking
function finders.sys(filename) return readfile(filename,nil,true ) end -- current path, obeys tex search
function finders.fix(filename) return readfile(filename,2,  false) end -- specified path, backtracking
function finders.set(filename) return readfile(filename,nil,false) end -- specified path, no backtracking
function finders.any(filename) return readfile(filename,2,  true ) end -- loc job sys

openers.job = openers.generic loaders.job = loaders.generic
openers.loc = openers.generic loaders.loc = loaders.generic
openers.sys = openers.generic loaders.sys = loaders.generic
openers.fix = openers.generic loaders.fix = loaders.generic
openers.set = openers.generic loaders.set = loaders.generic
openers.any = openers.generic loaders.any = loaders.generic

function support.doreadfile(protocol,path,name)
    local specification = ((path == "") and format("%s:///%s",protocol,name)) or format("%s:///%s/%s",protocol,path,name)
    texsprint(ctxcatcodes,resolvers.findtexfile(specification))
end
