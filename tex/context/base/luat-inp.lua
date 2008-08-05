if not modules then modules = { } end modules ['luat-inp'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "companion to luat-lib.tex",
}

-- TODO: os.getenv -> os.env[]
-- TODO: instances.[hashes,cnffiles,configurations,522] -> ipairs (alles check, sneller)
-- TODO: check escaping in find etc, too much, too slow

-- This lib is multi-purpose and can be loaded again later on so that
-- additional functionality becomes available. We will split this
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

if not input            then input            = { } end
if not input.suffixes   then input.suffixes   = { } end
if not input.formats    then input.formats    = { } end
if not input.aux        then input.aux        = { } end

if not input.suffixmap  then input.suffixmap  = { } end

if not input.locators   then input.locators   = { } end  -- locate databases
if not input.hashers    then input.hashers    = { } end  -- load databases
if not input.generators then input.generators = { } end  -- generate databases
if not input.filters    then input.filters    = { } end  -- conversion filters

local format = string.format

input.locators.notfound   = { nil }
input.hashers.notfound    = { nil }
input.generators.notfound = { nil }

input.cacheversion = '1.0.1'
input.banner       = nil
input.verbose      = false
input.debug        = false
input.cnfname      = 'texmf.cnf'
input.luaname      = 'texmfcnf.lua'
input.lsrname      = 'ls-R'
input.homedir      = os.env[os.platform == "windows" and 'USERPROFILE'] or os.env['HOME'] or '~'

--~ input.luasuffix    = 'tma'
--~ input.lucsuffix    = 'tmc'

-- for the moment we have .local but this will disappear
input.cnfdefault   = '{$SELFAUTOLOC,$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}'

-- chances are low that the cnf file is in the bin path
input.cnfdefault   = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}'

-- we use a cleaned up list / format=any is a wildcard, as is *name

input.formats['afm'] = 'AFMFONTS'       input.suffixes['afm'] = { 'afm' }
input.formats['enc'] = 'ENCFONTS'       input.suffixes['enc'] = { 'enc' }
input.formats['fmt'] = 'TEXFORMATS'     input.suffixes['fmt'] = { 'fmt' }
input.formats['map'] = 'TEXFONTMAPS'    input.suffixes['map'] = { 'map' }
input.formats['mp']  = 'MPINPUTS'       input.suffixes['mp']  = { 'mp' }
input.formats['ocp'] = 'OCPINPUTS'      input.suffixes['ocp'] = { 'ocp' }
input.formats['ofm'] = 'OFMFONTS'       input.suffixes['ofm'] = { 'ofm', 'tfm' }
input.formats['otf'] = 'OPENTYPEFONTS'  input.suffixes['otf'] = { 'otf' } -- 'ttf'
input.formats['opl'] = 'OPLFONTS'       input.suffixes['opl'] = { 'opl' }
input.formats['otp'] = 'OTPINPUTS'      input.suffixes['otp'] = { 'otp' }
input.formats['ovf'] = 'OVFFONTS'       input.suffixes['ovf'] = { 'ovf', 'vf' }
input.formats['ovp'] = 'OVPFONTS'       input.suffixes['ovp'] = { 'ovp' }
input.formats['tex'] = 'TEXINPUTS'      input.suffixes['tex'] = { 'tex' }
input.formats['tfm'] = 'TFMFONTS'       input.suffixes['tfm'] = { 'tfm' }
input.formats['ttf'] = 'TTFONTS'        input.suffixes['ttf'] = { 'ttf', 'ttc' }
input.formats['pfb'] = 'T1FONTS'        input.suffixes['pfb'] = { 'pfb', 'pfa' }
input.formats['vf']  = 'VFFONTS'        input.suffixes['vf']  = { 'vf' }

input.formats['fea'] = 'FONTFEATURES'   input.suffixes['fea'] = { 'fea' }
input.formats['cid'] = 'FONTCIDMAPS'    input.suffixes['cid'] = { 'cid', 'cidmap' }

input.formats ['texmfscripts'] = 'TEXMFSCRIPTS' -- new
input.suffixes['texmfscripts'] = { 'rb', 'pl', 'py' } -- 'lua'

input.formats ['lua'] = 'LUAINPUTS' -- new
input.suffixes['lua'] = { 'lua', 'luc', 'tma', 'tmc' }

-- here we catch a few new thingies (todo: add these paths to context.tmf)
--
-- FONTFEATURES  = .;$TEXMF/fonts/fea//
-- FONTCIDMAPS   = .;$TEXMF/fonts/cid//

function input.checkconfigdata() -- not yet ok, no time for debugging now
    local instance = input.instance
    local function fix(varname,default)
        local proname = varname .. "." .. instance.progname or "crap"
        local p = instance.environment[proname]
        local v = instance.environment[varname]
        if not ((p and p ~= "") or (v and v ~= "")) then
            instance.variables[varname] = default -- or environment?
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
end

-- backward compatible ones

input.alternatives = { }

input.alternatives['map files']            = 'map'
input.alternatives['enc files']            = 'enc'
input.alternatives['cid files']            = 'cid'
input.alternatives['fea files']            = 'fea'
input.alternatives['opentype fonts']       = 'otf'
input.alternatives['truetype fonts']       = 'ttf'
input.alternatives['truetype collections'] = 'ttc'
input.alternatives['type1 fonts']          = 'pfb'

-- obscure ones

input.formats ['misc fonts'] = ''
input.suffixes['misc fonts'] = { }

input.formats     ['sfd']                      = 'SFDFONTS'
input.suffixes    ['sfd']                      = { 'sfd' }
input.alternatives['subfont definition files'] = 'sfd'

-- In practice we will work within one tds tree, but i want to keep
-- the option open to build tools that look at multiple trees, which is
-- why we keep the tree specific data in a table. We used to pass the
-- instance but for practical pusposes we now avoid this and use a
-- instance variable.

function input.newinstance()

    local instance = { }

    instance.rootpath        = ''
    instance.treepath        = ''
    instance.progname        = 'context'
    instance.engine          = 'luatex'
    instance.format          = ''
    instance.environment     = { }
    instance.variables       = { }
    instance.expansions      = { }
    instance.files           = { }
    instance.remap           = { }
    instance.configuration   = { }
    instance.setup           = { }
    instance.order           = { }
    instance.found           = { }
    instance.foundintrees    = { }
    instance.kpsevars        = { }
    instance.hashes          = { }
    instance.cnffiles        = { }
    instance.luafiles        = { }
    instance.lists           = { }
    instance.remember        = true
    instance.diskcache       = true
    instance.renewcache      = false
    instance.scandisk        = true
    instance.cachepath       = nil
    instance.loaderror       = false
    instance.smallcache      = false
    instance.sortdata        = false
    instance.savelists       = true
    instance.cleanuppaths    = true
    instance.allresults      = false
    instance.pattern         = nil    -- lists
    instance.kpseonly        = false  -- lists
    instance.loadtime        = 0
    instance.starttime       = 0
    instance.stoptime        = 0
    instance.validfile       = function(path,name) return true end
    instance.data            = { } -- only for loading
    instance.force_suffixes  = true
    instance.dummy_path_expr = "^!*unset/*$"
    instance.fakepaths       = { }
    instance.lsrmode         = false

    -- store once, freeze and faster (once reset we can best use instance.environment)

    for k,v in pairs(os.env) do
        instance.environment[k] = input.bare_variable(v)
    end

    -- cross referencing, delayed because we can add suffixes

    for k, v in pairs(input.suffixes) do
        for _, vv in pairs(v) do
            if vv then
                input.suffixmap[vv] = k
            end
        end
    end

    return instance

end

input.instance = input.instance or nil

function input.reset()
    input.instance = input.newinstance()
    return input.instance
end

function input.reset_hashes()
    input.instance.lists = { }
    input.instance.found = { }
end

function input.bare_variable(str) -- assumes str is a string
 -- return string.gsub(string.gsub(string.gsub(str,"%s+$",""),'^"(.+)"$',"%1"),"^'(.+)'$","%1")
    return (str:gsub("\s*([\"\']?)(.+)%1\s*", "%2"))
end

function input.settrace(n)
    input.trace = tonumber(n or 0)
    if input.trace > 0 then
        input.verbose = true
    end
end

input.log  = (texio and texio.write_nl) or print

function input.report(...)
    if input.verbose then
        input.log("<<"..format(...)..">>")
    end
end

function input.report(...)
    if input.trace > 0 then -- extra test
        input.log("<<"..format(...)..">>")
    end
end

input.settrace(tonumber(os.getenv("MTX.INPUT.TRACE") or os.getenv("MTX_INPUT_TRACE") or input.trace or 0))

-- These functions can be used to test the performance, especially
-- loading the database files.

do
    local clock = os.gettimeofday or os.clock

    function input.starttiming(instance)
        if instance then
            instance.starttime = clock()
            if not instance.loadtime then
                instance.loadtime = 0
            end
        end
    end

    function input.stoptiming(instance, report)
        if instance then
            local starttime = instance.starttime
            if starttime then
                local stoptime = clock()
                local loadtime = stoptime - starttime
                instance.stoptime = stoptime
                instance.loadtime = instance.loadtime + loadtime
                if report then
                    input.report("load time %0.3f",loadtime)
                end
                return loadtime
            end
        end
        return 0
    end

end

function input.elapsedtime(instance)
    return format("%0.3f",(instance and instance.loadtime) or 0)
end

function input.report_loadtime(instance)
    if instance then
        input.report('total load time %s', input.elapsedtime(instance))
    end
end

input.loadtime = input.elapsedtime

function input.env(key)
    return input.instance.environment[key] or input.osenv(key)
end

function input.osenv(key)
    local ie = input.instance.environment
    local value = ie[key]
    if value == nil then
     -- local e = os.getenv(key)
        local e = os.env[key]
        if e == nil then
         -- value = "" -- false
        else
            value = input.bare_variable(e)
        end
        ie[key] = value
    end
    return value or ""
end

-- we follow a rather traditional approach:
--
-- (1) texmf.cnf given in TEXMFCNF
-- (2) texmf.cnf searched in default variable
--
-- also we now follow the stupid route: if not set then just assume *one*
-- cnf file under texmf (i.e. distribution)

input.ownpath     = input.ownpath or nil
input.ownbin      = input.ownbin  or arg[-2] or arg[-1] or arg[0] or "luatex"
input.autoselfdir = true -- false may be handy for debugging

function input.getownpath()
    if not input.ownpath then
        if input.autoselfdir and os.selfdir then
            input.ownpath = os.selfdir
        else
            local binary = input.ownbin
            if os.platform == "windows" then
                binary = file.replacesuffix(binary,"exe")
            end
            for p in string.gmatch(os.getenv("PATH"),"[^"..io.pathseparator.."]+") do
                local b = file.join(p,binary)
                if lfs.isfile(b) then
                    -- we assume that after changing to the path the currentdir function
                    -- resolves to the real location and use this side effect here; this
                    -- trick is needed because on the mac installations use symlinks in the
                    -- path instead of real locations
                    local olddir = lfs.currentdir()
                    if lfs.chdir(p) then
                        local pp = lfs.currentdir()
                        if input.verbose and p ~= pp then
                            input.report("following symlink %s to %s",p,pp)
                        end
                        input.ownpath = pp
                        lfs.chdir(olddir)
                    else
                        if input.verbose then
                            input.report("unable to check path %s",p)
                        end
                        input.ownpath =  p
                    end
                    break
                end
            end
        end
        if not input.ownpath then input.ownpath = '.' end
    end
    return input.ownpath
end

function input.identify_own()
    local instance = input.instance
    local ownpath = input.getownpath() or lfs.currentdir()
    local ie = instance.environment
    if ownpath then
        if input.env('SELFAUTOLOC')    == "" then os.env['SELFAUTOLOC']    = file.collapse_path(ownpath) end
        if input.env('SELFAUTODIR')    == "" then os.env['SELFAUTODIR']    = file.collapse_path(ownpath .. "/..") end
        if input.env('SELFAUTOPARENT') == "" then os.env['SELFAUTOPARENT'] = file.collapse_path(ownpath .. "/../..") end
    else
        input.verbose = true
        input.report("error: unable to locate ownpath")
        os.exit()
    end
    if input.env('TEXMFCNF') == "" then os.env['TEXMFCNF'] = input.cnfdefault end
    if input.env('TEXOS')    == "" then os.env['TEXOS']    = input.env('SELFAUTODIR') end
    if input.env('TEXROOT')  == "" then os.env['TEXROOT']  = input.env('SELFAUTOPARENT') end
    if input.verbose then
        for _,v in ipairs({"SELFAUTOLOC","SELFAUTODIR","SELFAUTOPARENT","TEXMFCNF"}) do
            input.report("variable %s set to %s",v,input.env(v) or "unknown")
        end
    end
    function input.identify_own() end
end

function input.identify_cnf()
    local instance = input.instance
    if #instance.cnffiles == 0 then
        -- fallback
        input.identify_own()
        -- the real search
        input.expand_variables()
        local t = input.split_path(input.env('TEXMFCNF'))
        t = input.aux.expanded_path(t)
        input.aux.expand_vars(t) -- redundant
        local function locate(filename,list)
            for _,v in ipairs(t) do
                local texmfcnf = input.normalize_name(file.join(v,filename))
                if lfs.isfile(texmfcnf) then
                    table.insert(list,texmfcnf)
                end
            end
        end
        locate(input.luaname,instance.luafiles)
        locate(input.cnfname,instance.cnffiles)
    end
end

function input.load_cnf()
    local instance = input.instance
    local function loadoldconfigdata()
        for _, fname in ipairs(instance.cnffiles) do
            input.aux.load_cnf(fname)
        end
    end
    -- instance.cnffiles contain complete names now !
    if #instance.cnffiles == 0 then
        input.report("no cnf files found (TEXMFCNF may not be set/known)")
    else
        instance.rootpath = instance.cnffiles[1]
        for k,fname in ipairs(instance.cnffiles) do
            instance.cnffiles[k] = input.normalize_name(fname:gsub("\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = input.normalize_name(instance.rootpath)
        if instance.lsrmode then
            loadoldconfigdata()
        elseif instance.diskcache and not instance.renewcache then
            input.loadoldconfig(instance.cnffiles)
            if instance.loaderror then
                loadoldconfigdata()
                input.saveoldconfig()
            end
        else
            loadoldconfigdata()
            if instance.renewcache then
                input.saveoldconfig()
            end
        end
        input.aux.collapse_cnf_data()
    end
    input.checkconfigdata()
end

function input.load_lua()
    local instance = input.instance
    if #instance.luafiles == 0 then
        -- yet harmless
    else
        instance.rootpath = instance.luafiles[1]
        for k,fname in ipairs(instance.luafiles) do
            instance.luafiles[k] = input.normalize_name(fname:gsub("\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = input.normalize_name(instance.rootpath)
        input.loadnewconfig()
        input.aux.collapse_cnf_data()
    end
    input.checkconfigdata()
end

function input.aux.collapse_cnf_data() -- potential optimization: pass start index (setup and configuration are shared)
    local instance = input.instance
    for _,c in ipairs(instance.order) do
        for k,v in pairs(c) do
            if not instance.variables[k] then
                if instance.environment[k] then
                    instance.variables[k] = instance.environment[k]
                else
                    instance.kpsevars[k] = true
                    instance.variables[k] = input.bare_variable(v)
                end
            end
        end
    end
end

function input.aux.load_cnf(fname)
    local instance = input.instance
    fname = input.clean_path(fname)
    local lname = file.replacesuffix(fname,'lua')
    local f = io.open(lname)
    if f then -- this will go
        f:close()
        local dname = file.dirname(fname)
        if not instance.configuration[dname] then
            input.aux.load_configuration(dname,lname)
            instance.order[#instance.order+1] = instance.configuration[dname]
        end
    else
        f = io.open(fname)
        if f then
            input.report("loading %s", fname)
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
                        line, n = line:gsub("\\%s*$", "")
                        if n > 0 then
                            line = line .. f:read()
                        else
                            break
                        end
                    end
                    if not line:find("^[%%#]") then
                        local k, v = (line:gsub("%s*%%.*$","")):match("%s*(.-)%s*=%s*(.-)%s*$")
                        if k and v and not data[k] then
                            data[k] = (v:gsub("[%%#].*",'')):gsub("~", "$HOME")
                            instance.kpsevars[k] = true
                        end
                    end
                else
                    break
                end
            end
            f:close()
        else
            input.report("skipping %s", fname)
        end
    end
end

-- database loading

function input.load_hash()
    local instance = input.instance
    input.locatelists()
    if instance.lsrmode then
        input.loadlists()
    elseif instance.diskcache and not instance.renewcache then
        input.loadfiles()
        if instance.loaderror then
            input.loadlists()
            input.savefiles()
        end
    else
        input.loadlists()
        if instance.renewcache then
            input.savefiles()
        end
    end
end

function input.aux.append_hash(type,tag,name)
    if input.trace > 0 then
        input.logger("= hash append: %s",tag)
    end
    table.insert(input.instance.hashes, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function input.aux.prepend_hash(type,tag,name)
    if input.trace > 0 then
        input.logger("= hash prepend: %s",tag)
    end
    table.insert(input.instance.hashes, 1, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function input.aux.extend_texmf_var(specification) -- crap, we could better prepend the hash
    local instance = input.instance
--  local t = input.expanded_path_list('TEXMF') -- full expansion
    local t = input.split_path(input.env('TEXMF'))
    table.insert(t,1,specification)
    local newspec = table.join(t,";")
    if instance.environment["TEXMF"] then
        instance.environment["TEXMF"] = newspec
    elseif instance.variables["TEXMF"] then
        instance.variables["TEXMF"] = newspec
    else
        -- weird
    end
    input.expand_variables()
    input.reset_hashes()
end

-- locators

function input.locatelists()
    local instance = input.instance
    for _, path in pairs(input.clean_path_list('TEXMF')) do
        input.report("locating list of %s",path)
        input.locatedatabase(input.normalize_name(path))
    end
end

function input.locatedatabase(specification)
    return input.methodhandler('locators', specification)
end

function input.locators.tex(specification)
    if specification and specification ~= '' and lfs.isdir(specification) then
        if input.trace > 0 then
            input.logger('! tex locator found: %s',specification)
        end
        input.aux.append_hash('file',specification,filename)
    elseif input.trace > 0 then
        input.logger('? tex locator not found: %s',specification)
    end
end

-- hashers

function input.hashdatabase(tag,name)
    return input.methodhandler('hashers',tag,name)
end

function input.loadfiles()
    local instance = input.instance
    instance.loaderror = false
    instance.files = { }
    if not instance.renewcache then
        for _, hash in ipairs(instance.hashes) do
            input.hashdatabase(hash.tag,hash.name)
            if instance.loaderror then break end
        end
    end
end

function input.hashers.tex(tag,name)
    input.aux.load_files(tag)
end

-- generators:

function input.loadlists()
    for _, hash in ipairs(input.instance.hashes) do
        input.generatedatabase(hash.tag)
    end
end

function input.generatedatabase(specification)
    return input.methodhandler('generators', specification)
end

local weird = lpeg.anywhere(lpeg.S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

function input.generators.tex(specification)
    local instance = input.instance
    local tag = specification
    if not instance.lsrmode and lfs.dir then
        input.report("scanning path %s",specification)
        instance.files[tag] = { }
        local files = instance.files[tag]
        local n, m, r = 0, 0, 0
        local spec = specification .. '/'
        local attributes = lfs.attributes
        local directory = lfs.dir
        local small = instance.smallcache
        local function action(path)
            local mode, full
            if path then
                full = spec .. path .. '/'
            else
                full = spec
            end
            for name in directory(full) do
                if name:find("^%.") then
                  -- skip
            --  elseif name:find("[%~%`%!%#%$%%%^%&%*%(%)%=%{%}%[%]%:%;\"\'%|%<%>%,%?\n\r\t]") then -- too much escaped
                elseif weird:match(name) then
                  -- texio.write_nl("skipping " .. name)
                  -- skip
                else
                    mode = attributes(full..name,'mode')
                    if mode == 'directory' then
                        m = m + 1
                        if path then
                            action(path..'/'..name)
                        else
                            action(name)
                        end
                    elseif path and mode == 'file' then
                        n = n + 1
                        local f = files[name]
                        if f then
                            if not small then
                                if type(f) == 'string' then
                                    files[name] = { f, path }
                                else
                                  f[#f+1] = path
                                end
                            end
                        else
                            files[name] = path
                            local lower = name:lower()
                            if name ~= lower then
                                files["remap:"..lower] = name
                                r = r + 1
                            end
                        end
                    end
                end
            end
        end
        action()
        input.report("%s files found on %s directories with %s uppercase remappings",n,m,r)
    else
        local fullname = file.join(specification,input.lsrname)
        local path     = '.'
        local f        = io.open(fullname)
        if f then
            instance.files[tag] = { }
            local files = instance.files[tag]
            local small = instance.smallcache
            input.report("loading lsr file %s",fullname)
        --  for line in f:lines() do -- much slower then the next one
            for line in (f:read("*a")):gmatch("(.-)\n") do
                if line:find("^[%a%d]") then
                    local fl = files[line]
                    if fl then
                        if not small then
                            if type(fl) == 'string' then
                                files[line] = { fl, path } -- table
                            else
                                fl[#fl+1] = path
                            end
                        end
                    else
                        files[line] = path -- string
                        local lower = line:lower()
                        if line ~= lower then
                            files["remap:"..lower] = line
                        end
                    end
                else
                    path = line:match("%.%/(.-)%:$") or path -- match could be nil due to empty line
                end
            end
            f:close()
        end
    end
end

-- savers, todo

function input.savefiles()
    input.aux.save_data('files', function(k,v)
        return input.instance.validfile(k,v) -- path, name
    end)
end

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

function input.splitconfig()
    for i,c in ipairs(input.instance) do
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

function input.joinconfig()
    for i,c in ipairs(input.instance.order) do
        for k,v in pairs(c) do
            if type(v) == 'table' then
                c[k] = file.join_path(v)
            end
        end
    end
end
function input.split_path(str)
    if type(str) == 'table' then
        return str
    else
        return file.split_path(str)
    end
end
function input.join_path(str)
    if type(str) == 'table' then
        return file.join_path(str)
    else
        return str
    end
end

function input.splitexpansions()
    local ie = input.instance.expansions
    for k,v in pairs(ie) do
        local t, h = { }, { }
        for _,vv in pairs(file.split_path(v)) do
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

function input.saveoldconfig()
    input.splitconfig()
    input.aux.save_data('configuration', nil)
    input.joinconfig()
end

input.configbanner = [[
-- This is a Luatex configuration file created by 'luatools.lua' or
-- 'luatex.exe' directly. For comment, suggestions and questions you can
-- contact the ConTeXt Development Team. This configuration file is
-- not copyrighted. [HH & TH]
]]

function input.serialize(files)
    -- This version is somewhat optimized for the kind of
    -- tables that we deal with, so it's much faster than
    -- the generic serializer. This makes sense because
    -- luatools and mtxtools are called frequently. Okay,
    -- we pay a small price for properly tabbed tables.
    local t = { }
    local concat = table.concat
    local sorted = table.sortedkeys
    local function dump(k,v,m)
        if type(v) == 'string' then
            return m .. "['" .. k .. "']='" .. v .. "',"
        elseif #v == 1 then
            return m .. "['" .. k .. "']='" .. v[1] .. "',"
        else
            return m .. "['" .. k .. "']={'" .. concat(v,"','").. "'},"
        end
    end
    t[#t+1] = "return {"
    if input.instance.sortdata then
        for _, k in pairs(sorted(files)) do
            local fk  = files[k]
            if type(fk) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for _, kk in pairs(sorted(fk)) do
                    t[#t+1] = dump(kk,fk[kk],"\t\t")
                end
                t[#t+1] = "\t},"
            else
                t[#t+1] = dump(k,fk,"\t")
            end
        end
    else
        for k, v in pairs(files) do
            if type(v) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for kk,vv in pairs(v) do
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

if not texmf then texmf = {} end -- no longer needed, at least not here

function input.aux.save_data(dataname, check, makename) -- untested without cache overload
    for cachename, files in pairs(input.instance[dataname]) do
        local name = (makename or file.join)(cachename,dataname)
        local luaname, lucname = name .. ".lua", name .. ".luc"
        input.report("preparing %s for %s",dataname,cachename)
        for k, v in pairs(files) do
            if not check or check(v,k) then -- path, name
                if type(v) == "table" and #v == 1 then
                    files[k] = v[1]
                end
            else
                files[k] = nil -- false
            end
        end
        local data = {
            type    = dataname,
            root    = cachename,
            version = input.cacheversion,
            date    = os.date("%Y-%m-%d"),
            time    = os.date("%H:%M:%S"),
            content = files,
        }
        local ok = io.savedata(luaname,input.serialize(data))
        if ok then
            input.report("%s saved in %s",dataname,luaname)
            if utils.lua.compile(luaname,lucname,false,true) then -- no cleanup but strip
                input.report("%s compiled to %s",dataname,lucname)
            else
                input.report("compiling failed for %s, deleting file %s",dataname,lucname)
                os.remove(lucname)
            end
        else
            input.report("unable to save %s in %s (access error)",dataname,luaname)
        end
    end
end

function input.aux.load_data(pathname,dataname,filename,makename) -- untested without cache overload
    local instance = input.instance
    filename = ((not filename or (filename == "")) and dataname) or filename
    filename = (makename and makename(dataname,filename)) or file.join(pathname,filename)
    local blob = loadfile(filename .. ".luc") or loadfile(filename .. ".lua")
    if blob then
        local data = blob()
        if data and data.content and data.type == dataname and data.version == input.cacheversion then
            input.report("loading %s for %s from %s",dataname,pathname,filename)
            instance[dataname][pathname] = data.content
        else
            input.report("skipping %s for %s from %s",dataname,pathname,filename)
            instance[dataname][pathname] = { }
            instance.loaderror = true
        end
    else
        input.report("skipping %s for %s from %s",dataname,pathname,filename)
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

function input.aux.load_texmfcnf(dataname,pathname)
    local instance = input.instance
    local filename = file.join(pathname,input.luaname)
    local blob = loadfile(filename)
    if blob then
        local data = blob()
        if data then
            input.report("loading configuration file %s",filename)
            if true then
                -- flatten to variable.progname
                local t = { }
                for k, v in pairs(data) do -- v = progname
                    if type(v) == "string" then
                        t[k] = v
                    else
                        for kk, vv in pairs(v) do -- vv = variable
                            if type(vv) == "string" then
                                t[vv.."."..v] = kk
                            end
                        end
                    end
                end
                instance[dataname][pathname] = t
            else
                instance[dataname][pathname] = data
            end
        else
            input.report("skipping configuration file %s",filename)
            instance[dataname][pathname] = { }
            instance.loaderror = true
        end
    else
        input.report("skipping configuration file %s",filename)
    end
end

function input.aux.load_configuration(dname,lname)
    input.aux.load_data(dname,'configuration',lname and file.basename(lname))
end
function input.aux.load_files(tag)
    input.aux.load_data(tag,'files')
end

function input.resetconfig()
    input.identify_own()
    local instance = input.instance
    instance.configuration, instance.setup, instance.order, instance.loaderror = { }, { }, { }, false
end

function input.loadnewconfig()
    local instance = input.instance
    for _, cnf in ipairs(instance.luafiles) do
        local dname = file.dirname(cnf)
        input.aux.load_texmfcnf('setup',dname)
        instance.order[#instance.order+1] = instance.setup[dname]
        if instance.loaderror then break end
    end
end

function input.loadoldconfig()
    local instance = input.instance
    if not instance.renewcache then
        for _, cnf in ipairs(instance.cnffiles) do
            local dname = file.dirname(cnf)
            input.aux.load_configuration(dname)
            instance.order[#instance.order+1] = instance.configuration[dname]
            if instance.loaderror then break end
        end
    end
    input.joinconfig()
end

function input.expand_variables()
    local instance = input.instance
    local expansions, environment, variables = { }, instance.environment, instance.variables
    local env = input.env
    instance.expansions = expansions
    if instance.engine   ~= "" then environment['engine']   = instance.engine   end
    if instance.progname ~= "" then environment['progname'] = instance.progname end
    for k,v in pairs(environment) do
        local a, b = k:match("^(%a+)%_(.*)%s*$")
        if a and b then
            expansions[a..'.'..b] = v
        else
            expansions[k] = v
        end
    end
    for k,v in pairs(environment) do -- move environment to expansions
        if not expansions[k] then expansions[k] = v end
    end
    for k,v in pairs(variables) do -- move variables to expansions
        if not expansions[k] then expansions[k] = v end
    end
    while true do
        local busy = false
        for k,v in pairs(expansions) do
            local s, n = v:gsub("%$([%a%d%_%-]+)", function(a)
                busy = true
                return expansions[a] or env(a)
            end)
            local s, m = s:gsub("%$%{([%a%d%_%-]+)%}", function(a)
                busy = true
                return expansions[a] or env(a)
            end)
            if n > 0 or m > 0 then
                expansions[k]= s
            end
        end
        if not busy then break end
    end
    for k,v in pairs(expansions) do
        expansions[k] = v:gsub("\\", '/')
    end
end

function input.aux.expand_vars(lst) -- simple vars
    local instance = input.instance
    local variables, env = instance.variables, input.env
    for k,v in pairs(lst) do
        lst[k] = v:gsub("%$([%a%d%_%-]+)", function(a)
            return variables[a] or env(a)
        end)
    end
end

function input.aux.expanded_var(var) -- simple vars
    local instance = input.instance
    return var:gsub("%$([%a%d%_%-]+)", function(a)
        return instance.variables[a] or input.env(a)
    end)
end

function input.aux.entry(entries,name)
    if name and (name ~= "") then
        local instance = input.instance
        name = name:gsub('%$','')
        local result = entries[name..'.'..instance.progname] or entries[name]
        if result then
            return result
        else
            result = input.env(name)
            if result then
                instance.variables[name] = result
                input.expand_variables()
                return instance.expansions[name] or ""
            end
        end
    end
    return ""
end
function input.variable(name)
    return input.aux.entry(input.instance.variables,name)
end
function input.expansion(name)
    return input.aux.entry(input.instance.expansions,name)
end

function input.aux.is_entry(entries,name)
    if name and name ~= "" then
        name = name:gsub('%$','')
        return (entries[name..'.'..input.instance.progname] or entries[name]) ~= nil
    else
        return false
    end
end

function input.is_variable(name)
    return input.aux.is_entry(input.instance.variables,name)
end

function input.is_expansion(name)
    return input.aux.is_entry(input.instance.expansions,name)
end

function input.unexpanded_path_list(str)
    local pth = input.variable(str)
    local lst = input.split_path(pth)
    return input.aux.expanded_path(lst)
end

function input.unexpanded_path(str)
    return file.join_path(input.unexpanded_path_list(str))
end

do
    local done = { }

    function input.reset_extra_path()
        local instance = input.instance
        local ep = instance.extra_paths
        if not ep then
            ep, done = { }, { }
            instance.extra_paths = ep
        elseif #ep > 0 then
            instance.lists, done = { }, { }
        end
    end

    function input.register_extra_path(paths,subpaths)
        local instance = input.instance
        local ep = instance.extra_paths or { }
        local n = #ep
        if paths and paths ~= "" then
            if subpaths and subpaths ~= "" then
                for p in paths:gmatch("[^,]+") do
                    -- we gmatch each step again, not that fast, but used seldom
                    for s in subpaths:gmatch("[^,]+") do
                        local ps = p .. "/" .. s
                        if not done[ps] then
                            ep[#ep+1] = input.clean_path(ps)
                            done[ps] = true
                        end
                    end
                end
            else
                for p in paths:gmatch("[^,]+") do
                    if not done[p] then
                        ep[#ep+1] = input.clean_path(p)
                        done[p] = true
                    end
                end
            end
        elseif subpaths and subpaths ~= "" then
            for i=1,n do
                -- we gmatch each step again, not that fast, but used seldom
                for s in subpaths:gmatch("[^,]+") do
                    local ps = ep[i] .. "/" .. s
                    if not done[ps] then
                        ep[#ep+1] = input.clean_path(ps)
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

function input.expanded_path_list(str)
    local instance = input.instance
    local function made_list(list)
        local ep = instance.extra_paths
        if not ep or #ep == 0 then
            return list
        else
            local done, new = { }, { }
            -- honour . .. ../.. but only when at the start
            for k, v in ipairs(list) do
                if not done[v] then
                    if v:find("^[%.%/]$") then
                        done[v] = true
                        new[#new+1] = v
                    else
                        break
                    end
                end
            end
            -- first the extra paths
            for k, v in ipairs(ep) do
                if not done[v] then
                    done[v] = true
                    new[#new+1] = v
                end
            end
            -- next the formal paths
            for k, v in ipairs(list) do
                if not done[v] then
                    done[v] = true
                    new[#new+1] = v
                end
            end
            return new
        end
    end
    if not str then
        return ep or { }
    elseif instance.savelists then
        -- engine+progname hash
        str = str:gsub("%$","")
        if not instance.lists[str] then -- cached
            local lst = made_list(input.split_path(input.expansion(str)))
            instance.lists[str] = input.aux.expanded_path(lst)
        end
        return instance.lists[str]
    else
        local lst = input.split_path(input.expansion(str))
        return made_list(input.aux.expanded_path(lst))
    end
end


function input.clean_path_list(str)
    local t = input.expanded_path_list(str)
    if t then
        for i=1,#t do
            t[i] = file.collapse_path(input.clean_path(t[i]))
        end
    end
    return t
end

function input.expand_path(str)
    return file.join_path(input.expanded_path_list(str))
end

function input.expanded_path_list_from_var(str) -- brrr
    local tmp = input.var_of_format_or_suffix(str:gsub("%$",""))
    if tmp ~= "" then
        return input.expanded_path_list(str)
    else
        return input.expanded_path_list(tmp)
    end
end
function input.expand_path_from_var(str)
    return file.join_path(input.expanded_path_list_from_var(str))
end

function input.format_of_var(str)
    return input.formats[str] or input.formats[input.alternatives[str]] or ''
end
function input.format_of_suffix(str)
    return input.suffixmap[file.extname(str)] or 'tex'
end

function input.variable_of_format(str)
    return input.formats[str] or input.formats[input.alternatives[str]] or ''
end

function input.var_of_format_or_suffix(str)
    local v = input.formats[str]
    if v then
        return v
    end
    v = input.formats[input.alternatives[str]]
    if v then
        return v
    end
    v = input.suffixmap[file.extname(str)]
    if v then
        return input.formats[isf]
    end
    return ''
end

function input.expand_braces(str) -- output variable and brace expansion of STRING
    local ori = input.variable(str)
    local pth = input.aux.expanded_path(input.split_path(ori))
    return file.join_path(pth)
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

function input.aux.splitpathexpr(str, t, validate)
    -- no need for optimization, only called a few times, we can use lpeg for the sub
    t = t or { }
    local concat = table.concat
    str = str:gsub(",}",",@}")
    str = str:gsub("{,","{@,")
 -- str = "@" .. str .. "@"
    while true do
        local done = false
        while true do
            local ok = false
            str = str:gsub("([^{},]+){([^{}]+)}", function(a,b)
                local t = { }
                for s in b:gmatch("[^,]+") do t[#t+1] = a .. s end
                ok, done = true, true
                return "{" .. concat(t,",") .. "}"
            end)
            if not ok then break end
        end
        while true do
            local ok = false
            str = str:gsub("{([^{}]+)}([^{},]+)", function(a,b)
                local t = { }
                for s in a:gmatch("[^,]+") do t[#t+1] = s .. b end
                ok, done = true, true
                return "{" .. concat(t,",") .. "}"
            end)
            if not ok then break end
        end
        while true do
            local ok = false
            str = str:gsub("{([^{}]+)}{([^{}]+)}", function(a,b)
                local t = { }
                for sa in a:gmatch("[^,]+") do
                    for sb in b:gmatch("[^,]+") do
                        t[#t+1] = sa .. sb
                    end
                end
                ok, done = true, true
                return "{" .. concat(t,",") .. "}"
            end)
            if not ok then break end
        end
        str = str:gsub("({[^{}]*){([^{}]+)}([^{}]*})", function(a,b,c)
            done = true
            return a .. b.. c
        end)
        if not done then break end
    end
    str = str:gsub("[{}]", "")
    str = str:gsub("@","")
    if validate then
        for s in str:gmatch("[^,]+") do
            s = validate(s)
            if s then t[#t+1] = s end
        end
    else
        for s in str:gmatch("[^,]+") do
            t[#t+1] = s
        end
    end
    return t
end

function input.aux.expanded_path(pathlist) -- maybe not a list, just a path
    local instance = input.instance
    -- a previous version fed back into pathlist
    local newlist, ok = { }, false
    for _,v in ipairs(pathlist) do
        if v:find("[{}]") then
            ok = true
            break
        end
    end
    if ok then
        for _, v in ipairs(pathlist) do
            input.aux.splitpathexpr(v, newlist, function(s)
                s = file.collapse_path(s)
                return s ~= "" and not s:find(instance.dummy_path_expr) and s
            end)
        end
    else
        for _,v in ipairs(pathlist) do
            for vv in string.gmatch(v..',',"(.-),") do
                vv = file.collapse_path(v)
                if vv ~= "" then newlist[#newlist+1] = vv end
            end
        end
    end
    return newlist
end

input.is_readable = { }

function input.aux.is_readable(readable, name)
    if input.trace > 2 then
        if readable then
            input.logger("+ readable: %s",name)
        else
            input.logger("- readable: %s", name)
        end
    end
    return readable
end

function input.is_readable.file(name)
    return input.aux.is_readable(lfs.isfile(name), name)
end

input.is_readable.tex = input.is_readable.file

-- name
-- name/name

function input.aux.collect_files(names)
    local instance = input.instance
    local filelist = { }
    for _, fname in pairs(names) do
        if fname then
            if input.trace > 2 then
                input.logger("? blobpath asked: %s",fname)
            end
            local bname = file.basename(fname)
            local dname = file.dirname(fname)
            if dname == "" or dname:find("^%.") then
                dname = false
            else
                dname = "/" .. dname .. "$"
            end
            for _, hash in ipairs(instance.hashes) do
                local blobpath = hash.tag
                local files = blobpath and instance.files[blobpath]
                if files then
                    if input.trace > 2 then
                        input.logger('? blobpath do: %s (%s)',blobpath,bname)
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
                            if not dname or blobfile:find(dname) then
                                filelist[#filelist+1] = {
                                    hash.type,
                                    file.join(blobpath,blobfile,bname), -- search
                                    input.concatinators[hash.type](blobpath,blobfile,bname) -- result
                                }
                            end
                        else
                            for _, vv in pairs(blobfile) do
                                if not dname or vv:find(dname) then
                                    filelist[#filelist+1] = {
                                        hash.type,
                                        file.join(blobpath,vv,bname), -- search
                                        input.concatinators[hash.type](blobpath,vv,bname) -- result
                                    }
                                end
                            end
                        end
                    end
                elseif input.trace > 1 then
                    input.logger('! blobpath no: %s (%s)',blobpath,bname)
                end
            end
        end
    end
    if #filelist > 0 then
        return filelist
    else
        return nil
    end
end

function input.suffix_of_format(str)
    if input.suffixes[str] then
        return input.suffixes[str][1]
    else
        return ""
    end
end

function input.suffixes_of_format(str)
    if input.suffixes[str] then
        return input.suffixes[str]
    else
        return {}
    end
end

do

    -- called about 700 times for an empty doc (font initializations etc)
    -- i need to weed the font files for redundant calls

    local letter     = lpeg.R("az","AZ")
    local separator  = lpeg.P("://")

    local qualified = lpeg.P(".")^0 * lpeg.P("/") + letter*lpeg.P(":") + letter^1*separator
    local rootbased = lpeg.P("/") + letter*lpeg.P(":")

    -- ./name ../name  /name c: ://
    function input.aux.qualified_path(filename)
        return qualified:match(filename)
    end
    function input.aux.rootbased_path(filename)
        return rootbased:match(filename)
    end

    function input.normalize_name(original)
        return original
    end

    input.normalize_name = file.collapse_path

end

function input.aux.register_in_trees(name)
    if not name:find("^%.") then
        local instance = input.instance
        instance.foundintrees[name] = (instance.foundintrees[name] or 0) + 1 -- maybe only one
    end
end

-- split the next one up, better for jit

function input.aux.find_file(filename) -- todo : plugin (scanners, checkers etc)
    local instance = input.instance
    local result = { }
    local stamp  = nil
    filename = input.normalize_name(filename)  -- elsewhere
    filename = file.collapse_path(filename:gsub("\\","/")) -- elsewhere
    -- speed up / beware: format problem
    if instance.remember then
        stamp = filename .. "--" .. instance.engine .. "--" .. instance.progname .. "--" .. instance.format
        if instance.found[stamp] then
            if input.trace > 0 then
                input.logger('! remembered: %s',filename)
            end
            return instance.found[stamp]
        end
    end
    if filename:find('%*') then
        if input.trace > 0 then
            input.logger('! wildcard: %s', filename)
        end
        result = input.find_wildcard_files(filename)
    elseif input.aux.qualified_path(filename) then
        if input.is_readable.file(filename) then
            if input.trace > 0 then
                input.logger('! qualified: %s', filename)
            end
            result = { filename }
        else
            local forcedname, ok = "", false
            if file.extname(filename) == "" then
                if instance.format == "" then
                    forcedname = filename .. ".tex"
                    if input.is_readable.file(forcedname) then
                        if input.trace > 0 then
                            input.logger('! no suffix, forcing standard filetype: tex')
                        end
                        result, ok = { forcedname }, true
                    end
                else
                    for _, s in pairs(input.suffixes_of_format(instance.format)) do
                        forcedname = filename .. "." .. s
                        if input.is_readable.file(forcedname) then
                            if input.trace > 0 then
                                input.logger('! no suffix, forcing format filetype: %s', s)
                            end
                            result, ok = { forcedname }, true
                            break
                        end
                    end
                end
            end
            if not ok and input.trace > 0 then
                input.logger('? qualified: %s', filename)
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
                filetype = input.format_of_suffix(forcedname)
                    if input.trace > 0 then
                        input.logger('! forcing filetype: %s',filetype)
                    end
            else
                filetype = input.format_of_suffix(filename)
                if input.trace > 0 then
                    input.logger('! using suffix based filetype: %s',filetype)
                end
            end
        else
            if ext == "" then
                for _, s in pairs(input.suffixes_of_format(instance.format)) do
                    wantedfiles[#wantedfiles+1] = filename .. "." .. s
                end
            end
            filetype = instance.format
            if input.trace > 0 then
                input.logger('! using given filetype: %s',filetype)
            end
        end
        local typespec = input.variable_of_format(filetype)
        local pathlist = input.expanded_path_list(typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if input.trace > 2 then
                input.logger('? filename: %s',filename)
                input.logger('? filetype: %s',filetype or '?')
                input.logger('? wanted files: %s',table.concat(wantedfiles," | "))
            end
            for _, fname in pairs(wantedfiles) do
                if fname and input.is_readable.file(fname) then
                    filename, done = fname, true
                    result[#result+1] = file.join('.',fname)
                    break
                end
            end
            -- this is actually 'other text files' or 'any' or 'whatever'
            local filelist = input.aux.collect_files(wantedfiles)
            local fl = filelist and filelist[1]
            if fl then
                filename = fl[3]
                result[#result+1] = filename
                done = true
            end
        else
            -- list search
            local filelist = input.aux.collect_files(wantedfiles)
            local doscan, recurse
            if input.trace > 2 then
                input.logger('? filename: %s',filename)
            --                if pathlist then input.logger('? path list: %s',table.concat(pathlist," | ")) end
            --                if filelist then input.logger('? file list: %s',table.concat(filelist," | ")) end
            end
            -- a bit messy ... esp the doscan setting here
            for _, path in pairs(pathlist) do
                if path:find("^!!") then doscan  = false else doscan  = true  end
                if path:find("//$") then recurse = true  else recurse = false end
                local pathname = path:gsub("^!+", '')
                done = false
                -- using file list
                if filelist and not (done and not instance.allresults) and recurse then
                    -- compare list entries with permitted pattern
                    pathname = pathname:gsub("([%-%.])","%%%1") -- this also influences
                    pathname = pathname:gsub("/+$", '/.*')      -- later usage of pathname
                    pathname = pathname:gsub("//", '/.-/')      -- not ok for /// but harmless
                    local expr = "^" .. pathname
                    -- input.debug('?',expr)
                    for _, fl in ipairs(filelist) do
                        local f = fl[2]
                        if f:find(expr) then
                            -- input.debug('T',' '..f)
                            if input.trace > 2 then
                                input.logger('= found in hash: %s',f)
                            end
                            --- todo, test for readable
                            result[#result+1] = fl[3]
                            input.aux.register_in_trees(f) -- for tracing used files
                            done = true
                            if not instance.allresults then break end
                        else
                            -- input.debug('F',' '..f)
                        end
                    end
                end
                if not done and doscan then
                    -- check if on disk / unchecked / does not work at all / also zips
                    if input.method_is_file(pathname) then -- ?
                        local pname = pathname:gsub("%.%*$",'')
                        if not pname:find("%*") then
                            local ppname = pname:gsub("/+$","")
                            if input.aux.can_be_dir(ppname) then
                                for _, w in pairs(wantedfiles) do
                                    local fname = file.join(ppname,w)
                                    if input.is_readable.file(fname) then
                                        if input.trace > 2 then
                                            input.logger('= found by scanning: %s',fname)
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
    for k,v in pairs(result) do
        result[k] = file.collapse_path(v)
    end
    if instance.remember then
        instance.found[stamp] = result
    end
    return result
end

input.aux._find_file_ = input.aux.find_file -- frozen variant

function input.aux.find_file(filename) -- maybe make a lowres cache too
    local result = input.aux._find_file_(filename)
    if #result == 0 then
        local lowered = filename:lower()
        if filename ~= lowered then
            return input.aux._find_file_(lowered)
        end
    end
    return result
end

function input.aux.can_be_dir(name)
    local instance = input.instance
    if not instance.fakepaths[name] then
        if lfs.isdir(name) then
            instance.fakepaths[name] = 1 -- directory
        else
            instance.fakepaths[name] = 2 -- no directory
        end
    end
    return (instance.fakepaths[name] == 1)
end

if not input.concatinators  then input.concatinators = { } end

input.concatinators.tex  = file.join
input.concatinators.file = input.concatinators.tex

function input.find_files(filename,filetype,mustexist)
    local instance = input.instance
    if type(mustexist) == boolean then
        -- all set
    elseif type(filetype) == 'boolean' then
        filetype, mustexist = nil, false
    elseif type(filetype) ~= 'string' then
        filetype, mustexist = nil, false
    end
    instance.format = filetype or ''
    local t = input.aux.find_file(filename,true)
    instance.format = ''
    return t
end

function input.find_file(filename,filetype,mustexist)
    return (input.find_files(filename,filetype,mustexist)[1] or "")
end

function input.find_given_files(filename)
    local instance = input.instance
    local bname, result = file.basename(filename), { }
    for k, hash in ipairs(instance.hashes) do
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
                result[#result+1] = input.concatinators[hash.type](hash.tag,blist,bname) or ""
                if not instance.allresults then break end
            else
                for kk,vv in pairs(blist) do
                    result[#result+1] = input.concatinators[hash.type](hash.tag,vv,bname) or ""
                    if not instance.allresults then break end
                end
            end
        end
    end
    return result
end

function input.find_given_file(filename)
    return (input.find_given_files(filename)[1] or "")
end

function input.find_wildcard_files(filename) -- todo: remap:
    local instance = input.instance
    local result = { }
    local bname, dname = file.basename(filename), file.dirname(filename)
    local path = dname:gsub("^*/","")
    path = path:gsub("*",".*")
    path = path:gsub("-","%%-")
    if dname == "" then
        path = ".*"
    end
    local name = bname
    name = name:gsub("*",".*")
    name = name:gsub("-","%%-")
    path = path:lower()
    name = name:lower()
    local function doit(blist,bname,hash,allresults)
        local done = false
        if blist then
            if type(blist) == 'string' then
                -- make function and share code
                if (blist:lower()):find(path) then
                    result[#result+1] = input.concatinators[hash.type](hash.tag,blist,bname) or ""
                    done = true
                end
            else
                for kk,vv in pairs(blist) do
                    if (vv:lower()):find(path) then
                        result[#result+1] = input.concatinators[hash.type](hash.tag,vv,bname) or ""
                        done = true
                        if not allresults then break end
                    end
                end
            end
        end
        return done
    end
    local files, allresults, done = instance.files, instance.allresults, false
    if name:find("%*") then
        for k, hash in ipairs(instance.hashes) do
            for kk, hh in pairs(files[hash.tag]) do
                if not kk:find("^remap:") then
                    if (kk:lower()):find(name) then
                        if doit(hh,kk,hash,allresults) then done = true end
                        if done and not allresults then break end
                    end
                end
            end
        end
    else
        for k, hash in ipairs(instance.hashes) do
            if doit(files[hash.tag][bname],bname,hash,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    return result
end

function input.find_wildcard_file(filename)
    return (input.find_wildcard_files(filename)[1] or "")
end

-- main user functions

function input.save_used_files_in_trees(filename,jobname)
    local instance = input.instance
    if not filename then filename = 'luatex.jlg' end
    local f = io.open(filename,'w')
    if f then
        f:write("<?xml version='1.0' standalone='yes'?>\n")
        f:write("<rl:job>\n")
        if jobname then
            f:write("\t<rl:name>" .. jobname .. "</rl:name>\n")
        end
        f:write("\t<rl:files>\n")
        for _,v in pairs(table.sortedkeys(instance.foundintrees)) do
            f:write("\t\t<rl:file n='" .. instance.foundintrees[v] .. "'>" .. v .. "</rl:file>\n")
        end
        f:write("\t</rl:files>\n")
        f:write("</rl:usedfiles>\n")
        f:close()
    end
end

function input.automount()
    -- implemented later
end

function input.load()
    input.starttiming(input.instance)
    input.resetconfig()
    input.identify_cnf()
    input.load_lua()
    input.expand_variables()
    input.load_cnf()
    input.expand_variables()
    input.load_hash()
    input.automount()
    input.stoptiming(input.instance)
end

function input.for_files(command, files, filetype, mustexist)
    if files and #files > 0 then
        local function report(str)
            if input.verbose then
                input.report(str) -- has already verbose
            else
                print(str)
            end
        end
        if input.verbose then
            report('')
        end
        for _, file in pairs(files) do
            local result = command(file,filetype,mustexist)
            if type(result) == 'string' then
                report(result)
            else
                for _,v in pairs(result) do
                    report(v)
                end
            end
        end
    end
end

-- strtab

input.var_value  = input.variable   -- output the value of variable $STRING.
input.expand_var = input.expansion  -- output variable expansion of STRING.

function input.show_path(str)     -- output search path for file type NAME
    return file.join_path(input.expanded_path_list(input.format_of_var(str)))
end

-- input.find_file(filename)
-- input.find_file(filename, filetype, mustexist)
-- input.find_file(filename, mustexist)
-- input.find_file(filename, filetype)

function input.aux.register_file(files, name, path)
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

if not input.finders  then input.finders  = { } end
if not input.openers  then input.openers  = { } end
if not input.loaders  then input.loaders  = { } end

input.finders.notfound  = { nil }
input.openers.notfound  = { nil }
input.loaders.notfound  = { false, nil, 0 }

function input.splitmethod(filename)
    if not filename then
        return { } -- safeguard
    elseif type(filename) == "table" then
        return filename -- already split
    elseif not filename:find("://") then
        return { scheme="file", path = filename, original=filename } -- quick hack
    else
        return url.hashed(filename)
    end
end

function input.method_is_file(filename)
    return input.splitmethod(filename).scheme == 'file'
end

function table.sequenced(t,sep) -- temp here
    local s = { }
    for k, v in pairs(t) do
        s[#s+1] = k .. "=" .. v
    end
    return table.concat(s, sep or " | ")
end

function input.methodhandler(what, filename, filetype) -- ...
    local specification = (type(filename) == "string" and input.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    if input[what][scheme] then
        if input.trace > 0 then
            input.logger('= handler: %s -> %s -> %s',specification.original,what,table.sequenced(specification))
        end
        return input[what][scheme](filename,filetype) -- todo: specification
    else
        return input[what].tex(filename,filetype) -- todo: specification
    end
end

-- also inside next test?

function input.findtexfile(filename, filetype)
    return input.methodhandler('finders',input.normalize_name(filename), filetype)
end
function input.opentexfile(filename)
    return input.methodhandler('openers',input.normalize_name(filename))
end

function input.findbinfile(filename, filetype)
    return input.methodhandler('finders',input.normalize_name(filename), filetype)
end
function input.openbinfile(filename)
    return input.methodhandler('loaders',input.normalize_name(filename))
end

function input.loadbinfile(filename, filetype)
    local fname = input.findbinfile(input.normalize_name(filename), filetype)
    if fname and fname ~= "" then
        return input.openbinfile(fname)
    else
        return unpack(input.loaders.notfound)
    end
end

function input.texdatablob(filename, filetype)
    local ok, data, size = input.loadbinfile(filename, filetype)
    return data or ""
end

input.loadtexfile = input.texdatablob

function input.openfile(filename)
    local fullname = input.findtexfile(filename)
    if fullname and (fullname ~= "") then
        return input.opentexfile(fullname)
    else
        return nil
    end
end

function input.logmode()
    return (os.getenv("MTX.LOG.MODE") or os.getenv("MTX_LOG_MODE") or "tex"):lower()
end

-- this is a prelude to engine/progname specific configuration files
-- in which case we can omit files meant for other programs and
-- packages

--- ctx

-- maybe texinputs + font paths
-- maybe positive selection tex/context fonts/tfm|afm|vf|opentype|type1|map|enc

input.validators            = { }
input.validators.visibility = { }

function input.validators.visibility.default(path, name)
    return true
end

function input.validators.visibility.context(path, name)
    path = path[1] or path -- some day a loop
    return not (
        path:find("latex")    or
--      path:find("doc")      or
        path:find("tex4ht")   or
        path:find("source")   or
--      path:find("config")   or
--      path:find("metafont") or
        path:find("lists$")   or
        name:find("%.tpm$")   or
        name:find("%.bak$")
    )
end

-- todo: describe which functions are public (maybe input.private. ... )

-- beware: i need to check where we still need a / on windows:

function input.clean_path(str)
    if str then
        str = str:gsub("\\","/")
        str = str:gsub("^!+","")
        str = str:gsub("^~",input.homedir)
        return str
    else
        return nil
    end
end

function input.do_with_path(name,func)
    for _, v in pairs(input.expanded_path_list(name)) do
        func("^"..input.clean_path(v))
    end
end

function input.do_with_var(name,func)
    func(input.aux.expanded_var(name))
end

function input.with_files(pattern,handle)
    local instance = input.instance
    for _, hash in ipairs(instance.hashes) do
        local blobpath = hash.tag
        local blobtype = hash.type
        if blobpath then
            local files = instance.files[blobpath]
            if files then
                for k,v in pairs(files) do
                    if k:find("^remap:") then
                        k = files[k]
                        v = files[k] -- chained
                    end
                    if k:find(pattern) then
                        if type(v) == "string" then
                            handle(blobtype,blobpath,v,k)
                        else
                            for _,vv in pairs(v) do
                                handle(blobtype,blobpath,vv,k)
                            end
                        end
                    end
                end
            end
        end
    end
end

function input.update_script(oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = input.clean_path(oldname)
    input.report("to be replaced old script %s", oldscript)
    local newscripts = input.find_files(newname) or { }
    if #newscripts == 0 then
        input.report("unable to locate new script")
    else
        for _, newscript in ipairs(newscripts) do
            newscript = input.clean_path(newscript)
            input.report("checking new script %s", newscript)
            if oldscript == newscript then
                input.report("old and new script are the same")
            elseif not newscript:find(scriptpath) then
                input.report("new script should come from %s",scriptpath)
            elseif not (oldscript:find(file.removesuffix(newname).."$") or oldscript:find(newname.."$")) then
                input.report("invalid new script name")
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    input.report("old script content replaced by new content")
                    io.savedata(oldscript,newdata)
                    break
                else
                    input.report("unable to load new script")
                end
            end
        end
    end
end


--~ print(table.serialize(input.aux.splitpathexpr("/usr/share/texmf-{texlive,tetex}", {})))

-- command line resolver:

--~ print(input.resolve("abc env:tmp file:cont-en.tex path:cont-en.tex full:cont-en.tex rel:zapf/one/p-chars.tex"))

do

    local resolvers = { }

    resolvers.environment = function(str)
        return input.clean_path(os.getenv(str) or os.getenv(str:upper()) or os.getenv(str:lower()) or "")
    end
    resolvers.relative = function(str,n)
        if io.exists(str) then
            -- nothing
        elseif io.exists("./" .. str) then
            str = "./" .. str
        else
            local p = "../"
            for i=1,n or 2 do
                if io.exists(p .. str) then
                    str = p .. str
                    break
                else
                    p = p .. "../"
                end
            end
        end
        return input.clean_path(str)
    end
    resolvers.locate = function(str)
        local fullname = input.find_given_file(str) or ""
        return input.clean_path((fullname ~= "" and fullname) or str)
    end
    resolvers.filename = function(str)
        local fullname = input.find_given_file(str) or ""
        return input.clean_path(file.basename((fullname ~= "" and fullname) or str))
    end
    resolvers.pathname = function(str)
        local fullname = input.find_given_file(str) or ""
        return input.clean_path(file.dirname((fullname ~= "" and fullname) or str))
    end

    resolvers.env  = resolvers.environment
    resolvers.rel  = resolvers.relative
    resolvers.loc  = resolvers.locate
    resolvers.kpse = resolvers.locate
    resolvers.full = resolvers.locate
    resolvers.file = resolvers.filename
    resolvers.path = resolvers.pathname

    local function resolve(str)
        if type(str) == "table" then
            for k, v in pairs(str) do
                str[k] = resolve(v) or v
            end
        elseif str and str ~= "" then
            str = str:gsub("([a-z]+):([^ ]*)", function(method,target)
                if resolvers[method] then
                    return resolvers[method](target)
                else
                    return method .. ":" .. target
                end
            end)
        end
        return str
    end

    if os.uname then
        for k, v in pairs(os.uname()) do
            if not resolvers[k] then
                resolvers[k] = function() return v end
            end
        end
    end

    input.resolve = resolve

end

function input.boolean_variable(str,default)
    local b = input.expansion(str)
    if b == "" then
        return default
    else
        b = toboolean(b)
        return (b == nil and default) or b
    end
end
