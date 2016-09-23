if not modules then modules = { } end modules ['luat-run'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find = string.format, string.find
local insert, remove = table.insert, table.remove

-- trace_job_status is also controlled by statistics.enable that is set via the directive system.nostatistics

local trace_lua_dump   = false  trackers.register("system.dump",      function(v) trace_lua_dump   = v end)
local trace_temp_files = false  trackers.register("system.tempfiles", function(v) trace_temp_files = v end)
local trace_job_status = true   trackers.register("system.jobstatus", function(v) trace_job_status = v end)
local trace_tex_status = false  trackers.register("system.texstatus", function(v) trace_tex_status = v end)

local report_lua       = logs.reporter("system","lua")
local report_tex       = logs.reporter("system","status")
local report_tempfiles = logs.reporter("resolvers","tempfiles")

luatex       = luatex or { }
local luatex = luatex

local startactions = { }
local stopactions  = { }
local dumpactions  = { }
local pageactions  = { }

function luatex.registerstartactions(...) insert(startactions, ...) end
function luatex.registerstopactions (...) insert(stopactions,  ...) end
function luatex.registerdumpactions (...) insert(dumpactions,  ...) end
function luatex.registerpageactions (...) insert(pageactions,  ...) end

local function start_run()
    if logs.start_run then
        logs.start_run()
    end
    for i=1,#startactions do
        startactions[i]()
    end
end

local function stop_run()
    for i=1,#stopactions do
        stopactions[i]()
    end
    if trace_job_status then
        statistics.show()
    end
    if trace_tex_status then
        for k, v in table.sortedhash(status.list()) do
            report_tex("%S=%S",k,v)
        end
    end
    if logs.stop_run then
        logs.stop_run()
    end
end

local function start_shipout_page()
    logs.start_page_number()
end

local function stop_shipout_page()
    logs.stop_page_number()
    for i=1,#pageactions do
        pageactions[i]()
    end
end

local function report_output_pages()
end

local function report_output_log()
end

-- local function show_open()
-- end

-- local function show_close()
-- end

local function pre_dump_actions()
    for i=1,#dumpactions do
        dumpactions[i]()
    end
    lua.finalize(trace_lua_dump and report_lua or nil)
 -- statistics.savefmtstatus("\jobname","\contextversion","context.tex")
end

-- this can be done later

callbacks.register('start_run',             start_run,           "actions performed at the beginning of a run")
callbacks.register('stop_run',              stop_run,            "actions performed at the end of a run")

---------.register('show_open',             show_open,           "actions performed when opening a file")
---------.register('show_close',            show_close,          "actions performed when closing a file")

callbacks.register('report_output_pages',   report_output_pages, "actions performed when reporting pages")
callbacks.register('report_output_log',     report_output_log,   "actions performed when reporting log file")

callbacks.register('start_page_number',     start_shipout_page,  "actions performed at the beginning of a shipout")
callbacks.register('stop_page_number',      stop_shipout_page,   "actions performed at the end of a shipout")

callbacks.register('process_input_buffer',  false,               "actions performed when reading data")
callbacks.register('process_output_buffer', false,               "actions performed when writing data")

callbacks.register("pre_dump",              pre_dump_actions,    "lua related finalizers called before we dump the format") -- comes after \everydump

-- an example:

local tempfiles = { }

function luatex.registertempfile(name,extrasuffix,keep) -- namespace might change
    if extrasuffix then
        name = name .. ".mkiv-tmp" -- maybe just .tmp
    end
    if trace_temp_files and not tempfiles[name] then
        report_tempfiles("registering temporary file %a",name)
    end
    tempfiles[name] = keep or false
    return name
end

function luatex.cleanuptempfiles()
    for name, keep in next, tempfiles do
        if not keep then
            if trace_temp_files then
                report_tempfiles("removing temporary file %a",name)
            end
            os.remove(name)
        end
    end
    tempfiles = { }
end

luatex.registerstopactions(luatex.cleanuptempfiles)

-- for the moment here

local report_system = logs.reporter("system")
local synctex       = 0

directives.register("system.synctex", function(v)
    synctex = tonumber(v) or (toboolean(v,true) and 1) or (v == "zipped" and 1) or (v == "unzipped" and -1) or 0
    if synctex ~= 0 then
        report_system("synctex functionality is enabled (%s), expect runtime overhead!",tostring(synctex))
    else
        report_system("synctex functionality is disabled!")
    end
    tex.normalsynctex = synctex
end)

statistics.register("synctex tracing",function()
    if synctex ~= 0 then
        return "synctex has been enabled (extra log file generated)"
    end
end)

-- filenames

local types = {
    "data",
    "font map",
    "image",
    "font subset",
    "full font",
}

local report_open  = logs.reporter("open source")
local report_close = logs.reporter("close source")
local report_load  = logs.reporter("load resource")

local register     = callbacks.register

local level = 0
local total = 0
local stack = { }
local all   = false

local function report_start(left,name)
    if not left then
        -- skip
    elseif left ~= 1 then
        if all then
         -- report_load("%s > %s",types[left],name or "?")
            report_load("type %a, name %a",types[left],name or "?")
        end
    elseif find(name,"virtual://") then
        insert(stack,false)
    else
        insert(stack,name)
        total = total + 1
        level = level + 1
     -- report_open("%i > %i > %s",level,total,name or "?")
        report_open("level %i, order %i, name %a",level,total,name or "?")
    end
end

local function report_stop(right)
    if level == 1 or not right or right == 1 then
        local name = remove(stack)
        if name then
         -- report_close("%i > %i > %s",level,total,name or "?")
            report_close("level %i, order %i, name %a",level,total,name or "?")
            level = level - 1
        end
    end
end

local function report_none()
end

register("start_file",report_start)
register("stop_file", report_stop)

directives.register("system.reportfiles", function(v)
    if v == "noresources" then
        all = false
        register("start_file",report_start)
        register("stop_file", report_stop)
    elseif toboolean(v) or v == "all" then
        all = true
        register("start_file",report_start)
        register("stop_file", report_stop)
    elseif v == "traditional" then
        register("start_file",nil)
        register("stop_file", nil)
    else
        register("start_file",report_none)
        register("stop_file", report_none)
    end
end)

-- start_run doesn't work

-- luatex.registerstartactions(function()
--     if environment.arguments.sandbox then
--         sandbox.enable()
--     end
-- end)

