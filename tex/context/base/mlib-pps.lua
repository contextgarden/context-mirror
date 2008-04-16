if not modules then modules = { } end modules ['mlib-pps'] = { -- prescript, postscripts and specials
    version   = 1.001,
    comment   = "companion to mlib-ctx.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, join, round = string.format, table.concat, math.round
local sprint = tex.sprint

colors = colors or { }

local rgbtocmyk  = colors.rgbtocmyk   or function() return 0,0,0,1 end
local cmyktorgb  = colors.cmyktorgb   or function() return 0,0,0   end
local rgbtogray  = colors.rgbtogray   or function() return 0       end
local cmyktogray = colors.cmyktogray  or function() return 0       end

metapost               = metapost or { }
metapost.specials      = metapost.specials or { }
metapost.specials.data = metapost.specials.data or { }

local data = metapost.specials.data

local colordata = { {}, {}, {}, {}, {} }

--~ (r,g,b) => cmyk             : r=123 g=   1 b=hash
--~         => spot             : r=123 g=   2 b=hash
--~         => transparent rgb  : r=123 g=   3 b=hash
--~         => transparent cmyk : r=123 g=   4 b=hash
--~         => transparent spot : r=123 g=   5 b=hash
--~         => rest             : r=123 g=n>10 b=whatever

function metapost.specials.register(str) -- only colors
    local size, content, n, class = str:match("^%%%%MetaPostSpecial: (%d+) (.*) (%d+) (%d+)$")
    if class then
        local data = { }
        for s in content:gmatch("[^ ]+") do
            data[#data+1] = s
        end
        class, n = tonumber(class), tonumber(n)
        if class == 3 or class == 4 or class == 5 then -- weird
            colordata[class][n] = data
        else
            colordata[class][tonumber(data[1])] = data
        end
    end
end

function metapost.colorhandler(cs, object, result, colorconverter)
    local cr = "0 g 0 G"
    local what = round(cs[2]*10000)
    local data = colordata[what][round(cs[3]*10000)]
    if not data then
        --
    elseif what == 1 then
        result[#result+1], cr = colorconverter({ data[2], data[3], data[4], data[5] })
    elseif what == 2 then
        ctx.registerspotcolor(data[2])
        result[#result+1] = ctx.pdfcolor(colors.model,colors.register('color',nil,'spot',data[2],data[3],data[4],data[5]))
    else
        if what == 3 then
            result[#result+1], cr = colorconverter({ data[3], data[4], data[5]})
        elseif what == 4 then
            result[#result+1], cr = colorconverter({ data[3], data[4], data[5], data[6]})
        elseif what == 5 then
            ctx.registerspotcolor(data[3])
            result[#result+1] = ctx.pdfcolor(colors.model,colors.register('color',nil,'spot',data[3],data[4],data[5],data[6]))
        end
        object.prescript = "tr"
        object.postscript = data[1] .. "," .. data[2]
    end
    object.color = nil
    return object, cr
end

function metapost.colorspec(cs)
    local what = round(cs[2]*10000)
    local data = colordata[what][round(cs[3]*10000)]
    if not data then
        return { 0 }
    elseif what == 1 then
        return { data[2], data[3], data[4], data[5] }
    elseif what == 2 then
        ctx.registerspotcolor(data[2])
        return ctx.pdfcolor(colors.model,colors.register('color',nil,'spot',data[2],data[3],data[4],data[5]))
    elseif what == 3 then
        return { data[3], data[4], data[5] }
    elseif what == 4 then
        return { data[3], data[4], data[5], data[6] }
    elseif what == 5 then
        ctx.registerspotcolor(data[3])
        return ctx.pdfcolor(colors.model,colors.register('color',nil,'spot',data[3],data[4],data[5],data[6]))
    end
end

function metapost.specials.tr(specification,object,result)
    local a, t = specification:match("^(.+),(.+)$")
    local before = a and t and function()
        result[#result+1] = format("/Tr%s gs",transparencies.register('mp',a,t))
        return object, result
    end
    local after = before and function()
        result[#result+1] = "/Tr0 gs"
        return object, result
    end
    return object, before, nil, after
end

--~ -- possible speedup: hash registered colors
--~
--~ function metapost.specials.sp(specification,object,result) -- todo: color conversion
--~     local s = object.color[1]
--~     object.color = nil
--~     local before = function()
--~         local spec = specification:split(" ")
--~         ctx.registerspotcolor(spec[1])
--~         result[#result+1] = ctx.pdfcolor(colors.model,colors.register('color',nil,'spot',spec[1],spec[2],spec[3],s))
--~         return object, result
--~     end
--~     local after = function()
--~         result[#result+1] = "0 g 0 G"
--~         return object, result
--~     end
--~     return object, before, nil, nil
--~ end

-- Unfortunately we cannot use cmyk colors natively because there is no
-- generic color allocation primitive ... it's just an rgbcolor color.. This
-- means that we cannot pass colors in either cmyk or rgb form.
--
-- def cmyk(expr c,m,y,k) =
--     1 withprescript "cc" withpostscript ddddecimal (c,m,y,k)
-- enddef ;
--
-- This is also an example of a simple plugin.

--~ function metapost.specials.cc(specification,object,result)
--~     object.color = specification:split(" ")
--~     return object, nil, nil, nil
--~ end
--~ function metapost.specials.cc(specification,object,result)
--~     local c = specification:split(" ")
--~     local o = object.color[1]
--~     c[1],c[2],c[3],c[4] = o*c[1],o*c[2],o*c[3],o*c[4]
--~     return object, nil, nil, nil
--~ end

-- thanks to taco's reading of the postscript manual:
--
-- x' = sx * x + ry * y + tx
-- y' = rx * x + sy * y + ty

function metapost.specials.fg(specification,object,result,flusher)
    local op = object.path
    local first, second, fourth  = op[1], op[2], op[4]
    local tx, ty = first.x_coord      , first.y_coord
    local sx, sy = second.x_coord - tx, fourth.y_coord - ty
    local rx, ry = second.y_coord - ty, fourth.x_coord - tx
    if sx == 0 then sx = 0.00001 end
    if sy == 0 then sy = 0.00001 end
    local before = specification and function()
        flusher.flushfigure(result)
        sprint(tex.ctxcatcodes,format("\\MPLIBfigure{%f}{%f}{%f}{%f}{%f}{%f}{%s}",sx,rx,ry,sy,tx,ty,specification))
        return object, { }
    end
    return { } , before, nil, nil -- replace { } by object for tracing
end

local nofshades = 0 -- todo: hash resources, start at 1000 in order not to clash with older

local function normalize(ca,cb)
    if #cb == 1 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = 0, 0, 0, 1-cb[1]
        else
            cb[1], cb[2], cb[3] = cb[1], cb[1], cb[1]
        end
    elseif #cb == 3 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = rgbtocmyk(cb[1],cb[2],cb[3])
        else
            cb[1], cb[2], cb[3] = cmyktorgb(cb[1],cb[2],cb[3],cb[4])
        end
    end
end

function metapost.specials.cs(specification,object,result,flusher) -- spot colors?
    nofshades = nofshades + 1
    flusher.flushfigure(result)
    result = { }
    local t = specification:split(" ")
    -- we need a way to move/scale
    local ca = t[4]:split(":")
    local cb = t[8]:split(":")
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    if type(ca) == "string" then
        -- spot color, not supported, maybe at some point use the fallbacks
        sprint(tex.ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s %s %s}",
            nofshades,
            t[1], t[2], 0, 1, 1, "DeviceGray",
            t[5], t[6], t[7], t[9], t[10], t[11]))
    else
        if #ca > #cb then
            normalize(ca,cb)
        elseif #ca < #cb then
            normalize(cb,ca)
        end
        local model = colors.model
        if model == "all" then
            model= (#ca == 4 and "cmyk") or (#ca == 3 and "rgb") or "gray"
        end
        if model == "rgb" then
            if #ca == 4 then
                ca[1], ca[2], ca[3] = cmyktorgb(ca[1],ca[2],ca[3],ca[4])
                cb[1], cb[2], cb[3] = cmyktorgb(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 1 then
                local a, b = 1-ca[1], 1-cb[1]
                ca[1], ca[2], ca[3] = a, a, a
                cb[1], cb[2], cb[3] = b, b, b
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f %.3f %.3f}{%.3f %.3f %.3f}{%s}{%s}{%s %s %s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], ca[2], ca[3], cb[1], cb[2], cb[3], 1, "DeviceRGB",
                t[5], t[6], t[7], t[9], t[10], t[11]))
        elseif model == "cmyk" then
            if #ca == 3 then
                ca[1], ca[2], ca[3], ca[4] = rgbtocmyk(ca[1],ca[2],ca[3])
                cb[1], cb[2], cb[3], ca[4] = rgbtocmyk(cb[1],cb[2],cb[3])
            elseif #ca == 1 then
                ca[1], ca[2], ca[3], ca[4] = 0, 0, 0, ca[1]
                cb[1], cb[2], cb[3], ca[4] = 0, 0, 0, ca[1]
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f %.3f %.3f %.3f}{%.3f %.3f %.3f %.3f}{%s}{%s}{%s %s %s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], ca[2], ca[3], ca[4], cb[1], cb[2], cb[3], cb[4], 1, "DeviceCMYK",
                t[5], t[6], t[7], t[9], t[10], t[11]))
        else
            if #ca == 4 then
                ca[1] = cmyktogray(ca[1],ca[2],ca[3],ca[4])
                cb[1] = cmyktogray(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 3 then
                ca[1] = rgbtogray(ca[1],ca[2],ca[3])
                cb[1] = rgbtogray(cb[1],cb[2],cb[3])
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], cb[1], 1, "DeviceGray",
                t[5], t[6], t[7], t[9], t[10], t[11]))
        end
    end
    local before = function()
        result[#result+1] = "q /Pattern cs"
        return object, result
    end
    local after = function()
        result[#result+1] = format("W n /MpSh%s sh Q", nofshades)
        return object, result
    end
    object.color, object.type = nil, nil
    return object, before, nil, after
end

function metapost.specials.ls(specification,object,result,flusher)
    nofshades = nofshades + 1
    flusher.flushfigure(result)
    result = { }
    local t = specification:split(" ")
    -- we need a way to move/scale
    local ca = t[4]:split(":")
    local cb = t[7]:split(":")
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    if type(ca) == "string" then
        -- spot color, not supported, maybe at some point use the fallbacks
        sprint(tex.ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s}",
            nofshades,
            t[1], t[2], 0, 1, 1, "DeviceGray",
            t[5], t[6], t[8], t[9]))
    else
        if #ca > #cb then
            normalize(ca,cb)
        elseif #ca < #cb then
            normalize(cb,ca)
        end
        local model = colors.model
        if model == "all" then
            model= (#ca == 4 and "cmyk") or (#ca == 3 and "rgb") or "gray"
        end
        if model == "rgb" then
            if #ca == 4 then
                ca[1], ca[2], ca[3] = cmyktorgb(ca[1],ca[2],ca[3],ca[4])
                cb[1], cb[2], cb[3] = cmyktorgb(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 1 then
                local a, b = 1-ca[1], 1-cb[1]
                ca[1], ca[2], ca[3] = a, a, a
                cb[1], cb[2], cb[3] = b, b, b
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f %.3f %.3f}{%.3f %.3f %.3f}{%s}{%s}{%s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], ca[2], ca[3], cb[1], cb[2], cb[3], 1, "DeviceRGB",
                t[5], t[6], t[8], t[9]))
        elseif model == "cmyk" then
            if #ca == 3 then
                ca[1], ca[2], ca[3], ca[4] = rgbtocmyk(ca[1],ca[2],ca[3])
                cb[1], cb[2], cb[3], ca[4] = rgbtocmyk(cb[1],cb[2],cb[3])
            elseif #ca == 1 then
                ca[1], ca[2], ca[3], ca[4] = 0, 0, 0, ca[1]
                cb[1], cb[2], cb[3], ca[4] = 0, 0, 0, ca[1]
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f %.3f %.3f %.3f}{%.3f %.3f %.3f %.3f}{%s}{%s}{%s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], ca[2], ca[3], ca[4], cb[1], cb[2], cb[3], cb[4], 1, "DeviceCMYK",
                t[5], t[6], t[8], t[9]))
        else
            if #ca == 4 then
                ca[1] = cmyktogray(ca[1],ca[2],ca[3],ca[4])
                cb[1] = cmyktogray(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 3 then
                ca[1] = rgbtogray(ca[1],ca[2],ca[3])
                cb[1] = rgbtogray(cb[1],cb[2],cb[3])
            end
            sprint(tex.ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s}",
                nofshades,
                t[1], t[2], ca[1], cb[1], 1, "DeviceGray",
                t[5], t[6], t[8], t[9]))
        end
    end
    local before = function()
        result[#result+1] = "q /Pattern cs"
        return object, result
    end
    local after = function()
        result[#result+1] = format("W n /MpSh%s sh Q", nofshades)
        return object, result
    end
    object.color, object.type = nil, nil
    return object, before, nil, after
end

-- no need for a before here

local current_format, current_graphic

--~ metapost.first_box, metapost.last_box = 1000, 1100

metapost.textext_current = metapost.first_box

function metapost.specials.tf(specification,object)
--~ print("setting", metapost.textext_current)
    sprint(tex.ctxcatcodes,format("\\MPLIBsettext{%s}{%s}",metapost.textext_current,specification))
    if metapost.textext_current < metapost.last_box then
        metapost.textext_current = metapost.textext_current + 1
    end
    return { }, nil, nil, nil
end

function metapost.specials.ts(specification,object,result,flusher)
    -- print("getting", metapost.textext_current)
    local op = object.path
    local first, second, fourth  = op[1], op[2], op[4]
    local tx, ty = first.x_coord      , first.y_coord
    local sx, sy = second.x_coord - tx, fourth.y_coord - ty
    local rx, ry = second.y_coord - ty, fourth.x_coord - tx
    if sx == 0 then sx = 0.00001 end
    if sy == 0 then sy = 0.00001 end
    local before = function()
    --~ flusher.flushfigure(result)
    --~ sprint(tex.ctxcatcodes,format("\\MPLIBgettext{%f}{%f}{%f}{%f}{%f}{%f}{%s}",sx,rx,ry,sy,tx,ty,metapost.textext_current))
    --~ result = { }
        result[#result+1] = format("q %f %f %f %f %f %f cm", sx,rx,ry,sy,tx,ty)
        flusher.flushfigure(result)
        local b = metapost.textext_current
        sprint(tex.ctxcatcodes,format("\\MPLIBgettextscaled{%s}{%s}{%s}",b, metapost.sxsy(tex.wd[b],tex.ht[b],tex.dp[b])))
        result = { "Q" }
        if metapost.textext_current < metapost.last_box then
            metapost.textext_current = metapost.textext_current + 1
        end
        return object, result
    end
    return { }, before, nil, nil -- replace { } by object for tracing
end

function metapost.colorconverter()
    -- it no longer pays off to distinguish between outline and fill
    --  (we now have both too, e.g. in arrows)
    local model = colors.model
    if model == "all" then
        return function(cr)
            local n = #cr
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s), "0 g 0 G"
            elseif n == 4 then
                local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k), "0 g 0 G"
            else
                local r, g, b = cr[1], cr[2], cr[3]
                return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b), "0 g 0 G"
            end
        end
    elseif model == "rgb" then
        return function(cr)
            local n = #cr
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s), "0 g 0 G"
            end
            local r, g, b
            if n == 4 then
                r, g, b = cmyktorgb(cr[1],cr[2],cr[3],cr[4])
            else
                r, g, b = cr[1],cr[2],cr[3]
            end
            return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b), "0 g 0 G"
        end
    elseif model == "cmyk" then
        return function(cr)
            local n = #cr
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s), "0 g 0 G"
            end
            local c, m, y, k
            if n == 4 then
                c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            else
                c, m, y, k = rgbtocmyk(cr[1],cr[2],cr[3])
            end
            return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k), "0 g 0 G"
        end
    else
        return function(cr)
            local s
            local n = #cr
            if n == 4 then
                s = cmyktogray(cr[1],cr[2],cr[3],cr[4])
            elseif n == 3 then
                s = rgbtogray(cr[1],cr[2],cr[3])
            else
                s = cr[1]
            end
            return format("%.3f g %.3f G",s,s), "0 g 0 G"
        end
    end
end

--~ local cmyk_fill    = "%.3f %.3f %.3f %.3f k"
--~ local rgb_fill     = "%.3f %.3f %.3f rg"
--~ local gray_fill    = "%.3f g"
--~ local reset_fill   = "0 g"

--~ local cmyk_stroke  = "%.3f %.3f %.3f %.3f K"
--~ local rgb_stroke   = "%.3f %.3f %.3f RG"
--~ local gray_stroke  = "%.3f G"
--~ local reset_stroke = "0 G"

metapost.reducetogray = true

function metapost.colorconverter()
    -- it no longer pays off to distinguish between outline and fill
    --  (we now have both too, e.g. in arrows)
    local model = colors.model
    local reduce = metapost.reducetogray
    if model == "all" then
        return function(cr)
            local n = #cr
            if reduce and n == 3 then if cr[1] == cr[2] and cr[1] == cr[3] then n = 1 end end
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s)
            elseif n == 4 then
                local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k)
            else
                local r, g, b = cr[1], cr[2], cr[3]
                return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b)
            end
        end
    elseif model == "rgb" then
        return function(cr)
            local n = #cr
            if reduce and n == 3 then if cr[1] == cr[2] and cr[1] == cr[3] then n = 1 end end
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s)
            end
            local r, g, b
            if n == 4 then
                r, g, b = cmyktorgb(cr[1],cr[2],cr[3],cr[4])
            else
                r, g, b = cr[1],cr[2],cr[3]
            end
            return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b)
        end
    elseif model == "cmyk" then
        return function(cr)
            local n = #cr
            if reduce and n == 3 then if cr[1] == cr[2] and cr[1] == cr[3] then n = 1 end end
            if n == 1 then
                local s = cr[1]
                return format("%.3f g %.3f G",s,s)
            end
            local c, m, y, k
            if n == 4 then
                c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            else
                c, m, y, k = rgbtocmyk(cr[1],cr[2],cr[3])
            end
            return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k)
        end
    else
        return function(cr)
            local n = #cr
            if reduce and n == 3 then if cr[1] == cr[2] and cr[1] == cr[3] then n = 1 end end
            if n == 4 then
                s = cmyktogray(cr[1],cr[2],cr[3],cr[4])
            elseif n == 3 then
                s = rgbtogray(cr[1],cr[2],cr[3])
            else
                s = cr[1]
            end
            return format("%.3f g %.3f G",s,s)
        end
    end
end

-- textext stuff

--~ do
--~
--~     local P, V, Cs = lpeg.P, lpeg.V, lpeg.Cs
--~
--~     local btex    = P("btex")
--~     local etex    = P("etex")
--~     local vtex    = P("verbatimtex")
--~     local ttex    = P("textext")
--~     local gtex    = P("graphictext")
--~     local spacing = P(" \n\r\t\v")^0
--~     local left    = P("(")
--~     local right   = P(")")
--~     local dquote  = P('"')
--~     local ddquote = P('\\"') / "\\\" & ditto & \""
--~
--~     local found, n = false, 0
--~
--~     local function textext_first(s)
--~         local str = format('_tex_text_f_("%s")',s)
--~         found, n = true, n + 1
--~         return str
--~     end
--~     local function textext_second()
--~         local str = format('_tex_text_s_(%s,%spt,%spt,%spt)',n,tex.wd[n]/65536,tex.ht[n]/65536,tex.dp[n]/65536)
--~         found, n = true, n + 1
--~         return str
--~     end
--~     local function graphictext_first(s)
--~         local str = format('_graphic_text_f_("%s")',s)
--~         found = true
--~         return str
--~     end
--~     local function graphictext_second()
--~         local str = format('_graphic_text_s_')
--~         found = true
--~         return str
--~     end
--~
--~     -- the next lpegs can be more efficient (in code only) by not using a grammar
--~
--~     local first = P {
--~         [1] = Cs(((V(2) + V(3))/textext_first + V(4)/graphictext_first + 1)^0),
--~         [2] = (btex + vtex) * spacing * Cs((1-etex)^0) * spacing * etex,
--~         [3] = ttex * spacing * left * spacing * V(5) * spacing * right,
--~         [4] = gtex * spacing * V(5),
--~         [5] = dquote * Cs((ddquote + (1-dquote))^0) * dquote,
--~     }
--~
--~     local second = P {
--~         [1] = Cs(((V(2) + V(3))/textext_second + V(4)/graphictext_second + 1)^0),
--~         [2] = (btex + vtex) * spacing * Cs((1-etex)^0) * spacing * etex,
--~         [3] = ttex * spacing * left * spacing * V(5) * spacing * right,
--~         [4] = gtex * spacing * V(5),
--~         [5] = dquote * Cs((ddquote + (1-dquote))^0) * dquote,
--~     }
--~
--~     function metapost.texttext_first(str)
--~         found, n = false, metapost.first_box -- or 0 no fallback, better an error
--~         return first:match(str), found
--~     end
--~     function metapost.texttext_second(str)
--~         found, n = false, metapost.first_box -- or 0 no fallback, better an error
--~         return second:match(str), found
--~     end
--~
--~ end
--~
--~ local factor = 65536*(7200/7227)
--~
--~ function metapost.edefsxsy(wd,ht,dp) -- helper for text
--~     commands.edef("sx",(wd ~= 0 and 1/( wd    /(factor))) or 0)
--~     commands.edef("sy",(wd ~= 0 and 1/((ht+dp)/(factor))) or 0)
--~ end
--~
--~ function metapost.sxsy(wd,ht,dp) -- helper for text
--~     return (wd ~= 0 and 1/(wd/(factor))) or 0, (wd ~= 0 and 1/((ht+dp)/(factor))) or 0
--~ end
--~
--~ metapost.intermediate         = metapost.intermediate         or {}
--~ metapost.intermediate.actions = metapost.intermediate.actions or {}
--~ metapost.intermediate.needed  = false
--~
--~ function metapost.graphic_base_pass(mpsformat,str,preamble)
--~     local prepared, done = metapost.texttext_first(str)
--~     metapost.textext_current = metapost.first_box
--~     metapost.intermediate.needed  = false
--~     if done then
--~         current_format, current_graphic = mpsformat, str
--~         metapost.process(mpsformat, {
--~             preamble or "",
--~             "beginfig(1); ",
--~             prepared,
--~             "endfig ;"
--~         }, true ) -- true means: trialrun
--~         if metapost.intermediate.needed then
--~             for _, action in pairs(metapost.intermediate.actions) do
--~                 action()
--~             end
--~         end
--~         sprint(tex.ctxcatcodes,"\\ctxlua{metapost.graphic_extra_pass()}")
--~     else
--~         metapost.process(mpsformat, {
--~             preamble or "",
--~             "beginfig(1); ",
--~             str,
--~             "endfig ;"
--~         } )
--~     end
--~ end
--~
--~ function metapost.graphic_extra_pass()
--~     local prepared, done = metapost.texttext_second(current_graphic)
--~     metapost.textext_current = metapost.first_box
--~     metapost.process(current_format, {
--~         "beginfig(0); ",
--~         prepared,
--~         "endfig ;"
--~     })
--~ end

--~ At the cost of passing data about the texts to MP, the following
--~ solution also handles textexts that are more complex and part of
--~ formats.

do

    local P, S, V, Cs = lpeg.P, lpeg.S, lpeg.V, lpeg.Cs

    local btex    = P("btex")
    local etex    = P(" etex")
    local vtex    = P("verbatimtex")
    local ttex    = P("textext")
    local gtex    = P("graphictext")
    local spacing = S(" \n\r\t\v")^0
    local dquote  = P('"')

    local found = false

    local function convert(str)
        found = true
        return "textext(\"" .. str .. "\")"
    end
    local function ditto(str)
        return "\" & ditto & \""
    end
    local function register()
        found = true
    end

    local parser = P {
        [1] = Cs((V(2)/register + V(3)/convert + 1)^0),
        [2] = ttex + gtex,
        [3] = (btex + vtex) * spacing * Cs((dquote/ditto + (1 - etex))^0) * etex,
    }

    -- currently a a one-liner produces less code

    local parser = Cs(((ttex + gtex)/register + ((btex + vtex) * spacing * Cs((dquote/ditto + (1 - etex))^0) * etex)/convert + 1)^0)

    function metapost.check_texts(str)
        found = false
        return parser:match(str), found
    end

end

local factor = 65536*(7200/7227)

function metapost.edefsxsy(wd,ht,dp) -- helper for text
    commands.edef("sx",(wd ~= 0 and 1/( wd    /(factor))) or 0)
    commands.edef("sy",(wd ~= 0 and 1/((ht+dp)/(factor))) or 0)
end

function metapost.sxsy(wd,ht,dp) -- helper for text
    return (wd ~= 0 and 1/(wd/(factor))) or 0, (wd ~= 0 and 1/((ht+dp)/(factor))) or 0
end

function metapost.text_texts_data()
    local t, n = { }, 0
    for i = metapost.first_box, metapost.last_box do
        n = n + 1
        if tex.box[i] then
            t[#t+1] = format("_tt_w_[%i]:=%f;_tt_h_[%i]:=%f;_tt_d_[%i]:=%f;", n,tex.wd[i]/factor, n,tex.ht[i]/factor, n,tex.dp[i]/factor)
        else
            break
        end
    end
    return t
end

metapost.intermediate         = metapost.intermediate         or {}
metapost.intermediate.actions = metapost.intermediate.actions or {}
metapost.intermediate.needed  = false

function metapost.graphic_base_pass(mpsformat,str,preamble)
    local prepared, done = metapost.check_texts(str)
    metapost.textext_current = metapost.first_box
    metapost.intermediate.needed  = false
    if done then
        current_format, current_graphic = mpsformat, prepared
        metapost.process(mpsformat, {
            preamble or "",
            "beginfig(1); ",
            "_trial_run_ := true ;",
            prepared,
            "endfig ;"
        }, true ) -- true means: trialrun
        if metapost.intermediate.needed then
            for _, action in pairs(metapost.intermediate.actions) do
                action()
            end
        end
        sprint(tex.ctxcatcodes,"\\ctxlua{metapost.graphic_extra_pass()}")
    else
        metapost.process(mpsformat, {
            preamble or "",
            "beginfig(1); ",
            "_trial_run_ := false ;",
            str,
            "endfig ;"
        } )
    end
end

function metapost.graphic_extra_pass()
    metapost.textext_current = metapost.first_box
    metapost.process(current_format, {
        "beginfig(0); ",
        "_trial_run_ := false ;",
        join(metapost.text_texts_data()," ;\n"),
        current_graphic,
        "endfig ;"
    })
end

function metapost.getclippath(data)
    local mpx = metapost.format("metafun")
    if mpx and data then
        input.starttiming(metapost)
        input.starttiming(metapost.exectime)
        local result = mpx:execute(format("beginfig(1);%s;endfig;",data))
        input.stoptiming(metapost.exectime)
        if result.status > 0 then
            print("error", result.status, result.error or result.term or result.log)
            result = ""
        else
            result = metapost.filterclippath(result)
        end
        input.stoptiming(metapost)
        sprint(result)
    end
end

do -- not that beautiful but ok, we could save a md5 hash in the tui file !

    local graphics = { }
    local start    = [[\starttext]]
    local preamble = [[\def\MPLIBgraphictext#1{\startTEXpage[scale=10000]#1\stopTEXpage}]]
    local stop     = [[\stoptext]]

    function metapost.specials.gt(specification,object) -- number, so that we can reorder
        graphics[#graphics+1] = format("\\MPLIBgraphictext{%s}",specification)
        metapost.intermediate.needed = true
        return { }, nil, nil, nil
    end

    function metapost.intermediate.actions.makempy()
        if #graphics > 0 then
            local mpofile = tex.jobname .. "-mp"
            local mpyfile = file.replacesuffix(mpofile,"mpy")
            local pdffile = file.replacesuffix(mpofile,"pdf")
            local texfile = file.replacesuffix(mpofile,"tex")
            io.savedata(texfile, { start, preamble, join(graphics,"\n"), stop }, "\n")
            os.execute(format("context --once %s", texfile))
            if io.exists(pdffile) then
                os.execute(format("pstoedit -ssp -dt -f mpost %s %s", pdffile, mpyfile))
                local result = { }
                if io.exists(mpyfile) then
                    local data = io.loaddata(mpyfile)
                    for figure in data:gmatch("beginfig(.-)endfig") do
                        result[#result+1] = format("begingraphictextfig%sendgraphictextfig ;\n", figure)
                    end
                    io.savedata(mpyfile,join(result,""))
                end
            end
            graphics = { }
        end
    end

end
