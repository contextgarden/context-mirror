if not modules then modules = { } end modules ['luat-cnf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat, find = string.format, table.concat, string.find

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

luatex = luatex or { }

luatex.variablenames = {
    'buf_size',         --  3000
    'dvi_buf_size',     -- 16384
    'error_line',       --    79
    'expand_depth',     -- 10000
    'half_error_line',  --    50
    'hash_extra',       --     0
    'nest_size',        --    50
    'max_in_open',      --    15
    'max_print_line',   --    79
    'max_strings',      -- 15000
    'ocp_stack_size',   --  1000
    'ocp_list_size',    --  1000
    'ocp_buf_size',     --  1000
    'param_size',       --    60
    'pk_dpi',           --    72
    'save_size',        --  4000
    'stack_size',       --   300
    'strings_free',     --   100
}

function luatex.variables()
    local t = { }
    for _,v in next, luatex.variablenames do
        local x = resolvers.var_value(v)
        t[v] = tonumber(x) or x
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

storage = storage or { }
luatex  = luatex  or { }

-- we provide our own file handling

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

-- as soon as possible

luatex.starttime = os.gettimeofday()

-- this will happen after the format is loaded

function texconfig.init()

    -- shortcut and helper

    local function init(start)
        local b = lua.bytecode
        local i = start
        while b[i] do
            b[i]() ;
            b[i] = nil ;
            i = i + 1
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

local function makestub()
    name = name or (environment.jobname .. ".lui")
    firsttable = firsttable or lua.firstbytecode
    local t = {
        "-- this file is generated, don't change it\n",
        "-- configuration (can be overloaded later)\n"
    }
    for _,v in next, luatex.variablenames do
        local tv = texconfig[v]
        if tv and tv ~= "" then
            t[#t+1] = format("texconfig.%s=%s",v,tv)
        end
    end
    io.savedata(name,format("%s\n\n%s",concat(t,"\n"),format(stub,firsttable)))
end

lua.registerfinalizer(makestub,"create stub file")

-- to be moved here:
--
-- statistics.report_storage("log")
-- statistics.save_fmt_status("\jobname","\contextversion","context.tex")
