if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- split_settings -> aux.settings_to_hash

-- for the moment this looks messy but we're waiting for a pdf backend interface
--
-- code collected here will move and be adapted
--
-- some pdf related code can go away

-- spec-pdf.lua

-- todo: %s -> %f

local texsprint = tex.sprint
local concat =table.concat
local format, gmatch, gsub, lower = string.format, string.gmatch, string.gsub, string.lower

ctx     = ctx     or { }
ctx.aux = ctx.aux or { }

local ctxcatcodes = tex.ctxcatcodes

local registrations = backends.registrations

local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')
local a_background   = attributes.private('background')

local a_l_c_template = "\\setevalue{(ca:%s)}{%s}" ..
                       "\\setevalue{(cs:%s)}{\\dosetattribute{color}{%s}}"
local a_g_c_template = "\\setxvalue{(ca:%s)}{%s}" ..
                       "\\setxvalue{(cs:%s)}{\\dosetattribute{color}{%s}}"
local f_l_c_template = "\\setvalue {(ca:%s)}{\\doinheritca{%s}}" ..
                       "\\setvalue {(cs:%s)}{\\doinheritcs{%s}}"
local f_g_c_template = "\\setgvalue{(ca:%s)}{\\doinheritca{%s}}" ..
                       "\\setgvalue{(cs:%s)}{\\doinheritcs{%s}}"
local r_l_c_template = "\\localundefine{(ca:%s)}" ..
                       "\\localundefine{(cs:%s)}"
local r_g_c_template = "\\globalundefine{(ca:%s)}" ..
                       "\\globalundefine{(cs:%s)}"

local a_l_t_template = "\\setevalue{(ta:%s)}{%s}" ..
                       "\\setevalue{(ts:%s)}{\\dosetattribute{transparency}{%s}}"
local a_g_t_template = "\\setxvalue{(ta:%s)}{%s}" ..
                       "\\setxvalue{(ts:%s)}{\\dosetattribute{transparency}{%s}}"
local f_l_t_template = "\\setvalue {(ta:%s)}{\\doinheritta{%s}}" ..
                       "\\setvalue {(ts:%s)}{\\doinheritts{%s}}"
local f_g_t_template = "\\setgvalue{(ta:%s)}{\\doinheritta{%s}}" ..
                       "\\setgvalue{(ts:%s)}{\\doinheritts{%s}}"
local r_l_t_template = "\\localundefine{(ta:%s)}" ..
                       "\\localundefine{(ts:%s)}"
local r_g_t_template = "\\globalundefine{(ta:%s)}" ..
                       "\\globalundefine{(ts:%s)}"

function ctx.aux.definecolor(name, ca, global)
    if ca and ca > 0 then
        if global then
            texsprint(ctxcatcodes,format(a_g_c_template, name, ca, name, ca))
        else
            texsprint(ctxcatcodes,format(a_l_c_template, name, ca, name, ca))
        end
    else
        if global then
            texsprint(ctxcatcodes,format(r_g_c_template, name, name))
        else
            texsprint(ctxcatcodes,format(r_l_c_template, name, name))
        end
    end
end
function ctx.aux.inheritcolor(name, ca, global)
    if ca and ca ~= "" then
        if global then
            texsprint(ctxcatcodes,format(f_g_c_template, name, ca, name, ca))
        else
            texsprint(ctxcatcodes,format(f_l_c_template, name, ca, name, ca))
        end
    else
        if global then
            texsprint(ctxcatcodes,format(r_g_c_template, name, name))
        else
            texsprint(ctxcatcodes,format(r_l_c_template, name, name))
        end
    end
end
function ctx.aux.definetransparent(name, ta, global)
    if ta and ta > 0 then
        if global then
            texsprint(ctxcatcodes,format(a_g_t_template, name, ta, name, ta))
        else
            texsprint(ctxcatcodes,format(a_l_t_template, name, ta, name, ta))
        end
    else
        if global then
            texsprint(ctxcatcodes,format(r_g_t_template, name, name))
        else
            texsprint(ctxcatcodes,format(r_l_t_template, name, name))
        end
    end
end
function ctx.aux.inherittransparent(name, ta, global)
    if ta and ta ~= "" then
        if global then
            texsprint(ctxcatcodes,format(f_g_t_template, name, ta, name, ta))
        else
            texsprint(ctxcatcodes,format(f_l_t_template, name, ta, name, ta))
        end
    else
        if global then
            texsprint(ctxcatcodes,format(r_g_t_template, name, name))
        else
            texsprint(ctxcatcodes,format(r_l_t_template, name, name))
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
-- are nil.

ctx.couplecolors = true

function ctx.definetransparency(name,n)
    transparent[name] = n
end

local registered = { }

local function registerspotcolor(parent,name,parentnumber,e,f,d,p)
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

local function registermultitonecolor(parent,name,parentnumber,e,f,d,p) -- same as spot but different template
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

function ctx.definesimplegray(name,s)
    return colors.register('color',name,'gray',s) -- we still need to get rid of 'color'
end

function ctx.defineprocesscolor(name,str,global,freeze) -- still inconsistent color vs transparent
    local t = str:split_settings()
    if t then
        if t.h then
            local r, g, b = (t.h .. "000000"):match("(..)(..)(..)")
            ctx.aux.definecolor(name, colors.register('color',name,'rgb',(tonumber(r,16) or 0)/256,(tonumber(g,16) or 0)/256,(tonumber(b,16) or 0)/256               ), global)
        elseif t.r or t.g or t.b then
            ctx.aux.definecolor(name, colors.register('color',name,'rgb', tonumber(t.r)  or 0,      tonumber(t.g)  or 0,      tonumber(t.b)  or 0                    ), global)
        elseif t.c or t.m or t.y or t.k then
            ctx.aux.definecolor(name, colors.register('color',name,'cmyk',tonumber(t.c)  or 0,      tonumber(t.m)  or 0,      tonumber(t.y)  or 0, tonumber(t.k) or 0), global)
        else
            ctx.aux.definecolor(name, colors.register('color',name,'gray',tonumber(t.s)  or 0), global)
        end
        if t.a and t.t then
            ctx.aux.definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
        elseif ctx.couplecolors then
        --  ctx.aux.definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
            ctx.aux.definetransparent(name, 0, global) -- can be sped up
        end
    elseif freeze then
        local ca = attributes.list[a_color]       [str]
        local ta = attributes.list[a_transparency][str]
        if ca then
            ctx.aux.definecolor(name, ca, global)
        end
        if ta then
            ctx.aux.definetransparent(name, ta, global)
        end
    else
        ctx.aux.inheritcolor(name, str, global)
        ctx.aux.inherittransparent(name, str, global)
    --  if global and str ~= "" then -- For Peter Rolf who wants access to the numbers in Lua. (Currently only global is supported.)
    --      attributes.list[a_color]       [name] = attributes.list[a_color]       [str] or attributes.unsetvalue  -- reset
    --      attributes.list[a_transparency][name] = attributes.list[a_transparency][str] or attributes.unsetvalue
    --  end
    end
end

function ctx.isblack(ca) -- maybe commands
    local cv = ca > 0 and colors.value(ca)
    return (cv and cv[2] == 0) or false
end

function ctx.definespotcolor(name,parent,str,global)
    if parent == "" or parent:find("=") then
        ctx.registerspotcolor(name, parent)
    elseif name ~= parent then
        local cp = attributes.list[a_color][parent]
        if cp then
            local t = str:split_settings()
            if t then
                t.p = tonumber(t.p) or 1
                registerspotcolor(parent, name, cp, t.e, 1, "", t.p) -- p not really needed, only diagnostics
                if name and name ~= "" then
                    ctx.aux.definecolor(name, colors.register('color',name,'spot', parent, 1, "", t.p), true)
                    if t.a and t.t then
                        ctx.aux.definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
                    elseif ctx.couplecolors then
                    --~ ctx.aux.definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                        ctx.aux.definetransparent(name, 0, global) -- can be sped up
                    end
                end
            end
        end
    end
end

function ctx.registerspotcolor(parent, str)
    local cp = attributes.list[a_color][parent]
    if cp then
        local e = ""
        if str then
            local t = str:split_settings()
            e = (t and t.e) or ""
        end
        registerspotcolor(parent, "dummy", cp, e, 1, "", 1) -- p not really needed, only diagnostics
    end
end

function ctx.definemultitonecolor(name,multispec,colorspec,selfspec)
    local dd, pp, nn = { }, { }, { }
    for k,v in gmatch(multispec,"(%a+)=([^%,]*)") do
        dd[#dd+1] = k
        pp[#pp+1] = v
        nn[#nn+1] = k
        nn[#nn+1] = format("%1.3g",tonumber(v))
    end
--~ v = tonumber(v) * p
    local nof = #dd
    if nof > 0 then
        dd, pp, nn = concat(dd,','), concat(pp,','), concat(nn,'_')
        local parent = gsub(lower(nn),"[^%d%a%.]+","_")
        ctx.defineprocesscolor(parent,colorspec..","..selfspec,true,true)
        local cp = attributes.list[a_color][parent]
        if cp then
            registerspotcolor     (parent, name, cp, "", nof, dd, pp)
            registermultitonecolor(parent, name, cp, "", nof, dd, pp)
            ctx.aux.definecolor(name, colors.register('color', name, 'spot', parent, nof, dd, pp), true)
            local t = selfspec:split_settings()
            if t and t.a and t.t then
                ctx.aux.definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
            elseif ctx.couplecolors then
            --  ctx.aux.definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                ctx.aux.definetransparent(name, 0, global) -- can be sped up
            end
        end
    end
end

function ctx.mpcolor(model,ca,ta,default)
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

function ctx.formatcolor(ca,separator)
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

function ctx.formatgray(ca,separator)
    local cv = colors.value(ca)
    return format("%0.3f",(cv and cv[2]) or 0)
end

function ctx.colorcomponents(ca)
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

function ctx.transparencycomponents(ta)
    local tv = transparencies.value(ta)
    if tv then
        return format("a=%1.3f t=%1.3f",tv[1],tv[2])
    else
        return ""
    end
end

function ctx.pdfcolor(model,ca,default) -- todo: use gray when no color
    local cv = colors.value(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        if model == 2 then
            local s = cv[2]
            return format("%s g %s G",s,s)
        elseif model == 3 then
            local r, g, b = cv[3], cv[4], cv[5]
            return format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b)
        elseif model == 4 then
            local c, m, y, k = cv[6],cv[7],cv[8],cv[9]
            return format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k)
        else
            local n,f,d,p = cv[10],cv[11],cv[12],cv[13]
            if type(p) == "string" then
                p = gsub(p,","," ") -- brr misuse of spot
            end
            return format("/%s cs /%s CS %s SCN %s scn",n,n,p,p)
        end
    else
        return format("%s g %s G",default or 0,default or 0)
    end
end

function ctx.pdfcolorvalue(model,ca,default)
    local cv = colors.value(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        if model == 2 then
            return format("%s",cv[2])
        elseif model == 3 then
            return format("%s %s %s",cv[3],cv[4],cv[5])
        elseif model == 4 then
            return format("%s %s %s %s",cv[6],cv[7],cv[8],cv[9])
        else
            return format("%s",cv[13])
        end
    else
        return format("%s",default or 0)
    end
end

function ctx.fdfcolor(model,ca,default)
    local cv = colors.value(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        if model == 2 then
            return format("[%s]",cv[2])
        elseif model == 3 then
            return format("[%s %s %s]",cv[3],cv[4],cv[5])
        elseif model == 4 then
            return format("[%s %s %s %s]",cv[6],cv[7],cv[8],cv[9])
        elseif model == 4 then
            return format("[%s]",cv[13])
        end
    else
        return format("[%s]",default or 0)
    end
end

function ctx.pdfcolorspace(model,ca)
    local cv = colors.value(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        if model == 2 then
            return "DeviceGray"
        elseif model == 3 then
            return "DeviceRGB"
        elseif model == 4 then
            return "DeviceCMYK"
        end
    end
    return "DeviceGRAY"
end

function ctx.spotcolorname(ca,default)
    local cv, v = colors.value(ca), "unknown"
    if cv and cv[1] == 5 then
        v = cv[10]
    end
    return tostring(v)
end

function ctx.spotcolorvalue(ca,default)
    local cv, v = colors.value(ca), 0
    if cv and cv[1] == 5 then
       v = cv[13]
    end
    return tostring(v)
end

-- unfortunately we have \cs's here but this will go anyway once we have mplib and such

function ctx.resolvempgraycolor(csa,csb,model,s)
    local ca = colors.register('color',nil,'gray',s)
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvemprgbcolor(csa,csb,model,r,g,b)
    local ca = colors.register('color',nil,'rgb',r,g,b)
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvempcmykcolor(csa,csb,model,c,m,y,k)
    local ca = colors.register('color',nil,'cmyk',c,m,y,k)
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvempspotcolor(csa,csb,model,n,f,d,p)
    local ca = colors.register('color',nil,'spot',n,f,d,p)
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    texsprint(ctxcatcodes,format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end

-- literals needed to inject code in the mp stream, we cannot use attributes there
-- since literals may have qQ's, much may go away once we have mplib code in place

local intransparency = false

function ctx.pdfrgbliteral(model,r,g,b)
    texsprint(ctxcatcodes,format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'rgb',r,g,b))))
end
function ctx.pdfcmykliteral(model,c,m,y,k)
    texsprint(ctxcatcodes,format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'cmyk',c,m,y,k))))
end
function ctx.pdfgrayliteral(model,s)
    texsprint(ctxcatcodes,format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'gray',s))))
end
function ctx.pdfspotliteral(model,n,f,d,p)
    texsprint(ctxcatcodes,format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'spot',n,f,d,p)))) -- incorrect
end
function ctx.pdftransparencyliteral(a,t)
    intransparency = true
    texsprint(ctxcatcodes,format("\\pdfliteral{/Tr%s gs}",transparencies.register(nil,a,t)))
end
function ctx.pdffinishtransparency()
    if intransparency then
        intransparency = false
        texsprint(ctxcatcodes,"\\pdfliteral{/Tr0 gs}") -- we happen to know this -)
    end
end
