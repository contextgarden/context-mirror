if not modules then modules = { } end modules ['lpdf-mis'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local format, gsub = string.format, string.gsub

local backends, lpdf = backends, lpdf

local colors               = attributes.colors
local transparencies       = attributes.transparencies
local registertransparancy = transparencies.register
local registercolor        = colors.register
local colorsvalue          = colors.value
local transparenciesvalue  = transparencies.value
local forcedmodel          = colors.forcedmodel

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
