if not modules then modules = { } end modules ['luat-log'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is a prelude to a more extensive logging module. For the sake
of parsing log files, in addition to the standard logging we will
provide an <l n='xml'/> structured file. Actually, any logging that
is hooked into callbacks will be \XML\ by default.</p>
--ldx]]--

-- input.logger -> special tracing, driven by log level (only input)
-- input.report -> goes to terminal, depends on verbose, has banner
-- logs.report  -> module specific tracing and reporting, no banner but class


input = input or { }
logs  = logs  or { }

--[[ldx--
<p>This looks pretty ugly but we need to speed things up a bit.</p>
--ldx]]--

logs.levels = {
    ['error']   = 1,
    ['warning'] = 2,
    ['info']    = 3,
    ['debug']   = 4
}

logs.functions = {
    'report', 'start', 'stop', 'push', 'pop', 'line', 'direct'
}

logs.callbacks  = {
    'start_page_number',
    'stop_page_number',
    'report_output_pages',
    'report_output_log'
}

logs.tracers = {
}

logs.xml = logs.xml or { }
logs.tex = logs.tex or { }

logs.level = 0

local write_nl, write, format = texio.write_nl or print, texio.write or io.write, string.format

if texlua then
    write_nl = print
    write    = io.write
end

function logs.xml.report(category,fmt,...) -- new
    write_nl(format("<r category='%s'>%s</r>",category,format(fmt,...)))
end
function logs.xml.line(fmt,...) -- new
    write_nl(format("<r>%s</r>",format(fmt,...)))
end

function logs.xml.start() if logs.level > 0 then tw("<%s>" ) end end
function logs.xml.stop () if logs.level > 0 then tw("</%s>") end end
function logs.xml.push () if logs.level > 0 then tw("<!-- ") end end
function logs.xml.pop  () if logs.level > 0 then tw(" -->" ) end end

function logs.tex.report(category,fmt,...) -- new
 -- write_nl(format("%s | %s",category,format(fmt,...))) -- arg to format can be tex comment so .. .
    write_nl(category .. " | " .. format(fmt,...))
end
function logs.tex.line(fmt,...) -- new
    write_nl(format(fmt,...))
end

function logs.set_level(level)
    logs.level = logs.levels[level] or level
end

function logs.set_method(method)
    for _, v in pairs(logs.functions) do
        logs[v] = logs[method][v] or function() end
    end
    if callback and input[method] then
        for _, cb in pairs(logs.callbacks) do
            callback.register(cb, input[method][cb])
        end
    end
end

function logs.xml.start_page_number()
    write_nl(format("<p real='%s' page='%s' sub='%s'", tex.count[0], tex.count[1], tex.count[2]))
end

function logs.xml.stop_page_number()
    write("/>")
    write_nl("")
end

function logs.xml.report_output_pages(p,b)
    write_nl(format("<v k='pages' v='%s'/>", p))
    write_nl(format("<v k='bytes' v='%s'/>", b))
    write_nl("")
end

function logs.xml.report_output_log()
end

function input.logger(...) -- assumes test for input.trace > n
    if input.trace > 0 then
        logs.report(...)
    end
end

function input.report(fmt,...)
    if input.verbose then
        logs.report(input.banner or "report",format(fmt,...))
    end
end

function input.reportlines(str) -- todo: <lines></lines>
    for line in str:gmatch("(.-)[\n\r]") do
        logs.report(input.banner or "report",line)
    end
end

input.moreinfo = [[
more information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

function input.help(banner,message)
    if not input.verbose then
        input.verbose = true
    --  input.report(banner,"\n")
    end
    input.report(banner,"\n")
    input.report("")
    input.reportlines(message)
    if input.moreinfo and input.moreinfo ~= "" then
        input.report("")
        input.reportlines(input.moreinfo)
    end
end

logs.set_level('error')
logs.set_method('tex')
