if not modules then modules = { } end modules ['luat-cnf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat, find = string.format, table.concat, string.find

luatex = luatex or { }

luatex.variablenames = {
    'main_memory', 'extra_mem_bot', 'extra_mem_top',
    'buf_size','expand_depth',
    'font_max', 'font_mem_size',
    'hash_extra', 'max_strings', 'pool_free', 'pool_size', 'string_vacancies',
    'obj_tab_size', 'pdf_mem_size', 'dest_names_size',
    'nest_size', 'param_size', 'save_size', 'stack_size','expand_depth',
    'trie_size', 'hyph_size', 'max_in_open',
    'ocp_stack_size', 'ocp_list_size', 'ocp_buf_size',
    'max_print_line',
}

function luatex.variables()
    local t, x = { }, nil
    for _,v in next, luatex.variablenames do
        x = resolvers.var_value(v)
        if x and find(x,"^%d+$") then
            t[v] = tonumber(x)
        end
    end
    return t
end

if not luatex.variables_set then
    for k, v in next, luatex.variables() do
        texconfig[k] = v
    end
    luatex.variables_set = true
end

local stub = [[
-- checking

storage = storage or {}
luatex  = luatex  or {}

-- as soon as possible

luatex.starttime = os.gettimeofday()

-- we provide our own file handling

texconfig.kpse_init = false
texconfig.shell_escape = 't'

-- this will happen after the format is loaded

function texconfig.init()

    -- shortcut and helper

    local b = lua.bytecode

    local function init(start)
        local i = start
        while b[i] do
            b[i]() ; b[i] = nil ; i = i + 1
         -- collectgarbage('step')
        end
        return i - start
    end

    -- the stored tables and modules

    storage.noftables  = init(0)
    storage.nofmodules = init(%s)

end

-- we provide a qualified path

callback.register('find_format_file',function(name)
    texconfig.formatname = name
    return name
end)

-- done, from now on input and callbacks are internal
]]

function luatex.dumpstate(name,firsttable)
    if tex and tex.luatexversion < 38 then
        os.remove(name)
    elseif true then
        local t = {
            "-- this file is generated, don't change it\n",
            "-- configuration (can be overloaded later)\n"
        }
        for _,v in next, luatex.variablenames do
            local tv = texconfig[v]
            if tv then
                t[#t+1] = format("texconfig.%s=%s",v,tv)
            end
        end
        io.savedata(name,format("%s\n\n%s",concat(t,"\n"),format(stub,firsttable or 501)))
    else
        io.savedata(name,format(stub,firsttable or 501))
    end
end

texconfig.kpse_init = false
texconfig.max_print_line = 100000
texconfig.max_in_open    = 127
texconfig.shell_escape   = 't'
