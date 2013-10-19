if not modules then modules = { } end modules ['x-flow'] = {
    version   = 1.001,
    comment   = "companion to m-flow.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when we can resolve mpcolor at the lua end we will
-- use metapost.graphic(....) directly

-- todo: labels

moduledata.charts = moduledata.charts or { }

local gsub, match, find, format, lower = string.gsub, string.match, string.find, string.format, string.lower
local setmetatableindex = table.setmetatableindex
local P, S, C, Cc, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.match

local report_chart = logs.reporter("chart")

local points     = number.points -- we can use %p instead

local variables  = interfaces.variables

local v_yes      = variables.yes
local v_no       = variables.no
local v_none     = variables.none
local v_standard = variables.standard
local v_overlay  = variables.overlay
local v_round    = variables.round
local v_test     = variables.test

local defaults = {
    chart = {
        name            = "",
        option          = "",
        backgroundcolor = "",
        width           = 100*65536,
        height          = 50*65536,
        dx              = 30*65536,
        dy              = 30*65536,
        offset          = 0,
        bodyfont        = "",
        dot             = "",
        hcompact        = variables_no,
        vcompact        = variables_no,
        autofocus       = "",
        focus           = "",
        labeloffset     = 5*65536,
        commentoffset   = 5*65536,
        exitoffset      = 0,

    },
    shape = { -- FLOS
        rulethickness   = 65536,
        default         = "",
        framecolor      = "darkblue",
        backgroundcolor = "lightgray",
    },
    focus = { -- FLOF
        rulethickness   = 65536,
        framecolor      = "darkred",
        backgroundcolor = "gray",
    },
    line = { -- FLOL
        rulethickness   = 65536,
        radius          = 10*65536,
        color           = "darkgreen",
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
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "tl",
    tr = "tr",
    bl = "bl",
    br = "br",
}

local validcommentlocations = {
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "tl",
    tr = "tr",
    bl = "bl",
    br = "br",
}

local validtextlocations = {
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    c  = "c",  center = "c",
    m  = "c",  middle = "m",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "lt",
    tr = "rt",
    bl = "lb",
    br = "rb",
}

setmetatableindex(validshapes,function(t,k)
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

-- function commands.flow_set(chartname,chartdata)
--     local hash = { }
--     local data = { }
--     charts[name] = {
--         data = data,
--         hash = hash,
--     }
--     for i=1,#chartdata do
--         local di = data[i]
--         local name = di.name or ""
--         if name then
--             data[#data+1] = {
--                 name        = name,
--                 labels      = di.labels      or { },
--                 comments    = di.comments    or { },
--                 exits       = di.exits       or { },
--                 connections = di.connections or { },
--                 settings    = di.settings    or { },
--                 x           = di.x           or 1,
--                 y           = di.y           or 1,
--             }
--             hash[name] = i
--         end
--      end
-- end

function commands.flow_reset(chartname)
    charts[name] = nil
end

function commands.flow_set_current_cell(n)
    temp = data[tonumber(n)] or { }
end

function commands.flow_start_cell(settings)
    temp = {
        texts       = { },
        labels      = { },
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
    temp.texts[#temp.texts+1] = {
        location = align,
        text = str,
    }
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

function commands.flow_set_comment(location,text)
    local connections = temp.connections
    if connections then
        local connection = connections[#connections]
        if connection then
            local comments = connection.comments
            if comments then
                comments[#comments+1] = {
                    location = location,
                    text = text,
                }
            end
        end
    end
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
        if si.include then
            inject(si,data,hash)
        else
            local t = {
                x        = si.x + xoffset,
                y        = si.y + yoffset,
                settings = settings,
            }
            setmetatableindex(t,si)
            data[#data+1] = t
            hash[si.name or #data] = t
        end
    end
end

local function pack(data,field)
    local list, max = { }, 0
    for e=1,#data do
        local d = data[e]
        local f = d[field]
        list[f] = true
        if f > max then
            max = f
        end
    end
    for i=1,max do
        if not list[i] then
            for e=1,#data do
                local d = data[e]
                local f = d[field]
                if f > i then
                    d[field] = f - 1
                end
            end
        end
    end
end

local function expanded(chart,chartsettings)
    local expandeddata = { }
    local expandedhash = { }
    local expandedchart = {
        data = expandeddata,
        hash = expandedhash,
    }
    setmetatableindex(expandedchart,chart)
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
    --
    expandedchart.settings = chartsettings or { }
    -- make locals
    chartsettings.shape = chartsettings.shape or { }
    chartsettings.focus = chartsettings.focus or { }
    chartsettings.line  = chartsettings.line  or { }
    chartsettings.set   = chartsettings.set   or { }
    chartsettings.split = chartsettings.split or { }
    chartsettings.chart = chartsettings.chart or { }
    setmetatableindex(chartsettings.shape,defaults.shape)
    setmetatableindex(chartsettings.focus,defaults.focus)
    setmetatableindex(chartsettings.line ,defaults.line )
    setmetatableindex(chartsettings.set  ,defaults.set  )
    setmetatableindex(chartsettings.split,defaults.split)
    setmetatableindex(chartsettings.chart,defaults.chart)
    --
    if chartsettings.chart.vcompact == v_yes then
        pack(expandeddata,"y")
    end
    if chartsettings.chart.hcompact == v_yes then
        pack(expandeddata,"x")
    end
    --
    for i=1,#expandeddata do
        local cell = expandeddata[i]
        local settings = cell.settings
        if not settings then
            cell.settings = chartsettings
        else
            settings.shape = settings.shape or { }
            settings.focus = settings.focus or { }
            settings.line  = settings.line  or { }
            setmetatableindex(settings.shape,chartsettings.shape)
            setmetatableindex(settings.focus,chartsettings.focus)
            setmetatableindex(settings.line ,chartsettings.line)
        end
    end
    return expandedchart
end

local splitter = lpeg.splitat(",")

function commands.flow_set_location(x,y)
    if type(x) == "string" and not y then
        x, y = lpegmatch(splitter,x)
    end
    if not x or x == "" then
        x = last_x
    elseif type(x) == "number" then
        -- ok
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
    elseif type(y) == "number" then
        -- ok
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
    dx = tonumber(dx)
    dy = tonumber(dy)
    temp.connections[#temp.connections+1] = {
        location = location,
        dx       = dx or 0,
        dy       = dy or 0,
        name     = name,
        comments = { },
    }
end

local function visible(chart,cell)
    local x, y = cell.x, cell.y
    return
        x >= chart.from_x and x <= chart.to_x and
        y >= chart.from_y and y <= chart.to_y and cell
end

local function process_cells(chart,xoffset,yoffset)
    local data = chart.data
    if not data then
        return
    end
    local focus = utilities.parsers.settings_to_hash(chart.settings.chart.focus or "")
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local settings = cell.settings
            local shapesettings = settings.shape
            local shape = cell.shape
            if not shape or shape == "" then
                shape = shapesettings.default or "none"
            end
            if shape ~= v_none then
                local shapedata = validshapes[shape]
                context("flow_begin_sub_chart ;") -- when is this needed
                if shapedata.kind == "line" then
                    local linesettings = settings.line
                    context("flow_shape_line_color := \\MPcolor{%s} ;", linesettings.color)
                    context("flow_shape_fill_color := \\MPcolor{%s} ;", linesettings.backgroundcolor)
                    context("flow_shape_line_width := %s ; ",           points(linesettings.rulethickness))
                elseif focus[cell.focus] or focus[cell.name] then
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
                context("flow_peepshape := false ;")   -- todo
                context("flow_new_shape(%s,%s,%s) ;",cell.x+xoffset,cell.y+yoffset,shapedata.number)
                context("flow_end_sub_chart ;")
            end
        end
    end
end

-- todo : make lpeg for splitter

local sign  = S("+p") /  "1"
            + S("-m") / "-1"

local full  = C(P("left"))
            + C(P("right"))
            + C(P("top"))
            + C(P("bottom"))

local char  = P("l") / "left"
            + P("r") / "right"
            + P("t") / "top"
            + P("b") / "bottom"

local space = P(" ")^0

local what  = space
            * (sign + Cc("0"))
            * space
            * (full + char)
            * space
            * (sign + Cc("0"))
            * space
            * (full + char)
            * space
            * P(-1)

-- print(lpegmatch(what,"lr"))
-- print(lpegmatch(what,"+l+r"))
-- print(lpegmatch(what,"+l"))
-- print(lpegmatch(what,"+ left+r     "))

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
                if othercell then -- and visible(chart,data[i]) then
                    local cellx, celly = cell.x, cell.y
                    local otherx, othery, location = othercell.x, othercell.y, connection.location
                    if otherx > 0 and othery > 0 and cellx > 0 and celly > 0 and connection.location then
                        local what_cell, where_cell, what_other, where_other = lpegmatch(what,location)
                        if what_cell and where_cell and what_other and where_other then
                            local linesettings = settings.line
                            context("flow_smooth := %s ;", linesettings.corner == v_round and "true" or "false")
                            context("flow_dashline := %s ;", linesettings.dash == v_yes and "true" or "false")
                            context("flow_arrowtip := %s ;", linesettings.arrow == v_yes and "true" or "false")
                            context("flow_touchshape := %s ;", linesettings.offset == v_none and "true" or "false")
                            context("flow_dsp_x := %s ; flow_dsp_y := %s ;",connection.dx or 0, connection.dy or 0)
                            context("flow_connection_line_color := \\MPcolor{%s} ;",linesettings.color)
                            context("flow_connection_line_width := %s ;",points(linesettings.rulethickness))
                            context("flow_connect_%s_%s (%s) (%s,%s,%s) (%s,%s,%s) ;",where_cell,where_other,j,cellx,celly,what_cell,otherx,othery,what_other)
                            context("flow_dsp_x := 0 ; flow_dsp_y := 0 ;")
                        end
                    end
                end
            end
        end
    end
end

local texttemplate = "\\setvariables[flowcell:text][x=%s,y=%s,text={%s},align={%s},figure={%s},destination={%s}]"

local splitter = lpeg.splitat(":")

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
            local texts = cell.texts
            for i=1,#texts do
                local text = texts[i]
                local data = text.text
                local align = validlabellocations[text.align or ""] or text.align or ""
                local figure = i == 1 and cell.figure or ""
                local destination = i == 1 and cell.destination or ""
                context('flow_chart_draw_text(%s,%s,textext("%s")) ;',x,y,format(texttemplate,x,y,data,align,figure,destination))
            end
            local labels = cell.labels
            for i=1,#labels do
                local label = labels[i]
                local text = label.text
                local location = validlabellocations[label.location or ""] or label.location or ""
                if text and location then
                    context('flow_chart_draw_label(%s,%s,"%s",textext("\\strut %s")) ;',x,y,location,text)
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
                        context('flow_chart_draw_exit(%s,%s,"%s",textext("\\strut %s")) ;',x,y,location,text)
                    end
                end
            end
            local connections = cell.connections
            for i=1,#connections do
                local comments = connections[i].comments
                for j=1,#comments do
                    local comment = comments[j]
                    local text = comment.text
                    local location = comment.location or ""
                    local length = 0
                    -- "tl" "tl:*" "tl:0.5"
                    local loc, len = lpegmatch(splitter,location) -- do the following in lpeg
                    if len == "*" then
                        location = validcommentlocations[loc] or ""
                        if location == "" then
                            location = "*"
                        else
                            location = location .. ":*"
                        end
                    elseif loc then
                        location = validcommentlocations[loc] or "*"
                        length = tonumber(len) or 0
                    else
                        location = validcommentlocations[location] or ""
                    end
                    if text and location then
                        context('flow_chart_draw_comment(%s,%s,%s,"%s",%s,textext("\\strut %s")) ;',x,y,i,location,length,text)
                    end
                end
            end
        end
    end
end

local function getchart(settings,forced_x,forced_y,forced_nx,forced_ny)
    if not settings then
        print("no settings given")
        return
    end
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
    chart = expanded(chart,settings)
    local chartsettings = chart.settings.chart
    local autofocus = chart.settings.chart.autofocus
    if autofocus then
        autofocus = utilities.parsers.settings_to_hash(autofocus)
        if not next(autofocus) then
            autofocus = false
        end
    end
    -- check natural window
    local x  = forced_x  or tonumber(chartsettings.x)
    local y  = forced_y  or tonumber(chartsettings.y)
    local nx = forced_nx or tonumber(chartsettings.nx)
    local ny = forced_ny or tonumber(chartsettings.ny)
    --
    local minx, miny, maxx, maxy = 0, 0, 0, 0
    local data = chart.data
    for i=1,#data do
        local cell = data[i]
        if not autofocus or autofocus[cell.name] then -- offsets probably interfere with autofocus
            local x = cell.x
            local y = cell.y
            if minx == 0 or x < minx then minx = x end
            if miny == 0 or y < miny then miny = y end
            if minx == 0 or x > maxx then maxx = x end
            if miny == 0 or y > maxy then maxy = y end
        end
    end
 -- print("1>",x,y,nx,ny)
 -- print("2>",minx, miny, maxx, maxy)
    -- check of window should be larger (maybe autofocus + nx/ny?)
    if autofocus then
        -- x and y are ignored
        if nx and nx > 0 then
            maxx = minx + nx - 1
        end
        if ny and ny > 0 then
            maxy = miny + ny - 1
        end
    else
        if x and x > 0 then
            minx = x
        end
        if y and y > 0 then
            miny = y
        end
        if nx and nx > 0 then
            maxx = minx + nx - 1
        end
        if ny and ny > 0 then
            maxy = miny + ny - 1
        end
    end
-- print("3>",minx, miny, maxx, maxy)
    --
    local nx = maxx - minx + 1
    local ny = maxy - miny + 1
    -- relocate cells
    for i=1,#data do
        local cell = data[i]
        cell.x = cell.x - minx + 1
        cell.y = cell.y - miny + 1
    end
    chart.from_x = 1
    chart.from_y = 1
    chart.to_x   = nx
    chart.to_y   = ny
    chart.nx     = nx
    chart.ny     = ny
    --
 -- inspect(chart)
    return chart
end

local function makechart(chart)
    local settings      = chart.settings
    local chartsettings = settings.chart
    --
    context.begingroup()
    context.forgetall()
    --
    context.startMPcode()
    context("if unknown context_flow : input mp-char.mpiv ; fi ;")
    context("flow_begin_chart(0,%s,%s);",chart.nx,chart.ny)
    --
    if chartsettings.option == v_test or chartsettings.dot == v_yes then
        context("flow_show_con_points := true ;")
        context("flow_show_mid_points := true ;")
        context("flow_show_all_points := true ;")
    elseif chartsettings.dot ~= "" then -- no checking done, private option
        context("flow_show_%s_points := true ;",chartsettings.dot)
    end
    --
    local backgroundcolor = chartsettings.backgroundcolor
    if backgroundcolor and backgroundcolor ~= "" then
        context("flow_chart_background_color := \\MPcolor{%s} ;",backgroundcolor)
    end
    --
    local shapewidth    = chartsettings.width
    local gridwidth     = shapewidth + 2*chartsettings.dx
    local shapeheight   = chartsettings.height
    local gridheight    = shapeheight + 2*chartsettings.dy
    local chartoffset   = chartsettings.offset
    local labeloffset   = chartsettings.labeloffset
    local exitoffset    = chartsettings.exitoffset
    local commentoffset = chartsettings.commentoffset
    context("flow_grid_width     := %s ;", points(gridwidth))
    context("flow_grid_height    := %s ;", points(gridheight))
    context("flow_shape_width    := %s ;", points(shapewidth))
    context("flow_shape_height   := %s ;", points(shapeheight))
    context("flow_chart_offset   := %s ;", points(chartoffset))
    context("flow_label_offset   := %s ;", points(labeloffset))
    context("flow_exit_offset    := %s ;", points(exitoffset))
    context("flow_comment_offset := %s ;", points(commentoffset))
    --
    local radius = settings.line.radius
    local rulethickness = settings.line.rulethickness
    local dx = chartsettings.dx
    local dy = chartsettings.dy
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
    local offset = chartsettings.offset -- todo: pass string
    if offset == v_none or offset == v_overlay or offset == "" then
        offset = -2.5 * radius -- or rulethickness?
    elseif offset == v_standard then
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

local function splitchart(chart)
    local settings      = chart.settings
    local splitsettings = settings.split
    local chartsettings = settings.chart
    --
    local name = chartsettings.name
    --
    local from_x = chart.from_x
    local from_y = chart.from_y
    local to_x   = chart.to_x
    local to_y   = chart.to_y
    --
    local step_x  = splitsettings.nx or to_x
    local step_y  = splitsettings.ny or to_y
    local delta_x = splitsettings.dx or 0
    local delta_y = splitsettings.dy or 0
    --
    report_chart("spliting %a from (%s,%s) upto (%s,%s) into (%s,%s) with overlap (%s,%s)",
        name,from_x,from_y,to_x,to_y,step_x,step_y,delta_x,delta_y)
    --
    local part_x = 0
    local first_x = from_x
    while true do
        part_x = part_x + 1
        local last_x = first_x + step_x - 1
        local done = last_x >= to_x
        if done then
            last_x = to_x
        end
        local part_y = 0
        local first_y = from_y
        while true do
            part_y = part_y + 1
            local last_y = first_y + step_y - 1
            local done = last_y >= to_y
            if done then
                last_y = to_y
            end
            --
            report_chart("part (%s,%s) of %a is split from (%s,%s) -> (%s,%s)",part_x,part_y,name,first_x,first_y,last_x,last_y)
            local x, y, nx, ny = first_x, first_y, last_x - first_x + 1,last_y - first_y + 1
            context.beforeFLOWsplit()
            context.handleFLOWsplit(function()
                makechart(getchart(settings,x,y,nx,ny)) -- we need to pass frozen settings !
            end)
            context.afterFLOWsplit()
            --
            if done then
                break
            else
                first_y = last_y + 1 - delta_y
            end
        end
        if done then
            break
        else
            first_x = last_x + 1 - delta_x
        end
    end
end

function commands.flow_make_chart(settings)
    local chart = getchart(settings)
    if chart then
        local settings = chart.settings
        if settings then
            local chartsettings = settings.chart
            if chartsettings and chartsettings.split == v_yes then
                splitchart(chart)
            else
                makechart(chart)
            end
        else
            makechart(chart)
        end
    end
end
