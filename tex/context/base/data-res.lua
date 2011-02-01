if not modules then modules = { } end modules ['data-res'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- In practice we will work within one tds tree, but i want to keep
-- the option open to build tools that look at multiple trees, which is
-- why we keep the tree specific data in a table. We used to pass the
-- instance but for practical purposes we now avoid this and use a
-- instance variable. We always have one instance active (sort of global).

-- todo: cache:/// home:///

local format, gsub, find, lower, upper, match, gmatch = string.format, string.gsub, string.find, string.lower, string.upper, string.match, string.gmatch
local concat, insert, sortedkeys = table.concat, table.insert, table.sortedkeys
local next, type, rawget, setmetatable = next, type, rawget, setmetatable
local os = os

local P, S, R, C, Cc, Cs, Ct, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local filedirname, filebasename, fileextname, filejoin = file.dirname, file.basename, file.extname, file.join
local collapsepath, joinpath = file.collapsepath, file.joinpath
local allocate = utilities.storage.allocate

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_detail     = false  trackers.register("resolvers.details",    function(v) trace_detail     = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local expandedpathfromlist   = resolvers.expandedpathfromlist
local checkedvariable        = resolvers.checkedvariable
local splitconfigurationpath = resolvers.splitconfigurationpath
local methodhandler          = resolvers.methodhandler

local initializesetter = utilities.setters.initialize

local ostype, osname, osenv, ossetenv, osgetenv = os.type, os.name, os.env, os.setenv, os.getenv

resolvers.cacheversion  = '1.0.1'
resolvers.configbanner  = ''
resolvers.homedir       = environment.homedir
resolvers.criticalvars  = allocate { "SELFAUTOLOC", "SELFAUTODIR", "SELFAUTOPARENT", "TEXMFCNF", "TEXMF", "TEXOS" }
resolvers.luacnfname    = 'texmfcnf.lua'
resolvers.luacnfstate   = "unknown"

-- resolvers.luacnfspec = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}' -- what a rubish path
resolvers.luacnfspec = 'selfautoparent:{/texmf{-local,}{,/web2c},}}'

--~ -- not yet, some reporters expect strings

--~ resolvers.luacnfspec    = {
--~     "selfautoparent:/texmf-local",
--~     "selfautoparent:/texmf-local/web2c",
--~     "selfautoparent:/texmf",
--~     "selfautoparent:/texmf/web2c",
--~     "selfautoparent:",
--~ }

local unset_variable = "unset"

local formats   = resolvers.formats
local suffixes  = resolvers.suffixes
local dangerous = resolvers.dangerous
local suffixmap = resolvers.suffixmap

resolvers.defaultsuffixes = { "tex" } --  "mkiv", "cld" -- too tricky

resolvers.instance = resolvers.instance or nil -- the current one (slow access)
local     instance = resolvers.instance or nil -- the current one (fast access)

-- An instance has an environment (coming from the outside, kept raw), variables
-- (coming from the configuration file), and expansions (variables with nested
-- variables replaced). One can push something into the outer environment and
-- its internal copy, but only the later one will be the raw unprefixed variant.

function resolvers.setenv(key,value)
    if instance then
        -- this one will be consulted first when we stay inside
        -- the current environment
        instance.environment[key] = value
        -- we feed back into the environment, and as this is used
        -- by other applications (via os.execute) we need to make
        -- sure that prefixes are resolved
        ossetenv(key,resolvers.resolve(value))
    end
end

-- Beware we don't want empty here as this one can be called early on
-- and therefore we use rawget.

local function getenv(key)
    local value = rawget(instance.environment,key)
    if value and value ~= "" then
        return value
    else
        local e = osgetenv(key)
        return e ~= nil and e ~= "" and checkedvariable(e) or ""
    end
end

resolvers.getenv = getenv
resolvers.env    = getenv

-- We are going to use some metatable trickery where we backtrack from
-- expansion to variable to environment.

local function resolve(k)
    return instance.expansions[k]
end

local dollarstripper   = lpeg.stripper("$")
local inhibitstripper  = P("!")^0 * Cs(P(1)^0)
local backslashswapper = lpeg.replacer("\\","/")

local somevariable     = P("$") / ""
local somekey          = C(R("az","AZ","09","__","--")^1)
local somethingelse    = P(";") * ((1-S("!{}/\\"))^1 * P(";") / "")
                       + P(";") * (P(";") / "")
                       + P(1)
local variableexpander = Cs( (somevariable * (somekey/resolve) + somethingelse)^1 )

local cleaner          = P("\\") / "/" + P(";") * S("!{}/\\")^0 * P(";")^1 / ";"
local variablecleaner  = Cs((cleaner  + P(1))^0)

local somevariable     = R("az","AZ","09","__","--")^1 / resolve
local variable         = (P("$")/"") * (somevariable + (P("{")/"") * somevariable * (P("}")/""))
local variableresolver = Cs((variable + P(1))^0)

local function expandedvariable(var)
    return lpegmatch(variableexpander,var) or var
end

function resolvers.expandvariables()
    -- no longer needed
end

local function collapse_configuration_data()
    -- no longer needed
end

function resolvers.newinstance() -- todo: all vars will become lowercase and alphanum only

    local environment, variables, expansions, order = allocate(), allocate(), allocate(), allocate()

    local newinstance = {
        environment     = environment,
        variables       = variables,
        expansions      = expansions,
        order           = order,
        files           = allocate(),
        setups          = allocate(),
        found           = allocate(),
        foundintrees    = allocate(),
        hashes          = allocate(),
        specification   = allocate(),
        lists           = allocate(),
        data            = allocate(), -- only for loading
        fakepaths       = allocate(),
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        loaderror       = false,
        savelists       = true,
        pattern         = nil, -- lists
        force_suffixes  = true,
    }

    setmetatable(variables, { __index = function(t,k)
        for i=1,#order do
            v = order[i][k]
            if v ~= nil then
                t[k] = v
                return v
            end
        end
        if v == nil then
            v = ""
        end
        t[k] = v
        return v
    end } )

    setmetatable(environment, { __index = function(t,k)
        v = osgetenv(k)
        if v == nil then
            v = variables[k]
        end
        if v ~= nil then
            v = checkedvariable(v) or ""
        end
        t[k] = v
        return v
    end } )

    setmetatable(expansions, { __index = function(t,k)
        local v = environment[k]
        if type(v) == "string" then
            v = lpegmatch(variableresolver,v)
            v = lpegmatch(variablecleaner,v)
        end
        t[k] = v
        return v
    end } )

    return newinstance

end

function resolvers.setinstance(someinstance) -- only one instance is active
    instance = someinstance
    resolvers.instance = someinstance
    return someinstance
end

function resolvers.reset()
    return resolvers.setinstance(resolvers.newinstance())
end

local function reset_hashes()
    instance.lists = { }
    instance.found = { }
end

local slash = P("/")

local pathexpressionpattern = Cs (
    Cc("^") * (
        Cc("%") * S(".-")
      + slash^2 * P(-1) / "/.*"
      + slash^2 / "/.-/"
      + (1-slash) * P(-1) * Cc("/")
      + P(1)
    )^1 * Cc("$") -- yes or no $
)

local cache = { }

local function makepathexpression(str)
    if str == "." then
        return "^%./$"
    else
        local c = cache[str]
        if not c then
            c = lpegmatch(pathexpressionpattern,str)
            cache[str] = c
        end
        return c
    end
end

local function reportcriticalvariables()
    if trace_locating then
        for i=1,#resolvers.criticalvars do
            local k = resolvers.criticalvars[i]
            local v = resolvers.getenv(k) or "unknown" -- this one will not resolve !
            report_resolvers("variable '%s' set to '%s'",k,v)
        end
        report_resolvers()
    end
    reportcriticalvariables = function() end
end

local function identify_configuration_files()
    local specification = instance.specification
    if #specification == 0 then
        local cnfspec = getenv('TEXMFCNF')
        if cnfspec == "" then
            cnfspec = resolvers.luacnfspec
            resolvers.luacnfstate = "default"
        else
            resolvers.luacnfstate = "environment"
        end
        reportcriticalvariables()
        local cnfpaths = expandedpathfromlist(resolvers.splitpath(cnfspec))
        local luacnfname = resolvers.luacnfname
        for i=1,#cnfpaths do
            local filename = collapsepath(filejoin(cnfpaths[i],luacnfname))
            local realname = resolvers.resolve(filename)
            if lfs.isfile(realname) then
                specification[#specification+1] = filename
                if trace_locating then
                    report_resolvers("found configuration file '%s'",realname)
                end
            elseif trace_locating then
                report_resolvers("unknown configuration file '%s'",realname)
            end
        end
        if trace_locating then
            report_resolvers()
        end
    end
end

local function load_configuration_files()
    local specification = instance.specification
    if #specification > 0 then
        local luacnfname = resolvers.luacnfname
        for i=1,#specification do
            local filename = specification[i]
            local pathname = filedirname(filename)
            local filename = filejoin(pathname,luacnfname)
            local realname = resolvers.resolve(filename) -- no shortcut
            local blob = loadfile(realname)
            if blob then
                local setups = instance.setups
                local data = blob()
                data = data and data.content
                if data then
                    if trace_locating then
                        report_resolvers("loading configuration file '%s'",filename)
                        report_resolvers()
                    end
                    local variables = data.variables or { }
                    local warning = false
                    for k, v in next, data do
                        local kind = type(v)
                        if kind == "table" then
                            initializesetter(filename,k,v)
                        elseif variables[k] == nil then
                            if trace_locating and not warning then
                                report_resolvers("variables like '%s' in configuration file '%s' should move to the 'variables' subtable",
                                    k,resolvers.resolve(filename))
                                warning = true
                            end
                            variables[k] = v
                        end
                    end
                    setups[pathname] = variables
                    if resolvers.luacnfstate == "default" then
                        -- the following code is not tested
                        local cnfspec = variables["TEXMFCNF"]
                        if cnfspec then
                            -- we push the value into the main environment (osenv) so
                            -- that it takes precedence over the default one and therefore
                            -- also over following definitions
                            resolvers.setenv('TEXMFCNF',resolvers.resolve(cnfspec))
                            -- we now identify and load the specified configuration files
                            instance.specification = { }
                            identify_configuration_files()
                            load_configuration_files()
                            -- we prevent further overload of the configuration variable
                            resolvers.luacnfstate = "configuration"
                            -- we quit the outer loop
                            break
                        end
                    end

                else
                    if trace_locating then
                        report_resolvers("skipping configuration file '%s' (no content)",filename)
                    end
                    setups[pathname] = { }
                    instance.loaderror = true
                end
            elseif trace_locating then
                report_resolvers("skipping configuration file '%s' (no file)",filename)
            end
            instance.order[#instance.order+1] = instance.setups[pathname]
            if instance.loaderror then
                break
            end
        end
    elseif trace_locating then
        report_resolvers("warning: no lua configuration files found")
    end
end

-- scheme magic ... database loading

local function load_file_databases()
    instance.loaderror, instance.files = false, allocate()
    if not instance.renewcache then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            resolvers.hashers.byscheme(hash.type,hash.name)
            if instance.loaderror then break end
        end
    end
end

local function locate_file_databases()
    -- todo: cache:// and tree:// (runtime)
    local texmfpaths = resolvers.expandedpathlist('TEXMF')
    if #texmfpaths > 0 then
        for i=1,#texmfpaths do
            local path = collapsepath(texmfpaths[i])
            local stripped = lpegmatch(inhibitstripper,path) -- the !! thing
            if stripped ~= "" then
                local runtime = stripped == path
                path = resolvers.cleanpath(path)
                local spec = resolvers.splitmethod(stripped)
                if spec.scheme == "cache" or spec.scheme == "file" then
                    stripped = spec.path
                elseif runtime and (spec.noscheme or spec.scheme == "file") then
                    stripped = "tree:///" .. stripped
                end
                if trace_locating then
                    if runtime then
                        report_resolvers("locating list of '%s' (runtime)",path)
                    else
                        report_resolvers("locating list of '%s' (cached)",path)
                    end
                end
                methodhandler('locators',stripped)
            end
        end
        if trace_locating then
            report_resolvers()
        end
    elseif trace_locating then
        report_resolvers("no texmf paths are defined (using TEXMF)")
    end
end

local function generate_file_databases()
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        methodhandler('generators',hash.name)
    end
    if trace_locating then
        report_resolvers()
    end
end

local function save_file_databases() -- will become cachers
    for i=1,#instance.hashes do
        local hash = instance.hashes[i]
        local cachename = hash.name
        if hash.cache then
            local content = instance.files[cachename]
            caches.collapsecontent(content)
            if trace_locating then
                report_resolvers("saving tree '%s'",cachename)
            end
            caches.savecontent(cachename,"files",content)
        elseif trace_locating then
            report_resolvers("not saving runtime tree '%s'",cachename)
        end
    end
end

local function load_databases()
    locate_file_databases()
    if instance.diskcache and not instance.renewcache then
        load_file_databases()
        if instance.loaderror then
            generate_file_databases()
            save_file_databases()
        end
    else
        generate_file_databases()
        if instance.renewcache then
            save_file_databases()
        end
    end
end

function resolvers.appendhash(type,name,cache)
    if trace_locating then
        report_resolvers("hash '%s' appended",name)
    end
    insert(instance.hashes, { type = type, name = name, cache = cache } )
end

function resolvers.prependhash(type,name,cache)
    if trace_locating then
        report_resolvers("hash '%s' prepended",name)
    end
    insert(instance.hashes, 1, { type = type, name = name, cache = cache } )
end

function resolvers.extendtexmfvariable(specification) -- crap, we could better prepend the hash
    local t = resolvers.splitpath(getenv('TEXMF'))
    insert(t,1,specification)
    local newspec = concat(t,";")
    if instance.environment["TEXMF"] then
        instance.environment["TEXMF"] = newspec
    elseif instance.variables["TEXMF"] then
        instance.variables["TEXMF"] = newspec
    else
        -- weird
    end
    reset_hashes()
end

function resolvers.splitexpansions()
    local ie = instance.expansions
    for k,v in next, ie do
        local t, tn, h, p = { }, 0, { }, splitconfigurationpath(v)
        for kk=1,#p do
            local vv = p[kk]
            if vv ~= "" and not h[vv] then
                tn = tn + 1
                t[tn] = vv
                h[vv] = true
            end
        end
        if #t > 1 then
            ie[k] = t
        else
            ie[k] = t[1]
        end
    end
end

-- end of split/join code

-- we used to have 'files' and 'configurations' so therefore the following
-- shared function

function resolvers.datastate()
    return caches.contentstate()
end

function resolvers.variable(name)
    local name = name and lpegmatch(dollarstripper,name)
    local result = name and instance.variables[name]
    return result ~= nil and result or ""
end

function resolvers.expansion(name)
    local name = name and lpegmatch(dollarstripper,name)
    local result = name and instance.expansions[name]
    return result ~= nil and result or ""
end

function resolvers.unexpandedpathlist(str)
    local pth = resolvers.variable(str)
    local lst = resolvers.splitpath(pth)
    return expandedpathfromlist(lst)
end

function resolvers.unexpandedpath(str)
    return joinpath(resolvers.unexpandedpathlist(str))
end

local done = { }

function resolvers.resetextrapath()
    local ep = instance.extra_paths
    if not ep then
        ep, done = { }, { }
        instance.extra_paths = ep
    elseif #ep > 0 then
        instance.lists, done = { }, { }
    end
end

function resolvers.registerextrapath(paths,subpaths)
    local ep = instance.extra_paths or { }
    local oldn = #ep
    local newn = oldn
    if paths and paths ~= "" then
        if subpaths and subpaths ~= "" then
            for p in gmatch(paths,"[^,]+") do
                -- we gmatch each step again, not that fast, but used seldom
                for s in gmatch(subpaths,"[^,]+") do
                    local ps = p .. "/" .. s
                    if not done[ps] then
                        newn = newn + 1
                        ep[newn] = resolvers.cleanpath(ps)
                        done[ps] = true
                    end
                end
            end
        else
            for p in gmatch(paths,"[^,]+") do
                if not done[p] then
                    newn = newn + 1
                    ep[newn] = resolvers.cleanpath(p)
                    done[p] = true
                end
            end
        end
    elseif subpaths and subpaths ~= "" then
        for i=1,n do
            -- we gmatch each step again, not that fast, but used seldom
            for s in gmatch(subpaths,"[^,]+") do
                local ps = ep[i] .. "/" .. s
                if not done[ps] then
                    newn = newn + 1
                    ep[newn] = resolvers.cleanpath(ps)
                    done[ps] = true
                end
            end
        end
    end
    if newn > 0 then
        instance.extra_paths = ep -- register paths
    end
    if newn > oldn then
        instance.lists = { } -- erase the cache
    end
end

local function made_list(instance,list)
    local ep = instance.extra_paths
    if not ep or #ep == 0 then
        return list
    else
        local done, new, newn = { }, { }, 0
        -- honour . .. ../.. but only when at the start
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                if find(v,"^[%.%/]$") then
                    done[v] = true
                    newn = newn + 1
                    new[newn] = v
                else
                    break
                end
            end
        end
        -- first the extra paths
        for k=1,#ep do
            local v = ep[k]
            if not done[v] then
                done[v] = true
                newn = newn + 1
                new[newn] = v
            end
        end
        -- next the formal paths
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                done[v] = true
                newn = newn + 1
                new[newn] = v
            end
        end
        return new
    end
end

function resolvers.cleanpathlist(str)
    local t = resolvers.expandedpathlist(str)
    if t then
        for i=1,#t do
            t[i] = collapsepath(resolvers.cleanpath(t[i]))
        end
    end
    return t
end

function resolvers.expandpath(str)
    return joinpath(resolvers.expandedpathlist(str))
end

function resolvers.expandedpathlist(str)
    if not str then
        return { }
    elseif instance.savelists then
        str = lpegmatch(dollarstripper,str)
        if not instance.lists[str] then -- cached
            local lst = made_list(instance,resolvers.splitpath(resolvers.expansion(str)))
            instance.lists[str] = expandedpathfromlist(lst)
        end
        return instance.lists[str]
    else
        local lst = resolvers.splitpath(resolvers.expansion(str))
        return made_list(instance,expandedpathfromlist(lst))
    end
end

function resolvers.expandedpathlistfromvariable(str) -- brrr
    str = lpegmatch(dollarstripper,str)
    local tmp = resolvers.variableofformatorsuffix(str)
    return resolvers.expandedpathlist(tmp ~= "" and tmp or str)
end

function resolvers.expandpathfromvariable(str)
    return joinpath(resolvers.expandedpathlistfromvariable(str))
end

function resolvers.expandbraces(str) -- output variable and brace expansion of STRING
    local ori = resolvers.variable(str)
    local pth = expandedpathfromlist(resolvers.splitpath(ori))
    return joinpath(pth)
end

function resolvers.registerfilehash(name,content,someerror)
    if content then
        instance.files[name] = content
    else
        instance.files[name] = { }
        if somerror == true then -- can be unset
            instance.loaderror = someerror
        end
    end
end

function isreadable(name)
    local readable = lfs.isfile(name) -- not file.is_readable(name) asit can be a dir
    if trace_detail then
        if readable then
            report_resolvers("file '%s' is readable",name)
        else
            report_resolvers("file '%s' is not readable", name)
        end
    end
    return readable
end

-- name
-- name/name

local function collect_files(names)
    local filelist, noffiles = { }, 0
    for k=1,#names do
        local fname = names[k]
        if trace_detail then
            report_resolvers("checking name '%s'",fname)
        end
        local bname = filebasename(fname)
        local dname = filedirname(fname)
        if dname == "" or find(dname,"^%.") then
            dname = false
        else
            dname = "/" .. dname .. "$"
        end
        local hashes = instance.hashes
        for h=1,#hashes do
            local hash = hashes[h]
            local blobpath = hash.name
            local files = blobpath and instance.files[blobpath]
            if files then
                if trace_detail then
                    report_resolvers("deep checking '%s' (%s)",blobpath,bname)
                end
                local blobfile = files[bname]
                if not blobfile then
                    local rname = "remap:"..bname
                    blobfile = files[rname]
                    if blobfile then
                        bname = files[rname]
                        blobfile = files[bname]
                    end
                end
                if blobfile then
                    local blobroot = files.__path__ or blobpath
                    if type(blobfile) == 'string' then
                        if not dname or find(blobfile,dname) then
                            local kind   = hash.type
                         -- local search = filejoin(blobpath,blobfile,bname)
                            local search = filejoin(blobroot,blobfile,bname)
                            local result = methodhandler('concatinators',hash.type,blobroot,blobfile,bname)
                            if trace_detail then
                                report_resolvers("match: kind '%s', search '%s', result '%s'",kind,search,result)
                            end
                            noffiles = noffiles + 1
                            filelist[noffiles] = { kind, search, result }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                local kind   = hash.type
                             -- local search = filejoin(blobpath,vv,bname)
                                local search = filejoin(blobroot,vv,bname)
                                local result = methodhandler('concatinators',hash.type,blobroot,vv,bname)
                                if trace_detail then
                                    report_resolvers("match: kind '%s', search '%s', result '%s'",kind,search,result)
                                end
                                noffiles = noffiles + 1
                                filelist[noffiles] = { kind, search, result }
                            end
                        end
                    end
                end
            elseif trace_locating then
                report_resolvers("no match in '%s' (%s)",blobpath,bname)
            end
        end
    end
    return noffiles > 0 and filelist or nil
end

function resolvers.registerintrees(name)
    if not find(name,"^%.") then
        instance.foundintrees[name] = (instance.foundintrees[name] or 0) + 1 -- maybe only one
    end
end

-- split the next one up for readability (but this module needs a cleanup anyway)

local function can_be_dir(name) -- can become local
    local fakepaths = instance.fakepaths
    if not fakepaths[name] then
        if lfs.isdir(name) then
            fakepaths[name] = 1 -- directory
        else
            fakepaths[name] = 2 -- no directory
        end
    end
    return fakepaths[name] == 1
end

local preparetreepattern = Cs((P(".")/"%%." + P("-")/"%%-" + P(1))^0 * Cc("$"))

-- this one will be split in smalle functions

local function collect_instance_files(filename,askedformat,allresults) -- todo : plugin (scanners, checkers etc)
    local result = { }
    local stamp  = nil
    askedformat = askedformat or ""
    filename = collapsepath(filename)
    -- speed up / beware: format problem
    if instance.remember and not allresults then
        stamp = filename .. "--" .. askedformat
        if instance.found[stamp] then
            if trace_locating then
                report_resolvers("remembered file '%s'",filename)
            end
            resolvers.registerintrees(filename) -- for tracing used files
            return instance.found[stamp]
        end
    end
    if not dangerous[askedformat] then
        if isreadable(filename) then
            if trace_detail then
                report_resolvers("file '%s' found directly",filename)
            end
            if stamp then
                instance.found[stamp] = { filename }
            end
            return { filename }
        end
    end
    if find(filename,'%*') then
        if trace_locating then
            report_resolvers("checking wildcard '%s'", filename)
        end
        result = resolvers.findwildcardfiles(filename) -- we can use th elocal
    elseif file.is_qualified_path(filename) then
        if isreadable(filename) then
            if trace_locating then
                report_resolvers("qualified name '%s'", filename)
            end
            result = { filename }
        else
            local forcedname, ok, suffix = "", false, fileextname(filename)
            if suffix == "" then -- why
                local format_suffixes = askedformat == "" and resolvers.defaultsuffixes or suffixes[askedformat]
                if format_suffixes then
                    for i=1,#format_suffixes do
                        local s = format_suffixes[i]
                        forcedname = filename .. "." .. s
                        if isreadable(forcedname) then
                            if trace_locating then
                                report_resolvers("no suffix, forcing format filetype '%s'", s)
                            end
                            result, ok = { forcedname }, true
                            break
                        end
                    end
                end
            end
            if not ok and suffix ~= "" then
                -- try to find in tree (no suffix manipulation), here we search for the
                -- matching last part of the name
                local basename = filebasename(filename)
                local pattern = lpegmatch(preparetreepattern,filename)
                -- messy .. to be sorted out
                local savedformat = askedformat
                local format = savedformat or ""
                if format == "" then
                    askedformat = resolvers.formatofsuffix(suffix)
                end
                if not format then
                    askedformat = "othertextfiles" -- kind of everything, maybe texinput is better
                end
                --
                if basename ~= filename then
                    local resolved = collect_instance_files(basename,askedformat,allresults)
                    if #result == 0 then -- shouldn't this be resolved ?
                        local lowered = lower(basename)
                        if filename ~= lowered then
                            resolved = collect_instance_files(lowered,askedformat,allresults)
                        end
                    end
                    resolvers.format = savedformat
                    --
                    for r=1,#resolved do
                        local rr = resolved[r]
                        if find(rr,pattern) then
                            result[#result+1], ok = rr, true
                        end
                    end
                end
                -- a real wildcard:
                --
                -- if not ok then
                --     local filelist = collect_files({basename})
                --     for f=1,#filelist do
                --         local ff = filelist[f][3] or ""
                --         if find(ff,pattern) then
                --             result[#result+1], ok = ff, true
                --         end
                --     end
                -- end
            end
            if not ok and trace_locating then
                report_resolvers("qualified name '%s'", filename)
            end
        end
    else
        -- search spec
        local filetype, done, wantedfiles, ext = '', false, { }, fileextname(filename)
        -- tricky as filename can be bla.1.2.3
--~         if not suffixmap[ext] then --- probably needs to be done elsewhere too
--~             wantedfiles[#wantedfiles+1] = filename
--~         end

-- to be checked

        wantedfiles[#wantedfiles+1] = filename
        if askedformat == "" then
            if ext == "" or not suffixmap[ext] then
                local defaultsuffixes = resolvers.defaultsuffixes
                for i=1,#defaultsuffixes do
                    local forcedname = filename .. '.' .. defaultsuffixes[i]
                    wantedfiles[#wantedfiles+1] = forcedname
                    filetype = resolvers.formatofsuffix(forcedname)
                    if trace_locating then
                        report_resolvers("forcing filetype '%s'",filetype)
                    end
                end
            else
                filetype = resolvers.formatofsuffix(filename)
                if trace_locating then
                    report_resolvers("using suffix based filetype '%s'",filetype)
                end
            end
        else
            if ext == "" or not suffixmap[ext] then
                local format_suffixes = suffixes[askedformat]
                if format_suffixes then
                    for i=1,#format_suffixes do
                        wantedfiles[#wantedfiles+1] = filename .. "." .. format_suffixes[i]
                    end
                end
            end
            filetype = askedformat
            if trace_locating then
                report_resolvers("using given filetype '%s'",filetype)
            end
        end
        local typespec = resolvers.variableofformat(filetype)
        local pathlist = resolvers.expandedpathlist(typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if trace_detail then
                report_resolvers("checking filename '%s', filetype '%s', wanted files '%s'",filename, filetype or '?',concat(wantedfiles," | "))
            end
            for k=1,#wantedfiles do
                local fname = wantedfiles[k]
                if fname and isreadable(fname) then
                    filename, done = fname, true
                    result[#result+1] = filejoin('.',fname)
                    break
                end
            end
            -- this is actually 'other text files' or 'any' or 'whatever'
            local filelist = collect_files(wantedfiles)
            local fl = filelist and filelist[1]
            if fl then
                filename = fl[3]
                result[#result+1] = filename
                done = true
            end
        else
            -- list search
            local filelist = collect_files(wantedfiles)
            local dirlist = { }
            if filelist then
                for i=1,#filelist do
                    dirlist[i] = filedirname(filelist[i][3]) .. "/" -- was [2] .. gamble
                end
            end
            if trace_detail then
                report_resolvers("checking filename '%s'",filename)
            end
            for k=1,#pathlist do
                local path = pathlist[k]
                local pathname = lpegmatch(inhibitstripper,path)
                local doscan = path == pathname -- no ^!!
                done = false
                -- using file list
                if filelist then
                    -- compare list entries with permitted pattern -- /xx /xx//
                    local expression = makepathexpression(pathname)
                    if trace_detail then
                        report_resolvers("using pattern '%s' for path '%s'",expression,pathname)
                    end
                    for k=1,#filelist do
                        local fl = filelist[k]
                        local f = fl[2]
                        local d = dirlist[k]
                        if find(d,expression) then
                            -- todo, test for readable
                            result[#result+1] = resolvers.resolve(fl[3]) -- no shortcut
                            done = true
                            if allresults then
                                if trace_detail then
                                    report_resolvers("match to '%s' in hash for file '%s' and path '%s', continue scanning",expression,f,d)
                                end
                            else
                                if trace_detail then
                                    report_resolvers("match to '%s' in hash for file '%s' and path '%s', quit scanning",expression,f,d)
                                end
                                break
                            end
                        elseif trace_detail then
                            report_resolvers("no match to '%s' in hash for file '%s' and path '%s'",expression,f,d)
                        end
                    end
                end
                if not done and doscan then
                    -- check if on disk / unchecked / does not work at all / also zips
                    local scheme = url.hasscheme(pathname)
                    if not scheme or scheme == "file" then
                        local pname = gsub(pathname,"%.%*$",'')
                        if not find(pname,"%*") then
                            local ppname = gsub(pname,"/+$","")
                            if can_be_dir(ppname) then
                                for k=1,#wantedfiles do
                                    local w = wantedfiles[k]
                                    local fname = filejoin(ppname,w)
                                    if isreadable(fname) then
                                        if trace_detail then
                                            report_resolvers("found '%s' by scanning",fname)
                                        end
                                        result[#result+1] = fname
                                        done = true
                                        if not allresults then break end
                                    end
                                end
                            else
                                -- no access needed for non existing path, speedup (esp in large tree with lots of fake)
                            end
                        end
                    end
                end
                if not done and doscan then
                    -- todo: slow path scanning ... although we now have tree:// supported in $TEXMF
                end
                if done and not allresults then break end
            end
        end
    end
    for k=1,#result do
        local rk = collapsepath(result[k])
        result[k] = rk
        resolvers.registerintrees(rk) -- for tracing used files
    end
    if stamp then
        instance.found[stamp] = result
    end
    return result
end

local function findfiles(filename,filetype,allresults)
    local result = collect_instance_files(filename,filetype or "",allresults)
    if #result == 0 then
        local lowered = lower(filename)
        if filename ~= lowered then
            return collect_instance_files(lowered,filetype or "",allresults)
        end
    end
    return result
end

function resolvers.findfiles(filename,filetype)
    return findfiles(filename,filetype,true)
end

function resolvers.findfile(filename,filetype)
    return findfiles(filename,filetype,false)[1] or ""
end

function resolvers.findpath(filename,filetype)
    return filedirname(findfiles(filename,filetype,false)[1] or "")
end

local function findgivenfiles(filename,allresults)
    local bname, result = filebasename(filename), { }
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        local files = instance.files[hash.name] or { }
        local blist = files[bname]
        if not blist then
            local rname = "remap:"..bname
            blist = files[rname]
            if blist then
                bname = files[rname]
                blist = files[bname]
            end
        end
        if blist then
            if type(blist) == 'string' then
                result[#result+1] = methodhandler('concatinators',hash.type,hash.name,blist,bname) or ""
                if not allresults then break end
            else
                for kk=1,#blist do
                    local vv = blist[kk]
                    result[#result+1] = methodhandler('concatinators',hash.type,hash.name,vv,bname) or ""
                    if not allresults then break end
                end
            end
        end
    end
    return result
end

function resolvers.findgivenfiles(filename)
    return findgivenfiles(filename,true)
end

function resolvers.findgivenfile(filename)
    return findgivenfiles(filename,false)[1] or ""
end

local function doit(path,blist,bname,tag,kind,result,allresults)
    local done = false
    if blist and kind then
        if type(blist) == 'string' then
            -- make function and share code
            if find(lower(blist),path) then
                result[#result+1] = methodhandler('concatinators',kind,tag,blist,bname) or ""
                done = true
            end
        else
            for kk=1,#blist do
                local vv = blist[kk]
                if find(lower(vv),path) then
                    result[#result+1] = methodhandler('concatinators',kind,tag,vv,bname) or ""
                    done = true
                    if not allresults then break end
                end
            end
        end
    end
    return done
end

local makewildcard = Cs(
    (P("^")^0 * P("/") * P(-1) + P(-1)) /".*"
  + (P("^")^0 * P("/") / "") * (P("*")/".*" + P("-")/"%%-" + P("?")/"."+ P("\\")/"/" + P(1))^0
)

local function findwildcardfiles(filename,allresults) -- todo: remap: and lpeg
    local result = { }
    local path = lower(lpegmatch(makewildcard,filedirname (filename)))
    local name = lower(lpegmatch(makewildcard,filebasename(filename)))
    local files, done = instance.files, false
    if find(name,"%*") then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local hashname, hashtype = hash.name, hash.type
            for kk, hh in next, files[hashname] do
                if not find(kk,"^remap:") then
                    if find(lower(kk),name) then
                        if doit(path,hh,kk,hashname,hashtype,result,allresults) then done = true end
                        if done and not allresults then break end
                    end
                end
            end
        end
    else
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local hashname, hashtype = hash.name, hash.type
            if doit(path,files[hashname][bname],bname,hashname,hashtype,result,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    -- we can consider also searching the paths not in the database, but then
    -- we end up with a messy search (all // in all path specs)
    return result
end

function resolvers.findwildcardfiles(filename)
    return findwildcardfiles(filename,true)
end

function resolvers.findwildcardfile(filename)
    return findwildcardfiles(filename,false)[1] or ""
end

-- main user functions

function resolvers.automount()
    -- implemented later
end

function resolvers.load(option)
    statistics.starttiming(instance)
    identify_configuration_files()
    load_configuration_files()
    if option ~= "nofiles" then
        load_databases()
        resolvers.automount()
    end
    statistics.stoptiming(instance)
    local files = instance.files
    return files and next(files) and true
end

local function report(str)
    if trace_locating then
        report_resolvers(str) -- has already verbose
    else
        print(str)
    end
end

function resolvers.dowithfilesandreport(command, files, ...) -- will move
    if files and #files > 0 then
        if trace_locating then
            report('') -- ?
        end
        for f=1,#files do
            local file = files[f]
            local result = command(file,...)
            if type(result) == 'string' then
                report(result)
            else
                for i=1,#result do
                    report(result[i]) -- could be unpack
                end
            end
        end
    end
end

-- obsolete

-- resolvers.varvalue  = resolvers.variable   -- output the value of variable $STRING.
-- resolvers.expandvar = resolvers.expansion  -- output variable expansion of STRING.

function resolvers.showpath(str)     -- output search path for file type NAME
    return joinpath(resolvers.expandedpathlist(resolvers.formatofvariable(str)))
end

function resolvers.registerfile(files, name, path)
    if files[name] then
        if type(files[name]) == 'string' then
            files[name] = { files[name], path }
        else
            files[name] = path
        end
    else
        files[name] = path
    end
end

function resolvers.dowithpath(name,func)
    local pathlist = resolvers.expandedpathlist(name)
    for i=1,#pathlist do
        func("^"..resolvers.cleanpath(pathlist[i]))
    end
end

function resolvers.dowithvariable(name,func)
    func(expandedvariable(name))
end

function resolvers.locateformat(name)
    local barename = file.removesuffix(name) -- gsub(name,"%.%a+$","")
    local fmtname = caches.getfirstreadablefile(barename..".fmt","formats") or ""
    if fmtname == "" then
        fmtname = resolvers.findfile(barename..".fmt")
        fmtname = resolvers.cleanpath(fmtname)
    end
    if fmtname ~= "" then
        local barename = file.removesuffix(fmtname)
        local luaname, lucname, luiname = barename .. ".lua", barename .. ".luc", barename .. ".lui"
        if lfs.isfile(luiname) then
            return barename, luiname
        elseif lfs.isfile(lucname) then
            return barename, lucname
        elseif lfs.isfile(luaname) then
            return barename, luaname
        end
    end
    return nil, nil
end

function resolvers.booleanvariable(str,default)
    local b = resolvers.expansion(str)
    if b == "" then
        return default
    else
        b = toboolean(b)
        return (b == nil and default) or b
    end
end

function resolvers.dowithfilesintree(pattern,handle,before,after) -- will move, can be a nice iterator instead
    local instance = resolvers.instance
    local hashes = instance.hashes
    for i=1,#hashes do
        local hash = hashes[i]
        local blobtype = hash.type
        local blobpath = hash.name
        if blobpath then
            if before then
                before(blobtype,blobpath,pattern)
            end
            local files = instance.files[blobpath]
            local total, checked, done = 0, 0, 0
            if files then
                for k,v in next, files do
                    total = total + 1
                    if find(k,"^remap:") then
                        k = files[k]
                        v = k -- files[k] -- chained
                    end
                    if find(k,pattern) then
                        if type(v) == "string" then
                            checked = checked + 1
                            if handle(blobtype,blobpath,v,k) then
                                done = done + 1
                            end
                        else
                            checked = checked + #v
                            for i=1,#v do
                                if handle(blobtype,blobpath,v[i],k) then
                                    done = done + 1
                                end
                            end
                        end
                    end
                end
            end
            if after then
                after(blobtype,blobpath,pattern,total,checked,done)
            end
        end
    end
end

resolvers.obsolete = resolvers.obsolete or { }
local obsolete     = resolvers.obsolete

resolvers.find_file  = resolvers.findfile    obsolete.find_file  = resolvers.findfile
resolvers.find_files = resolvers.findfiles   obsolete.find_files = resolvers.findfiles
