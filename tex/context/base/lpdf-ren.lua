if not modules then modules = { } end modules ['lpdf-ren'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- rendering

local tostring, tonumber, next = tostring, tonumber, next
local format = string.format
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

jobreferences          = jobreferences          or { }
--~ jobreferences.runners  = jobreferences.runners  or { }
--~ jobreferences.specials = jobreferences.specials or { }
--~ jobreferences.handlers = jobreferences.handlers or { }
jobreferences.executers = jobreferences.executers or { }

--~ local runners   = jobreferences.runners
--~ local specials  = jobreferences.specials
--~ local handlers  = jobreferences.handlers
local executers = jobreferences.executers

local variables = interfaces.variables

local pdfconstant   = lpdf.constant
local pdfdictionary = lpdf.dictionary
local pdfarray      = lpdf.array
local pdfreference  = lpdf.reference

local pdfreserveobj   = pdf.reserveobj
local pdfimmediateobj = pdf.immediateobj

local pdf_ocg         = pdfconstant("OCG")
local pdf_ocmd        = pdfconstant("OCMD")
local pdf_off         = pdfconstant("OFF")
local pdf_on          = pdfconstant("ON")
local pdf_toggle      = pdfconstant("Toggle")
local pdf_setocgstate = pdfconstant("SetOCGState")

local lpdf_usage = pdfdictionary { Print = pdfdictionary { PrintState = pdfconstant("OFF") } }

local pdfln, pdfld = { }, { }
local textlayers, hidelayers, videlayers = pdfarray(), pdfarray(), pdfarray()
local pagelayers = pdfdictionary()

lpdf.layerreferences = pdfln

function backends.pdf.layerreference(name)
    return pdfln[name]
end

function codeinjections.defineviewerlayer(specification)
    if textlayers then
        local tag = specification.tag
        -- todo: reserve
        local n = pdfdictionary {
            Type   = pdf_ocg,
            Name   = specification.title or "unknown",
            Intent = ((specification.kind > 0) and pdf_design) or nil, -- disable layer hiding by user
            Usage  = ((specification.printable == variables.no) and lpdf_usage) or nil , -- printable or not
        }
        local nr = pdfreference(pdfimmediateobj(tostring(n)))
        pdfln[tag] = nr -- was n
        local d = pdfdictionary {
            Type = pdf_ocmd,
            OCGs = pdfarray { nr },
        }
        local dr = pdfreference(pdfimmediateobj(tostring(d)))
        pdfld[tag] = dr
        textlayers[#textlayers+1] = nr
        if specification.visible == variables.start then
            videlayers[#videlayers+1] = nr
        else
            hidelayers[#hidelayers+1] = nr
        end
        pagelayers[tag] = dr -- check
    end
end

local function flushtextlayers()
    if textlayers and #textlayers > 0 then
        local d = pdfdictionary {
            OCGs = textlayers,
            D    = pdfdictionary {
                Order = textlayers,
                ON    = videlayers,
                OFF   = hidelayers,
            },
        }
        lpdf.addtocatalog("OCProperties",d)
        textlayers = nil
    end
end

local function flushpagelayers()
    if next(pagelayers) then
        lpdf.addtopageresources("Properties",pagelayers)
    end
end

lpdf.registerpagefinalizer    (flushpagelayers)
lpdf.registerdocumentfinalizer(flushtextlayers)

local function setlayer(what,arguments)
    -- maybe just a gmatch of even better, earlier in lpeg
    arguments = (type(arguments) == "table" and arguments) or aux.settings_to_array(arguments)
    local state = pdfarray { what }
    for i=1,#arguments do
        local p = pdfln[arguments[i]]
        if p then
            state[#state+1] = p
        end
    end
    return pdfdictionary {
        S     = pdf_setocgstate,
        State = state,
    }
end

function executers.hidelayer  (arguments) setlayer(pdf_off,   arguments) end
function executers.videlayer  (arguments) setlayer(pdf_on,    arguments) end
function executers.togglelayer(arguments) setlayer(pdf_toggle,arguments) end

-- transitions

local pagetransitions = {
    {"split","in","vertical"}, {"split","in","horizontal"},
    {"split","out","vertical"}, {"split","out","horizontal"},
    {"blinds","horizontal"}, {"blinds","vertical"},
    {"box","in"}, {"box","out"},
    {"wipe","east"}, {"wipe","west"}, {"wipe","north"}, {"wipe","south"},
    {"dissolve"},
    {"glitter","east"}, {"glitter","south"},
    {"fly","in","east"}, {"fly","in","west"}, {"fly","in","north"}, {"fly","in","south"},
    {"fly","out","east"}, {"fly","out","west"}, {"fly","out","north"}, {"fly","out","south"},
    {"push","east"}, {"push","west"}, {"push","north"}, {"push","south"},
    {"cover","east"}, {"cover","west"}, {"cover","north"}, {"cover","south"},
    {"uncover","east"}, {"uncover","west"}, {"uncover","north"}, {"uncover","south"},
    {"fade"},
}

local mapping = {
    split      = { "S"  , pdfconstant("Split") },
    blinds     = { "S"  , pdfconstant("Blinds") },
    box        = { "S"  , pdfconstant("Box") },
    wipe       = { "S"  , pdfconstant("Wipe") },
    dissolve   = { "S"  , pdfconstant("Dissolve") },
    glitter    = { "S"  , pdfconstant("Glitter") },
    replace    = { "S"  , pdfconstant("R") },
    fly        = { "S"  , pdfconstant("Fly") },
    push       = { "S"  , pdfconstant("Push") },
    cover      = { "S"  , pdfconstant("Cover") },
    uncover    = { "S"  , pdfconstant("Uncover") },
    fade       = { "S"  , pdfconstant("Fade") },
    horizontal = { "Dm" , pdfconstant("H") },
    vertical   = { "Dm" , pdfconstant("V") },
    ["in"]     = { "M"  , pdfconstant("I") },
    out        = { "M"  , pdfconstant("O") },
    east       = { "Di" ,   0 },
    north      = { "Di" ,  90 },
    west       = { "Di" , 180 },
    south      = { "Di" , 270 },
}

local last = 0

-- n: number, "stop", "reset", "random", "a,b,c" delay: number, "none"

function codeinjections.setpagetransition(specification)
    local n, delay = specification.n, specification.delay
    if n == variables.auto then
        if last >= #pagetransitions then
            last = 0
        end
        n = last + 1
    elseif n == variables.stop then
        return
    elseif n == variables.reset then
        last = 0
        return
    elseif n == variables.random then
        n = math.random(1,#pagetransitions)
    else
        n = tonumber(n)
    end
    local t = n and pagetransitions[n] or pagetransitions[1]
    if not t then
        t = aux.settings_to_array(n)
    end
    if t and #t > 0 then
        local d = pdfdictionary()
        for i=1,#t do
            local m = mapping[t[i]]
            d[m[1]] = m[2]
        end
        delay = tonumber(delay)
        if delay and delay > 0 then
            lpdf.addtopageattributes("Dur",delay)
        end
        lpdf.addtopageattributes("Trans",d)
    end
end
