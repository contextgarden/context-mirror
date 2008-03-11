-- filename : luat-inp.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- This lib is multi-purpose and can be loaded again later on so that
-- additional functionality becomes available. We will split this
-- module in components when we're done with prototyping.

-- This is the first code I wrote for LuaTeX, so it needs some cleanup.

-- To be considered: hash key lowercase, first entry in table filename
-- (any case), rest paths (so no need for optimization). Or maybe a
-- separate table that matches lowercase names to mixed case when
-- present. In that case the lower() cases can go away. I will do that
-- only when we run into problems with names ... well ... Iwona-Regular.

-- Beware, loading and saving is overloaded in luat-tmp!

-- todo: instances.[hashes,cnffiles,configurations,522] -> ipairs (alles check, sneller)
-- todo: check escaping in find etc, too much, too slow

if not versions    then versions    = { } end versions['luat-inp'] = 1.001
if not environment then environment = { } end
if not file        then file        = { } end

if environment.aleph_mode == nil then environment.aleph_mode = true end -- temp hack

if not input            then input            = { } end
if not input.suffixes   then input.suffixes   = { } end
if not input.formats    then input.formats    = { } end
if not input.aux        then input.aux        = { } end

if not input.suffixmap  then input.suffixmap  = { } end

if not input.locators   then input.locators   = { } end  -- locate databases
if not input.hashers    then input.hashers    = { } end  -- load databases
if not input.generators then input.generators = { } end  -- generate databases
if not input.filters    then input.filters    = { } end  -- conversion filters

input.locators.notfound   = { nil }
input.hashers.notfound    = { nil }
input.generators.notfound = { nil }

input.cacheversion = '1.0.1'
input.banner       = nil
input.verbose      = false
input.debug        = false
input.cnfname      = 'texmf.cnf'
input.lsrname      = 'ls-R'
input.luasuffix    = '.tma'
input.lucsuffix    = '.tmc'

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

function input.checkconfigdata(instance) -- not yet ok, no time for debugging now
    local function fix(varname,default)
        local proname = varname .. "." .. instance.progname or "crap"
        local p = instance.environment[proname]
        local v = instance.environment[varname]
        if not ((p and p ~= "") or (v and v ~= "")) then
            instance.variables[varname] = default -- or environment?
        end
    end
    fix("LUAINPUTS"   , ".;$TEXINPUTS;$TEXMFSCRIPTS")
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

function input.reset()

    local instance = { }

    instance.rootpath        = ''
    instance.treepath        = ''
    instance.progname        = environment.progname or 'context'
    instance.engine          = environment.engine   or 'luatex'
    instance.format          = ''
    instance.environment     = { }
    instance.variables       = { }
    instance.expansions      = { }
    instance.files           = { }
    instance.remap           = { }
    instance.configuration   = { }
    instance.order           = { }
    instance.found           = { }
    instance.foundintrees    = { }
    instance.kpsevars        = { }
    instance.hashes          = { }
    instance.cnffiles        = { }
    instance.lists           = { }
    instance.remember        = true
    instance.diskcache       = true
    instance.renewcache      = false
    instance.scandisk        = true
    instance.cachepath       = nil
    instance.loaderror       = false
    instance.smallcache      = false
    instance.savelists       = true
    instance.cleanuppaths    = true
    instance.allresults      = false
    instance.pattern         = nil    -- lists
    instance.kpseonly        = false  -- lists
    instance.cachefile       = 'tmftools'
    instance.loadtime        = 0
    instance.starttime       = 0
    instance.stoptime        = 0
    instance.validfile       = function(path,name) return true end
    instance.data            = { } -- only for loading
    instance.sortdata        = false
    instance.force_suffixes  = true
    instance.dummy_path_expr = "^!*unset/*$"
    instance.fakepaths       = { }
    instance.lsrmode         = false

    if os.env then
        -- store once, freeze and faster
        for k,v in pairs(os.env) do
            instance.environment[k] = input.bare_variable(v)
        end
    else
        -- we will access os.env frequently
        for k,v in pairs({'HOME','TEXMF','TEXMFCNF','SELFAUTOPARENT'}) do
            local e = os.getenv(v)
            if e then
            --  input.report("setting",v,"to",input.bare_variable(e))
                instance.environment[v] = input.bare_variable(e)
            end
        end
    end

    -- cross referencing

    for k, v in pairs(input.suffixes) do
        for _, vv in pairs(v) do
            if vv then
                input.suffixmap[vv] = k
            end
        end
    end

    return instance

end

function input.reset_hashes(instance)
    instance.lists = { }
    instance.found = { }
end

function input.bare_variable(str)
 -- return string.gsub(string.gsub(string.gsub(str,"%s+$",""),'^"(.+)"$',"%1"),"^'(.+)'$","%1")
    return (str:gsub("\s*([\"\']?)(.+)%1\s*", "%2"))
end

if texio then
    input.log = texio.write_nl
else
    input.log = print
end

function input.simple_logger(kind, name)
    if name and name ~= "" then
        if input.banner then
            input.log(input.banner..kind..": "..name)
        else
            input.log("<<"..kind..": "..name..">>")
        end
    else
        if input.banner then
            input.log(input.banner..kind..": no name")
        else
            input.log("<<"..kind..": no name>>")
        end
    end
end

function input.dummy_logger()
end

function input.settrace(n)
    input.trace = tonumber(n or 0)
    if input.trace > 0 then
        input.logger = input.simple_logger
        input.verbose = true
    else
        input.logger = function() end
    end
end

function input.report(...) -- inefficient
    if input.verbose then
        if input.banner then
            input.log(input.banner .. table.concat({...},' '))
        elseif input.logmode() == 'xml' then
            input.log("<t>"..table.concat({...},' ').."</t>")
        else
            input.log("<<"..table.concat({...},' ')..">>")
        end
    end
end

function input.reportlines(str)
    if type(str) == "string" then
        str = str:split("\n")
    end
    for _,v in pairs(str) do input.report(v) end
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
                    input.report('load time', string.format("%0.3f",loadtime))
                end
                return loadtime
            end
        end
        return 0
    end

end

function input.elapsedtime(instance)
    return string.format("%0.3f",(instance and instance.loadtime) or 0)
end

function input.report_loadtime(instance)
    if instance then
        input.report('total load time', input.elapsedtime(instance))
    end
end

input.loadtime = input.elapsedtime

function input.env(instance,key)
    return instance.environment[key] or input.osenv(instance,key)
end

function input.osenv(instance,key)
    if instance.environment[key] == nil then
        local e = os.getenv(key)
        if e == nil then
            instance.environment[key] = "" -- false
        else
            instance.environment[key] = input.bare_variable(e)
        end
    end
    return instance.environment[key] or ""
end

-- we follow a rather traditional approach:
--
-- (1) texmf.cnf given in TEXMFCNF
-- (2) texmf.cnf searched in TEXMF/web2c
--
-- for the moment we don't expect a configuration file in a zip

function input.identify_cnf(instance)
    if #instance.cnffiles == 0 then
        if instance.treepath ~= "" then
            -- this is a special purpose branch, not really used
            if instance.rootpath ~= "" then
                local t = instance.treepath:splitchr(',')
                for k,v in ipairs(t) do
                    t[k] = file.join(instance.rootpath,v)
                end
                instance.treepath = table.concat(t,',')
            end
            local t = instance.treepath:splitchr(',')
            instance.environment['TEXMF'] = input.bare_variable(instance.treepath)
            instance.environment['TEXMFCNF'] = file.join(t[1] or '.','texmf/web2c')
        end
        if instance.rootpath ~= "" then
            -- this assumes a single path, maybe do an expanded split here too
            instance.environment['TEXMFCNF'] = file.join(instance.rootpath,'texmf/web2c')
            instance.environment['SELFAUTOPARENT'] = instance.rootpath
        end
        if input.env(instance,'TEXMFCNF') ~= "" then
            local t = input.split_path(input.env(instance,'TEXMFCNF'))
            t = input.aux.expanded_path(instance,t)
            input.aux.expand_vars(instance,t)
            for _,v in ipairs(t) do
                table.insert(instance.cnffiles,file.join(v,input.cnfname))
            end
        elseif input.env(instance,'SELFAUTOPARENT') == '.' then
            table.insert(instance.cnffiles,file.join('.',input.cnfname))
        else
            for _,v in ipairs({'texmf-local','texmf'}) do
                table.insert(instance.cnffiles,file.join(input.env(instance,'SELFAUTOPARENT'),v,'web2c',input.cnfname))
            end
        end
    end
end

function input.load_cnf(instance)
    -- instance.cnffiles contain complete names now !
    if #instance.cnffiles == 0 then
        input.report("no cnf files found (TEXMFCNF may not be set/known)")
    else
        instance.rootpath = instance.cnffiles[1]
        for k,fname in ipairs(instance.cnffiles) do
            instance.cnffiles[k] = fname:gsub("\\",'/') -- needed?
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        if instance.lsrmode then
            input.loadconfigdata(instance,instance.cnffiles)
        elseif instance.diskcache and not instance.renewcache then
            input.loadconfig(instance,instance.cnffiles)
            if instance.loaderror then
                input.loadconfigdata(instance,instance.cnffiles)
                input.saveconfig(instance)
            end
        else
            input.loadconfigdata(instance,instance.cnffiles)
            if instance.renewcache then
                input.saveconfig(instance)
            end
        end
        input.aux.collapse_cnf_data(instance)
    end
    input.checkconfigdata(instance)
end

function input.loadconfigdata(instance)
    for _, fname in ipairs(instance.cnffiles) do
        input.aux.load_cnf(instance,fname)
    end
end

if os.env then
    function input.aux.collapse_cnf_data(instance)
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
else
    function input.aux.collapse_cnf_data(instance)
        for _,c in ipairs(instance.order) do
            for k,v in pairs(c) do
                if not instance.variables[k] then
                    local e = os.getenv(k)
                    if e then
                        instance.environment[k] = input.bare_variable(e)
                        instance.variables[k]   = instance.environment[k]
                    else
                        instance.variables[k] = input.bare_variable(v)
                        instance.kpsevars[k]  = true
                    end
                end
            end
        end
    end
end

function input.aux.load_cnf(instance,fname)
    fname = input.clean_path(fname)
    local lname = fname:gsub("%.%a+$",input.luasuffix)
    local f = io.open(lname)
    if f then
        f:close()
        local dname = file.dirname(fname)
        if not instance.configuration[dname] then
            input.aux.load_data(instance,dname,'configuration',file.basename(lname))
            instance.order[#instance.order+1] = instance.configuration[dname]
        end
    else
        f = io.open(fname)
        if f then
            input.report("loading", fname)
            local line, data, n, k, v
            local dname = file.dirname(fname)
            if not instance.configuration[dname] then
                instance.configuration[dname] = { }
                instance.order[#instance.order+1] = instance.configuration[dname]
            end
            local data = instance.configuration[dname]
            while true do
                line = f:read()
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
                        k, v = (line:gsub("%s*%%.*$","")):match("%s*(.-)%s*=%s*(.-)%s*$")
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
            input.report("skipping", fname)
        end
    end
end

-- database loading

function input.load_hash(instance)
    input.locatelists(instance)
    if instance.lsrmode then
        input.loadlists(instance)
    elseif instance.diskcache and not instance.renewcache then
        input.loadfiles(instance)
        if instance.loaderror then
            input.loadlists(instance)
            input.savefiles(instance)
        end
    else
        input.loadlists(instance)
        if instance.renewcache then
            input.savefiles(instance)
        end
    end
end

function input.aux.append_hash(instance,type,tag,name)
    input.logger("= hash append",tag)
    table.insert(instance.hashes, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function input.aux.prepend_hash(instance,type,tag,name)
    input.logger("= hash prepend",tag)
    table.insert(instance.hashes, 1, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function input.aux.extend_texmf_var(instance,specification) -- crap
    if instance.environment['TEXMF'] then
        input.report("extending environment variable TEXMF with", specification)
        instance.environment['TEXMF'] = instance.environment['TEXMF']:gsub("^%{", function()
            return "{" .. specification .. ","
        end)
    elseif instance.variables['TEXMF'] then
        input.report("extending configuration variable TEXMF with", specification)
        instance.variables['TEXMF'] = instance.variables['TEXMF']:gsub("^%{", function()
            return "{" .. specification .. ","
        end)
    else
        input.report("setting configuration variable TEXMF to", specification)
        instance.variables['TEXMF'] = "{" .. specification .. "}"
    end
    if instance.variables['TEXMF']:find("%,") and not instance.variables['TEXMF']:find("^%{") then
        input.report("adding {} to complex TEXMF variable, best do that yourself")
        instance.variables['TEXMF'] = "{" .. instance.variables['TEXMF'] .. "}"
    end
    input.expand_variables(instance)
    input.reset_hashes(instance)
end

-- locators

function input.locatelists(instance)
    for _, path in pairs(input.simplified_list(input.expansion(instance,'TEXMF'))) do
        input.report("locating list of",path)
        input.locatedatabase(instance,input.normalize_name(path))
    end
end

function input.locatedatabase(instance,specification)
    return input.methodhandler('locators', instance, specification)
end

function input.locators.tex(instance,specification)
    if specification and specification ~= '' and lfs.isdir(specification) then
        input.logger('! tex locator', specification..' found')
        input.aux.append_hash(instance,'file',specification,filename)
    else
        input.logger('? tex locator', specification..' not found')
    end
end

-- hashers

function input.hashdatabase(instance,tag,name)
    return input.methodhandler('hashers',instance,tag,name)
end

function input.loadfiles(instance)
    instance.loaderror = false
    instance.files = { }
    if not instance.renewcache then
        for _, hash in ipairs(instance.hashes) do
            input.hashdatabase(instance,hash.tag,hash.name)
            if instance.loaderror then break end
        end
    end
end

function input.hashers.tex(instance,tag,name)
    input.aux.load_data(instance,tag,'files')
end

-- generators:

function input.loadlists(instance)
    for _, hash in ipairs(instance.hashes) do
        input.generatedatabase(instance,hash.tag)
    end
end

function input.generatedatabase(instance,specification)
    return input.methodhandler('generators', instance, specification)
end

do

    local weird = lpeg.anywhere(lpeg.S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

    function input.generators.tex(instance,specification)
        local tag = specification
        if not instance.lsrmode and lfs and lfs.dir then
            input.report("scanning path",specification)
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
                        if mode == "directory" then
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
            input.report(string.format("%s files found on %s directories with %s uppercase remappings",n,m,r))
        else
            local fullname = file.join(specification,input.lsrname)
            local path     = '.'
            local f        = io.open(fullname)
            if f then
                instance.files[tag] = { }
                local files = instance.files[tag]
                local small = instance.smallcache
                input.report("loading lsr file",fullname)
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

end

-- savers, todo

function input.savefiles(instance)
    input.aux.save_data(instance, 'files', function(k,v)
        return instance.validfile(k,v) -- path, name
    end)
end

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

function input.splitconfig(instance)
    for i,c in ipairs(instance.order) do
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
function input.joinconfig(instance)
    for i,c in ipairs(instance.order) do
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
--~ function input.splitexpansions(instance)
--~     for k,v in pairs(instance.expansions) do
--~         local t = file.split_path(v)
--~         if #t >  1 then
--~             instance.expansions[k] = t
--~         end
--~     end
--~ end
function input.splitexpansions(instance)
    for k,v in pairs(instance.expansions) do
        local t, h = { }, { }
        for _,vv in pairs(file.split_path(v)) do
            if vv ~= "" and not h[vv] then
                t[#t+1] = vv
                h[vv] = true
            end
        end
        if #t > 1 then
            instance.expansions[k] = t
        else
            instance.expansions[k] = t[1]
        end
    end
end

-- end of split/join code

function input.saveconfig(instance)
    input.splitconfig(instance)
    input.aux.save_data(instance, 'configuration', nil)
    input.joinconfig(instance)
end

input.configbanner = [[
-- This is a Luatex configuration file created by 'luatools.lua' or
-- 'luatex.exe' directly. For comment, suggestions and questions you can
-- contact the ConTeXt Development Team. This configuration file is
-- not copyrighted. [HH & TH]
]]

function input.aux.save_data(instance, dataname, check)
    for cachename, files in pairs(instance[dataname]) do
        local name = file.join(cachename,dataname)
        local luaname, lucname = name .. input.luasuffix, name .. input.lucsuffix
        local f = io.open(luaname,'w')
        if f then
            input.report("saving " .. dataname .. " in", luaname)
            f:write(input.configbanner)
            f:write("\n")
            f:write("if not texmf      then texmf      = { } end\n")
            f:write("if not texmf.data then texmf.data = { } end\n")
            f:write("\n")
            f:write("texmf.data.type    = '" .. dataname .. "'\n")
            f:write("texmf.data.version = '" .. input.cacheversion .. "'\n")
            f:write("texmf.data.date    = '" .. os.date("%Y-%m-%d") .. "'\n")
            f:write("texmf.data.time    = '" .. os.date("%H:%M:%S") .. "'\n")
            f:write('texmf.data.content = {\n')
            local function dump(k,v)
                if not check or check(v,k) then -- path, name
                    if type(v) == 'string' then
                        f:write("\t['" .. k .. "'] = '" .. v .. "',\n")
                    elseif #v == 1 then
                        f:write("\t['" .. k .. "'] = '" .. v[1] .. "',\n")
                    else
                        f:write("\t['" .. k .. "'] = {'" .. table.concat(v,"','").. "'},\n")
                    end
                end
            end
            if instance.sortdata then
                for _, k in pairs(table.sortedkeys(files)) do
                    dump(k,files[k])
                end
            else
                for k, v in pairs(files) do
                    dump(k,v)
                end
            end
            f:write('}\n')
            f:close()
            input.report("compiling " .. dataname .. " to", lucname)
            if not utils.lua.compile(luaname,lucname) then
                input.report("compiling failed for " .. dataname .. ", deleting file " .. lucname)
                os.remove(lucname)
            end
        else
            input.report("unable to save " .. dataname .. " in " .. name..input.luasuffix)
        end
    end
end

function input.loadconfig(instance)
    instance.configuration, instance.order, instance.loaderror = { }, { }, false
    if not instance.renewcache then
        for _, cnf in ipairs(instance.cnffiles) do
            local dname = file.dirname(cnf)
            input.aux.load_data(instance,dname,'configuration')
            instance.order[#instance.order+1] = instance.configuration[dname]
            if instance.loaderror then break end
        end
    end
    input.joinconfig(instance)
end

if not texmf      then texmf      = {} end
if not texmf.data then texmf.data = {} end

function input.aux.load_data(instance,pathname,dataname,filename)
    if not filename or (filename == "") then
        filename = dataname .. input.lucsuffix
    end
    local blob = loadfile(file.join(pathname,filename))
    if not blob then
        filename = dataname .. input.luasuffix
        blob = loadfile(file.join(pathname,filename))
    end
    if blob then
        blob()
        if (texmf.data.type == dataname) and (texmf.data.version == input.cacheversion) and texmf.data.content then
            input.report("loading",dataname,"for",pathname,"from",filename)
            instance[dataname][pathname] = texmf.data.content
        else
            input.report("skipping",dataname,"for",pathname,"from",filename)
            instance[dataname][pathname] = { }
            instance.loaderror = true
        end
    end
    texmf.data.content = { }
end

function input.expand_variables(instance)
    instance.expansions = { }
    if instance.engine   ~= "" then instance.environment['engine']   = instance.engine end
    if instance.progname ~= "" then instance.environment['progname'] = instance.engine end
    for k,v in pairs(instance.environment) do
        local a, b = k:match("^(%a+)%_(.*)%s*$")
        if a and b then
            instance.expansions[a..'.'..b] = v
        else
            instance.expansions[k] = v
        end
    end
    for k,v in pairs(instance.environment) do -- move environment to expansions
        if not instance.expansions[k] then instance.expansions[k] = v end
    end
    for k,v in pairs(instance.variables) do -- move variables to expansions
        if not instance.expansions[k] then instance.expansions[k] = v end
    end
    while true do
        local busy = false
        for k,v in pairs(instance.expansions) do
            local s, n = v:gsub("%$([%a%d%_%-]+)", function(a)
                busy = true
                return instance.expansions[a] or input.env(instance,a)
            end)
            local s, m = s:gsub("%$%{([%a%d%_%-]+)%}", function(a)
                busy = true
                return instance.expansions[a] or input.env(instance,a)
            end)
            if n > 0 or m > 0 then
                instance.expansions[k]= s
            end
        end
        if not busy then break end
    end
    for k,v in pairs(instance.expansions) do
        instance.expansions[k] = v:gsub("\\", '/')
    end
end

function input.aux.expand_vars(instance,lst) -- simple vars
    for k,v in pairs(lst) do
        lst[k] = v:gsub("%$([%a%d%_%-]+)", function(a)
            return instance.variables[a] or input.env(instance,a)
        end)
    end
end

function input.aux.expanded_var(instance,var) -- simple vars
    return var:gsub("%$([%a%d%_%-]+)", function(a)
        return instance.variables[a] or input.env(instance,a)
    end)
end

function input.aux.entry(instance,entries,name)
    if name and (name ~= "") then
        name = name:gsub('%$','')
        local result = entries[name..'.'..instance.progname] or entries[name]
        if result then
            return result
        else
            result = input.env(instance,name)
            if result then
                instance.variables[name] = result
                input.expand_variables(instance)
                return instance.expansions[name] or ""
            end
        end
    end
    return ""
end
function input.variable(instance,name)
    return input.aux.entry(instance,instance.variables,name)
end
function input.expansion(instance,name)
    return input.aux.entry(instance,instance.expansions,name)
end

function input.aux.is_entry(instance,entries,name)
    if name and name ~= "" then
        name = name:gsub('%$','')
        return (entries[name..'.'..instance.progname] or entries[name]) ~= nil
    else
        return false
    end
end

function input.is_variable(instance,name)
    return input.aux.is_entry(instance,instance.variables,name)
end
function input.is_expansion(instance,name)
    return input.aux.is_entry(instance,instance.expansions,name)
end

function input.aux.list(instance,list)
    local pat = string.upper(instance.pattern or "","")
    for _,key in pairs(table.sortedkeys(list)) do
        if (instance.pattern=="") or string.find(key:upper(),pat) then
            if instance.kpseonly then
                if instance.kpsevars[key] then
                    print(key .. "=" .. input.aux.tabstr(list[key]))
                end
            elseif instance.kpsevars[key] then
                print('K ' .. key .. "=" .. input.aux.tabstr(list[key]))
            else
                print('E ' .. key .. "=" .. input.aux.tabstr(list[key]))
            end
        end
    end
end

function input.list_variables(instance)
    input.aux.list(instance,instance.variables)
end
function input.list_expansions(instance)
    input.aux.list(instance,instance.expansions)
end

function input.list_configurations(instance)
    for _,key in pairs(table.sortedkeys(instance.kpsevars)) do
        if not instance.pattern or (instance.pattern=="") or key:find(instance.pattern) then
            print(key.."\n")
            for i,c in ipairs(instance.order) do
                local str = c[key]
                if str then
                    print("\t" .. i .. "\t\t" .. input.aux.tabstr(str))
                end
            end
            print()
        end
    end
end

function input.aux.tabstr(str)
    if type(str) == 'table' then
        return table.concat(str," | ")
    else
        return str
    end
end

function input.simplified_list(str)
    if type(str) == 'table' then
        return str -- troubles ; ipv , in texmf
    elseif str == '' then
        return { }
    else
        local t = { }
        for _,v in ipairs(string.splitchr(str:gsub("^\{(.+)\}$","%1"),",")) do
            t[#t+1] = (v:gsub("^[%!]*(.+)[%/\\]*$","%1"))
        end
        return t
    end
end

function input.unexpanded_path_list(instance,str)
    local pth = input.variable(instance,str)
    local lst = input.split_path(pth)
    return input.aux.expanded_path(instance,lst)
end
function input.unexpanded_path(instance,str)
    return file.join_path(input.unexpanded_path_list(instance,str))
end

--~ function input.expanded_path_list(instance,str)
--~     if not str then
--~         return { }
--~     elseif instance.savelists then
--~         -- engine+progname hash
--~         str = str:gsub("%$","")
--~         if not instance.lists[str] then -- cached
--~             local lst = input.split_path(input.expansion(instance,str))
--~             instance.lists[str] = input.aux.expanded_path(instance,lst)
--~         end
--~         return instance.lists[str]
--~     else
--~         local lst = input.split_path(input.expansion(instance,str))
--~         return input.aux.expanded_path(instance,lst)
--~     end
--~ end

do
    local done = { }

    function input.reset_extra_path(instance)
        local ep = instance.extra_paths
        if not ep then
            ep, done = { }, { }
            instance.extra_paths = ep
        elseif #ep > 0 then
            instance.lists, done = { }, { }
        end
    end

    function input.register_extra_path(instance,paths,subpaths)
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

function input.expanded_path_list(instance,str)
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
            local lst = made_list(input.split_path(input.expansion(instance,str)))
            instance.lists[str] = input.aux.expanded_path(instance,lst)
        end
        return instance.lists[str]
    else
        local lst = input.split_path(input.expansion(instance,str))
        return made_list(input.aux.expanded_path(instance,lst))
    end
end

function input.expand_path(instance,str)
    return file.join_path(input.expanded_path_list(instance,str))
end

--~ function input.first_writable_path(instance,name)
--~     for _,v in pairs(input.expanded_path_list(instance,name)) do
--~         if file.is_writable(file.join(v,'luatex-cache.tmp')) then
--~             return v
--~         end
--~     end
--~     return "."
--~ end

function input.expanded_path_list_from_var(instance,str) -- brrr
    local tmp = input.var_of_format_or_suffix(str:gsub("%$",""))
    if tmp ~= "" then
        return input.expanded_path_list(instance,str)
    else
        return input.expanded_path_list(instance,tmp)
    end
end
function input.expand_path_from_var(instance,str)
    return file.join_path(input.expanded_path_list_from_var(instance,str))
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

function input.expand_braces(instance,str) -- output variable and brace expansion of STRING
    local ori = input.variable(instance,str)
    local pth = input.aux.expanded_path(instance,input.split_path(ori))
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
    while true do
        local done = false
        while true do
            ok = false
            str = str:gsub("([^{},]+){([^{}]-)}", function(a,b)
                local t = { }
                b:piecewise(",", function(s) t[#t+1] = a .. s end)
                ok, done = true, true
                return "{" .. concat(t,",") .. "}"
            end)
            if not ok then break end
        end
        while true do
            ok = false
            str = str:gsub("{([^{}]-)}([^{},]+)", function(a,b)
                local t = { }
                a:piecewise(",", function(s) t[#t+1] = s .. b end)
                ok, done = true, true
                return "{" .. concat(t,",") .. "}"
            end)
            if not ok then break end
        end
        while true do
            ok = false
            str = str:gsub("([,{]){([^{}]+)}([,}])", function(a,b,c)
                ok, done = true, true
                return a .. b .. c
            end)
            if not ok then break end
        end
        if not done then break end
    end
    while true do
        ok = false
        str = str:gsub("{([^{}]-)}{([^{}]-)}", function(a,b)
            local t = { }
            a:piecewise(",", function(sa)
                b:piecewise(",", function(sb)
                    t[#t+1] = sa .. sb
                end)
            end)
            ok = true
            return "{" .. concat(t,",") .. "}"
        end)
        if not ok then break end
    end
    while true do
        ok = false
        str = str:gsub("{([^{}]-)}", function(a)
            ok = true
            return a
        end)
        if not ok then break end
    end
    if validate then
        str:piecewise(",", function(s)
            s = validate(s)
            if s then t[#t+1] = s end
        end)
    else
        str:piecewise(",", function(s)
            t[#t+1] = s
        end)
    end
    return t
end

function input.aux.expanded_path(instance,pathlist) -- maybe not a list, just a path
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
            input.logger("+ readable", name)
        else
            input.logger("- readable", name)
        end
    end
    return readable
end

function input.is_readable.file(name)
 -- return input.aux.is_readable(file.is_readable(name), name)
    return input.aux.is_readable(input.aux.is_file(name), name)
end

input.is_readable.tex = input.is_readable.file

-- name
-- name/name

function input.aux.collect_files(instance,names)
    local filelist = { }
    for _, fname in pairs(names) do
        if fname then
            if input.trace > 2 then
                input.logger("? blobpath asked",fname)
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
                        input.logger('? blobpath do',blobpath .. " (" .. bname ..")")
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
                    input.logger('! blobpath no',blobpath .. " (" .. bname ..")" )
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

end

function input.aux.register_in_trees(instance,name)
    if not name:find("^%.") then
        instance.foundintrees[name] = (instance.foundintrees[name] or 0) + 1 -- maybe only one
    end
end

-- split the next one up, better for jit

function input.aux.find_file(instance,filename) -- todo : plugin (scanners, checkers etc)
    local result = { }
    local stamp  = nil
    filename = input.normalize_name(filename)  -- elsewhere
    filename = file.collapse_path(filename:gsub("\\","/")) -- elsewhere
    -- speed up / beware: format problem
    if instance.remember then
        stamp = filename .. "--" .. instance.engine .. "--" .. instance.progname .. "--" .. instance.format
        if instance.found[stamp] then
            input.logger('! remembered', filename)
            return instance.found[stamp]
        end
    end
    if filename:find('%*') then
        input.logger('! wildcard', filename)
        result = input.find_wildcard_files(instance,filename)
    elseif input.aux.qualified_path(filename) then
        if input.is_readable.file(filename) then
            input.logger('! qualified', filename)
            result = { filename }
        else
            local forcedname, ok = "", false
            if file.extname(filename) == "" then
                if instance.format == "" then
                    forcedname = filename .. ".tex"
                    if input.is_readable.file(forcedname) then
                        input.logger('! no suffix, forcing standard filetype tex')
                        result, ok = { forcedname }, true
                    end
                else
                    for _, s in pairs(input.suffixes_of_format(instance.format)) do
                        forcedname = filename .. "." .. s
                        if input.is_readable.file(forcedname) then
                            input.logger('! no suffix, forcing format filetype', s)
                            result, ok = { forcedname }, true
                            break
                        end
                    end
                end
            end
            if not ok then
                input.logger('? qualified', filename)
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
                input.logger('! forcing filetype',filetype)
            else
                filetype = input.format_of_suffix(filename)
                input.logger('! using suffix based filetype',filetype)
            end
        else
            if ext == "" then
                for _, s in pairs(input.suffixes_of_format(instance.format)) do
                    wantedfiles[#wantedfiles+1] = filename .. "." .. s
                end
            end
            filetype = instance.format
            input.logger('! using given filetype',filetype)
        end
        local typespec = input.variable_of_format(filetype)
        local pathlist = input.expanded_path_list(instance,typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if input.trace > 2 then
                input.logger('? filename',filename)
                input.logger('? filetype',filetype or '?')
                input.logger('? wanted files',table.concat(wantedfiles," | "))
            end
            for _, fname in pairs(wantedfiles) do
                if fname and input.is_readable.file(fname) then
                    filename, done = fname, true
                    result[#result+1] = file.join('.',fname)
                    break
                end
            end
            -- this is actually 'other text files' or 'any' or 'whatever'
            local filelist = input.aux.collect_files(instance,wantedfiles)
            local fl = filelist and filelist[1]
            if fl then
                filename = fl[3]
                result[#result+1] = filename
                done = true
            end
        else
            -- list search
            local filelist = input.aux.collect_files(instance,wantedfiles)
            local doscan, recurse
            if input.trace > 2 then
                input.logger('? filename',filename)
            --                if pathlist then input.logger('? path list',table.concat(pathlist," | ")) end
            --                if filelist then input.logger('? file list',table.concat(filelist," | ")) end
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
                                input.logger('= found in hash',f)
                            end
                            --- todo, test for readable
                            result[#result+1] = fl[3]
                            input.aux.register_in_trees(instance,f) -- for tracing used files
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
                            if input.aux.can_be_dir(instance,ppname) then
                                for _, w in pairs(wantedfiles) do
                                    local fname = file.join(ppname,w)
                                    if input.is_readable.file(fname) then
                                        if input.trace > 2 then
                                            input.logger('= found by scanning',fname)
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

input.aux._find_file_ = input.aux.find_file

function input.aux.find_file(instance,filename) -- maybe make a lowres cache too
    local result = input.aux._find_file_(instance,filename)
    if #result == 0 then
        local lowered = filename:lower()
        if filename ~= lowered then
            return input.aux._find_file_(instance,lowered)
        end
    end
    return result
end

if lfs and lfs.isfile then
    input.aux.is_file = lfs.isfile      -- to be done: use this
else
    input.aux.is_file = file.is_readable
end

if lfs and lfs.isdir then
    function input.aux.can_be_dir(instance,name)
        if not instance.fakepaths[name] then
            if lfs.isdir(name) then
                instance.fakepaths[name] = 1 -- directory
            else
                instance.fakepaths[name] = 2 -- no directory
            end
        end
        return (instance.fakepaths[name] == 1)
    end
else
    function input.aux.can_be_dir()
        return true
    end
end

if not input.concatinators  then input.concatinators = { } end

input.concatinators.tex  = file.join
input.concatinators.file = input.concatinators.tex

function input.find_files(instance,filename,filetype,mustexist)
    if type(mustexist) == boolean then
        -- all set
    elseif type(filetype) == 'boolean' then
        filetype, mustexist = nil, false
    elseif type(filetype) ~= 'string' then
        filetype, mustexist = nil, false
    end
    instance.format = filetype or ''
    local t = input.aux.find_file(instance,filename,true)
    instance.format = ''
    return t
end

function input.find_file(instance,filename,filetype,mustexist)
    return (input.find_files(instance,filename,filetype,mustexist)[1] or "")
end

function input.find_given_files(instance,filename)
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

function input.find_given_file(instance,filename)
    return (input.find_given_files(instance,filename)[1] or "")
end

function input.find_wildcard_files(instance,filename) -- todo: remap:
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

function input.find_wildcard_file(instance,filename)
    return (input.find_wildcard_files(instance,filename)[1] or "")
end

-- main user functions

function input.save_used_files_in_trees(instance, filename,jobname)
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

function input.automount(instance)
    -- implemented later
end

function input.load(instance)
    input.starttiming(instance)
    input.identify_cnf(instance)
    input.load_cnf(instance)
    input.expand_variables(instance)
    input.load_hash(instance)
    input.automount(instance)
    input.stoptiming(instance)
end

function input.for_files(instance, command, files, filetype, mustexist)
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
            local result = command(instance,file,filetype,mustexist)
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

function input.var_value(instance,str)     -- output the value of variable $STRING.
    return input.variable(instance,str)
end
function input.expand_var(instance,str)    -- output variable expansion of STRING.
    return input.expansion(instance,str)
end
function input.show_path(instance,str)     -- output search path for file type NAME
    return file.join_path(input.expanded_path_list(instance,input.format_of_var(str)))
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

function input.methodhandler(what, instance, filename, filetype) -- ...
    local specification = (type(filename) == "string" and input.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    if input[what][scheme] then
        input.logger('= handler',specification.original .." -> " .. what .. " -> " .. table.sequenced(specification))
        return input[what][scheme](instance,filename,filetype) -- todo: specification
    else
        return input[what].tex(instance,filename,filetype) -- todo: specification
    end
end

-- also inside next test?

function input.findtexfile(instance, filename, filetype)
    return input.methodhandler('finders',instance, input.normalize_name(filename), filetype)
end
function input.opentexfile(instance,filename)
    return input.methodhandler('openers',instance, input.normalize_name(filename))
end

function input.findbinfile(instance, filename, filetype)
    return input.methodhandler('finders',instance, input.normalize_name(filename), filetype)
end
function input.openbinfile(instance,filename)
    return input.methodhandler('loaders',instance, input.normalize_name(filename))
end

function input.loadbinfile(instance, filename, filetype)
    local fname = input.findbinfile(instance, input.normalize_name(filename), filetype)
    if fname and fname ~= "" then
        return input.openbinfile(instance,fname)
    else
        return unpack(input.loaders.notfound)
    end
end

function input.texdatablob(instance, filename, filetype)
    local ok, data, size = input.loadbinfile(instance, filename, filetype)
    return data or ""
end

input.loadtexfile = input.texdatablob

function input.openfile(filename) -- brrr texmf.instance here  / todo ! ! ! ! !
    local fullname = input.findtexfile(texmf.instance, filename)
    if fullname and (fullname ~= "") then
        return input.opentexfile(texmf.instance, fullname)
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
--~     return (((str:gsub("\\","/")):gsub("^!+","")):gsub("//+","//"))
    if str then
        return ((str:gsub("\\","/")):gsub("^!+",""))
    else
        return nil
    end
end

function input.do_with_path(name,func)
    for _, v in pairs(input.expanded_path_list(instance,name)) do
        func("^"..input.clean_path(v))
    end
end

function input.do_with_var(name,func)
    func(input.aux.expanded_var(name))
end

function input.with_files(instance,pattern,handle)
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

--~ function input.update_script(oldname,newname) -- oldname -> own.name, not per se a suffix
--~     newname = file.addsuffix(newname,"lua")
--~     local newscript = input.clean_path(input.find_file(instance, newname))
--~     local oldscript = input.clean_path(oldname)
--~     input.report("old script", oldscript)
--~     input.report("new script", newscript)
--~     if oldscript ~= newscript and (oldscript:find(file.removesuffix(newname).."$") or oldscript:find(newname.."$")) then
--~         local newdata = io.loaddata(newscript)
--~         if newdata then
--~             input.report("old script content replaced by new content")
--~             io.savedata(oldscript,newdata)
--~         end
--~     end
--~ end

function input.update_script(instance,oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = input.clean_path(oldname)
    input.report("to be replaced old script", oldscript)
    local newscripts = input.find_files(instance, newname) or { }
    if #newscripts == 0 then
        input.report("unable to locate new script")
    else
        for _, newscript in ipairs(newscripts) do
            newscript = input.clean_path(newscript)
            input.report("checking new script", newscript)
            if oldscript == newscript then
                input.report("old and new script are the same")
            elseif not newscript:find(scriptpath) then
                input.report("new script should come from",scriptpath)
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

    resolvers.environment = function(instance,str)
        return input.clean_path(os.getenv(str) or os.getenv(str:upper()) or os.getenv(str:lower()) or "")
    end
    resolvers.relative = function(instance,str,n)
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
    resolvers.locate = function(instance,str)
        local fullname = input.find_given_file(instance,str) or ""
        return input.clean_path((fullname ~= "" and fullname) or str)
    end
    resolvers.filename = function(instance,str)
        local fullname = input.find_given_file(instance,str) or ""
        return input.clean_path(file.basename((fullname ~= "" and fullname) or str))
    end
    resolvers.pathname = function(instance,str)
        local fullname = input.find_given_file(instance,str) or ""
        return input.clean_path(file.dirname((fullname ~= "" and fullname) or str))
    end

    resolvers.env  = resolvers.environment
    resolvers.rel  = resolvers.relative
    resolvers.loc  = resolvers.locate
    resolvers.kpse = resolvers.locate
    resolvers.full = resolvers.locate
    resolvers.file = resolvers.filename
    resolvers.path = resolvers.pathname

    function resolve(instance,str)
        if type(str) == "table" then
            for k, v in pairs(str) do
                str[k] = resolve(instance,v) or v
            end
        elseif str and str ~= "" then
            str = str:gsub("([a-z]+):([^ ]+)", function(method,target)
                if resolvers[method] then
                    return resolvers[method](instance,target)
                else
                    return method .. ":" .. target
                end
            end)
        end
        return str
    end

    input.resolve = resolve

end
