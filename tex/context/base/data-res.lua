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

-- I will reimplement this module ... way too fuzzy now and we can work
-- with some sensible constraints as it is only is used for context.

-- todo: cache:/// home:/// selfautoparent:/// (sometime end 2012)

local gsub, find, lower, upper, match, gmatch = string.gsub, string.find, string.lower, string.upper, string.match, string.gmatch
local concat, insert, sortedkeys = table.concat, table.insert, table.sortedkeys
local next, type, rawget = next, type, rawget
local os = os

local P, S, R, C, Cc, Cs, Ct, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local formatters        = string.formatters
local filedirname       = file.dirname
local filebasename      = file.basename
local suffixonly        = file.suffixonly
local filejoin          = file.join
local collapsepath      = file.collapsepath
local joinpath          = file.joinpath
local allocate          = utilities.storage.allocate
local settings_to_array = utilities.parsers.settings_to_array
local setmetatableindex = table.setmetatableindex
local luasuffixes       = utilities.lua.suffixes
local getcurrentdir     = lfs.currentdir

local trace_locating    = false  trackers  .register("resolvers.locating",   function(v) trace_locating    = v end)
local trace_detail      = false  trackers  .register("resolvers.details",    function(v) trace_detail      = v end)
local trace_expansions  = false  trackers  .register("resolvers.expansions", function(v) trace_expansions  = v end)
local resolve_otherwise = true   directives.register("resolvers.otherwise",  function(v) resolve_otherwise = v end)

local report_resolving = logs.reporter("resolvers","resolving")

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
resolvers.luacnfname    = "texmfcnf.lua"
resolvers.luacnfstate   = "unknown"

-- The web2c tex binaries as well as kpse have built in paths for the configuration
-- files and there can be a depressing truckload of them. This is actually the weak
-- spot of a distribution. So we don't want:
--
-- resolvers.luacnfspec = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}'
--
-- but instead (for instance) use:
--
-- resolvers.luacnfspec = 'selfautoparent:{/texmf{-local,}{,/web2c}}'
--
-- which does not make texlive happy as there is a texmf-local tree one level up
-- (sigh), so we need this. We can assume web2c as mkiv does not run on older
-- texlives anyway.
--
-- texlive:
--
-- selfautoloc:
-- selfautoloc:/share/texmf-local/web2c
-- selfautoloc:/share/texmf-dist/web2c
-- selfautoloc:/share/texmf/web2c
-- selfautoloc:/texmf-local/web2c
-- selfautoloc:/texmf-dist/web2c
-- selfautoloc:/texmf/web2c
-- selfautodir:
-- selfautodir:/share/texmf-local/web2c
-- selfautodir:/share/texmf-dist/web2c
-- selfautodir:/share/texmf/web2c
-- selfautodir:/texmf-local/web2c
-- selfautodir:/texmf-dist/web2c
-- selfautodir:/texmf/web2c
-- selfautoparent:/../texmf-local/web2c
-- selfautoparent:
-- selfautoparent:/share/texmf-local/web2c
-- selfautoparent:/share/texmf-dist/web2c
-- selfautoparent:/share/texmf/web2c
-- selfautoparent:/texmf-local/web2c
-- selfautoparent:/texmf-dist/web2c
-- selfautoparent:/texmf/web2c
--
-- minimals:
--
-- home:texmf/web2c
-- selfautoparent:texmf-local/web2c
-- selfautoparent:texmf-context/web2c
-- selfautoparent:texmf/web2c

-- This is a real mess: you don't want to know what creepy paths end up in the default
-- configuration spec, for instance nested texmf- paths. I'd rather get away from it and
-- specify a proper search sequence but alas ... it is not permitted in texlive and there
-- is no way to check if we run a minimals as texmf-context is not in that spec. It's a
-- compiled-in permutation of historics with the selfautoloc, selfautodir, selfautoparent
-- resulting in weird combinations. So, when we eventually check the 30 something paths
-- we also report weird ones, with weird being: (1) duplicate /texmf or (2) no /web2c in
-- the names.

if environment.default_texmfcnf then
    resolvers.luacnfspec = "home:texmf/web2c;" .. environment.default_texmfcnf -- texlive + home: for taco etc
else
    resolvers.luacnfspec = concat ( {
        "home:texmf/web2c",
        "selfautoparent:/texmf-local/web2c",
        "selfautoparent:/texmf-context/web2c",
        "selfautoparent:/texmf-dist/web2c",
        "selfautoparent:/texmf/web2c",
    }, ";")
end

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

function resolvers.setenv(key,value,raw)
    if instance then
        -- this one will be consulted first when we stay inside
        -- the current environment (prefixes are not resolved here)
        instance.environment[key] = value
        -- we feed back into the environment, and as this is used
        -- by other applications (via os.execute) we need to make
        -- sure that prefixes are resolve
        ossetenv(key,raw and value or resolvers.resolve(value))
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

function resolvers.newinstance() -- todo: all vars will become lowercase and alphanum only

     if trace_locating then
        report_resolving("creating instance")
     end

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
        hashed          = allocate(),
        specification   = allocate(),
        lists           = allocate(),
        data            = allocate(), -- only for loading
        fakepaths       = allocate(),
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        renewtree       = false,
        loaderror       = false,
        savelists       = true,
        pattern         = nil, -- lists
        force_suffixes  = true,
    }

    setmetatableindex(variables,function(t,k)
        local v
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
    end)

    setmetatableindex(environment, function(t,k)
        local v = osgetenv(k)
        if v == nil then
            v = variables[k]
        end
        if v ~= nil then
            v = checkedvariable(v) or ""
        end
        v = resolvers.repath(v) -- for taco who has a : separated osfontdir
        t[k] = v
        return v
    end)

    setmetatableindex(expansions, function(t,k)
        local v = environment[k]
        if type(v) == "string" then
            v = lpegmatch(variableresolver,v)
            v = lpegmatch(variablecleaner,v)
        end
        t[k] = v
        return v
    end)

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

local pathexpressionpattern = Cs ( -- create lpeg instead (2013/2014)
    Cc("^") * (
        Cc("%") * S(".-")
      + slash^2 * P(-1) / "/.*"
   -- + slash^2 / "/.-/"
   -- + slash^2 / "/[^/]*/*"   -- too general
      + slash^2 / "/"
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

local function reportcriticalvariables(cnfspec)
    if trace_locating then
        for i=1,#resolvers.criticalvars do
            local k = resolvers.criticalvars[i]
            local v = resolvers.getenv(k) or "unknown" -- this one will not resolve !
            report_resolving("variable %a set to %a",k,v)
        end
        report_resolving()
        if cnfspec then
            report_resolving("using configuration specification %a",type(cnfspec) == "table" and concat(cnfspec,",") or cnfspec)
        end
        report_resolving()
    end
    reportcriticalvariables = function() end
end

local function identify_configuration_files()
    local specification = instance.specification
    if #specification == 0 then
        local cnfspec = getenv("TEXMFCNF")
        if cnfspec == "" then
            cnfspec = resolvers.luacnfspec
            resolvers.luacnfstate = "default"
        else
            resolvers.luacnfstate = "environment"
        end
        reportcriticalvariables(cnfspec)
        local cnfpaths = expandedpathfromlist(resolvers.splitpath(cnfspec))
        local luacnfname = resolvers.luacnfname
        for i=1,#cnfpaths do
            local filepath = cnfpaths[i]
            local filename = collapsepath(filejoin(filepath,luacnfname))
            local realname = resolvers.resolve(filename) -- can still have "//" ... needs checking
            -- todo: environment.skipweirdcnfpaths directive
            if trace_locating then
                local fullpath  = gsub(resolvers.resolve(collapsepath(filepath)),"//","/")
                local weirdpath = find(fullpath,"/texmf.+/texmf") or not find(fullpath,"/web2c",1,true)
                report_resolving("looking for %a on %s path %a from specification %a",luacnfname,weirdpath and "weird" or "given",fullpath,filepath)
            end
            if lfs.isfile(realname) then
                specification[#specification+1] = filename -- unresolved as we use it in matching, relocatable
                if trace_locating then
                    report_resolving("found configuration file %a",realname)
                end
            end
        end
        if trace_locating then
            report_resolving()
        end
    elseif trace_locating then
        report_resolving("configuration files already identified")
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
                local parent = data and data.parent
                if parent then
                    local filename = filejoin(pathname,parent)
                    local realname = resolvers.resolve(filename) -- no shortcut
                    local blob = loadfile(realname)
                    if blob then
                        local parentdata = blob()
                        if parentdata then
                            report_resolving("loading configuration file %a",filename)
                            data = table.merged(parentdata,data)
                        end
                    end
                end
                data = data and data.content
                if data then
                    if trace_locating then
                        report_resolving("loading configuration file %a",filename)
                        report_resolving()
                    end
                    local variables = data.variables or { }
                    local warning = false
                    for k, v in next, data do
                        local variant = type(v)
                        if variant == "table" then
                            initializesetter(filename,k,v)
                        elseif variables[k] == nil then
                            if trace_locating and not warning then
                                report_resolving("variables like %a in configuration file %a should move to the 'variables' subtable",
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
                            if trace_locating then
                                report_resolving("reloading configuration due to TEXMF redefinition")
                            end
                            -- we push the value into the main environment (osenv) so
                            -- that it takes precedence over the default one and therefore
                            -- also over following definitions
                            resolvers.setenv("TEXMFCNF",cnfspec) -- resolves prefixes
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
                        report_resolving("skipping configuration file %a (no content)",filename)
                    end
                    setups[pathname] = { }
                    instance.loaderror = true
                end
            elseif trace_locating then
                report_resolving("skipping configuration file %a (no valid format)",filename)
            end
            instance.order[#instance.order+1] = instance.setups[pathname]
            if instance.loaderror then
                break
            end
        end
    elseif trace_locating then
        report_resolving("warning: no lua configuration files found")
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
    local texmfpaths = resolvers.expandedpathlist("TEXMF")
    if #texmfpaths > 0 then
        for i=1,#texmfpaths do
            local path = collapsepath(texmfpaths[i])
            path = gsub(path,"/+$","") -- in case $HOME expands to something with a trailing /
            local stripped = lpegmatch(inhibitstripper,path) -- the !! thing
            if stripped ~= "" then
                local runtime = stripped == path
                path = resolvers.cleanpath(path)
                local spec = resolvers.splitmethod(stripped)
                if runtime and (spec.noscheme or spec.scheme == "file") then
                    stripped = "tree:///" .. stripped
                elseif spec.scheme == "cache" or spec.scheme == "file" then
                    stripped = spec.path
                end
                if trace_locating then
                    if runtime then
                        report_resolving("locating list of %a (runtime) (%s)",path,stripped)
                    else
                        report_resolving("locating list of %a (cached)",path)
                    end
                end
                methodhandler('locators',stripped)
            end
        end
        if trace_locating then
            report_resolving()
        end
    elseif trace_locating then
        report_resolving("no texmf paths are defined (using TEXMF)")
    end
end

local function generate_file_databases()
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        methodhandler('generators',hash.name)
    end
    if trace_locating then
        report_resolving()
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
                report_resolving("saving tree %a",cachename)
            end
            caches.savecontent(cachename,"files",content)
        elseif trace_locating then
            report_resolving("not saving runtime tree %a",cachename)
        end
    end
end

function resolvers.renew(hashname)
    if hashname and hashname ~= "" then
        local expanded = resolvers.expansion(hashname) or ""
        if expanded ~= "" then
            if trace_locating then
                report_resolving("identifying tree %a from %a",expanded,hashname)
            end
            hashname = expanded
        else
            if trace_locating then
                report_resolving("identifying tree %a",hashname)
            end
        end
        local realpath = resolvers.resolve(hashname)
        if lfs.isdir(realpath) then
            if trace_locating then
                report_resolving("using path %a",realpath)
            end
            methodhandler('generators',hashname)
            -- could be shared
            local content = instance.files[hashname]
            caches.collapsecontent(content)
            if trace_locating then
                report_resolving("saving tree %a",hashname)
            end
            caches.savecontent(hashname,"files",content)
            -- till here
        else
            report_resolving("invalid path %a",realpath)
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
    -- safeguard ... tricky as it's actually a bug when seen twice
    if not instance.hashed[name] then
        if trace_locating then
            report_resolving("hash %a appended",name)
        end
        insert(instance.hashes, { type = type, name = name, cache = cache } )
        instance.hashed[name] = cache
    end
end

function resolvers.prependhash(type,name,cache)
    -- safeguard ... tricky as it's actually a bug when seen twice
    if not instance.hashed[name] then
        if trace_locating then
            report_resolving("hash %a prepended",name)
        end
        insert(instance.hashes, 1, { type = type, name = name, cache = cache } )
        instance.hashed[name] = cache
    end
end

function resolvers.extendtexmfvariable(specification) -- crap, we could better prepend the hash
    local t = resolvers.splitpath(getenv("TEXMF")) -- okay?
    insert(t,1,specification)
    local newspec = concat(t,",") -- not ;
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
    paths = settings_to_array(paths)
    subpaths = settings_to_array(subpaths)
    local ep = instance.extra_paths or { }
    local oldn = #ep
    local newn = oldn
    local nofpaths = #paths
    local nofsubpaths = #subpaths
    if nofpaths > 0 then
        if nofsubpaths > 0 then
            for i=1,nofpaths do
                local p = paths[i]
                for j=1,nofsubpaths do
                    local s = subpaths[j]
                    local ps = p .. "/" .. s
                    if not done[ps] then
                        newn = newn + 1
                        ep[newn] = resolvers.cleanpath(ps)
                        done[ps] = true
                    end
                end
            end
        else
            for i=1,nofpaths do
                local p = paths[i]
                if not done[p] then
                    newn = newn + 1
                    ep[newn] = resolvers.cleanpath(p)
                    done[p] = true
                end
            end
        end
    elseif nofsubpaths > 0 then
        for i=1,oldn do
            for j=1,nofsubpaths do
                local s = subpaths[j]
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
        local lists = instance.lists
        local lst = lists[str]
        if not lst then
            local l = made_list(instance,resolvers.splitpath(resolvers.expansion(str)))
            lst = expandedpathfromlist(l)
            lists[str] = lst
        end
        return lst
    else
        local lst = resolvers.splitpath(resolvers.expansion(str))
        return made_list(instance,expandedpathfromlist(lst))
    end
end

function resolvers.expandedpathlistfromvariable(str) -- brrr / could also have cleaner ^!! /$ //
    str = lpegmatch(dollarstripper,str)
    local tmp = resolvers.variableofformatorsuffix(str)
    return resolvers.expandedpathlist(tmp ~= "" and tmp or str)
end

function resolvers.expandpathfromvariable(str)
    return joinpath(resolvers.expandedpathlistfromvariable(str))
end

function resolvers.expandbraces(str) -- output variable and brace expansion of STRING
--     local ori = resolvers.variable(str)
--     if ori == "" then
        local ori = str
--     end
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

local function isreadable(name)
    local readable = lfs.isfile(name) -- not file.is_readable(name) asit can be a dir
    if trace_detail then
        if readable then
            report_resolving("file %a is readable",name)
        else
            report_resolving("file %a is not readable", name)
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
            report_resolving("checking name %a",fname)
        end
        local bname = filebasename(fname)
        local dname = filedirname(fname)
        if dname == "" or find(dname,"^%.") then
            dname = false
        else
            dname = gsub(dname,"%*",".*")
            dname = "/" .. dname .. "$"
        end
        local hashes = instance.hashes
        for h=1,#hashes do
            local hash = hashes[h]
            local blobpath = hash.name
            local files = blobpath and instance.files[blobpath]
            if files then
                if trace_detail then
                    report_resolving("deep checking %a, base %a, pattern %a",blobpath,bname,dname)
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
                            local variant = hash.type
                         -- local search  = filejoin(blobpath,blobfile,bname)
                            local search  = filejoin(blobroot,blobfile,bname)
                            local result  = methodhandler('concatinators',hash.type,blobroot,blobfile,bname)
                            if trace_detail then
                                report_resolving("match: variant %a, search %a, result %a",variant,search,result)
                            end
                            noffiles = noffiles + 1
                            filelist[noffiles] = { variant, search, result }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                local variant = hash.type
                             -- local search  = filejoin(blobpath,vv,bname)
                                local search  = filejoin(blobroot,vv,bname)
                                local result  = methodhandler('concatinators',hash.type,blobroot,vv,bname)
                                if trace_detail then
                                    report_resolving("match: variant %a, search %a, result %a",variant,search,result)
                                end
                                noffiles = noffiles + 1
                                filelist[noffiles] = { variant, search, result }
                            end
                        end
                    end
                end
            elseif trace_locating then
                report_resolving("no match in %a (%s)",blobpath,bname)
            end
        end
    end
    return noffiles > 0 and filelist or nil
end

local fit = { }

function resolvers.registerintrees(filename,format,filetype,usedmethod,foundname)
    local foundintrees = instance.foundintrees
    if usedmethod == "direct" and filename == foundname and fit[foundname] then
        -- just an extra lookup after a test on presence
    else
        local t = {
            filename   = filename,
            format     = format ~= "" and format or nil,
            filetype   = filetype  ~= "" and filetype or nil,
            usedmethod = usedmethod,
            foundname  = foundname,
        }
        fit[foundname] = t
        foundintrees[#foundintrees+1] = t
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

-- -- -- begin of main file search routing -- -- -- needs checking as previous has been patched

local collect_instance_files

local function find_analyze(filename,askedformat,allresults)
    local filetype, wantedfiles, ext = '', { }, suffixonly(filename)
    -- too tricky as filename can be bla.1.2.3:
    --
    -- if not suffixmap[ext] then
    --     wantedfiles[#wantedfiles+1] = filename
    -- end
    wantedfiles[#wantedfiles+1] = filename
    if askedformat == "" then
        if ext == "" or not suffixmap[ext] then
            local defaultsuffixes = resolvers.defaultsuffixes
            for i=1,#defaultsuffixes do
                local forcedname = filename .. '.' .. defaultsuffixes[i]
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = resolvers.formatofsuffix(forcedname)
                if trace_locating then
                    report_resolving("forcing filetype %a",filetype)
                end
            end
        else
            filetype = resolvers.formatofsuffix(filename)
            if trace_locating then
                report_resolving("using suffix based filetype %a",filetype)
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
            report_resolving("using given filetype %a",filetype)
        end
    end
    return filetype, wantedfiles
end

local function find_direct(filename,allresults)
    if not dangerous[askedformat] and isreadable(filename) then
        if trace_detail then
            report_resolving("file %a found directly",filename)
        end
        return "direct", { filename }
    end
end

local function find_wildcard(filename,allresults)
    if find(filename,'*',1,true) then
        if trace_locating then
            report_resolving("checking wildcard %a", filename)
        end
        local method, result = resolvers.findwildcardfiles(filename)
        if result then
            return "wildcard", result
        end
    end
end

local function find_qualified(filename,allresults,askedformat,alsostripped) -- this one will be split too
    if not file.is_qualified_path(filename) then
        return
    end
    if trace_locating then
        report_resolving("checking qualified name %a", filename)
    end
    if isreadable(filename) then
        if trace_detail then
            report_resolving("qualified file %a found", filename)
        end
        return "qualified", { filename }
    end
    if trace_detail then
        report_resolving("locating qualified file %a", filename)
    end
    local forcedname, suffix = "", suffixonly(filename)
    if suffix == "" then -- why
        local format_suffixes = askedformat == "" and resolvers.defaultsuffixes or suffixes[askedformat]
        if format_suffixes then
            for i=1,#format_suffixes do
                local s = format_suffixes[i]
                forcedname = filename .. "." .. s
                if isreadable(forcedname) then
                    if trace_locating then
                        report_resolving("no suffix, forcing format filetype %a", s)
                    end
                    return "qualified", { forcedname }
                end
            end
        end
    end
    if alsostripped and suffix and suffix ~= "" then
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
            askedformat = "othertextfiles" -- kind of everything, maybe all
        end
        --
        -- is this really what we want? basename if we have an explicit path?
        --
        if basename ~= filename then
            local resolved = collect_instance_files(basename,askedformat,allresults)
            if #resolved == 0 then
                local lowered = lower(basename)
                if filename ~= lowered then
                    resolved = collect_instance_files(lowered,askedformat,allresults)
                end
            end
            resolvers.format = savedformat
            --
            if #resolved > 0 then
                local result = { }
                for r=1,#resolved do
                    local rr = resolved[r]
                    if find(rr,pattern) then
                        result[#result+1] = rr
                    end
                end
                if #result > 0 then
                    return "qualified", result
                end
            end
        end
        -- a real wildcard:
        --
        -- local filelist = collect_files({basename})
        -- result = { }
        -- for f=1,#filelist do
        --     local ff = filelist[f][3] or ""
        --     if find(ff,pattern) then
        --         result[#result+1], ok = ff, true
        --     end
        -- end
        -- if #result > 0 then
        --     return "qualified", result
        -- end
    end
end

local function check_subpath(fname)
    if isreadable(fname) then
        if trace_detail then
            report_resolving("found %a by deep scanning",fname)
        end
        return fname
    end
end

local function find_intree(filename,filetype,wantedfiles,allresults)
    local typespec = resolvers.variableofformat(filetype)
    local pathlist = resolvers.expandedpathlist(typespec)
    local method = "intree"
    if pathlist and #pathlist > 0 then
        -- list search
        local filelist = collect_files(wantedfiles)
        local dirlist = { }
        if filelist then
            for i=1,#filelist do
                dirlist[i] = filedirname(filelist[i][3]) .. "/" -- was [2] .. gamble
            end
        end
        if trace_detail then
            report_resolving("checking filename %a",filename)
        end
        local resolve = resolvers.resolve
        local result = { }
        -- pathlist : resolved
        -- dirlist  : unresolved or resolved
        -- filelist : unresolved
        for k=1,#pathlist do
            local path = pathlist[k]
            local pathname = lpegmatch(inhibitstripper,path)
            local doscan = path == pathname -- no ^!!
            if not find (pathname,'//$') then
                doscan = false -- we check directly on the path
            end
            local done = false
            -- using file list
            if filelist then -- database
                -- compare list entries with permitted pattern -- /xx /xx//
                local expression = makepathexpression(pathname)
                if trace_detail then
                    report_resolving("using pattern %a for path %a",expression,pathname)
                end
                for k=1,#filelist do
                    local fl = filelist[k]
                    local f = fl[2]
                    local d = dirlist[k]
                    -- resolve is new:
                    if find(d,expression) or find(resolve(d),expression) then
                        -- todo, test for readable
                        result[#result+1] = resolve(fl[3]) -- no shortcut
                        done = true
                        if allresults then
                            if trace_detail then
                                report_resolving("match to %a in hash for file %a and path %a, continue scanning",expression,f,d)
                            end
                        else
                            if trace_detail then
                                report_resolving("match to %a in hash for file %a and path %a, quit scanning",expression,f,d)
                            end
                            break
                        end
                    elseif trace_detail then
                        report_resolving("no match to %a in hash for file %a and path %a",expression,f,d)
                    end
                end
            end
            if done then
                method = "database"
            else
                method = "filesystem" -- bonus, even when !! is specified
                pathname = gsub(pathname,"/+$","")
                pathname = resolve(pathname)
                local scheme = url.hasscheme(pathname)
                if not scheme or scheme == "file" then
                    local pname = gsub(pathname,"%.%*$",'')
                    if not find(pname,"*",1,true) then
                        if can_be_dir(pname) then
                            -- quick root scan first
                            for k=1,#wantedfiles do
                                local w = wantedfiles[k]
                                local fname = check_subpath(filejoin(pname,w))
                                if fname then
                                    result[#result+1] = fname
                                    done = true
                                    if not allresults then
                                        break
                                    end
                                end
                            end
                            if not done and doscan then
                                -- collect files in path (and cache the result)
                                local files = resolvers.simplescanfiles(pname,false,true)
                                for k=1,#wantedfiles do
                                    local w = wantedfiles[k]
                                    local subpath = files[w]
                                    if not subpath or subpath == "" then
                                        -- rootscan already done
                                    elseif type(subpath) == "string" then
                                        local fname = check_subpath(filejoin(pname,subpath,w))
                                        if fname then
                                            result[#result+1] = fname
                                            done = true
                                            if not allresults then
                                                break
                                            end
                                        end
                                    else
                                        for i=1,#subpath do
                                            local sp = subpath[i]
                                            if sp == "" then
                                                -- roottest already done
                                            else
                                                local fname = check_subpath(filejoin(pname,sp,w))
                                                if fname then
                                                    result[#result+1] = fname
                                                    done = true
                                                    if not allresults then
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if done and not allresults then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else
                        -- no access needed for non existing path, speedup (esp in large tree with lots of fake)
                    end
                end
            end
            -- todo recursive scanning
            if done and not allresults then
                break
            end
        end
        if #result > 0 then
            return method, result
        end
    end
end

local function find_onpath(filename,filetype,wantedfiles,allresults)
    if trace_detail then
        report_resolving("checking filename %a, filetype %a, wanted files %a",filename,filetype,concat(wantedfiles," | "))
    end
    local result = { }
    for k=1,#wantedfiles do
        local fname = wantedfiles[k]
        if fname and isreadable(fname) then
            filename = fname
            result[#result+1] = filejoin('.',fname)
            if not allresults then
                break
            end
        end
    end
    if #result > 0 then
        return "onpath", result
    end
end

local function find_otherwise(filename,filetype,wantedfiles,allresults) -- other text files | any | whatever
    local filelist = collect_files(wantedfiles)
    local fl = filelist and filelist[1]
    if fl then
        return "otherwise", { resolvers.resolve(fl[3]) } -- filename
    end
end

-- we could have a loop over the 6 functions but then we'd have to
-- always analyze .. todo: use url split

collect_instance_files = function(filename,askedformat,allresults) -- uses nested
    askedformat = askedformat or ""
    filename = collapsepath(filename,".")

    filename = gsub(filename,"^%./",getcurrentdir().."/") -- we will merge dir.expandname and collapse some day

    if allresults then
        -- no need for caching, only used for tracing
        local filetype, wantedfiles = find_analyze(filename,askedformat)
        local results = {
            { find_direct   (filename,true) },
            { find_wildcard (filename,true) },
            { find_qualified(filename,true,askedformat) }, -- we can add ,true if we want to find dups
            { find_intree   (filename,filetype,wantedfiles,true) },
            { find_onpath   (filename,filetype,wantedfiles,true) },
            { find_otherwise(filename,filetype,wantedfiles,true) },
        }
        local result, status, done = { }, { }, { }
        for k, r in next, results do
            local method, list = r[1], r[2]
            if method and list then
                for i=1,#list do
                    local c = collapsepath(list[i])
                    if not done[c] then
                        result[#result+1] = c
                        done[c] = true
                    end
                    status[#status+1] = formatters["%-10s: %s"](method,c)
                end
            end
        end
        if trace_detail then
            report_resolving("lookup status: %s",table.serialize(status,filename))
        end
        return result, status
    else
        local method, result, stamp, filetype, wantedfiles
        if instance.remember then
            stamp = formatters["%s--%s"](filename,askedformat)
            result = stamp and instance.found[stamp]
            if result then
                if trace_locating then
                    report_resolving("remembered file %a",filename)
                end
                return result
            end
        end
        method, result = find_direct(filename)
        if not result then
            method, result = find_wildcard(filename)
            if not result then
                method, result = find_qualified(filename,false,askedformat)
                if not result then
                    filetype, wantedfiles = find_analyze(filename,askedformat)
                    method, result = find_intree(filename,filetype,wantedfiles)
                    if not result then
                        method, result = find_onpath(filename,filetype,wantedfiles)
                        if resolve_otherwise and not result then
                            -- this will search everywhere in the tree
                            method, result = find_otherwise(filename,filetype,wantedfiles)
                        end
                    end
                end
            end
        end
        if result and #result > 0 then
            local foundname = collapsepath(result[1])
            resolvers.registerintrees(filename,askedformat,filetype,method,foundname)
            result = { foundname }
        else
            result = { } -- maybe false
        end
        if stamp then
            if trace_locating then
                report_resolving("remembering file %a",filename)
            end
            instance.found[stamp] = result
        end
        return result
    end
end

-- -- -- end of main file search routing -- -- --

local function findfiles(filename,filetype,allresults)
    local result, status = collect_instance_files(filename,filetype or "",allresults)
    if not result or #result == 0 then
        local lowered = lower(filename)
        if filename ~= lowered then
            result, status = collect_instance_files(lowered,filetype or "",allresults)
        end
    end
    return result or { }, status
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
    local noffound = 0
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
                local found = methodhandler('concatinators',hash.type,hash.name,blist,bname) or ""
                if found ~= "" then
                    noffound = noffound + 1
                    result[noffound] = resolvers.resolve(found)
                    if not allresults then
                        break
                    end
                end
            else
                for kk=1,#blist do
                    local vv = blist[kk]
                    local found = methodhandler('concatinators',hash.type,hash.name,vv,bname) or ""
                    if found ~= "" then
                        noffound = noffound + 1
                        result[noffound] = resolvers.resolve(found)
                        if not allresults then break end
                    end
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

local function doit(path,blist,bname,tag,variant,result,allresults)
    local done = false
    if blist and variant then
        local resolve = resolvers.resolve -- added
        if type(blist) == 'string' then
            -- make function and share code
            if find(lower(blist),path) then
                local full = methodhandler('concatinators',variant,tag,blist,bname) or ""
                result[#result+1] = resolve(full)
                done = true
            end
        else
            for kk=1,#blist do
                local vv = blist[kk]
                if find(lower(vv),path) then
                    local full = methodhandler('concatinators',variant,tag,vv,bname) or ""
                    result[#result+1] = resolve(full)
                    done = true
                    if not allresults then break end
                end
            end
        end
    end
    return done
end

--~ local makewildcard = Cs(
--~     (P("^")^0 * P("/") * P(-1) + P(-1)) /".*"
--~   + (P("^")^0 * P("/") / "") * (P("*")/".*" + P("-")/"%%-" + P("?")/"."+ P("\\")/"/" + P(1))^0
--~ )

local makewildcard = Cs(
    (P("^")^0 * P("/") * P(-1) + P(-1)) /".*"
  + (P("^")^0 * P("/") / "")^0 * (P("*")/".*" + P("-")/"%%-" + P(".")/"%%." + P("?")/"."+ P("\\")/"/" + P(1))^0
)

function resolvers.wildcardpattern(pattern)
    return lpegmatch(makewildcard,pattern) or pattern
end

local function findwildcardfiles(filename,allresults,result) -- todo: remap: and lpeg
    result = result or { }
--~     local path = lower(lpegmatch(makewildcard,filedirname (filename)))
--~     local name = lower(lpegmatch(makewildcard,filebasename(filename)))
    local base = filebasename(filename)
    local dirn = filedirname(filename)
    local path = lower(lpegmatch(makewildcard,dirn) or dirn)
    local name = lower(lpegmatch(makewildcard,base) or base)
    local files, done = instance.files, false
    if find(name,"*",1,true) then
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
-- inspect(hashes)
        for k=1,#hashes do
            local hash = hashes[k]
            local hashname, hashtype = hash.name, hash.type
            if doit(path,files[hashname][base],base,hashname,hashtype,result,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    -- we can consider also searching the paths not in the database, but then
    -- we end up with a messy search (all // in all path specs)
    return result
end

function resolvers.findwildcardfiles(filename,result)
    return findwildcardfiles(filename,true,result)
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

function resolvers.loadtime()
    return statistics.elapsedtime(instance)
end

local function report(str)
    if trace_locating then
        report_resolving(str) -- has already verbose
    else
        print(str)
    end
end

function resolvers.dowithfilesandreport(command, files, ...) -- will move
    if files and #files > 0 then
        if trace_locating then
            report('') -- ?
        end
        if type(files) == "string" then
            files = { files }
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
    local engine = environment.ownmain or "luatex"
    local barename = file.removesuffix(name)
    local fullname = file.addsuffix(barename,"fmt")
    local fmtname = caches.getfirstreadablefile(fullname,"formats",engine) or ""
    if fmtname == "" then
        fmtname = resolvers.findfile(fullname)
        fmtname = resolvers.cleanpath(fmtname)
    end
    if fmtname ~= "" then
        local barename = file.removesuffix(fmtname)
        local luaname = file.addsuffix(barename,luasuffixes.lua)
        local lucname = file.addsuffix(barename,luasuffixes.luc)
        local luiname = file.addsuffix(barename,luasuffixes.lui)
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
                for k, v in table.sortedhash(files) do -- next, files do, beware: this is not the resolve order
                    total = total + 1
                    if find(k,"^remap:") then
                        -- forget about these
                    elseif find(k,pattern) then
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
