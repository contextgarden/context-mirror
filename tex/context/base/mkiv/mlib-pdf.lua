if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- maybe %s is better than %f

local format, concat, gsub = string.format, table.concat, string.gsub
local abs, sqrt, round = math.abs, math.sqrt, math.round
local setmetatable, rawset, tostring, tonumber, type = setmetatable, rawset, tostring, tonumber, type
local P, S, C, Ct, Cc, Cg, Cf, Carg = lpeg.P, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.Carg
local lpegmatch = lpeg.match
local formatters = string.formatters

local report_metapost = logs.reporter("metapost")

local trace_variables = false  trackers.register("metapost.variables",function(v) trace_variables = v end)

local mplib           = mplib
local context         = context

local allocate        = utilities.storage.allocate

local copy_node       = node.copy
local write_node      = node.write

local pen_info        = mplib.pen_info
local object_fields   = mplib.fields

local save_table      = false

metapost              = metapost or { }
local metapost        = metapost

metapost.flushers     = metapost.flushers or { }
local pdfflusher      = { }
metapost.flushers.pdf = pdfflusher

metapost.n            = 0
metapost.optimize     = true  -- false

local experiment      = true -- uses context(node) that already does delayed nodes
local savedliterals   = nil  -- needs checking
local mpsliteral      = nodes.pool.register(node.new("whatsit",nodes.whatsitcodes.pdfliteral)) -- pdfliteral.mode  = 1

local f_f  = formatters["%F"]

local f_m  = formatters["%F %F m"]
local f_c  = formatters["%F %F %F %F %F %F c"]
local f_l  = formatters["%F %F l"]
local f_cm = formatters["%F %F %F %F %F %F cm"]
local f_M  = formatters["%F M"]
local f_j  = formatters["%i j"]
local f_J  = formatters["%i J"]
local f_d  = formatters["[%s] %F d"]
local f_w  = formatters["%F w"]

directives.register("metapost.savetable",function(v)
    if type(v) == "string" then
        save_table = file.addsuffix(v,"mpl")
    elseif v then
        save_table = file.addsuffix(environment.jobname .. "-graphic","mpl")
    else
        save_table = false
    end
end)

local pdfliteral = function(pdfcode)
    local literal = copy_node(mpsliteral)
    literal.data = pdfcode
    return literal
end

-- Because in MKiV we always have two passes, we save the objects. When an extra
-- mp run is done (due to for instance texts identifier in the parse pass), we
-- get a new result table and the stored objects are forgotten. Otherwise they
-- are reused.

local function getobjects(result,figure,index)
    if metapost.optimize then
        local robjects = result.objects
        if not robjects then
            robjects = { }
            result.objects = robjects
        end
        local fobjects = robjects[index or 1]
        if not fobjects then
            fobjects = figure:objects()
            robjects[index] = fobjects
        end
        return fobjects
    else
        return figure:objects()
    end
end

function metapost.convert(result, trialrun, flusher, multipass, askedfig)
    if trialrun then
        local multipassindeed = metapost.parse(result,askedfig)
        if multipass and not multipassindeed and metapost.optimize then
            if save_table then
                table.save(save_table,metapost.totable(result,1)) -- direct
            end
            metapost.flush(result,flusher,askedfig) -- saves a run
        else
            return false
        end
    else
        if save_table then
            table.save(save_table,metapost.totable(result,1)) -- direct
        end
        metapost.flush(result,flusher,askedfig)
    end
    return true -- done
end

function metapost.flushliteral(d)
    if savedliterals then
        local literal = copy_node(mpsliteral)
        literal.data = savedliterals[d]
        write_node(literal)
    else
        report_metapost("problem flushing literal %a",d)
    end
end

function metapost.flushreset() -- will become obsolete and internal
    savedliterals = nil
end

function pdfflusher.comment(message)
    if message then
        message = formatters["%% mps graphic %s: %s"](metapost.n,message)
        if experiment then
            context(pdfliteral(message))
        elseif savedliterals then
            local last = #savedliterals + 1
            savedliterals[last] = message
            context.MPLIBtoPDF(last)
        else
            savedliterals = { message }
            context.MPLIBtoPDF(1)
        end
    end
end

function pdfflusher.startfigure(n,llx,lly,urx,ury,message)
    savedliterals = nil
    metapost.n = metapost.n + 1
    context.startMPLIBtoPDF(f_f(llx),f_f(lly),f_f(urx),f_f(ury))
    if message then pdfflusher.comment(message) end
end

function pdfflusher.stopfigure(message)
    if message then pdfflusher.comment(message) end
    context.stopMPLIBtoPDF()
    context.MPLIBflushreset() -- maybe just at the beginning
end

function pdfflusher.flushfigure(pdfliterals) -- table
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

function pdfflusher.textfigure(font,size,text,width,height,depth) -- we could save the factor
    text = gsub(text,".","\\hbox{%1}") -- kerning happens in metapost (i have to check if this is true for mplib)
    context.MPtextext(font,size,text,0,-number.dimenfactors.bp*depth)
end

local bend_tolerance = 131/65536

local rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1

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
            t[nt] = f_m(pth.x_coord,pth.y_coord)
        elseif curved(ith,pth) then
            t[nt] = f_c(ith.right_x,ith.right_y,pth.left_x,pth.left_y,pth.x_coord,pth.y_coord)
        else
            t[nt] = f_l(pth.x_coord,pth.y_coord)
        end
        ith = pth
    end
    if not open then
        nt = nt + 1
        local one = path[1]
        if curved(pth,one) then
            t[nt] = f_c(pth.right_x,pth.right_y,one.left_x,one.left_y,one.x_coord,one.y_coord )
        else
            t[nt] = f_l(one.x_coord,one.y_coord)
        end
    elseif #path == 1 then
        -- special case .. draw point
        local one = path[1]
        nt = nt + 1
        t[nt] = f_l(one.x_coord,one.y_coord)
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
    t[nt] = f_cm(sx,rx,ry,sy,tx,ty)
    for i=1,#path do
        nt = nt + 1
        pth = path[i]
        if not ith then
            t[nt] = f_m(mpconcat(pth.x_coord,pth.y_coord))
        elseif curved(ith,pth) then
            local a, b = mpconcat(ith.right_x,ith.right_y)
            local c, d = mpconcat(pth.left_x,pth.left_y)
            t[nt] = f_c(a,b,c,d,mpconcat(pth.x_coord,pth.y_coord))
        else
           t[nt] = f_l(mpconcat(pth.x_coord, pth.y_coord))
        end
        ith = pth
    end
    if not open then
        nt = nt + 1
        local one = path[1]
        if curved(pth,one) then
            local a, b = mpconcat(pth.right_x,pth.right_y)
            local c, d = mpconcat(one.left_x,one.left_y)
            t[nt] = f_c(a,b,c,d,mpconcat(one.x_coord, one.y_coord))
        else
            t[nt] = f_l(mpconcat(one.x_coord,one.y_coord))
        end
    elseif #path == 1 then
        -- special case .. draw point
        nt = nt + 1
        local one = path[1]
        t[nt] = f_l(mpconcat(one.x_coord,one.y_coord))
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

local ignore   = function () end

local space    = P(" ")
local equal    = P("=")
local key      = C((1-equal)^1) * equal
local newline  = S("\n\r")^1
local number   = (((1-space-newline)^1) / tonumber) * (space^0)

local p_number  = number
local p_string  = C((1-newline)^0)
local p_boolean = P("false") * Cc(false) + P("true") * Cc(true)
local p_set     = Ct(number^1)
local p_path    = Ct(Ct(number * number^-5)^1)

-- local variable =
--     P("1:")            * key * p_number
--   + P("2:")            * key * p_string
--   + P("3:")            * key * p_boolean
--   + S("4568") * P(":") * key * p_set
--   + P("7:")            * key * p_path
--
-- local pattern_key = Cf ( Carg(1) * (Cg(variable * newline^0)^0), rawset)

local variable =
    P("1:")            * p_number
  + P("2:")            * p_string
  + P("3:")            * p_boolean
  + S("4568") * P(":") * p_set
  + P("7:")            * p_path

local pattern_tab = Cf ( Carg(1) * (Cg(variable * newline^0)^0), rawset)

local variable =
    P("1:")            * p_number
  + P("2:")            * p_string
  + P("3:")            * p_boolean
  + S("4568") * P(":") * number^1
  + P("7:")            * (number * number^-5)^1

local pattern_lst = (variable * newline^0)^0

metapost.variables  = { } -- currently across instances
metapost.properties = { } -- to be stacked

function metapost.untagvariable(str,variables) -- will be redone
    if variables == false then
        return lpegmatch(pattern_lst,str)
    else
        return lpegmatch(pattern_tab,str,1,variables or { })
    end
end

-- function metapost.processspecial(str)
--     lpegmatch(pattern_key,object.prescript,1,variables)
-- end

function metapost.processspecial(str)
    local code = loadstring(str)
    if code then
        if trace_variables then
            report_metapost("executing special code: %s",str)
        end
        code()
    else
        report_metapost("invalid special code: %s",str)
    end
end

local function setproperties(figure)
    local boundingbox = figure:boundingbox()
    local properties = {
        llx    = boundingbox[1],
        lly    = boundingbox[2],
        urx    = boundingbox[3],
        ury    = boundingbox[4],
        slot   = figure:charcode(),
        width  = figure:width(),
        height = figure:height(),
        depth  = figure:depth(),
        italic = figure:italcorr(),
        number = figure:charcode() or 0,
    }
    metapost.properties = properties
    return properties
end

local function nocomment() end

metapost.comment = nocomment

function metapost.flush(result,flusher,askedfig)
    if result then
        local figures = result.fig
        if figures then
            flusher = flusher or pdfflusher
            local resetplugins = metapost.resetplugins or ignore -- before figure
            local processplugins = metapost.processplugins or ignore -- each object
            local synchronizeplugins = metapost.synchronizeplugins or ignore
            local pluginactions = metapost.pluginactions or ignore -- before / after
            local startfigure = flusher.startfigure
            local stopfigure = flusher.stopfigure
            local flushfigure = flusher.flushfigure
            local textfigure = flusher.textfigure
            local processspecial = flusher.processspecial or metapost.processspecial
            metapost.comment = flusher.comment or nocomment
            for index=1,#figures do
                local figure = figures[index]
                local properties = setproperties(figure)
                if askedfig == "direct" or askedfig == "all" or askedfig == properties.number then
                    local objects = getobjects(result,figure,index)
                    local result = { }
                    local miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                    local llx = properties.llx
                    local lly = properties.lly
                    local urx = properties.urx
                    local ury = properties.ury
                    if urx < llx then
                        -- invalid
                        startfigure(properties.number,0,0,0,0,"invalid",figure)
                        stopfigure()
                    else
                        startfigure(properties.number,llx,lly,urx,ury,"begin",figure)
                        result[#result+1] = "q"
                        if objects then
                            resetplugins(result) -- we should move the colorinitializer here
                            local savedpath = nil
                            local savedhtap = nil
                            for o=1,#objects do
                                local object = objects[o]
                                local objecttype = object.type
                                if objecttype == "text" then
                                    result[#result+1] = "q"
                                    local ot = object.transform -- 3,4,5,6,1,2
                                    result[#result+1] = f_cm(ot[3],ot[4],ot[5],ot[6],ot[1],ot[2]) -- TH: formatters["%F %F m %F %F %F %F 0 0 cm"](unpack(ot))
                                    flushfigure(result) -- flush accumulated literals
                                    result = { }
                                    textfigure(object.font,object.dsize,object.text,object.width,object.height,object.depth)
                                    result[#result+1] = "Q"
                                elseif objecttype == "special" then
                                    if processspecial then
                                        processspecial(object.prescript)
                                    end
                                elseif objecttype == "start_clip" then
                                    local evenodd = not object.istext and object.postscript == "evenodd"
                                    result[#result+1] = "q"
                                    flushnormalpath(object.path,result,false)
                                    result[#result+1] = evenodd and "W* n" or "W n"
                                elseif objecttype == "stop_clip" then
                                    result[#result+1] = "Q"
                                    miterlimit, linecap, linejoin, dashed = -1, -1, -1, "" -- was false
                                elseif objecttype == "start_bounds" or objecttype == "stop_bounds" then
                                    -- skip
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
                                    local evenodd, collect, both = false, false, false
                                    local postscript = object.postscript
                                    if not object.istext then
                                        if postscript == "evenodd" then
                                            evenodd = true
                                        elseif postscript == "collect" then
                                            collect = true
                                        elseif postscript == "both" then
                                            both = true
                                        elseif postscript == "eoboth" then
                                            evenodd = true
                                            both    = true
                                        end
                                    end
                                    --
                                    if collect then
                                        if not savedpath then
                                            savedpath = { object.path or false }
                                            savedhtap = { object.htap or false }
                                        else
                                            savedpath[#savedpath+1] = object.path or false
                                            savedhtap[#savedhtap+1] = object.htap or false
                                        end
                                    else
                                        local objecttype = object.type -- can have changed
                                        if before then
                                            result = pluginactions(before,result,flushfigure)
                                        end
                                        local ml = object.miterlimit
                                        if ml and ml ~= miterlimit then
                                            miterlimit = ml
                                            result[#result+1] = f_M(ml)
                                        end
                                        local lj = object.linejoin
                                        if lj and lj ~= linejoin then
                                            linejoin = lj
                                            result[#result+1] = f_j(lj)
                                        end
                                        local lc = object.linecap
                                        if lc and lc ~= linecap then
                                            linecap = lc
                                            result[#result+1] = f_J(lc)
                                        end
                                        if both then
                                            if dashed ~= false then -- was just dashed test
                                               result[#result+1] = "[] 0 d"
                                               dashed = false
                                            end
                                        else
                                            local dl = object.dash
                                            if dl then
                                                local d = f_d(concat(dl.dashes or {}," "),dl.offset)
                                                if d ~= dashed then
                                                    dashed = d
                                                    result[#result+1] = d
                                                end
                                            elseif dashed ~= false then -- was just dashed test
                                               result[#result+1] = "[] 0 d"
                                               dashed = false
                                            end
                                        end
                                        local path = object.path -- newpath
                                        local transformed, penwidth = false, 1
                                        local open = path and path[1].left_type and path[#path].right_type -- at this moment only "end_point"
                                        local pen = object.pen
                                        if pen then
                                           if pen.type == 'elliptical' then
                                                transformed, penwidth = pen_characteristics(original) -- boolean, value
                                                result[#result+1] = f_w(penwidth) -- todo: only if changed
                                                if objecttype == 'fill' then
                                                    objecttype = 'both'
                                                end
                                           else -- calculated by mplib itself
                                                objecttype = 'fill'
                                           end
                                        end
                                        if transformed then
                                            result[#result+1] = "q"
                                        end
                                        if path then
                                            if savedpath then
                                                for i=1,#savedpath do
                                                    local path = savedpath[i]
                                                    if transformed then
                                                        flushconcatpath(path,result,open)
                                                    else
                                                        flushnormalpath(path,result,open)
                                                    end
                                                end
                                                savedpath = nil
                                            end
                                            if transformed then
                                                flushconcatpath(path,result,open)
                                            else
                                                flushnormalpath(path,result,open)
                                            end
                                            if objecttype == "fill" then
                                                result[#result+1] = evenodd and "h f*" or "h f" -- f* = eo
                                            elseif objecttype == "outline" then
                                                if both then
                                                    result[#result+1] = evenodd and "h B*" or "h B" -- f* = eo
                                                else
                                                    result[#result+1] = open and "S" or "h S"
                                                end
                                            elseif objecttype == "both" then
                                                result[#result+1] = evenodd and "h B*" or "h B"-- B* = eo -- b includes closepath
                                            end
                                        end
                                        if transformed then
                                            result[#result+1] = "Q"
                                        end
                                        local path = object.htap
                                        if path then
                                            if transformed then
                                                result[#result+1] = "q"
                                            end
                                            if savedhtap then
                                                for i=1,#savedhtap do
                                                    local path = savedhtap[i]
                                                    if transformed then
                                                        flushconcatpath(path,result,open)
                                                    else
                                                        flushnormalpath(path,result,open)
                                                    end
                                                end
                                                savedhtap = nil
                                                evenodd   = true
                                            end
                                            if transformed then
                                                flushconcatpath(path,result,open)
                                            else
                                                flushnormalpath(path,result,open)
                                            end
                                            if objecttype == "fill" then
                                                result[#result+1] = evenodd and "h f*" or "h f" -- f* = eo
                                            elseif objecttype == "outline" then
                                                result[#result+1] = open and "S" or "h S"
                                            elseif objecttype == "both" then
                                                result[#result+1] = evenodd and "h B*" or "h B"-- B* = eo -- b includes closepath
                                            end
                                            if transformed then
                                                result[#result+1] = "Q"
                                            end
                                        end
                                        if after then
                                            result = pluginactions(after,result,flushfigure)
                                        end
                                    end
                                    if object.grouped then
                                        -- can be qQ'd so changes can end up in groups
                                        miterlimit, linecap, linejoin, dashed = -1, -1, -1, "" -- was false
                                    end
                                end
                            end
                        end
                        result[#result+1] = "Q"
                        flushfigure(result)
                        stopfigure("end")
                    end
                    if askedfig ~= "all" then
                        break
                    end
                end
            end
            metapost.comment = nocomment
        end
    end
end

function metapost.parse(result,askedfig)
    if result then
        local figures = result.fig
        if figures then
            local multipass = false
            local analyzeplugins = metapost.analyzeplugins -- each object
            for index=1,#figures do
                local figure = figures[index]
                local properties = setproperties(figure)
                if askedfig == "direct" or askedfig == "all" or askedfig == properties.number then
                    local objects = getobjects(result,figure,index)
                    if objects then
                        for o=1,#objects do
                            if analyzeplugins(objects[o]) then
                                multipass = true
                            end
                        end
                    end
                    if askedfig ~= "all" then
                        break
                    end
                end
            end
            return multipass
        end
    end
end

-- tracing:

local result = { }

local flusher = {
    startfigure = function()
        result = { }
        context.startnointerference()
    end,
    flushfigure = function(literals)
        local n = #result
        for i=1,#literals do
            result[n+i] = literals[i]
        end
    end,
    stopfigure = function()
        context.stopnointerference()
    end
}

function metapost.pdfliterals(result)
    metapost.flush(result,flusher)
    return result
end

function metapost.totable(result,askedfig)
    local askedfig = askedfig or 1
    local figure   = result and result.fig and result.fig[1]
    if figure then
        local results = { }
     -- local objects = figure:objects()
        local objects = getobjects(result,figure,askedfig)
        for o=1,#objects do
            local object = objects[o]
            local result = { }
            local fields = object_fields(object) -- hm, is this the whole list, if so, we can get it once
            for f=1,#fields do
                local field = fields[f]
                result[field] = object[field]
            end
            results[o] = result
        end
        local boundingbox = figure:boundingbox()
        return {
            boundingbox = {
                llx = boundingbox[1],
                lly = boundingbox[2],
                urx = boundingbox[3],
                ury = boundingbox[4],
            },
            objects = results
        }
    else
        return nil
    end
end
