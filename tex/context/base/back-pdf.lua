if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we will move code to lpdf-* files (second cleanup stage in 2011/2012)

-- the push/pop is a mess (only needed for calculate ...) .. will be done differently

--[[ldx--
<p>This module implements a couple of cleanup methods. We need these
in order to meet the <l n='pdf'/> specification. Watch the double
parenthesis; they are needed because otherwise we would pass more
than one argument to <l n='tex'/>.</p>
--ldx]]--

local type, next, tostring = type, next, tostring
local char, byte, format, gsub, rep, gmatch = string.char, string.byte, string.format, string.gsub, string.rep, string.gmatch
local concat = table.concat
local round = math.round
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues

local backends, lpdf, nodes, node = backends, lpdf, nodes, node

local copy_node           = node.copy

local nodeinjections      = backends.pdf.nodeinjections
local codeinjections      = backends.pdf.codeinjections
local registrations       = backends.pdf.registrations

local nodepool            = nodes.pool

local register            = nodepool.register

local pdfconstant         = lpdf.constant
local pdfstring           = lpdf.string
local pdfdictionary       = lpdf.dictionary
local pdfarray            = lpdf.array
local pdfreference        = lpdf.reference
local pdfverbose          = lpdf.verbose
local pdfflushobject      = lpdf.flushobject
local pdfimmediateobject  = lpdf.immediateobject

local pdfliteral          = nodepool.pdfliteral
local pdfannotation_node  = nodepool.pdfannotation

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

local effects = {
    normal = 0,
    inner  = 0,
    outer  = 1,
    both   = 2,
    hidden = 3,
}

function nodeinjections.effect(effect,stretch,rulethickness)
    -- always, no zero test (removed)
    rulethickness = number.dimenfactors["bp"] * rulethickness
    effect = effects[effect] or effects['normal']
    return register(pdfliteral(format("%s Tc %s w %s Tr",stretch,rulethickness,effect))) -- watch order
end

-- cached ..

local cache = { }

function codeinjections.startlayer(name)
    codeinjections.useviewerlayer(name)
    return format("/OC /%s BDC",name)
end

function codeinjections.stoplayer(name)
    return "EMC"
end

function nodeinjections.startlayer(name)
    local c = cache[name]
    if not c then
        codeinjections.useviewerlayer(name)
        c = register(pdfliteral(format("/OC /%s BDC",name)))
        cache[name] = c
    end
    return copy_node(c)
end

local stop = register(pdfliteral("EMC"))

function nodeinjections.stoplayer()
    return copy_node(stop)
end

local cache = { }

function nodeinjections.switchlayer(name) -- not used, optimization
    local c = cache[name]
    if not c then
        codeinjections.useviewerlayer(name)
        c = register(pdfliteral(format("EMC /OC /%s BDC",name)))
    end
    return copy_node(c)
end

-- code, will move to lpdf-*

function nodeinjections.insertmovie(specification)
    -- managed in figure inclusion: width, height, factor, repeat, controls, preview, label, foundname
    local width  = specification.width
    local height = specification.height
    local factor = specification.factor or number.dimenfactors.bp
    local moviedict = pdfdictionary {
        F      = specification.foundname,
        Aspect = pdfarray { factor * width, factor * height },
        Poster = (specification.preview and true) or false,
    }
    local controldict = pdfdictionary {
        ShowControls = (specification.controls and true) or false,
        Mode         = (specification["repeat"] and pdfconstant("Repeat")) or nil,
    }
    local action = pdfdictionary {
        Subtype = pdfconstant("Movie"),
        Border  = pdfarray { 0, 0, 0 },
        T       = format("movie %s",specification.label),
        Movie   = moviedict,
        A       = controldict,
    }
    node.write(pdfannotation_node(width,height,0,action()))
end

function nodeinjections.insertsound(specification)
    -- rmanaged in interaction: repeat, label, foundname
    local soundclip = interactions.soundclips.soundclip(specification.label)
    if soundclip then
        local controldict = pdfdictionary {
            Mode = (specification["repeat"] and pdfconstant("Repeat")) or nil
        }
        local sounddict = pdfdictionary {
            F = soundclip.filename
        }
        local action = pdfdictionary {
            Subtype = pdfconstant("Movie"),
            Border  = pdfarray { 0, 0, 0 },
            T       = format("sound %s",specification.label),
            Movie   = sounddict,
            A       = controldict,
        }
        node.write(pdfannotation_node(0,0,0,action()))
    end
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
        local calculations = pdfimmediateobject("stream",format("{ %s }",funct),dictionary()) -- todo: lpdf.stream
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
        local m = pdfimmediateobject(tostring(array))
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
            processcolors = pdfreference(pdfimmediateobject(tostring(specification)))
        end
        local dictionary = pdfdictionary {
            FunctionType = 4,
            Domain       = domain,
            Range        = range,
        }
        local calculation = pdfimmediateobject("stream",format("{ %s %s }",rep("pop ",noffractions),funct),dictionary())
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
        local m = pdfimmediateobject(tostring(array))
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
    local n = pdfimmediateobject("stream",format("{ %s %s }",rep("exch pop ",noffractions),funct),dictionary()) -- exch pop
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
    local n = pdfimmediateobject(tostring(pdfarray{ pdf_indexed, a, 255, vector }))
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
--~ print(name,noffractions,names,p,r,g,b)
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
        local m = pdfimmediateobject(tostring(d))
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
        local m = pdfimmediateobject(tostring(d))
        local mr = pdfreference(m)
        transparencyhash[n] = m
        documenttransparencies[n] = mr
        lpdf.adddocumentextgstate(format("Tr%s",n),mr)
    end
end

-- overloaded in lpdf-xmp:

function codeinjections.adddocumentinfo(key,value)
    lpdf.addtoinfo(key,lpdf.tosixteen(value))
end

-- graphics

function codeinjections.setfigurealternative(data,figure)
    local request = data.request
    local display = request.display
    if display and display ~= ""  then
        local nested = figures.push {
            name   = display,
            page   = request.page,
            size   = request.size,
            prefix = request.prefix,
            cache  = request.cache,
            width  = request.width,
            height = request.height,
        }
        figures.identify()
        local displayfigure = figures.check()
        if displayfigure then
        --  figure.aform = true
            img.immediatewrite(figure)
            local a = pdfarray {
                pdfdictionary {
                    Image              = pdfreference(figure.objnum),
                    DefaultForPrinting = true,
                }
            }
            local d = pdfdictionary {
                Alternates = pdfreference(pdfimmediateobject(tostring(a))),
            }
            displayfigure.attr = d()
            figures.pop()
            return displayfigure, nested
        else
            figures.pop()
        end
    end
end

function codeinjections.getpreviewfigure(request)
    local figure = figures.initialize(request)
    if not figure then
        return
    end
    figure = figures.identify(figure)
    if not figure then
        return
    end
    figure = figures.check(figure)
    if not figure then
        return
    end
    local image = figure.status.private
    if image then
        img.immediatewrite(image)
    end
    return figure
end

function codeinjections.setfiguremask(data,figure) -- mark
    local request = data.request
    local mask = request.mask
    if mask and mask ~= ""  then
        figures.push {
            name   = mask,
            page   = request.page,
            size   = request.size,
            prefix = request.prefix,
            cache  = request.cache,
            width  = request.width,
            height = request.height,
        }
        figures.identify()
        local maskfigure = figures.check()
        if maskfigure then
            local image = maskfigure.status.private
            if image then
                img.immediatewrite(image)
                local d = pdfdictionary {
                    Interpolate  = false,
                    SMask        = pdfreference(image.objnum),
                }
                figure.attr = d()
            end
        end
        figures.pop()
    end
end

local outputfilename

function codeinjections.getoutputfilename()
    if not outputfilename then
        outputfilename = file.addsuffix(tex.jobname,"pdf")
    end
    return outputfilename
end

-- temp hack

local factor = number.dimenfactors.bp

function img.package(image)
    local boundingbox = image.bbox
    local imagetag    = "Im" .. image.index
    local resources   = pdfdictionary {
        ProcSet = pdfarray {
            pdfconstant("PDF"),
            pdfconstant("ImageC")
        },
        Resources = pdfdictionary {
            XObject = pdfdictionary {
                [imagetag] = pdfreference(image.objnum)
            }
        }
    }
    local width = boundingbox[3]
    local height = boundingbox[4]
    local xform = img.scan {
        attr   = resources(),
        stream = format("%s 0 0 %s 0 0 cm /%s Do",width,height,imagetag),
        bbox   = { 0, 0, width/factor, height/factor },
    }
    img.immediatewrite(xform)
    return xform
end

-- till here

backends.install("pdf")
