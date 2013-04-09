if not modules then modules = { } end modules ['data-pre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It could be interesting to hook the resolver in the file
-- opener so that unresolved prefixes travel around and we
-- get more abstraction.

-- As we use this beforehand we will move this up in the chain
-- of loading.

--~ print(resolvers.resolve("abc env:tmp file:cont-en.tex path:cont-en.tex full:cont-en.tex rel:zapf/one/p-chars.tex"))

local resolvers    = resolvers
local prefixes     = utilities.storage.allocate()
resolvers.prefixes = prefixes

local cleanpath, findgivenfile, expansion = resolvers.cleanpath, resolvers.findgivenfile, resolvers.expansion
local getenv = resolvers.getenv -- we can probably also use resolvers.expansion
local P, S, R, C, Cs, Cc, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.match
local joinpath, basename, dirname = file.join, file.basename, file.dirname
local getmetatable, rawset, type = getmetatable, rawset, type

-- getenv = function(...) return resolvers.getenv(...) end -- needs checking (definitions changes later on)

prefixes.environment = function(str)
    return cleanpath(expansion(str))
end

prefixes.relative = function(str,n) -- lfs.isfile
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
    return cleanpath(str)
end

prefixes.auto = function(str)
    local fullname = prefixes.relative(str)
    if not lfs.isfile(fullname) then
        fullname = prefixes.locate(str)
    end
    return fullname
end

prefixes.locate = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath((fullname ~= "" and fullname) or str)
end

prefixes.filename = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(basename((fullname ~= "" and fullname) or str)) -- no cleanpath needed here
end

prefixes.pathname = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(dirname((fullname ~= "" and fullname) or str))
end

prefixes.selfautoloc = function(str)
    return cleanpath(joinpath(getenv('SELFAUTOLOC'),str))
end

prefixes.selfautoparent = function(str)
    return cleanpath(joinpath(getenv('SELFAUTOPARENT'),str))
end

prefixes.selfautodir = function(str)
    return cleanpath(joinpath(getenv('SELFAUTODIR'),str))
end

prefixes.home = function(str)
    return cleanpath(joinpath(getenv('HOME'),str))
end

local function toppath()
    local inputstack = resolvers.inputstack -- dependency, actually the code should move but it's
    if not inputstack then                  -- more convenient to keep it here
        return "."
    end
    local pathname = dirname(inputstack[#inputstack] or "")
    if pathname == "" then
        return "."
    else
        return pathname
    end
end

resolvers.toppath = toppath

prefixes.toppath = function(str)
    return cleanpath(joinpath(toppath(),str))
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
    local action = prefixes[method]
    if action then
        return action(target)
    else
        return method .. ":" .. target
    end
end

local resolved, abstract = { }, { }

function resolvers.resetresolve(str)
    resolved, abstract = { }, { }
end

-- todo: use an lpeg (see data-lua for !! / stripper)

-- local function resolve(str) -- use schemes, this one is then for the commandline only
--     if type(str) == "table" then
--         local t = { }
--         for i=1,#str do
--             t[i] = resolve(str[i])
--         end
--         return t
--     else
--         local res = resolved[str]
--         if not res then
--             res = gsub(str,"([a-z][a-z]+):([^ \"\';,]*)",_resolve_) -- home:xx;selfautoparent:xx; etc (comma added)
--             resolved[str] = res
--             abstract[res] = str
--         end
--         return res
--     end
-- end

-- home:xx;selfautoparent:xx;

local pattern = Cs((C(R("az")^2) * P(":") * C((1-S(" \"\';,"))^1) / _resolve_ + P(1))^0)

local prefix   = C(R("az")^2) * P(":")
local target   = C((1-S(" \"\';,"))^1)
local notarget = (#S(";,") + P(-1)) * Cc("")

local pattern  = Cs(((prefix * (target + notarget)) / _resolve_ + P(1))^0)

local function resolve(str) -- use schemes, this one is then for the commandline only
    if type(str) == "table" then
        local t = { }
        for i=1,#str do
            t[i] = resolve(str[i])
        end
        return t
    else
        local res = resolved[str]
        if not res then
            res = lpegmatch(pattern,str)
            resolved[str] = res
            abstract[res] = str
        end
        return res
    end
end

local function unresolve(str)
    return abstract[str] or str
end

resolvers.resolve   = resolve
resolvers.unresolve = unresolve

if type(os.uname) == "function" then

    for k, v in next, os.uname() do
        if not prefixes[k] then
            prefixes[k] = function() return v end
        end
    end

end

if os.type == "unix" then

    -- We need to distringuish between a prefix and something else : so we
    -- have a special repath variant for linux. Also, when a new prefix is
    -- defined, we need to remake the matcher.

    local pattern

    local function makepattern(t,k,v)
        if t then
            rawset(t,k,v)
        end
        local colon = P(":")
        for k, v in table.sortedpairs(prefixes) do
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
        pattern = Cs((p * colon + colon/";" + P(1))^0)
    end

    makepattern()

    getmetatable(prefixes).__newindex = makepattern

    function resolvers.repath(str)
        return lpegmatch(pattern,str)
    end

else -- already the default:

    function resolvers.repath(str)
        return str
    end

end
