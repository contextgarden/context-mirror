if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module implements a couple of cleanup methods. We need these
in order to meet the <l n='pdf'/> specification. Watch the double
parenthesis; they are needed because otherwise we would pass more
than one argument to <l n='tex'/>.</p>
--ldx]]--

local type, next = type, next
local char, byte, format, gsub = string.char, string.byte, string.format, string.gsub
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local texsprint, texwrite = tex.sprint, tex.write

ctxcatcodes = tex.ctxcatcodes

pdf = pdf or { } -- global

backends.pdf = pdf -- registered

function pdf.cleandestination(str)
    texsprint((gsub(str,"[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.cleandestination(str)
    texsprint((gsub(str,"[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.sanitizedstring(str)
    texsprint((gsub(str,"([\\/#<>%[%]%(%)])","\\%1")))
end

function pdf.hexify(str)
    texwrite("feff")
    for b in utfvalues(str) do
		if b < 0x10000 then
            texwrite(format("%04x",b))
        else
            texwrite(format("%04x%04x",b/1024+0xD800,b%1024+0xDC00))
        end
    end
end

function pdf.utf8to16(s,offset) -- derived from j. sauter's post on the list
    offset = (offset and 0x110000) or 0 -- so, only an offset when true
	texwrite(char(offset+254,offset+255))
	for c in utfvalues(s) do
		if c < 0x10000 then
			texwrite(char(offset+c/256,offset+c%256))
		else
			c = c - 0x10000
			local c1, c2 = c / 1024 + 0xD800, c % 1024 + 0xDC00
			texwrite(char(offset+c1/256,offset+c1%256,offset+c2/256,offset+c2%256))
		end
	end
end

pdf.nodeinjections = pdf.nodeinjections or { } -- we hash elsewhere
pdf.codeinjections = pdf.codeinjections or { } -- we hash elsewhere
pdf.registrations  = pdf.registrations  or { } -- we hash elsewhere

local pdfliteral, register = nodes.pdfliteral, nodes.register

local nodeinjections = pdf.nodeinjections
local codeinjections = pdf.codeinjections
local registrations  = pdf.registrations

function nodeinjections.rgbcolor(r,g,b)
    return register(pdfliteral(format("%s %s %s rg %s %s %s RG",r,g,b,r,g,b)))
end

function nodeinjections.cmykcolor(c,m,y,k)
    return register(pdfliteral(format("%s %s %s %s k %s %s %s %s K",c,m,y,k,c,m,y,k)))
end

function nodeinjections.graycolor(s)
    return register(pdfliteral(format("%s g %s G",s,s)))
end

function nodeinjections.spotcolor(n,f,d,p)
    if type(p) == "string" then
        p = p:gsub(","," ") -- brr misuse of spot
    end
    return register(pdfliteral(format("/%s cs /%s CS %s SCN %s scn",n,n,p,p)))
end

function nodeinjections.transparency(n)
    return register(pdfliteral(format("/Tr%s gs",n)))
end

function nodeinjections.overprint()
    return register(pdfliteral("/GSoverprint gs"))
end

function nodeinjections.knockout()
    return register(pdfliteral("/GSknockout gs"))
end

function nodeinjections.positive()
    return register(pdfliteral("/GSpositive gs"))
end

function nodeinjections.negative()
    return register(pdfliteral("/GSnegative gs"))
end

local effects = {
    normal = 0,
    inner  = 0,
    outer  = 1,
    both   = 2,
    hidden = 3,
}

function nodeinjections.effect(stretch,rulethickness,effect)
    -- always, no zero test (removed)
    rulethickness = number.dimenfactors["bp"]*rulethickness
    effect = effects[effect] or effects['normal']
    return register(pdfliteral(format("%s Tc %s w %s Tr",stretch,rulethickness,effect))) -- watch order
end

function nodeinjections.startlayer(name)
    return register(pdfliteral(format("/OC /%s BDC",name)))
end

function nodeinjections.stoplayer()
    return register(pdfliteral("EMC"))
end

function nodeinjections.switchlayer(name)
    return register(pdfliteral(format("EMC /OC /%s BDC",name)))
end

-- code

function codeinjections.insertmovie(spec) -- width, height, factor, repeat, controls, preview, label, foundname
    local width, height = spec.width, spec.height
    local options, actions = "", ""
    if spec["repeat"] then
        actions = actions .. "/Mode /Repeat "
    end
    if spec.controls then
        actions = actions .. "/ShowControls true "
    else
        actions = actions .. "/ShowControls false "
    end
    if spec.preview then
        options = options .. "/Poster true "
    end
    if actions ~= "" then
        actions= "/A <<" .. actions .. ">>"
    end
    return format( -- todo: doPDFannotation
        "\\doPDFannotation{%ssp}{%ssp}{/Subtype /Movie /Border [0 0 0] /T (movie %s) /Movie << /F (%s) /Aspect [%s %s] %s>> %s}",
        width, height, spec.label, spec.foundname, factor * width, factor * height, options, actions
    )
end

local s_template_g = "\\dodoPDFregistergrayspotcolor{%s}{%s}{%s}{%s}{%s}"             -- n f d p s (p can go away)
local s_template_r = "\\dodoPDFregisterrgbspotcolor {%s}{%s}{%s}{%s}{%s}{%s}{%s}"     -- n f d p r g b
local s_template_c = "\\dodoPDFregistercmykspotcolor{%s}{%s}{%s}{%s}{%s}{%s}{%s}{%s}" -- n f d p c m y k
local m_template_g = "\\doPDFregistergrayindexcolor{%s}{%s}{%s}{%s}{%s}"              -- n f d p s (p can go away)
local m_template_r = "\\doPDFregisterrgbindexcolor {%s}{%s}{%s}{%s}{%s}{%s}{%s}"      -- n f d p r g b
local m_template_c = "\\doPDFregistercmykindexcolor{%s}{%s}{%s}{%s}{%s}{%s}{%s}{%s}"  -- n f d p c m y k
local s_template_e = "\\doPDFregisterspotcolorname{%s}{%s}"                           -- name, e -- todo in new backend: gsub(e," ","#20")
local t_template   = "\\presetPDFtransparencybynumber{%s}{%s}{%s}"                    -- n, a, t

function registrations.grayspotcolor (n,f,d,p,s)       states.collect(format(s_template_g,n,f,d,p,s))       end
function registrations.rgbspotcolor  (n,f,d,p,r,g,b)   states.collect(format(s_template_r,n,f,d,p,r,g,b))   end
function registrations.cmykspotcolor (n,f,d,p,c,m,y,k) states.collect(format(s_template_c,n,f,d,p,c,m,y,k)) end
function registrations.grayindexcolor(n,f,d,p,s)       states.collect(format(m_template_g,n,f,d,p,s))       end
function registrations.rgbindexcolor (n,f,d,p,r,g,b)   states.collect(format(m_template_r,n,f,d,p,r,g,b))   end
function registrations.cmykindexcolor(n,f,d,p,c,m,y,k) states.collect(format(m_template_c,n,f,d,p,c,m,y,k)) end
function registrations.spotcolorname (name,e)          states.collect(format(s_template_e,name,e))          end -- texsprint(ctxcatcodes,format(s_template_e,name,e))
function registrations.transparency  (n,a,t)           states.collect(format(t_template  ,n,a,t))           end -- too many, but experimental anyway

-- eventually we need to load this runtime
--
-- backends.install((environment and environment.arguments and environment.arguments.backend) or "pdf")
--
-- but now we need to force this as we also load the pdf tex part which hooks into all kind of places

backends.install("pdf")
