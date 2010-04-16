if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local format, gmatch, gsub, lower, match, find = string.format, string.gmatch, string.gsub, string.lower, string.match, string.find
local texsprint = tex.sprint
local ctxcatcodes = tex.ctxcatcodes

local trace_define = false  trackers.register("colors.define",function(v) trace_define = v end)

local settings_to_hash_strict = aux.settings_to_hash_strict

colors         = colors         or { }
transparencies = transparencies or { }

local registrations = backends.registrations

local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')
local a_background   = attributes.private('background')

local register_color  = colors.register
local attributes_list = attributes.list

local function definecolor(name, ca, global)
    if ca and ca > 0 then
        if global then
            if trace_define then
                commands.writestatus("color","define global color '%s' with attribute: %s",name,ca)
            end
            context.colordefagc(name,ca)
        else
            if trace_define then
                commands.writestatus("color","define local color '%s' with attribute: %s",name,ca)
            end
            context.colordefalc(name,ca)
        end
    else
        if global then
            context.colordefrgc(name)
        else
            context.colordefrlc(name)
        end
    end
end

local function inheritcolor(name, ca, global)
    if ca and ca ~= "" then
        if global then
            if trace_define then
                commands.writestatus("color","inherit global color '%s' with attribute: %s",name,ca)
            end
            context.colordeffgc(name,ca)
        else
            if trace_define then
                commands.writestatus("color","inherit local color '%s' with attribute: %s",name,ca)
            end
            context.colordefflc(name,ca)
        end
    else
        if global then
            context.colordefrgc(name)
        else
            context.colordefrlc(name)
        end
    end
end

local function definetransparent(name, ta, global)
    if ta and ta > 0 then
        if global then
            if trace_define then
                commands.writestatus("color","define global transparency '%s' with attribute: %s",name,ta)
            end
            context.colordefagt(name,ta)
        else
            if trace_define then
                commands.writestatus("color","define local transparency '%s' with attribute: %s",name,ta)
            end
            context.colordefalt(name,ta)
        end
    else
        if global then
            context.colordefrgt(name)
        else
            context.colordefrlt(name)
        end
    end
end

local function inherittransparent(name, ta, global)
    if ta and ta ~= "" then
        if global then
            if trace_define then
                commands.writestatus("color","inherit global transparency '%s' with attribute: %s",name,ta)
            end
            context.colordeffgt(name,ta)
        else
            if trace_define then
                commands.writestatus("color","inherit local transparency '%s' with attribute: %s",name,ta)
            end
            context.colordefflt(name,ta)
        end
    else
        if global then
            context.colordefrgt(name)
        else
            context.colordefrlt(name)
        end
    end
end

local transparent = {
    none       =  0,
    normal     =  1,
    multiply   =  2,
    screen     =  3,
    overlay    =  4,
    softlight  =  5,
    hardlight  =  6,
    colordodge =  7,
    colorburn  =  8,
    darken     =  9,
    lighten    = 10,
    difference = 11,
    exclusion  = 12,
}

-- By coupling we are downward compatible. When we decouple we need to do more tricky
-- housekeeping (e.g. persist color independent transparencies when color bound ones
-- are nil.)

colors.couple = true

function colors.definetransparency(name,n)
    transparent[name] = n
end

local registered = { }

local function do_registerspotcolor(parent,name,parentnumber,e,f,d,p)
    if not registered[parentnumber] then
        local v = colors.values[parentnumber]
        if v then
            local kind = colors.default -- else problems with shading etc
            if kind == 1 then kind = v[1] end
            if     kind == 2 then -- name noffractions names p's r g b
                registrations.grayspotcolor(parent,f,d,p,v[2])
            elseif kind == 3 then
                registrations.rgbspotcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif kind == 4 then
                registrations.cmykspotcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
            if e and e ~= "" then
                registrations.spotcolorname(parent,e)
            end
        end
        registered[parentnumber] = true
    end
end

local function do_registermultitonecolor(parent,name,parentnumber,e,f,d,p) -- same as spot but different template
    if not registered[parentnumber] then
        local v = colors.values[parentnumber]
        if v then
            local kind = colors.default -- else problems with shading etc
            if kind == 1 then kind = v[1] end
            if     kind == 2 then
                registrations.grayindexcolor(parent,f,d,p,v[2])
            elseif kind == 3 then
                registrations.rgbindexcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif kind == 4 then
                registrations.cmykindexcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
        end
        registered[parentnumber] = true
    end
end

function colors.definesimplegray(name,s)
    return register_color(name,'gray',s) -- we still need to get rid of 'color'
end

function colors.defineprocesscolor(name,str,global,freeze) -- still inconsistent color vs transparent
    local r = match(str,"^#(.+)$") -- for old times sake (if we need to feed from xml or so)
    local t = (r and { h = r }) or settings_to_hash_strict(str)
    if t then
        if t.v then
            local r, g, b = colors.hsvtorgb(tonumber(t.h) or 0, tonumber(t.s) or 1, tonumber(t.v) or 1) -- maybe later native
            definecolor(name, register_color(name,'rgb',r,g,b), global)
        elseif t.h then
            local r, g, b = match(t.h .. "000000","(..)(..)(..)") -- watch the 255
            definecolor(name, register_color(name,'rgb',(tonumber(r,16) or 0)/255,(tonumber(g,16) or 0)/255,(tonumber(b,16) or 0)/255), global)
        elseif t.r or t.g or t.b then
            definecolor(name, register_color(name,'rgb', tonumber(t.r) or 0, tonumber(t.g) or 0, tonumber(t.b) or 0), global)
        elseif t.c or t.m or t.y or t.k then
            definecolor(name, register_color(name,'cmyk',tonumber(t.c) or 0, tonumber(t.m) or 0, tonumber(t.y) or 0, tonumber(t.k) or 0), global)
        else
            definecolor(name, register_color(name,'gray',tonumber(t.s) or 0), global)
        end
        if t.a and t.t then
            definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
        elseif colors.couple then
        --  definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
            definetransparent(name, 0, global) -- can be sped up
        end
    elseif freeze then
        local ca = attributes_list[a_color]       [str]
        local ta = attributes_list[a_transparency][str]
        if ca then
            definecolor(name, ca, global)
        end
        if ta then
            definetransparent(name, ta, global)
        end
    else
        inheritcolor(name, str, global)
        inherittransparent(name, str, global)
    --  if global and str ~= "" then -- For Peter Rolf who wants access to the numbers in Lua. (Currently only global is supported.)
    --      attributes_list[a_color]       [name] = attributes_list[a_color]       [str] or attributes.unsetvalue  -- reset
    --      attributes_list[a_transparency][name] = attributes_list[a_transparency][str] or attributes.unsetvalue
    --  end
    end
end

function colors.isblack(ca) -- maybe commands
    local cv = ca > 0 and colors.value(ca)
    return (cv and cv[2] == 0) or false
end

function colors.definespotcolor(name,parent,str,global)
    if parent == "" or find(parent,"=") then
        colors.registerspotcolor(name, parent)
    elseif name ~= parent then
        local cp = attributes_list[a_color][parent]
        if cp then
            local t = settings_to_hash_strict(str)
            if t then
                local tp = tonumber(t.p) or 1
                do_registerspotcolor(parent, name, cp, t.e, 1, "", tp) -- p not really needed, only diagnostics
                if name and name ~= "" then
                    definecolor(name, register_color(name,'spot', parent, 1, "", tp), true)
                    local ta, tt = t.a, t.t
                    if ta and tt then
                        definetransparent(name, transparencies.register(name,transparent[ta] or tonumber(ta) or 1,tonumber(tt) or 1), global)
                    elseif colors.couple then
                    --~ definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                        definetransparent(name, 0, global) -- can be sped up
                    end
                end
            end
        end
    end
end

function colors.registerspotcolor(parent, str)
    local cp = attributes_list[a_color][parent]
    if cp then
        local e = ""
        if str then
            local t = settings_to_hash_strict(str)
            e = (t and t.e) or ""
        end
        do_registerspotcolor(parent, "dummy", cp, e, 1, "", 1) -- p not really needed, only diagnostics
    end
end

function colors.definemultitonecolor(name,multispec,colorspec,selfspec)
    local dd, pp, nn = { }, { }, { }
    for k,v in gmatch(multispec,"(%a+)=([^%,]*)") do
        dd[#dd+1] = k
        pp[#pp+1] = v
        nn[#nn+1] = k
        nn[#nn+1] = format("%1.3g",tonumber(v) or 0) -- 0 can't happen
    end
--~ v = tonumber(v) * p
    local nof = #dd
    if nof > 0 then
        dd, pp, nn = concat(dd,','), concat(pp,','), concat(nn,'_')
        local parent = gsub(lower(nn),"[^%d%a%.]+","_")
        colors.defineprocesscolor(parent,colorspec..","..selfspec,true,true)
        local cp = attributes_list[a_color][parent]
        if cp then
            do_registerspotcolor(parent, name, cp, "", nof, dd, pp)
            do_registermultitonecolor(parent, name, cp, "", nof, dd, pp)
            definecolor(name, register_color(name, 'spot', parent, nof, dd, pp), true)
            local t = settings_to_hash_strict(selfspec)
            if t and t.a and t.t then
                definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
            elseif colors.couple then
            --  definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                definetransparent(name, 0, global) -- can be sped up
            end
        end
    end
end

function colors.mp(model,ca,ta,default)
    local cv = colors.value(ca) -- faster when direct colors.values[ca]
    if cv then
        local tv = transparencies.value(ta)
        if model == 1 then
            model = cv[1]
        end
        if tv then
            if model == 2 then
                return format("transparent(%s,%s,(%s,%s,%s))",tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 3 then
                return format("transparent(%s,%s,(%s,%s,%s))",tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 4 then
                return format("transparent(%s,%s,cmyk(%s,%s,%s,%s))",tv[1],tv[2],cv[6],cv[7],cv[8],cv[9])
            else
                return format("transparent(%s,%s,multitonecolor(\"%s\",%s,\"%s\",\"%s\"))",tv[1],tv[2],cv[10],cv[11],cv[12],cv[13])
            end
        else
            if model == 2 then
                return format("(%s,%s,%s)",cv[3],cv[4],cv[5])
            elseif model == 3 then
                return format("(%s,%s,%s)",cv[3],cv[4],cv[5])
            elseif model == 4 then
                return format("cmyk(%s,%s,%s,%s)",cv[6],cv[7],cv[8],cv[9])
            else
                return format("multitonecolor(\"%s\",%s,\"%s\",\"%s\")",cv[10],cv[11],cv[12],cv[13])
            end
        end
    else
        default = default or 0 -- rgb !
        return format("(%s,%s,%s)",default,default,default)
    end
end

function colors.formatcolor(ca,separator)
    local cv = colors.value(ca)
    if cv then
        local c, f, t, model = { }, 13, 13, cv[1]
        if model == 2 then
            f, t = 2, 2
        elseif model == 3 then
            f, t = 3, 5
        elseif model == 4 then
            f, t = 6, 9
        end
        for i=f,t do
            c[#c+1] = format("%0.3f",cv[i])
        end
        return concat(c,separator)
    else
        return format("%0.3f",0)
    end
end

function colors.formatgray(ca,separator)
    local cv = colors.value(ca)
    return format("%0.3f",(cv and cv[2]) or 0)
end

function colors.colorcomponents(ca) -- return list
    local cv = colors.value(ca)
    if cv then
        local model = cv[1]
        if model == 2 then
            return format("s=%1.3f",cv[2])
        elseif model == 3 then
            return format("r=%1.3f g=%1.3f b=%1.3f",cv[3],cv[4],cv[5])
        elseif model == 4 then
            return format("c=%1.3f m=%1.3f y=%1.3f k=%1.3f",cv[6],cv[7],cv[8],cv[9])
        elseif type(cv[13]) == "string" then
            return format("p=%s",cv[13])
        else
            return format("p=%1.3f",cv[13])
        end
    else
        return ""
    end
end

function colors.transparencycomponents(ta)
    local tv = transparencies.value(ta)
    if tv then
        return format("a=%1.3f t=%1.3f",tv[1],tv[2])
    else
        return ""
    end
end

function colors.spotcolorname(ca,default)
    local cv, v = colors.value(ca), "unknown"
    if cv and cv[1] == 5 then
        v = cv[10]
    end
    return tostring(v)
end

function colors.spotcolorparent(ca,default)
    local cv, v = colors.value(ca), "unknown"
    if cv and cv[1] == 5 then
        v = cv[12]
        if v == "" then
            v = cv[10]
        end
    end
    return tostring(v)
end

function colors.spotcolorvalue(ca,default)
    local cv, v = colors.value(ca), 0
    if cv and cv[1] == 5 then
       v = cv[13]
    end
    return tostring(v)
end

-- experiment  (a bit of a hack, as we need to get the attribute number)

local min = math.min

-- a[b,c] -> b+a*(c-b)

local function f(one,two,i,fraction)
    local o, t = one[i], two[i]
    local otf = o + fraction * (t - o)
    if otf > 1 then
        otf = 1
    end
    return otf
end

function colors.defineintermediatecolor(name,fraction,c_one,c_two,a_one,a_two,specs,global,freeze)
    fraction = tonumber(fraction) or 1
    local one, two = colors.value(c_one), colors.value(c_two)
    if one and two then
        local csone, cstwo = one[1], two[1]
        if csone == cstwo then
            -- actually we can set all 8 values at once here but this is cleaner as we avoid
            -- problems with weighted gray conversions and work with original values
            local ca
            if csone == 2 then
                ca = register_color(name,'gray',f(one,two,2,fraction))
            elseif csone == 3 then
                ca = register_color(name,'rgb',f(one,two,3,fraction),f(one,two,4,fraction),f(one,two,5,fraction))
            elseif csone == 4 then
                ca = register_color(name,'cmyk',f(one,two,6,fraction),f(one,two,7,fraction),f(one,two,8,fraction),f(one,two,9,fraction))
            else
                ca = register_color(name,'gray',f(one,two,2,fraction))
            end
            definecolor(name,ca,global,freeze)
        end
    end
    local one, two = transparencies.value(a_one), transparencies.value(a_two)
    local t = settings_to_hash_strict(specs)
    local ta = tonumber((t and t.a) or (one and one[1]) or (two and two[1]))
    local tt = tonumber((t and t.t) or (one and two and f(one,two,2,fraction)))
    if ta and tt then
--~     print(ta,tt)
        definetransparent(name,transparencies.register(name,ta,tt),global)
    end
end
