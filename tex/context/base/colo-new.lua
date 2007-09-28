if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for the moment this looks messy but we're waiting for a pdf backend interface
--
-- code collected here will move and be adapted
--
-- some pdf related code can go away

-- spec-pdf.lua

backends     = backends     or { }
backends.pdf = backends.pdf or { }
backend      = backends.pdf

do

    -- maybe combine spotcolorname

    local s_template_g = "\\doregistergrayspotcolor{%s}{%s}{%s}{%s}{%s}"             -- n f d p s (p can go away)
    local s_template_r = "\\doregisterrgbspotcolor {%s}{%s}{%s}{%s}{%s}{%s}{%s}"     -- n f d p r g b
    local s_template_c = "\\doregistercmykspotcolor{%s}{%s}{%s}{%s}{%s}{%s}{%s}{%s}" -- n f d p c m y k

    function backends.pdf.registergrayspotcolor(n,f,d,p,s)       states.collect(s_template_g:format(n,f,d,p,s))       end
    function backends.pdf.registerrgbspotcolor (n,f,d,p,r,g,b)   states.collect(s_template_r:format(n,f,d,p,r,g,b))   end
    function backends.pdf.registercmykspotcolor(n,f,d,p,c,m,y,k) states.collect(s_template_c:format(n,f,d,p,c,m,y,k)) end

    local m_template_g = "\\doregistergrayindexcolor{%s}{%s}{%s}{%s}{%s}"             -- n f d p s (p can go away)
    local m_template_r = "\\doregisterrgbindexcolor {%s}{%s}{%s}{%s}{%s}{%s}{%s}"     -- n f d p r g b
    local m_template_c = "\\doregistercmykindexcolor{%s}{%s}{%s}{%s}{%s}{%s}{%s}{%s}" -- n f d p c m y k

    function backends.pdf.registergrayindexcolor(n,f,d,p,s)       states.collect(m_template_g:format(n,f,d,p,s))       end
    function backends.pdf.registerrgbindexcolor (n,f,d,p,r,g,b)   states.collect(m_template_r:format(n,f,d,p,r,g,b))   end
    function backends.pdf.registercmykindexcolor(n,f,d,p,c,m,y,k) states.collect(m_template_c:format(n,f,d,p,c,m,y,k)) end

    local s_template_e = "\\doregisterspotcolorname{%s}{%s}" -- name, e

    function backends.pdf.registerspotcolorname(name,e)
        if e and e ~= "" then
           tex.sprint(tex.ctxcatcodes,string.format(s_template_e,name,e))
        end
    end

end

ctx     = ctx     or { }
ctx.aux = ctx.aux or { }

do

    local a_l_c_template = "\\setevalue{(ca:%s)}{%s}" ..
                           "\\setevalue{(cs:%s)}{\\dosetattribute{color}{%s}}"
    local a_g_c_template = "\\setxvalue{(ca:%s)}{%s}" ..
                           "\\setxvalue{(cs:%s)}{\\dosetattribute{color}{%s}}"
    local f_l_c_template = "\\setvalue {(ca:%s)}{\\doinheritca{%s}}" ..
                           "\\setvalue {(cs:%s)}{\\doinheritcs{%s}}"
    local f_g_c_template = "\\setgvalue{(ca:%s)}{\\doinheritca{%s}}" ..
                           "\\setgvalue{(cs:%s)}{\\doinheritcs{%s}}"

    local a_l_t_template = "\\setevalue{(ta:%s)}{%s}" ..
                           "\\setevalue{(ts:%s)}{\\dosetattribute{transparency}{%s}}"
    local a_g_t_template = "\\setxvalue{(ta:%s)}{%s}" ..
                           "\\setxvalue{(ts:%s)}{\\dosetattribute{transparency}{%s}}"
    local f_l_t_template = "\\setvalue {(ta:%s)}{\\doinheritta{%s}}" ..
                           "\\setvalue {(ts:%s)}{\\doinheritts{%s}}"
    local f_g_t_template = "\\setgvalue{(ta:%s)}{\\doinheritta{%s}}" ..
                           "\\setgvalue{(ts:%s)}{\\doinheritts{%s}}"

    function ctx.aux.definecolor(name, ca, global)
        if ca and ca > 0 then
            if global then
                tex.sprint(tex.ctxcatcodes,a_g_c_template:format(name, ca, name, ca))
            else
                tex.sprint(tex.ctxcatcodes,a_l_c_template:format(name, ca, name, ca))
            end
        end
    end
    function ctx.aux.inheritcolor(name, ca, global)
        if ca and ca ~= "" then
            if global then
                tex.sprint(tex.ctxcatcodes,f_g_c_template:format(name, ca, name, ca))
            else
                tex.sprint(tex.ctxcatcodes,f_l_c_template:format(name, ca, name, ca))
            end
        end
    end
    function ctx.aux.definetransparent(name, ta, global)
        if ta and ta > 0 then
            if global then
                tex.sprint(tex.ctxcatcodes,a_g_t_template:format(name, ta, name, ta))
            else
                tex.sprint(tex.ctxcatcodes,a_l_t_template:format(name, ta, name, ta))
            end
        end
    end
    function ctx.aux.inherittransparent(name, ta, global)
        if ta and ta ~= "" then
            if global then
                tex.sprint(tex.ctxcatcodes,f_g_t_template:format(name, ta, name, ta))
            else
                tex.sprint(tex.ctxcatcodes,f_l_t_template:format(name, ta, name, ta))
            end
        end
    end

end

do

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

    local function registerspotcolor(parent,name,parentnumber,e,f,d,p)
        local v = colors.values[parentnumber]
        if v then
            local kind = v[1]
            if     kind == 2 then -- name noffractions names p's r g b
                backend.registergrayspotcolor(parent,f,d,p,v[2])
            elseif kind == 3 then
                backend.registerrgbspotcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif kind == 4 then
                backend.registercmykspotcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
            backends.pdf.registerspotcolorname(name,e)
        end
    end

    local function registermultitonecolor(parent,name,parentnumber,e,f,d,p) -- same as spot but different template
        local v = colors.values[parentnumber]
        if v then
            local kind = v[1]
            if     kind == 2 then
                backend.registergrayindexcolor(parent,f,d,p,v[2])
            elseif kind == 3 then
                backend.registerrgbindexcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif kind == 4 then
                backend.registercmykindexcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
        end
    end

    function ctx.definesimplegray(name,s)
        return colors.register('color',name,'gray',s) -- we still need to get rid of 'color'
    end

    function ctx.defineprocesscolor(prefix,name,str,global,freeze) -- still inconsistent color vs transparent
        local t = str:split_settings()
        if t then
            if t.h then
                local r, g, b =string.match(t.h .. "000000","(..)(..)(..)")
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
--~                 ctx.aux.definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                ctx.aux.definetransparent(name, 0, global) -- can be sped up
            end
        elseif freeze then
            local ca = attributes.list[attributes.numbers['color']]       [str]
            local ta = attributes.list[attributes.numbers['transparency']][str]
            if ca then
                ctx.aux.definecolor(name, ca, global)
            end
            if ta then
                ctx.aux.definetransparent(name, ta, global)
            end
        else
            ctx.aux.inheritcolor(name, str, global)
            ctx.aux.inherittransparent(name, str, global)
        end
    end

    function ctx.definespotcolor(prefix,name,parent,str,global)
        if name ~= parent then
            local cp = attributes.list[attributes.numbers['color']][parent]
            if cp then
                local t = str:split_settings()
                if t then
                    t.p = tonumber(t.p) or 1
                    registerspotcolor(parent, name, cp, t.e, 1, "", t.p) -- p not really needed, only diagnostics
                    ctx.aux.definecolor(name, colors.register('color',name,'spot', parent, 1, "", t.p), true)
                    if t.a and t.t then
                        ctx.aux.definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
                    elseif ctx.couplecolors then
--~                         ctx.aux.definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                        ctx.aux.definetransparent(name, 0, global) -- can be sped up
                    end
                end
            end
        end
    end

    function ctx.definemultitonecolor(prefix,name,multispec,colorspec,selfspec)
        local dd, pp, nn = { }, { }, { }
        for k,v in multispec:gmatch("(%a+)=([^%,]*)") do
            dd[#dd+1] = k
            pp[#pp+1] = v
            nn[#nn+1] = k
            nn[#nn+1] = string.format("%1.3g",tonumber(v))
        end
    --~ v = tonumber(v) * p
        local nof = #dd
        if nof > 0 then
            dd, pp, nn = table.concat(dd,','), table.concat(pp,','), table.concat(nn,'_')
            local parent = (nn:lower()):gsub("[^%d%a%.]+","_")
            ctx.defineprocesscolor(prefix,parent,colorspec..","..selfspec,true,true)
            local cp = attributes.list[attributes.numbers['color']][parent]
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
                    return string.format("transparent(%s,%s,(%s,%s,%s))",tv[1],tv[2],cv[3],cv[4],cv[5])
                elseif model == 3 then
                    return string.format("transparent(%s,%s,(%s,%s,%s))",tv[1],tv[2],cv[3],cv[4],cv[5])
                elseif model == 4 then
                    return string.format("transparent(%s,%s,cmyk(%s,%s,%s,%s))",tv[1],tv[2],cv[6],cv[7],cv[8],cv[9])
                else
                    return string.format("transparent(%s,%s,multitonecolor(\"%s\",%s,\"%s\",\"%s\"))",tv[1],tv[2],cv[10],cv[11],cv[12],cv[13])
                end
            else
                if model == 2 then
                    return string.format("(%s,%s,%s)",cv[3],cv[4],cv[5])
                elseif model == 3 then
                    return string.format("(%s,%s,%s)",cv[3],cv[4],cv[5])
                elseif model == 4 then
                    return string.format("cmyk(%s,%s,%s,%s)",cv[6],cv[7],cv[8],cv[9])
                else
                    return string.format("multitonecolor(\"%s\",%s,\"%s\",\"%s\")",cv[10],cv[11],cv[12],cv[13])
                end
            end
        else
            default = default or 0 -- rgb !
            return string.format("(%s,%s,%s)",default,default,default)
        end
    end

    function ctx.formatcolor(ca,separator)
        local cv = colors.value(ca)
        if cv then
            local model = cv[1]
            if model == 2 then
                return tostring(cv[2])
            elseif model == 3 then
                return table.concat(cv,separator,3,5)
            elseif model == 4 then
                return table.concat(cv,separator,6,9)
            else
                return tostring(cv[13])
            end
        else
            return tostring(0)
        end
    end

    function ctx.formatgray(ca,separator)
        local cv = colors.value(ca)
        if cv then
            return tostring(cv[2])
        else
            return tostring(0)
        end
    end

    function ctx.colorcomponents(ca)
        local cv = colors.value(ca)
        if cv then
            local model = cv[1]
            if model == 2 then
                return string.format("s=%1.3f",cv[2])
            elseif model == 3 then
                return string.format("r=%1.3f g=%1.3f b=%1.3f",cv[3],cv[4],cv[5])
            elseif model == 4 then
                return string.format("c=%1.3f m=%1.3f y=%1.3f k=%1.3f",cv[6],cv[7],cv[8],cv[9])
            elseif type(cv[13]) == "string" then
                return string.format("p=%s",cv[13])
            else
                return string.format("p=%1.3f",cv[13])
            end
        else
            return ""
        end
    end

    function ctx.transparencycomponents(ta)
        local tv = transparencies.value(ta)
        if tv then
            return string.format("a=%1.3f t=%1.3f",tv[1],tv[2])
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
                return string.format("%s g %s G",s,s)
            elseif model == 3 then
                local r, g, b = cv[3], cv[4], cv[5]
                return string.format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b)
            elseif model == 4 then
                local c, m, y, k = cv[6],cv[7],cv[8],cv[9]
                return string.format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k)
            else
                local n,f,d,p = cv[10],cv[11],cv[12],cv[13]
                if type(p) == "string" then
                    p = p:gsub(","," ") -- brr misuse of spot
                end
                return string.format("/%s cs /%s CS %s SCN %s scn",n,n,p,p)
            end
        else
            return string.format("%s g %s G",default or 0)
        end
    end

    function ctx.pdfcolorvalue(model,ca,default)
        local cv = colors.value(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            if model == 2 then
                return string.format("%s",cv[2])
            elseif model == 3 then
                return string.format("%s %s %s",cv[3],cv[4],cv[5])
            elseif model == 4 then
                return string.format("%s %s %s %s",cv[6],cv[7],cv[8],cv[9])
            else
                return string.format("%s",cv[13])
            end
        else
            return string.format("%s",default or 0)
        end
    end

    function ctx.fdfcolor(model,ca,default)
        local cv = colors.value(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            if model == 2 then
                return string.format("[%s]",cv[2])
            elseif model == 3 then
                return string.format("[%s %s %s]",cv[3],cv[4],cv[5])
            elseif model == 4 then
                return string.format("[%s %s %s %s]",cv[6],cv[7],cv[8],cv[9])
            elseif model == 4 then
                return string.format("[%s]",cv[13])
            end
        else
            return string.format("[%s]",default or 0)
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

end

-- unfortunately we have \cs's here but this will go anyway once we have mplib and such

function ctx.resolvempgraycolor(csa,csb,model,s)
    local ca = colors.register('color',nil,'gray',s)
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvemprgbcolor(csa,csb,model,r,g,b)
    local ca = colors.register('color',nil,'rgb',r,g,b)
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvempcmykcolor(csa,csb,model,c,m,y,k)
    local ca = colors.register('color',nil,'cmyk',c,m,y,k)
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end
function ctx.resolvempspotcolor(csa,csb,model,n,f,d,p)
    local ca = colors.register('color',nil,'spot',n,f,d,p)
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csa,ctx.pdfcolorvalue(model,ca)))
    tex.sprint(tex.ctxcatcodes,string.format("\\setxvalue{%s}{%s}",csb,ctx.pdfcolorspace(model,ca)))
end

-- literals needed to inject code in the mp stream, we cannot use attributes there
-- since literals may have qQ's

function ctx.pdfrgbliteral(model,r,g,b)
    tex.sprint(tex.ctxcatcodes,string.format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'rgb',r,g,b))))
end
function ctx.pdfcmykliteral(model,c,m,y,k)
    tex.sprint(tex.ctxcatcodes,string.format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'cmyk',c,m,y,k))))
end
function ctx.pdfgrayliteral(model,s)
    tex.sprint(tex.ctxcatcodes,string.format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'gray',s))))
end
function ctx.pdfspotliteral(model,n,f,d,p)
    tex.sprint(tex.ctxcatcodes,string.format("\\pdfliteral{%s}",ctx.pdfcolor(model,colors.register('color',nil,'spot',n,f,d,p)))) -- incorrect
end
function ctx.pdftransparencyliteral(a,t)
    tex.sprint(tex.ctxcatcodes,string.format("\\pdfliteral{/Tr%s gs}",transparencies.register(nil,a,t)))
end
