if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, gsub, match = string.find, string.gsub, string.match
local getenv, setenv = os.getenv, os.setenv

-- loads *.tmf files in minimal tree roots (to be optimized and documented)

function resolvers.check_environment(tree)
    logs.simpleline()
    setenv('TMP', getenv('TMP') or getenv('TEMP') or getenv('TMPDIR') or getenv('HOME'))
    setenv('TEXOS', getenv('TEXOS') or ("texmf-" .. os.platform))
    setenv('TEXPATH', gsub(tree or "tex","\/+$",''))
    setenv('TEXMFOS', getenv('TEXPATH') .. "/" .. getenv('TEXOS'))
    logs.simpleline()
    logs.simple("preset : TEXPATH => %s", getenv('TEXPATH'))
    logs.simple("preset : TEXOS   => %s", getenv('TEXOS'))
    logs.simple("preset : TEXMFOS => %s", getenv('TEXMFOS'))
    logs.simple("preset : TMP     => %s", getenv('TMP'))
    logs.simple('')
end

function resolvers.load_environment(name) -- todo: key=value as well as lua
    local f = io.open(name)
    if f then
        for line in f:lines() do
            if find(line,"^[%%%#]") then
                -- skip comment
            else
                local key, how, value = match(line,"^(.-)%s*([<=>%?]+)%s*(.*)%s*$")
                if how then
                    value = gsub(value,"%%(.-)%%", function(v) return getenv(v) or "" end)
                        if how == "=" or how == "<<" then
                            setenv(key,value)
                    elseif how == "?" or how == "??" then
                            setenv(key,getenv(key) or value)
                    elseif how == "<" or how == "+=" then
                        if getenv(key) then
                            setenv(key,getenv(key) .. io.fileseparator .. value)
                        else
                            setenv(key,value)
                        end
                    elseif how == ">" or how == "=+" then
                        if getenv(key) then
                            setenv(key,value .. io.pathseparator .. getenv(key))
                        else
                            setenv(key,value)
                        end
                    end
                end
            end
        end
        f:close()
    end
end

function resolvers.load_tree(tree)
    if tree and tree ~= "" then
        local setuptex = 'setuptex.tmf'
        if lfs.attributes(tree, "mode") == "directory" then -- check if not nil
            setuptex = tree .. "/" .. setuptex
        else
            setuptex = tree
        end
        if io.exists(setuptex) then
            resolvers.check_environment(tree)
            resolvers.load_environment(setuptex)
        end
    end
end
