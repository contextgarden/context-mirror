dofile(input.find_file(instance,"luat-log.lua"))

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts       = scripts       or { }
scripts.cache = scripts.cache or { }

function scripts.cache.collect_one(...)
    local path = caches.setpath(instance,...)
    local tmas = dir.glob(path .. "/*tma")
    local tmcs = dir.glob(path .. "/*tmc")
    return path, tmas, tmcs
end

function scripts.cache.collect_two(...)
    local path = caches.setpath(instance,...)
    local rest = dir.glob(path .. "/**/*")
    return path, rest
end

function scripts.cache.process_one(action)
    action("fonts", "afm")
    action("fonts", "tfm")
    action("fonts", "def")
    action("fonts", "enc")
    action("fonts", "otf")
    action("fonts", "data")
end

function scripts.cache.process_two(action)
    action("curl")
end

-- todo: recursive delete of paths

function scripts.cache.remove(list,keep)
    local keepsuffixes = { }
    for _, v in ipairs(keep or {}) do
        keepsuffixes[v] = true
    end
    local n = 0
    for _,filename in ipairs(list) do
        if filename:find("luatex%-cache") then -- safeguard
            if not keepsuffixes[file.extname(filename) or ""] then
                os.remove(filename)
                n = n + 1
            end
        end
    end
    return n
end

function scripts.cache.delete(all,keep)
    local function action(...)
        local path, rest = scripts.cache.collect_two(...)
        local n = scripts.cache.remove(rest,keep)
        logs.report("cache path",string.format("%4i files out of %4i deleted on %s",n,#rest,path))
    end
    scripts.cache.process_one(action)
    scripts.cache.process_two(action)
end

function scripts.cache.list(all)
    scripts.cache.process_one(function(...)
        local path, tmas, tmcs = scripts.cache.collect_one(...)
        logs.report("cache path",string.format("tma:%4i tmc:%4i   %s",#tmas,#tmcs,path))
    end)
    scripts.cache.process_two(function(...)
        local path, rest = scripts.cache.collect_two("curl")
        logs.report("cache path",string.format("all:%4i            %s",#rest,path))
    end)
end

banner = banner .. " | cache tools "

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
    input.help(banner,messages.help)
end
