if not modules then modules = { } end modules ['lpdf-pdx'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Peter Rold and Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local codeinjections = backends.codeinjections -- normally it is registered
local variables      = interfaces.variables

local pdfdictionary  = lpdf.dictionary
local pdfarray       = lpdf.array
local pdfconstant    = lpdf.constant
local pdfreference   = lpdf.reference
local pdfflushobject = lpdf.flushobject
local pdfstring      = lpdf.string
local pdfverbose     = lpdf.verbose

local lower, gmatch = string.lower, string.gmatch

local channels = {
    gray = 1,
    grey = 1,
    rgb  = 3,
    cmyk = 4,
}

local prefixes = {
    gray = "DefaultGray",
    grey = "DefaultGray",
    rgb  = "DefaultRGB",
    cmyk = "DefaultCMYK",
}

local profiles    = { }
local defaults    = { }
local intents     = pdfarray()
local lastprofile = nil

function codeinjections.useinternalICCprofile(colorspace,filename)
    local name = lower(file.basename(filename))
    local profile = profiles[name]
    if not profile then
        local colorspace = lower(colorspace)
        local filename = resolvers.findctxfile(filename) or ""
        local channel = channels[colorspace]
        if channel and filename ~= "" then
            local a = pdfdictionary { N = channel }
            profile = pdf.obj {
                compresslevel = 0,
                immediate     = true,
                type          = "stream",
                file          = filename,
                attr          = a(),
            }
            profiles[name] = profile
        end
    end
    lastprofile = profile
    return profile
end

function codeinjections.useexternalICCprofile(colorspace,name,urls,checksum,version)
    local profile = profiles[name]
    if not profile then
        local u = pdfarray()
        for url in gmatch(urls,"([^, ]+)") do
            u[#u+1] = pdfdictionary {
                FS = pdfconstant("URL"),
                F  = pdfstring(url),
            }
        end
        local d = pdfdictionary {
            ProfileName = name,                              -- not file name!
            ProfileCS   = colorspace,
            URLs        = u,                                 -- array containing at least one URL
            CheckSum    = pdfverbose { "<", checksum, ">" }, -- 16byte MD5 hash
            ICCVersion  = pdfverbose { "<", version, ">"  }, -- bytes 8..11 from the header of the ICC profile, as a hex string
        }
        local n = pdfflushobject(d)
        profiles[name] = n
        lastprofile = n
        return n
    end
end

local function embedprofile(colorspace,filename)
    local colorspace = lower(colorspace)
    local n = codeinjections.useinternaliccprofile(colorspace,filename)
    if n then
        local a = pdfarray {
            pdfconstant("ICCBased"),
            pdfreference(n),
        }
        lpdf.adddocumentcolorspace(prefixes[colorspace],pdfreference(pdfflushobject(a))) -- part of page /Resources
        defaults[lower(colorspace)] = filename
    end
end


function codeinjections.useICCdefaultprofile(colorspace,filename)
    defaults[lower(colorspace)] = filename
end

local function flushembeddedprofiles()
    for colorspace, filename in next, defaults do
	embedprofile(colorspace,filename)
    end
end

function codeinjections.usePDFXoutputintent(id,name,reference,outputcondition,info)
    local d = {
          Type                      = pdfconstant("OutputIntent"),
          S                         = pdfconstant("GTS_PDFX"),
          OutputConditionIdentifier = id,
          RegistryName              = name,
          OutputCondition           = outputcondition,
          Info                      = info,
    }
    local icc = lastprofile
    if reference == variables.yes then
        d["DestOutputProfileRef"] = pdfreference(icc)
    else
        d["DestOutputProfile"] = pdfreference(icc)
    end
 -- intents[#intents+1] = pdfdictionary(d)
    intents[#intents+1] = pdfreference(pdfflushobject(pdfdictionary(d))) -- nicer as separate object
end

local function flushoutputintents()
    if #intents > 0 then
        lpdf.addtocatalog("OutputIntents",pdfreference(pdfflushobject(intents)))
    end
end


lpdf.registerdocumentfinalizer(flushoutputintents,1)
lpdf.registerdocumentfinalizer(flushembeddedprofiles,1)
