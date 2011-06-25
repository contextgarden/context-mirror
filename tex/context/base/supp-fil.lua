if not modules then modules = { } end modules ['supp-fil'] = {
    version   = 1.001,
    comment   = "companion to supp-fil.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module will be redone !

-- context is not defined yet! todo! (we need to load tupp-fil after cld)
-- todo: move startreadingfile to lua and push regime there

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in
<l n='lua'/> than in <l n='tex'/>. These methods have counterparts
at the <l n='tex'/> side.</p>
--ldx]]--

local find, gsub, match, format, concat = string.find, string.gsub, string.match, string.format, table.concat
local texcount = tex.count
local isfile = lfs.isfile

local trace_modules = false  trackers.register("modules.loading",    function(v) trace_modules = v end)
local trace_files   = false  trackers.register("resolvers.readfile", function(v) trace_files = v end)

local report_modules = logs.reporter("resolvers","modules")
local report_files   = logs.reporter("files","readfile")

commands          = commands or { }
local commands    = commands
environment       = environment or { }
local environment = environment

local findbyscheme = resolvers.finders.byscheme

-- needs a cleanup:

function commands.checkfilename(str) -- "/whatever..." "c:..." "http://..."
    texcount.kindoffile = (find(str,"^/") or find(str,"[%a]:") and 1) or 0
end

function commands.thesanitizedfilename(str)
    context((gsub(str,"\\","/")))
end

local testcase = commands.testcase

function commands.splitfilename(fullname)
    local path, name, base, suffix = '', fullname, fullname, ''
    local p, n = match(fullname,"^(.+)/(.-)$")
    if p and n then
        path, name, base = p, n, n
    end
    local b, s = match(base,"^(.+)%.(.-)$")
    if b and s then
        name, suffix = b, s
    end
    texcount.splitoffkind = (path == "" and 0) or (path == '.' and 1) or 2
    local setvalue = context.setvalue
    setvalue("splitofffull", fullname)
    setvalue("splitoffpath", path)
    setvalue("splitoffbase", base)
    setvalue("splitoffname", name)
    setvalue("splitofftype", suffix)
end

function commands.splitfiletype(fullname)
    local name, suffix = fullname, ''
    local n, s = match(fullname,"^(.+)%.(.-)$")
    if n and s then
        name, suffix = n, s
    end
    local setvalue = context.setvalue
    setvalue("splitofffull", fullname)
    setvalue("splitoffpath", "")
    setvalue("splitoffname", name)
    setvalue("splitofftype", suffix)
end

function commands.doifparentfileelse(n)
    testcase(n == environment.jobname or n == environment.jobname .. '.tex' or n == environment.outputfilename)
end

-- saves some .15 sec on 12 sec format generation

local lastexistingfile = ""

function commands.doiffileexistelse(name)
    if not name or name == "" then
        lastexistingfile = ""
    else
        lastexistingfile = resolvers.findtexfile(name) or ""
    end
    return testcase(lastexistingfile ~= "")
end

function commands.lastexistingfile()
    context(lastexistingfile)
end

-- more, we can cache matches

local finders, loaders, openers = resolvers.finders, resolvers.loaders, resolvers.openers

local found = { } -- can best be done in the resolver itself

-- todo: tracing

local function readfilename(specification,backtrack,treetoo)
    local name = specification.filename
    local fnd = found[name]
    if not fnd then
        if isfile(name) then
            if trace_files then
                report_files("found local: %s",name)
            end
            fnd = name
        end
        if not fnd and backtrack then
            local fname = name
            for i=1,backtrack,1 do
                fname = "../" .. fname
                if isfile(fname) then
                    if trace_files then
                        report_files("found by backtracking: %s",fname)
                    end
                    fnd = fname
                    break
                elseif trace_files then
                    report_files("not found by backtracking: %s",fname)
                end
            end
        end
        if not fnd and treetoo then
            fnd = resolvers.findtexfile(name) or ""
            if trace_files then
                if fnd ~= "" then
                    report_files("found by tree lookup: %s",fnd)
                else
                    report_files("not found by tree lookup: %s",name)
                end
            end
        end
        found[name] = fnd
    elseif trace_files then
        if fnd ~= "" then
            report_files("already found: %s",fnd)
        else
            report_files("already not found: %s",name)
        end
    end
    return fnd or ""
end

function commands.readfilename(filename)
    return findbyscheme("any",filename)
end

function finders.job(specification) return readfilename(specification,false,false) end -- current path, no backtracking
function finders.loc(specification) return readfilename(specification,2,    false) end -- current path, backtracking
function finders.sys(specification) return readfilename(specification,false,true ) end -- current path, obeys tex search
function finders.fix(specification) return readfilename(specification,2,    false) end -- specified path, backtracking
function finders.set(specification) return readfilename(specification,false,false) end -- specified path, no backtracking
function finders.any(specification) return readfilename(specification,2,    true ) end -- loc job sys

openers.job = openers.file loaders.job = loaders.file -- default anyway
openers.loc = openers.file loaders.loc = loaders.file
openers.sys = openers.file loaders.sys = loaders.file
openers.fix = openers.file loaders.fix = loaders.file
openers.set = openers.file loaders.set = loaders.file
openers.any = openers.file loaders.any = loaders.file

function finders.doreadfile(scheme,path,name) -- better do a split and then pass table
    local fullname
    if url.hasscheme(name) then
        fullname = name
    else
        fullname = ((path == "") and format("%s:///%s",scheme,name)) or format("%s:///%s/%s",scheme,path,name)
    end
    return resolvers.findtexfile(fullname) or "" -- can be more direct
end

function commands.doreadfile(scheme,path,name)
    context(finders.doreadfile(scheme,path,name))
end

-- modules can have a specific suffix or can specify one

local prefixes  = { "m", "p", "s", "x", "v", "t" }
local suffixes  = { "mkiv", "tex", "mkvi" } -- order might change and how about cld
local modstatus = { }

local function usemodule(name,hasscheme)
    local foundname
    if hasscheme then
        -- no auto suffix as http will return a home page or error page
        -- so we only add one if missing
        local fullname = file.addsuffix(name,"tex")
        if trace_modules then
            report_modules("checking url: '%s'",fullname)
        end
        foundname = resolvers.findtexfile(fullname) or ""
    elseif file.extname(name) ~= "" then
        if trace_modules then
            report_modules("checking file: '%s'",name)
        end
        foundname = findbyscheme("any",name) or ""
    else
        for i=1,#suffixes do
            local fullname = file.addsuffix(name,suffixes[i])
            if trace_modules then
                report_modules("checking file: '%s'",fullname)
            end
            foundname = findbyscheme("any",fullname) or ""
            if foundname ~= "" then
                break
            end
        end
    end
    if foundname ~= "" then
        if trace_modules then
            report_modules("loading: '%s'",foundname)
        end
        context.startreadingfile()
        context.input(foundname)
        context.stopreadingfile()
        return true
    else
        return false
    end
end

function commands.usemodules(prefix,askedname,truename)
    local hasprefix = prefix and prefix ~= ""
    local hashname = ((hasprefix and prefix) or "*") .. "-" .. truename
    local status = modstatus[hashname]
    if status == 0 then
        -- not found
    elseif status == 1 then
        status = status + 1
    else
        if trace_modules then
            report_modules("locating: prefix: '%s', askedname: '%s', truename: '%s'",prefix or "", askedname or "", truename or "")
        end
        local hasscheme = url.hasscheme(truename)
        if hasscheme then
            -- no prefix and suffix done
            if usemodule(truename,true) then
                status = 1
            else
                status = 0
            end
        elseif hasprefix then
            if usemodule(prefix .. "-" .. truename) then
                status = 1
            else
                status = 0
            end
        else
            for i=1,#prefixes do
                -- todo: reconstruct name i.e. basename
                local thename = prefixes[i] .. "-" .. truename
                if usemodule(thename) then
                    status = 1
                    break
                end
            end
            if status then
                -- ok, don't change
            elseif usemodule(truename) then
                status = 1
            else
                status = 0
            end
        end
    end
    if status == 0 then
        report_modules("not found: '%s'",askedname)
    elseif status == 1 then
        report_modules("loaded: '%s'",trace_modules and truename or askedname)
    else
        report_modules("already loaded: '%s'",trace_modules and truename or askedname)
    end
    modstatus[hashname] = status
end

local loaded = { }

function commands.uselibrary(name,patterns,action,failure)
    local files = utilities.parsers.settings_to_array(name)
    local done = false
    for i=1,#files do
        local filename = files[i]
        if not loaded[filename] then
            loaded[filename] = true
            for i=1,#patterns do
                local filename = format(patterns[i],filename)
             -- local foundname = resolvers.findfile(filename) or ""
                local foundname = finders.doreadfile("any",".",filename)
                if foundname ~= "" then
                    action(name,foundname)
                    done = true
                    break
                end
            end
            if done then
                break
            end
        end
    end
    if failure and not done then
        failure(name)
    end
end

statistics.register("loaded tex modules", function()
    if next(modstatus) then
        local t, f, nt, nf = { }, { }, 0, 0
        for k, v in table.sortedhash(modstatus) do
            k = file.basename(k)
            if v == 0 then
                nf = nf + 1
                f[nf] = k
            else
                nt = nt + 1
                t[nt] = k
            end
        end
        local ts = (nt>0 and format(" (%s)",concat(t," "))) or ""
        local fs = (nf>0 and format(" (%s)",concat(f," "))) or ""
        return format("%s requested, %s found%s, %s missing%s",nt+nf,nt,ts,nf,fs)
    else
        return nil
    end
end)
