if not modules then modules = { } end modules ['luat-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A former version provided functionality for non embeded core
-- scripts i.e. runtime library loading. Given the amount of
-- Lua code we use now, this no longer makes sense. Much of this
-- evolved before bytecode arrays were available and so a lot of
-- code has disappeared already.

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_lua = logs.reporter("resolvers","lua")

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local format, sub, match, gsub, find = string.format, string.sub, string.match, string.gsub, string.find
local unquoted, quoted = string.unquoted, string.quoted
local concat = table.concat

-- precautions

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

function os.setlocale()
    -- no way you can mess with it
end

-- dirty tricks

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1] = arg[0]
    arg[ 0] = arg[2]
    for k=3,#arg do
        arg[k-2] = arg[k]
    end
    arg[#arg] = nil -- last
    arg[#arg] = nil -- pre-last
end

-- environment

environment             = environment or { }
local environment       = environment

environment.arguments   = allocate()
environment.files       = allocate()
environment.sortedflags = nil

local mt = {
    __index = function(_,k)
        if k == "version" then
            local version = tex.toks and tex.toks.contextversiontoks
            if version and version ~= "" then
                rawset(environment,"version",version)
                return version
            else
                return "unknown"
            end
        elseif k == "jobname" or k == "formatname" then
            local name = tex and tex[k]
            if name or name== "" then
                rawset(environment,k,name)
                return name
            else
                return "unknown"
            end
        elseif k == "outputfilename" then
            local name = environment.jobname
            rawset(environment,k,name)
            return name
        end
    end
}

setmetatable(environment,mt)

function environment.initializearguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index=1,#arg do
        local argument = arg[index]
        if index > 0 then
            local flag, value = match(argument,"^%-+(.-)=(.-)$")
            if flag then
                arguments[flag] = unquoted(value or "")
            else
                flag = match(argument,"^%-+(.+)")
                if flag then
                    arguments[flag] = true
                else
                    files[#files+1] = argument
                end
            end
        end
    end
    environment.ownname = environment.ownname or arg[0] or 'unknown.lua'
end

function environment.setargument(name,value)
    environment.arguments[name] = value
end

-- todo: defaults, better checks e.g on type (boolean versus string)
--
-- tricky: too many hits when we support partials unless we add
-- a registration of arguments so from now on we have 'partial'

function environment.argument(name,partial)
    local arguments, sortedflags = environment.arguments, environment.sortedflags
    if arguments[name] then
        return arguments[name]
    elseif partial then
        if not sortedflags then
            sortedflags = allocate(table.sortedkeys(arguments))
            for k=1,#sortedflags do
                sortedflags[k] = "^" .. sortedflags[k]
            end
            environment.sortedflags = sortedflags
        end
        -- example of potential clash: ^mode ^modefile
        for k=1,#sortedflags do
            local v = sortedflags[k]
            if find(name,v) then
                return arguments[sub(v,2,#v)]
            end
        end
    end
    return nil
end

function environment.splitarguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    local originalarguments = environment.originalarguments
    for k=1,#originalarguments do
        local v = originalarguments[k]
        if not done and v == separator then
            done = true
        elseif done then
            after[#after+1] = v
        else
            before[#before+1] = v
        end
    end
    return before, after
end

function environment.reconstructcommandline(arg,noquote)
    arg = arg or environment.originalarguments
    if noquote and #arg == 1 then
        -- we could just do: return unquoted(resolvers.resolve(arg[i]))
        local a = arg[1]
        a = resolvers.resolve(a)
        a = unquoted(a)
        return a
    elseif #arg > 0 then
        local result = { }
        for i=1,#arg do
            -- we could just do: result[#result+1] = format("%q",unquoted(resolvers.resolve(arg[i])))
            local a = arg[i]
            a = resolvers.resolve(a)
            a = unquoted(a)
            a = gsub(a,'"','\\"') -- tricky
            if find(a," ") then
                result[#result+1] = quoted(a)
            else
                result[#result+1] = a
            end
        end
        return concat(result," ")
    else
        return ""
    end
end

--~ -- to be tested:
--~
--~ function environment.reconstructcommandline(arg,noquote)
--~     arg = arg or environment.originalarguments
--~     if noquote and #arg == 1 then
--~         return unquoted(resolvers.resolve(arg[1]))
--~     elseif #arg > 0 then
--~         local result = { }
--~         for i=1,#arg do
--~             result[#result+1] = format("%q",unquoted(resolvers.resolve(arg[i]))) -- always quote
--~         end
--~         return concat(result," ")
--~     else
--~         return ""
--~     end
--~ end

if arg then

    -- new, reconstruct quoted snippets (maybe better just remove the " then and add them later)
    local newarg, instring = { }, false

    for index=1,#arg do
        local argument = arg[index]
        if find(argument,"^\"") then
            newarg[#newarg+1] = gsub(argument,"^\"","")
            if not find(argument,"\"$") then
                instring = true
            end
        elseif find(argument,"\"$") then
            newarg[#newarg] = newarg[#newarg] .. " " .. gsub(argument,"\"$","")
            instring = false
        elseif instring then
            newarg[#newarg] = newarg[#newarg] .. " " .. argument
        else
            newarg[#newarg+1] = argument
        end
    end
    for i=1,-5,-1 do
        newarg[i] = arg[i]
    end

    environment.initializearguments(newarg)

    environment.originalarguments = mark(newarg)
    environment.rawarguments      = mark(arg)

    arg = { } -- prevent duplicate handling

end

-- weird place ... depends on a not yet loaded module

function environment.texfile(filename)
    return resolvers.findfile(filename,'tex')
end

function environment.luafile(filename)
    local resolved = resolvers.findfile(filename,'tex') or ""
    if resolved ~= "" then
        return resolved
    end
    resolved = resolvers.findfile(filename,'texmfscripts') or ""
    if resolved ~= "" then
        return resolved
    end
    return resolvers.findfile(filename,'luatexlibs') or ""
end

environment.loadedluacode = loadfile -- can be overloaded

function environment.luafilechunk(filename,silent) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        local data = environment.loadedluacode(fullname)
        if trace_locating then
            report_lua("loading file %s%s", fullname, not data and " failed" or "")
        elseif not silent then
            texio.write("<",data and "+ " or "- ",fullname,">")
        end
        return data
    else
        if trace_locating then
            report_lua("unknown file %s", filename)
        end
        return nil
    end
end

-- the next ones can use the previous ones / combine

function environment.loadluafile(filename, version)
    local lucname, luaname, chunk
    local basename = file.removesuffix(filename)
    if basename == filename then
        lucname, luaname = basename .. ".luc",  basename .. ".lua"
    else
        lucname, luaname = nil, basename -- forced suffix
    end
    -- when not overloaded by explicit suffix we look for a luc file first
    local fullname = (lucname and environment.luafile(lucname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
    end
    if chunk then
        assert(chunk)()
        if version then
            -- we check of the version number of this chunk matches
            local v = version -- can be nil
            if modules and modules[filename] then
                v = modules[filename].version -- new method
            elseif versions and versions[filename] then
                v = versions[filename]        -- old method
            end
            if v == version then
                return true
            else
                if trace_locating then
                    report_lua("version mismatch for %s: lua=%s, luc=%s", filename, v, version)
                end
                environment.loadluafile(filename)
            end
        else
            return true
        end
    end
    fullname = (luaname and environment.luafile(luaname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            if trace_locating then
                report_lua("unknown file %s", filename)
            end
        else
            assert(chunk)()
            return true
        end
    end
    return false
end
