if not modules then modules = { } end modules ['trac-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- xml logging is only usefull in normal runs, not in ini mode
-- it looks like some tex logging (like filenames) is broken (no longer
-- interceoted at the tex end so the xml variant is not that useable now)

--~ io.stdout:setvbuf("no")
--~ io.stderr:setvbuf("no")

local write_nl, write = texio and texio.write_nl or print, texio and texio.write or io.write
local format, gmatch = string.format, string.gmatch
local texcount = tex and tex.count

--[[ldx--
<p>This is a prelude to a more extensive logging module. For the sake
of parsing log files, in addition to the standard logging we will
provide an <l n='xml'/> structured file. Actually, any logging that
is hooked into callbacks will be \XML\ by default.</p>
--ldx]]--

logs = logs or { }

--[[ldx--
<p>This looks pretty ugly but we need to speed things up a bit.</p>
--ldx]]--

local moreinfo = [[
More information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

local functions = {
    'report', 'status', 'start', 'stop', 'push', 'pop', 'line', 'direct',
    'start_run', 'stop_run',
    'start_page_number', 'stop_page_number',
    'report_output_pages', 'report_output_log',
    'report_tex_stat', 'report_job_stat',
    'show_open', 'show_close', 'show_load',
    'dummy',
}

local method = "nop"

function logs.set_method(newmethod)
    method = newmethod
    -- a direct copy might be faster but let's try this for a while
    setmetatable(logs, { __index = logs[method] })
end

function logs.get_method()
    return method
end

-- installer

local data = { }

function logs.new(category)
    local logger = data[category]
    if not logger then
        logger = function(...)
            logs.report(category,...)
        end
        data[category] = logger
    end
    return logger
end

--~ local report = logs.new("fonts")


-- nop logging (maybe use __call instead)

local noplog = { } logs.nop = noplog  setmetatable(logs, { __index = noplog })

for i=1,#functions do
    noplog[functions[i]] = function() end
end

-- tex logging

local texlog = { }  logs.tex = texlog  setmetatable(texlog, { __index = noplog })

function texlog.report(a,b,c,...)
    if c then
        write_nl(format("%-16s> %s\n",a,format(b,c,...)))
    elseif b then
        write_nl(format("%-16s> %s\n",a,b))
    else
        write_nl(format("%-16s>\n",a))
    end
end

function texlog.status(a,b,c,...)
    if c then
        write_nl(format("%-16s: %s\n",a,format(b,c,...)))
    elseif b then
        write_nl(format("%-16s: %s\n",a,b)) -- b can have %'s
    else
        write_nl(format("%-16s:>\n",a))
    end
end

function texlog.line(fmt,...) -- new
    if fmt then
        write_nl(format(fmt,...))
    else
        write_nl("")
    end
end

local real, user, sub

function texlog.start_page_number()
    real, user, sub = texcount.realpageno, texcount.userpageno, texcount.subpageno
end

local report_pages = logs.new("pages") -- not needed but saves checking when we grep for it

function texlog.stop_page_number()
    if real > 0 then
        if user > 0 then
            if sub > 0 then
                report_pages("flushing realpage %s, userpage %s, subpage %s",real,user,sub)
            else
                report_pages("flushing realpage %s, userpage %s",real,user)
            end
        else
            report_pages("flushing realpage %s",real)
        end
    else
        report_pages("flushing page")
    end
    io.flush()
end

texlog.report_job_stat = statistics and statistics.show_job_stat

-- xml logging

local xmllog = { }  logs.xml = xmllog  setmetatable(xmllog, { __index = noplog })

function xmllog.report(category,fmt,s,...) -- new
    if s then
        write_nl(format("<r category='%s'>%s</r>",category,format(fmt,s,...)))
    elseif fmt then
        write_nl(format("<r category='%s'>%s</r>",category,fmt))
    else
        write_nl(format("<r category='%s'/>",category))
    end
end

function xmllog.status(category,fmt,s,...)
    if s then
        write_nl(format("<s category='%s'>%s</r>",category,format(fmt,s,...)))
    elseif fmt then
        write_nl(format("<s category='%s'>%s</r>",category,fmt))
    else
        write_nl(format("<s category='%s'/>",category))
    end
end

function xmllog.line(fmt,...) -- new
    if fmt then
        write_nl(format("<r>%s</r>",format(fmt,...)))
    else
        write_nl("<r/>")
    end
end

function xmllog.start() write_nl("<%s>" ) end
function xmllog.stop () write_nl("</%s>") end
function xmllog.push () write_nl("<!-- ") end
function xmllog.pop  () write_nl(" -->" ) end

function xmllog.start_run()
    write_nl("<?xml version='1.0' standalone='yes'?>")
    write_nl("<job>") --  xmlns='www.pragma-ade.com/luatex/schemas/context-job.rng'
    write_nl("")
end

function xmllog.stop_run()
    write_nl("</job>")
end

function xmllog.start_page_number()
    write_nl(format("<p real='%s' page='%s' sub='%s'", texcount.realpageno, texcount.userpageno, texcount.subpageno))
end

function xmllog.stop_page_number()
    write("/>")
    write_nl("")
end

function xmllog.report_output_pages(p,b)
    write_nl(format("<v k='pages' v='%s'/>", p))
    write_nl(format("<v k='bytes' v='%s'/>", b))
    write_nl("")
end

function xmllog.report_output_log()
    -- nothing
end

function xmllog.report_tex_stat(k,v)
    write_nl("log","<v k='"..k.."'>"..tostring(v).."</v>")
end

local nesting = 0

function xmllog.show_open(name)
    nesting = nesting + 1
    write_nl(format("<f l='%s' n='%s'>",nesting,name))
end

function xmllog.show_close(name)
    write("</f> ")
    nesting = nesting - 1
end

function xmllog.show_load(name)
    write_nl(format("<f l='%s' n='%s'/>",nesting+1,name))
end

-- initialization

if tex and (tex.jobname or tex.formatname) then
    -- todo: this can be set in mtxrun ... or maybe we should just forget about this alternative format
    if (os.getenv("mtx.directives.logmethod") or os.getenv("mtx_directives_logmethod")) == "xml" then
        logs.set_method('xml')
    else
        logs.set_method('tex')
    end
else
    logs.set_method('nop')
end

-- logging in runners -> these are actually the nop loggers

local name, banner = 'report', 'context'

function noplog.report(category,fmt,...) -- todo: fmt,s
    if fmt then
        write_nl(format("%s | %s: %s",name,category,format(fmt,...)))
    elseif category then
        write_nl(format("%s | %s",name,category))
    else
        write_nl(format("%s |",name))
    end
end

noplog.status = noplog.report -- just to be sure, never used

function noplog.simple(fmt,...) -- todo: fmt,s
    if fmt then
        write_nl(format("%s | %s",name,format(fmt,...)))
    else
        write_nl(format("%s |",name))
    end
end

if utils then
    utils.report = function(...) logs.simple(...) end
end

function logs.setprogram(newname,newbanner)
    name, banner = newname, newbanner
end

function logs.extendbanner(newbanner)
    banner = banner .. " | ".. newbanner
end

function logs.reportlines(str) -- todo: <lines></lines>
    for line in gmatch(str,"(.-)[\n\r]") do
        logs.report(line)
    end
end

function logs.reportline() -- for scripts too
    logs.report()
end

function logs.simpleline()
    logs.report()
end

function logs.simplelines(str) -- todo: <lines></lines>
    for line in gmatch(str,"(.-)[\n\r]") do
        logs.simple(line)
    end
end

function logs.reportbanner() -- for scripts too
    logs.report(banner)
end

function logs.help(message,option)
    logs.reportbanner()
    logs.reportline()
    logs.reportlines(message)
    if option ~= "nomoreinfo" then
        logs.reportline()
        logs.reportlines(moreinfo)
    end
end

-- logging to a file

--~ local syslogname = "oeps.xxx"
--~
--~ for i=1,10 do
--~     logs.system(syslogname,"context","test","fonts","font %s recached due to newer version (%s)","blabla","123")
--~ end

function logs.system(whereto,process,jobname,category,...)
    local message = format("%s %s => %s => %s => %s\r",os.date("%d/%m/%y %H:%m:%S"),process,jobname,category,format(...))
    for i=1,10 do
        local f = io.open(whereto,"a")
        if f then
            f:write(message)
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

-- bonus

function logs.fatal(where,...)
    logs.report(where,"fatal error: %s, aborting now",format(...))
    os.exit()
end

--~ the traditional tex page number logging
--~
--~ function logs.tex.start_page_number()
--~     local real, user, sub = texcount.realpageno, texcount.userpageno, texcount.subpageno
--~     if real > 0 then
--~         if user > 0 then
--~             if sub > 0 then
--~                 write(format("[%s.%s.%s",real,user,sub))
--~             else
--~                 write(format("[%s.%s",real,user))
--~             end
--~         else
--~             write(format("[%s",real))
--~         end
--~     else
--~         write("[-")
--~     end
--~ end
--~
--~ function logs.tex.stop_page_number()
--~     write("]")
--~ end
