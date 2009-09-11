if not modules then modules = { } end modules ['luat-run'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, rpadd = string.format, string.rpadd

main = main or { }

local start_actions = { }
local stop_actions  = { }

function main.register_start_actions(...) table.insert(start_actions, ...) end
function main.register_stop_actions (...) table.insert(stop_actions,  ...) end

main.show_tex_stat = main.show_tex_stat or function() end
main.show_job_stat = main.show_job_stat or statistics.show_job_stat

function main.start()
    if logs.start_run then
        logs.start_run()
    end
    for _, action in next, start_actions do
        action()
    end
end

function main.stop()
    for _, action in next, stop_actions do
        action()
    end
    if main.show_job_stat then
        statistics.show(logs.report_job_stat)
    end
    if main.show_tex_stat then
        for k,v in next, status.list() do
            logs.report_tex_stat(k,v)
        end
    end
    if logs.stop_run then
        logs.stop_run()
    end
end

function main.start_shipout_page()
    logs.start_page_number()
end

function main.stop_shipout_page()
    logs.stop_page_number()
end

function main.report_output_pages()
end

function main.report_output_log()
end

-- this can be done later

callback.register('start_run',           main.start)
callback.register('stop_run',            main.stop)
callback.register('report_output_pages', main.report_output_pages)
callback.register('report_output_log'  , main.report_output_log)
callback.register('start_page_number'  , main.start_shipout_page)
callback.register('stop_page_number'   , main.stop_shipout_page)
