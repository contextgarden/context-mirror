if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, concat, gsub = string.format, table.concat, string.gsub
local texsprint = tex.sprint
local abs, sqrt, round = math.abs, math.sqrt, math.round

local report_mplib = logs.new("mplib")

local mplib = mplib

local ctxcatcodes = tex.ctxcatcodes
local copy_node   = node.copy
local write_node  = node.write

metapost           = metapost or { }
local metapost     = metapost

metapost.multipass = false
metapost.n         = 0
metapost.optimize  = true -- false

--~ Because in MKiV we always have two passes, we save the objects. When an extra
--~ mp run is done (due to for instance texts identifier in the parse pass), we
--~ get a new result table and the stored objects are forgotten. Otherwise they
--~ are reused.

local function getobjects(result,figure,f)
    if metapost.optimize then
        local objects = result.objects
        if not objects then
            result.objects = { }
        end
        objects = result.objects[f]
        if not objects then
            objects = figure:objects()
            result.objects[f] = objects
        end
        return objects
    else
        return figure:objects()
    end
end

function metapost.convert(result, trialrun, flusher, multipass, askedfig)
    if trialrun then
        metapost.multipass = false
        metapost.parse(result, askedfig)
        if multipass and not metapost.multipass and metapost.optimize then
            metapost.flush(result, flusher, askedfig) -- saves a run
        else
            return false
        end
    else
        metapost.flush(result, flusher, askedfig)
    end
    return true -- done
end

metapost.flushers = { }
metapost.flushers.pdf = { }

local savedliterals = nil

local mpsliteral = nodes.pool.register(node.new("whatsit",8)) -- pdfliteral

function metapost.flush_literal(d) -- \def\MPLIBtoPDF#1{\ctxlua{metapost.flush_literal(#1)}}
    if savedliterals then
        local literal = copy_node(mpsliteral)
        literal.data = savedliterals[d]
        write_node(literal)
    else
        report_mplib("problem flushing literal %s",d)
    end
end

function metapost.flush_reset()
    savedliterals = nil
end

function metapost.flushers.pdf.comment(message)
    if message then
        message = format("%% mps graphic %s: %s", metapost.n, message)
        if savedliterals then
            local last = #savedliterals + 1
            savedliterals[last] = message
            texsprint(ctxcatcodes,"\\MPLIBtoPDF{",last,"}")
        else
            savedliterals = { message }
            texsprint(ctxcatcodes,"\\MPLIBtoPDF{1}")
        end
    end
end

function metapost.flushers.pdf.startfigure(n,llx,lly,urx,ury,message)
    savedliterals = nil
    metapost.n = metapost.n + 1
    texsprint(ctxcatcodes,format("\\startMPLIBtoPDF{%s}{%s}{%s}{%s}",llx,lly,urx,ury))
    if message then metapost.flushers.pdf.comment(message) end
end

function metapost.flushers.pdf.stopfigure(message)
    if message then metapost.flushers.pdf.comment(message) end
    texsprint(ctxcatcodes,"\\stopMPLIBtoPDF")
    texsprint(ctxcatcodes,"\\ctxlua{metapost.flush_reset()}") -- maybe just at the beginning
end

function metapost.flushers.pdf.flushfigure(pdfliterals) -- table
    if #pdfliterals > 0 then
        pdfliterals = concat(pdfliterals,"\n")
        if savedliterals then
            local last = #savedliterals + 1
            savedliterals[last] = pdfliterals
            texsprint(ctxcatcodes,"\\MPLIBtoPDF{",last,"}")
        else
            savedliterals = { pdfliterals }
            texsprint(ctxcatcodes,"\\MPLIBtoPDF{1}")
        end
    end
end

function metapost.flushers.pdf.textfigure(font,size,text,width,height,depth) -- we could save the factor
    text = gsub(text,".","\\hbox{%1}") -- kerning happens in metapost (i have to check if this is true for mplib)
    texsprint(ctxcatcodes,format("\\MPLIBtextext{%s}{%s}{%s}{%s}{%s}",font,size,text,0,-number.dimenfactors.bp*depth))
end

local bend_tolerance = 131/65536

local rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1

local function pen_characteristics(object)
    if mplib.pen_info then
        local t = mplib.pen_info(object)
        rx, ry, sx, sy, tx, ty = t.rx, t.ry, t.sx, t.sy, t.tx, t.ty
        divider = sx*sy - rx*ry
        return not (sx==1 and rx==0 and ry==0 and sy==1 and tx==0 and ty==0), t.width
    else
        rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1
        return false, 1
    end
end

local function mpconcat(px, py) -- no tx, ty here / we can move this one inline if needed
    return (sy*px-ry*py)/divider,(sx*py-rx*px)/divider
end

local function curved(ith,pth)
    local d = pth.left_x - ith.right_x
    if abs(ith.right_x - ith.x_coord - d) <= bend_tolerance and abs(pth.x_coord - pth.left_x - d) <= bend_tolerance then
        d = pth.left_y - ith.right_y
        if abs(ith.right_y - ith.y_coord - d) <= bend_tolerance and abs(pth.y_coord - pth.left_y - d) <= bend_tolerance then
            return false
        end
    end
    return true
end

local function flushnormalpath(path, t, open)
    t = t or { }
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
    elseif #path == 1 then
        -- special case .. draw point
        local one = path[1]
        t[#t+1] = format("%f %f l",one.x_coord,one.y_coord)
    end
    return t
end

local function flushconcatpath(path, t, open)
    t = t or { }
    t[#t+1] = format("%f %f %f %f %f %f cm", sx, rx, ry, sy, tx ,ty)
    local pth, ith
    for i=1,#path do
        pth = path[i]
        if not ith then
           t[#t+1] = format("%f %f m",mpconcat(pth.x_coord,pth.y_coord))
        elseif curved(ith,pth) then
            local a, b = mpconcat(ith.right_x,ith.right_y)
            local c, d = mpconcat(pth.left_x,pth.left_y)
            t[#t+1] = format("%f %f %f %f %f %f c",a,b,c,d,mpconcat(pth.x_coord,pth.y_coord))
        else
           t[#t+1] = format("%f %f l",mpconcat(pth.x_coord, pth.y_coord))
        end
        ith = pth
    end
    if not open then
        local one = path[1]
        if curved(pth,one) then
            local a, b = mpconcat(pth.right_x,pth.right_y)
            local c, d = mpconcat(one.left_x,one.left_y)
            t[#t+1] = format("%f %f %f %f %f %f c",a,b,c,d,mpconcat(one.x_coord, one.y_coord))
        else
            t[#t+1] = format("%f %f l",mpconcat(one.x_coord,one.y_coord))
        end
    elseif #path == 1 then
        -- special case .. draw point
        local one = path[1]
        t[#t+1] = format("%f %f l",mpconcat(one.x_coord,one.y_coord))
    end
    return t
end

metapost.flushnormalpath = flushnormalpath

metapost.specials = metapost.specials or { }

-- we have two extension handlers, one for pre and postscripts, and one for colors

-- the flusher is pdf based, if another backend is used, we need to overload the
-- flusher; this is beta code, the organization will change

function metapost.flush(result,flusher,askedfig) -- pdf flusher, table en dan concat is sneller, 1 literal
    if result then
        local figures = result.fig
        if figures then
            flusher = flusher or metapost.flushers.pdf
            local colorconverter = metapost.colorconverter() -- function !
            local colorhandler   = metapost.colorhandler
            for f=1, #figures do
                local figure = figures[f]
                local objects = getobjects(result,figure,f)
                local fignum = figure:charcode() or 0
                if not askedfig or (askedfig == fignum) then
                    local t = { }
                    local miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                    local bbox = figure:boundingbox()
                    local llx, lly, urx, ury = bbox[1], bbox[2], bbox[3], bbox[4] -- faster than unpack
                    metapost.llx = llx
                    metapost.lly = lly
                    metapost.urx = urx
                    metapost.ury = ury
                    if urx < llx then
                        -- invalid
                        flusher.startfigure(fignum,0,0,0,0,"invalid",figure)
                        flusher.stopfigure()
                    else
                        flusher.startfigure(fignum,llx,lly,urx,ury,"begin",figure)
                        t[#t+1] = "q"
                        if objects then
                            t[#t+1] = metapost.colorinitializer()
                            -- once we have multiple prescripts we can do more tricky things like
                            -- text and special colors at the same time
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
                                    flusher.flushfigure(t) -- flush accumulated literals
                                    t = { }
                                    flusher.textfigure(object.font,object.dsize,object.text,object.width,object.height,object.depth)
                                    t[#t+1] = "Q"
                                else
                                    -- alternatively we can pass on the stack, could be a helper
                                    -- can be optimized with locals
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
                                    if prescript and prescript ~= "" then
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
                                    if before then currentobject, t = before() end
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
                                        local d = format("[%s] %i d",concat(dl.dashes or {}," "),dl.offset)
                                        if d ~= dashed then
                                            dashed = d
                                            t[#t+1] = dashed
                                        end
                                    elseif dashed then
                                       t[#t+1] = "[] 0 d"
                                       dashed = false
                                    end
                                    if inbetween then currentobject, t = inbetween() end
                                    local path = currentobject.path
                                    local transformed, penwidth = false, 1
                                    local open = path and path[1].left_type and path[#path].right_type -- at this moment only "end_point"
                                    local pen = currentobject.pen
                                    if pen then
                                       if pen.type == 'elliptical' then
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
                                    if after then currentobject, t = after() end
                                end
                           end
                        end
                        t[#t+1] = "Q"
                        flusher.flushfigure(t)
                        flusher.stopfigure("end")
                    end
                    if askedfig then
                        break
                    end
                end
            end
        end
    end
end

function metapost.parse(result,askedfig)
    if result then
        local figures = result.fig
        if figures then
            for f=1, #figures do
                local figure = figures[f]
                local fignum = figure:charcode() or 0
                if not askedfig or (askedfig == fignum) then
                    local bbox = figure:boundingbox()
                    local llx, lly, urx, ury = bbox[1], bbox[2], bbox[3], bbox[4] -- faster than unpack
                    metapost.llx = llx
                    metapost.lly = lly
                    metapost.urx = urx
                    metapost.ury = ury
                    local objects = getobjects(result,figure,f)
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
                    break
                end
            end
        end
    end
end

-- tracing:

local t = { }

local flusher = {
    startfigure = function()
        t = { }
        texsprint(ctxcatcodes,"\\startnointerference")
    end,
    flushfigure = function(literals)
        for i=1, #literals do
            t[#t+1] = literals[i]
        end
    end,
    stopfigure = function()
        texsprint(ctxcatcodes,"\\stopnointerference")
    end
}

function metapost.pdfliterals(result)
    metapost.flush(result,flusher)
    return t
end

-- so far

function metapost.totable(result)
    local figure = result and result.fig and result.fig[1]
    if figure then
        local t = { }
        local objects = figure:objects()
        for o=1,#objects do
            local object = objects[o]
            local tt = { }
            local fields = mplib.fields(object)
            for f=1,#fields do
                local field = fields[f]
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

-- will be overloaded later

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
