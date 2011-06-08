if not modules then modules = { } end modules ['lpdf-mis'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring = type, next, tostring
local char, byte, format, gsub, rep, gmatch = string.char, string.byte, string.format, string.gsub, string.rep, string.gmatch
local concat = table.concat
local round = math.round

local backends, lpdf, nodes = backends, lpdf, nodes

local nodeinjections       = backends.pdf.nodeinjections
local codeinjections       = backends.pdf.codeinjections
local registrations        = backends.pdf.registrations

local nodepool             = nodes.pool
local register             = nodepool.register
local pdfliteral           = nodepool.pdfliteral

local pdfconstant          = lpdf.constant
local pdfstring            = lpdf.string
local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfreference         = lpdf.reference
local pdfverbose           = lpdf.verbose
local pdfflushobject       = lpdf.flushobject
local pdfflushstreamobject = lpdf.flushstreamobject

local colors               = attributes.colors
local transparencies       = attributes.transparencies
local registertransparancy = transparencies.register
local registercolor        = colors.register
local colorsvalue          = colors.value
local transparenciesvalue  = transparencies.value
local forcedmodel          = colors.forcedmodel

-- injection code (needs a bit reordering)

-- color injection

function nodeinjections.rgbcolor(r,g,b)
    return register(pdfliteral(format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b)))
end

function nodeinjections.cmykcolor(c,m,y,k)
    return register(pdfliteral(format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k)))
end

function nodeinjections.graycolor(s) -- caching 0/1 does not pay off
    return register(pdfliteral(format("%s g %s G",s,s)))
end

function nodeinjections.spotcolor(n,f,d,p)
    if type(p) == "string" then
        p = gsub(p,","," ") -- brr misuse of spot
    end
    return register(pdfliteral(format("/%s cs /%s CS %s SCN %s scn",n,n,p,p)))
end

function nodeinjections.transparency(n)
    return register(pdfliteral(format("/Tr%s gs",n)))
end

-- a bit weird but let's keep it here for a while

local effects = {
    normal = 0,
    inner  = 0,
    outer  = 1,
    both   = 2,
    hidden = 3,
}

local bp = number.dimenfactors.bp

function nodeinjections.effect(effect,stretch,rulethickness)
    -- always, no zero test (removed)
    rulethickness = bp * rulethickness
    effect = effects[effect] or effects['normal']
    return register(pdfliteral(format("%s Tc %s w %s Tr",stretch,rulethickness,effect))) -- watch order
end

-- spot- and indexcolors

local pdf_separation  = pdfconstant("Separation")
local pdf_indexed     = pdfconstant("Indexed")
local pdf_device_n    = pdfconstant("DeviceN")
local pdf_device_rgb  = pdfconstant("DeviceRGB")
local pdf_device_cmyk = pdfconstant("DeviceCMYK")
local pdf_device_gray = pdfconstant("DeviceGray")
local pdf_extgstate   = pdfconstant("ExtGState")

local pdf_rbg_range  = pdfarray { 0, 1, 0, 1, 0, 1 }
local pdf_cmyk_range = pdfarray { 0, 1, 0, 1, 0, 1, 0, 1 }
local pdf_gray_range = pdfarray { 0, 1 }

local rgb_function  = "dup %s mul exch dup %s mul exch %s mul"
local cmyk_function = "dup %s mul exch dup %s mul exch dup %s mul exch %s mul"
local gray_function = "%s mul"

local documentcolorspaces = pdfdictionary()

local spotcolorhash      = { } -- not needed
local spotcolornames      = { }
local indexcolorhash      = { }
local delayedindexcolors  = { }

function registrations.spotcolorname(name,e)
    spotcolornames[name] = e or name
end

function registrations.getspotcolorreference(name)
    return spotcolorhash[name]
end

-- beware: xpdf/okular/evince cannot handle the spot->process shade

-- This should become delayed i.e. only flush when used; in that case we need
-- need to store the specification and then flush them when accesssomespotcolor
-- is called. At this moment we assume that splotcolors that get defined are
-- also used which keeps the overhad small anyway.

local processcolors

local function registersomespotcolor(name,noffractions,names,p,colorspace,range,funct)
    noffractions = tonumber(noffractions) or 1 -- to be checked
    if noffractions == 0 then
        -- can't happen
    elseif noffractions == 1 then
        local dictionary = pdfdictionary {
            FunctionType = 4,
            Domain       = { 0, 1 },
            Range        = range,
        }
        local calculations = pdfflushstreamobject(format("{ %s }",funct),dictionary)
      -- local calculations = pdfobject {
      --     type      = "stream",
      --     immediate = true,
      --     string    = format("{ %s }",funct),
      --     attr      = dictionary(),
      -- }
        local array = pdfarray {
            pdf_separation,
            pdfconstant(spotcolornames[name] or name),
            colorspace,
            pdfreference(calculations),
        }
        local m = pdfflushobject(array)
        local mr = pdfreference(m)
        spotcolorhash[name] = m
        documentcolorspaces[name] = mr
        lpdf.adddocumentcolorspace(name,mr)
    else
        local cnames = pdfarray()
        local domain = pdfarray()
        local colorants = pdfdictionary()
        for n in gmatch(names,"[^,]+") do
            local name = spotcolornames[n] or n
            if n == "cyan" then
                name = "Cyan"
            elseif n == "magenta" then
                name = "Magenta"
            elseif n == "yellow" then
                name = "Yellow"
            elseif n == "black" then
                name = "Black"
            else
                colorants[name]   = pdfreference(spotcolorhash[name] or spotcolorhash[n])
            end
            cnames[#cnames+1] = pdfconstant(name)
            domain[#domain+1] = 0
            domain[#domain+1] = 1
        end
        if not processcolors then
            local specification = pdfdictionary {
                ColorSpace = pdfconstant("DeviceCMYK"),
                Components = pdfarray {
                    pdfconstant("Cyan"),
                    pdfconstant("Magenta"),
                    pdfconstant("Yellow"),
                    pdfconstant("Black")
                }
            }
            processcolors = pdfreference(pdfflushobject(specification))
        end
        local dictionary = pdfdictionary {
            FunctionType = 4,
            Domain       = domain,
            Range        = range,
        }
        local calculation = pdfflushstreamobject(format("{ %s %s }",rep("pop ",noffractions),funct),dictionary)
        local channels = pdfdictionary {
            Subtype   = pdfconstant("NChannel"),
            Colorants = colorants,
            Process   = processcolors,
        }
        local array = pdfarray {
            pdf_device_n,
            cnames,
            colorspace,
            pdfreference(calculation),
            lpdf.shareobjectreference(tostring(channels)), -- optional but needed for shades
        }
        local m = pdfflushobject(array)
        local mr = pdfreference(m)
        spotcolorhash[name] = m
        documentcolorspaces[name] = mr
        lpdf.adddocumentcolorspace(name,mr)
    end
end

-- wrong name

local function registersomeindexcolor(name,noffractions,names,p,colorspace,range,funct)
    noffractions = tonumber(noffractions) or 1 -- to be checked
    local cnames = pdfarray()
    local domain = pdfarray()
    if names == "" then
        names = name .. ",None"
    else
        names = names .. ",None"
    end
    for n in gmatch(names,"[^,]+") do
        cnames[#cnames+1] = pdfconstant(spotcolornames[n] or n)
        domain[#domain+1] = 0
        domain[#domain+1] = 1
    end
    local dictionary = pdfdictionary {
        FunctionType = 4,
        Domain       = domain,
        Range        = range,
    }
    local n = pdfflushstreamobject(format("{ %s %s }",rep("exch pop ",noffractions),funct),dictionary) -- exch pop
    local a = pdfarray {
        pdf_device_n,
        cnames,
        colorspace,
        pdfreference(n),
    }
    if p == "" then
        p = "1"
    else
        p = p .. ",1"
    end
    local pi = { }
    for pp in gmatch(p,"[^,]+") do
        pi[#pi+1] = tonumber(pp)
    end
    local vector, set, n = { }, { }, #pi
    for i=255,0,-1 do
        for j=1,n do
            set[j] = format("%02X",round(pi[j]*i))
        end
        vector[#vector+1] = concat(set)
    end
    vector = pdfverbose { "<", concat(vector, " "), ">" }
    local n = pdfflushobject(pdfarray{ pdf_indexed, a, 255, vector })
    lpdf.adddocumentcolorspace(format("%s_indexed",name),pdfreference(n))
    return n
end

-- actually, names (parent) is the hash

local function delayindexcolor(name,names,func)
    local hash = (names ~= "" and names) or name
    delayedindexcolors[hash] = func
end

local function indexcolorref(name) -- actually, names (parent) is the hash
    if not indexcolorhash[name] then
        local delayedindexcolor = delayedindexcolors[name]
        if type(delayedindexcolor) == "function" then
            indexcolorhash[name] = delayedindexcolor()
            delayedindexcolors[name] = true
        end
    end
    return indexcolorhash[name]
end

function registrations.rgbspotcolor(name,noffractions,names,p,r,g,b)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rbg_range,format(rgb_function,r,g,b))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rbg_range,format("%s %s %s",r,g,b))
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,format(rgb_function,r,g,b))
    end)
end

function registrations.cmykspotcolor(name,noffractions,names,p,c,m,y,k)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,format(cmyk_function,c,m,y,k))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,format("%s %s %s %s",c,m,y,k))
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,format(cmyk_function,c,m,y,k))
    end)
end

function registrations.grayspotcolor(name,noffractions,names,p,s)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,format(gray_function,s))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,s)
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,format(gray_function,s))
    end)
end

function registrations.rgbindexcolor(name,noffractions,names,p,r,g,b)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,format(rgb_function,r,g,b))
end

function registrations.cmykindexcolor(name,noffractions,names,p,c,m,y,k)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,format(cmyk_function,c,m,y,k))
end

function registrations.grayindexcolor(name,noffractions,names,p,s)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,gray_function)
end

function codeinjections.setfigurecolorspace(data,figure)
    local color = data.request.color
    if color then
        local ref = indexcolorref(color)
        if ref then
            figure.colorspace = ref
            data.used.color = color
        end
    end
end

-- transparency

local transparencies = { [0] =
    pdfconstant("Normal"),
    pdfconstant("Normal"),
    pdfconstant("Multiply"),
    pdfconstant("Screen"),
    pdfconstant("Overlay"),
    pdfconstant("SoftLight"),
    pdfconstant("HardLight"),
    pdfconstant("ColorDodge"),
    pdfconstant("ColorBurn"),
    pdfconstant("Darken"),
    pdfconstant("Lighten"),
    pdfconstant("Difference"),
    pdfconstant("Exclusion"),
    pdfconstant("Compatible"),
}

local documenttransparencies = { }
local transparencyhash       = { } -- share objects

local done = false

function registrations.transparency(n,a,t)
    if not done then
        local d = pdfdictionary {
              Type = pdf_extgstate,
              ca   = 1,
              CA   = 1,
              BM   = transparencies[1],
              AIS  = false,
            }
        local m = pdfflushobject(d)
        local mr = pdfreference(m)
        transparencyhash[0] = m
        documenttransparencies[0] = mr
        lpdf.adddocumentextgstate("Tr0",mr)
        done = true
    end
    if n > 0 and not transparencyhash[n] then
        local d = pdfdictionary {
              Type = pdf_extgstate,
              ca   = tonumber(t),
              CA   = tonumber(t),
              BM   = transparencies[tonumber(a)] or transparencies[0],
              AIS  = false,
            }
        local m = pdfflushobject(d)
        local mr = pdfreference(m)
        transparencyhash[n] = m
        documenttransparencies[n] = mr
        lpdf.adddocumentextgstate(format("Tr%s",n),mr)
    end
end

-- Literals needed to inject code in the mp stream, we cannot use attributes there
-- since literals may have qQ's, much may go away once we have mplib code in place.
--
-- This module assumes that some functions are defined in the colors namespace
-- which most likely will be loaded later.

local function lpdfcolor(model,ca,default) -- todo: use gray when no color
    if colors.supported then
        local cv = colorsvalue(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            model = forcedmodel(model)
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
    else
        return ""
    end
end

lpdf.color = lpdfcolor

function lpdf.colorspec(model,ca,default)
    if ca and ca > 0 then
        local cv = colors.value(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            if model == 2 then
                return pdfarray { cv[2] }
            elseif model == 3 then
                return pdfarray { cv[3],cv[4],cv[5] }
            elseif model == 4 then
                return pdfarray { cv[6],cv[7],cv[8],cv[9] }
            elseif model == 5 then
                return pdfarray { cv[13] }
            end
        end
    end
    if default then
        return default
    end
end

function lpdf.pdfcolor(attribute) -- bonus, for pgf and friends
    context(lpdfcolor(1,attribute))
end

function lpdf.transparency(ct,default) -- kind of overlaps with transparencycode
    -- beware, we need this hack because normally transparencies are not
    -- yet registered and therefore the number is not not known ... we
    -- might use the attribute number itself in the future
    if transparencies.supported then
        local ct = transparenciesvalue(ct)
        if ct then
            return format("/Tr%s gs",registertransparancy(nil,ct[1],ct[2],true))
        else
            return "/Tr0 gs"
        end
    else
        return ""
    end
end

function lpdf.colorvalue(model,ca,default)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
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

--~ function lpdf.fdfcolor(model,ca,default)
--~     local cv = colorsvalue(ca)
--~     if cv then
--~         if model == 1 then
--~             model = cv[1]
--~         end
--~         model = forcedmodel(model)
--~         if model == 2 then
--~             return format("[%s]",cv[2])
--~         elseif model == 3 then
--~             return format("[%s %s %s]",cv[3],cv[4],cv[5])
--~         elseif model == 4 then
--~             return format("[%s %s %s %s]",cv[6],cv[7],cv[8],cv[9])
--~         elseif model == 4 then
--~             return format("[%s]",cv[13])
--~         end
--~     else
--~         return format("[%s]",default or 0)
--~     end
--~ end

function lpdf.colorvalues(model,ca,default)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
        if model == 2 then
            return cv[2]
        elseif model == 3 then
            return cv[3], cv[4], cv[5]
        elseif model == 4 then
            return cv[6], cv[7], cv[8], cv[9]
        elseif model == 4 then
            return cv[13]
        end
    else
        return default or 0
    end
end

function lpdf.transparencyvalue(ta,default)
    local tv = transparenciesvalue(ta)
    if tv then
        return tv[2]
    else
        return default or 1
    end
end

function lpdf.colorspace(model,ca)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
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

-- by registering we getconversion for free (ok, at the cost of overhead)

local intransparency = false
local pdfcolor       = lpdf.color

function lpdf.rgbcode(model,r,g,b)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'rgb',r,g,b))
    else
        return ""
    end
end

function lpdf.cmykcode(model,c,m,y,k)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'cmyk',c,m,y,k))
    else
        return ""
    end
end

function lpdf.graycode(model,s)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'gray',s))
    else
        return ""
    end
end

function lpdf.spotcode(model,n,f,d,p)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'spot',n,f,d,p)) -- incorrect
    else
        return ""
    end
end

function lpdf.transparencycode(a,t)
    if transparencies.supported then
        intransparency = true
        return format("/Tr%s gs",registertransparancy(nil,a,t,true)) -- true forces resource
    else
        return ""
    end
end

function lpdf.finishtransparencycode()
    if transparencies.supported and intransparency then
        intransparency = false
        return "/Tr0 gs"  -- we happen to know this -)
    else
        return ""
    end
end

-- this will move to lpdf-spe.lua

backends.pdf.tables.vfspecials = { -- todo: distinguish between glyph and rule color

    red        = { "special", 'pdf: 1 0 0 rg 1 0 0 RG' },
    green      = { "special", 'pdf: 0 1 0 rg 0 1 0 RG' },
    blue       = { "special", 'pdf: 0 0 1 rg 0 0 1 RG' },
    black      = { "special", 'pdf: 0 g 0 G' },

    startslant = function(a) return { "special", format("pdf: q 1 0 %s 1 0 0 cm",a) } end,
    stopslant  = { "special", "pdf: Q" },

}
