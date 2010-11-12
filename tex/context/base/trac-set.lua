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

local function report(a,b,...)
    texio.write_nl(format("%-16s> %s",a,format(b,...)))
end

function setters.initialize(filename,name,values) -- filename only for diagnostics
    local data = data[name]
    if data then
        data = data.data
        if data then
            for key, value in next, values do
             -- key = gsub(key,"_",".")
                value = is_boolean(value,value)
                local functions = data[key]
                if functions then
                    if #functions > 0 and not functions.value then
                        if trace_initialize then
                            report(name,"executing %s (%s -> %s)",key,filename,tostring(value))
                        end
                        for i=1,#functions do
                            functions[i](value)
                        end
                        functions.value = value
                    else
                        if trace_initialize then
                            report(name,"skipping %s (%s -> %s)",key,filename,tostring(value))
                        end
                    end
                else
                    -- we do a simple preregistration i.e. not in the
                    -- list as it might be an obsolete entry
                    functions = { default = value }
                    data[key] = functions
                    if trace_initialize then
                        report(name,"storing %s (%s -> %s)",key,filename,tostring(value))
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
    for w, value in next, what do
        if value == "" then
            value = newvalue
        elseif not value then
            value = false -- catch nil
        else
            value = is_boolean(value,value)
        end
        for name, functions in next, data do
            if done[name] then
                -- prevent recursion due to wildcards
            elseif find(name,escapedpattern(w,true)) then
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
            report(t.name,"defining %s",what)
        end
    end
    local default = functions.default -- can be set from cnf file
    for _, fnc in next, { ... } do
        local typ = type(fnc)
        if typ == "string" then
            if trace_initialize then
                report(t.name,"coupling %s to %s",what,fnc)
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
    commands.writestatus("","")
    local list = setters.list(t)
    local category = t.name
    for k=1,#list do
        local name = list[k]
        local functions = t.data[name]
        if functions then
            local value, default, modules = functions.value, functions.default, #functions
            value   = value   == nil and "unset" or tostring(value)
            default = default == nil and "unset" or tostring(default)
            commands.writestatus(category,format("%-30s   modules: %2i   default: %5s   value: %5s",name,modules,default,value))
        end
    end
    commands.writestatus("","")
end

-- we could have used a bit of oo and the trackers:enable syntax but
-- there is already a lot of code around using the singular tracker

-- we could make this into a module but we also want the rest avaliable

local enable, disable, register, list, show = setters.enable, setters.disable, setters.register, setters.list, setters.show

function setters.new(name)
    local t -- we need to access it in t
    t = {
        data     = allocate(), -- indexed, but also default and value fields
        name     = name,
        enable   = function(...) enable  (t,...) end,
        disable  = function(...) disable (t,...) end,
        register = function(...) register(t,...) end,
        list     = function(...) list    (t,...) end,
        show     = function(...) show    (t,...) end,
    }
    data[name] = t
    return t
end

trackers    = setters.new("trackers")
directives  = setters.new("directives")
experiments = setters.new("experiments")

local t_enable, t_disable = trackers   .enable, trackers   .disable
local d_enable, d_disable = directives .enable, directives .disable
local e_enable, e_disable = experiments.enable, experiments.disable

-- experiment

if trackers and environment and environment.engineflags.trackers then
    t_enable(environment.engineflags.trackers)
end

if directives and environment and environment.engineflags.directives then
    d_enable(environment.engineflags.directives)
end

-- nice trick: we overload two of the directives related functions with variants that
-- do tracing (itself using a tracker) .. proof of concept

local function report(...) -- messy .. chicken or egg
    local p = (commands and commands.writestatus) or (logs and logs.report)
    if p then p(...) end
end

local trace_directives  = false local trace_directives  = false  trackers.register("system.directives",  function(v) trace_directives  = v end)
local trace_experiments = false local trace_experiments = false  trackers.register("system.experiments", function(v) trace_experiments = v end)

function directives.enable(...)
    report("directives","enabling: %s",concat({...}," "))
    d_enable(...)
end

function directives.disable(...)
    report("directives","disabling: %s",concat({...}," "))
    d_disable(...)
end

function experiments.enable(...)
    report("experiments","enabling: %s",concat({...}," "))
    e_enable(...)
end

function experiments.disable(...)
    report("experiments","disabling: %s",concat({...}," "))
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

if trackers and environment and environment.engineflags.trackers then
    t_enable(environment.engineflags.trackers)
end
if directives and environment and environment.engineflags.directives then
    d_enable(environment.engineflags.directives)
end

-- here

if texconfig then

    local function set(k,v)
        v = tonumber(v)
        if v then
--~     print(k,v)
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
