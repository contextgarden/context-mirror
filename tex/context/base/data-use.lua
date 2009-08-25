if not modules then modules = { } end modules ['data-use'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_verbose    = false  trackers.register("resolvers.verbose",    function(v) trace_verbose    = v end)
local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v trackers.enable("resolvers.verbose") end)

-- since we want to use the cache instead of the tree, we will now
-- reimplement the saver.

local save_data = resolvers.save_data
local load_data = resolvers.load_data

resolvers.cachepath = nil  -- public, for tracing
resolvers.usecache  = true -- public, for tracing

function resolvers.save_data(dataname)
    save_data(dataname, function(cachename,dataname)
        resolvers.usecache = not toboolean(resolvers.expansion("CACHEINTDS") or "false",true)
        if resolvers.usecache then
            resolvers.cachepath = resolvers.cachepath or caches.definepath("trees")
            return file.join(resolvers.cachepath(),caches.hashed(cachename))
        else
            return file.join(cachename,dataname)
        end
    end)
end

function resolvers.load_data(pathname,dataname,filename)
    load_data(pathname,dataname,filename,function(dataname,filename)
        resolvers.usecache = not toboolean(resolvers.expansion("CACHEINTDS") or "false",true)
        if resolvers.usecache then
            resolvers.cachepath = resolvers.cachepath or caches.definepath("trees")
            return file.join(resolvers.cachepath(),caches.hashed(pathname))
        else
            if not filename or (filename == "") then
                filename = dataname
            end
            return file.join(pathname,filename)
        end
    end)
end

-- we will make a better format, maybe something xml or just text or lua

resolvers.automounted = resolvers.automounted or { }

function resolvers.automount(usecache)
    local mountpaths = resolvers.clean_path_list(resolvers.expansion('TEXMFMOUNT'))
    if table.is_empty(mountpaths) and usecache then
        mountpaths = { caches.setpath("mount") }
    end
    if not table.is_empty(mountpaths) then
        statistics.starttiming(resolvers.instance)
        for k, root in pairs(mountpaths) do
            local f = io.open(root.."/url.tmi")
            if f then
                for line in f:lines() do
                    if line then
                        if line:find("^[%%#%-]") then -- or %W
                            -- skip
                        elseif line:find("^zip://") then
                            if trace_locating then
                                logs.report("fileio","mounting %s",line)
                            end
                            table.insert(resolvers.automounted,line)
                            resolvers.usezipfile(line)
                        end
                    end
                end
                f:close()
            end
        end
        statistics.stoptiming(resolvers.instance)
    end
end

-- status info

statistics.register("used config path", function() return caches.configpath()  end)
statistics.register("used cache path",  function() return caches.temp() or "?" end)

-- experiment (code will move)

function statistics.save_fmt_status(texname,formatbanner,sourcefile) -- texname == formatname
    local enginebanner = status.list().banner
    if formatbanner and enginebanner and sourcefile then
        local luvname = file.replacesuffix(texname,"luv")
        local luvdata = {
            enginebanner = enginebanner,
            formatbanner = formatbanner,
            sourcehash   = md5.hex(io.loaddata(resolvers.find_file(sourcefile)) or "unknown"),
            sourcefile   = sourcefile,
        }
        io.savedata(luvname,table.serialize(luvdata,true))
    end
end

function statistics.check_fmt_status(texname)
    local enginebanner = status.list().banner
    if enginebanner and texname then
        local luvname = file.replacesuffix(texname,"luv")
        if lfs.isfile(luvname) then
            local luv = dofile(luvname)
            if luv and luv.sourcefile then
                local sourcehash = md5.hex(io.loaddata(resolvers.find_file(luv.sourcefile)) or "unknown")
                if luv.enginebanner and luv.enginebanner ~= enginebanner then
                    return "engine mismatch"
                end
                if luv.sourcehash and luv.sourcehash ~= sourcehash then
                    return "source mismatch"
                end
            else
                return "invalid status file"
            end
        else
            return "missing status file"
        end
    end
    return true
end
