if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts       = scripts       or { }
scripts.cache = scripts.cache or { }

local function collect(path)
    local all = dir.glob(path .. "/**/*")
    local tmas, tmcs, rest = { }, { }, { }
    for i=1,#all do
        local name = all[i]
        local suffix = file.suffix(name)
        if suffix == "tma" then
            tmas[#tmas+1] = name
        elseif suffix == "tmc" then
            tmcs[#tmcs+1] = name
        else
            rest[#rest+1] = name
        end
    end
    return tmas, tmcs, rest, all
end

local function list(banner,path,tmas,tmcs,rest)
    logs.report("cache",string.format("%s: %s",banner,path))
    logs.report()
    logs.report("cache",string.format("tma   : %4i",#tmas))
    logs.report("cache",string.format("tmc   : %4i",#tmcs))
    logs.report("cache",string.format("rest  : %4i",#rest))
    logs.report("cache",string.format("total : %4i",#tmas+#tmcs+#rest))
    logs.report()
end

local function purge(banner,path,list,all)
    logs.report("cache",string.format("%s: %s",banner,path))
    logs.report()
    local n = 0
    for i=1,#list do
        local filename = list[i]
        if string.find(filename,"luatex%-cache") then -- safeguard
            if all then
                os.remove(filename)
                n = n + 1
            else
                local suffix = file.suffix(filename)
                if suffix == "tma" then
                    local checkname = file.replacesuffix(filename,"tma","tmc")
                    if lfs.isfile(checkname) then
                        os.remove(filename)
                        n = n + 1
                    end
                end
            end
        end
    end
    logs.report("cache",string.format("removed tma files : %i",n))
    logs.report()
end

function scripts.cache.purge()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    local n = purge("writable path",writable,tmas)
    list("writable path",writable,tmas,tmcs,rest)
end

function scripts.cache.erase()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest, all = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    local n = purge("writable path",writable,all,true)
    list("writable path",writable,tmas,tmcs,rest)
end

function scripts.cache.list()
    local readables = caches.getreadablepaths()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    for i=1,#readables do
        local readable = readables[i]
        if readable ~= writable then
            local tmas, tmcs = collect(readable)
            list("readable path",readable,tmas,tmcs,rest)
        end
    end
end

logs.extendbanner("ConTeXt & MetaTeX Cache Management 0.10")

messages.help = [[
--purge               remove not used files
--erase               completely remove cache
--list                show cache

--all                 all (not yet implemented)
]]

if environment.argument("purge") then
    scripts.cache.purge()
elseif environment.argument("erase") then
    scripts.cache.erase()
elseif environment.argument("list") then
    scripts.cache.list()
else
    logs.help(messages.help)
end
