if not modules then modules = { } end modules ['luat-lib'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "companion to luat-lib.tex",
}

-- most code already moved to the l-*.lua and other luat-*.lua files

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

function os.setlocale()
    -- no way you can mess with it
end

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

environment             = environment or { }
environment.arguments   = { }
environment.files       = { }
environment.sortedflags = nil

function environment.initialize_arguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index, argument in pairs(arg) do
        if index > 0 then
            local flag, value = argument:match("^%-+(.+)=(.-)$")
            if flag then
                arguments[flag] = string.unquote(value or "")
            else
                flag = argument:match("^%-+(.+)")
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
    local arguments, sortedflags = environment.arguments, environment.sortedflags
    if arguments[name] then
        return arguments[name]
    else
        if not sortedflags then
            sortedflags = { }
            for _,v in pairs(table.sortedkeys(arguments)) do
                sortedflags[#sortedflags+1] = "^" .. v
            end
            environment.sortedflags = sortedflags
        end
        for _,v in ipairs(sortedflags) do
            if name:find(v) then
                return arguments[v:sub(2,#v)]
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
