if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts       = scripts       or { }
scripts.cache = scripts.cache or { }

function scripts.cache.collect_one(...)
    local path = caches.setpath(...)
    local tmas = dir.glob(path .. "/*.tma")
    local tmcs = dir.glob(path .. "/*.tmc")
    return path, tmas, tmcs
end

function scripts.cache.collect_two(...)
    local path = caches.setpath(...)
    local rest = dir.glob(path .. "/**/*")
    return path, rest
end

local suffixes = { "afm", "tfm", "def", "enc", "otf", "mp", "data" }

function scripts.cache.process_one(action)
    for i=1,#suffixes do
        action("fonts", suffixes[i])
    end
end

function scripts.cache.process_two(action)
    action("curl")
end

-- todo: recursive delete of paths

function scripts.cache.remove(list,keep)
    local n, keepsuffixes = 0, table.tohash(keep or { })
    for i=1,#list do
        local filename = list[i]
        if string.find(filename,"luatex%-cache") then -- safeguard
            if not keepsuffixes[file.extname(filename) or ""] then
                os.remove(filename)
                n = n + 1
            end
        end
    end
    return n
end

function scripts.cache.delete(all,keep)
    scripts.cache.process_one(function(...)
        local path, rest = scripts.cache.collect_one(...)
        local n = scripts.cache.remove(rest,keep)
        logs.report("cache path",string.format("%4i files out of %4i deleted on %s",n,#rest,path))
    end)
    scripts.cache.process_two(function(...)
        local path, rest = scripts.cache.collect_two(...)
        local n = scripts.cache.remove(rest,keep)
        logs.report("cache path",string.format("%4i files out of %4i deleted on %s",n,#rest,path))
    end)
end

function scripts.cache.list(all)
    scripts.cache.process_one(function(...)
        local path, tmas, tmcs = scripts.cache.collect_one(...)
        logs.report("cache path",string.format("%4i (tma:%4i, tmc:%4i)  %s",#tmas+#tmcs,#tmas,#tmcs,path))
        logs.report("cache path",string.format("%4i (tma:%4i, tmc:%4i)  %s",#tmas+#tmcs,#tmas,#tmcs,path))
    end)
    scripts.cache.process_two(function(...)
        local path, rest = scripts.cache.collect_two("curl")
        logs.report("cache path",string.format("%4i                       %s",#rest,path))
    end)
end

logs.extendbanner("ConTeXt & MetaTeX Cache Management 0.10")

messages.help = [[
--purge               remove not used files
--erase               completely remove cache
--list                show cache

--all                 all (not yet implemented)
]]

if environment.argument("purge") then
    scripts.cache.delete(environment.argument("all"),{"tmc"})
elseif environment.argument("erase") then
    scripts.cache.delete(environment.argument("all"))
elseif environment.argument("list") then
    scripts.cache.list(environment.argument("all"))
else
    logs.help(messages.help)
end
