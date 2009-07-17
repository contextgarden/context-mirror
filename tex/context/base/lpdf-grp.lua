if not modules then modules = { } end modules ['lpdf-grp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local pdfdictionary = lpdf.dictionary
local pdfarray      = lpdf.array
local pdfconstant   = lpdf.constant
local pdfreference  = lpdf.reference

local pdfreserveobj   = pdf.reserveobj
local pdfimmediateobj = pdf.immediateobj

local function shade(stype,name,domain,color_a,color_b,n,colorspace,coordinates)
    local f = pdfdictionary {
        FunctionType = 2,
        Domain       = pdfarray(domain), -- domain is actually a string
        C0           = pdfarray(color_a),
        C1           = pdfarray(color_b),
        N            = tonumber(n),
    }
    local s = pdfdictionary {
        ShadingType = stype,
        ColorSpace  = pdfconstant(colorspace),
        Function    = pdfreference(pdfimmediateobj(tostring(f))),
        Coords      = pdfarray(coordinates),
        Extend      = pdfarray { true, true },
    }
    lpdf.adddocumentshade(name,pdfreference(pdfimmediateobj(tostring(s))))
end

function lpdf.circularshade(name,domain,color_a,color_b,n,colorspace,coordinates)
    shade(3,name,domain,color_a,color_b,n,colorspace,coordinates)
end

function lpdf.linearshade(name,domain,color_a,color_b,n,colorspace,coordinates)
    shade(2,name,domain,color_a,color_b,n,colorspace,coordinates)
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
