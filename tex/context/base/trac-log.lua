if not modules then modules = { } end modules ['luat-log'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is old code that needs an overhaul

local write_nl, write, format = texio.write_nl or print, texio.write or io.write, string.format

if texlua then
    write_nl = print
    write    = io.write
end

--[[ldx--
<p>This is a prelude to a more extensive logging module. For the sake
of parsing log files, in addition to the standard logging we will
provide an <l n='xml'/> structured file. Actually, any logging that
is hooked into callbacks will be \XML\ by default.</p>
--ldx]]--

logs     = logs     or { }
logs.xml = logs.xml or { }
logs.tex = logs.tex or { }

--[[ldx--
<p>This looks pretty ugly but we need to speed things up a bit.</p>
--ldx]]--

logs.moreinfo = [[
more information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

logs.levels = {
    ['error']   = 1,
    ['warning'] = 2,
    ['info']    = 3,
    ['debug']   = 4,
}

logs.functions = {
    'report', 'start', 'stop', 'push', 'pop', 'line', 'direct',
    'start_run', 'stop_run',
    'start_page_number', 'stop_page_number',
    'report_output_pages', 'report_output_log',
    'report_tex_stat', 'report_job_stat',
    'show_open', 'show_close', 'show_load',
}

logs.tracers = {
}

logs.level = 0
logs.mode  = string.lower((os.getenv("MTX.LOG.MODE") or os.getenv("MTX_LOG_MODE") or "tex"))

function logs.set_level(level)
    logs.level = logs.levels[level] or level
end

function logs.set_method(method)
    for _, v in next, logs.functions do
        logs[v] = logs[method][v] or function() end
    end
end

-- tex logging

function logs.tex.report(category,fmt,...) -- new
    if fmt then
        write_nl(category .. " | " .. format(fmt,...))
    else
        write_nl(category .. " |")
    end
end

function logs.tex.line(fmt,...) -- new
    if fmt then
        write_nl(format(fmt,...))
    else
        write_nl("")
    end
end

local texcount = tex and tex.count

function logs.tex.start_page_number()
    local real, user, sub = texcount[0], texcount[1], texcount[2]
    if real > 0 then
        if user > 0 then
            if sub > 0 then
                write(format("[%s.%s.%s",real,user,sub))
            else
                write(format("[%s.%s",real,user))
            end
        else
            write(format("[%s",real))
        end
    else
        write("[-")
    end
end

function logs.tex.stop_page_number()
    write("]")
end

logs.tex.report_job_stat = statistics.show_job_stat

-- xml logging

function logs.xml.report(category,fmt,...) -- new
    if fmt then
        write_nl(format("<r category='%s'>%s</r>",category,format(fmt,...)))
    else
        write_nl(format("<r category='%s'/>",category))
    end
end
function logs.xml.line(fmt,...) -- new
    if fmt then
        write_nl(format("<r>%s</r>",format(fmt,...)))
    else
        write_nl("<r/>")
    end
end

function logs.xml.start() if logs.level > 0 then tw("<%s>" ) end end
function logs.xml.stop () if logs.level > 0 then tw("</%s>") end end
function logs.xml.push () if logs.level > 0 then tw("<!-- ") end end
function logs.xml.pop  () if logs.level > 0 then tw(" -->" ) end end

function logs.xml.start_run()
    write_nl("<?xml version='1.0' standalone='yes'?>")
    write_nl("<job>") --  xmlns='www.pragma-ade.com/luatex/schemas/context-job.rng'
    write_nl("")
end

function logs.xml.stop_run()
    write_nl("</job>")
end

function logs.xml.start_page_number()
    write_nl(format("<p real='%s' page='%s' sub='%s'", texcount[0], texcount[1], texcount[2]))
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

function logs.xml.report_tex_stat(k,v)
    texiowrite_nl("log","<v k='"..k.."'>"..tostring(v).."</v>")
end

local level = 0

function logs.xml.show_open(name)
    level = level + 1
    texiowrite_nl(format("<f l='%s' n='%s'>",level,name))
end

function logs.xml.show_close(name)
    texiowrite("</f> ")
    level = level - 1
end

function logs.xml.show_load(name)
    texiowrite_nl(format("<f l='%s' n='%s'/>",level+1,name))
end

--

local name, banner = 'report', 'context'

local function report(category,fmt,...)
    if fmt then
        write_nl(format("%s | %s: %s",name,category,format(fmt,...)))
    elseif category then
        write_nl(format("%s | %s",name,category))
    else
        write_nl(format("%s |",name))
    end
end

local function simple(fmt,...)
    if fmt then
        write_nl(format("%s | %s",name,format(fmt,...)))
    else
        write_nl(format("%s |",name))
    end
end

function logs.setprogram(_name_,_banner_,_verbose_)
    name, banner = _name_, _banner_
    if _verbose_ then
        trackers.enable("resolvers.verbose")
    end
    logs.set_method("tex")
    logs.report = report -- also used in libraries
    logs.simple = simple -- only used in scripts !
    if utils then
        utils.report = simple
    end
    logs.verbose = _verbose_
end

function logs.setverbose(what)
    if what then
        trackers.enable("resolvers.verbose")
    else
        trackers.disable("resolvers.verbose")
    end
    logs.verbose = what or false
end

function logs.extendbanner(_banner_,_verbose_)
    banner = banner .. " | ".. _banner_
    if _verbose_ ~= nil then
        logs.setverbose(what)
    end
end

logs.verbose = false
logs.report  = logs.tex.report
logs.simple  = logs.tex.report

function logs.reportlines(str) -- todo: <lines></lines>
    for line in str:gmatch("(.-)[\n\r]") do
        logs.report(line)
    end
end

function logs.reportline() -- for scripts too
    logs.report()
end

logs.simpleline = logs.reportline

function logs.help(message,option)
    logs.report(banner)
    logs.reportline()
    logs.reportlines(message)
    local moreinfo = logs.moreinfo or ""
    if moreinfo ~= "" and option ~= "nomoreinfo" then
        logs.reportline()
        logs.reportlines(moreinfo)
    end
end

logs.set_level('error')
logs.set_method('tex')

function logs.system(whereto,process,jobname,category,...)
    for i=1,10 do
        local f = io.open(whereto,"a")
        if f then
            f:write(format("%s %s => %s => %s => %s\r",os.date("%d/%m/%y %H:%m:%S"),process,jobname,category,format(...)))
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

--~ local syslogname = "oeps.xxx"
--~
--~ for i=1,10 do
--~     logs.system(syslogname,"context","test","fonts","font %s recached due to newer version (%s)","blabla","123")
--~ end
