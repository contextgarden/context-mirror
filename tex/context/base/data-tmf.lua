if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- loads *.tmf files in minimal tree roots (to be optimized and documented)

function resolvers.check_environment(tree)
    logs.simpleline()
    os.setenv('TMP', os.getenv('TMP') or os.getenv('TEMP') or os.getenv('TMPDIR') or os.getenv('HOME'))
    os.setenv('TEXOS', os.getenv('TEXOS') or ("texmf-" .. os.currentplatform()))
    os.setenv('TEXPATH', (tree or "tex"):gsub("\/+$",''))
    os.setenv('TEXMFOS', os.getenv('TEXPATH') .. "/" .. os.getenv('TEXOS'))
    logs.simpleline()
    logs.simple("preset : TEXPATH => %s", os.getenv('TEXPATH'))
    logs.simple("preset : TEXOS   => %s", os.getenv('TEXOS'))
    logs.simple("preset : TEXMFOS => %s", os.getenv('TEXMFOS'))
    logs.simple("preset : TMP     => %s", os.getenv('TMP'))
    logs.simple('')
end

function resolvers.load_environment(name) -- todo: key=value as well as lua
    local f = io.open(name)
    if f then
        for line in f:lines() do
            if line:find("^[%%%#]") then
                -- skip comment
            else
                local key, how, value = line:match("^(.-)%s*([<=>%?]+)%s*(.*)%s*$")
                if how then
                    value = value:gsub("%%(.-)%%", function(v) return os.getenv(v) or "" end)
                        if how == "=" or how == "<<" then
                            os.setenv(key,value)
                    elseif how == "?" or how == "??" then
                            os.setenv(key,os.getenv(key) or value)
                    elseif how == "<" or how == "+=" then
                        if os.getenv(key) then
                            os.setenv(key,os.getenv(key) .. io.fileseparator .. value)
                        else
                            os.setenv(key,value)
                        end
                    elseif how == ">" or how == "=+" then
                        if os.getenv(key) then
                            os.setenv(key,value .. io.pathseparator .. os.getenv(key))
                        else
                            os.setenv(key,value)
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
