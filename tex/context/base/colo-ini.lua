if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tonumber = type, tonumber
local concat, insert, remove = table.concat, table.insert, table.remove
local format, gmatch, gsub, lower, match, find = string.format, string.gmatch, string.gsub, string.lower, string.match, string.find
local P, R, C, Cc = lpeg.P, lpeg.R, lpeg.C, lpeg.Cc
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local formatters = string.formatters

local trace_define = false  trackers.register("colors.define",function(v) trace_define = v end)

local report_colors = logs.reporter("colors","defining")

local attributes, backends, storage = attributes, backends, storage
local context, commands = context, commands

local settings_to_hash_strict = utilities.parsers.settings_to_hash_strict

local colors              = attributes.colors
local transparencies      = attributes.transparencies
local colorintents        = attributes.colorintents
local registrations       = backends.registrations
local settexattribute     = tex.setattribute
local gettexattribute     = tex.getattribute

local a_color             = attributes.private('color')
local a_transparency      = attributes.private('transparency')
local a_colorspace        = attributes.private('colormodel')

local register_color      = colors.register
local attributes_list     = attributes.list

local colorvalues         = colors.values
local transparencyvalues  = transparencies.values

local texattribute        = tex.attribute

colors.sets               = colors.sets or { } -- sets are mostly used for
local colorsets           = colors.sets        -- showing lists of defined
local colorset            = { }                -- colors
colorsets.default         = colorset

storage.register("attributes/colors/sets",colorsets,"attributes.colors.sets")

local stack = { }

function colors.pushset(name)
    insert(stack,colorset)
    colorset = colorsets[name]
    if not colorset then
        colorset = { }
        colorsets[name] = colorset
    end
end

function colors.popset(name)
    colorset = remove(stack)
end

function colors.setlist(name)
    return table.sortedkeys(name and name ~= "" and colorsets[name] or colorsets.default or {})
end

local function definecolor(name, ca, global)
    if ca and ca > 0 then
        if global then
            if trace_define then
                report_colors("define global color %a with attribute %a",name,ca)
            end
            context.colordefagc(name,ca)
        else
            if trace_define then
                report_colors("define local color %a with attribute %a",name,ca)
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
    colorset[name] = true-- maybe we can store more
end

local function inheritcolor(name, ca, global)
    if ca and ca ~= "" then
        if global then
            if trace_define then
                report_colors("inherit global color %a with attribute %a",name,ca)
            end
            context.colordeffgc(name,ca) -- some day we will set the macro directly
        else
            if trace_define then
                report_colors("inherit local color %a with attribute %a",name,ca)
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
    colorset[name] = true-- maybe we can store more
end

local function definetransparent(name, ta, global)
    if ta and ta > 0 then
        if global then
            if trace_define then
                report_colors("define global transparency %a with attribute %a",name,ta)
            end
            context.colordefagt(name,ta)
        else
            if trace_define then
                report_colors("define local transparency %a with attribute %a",name,ta)
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
                report_colors("inherit global transparency %a with attribute %a",name,ta)
            end
            context.colordeffgt(name,ta)
        else
            if trace_define then
                report_colors("inherit local transparency %a with attribute %a",name,ta)
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
    hue        = 13,
    saturation = 14,
    color      = 15,
    luminosity = 16,
}

local gray_okay, rgb_okay, cmyk_okay, spot_okay, multichannel_okay, forced = true, true, true, true, true, false

function colors.forcesupport(gray,rgb,cmyk,spot,multichannel) -- pdfx driven
    gray_okay, rgb_okay, cmyk_okay, spot_okay, multichannel_okay, forced = gray, rgb, cmyk, spot, multichannel, true
    report_colors("supported models: gray %a, rgb %a, cmyk %a, spot %a",gray,rgb,cmyk,spot) -- multichannel=%l multichannel
end

local function forcedmodel(model) -- delayed till the backend but mp directly
    if not forced then
        return model
    elseif model == 2 then -- gray
        if gray_okay then
            -- okay
        elseif cmyk_okay then
            return 4
        elseif rgb_okay then
            return 3
        end
    elseif model == 3 then -- rgb
        if rgb_okay then
            -- okay
        elseif cmyk_okay then
            return 4
        elseif gray_okay then
            return 2
        end
    elseif model == 4 then -- cmyk
        if cmyk_okay then
            -- okay
        elseif rgb_okay then
            return 3
        elseif gray_okay then
            return 2
        end
    elseif model == 5 then -- spot
        if cmyk_okay then
            return 4
        elseif rgb_okay then
            return 3
        elseif gray_okay then
            return 2
        end
    end
    return model
end

colors.forcedmodel = forcedmodel

-- By coupling we are downward compatible. When we decouple we need to do more tricky
-- housekeeping (e.g. persist color independent transparencies when color bound ones
-- are nil.)

colors.couple = true

function colors.definetransparency(name,n)
    transparent[name] = n
end

local registered = { }

local function do_registerspotcolor(parent,name,parentnumber,e,f,d,p)
    if not registered[parent] then
        local v = colorvalues[parentnumber]
        if v then
            local model = colors.default -- else problems with shading etc
            if model == 1 then model = v[1] end
            if e and e ~= "" then
                registrations.spotcolorname(parent,e) -- before registration of the color
            end
            if     model == 2 then -- name noffractions names p's r g b
                registrations.grayspotcolor(parent,f,d,p,v[2])
            elseif model == 3 then
                registrations.rgbspotcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif model == 4 then
                registrations.cmykspotcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
        end
        registered[parent] = true
    end
end

local function do_registermultitonecolor(parent,name,parentnumber,e,f,d,p) -- same as spot but different template
    if not registered[parent] then
        local v = colorvalues[parentnumber]
        if v then
            local model = colors.default -- else problems with shading etc
            if model == 1 then model = v[1] end
            if     model == 2 then
                registrations.grayindexcolor(parent,f,d,p,v[2])
            elseif model == 3 then
                registrations.rgbindexcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif model == 4 then
                registrations.cmykindexcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
        end
        registered[parent] = true
    end
end

function colors.definesimplegray(name,s)
    return register_color(name,'gray',s) -- we still need to get rid of 'color'
end

local hexdigit    = R("09","AF","af")
local hexnumber   = hexdigit * hexdigit / function(s) return tonumber(s,16)/255 end + Cc(0)
local hexpattern  = hexnumber^-3 * P(-1)
local hexcolor    = Cc("H") * P("#") * hexpattern

local left        = P("(")
local right       = P(")")
local comma       = P(",")
local mixnumber   = lpegpatterns.number / tonumber
local mixname     = C(P(1-left-right-comma)^1)
----- mixcolor    = Cc("M") * mixnumber * left * mixname * (comma * mixname)^-1 * right * P(-1)
local mixcolor    = Cc("M") * mixnumber * left * mixname * (comma * mixname)^0 * right * P(-1) -- one is also ok

local exclamation = P("!")
local pgfnumber   = lpegpatterns.digit^0 / function(s) return tonumber(s)/100 end
local pgfname     = C(P(1-exclamation)^1)
local pgfcolor    = Cc("P") * pgfname * exclamation * pgfnumber * (exclamation * pgfname)^-1 * P(-1)

local specialcolor = hexcolor + mixcolor

local l_color        = attributes.list[a_color]
local l_transparency = attributes.list[a_transparency]

directives.register("colors.pgf",function(v)
    if v then
        specialcolor = hexcolor + mixcolor + pgfcolor
    else
        specialcolor = hexcolor + mixcolor
    end
end)

function colors.defineprocesscolor(name,str,global,freeze) -- still inconsistent color vs transparent
    local what, one, two, three = lpegmatch(specialcolor,str)
    if what == "H" then
        -- for old times sake (if we need to feed from xml or so)
        definecolor(name, register_color(name,'rgb',one,two,three),global)
    elseif what == "M" then
        -- intermediate
        return colors.defineintermediatecolor(name,one,l_color[two],l_color[three],l_transparency[two],l_transparency[three],"",global,freeze)
    elseif what == "P" then
        -- pgf for tikz
        return colors.defineintermediatecolor(name,two,l_color[one],l_color[three],l_transparency[one],l_transparency[three],"",global,freeze)
    else
        local settings = settings_to_hash_strict(str)
        if settings then
            local r, g, b = settings.r, settings.g, settings.b
            if r or g or b then
                -- we can consider a combined rgb cmyk s definition
                definecolor(name, register_color(name,'rgb', tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0), global)
            else
                local c, m, y, k = settings.c, settings.m, settings.y, settings.k
                if c or m or y or b then
                    definecolor(name, register_color(name,'cmyk',tonumber(c) or 0, tonumber(m) or 0, tonumber(y) or 0, tonumber(k) or 0), global)
                else
                    local h, s, v = settings.h, settings.s, settings.v
                    if v then
                        r, g, b = colors.hsvtorgb(tonumber(h) or 0, tonumber(s) or 1, tonumber(v) or 1) -- maybe later native
                        definecolor(name, register_color(name,'rgb',r,g,b), global)
                    else
                        local x = settings.x or h
                        if x then
                            r, g, b = lpegmatch(hexpattern,x) -- can be inlined
                            definecolor(name, register_color(name,'rgb',r,g,b), global)
                        else
                            definecolor(name, register_color(name,'gray',tonumber(s) or 0), global)
                        end
                    end
                end
            end
            local a, t = settings.a, settings.t
            if a and t then
                definetransparent(name, transparencies.register(name,transparent[a] or tonumber(a) or 1,tonumber(t) or 1), global)
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
    colorset[name] = true-- maybe we can store more
end

function colors.isblack(ca) -- maybe commands
    local cv = ca > 0 and colorvalues[ca]
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
    colorset[name] = true-- maybe we can store more
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
    local dd, pp, nn, max = { }, { }, { }, 0
    for k,v in gmatch(multispec,"(%a+)=([^%,]*)") do -- use settings_to_array
        max = max + 1
        dd[max] = k
        pp[max] = v
        nn[max] = formatters["%s_%1.3g"](k,tonumber(v) or 0) -- 0 can't happen
    end
    if max > 0 then
        nn = concat(nn,'_')
        local parent = gsub(lower(nn),"[^%d%a%.]+","_")
        if not colorspec or colorspec == "" then
            local cc = { } for i=1,max do cc[i] = l_color[dd[i]] end
            colors.definemixcolor(parent,pp,cc,global,freeze) -- can become local
        else
            if selfspec ~= "" then
                colorspec = colorspec .. "," .. selfspec
            end
            colors.defineprocesscolor(parent,colorspec,true,true)
        end
        local cp = attributes_list[a_color][parent]
        dd, pp = concat(dd,','), concat(pp,',')
        if cp then
            do_registerspotcolor(parent, name, cp, "", max, dd, pp)
            definecolor(name, register_color(name, 'spot', parent, max, dd, pp), true)
            local t = settings_to_hash_strict(selfspec)
            if t and t.a and t.t then
                definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
            elseif colors.couple then
            --  definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                definetransparent(name, 0, global) -- can be sped up
            end
        end
    end
    colorset[name] = true-- maybe we can store more
end

-- will move to mlib-col as colors in m,p are somewhat messy due to the fact
-- that we cannot cast

local function mpcolor(model,ca,ta,default)
    local cv = colorvalues[ca]
    if cv then
        local tv = transparencyvalues[ta]
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
        if tv then
            if model == 2 then
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 3 then
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 4 then
                return formatters["transparent(%s,%s,cmyk(%s,%s,%s,%s))"](tv[1],tv[2],cv[6],cv[7],cv[8],cv[9])
            elseif model == 5 then
                return formatters['transparent(%s,%s,multitonecolor("%s",%s,"%s","%s"))'](tv[1],tv[2],cv[10],cv[11],cv[12],cv[13])
            else -- see ** in meta-ini.mkiv: return formatters["transparent(%s,%s,(%s))"](tv[1],tv[2],cv[2])
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            end
        else
            if model == 2 then
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            elseif model == 3 then
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            elseif model == 4 then
                return formatters["cmyk(%s,%s,%s,%s)"](cv[6],cv[7],cv[8],cv[9])
            elseif model == 5 then
                return formatters['multitonecolor("%s",%s,"%s","%s")'](cv[10],cv[11],cv[12],cv[13])
            else -- see ** in meta-ini.mkiv: return formatters["%s"]((cv[2]))
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            end
        end
    else
        default = default or 0 -- rgb !
        return formatters["(%s,%s,%s)"](default,default,default)
    end
end

local function mpnamedcolor(name)
    return mpcolor(texattribute[a_colorspace],l_color[name] or l_color.black)
end

local function mpoptions(model,ca,ta,default) -- will move to mlib-col
    return formatters["withcolor %s"](mpcolor(model,ca,ta,default))
end

colors.mpcolor      = mpcolor
colors.mpnamedcolor = mpnamedcolor
colors.mpoptions    = mpoptions

function colors.formatcolor(ca,separator)
    local cv = colorvalues[ca]
    if cv then
        local c, cn, f, t, model = { }, 0, 13, 13, cv[1]
        if model == 2 then
            f, t = 2, 2
        elseif model == 3 then
            f, t = 3, 5
        elseif model == 4 then
            f, t = 6, 9
        end
        for i=f,t do
            cn = cn + 1
            c[cn] = format("%0.3f",cv[i])
        end
        return concat(c,separator)
    else
        return format("%0.3f",0)
    end
end

function colors.formatgray(ca,separator)
    local cv = colorvalues[ca]
    return format("%0.3f",(cv and cv[2]) or 0)
end

function colors.colorcomponents(ca) -- return list
    local cv = colorvalues[ca]
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
    local tv = transparencyvalues[ta]
    if tv then
        return format("a=%1.3f t=%1.3f",tv[1],tv[2])
    else
        return ""
    end
end

function colors.spotcolorname(ca,default)
    local cv, v = colorvalues[ca], "unknown"
    if cv and cv[1] == 5 then
        v = cv[10]
    end
    return tostring(v)
end

function colors.spotcolorparent(ca,default)
    local cv, v = colorvalues[ca], "unknown"
    if cv and cv[1] == 5 then
        v = cv[12]
        if v == "" then
            v = cv[10]
        end
    end
    return tostring(v)
end

function colors.spotcolorvalue(ca,default)
    local cv, v = colorvalues[ca], 0
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
    local one, two = colorvalues[c_one], colorvalues[c_two]
    if one then
        if two then
            local csone, cstwo = one[1], two[1]
         -- if csone == cstwo then
                -- actually we can set all 8 values at once here but this is cleaner as we avoid
                -- problems with weighted gray conversions and work with original values
                local ca
                if csone == 2 then
                    ca = register_color(name,'gray',f(one,two,2,fraction))
                elseif csone == 3 then
                    ca = register_color(name,'rgb', f(one,two,3,fraction),
                                                    f(one,two,4,fraction),
                                                    f(one,two,5,fraction))
                elseif csone == 4 then
                    ca = register_color(name,'cmyk',f(one,two,6,fraction),
                                                    f(one,two,7,fraction),
                                                    f(one,two,8,fraction),
                                                    f(one,two,9,fraction))
                else
                    ca = register_color(name,'gray',f(one,two,2,fraction))
                end
                definecolor(name,ca,global,freeze)
         -- end
        else
            local csone = one[1]
            local ca
            if csone == 2 then
                ca = register_color(name,'gray',fraction*one[2])
            elseif csone == 3 then
                ca = register_color(name,'rgb', fraction*one[3],
                                                fraction*one[4],
                                                fraction*one[5])
            elseif csone == 4 then
                ca = register_color(name,'cmyk',fraction*one[6],
                                                fraction*one[7],
                                                fraction*one[8],
                                                fraction*one[9])
            else
                ca = register_color(name,'gray',fraction*one[2])
            end
            definecolor(name,ca,global,freeze)
        end
    end
    local one, two = transparencyvalues[a_one], transparencyvalues[a_two]
    local t = settings_to_hash_strict(specs)
    local ta = tonumber((t and t.a) or (one and one[1]) or (two and two[1]))
    local tt = tonumber((t and t.t) or (one and two and f(one,two,2,fraction)))
    if ta and tt then
        definetransparent(name,transparencies.register(name,ta,tt),global)
    end
end

local function f(i,colors,fraction)
    local otf = 0
    for c=1,#colors do
        otf = otf + (tonumber(fraction[c]) or 1) * colors[c][i]
    end
    if otf > 1 then
        otf = 1
    end
    return otf
end

function colors.definemixcolor(name,fractions,cs,global,freeze)
    local values = { }
    for i=1,#cs do -- do fraction in here
        local v = colorvalues[cs[i]]
        if not v then
            return
        end
        values[i] = v
    end
    local csone = values[1][1]
    local ca
    if csone == 2 then
        ca = register_color(name,'gray',f(2,values,fractions))
    elseif csone == 3 then
        ca = register_color(name,'rgb', f(3,values,fractions),
                                        f(4,values,fractions),
                                        f(5,values,fractions))
    elseif csone == 4 then
        ca = register_color(name,'cmyk',f(6,values,fractions),
                                        f(7,values,fractions),
                                        f(8,values,fractions),
                                        f(9,values,fractions))
    else
        ca = register_color(name,'gray',f(2,values,fractions))
    end
    definecolor(name,ca,global,freeze)
end

-- for the moment downward compatible

local patterns = { "colo-imp-%s.mkiv", "colo-imp-%s.tex", "colo-%s.mkiv", "colo-%s.tex" }

local function action(name,foundname)
    -- could be one command
    context.startreadingfile()
    context.startcolorset { name }
    context.input(foundname)
    context.showmessage("colors",4,name)
    context.stopcolorset()
    context.stopreadingfile()
end

local function failure(name)
 -- context.showmessage("colors",5,name)
    report_colors("unknown library %a",name)
end

function colors.usecolors(name)
    commands.uselibrary {
        category = "color definition",
        name     = name,
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = true,
    }
end

-- interface (todo: use locals)

local setcolormodel = colors.setmodel

function commands.setcolormodel(model,weight)
    settexattribute(a_colorspace,setcolormodel(model,weight))
end

-- function commands.setrastercolor(name,s)
--     settexattribute(a_color,colors.definesimplegray(name,s))
-- end

function commands.registermaintextcolor(a)
    colors.main = a
end

commands.defineprocesscolor      = colors.defineprocesscolor
commands.definespotcolor         = colors.definespotcolor
commands.definemultitonecolor    = colors.definemultitonecolor
commands.definetransparency      = colors.definetransparency
commands.defineintermediatecolor = colors.defineintermediatecolor

function commands.spotcolorname         (a)   context(colors.spotcolorname         (a))   end
function commands.spotcolorparent       (a)   context(colors.spotcolorparent       (a))   end
function commands.spotcolorvalue        (a)   context(colors.spotcolorvalue        (a))   end
function commands.colorcomponents       (a)   context(colors.colorcomponents       (a))   end
function commands.transparencycomponents(a)   context(colors.transparencycomponents(a))   end
function commands.formatcolor           (...) context(colors.formatcolor           (...)) end
function commands.formatgray            (...) context(colors.formatgray            (...)) end

function commands.mpcolor(model,ca,ta,default)
    context(mpcolor(model,ca,ta,default))
end

function commands.mpoptions(model,ca,ta,default)
    context(mpoptions(model,ca,ta,default))
end

function commands.doifblackelse(a)
    commands.doifelse(colors.isblack(a))
end

function commands.doifdrawingblackelse()
    commands.doifelse(colors.isblack(gettexattribute(a_color)))
end

-- function commands.withcolorsinset(name,command)
--     local set
--     if name and name ~= "" then
--         set = colorsets[name]
--     else
--         set = colorsets.default
--     end
--     if set then
--         if command then
--             for name in table.sortedhash(set) do
--                 context[command](name)
--             end
--         else
--             context(concat(table.sortedkeys(set),","))
--         end
--     end
-- end

commands.startcolorset = colors.pushset
commands.stopcolorset  = colors.popset

commands.usecolors = colors.usecolors

-- bonus

function commands.pgfxcolorspec(ca) -- {}{}{colorspace}{list}
 -- local cv = attributes.colors.values[ca]
    local cv = colorvalues[ca]
    if cv then
        local model = cv[1]
        if model == 2 then
            context("{gray}{%1.3f}",cv[2])
        elseif model == 3 then
            context("{rgb}{%1.3f,%1.3f,%1.3f}",cv[3],cv[4],cv[5])
        elseif model == 4 then
            context("{cmyk}{%1.3f,%1.3f,%1.3f,%1.3f}",cv[6],cv[7],cv[8],cv[9])
        else
            context("{gray}{%1.3f}",cv[2])
        end
    else
        context("{gray}{0}")
    end
end

-- function commands.pgfregistercolor(name,attribute)
--     local cv = colorvalues[ca]
--     context.pushcatcodes('prt')
--     if cv then
--         local model = forcedmodel(cv[1])
--         if model == 2 then
--             context["pgfutil@definecolor"]("{%s}{gray}{%1.3f}",name,cv[2])
--         elseif model == 3 then
--             context["pgfutil@definecolor"]("{%s}{rgb}{%1.3f,%1.3f,%1.3f}",name,cv[3],cv[4],cv[5])
--         elseif model == 4 then
--             context["pgfutil@definecolor"]("{%s}{cmyk}{%1.3f,%1.3f,%1.3f,%1.3f}",name,cv[6],cv[7],cv[8],cv[9])
--         else
--             context["pgfutil@definecolor"]("{%s}{gray}{0}",name)
--         end
--     else
--         context["pgfutil@definecolor"]("{%s}{gray}{0}",name)
--     end
--     context.popcatcodes()
-- end

-- handy

local models = storage.allocate { "all", "gray", "rgb", "cmyk", "spot" }

colors.models = models -- check for usage elsewhere

function colors.spec(name)
    local l = attributes_list[a_color]
    local t = colorvalues[l[name]] or colorvalues[l.black]
    return {
        model = models[t[1]] or models[1],
        s = t[2],
        r = t[3], g = t[4], b = t[5],
        c = t[6], m = t[7], y = t[8], k = t[9],
    }
end

-- inspect(attributes.colors.spec("red"))
-- inspect(attributes.colors.spec("red socks"))
