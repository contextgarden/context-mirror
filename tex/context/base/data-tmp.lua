if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
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

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache = false  trackers.register("resolvers.cache", function(v) trace_cache = v end) -- not used yet

caches = caches or { }

caches.path     = caches.path or nil
caches.base     = caches.base or "luatex-cache"
caches.more     = caches.more or "context"
caches.direct   = false -- true is faster but may need huge amounts of memory
caches.tree     = false
caches.paths    = caches.paths or nil
caches.force    = false
caches.defaults = { "TEXMFCACHE", "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

function caches.temp()
    local cachepath = nil
    local function check(list,isenv)
        if not cachepath then
            for k=1,#list do
                local v = list[k]
                cachepath = (isenv and (os.env[v] or "")) or v or ""
                if cachepath == "" then
                    -- next
                else
                    cachepath = resolvers.clean_path(cachepath)
                    if lfs.isdir(cachepath) and file.iswritable(cachepath) then -- lfs.attributes(cachepath,"mode") == "directory"
                        break
                    elseif caches.force or io.ask(format("\nShould I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
                        dir.mkdirs(cachepath)
                        if lfs.isdir(cachepath) and file.iswritable(cachepath) then
                            break
                        end
                    end
                end
                cachepath = nil
            end
        end
    end
    check(resolvers.clean_path_list("TEXMFCACHE") or { })
    check(caches.defaults,true)
    if not cachepath then
        print("\nfatal error: there is no valid (writable) cache path defined\n")
        os.exit()
    elseif not lfs.isdir(cachepath) then -- lfs.attributes(cachepath,"mode") ~= "directory"
        print(format("\nfatal error: cache path %s is not a directory\n",cachepath))
        os.exit()
    end
    cachepath = file.collapse_path(cachepath)
    function caches.temp()
        return cachepath
    end
    return cachepath
end

function caches.configpath()
    return table.concat(resolvers.instance.cnffiles,";")
end

function caches.hashed(tree)
    return md5.hex(gsub(lower(tree),"[\\\/]+","/"))
end

function caches.treehash()
    local tree = caches.configpath()
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

function caches.setpath(...)
    if not caches.path then
        if not caches.path then
            caches.path = caches.temp()
        end
        caches.path = resolvers.clean_path(caches.path) -- to be sure
        caches.tree = caches.tree or caches.treehash()
        if caches.tree then
            caches.path = dir.mkdirs(caches.path,caches.base,caches.more,caches.tree)
        else
            caches.path = dir.mkdirs(caches.path,caches.base,caches.more)
        end
    end
    if not caches.path then
        caches.path = '.'
    end
    caches.path = resolvers.clean_path(caches.path)
    if not table.is_empty({...}) then
        local pth = dir.mkdirs(caches.path,...)
        return pth
    end
    caches.path = dir.expand_name(caches.path)
    return caches.path
end

function caches.definepath(category,subcategory)
    return function()
        return caches.setpath(category,subcategory)
    end
end

function caches.setluanames(path,name)
    return path .. "/" .. name .. ".tma", path .. "/" .. name .. ".tmc"
end

function caches.loaddata(path,name)
    local tmaname, tmcname = caches.setluanames(path,name)
    local loader = loadfile(tmcname) or loadfile(tmaname)
    if loader then
        loader = loader()
        collectgarbage("step")
        return loader
    else
        return false
    end
end

--~ function caches.loaddata(path,name)
--~     local tmaname, tmcname = caches.setluanames(path,name)
--~     return dofile(tmcname) or dofile(tmaname)
--~ end

function caches.iswritable(filepath,filename)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    return file.iswritable(tmaname)
end

function caches.savedata(filepath,filename,data,raw)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    local reduce, simplify = true, true
    if raw then
        reduce, simplify = false, false
    end
    data.cache_uuid = os.uuid()
    if caches.direct then
        file.savedata(tmaname, table.serialize(data,'return',false,true,false)) -- no hex
    else
        table.tofile(tmaname, data,'return',false,true,false) -- maybe not the last true
    end
    local cleanup = resolvers.boolean_variable("PURGECACHE", false)
    local strip = resolvers.boolean_variable("LUACSTRIP", true)
    utils.lua.compile(tmaname, tmcname, cleanup, strip)
end

-- here we use the cache for format loading (texconfig.[formatname|jobname])

--~ if tex and texconfig and texconfig.formatname and texconfig.formatname == "" then
if tex and texconfig and (not texconfig.formatname or texconfig.formatname == "") and input and resolvers.instance then
    if not texconfig.luaname then texconfig.luaname = "cont-en.lua" end -- or luc
    texconfig.formatname = caches.setpath("formats") .. "/" .. gsub(texconfig.luaname,"%.lu.$",".fmt")
end
