if not modules then modules = { } end modules ['luat-run'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, rpadd = string.format, string.rpadd

luatex = luatex or { }

local start_actions = { }
local stop_actions  = { }

function luatex.register_start_actions(...) table.insert(start_actions, ...) end
function luatex.register_stop_actions (...) table.insert(stop_actions,  ...) end

luatex.show_tex_stat = luatex.show_tex_stat or function() end
luatex.show_job_stat = luatex.show_job_stat or statistics.show_job_stat

function luatex.start_run()
    if logs.start_run then
        logs.start_run()
    end
    for _, action in next, start_actions do
        action()
    end
end

function luatex.stop_run()
    for _, action in next, stop_actions do
        action()
    end
    if luatex.show_job_stat then
        statistics.show(logs.report_job_stat)
    end
    if luatex.show_tex_stat then
        for k,v in next, status.list() do
            logs.report_tex_stat(k,v)
        end
    end
    if logs.stop_run then
        logs.stop_run()
    end
end

function luatex.start_shipout_page()
    logs.start_page_number()
end

function luatex.stop_shipout_page()
    logs.stop_page_number()
end

function luatex.report_output_pages()
end

function luatex.report_output_log()
end

-- this can be done later

callbacks.register('start_run',             luatex.start_run,           "actions performed at the beginning of a run")
callbacks.register('stop_run',              luatex.stop_run,            "actions performed at the end of a run")

callbacks.register('report_output_pages',   luatex.report_output_pages, "actions performed when reporting pages")
callbacks.register('report_output_log',     luatex.report_output_log,   "actions performed when reporting log file")

callbacks.register('start_page_number',     luatex.start_shipout_page,  "actions performed at the beginning of a shipout")
callbacks.register('stop_page_number',      luatex.stop_shipout_page,   "actions performed at the end of a shipout")

callbacks.register('process_input_buffer',  false,                      "actions performed when reading data")
callbacks.register('process_output_buffer', false,                      "actions performed when writing data")
