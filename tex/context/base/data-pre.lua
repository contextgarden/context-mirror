if not modules then modules = { } end modules ['data-res'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ print(resolvers.resolve("abc env:tmp file:cont-en.tex path:cont-en.tex full:cont-en.tex rel:zapf/one/p-chars.tex"))

local upper, lower, gsub = string.upper, string.lower, string.gsub

local prefixes = { }

prefixes.environment = function(str)
    return resolvers.clean_path(os.getenv(str) or os.getenv(upper(str)) or os.getenv(lower(str)) or "")
end

prefixes.relative = function(str,n)
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
    return resolvers.clean_path(str)
end

prefixes.auto = function(str)
    local fullname = prefixes.relative(str)
    if not lfs.isfile(fullname) then
        fullname = prefixes.locate(str)
    end
    return fullname
end

prefixes.locate = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path((fullname ~= "" and fullname) or str)
end

prefixes.filename = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path(file.basename((fullname ~= "" and fullname) or str))
end

prefixes.pathname = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path(file.dirname((fullname ~= "" and fullname) or str))
end

prefixes.env  = prefixes.environment
prefixes.rel  = prefixes.relative
prefixes.loc  = prefixes.locate
prefixes.kpse = prefixes.locate
prefixes.full = prefixes.locate
prefixes.file = prefixes.filename
prefixes.path = prefixes.pathname

function resolvers.allprefixes(separator)
    local all = table.sortedkeys(prefixes)
    if separator then
        for i=1,#all do
            all[i] = all[i] .. ":"
        end
    end
    return all
end

local function _resolve_(method,target)
    if prefixes[method] then
        return prefixes[method](target)
    else
        return method .. ":" .. target
    end
end

local function resolve(str)
    if type(str) == "table" then
        for k, v in pairs(str) do -- ipairs
            str[k] = resolve(v) or v
        end
    elseif str and str ~= "" then
        str = gsub(str,"([a-z]+):([^ \"\']*)",_resolve_)
    end
    return str
end

resolvers.resolve = resolve

if os.uname then

    for k, v in pairs(os.uname()) do
        if not prefixes[k] then
            prefixes[k] = function() return v end
        end
    end

end
