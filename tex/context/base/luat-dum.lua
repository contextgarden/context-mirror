if not modules then modules = { } end modules ['luat-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local dummyfunction = function() end

statistics = {
    register      = dummyfunction,
    starttiming   = dummyfunction,
    stoptiming    = dummyfunction,
}
directives = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
trackers = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
experiments = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
storage = {
    register      = dummyfunction,
    shared        = { },
}
logs = {
    report        = dummyfunction,
    simple        = dummyfunction,
}
tasks = {
    new           = dummyfunction,
    actions       = dummyfunction,
    appendaction  = dummyfunction,
    prependaction = dummyfunction,
}
callbacks = {
    register = function(n,f) return callback.register(n,f) end,
}

-- we need to cheat a bit here

texconfig.kpse_init = true

resolvers = resolvers or { } -- no fancy file helpers used

local remapper = {
    otf   = "opentype fonts",
    ttf   = "truetype fonts",
    ttc   = "truetype fonts",
    dfont = "truetype dictionary",
    cid   = "cid maps",
    fea   = "font feature files",
}

function resolvers.find_file(name,kind)
    name = string.gsub(name,"\\","\/")
    kind = string.lower(kind)
    return kpse.find_file(name,(kind and kind ~= "" and (remapper[kind] or kind)) or file.extname(name,"tex"))
end

function resolvers.findbinfile(name,kind)
    if not kind or kind == "" then
        kind = file.extname(name) -- string.match(name,"%.([^%.]-)$")
    end
    return resolvers.find_file(name,(kind and remapper[kind]) or kind)
end

-- Caches ... I will make a real stupid version some day when I'm in the
-- mood. After all, the generic code does not need the more advanced
-- ConTeXt features. Cached data is not shared between ConTeXt and other
-- usage as I don't want any dependency at all. Also, ConTeXt might have
-- different needs and tricks added.

caches = { }

--~ containers.usecache = true

function caches.setpath(category,subcategory)
    local root = kpse.var_value("TEXMFCACHE") or ""
    if root == "" then
        root = kpse.var_value("VARTEXMF") or ""
    end
    if root ~= "" then
        root = file.join(root,category)
        lfs.mkdir(root)
        root = file.join(root,subcategory)
        lfs.mkdir(root)
        return lfs.isdir(root) and root
    end
end

local function makefullname(path,name)
    if path and path ~= "" then
        name = "temp-" and name -- clash prevention
        return file.addsuffix(file.join(path,name),"lua")
    end
end

function caches.iswritable(path,name)
    local fullname = makefullname(path,name)
    return fullname and file.iswritable(fullname)
end

function caches.loaddata(path,name)
    local fullname = makefullname(path,name)
    if fullname then
        local data = loadfile(fullname)
        return data and data()
    end
end

function caches.savedata(path,name,data)
    local fullname = makefullname(path,name)
    if fullname then
        table.tofile(fullname,data,'return',false,true,false)
    end
end
