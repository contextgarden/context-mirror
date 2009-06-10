if not modules then modules = { } end modules ['mlib-pps'] = { -- prescript, postscripts and specials
    version   = 1.001,
    comment   = "companion to mlib-ctx.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- current limitation: if we have textext as well as a special color then due to
-- prescript/postscript overload we can have problems

local format, gmatch, concat, round, match = string.format, string.gmatch, table.concat, math.round, string.match
local sprint = tex.sprint
local tonumber, type = tonumber, type

local ctxcatcodes = tex.ctxcatcodes

local trace_textexts = false  trackers.register("metapost.textexts", function(v) trace_textexts = v end)

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

local nooutercolor        = "0 g 0 G"
local nooutertransparency = "/Tr0 gs"
local outercolormode      = 0
local outercolor          = nooutercolor
local outertransparency   = nooutertransparency
local innercolor          = nooutercolor
local innertransparency   = nooutertransparency

function metapost.set_outer_color(mode,color,transparency)
    -- has always to be called before conversion
    -- todo: transparency (not in the mood now)
    outercolormode = mode
    if mode == 1 or mode == 3 then
        -- inherit from outer
        outercolor        = color        or nooutercolor
        outertransparency = transparency or nooutertransparency
    elseif mode == 2 then
        -- stand alone
        outercolor        = ""
        outertransparency = ""
    else -- 0
        outercolor        = nooutercolor
        outertransparency = nooutertransparency
    end
    innercolor = outercolor
    innertransparency = outertransparency
end

local function checked_color_pair(color)
    if not color then
        return innercolor, outercolor
    elseif outercolormode == 3 then
        innercolor = color
        return innercolor, innercolor
    else
        return color, outercolor
    end
end

metapost.checked_color_pair = checked_color_pair

function metapost.colorinitializer()
    innercolor = outercolor
    innertransparency = outertransparency
    return outercolor, outertransparency
end

function metapost.specials.register(str) -- only colors
    local size, content, n, class = match(str,"^%%%%MetaPostSpecial: (%d+) (.*) (%d+) (%d+)$")
    if class then
        -- use lpeg splitter
        local data = { }
        for s in gmatch(content,"[^ ]+") do
            data[#data+1] = s
        end
        class, n = tonumber(class), tonumber(n)
        if class == 3 or class == 4 or class == 5 then
            -- hm, weird
        else
            n = tonumber(data[1])
        end
        if n then
            local cc = colordata[class]
            if cc then
                cc[n] = data
            else
                logs.report("mplib","problematic special: %s (no colordata class %s)", str or "?",class)
            end
        else
         -- there is some bug to be solved, so we issue a message
            logs.report("mplib","problematic special: %s", str or "?")
        end
    end
--~     if str:match("^%%%%MetaPostOption: multipass") then
--~         metapost.multipass = true
--~     end
end

function metapost.colorhandler(cs, object, result, colorconverter)
    local cr = outercolor
    local what = round(cs[2]*10000)
    local data = colordata[what]
    if data then
        data = data[round(cs[3]*10000)]
    end
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
    local a, t = match(specification,"^(.+),(.+)$")
    local before = a and t and function()
        result[#result+1] = format("/Tr%s gs",transparencies.register('mp',a,t))
        return object, result
    end
    local after = before and function()
        result[#result+1] = outertransparency -- here we could revert to teh outer color
        return object, result
    end
    return object, before, nil, after
end

local specificationsplitter = lpeg.Ct(lpeg.splitat(" "))
local colorsplitter         = lpeg.Ct(lpeg.splitat(":"))

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
--~     object.color = specificationsplitter:match(specification)
--~     return object, nil, nil, nil
--~ end
--~ function metapost.specials.cc(specification,object,result)
--~     local c = specificationsplitter:match(specification)
--~     local o = object.color[1]
--~     c[1],c[2],c[3],c[4] = o*c[1],o*c[2],o*c[3],o*c[4]
--~     return object, nil, nil, nil
--~ end

-- thanks to taco's reading of the postscript manual:
--
-- x' = sx * x + ry * y + tx
-- y' = rx * x + sy * y + ty

function metapost.specials.fg(specification,object,result,flusher) -- graphics
    local op = object.path
    local first, second, fourth  = op[1], op[2], op[4]
    local tx, ty = first.x_coord      , first.y_coord
    local sx, sy = second.x_coord - tx, fourth.y_coord - ty
    local rx, ry = second.y_coord - ty, fourth.x_coord - tx
    if sx == 0 then sx = 0.00001 end
    if sy == 0 then sy = 0.00001 end
    local before = specification and function()
        flusher.flushfigure(result)
        sprint(ctxcatcodes,format("\\MPLIBfigure{%f}{%f}{%f}{%f}{%f}{%f}{%s}",sx,rx,ry,sy,tx,ty,specification))
        object.path = nil
        return object, { }
    end
    return { } , before, nil, nil -- replace { } by object for tracing
end

function metapost.specials.ps(specification,object,result) -- positions
    local op = object.path
    local first, third  = op[1], op[3]
    local x, y = first.x_coord, first.y_coord
    local w, h = third.x_coord - x, third.y_coord - y
    local label = specification
    x = x - metapost.llx
    y = metapost.ury - y
 -- logs.report("mplib", "todo: position '%s' at (%s,%s) with (%s,%s)",label,x,y,w,h)
    sprint(ctxcatcodes,format("\\dosavepositionwhd{%s}{0}{%sbp}{%sbp}{%sbp}{%sbp}{0pt}",label,x,y,w,h))
    return { }, nil, nil, nil
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

-- todo: check for the same colorspace (actually a backend issue), now we can
-- have several similar resources
--
-- normalize(ca,cb) fails for spotcolors

function metapost.specials.cs(specification,object,result,flusher) -- spot colors?
    -- a mess, not dynamic anyway
    nofshades = nofshades + 1
    flusher.flushfigure(result)
    result = { }
    local t = specificationsplitter:match(specification)
    -- we need a way to move/scale
    local ca = colorsplitter:match(t[4])
    local cb = colorsplitter:match(t[8])
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    if type(ca) == "string" then
        -- spot color, not supported, maybe at some point use the fallbacks
        sprint(ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s %s %s}",
            nofshades,
            t[1], t[2], 0, 1, 1, "DeviceGray",
            t[5], t[6], t[7], t[9], t[10], t[11]))
-- terrible hack, somehow does not work
--~ local a = ca:match("^([^ ]+)")
--~ local b = cb:match("^([^ ]+)")
--~ sprint(ctxcatcodes,format("\\xMPLIBcircularshade{%s}{%s %s}{%s}{%s}{%s}{%s}{%s %s %s %s %s %s}",
--~     nofshades,
--~     --~ t[1], t[2], a, b, 1, "DeviceN",
--~     0, 1, a, b, 1, "DeviceN",
--~     t[5], t[6], t[7], t[9], t[10], t[11]))
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
                ca[4], cb[4] = nil, nil
            elseif #ca == 1 then
                local a, b = 1-ca[1], 1-cb[1]
                ca[1], ca[2], ca[3] = a, a, a
                cb[1], cb[2], cb[3] = b, b, b
            end
            sprint(ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f %.3f %.3f}{%.3f %.3f %.3f}{%s}{%s}{%s %s %s %s %s %s}",
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
            sprint(ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f %.3f %.3f %.3f}{%.3f %.3f %.3f %.3f}{%s}{%s}{%s %s %s %s %s %s}",
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
            sprint(ctxcatcodes,format("\\MPLIBcircularshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s %s %s}",
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
    local t = specificationsplitter:match(specification)
    -- we need a way to move/scale
    local ca = colorsplitter:match(t[4])
    local cb = colorsplitter:match(t[7])
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    if type(ca) == "string" then
        -- spot color, not supported, maybe at some point use the fallbacks
        sprint(ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s}",
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
            sprint(ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f %.3f %.3f}{%.3f %.3f %.3f}{%s}{%s}{%s %s %s %s}",
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
            sprint(ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f %.3f %.3f %.3f}{%.3f %.3f %.3f %.3f}{%s}{%s}{%s %s %s %s}",
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
            sprint(ctxcatcodes,format("\\MPLIBlinearshade{%s}{%s %s}{%.3f}{%.3f}{%s}{%s}{%s %s %s %s}",
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

metapost.first_box       = metapost.first_box or 1000
metapost.last_box        = metapost.last_box or 1100
metapost.textext_current = metapost.first_box
metapost.multipass       = false

function metapost.free_boxes()
    local tb = tex.box
    for i = metapost.first_box,metapost.last_box do
        local b = tb[i]
        if b then
            tb[i] = nil -- no node.flush_list(b) needed, else double free error
        else
            break
        end
    end
end

function metapost.specials.tf(specification,object)
--~ print("setting", metapost.textext_current)
    local n, str = match(specification,"^(%d+):(.+)$")
    if n and str then
        if metapost.textext_current < metapost.last_box then
            metapost.textext_current = metapost.first_box + n - 1
        end
        if trace_textexts then
            logs.report("metapost","first pass: order %s, box %s",n,metapost.textext_current)
        end
        sprint(ctxcatcodes,format("\\MPLIBsettext{%s}{%s}",metapost.textext_current,str))
        metapost.multipass = true
    end
    return { }, nil, nil, nil
end

function metapost.specials.ts(specification,object,result,flusher)
    -- print("getting", metapost.textext_current)
    local n, str = match(specification,"^(%d+):(.+)$")
    if n and str then
        if trace_textexts then
            logs.report("metapost","second pass: order %s, box %s",n,metapost.textext_current)
        end
        local op = object.path
        local first, second, fourth = op[1], op[2], op[4]
        local tx, ty = first.x_coord      , first.y_coord
        local sx, sy = second.x_coord - tx, fourth.y_coord - ty
        local rx, ry = second.y_coord - ty, fourth.x_coord - tx
        if sx == 0 then sx = 0.00001 end
        if sy == 0 then sy = 0.00001 end
        if not trace_textexts then
            object.path = nil
        end
        local before = function() -- no need for function
        --~ flusher.flushfigure(result)
        --~ sprint(ctxcatcodes,format("\\MPLIBgettext{%f}{%f}{%f}{%f}{%f}{%f}{%s}",sx,rx,ry,sy,tx,ty,metapost.textext_current))
        --~ result = { }
            result[#result+1] = format("q %f %f %f %f %f %f cm", sx,rx,ry,sy,tx,ty)
            flusher.flushfigure(result)
            if metapost.textext_current < metapost.last_box then
                metapost.textext_current = metapost.first_box + n - 1
            end
            local b = metapost.textext_current
            sprint(ctxcatcodes,format("\\MPLIBgettextscaled{%s}{%s}{%s}",b, metapost.sxsy(tex.wd[b],tex.ht[b],tex.dp[b])))
            result = { "Q" }
            return object, result
        end
        return { }, before, nil, nil -- replace { } by object for tracing
    else
        return { }, nil, nil, nil -- replace { } by object for tracing
    end
end

metapost.reducetogray = true


function metapost.colorconverter() -- rather generic pdf, so use this elsewhere too
    -- it no longer pays off to distinguish between outline and fill
    --  (we now have both too, e.g. in arrows)
    local model = colors.model
    local reduce = metapost.reducetogray
    if model == "all" then
        return function(cr)
            local n = #cr
            if n == 0 then
                return checked_color_pair()
            elseif reduce then
                if n == 1 then
                    local s = cr[1]
                    return checked_color_pair(format("%.3f g %.3f G",s,s))
                elseif n == 3 then
                    local r, g, b = cr[1], cr[2], cr[3]
                    if r == g and g == b then
                        return checked_color_pair(format("%.3f g %.3f G",r,r))
                    else
                        return checked_color_pair(format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b))
                    end
                else
                    local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                    if c == m and m == y and y == 0 then
                        k = 1 - k
                        return checked_color_pair(format("%.3f g %.3f G",k,k))
                    else
                        return checked_color_pair(format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k))
                    end
                end
            elseif n == 1 then
                local s = cr[1]
                return checked_color_pair(format("%.3f g %.3f G",s,s))
            elseif n == 3 then
                local r, g, b = cr[1], cr[2], cr[3]
                return checked_color_pair(format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b))
            else
                local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                return checked_color_pair(format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k))
            end
        end
    elseif model == "rgb" then
        return function(cr)
            local n = #cr
            if n == 0 then
                return checked_color_pair()
            elseif reduce then
                if n == 1 then
                    local s = cr[1]
                    checked_color_pair(format("%.3f g %.3f G",s,s))
                elseif n == 3 then
                    local r, g, b = cr[1], cr[2], cr[3]
                    if r == g and g == b then
                        return checked_color_pair(format("%.3f g %.3f G",r,r))
                    else
                        return checked_color_pair(format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b))
                    end
                else
                    local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                    if c == m and m == y and y == 0 then
                        k = 1 - k
                        return checked_color_pair(format("%.3f g %.3f G",k,k))
                    else
                        local r, g, b = cmyktorgb(c,m,y,k)
                        return checked_color_pair(format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b))
                    end
                end
            elseif n == 1 then
                local s = cr[1]
                return checked_color_pair(format("%.3f g %.3f G",s,s))
            else
                local r, g, b
                if n == 3 then
                    r, g, b = cmyktorgb(cr[1],cr[2],cr[3],cr[4])
                else
                    r, g, b = cr[1], cr[2], cr[3]
                end
                return checked_color_pair(format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b))
            end
        end
    elseif model == "cmyk" then
        return function(cr)
            local n = #cr
            if n == 0 then
                return checked_color_pair()
            elseif reduce then
                if n == 1 then
                    local s = cr[1]
                    return checked_color_pair(format("%.3f g %.3f G",s,s))
                elseif n == 3 then
                    local r, g, b = cr[1], cr[2], cr[3]
                    if r == g and g == b then
                        return checked_color_pair(format("%.3f g %.3f G",r,r))
                    else
                        local c, m, y, k = rgbtocmyk(r,g,b)
                        return checked_color_pair(format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k))
                    end
                else
                    local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                    if c == m and m == y and y == 0 then
                        k = 1 - k
                        return checked_color_pair(format("%.3f g %.3f G",k,k))
                    else
                        return checked_color_pair(format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k))
                    end
                end
            elseif n == 1 then
                local s = cr[1]
                return checked_color_pair(format("%.3f g %.3f G",s,s))
            else
                local c, m, y, k
                if n == 3 then
                    c, m, y, k = rgbtocmyk(cr[1],cr[2],cr[3])
                else
                    c, m, y, k = cr[1], cr[2], cr[3], cr[4]
                end
                return checked_color_pair(format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k))
            end
        end
    else
        return function(cr)
            local n, s = #cr, 0
            if n == 0 then
                return checked_color_pair()
            elseif n == 4 then
                s = cmyktogray(cr[1],cr[2],cr[3],cr[4])
            elseif n == 3 then
                s = rgbtogray(cr[1],cr[2],cr[3])
            else
                s = cr[1]
            end
            return checked_color_pair(format("%.3f g %.3f G",s,s))
        end
    end
end

do

    local P, S, V, Cs = lpeg.P, lpeg.S, lpeg.V, lpeg.Cs

    local btex      = P("btex")
    local etex      = P(" etex")
    local vtex      = P("verbatimtex")
    local ttex      = P("textext")
    local gtex      = P("graphictext")
    local multipass = P("forcemultipass")
    local spacing   = S(" \n\r\t\v")^0
    local dquote    = P('"')

    local found, forced = false, false

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
    local function force()
        forced = true
    end

    local parser = P {
        [1] = Cs((V(2)/register + V(3)/convert + V(4)/force + 1)^0),
        [2] = ttex + gtex,
        [3] = (btex + vtex) * spacing * Cs((dquote/ditto + (1 - etex))^0) * etex,
        [4] = multipass, -- experimental, only for testing
    }

    -- currently a a one-liner produces less code

    local parser = Cs(((ttex + gtex)/register + ((btex + vtex) * spacing * Cs((dquote/ditto + (1 - etex))^0) * etex)/convert + 1)^0)

    function metapost.check_texts(str)
        found, forced = false, false
        return parser:match(str), found, forced
    end

end

local factor = 65536*(7227/7200)

function metapost.edefsxsy(wd,ht,dp) -- helper for figure
    local hd = ht + dp
    commands.edef("sx",(wd ~= 0 and factor/wd) or 0)
    commands.edef("sy",(hd ~= 0 and factor/hd) or 0)
end

function metapost.sxsy(wd,ht,dp) -- helper for text
    local hd = ht + dp
    return (wd ~= 0 and factor/wd) or 0, (hd ~= 0 and factor/hd) or 0
end

function metapost.text_texts_data()
    local t, n = { }, 0
    for i = metapost.first_box, metapost.last_box do
        n = n + 1
        if trace_textexts then
            logs.report("metapost","passed data: order %s, box %s",n,i)
        end
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

metapost.method = 1 -- 1:dumb 2:clever

function metapost.graphic_base_pass(mpsformat,str,preamble,askedfig)
    local nofig = (askedfig and "") or false
    local done_1, done_2, forced_1, forced_2
    str, done_1, forced_1 = metapost.check_texts(str)
    if preamble then
        preamble, done_2, forced_2 = metapost.check_texts(preamble)
    else
        preamble, done_2, forced_2 = "", false, false
    end
    metapost.textext_current = metapost.first_box
    metapost.intermediate.needed  = false
    metapost.multipass = false -- no needed here
    current_format, current_graphic = mpsformat, str
    if metapost.method == 1 or (metapost.method == 2 and (done_1 or done_2)) then
     -- first true means: trialrun, second true means: avoid extra run if no multipass
        local flushed = metapost.process(mpsformat, {
            preamble,
            nofig or "beginfig(1); ",
            "if unknown _trial_run_ : boolean _trial_run_ fi ; _trial_run_ := true ;",
            str,
            nofig or "endfig ;"
     -- }, true, nil, true )
        }, true, nil, not (forced_1 or forced_2), false, askedfig)
        if metapost.intermediate.needed then
            for _, action in pairs(metapost.intermediate.actions) do
                action()
            end
        end
        if not flushed or not metapost.optimize then
            -- tricky, we can only ask once for objects and therefore
            -- we really need a second run when not optimized
            sprint(ctxcatcodes,format("\\ctxlua{metapost.graphic_extra_pass(%s)}",askedfig or "false"))
        end
    else
        metapost.process(mpsformat, {
            preamble or "",
            nofig or "beginfig(1); ",
            "_trial_run_ := false ;",
            str,
            nofig or "endfig ;"
        }, false, nil, false, false, askedfig )
    end
    -- here we could free the textext boxes
    metapost.free_boxes()
end

function metapost.graphic_extra_pass(askedfig)
    local nofig = (askedfig and "") or false
    metapost.textext_current = metapost.first_box
    metapost.process(current_format, {
        nofig or "beginfig(1); ",
        "_trial_run_ := false ;",
        concat(metapost.text_texts_data()," ;\n"),
        current_graphic,
        nofig or "endfig ;"
    }, false, nil, false, true, askedfig )
end

function metapost.getclippath(data)
    local mpx = metapost.format("metafun")
    if mpx and data then
        statistics.starttiming(metapost)
        statistics.starttiming(metapost.exectime)
        local result = mpx:execute(format("beginfig(1);%s;endfig;",data))
        statistics.stoptiming(metapost.exectime)
        if result.status > 0 then
            print("error", result.status, result.error or result.term or result.log)
            result = ""
        else
            result = metapost.filterclippath(result)
        end
        statistics.stoptiming(metapost)
        sprint(result)
    end
end

metapost.tex = metapost.tex or { }

do -- only used in graphictexts

    local environments = { }

    function metapost.tex.set(str)
        environments[#environments+1] = str
    end
    function metapost.tex.reset()
        environments = { }
    end
    function metapost.tex.get()
        return concat(environments,"\n")
    end

end

local graphics = { }
local start    = [[\starttext]]
local preamble = [[\long\def\MPLIBgraphictext#1{\startTEXpage[scale=10000]#1\stopTEXpage}]]
local stop     = [[\stoptext]]

function metapost.specials.gt(specification,object) -- number, so that we can reorder
    graphics[#graphics+1] = format("\\MPLIBgraphictext{%s}",specification)
    metapost.intermediate.needed = true
    metapost.multipass = true
    return { }, nil, nil, nil
end

function metapost.intermediate.actions.makempy()
    if #graphics > 0 then
        local mpofile = tex.jobname .. "-mpgraph"
        local mpyfile = file.replacesuffix(mpofile,"mpy")
        local pdffile = file.replacesuffix(mpofile,"pdf")
        local texfile = file.replacesuffix(mpofile,"tex")
        io.savedata(texfile, { start, preamble, metapost.tex.get(), concat(graphics,"\n"), stop }, "\n")
        os.execute(format("context --once %s", texfile))
        if io.exists(pdffile) then
            os.execute(format("pstoedit -ssp -dt -f mpost %s %s", pdffile, mpyfile))
            local result = { }
            if io.exists(mpyfile) then
                local data = io.loaddata(mpyfile)
                for figure in gmatch(data,"beginfig(.-)endfig") do
                    result[#result+1] = format("begingraphictextfig%sendgraphictextfig ;\n", figure)
                end
                io.savedata(mpyfile,concat(result,""))
            end
        end
        graphics = { }
    end
end
