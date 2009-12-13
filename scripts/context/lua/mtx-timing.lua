if not modules then modules = { } end modules ['mtx-timing'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gsub, concat = string.format, string.gsub, table.concat

dofile(resolvers.find_file("trac-tim.lua","tex"))
dofile(resolvers.find_file("trac-lmx.lua","tex"))

local meta = [[
    beginfig(%s) ;
        begingroup ;
            save p, q, b, h, w ;
            path p, q, b ; numeric h, w ;
            linecap := butt ;
            h := 100 ;
            w := 800pt ;
            p := %s ;
            q := %s ;
            p := p shifted -llcorner p ;
            q := q shifted -llcorner q ;
            q := q xstretched w ;
            p := p xstretched w ;
            b := boundingbox (llcorner p -- llcorner p shifted (w,h)) ;
            draw b withcolor white withpen pencircle scaled 4pt ;
            draw p withcolor red   withpen pencircle scaled 4pt ;
            draw q withcolor blue  withpen pencircle scaled 2pt ;
        endgroup ;
    endfig ;
]]

local html_graphic = [[
    <h1><a name='graphic-%s'>%s (red) %s (blue)</a></h1>
    <table>
        <tr>
            <td>%s</td>
            <td valign='top'>
                &nbsp;&nbsp;min: %s<br/>
                &nbsp;&nbsp;max: %s<br/>
                &nbsp;&nbsp;pages: %s<br/>
                &nbsp;&nbsp;average: %s<br/>
            </td>
        </tr>
    </table>
    <br/>
]]

local html_menu = [[
    <a href='#graphic-%s'>%s</a>
]]

local directrun = true

function goodies.progress.make_svg(filename,other)
    local metadata, menudata, c = { }, { }, 0
    metadata[#metadata+1] = 'outputformat := "svg" ;'
    for _, kind in pairs { "parameters", "nodes" } do
        local mdk = { }
        menudata[kind] = mdk
        for n, name in pairs(goodies.progress[kind](filename)) do
            local first = goodies.progress.path(filename,name)
            local second = goodies.progress.path(filename,other)
            c = c + 1
            metadata[#metadata+1] = format(meta,c,first,second)
            mdk[#mdk+1] = { name, c }
        end
    end
    metadata[#metadata+1] = "end ."
    metadata = concat(metadata,"\n\n")
    if directrun then
        dofile(resolvers.find_file("mlib-run.lua","tex"))
        commands = commands or { }
        commands.writestatus = logs.report
        local result = metapost.directrun("metafun","timing data","svg",true,metadata)
        return menudata, result
    else
        local mpname = file.replacesuffix(filename,"mp")
        io.savedata(mpname,metadata)
        os.execute(format("mpost --progname=context --mem=metafun.mem %s",mpname))
        os.remove(mpname)
        os.remove(file.removesuffix(filename).."-mpgraph.mpo") -- brr
        os.remove(file.removesuffix(filename)..".log") -- brr
        return menudata
    end
end

function goodies.progress.makehtml(filename,other,menudata,metadata)
    local graphics = { }
    local result = { graphics = graphics }
    for _, kind in pairs { "parameters", "nodes" } do
        local md = menudata[kind]
        local menu = { }
        result[kind] = menu
        for k, v in ipairs(md) do
            local name, number = v[1], v[2]
            local min     = goodies.progress.bot(filename,name)
            local max     = goodies.progress.top(filename,name)
            local pages   = goodies.progress.pages(filename)
            local average = math.round(max/pages)
            if directrun then
                local data = metadata[number]
                menu[#menu+1] = format(html_menu,name,name)
                graphics[#graphics+1] = format(html_graphic,name,name,other,data,min,max,pages,average)
            else
                local mpname = file.replacesuffix(filename,number)
                local data = io.loaddata(mpname) or ""
            --  data = gsub(data,"<!%-%-(.-)%-%->[\n\r]*","")
                data = gsub(data,"<%?xml.->","")
                menu[#menu+1] = format(html_menu,name,name)
                graphics[#graphics+1] = format(html_graphic,name,name,other,data,min,max,pages,average)
                os.remove(mpname)
            end
        end
    end
    return result
end

function goodies.progress.valid_file(name)
    return name and name ~= "" and lfs.isfile(name .. "-luatex-progress.lut")
end

function goodies.progress.make_lmx_page(name,launch,remove)

    local filename = name .. "-luatex-progress"
    local other    = "elapsed_time"
    local template = 'context-timing.lmx'

    goodies.progress.convert(filename)

    local menudata, metadata = goodies.progress.make_svg(filename,other)
    local htmldata = goodies.progress.makehtml(filename,other,menudata,metadata)

    lmx.htmfile = function(name) return name .. "-timing.xhtml" end
    lmx.lmxfile = function(name) return resolvers.find_file(name,'tex') end

    local variables = {
        ['title-default']        = 'ConTeXt Timing Information',
        ['title']                = format('ConTeXt Timing Information: %s',file.basename(name)),
        ['parametersmenu']       = concat(htmldata.parameters, "&nbsp;&nbsp;"),
        ['nodesmenu']            = concat(htmldata.nodes, "&nbsp;&nbsp;"),
        ['graphics']             = concat(htmldata.graphics, "\n\n"),
        ['color-background-one'] = lmx.get('color-background-green'),
        ['color-background-two'] = lmx.get('color-background-blue'),
    }

    if launch then
        local htmfile = lmx.show(template,variables)
        if remove then
            os.sleep(1) -- give time to launch
            os.remove(htmfile)
        end
    else
        lmx.make(template,variables)
    end

end

scripts         = scripts         or { }
scripts.timings = scripts.timings or { }

function scripts.timings.xhtml(filename)
    if filename == "" then
        logs.simple("provide filename")
    elseif not goodies.progress.valid_file(filename) then
        logs.simple("first run context again with the --timing option")
    else
        local basename = file.removesuffix(filename)
        local launch   = environment.argument("launch")
        local remove   = environment.argument("remove")
        goodies.progress.make_lmx_page(basename,launch,remove)
    end
end

logs.extendbanner("ConTeXt Timing Tools 0.10",true)

messages.help = [[
--xhtml               make xhtml file
--launch              launch after conversion
--remove              remove after launching
]]

if environment.argument("xhtml") then
    scripts.timings.xhtml(environment.files[1] or "")
else
    logs.help(messages.help)
end
