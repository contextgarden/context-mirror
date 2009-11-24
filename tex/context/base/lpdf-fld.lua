if not modules then modules = { } end modules ['lpdf-fld'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- cleaned up, e.g. no longer older viewers
-- always kids so no longer explicit main / clone / copy
-- some optimizations removed (will come bakc if needed)

local gmatch, lower, format = string.gmatch, string.lower, string.format

local trace_fields = false  trackers.register("widgets.fields",   function(v) trace_fields   = v end)

local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

local variables = interfaces.variables

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local registeredsymbol = codeinjections.registeredsymbol

local pdfstream     = lpdf.stream
local pdfdictionary = lpdf.dictionary
local pdfarray      = lpdf.array
local pdfreference  = lpdf.reference
local pdfunicode    = lpdf.unicode
local pdfstring     = lpdf.string
local pdfconstant   = lpdf.constant
local pdftoeight    = lpdf.toeight

local pdfimmediateobj = pdf.immediateobj
local pdfreserveobj   = pdf.reserveobj

local submitoutputformat = 0 --  0=unknown 1=HTML 2=FDF 3=XML   => not yet used, needs to be checked

local splitter = lpeg.splitat("=>")

local formats = {
    html = 1, fdf = 2, xml = 3,
}

function codeinjections.setformsmethod(name)
    submitoutputformat = formats[lower(name)] or 3
end

local flag = {
    MultiLine       =     4096, --  13
    NoToggleToOff   =    16384, --  15
    Radio           =    32768, --  16
    PushButton      =    65536, --  17
    PopUp           =   131072, --  18
    Edit            =   262144, --  19
    RadiosInUnison  = 33554432, --  26
    DoNotSpellCheck =  4194304, --  23
    DoNotScroll     =  8388608, --  24
    ReadOnly        =        1, --   1
    Required        =        2, --   2
    NoExport        =        4, --   3
    Password        =     8192, --  14
    Sort            =   524288, --  20
    FileSelect      =  1048576, --  21
}

local plus = {
    Invisible       =        1, --   1
    Hidden          =        2, --   2
    Printable       =        4, --   3
    NoView          =       32, --   6
    ToggleNoView    =      256, --   9
    AutoView        =      256, -- 288 (6+9)
}

-- todo: check what is interfaced

flag.readonly    = flag.ReadOnly
flag.required    = flag.Required
flag.protected   = flag.Password
flag.sorted      = flag.Sort
flag.unavailable = flag.NoExport
flag.nocheck     = flag.DoNotSpellCheck
flag.fixed       = flag.DoNotScroll
flag.file        = flag.FileSelect

plus.hidden      = plus.Hidden
plus.printable   = plus.Printable
plus.auto        = plus.AutoView

-- some day .. lpeg with function or table

local function fieldflag(specification)
    local o, n = specification.options, 0
    if o and o ~= "" then
        for f in gmatch(o,"[^, ]+") do
            n = n + (flag[f] or 0)
        end
    end
    return n
end

local function fieldplus(specification)
    local o, n = specification.options, 0
    if o and o ~= "" then
        for p in gmatch(o,"[^, ]+") do
            n = n + (plus[p] or 0)
        end
    end
    return n
end


local function checked(what)
    if what and what ~= "" then
        local set, bug = jobreferences.identify("",what)
        return not bug and #set > 0 and lpdf.pdfaction(set)
    end
end

local function fieldactions(specification) -- share actions
--~ print(table.serialize(specification))
    local d, a = { }, nil
    a = specification.mousedown         if a and a ~= "" then d.D  = checked(a) end
    a = specification.mouseup           if a and a ~= "" then d.U  = checked(a) end
    a = specification.regionin          if a and a ~= "" then d.E  = checked(a) end -- Enter
    a = specification.regionout         if a and a ~= "" then d.X  = checked(a) end -- eXit
    a = specification.afterkeystroke    if a and a ~= "" then d.K  = checked(a) end
    a = specification.formatresult      if a and a ~= "" then d.F  = checked(a) end
    a = specification.validateresult    if a and a ~= "" then d.V  = checked(a) end
    a = specification.calculatewhatever if a and a ~= "" then d.C  = checked(a) end
    a = specification.focusin           if a and a ~= "" then d.Fo = checked(a) end
    a = specification.focusout          if a and a ~= "" then d.Bl = checked(a) end
 -- a = specification.openpage          if a and a ~= "" then d.PO = checked(a) end
 -- a = specification.closepage         if a and a ~= "" then d.PC = checked(a) end
 -- a = specification.visiblepage       if a and a ~= "" then d.PV = checked(a) end
 -- a = specification.invisiblepage     if a and a ~= "" then d.PI = checked(a) end
    return next(d) and pdfdictionary(d)
end

-- fonts and color

local fontnames = {
    rmtf = "Times-Roman",           rmbf = "Times-Bold",
    rmit = "Times-Italic",          rmsl = "Times-Italic",
    rmbi = "Times-BoldItalic",      rmbs = "Times-BoldItalic",
    sstf = "Helvetica",             ssbf = "Helvetica-Bold",
    ssit = "Helvetica-Oblique",     sssl = "Helvetica-Oblique",
    ssbi = "Helvetica-BoldOblique", ssbs = "Helvetica-BoldOblique",
    tttf = "Courier",               ttbf = "Courier-Bold",
    ttit = "Courier-Oblique",       ttsl = "Courier-Oblique",
    ttbi = "Courier-BoldOblique",   ttbs = "Courier-BoldOblique",
}

local usedfonts = { }

local function fieldsurrounding(specification)
    local tag = (specification.fontstyle or "tt") .. (specification.fontalternative or "tf")
    if not fontnames[tag] then
        tag = "tttf"
    end
    local size = specification.fontsize
    local stream = pdfstream {
        pdfconstant(tag),
        format("%s Tf",(size and (number.dimenfactors.bp * size)) or 12),
    }
    usedfonts[tag] = true
    -- add color to stream: 0 g
    -- move up with "x.y Ts"
    return tostring(stream)
end

local function registerfonts()
    if next(usedfonts) then
        local d = pdfdictionary()
        for tag, _ in next, usedfonts do
            local f = pdfdictionary {
                Type     = pdfconstant("Font"),
                Subtype  = pdfconstant("Type1"), -- todo
                Name     = pdfconstant(tag),
                BaseFont = pdfconstant(fontnames[tag]),
            }
            d[tag] = pdfreference(pdfimmediateobj(tostring(f)))
        end
        return d
    end
end

-- cache

local function fieldattributes(specification)
--~     return pdfarray {
--~     --    BG = -- backgroundcolor
--~     --    BC = -- framecolor
--~     }
    return nil
end

-- symbols

local function fieldappearances(specification)
    -- todo: caching
    local values = specification.values
    local default = specification.default
    if not values then
        -- error
        return
    end
    local v = aux.settings_to_array(values)
    local n, r, d
    if #v == 1 then
        n, r, d = v[1], v[1], v[1]
    elseif #v == 2 then
        n, r, d = v[1], v[1], v[2]
    else
        n, r, d = v[1], v[2], v[3]
    end
    local appearance = pdfdictionary { -- cache this one
        N = registeredsymbol(n), R = registeredsymbol(r), D = registeredsymbol(d),
    }
    return lpdf.sharedobj(tostring(appearance))
end

local function fieldstates(specification,forceyes,values,default)
    -- we don't use Opt here (too messy for radio buttons)
    local values, default = values or specification.values, default or specification.default
    if not values then
        -- error
        return
    end
    local v = aux.settings_to_array(values)
    local yes, off
    if #v == 1 then
        yes, off = v[1], v[1]
    else
        yes, off = v[1], v[2]
    end
    local yesshown, yesvalue = splitter:match(yes)
    if not (yesshown and yesvalue) then
        yesshown = yes, yes
    end
    yes = aux.settings_to_array(yesshown)
    local offshown, offvalue = splitter:match(off)
    if not (offshown and offvalue) then
        offshown = off, off
    end
    off = aux.settings_to_array(offshown)
    if #yes == 1 then
        yesn, yesr, yesd = yes[1], yes[1], yes[1]
    elseif #yes == 2 then
        yesn, yesr, yesd = yes[1], yes[1], yes[2]
    else
        yesn, yesr, yesd = yes[1], yes[2], yes[3]
    end
    if #off == 1 then
        offn, offr, offd = off[1], off[1], off[1]
    elseif #off == 2 then
        offn, offr, offd = off[1], off[1], off[2]
    else
        offn, offr, offd = off[1], off[2], off[3]
    end
    if not yesvalue then
        yesvalue = yesn
    end
    if not offvalue then
        offvalue = offn
    end
    if forceyes == true then
        forceyes = forceyes and "On" -- spec likes Yes more but we've used On for ages now
    else
        -- false or string
    end
    if default == yesn then
        default = pdfconstant(forceyes or yesn)
    else
        default = pdfconstant("Off")
    end
    local appearance = pdfdictionary { -- maybe also cache components
        N = pdfdictionary { [forceyes or yesn] = registeredsymbol(yesn), Off = registeredsymbol(offn) },
        R = pdfdictionary { [forceyes or yesr] = registeredsymbol(yesr), Off = registeredsymbol(offr) },
        D = pdfdictionary { [forceyes or yesd] = registeredsymbol(yesd), Off = registeredsymbol(offd) }
    }
    local appearanceref = lpdf.sharedobj(tostring(appearance))
    return appearanceref, default
end

local function fieldoptions(specification)
    local values = specification.values
    local default = specification.default
    if values then
        local v = aux.settings_to_array(values)
        for i=1,#v do
            local vi = v[i]
            local shown, value = splitter:match(vi)
            if shown and value then
                v[i] = pdfarray { pdfunicode(value), shown }
            else
                v[i] = pdfunicode(v[i])
            end
        end
        return pdfarray(v)
    end
end

local function radiodefault(parent,field,forceyes)
    local default, values = parent.default, parent.values
    if not default or default == "" then
        values = aux.settings_to_array(values)
        default = values[1]
    end
    local name = field.name
    local fieldvalues = aux.settings_to_array(field.values)
    local yes, off = fieldvalues[1], fieldvalues[2] or fieldvalues[1]
    if not default then
        return pdfconstant((forceyes and "On") or yes)
    elseif default == name then
        return pdfconstant((forceyes and "On") or default)
    else
        return pdfconstant("Off")
    end
end

-- layers

local function fieldlayer(specification) -- we can move this in line
    local layer = specification.layer
    return (layer and lpdf.layerreferences[layer]) or nil
end

-- defining

local fields, radios, clones, fieldsets, calculationset = { }, { }, { }, { }, nil

function codeinjections.definefieldset(tag,list)
    fieldsets[tag] = list
end

function codeinjections.getfieldset(tag)
    return fieldsets[tag]
end

local function fieldsetlist(tag)
    if tag then
        local ft = fieldsets[tag]
        if ft then
            local a = pdfarray()
            for name in gmatch(list,"[^, ]+") do
                local f = field[name]
                if f and f.pobj then
                    a[#a+1] = pdfreference(f.pobj)
                end
            end
            return a
        end
    end
end

function codeinjections.setfieldcalculationset(tag)
    calculationset = tag
end

local function predefinesymbols(specification)
    local values = specification.values
    if values then
        local a, b = splitter:match(values)
        codeinjections.presetsymbollist(a or values)
    end
end

function codeinjections.getdefaultfieldvalue(name)
    local f = fields[name]
    if f then
        local values  = f.values
        local default = f.default
        if not default or default == "" then
            local a, b = splitter:match(values)
            values = a or values
            for name in gmatch(list,"[^, ]+") do
                default = name
                break
            end
        end
        if default then
            tex.sprint(ctxcatcodes,default)
        end
    end
end

function codeinjections.definefield(specification)
    local n = specification.name
    local f = fields[n]
    if not f then
        local kind = specification.kind
        if not kind then
            if trace_fields then
                logs.report("fields","invalid definition of '%s': unknown type",n)
            end
        elseif kind == "radio" then
            local values = specification.values
            if values and values ~= "" then
                values = aux.settings_to_array(values)
                for v=1,#values do
                    radios[values[v]] = { parent = n }
                end
                fields[n] = specification
                if trace_fields then
                    logs.report("fields","defining '%s' as radio",n or "?")
                end
            elseif trace_fields then
                logs.report("fields","invalid definition of radio '%s': missing values",n)
            end
        elseif kind == "sub" then
            -- not in main field list !
            local radio = radios[n]
            if radio then
                -- merge specification
                for key, value in next, specification do
                    radio[key] = value
                end
                if trace_fields then
                    local p = radios[n] and radios[n].parent
                    logs.report("fields","defining '%s' as sub of radio '%s'",n or "?",p or "?")
                end
            elseif trace_fields then
                logs.report("fields","invalid definition of radio sub '%s': no parent",n)
            end
            predefinesymbols(specification)
        else
            fields[n] = specification
            if trace_fields then
                logs.report("fields","defining '%s' as %s",n,kind)
            end
            predefinesymbols(specification)
        end
    elseif trace_fields then
        logs.report("fields","invalid definition of '%s': already defined",n)
    end
end

function codeinjections.clonefield(specification)
    local p, c, v = specification.parent, specification.children, specification.variant
    if not p or not c then
        if trace_fields then
            logs.report("fields","invalid clone: children: '%s', parent '%s', variant: '%s'",p or "?",c or "?", v or "?")
        end
    else
        for n in gmatch(c,"[^, ]+") do
            local f, r, c, x = fields[n], radios[n], clones[n], fields[p]
            if f or r or c then
                if trace_fields then
                    logs.report("fields","already cloned: child: '%s', parent '%s', variant: '%s'",p or "?",n or "?", v or "?")
                end
            elseif x then
                if trace_fields then
                    logs.report("fields","invalid clone: child: '%s', variant: '%s', no parent",n or "?", v or "?")
                end
            else
                if trace_fields then
                    logs.report("fields","cloning: child: '%s', parent '%s', variant: '%s'",p or "?",n or "?", v or "?")
                end
                clones[n] = specification
                predefinesymbols(specification)
            end
        end
    end
end

function codeinjections.getfieldgroup(name)
    local f = fields[name] or radios[name] or clones[name]
    local g = f and f.group
    if not g or g == "" then
        local v, p, k = f.variant, f.parent, f.kind
        if v == "clone" or v == "copy" then
            f = fields[p] or radios[p]
            g = f and f.group
        elseif k == "sub" then
            f = fields[p]
            g = f and f.group
        end
    end
    if g then
        texsprint(ctxcatcodes,g)
    end
end

--

function codeinjections.doiffieldset(tag)
    commands.testcase(fieldsets[tag])
end

function codeinjections.doiffieldelse(name)
    commands.testcase(fields[name])
end

--

local alignments = {
    flushleft  = 0, right  = 0,
    center     = 1, middle = 1,
    flushright = 2, left   = 2,
}

local function fieldalignment(specification)
    return alignments[specification.align] or 0
end

local function enhance(specification,option)
    local so = specification.options
    if so and so ~= "" then
        specification.options = so .. "," .. option
    else
        specification.options = option
    end
    return specification
end

-- finish

local collected = pdfarray()

function codeinjections.finishfields()
    for name, field in next, fields do
        local kids = field.kids
        if kids then
            pdfimmediateobj(field.kobj,tostring(kids))
        end
        local pobj = field.pobj
    end
    for name, field in next, radios do
        local kids = field.kids
        if kids then
            pdfimmediateobj(field.kobj,tostring(kids))
        end
    end
    if #collected > 0 then
        local acroform = pdfdictionary {
            NeedAppearances = true,
            Fields = pdfreference(pdfimmediateobj(tostring(collected))),
            DR     = pdfdictionary { Font = registerfonts() },
            CO     = fieldsetlist(calculationset),
            DA     = "/tttf 12 Tf 0 g",
        }
        lpdf.addtocatalog("AcroForm",pdfreference(pdfimmediateobj(tostring(acroform))))
    end
    lpdf.finishfields = function() end
end

local pdf_widget = pdfconstant("Widget")
local pdf_tx     = pdfconstant("Tx")
local pdf_ch     = pdfconstant("Ch")
local pdf_btn    = pdfconstant("Btn")
local pdf_yes    = pdfconstant("Yes")
local pdf_p      = pdfconstant("P") -- None Invert Outline Push
local pdf_n      = pdfconstant("N") -- None Invert Outline Push
--
local pdf_no_rect = pdfarray { 0, 0, 0, 0 }

local methods = { }

function codeinjections.typesetfield(name,specification)
    local field = fields[name] or radios[name] or clones[name]
    if not field then
        logs.report("fields", "unknown child '%s'",name)
        -- unknown field
        return
    end
    local variant, parent = field.variant, field.parent
    if variant == "copy" or variant == "clone" then -- only in clones
        field = fields[parent] or radios[parent]
    end
    local method = methods[field.kind]
    if method then
        method(name,specification,variant)
    else
        logs.report("fields", "unknown method '%s' for child '%s'",field.kind,name)
    end
end

-- can be optional multipass optimization (share objects)

local function save_parent(field,specification,d)
    local kn = pdfreserveobj()
    d.Kids = pdfreference(kn)
    field.kobj = kn
    field.kids = pdfarray()
    local pn = pdfimmediateobj(tostring(d))
    field.pobj = pn
    collected[#collected+1] = pdfreference(pn)
end

local function save_kid(field,specification,d)
    local kn = pdfreserveobj()
    field.kids[#field.kids+1] = pdfreference(kn)
    node.write(nodes.pdfannot(specification.width,specification.height,0,d(),kn))
end

function methods.line(name,specification,variant,extras)
    local field = fields[name]
    if variant == "copy" or variant == "clone" then
        logs.report("fields","todo: clones of text fields")
    end
    local kind = field.kind
    if not field.pobj then
        if trace_fields then
            logs.report("fields","using parent text '%s'",name)
        end
        if extras then
            enhance(specification,extras)
        end
        local text = pdfunicode(specification.default)
        local d = pdfdictionary {
            Subtype  = pdf_widget,
            T        = pdfunicode(specification.title),
            F        = fieldplus(specification),
            Ff       = fieldflag(specification),
            OC       = fieldlayer(specification),
            MK       = fieldsurrounding(specification),
            AA       = fieldactions(specification),
            FT       = pdf_tx,
            Q        = fieldalignment(specification),
            MaxLen   = (specification.length == 0 and 1000) or specification.length,
            DV       = text,
            V        = text,
        }
        save_parent(field,specification,d)
        field.specification = specification
    end
    specification = field.specification or { } -- todo: radio spec
    if trace_fields then
        logs.report("fields","using child text '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        DA      = fieldattributes(specification),
        OC      = fieldlayer(specification),
        MK      = fieldsurrounding(specification),
        AA      = fieldactions(specification),
        Q       = fieldalignment(specification)
    }
    save_kid(field,specification,d)
end

function methods.text(name,specification,variant)
    methods.line(name,specification,variant,"MultiLine")
end

function methods.choice(name,specification,variant,extras)
    local field = fields[name]
    if variant == "copy" or variant == "clone" then
        logs.report("fields","todo: clones of choice fields")
    end
    local kind = field.kind
    local d
    if not field.pobj then
        if trace_fields then
            logs.report("fields","using parent choice '%s'",name)
        end
        if extras then
            enhance(specification,extras)
        end
        local d = pdfdictionary {
            Subtype  = pdf_widget,
            T        = pdfunicode(specification.title),
            F        = fieldplus(specification),
            Ff       = fieldflag(specification),
            OC       = fieldlayer(specification),
            AA       = fieldactions(specification),
            FT       = pdf_ch,
            Opt      = fieldoptions(field),
        }
        save_parent(field,specification,d)
        field.specification = specification
    end
    specification = field.specification or { }
    if trace_fields then
        logs.report("fields","using child choice '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        DA      = fieldattributes(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
    }
    save_kid(field,specification,d)
end

function methods.popup(name,specification,variant)
    methods.choice(name,specification,variant,"PopUp")
end
function methods.combo(name,specification,variant)
    methods.choice(name,specification,variant,"PopUp,Edit")
end

-- Probably no default appearance needed for first kid and no javascripts for the
-- parent ... I will look into it when I have to make a complex document.

function methods.check(name,specification,variant)
    -- no /Opt because (1) it's messy - see pdf spec, (2) it discouples kids and
    -- contrary to radio there is no way to associate then
    local field = fields[name]
    if variant == "copy" or variant == "clone" then
        logs.report("fields","todo: clones of check fields")
    end
    local kind = field.kind
    local appearance, default = fieldstates(field,true)
    if not field.pobj then
        if trace_fields then
            logs.report("fields","using parent check '%s'",name)
        end
        local d = pdfdictionary {
            Subtype  = pdf_widget,
            T        = pdfunicode(specification.title),
            F        = fieldplus(specification),
            Ff       = fieldflag(specification),
            OC       = fieldlayer(specification),
            AA       = fieldactions(specification),
            FT       = pdf_btn,
            DV       = default,
            V        = default,
            AS       = default,
            AP       = appearance,
            H        = pdf_n,
        }
        save_parent(field,specification,d)
        field.specification = specification
    end
    specification = field.specification or { } -- todo: radio spec
    if trace_fields then
        logs.report("fields","using child check '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        DA      = fieldattributes(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        DV      = default,
        V       = default,
        AS      = default,
        AP      = appearance,
        H       = pdf_n,
    }
    save_kid(field,specification,d)
end

function methods.push(name,specification,variant)
    local field = fields[name]
    if variant == "copy" or variant == "clone" then
        logs.report("fields","todo: clones of push fields")
    end
    local kind = field.kind
    if not field.pobj then
        if trace_fields then
            logs.report("fields","using parent push '%s'",name)
        end
        enhance(specification,"PushButton")
        local d = pdfdictionary {
            Subtype  = pdf_widget,
            T        = pdfunicode(specification.title),
            F        = fieldplus(specification),
            Ff       = fieldflag(specification),
            OC       = fieldlayer(specification),
            AA       = fieldactions(specification),
            FT       = pdf_btn,
            AP       = fieldappearances(field),
            H        = pdf_p,
        }
        save_parent(field,specification,d)
        field.specification = specification
    end
    specification = field.specification or { } -- todo: radio spec
    if trace_fields then
        logs.report("fields","using child push '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        DA      = fieldattributes(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        AP      = fieldappearances(field),
        H       = pdf_p,
    }
    save_kid(field,specification,d)
end

function methods.sub(name,specification,variant)
    local field = radios[name] or fields[name] or clones[name] -- fields in case of a clone, maybe use dedicated clones
    local values
    if variant == "copy" or variant == "clone" then
        name = field.parent
        values = field.values -- clone only, copy has nil so same as parent
        field = radios[name]
    else
        values = field.values
    end
    local parent = fields[field.parent]
    if not parent then
        return
    end
    local appearance = fieldstates(field,name,values) -- we need to force the 'On' name
    local default = radiodefault(parent,field)
    if not parent.pobj then
        if trace_fields then
            logs.report("fields","using parent '%s' of radio '%s' with values '%s' and default '%s'",parent.name,name,parent.values or "?",parent.default or "?")
        end
        local specification = parent.specification or { }
    --  enhance(specification,"Radio,RadiosInUnison")
        enhance(specification,"RadiosInUnison") -- maybe also PushButton as acrobat does
        local d = pdfdictionary {
            T    = parent.name,
            FT   = pdf_btn,
            Rect = pdf_no_rect,
            F    = fieldplus(specification),
            Ff   = fieldflag(specification),
            H    = pdf_n,
            V    = default,
        }
        save_parent(parent,specification,d)
    end
    if trace_fields then
        logs.report("fields","using child radio '%s' with values '%s'",name,values or "?")
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        DA      = fieldattributes(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        AS      = default,
        AP      = appearance,
        H       = pdf_n,
    }
    save_kid(parent,specification,d)
end
