if not modules then modules = { } end modules ['lpdf-grp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local backends, lpdf = backends, lpdf

local nodeinjections = backends.pdf.nodeinjections

local colors         = attributes.colors
local basepoints     = number.dimenfactors["bp"]
local inches         = number.dimenfactors["in"]

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local pdfdictionary  = lpdf.dictionary
local pdfarray       = lpdf.array
local pdfconstant    = lpdf.constant
local pdfboolean     = lpdf.boolean
local pdfreference   = lpdf.reference
local pdfflushobject = lpdf.flushobject

-- can also be done indirectly:
--
-- 12 : << /AntiAlias false /ColorSpace  8 0 R /Coords [ 0.0 0.0 1.0 0.0 ] /Domain [ 0.0 1.0 ] /Extend [ true true ] /Function 22 0 R /ShadingType 2 >>
-- 22 : << /Bounds [ ] /Domain [ 0.0 1.0 ] /Encode [ 0.0 1.0 ] /FunctionType 3 /Functions [ 31 0 R ] >>
-- 31 : << /C0 [ 1.0 0.0 ] /C1 [ 0.0 1.0 ] /Domain [ 0.0 1.0 ] /FunctionType 2 /N 1.0 >>

local function shade(stype,name,domain,color_a,color_b,n,colorspace,coordinates,separation)
    local f = pdfdictionary {
        FunctionType = 2,
        Domain       = pdfarray(domain), -- domain is actually a string
        C0           = pdfarray(color_a),
        C1           = pdfarray(color_b),
        N            = tonumber(n),
    }
    separation = separation and registrations.getspotcolorreference(separation)
    local s = pdfdictionary {
        ShadingType = stype,
        ColorSpace  = separation and pdfreference(separation) or pdfconstant(colorspace),
        Function    = pdfreference(pdfflushobject(f)),
        Coords      = pdfarray(coordinates),
        Extend      = pdfarray { true, true },
        AntiAlias   = pdfboolean(true),
    }
    lpdf.adddocumentshade(name,pdfreference(pdfflushobject(s)))
end

function lpdf.circularshade(name,domain,color_a,color_b,n,colorspace,coordinates,separation)
    shade(3,name,domain,color_a,color_b,n,colorspace,coordinates,separation)
end

function lpdf.linearshade(name,domain,color_a,color_b,n,colorspace,coordinates,separation)
    shade(2,name,domain,color_a,color_b,n,colorspace,coordinates,separation)
end

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

-- inline bitmaps but xform'd
--
-- we could derive the colorspace if we strip the data
-- and divide by x*y

local template = "q BI %s ID %s > EI Q"
local factor   = 72/300

function nodeinjections.injectbitmap(t)
    -- encoding is ascii hex, no checking here
    local xresolution, yresolution = t.xresolution or 0, t.yresolution or 0
    if xresolution == 0 or yresolution == 0 then
        return -- fatal error
    end
    local colorspace = t.colorspace
    if colorspace ~= "rgb" and colorspace ~= "cmyk" and colorspace ~= "gray" then
        -- not that efficient but ok
        local d = string.gsub(t.data,"[^0-9a-f]","")
        local b = math.round(#d / (xresolution * yresolution))
        if b == 2 then
            colorspace = "gray"
        elseif b == 6 then
            colorspace = "rgb"
        elseif b == 8 then
            colorspace = "cmyk"
        end
    end
    if colorspace == "gray" then
        colorspace = pdfconstant("DeviceGray")
    elseif colorspace == "rgb" then
        colorspace = pdfconstant("DeviceRGB")
    elseif colorspace == "cmyk" then
        colorspace = pdfconstant("DeviceCMYK")
    else
        return -- fatal error
    end
    local d = pdfdictionary {
        W   = xresolution,
        H   = yresolution,
        CS  = colorspace,
        BPC = 8,
        F   = pdfconstant("AHx"),
    }
    -- for some reasons it only works well if we take a 1bp boundingbox
    local urx, ury = 1/basepoints, 1/basepoints
 -- urx = (xresolution/300)/basepoints
 -- ury = (yresolution/300)/basepoints
    local width, height = t.width or 0, t.height or 0
    if width == 0 and height == 0 then
        width  = factor * xresolution / basepoints
        height = factor * yresolution / basepoints
    elseif width == 0 then
        width  = height * xresolution / yresolution
    elseif height == 0 then
        height = width  * yresolution / xresolution
    end
    local image = img.new {
        stream = format(template,d(),t.data),
        width  = width,
        height = height,
        bbox   = { 0, 0, urx, ury },
    }
    return img.node(image)
end
