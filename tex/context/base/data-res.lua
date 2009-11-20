if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- After a few years using the code the large luat-inp.lua file
-- has been split up a bit. In the process some functionality was
-- dropped:
--
-- * support for reading lsr files
-- * selective scanning (subtrees)
-- * some public auxiliary functions were made private
--
-- TODO: os.getenv -> os.env[]
-- TODO: instances.[hashes,cnffiles,configurations,522] -> ipairs (alles check, sneller)
-- TODO: check escaping in find etc, too much, too slow

-- This lib is multi-purpose and can be loaded again later on so that
-- additional functionality becomes available. We will split thislogs.report("fileio",
-- module in components once we're done with prototyping. This is the
-- first code I wrote for LuaTeX, so it needs some cleanup. Before changing
-- something in this module one can best check with Taco or Hans first; there
-- is some nasty trickery going on that relates to traditional kpse support.

-- To be considered: hash key lowercase, first entry in table filename
-- (any case), rest paths (so no need for optimization). Or maybe a
-- separate table that matches lowercase names to mixed case when
-- present. In that case the lower() cases can go away. I will do that
-- only when we run into problems with names ... well ... Iwona-Regular.

-- Beware, loading and saving is overloaded in luat-tmp!

local format, gsub, find, lower, upper, match, gmatch = string.format, string.gsub, string.find, string.lower, string.upper, string.match, string.gmatch
local concat, insert, sortedkeys = table.concat, table.insert, table.sortedkeys
local next, type = next, type

local collapse_path = file.collapse_path

local trace_locating, trace_detail, trace_verbose  = false, false, false

trackers.register("resolvers.verbose",  function(v) trace_verbose  = v end)
trackers.register("resolvers.locating", function(v) trace_locating = v trackers.enable("resolvers.verbose") end)
trackers.register("resolvers.detail",   function(v) trace_detail   = v trackers.enable("resolvers.verbose,resolvers.detail") end)

if not resolvers then
    resolvers = {
        suffixes     = { },
        formats      = { },
        dangerous    = { },
        suffixmap    = { },
        alternatives = { },
        locators     = { },  -- locate databases
        hashers      = { },  -- load databases
        generators   = { },  -- generate databases
    }
end

local resolvers = resolvers

resolvers.locators  .notfound = { nil }
resolvers.hashers   .notfound = { nil }
resolvers.generators.notfound = { nil }

resolvers.cacheversion = '1.0.1'
resolvers.cnfname      = 'texmf.cnf'
resolvers.luaname      = 'texmfcnf.lua'
resolvers.homedir      = os.env[os.platform == "windows" and 'USERPROFILE'] or os.env['HOME'] or '~'
resolvers.cnfdefault   = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}'

local dummy_path_expr = "^!*unset/*$"

local formats      = resolvers.formats
local suffixes     = resolvers.suffixes
local dangerous    = resolvers.dangerous
local suffixmap    = resolvers.suffixmap
local alternatives = resolvers.alternatives

formats['afm'] = 'AFMFONTS'       suffixes['afm'] = { 'afm' }
formats['enc'] = 'ENCFONTS'       suffixes['enc'] = { 'enc' }
formats['fmt'] = 'TEXFORMATS'     suffixes['fmt'] = { 'fmt' }
formats['map'] = 'TEXFONTMAPS'    suffixes['map'] = { 'map' }
formats['mp']  = 'MPINPUTS'       suffixes['mp']  = { 'mp' }
formats['ocp'] = 'OCPINPUTS'      suffixes['ocp'] = { 'ocp' }
formats['ofm'] = 'OFMFONTS'       suffixes['ofm'] = { 'ofm', 'tfm' }
formats['otf'] = 'OPENTYPEFONTS'  suffixes['otf'] = { 'otf' } -- 'ttf'
formats['opl'] = 'OPLFONTS'       suffixes['opl'] = { 'opl' }
formats['otp'] = 'OTPINPUTS'      suffixes['otp'] = { 'otp' }
formats['ovf'] = 'OVFFONTS'       suffixes['ovf'] = { 'ovf', 'vf' }
formats['ovp'] = 'OVPFONTS'       suffixes['ovp'] = { 'ovp' }
formats['tex'] = 'TEXINPUTS'      suffixes['tex'] = { 'tex' }
formats['tfm'] = 'TFMFONTS'       suffixes['tfm'] = { 'tfm' }
formats['ttf'] = 'TTFONTS'        suffixes['ttf'] = { 'ttf', 'ttc', 'dfont' }
formats['pfb'] = 'T1FONTS'        suffixes['pfb'] = { 'pfb', 'pfa' }
formats['vf']  = 'VFFONTS'        suffixes['vf']  = { 'vf' }

formats['fea'] = 'FONTFEATURES'   suffixes['fea'] = { 'fea' }
formats['cid'] = 'FONTCIDMAPS'    suffixes['cid'] = { 'cid', 'cidmap' }

formats ['texmfscripts'] = 'TEXMFSCRIPTS' -- new
suffixes['texmfscripts'] = { 'rb', 'pl', 'py' } -- 'lua'

formats ['lua'] = 'LUAINPUTS' -- new
suffixes['lua'] = { 'lua', 'luc', 'tma', 'tmc' }

-- backward compatible ones

alternatives['map files']            = 'map'
alternatives['enc files']            = 'enc'
alternatives['cid files']            = 'cid'
alternatives['fea files']            = 'fea'
alternatives['opentype fonts']       = 'otf'
alternatives['truetype fonts']       = 'ttf'
alternatives['truetype collections'] = 'ttc'
alternatives['truetype dictionary']  = 'dfont'
alternatives['type1 fonts']          = 'pfb'

-- obscure ones

formats ['misc fonts'] = ''
suffixes['misc fonts'] = { }

formats     ['sfd']                      = 'SFDFONTS'
suffixes    ['sfd']                      = { 'sfd' }
alternatives['subfont definition files'] = 'sfd'

-- In practice we will work within one tds tree, but i want to keep
-- the option open to build tools that look at multiple trees, which is
-- why we keep the tree specific data in a table. We used to pass the
-- instance but for practical pusposes we now avoid this and use a
-- instance variable.

-- here we catch a few new thingies (todo: add these paths to context.tmf)
--
-- FONTFEATURES  = .;$TEXMF/fonts/fea//
-- FONTCIDMAPS   = .;$TEXMF/fonts/cid//

-- we always have one instance active

resolvers.instance = resolvers.instance or nil -- the current one (slow access)
local instance = resolvers.instance or nil -- the current one (fast access)

function resolvers.newinstance()

    -- store once, freeze and faster (once reset we can best use
    -- instance.environment) maybe better have a register suffix
    -- function

    for k, v in next, suffixes do
        for i=1,#v do
            local vi = v[i]
            if vi then
                suffixmap[vi] = k
            end
        end
    end

    -- because vf searching is somewhat dangerous, we want to prevent
    -- too liberal searching esp because we do a lookup on the current
    -- path anyway; only tex (or any) is safe

    for k, v in next, formats do
        dangerous[k] = true
    end
    dangerous.tex = nil

    -- the instance

    local newinstance = {
        rootpath        = '',
        treepath        = '',
        progname        = 'context',
        engine          = 'luatex',
        format          = '',
        environment     = { },
        variables       = { },
        expansions      = { },
        files           = { },
        remap           = { },
        configuration   = { },
        setup           = { },
        order           = { },
        found           = { },
        foundintrees    = { },
        kpsevars        = { },
        hashes          = { },
        cnffiles        = { },
        luafiles        = { },
        lists           = { },
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        scandisk        = true,
        cachepath       = nil,
        loaderror       = false,
        sortdata        = false,
        savelists       = true,
        cleanuppaths    = true,
        allresults      = false,
        pattern         = nil, -- lists
        data            = { }, -- only for loading
        force_suffixes  = true,
        fakepaths       = { },
    }

    local ne = newinstance.environment

    for k,v in next, os.env do
        ne[k] = resolvers.bare_variable(v)
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

local function check_configuration() -- not yet ok, no time for debugging now
    local ie, iv = instance.environment, instance.variables
    local function fix(varname,default)
        local proname = varname .. "." .. instance.progname or "crap"
        local p, v = ie[proname], ie[varname] or iv[varname]
        if not ((p and p ~= "") or (v and v ~= "")) then
            iv[varname] = default -- or environment?
        end
    end
    local name = os.name
    if name == "windows" then
        fix("OSFONTDIR", "c:/windows/fonts//")
    elseif name == "macosx" then
        fix("OSFONTDIR", "$HOME/Library/Fonts//;/Library/Fonts//;/System/Library/Fonts//")
    else
        -- bad luck
    end
    fix("LUAINPUTS"   , ".;$TEXINPUTS;$TEXMFSCRIPTS") -- no progname, hm
    fix("FONTFEATURES", ".;$TEXMF/fonts/fea//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS")
    fix("FONTCIDMAPS" , ".;$TEXMF/fonts/cid//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS")
    fix("LUATEXLIBS"  , ".;$TEXMF/luatex/lua//")
end

function resolvers.bare_variable(str) -- assumes str is a string
    return (gsub(str,"\s*([\"\']?)(.+)%1\s*", "%2"))
end

function resolvers.settrace(n) -- no longer number but: 'locating' or 'detail'
    if n then
        trackers.disable("resolvers.*")
        trackers.enable("resolvers."..n)
    end
end

resolvers.settrace(os.getenv("MTX.resolvers.TRACE") or os.getenv("MTX_INPUT_TRACE"))

function resolvers.osenv(key)
    local ie = instance.environment
    local value = ie[key]
    if value == nil then
     -- local e = os.getenv(key)
        local e = os.env[key]
        if e == nil then
         -- value = "" -- false
        else
            value = resolvers.bare_variable(e)
        end
        ie[key] = value
    end
    return value or ""
end

function resolvers.env(key)
    return instance.environment[key] or resolvers.osenv(key)
end

--

local function expand_vars(lst) -- simple vars
    local variables, env = instance.variables, resolvers.env
    local function resolve(a)
        return variables[a] or env(a)
    end
    for k=1,#lst do
        lst[k] = gsub(lst[k],"%$([%a%d%_%-]+)",resolve)
    end
end

local function expanded_var(var) -- simple vars
    local function resolve(a)
        return instance.variables[a] or resolvers.env(a)
    end
    return (gsub(var,"%$([%a%d%_%-]+)",resolve))
end

local function entry(entries,name)
    if name and (name ~= "") then
        name = gsub(name,'%$','')
        local result = entries[name..'.'..instance.progname] or entries[name]
        if result then
            return result
        else
            result = resolvers.env(name)
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

-- {a,b,c,d}
-- a,b,c/{p,q,r},d
-- a,b,c/{p,q,r}/d/{x,y,z}//
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a{b,c}{d,e}f
-- {a,b,c,d}
-- {a,b,c/{p,q,r},d}
-- {a,b,c/{p,q,r}/d/{x,y,z}//}
-- {a,b,c/{p,q/{x,y,z}},d/{p,q,r}}
-- {a,b,c/{p,q/{x,y,z},w}v,d/{p,q,r}}
-- {$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}

-- this one is better and faster, but it took me a while to realize
-- that this kind of replacement is cleaner than messy parsing and
-- fuzzy concatenating we can probably gain a bit with selectively
-- applying lpeg, but experiments with lpeg parsing this proved not to
-- work that well; the parsing is ok, but dealing with the resulting
-- table is a pain because we need to work inside-out recursively

local function do_first(a,b)
    local t = { }
    for s in gmatch(b,"[^,]+") do t[#t+1] = a .. s end
    return "{" .. concat(t,",") .. "}"
end

local function do_second(a,b)
    local t = { }
    for s in gmatch(a,"[^,]+") do t[#t+1] = s .. b end
    return "{" .. concat(t,",") .. "}"
end

local function do_both(a,b)
    local t = { }
    for sa in gmatch(a,"[^,]+") do
        for sb in gmatch(b,"[^,]+") do
            t[#t+1] = sa .. sb
        end
    end
    return "{" .. concat(t,",") .. "}"
end

local function do_three(a,b,c)
    return a .. b.. c
end

local function splitpathexpr(str, t, validate)
    -- no need for further optimization as it is only called a
    -- few times, we can use lpeg for the sub; we could move
    -- the local functions outside the body
    t = t or { }
    str = gsub(str,",}",",@}")
    str = gsub(str,"{,","{@,")
 -- str = "@" .. str .. "@"
    local ok, done
    while true do
        done = false
        while true do
            str, ok = gsub(str,"([^{},]+){([^{}]+)}",do_first)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}([^{},]+)",do_second)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}{([^{}]+)}",do_both)
            if ok > 0 then done = true else break end
        end
        str, ok = gsub(str,"({[^{}]*){([^{}]+)}([^{}]*})",do_three)
        if ok > 0 then done = true end
        if not done then break end
    end
    str = gsub(str,"[{}]", "")
    str = gsub(str,"@","")
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then t[#t+1] = s end
        end
    else
        for s in gmatch(str,"[^,]+") do
            t[#t+1] = s
        end
    end
    return t
end

local function validate(s)
    s = collapse_path(s)
    return s ~= "" and not find(s,dummy_path_expr) and s
end

local function expanded_path_from_list(pathlist) -- maybe not a list, just a path
    -- a previous version fed back into pathlist
    local newlist, ok = { }, false
    for k=1,#pathlist do
        if find(pathlist[k],"[{}]") then
            ok = true
            break
        end
    end
    if ok then
        for k=1,#pathlist do
            splitpathexpr(pathlist[k],newlist,validate)
        end
    else
        for k=1,#pathlist do
            for p in gmatch(pathlist[k],"([^,]+)") do
                p = collapse_path(p)
                if p ~= "" then newlist[#newlist+1] = p end
            end
        end
    end
    return newlist
end

-- we follow a rather traditional approach:
--
-- (1) texmf.cnf given in TEXMFCNF
-- (2) texmf.cnf searched in default variable
--
-- also we now follow the stupid route: if not set then just assume *one*
-- cnf file under texmf (i.e. distribution)

resolvers.ownpath     = resolvers.ownpath or nil
resolvers.ownbin      = resolvers.ownbin  or arg[-2] or arg[-1] or arg[0] or "luatex"
resolvers.autoselfdir = true -- false may be handy for debugging

function resolvers.getownpath()
    if not resolvers.ownpath then
        if resolvers.autoselfdir and os.selfdir then
            resolvers.ownpath = os.selfdir
        else
            local binary = resolvers.ownbin
            if os.platform == "windows" then
                binary = file.replacesuffix(binary,"exe")
            end
            for p in gmatch(os.getenv("PATH"),"[^"..io.pathseparator.."]+") do
                local b = file.join(p,binary)
                if lfs.isfile(b) then
                    -- we assume that after changing to the path the currentdir function
                    -- resolves to the real location and use this side effect here; this
                    -- trick is needed because on the mac installations use symlinks in the
                    -- path instead of real locations
                    local olddir = lfs.currentdir()
                    if lfs.chdir(p) then
                        local pp = lfs.currentdir()
                        if trace_verbose and p ~= pp then
                            logs.report("fileio","following symlink %s to %s",p,pp)
                        end
                        resolvers.ownpath = pp
                        lfs.chdir(olddir)
                    else
                        if trace_verbose then
                            logs.report("fileio","unable to check path %s",p)
                        end
                        resolvers.ownpath =  p
                    end
                    break
                end
            end
        end
        if not resolvers.ownpath then resolvers.ownpath = '.' end
    end
    return resolvers.ownpath
end

local own_places = { "SELFAUTOLOC", "SELFAUTODIR", "SELFAUTOPARENT", "TEXMFCNF" }

local function identify_own()
    local ownpath = resolvers.getownpath() or lfs.currentdir()
    local ie = instance.environment
    if ownpath then
        if resolvers.env('SELFAUTOLOC')    == "" then os.env['SELFAUTOLOC']    = collapse_path(ownpath) end
        if resolvers.env('SELFAUTODIR')    == "" then os.env['SELFAUTODIR']    = collapse_path(ownpath .. "/..") end
        if resolvers.env('SELFAUTOPARENT') == "" then os.env['SELFAUTOPARENT'] = collapse_path(ownpath .. "/../..") end
    else
        logs.report("fileio","error: unable to locate ownpath")
        os.exit()
    end
    if resolvers.env('TEXMFCNF') == "" then os.env['TEXMFCNF'] = resolvers.cnfdefault end
    if resolvers.env('TEXOS')    == "" then os.env['TEXOS']    = resolvers.env('SELFAUTODIR') end
    if resolvers.env('TEXROOT')  == "" then os.env['TEXROOT']  = resolvers.env('SELFAUTOPARENT') end
    if trace_verbose then
        for i=1,#own_places do
            local v = own_places[i]
            logs.report("fileio","variable %s set to %s",v,resolvers.env(v) or "unknown")
        end
    end
    identify_own = function() end
end

function resolvers.identify_cnf()
    if #instance.cnffiles == 0 then
        -- fallback
        identify_own()
        -- the real search
        resolvers.expand_variables()
        local t = resolvers.split_path(resolvers.env('TEXMFCNF'))
        t = expanded_path_from_list(t)
        expand_vars(t) -- redundant
        local function locate(filename,list)
            for i=1,#t do
                local ti = t[i]
                local texmfcnf = collapse_path(file.join(ti,filename))
                if lfs.isfile(texmfcnf) then
                    list[#list+1] = texmfcnf
                end
            end
        end
        locate(resolvers.luaname,instance.luafiles)
        locate(resolvers.cnfname,instance.cnffiles)
    end
end

local function load_cnf_file(fname)
    -- why don't we just read the file from the cache
    -- we need to switch to the lua file
    fname = resolvers.clean_path(fname)
    local lname = file.replacesuffix(fname,'lua')
    if lfs.isfile(lname) then
        local dname = file.dirname(fname)
        if not instance.configuration[dname] then
            resolvers.load_data(dname,'configuration',lname and file.basename(lname))
            instance.order[#instance.order+1] = instance.configuration[dname]
        end
    else
        f = io.open(fname)
        if f then
            if trace_verbose then
                logs.report("fileio","loading %s", fname)
            end
            local line, data, n, k, v
            local dname = file.dirname(fname)
            if not instance.configuration[dname] then
                instance.configuration[dname] = { }
                instance.order[#instance.order+1] = instance.configuration[dname]
            end
            local data = instance.configuration[dname]
            while true do
                local line, n = f:read(), 0
                if line then
                    while true do -- join lines
                        line, n = gsub(line,"\\%s*$", "")
                        if n > 0 then
                            line = line .. f:read()
                        else
                            break
                        end
                    end
                    if not find(line,"^[%%#]") then
                        local l = gsub(line,"%s*%%.*$","")
                        local k, v = match(l,"%s*(.-)%s*=%s*(.-)%s*$")
                        if k and v and not data[k] then
                            v = gsub(v,"[%%#].*",'')
                            data[k] = gsub(v,"~","$HOME")
                            instance.kpsevars[k] = true
                        end
                    end
                else
                    break
                end
            end
            f:close()
        elseif trace_verbose then
            logs.report("fileio","skipping %s", fname)
        end
    end
end

local function collapse_cnf_data() -- potential optimization: pass start index (setup and configuration are shared)
    for _,c in ipairs(instance.order) do
        for k,v in next, c do
            if not instance.variables[k] then
                if instance.environment[k] then
                    instance.variables[k] = instance.environment[k]
                else
                    instance.kpsevars[k] = true
                    instance.variables[k] = resolvers.bare_variable(v)
                end
            end
        end
    end
end

local function loadoldconfigdata()
    for _, fname in ipairs(instance.cnffiles) do
        load_cnf_file(fname)
    end
end

function resolvers.load_cnf()
    -- instance.cnffiles contain complete names now !
    -- we still use a funny mix of cnf and new but soon
    -- we will switch to lua exclusively as we only use
    -- the file to collect the tree roots
    if #instance.cnffiles == 0 then
        if trace_verbose then
            logs.report("fileio","no cnf files found (TEXMFCNF may not be set/known)")
        end
    else
        instance.rootpath = instance.cnffiles[1]
        for k,fname in ipairs(instance.cnffiles) do
            instance.cnffiles[k] = collapse_path(gsub(fname,"\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = collapse_path(instance.rootpath)
        if instance.diskcache and not instance.renewcache then
            resolvers.loadoldconfig(instance.cnffiles)
            if instance.loaderror then
                loadoldconfigdata()
                resolvers.saveoldconfig()
            end
        else
            loadoldconfigdata()
            if instance.renewcache then
                resolvers.saveoldconfig()
            end
        end
        collapse_cnf_data()
    end
    check_configuration()
end

function resolvers.load_lua()
    if #instance.luafiles == 0 then
        -- yet harmless
    else
        instance.rootpath = instance.luafiles[1]
        for k,fname in ipairs(instance.luafiles) do
            instance.luafiles[k] = collapse_path(gsub(fname,"\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = collapse_path(instance.rootpath)
        resolvers.loadnewconfig()
        collapse_cnf_data()
    end
    check_configuration()
end

-- database loading

function resolvers.load_hash()
    resolvers.locatelists()
    if instance.diskcache and not instance.renewcache then
        resolvers.loadfiles()
        if instance.loaderror then
            resolvers.loadlists()
            resolvers.savefiles()
        end
    else
        resolvers.loadlists()
        if instance.renewcache then
            resolvers.savefiles()
        end
    end
end

function resolvers.append_hash(type,tag,name)
    if trace_locating then
        logs.report("fileio","= hash append: %s",tag)
    end
    insert(instance.hashes, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function resolvers.prepend_hash(type,tag,name)
    if trace_locating then
        logs.report("fileio","= hash prepend: %s",tag)
    end
    insert(instance.hashes, 1, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function resolvers.extend_texmf_var(specification) -- crap, we could better prepend the hash
--  local t = resolvers.expanded_path_list('TEXMF') -- full expansion
    local t = resolvers.split_path(resolvers.env('TEXMF'))
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

-- locators

function resolvers.locatelists()
    for _, path in ipairs(resolvers.clean_path_list('TEXMF')) do
        if trace_verbose then
            logs.report("fileio","locating list of %s",path)
        end
        resolvers.locatedatabase(collapse_path(path))
    end
end

function resolvers.locatedatabase(specification)
    return resolvers.methodhandler('locators', specification)
end

function resolvers.locators.tex(specification)
    if specification and specification ~= '' and lfs.isdir(specification) then
        if trace_locating then
            logs.report("fileio",'! tex locator found: %s',specification)
        end
        resolvers.append_hash('file',specification,filename)
    elseif trace_locating then
        logs.report("fileio",'? tex locator not found: %s',specification)
    end
end

-- hashers

function resolvers.hashdatabase(tag,name)
    return resolvers.methodhandler('hashers',tag,name)
end

function resolvers.loadfiles()
    instance.loaderror = false
    instance.files = { }
    if not instance.renewcache then
        for _, hash in ipairs(instance.hashes) do
            resolvers.hashdatabase(hash.tag,hash.name)
            if instance.loaderror then break end
        end
    end
end

function resolvers.hashers.tex(tag,name)
    resolvers.load_data(tag,'files')
end

-- generators:

function resolvers.loadlists()
    for _, hash in ipairs(instance.hashes) do
        resolvers.generatedatabase(hash.tag)
    end
end

function resolvers.generatedatabase(specification)
    return resolvers.methodhandler('generators', specification)
end

-- starting with . or .. etc or funny char

local weird = lpeg.P(".")^1 + lpeg.anywhere(lpeg.S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

function resolvers.generators.tex(specification)
    local tag = specification
    if trace_verbose then
        logs.report("fileio","scanning path %s",specification)
    end
    instance.files[tag] = { }
    local files = instance.files[tag]
    local n, m, r = 0, 0, 0
    local spec = specification .. '/'
    local attributes = lfs.attributes
    local directory = lfs.dir
    local function action(path)
        local full
        if path then
            full = spec .. path .. '/'
        else
            full = spec
        end
        for name in directory(full) do
            if not weird:match(name) then
                local mode = attributes(full..name,'mode')
                if mode == 'file' then
                    if path then
                        n = n + 1
                        local f = files[name]
                        if f then
                            if type(f) == 'string' then
                                files[name] = { f, path }
                            else
                                f[#f+1] = path
                            end
                        else -- probably unique anyway
                            files[name] = path
                            local lower = lower(name)
                            if name ~= lower then
                                files["remap:"..lower] = name
                                r = r + 1
                            end
                        end
                    end
                elseif mode == 'directory' then
                    m = m + 1
                    if path then
                        action(path..'/'..name)
                    else
                        action(name)
                    end
                end
            end
        end
    end
    action()
    if trace_verbose then
        logs.report("fileio","%s files found on %s directories with %s uppercase remappings",n,m,r)
    end
end

-- savers, todo

function resolvers.savefiles()
    resolvers.save_data('files')
end

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

function resolvers.splitconfig()
    for i,c in ipairs(instance) do
        for k,v in pairs(c) do
            if type(v) == 'string' then
                local t = file.split_path(v)
                if #t > 1 then
                    c[k] = t
                end
            end
        end
    end
end

function resolvers.joinconfig()
    for i,c in ipairs(instance.order) do
        for k,v in pairs(c) do -- ipairs?
            if type(v) == 'table' then
                c[k] = file.join_path(v)
            end
        end
    end
end

local winpath   = lpeg.P("!!")^-1 * (lpeg.R("AZ","az") * lpeg.P(":") * lpeg.P("/"))
local separator = lpeg.P(":") + lpeg.P(";")
local rest      = (1-separator)^1
local somepath  = winpath * rest + rest
local splitter  = lpeg.Ct(lpeg.C(somepath) * (separator^1 + lpeg.C(somepath))^0)

local function split_kpse_path(str)
    str = gsub(str,"\\","/")
    return splitter:match(str) or { }
end

local cache = { } -- we assume stable strings

function resolvers.split_path(str) -- overkill but i need to check this module anyway
    if type(str) == 'table' then
        return str
    else
        str = gsub(str,"\\","/")
        local s = cache[str]
        if s then
            return s -- happens seldom
        else
            s = { }
        end
        local t = string.checkedsplit(str,io.pathseparator) or { str }
        for _, p in ipairs(t) do
            splitpathexpr(p,s)
        end
        --~ print(str,table.serialize(s))
        cache[str] = s
        return s
    end
end

function resolvers.join_path(str)
    if type(str) == 'table' then
        return file.join_path(str)
    else
        return str
    end
end

function resolvers.splitexpansions()
    local ie = instance.expansions
    for k,v in next, ie do
        local t, h = { }, { }
        for _,vv in ipairs(file.split_path(v)) do
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

function resolvers.saveoldconfig()
    resolvers.splitconfig()
    resolvers.save_data('configuration')
    resolvers.joinconfig()
end

resolvers.configbanner = [[
-- This is a Luatex configuration file created by 'luatools.lua' or
-- 'luatex.exe' directly. For comment, suggestions and questions you can
-- contact the ConTeXt Development Team. This configuration file is
-- not copyrighted. [HH & TH]
]]

function resolvers.serialize(files)
    -- This version is somewhat optimized for the kind of
    -- tables that we deal with, so it's much faster than
    -- the generic serializer. This makes sense because
    -- luatools and mtxtools are called frequently. Okay,
    -- we pay a small price for properly tabbed tables.
    local t = { }
    local function dump(k,v,m) -- could be moved inline
        if type(v) == 'string' then
            return m .. "['" .. k .. "']='" .. v .. "',"
        elseif #v == 1 then
            return m .. "['" .. k .. "']='" .. v[1] .. "',"
        else
            return m .. "['" .. k .. "']={'" .. concat(v,"','").. "'},"
        end
    end
    t[#t+1] = "return {"
    if instance.sortdata then
        for _, k in pairs(sortedkeys(files)) do -- ipairs
            local fk  = files[k]
            if type(fk) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for _, kk in pairs(sortedkeys(fk)) do -- ipairs
                    t[#t+1] = dump(kk,fk[kk],"\t\t")
                end
                t[#t+1] = "\t},"
            else
                t[#t+1] = dump(k,fk,"\t")
            end
        end
    else
        for k, v in next, files do
            if type(v) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for kk,vv in next, v do
                    t[#t+1] = dump(kk,vv,"\t\t")
                end
                t[#t+1] = "\t},"
            else
                t[#t+1] = dump(k,v,"\t")
            end
        end
    end
    t[#t+1] = "}"
    return concat(t,"\n")
end

function resolvers.save_data(dataname, makename) -- untested without cache overload
    for cachename, files in next, instance[dataname] do
        local name = (makename or file.join)(cachename,dataname)
        local luaname, lucname = name .. ".lua", name .. ".luc"
        if trace_verbose then
            logs.report("fileio","preparing %s for %s",dataname,cachename)
        end
        for k, v in next, files do
            if type(v) == "table" and #v == 1 then
                files[k] = v[1]
            end
        end
        local data = {
            type    = dataname,
            root    = cachename,
            version = resolvers.cacheversion,
            date    = os.date("%Y-%m-%d"),
            time    = os.date("%H:%M:%S"),
            content = files,
            uuid    = os.uuid(),
        }
        local ok = io.savedata(luaname,resolvers.serialize(data))
        if ok then
            if trace_verbose then
                logs.report("fileio","%s saved in %s",dataname,luaname)
            end
            if utils.lua.compile(luaname,lucname,false,true) then -- no cleanup but strip
                if trace_verbose then
                    logs.report("fileio","%s compiled to %s",dataname,lucname)
                end
            else
                if trace_verbose then
                    logs.report("fileio","compiling failed for %s, deleting file %s",dataname,lucname)
                end
                os.remove(lucname)
            end
        elseif trace_verbose then
            logs.report("fileio","unable to save %s in %s (access error)",dataname,luaname)
        end
    end
end

local data_state = { }

function resolvers.data_state()
    return data_state or { }
end

function resolvers.load_data(pathname,dataname,filename,makename) -- untested without cache overload
    filename = ((not filename or (filename == "")) and dataname) or filename
    filename = (makename and makename(dataname,filename)) or file.join(pathname,filename)
    local blob = loadfile(filename .. ".luc") or loadfile(filename .. ".lua")
    if blob then
        local data = blob()
        if data and data.content and data.type == dataname and data.version == resolvers.cacheversion then
            data_state[#data_state+1] = data.uuid
            if trace_verbose then
                logs.report("fileio","loading %s for %s from %s",dataname,pathname,filename)
            end
            instance[dataname][pathname] = data.content
        else
            if trace_verbose then
                logs.report("fileio","skipping %s for %s from %s",dataname,pathname,filename)
            end
            instance[dataname][pathname] = { }
            instance.loaderror = true
        end
    elseif trace_verbose then
        logs.report("fileio","skipping %s for %s from %s",dataname,pathname,filename)
    end
end

-- some day i'll use the nested approach, but not yet (actually we even drop
-- engine/progname support since we have only luatex now)
--
-- first texmfcnf.lua files are located, next the cached texmf.cnf files
--
-- return {
--     TEXMFBOGUS = 'effe checken of dit werkt',
-- }

function resolvers.resetconfig()
    identify_own()
    instance.configuration, instance.setup, instance.order, instance.loaderror = { }, { }, { }, false
end

function resolvers.loadnewconfig()
    for _, cnf in ipairs(instance.luafiles) do
        local pathname = file.dirname(cnf)
        local filename = file.join(pathname,resolvers.luaname)
        local blob = loadfile(filename)
        if blob then
            local data = blob()
            if data then
                if trace_verbose then
                    logs.report("fileio","loading configuration file %s",filename)
                end
                if true then
                    -- flatten to variable.progname
                    local t = { }
                    for k, v in next, data do -- v = progname
                        if type(v) == "string" then
                            t[k] = v
                        else
                            for kk, vv in next, v do -- vv = variable
                                if type(vv) == "string" then
                                    t[vv.."."..v] = kk
                                end
                            end
                        end
                    end
                    instance['setup'][pathname] = t
                else
                    instance['setup'][pathname] = data
                end
            else
                if trace_verbose then
                    logs.report("fileio","skipping configuration file %s",filename)
                end
                instance['setup'][pathname] = { }
                instance.loaderror = true
            end
        elseif trace_verbose then
            logs.report("fileio","skipping configuration file %s",filename)
        end
        instance.order[#instance.order+1] = instance.setup[pathname]
        if instance.loaderror then break end
    end
end

function resolvers.loadoldconfig()
    if not instance.renewcache then
        for _, cnf in ipairs(instance.cnffiles) do
            local dname = file.dirname(cnf)
            resolvers.load_data(dname,'configuration')
            instance.order[#instance.order+1] = instance.configuration[dname]
            if instance.loaderror then break end
        end
    end
    resolvers.joinconfig()
end

function resolvers.expand_variables()
    local expansions, environment, variables = { }, instance.environment, instance.variables
    local env = resolvers.env
    instance.expansions = expansions
    if instance.engine   ~= "" then environment['engine']   = instance.engine   end
    if instance.progname ~= "" then environment['progname'] = instance.progname end
    for k,v in next, environment do
        local a, b = match(k,"^(%a+)%_(.*)%s*$")
        if a and b then
            expansions[a..'.'..b] = v
        else
            expansions[k] = v
        end
    end
    for k,v in next, environment do -- move environment to expansions
        if not expansions[k] then expansions[k] = v end
    end
    for k,v in next, variables do -- move variables to expansions
        if not expansions[k] then expansions[k] = v end
    end
    local busy = false
    local function resolve(a)
        busy = true
        return expansions[a] or env(a)
    end
    while true do
        busy = false
        for k,v in next, expansions do
            local s, n = gsub(v,"%$([%a%d%_%-]+)",resolve)
            local s, m = gsub(s,"%$%{([%a%d%_%-]+)%}",resolve)
            if n > 0 or m > 0 then
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

do -- no longer needed

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
        return ep or { }
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
        return resolvers.expanded_path_list(str)
    else
        return resolvers.expanded_path_list(tmp)
    end
end

function resolvers.expand_path_from_var(str)
    return file.join_path(resolvers.expanded_path_list_from_var(str))
end

function resolvers.format_of_var(str)
    return formats[str] or formats[alternatives[str]] or ''
end
function resolvers.format_of_suffix(str)
    return suffixmap[file.extname(str)] or 'tex'
end

function resolvers.variable_of_format(str)
    return formats[str] or formats[alternatives[str]] or ''
end

function resolvers.var_of_format_or_suffix(str)
    local v = formats[str]
    if v then
        return v
    end
    v = formats[alternatives[str]]
    if v then
        return v
    end
    v = suffixmap[file.extname(str)]
    if v then
        return formats[isf]
    end
    return ''
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
            logs.report("fileio","+ readable: %s",name)
        else
            logs.report("fileio","- readable: %s", name)
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
            logs.report("fileio","? blobpath asked: %s",fname)
        end
        local bname = file.basename(fname)
        local dname = file.dirname(fname)
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
                    logs.report("fileio",'? blobpath do: %s (%s)',blobpath,bname)
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
                    if type(blobfile) == 'string' then
                        if not dname or find(blobfile,dname) then
                            filelist[#filelist+1] = {
                                hash.type,
                                file.join(blobpath,blobfile,bname), -- search
                                resolvers.concatinators[hash.type](blobpath,blobfile,bname) -- result
                            }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                filelist[#filelist+1] = {
                                    hash.type,
                                    file.join(blobpath,vv,bname), -- search
                                    resolvers.concatinators[hash.type](blobpath,vv,bname) -- result
                                }
                            end
                        end
                    end
                end
            elseif trace_locating then
                logs.report("fileio",'! blobpath no: %s (%s)',blobpath,bname)
            end
        end
    end
    if #filelist > 0 then
        return filelist
    else
        return nil
    end
end

function resolvers.suffix_of_format(str)
    if suffixes[str] then
        return suffixes[str][1]
    else
        return ""
    end
end

function resolvers.suffixes_of_format(str)
    if suffixes[str] then
        return suffixes[str]
    else
        return {}
    end
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
    return (fakepaths[name] == 1)
end

local function collect_instance_files(filename,collected) -- todo : plugin (scanners, checkers etc)
    local result = collected or { }
    local stamp  = nil
    filename = collapse_path(filename)  -- elsewhere
    filename = collapse_path(gsub(filename,"\\","/")) -- elsewhere
    -- speed up / beware: format problem
    if instance.remember then
        stamp = filename .. "--" .. instance.engine .. "--" .. instance.progname .. "--" .. instance.format
        if instance.found[stamp] then
            if trace_locating then
                logs.report("fileio",'! remembered: %s',filename)
            end
            return instance.found[stamp]
        end
    end
    if not dangerous[instance.format or "?"] then
        if resolvers.isreadable.file(filename) then
            if trace_detail then
                logs.report("fileio",'= found directly: %s',filename)
            end
            instance.found[stamp] = { filename }
            return { filename }
        end
    end
    if find(filename,'%*') then
        if trace_locating then
            logs.report("fileio",'! wildcard: %s', filename)
        end
        result = resolvers.find_wildcard_files(filename)
    elseif file.is_qualified_path(filename) then
        if resolvers.isreadable.file(filename) then
            if trace_locating then
                logs.report("fileio",'! qualified: %s', filename)
            end
            result = { filename }
        else
            local forcedname, ok, suffix = "", false, file.extname(filename)
            if suffix == "" then -- why
                if instance.format == "" then
                    forcedname = filename .. ".tex"
                    if resolvers.isreadable.file(forcedname) then
                        if trace_locating then
                            logs.report("fileio",'! no suffix, forcing standard filetype: tex')
                        end
                        result, ok = { forcedname }, true
                    end
                else
                    local suffixes = resolvers.suffixes_of_format(instance.format)
                    for _, s in next, suffixes do
                        forcedname = filename .. "." .. s
                        if resolvers.isreadable.file(forcedname) then
                            if trace_locating then
                                logs.report("fileio",'! no suffix, forcing format filetype: %s', s)
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
                local basename = file.basename(filename)
                local pattern = (filename .. "$"):gsub("([%.%-])","%%%1")
                local savedformat = instance.format
                local format = savedformat or ""
                if format == "" then
                    instance.format = resolvers.format_of_suffix(suffix)
                end
                if not format then
                    instance.format = "othertextfiles" -- kind of everything, maybe texinput is better
                end
                --
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
                    if rr:find(pattern) then
                        result[#result+1], ok = rr, true
                    end
                end
                -- a real wildcard:
                --
                -- if not ok then
                --     local filelist = collect_files({basename})
                --     for f=1,#filelist do
                --         local ff = filelist[f][3] or ""
                --         if ff:find(pattern) then
                --             result[#result+1], ok = ff, true
                --         end
                --     end
                -- end
            end
            if not ok and trace_locating then
                logs.report("fileio",'? qualified: %s', filename)
            end
        end
    else
        -- search spec
        local filetype, extra, done, wantedfiles, ext = '', nil, false, { }, file.extname(filename)
        if ext == "" then
            if not instance.force_suffixes then
                wantedfiles[#wantedfiles+1] = filename
            end
        else
            wantedfiles[#wantedfiles+1] = filename
        end
        if instance.format == "" then
            if ext == "" then
                local forcedname = filename .. '.tex'
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = resolvers.format_of_suffix(forcedname)
                if trace_locating then
                    logs.report("fileio",'! forcing filetype: %s',filetype)
                end
            else
                filetype = resolvers.format_of_suffix(filename)
                if trace_locating then
                    logs.report("fileio",'! using suffix based filetype: %s',filetype)
                end
            end
        else
            if ext == "" then
                local suffixes = resolvers.suffixes_of_format(instance.format)
                for _, s in next, suffixes do
                    wantedfiles[#wantedfiles+1] = filename .. "." .. s
                end
            end
            filetype = instance.format
            if trace_locating then
                logs.report("fileio",'! using given filetype: %s',filetype)
            end
        end
        local typespec = resolvers.variable_of_format(filetype)
        local pathlist = resolvers.expanded_path_list(typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if trace_detail then
                logs.report("fileio",'? filename: %s',filename)
                logs.report("fileio",'? filetype: %s',filetype or '?')
                logs.report("fileio",'? wanted files: %s',concat(wantedfiles," | "))
            end
            for k=1,#wantedfiles do
                local fname = wantedfiles[k]
                if fname and resolvers.isreadable.file(fname) then
                    filename, done = fname, true
                    result[#result+1] = file.join('.',fname)
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
            local doscan, recurse
            if trace_detail then
                logs.report("fileio",'? filename: %s',filename)
            end
            -- a bit messy ... esp the doscan setting here
            for k=1,#pathlist do
                local path = pathlist[k]
                if find(path,"^!!") then doscan  = false else doscan  = true  end
                if find(path,"//$") then recurse = true  else recurse = false end
                local pathname = gsub(path,"^!+", '')
                done = false
                -- using file list
                if filelist and not (done and not instance.allresults) and recurse then
                    -- compare list entries with permitted pattern
                    pathname = gsub(pathname,"([%-%.])","%%%1") -- this also influences
                    pathname = gsub(pathname,"/+$", '/.*')      -- later usage of pathname
                    pathname = gsub(pathname,"//", '/.-/')      -- not ok for /// but harmless
                    local expr = "^" .. pathname
                    for k=1,#filelist do
                        local fl = filelist[k]
                        local f = fl[2]
                        if find(f,expr) then
                            if trace_detail then
                                logs.report("fileio",'= found in hash: %s',f)
                            end
                            --- todo, test for readable
                            result[#result+1] = fl[3]
                            resolvers.register_in_trees(f) -- for tracing used files
                            done = true
                            if not instance.allresults then break end
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
                                    local fname = file.join(ppname,w)
                                    if resolvers.isreadable.file(fname) then
                                        if trace_detail then
                                            logs.report("fileio",'= found by scanning: %s',fname)
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
                    -- todo: slow path scanning
                end
                if done and not instance.allresults then break end
            end
        end
    end
    for k=1,#result do
        result[k] = collapse_path(result[k])
    end
    if instance.remember then
        instance.found[stamp] = result
    end
    return result
end

if not resolvers.concatinators  then resolvers.concatinators = { } end

resolvers.concatinators.tex  = file.join
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

function resolvers.find_given_files(filename)
    local bname, result = file.basename(filename), { }
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        local files = instance.files[hash.tag]
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

function resolvers.find_wildcard_files(filename) -- todo: remap:
    local result = { }
    local bname, dname = file.basename(filename), file.dirname(filename)
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
    resolvers.resetconfig()
    resolvers.identify_cnf()
    resolvers.load_lua() -- will become the new method
    resolvers.expand_variables()
    resolvers.load_cnf() -- will be skipped when we have a lua file
    resolvers.expand_variables()
    if option ~= "nofiles" then
        resolvers.load_hash()
        resolvers.automount()
    end
    statistics.stoptiming(instance)
end

function resolvers.for_files(command, files, filetype, mustexist)
    if files and #files > 0 then
        local function report(str)
            if trace_verbose then
                logs.report("fileio",str) -- has already verbose
            else
                print(str)
            end
        end
        if trace_verbose then
            report('')
        end
        for _, file in ipairs(files) do
            local result = command(file,filetype,mustexist)
            if type(result) == 'string' then
                report(result)
            else
                for _,v in ipairs(result) do
                    report(v)
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

function resolvers.splitmethod(filename)
    if not filename then
        return { } -- safeguard
    elseif type(filename) == "table" then
        return filename -- already split
    elseif not find(filename,"://") then
        return { scheme="file", path = filename, original=filename } -- quick hack
    else
        return url.hashed(filename)
    end
end

function table.sequenced(t,sep) -- temp here
    local s = { }
    for k, v in pairs(t) do -- pairs?
        s[#s+1] = k .. "=" .. v
    end
    return concat(s, sep or " | ")
end

function resolvers.methodhandler(what, filename, filetype) -- ...
    local specification = (type(filename) == "string" and resolvers.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    if resolvers[what][scheme] then
        if trace_locating then
            logs.report("fileio",'= handler: %s -> %s -> %s',specification.original,what,table.sequenced(specification))
        end
        return resolvers[what][scheme](filename,filetype) -- todo: specification
    else
        return resolvers[what].tex(filename,filetype) -- todo: specification
    end
end

function resolvers.clean_path(str)
    if str then
        str = gsub(str,"\\","/")
        str = gsub(str,"^!+","")
        str = gsub(str,"^~",resolvers.homedir)
        return str
    else
        return nil
    end
end

function resolvers.do_with_path(name,func)
    for _, v in pairs(resolvers.expanded_path_list(name)) do -- pairs?
        func("^"..resolvers.clean_path(v))
    end
end

function resolvers.do_with_var(name,func)
    func(expanded_var(name))
end

function resolvers.with_files(pattern,handle)
    for _, hash in ipairs(instance.hashes) do
        local blobpath = hash.tag
        local blobtype = hash.type
        if blobpath then
            local files = instance.files[blobpath]
            if files then
                for k,v in next, files do
                    if find(k,"^remap:") then
                        k = files[k]
                        v = files[k] -- chained
                    end
                    if find(k,pattern) then
                        if type(v) == "string" then
                            handle(blobtype,blobpath,v,k)
                        else
                            for _,vv in pairs(v) do -- ipairs?
                                handle(blobtype,blobpath,vv,k)
                            end
                        end
                    end
                end
            end
        end
    end
end

function resolvers.locate_format(name)
    local barename, fmtname = name:gsub("%.%a+$",""), ""
    if resolvers.usecache then
        local path = file.join(caches.setpath("formats")) -- maybe platform
        fmtname = file.join(path,barename..".fmt") or ""
    end
    if fmtname == "" then
        fmtname = resolvers.find_files(barename..".fmt")[1] or ""
    end
    fmtname = resolvers.clean_path(fmtname)
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

texconfig.kpse_init = false

kpse = { original = kpse } setmetatable(kpse, { __index = function(k,v) return resolvers[v] end } )

-- for a while

input = resolvers
