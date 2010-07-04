if not modules then modules = { } end modules ['mlib-pps'] = { -- prescript, postscripts and specials
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- current limitation: if we have textext as well as a special color then due to
-- prescript/postscript overload we can have problems
--
-- todo: report max textexts

local format, gmatch, concat, round, match = string.format, string.gmatch, table.concat, math.round, string.match
local sprint = tex.sprint
local tonumber, type = tonumber, type
local lpegmatch = lpeg.match
local texbox = tex.box
local copy_list = node.copy_list

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

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
metapost.externals     = metapost.externals or { n = 0 }

local data = metapost.specials.data

local colordata = { {}, {}, {}, {}, {} }

--~ (r,g,b) => cmyk             : r=123 g=   1 b=hash
--~         => spot             : r=123 g=   2 b=hash
--~         => transparent rgb  : r=123 g=   3 b=hash
--~         => transparent cmyk : r=123 g=   4 b=hash
--~         => transparent spot : r=123 g=   5 b=hash
--~         => rest             : r=123 g=n>10 b=whatever

local nooutercolor        = "0 g 0 G"
local nooutertransparency = "/Tr0 gs" -- only when set
local outercolormode      = 0
local outercolor          = nooutercolor
local outertransparency   = nooutertransparency
local innercolor          = nooutercolor
local innertransparency   = nooutertransparency

local pdfcolor, pdftransparency = lpdf.color, lpdf.transparency
local registercolor, registerspotcolor = colors.register, colors.registerspotcolor
local registertransparency = transparencies.register

function metapost.set_outer_color(mode,colormodel,colorattribute,transparencyattribute)
    -- has always to be called before conversion
    -- todo: transparency (not in the mood now)
    outercolormode = mode
    if mode == 1 or mode == 3 then
        -- inherit from outer (registered color)
        outercolor        = pdfcolor(colormodel,colorattribute)    or nooutercolor
        outertransparency = pdftransparency(transparencyattribute) or nooutertransparency
    elseif mode == 2 then
        -- stand alone (see m-punk.tex)
        outercolor        = ""
        outertransparency = ""
    else -- 0
        outercolor        = nooutercolor
        outertransparency = nooutertransparency
    end
    innercolor        = outercolor
    innertransparency = outertransparency -- not yet used
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
--~     if match(str,"^%%%%MetaPostOption: multipass") then
--~         metapost.multipass = true
--~     end
end

local function spotcolorconverter(parent, n, d, p)
    registerspotcolor(parent)
    return pdfcolor(colors.model,registercolor(nil,'spot',parent,n,d,p))
end

function metapost.colorhandler(cs, object, result, colorconverter) -- handles specials
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
        result[#result+1] = spotcolorconverter(data[2],data[3],data[4],data[5])
    else
        if what == 3 then
            result[#result+1], cr = colorconverter({ data[3], data[4], data[5]})
        elseif what == 4 then
            result[#result+1], cr = colorconverter({ data[3], data[4], data[5], data[6]})
        elseif what == 5 then
            result[#result+1] = spotcolorconverter(data[3],data[4],data[5],data[6])
        end
        object.prescript = "tr"
        object.postscript = data[1] .. "," .. data[2]
    end
    object.color = nil
    return object, cr
end

function metapost.colorspec(cs) -- used for shades ... returns table (for checking) or string (spot)
    local what = round(cs[2]*10000)
    local data = colordata[what][round(cs[3]*10000)]
    if not data then
        return { 0 }
    elseif what == 1 then
        return { tonumber(data[2]), tonumber(data[3]), tonumber(data[4]), tonumber(data[5]) }
    elseif what == 2 then
        return spotcolorconverter(data[2],data[3],data[4],data[5])
    elseif what == 3 then
        return { tonumber(data[3]), tonumber(data[4]), tonumber(data[5]) }
    elseif what == 4 then
        return { tonumber(data[3]), tonumber(data[4]), tonumber(data[5]), tonumber(data[6]) }
    elseif what == 5 then
        return spotcolorconverter(data[3],data[4],data[5],data[6])
    end
end

function metapost.specials.tr(specification,object,result)
    local a, t = match(specification,"^(.+),(.+)$")
    local before = a and t and function()
        result[#result+1] = format("/Tr%s gs",registertransparency(nil,a,t,true)) -- maybe nil instead of 'mp'
        return object, result
    end
    local after = before and function()
        result[#result+1] = outertransparency -- here we could revert to the outer color
        return object, result
    end
    return object, before, nil, after
end

local specificationsplitter = lpeg.Ct(lpeg.splitat(" "))
local colorsplitter         = lpeg.Ct(lpeg.splitat(":"))
local colorsplitter         = lpeg.Ct(lpeg.splitter(":",tonumber))

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
--~     object.color = lpegmatch(specificationsplitter,specification)
--~     return object, nil, nil, nil
--~ end
--~ function metapost.specials.cc(specification,object,result)
--~     local c = lpegmatch(specificationsplitter,specification)
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
    local t = lpegmatch(specificationsplitter,specification)
    -- we need a way to move/scale
    local ca = lpegmatch(colorsplitter,t[4])
    local cb = lpegmatch(colorsplitter,t[8])
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    local name = format("MplSh%s",nofshades)
    local domain = { tonumber(t[1]), tonumber(t[2]) }
    local coordinates = { tonumber(t[5]), tonumber(t[6]), tonumber(t[7]), tonumber(t[9]), tonumber(t[10]), tonumber(t[11]) }
    if type(ca) == "string" then
        -- backend specific (will be renamed)
        lpdf.circularshade(name,domain,{ 0 },{ 1 },1,"DeviceGray",coordinates)
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
            -- backend specific (will be renamed)
            lpdf.circularshade(name,domain,ca,cb,1,"DeviceRGB",coordinates)
        elseif model == "cmyk" then
            if #ca == 3 then
                ca[1], ca[2], ca[3], ca[4] = rgbtocmyk(ca[1],ca[2],ca[3])
                cb[1], cb[2], cb[3], ca[4] = rgbtocmyk(cb[1],cb[2],cb[3])
            elseif #ca == 1 then
                ca[1], ca[2], ca[3], ca[4] = 0, 0, 0, ca[1]
                cb[1], cb[2], cb[3], ca[4] = 0, 0, 0, ca[1]
            end
            -- backend specific (will be renamed)
            lpdf.circularshade(name,domain,ca,cb,1,"DeviceCMYK",coordinates)
        else
            if #ca == 4 then
                ca[1] = cmyktogray(ca[1],ca[2],ca[3],ca[4])
                cb[1] = cmyktogray(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 3 then
                ca[1] = rgbtogray(ca[1],ca[2],ca[3])
                cb[1] = rgbtogray(cb[1],cb[2],cb[3])
            end
            -- backend specific (will be renamed)
            lpdf.circularshade(name,domain,ca,cb,1,"DeviceGRAY",coordinates)
        end
    end
    local before = function()
        result[#result+1] = "q /Pattern cs"
        return object, result
    end
    local after = function()
        result[#result+1] = format("W n /%s sh Q", name)
        return object, result
    end
    object.color, object.type = nil, nil
    return object, before, nil, after
end

function metapost.specials.ls(specification,object,result,flusher)
    nofshades = nofshades + 1
    flusher.flushfigure(result)
    result = { }
    local t = lpegmatch(specificationsplitter,specification)
    -- we need a way to move/scale
    local ca = lpegmatch(colorsplitter,t[4])
    local cb = lpegmatch(colorsplitter,t[7])
    if round(ca[1]*10000) == 123 then ca = metapost.colorspec(ca) end
    if round(cb[1]*10000) == 123 then cb = metapost.colorspec(cb) end
    local name = format("MpSh%s",nofshades)
    local domain = { tonumber(t[1]), tonumber(t[2]) }
    local coordinates = { tonumber(t[5]), tonumber(t[6]), tonumber(t[8]), tonumber(t[9]) }
    if type(ca) == "string" then
        -- backend specific (will be renamed)
        lpdf.linearshade(name,domain,{ 0 },{ 1 },1,"DeviceGray",coordinates)
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
            -- backend specific (will be renamed)
            lpdf.linearshade(name,domain,ca,cb,1,"DeviceRGB",coordinates)
        elseif model == "cmyk" then
            if #ca == 3 then
                ca[1], ca[2], ca[3], ca[4] = rgbtocmyk(ca[1],ca[2],ca[3])
                cb[1], cb[2], cb[3], ca[4] = rgbtocmyk(cb[1],cb[2],cb[3])
            elseif #ca == 1 then
                ca[1], ca[2], ca[3], ca[4] = 0, 0, 0, ca[1]
                cb[1], cb[2], cb[3], ca[4] = 0, 0, 0, ca[1]
            end
            -- backend specific (will be renamed)
            lpdf.linearshade(name,domain,ca,cb,1,"DeviceCMYK",coordinates)
        else
            if #ca == 4 then
                ca[1] = cmyktogray(ca[1],ca[2],ca[3],ca[4])
                cb[1] = cmyktogray(cb[1],cb[2],cb[3],cb[4])
            elseif #ca == 3 then
                ca[1] = rgbtogray(ca[1],ca[2],ca[3])
                cb[1] = rgbtogray(cb[1],cb[2],cb[3])
            end
            -- backend specific (will be renamed)
            lpdf.linearshade(name,domain,ca,cb,1,"DeviceGRAY",coordinates)
        end
    end
    local before = function()
        result[#result+1] = "q /Pattern cs"
        return object, result
    end
    local after = function()
        result[#result+1] = format("W n /%s sh Q", name)
        return object, result
    end
    object.color, object.type = nil, nil
    return object, before, nil, after
end

-- no need for a before here

local current_format, current_graphic, current_initializations

-- metapost.first_box       = metapost.first_box or 1000
-- metapost.last_box        = metapost.last_box or 1100
--~ metapost.textext_current = metapost.first_box
metapost.multipass       = false

local textexts = { }

function metapost.free_boxes() -- todo: mp direct list ipv box
 -- for i = metapost.first_box,metapost.last_box do
 --     local b = texbox[i]
 --     if b then
 --         texbox[i] = nil -- no node.flush_list(b) needed, else double free error
 --     else
 --         break
 --     end
 -- end
    for n, box in next, textexts do
        local tn = textexts[n]
        if tn then
            -- somehow not flushed (used)
            textexts[n] = nil
        end
    end
    textexts = { }
end

function metapost.settext(box,slot)
    textexts[slot] = copy_list(texbox[box])
    texbox[box] = nil
    -- this will become
    -- textexts[slot] = texbox[box]
    -- unsetbox(box)
end

function metapost.gettext(box,slot)
    texbox[box] = copy_list(textexts[slot])
--  textexts[slot] = nil -- no, pictures can be placed several times
end

function metapost.specials.tf(specification,object)
--~ print("setting", metapost.textext_current)
    local n, str = match(specification,"^(%d+):(.+)$")
    if n and str then
        n = tonumber(n)
     -- if metapost.textext_current < metapost.last_box then
     --     metapost.textext_current = metapost.first_box + n - 1
     -- end
        if trace_textexts then
         -- logs.report("metapost","first pass: order %s, box %s",n,metapost.textext_current)
            logs.report("metapost","first pass: order %s",n)
        end
     -- sprint(ctxcatcodes,format("\\MPLIBsettext{%s}{%s}",metapost.textext_current,str))
        sprint(ctxcatcodes,format("\\MPLIBsettext{%s}{%s}",n,str))
        metapost.multipass = true
    end
    return { }, nil, nil, nil
end

function metapost.specials.ts(specification,object,result,flusher)
    -- print("getting", metapost.textext_current)
    local n, str = match(specification,"^(%d+):(.+)$")
    if n and str then
        n = tonumber(n)
        if trace_textexts then
         -- logs.report("metapost","second pass: order %s, box %s",n,metapost.textext_current)
            logs.report("metapost","second pass: order %s",n)
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
        local before = function() -- no need for before function (just do it directly)
        --~ flusher.flushfigure(result)
        --~ sprint(ctxcatcodes,format("\\MPLIBgettext{%f}{%f}{%f}{%f}{%f}{%f}{%s}",sx,rx,ry,sy,tx,ty,metapost.textext_current))
        --~ result = { }
            result[#result+1] = format("q %f %f %f %f %f %f cm", sx,rx,ry,sy,tx,ty)
            flusher.flushfigure(result)
            -- if metapost.textext_current < metapost.last_box then
            --     metapost.textext_current = metapost.first_box + n - 1
            --  end
         -- local b = metapost.textext_current
         -- local box = texbox[b]
            local box = textexts[n]
            if box then
             -- sprint(ctxcatcodes,format("\\MPLIBgettextscaled{%s}{%s}{%s}",b,metapost.sxsy(box.width,box.height,box.depth)))
                sprint(ctxcatcodes,format("\\MPLIBgettextscaled{%s}{%s}{%s}",n,metapost.sxsy(box.width,box.height,box.depth)))
            else
                -- error
            end
            result = { "Q" }
            return object, result
        end
        return { }, before, nil, nil -- replace { } by object for tracing
    else
        return { }, nil, nil, nil -- replace { } by object for tracing
    end
end

-- rather generic pdf, so use this elsewhere too it no longer pays
-- off to distinguish between outline and fill (we now have both
-- too, e.g. in arrows)

metapost.reducetogray = true

local models = { }

function models.all(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
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

function models.rgb(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
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

function models.cmyk(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
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

function models.gray(cr)
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

function metapost.colorconverter()
    return models[colors.model] or gray
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
        return "rawtextext(\"" .. str .. "\")" -- centered
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

    local texmess   = (dquote/ditto + (1 - etex))^0

    local function ignore(s)
        logs.report("mplib","ignoring verbatim tex: %s",s)
        return ""
    end

    local parser = P {
        [1] = Cs((V(2)/register + V(4)/ignore + V(3)/convert + V(5)/force + 1)^0),
        [2] = ttex + gtex,
        [3] = btex * spacing * Cs(texmess) * etex,
        [4] = vtex * spacing * Cs(texmess) * etex,
        [5] = multipass, -- experimental, only for testing
    }

    -- currently a a one-liner produces less code

    local parser = Cs((
        (ttex + gtex)/register
      + (btex * spacing * Cs(texmess) * etex)/convert
      + (vtex * spacing * Cs(texmess) * etex)/ignore
      + 1
    )^0)

    function metapost.check_texts(str)
        found, forced = false, false
        return lpegmatch(parser,str), found, forced
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

local no_trial_run       = "_trial_run_ := false ;"
local do_trial_run       = "if unknown _trial_run_ : boolean _trial_run_ fi ; _trial_run_ := true ;"
local text_data_template = "_tt_w_[%i]:=%f;_tt_h_[%i]:=%f;_tt_d_[%i]:=%f;"
local do_begin_fig       = "; beginfig(1); "
local do_end_fig         = "; endfig ;"
local do_safeguard       = ";"

function metapost.text_texts_data()
    local t, n = { }, 0
--~     for i = metapost.first_box, metapost.last_box do
--~         n = n + 1
--~         local box = texbox[i]
    for n, box in next, textexts do
        if trace_textexts then
            logs.report("metapost","passed data: order %s, box %s",n,i)
        end
        if box then
            t[#t+1] = format(text_data_template,n,box.width/factor,n,box.height/factor,n,box.depth/factor)
        else
            break
        end
    end
--~     print(table.serialize(t))
    return t
end

metapost.intermediate         = metapost.intermediate         or {}
metapost.intermediate.actions = metapost.intermediate.actions or {}
metapost.intermediate.needed  = false

metapost.method = 1 -- 1:dumb 2:clever

function metapost.graphic_base_pass(mpsformat,str,initializations,preamble,askedfig)
    local nofig = (askedfig and "") or false
    local done_1, done_2, forced_1, forced_2
    str, done_1, forced_1 = metapost.check_texts(str)
    if not preamble or preamble == "" then
        preamble, done_2, forced_2 = "", false, false
    else
        preamble, done_2, forced_2 = metapost.check_texts(preamble)
    end
 -- metapost.textext_current = metapost.first_box
    metapost.intermediate.needed  = false
    metapost.multipass = false -- no needed here
    current_format, current_graphic, current_initializations = mpsformat, str, initializations or ""
    if metapost.method == 1 or (metapost.method == 2 and (done_1 or done_2)) then
     -- first true means: trialrun, second true means: avoid extra run if no multipass
        local flushed = metapost.process(mpsformat, {
            preamble,
            nofig or do_begin_fig,
            do_trial_run,
            current_initializations,
            do_safeguard,
            current_graphic,
            nofig or do_end_fig
     -- }, true, nil, true )
        }, true, nil, not (forced_1 or forced_2), false, askedfig)
        if metapost.intermediate.needed then
            for _, action in next, metapost.intermediate.actions do
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
            preamble,
            nofig or do_begin_fig,
            no_trial_run,
            current_initializations,
            do_safeguard,
            current_graphic,
            nofig or do_end_fig
        }, false, nil, false, false, askedfig )
    end
    -- here we could free the textext boxes
    metapost.free_boxes()
end

function metapost.graphic_extra_pass(askedfig)
    local nofig = (askedfig and "") or false
 -- metapost.textext_current = metapost.first_box
    metapost.process(current_format, {
        nofig or do_begin_fig,
        no_trial_run,
        concat(metapost.text_texts_data()," ;\n"),
        current_initializations,
        do_safeguard,
        current_graphic,
        nofig or do_end_fig
    }, false, nil, false, true, askedfig )
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
        local externals = metapost.externals
        externals.n = externals.n + 1
        starttiming(externals)
        local mpofile = tex.jobname .. "-mpgraph"
        local mpyfile = file.replacesuffix(mpofile,"mpy")
        local pdffile = file.replacesuffix(mpofile,"pdf")
        local texfile = file.replacesuffix(mpofile,"tex")
        io.savedata(texfile, { start, preamble, metapost.tex.get(), concat(graphics,"\n"), stop }, "\n")
        local command = format("context --once %s %s", (tex.interactionmode == 0 and "--batchmode") or "", texfile)
        os.execute(command)
        if io.exists(pdffile) then
            command = format("pstoedit -ssp -dt -f mpost %s %s", pdffile, mpyfile)
            os.execute(command)
            local result = { }
            if io.exists(mpyfile) then
                local data = io.loaddata(mpyfile)
                for figure in gmatch(data,"beginfig(.-)endfig") do
                    result[#result+1] = format("begingraphictextfig%sendgraphictextfig ;\n", figure)
                end
                io.savedata(mpyfile,concat(result,""))
            end
        end
        stoptiming(externals)
        graphics = { } -- ?
    end
end
