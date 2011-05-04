if not modules then modules = { } end modules ['lpdf-ren'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- rendering

local tostring, tonumber, next = tostring, tonumber, next
local format = string.format
local settings_to_array = utilities.parsers.settings_to_array

local backends, lpdf = backends, lpdf

local nodeinjections   = backends.pdf.nodeinjections
local codeinjections   = backends.pdf.codeinjections
local registrations    = backends.pdf.registrations
local viewerlayers     = attributes.viewerlayers

local references       = structures.references

references.executers   = references.executers or { }
local executers        = references.executers

local variables        = interfaces.variables

local v_no             = variables.no
local v_yes            = variables.yes
local v_start          = variables.start
local v_stop           = variables.stop
local v_reset          = variables.reset
local v_auto           = variables.auto
local v_random         = variables.random

local pdfconstant      = lpdf.constant
local pdfdictionary    = lpdf.dictionary
local pdfarray         = lpdf.array
local pdfreference     = lpdf.reference
local pdfflushobject   = lpdf.flushobject
local pdfreserveobject = lpdf.reserveobject

local pdf_ocg          = pdfconstant("OCG")
local pdf_ocmd         = pdfconstant("OCMD")
local pdf_off          = pdfconstant("OFF")
local pdf_on           = pdfconstant("ON")
local pdf_toggle       = pdfconstant("Toggle")
local pdf_setocgstate  = pdfconstant("SetOCGState")

local lpdf_usage = pdfdictionary { Print = pdfdictionary { PrintState = pdf_off } }

-- We can have references to layers before they are places, for instance from
-- hide and vide actions. This is why we need to be able to force usage of layers
-- at several moments.

local pdfln, pdfld = { }, { }
local textlayers, hidelayers, videlayers = pdfarray(), pdfarray(), pdfarray()
local pagelayers, pagelayersreference, cache = nil, nil, { }

local specifications = { }
local initialized    = { }

function codeinjections.defineviewerlayer(specification)
    if viewerlayers.supported and textlayers then
        local tag = specification.tag
        if not specifications[tag] then
            specifications[tag] = specification
        end
    end
end

local function useviewerlayer(name)
    local specification = specifications[name]
    if not environment.initex and specification and not initialized[name] then
        specifications[name] = nil -- or not
        initialized   [name] = true
        if not pagelayers then
            pagelayers = pdfdictionary()
            pagelayersreference = pdfreserveobject()
        end
        local tag = specification.tag
        -- todo: reserve
        local nn = pdfreserveobject()
        local nr = pdfreference(nn)
        local nd = pdfdictionary {
            Type   = pdf_ocg,
            Name   = specification.title or "unknown",
            Intent = ((specification.editable  ~= v_no) and pdf_design) or nil,  -- disable layer hiding by user
            Usage  = ((specification.printable == v_no) and lpdf_usage) or nil, -- printable or not
        }
        cache[#cache+1] = { nn, nd }
        pdfln[tag] = nr -- was n
        local dn = pdfreserveobject()
        local dr = pdfreference(dn)
        local dd = pdfdictionary {
            Type = pdf_ocmd,
            OCGs = pdfarray { nr },
        }
        cache[#cache+1] = { dn, dd }
        pdfld[tag] = dr
        textlayers[#textlayers+1] = nr
        if specification.visible == v_start then
            videlayers[#videlayers+1] = nr
        else
            hidelayers[#hidelayers+1] = nr
        end
        pagelayers[tag] = dr -- check
    end
end

codeinjections.useviewerlayer = useviewerlayer

local function layerreference(name)
    local r = pdfln[name]
    if r then
        return r
    else
        useviewerlayer(name)
        return pdfln[name]
    end
end

lpdf.layerreference = layerreference -- also triggered when a hide or vide happens

local function flushtextlayers()
    if viewerlayers.supported then
        if pagelayers then
            pdfflushobject(pagelayersreference,pagelayers)
        end
        for i=1,#cache do
            local ci = cache[i]
            pdfflushobject(ci[1],ci[2])
        end
        if textlayers and #textlayers > 0 then -- we can group them if needed, like: layout
            local d = pdfdictionary {
                OCGs = textlayers,
                D    = pdfdictionary {
                    Name      = "Document",
                    Order     = (viewerlayers.hasorder and textlayers) or nil,
                    ON        = videlayers,
                    OFF       = hidelayers,
                    BaseState = pdf_on,
                },
            }
            lpdf.addtocatalog("OCProperties",d)
            textlayers = nil
        end
    end
end

local function flushpagelayers() -- we can share these
    if pagelayers then
        lpdf.addtopageresources("Properties",pdfreference(pagelayersreference)) -- we could cache this
    end
end

lpdf.registerpagefinalizer    (flushpagelayers,"layers")
lpdf.registerdocumentfinalizer(flushtextlayers,"layers")

local function setlayer(what,arguments)
    -- maybe just a gmatch of even better, earlier in lpeg
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    local state = pdfarray { what }
    for i=1,#arguments do
        local p = layerreference(arguments[i])
        if p then
            state[#state+1] = p
        end
    end
    return pdfdictionary {
        S     = pdf_setocgstate,
        State = state,
    }
end

function executers.hidelayer  (arguments) return setlayer(pdf_off,   arguments) end
function executers.videlayer  (arguments) return setlayer(pdf_on,    arguments) end
function executers.togglelayer(arguments) return setlayer(pdf_toggle,arguments) end

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
    if not n or n == "" then
        return -- let's forget about it
    elseif n == v_auto then
        if last >= #pagetransitions then
            last = 0
        end
        n = last + 1
    elseif n == v_stop then
        return
    elseif n == v_reset then
        last = 0
        return
    elseif n == v_random then
        n = math.random(1,#pagetransitions)
    else
        n = tonumber(n)
    end
    local t = n and pagetransitions[n] or pagetransitions[1]
    if not t then
        t = settings_to_array(n)
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
