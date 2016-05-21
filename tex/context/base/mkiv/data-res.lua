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
local concat, insert, remove, sortedkeys, sortedhash = table.concat, table.insert, table.remove, table.sortedkeys, table.sortedhash
local next, type, rawget = next, type, rawget
local os = os

local P, S, R, C, Cc, Cs, Ct, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local formatters        = string.formatters
local filedirname       = file.dirname
local filebasename      = file.basename
local suffixonly        = file.suffixonly
local addsuffix         = file.addsuffix
local removesuffix      = file.removesuffix
local filejoin          = file.join
local collapsepath      = file.collapsepath
local joinpath          = file.joinpath
local is_qualified_path = file.is_qualified_path

local allocate          = utilities.storage.allocate
local settings_to_array = utilities.parsers.settings_to_array

local getcurrentdir     = lfs.currentdir
local isfile            = lfs.isfile
local isdir             = lfs.isdir

local setmetatableindex = table.setmetatableindex
local luasuffixes       = utilities.lua.suffixes

local trace_locating    = false  trackers  .register("resolvers.locating",   function(v) trace_locating    = v end)
local trace_detail      = false  trackers  .register("resolvers.details",    function(v) trace_detail      = v end)
local trace_expansions  = false  trackers  .register("resolvers.expansions", function(v) trace_expansions  = v end)
local trace_paths       = false  trackers  .register("resolvers.paths",      function(v) trace_paths       = v end)
local resolve_otherwise = true   directives.register("resolvers.otherwise",  function(v) resolve_otherwise = v end)

local report_resolving = logs.reporter("resolvers","resolving")

local resolvers              = resolvers

local expandedpathfromlist   = resolvers.expandedpathfromlist
local checkedvariable        = resolvers.checkedvariable
local splitconfigurationpath = resolvers.splitconfigurationpath
local methodhandler          = resolvers.methodhandler
local filtered               = resolvers.filtered_from_content
local lookup                 = resolvers.get_from_content
local cleanpath              = resolvers.cleanpath
local resolveprefix          = resolvers.resolve

local initializesetter       = utilities.setters.initialize

local ostype, osname, osenv, ossetenv, osgetenv = os.type, os.name, os.env, os.setenv, os.getenv

resolvers.cacheversion  = "1.100"
resolvers.configbanner  = ""
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
local usertypes = resolvers.usertypes
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
        ossetenv(key,raw and value or resolveprefix(value))
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

local function resolvevariable(k)
    return instance.expansions[k]
end

local dollarstripper   = lpeg.stripper("$")
local inhibitstripper  = P("!")^0 * Cs(P(1)^0)

local somevariable     = P("$") / ""
local somekey          = C(R("az","AZ","09","__","--")^1)
local somethingelse    = P(";") * ((1-S("!{}/\\"))^1 * P(";") / "")
                       + P(";") * (P(";") / "")
                       + P(1)
local variableexpander = Cs( (somevariable * (somekey/resolvevariable) + somethingelse)^1 )

local cleaner          = P("\\") / "/" + P(";") * S("!{}/\\")^0 * P(";")^1 / ";"
local variablecleaner  = Cs((cleaner  + P(1))^0)

local somevariable     = R("az","AZ","09","__","--")^1 / resolvevariable
local variable         = (P("$")/"") * (somevariable + (P("{")/"") * somevariable * (P("}")/""))
local variableresolver = Cs((variable + P(1))^0)

local function expandedvariable(var)
    return lpegmatch(variableexpander,var) or var
end

function resolvers.newinstance() -- todo: all vars will become lowercase and alphanum only

    -- normally we only need one instance but for special cases we can (re)load one so
    -- we stick to this model.

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
        pathlists       = false,-- delayed
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
        pathstack       = { },
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
    instance.lists     = { }
    instance.pathlists = false
    instance.found     = { }
end

local function reset_caches()
    instance.lists     = { }
    instance.pathlists = false
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
            local realname = resolveprefix(filename) -- can still have "//" ... needs checking
            -- todo: environment.skipweirdcnfpaths directive
            if trace_locating then
                local fullpath  = gsub(resolveprefix(collapsepath(filepath)),"//","/")
                local weirdpath = find(fullpath,"/texmf.+/texmf") or not find(fullpath,"/web2c",1,true)
                report_resolving("looking for %a on %s path %a from specification %a",luacnfname,weirdpath and "weird" or "given",fullpath,filepath)
            end
            if isfile(realname) then
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
            local realname = resolveprefix(filename) -- no shortcut
            local blob = loadfile(realname)
            if blob then
                local setups = instance.setups
                local data = blob()
                local parent = data and data.parent
                if parent then
                    local filename = filejoin(pathname,parent)
                    local realname = resolveprefix(filename) -- no shortcut
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
                                    k,resolveprefix(filename))
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
                path = cleanpath(path)
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
        local realpath = resolveprefix(hashname)
        if isdir(realpath) then
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

function resolvers.pushpath(name)
    local pathstack = instance.pathstack
    local lastpath  = pathstack[#pathstack]
    local pluspath  = filedirname(name)
    if lastpath then
        lastpath = collapsepath(filejoin(lastpath,pluspath))
    else
        lastpath = collapsepath(pluspath)
    end
    insert(pathstack,lastpath)
    if trace_paths then
        report_resolving("pushing path %a",lastpath)
    end
end

function resolvers.poppath()
    local pathstack = instance.pathstack
    if trace_paths and #pathstack > 0 then
        report_resolving("popping path %a",pathstack[#pathstack])
    end
    remove(pathstack)
end

function resolvers.stackpath()
    local pathstack   = instance.pathstack
    local currentpath = pathstack[#pathstack]
    return currentpath ~= "" and currentpath or nil
end

local done = { }

function resolvers.resetextrapath()
    local ep = instance.extra_paths
    if not ep then
        done                 = { }
        instance.extra_paths = { }
    elseif #ep > 0 then
        done = { }
        reset_caches()
    end
end

function resolvers.registerextrapath(paths,subpaths)
    if not subpaths or subpaths == "" then
        if not paths or path == "" then
            return -- invalid spec
        elseif done[paths] then
            return -- already done
        end
    end
    local paths       = settings_to_array(paths)
    local subpaths    = settings_to_array(subpaths)
    local ep          = instance.extra_paths or { }
    local oldn        = #ep
    local newn        = oldn
    local nofpaths    = #paths
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
                        ep[newn] = cleanpath(ps)
                        done[ps] = true
                    end
                end
            end
        else
            for i=1,nofpaths do
                local p = paths[i]
                if not done[p] then
                    newn = newn + 1
                    ep[newn] = cleanpath(p)
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
                    ep[newn] = cleanpath(ps)
                    done[ps] = true
                end
            end
        end
    end
    if newn > 0 then
        instance.extra_paths = ep -- register paths
    end
    if newn ~= oldn then
        reset_caches()
    end
end

function resolvers.pushextrapath(path)
    local paths = settings_to_array(path)
    if instance.extra_stack then
        insert(instance.extra_stack,1,paths)
    else
        instance.extra_stack = { paths }
    end
    reset_caches()
end

function resolvers.popextrapath()
    if instance.extra_stack then
        reset_caches()
        return remove(instance.extra_stack,1)
    end
end

local function made_list(instance,list,extra_too)
    local done = { }
    local new  = { }
    local newn = 0
    -- a helper
    local function add(p)
        for k=1,#p do
            local v = p[k]
            if not done[v] then
                done[v] = true
                newn = newn + 1
                new[newn] = v
            end
        end
    end
    -- honour . .. ../.. but only when at the start
    for k=1,#list do
        local v = list[k]
        if done[v] then
            -- skip
        elseif find(v,"^[%.%/]$") then
            done[v] = true
            newn = newn + 1
            new[newn] = v
        else
            break
        end
    end
    if extra_too then
        -- first the stacked paths
        local es = instance.extra_stack
        if es and #es > 0 then
            for k=1,#es do
                add(es[k])
            end
        end
        -- then the extra paths
        local ep = instance.extra_paths
        if ep and #ep > 0 then
            add(ep)
        end
    end
    -- last the formal paths
    add(list)
    return new
end

function resolvers.cleanpathlist(str)
    local t = resolvers.expandedpathlist(str)
    if t then
        for i=1,#t do
            t[i] = collapsepath(cleanpath(t[i]))
        end
    end
    return t
end

function resolvers.expandpath(str)
    return joinpath(resolvers.expandedpathlist(str))
end

function resolvers.expandedpathlist(str,extra_too)
    if not str then
        return { }
    elseif instance.savelists then -- hm, what if two cases, with and without extra_too
        str = lpegmatch(dollarstripper,str)
        local lists = instance.lists
        local lst = lists[str]
        if not lst then
            local l = made_list(instance,resolvers.splitpath(resolvers.expansion(str)),extra_too)
            lst = expandedpathfromlist(l)
            lists[str] = lst
        end
        return lst
    else
        local lst = resolvers.splitpath(resolvers.expansion(str))
        return made_list(instance,expandedpathfromlist(lst),extra_too)
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

function resolvers.cleanedpathlist(v) -- can be cached if needed
    local t = resolvers.expandedpathlist(v)
    for i=1,#t do
        t[i] = resolvers.resolve(resolvers.cleanpath(t[i]))
    end
    return t
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
    local readable = isfile(name) -- not file.is_readable(name) asit can be a dir
    if trace_detail then
        if readable then
            report_resolving("file %a is readable",name)
        else
            report_resolving("file %a is not readable", name)
        end
    end
    return readable
end

-- name | name/name

local function collect_files(names) -- potential files .. sort of too much when asking for just one file
    local filelist = { }            -- but we need it for pattern matching later on
    local noffiles = 0
    local function check(hash,root,pathname,path,name)
        if not pathname or find(path,pathname) then
            local variant = hash.type
            local search  = filejoin(root,path,name) -- funny no concatinator
            local result  = methodhandler('concatinators',variant,root,path,name)
            if trace_detail then
                report_resolving("match: variant %a, search %a, result %a",variant,search,result)
            end
            noffiles = noffiles + 1
            filelist[noffiles] = { variant, search, result }
        end
    end
    for k=1,#names do
        local filename = names[k]
        if trace_detail then
            report_resolving("checking name %a",filename)
        end
        local basename = filebasename(filename)
        local pathname = filedirname(filename)
        if pathname == "" or find(pathname,"^%.") then
            pathname = false
        else
            pathname = gsub(pathname,"%*",".*")
            pathname = "/" .. pathname .. "$"
        end
        local hashes = instance.hashes
        for h=1,#hashes do
            local hash     = hashes[h]
            local hashname = hash.name
            local content  = hashname and instance.files[hashname]
            if content then
                if trace_detail then
                    report_resolving("deep checking %a, base %a, pattern %a",hashname,basename,pathname)
                end
                local path, name = lookup(content,basename)
                if path then
                    local metadata = content.metadata
                    local realroot = metadata and metadata.path or hashname
                    if type(path) == "string" then
                        check(hash,realroot,pathname,path,name)
                    else
                        for i=1,#path do
                            check(hash,realroot,pathname,path[i],name)
                        end
                    end
                end
            elseif trace_locating then
                report_resolving("no match in %a (%s)",hashname,basename)
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
        if isdir(name) then
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
            local formatofsuffix  = resolvers.formatofsuffix
            for i=1,#defaultsuffixes do
                local forcedname = filename .. '.' .. defaultsuffixes[i]
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = formatofsuffix(forcedname)
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
        local result = resolvers.findwildcardfiles(filename)
        if result then
            return "wildcard", result
        end
    end
end

local function find_qualified(filename,allresults,askedformat,alsostripped) -- this one will be split too
    if not is_qualified_path(filename) then
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

-- this caching is not really needed (seldom accessed) but more readable
-- we could probably move some to a higher level but then we need to adapt
-- more code ... maybe some day

local function makepathlist(list,filetype)
    local typespec = resolvers.variableofformat(filetype)
    local pathlist = resolvers.expandedpathlist(typespec,filetype and usertypes[filetype]) -- only extra path with user files
    local entry    = { }
    if pathlist and #pathlist > 0 then
        for k=1,#pathlist do
            local path       = pathlist[k]
            local prescanned = find(path,'^!!')
            local resursive  = find(path,'//$')
            local pathname   = lpegmatch(inhibitstripper,path)
            local expression = makepathexpression(pathname)
            local barename   = gsub(pathname,"/+$","")
            barename         = resolveprefix(barename)
            local scheme     = url.hasscheme(barename)
            local schemename = gsub(barename,"%.%*$",'') -- after scheme
         -- local prescanned = path ~= pathname -- ^!!
         -- local resursive  = find(pathname,'//$')
            entry[k] = {
                path       = path,
                pathname   = pathname,
                prescanned = prescanned,
                recursive  = recursive,
                expression = expression,
                barename   = barename,
                scheme     = scheme,
                schemename = schemename,
            }
        end
        entry.typespec = typespec
        list[filetype] = entry
    else
        list[filetype] = false
    end
    return entry
end

-- pathlist : resolved
-- dirlist  : unresolved or resolved
-- filelist : unresolved

local function find_intree(filename,filetype,wantedfiles,allresults)
    local pathlists = instance.pathlists
    if not pathlists then
        pathlists = setmetatableindex(allocate(),makepathlist)
        instance.pathlists = pathlists
    end
    local pathlist = pathlists[filetype]
    if pathlist then
        -- list search
        local method   = "intree"
        local filelist = collect_files(wantedfiles) -- okay, a bit over the top when we just look relative to the current path
        local dirlist  = { }
        local result   = { }
        if filelist then
            for i=1,#filelist do
                dirlist[i] = filedirname(filelist[i][3]) .. "/" -- was [2] .. gamble
            end
        end
        if trace_detail then
            report_resolving("checking filename %a in tree",filename)
        end
        for k=1,#pathlist do
            local entry    = pathlist[k]
            local path     = entry.path
            local pathname = entry.pathname
            local done     = false
            -- using file list
            if filelist then -- database
                -- compare list entries with permitted pattern -- /xx /xx//
                local expression = entry.expression
                if trace_detail then
                    report_resolving("using pattern %a for path %a",expression,pathname)
                end
                for k=1,#filelist do
                    local fl = filelist[k]
                    local f  = fl[2]
                    local d  = dirlist[k]
                    -- resolve is new:
                    if find(d,expression) or find(resolveprefix(d),expression) then
                        -- todo, test for readable
                        result[#result+1] = resolveprefix(fl[3]) -- no shortcut
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
                -- beware: we don't honor allresults here in a next attempt (done false)
                -- but that is kind of special anyway
                method       = "filesystem" -- bonus, even when !! is specified
                local scheme = entry.scheme
                if not scheme or scheme == "file" then
                    local pname = entry.schemename
                    if not find(pname,"*",1,true) then
                        if can_be_dir(pname) then
                            -- hm, rather useless as we don't go deeper and if we would we could also
                            -- auto generate the file database .. however, we need this for extra paths
                            -- that are not hashed (like sources on my machine) .. so, this is slightly
                            -- out of order but at least fast (and we seldom end up here, only when a file
                            -- is not already found
-- inspect(entry)
                            if not done and not entry.prescanned then
                                if trace_detail then
                                    report_resolving("quick root scan for %a",pname)
                                end
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
                                if not done and entry.recursive then -- maybe also when allresults
                                    -- collect files in path (and cache the result)
                                    if trace_detail then
                                        report_resolving("scanning filesystem for %a",pname)
                                    end
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
                        end
                    else
                        -- no access needed for non existing path, speedup (esp in large tree with lots of fake)
                    end
                else
                    -- we can have extra_paths that are urls
                    for k=1,#wantedfiles do
                        -- independent url scanner
                        local pname = entry.barename
                        local fname = methodhandler('finders',pname .. "/" .. wantedfiles[k])
                        if fname then
                            result[#result+1] = fname
                            done = true
                            if not allresults then
                                break
                            end
                        end
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
        return "otherwise", { resolveprefix(fl[3]) } -- filename
    end
end

-- we could have a loop over the 6 functions but then we'd have to
-- always analyze .. todo: use url split

collect_instance_files = function(filename,askedformat,allresults) -- uses nested
    if not filename or filename == "" then
        return { }
    end
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
            if askedformat == "" then
                stamp = formatters["%s::%s"](suffixonly(filename),filename)
            else
                stamp = formatters["%s::%s"](askedformat,filename)
            end
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
                report_resolving("remembering file %a using hash %a",filename,stamp)
            end
            instance.found[stamp] = result
        end
        return result
    end
end

-- -- -- end of main file search routing -- -- --

local function findfiles(filename,filetype,allresults)
    if not filename or filename == "" then
        return { }
    end
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
    if not filename or filename == "" then
        -- weird ... why called then
        return ""
    else
        return findfiles(filename,filetype,true)
    end
end

function resolvers.findfile(filename,filetype)
    if not filename or filename == "" then
        -- weird ... why called then
        return ""
    else
        return findfiles(filename,filetype,false)[1] or ""
    end
end

function resolvers.findpath(filename,filetype)
    return filedirname(findfiles(filename,filetype,false)[1] or "")
end

local function findgivenfiles(filename,allresults)
    local base    = filebasename(filename)
    local result  = { }
    local hashes  = instance.hashes
    --
    local function okay(hash,path,name)
        local found = methodhandler('concatinators',hash.type,hash.name,path,name)
        if found and found ~= "" then
            result[#result+1] = resolveprefix(found)
            return not allresults
        end
    end
    --
    for k=1,#hashes do
        local hash    = hashes[k]
        local content = instance.files[hash.name]
        if content then
            local path, name = lookup(content,base)
            if not path then
                -- no match
            elseif type(path) == "string" then
                if okay(hash,path,name) then
                    return result
                end
            else
                for i=1,#path do
                    if okay(hash,path[i],name) then
                        return result
                    end
                end
            end
        end
    end
    --
    return result
end

function resolvers.findgivenfiles(filename)
    return findgivenfiles(filename,true)
end

function resolvers.findgivenfile(filename)
    return findgivenfiles(filename,false)[1] or ""
end

local makewildcard = Cs(
    (P("^")^0 * P("/") * P(-1) + P(-1)) /".*"
  + (P("^")^0 * P("/") / "")^0 * (P("*")/".*" + P("-")/"%%-" + P(".")/"%%." + P("?")/"."+ P("\\")/"/" + P(1))^0
)

function resolvers.wildcardpattern(pattern)
    return lpegmatch(makewildcard,pattern) or pattern
end

-- we use more function calls than before but we also have smaller trees so
-- why bother

local function findwildcardfiles(filename,allresults,result)
    local result  = result or { }
    local base    = filebasename(filename)
    local dirn    = filedirname(filename)
    local path    = lower(lpegmatch(makewildcard,dirn) or dirn)
    local name    = lower(lpegmatch(makewildcard,base) or base)
    local files   = instance.files
    --
    if find(name,"*",1,true) then
        local hashes = instance.hashes
        local function okay(found,path,base,hashname,hashtype)
            if find(found,path) then
                local full = methodhandler('concatinators',hashtype,hashname,found,base)
                if full and full ~= "" then
                    result[#result+1] = resolveprefix(full)
                    return not allresults
                end
            end
        end
        for k=1,#hashes do
            local hash     = hashes[k]
            local hashname = hash.name
            local hashtype = hash.type
            if hashname and hashtype then
                for found, base in filtered(files[hashname],name) do
                    if type(found) == 'string' then
                        if okay(found,path,base,hashname,hashtype) then
                            break
                        end
                    else
                        for i=1,#found do
                            if okay(found[i],path,base,hashname,hashtype) then
                                break
                            end
                        end
                    end
                end
            end
        end
    else
        local function okayokay(found,path,base,hashname,hashtype)
            if find(found,path) then
                local full = methodhandler('concatinators',hashtype,hashname,found,base)
                if full and full ~= "" then
                    result[#result+1] = resolveprefix(full)
                    return not allresults
                end
            end
        end
        --
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash     = hashes[k]
            local hashname = hash.name
            local hashtype = hash.type
            if hashname and hashtype then
                local found, base = lookup(content,base)
                if not found then
                    -- nothing
                elseif type(found) == 'string' then
                    if okay(found,path,base,hashname,hashtype) then
                        break
                    end
                else
                    for i=1,#found do
                        if okay(found[i],path,base,hashname,hashtype) then
                            break
                        end
                    end
                end
            end
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
        func("^"..cleanpath(pathlist[i]))
    end
end

function resolvers.dowithvariable(name,func)
    func(expandedvariable(name))
end

function resolvers.locateformat(name)
    local engine = environment.ownmain or "luatex"
    local barename = removesuffix(name)
    local fullname = addsuffix(barename,"fmt")
    local fmtname = caches.getfirstreadablefile(fullname,"formats",engine) or ""
    if fmtname == "" then
        fmtname = resolvers.findfile(fullname)
        fmtname = cleanpath(fmtname)
    end
    if fmtname ~= "" then
        local barename = removesuffix(fmtname)
        local luaname = addsuffix(barename,luasuffixes.lua)
        local lucname = addsuffix(barename,luasuffixes.luc)
        local luiname = addsuffix(barename,luasuffixes.lui)
        if isfile(luiname) then
            return barename, luiname
        elseif isfile(lucname) then
            return barename, lucname
        elseif isfile(luaname) then
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
    local hashes   = instance.hashes
    for i=1,#hashes do
        local hash     = hashes[i]
        local blobtype = hash.type
        local blobpath = hash.name
        if blobtype and blobpath then
            local total   = 0
            local checked = 0
            local done    = 0
            if before then
                before(blobtype,blobpath,pattern)
            end
            for path, name in filtered(instance.files[blobpath],pattern) do
                if type(path) == "string" then
                    checked = checked + 1
                    if handle(blobtype,blobpath,path,name) then
                        done = done + 1
                    end
                else
                    checked = checked + #path
                    for i=1,#path do
                        if handle(blobtype,blobpath,path[i],name) then
                            done = done + 1
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

local obsolete     = resolvers.obsolete or { }
resolvers.obsolete = obsolete

resolvers.find_file  = resolvers.findfile    obsolete.find_file  = resolvers.findfile
resolvers.find_files = resolvers.findfiles   obsolete.find_files = resolvers.findfiles
