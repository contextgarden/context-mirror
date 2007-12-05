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
    'error', 'warning', 'info', 'debug', 'report',
    'start', 'stop', 'push', 'pop'
}

logs.callbacks  = {
    'start_page_number',
    'stop_page_number',
    'report_output_pages',
    'report_output_log'
}

logs.xml = logs.xml or { }
logs.tex = logs.tex or { }

logs.level = 0

do
    local write_nl, write, format = texio.write_nl or print, texio.write or io.write, string.format

    if texlua then
        write_nl = print
        write    = io.write
    end

    function logs.xml.debug(category,str)
        if logs.level > 3 then write_nl(format("<d category='%s'>%s</d>",category,str)) end
    end
    function logs.xml.info(category,str)
        if logs.level > 2 then write_nl(format("<i category='%s'>%s</i>",category,str)) end
    end
    function logs.xml.warning(category,str)
        if logs.level > 1 then write_nl(format("<w category='%s'>%s</w>",category,str)) end
    end
    function logs.xml.error(category,str)
        if logs.level > 0 then write_nl(format("<e category='%s'>%s</e>",category,str)) end
    end
    function logs.xml.report(category,str)
        write_nl(format("<r category='%s'>%s</r>",category,str))
    end

    function logs.xml.start() if logs.level > 0 then tw("<%s>" ) end end
    function logs.xml.stop () if logs.level > 0 then tw("</%s>") end end
    function logs.xml.push () if logs.level > 0 then tw("<!-- ") end end
    function logs.xml.pop  () if logs.level > 0 then tw(" -->" ) end end

    function logs.tex.debug(category,str)
        if logs.level > 3 then write_nl(format("debug >> %s: %s"  ,category,str)) end
    end
    function logs.tex.info(category,str)
        if logs.level > 2 then write_nl(format("info >> %s: %s"   ,category,str)) end
    end
    function logs.tex.warning(category,str)
        if logs.level > 1 then write_nl(format("warning >> %s: %s",category,str)) end
    end
    function logs.tex.error(category,str)
        if logs.level > 0 then write_nl(format("error >> %s: %s"  ,category,str)) end
    end
    function logs.tex.report(category,str)
        write_nl(format("report >> %s: %s"  ,category,str))
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

end

logs.set_level('error')
logs.set_method('tex')
