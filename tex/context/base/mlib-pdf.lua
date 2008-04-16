if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, join = string.format, table.concat
local sprint = tex.sprint
local abs, sqrt, round = math.abs, math.sqrt, math.round

metapost = metapost or { }

function metapost.convert(result, trialrun, flusher)
    if trialrun then
        metapost.parse(result, flusher)
    else
        metapost.flush(result, flusher)
    end
end

metapost.n = 0

function metapost.comment(message)
    if message then
        sprint(tex.ctxcatcodes,format("\\MPLIBtoPDF{\\letterpercent\\space mps graphic %s: %s}", metapost.n, message))
    end
end

metapost.flushers = { }
metapost.flushers.pdf = { }

function metapost.flushers.pdf.startfigure(n,llx,lly,urx,ury,message)
    metapost.n = metapost.n + 1
    sprint(tex.ctxcatcodes,format("\\startMPLIBtoPDF{%s}{%s}{%s}{%s}",llx,lly,urx,ury))
    if message then metapost.comment(message) end
end

function metapost.flushers.pdf.stopfigure(message)
    if message then metapost.comment(message) end
    sprint(tex.ctxcatcodes,"\\stopMPLIBtoPDF")
end

function metapost.flushers.pdf.flushfigure(pdfliterals) -- table
    if #pdfliterals > 0 then
        sprint(tex.ctxcatcodes,"\\MPLIBtoPDF{",join(pdfliterals,"\n"),"}")
    end
end

function metapost.flushers.pdf.textfigure(font,size,text,width,height,depth) -- we could save the factor
    text = text:gsub(".","\\hbox{%1}") -- kerning happens in metapost (i have to check if this is true for mplib)
    sprint(tex.ctxcatcodes,format("\\MPLIBtextext{%s}{%s}{%s}{%s}{%s}",font,size,text,0,-number.dimenfactors.bp*depth))
end

-- the pen calculations are taken from metapost, first converted by
-- taco from c to lua, and then optimized by hans, so all errors are his

local function pyth(a,b)
    return sqrt(a*a + b*b) -- much faster than sqrt(a^2 + b^2)
end

local aspect_bound   =  10/65536
local aspect_default =   1/65536
local bend_tolerance = 131/65536
local eps            = 0.0001

local function coord_range_x(h, dz) -- direction x
    local zlo, zhi = 0, 0
    for i=1, #h do
        local p = h[i]
        local z = p.x_coord
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
        z = p.right_x
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
        z = p.left_x
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
    end
    return (zhi - zlo <= dz and aspect_bound) or aspect_default
end

local function coord_range_y(h, dz) -- direction y
    local zlo, zhi = 0, 0
    for i=1, #h do
        local p = h[i]
        local z = p.y_coord
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
        z = p.right_y
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
        z = p.left_y
        if z < zlo then zlo = z elseif z > zhi then zhi = z end
    end
    return (zhi - zlo <= dz and aspect_bound) or aspect_default
end

local rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1

local function pen_characteristics(object)
    local p = object.pen[1]
    local x_coord, y_coord, left_x, left_y, right_x, right_y = p.x_coord, p.y_coord, p.left_x, p.left_y, p.right_x, p.right_y
    local wx, wy, width
    if right_x == x_coord and left_y == y_coord then
        wx = abs(left_x  - x_coord)
        wy = abs(right_y - y_coord)
    else
        wx = pyth(left_x - x_coord, right_x - x_coord)
        wy = pyth(left_y - y_coord, right_y - y_coord)
    end
    if wy/coord_range_x(object.path, wx) >= wx/coord_range_y(object.path, wy) then
        width = wy
    else
        width = wx
    end
    sx, rx, ry, sy, tx, ty = left_x, left_y, right_x, right_y, x_coord, y_coord
    sx, rx, ry, sy = (sx-tx), (rx-ty), (ry-tx), (sy-ty) -- combine with previous
    if width ~= 1 then
        if width == 0 then
            sx, sy = 1, 1
        else
            rx, ry, sx, sy = rx/width, ry/width, sx/width, sy/width
        end
    end
    -- sx rx ry sy tx ty -> 1 0 0 1 0 0 is ok, but 0 0 0 0 0 0 not
    if true then
        if abs(sx) < eps then sx = eps end
        if abs(sy) < eps then sy = eps end
    else
        -- this block looks complicated but it only captures invalid transforms
        -- to be checked rx vs sx and so
        local det = sx/sy - ry/rx
        local aspect = 4*aspect_bound + aspect_default
        if abs(det) < aspect  then
            local s
            if det >= 0 then
                s, aspect = 1, aspect - det
            else
                s, aspect = -1, -aspect - det -- - ?
            end
            local absrx, absry, abssy, abssx = abs(rx), abs(ry), abs(sy), abs(sx)
            if abssx + abssy >= absry + absrx then -- was yy
                if abssx > abssy then
                    sy = sy + (aspect + s*abssx) / sx
                else
                    sx = sx + (aspect + s*abssy) / sy
                end
            else
                if absry > absrx then
                    rx = rx + (aspect + s*absry) / ry
                else
                    ry = ry + (aspect + s*absrx) / rx
                end
            end
        end
    end
    divider = sx*sy - rx*ry
    return not (sx==1 and rx==0 and ry==0 and sy==1 and tx==0 and ty==0), width
end

local function concat(px, py) -- no tx, ty here
    return (sy*px-ry*py)/divider,(sx*py-rx*px)/divider
end

local function curved(ith,pth)
    local d = pth.left_x - ith.right_x
    if abs(ith.right_x-ith.x_coord-d) <= bend_tolerance and abs(pth.x_coord-pth.left_x-d) <= bend_tolerance then
        d = pth.left_y - ith.right_y
        if abs(ith.right_y-ith.y_coord-d) <= bend_tolerance and abs(pth.y_coord-pth.left_y-d) <= bend_tolerance then
            return false
        end
    end
    return true
end

local function flushnormalpath(path, t, open)
    local pth, ith
    for i=1,#path do
        pth = path[i]
        if not ith then
            t[#t+1] = format("%f %f m",pth.x_coord,pth.y_coord)
        elseif curved(ith,pth) then
            t[#t+1] = format("%f %f %f %f %f %f c",ith.right_x,ith.right_y,pth.left_x,pth.left_y,pth.x_coord,pth.y_coord)
        else
            t[#t+1] = format("%f %f l",pth.x_coord,pth.y_coord)
        end
        ith = pth
    end
    if not open then
        local one = path[1]
        if curved(pth,one) then
            t[#t+1] = format("%f %f %f %f %f %f c",pth.right_x,pth.right_y,one.left_x,one.left_y,one.x_coord,one.y_coord )
        else
           t[#t+1] = format("%f %f l",one.x_coord,one.y_coord)
        end
    end
    return t
end

local function flushconcatpath(path, t, open)
    t[#t+1] = format("%f %f %f %f %f %f cm", sx, rx, ry, sy, tx ,ty)
    local pth, ith
    for i=1,#path do
        pth = path[i]
        if not ith then
           t[#t+1] = format("%f %f m",concat(pth.x_coord,pth.y_coord))
        elseif curved(ith,pth) then
            local a, b = concat(ith.right_x,ith.right_y)
            local c, d = concat(pth.left_x,pth.left_y)
            t[#t+1] = format("%f %f %f %f %f %f c",a,b,c,d,concat(pth.x_coord, pth.y_coord))
        else
           t[#t+1] = format("%f %f l",concat(pth.x_coord, pth.y_coord))
        end
        ith = pth
    end
    if not open then
        local one = path[1]
        if curved(pth,one) then
            local a, b = concat(pth.right_x,pth.right_y)
            local c, d = concat(one.left_x,one.left_y)
            t[#t+1] = format("%f %f %f %f %f %f c",a,b,c,d,concat(one.x_coord, one.y_coord))
        else
           t[#t+1] = format("%f %f l",concat(one.x_coord,one.y_coord))
        end
    end
    return t
end

metapost.specials = metapost.specials or { }

-- we have two extension handlers, one for pre and postscripts, and one for colors

-- the flusher is pdf based, if another backend is used, we need to overload the
-- flusher; this is beta code, the organization will change

function metapost.flush(result,flusher) -- pdf flusher, table en dan concat is sneller, 1 literal
    if result then
        local figures = result.fig
        if figures then
            flusher = flusher or metapost.flushers.pdf
            local colorconverter = metapost.colorconverter() -- function !
            local colorhandler   = metapost.colorhandler
            for f=1, #figures do
                local figure = figures[f]
                local objects = figure:objects()
                local fignum = tonumber((figure:filename()):match("([%d]+)$") or 0)
                local t = { }
                local miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                local bbox = figure:boundingbox()
                local llx, lly, urx, ury = bbox[1], bbox[2], bbox[3], bbox[4] -- faster than unpack
                if urx < llx then
                    -- invalid
                    flusher.startfigure(fignum,0,0,0,0,"invalid")
                    flusher.stopfigure()
                else
                    flusher.startfigure(fignum,llx,lly,urx,ury,"begin")
                    t[#t+1] = "q"
                    if objects then
                        for o=1,#objects do
                            local object = objects[o]
                            local objecttype = object.type
                            if objecttype == "start_bounds" or objecttype == "stop_bounds" then
                                -- skip
                            elseif objecttype == "start_clip" then
                                t[#t+1] = "q"
                                flushnormalpath(object.path,t,false)
                                t[#t+1] = "W n"
                            elseif objecttype == "stop_clip" then
                                t[#t+1] = "Q"
                                miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                            elseif objecttype == "special" then
                                metapost.specials.register(object.prescript)
                            elseif objecttype == "text" then
                                t[#t+1] = "q"
                                local ot = object.transform -- 3,4,5,6,1,2
                                t[#t+1] = format("%f %f %f %f %f %f cm",ot[3],ot[4],ot[5],ot[6],ot[1],ot[2]) -- TH: format("%f %f m %f %f %f %f 0 0 cm",unpack(ot))
                                flusher.flushfigure(t)
                                t = { }
                                flusher.textfigure(object.font,object.dsize,object.text,object.width,object.height,object.depth)
                                t[#t+1] = "Q"
                            else
                                -- alternatively we can pass on the stack, could be a helper
                                local currentobject = { -- not needed when no extensions
                                    type = object.type,
                                    miterlimit = object.miterlimit,
                                    linejoin = object.linejoin,
                                    linecap = object.linecap,
                                    color = object.color,
                                    dash = object.dash,
                                    path = object.path,
                                    htap = object.htap,
                                    pen = object.pen,
                                    prescript = object.prescript,
                                    postscript = object.postscript,
                                }
                                --
                                local before, inbetween, after = nil, nil, nil
                                --
                                local cs, cr = currentobject.color, nil
                                -- todo document why ...
                                if cs and colorhandler and #cs > 0 and round(cs[1]*10000) == 123 then -- test in function
                                    currentobject, cr = colorhandler(cs,currentobject,t,colorconverter)
                                    objecttype = currentobject.type
                                end
                                --
                                local prescript = currentobject.prescript
                                if prescript then
                                    -- move test to function
                                    local special = metapost.specials[prescript]
                                    if special then
                                        currentobject, before, inbetween, after = special(currentobject.postscript,currentobject,t,flusher)
                                        objecttype = currentobject.type
                                    end
                                end
                                --
                                cs = currentobject.color
                                if cs and #cs > 0 then
                                    t[#t+1], cr = colorconverter(cs)
                                end
                                --
                                if before then object, t = before() end
                                local ml = currentobject.miterlimit
                                if ml and ml ~= miterlimit then
                                    miterlimit = ml
                                    t[#t+1] = format("%f M",ml)
                                end
                                local lj = currentobject.linejoin
                                if lj and lj ~= linejoin then
                                    linejoin = lj
                                    t[#t+1] = format("%i j",lj)
                                end
                                local lc = currentobject.linecap
                                if lc and lc ~= linecap then
                                    linecap = lc
                                    t[#t+1] = format("%i J",lc)
                                end
                                local dl = currentobject.dash
                                if dl then
                                    local d = format("[%s] %i d",join(dl.dashes or {}," "),dl.offset)
                                    if d ~= dashed then
                                        dashed = d
                                        t[#t+1] = dashed
                                    end
                                elseif dashed then
                                   t[#t+1] = "[] 0 d"
                                   dashed = false
                                end
                                if inbetween then object, t = inbetween() end
                                local path = currentobject.path
                                local transformed, penwidth = false, 1
                                local open = path and path[1].left_type and path[#path].right_type -- at this moment only "end_point"
                                local pen = currentobject.pen
                                if pen then
								   if pen.type=='elliptical' then
                                        transformed, penwidth = pen_characteristics(object) -- boolean, value
                                        t[#t+1] = format("%f w",penwidth) -- todo: only if changed
                                        if objecttype == 'fill' then
                                            objecttype = 'both'
                                        end
                                   else -- calculated by mplib itself
                                        objecttype = 'fill'
                                   end
                                end
                                if transformed then
                                    t[#t+1] = "q"
                                end
                                if path then
                                    if transformed then
                                        flushconcatpath(path,t,open)
                                    else
                                        flushnormalpath(path,t,open)
                                    end
                                    if objecttype == "fill" then
                                        t[#t+1] = "h f"
                                    elseif objecttype == "outline" then
                                        t[#t+1] = (open and "S") or "h S"
                                    elseif objecttype == "both" then
                                        t[#t+1] = "h B"
                                    end
                                end
                                if transformed then
                                    t[#t+1] = "Q"
                                end
                                local path = currentobject.htap
                                if path then
                                    if transformed then
                                        t[#t+1] = "q"
                                    end
                                    if transformed then
                                        flushconcatpath(path,t,open)
                                    else
                                        flushnormalpath(path,t,open)
                                    end
                                    if objecttype == "fill" then
                                        t[#t+1] = "h f"
                                    elseif objecttype == "outline" then
                                        t[#t+1] = (open and "S") or "h S"
                                    elseif objecttype == "both" then
                                        t[#t+1] = "h B"
                                    end
                                    if transformed then
                                        t[#t+1] = "Q"
                                    end
                                end
                                if cr then
                                    t[#t+1] = cr
                                end
                                if after then object, t = after() end
                            end
                       end
                    end
                    t[#t+1] = "Q"
                    flusher.flushfigure(t)
                    flusher.stopfigure("end")
                end
            end
        end
    end
end

function metapost.parse(result)
    if result then
        local figures = result.fig
        if figures then
            for f=1, #figures do
                local figure = figures[f]
                local objects = figure:objects()
                if objects then
                    for o=1,#objects do
                        local object = objects[o]
                        if object.type == "outline" then
                            local prescript = object.prescript
                            if prescript then
                                local special = metapost.specials[prescript]
                                if special then
                                    special(object.postscript,object)
                                end
                            end
                       end
                    end
                end
            end
        end
    end
end

do

    -- just tracing

    local t = { }

    local flusher = {
        startfigure = function()
            t = { }
            tex.sprint(tex.ctxcatcodes,"\\startnointerference")
        end,
        flushfigure = function(literals)
            for i=1, #literals do
                t[#t+1] = literals[i]
            end
        end,
        stopfigure = function()
            tex.sprint(tex.ctxcatcodes,"\\stopnointerference")
        end
    }

    function metapost.pdfliterals(result)
        metapost.flush(result,flusher)
        return t
    end

end

function metapost.totable(result)
    local figure = result and result.fig and result.fig[1]
    if figure then
        local t = { }
        local objects = figure:objects()
        for _, object in ipairs(objects) do
            local tt = { }
            for _, field in ipairs(mplib.fields(object)) do
                tt[field] = object[field]
            end
            t[#t+1] = tt
        end
        local b = figure:boundingbox()
        return {
            boundingbox = { llx = b[1], lly = b[2], urx = b[3], ury = b[4] },
            objects = t
        }
    else
        return nil
    end
end

function metapost.colorconverter()
    return function(cr)
        local n = #cr
        if n == 4 then
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k), "0 g 0 G"
        elseif n == 3 then
            local r, g, b = cr[1], cr[2], cr[3]
            return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b), "0 g 0 G"
        else
            local s = cr[1]
            return format("%.3f g %.3f G",s,s), "0 g 0 G"
        end
    end
end
