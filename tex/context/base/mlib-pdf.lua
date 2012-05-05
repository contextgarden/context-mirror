if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, concat, gsub = string.format, table.concat, string.gsub
local abs, sqrt, round = math.abs, math.sqrt, math.round
local setmetatable = setmetatable
local Cf, C, Cg, Ct, P, S, lpegmatch = lpeg.Cf, lpeg.C, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.S, lpeg.match

local allocate = utilities.storage.allocate

local report_metapost = logs.reporter("metapost")

local mplib, context = mplib, context

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

metapost.flushers     = { }
metapost.flushers.pdf = { }

-- \def\MPLIBtoPDF#1{\ctxlua{metapost.flushliteral(#1)}}

local savedliterals = nil -- needs checking

local mpsliteral = nodes.pool.register(node.new("whatsit",8)) -- pdfliteral

local pdfliteral = function(s)
    local literal = copy_node(mpsliteral)
    literal.data = s
    return literal
end

local experiment = true -- uses context(node) that already does delayed nodes

function metapost.flushliteral(d)
    if savedliterals then
        local literal = copy_node(mpsliteral)
        literal.data = savedliterals[d]
        write_node(literal)
    else
        report_metapost("problem flushing literal %s",d)
    end
end

function metapost.flushreset() -- will become obsolete and internal
    savedliterals = nil
end

function metapost.flushers.pdf.comment(message)
    if message then
        message = format("%% mps graphic %s: %s", metapost.n, message)
        if experiment then
            context(pdfliteral(message))
        else
            if savedliterals then
                local last = #savedliterals + 1
                savedliterals[last] = message
                context.MPLIBtoPDF(last)
            else
                savedliterals = { message }
                context.MPLIBtoPDF(1)
            end
        end
    end
end

function metapost.flushers.pdf.startfigure(n,llx,lly,urx,ury,message)
    savedliterals = nil
    metapost.n = metapost.n + 1
    context.startMPLIBtoPDF(llx,lly,urx,ury)
    if message then metapost.flushers.pdf.comment(message) end
end

function metapost.flushers.pdf.stopfigure(message)
    if message then metapost.flushers.pdf.comment(message) end
    context.stopMPLIBtoPDF()
    context.MPLIBflushreset() -- maybe just at the beginning
end

function metapost.flushers.pdf.flushfigure(pdfliterals) -- table
    if #pdfliterals > 0 then
        pdfliterals = concat(pdfliterals,"\n")
        if experiment then
            context(pdfliteral(pdfliterals))
        else
            if savedliterals then
                local last = #savedliterals + 1
                savedliterals[last] = pdfliterals
                context.MPLIBtoPDF(last)
            else
                savedliterals = { pdfliterals }
                context.MPLIBtoPDF(1)
            end
        end
    end
end

function metapost.flushers.pdf.textfigure(font,size,text,width,height,depth) -- we could save the factor
    text = gsub(text,".","\\hbox{%1}") -- kerning happens in metapost (i have to check if this is true for mplib)
    context.MPtextext(font,size,text,0,-number.dimenfactors.bp*depth)
end

local bend_tolerance = 131/65536

local rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1

local pen_info = mplib.pen_info

local function pen_characteristics(object)
    local t = pen_info(object)
    rx, ry, sx, sy, tx, ty = t.rx, t.ry, t.sx, t.sy, t.tx, t.ty
    divider = sx*sy - rx*ry
    return not (sx==1 and rx==0 and ry==0 and sy==1 and tx==0 and ty==0), t.width
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
    local pth, ith, nt
    if t then
        nt = #t
    else
        t = { }
        nt = 0
    end
    for i=1,#path do
        nt = nt + 1
        pth = path[i]
        if not ith then
            t[nt] = format("%f %f m",pth.x_coord,pth.y_coord)
        elseif curved(ith,pth) then
            t[nt] = format("%f %f %f %f %f %f c",ith.right_x,ith.right_y,pth.left_x,pth.left_y,pth.x_coord,pth.y_coord)
        else
            t[nt] = format("%f %f l",pth.x_coord,pth.y_coord)
        end
        ith = pth
    end
    if not open then
        nt = nt + 1
        local one = path[1]
        if curved(pth,one) then
            t[nt] = format("%f %f %f %f %f %f c",pth.right_x,pth.right_y,one.left_x,one.left_y,one.x_coord,one.y_coord )
        else
            t[nt] = format("%f %f l",one.x_coord,one.y_coord)
        end
    elseif #path == 1 then
        -- special case .. draw point
        local one = path[1]
        nt = nt + 1
        t[nt] = format("%f %f l",one.x_coord,one.y_coord)
    end
    return t
end

local function flushconcatpath(path, t, open)
    local pth, ith, nt
    if t then
        nt = #t
    else
        t = { }
        nt = 0
    end
    nt = nt + 1
    t[nt] = format("%f %f %f %f %f %f cm", sx, rx, ry, sy, tx ,ty)
    for i=1,#path do
        nt = nt + 1
        pth = path[i]
        if not ith then
            t[nt] = format("%f %f m",mpconcat(pth.x_coord,pth.y_coord))
        elseif curved(ith,pth) then
            local a, b = mpconcat(ith.right_x,ith.right_y)
            local c, d = mpconcat(pth.left_x,pth.left_y)
            t[nt] = format("%f %f %f %f %f %f c",a,b,c,d,mpconcat(pth.x_coord,pth.y_coord))
        else
           t[nt] = format("%f %f l",mpconcat(pth.x_coord, pth.y_coord))
        end
        ith = pth
    end
    if not open then
        nt = nt + 1
        local one = path[1]
        if curved(pth,one) then
            local a, b = mpconcat(pth.right_x,pth.right_y)
            local c, d = mpconcat(one.left_x,one.left_y)
            t[nt] = format("%f %f %f %f %f %f c",a,b,c,d,mpconcat(one.x_coord, one.y_coord))
        else
            t[nt] = format("%f %f l",mpconcat(one.x_coord,one.y_coord))
        end
    elseif #path == 1 then
        -- special case .. draw point
        nt = nt + 1
        local one = path[1]
        t[nt] = format("%f %f l",mpconcat(one.x_coord,one.y_coord))
    end
    return t
end

metapost.flushnormalpath = flushnormalpath

-- The flusher is pdf based, if another backend is used, we need to overload the
-- flusher; this is beta code, the organization will change (already upgraded in
-- sync with mplib)
--
-- We can avoid the before table but I like symmetry. There is of course a small
-- performance penalty, but so is passing extra arguments (result, flusher, after)
-- and returning stuff.

local function ignore() end

function metapost.flush(result,flusher,askedfig)
    if result then
        local figures = result.fig
        if figures then
            flusher = flusher or metapost.flushers.pdf
            local resetplugins = metapost.resetplugins or ignore -- before figure
            local processplugins = metapost.processplugins or ignore -- each object
            local synchronizeplugins = metapost.synchronizeplugins or ignore
            local pluginactions = metapost.pluginactions or ignore -- before / after
            local startfigure = flusher.startfigure
            local stopfigure = flusher.stopfigure
            local flushfigure = flusher.flushfigure
            local textfigure = flusher.textfigure
            for f=1, #figures do
                local figure = figures[f]
                local objects = getobjects(result,figure,f)
                local fignum = figure:charcode() or 0
                if askedfig == "direct" or askedfig == "all" or askedfig == fignum then
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
                        startfigure(fignum,0,0,0,0,"invalid",figure)
                        stopfigure()
                    else
                        startfigure(fignum,llx,lly,urx,ury,"begin",figure)
                        t[#t+1] = "q"
                        if objects then
                            resetplugins(t) -- we should move the colorinitializer here
                            for o=1,#objects do
                                local object = objects[o]
                                local objecttype = object.type
                                if objecttype == "start_bounds" or objecttype == "stop_bounds" or objecttype == "special" then
                                    -- skip
                                elseif objecttype == "start_clip" then
                                    t[#t+1] = "q"
                                    flushnormalpath(object.path,t,false)
                                    t[#t+1] = "W n"
                                elseif objecttype == "stop_clip" then
                                    t[#t+1] = "Q"
                                    miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                                elseif objecttype == "text" then
                                    t[#t+1] = "q"
                                    local ot = object.transform -- 3,4,5,6,1,2
                                    t[#t+1] = format("%f %f %f %f %f %f cm",ot[3],ot[4],ot[5],ot[6],ot[1],ot[2]) -- TH: format("%f %f m %f %f %f %f 0 0 cm",unpack(ot))
                                    flushfigure(t) -- flush accumulated literals
                                    t = { }
                                    textfigure(object.font,object.dsize,object.text,object.width,object.height,object.depth)
                                    t[#t+1] = "Q"
                                else
                                    -- we use an indirect table as we want to overload
                                    -- entries but this is not possible in userdata
                                    --
                                    -- can be optimized if no path
                                    --
                                    local original = object
                                    local object = { }
                                    setmetatable(object, {
                                        __index = original
                                    })
                                    -- first we analyze
                                    local before, after = processplugins(object)
                                    local objecttype = object.type -- can have changed
                                    if before then
                                        t = pluginactions(before,t,flushfigure)
                                    end
                                    local ml = object.miterlimit
                                    if ml and ml ~= miterlimit then
                                        miterlimit = ml
                                        t[#t+1] = format("%f M",ml)
                                    end
                                    local lj = object.linejoin
                                    if lj and lj ~= linejoin then
                                        linejoin = lj
                                        t[#t+1] = format("%i j",lj)
                                    end
                                    local lc = object.linecap
                                    if lc and lc ~= linecap then
                                        linecap = lc
                                        t[#t+1] = format("%i J",lc)
                                    end
                                    local dl = object.dash
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
                                    local path = object.path -- newpath
                                    local transformed, penwidth = false, 1
                                    local open = path and path[1].left_type and path[#path].right_type -- at this moment only "end_point"
                                    local pen = object.pen
                                    if pen then
                                       if pen.type == 'elliptical' then
                                            transformed, penwidth = pen_characteristics(original) -- boolean, value
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
                                    local path = object.htap
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
                                    if after then
                                        t = pluginactions(after,t,flushfigure)
                                    end
                                    if object.grouped then
                                        -- can be qQ'd so changes can end up in groups
                                        miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                                    end
                                end
                            end
                        end
                        t[#t+1] = "Q"
                        flushfigure(t)
                        stopfigure("end")
                    end
                    if askedfig ~= "all" then
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
            local analyzeplugins = metapost.analyzeplugins -- each object
            for f=1, #figures do
                local figure = figures[f]
                local fignum = figure:charcode() or 0
                if askedfig == "direct" or askedfig == "all" or askedfig == fignum then
                    local bbox = figure:boundingbox()
                    local llx, lly, urx, ury = bbox[1], bbox[2], bbox[3], bbox[4] -- faster than unpack
                    metapost.llx = llx
                    metapost.lly = lly
                    metapost.urx = urx
                    metapost.ury = ury
                    local objects = getobjects(result,figure,f)
                    if objects then
                     -- for o=1,#objects do
                     -- local object = objects[o]
                     -- local prescript = object.prescript
                     -- if prescript then
                     --     analyzeplugins(object)
                     -- end
                        for o=1,#objects do
                            analyzeplugins(objects[o])
                        end
                    end
                    if askedfig ~= "all" then
                        break
                    end
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
        context.startnointerference()
    end,
    flushfigure = function(literals)
        local n = #t
        for i=1, #literals do
            n = n + 1
            t[n] = literals[i]
        end
    end,
    stopfigure = function()
        context.stopnointerference()
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
            t[o] = tt
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
