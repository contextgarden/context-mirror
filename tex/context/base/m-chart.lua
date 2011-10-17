if not modules then modules = { } end modules ['x-flow'] = {
    version   = 1.001,
    comment   = "companion to m-flow.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when we can resolve mpcolor at the lua end we will use metapost.graphic(....) directly

moduledata.charts = moduledata.charts or { }

local gsub, match, find, format, lower = string.gsub, string.match, string.find, string.format, string.lower
local lpegmatch = lpeg.match

local points = number.points
local variables = interfaces.variables

local defaults = {
    chart = {
        name            = "",
        option          = "",
        backgroundcolor = "",
        width           = 0,
        height          = 0,
        dx              = 0,
        dy              = 0,
        offset          = 0,
        bodyfont        = "",
        dot             = "",
    },
    shape = { -- FLOS
        rulethickness   = 65436,
        default         = "",
        framecolor      = "green",
        backgroundcolor = "yellow",
    },
    focus = { -- FLOF
        rulethickness   = 65436,
        framecolor      = "red",
        backgroundcolor = "yellow",
    },
    line = { -- FLOL
        rulethickness   = 65436,
        radius          = 65436,
        color           = "blue",
        corner          = "",
        dash            = "",
        arrow           = "",
        offset          = "",
    },
    set = { -- FLOX
    },
    split = {
        nx      = 3,
        ny      = 3,
        command = "",
        marking = "",
        before  = "",
        after   = "",
    }
}

local validshapes = {
    ["node"]            = { kind = "shape", number =  0 },
    ["action"]          = { kind = "shape", number = 24 },
    ["procedure"]       = { kind = "shape", number =  5 },
    ["product"]         = { kind = "shape", number = 12 },
    ["decision"]        = { kind = "shape", number = 14 },
    ["archive"]         = { kind = "shape", number = 19 },
    ["loop"]            = { kind = "shape", number = 35 },
    ["wait"]            = { kind = "shape", number =  6 },
    ["subprocedure"]    = { kind = "shape", number = 20 },
    ["singledocument"]  = { kind = "shape", number = 32 },
    ["multidocument"]   = { kind = "shape", number = 33 },

    ["right"]           = { kind = "line",  number = 66 },
    ["left"]            = { kind = "line",  number = 67 },
    ["up"]              = { kind = "line",  number = 68 },
    ["down"]            = { kind = "line",  number = 69 },
}

local validlabellocations = {
    l = "l", left   = "l",
    r = "r", right  = "r",
    t = "t", top    = "t",
    b = "b", bottom = "b",
}

table.setmetatableindex(validshapes,function(t,k)
    local l = gsub(lower(k)," ","")
    local v = rawget(t,l)
    if not v then
        local n = tonumber(k)
        if n then
            v = { kind = "shape", number = n }
        else
            v = rawget(t,"action")
        end
    end
    t[k] = v
    return v
end)

local charts = { }

local data, hash, temp, last_x, last_y, name

function commands.flow_start_chart(chartname)
    data = { }
    hash = { }
    last_x, last_y = 0, 0
    name = chartname
end

function commands.flow_stop_chart()
    charts[name] = {
        data = data,
        hash = hash,
        last_x = last_x,
        last_y = last_y,
    }
    data, hash, temp = nil, nil, nil
end

function commands.flow_set_current_cell(n)
    temp = data[tonumber(n)] or { }
end

function commands.flow_start_cell(settings)
    temp = {
        labels      = { },
        comments    = { },
        exits       = { },
        connections = { },
        settings    = settings,
        x           = 1,
        y           = 1,
        name        = "",
    }
end

function commands.flow_stop_cell()
    data[#data+1] = temp
    hash[temp.name or #data] = temp
end

function commands.flow_set_name(str)
    temp.name = str
end

function commands.flow_set_shape(str)
    temp.shape = str
end

function commands.flow_set_destination(str)
    temp.destination = str
end

function commands.flow_set_text(align,str)
    temp.align = align
    temp.text  = str
end

function commands.flow_set_overlay(str)
    temp.overlay = str
end

function commands.flow_set_focus(str)
    temp.focus = str
end

function commands.flow_set_figure(str)
    temp.figure = str
end

function commands.flow_set_label(location,text)
    temp.labels[#temp.labels+1] = {
        location = location,
        text = text,
    }
end

function commands.flow_set_comment(name,str)
    temp.comments[#temp.comments+1] = {
        location = location,
        text = text,
    }
end

function commands.flow_set_exit(location,text)
    temp.exits[#temp.exits+1] = {
        location = location,
        text = text,
    }
end

function commands.flow_set_include(name,x,y,settings)
    data[#data+1] = {
        include  = name,
        x        = x,
        y        = y,
     -- settings = settings,
    }
end

local function inject(includedata,data,hash)
    local subchart = charts[includedata.include]
    if not subchart then
        return
    end
    local subdata = subchart.data
    if not subdata then
        return
    end
    local xoffset  = (includedata.x or 1) - 1
    local yoffset  = (includedata.y or 1) - 1
    local settings = includedata.settings
    for i=1,#subdata do
        local si = subdata[i]
        local t = {
            x        = si.x + xoffset,
            y        = si.y + yoffset,
            settings = settings,
        }
        table.setmetatableindex(t,si)
        data[#data+1] = t
        hash[si.name or #data] = t
    end
end

local function expanded(chart)
    local expandeddata = { }
    local expandedhash = { }
    local expandedchart = {
        data = expandeddata,
        hash = expandedhash,
    }
    table.setmetatableindex(expandedchart,chart)
    local data = chart.data
    local hash = chart.hash
    for i=1,#data do
        local di = data[i]
        if di.include then
            inject(di,expandeddata,expandedhash)
        else
            expandeddata[#expandeddata+1]  = di
            expandedhash[di.name or #expandeddata] = di
        end
    end
    for i=1,#expandeddata do
        local cell = expandeddata[i]
        local settings = cell.settings
        if not settings then
            cell.settings = chart.settings
        else
            table.setmetatableindex(settings,chart.settings)
        end
    end
    return expandedchart
end


local splitter = lpeg.splitat(",")

function commands.flow_set_location(str) -- handle include differently
    -- wrong: delay real x,y, only store relative
    local x, y = lpegmatch(splitter,str)
    if not x or x == "" then
        x = last_x
    elseif x == "+" then
        x = last_x + 1
    elseif x == "-" then
        x = last_x - 1
    elseif find(x,"^[%+%-]") then
        x = last_x + (tonumber(x) or 0)
    else
        x = tonumber(x)
    end
    if not y or y == "" then
        y = last_y
    elseif y == "+" then
        y = last_y + 1
    elseif x == "-" then
        y = last_y - 1
    elseif find(y,"^[%+%-]") then
        y = last_y + (tonumber(y) or 0)
    else
        y = tonumber(y)
    end
    temp.x = x or 1
    temp.y = y or 1
    last_x = x or last_x
    last_y = y or last_y
end

function commands.flow_set_connection(location,displacement,name)
    local dx, dy = lpegmatch(splitter,displacement)
    dx = tonumber(dx) or 1
    dy = tonumber(dy) or 1
    temp.connections[#temp.connections+1] = {
        location = location,
        dx       = dx - 1,
        dy       = dy - 1,
        name     = name,
    }
end

local where = {
    l = "left",
    r = "right",
    t = "top",
    b = "bottom",
}

local what = {
    ["p"] =  1,
    ["m"] = -1,
    ["+"] =  1,
    ["-"] = -1,
}

local function visible(chart,cell)
    local x, y = cell.x, cell.y
    return
        x >= chart.from_x and x <= chart.to_x and
        y >= chart.from_y and y <= chart.to_y and cell
end

local function check_cells(chart,xoffset,yoffset,min_x,min_y,max_x,max_y)
    local data = chart.data
    if not data then
        return
    end
    for i=1,#data do
        local cell = data[i]
        local x, y = cell.x + xoffset, cell.y + yoffset
        if min_x == 0 then
            min_x, max_x = x, x
            min_y, max_y = y, y
        else
            if x < min_x then min_x = x end
            if y < min_y then min_y = y end
            if x > max_x then max_x = x end
            if y > max_y then max_y = y end
        end
    end
    return min_x, min_y, max_x, max_y
end

local function process_cells(chart,xoffset,yoffset)
    local data = chart.data
    if not data then
        return
    end
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local shape = cell.shape
            if not shape or shape == "" then
                shape = settings.shape.default or "none"
            end
            if shape ~= variables.none then
                local settings = cell.settings
                local shapedata = validshapes[shape]
                context("flow_begin_sub_chart ;")
                if shapedata.kind == "line" then
                    local linesettings = settings.line
                    context("flow_shape_line_color := \\MPcolor{%s} ;", linesettings.color)
                    context("flow_shape_fill_color := \\MPcolor{%s} ;", linesettings.backgroundcolor)
                    context("flow_shape_line_width := %s ; ",           points(linesettingsrulethickness))
                elseif hasfocus then -- doifcommonelse{FLOWcell,FLOWfocus}@@FLOWfocus
                    local focussettings = settings.focus
                    context("flow_shape_line_color := \\MPcolor{%s} ;", focussettings.framecolor)
                    context("flow_shape_fill_color := \\MPcolor{%s} ;", focussettings.backgroundcolor)
                    context("flow_shape_line_width := %s ; ",           points(focussettings.rulethickness))
                else
                    local shapesettings = settings.shape
                    context("flow_shape_line_color := \\MPcolor{%s} ;", shapesettings.framecolor)
                    context("flow_shape_fill_color := \\MPcolor{%s} ;", shapesettings.backgroundcolor)
                    context("flow_shape_line_width := %s ; " ,          points(shapesettings.rulethickness))
                end
                context("bodyfontsize := 10pt ;") -- todo
                context("flow_peepshape := false ;")   -- todo
                context("flow_new_shape(%s,%s,%s) ;",cell.x+xoffset,cell.y+yoffset,shapedata.number)
                context("flow_end_sub_chart ;")
            end
        end
    end
end

-- todo : make lpeg for splitter

local function process_connections(chart,xoffset,yoffset)
    local data = chart.data
    local hash = chart.hash
    if not data then
        return
    end
    local settings = chart.settings
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local connections = cell.connections
            for j=1,#connections do
                local connection = connections[j]
                local othername = connection.name
                local othercell = hash[othername]
                if othercell then
                    local cellx, celly = cell.x, cell.y
                    local otherx, othery, location = othercell.x, othercell.y, connection.location
                    if otherx > 0 and othery > 0 and cellx > 0 and celly > 0 and connection.location then
                        -- move to setter
                        local what_cell, where_cell, what_other, where_other = match(location,"([%+%-pm]-)([lrtb]),?([%+%-pm]-)([lrtb])")
                        local what_cell   = what [what_cell]   or 0
                        local what_other  = what [what_other]  or 0
                        local where_cell  = where[where_cell]  or "left"
                        local where_other = where[where_other] or "right"
                        local linesettings = settings.line
                        context("flow_smooth := %s ;", linesettings.corner == variables.round and "true" or "false")
                        context("flow_dashline := %s ;", linesettings.dash == variables.yes and "true" or "false")
                        context("flow_arrowtip := %s ;", linesettings.arrow == variables.yes and "true" or "false")
                        context("flow_touchshape := %s ;", linesettings.offset == variables.none and "true" or "false")
                        context("flow_dsp_x := %s ; flow_dsp_y := %s ;",connection.dx or 0, connection.dy or 0)
                        context("flow_connection_line_color := \\MPcolor{%s} ;",linesettings.color)
                        context("flow_connection_line_width := 2pt ;",points(linesettings.rulethickness))
                        context("flow_connect_%s_%s(%s,%s,%s) (%s,%s,%s) ;",where_cell,where_other,cellx,celly,what_cell,otherx,othery,what_other)
                        context("flow_dsp_x := 0 ; flow_dsp_y := 0 ;")
                    end
                end
            end
        end
    end
end

local texttemplate = "\\setvariables[flowcell:text][x=%s,y=%s,text={%s},align={%s},figure={%s},destination={%s}]"

local function process_texts(chart,xoffset,yoffset)
    local data = chart.data
    local hash = chart.hash
    if not data then
        return
    end
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local x = cell.x or 1
            local y = cell.y or 1
            local text = cell.text
            if text and text ~= "" then
                local a = cell.align or ""
                local f = cell.figure or ""
                local d = cell.destination or ""
                context('flow_chart_draw_text(%s,%s,textext("%s")) ;',x,y,format(texttemplate,x,y,text,a,f,d))
            end
            local labels = cell.labels
            for i=1,#labels do
                local label = labels[i]
                local text = label.text
                local location = validlabellocations[label.location or ""]
                if text and location then
                    context('flow_chart_draw_label_%s(%s,%s,textext("%s")) ;',location,x,y,text)
                end
            end
            local exits = cell.exits
            for i=1,#exits do
                local exit = exits[i]
                local text = exit.text
                local location = validlabellocations[exit.location or ""]
                if text and location then
                    -- maybe make autoexit an option
                    if location == "l" and x == chart.from_x + 1 or
                       location == "r" and x == chart.to_x   - 1 or
                       location == "t" and y == chart.to_y   - 1 or
                       location == "b" and y == chart.from_y + 1 then
                        context('flow_chart_draw_exit_%s(%s,%s,textext("%s")) ;',location,x,y,text)
                    end
                end
            end
            local comments = cell.comments
            for i=1,#comments do
                -- invisible
            end
        end
    end
end

local function getchart(settings)
    local chartname = settings.chart.name
    if not chartname then
        print("no name given")
        return
    end
    local chart = charts[chartname]
    if not chart then
        print("no such chart",chartname)
        return
    end
    chart.settings = settings
    table.setmetatableindex(settings,defaults)
    chart = expanded(chart)
    local _, _, nx, ny = check_cells(chart,0,0,0,0,0,0)
    chart.from_x = chart.settings.chart.x  or 1
    chart.from_y = chart.settings.chart.y  or 1
    chart.to_x   = chart.settings.chart.nx or nx
    chart.to_y   = chart.settings.chart.ny or ny
    chart.nx     = chart.to_x - chart.from_x  + 1
    chart.ny     = chart.to_y - chart.from_y  + 1
    return chart
end

local function makechart(chart)
    local settings = chart.settings
    context.begingroup()
    context.forgetall()
    --
    local bodyfont = settings.chart.bodyfont
    if bodyfont ~= "" then
        context.switchtobodyfont { bodyfont }
    end
    --
    context.startMPcode()
    context("if unknown context_flow : input mp-char.mpiv ; fi ;")
    context("flow_begin_chart(0,%s,%s);",chart.nx,chart.ny)
    --
    if settings.chart.option == variables.test or settings.chart.dot == variables.yes then
        context("flow_show_con_points := true ;")
        context("flow_show_mid_points := true ;")
        context("flow_show_all_points := true ;")
    elseif settings.chart.dot ~= "" then -- no checking done, private option
        context("flow_show_%s_points := true ;",settings.chart.dot)
    end
    --
    local backgroundcolor = settings.chart.backgroundcolor
    if backgroundcolor and backgroundcolor ~= "" then
        context("flow_chart_background_color := \\MPcolor{%s} ;",backgroundcolor)
    end
    --
    local shapewidth  = settings.chart.width
    local gridwidth   = shapewidth + 2*settings.chart.dx
    local shapeheight = settings.chart.height
    local gridheight  = shapeheight + 2*settings.chart.dy
    context("flow_grid_width := %s ;", points(gridwidth))
    context("flow_grid_height := %s ;", points(gridheight))
    context("flow_shape_width := %s ;", points(shapewidth))
    context("flow_shape_height := %s ;", points(shapeheight))
    --
    local radius = settings.line.radius
    local rulethickness = settings.line.rulethickness
    local dx = settings.chart.dx
    local dy = settings.chart.dy
    if radius < rulethickness then
        radius = 2.5*rulethickness
        if radius > dx then
            radius = dx
        end
        if radius > dy then
            radius = dy
        end
    end
    context("flow_connection_line_width := %s ;", points(rulethickness))
    context("flow_connection_smooth_size := %s ;", points(radius))
    context("flow_connection_arrow_size := %s ;", points(radius))
    context("flow_connection_dash_size := %s ;", points(radius))
    --
    local offset = settings.chart.offset -- todo: pass string
    if offset == variables.none or offset == variables.overlay or offset == "" then
        offset = -2.5 * radius -- or rulethickness?
    elseif offset == variables.standard then
        offset = radius -- or rulethickness?
    end
    context("flow_chart_offset := %s ;",points(offset))
    --
    context("flow_reverse_y := true ;")
    process_cells(chart,0,0)
    process_connections(chart,0,0)
    process_texts(chart,0,0)
 -- context("clip_chart(%s,%s,%s,%s) ;",x,y,nx,ny) -- todo: draw lines but not shapes
    context("flow_end_chart ;")
    context.stopMPcode()
    context.endgroup()
end

function commands.flow_make_chart(settings)
    local chart = getchart(settings)
    if chart then
        local settings = chart.settings
        if settings.split.state == variables.start then
            local nx = chart.settings.split.nx
            local ny = chart.settings.split.ny
            local x = 1
            while true do
                local y = 1
                while true do
                    -- FLOTbefore
                    -- doif @@FLOTmarking on -> cuthbox
                    -- @@FLOTcommand
                    chart.from_x = x
                    chart.from_y = y
                    chart.to_x   = math.min(x + nx - 1,chart.nx)
                    chart.to_y   = math.min(x + ny - 1,chart.ny)
                    makechart(chart)
                    -- FLOTafter
                    y = y + ny
                    if y > chart.max_y then
                       break
                    else
                       y = y - dy
                    end
                end
                x = x + nx
                if x > chart.max_x then
                    break
                else
                    x = x - dx
                end
            end
        else
            makechart(chart)
        end
    end
end
