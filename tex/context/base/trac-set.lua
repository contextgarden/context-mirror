if not modules then modules = { } end modules ['trac-set'] = { -- might become util-set.lua
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring = type, next, tostring
local concat = table.concat
local format, find, lower, gsub, escapedpattern = string.format, string.find, string.lower, string.gsub, string.escapedpattern
local is_boolean = string.is_boolean
local settings_to_hash = utilities.parsers.settings_to_hash
local allocate = utilities.storage.allocate

utilities         = utilities or { }
local utilities   = utilities
utilities.setters = utilities.setters or { }
local setters     = utilities.setters

local data = { } -- maybe just local

-- We can initialize from the cnf file. This is sort of tricky as
-- later defined setters also need to be initialized then. If set
-- this way, we need to ensure that they are not reset later on.

local trace_initialize = false -- only for testing during development

function setters.initialize(filename,name,values) -- filename only for diagnostics
    local setter = data[name]
    if setter then
        local data = setter.data
        if data then
            for key, value in next, values do
             -- key = gsub(key,"_",".")
                value = is_boolean(value,value)
                local functions = data[key]
                if functions then
                    if #functions > 0 and not functions.value then
                        if trace_initialize then
                            setter.report("executing %s (%s -> %s)",key,filename,tostring(value))
                        end
                        for i=1,#functions do
                            functions[i](value)
                        end
                        functions.value = value
                    else
                        if trace_initialize then
                            setter.report("skipping %s (%s -> %s)",key,filename,tostring(value))
                        end
                    end
                else
                    -- we do a simple preregistration i.e. not in the
                    -- list as it might be an obsolete entry
                    functions = { default = value }
                    data[key] = functions
                    if trace_initialize then
                        setter.report("storing %s (%s -> %s)",key,filename,tostring(value))
                    end
                end
            end
            return true
        end
    end
end

-- user interface code

local function set(t,what,newvalue)
    local data, done = t.data, t.done
    if type(what) == "string" then
        what = settings_to_hash(what) -- inefficient but ok
    end
    if type(what) ~= "table" then
        return
    end
    if not done then -- catch ... why not set?
        done = { }
        t.done = done
    end
    for w, value in next, what do
        if value == "" then
            value = newvalue
        elseif not value then
            value = false -- catch nil
        else
            value = is_boolean(value,value)
        end
        w = "^" .. escapedpattern(w,true) .. "$" -- new: anchored
        for name, functions in next, data do
            if done[name] then
                -- prevent recursion due to wildcards
            elseif find(name,w) then
                done[name] = true
                for i=1,#functions do
                    functions[i](value)
                end
                functions.value = value
            end
        end
    end
end

local function reset(t)
    for name, functions in next, t.data do
        for i=1,#functions do
            functions[i](false)
        end
        functions.value = false
    end
end

local function enable(t,what)
    set(t,what,true)
end

local function disable(t,what)
    local data = t.data
    if not what or what == "" then
        t.done = { }
        reset(t)
    else
        set(t,what,false)
    end
end

function setters.register(t,what,...)
    local data = t.data
    what = lower(what)
    local functions = data[what]
    if not functions then
        functions = { }
        data[what] = functions
        if trace_initialize then
            t.report("defining %s",what)
        end
    end
    local default = functions.default -- can be set from cnf file
    for _, fnc in next, { ... } do
        local typ = type(fnc)
        if typ == "string" then
            if trace_initialize then
                t.report("coupling %s to %s",what,fnc)
            end
            local s = fnc -- else wrong reference
            fnc = function(value) set(t,s,value) end
        elseif typ ~= "function" then
            fnc = nil
        end
        if fnc then
            functions[#functions+1] = fnc
            -- default: set at command line or in cnf file
            -- value  : set in tex run (needed when loading runtime)
            local value = functions.value or default
            if value ~= nil then
                fnc(value)
                functions.value = value
            end
        end
    end
    return false -- so we can use it in an assignment
end

function setters.enable(t,what)
    local e = t.enable
    t.enable, t.done = enable, { }
    enable(t,what)
    t.enable, t.done = e, { }
end

function setters.disable(t,what)
    local e = t.disable
    t.disable, t.done = disable, { }
    disable(t,what)
    t.disable, t.done = e, { }
end

function setters.reset(t)
    t.done = { }
    reset(t)
end

function setters.list(t) -- pattern
    local list = table.sortedkeys(t.data)
    local user, system = { }, { }
    for l=1,#list do
        local what = list[l]
        if find(what,"^%*") then
            system[#system+1] = what
        else
            user[#user+1] = what
        end
    end
    return user, system
end

function setters.show(t)
    local category = t.name
    local list = setters.list(t)
    t.report()
    for k=1,#list do
        local name = list[k]
        local functions = t.data[name]
        if functions then
            local value, default, modules = functions.value, functions.default, #functions
            value   = value   == nil and "unset" or tostring(value)
            default = default == nil and "unset" or tostring(default)
            t.report("%-30s   modules: %2i   default: %6s   value: %6s",name,modules,default,value)
        end
    end
    t.report()
end

-- we could have used a bit of oo and the trackers:enable syntax but
-- there is already a lot of code around using the singular tracker

-- we could make this into a module but we also want the rest avaliable

local enable, disable, register, list, show = setters.enable, setters.disable, setters.register, setters.list, setters.show

local function report(setter,...)
    local report = logs and logs.report
    if report then
        report(setter.name,...)
    else -- fallback, as this module is loaded before the logger
        write_nl(format("%-15s : %s\n",setter.name,format(...)))
    end
end

function setters.new(name)
    local setter -- we need to access it in setter itself
    setter = {
        data     = allocate(), -- indexed, but also default and value fields
        name     = name,
        report   = function(...) report  (setter,...) end,
        enable   = function(...) enable  (setter,...) end,
        disable  = function(...) disable (setter,...) end,
        register = function(...) register(setter,...) end,
        list     = function(...) list    (setter,...) end,
        show     = function(...) show    (setter,...) end,
    }
    data[name] = setter
    return setter
end

trackers    = setters.new("trackers")
directives  = setters.new("directives")
experiments = setters.new("experiments")

local t_enable, t_disable, t_report = trackers   .enable, trackers   .disable, trackers   .report
local d_enable, d_disable, d_report = directives .enable, directives .disable, directives .report
local e_enable, e_disable, e_report = experiments.enable, experiments.disable, experiments.report

-- nice trick: we overload two of the directives related functions with variants that
-- do tracing (itself using a tracker) .. proof of concept

local trace_directives  = false local trace_directives  = false  trackers.register("system.directives",  function(v) trace_directives  = v end)
local trace_experiments = false local trace_experiments = false  trackers.register("system.experiments", function(v) trace_experiments = v end)

function directives.enable(...)
    if trace_directives then
        d_report("enabling: %s",concat({...}," "))
    end
    d_enable(...)
end

function directives.disable(...)
    if trace_directives then
        d_report("disabling: %s",concat({...}," "))
    end
    d_disable(...)
end

function experiments.enable(...)
    if trace_experiments then
        e_report("enabling: %s",concat({...}," "))
    end
    e_enable(...)
end

function experiments.disable(...)
    if trace_experiments then
        e_report("disabling: %s",concat({...}," "))
    end
    e_disable(...)
end

-- a useful example

directives.register("system.nostatistics", function(v)
    statistics.enable = not v
end)

directives.register("system.nolibraries", function(v)
    libraries = nil -- we discard this tracing for security
end)

-- experiment

local flags = environment and environment.engineflags

if flags then
    if trackers and flags.trackers then
        setters.initialize("flags","trackers", settings_to_hash(flags.trackers))
     -- t_enable(flags.trackers)
    end
    if directives and flags.directives then
        setters.initialize("flags","directives", settings_to_hash(flags.directives))
     -- d_enable(flags.directives)
    end
end

-- here

if texconfig then

    -- this happens too late in ini mode but that is no problem

    local function set(k,v)
        v = tonumber(v)
        if v then
            texconfig[k] = v
        end
    end

    directives.register("luatex.expanddepth",  function(v) set("expand_depth",v)   end)
    directives.register("luatex.hashextra",    function(v) set("hash_extra",v)     end)
    directives.register("luatex.nestsize",     function(v) set("nest_size",v)      end)
    directives.register("luatex.maxinopen",    function(v) set("max_in_open",v)    end)
    directives.register("luatex.maxprintline", function(v) set("max_print_line",v) end)
    directives.register("luatex.maxstrings",   function(v) set("max_strings",v)    end)
    directives.register("luatex.paramsize",    function(v) set("param_size",v)     end)
    directives.register("luatex.savesize",     function(v) set("save_size",v)      end)
    directives.register("luatex.stacksize",    function(v) set("stack_size",v)     end)

end
