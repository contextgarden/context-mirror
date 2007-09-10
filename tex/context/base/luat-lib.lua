-- filename : luat-lib.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-lib'] = 1.001

-- mostcode moved to the l-*.lua and other luat-*.lua files

-- os / io

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

-- os.platform

-- mswin|bccwin|mingw|cygwin  windows
-- darwin|rhapsody|nextstep   macosx
-- netbsd|unix                unix
-- linux                      linux

if not io.fileseparator then
    if string.find(os.getenv("PATH"),";") then
        io.fileseparator, io.pathseparator, os.platform = "\\", ";", "windows"
    else
        io.fileseparator, io.pathseparator, os.platform = "/" , ":", "unix"
    end
end

if not os.platform then
    if io.pathseparator == ";" then
        os.platform = "windows"
    else
        os.platform = "unix"
    end
end

-- arg normalization
--
-- for k,v in pairs(arg) do print(k,v) end

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

-- environment

if not environment then environment = { } end

environment.arguments            = { }
environment.files                = { }
environment.sorted_argument_keys = nil

environment.platform = os.platform

function environment.initialize_arguments(arg)
    environment.arguments = { }
    environment.files     = { }
    environment.sorted_argument_keys = nil
    for index, argument in pairs(arg) do
        if index > 0 then
            local flag, value = argument:match("^%-+(.+)=(.-)$")
            if flag then
                environment.arguments[flag] = string.unquote(value or "")
            else
                flag = argument:match("^%-+(.+)")
                if flag then
                    environment.arguments[flag] = true
                else
                    environment.files[#environment.files+1] = argument
                end
            end
        end
    end
    environment.ownname = environment.ownname or arg[0] or 'unknown.lua'
end

function environment.showarguments()
    for k,v in pairs(environment.arguments) do
        print(k .. " : " .. tostring(v))
    end
    if #environment.files > 0 then
        print("files : " .. table.concat(environment.files, " "))
    end
end

function environment.setargument(name,value)
    environment.arguments[name] = value
end

function environment.argument(name)
    if environment.arguments[name] then
        return environment.arguments[name]
    else
        if not environment.sorted_argument_keys then
            environment.sorted_argument_keys = { }
            for _,v in pairs(table.sortedkeys(environment.arguments)) do
                table.insert(environment.sorted_argument_keys, "^" .. v)
            end
        end
        for _,v in pairs(environment.sorted_argument_keys) do
            if name:find(v) then
                return environment.arguments[v:sub(2,#v)]
            end
        end
    end
    return nil
end

function environment.split_arguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    for _,v in ipairs(environment.original_arguments) do
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

function environment.reconstruct_commandline(arg)
    if not arg then arg = environment.original_arguments end
    local result = { }
    for _,a in ipairs(arg) do -- ipairs 1 .. #n
        local kk, vv = a:match("^(%-+.-)=(.+)$")
        if kk and vv then
            if vv:find(" ") then
                result[#result+1] = kk .. "=" .. string.quote(vv)
            else
                result[#result+1] = a
            end
        elseif a:find(" ") then
            result[#result+1] = string.quote(a)
        else
            result[#result+1] = a
        end
    end
    return table.join(result," ")
end

if arg then
    environment.initialize_arguments(arg)
    environment.original_arguments = arg
    arg = { } -- prevent duplicate handling
end
