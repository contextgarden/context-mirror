if not modules then modules = { } end modules ['luat-cnf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring, tonumber =  type, next, tostring, tonumber
local format, concat, find = string.format, table.concat, string.find

local allocate = utilities.storage.allocate

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

luatex       = luatex or { }
local luatex = luatex

local variablenames = allocate { -- most of this becomes obsolete
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
    'param_size',       --    60
    'pk_dpi',           --    72
    'save_size',        --  4000
    'stack_size',       --   300
    'strings_free',     --   100
}

local function initialize()
    local t, variable = allocate(), resolvers.variable
    for i=1,#variablenames do
        local name = variablenames[i]
        local value = variable(name)
        value = tonumber(value) or value
        texconfig[name], t[name] = value, value
    end
    initialize = nil
    return t
end

luatex.variables = initialize()

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

    -- development

    local builtin, globals = { }, { }

    libraries = { -- we set it her as we want libraries also 'indexed'
        basiclua = {
            "string", "table", "coroutine", "debug", "file", "io", "lpeg", "math", "os", "package",
        },
        basictex = { -- noad
            "callback", "font", "img", "lang", "lua", "node", "pdf", "status", "tex", "texconfig", "texio", "token",
        },
        extralua = {
            "gzip",  "zip", "zlib", "lfs", "ltn12", "mime", "socket", "md5", "profiler", "unicode", "utf",
        },
        extratex = {
            "epdf", "fontloader", "kpse", "mplib",
        },
        obsolete = {
            "fontforge", -- can be filled by luat-log
            "kpse",
        },
        builtin = builtin, -- to be filled
        globals = globals, -- to be filled
    }

    for k, v in next, _G do
        globals[k] = tostring(v)
    end

    local function collect(t)
        local lib = { }
        for k, v in next, t do
            local keys = { }
            local gv = _G[v]
            if type(gv) == "table" then
                for k, v in next, gv do
                    keys[k] = tostring(v) -- true -- by tostring we cannot call overloades functions (security)
                end
            end
            lib[v] = keys
            builtin[v] = keys
        end
        return lib
    end

    libraries.basiclua = collect(libraries.basiclua)
    libraries.basictex = collect(libraries.basictex)
    libraries.extralua = collect(libraries.extralua)
    libraries.extratex = collect(libraries.extratex)
    libraries.obsolete = collect(libraries.obsolete)

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
    for _,v in next, variablenames do
        local tv = texconfig[v]
        if tv and tv ~= "" then
            t[#t+1] = format("texconfig.%s=%s",v,tv)
        end
    end
    io.savedata(name,format("%s\n\n%s",concat(t,"\n"),format(stub,firsttable)))
end

lua.registerfinalizer(makestub,"create stub file")
