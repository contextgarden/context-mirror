if not modules then modules = { } end modules ['luat-tmp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module deals with caching data. It sets up the paths and
implements loaders and savers for tables. Best is to set the
following variable. When not set, the usual paths will be
checked. Personally I prefer the (users) temporary path.</p>

</code>
TEXMFCACHE=$TMP;$TEMP;$TMPDIR;$TEMPDIR;$HOME;$TEXMFVAR;$VARTEXMF;.
</code>

<p>Currently we do no locking when we write files. This is no real
problem because most caching involves fonts and the chance of them
being written at the same time is small. We also need to extend
luatools with a recache feature.</p>
--ldx]]--

caches = caches or { }
dir    = dir    or { }
texmf  = texmf  or { }

caches.path   = caches.path or nil
caches.base   = caches.base or "luatex-cache"
caches.more   = caches.more or "context"
caches.direct = false -- true is faster but may need huge amounts of memory
caches.trace  = false
caches.tree   = false
caches.paths  = caches.paths or nil
caches.force  = false

input.usecache = not toboolean(os.getenv("TEXMFSHARECACHE") or "false",true) -- true

function caches.temp(instance)
    local function checkpath(cachepath)
        if not cachepath or cachepath == "" then
            return nil
        elseif lfs.attributes(cachepath,"mode") == "directory" then -- lfs.isdir(cachepath) then
            return cachepath
        elseif caches.force or io.ask(string.format("Should I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
            dir.mkdirs(cachepath)
            return (lfs.attributes(cachepath,"mode") == "directory") and cachepath
        else
            return nil
        end
    end
    local cachepath = input.expanded_path_list(instance,"TEXMFCACHE")
    cachepath = cachepath and #cachepath > 0 and checkpath(cachepath[1])
    if not cachepath then
        cachepath = os.getenv("TEXMFCACHE") or os.getenv("HOME") or os.getenv("HOMEPATH") or os.getenv("TMP") or os.getenv("TEMP") or os.getenv("TMPDIR") or nil
        cachepath = checkpath(cachepath)
    end
    if not cachepath then
        print("\nfatal error: there is no valid cache path defined\n")
        os.exit()
    elseif lfs.attributes(cachepath,"mode") ~= "directory" then
        print(string.format("\nfatal error: cache path %s is not a directory\n",cachepath))
        os.exit()
    end
    function caches.temp(instance)
        return cachepath
    end
    return cachepath
end

function caches.configpath(instance)
    return table.concat(instance.cnffiles,";")
end

function caches.hashed(tree)
    return md5.hex((tree:lower()):gsub("[\\\/]+","/"))
end

function caches.treehash(instance)
    local tree = caches.configpath(instance)
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

function caches.setpath(instance,...)
    if not caches.path then
        if not caches.path then
            caches.path = caches.temp(instance)
        end
        caches.path = input.clean_path(caches.path) -- to be sure
        if lfs then
            caches.tree = caches.tree or caches.treehash(instance)
            if caches.tree then
                caches.path = dir.mkdirs(caches.path,caches.base,caches.more,caches.tree)
            else
                caches.path = dir.mkdirs(caches.path,caches.base,caches.more)
            end
        end
    end
    if not caches.path then
        caches.path = '.'
    end
    caches.path = input.clean_path(caches.path)
    if lfs and not table.is_empty({...}) then
        local pth = dir.mkdirs(caches.path,...)
        return pth
    end
    caches.path = dir.expand_name(caches.path)
    return caches.path
end

function caches.definepath(instance,category,subcategory)
    return function()
        return caches.setpath(instance,category,subcategory)
    end
end

function caches.setluanames(path,name)
    return path .. "/" .. name .. ".tma", path .. "/" .. name .. ".tmc"
end

function caches.loaddata(path,name)
    local tmaname, tmcname = caches.setluanames(path,name)
    local loader = loadfile(tmcname) or loadfile(tmaname)
    if loader then
        return loader()
    else
        return false
    end
end

function caches.is_writable(filepath,filename)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    return file.is_writable(tmaname)
end

function caches.savedata(filepath,filename,data,raw) -- raw needed for file cache
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    local reduce, simplify = true, true
    if raw then
        reduce, simplify = false, false
    end
    if caches.direct then
        file.savedata(tmaname, table.serialize(data,'return',true,true))
    else
        table.tofile(tmaname, data,'return',true,true) -- maybe not the last true
    end
    utils.lua.compile(tmaname, tmcname, input.expand_var(texmf.instance,'PURGECACHE') == 't')
end

-- here we use the cache for format loading (texconfig.[formatname|jobname])

--~ if tex and texconfig and texconfig.formatname and texconfig.formatname == "" then
if tex and texconfig and (not texconfig.formatname or texconfig.formatname == "") and texmf.instance then
    if not texconfig.luaname then texconfig.luaname = "cont-en.lua" end -- or luc
    texconfig.formatname = caches.setpath(texmf.instance,"formats") .. "/" .. texconfig.luaname:gsub("%.lu.$",".fmt")
end

--[[ldx--
<p>Once we found ourselves defining similar cache constructs
several times, containers were introduced. Containers are used
to collect tables in memory and reuse them when possible based
on (unique) hashes (to be provided by the calling function).</p>

<p>Caching to disk is disabled by default. Version numbers are
stored in the saved table which makes it possible to change the
table structures without bothering about the disk cache.</p>

<p>Examples of usage can be found in the font related code.</p>
--ldx]]--

containers       = { }
containers.trace = false

do -- local report

    local function report(container,tag,name)
        if caches.trace or containers.trace or container.trace then
            logs.report(string.format("%s cache",container.subcategory),string.format("%s: %s",tag,name or 'invalid'))
        end
    end

    local allocated = { }

    -- tracing

    function containers.define(category, subcategory, version, enabled)
        return function()
            if category and subcategory then
                local c = allocated[category]
                if not c then
                    c  = { }
                    allocated[category] = c
                end
                local s = c[subcategory]
                if not s then
                    s = {
                        category = category,
                        subcategory = subcategory,
                        storage = { },
                        enabled = enabled,
                        version = version or 1.000,
                        trace = false,
                        path = caches.setpath(texmf.instance,category,subcategory),
                    }
                    c[subcategory] = s
                end
                return s
            else
                return nil
            end
        end
    end

    function containers.is_usable(container, name)
        return container.enabled and caches.is_writable(container.path, name)
    end

    function containers.is_valid(container, name)
        if name and name ~= "" then
            local storage = container.storage[name]
            return storage and not table.is_empty(storage) and storage.cache_version == container.version
        else
            return false
        end
    end

    function containers.read(container,name)
        if container.enabled and not container.storage[name] then
            container.storage[name] = caches.loaddata(container.path,name)
            if containers.is_valid(container,name) then
                report(container,"loaded",name)
            else
                container.storage[name] = nil
            end
        end
        if container.storage[name] then
            report(container,"reusing",name)
        end
        return container.storage[name]
    end

    function containers.write(container, name, data)
        if data then
            data.cache_version = container.version
            if container.enabled then
                local unique, shared = data.unique, data.shared
                data.unique, data.shared = nil, nil
                caches.savedata(container.path, name, data)
                report(container,"saved",name)
                data.unique, data.shared = unique, shared
            end
            report(container,"stored",name)
            container.storage[name] = data
        end
        return data
    end

    function containers.content(container,name)
        return container.storage[name]
    end

end

-- since we want to use the cache instead of the tree, we will now
-- reimplement the saver.

local save_data = input.aux.save_data

input.cachepath = nil

function input.aux.save_data(instance, dataname, check)
    input.cachepath = input.cachepath or caches.definepath(instance,"trees")
    save_data(instance, dataname, check, function(cachename,dataname)
        if input.usecache then
            return file.join(input.cachepath(),caches.hashed(cachename))
        else
            return file.join(cachename,dataname)
        end
    end)
end

local load_data = input.aux.load_data

function input.aux.load_data(instance,pathname,dataname,filename)
    input.cachepath = input.cachepath or caches.definepath(instance,"trees")
    load_data(instance,pathname,dataname,filename,function(dataname,filename)
        if input.usecache then
            return file.join(input.cachepath(),caches.hashed(pathname))
        else
            if not filename or (filename == "") then
                filename = dataname
            end
            return file.join(pathname,filename)
        end
    end)
end

-- we will make a better format, maybe something xml or just text or lua

input.automounted = input.automounted or { }

function input.automount(instance,usecache)
    local mountpaths = input.simplified_list(input.expansion(instance,'TEXMFMOUNT'))
    if table.is_empty(mountpaths) and usecache then
        mountpaths = { caches.setpath(instance,"mount") }
    end
    if not table.is_empty(mountpaths) then
        input.starttiming(instance)
        for k, root in pairs(mountpaths) do
            local f = io.open(root.."/url.tmi")
            if f then
                for line in f:lines() do
                    if line then
                        if line:find("^[%%#%-]") then -- or %W
                            -- skip
                        elseif line:find("^zip://") then
                            input.report("mounting",line)
                            table.insert(input.automounted,line)
                            input.usezipfile(instance,line)
                        end
                    end
                end
                f:close()
            end
        end
        input.stoptiming(instance)
    end
end

-- store info in format

input.storage            = { }
input.storage.data       = { }
input.storage.min        = 0 -- 500
input.storage.max        = input.storage.min - 1
input.storage.trace      = false -- true
input.storage.done       = 0
input.storage.evaluators = { }
-- (evaluate,message,names)

function input.storage.register(...)
    input.storage.data[#input.storage.data+1] = { ... }
end

function input.storage.evaluate(name)
    input.storage.evaluators[#input.storage.evaluators+1] = name
end

function input.storage.finalize() -- we can prepend the string with "evaluate:"
    for _, t in ipairs(input.storage.evaluators) do
        for i, v in pairs(t) do
            if type(v) == "string" then
                t[i] = loadstring(v)()
            elseif type(v) == "table" then
                for _, vv in pairs(v) do
                    if type(vv) == "string" then
                        t[i] = loadstring(vv)()
                    end
                end
            end
        end
    end
end

function input.storage.dump()
    for name, data in ipairs(input.storage.data) do
        local evaluate, message, original, target = data[1], data[2], data[3] ,data[4]
        local name, initialize, finalize, code = nil, "", "", ""
        for str in target:gmatch("([^%.]+)") do
            if name then
                name = name .. "." .. str
            else
                name = str
            end
            initialize = string.format("%s %s = %s or {} ", initialize, name, name)
        end
        if evaluate then
            finalize = "input.storage.evaluate(" .. name .. ")"
        end
        input.storage.max = input.storage.max + 1
        if input.storage.trace then
            logs.report('storage',string.format('saving %s in slot %s',message,input.storage.max))
            code =
                initialize ..
                string.format("logs.report('storage','restoring %s from slot %s') ",message,input.storage.max) ..
                table.serialize(original,name) ..
                finalize
        else
            code = initialize .. table.serialize(original,name) .. finalize
        end
        lua.bytecode[input.storage.max] = loadstring(code)
    end
end

if lua.bytecode then -- from 0 upwards
    local i = input.storage.min
    while lua.bytecode[i] do
        lua.bytecode[i]()
        lua.bytecode[i] = nil
        i = i + 1
    end
    input.storage.done = i
end
