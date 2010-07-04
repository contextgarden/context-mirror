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
local next, type = next, type

local lpegP, lpegS, lpegR, lpegC, lpegCc, lpegCs, lpegCt = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local filedirname, filebasename, fileextname, filejoin = file.dirname, file.basename, file.extname, file.join
local collapse_path = file.collapse_path

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_detail     = false  trackers.register("resolvers.details",    function(v) trace_detail     = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_resolvers = logs.new("resolvers")

local expanded_path_from_list  = resolvers.expanded_path_from_list
local checked_variable         = resolvers.checked_variable
local split_configuration_path = resolvers.split_configuration_path

local ostype, osname, osenv, ossetenv, osgetenv = os.type, os.name, os.env, os.setenv, os.getenv

resolvers.cacheversion = '1.0.1'
resolvers.configbanner = ''
resolvers.homedir      = environment.homedir
resolvers.criticalvars = { "SELFAUTOLOC", "SELFAUTODIR", "SELFAUTOPARENT", "TEXMFCNF", "TEXMF", "TEXOS" }
resolvers.luacnfspec   = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}' -- rubish path
resolvers.luacnfname   = 'texmfcnf.lua'
resolvers.luacnfstate  = "unknown"

local unset_variable  = "unset"

local formats      = resolvers.formats
local suffixes     = resolvers.suffixes
local dangerous    = resolvers.dangerous
local suffixmap    = resolvers.suffixmap
local alternatives = resolvers.alternatives

resolvers.instance = resolvers.instance or nil -- the current one (slow access)
local     instance = resolvers.instance or nil -- the current one (fast access)

function resolvers.newinstance()

    local newinstance = {
        progname        = 'context',
        engine          = 'luatex',
        format          = '',
        environment     = { },
        variables       = { },
        expansions      = { },
        files           = { },
        setups          = { },
        order           = { },
        found           = { },
        foundintrees    = { },
        origins         = { },
        hashes          = { },
        specification   = { },
        lists           = { },
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        loaderror       = false,
        savelists       = true,
        allresults      = false,
        pattern         = nil, -- lists
        data            = { }, -- only for loading
        force_suffixes  = true,
        fakepaths       = { },
    }

    local ne = newinstance.environment

    for k, v in next, osenv do
        ne[upper(k)] = checked_variable(v)
    end

    return newinstance

end

function resolvers.setinstance(someinstance)
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

function resolvers.setenv(key,value)
    if instance then
        instance.environment[key] = value
        ossetenv(key,value)
    end
end

function resolvers.getenv(key)
    local value = instance.environment[key]
    if value and value ~= "" then
        return value
    else
        local e = osgetenv(key)
        return e ~= nil and e ~= "" and checked_variable(e) or ""
    end
end

resolvers.env = resolvers.getenv

local function expand_vars(lst) -- simple vars
    local variables, getenv = instance.variables, resolvers.getenv
    local function resolve(a)
        local va = variables[a] or ""
        return (va ~= "" and va) or getenv(a) or ""
    end
    for k=1,#lst do
        local var = lst[k]
        var = gsub(var,"%$([%a%d%_%-]+)",resolve)
        var = gsub(var,";+",";")
        var = gsub(var,";[!{}/\\]+;",";")
--~         var = gsub(var,"~",resolvers.homedir)
        lst[k] = var
    end
end

local function resolve(key)
    local value = instance.variables[key]
    if value and value ~= "" then
        return value
    end
    local value = instance.environment[key]
    if value and value ~= "" then
        return value
    end
    local e = osgetenv(key)
    return e ~= nil and e ~= "" and checked_variable(e) or ""
end

local function expanded_var(var) -- simple vars
    var = gsub(var,"%$([%a%d%_%-]+)",resolve)
    var = gsub(var,";+",";")
    var = gsub(var,";[!{}/\\]+;",";")
--~     var = gsub(var,"~",resolvers.homedir)
    return var
end

local function entry(entries,name)
    if name and name ~= "" then
        name = gsub(name,'%$','')
        local result = entries[name..'.'..instance.progname] or entries[name]
        if result then
            return result
        else
            result = resolvers.getenv(name)
            if result then
                instance.variables[name] = result
                resolvers.expand_variables()
                return instance.expansions[name] or ""
            end
        end
    end
    return ""
end

local function is_entry(entries,name)
    if name and name ~= "" then
        name = gsub(name,'%$','')
        return (entries[name..'.'..instance.progname] or entries[name]) ~= nil
    else
        return false
    end
end

function resolvers.report_critical_variables()
    if trace_locating then
        for i=1,#resolvers.criticalvars do
            local v = resolvers.criticalvars[i]
            report_resolvers("variable '%s' set to '%s'",v,resolvers.getenv(v) or "unknown")
        end
        report_resolvers()
    end
    resolvers.report_critical_variables = function() end
end

local function identify_configuration_files()
    local specification = instance.specification
    if #specification == 0 then
        local cnfspec = resolvers.getenv('TEXMFCNF')
        if cnfspec == "" then
            cnfspec = resolvers.luacnfspec
            resolvers.luacnfstate = "default"
        else
            resolvers.luacnfstate = "environment"
        end
        resolvers.report_critical_variables()
        resolvers.expand_variables()
        local cnfpaths = expanded_path_from_list(resolvers.split_path(cnfspec))
        expand_vars(cnfpaths) --- hm
        local luacnfname = resolvers.luacnfname
        for i=1,#cnfpaths do
            local filename = collapse_path(filejoin(cnfpaths[i],luacnfname))
            if lfs.isfile(filename) then
                specification[#specification+1] = filename
            end
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
            local blob = loadfile(filename)
            if blob then
                local data = blob()
                data = data and data.content
                local setups = instance.setups
                if data then
                    if trace_locating then
                        report_resolvers("loading configuration file '%s'",filename)
                        report_resolvers()
                    end
                    -- flattening is easier to deal with as we need to collapse
                    local t = { }
                    for k, v in next, data do -- v = progname
                        if v ~= unset_variable then
                            local kind = type(v)
                            if kind == "string" then
                                t[k] = v
                            elseif kind == "table" then
                                -- this operates on the table directly
                                setters.initialize(filename,k,v)
                                -- this doesn't (maybe metatables some day)
                                for kk, vv in next, v do -- vv = variable
                                    if vv ~= unset_variable then
                                        if type(vv) == "string" then
                                            t[kk.."."..k] = vv
                                        end
                                    end
                                end
                            else
                             -- report_resolvers("strange key '%s' in configuration file '%s'",k,filename)
                            end
                        end
                    end
                    setups[pathname] = t

                    if resolvers.luacnfstate == "default" then
                        -- the following code is not tested
                        local cnfspec = t["TEXMFCNF"]
                        if cnfspec then
                            -- we push the value into the main environment (osenv) so
                            -- that it takes precedence over the default one and therefore
                            -- also over following definitions
                            resolvers.setenv('TEXMFCNF',cnfspec)
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
                        report_resolvers("skipping configuration file '%s'",filename)
                    end
                    setups[pathname] = { }
                    instance.loaderror = true
                end
            elseif trace_locating then
                report_resolvers("skipping configuration file '%s'",filename)
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

local function collapse_configuration_data() -- potential optimization: pass start index (setup and configuration are shared)
    local order, variables, environment, origins = instance.order, instance.variables, instance.environment, instance.origins
    for i=1,#order do
        local c = order[i]
        for k,v in next, c do
            if variables[k] then
                -- okay
            else
                local ek = environment[k]
                if ek and ek ~= "" then
                    variables[k], origins[k] = ek, "env"
                else
                    local bv = checked_variable(v)
                    variables[k], origins[k] = bv, "cnf"
                end
            end
        end
    end
end

-- database loading

-- locators

function resolvers.locatedatabase(specification)
    return resolvers.methodhandler('locators', specification)
end

function resolvers.locators.tex(specification)
    if specification and specification ~= '' and lfs.isdir(specification) then
        if trace_locating then
            report_resolvers("tex locator '%s' found",specification)
        end
        resolvers.append_hash('file',specification,filename,true) -- cache
    elseif trace_locating then
        report_resolvers("tex locator '%s' not found",specification)
    end
end

-- hashers

function resolvers.hashdatabase(tag,name)
    return resolvers.methodhandler('hashers',tag,name)
end

local function load_file_databases()
    instance.loaderror, instance.files = false, { }
    if not instance.renewcache then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            resolvers.hashdatabase(hash.tag,hash.name)
            if instance.loaderror then break end
        end
    end
end

function resolvers.hashers.tex(tag,name) -- used where?
    local content = caches.loadcontent(tag,'files')
    if content then
        instance.files[tag] = content
    else
        instance.files[tag] = { }
        instance.loaderror = true
    end
end

local function locate_file_databases()
    -- todo: cache:// and tree:// (runtime)
    local texmfpaths = resolvers.expanded_path_list('TEXMF')
    for i=1,#texmfpaths do
        local path = collapse_path(texmfpaths[i])
        local stripped = gsub(path,"^!!","")
        local runtime = stripped == path
        path = resolvers.clean_path(path)
        if stripped ~= "" then
            if lfs.isdir(path) then
                local spec = resolvers.splitmethod(stripped)
                if spec.scheme == "cache" then
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
                resolvers.locatedatabase(stripped) -- nothing done with result
            else
                if trace_locating then
                    if runtime then
                        report_resolvers("skipping list of '%s' (runtime)",path)
                    else
                        report_resolvers("skipping list of '%s' (cached)",path)
                    end
                end
            end
        end
    end
    if trace_locating then
        report_resolvers()
    end
end

local function generate_file_databases()
    local hashes = instance.hashes
    for i=1,#hashes do
        resolvers.methodhandler('generators',hashes[i].tag)
    end
    if trace_locating then
        report_resolvers()
    end
end

local function save_file_databases() -- will become cachers
    for i=1,#instance.hashes do
        local hash = instance.hashes[i]
        local cachename = hash.tag
        if hash.cache then
            local content = instance.files[cachename]
            caches.collapsecontent(content)
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

function resolvers.append_hash(type,tag,name,cache)
    if trace_locating then
        report_resolvers("hash '%s' appended",tag)
    end
    insert(instance.hashes, { type = type, tag = tag, name = name, cache = cache } )
end

function resolvers.prepend_hash(type,tag,name,cache)
    if trace_locating then
        report_resolvers("hash '%s' prepended",tag)
    end
    insert(instance.hashes, 1, { type = type, tag = tag, name = name, cache = cache } )
end

function resolvers.extend_texmf_var(specification) -- crap, we could better prepend the hash
--  local t = resolvers.expanded_path_list('TEXMF') -- full expansion
    local t = resolvers.split_path(resolvers.getenv('TEXMF'))
    insert(t,1,specification)
    local newspec = concat(t,";")
    if instance.environment["TEXMF"] then
        instance.environment["TEXMF"] = newspec
    elseif instance.variables["TEXMF"] then
        instance.variables["TEXMF"] = newspec
    else
        -- weird
    end
    resolvers.expand_variables()
    reset_hashes()
end

function resolvers.generators.tex(specification,tag)
    instance.files[tag or specification] = resolvers.scan_files(specification)
end

function resolvers.splitexpansions()
    local ie = instance.expansions
    for k,v in next, ie do
        local t, h, p = { }, { }, split_configuration_path(v)
        for kk=1,#p do
            local vv = p[kk]
            if vv ~= "" and not h[vv] then
                t[#t+1] = vv
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

function resolvers.data_state()
    return caches.contentstate()
end

function resolvers.expand_variables()
    local expansions, environment, variables = { }, instance.environment, instance.variables
    local getenv = resolvers.getenv
    instance.expansions = expansions
    local engine, progname = instance.engine, instance.progname
    if type(engine)   ~= "string" then instance.engine,   engine   = "", "" end
    if type(progname) ~= "string" then instance.progname, progname = "", "" end
    if engine   ~= "" then environment['engine']   = engine   end
    if progname ~= "" then environment['progname'] = progname end
    for k,v in next, environment do
        local a, b = match(k,"^(%a+)%_(.*)%s*$")
        if a and b then
            expansions[a..'.'..b] = v
        else
            expansions[k] = v
        end
    end
    for k,v in next, environment do -- move environment to expansions (variables are already in there)
        if not expansions[k] then expansions[k] = v end
    end
    for k,v in next, variables do -- move variables to expansions
        if not expansions[k] then expansions[k] = v end
    end
    local busy = false
    local function resolve(a)
        busy = true
        return expansions[a] or getenv(a)
    end
    while true do
        busy = false
        for k,v in next, expansions do
            local s, n = gsub(v,"%$([%a%d%_%-]+)",resolve)
            local s, m = gsub(s,"%$%{([%a%d%_%-]+)%}",resolve)
            if n > 0 or m > 0 then
                s = gsub(s,";+",";")
                s = gsub(s,";[!{}/\\]+;",";")
                expansions[k]= s
            end
        end
        if not busy then break end
    end
    for k,v in next, expansions do
        expansions[k] = gsub(v,"\\", '/')
    end
end

function resolvers.variable(name)
    return entry(instance.variables,name)
end

function resolvers.expansion(name)
    return entry(instance.expansions,name)
end

function resolvers.is_variable(name)
    return is_entry(instance.variables,name)
end

function resolvers.is_expansion(name)
    return is_entry(instance.expansions,name)
end

function resolvers.unexpanded_path_list(str)
    local pth = resolvers.variable(str)
    local lst = resolvers.split_path(pth)
    return expanded_path_from_list(lst)
end

function resolvers.unexpanded_path(str)
    return file.join_path(resolvers.unexpanded_path_list(str))
end

local done = { }

function resolvers.reset_extra_path()
    local ep = instance.extra_paths
    if not ep then
        ep, done = { }, { }
        instance.extra_paths = ep
    elseif #ep > 0 then
        instance.lists, done = { }, { }
    end
end

function resolvers.register_extra_path(paths,subpaths)
    local ep = instance.extra_paths or { }
    local n = #ep
    if paths and paths ~= "" then
        if subpaths and subpaths ~= "" then
            for p in gmatch(paths,"[^,]+") do
                -- we gmatch each step again, not that fast, but used seldom
                for s in gmatch(subpaths,"[^,]+") do
                    local ps = p .. "/" .. s
                    if not done[ps] then
                        ep[#ep+1] = resolvers.clean_path(ps)
                        done[ps] = true
                    end
                end
            end
        else
            for p in gmatch(paths,"[^,]+") do
                if not done[p] then
                    ep[#ep+1] = resolvers.clean_path(p)
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
                    ep[#ep+1] = resolvers.clean_path(ps)
                    done[ps] = true
                end
            end
        end
    end
    if #ep > 0 then
        instance.extra_paths = ep -- register paths
    end
    if #ep > n then
        instance.lists = { } -- erase the cache
    end
end

local function made_list(instance,list)
    local ep = instance.extra_paths
    if not ep or #ep == 0 then
        return list
    else
        local done, new = { }, { }
        -- honour . .. ../.. but only when at the start
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                if find(v,"^[%.%/]$") then
                    done[v] = true
                    new[#new+1] = v
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
                new[#new+1] = v
            end
        end
        -- next the formal paths
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                done[v] = true
                new[#new+1] = v
            end
        end
        return new
    end
end

function resolvers.clean_path_list(str)
    local t = resolvers.expanded_path_list(str)
    if t then
        for i=1,#t do
            t[i] = collapse_path(resolvers.clean_path(t[i]))
        end
    end
    return t
end

function resolvers.expand_path(str)
    return file.join_path(resolvers.expanded_path_list(str))
end

function resolvers.expanded_path_list(str)
    if not str then
        return ep or { } -- ep ?
    elseif instance.savelists then
        -- engine+progname hash
        str = gsub(str,"%$","")
        if not instance.lists[str] then -- cached
            local lst = made_list(instance,resolvers.split_path(resolvers.expansion(str)))
            instance.lists[str] = expanded_path_from_list(lst)
        end
        return instance.lists[str]
    else
        local lst = resolvers.split_path(resolvers.expansion(str))
        return made_list(instance,expanded_path_from_list(lst))
    end
end

function resolvers.expanded_path_list_from_var(str) -- brrr
    local tmp = resolvers.var_of_format_or_suffix(gsub(str,"%$",""))
    if tmp ~= "" then
        return resolvers.expanded_path_list(tmp)
    else
        return resolvers.expanded_path_list(str)
    end
end

function resolvers.expand_path_from_var(str)
    return file.join_path(resolvers.expanded_path_list_from_var(str))
end

function resolvers.expand_braces(str) -- output variable and brace expansion of STRING
    local ori = resolvers.variable(str)
    local pth = expanded_path_from_list(resolvers.split_path(ori))
    return file.join_path(pth)
end

resolvers.isreadable = { }

function resolvers.isreadable.file(name)
    local readable = lfs.isfile(name) -- brrr
    if trace_detail then
        if readable then
            report_resolvers("file '%s' is readable",name)
        else
            report_resolvers("file '%s' is not readable", name)
        end
    end
    return readable
end

resolvers.isreadable.tex = resolvers.isreadable.file

-- name
-- name/name

local function collect_files(names)
    local filelist = { }
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
            local blobpath = hash.tag
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
                            local search = filejoin(blobpath,blobfile,bname)
                            local result = resolvers.concatinators[hash.type](blobroot,blobfile,bname)
                            if trace_detail then
                                report_resolvers("match: kind '%s', search '%s', result '%s'",kind,search,result)
                            end
                            filelist[#filelist+1] = { kind, search, result }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                local kind   = hash.type
                                local search = filejoin(blobpath,vv,bname)
                                local result = resolvers.concatinators[hash.type](blobroot,vv,bname)
                                if trace_detail then
                                    report_resolvers("match: kind '%s', search '%s', result '%s'",kind,search,result)
                                end
                                filelist[#filelist+1] = { kind, search, result }
                            end
                        end
                    end
                end
            elseif trace_locating then
                report_resolvers("no match in '%s' (%s)",blobpath,bname)
            end
        end
    end
    return #filelist > 0 and filelist or nil
end

function resolvers.register_in_trees(name)
    if not find(name,"^%.") then
        instance.foundintrees[name] = (instance.foundintrees[name] or 0) + 1 -- maybe only one
    end
end

-- split the next one up for readability (bu this module needs a cleanup anyway)

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

local function collect_instance_files(filename,collected) -- todo : plugin (scanners, checkers etc)
    local result = collected or { }
    local stamp  = nil
    filename = collapse_path(filename)
    -- speed up / beware: format problem
    if instance.remember then
        stamp = filename .. "--" .. instance.engine .. "--" .. instance.progname .. "--" .. instance.format
        if instance.found[stamp] then
            if trace_locating then
                report_resolvers("remembering file '%s'",filename)
            end
            resolvers.register_in_trees(filename) -- for tracing used files
            return instance.found[stamp]
        end
    end
    if not dangerous[instance.format or "?"] then
        if resolvers.isreadable.file(filename) then
            if trace_detail then
                report_resolvers("file '%s' found directly",filename)
            end
            instance.found[stamp] = { filename }
            return { filename }
        end
    end
    if find(filename,'%*') then
        if trace_locating then
            report_resolvers("checking wildcard '%s'", filename)
        end
        result = resolvers.find_wildcard_files(filename)
    elseif file.is_qualified_path(filename) then
        if resolvers.isreadable.file(filename) then
            if trace_locating then
                report_resolvers("qualified name '%s'", filename)
            end
            result = { filename }
        else
            local forcedname, ok, suffix = "", false, fileextname(filename)
            if suffix == "" then -- why
                if instance.format == "" then
                    forcedname = filename .. ".tex"
                    if resolvers.isreadable.file(forcedname) then
                        if trace_locating then
                            report_resolvers("no suffix, forcing standard filetype 'tex'")
                        end
                        result, ok = { forcedname }, true
                    end
                else
                    local format_suffixes = suffixes[instance.format]
                    if format_suffixes then
                        for i=1,#format_suffixes do
                            local s = format_suffixes[i]
                            forcedname = filename .. "." .. s
                            if resolvers.isreadable.file(forcedname) then
                                if trace_locating then
                                    report_resolvers("no suffix, forcing format filetype '%s'", s)
                                end
                                result, ok = { forcedname }, true
                                break
                            end
                        end
                    end
                end
            end
            if not ok and suffix ~= "" then
                -- try to find in tree (no suffix manipulation), here we search for the
                -- matching last part of the name
                local basename = filebasename(filename)
                local pattern = gsub(filename .. "$","([%.%-])","%%%1")
                local savedformat = instance.format
                local format = savedformat or ""
                if format == "" then
                    instance.format = resolvers.format_of_suffix(suffix)
                end
                if not format then
                    instance.format = "othertextfiles" -- kind of everything, maybe texinput is better
                end
                --
                if basename ~= filename then
                    local resolved = collect_instance_files(basename)
                    if #result == 0 then
                        local lowered = lower(basename)
                        if filename ~= lowered then
                            resolved = collect_instance_files(lowered)
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
        local filetype, extra, done, wantedfiles, ext = '', nil, false, { }, fileextname(filename)
        -- tricky as filename can be bla.1.2.3
--~         if not suffixmap[ext] then --- probably needs to be done elsewhere too
--~             wantedfiles[#wantedfiles+1] = filename
--~         end
        if ext == "" then
            if not instance.force_suffixes then
                wantedfiles[#wantedfiles+1] = filename
            end
        else
            wantedfiles[#wantedfiles+1] = filename
        end
        if instance.format == "" then
            if ext == "" or not suffixmap[ext] then
                local forcedname = filename .. '.tex'
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = resolvers.format_of_suffix(forcedname)
                if trace_locating then
                    report_resolvers("forcing filetype '%s'",filetype)
                end
            else
                filetype = resolvers.format_of_suffix(filename)
                if trace_locating then
                    report_resolvers("using suffix based filetype '%s'",filetype)
                end
            end
        else
            if ext == "" or not suffixmap[ext] then
                local format_suffixes = suffixes[instance.format]
                if format_suffixes then
                    for i=1,#format_suffixes do
                        wantedfiles[#wantedfiles+1] = filename .. "." .. format_suffixes[i]
                    end
                end
            end
            filetype = instance.format
            if trace_locating then
                report_resolvers("using given filetype '%s'",filetype)
            end
        end
        local typespec = resolvers.variable_of_format(filetype)
        local pathlist = resolvers.expanded_path_list(typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if trace_detail then
                report_resolvers("checking filename '%s', filetype '%s', wanted files '%s'",filename, filetype or '?',concat(wantedfiles," | "))
            end
            for k=1,#wantedfiles do
                local fname = wantedfiles[k]
                if fname and resolvers.isreadable.file(fname) then
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
            -- a bit messy ... esp the doscan setting here
            local doscan
            for k=1,#pathlist do
                local path = pathlist[k]
                if find(path,"^!!") then doscan  = false else doscan  = true  end
                local pathname = gsub(path,"^!+", '')
                done = false
                -- using file list
                if filelist then
                    local expression
                    -- compare list entries with permitted pattern -- /xx /xx//
                    if not find(pathname,"/$") then
                        expression = pathname .. "/"
                    else
                        expression = pathname
                    end
                    expression = gsub(expression,"([%-%.])","%%%1") -- this also influences
                    expression = gsub(expression,"//+$", '/.*')     -- later usage of pathname
                    expression = gsub(expression,"//", '/.-/')      -- not ok for /// but harmless
                    expression = "^" .. expression .. "$"
                    if trace_detail then
                        report_resolvers("using pattern '%s' for path '%s'",expression,pathname)
                    end
                    for k=1,#filelist do
                        local fl = filelist[k]
                        local f = fl[2]
                        local d = dirlist[k]
                        if find(d,expression) then
                            --- todo, test for readable
                            result[#result+1] = fl[3]
                            done = true
                            if instance.allresults then
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
                    if resolvers.splitmethod(pathname).scheme == 'file' then -- ?
                        local pname = gsub(pathname,"%.%*$",'')
                        if not find(pname,"%*") then
                            local ppname = gsub(pname,"/+$","")
                            if can_be_dir(ppname) then
                                for k=1,#wantedfiles do
                                    local w = wantedfiles[k]
                                    local fname = filejoin(ppname,w)
                                    if resolvers.isreadable.file(fname) then
                                        if trace_detail then
                                            report_resolvers("found '%s' by scanning",fname)
                                        end
                                        result[#result+1] = fname
                                        done = true
                                        if not instance.allresults then break end
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
                if done and not instance.allresults then break end
            end
        end
    end
    for k=1,#result do
        local rk = collapse_path(result[k])
        result[k] = rk
        resolvers.register_in_trees(rk) -- for tracing used files
    end
    if instance.remember then
        instance.found[stamp] = result
    end
    return result
end

if not resolvers.concatinators  then resolvers.concatinators = { } end

resolvers.concatinators.tex  = filejoin
resolvers.concatinators.file = resolvers.concatinators.tex

function resolvers.find_files(filename,filetype,mustexist)
    if type(mustexist) == boolean then
        -- all set
    elseif type(filetype) == 'boolean' then
        filetype, mustexist = nil, false
    elseif type(filetype) ~= 'string' then
        filetype, mustexist = nil, false
    end
    instance.format = filetype or ''
    local result = collect_instance_files(filename)
    if #result == 0 then
        local lowered = lower(filename)
        if filename ~= lowered then
            return collect_instance_files(lowered)
        end
    end
    instance.format = ''
    return result
end

function resolvers.find_file(filename,filetype,mustexist)
    return (resolvers.find_files(filename,filetype,mustexist)[1] or "")
end

function resolvers.find_path(filename,filetype)
    local path = resolvers.find_files(filename,filetype)[1] or ""
    -- todo return current path
    return file.dirname(path)
end

function resolvers.find_given_files(filename)
    local bname, result = filebasename(filename), { }
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        local files = instance.files[hash.tag] or { }
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
                result[#result+1] = resolvers.concatinators[hash.type](hash.tag,blist,bname) or ""
                if not instance.allresults then break end
            else
                for kk=1,#blist do
                    local vv = blist[kk]
                    result[#result+1] = resolvers.concatinators[hash.type](hash.tag,vv,bname) or ""
                    if not instance.allresults then break end
                end
            end
        end
    end
    return result
end

function resolvers.find_given_file(filename)
    return (resolvers.find_given_files(filename)[1] or "")
end

local function doit(path,blist,bname,tag,kind,result,allresults)
    local done = false
    if blist and kind then
        if type(blist) == 'string' then
            -- make function and share code
            if find(lower(blist),path) then
                result[#result+1] = resolvers.concatinators[kind](tag,blist,bname) or ""
                done = true
            end
        else
            for kk=1,#blist do
                local vv = blist[kk]
                if find(lower(vv),path) then
                    result[#result+1] = resolvers.concatinators[kind](tag,vv,bname) or ""
                    done = true
                    if not allresults then break end
                end
            end
        end
    end
    return done
end

function resolvers.find_wildcard_files(filename) -- todo: remap: and lpeg
    local result = { }
    local bname, dname = filebasename(filename), filedirname(filename)
    local path = gsub(dname,"^*/","")
    path = gsub(path,"*",".*")
    path = gsub(path,"-","%%-")
    if dname == "" then
        path = ".*"
    end
    local name = bname
    name = gsub(name,"*",".*")
    name = gsub(name,"-","%%-")
    path = lower(path)
    name = lower(name)
    local files, allresults, done = instance.files, instance.allresults, false
    if find(name,"%*") then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local tag, kind = hash.tag, hash.type
            for kk, hh in next, files[hash.tag] do
                if not find(kk,"^remap:") then
                    if find(lower(kk),name) then
                        if doit(path,hh,kk,tag,kind,result,allresults) then done = true end
                        if done and not allresults then break end
                    end
                end
            end
        end
    else
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local tag, kind = hash.tag, hash.type
            if doit(path,files[tag][bname],bname,tag,kind,result,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    -- we can consider also searching the paths not in the database, but then
    -- we end up with a messy search (all // in all path specs)
    return result
end

function resolvers.find_wildcard_file(filename)
    return (resolvers.find_wildcard_files(filename)[1] or "")
end

-- main user functions

function resolvers.automount()
    -- implemented later
end

function resolvers.load(option)
    statistics.starttiming(instance)
    identify_configuration_files()
    load_configuration_files()
    collapse_configuration_data()
    resolvers.expand_variables()
    if option ~= "nofiles" then
        load_databases()
        resolvers.automount()
    end
    statistics.stoptiming(instance)
    local files = instance.files
    return files and next(files) and true
end

function resolvers.for_files(command, files, filetype, mustexist)
    if files and #files > 0 then
        local function report(str)
            if trace_locating then
                report_resolvers(str) -- has already verbose
            else
                print(str)
            end
        end
        if trace_locating then
            report('') -- ?
        end
        for f=1,#files do
            local file = files[f]
            local result = command(file,filetype,mustexist)
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

-- strtab

resolvers.var_value  = resolvers.variable   -- output the value of variable $STRING.
resolvers.expand_var = resolvers.expansion  -- output variable expansion of STRING.

function resolvers.show_path(str)     -- output search path for file type NAME
    return file.join_path(resolvers.expanded_path_list(resolvers.format_of_var(str)))
end

-- resolvers.find_file(filename)
-- resolvers.find_file(filename, filetype, mustexist)
-- resolvers.find_file(filename, mustexist)
-- resolvers.find_file(filename, filetype)

function resolvers.register_file(files, name, path)
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

function resolvers.do_with_path(name,func)
    local pathlist = resolvers.expanded_path_list(name)
    for i=1,#pathlist do
        func("^"..resolvers.clean_path(pathlist[i]))
    end
end

function resolvers.do_with_var(name,func)
    func(expanded_var(name))
end

function resolvers.locate_format(name)
    local barename = gsub(name,"%.%a+$","")
    local fmtname = caches.getfirstreadablefile(barename..".fmt","formats") or ""
    if fmtname == "" then
        fmtname = resolvers.find_files(barename..".fmt")[1] or ""
        fmtname = resolvers.clean_path(fmtname)
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

function resolvers.boolean_variable(str,default)
    local b = resolvers.expansion(str)
    if b == "" then
        return default
    else
        b = toboolean(b)
        return (b == nil and default) or b
    end
end

function resolvers.with_files(pattern,handle,before,after) -- can be a nice iterator instead
    local instance = resolvers.instance
    local hashes = instance.hashes
    for i=1,#hashes do
        local hash = hashes[i]
        local blobtype = hash.type
        local blobpath = hash.tag
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
