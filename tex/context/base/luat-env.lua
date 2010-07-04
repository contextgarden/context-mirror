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

local format, sub, match, gsub, find = string.format, string.sub, string.match, string.gsub, string.find
local unquote, quote = string.unquote, string.quote

-- precautions

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

function os.setlocale()
    -- no way you can mess with it
end

-- dirty tricks

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

if profiler and os.env["MTX_PROFILE_RUN"] == "YES" then
    profiler.start("luatex-profile.log")
end

-- environment

environment             = environment or { }
environment.arguments   = { }
environment.files       = { }
environment.sortedflags = nil

if not environment.jobname or environment.jobname == "" then if tex then environment.jobname = tex.jobname end end
if not environment.version or environment.version == "" then             environment.version = "unknown"   end
if not environment.jobname                              then             environment.jobname = "unknown"   end

function environment.initialize_arguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index=1,#arg do
        local argument = arg[index]
        if index > 0 then
            local flag, value = match(argument,"^%-+(.-)=(.-)$")
            if flag then
                arguments[flag] = unquote(value or "")
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
            sortedflags = table.sortedkeys(arguments)
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

environment.argument("x",true)

function environment.split_arguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    local original_arguments = environment.original_arguments
    for k=1,#original_arguments do
        local v = original_arguments[k]
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

function environment.reconstruct_commandline(arg,noquote)
    arg = arg or environment.original_arguments
    if noquote and #arg == 1 then
        local a = arg[1]
        a = resolvers.resolve(a)
        a = unquote(a)
        return a
    elseif #arg > 0 then
        local result = { }
        for i=1,#arg do
            local a = arg[i]
            a = resolvers.resolve(a)
            a = unquote(a)
            a = gsub(a,'"','\\"') -- tricky
            if find(a," ") then
                result[#result+1] = quote(a)
            else
                result[#result+1] = a
            end
        end
        return table.join(result," ")
    else
        return ""
    end
end

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

    environment.initialize_arguments(newarg)
    environment.original_arguments = newarg
    environment.raw_arguments = arg

    arg = { } -- prevent duplicate handling

end

-- weird place ... depends on a not yet loaded module

function environment.texfile(filename)
    return resolvers.find_file(filename,'tex')
end

function environment.luafile(filename)
    local resolved = resolvers.find_file(filename,'tex') or ""
    if resolved ~= "" then
        return resolved
    end
    resolved = resolvers.find_file(filename,'texmfscripts') or ""
    if resolved ~= "" then
        return resolved
    end
    return resolvers.find_file(filename,'luatexlibs') or ""
end

environment.loadedluacode = loadfile -- can be overloaded

--~ function environment.loadedluacode(name)
--~     if os.spawn("texluac -s -o texluac.luc " .. name) == 0 then
--~         local chunk = loadstring(io.loaddata("texluac.luc"))
--~         os.remove("texluac.luc")
--~         return chunk
--~     else
--~         environment.loadedluacode = loadfile -- can be overloaded
--~         return loadfile(name)
--~     end
--~ end

function environment.luafilechunk(filename) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        if trace_locating then
            logs.report("fileio","loading file %s", fullname)
        end
        return environment.loadedluacode(fullname)
    else
        if trace_locating then
            logs.report("fileio","unknown file %s", filename)
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
            logs.report("fileio","loading %s", fullname)
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
                    logs.report("fileio","version mismatch for %s: lua=%s, luc=%s", filename, v, version)
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
            logs.report("fileio","loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            if trace_locating then
                logs.report("fileio","unknown file %s", filename)
            end
        else
            assert(chunk)()
            return true
        end
    end
    return false
end
