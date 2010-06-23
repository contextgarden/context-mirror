if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.100,
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

local format, lower, gsub, concat = string.format, string.lower, string.gsub, table.concat
local mkdirs, isdir = dir.mkdirs, lfs.isdir

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)
local trace_cache    = false  trackers.register("resolvers.cache",    function(v) trace_cache    = v end)

local report_cache = logs.new("cache")

local report_resolvers = logs.new("resolvers")

caches = caches or { }

caches.base      = caches.base or "luatex-cache"
caches.more      = caches.more or "context"
caches.direct    = false -- true is faster but may need huge amounts of memory
caches.tree      = false
caches.force     = true
caches.ask       = false
caches.defaults  = { "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

local writable, readables, usedreadables = nil, { }, { }

-- we could use a metatable for writable and readable but not yet

local function identify()
    -- Combining the loops makes it messy. First we check the format cache path
    -- and when the last component is not present we try to create it.
    local texmfcaches = resolvers.clean_path_list("TEXMFCACHE")
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            if cachepath ~= "" then
                cachepath = resolvers.clean_path(cachepath)
                cachepath = file.collapse_path(cachepath)
                local valid = isdir(cachepath)
                if valid then
                    if file.isreadable(cachepath) then
                        readables[#readables+1] = cachepath
                        if not writable and file.iswritable(cachepath) then
                            writable = cachepath
                        end
                    end
                elseif not writable and caches.force then
                    local cacheparent = file.dirname(cachepath)
                    if file.iswritable(cacheparent) then
                        if not caches.ask or io.ask(format("\nShould I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
                            mkdirs(cachepath)
                            if isdir(cachepath) and file.iswritable(cachepath) then
                                report_cache("created: %s",cachepath)
                                writable = cachepath
                                readables[#readables+1] = cachepath
                            end
                        end
                    end
                end
            end
        end
    end
    -- As a last resort we check some temporary paths but this time we don't
    -- create them.
    local texmfcaches = caches.defaults
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            cachepath = resolvers.getenv(cachepath)
            if cachepath ~= "" then
                cachepath = resolvers.clean_path(cachepath)
                local valid = isdir(cachepath)
                if valid and file.isreadable(cachepath) then
                    if not writable and file.iswritable(cachepath) then
                        readables[#readables+1] = cachepath
                        writable = cachepath
                        break
                    end
                end
            end
        end
    end
    -- Some extra checking. If we have no writable or readable path then we simply
    -- quit.
    if not writable then
        report_cache("fatal error: there is no valid writable cache path defined")
        os.exit()
    elseif #readables == 0 then
        report_cache("fatal error: there is no valid readable cache path defined")
        os.exit()
    end
    -- why here
    writable = dir.expand_name(resolvers.clean_path(writable)) -- just in case
    -- moved here
    local base, more, tree = caches.base, caches.more, caches.tree or caches.treehash() -- we have only one writable tree
    if tree then
        caches.tree = tree
        writable = mkdirs(writable,base,more,tree)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more,tree)
        end
    else
        writable = mkdirs(writable,base,more)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more)
        end
    end
    -- end
    if trace_cache then
        for i=1,#readables do
            report_cache("using readable path '%s' (order %s)",readables[i],i)
        end
        report_cache("using writable path '%s'",writable)
    end
    identify = function()
        return writable, readables
    end
    return writable, readables
end

function caches.usedpaths()
    local writable, readables = identify()
    if #readables > 1 then
        local result = { }
        for i=1,#readables do
            local readable = readables[i]
            if usedreadables[i] or readable == writable then
                result[#result+1] = format("readable: '%s' (order %s)",readable,i)
            end
        end
        result[#result+1] = format("writable: '%s'",writable)
        return result
    else
        return writable
    end
end

function caches.configfiles()
    return table.concat(resolvers.instance.specification,";")
end

function caches.hashed(tree)
    return md5.hex(gsub(lower(tree),"[\\\/]+","/"))
end

function caches.treehash()
    local tree = caches.configfiles()
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

local r_cache, w_cache = { }, { } -- normally w in in r but who cares

local function getreadablepaths(...) -- we can optimize this as we have at most 2 tags
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = r_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = { }
            for i=1,#readables do
                done[i] = file.join(readables[i],...)
            end
        else
            done = readables
        end
        r_cache[hash] = done
    end
    return done
end

local function getwritablepath(...)
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = w_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = mkdirs(writable,...)
        else
            done = writable
        end
        w_cache[hash] = done
    end
    return done
end

caches.getreadablepaths = getreadablepaths
caches.getwritablepath  = getwritablepath

function caches.getfirstreadablefile(filename,...)
    local rd = getreadablepaths(...)
    for i=1,#rd do
        local path = rd[i]
        local fullname = file.join(path,filename)
        if file.isreadable(fullname) then
            usedreadables[i] = true
            return fullname, path
        end
    end
    return caches.setfirstwritablefile(filename,...)
end

function caches.setfirstwritablefile(filename,...)
    local wr = getwritablepath(...)
    local fullname = file.join(wr,filename)
    return fullname, wr
end

function caches.define(category,subcategory) -- for old times sake
    return function()
        return getwritablepath(category,subcategory)
    end
end

function caches.setluanames(path,name)
    return path .. "/" .. name .. ".tma", path .. "/" .. name .. ".tmc"
end

function caches.loaddata(readables,name)
    if type(readables) == "string" then
        readables = { readables }
    end
    for i=1,#readables do
        local path = readables[i]
        local tmaname, tmcname = caches.setluanames(path,name)
        local loader = loadfile(tmcname) or loadfile(tmaname)
        if loader then
            loader = loader()
            collectgarbage("step")
            return loader
        end
    end
    return false
end

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

-- moved from data-res:

local content_state = { }

function caches.contentstate()
    return content_state or { }
end

function caches.loadcontent(cachename,dataname)
    local name = caches.hashed(cachename)
    local full, path = caches.getfirstreadablefile(name ..".lua","trees")
    local filename = file.join(path,name)
    local blob = loadfile(filename .. ".luc") or loadfile(filename .. ".lua")
    if blob then
        local data = blob()
        if data and data.content and data.type == dataname and data.version == resolvers.cacheversion then
            content_state[#content_state+1] = data.uuid
            if trace_locating then
                report_resolvers("loading '%s' for '%s' from '%s'",dataname,cachename,filename)
            end
            return data.content
        elseif trace_locating then
            report_resolvers("skipping '%s' for '%s' from '%s'",dataname,cachename,filename)
        end
    elseif trace_locating then
        report_resolvers("skipping '%s' for '%s' from '%s'",dataname,cachename,filename)
    end
end

function caches.collapsecontent(content)
    for k, v in next, content do
        if type(v) == "table" and #v == 1 then
            content[k] = v[1]
        end
    end
end

function caches.savecontent(cachename,dataname,content)
    local name = caches.hashed(cachename)
    local full, path = caches.setfirstwritablefile(name ..".lua","trees")
    local filename = file.join(path,name) -- is full
    local luaname, lucname = filename .. ".lua", filename .. ".luc"
    if trace_locating then
        report_resolvers("preparing '%s' for '%s'",dataname,cachename)
    end
    local data = {
        type    = dataname,
        root    = cachename,
        version = resolvers.cacheversion,
        date    = os.date("%Y-%m-%d"),
        time    = os.date("%H:%M:%S"),
        content = content,
        uuid    = os.uuid(),
    }
    local ok = io.savedata(luaname,table.serialize(data,true))
    if ok then
        if trace_locating then
            report_resolvers("category '%s', cachename '%s' saved in '%s'",dataname,cachename,luaname)
        end
        if utils.lua.compile(luaname,lucname,false,true) then -- no cleanup but strip
            if trace_locating then
                report_resolvers("'%s' compiled to '%s'",dataname,lucname)
            end
            return true
        else
            if trace_locating then
                report_resolvers("compiling failed for '%s', deleting file '%s'",dataname,lucname)
            end
            os.remove(lucname)
        end
    elseif trace_locating then
        report_resolvers("unable to save '%s' in '%s' (access error)",dataname,luaname)
    end
end


